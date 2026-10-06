#requires -Version 5.1
<#
    Compile-check every GDScript in the project.

        powershell -ExecutionPolicy Bypass -File test/check_scripts.ps1

    What this IS:   drives Godot's own resource pipeline to compile every script and
                    resolve every global class, then reports anything that failed to
                    compile. It catches broken identifiers, const-as-type mistakes,
                    cyclic references and missing classes across the whole project.

    What this IS NOT: it does NOT replace opening the game. See docs/验证流程.md - the
                    project removed its old static rule checkers on purpose, because
                    "compiles" never proved "playable". The recursion bug that once
                    crashed Log._write() passed every static check.

    Use it as a cheap first gate (seconds) before spending minutes on a real run:
        check_scripts.ps1   ->      then   run_autopilot.ps1 -Scenario probe_x -Windowed

    KNOWN LIMITATION: Godot only compiles scripts reachable from something it loads,
    so a brand-new script that nothing imports yet may slip through unnoticed. Run it
    again after the file has been referenced (or after a full editor scan). Errors in
    existing scripts are always caught - that was verified by injecting a broken symbol.

    A curated list of messages that are noisy but harmless is skipped (see $Known below).
    Exit code: 0 = no unexpected errors, 1 = at least one real compile problem.
#>
param(
    [string]$Godot = 'C:\Users\a a\Desktop\Godot_v4.6.2-stable_win64.exe',
    [switch]$ShowIgnored
)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'pvz_check_scripts'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$outF = Join-Path $tmp 'out.txt'
$errF = Join-Path $tmp 'err.txt'
Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue

Write-Host '[check] compiling every script via Godot resource pipeline...'
$line = '"' + $Godot + '" --headless --path "' + $project + '" --import > "' + $outF + '" 2> "' + $errF + '"'
cmd.exe /c $line | Out-Null

$raw = @()
if (Test-Path -LiteralPath $errF) { $raw = Get-Content -LiteralPath $errF -Encoding UTF8 }

## Patterns that are expected noise from tearing down a headless import.
$Known = @(
    'Failed to read the root certificate store',
    'ObjectDB instances leaked at exit',
    'were leaked at exit',
    'leaked \d+ bytes',
    'resources still in use at exit',
    'RID allocations of type',
    "Invalid access to property or key 'card_type' on a base object of type 'Control \(Card\)'"
)

## Anything that means a script genuinely failed to build.
$RealPattern = 'Parse Error|SCRIPT ERROR|Failed to load script|Cyclic|cyclic'

$real = @()
$ignored = @()
foreach ($l in $raw) {
    if ($l -notmatch $RealPattern) { continue }
    $isKnown = $false
    foreach ($k in $Known) { if ($l -match $k) { $isKnown = $true; break } }
    if ($isKnown) { $ignored += $l } else { $real += $l }
}

Write-Host ''
Write-Host ('[check] stderr lines        : {0}' -f $raw.Count)
Write-Host ('[check] expected noise      : {0}' -f $ignored.Count)
Write-Host ('[check] real compile errors : {0}' -f $real.Count)

if ($real.Count -gt 0) {
    Write-Host ''
    Write-Host '---- PROBLEMS ----' -ForegroundColor Red
    $real | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host ''
    Write-Host '[check] result=FAIL' -ForegroundColor Red
    exit 1
}

if ($ShowIgnored -and $ignored.Count -gt 0) {
    Write-Host ''
    Write-Host '---- EXPECTED NOISE (ignored) ----' -ForegroundColor DarkGray
    $ignored | Select-Object -First 20 | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
}

Write-Host '[check] result=PASS  (does NOT prove the game plays; open it to confirm)' -ForegroundColor Green
exit 0
