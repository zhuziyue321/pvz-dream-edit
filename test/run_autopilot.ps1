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
    ## Unified with test/check_scripts.ps1 on 2026-10-16. The old default pointed at
    ## 'Godot_v4.6.2-stable_win64.exe', which does not exist on this machine (the real
    ## binary is 'godot.exe') - so a batch run silently failed to launch the engine.
    ## check_scripts.ps1 already hit the same trap and was fixed; keep the two in sync.
    [string]$Godot = 'C:\Users\a a\Desktop\godot.exe',
    [string]$Project = '',
    [switch]$Windowed,
    [int]$MaxSeconds = 300,
    [switch]$Quiet,
    ## 2026-10-16: refuse to run while a previous godot instance still holds the
    ## shared output file - that is exactly how "I asked for probe_x but got
    ## probe_y" happens. With this switch the leftovers are killed and we go on.
    [switch]$KillStale
)

$ErrorActionPreference = 'Stop'

## Fail loudly when the engine binary is missing: otherwise cmd just prints
## "not recognized" and we end up reading a stale/empty output file (silent green).
if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Host ('[autopilot] Godot executable not found: {0}' -f $Godot) -ForegroundColor Red
    Write-Host '[autopilot] pass -Godot "<real path>" or fix the default in this script' -ForegroundColor Red
    exit 2
}

## --- stale process guard (2026-10-16) ---------------------------------------
## ap_out.txt / ap_err.txt have FIXED paths, and a godot instance that never got
## told to quit keeps the file open. cmd then cannot truncate it, so this script
## reads the PREVIOUS run's report and prints it as if it were today's result
## (the classic symptom is "I asked for probe_x and got probe_y").
## Refuse to start against that state; -KillStale kills the leftovers instead.
$stale = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*godot*' })
if ($stale.Count -gt 0) {
    if ($KillStale) {
        Write-Host ('[autopilot] -KillStale: killing {0} leftover godot process(es)' -f $stale.Count) -ForegroundColor Yellow
        $stale | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } else {
        Write-Host ('[autopilot] {0} godot process(es) already running:' -f $stale.Count) -ForegroundColor Red
        foreach ($p in $stale) {
            Write-Host ('[autopilot]   pid {0}  started {1}' -f $p.Id, $p.StartTime) -ForegroundColor Red
        }
        Write-Host '[autopilot] they may hold the shared output file -> this run could print THEIR report.' -ForegroundColor Red
        Write-Host '[autopilot] close them (editor + game window), or pass -KillStale to kill them.' -ForegroundColor Red
        Write-Host '[autopilot] result=STALE_PROCESS' -ForegroundColor Red
        exit 3
    }
}
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
$runStart = Get-Date
try {
    $line = '"' + $Godot + '" ' + $godotArgs + ' > "' + $outF + '" 2> "' + $errF + '"'
    cmd.exe /c $line | Out-Null
    $code = $LASTEXITCODE
} finally {
    $env:APPDATA = $old
}

## --- freshness check ---------------------------------------------------------
## A report file older than $runStart was NOT written by this run: cmd could not
## open it (a leftover process still holds it) and we are about to print an old
## report as today's result. Say so loudly instead of passing it off as real.
$isStale = $true
if (Test-Path -LiteralPath $outF) {
    $isStale = (Get-Item -LiteralPath $outF).LastWriteTime -lt $runStart
}

$out = Get-Content -LiteralPath $outF -Encoding UTF8 -ErrorAction SilentlyContinue
$err = Get-Content -LiteralPath $errF -Encoding UTF8 -ErrorAction SilentlyContinue

if ($isStale) {
    Write-Host ''
    Write-Host '[autopilot] STALE OUTPUT: ap_out.txt was NOT written by this run.' -ForegroundColor Red
    Write-Host '            Everything below is from a PREVIOUS run - do NOT trust it.' -ForegroundColor Red
    Write-Host '            Look for leftover godot processes, then re-run with -KillStale.' -ForegroundColor Red
}

if (-not $Quiet) {
    Write-Host "---- STDOUT ----"
    $out | ForEach-Object { Write-Host $_ }
    if ($err) {
        Write-Host "---- STDERR ----"
        $err | Select-Object -First 40 | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
    }
}

Write-Host ""
Write-Host ("[autopilot] exitCode={0}  stdoutLines={1}  stderrLines={2}  stale={3}" -f $code, @($out).Count, @($err).Count, $isStale)
