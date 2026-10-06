#requires -Version 5.1
<#
    merge_alpha.ps1 - bake a PVZ-style alpha mask into a base image, offline.

    The classic PVZ asset set ships colour as JPG plus a separate grayscale mask
    (<name>_.*) where white = opaque and black = transparent. Merging the two
    once here produces a single RGBA PNG, so nothing has to apply the mask
    again at runtime (no shader, no per-pixel Image loop in the game).

    Usage:
      powershell -ExecutionPolicy Bypass -File tools/merge_alpha.ps1 -Name assets/image/background/pool_base
      powershell -ExecutionPolicy Bypass -File tools/merge_alpha.ps1 -Name assets/image/background/pool_base_night -Mask assets/image/background/pool_base_.png
      powershell -ExecutionPolicy Bypass -File tools/merge_alpha.ps1 -Name assets/image/background/pool_base -Invert
      powershell -ExecutionPolicy Bypass -File tools/merge_alpha.ps1 -All
      powershell -ExecutionPolicy Bypass -File tools/merge_alpha.ps1 -All -Overwrite

    -Name        target WITHOUT extension; base and mask are resolved as siblings
    -Mask        explicit mask path; overrides the automatic lookup
    -All         scan -AssetsRoot for every '*_.png|*_.jpg' mask and bake each pair
    -AssetsRoot  directory scanned by -All (default: assets)
    -Invert      negate the mask (use it when black = opaque)
    -Overwrite   replace an existing output PNG (default: skip it)
    -WhatIf      print the ffmpeg command line instead of running it

    Notes
      Base lookup order is .jpg then .png, because a base that is already a PNG
      may carry its own alpha and re-baking could double-apply the mask.
      -All refuses pairs whose base is a PNG for the same reason: the output name
      would overwrite the source. Bake those explicitly with -Name -Mask.
      A mask whose size differs from the base is scaled to it (nearest neighbour),
      so alpha edges stay hard.

    This file is ASCII-only on purpose: PowerShell 5.1 reads BOM-less scripts as
    ANSI, so non-ASCII literals are unreliable.
#>
param(
    [string]$Name = '',
    [string]$Mask = '',
    [switch]$All,
    [string]$AssetsRoot = 'assets',
    [switch]$Invert,
    [switch]$Overwrite,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

## Paths are resolved against this repository root, so the script behaves the
## same no matter which directory it is invoked from.
## $MyInvocation.MyCommand.Path is used instead of $PSScriptRoot because PS 5.1
## resolves $PSScriptRoot inconsistently for relative script paths.
$thisScript = $MyInvocation.MyCommand.Path
if (-not $thisScript) { throw 'cannot locate this script; invoke it with -File <path>' }
$scriptDir = Split-Path -Parent (Resolve-Path -LiteralPath $thisScript).Path
$repoRoot = Split-Path -Parent $scriptDir
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.godot') -PathType Container) -and
    -not (Test-Path -LiteralPath (Join-Path $repoRoot 'project.godot') -PathType Leaf)) {
    throw "unexpected repo root: $repoRoot"
}

function Resolve-FromRoot([string]$path) {
    if ([System.IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repoRoot $path
}

## Pair discovered by -All
function New-Pair {
    param([string]$BasePath, [string]$MaskPath, [string]$OutPath)
    return [PSCustomObject]@{ Base = $BasePath; Mask = $MaskPath; Out = $OutPath }
}

function Get-ImageSize([string]$path) {
    $raw = (& ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 $path) -join ''
    $parts = $raw -split ','
    if ($parts.Count -lt 2) { throw "cannot read size of $path" }
    return @([int]$parts[0], [int]$parts[1])
}

function Merge-AlphaPair {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$MaskPath,
        [Parameter(Mandatory = $true)][string]$OutPath,
        [switch]$Invert,
        [switch]$Overwrite,
        [switch]$WhatIf,
        [hashtable]$Stats
    )

    $label = Split-Path $OutPath -Leaf

    if (-not (Test-Path -LiteralPath $BasePath)) { Write-Host "[SKIP] $label - base missing: $BasePath" -ForegroundColor Yellow; $Stats.Skip += 1; return }
    if (-not (Test-Path -LiteralPath $MaskPath)) { Write-Host "[SKIP] $label - mask missing: $MaskPath" -ForegroundColor Yellow; $Stats.Skip += 1; return }
    if ((Test-Path -LiteralPath $OutPath) -and -not $Overwrite) {
        Write-Host "[SKIP] $label - already baked (use -Overwrite to replace)" -ForegroundColor DarkGray
        $Stats.Skip += 1
        return
    }

    $size = Get-ImageSize $BasePath
    $maskSize = Get-ImageSize $MaskPath
    $scale = ''
    if ($size[0] -ne $maskSize[0] -or $size[1] -ne $maskSize[1]) {
        $scale = ',scale=' + $size[0] + ':' + $size[1] + ':flags=neighbor'
    }
    $negate = if ($Invert) { ',negate' } else { '' }
    $filter = "[0:v]format=rgba[base];[1:v]format=gray$scale$negate[mask];[base][mask]alphamerge"

    ## Base and output can be the same file (explicit -Name on a PNG base):
    ## always render to a temp file first, then move it into place.
    ## The temp name keeps the .png extension because ffmpeg infers the muxer
    ## from it.
    $outDir = Split-Path $OutPath -Parent
    $outStem = [System.IO.Path]::GetFileNameWithoutExtension($OutPath)
    $tmpOut = Join-Path $outDir ($outStem + '.baking.png')
    ## -update 1 is required by ffmpeg >= 7 when writing a single image with -frames:v 1,
    ## otherwise image2 rejects the output name for lacking a sequence pattern.
    $argLine = 'ffmpeg -y -i "' + $BasePath + '" -i "' + $MaskPath + '" -filter_complex "' + $filter + '" -frames:v 1 -update 1 -pix_fmt rgba "' + $tmpOut + '"'

    if ($WhatIf) {
        Write-Host "[WHATIF] $argLine" -ForegroundColor Cyan
        $Stats.Skip += 1
        return
    }

    ## Native stderr would raise a NativeCommandError under $ErrorActionPreference='Stop'.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & ffmpeg -y -i $BasePath -i $MaskPath -filter_complex $filter -frames:v 1 -update 1 -pix_fmt rgba $tmpOut 2>$null
    $ffExit = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference

    if ($ffExit -ne 0 -or -not (Test-Path -LiteralPath $tmpOut)) {
        Write-Host "[FAIL] $label - ffmpeg failed on $BasePath" -ForegroundColor Red
        Remove-Item -LiteralPath $tmpOut -Force -ErrorAction SilentlyContinue
        $Stats.Fail += 1
        return
    }

    Move-Item -LiteralPath $tmpOut -Destination $OutPath -Force
    $finalSize = Get-ImageSize $OutPath
    Write-Host ("[ OK ] {0} - {1}x{2} alpha baked" -f $label, $finalSize[0], $finalSize[1]) -ForegroundColor Green
    $Stats.Ok += 1
}

$stats = @{ Ok = 0; Skip = 0; Fail = 0 }
$pairs = New-Object System.Collections.ArrayList

if ($All) {
    $root = Resolve-FromRoot $AssetsRoot
    if (-not (Test-Path -LiteralPath $root)) { throw "assets root not found: $AssetsRoot" }
    $masks = Get-ChildItem -LiteralPath $root -Recurse -File |
        Where-Object { $_.BaseName -match '.+_$' -and $_.Extension -in @('.png', '.jpg', '.jpeg') }
    foreach ($m in $masks) {
        $prefix = Join-Path $m.DirectoryName $m.BaseName.Substring(0, $m.BaseName.Length - 1)
        $base = Get-ChildItem -Path ($prefix + '.*') -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.jpg', '.jpeg') } | Select-Object -First 1
        if ($null -eq $base) { continue }   ## PNG base only: see file header notes
        $out = $prefix + '.png'
        [void]$pairs.Add((New-Pair -BasePath $base.FullName -MaskPath $m.FullName -OutPath $out))
    }
}
elseif ($Name -ne '') {
    $prefix = Resolve-FromRoot $Name
    if ($Mask -ne '') {
        $maskPath = Resolve-FromRoot $Mask
    }
    else {
        $maskPath = ''
        foreach ($candidate in @(($prefix + '_.png'), ($prefix + '_.jpg'), ($prefix + '_.jpeg'))) {
            if (Test-Path -LiteralPath $candidate) { $maskPath = $candidate; break }
        }
        if ($maskPath -eq '') { Write-Error ("cannot find mask for " + $prefix + " (tried " + $prefix + "_.png)"); exit 1 }
    }
    $basePath = ''
    foreach ($candidate in @(($prefix + '.jpg'), ($prefix + '.jpeg'), ($prefix + '.png'))) {
        if (Test-Path -LiteralPath $candidate) { $basePath = $candidate; break }
    }
    if ($basePath -eq '') { Write-Error ("cannot find base image for " + $prefix); exit 1 }
    [void]$pairs.Add((New-Pair -BasePath $basePath -MaskPath $maskPath -OutPath ($prefix + '.png')))
}
else {
    Write-Host 'nothing to do: pass -Name <path-without-extension> or -All' -ForegroundColor Yellow
    exit 0
}

if ($pairs.Count -eq 0) {
    Write-Host 'no base+mask pair matched' -ForegroundColor Yellow
    exit 0
}

foreach ($p in $pairs) {
    Merge-AlphaPair -BasePath $p.Base -MaskPath $p.Mask -OutPath $p.Out `
        -Invert:$Invert -Overwrite:$Overwrite -WhatIf:$WhatIf -Stats $stats
}

Write-Host ""
Write-Host ("baked={0} skipped={1} failed={2}" -f $stats.Ok, $stats.Skip, $stats.Fail)
if ($stats.Fail -gt 0) { exit 1 }
