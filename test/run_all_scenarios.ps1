#requires -Version 5.1
<#
    Batch-run every autopilot probe scenario and summarise PASS / FAIL / ERROR.

    Usage:
        powershell -ExecutionPolicy Bypass -File test/run_all_scenarios.ps1
        powershell -ExecutionPolicy Bypass -File test/run_all_scenarios.ps1 -Filter 'probe_zomboss_*'
        powershell -ExecutionPolicy Bypass -File test/run_all_scenarios.ps1 -Filter 'probe_init,probe_hand' -Windowed
        powershell -ExecutionPolicy Bypass -File test/run_all_scenarios.ps1 -OutFile test/_reports/last.md

    WHAT THIS IS
        A batch runner over the behaviour probes that already live in
        test/scenarios/. It boots the REAL main scene once per scenario
        (exactly like run_autopilot.ps1 does), reads each probe's
        machine-readable summary line ("[TAG] result=PASS|FAIL failed=<n>")
        and prints one table at the end. Non-zero exit when anything FAILs
        or ERRORs, so it can be wired into a CI step later.

    WHAT THIS IS NOT
        It is NOT a static checker, and a green run does NOT prove the game
        is playable. Rule card E-02 (indexed from docs/README.md) spells out
        the trap to avoid: probes only cover what they assert, so picture,
        timing and feel still need a human opening the game with a window.
        Use this to catch regressions in what the probes already assert,
        never as a replacement for playing.
        (Filename note: this file stays ASCII on purpose - PowerShell 5.1
        reads BOM-less scripts as ANSI, a trap recorded in the AI debugging
        doc; so CJK doc names are never written here, not even in comments.)

    VERDICTS
        PASS  - probe printed result=PASS
        FAIL  - probe printed result=FAIL
        DONE  - probe printed result=DONE (ran to the end, asserts nothing)
        ERROR - no result line at all: crash, hang, timeout, or the probe
                never reached its summary line. Treated as a failure.

    NOTES
        Scenarios MUST run one at a time. run_autopilot.ps1 re-creates the
        same redirected user dir (%TEMP%\pvz_autopilot\userdir) on every
        launch, so parallel runs would delete each other's save data.
        Per-scenario stdout is copied to %TEMP%\pvz_autopilot\runs\<name>.log
        - check that file first when a verdict looks wrong.

        -Godot is optional: when empty, run_autopilot.ps1 keeps its own
        default engine path, so the path is only hardcoded in one place.

    Exit code: 0 = no FAIL and no ERROR, 1 = at least one FAIL or ERROR.
    This file is ASCII-only on purpose (PowerShell 5.1 reads BOM-less scripts as ANSI).
#>
param(
    ## Comma-separated file-name patterns (without .gd). Default: every probe.
    [string]$Filter = 'probe_*',
    ## Empty = let run_autopilot.ps1 use its own default engine path.
    [string]$Godot = '',
    ## Per-scenario watchdog handed to run_autopilot.ps1 (it self-quits long before this).
    [int]$MaxSeconds = 180,
    [switch]$Windowed,
    [switch]$StopOnFail,
    ## Only print what would run, then exit 0.
    [switch]$ListOnly,
    ## Optional Markdown report path. Empty = print to console only.
    [string]$OutFile = ''
)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$scenarioDir = Join-Path $PSScriptRoot 'scenarios'
$runPs1 = Join-Path $PSScriptRoot 'run_autopilot.ps1'

if (-not (Test-Path -LiteralPath $runPs1)) {
    Write-Host "[runall] MISSING $runPs1" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $scenarioDir)) {
    Write-Host "[runall] MISSING $scenarioDir" -ForegroundColor Red
    exit 2
}

## Resolve TEMP to its long form, and use the SAME temp root run_autopilot.ps1
## writes to - that is where ap_out.txt lands after each scenario.
$tempRoot = $env:TEMP
try { $tempRoot = (Get-Item -LiteralPath $env:TEMP).FullName } catch { }
$tmpAp = Join-Path $tempRoot 'pvz_autopilot'
$runsDir = Join-Path $tmpAp 'runs'
New-Item -ItemType Directory -Force -Path $runsDir | Out-Null
Get-ChildItem -LiteralPath $runsDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

## Collect scenarios (support several comma-separated patterns, de-duplicated).
$patterns = @($Filter -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if ($patterns.Count -eq 0) { $patterns = @('probe_*') }

$files = @()
foreach ($p in $patterns) {
    $files += @(Get-ChildItem -LiteralPath $scenarioDir -Filter ($p + '.gd') -File -ErrorAction SilentlyContinue)
}
$files = @($files | Sort-Object -Property Name -Unique)

if ($files.Count -eq 0) {
    Write-Host "[runall] no scenario matched -Filter '$Filter' in $scenarioDir" -ForegroundColor Red
    exit 2
}

Write-Host "[runall] project   : $project"
Write-Host "[runall] filter    : $Filter"
Write-Host "[runall] scenarios : $($files.Count)"
Write-Host "[runall] windowed  : $($Windowed.IsPresent)"
Write-Host "[runall] watchdog  : ${MaxSeconds}s per scenario"
Write-Host "[runall] run logs  : $runsDir"
Write-Host ''

if ($ListOnly) {
    $files | ForEach-Object { Write-Host ('  ' + [System.IO.Path]::GetFileNameWithoutExtension($_.Name)) }
    exit 0
}

$results = @()
$index = 0
foreach ($f in $files) {
    $index++
    $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)

    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $runPs1,
                '-Scenario', $name, '-Quiet', '-MaxSeconds', $MaxSeconds)
    if ($Windowed) { $psArgs += '-Windowed' }
    if ($Godot -ne '') { $psArgs += @('-Godot', $Godot) }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & powershell.exe $psArgs | Out-Null
    } catch {
        ## A launcher-level failure must not abort the whole batch.
    }
    $sw.Stop()
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 1)

    ## run_autopilot.ps1 always (re)writes ap_out.txt / ap_err.txt for this run.
    $srcOut = Join-Path $tmpAp 'ap_out.txt'
    $srcErr = Join-Path $tmpAp 'ap_err.txt'
    $out = ''
    if (Test-Path -LiteralPath $srcOut) {
        $out = [string](Get-Content -LiteralPath $srcOut -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
    }
    if (-not $out) { $out = '' }
    $runLog = Join-Path $runsDir ($name + '.log')
    if (Test-Path -LiteralPath $srcOut) {
        Copy-Item -LiteralPath $srcOut -Destination $runLog -Force -ErrorAction SilentlyContinue
    }

    $verdict = 'ERROR'
    if ($out -match 'result\s*=\s*FAIL') { $verdict = 'FAIL' }
    elseif ($out -match 'result\s*=\s*PASS') { $verdict = 'PASS' }
    elseif ($out -match 'result\s*=\s*DONE') { $verdict = 'DONE' }

    $failedCount = ''
    if ($out -match 'failed\s*=\s*(\d+)') { $failedCount = $Matches[1] }

    $detail = ''
    if ($verdict -eq 'ERROR') {
        $errTxt = ''
        if (Test-Path -LiteralPath $srcErr) {
            $errTxt = [string](Get-Content -LiteralPath $srcErr -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
        }
        if ($errTxt -match 'SCRIPT ERROR|Parse Error|Failed to load script') {
            $detail = 'crash'
        } elseif ($secs -ge ($MaxSeconds - 5)) {
            $detail = 'timeout'
        } else {
            $detail = 'no-result-line'
        }
    }

    $color = switch ($verdict) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'DONE' { 'Cyan' }
        default { 'Yellow' }
    }
    $suffix = if ($failedCount -ne '') { " failed=$failedCount" } else { '' }
    $suffix += if ($detail -ne '') { " ($detail)" } else { '' }
    Write-Host ('[{0,3}/{1}] {2,-32} {3,-6} {4,6}s{5}' -f $index, $files.Count, $name, $verdict, $secs, $suffix) -ForegroundColor $color

    $results += [pscustomobject]@{
        Name    = $name
        Verdict = $verdict
        Failed  = $failedCount
        Seconds = $secs
        Detail  = $detail
        Log     = $runLog
    }

    if ($StopOnFail -and ($verdict -eq 'FAIL' -or $verdict -eq 'ERROR')) {
        Write-Host ''
        Write-Host "[runall] -StopOnFail: aborted after $name" -ForegroundColor Yellow
        break
    }
}

$nPass = @($results | Where-Object { $_.Verdict -eq 'PASS' }).Count
$nFail = @($results | Where-Object { $_.Verdict -eq 'FAIL' }).Count
$nDone = @($results | Where-Object { $_.Verdict -eq 'DONE' }).Count
$nErr  = @($results | Where-Object { $_.Verdict -eq 'ERROR' }).Count
$total = [math]::Round((($results | Measure-Object -Property Seconds -Sum).Sum), 1)

Write-Host ''
Write-Host '================ SUMMARY ================' -ForegroundColor White
Write-Host ("  PASS   : {0}" -f $nPass) -ForegroundColor Green
Write-Host ("  FAIL   : {0}" -f $nFail) -ForegroundColor $(if ($nFail -gt 0) { 'Red' } else { 'Gray' })
Write-Host ("  DONE   : {0}  (ran to the end, asserts nothing)" -f $nDone) -ForegroundColor Cyan
Write-Host ("  ERROR  : {0}  (crash / timeout / no result line)" -f $nErr) -ForegroundColor $(if ($nErr -gt 0) { 'Red' } else { 'Gray' })
Write-Host ("  elapsed: {0}s" -f $total)

$bad = @($results | Where-Object { $_.Verdict -eq 'FAIL' -or $_.Verdict -eq 'ERROR' })
if ($bad.Count -gt 0) {
    Write-Host ''
    Write-Host '---- NOT PASSING ----' -ForegroundColor Red
    foreach ($r in $bad) {
        Write-Host ("  {0,-32} {1,-6} {2}" -f $r.Name, $r.Verdict, $r.Detail) -ForegroundColor Red
        Write-Host ("      log: {0}" -f $r.Log) -ForegroundColor DarkGray
    }
}

$noAssert = @($results | Where-Object { $_.Verdict -eq 'DONE' })
if ($noAssert.Count -gt 0) {
    Write-Host ''
    Write-Host '---- NO ASSERTION (consider giving these a result=PASS|FAIL line) ----' -ForegroundColor Cyan
    $noAssert | ForEach-Object { Write-Host ('  ' + $_.Name) -ForegroundColor Cyan }
}

if ($OutFile -ne '') {
    $outDir = Split-Path $OutFile -Parent
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    $lines = @()
    $lines += '# run_all_scenarios report'
    $lines += ''
    $lines += ('- filter : `{0}`' -f $Filter)
    $lines += ('- verdict: PASS {0} / FAIL {1} / DONE {2} / ERROR {3}' -f $nPass, $nFail, $nDone, $nErr)
    $lines += ('- elapsed: {0}s' -f $total)
    $lines += ''
    $lines += '| scenario | verdict | failed | seconds | detail |'
    $lines += '|---|---|---|---|---|'
    foreach ($r in $results) {
        $lines += ('| {0} | {1} | {2} | {3} | {4} |' -f $r.Name, $r.Verdict, $r.Failed, $r.Seconds, $r.Detail)
    }
    $lines += ''
    Set-Content -LiteralPath $OutFile -Value ($lines -join "`n") -Encoding UTF8
    Write-Host ''
    Write-Host "[runall] report written to $OutFile"
}

Write-Host ''
## NB: console strings stay ASCII on purpose - PowerShell 5.1 reads this file as
## ANSI, so any CJK here would print as mojibake (CJK inside comments is fine).
if ($nFail -gt 0 -or $nErr -gt 0) {
    Write-Host '[runall] result=FAIL  (a PASS only means the probes agreed - open the game to confirm)' -ForegroundColor Red
    exit 1
}
Write-Host '[runall] result=PASS  (a PASS only means the probes agreed - open the game to confirm)' -ForegroundColor Green
exit 0
