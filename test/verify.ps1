#requires -Version 5.1
<#
    PVZ-Godot project verification pipeline.

    Usage:
        powershell -ExecutionPolicy Bypass -File test/verify.ps1
        powershell -ExecutionPolicy Bypass -File test/verify.ps1 -Godot "D:\Godot\godot.exe"
        powershell -ExecutionPolicy Bypass -File test/verify.ps1 -SkipSlow

    Steps:
      1  editor scan          compile every script, resolve every resource
      1b script compile       explicitly load every .gd
      1c standard check       project standard red lines (docs/project-standard.md)
      2  resource self-check  load every .tres/.tscn, report missing .uid
      3  reference integrity  every res:// path in the project must resolve
      4  runtime smoke        execute utility classes            (no autoloads)
      5  autoload smoke       boot all autoloads in an isolated user dir
      6  hygiene              *.tmp, orphan .uid, leftover temp names

    IMPORTANT
      Steps 1-3 only prove "it compiles" and "references resolve".
      They CANNOT catch runtime faults such as infinite recursion.
      Steps 4-5 exist exactly for that - do not skip them.

    This file is intentionally ASCII-only: PowerShell 5.1 reads BOM-less
    scripts as ANSI, so non-ASCII literals (including regexes) are unreliable.
    The Godot-side tests emit ASCII marker lines instead:
        [SELFCHECK] ... result=PASS|FAIL
        [RUNTIME-SMOKE] ... result=PASS|FAIL
        [AUTOLOAD-SMOKE] ... result=PASS|FAIL
#>
param(
    [string]$Godot = 'C:\Users\a a\Desktop\Godot_v4.6.2-stable_win64.exe',
    [string]$Project = '',
    [switch]$SkipSlow
)

if (-not $Project) {
    if ($PSScriptRoot) { $Project = (Split-Path $PSScriptRoot -Parent) } else { $Project = (Get-Location).Path }
}

$ErrorActionPreference = 'Stop'
$NL = [string][char]10
## Resolve TEMP to its long form: a child process may report the 8.3 short name
## (C:UsersXXXXXX~1...), which breaks Remove-Item with a terminating argument error.
$tempRoot = $env:TEMP
try { $tempRoot = (Get-Item -LiteralPath $env:TEMP).FullName } catch { }
$tmp = Join-Path $tempRoot ('pvz_verify_' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'appdata') | Out-Null

$summary = New-Object System.Collections.ArrayList

function Invoke-Godot {
    param([string]$Arguments, [string]$OutFile, [string]$ErrFile, [switch]$IsolatedUser)
    $oldAppData = $env:APPDATA
    if ($IsolatedUser) { $env:APPDATA = (Join-Path $tmp 'appdata') }
    try {
        Remove-Item -LiteralPath $OutFile, $ErrFile -Force -ErrorAction SilentlyContinue
        ## Start-Process is denied by some sandboxed environments, and Godot's Windows
        ## exe is a GUI-subsystem binary whose stdout is only captured when it is given
        ## a real file handle. cmd redirection provides both.
        $line = '"' + $Godot + '" ' + $Arguments + ' > "' + $OutFile + '" 2> "' + $ErrFile + '"'
        cmd.exe /c $line | Out-Null
        return $LASTEXITCODE
    } finally {
        if ($IsolatedUser) { $env:APPDATA = $oldAppData }
    }
}

function Get-Text([string]$path) {
    return ((Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue) -join $NL)
}

function Add-Result {
    param([string]$Step, [bool]$Passed, [string]$Detail)
    [void]$summary.Add([PSCustomObject]@{ Step = $Step; Passed = $Passed })
    $tag = if ($Passed) { 'PASS' } else { 'FAIL' }
    $color = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1} {2}" -f $tag, $Step.PadRight(22), $Detail) -ForegroundColor $color
}

Write-Host ""
Write-Host "project : $Project"
Write-Host "godot   : $Godot"
Write-Host ""

# ------------------------------------------------------------- step 0 (precheck)
$running = @(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -and $_.CommandLine -like "*$Project*" })
if ($running.Count -gt 0) {
    Write-Host "[WARN] An editor has THIS project open. Close it before renaming files:" -ForegroundColor Yellow
    Write-Host "       the editor deletes .uid files whose target briefly disappears." -ForegroundColor Yellow
    Write-Host ""
}

# ------------------------------------------------------------- step 1
$eo = Join-Path $tmp 'ed.out'
$ee = Join-Path $tmp 'ed.err'
[void](Invoke-Godot -Arguments ('--headless --path "{0}" --editor --quit' -f $Project) -OutFile $eo -ErrFile $ee -IsolatedUser)
## Scan BOTH streams: engine diagnostics land on stderr, but the editor's own
## messages (which are LOCALIZED - e.g. Chinese "错误 (146, 53)") can land on stdout.
## Relying on English keywords alone silently misses real parse errors.
$edAll = @()
$edAll += @(Get-Content -LiteralPath $ee -Encoding UTF8 -ErrorAction SilentlyContinue)
$edAll += @(Get-Content -LiteralPath $eo -Encoding UTF8 -ErrorAction SilentlyContinue)
$errPat = 'SCRIPT ERROR|Parse Error|Compile Error|File not found|Failed to load|Attempt to open|ERROR:|错误|解析错误|分析错误|\(\d+,\s*\d+\)'
$shutdownNoise = 'leaked at exit|still in use at exit|ObjectDB instances leaked'
## Environment noise, not a project problem: this machine has no readable root
## certificate store, and a sandboxed run may be unable to write editor prefs.
$envNoise = 'root certificate store|editor_settings-4\.6\.tres'
$edBad = @($edAll | Where-Object { ($_ -match $errPat) -and ($_ -notmatch $shutdownNoise) -and ($_ -notmatch $envNoise) })
Add-Result '1 editor scan' ($edBad.Count -eq 0) ("problems=$($edBad.Count)")
if ($edBad.Count -gt 0) { $edBad | Select-Object -First 10 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkRed } }

# ------------------------------------------------------------- step 1b
$so = Join-Path $tmp 'sc.out'
$se = Join-Path $tmp 'sc.err'
## --no-autopilot: this is not a game boot, so do not let DebugChannel inject
## the autopilot scenario into it.
[void](Invoke-Godot -Arguments ('--headless --path "{0}" "res://test/script_check.tscn" -- --no-autopilot' -f $Project) -OutFile $so -ErrFile $se -IsolatedUser)
$scMark = [regex]::Match((Get-Text $so), '\[SCRIPTCHECK\] checked=(\d+) failed=(\d+) result=(\w+)')
if ($scMark.Success) {
    $d1b = "compiled=" + $scMark.Groups[1].Value + " failed=" + $scMark.Groups[2].Value
    Add-Result '1b script compile' ($scMark.Groups[3].Value -eq 'PASS') $d1b
    if ($scMark.Groups[3].Value -ne 'PASS') { (Get-Text $so) -split $NL | Where-Object { $_ -match 'BUILD-FAIL' } | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkRed } }
} else {
    Add-Result '1b script compile' $false 'no [SCRIPTCHECK] marker'
}

# ------------------------------------------------------------- step 1c
$do = Join-Path $tmp 'std.out'
$de = Join-Path $tmp 'std.err'
[void](Invoke-Godot -Arguments ('--headless --path "{0}" --script "res://test/standard_check.gd"' -f $Project) -OutFile $do -ErrFile $de -IsolatedUser)
$stdMark = [regex]::Match((Get-Text $do), '\[STDCHECK\] scripts=(\d+) checks=(\d+) failed=(\d+) warned=(\d+) result=(\w+)')
if ($stdMark.Success) {
    $detail1c = "checked=" + $stdMark.Groups[1].Value + " failed=" + $stdMark.Groups[3].Value + " warned=" + $stdMark.Groups[4].Value
    Add-Result '1c standard check' ($stdMark.Groups[5].Value -eq 'PASS') $detail1c
    if ($stdMark.Groups[5].Value -ne 'PASS') { (Get-Text $do) -split $NL | Where-Object { $_ -match '\[FAIL\]' } | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkRed } }
} else {
    Add-Result '1c standard check' $false 'no [STDCHECK] marker in output'
}

# ------------------------------------------------------------- step 2
$co = Join-Path $tmp 'ck.out'
$ce = Join-Path $tmp 'ck.err'
[void](Invoke-Godot -Arguments ('--headless --path "{0}" --script "res://test/project_checker.gd"' -f $Project) -OutFile $co -ErrFile $ce -IsolatedUser)
$ckMark = [regex]::Match((Get-Text $co), '\[SELFCHECK\] checked=(\d+) loadFailures=(\d+) missingUid=(\d+) result=(\w+)')
if ($ckMark.Success) {
    $detail2 = "checked=" + $ckMark.Groups[1].Value + " loadFailures=" + $ckMark.Groups[2].Value + " missingUid=" + $ckMark.Groups[3].Value
    Add-Result '2 resource self-check' ($ckMark.Groups[4].Value -eq 'PASS') $detail2
} else {
    Add-Result '2 resource self-check' $false 'no [SELFCHECK] marker in output'
}

# ------------------------------------------------------------- step 3
$refExts = @('.tres','.tscn','.gd','.md','.cfg','.godot','.json','.txt','.gdshader','.gdshaderinc','.import')
$refFiles = @(Get-ChildItem -LiteralPath $Project -Recurse -File | Where-Object { $refExts -contains $_.Extension -and $_.FullName -notmatch '\\\.godot\\' -and $_.FullName -notmatch '\\assets\\' -and $_.FullName -notmatch '\\readme_show\\' })
$refSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in $refFiles) {
    $t = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($f.FullName))
    ## Also stop at CJK / full-width punctuation: docs and log messages put Chinese
    ## text directly after a path, which otherwise gets swallowed into the match.
    foreach ($m in [regex]::Matches($t, 'res://[^"\s\),\x60\\\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]+')) { [void]$refSet.Add($m.Value) }
}
$broken = New-Object System.Collections.ArrayList
foreach ($r in $refSet) {
    $rel = ($r -replace '^res://','') -replace '/','\'
    if (-not (Test-Path -LiteralPath (Join-Path $Project $rel))) { [void]$broken.Add($r) }
}
## Benign unresolvable references:
##   - bare "res://" prefix appearing in prose
##   - third-party addons
##   - assets removed for copyright reasons
##   - editor-only helper defaults
##   - test/inject/* : created on demand to arm the autopilot; the code guards with
##     ResourceLoader.exists(), so a missing file here is the NORMAL (disarmed) state
##   - prose examples in the docs (res://, res://x.gd)
$benign = @($broken | Where-Object { $_ -eq 'res://' -or $_ -eq 'res://x.gd' -or $_ -like 'res://addons/*' -or $_ -like 'res://assets/reanim/*' -or $_ -like 'res://test/inject/*' -or $_ -in @('res://combined_result.png','res://CrazyDave_body1.png') })
$realBroken = @($broken | Where-Object { $benign -notcontains $_ })
$detail3 = "checked=" + $refSet.Count + " unresolvable=" + $broken.Count + " benign=" + $benign.Count
Add-Result '3 reference integrity' ($realBroken.Count -eq 0) $detail3
$realBroken | Select-Object -First 15 | ForEach-Object { Write-Host "        BROKEN $_" -ForegroundColor DarkRed }

if (-not $SkipSlow) {
    # --------------------------------------------------------- step 4
    $ro = Join-Path $tmp 'rt.out'
    $re = Join-Path $tmp 'rt.err'
    [void](Invoke-Godot -Arguments ('--headless --path "{0}" --script "res://test/runtime_smoke.gd"' -f $Project) -OutFile $ro -ErrFile $re -IsolatedUser)
    $rtOut = Get-Text $ro
    $rtErr = Get-Text $re
    $rtMark = [regex]::Match($rtOut, '\[RUNTIME-SMOKE\] passed=(\d+) failed=(\d+) result=(\w+)')
    $overflow = ($rtErr -match 'Stack overflow') -or ($rtErr -match 'Internal script error')
    if ($rtMark.Success) {
        $detail4 = "passed=" + $rtMark.Groups[1].Value + " failed=" + $rtMark.Groups[2].Value + " stackOverflow=" + $overflow
        Add-Result '4 runtime smoke' (($rtMark.Groups[3].Value -eq 'PASS') -and (-not $overflow)) $detail4
    } else {
        Add-Result '4 runtime smoke' $false 'no [RUNTIME-SMOKE] marker (crashed before summary?)'
        ($rtErr -split $NL) | Select-Object -First 10 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkRed }
        ($rtOut -split $NL) | Select-Object -Last 10 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkRed }
    }

    # --------------------------------------------------------- step 5
    $ao = Join-Path $tmp 'al.out'
    $ae = Join-Path $tmp 'al.err'
    $alCode = Invoke-Godot -Arguments ('--headless --path "{0}" "res://test/autoload_smoke.tscn" -- --no-autopilot' -f $Project) -OutFile $ao -ErrFile $ae -IsolatedUser
    $alOut = Get-Text $ao
    $alErr = Get-Text $ae
    $alMark = [regex]::Match($alOut, '\[AUTOLOAD-SMOKE\] failed=(\d+) result=(\w+)')
    if ($alMark.Success) {
        $detail5 = "failed=" + $alMark.Groups[1].Value + " exitCode=" + $alCode + " userDir=isolated"
        Add-Result '5 autoload smoke' (($alMark.Groups[2].Value -eq 'PASS') -and $alCode -eq 0) $detail5
    } else {
        Add-Result '5 autoload smoke' $false 'no [AUTOLOAD-SMOKE] marker'
        ($alErr -split $NL) | Select-Object -First 8 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkRed }
    }
}

# ------------------------------------------------------------- step 6
$junkTmp = @(Get-ChildItem -LiteralPath $Project -Recurse -File -Filter '*.tmp')
$casetmp = @(Get-ChildItem -LiteralPath $Project -Recurse -Force | Where-Object { $_.Name -like '*__casetmp*' })
$orphanUid = @(Get-ChildItem -LiteralPath $Project -Recurse -File -Filter '*.uid' | Where-Object { -not (Test-Path -LiteralPath ($_.FullName -replace '\.uid$','')) })
$detail6 = "tmp=" + $junkTmp.Count + " casetmp=" + $casetmp.Count + " orphanUid=" + $orphanUid.Count
Add-Result '6 hygiene' (($junkTmp.Count + $casetmp.Count + $orphanUid.Count) -eq 0) $detail6

# ------------------------------------------------------------- summary
$failed = @($summary | Where-Object { -not $_.Passed })
Write-Host ""
Write-Host ("=" * 62)
if ($failed.Count -eq 0) {
    Write-Host "VERIFICATION PASSED" -ForegroundColor Green
} else {
    Write-Host "VERIFICATION FAILED: $($failed.Count) step(s)" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host ("  - " + $_.Step) -ForegroundColor Red }
}
Write-Host ("=" * 62)
Write-Host ""
Write-Host "Automated steps cannot cover gameplay behaviour."
Write-Host "See docs/verification.md for the manual regression checklist."
Write-Host ""

## Cleanup must never change the verdict: wrap it so a temp-dir quirk
## cannot turn a passing run into a non-zero exit code.
try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch { }

if ($failed.Count -gt 0) { exit 1 } else { exit 0 }
