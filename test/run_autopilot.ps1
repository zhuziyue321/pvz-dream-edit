#requires -Version 5.1
<#
    Run one autopilot scenario headless and print its report.

    Usage:
        powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario probe_plant
        powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario res://test/inject/scenario.gd
        powershell -ExecutionPolicy Bypass -File test/run_autopilot.ps1 -Scenario boot_level -Windowed

    The game boots its REAL main scene (start menu, level select, level), and the
    DebugChannel autoload injects the autopilot because --scenario was passed.
    Do NOT pass res://test/autopilot.tscn as the scene: that replaces the main scene,
    so there is no start menu and every menu-driven scenario fails immediately.

    This works whether or not the F5 injection switch (test/inject/scenario.gd)
    is armed - the CLI trigger is independent of that file.

    The user data dir is redirected to a temp folder, so real saves are untouched.
    This file is ASCII-only on purpose (PowerShell 5.1 reads BOM-less scripts as ANSI).
#>
param(
    [Parameter(Mandatory = $true)][string]$Scenario,
    [string]$Godot = 'C:\Users\a a\Desktop\Godot_v4.6.2-stable_win64.exe',
    [string]$Project = '',
    [switch]$Windowed,
    [int]$MaxSeconds = 300,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
if (-not $Project) {
    if ($PSScriptRoot) { $Project = (Split-Path $PSScriptRoot -Parent) } else { $Project = (Get-Location).Path }
}
## Hard dependency: the injector loads this file by path.
$ap = Join-Path $Project 'test\autopilot.gd'
if (-not (Test-Path -LiteralPath $ap)) {
    Write-Host "[autopilot] MISSING $ap - nothing to inject." -ForegroundColor Red
    exit 2
}
## Informational only: the F5 switch is independent of this CLI path.
$inject = Join-Path $Project 'test\inject\scenario.gd'
$armed = Test-Path -LiteralPath $inject

## Resolve TEMP to its long form: a child process may report the 8.3 short name.
$tempRoot = $env:TEMP
try { $tempRoot = (Get-Item -LiteralPath $env:TEMP).FullName } catch { }
$tmp = Join-Path $tempRoot 'pvz_autopilot'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$userDir = Join-Path $tmp 'userdir'
if (Test-Path -LiteralPath $userDir) { Remove-Item -LiteralPath $userDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $userDir | Out-Null

$resPath = if ($Scenario -like 'res://*') { $Scenario } else { 'res://test/scenarios/' + $Scenario + '.gd' }
$headless = if ($Windowed) { '' } else { '--headless ' }

$outF = Join-Path $tmp 'ap_out.txt'
$errF = Join-Path $tmp 'ap_err.txt'
Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue

## NB: do not name this $args - that is a PowerShell automatic variable.
$godotArgs = $headless + '--path "' + $Project + '" -- --scenario=' + $resPath + ' --autopilot-max-seconds=' + $MaxSeconds
Write-Host "[autopilot] scenario : $resPath"
Write-Host "[autopilot] headless : $(-not $Windowed)"
Write-Host "[autopilot] usrdir   : $userDir"
Write-Host "[autopilot] F5 arm   : $armed  (test/inject/scenario.gd present?)"
Write-Host ""

## Start-Process is denied by some sandboxed environments, and Godot's Windows exe
## is a GUI-subsystem binary whose stdout is only captured when it is given a real
## file handle. cmd redirection gives us both: no Start-Process, and a real handle.
$old = $env:APPDATA
$env:APPDATA = $userDir
$code = -1
try {
    $line = '"' + $Godot + '" ' + $godotArgs + ' > "' + $outF + '" 2> "' + $errF + '"'
    cmd.exe /c $line | Out-Null
    $code = $LASTEXITCODE
} finally {
    $env:APPDATA = $old
}

$out = Get-Content -LiteralPath $outF -Encoding UTF8 -ErrorAction SilentlyContinue
$err = Get-Content -LiteralPath $errF -Encoding UTF8 -ErrorAction SilentlyContinue

if (-not $Quiet) {
    Write-Host "---- STDOUT ----"
    $out | ForEach-Object { Write-Host $_ }
    if ($err) {
        Write-Host "---- STDERR ----"
        $err | Select-Object -First 40 | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
    }
}

Write-Host ""
Write-Host "[autopilot] exitCode=$code  stdoutLines=$(@($out).Count)  stderrLines=$(@($err).Count)"
