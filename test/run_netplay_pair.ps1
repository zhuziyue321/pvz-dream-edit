#requires -Version 5.1
<#
    Two-process netplay test: one headless Godot as HOST, one as CLIENT, over localhost.

    WHY THIS EXISTS
    ---------------
    Single-process probes cannot cover the "host pushes event -> sends command ->
    client rebuilds" half of the netplay stack: Godot's rpc() does NOT invoke
    locally when there is no remote peer. Every netplay mechanism added so far
    (wave sync, sun sync, drop sync, snapshot, render-only zombies) therefore had
    single-process evidence only. This harness runs them on two real processes.

    HOW THE TWO SIDES ARE COMPARED
    ------------------------------
    The client sends its view of the field back to the host every 2 seconds over
    the REAL command channel; the host samples its own view the moment it receives
    one and logs a matched pair. So no post-hoc timestamp alignment of two logs is
    needed - the pairing arrives over the network itself.

    Usage:
        powershell -ExecutionPolicy Bypass -File test/run_netplay_pair.ps1
        powershell -ExecutionPolicy Bypass -File test/run_netplay_pair.ps1 -KeepLogs

    This file is ASCII-only on purpose (PowerShell 5.1 reads BOM-less scripts as ANSI).
#>
param(
    ## Unified with run_autopilot.ps1 / check_scripts.ps1 on 2026-10-25: the old
    ## 'Godot_v4.6.2-stable_win64.exe' does not exist on this machine (the real
    ## binary is 'godot.exe'), so Start-Process failed before any instance ran.
    [string]$Godot = 'C:\Users\a a\Desktop\godot.exe',
    [string]$Project = '',
    [int]$HostMaxSeconds = 150,
    [int]$ClientMaxSeconds = 140,
    [int]$TimeoutSeconds = 220,
    [switch]$KeepLogs
)

$ErrorActionPreference = 'Stop'
## Fail loudly when the engine binary is missing (same guard as run_autopilot.ps1):
## otherwise Start-Process throws and the run looks like a netplay failure.
if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Host ('[pair] Godot executable not found: {0}' -f $Godot) -ForegroundColor Red
    Write-Host '[pair] pass -Godot "<real path>" or fix the default in this script' -ForegroundColor Red
    exit 2
}
if (-not $Project) {
    if ($PSScriptRoot) { $Project = (Split-Path $PSScriptRoot -Parent) } else { $Project = (Get-Location).Path }
}

## Rendezvous: both Godot instances meet here. Kept OUTSIDE user:// because each
## instance gets its own APPDATA (two instances must not share one save file).
$tmpRoot = $env:TEMP
try { $tmpRoot = (Get-Item -LiteralPath $env:TEMP).FullName } catch { }
$rdy   = Join-Path $tmpRoot 'pvz_netplay_pair'
$work  = Join-Path $tmpRoot 'pvz_netplay_pair_run'
New-Item -ItemType Directory -Force -Path $rdy | Out-Null
New-Item -ItemType Directory -Force -Path $work | Out-Null
Remove-Item -LiteralPath (Join-Path $rdy 'host_ready') -Force -ErrorAction SilentlyContinue

$hostDir   = Join-Path $work 'host_ud'
$clientDir = Join-Path $work 'client_ud'
foreach ($d in @($hostDir, $clientDir)) {
    if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}
$hostOut   = Join-Path $work 'host_out.txt'
$hostErr   = Join-Path $work 'host_err.txt'
$clientOut = Join-Path $work 'client_out.txt'
$clientErr = Join-Path $work 'client_err.txt'
Remove-Item -LiteralPath $hostOut, $hostErr, $clientOut, $clientErr -Force -ErrorAction SilentlyContinue

Write-Host "[pair] rendezvous : $rdy"
Write-Host "[pair] host userdir: $hostDir"
Write-Host ""

function Start-Side {
    param([string]$UserDir, [string]$Scenario, [int]$MaxSeconds, [string]$OutFile, [string]$ErrFile)
    $old = $env:APPDATA
    $env:APPDATA = $UserDir
    try {
        ## ⚠️ 必须拼成**整条**命令行并自己加引号：把 `--path` 与路径当成两个数组元素传，
        ## PowerShell 不会替路径补引号，路径里有空格（本项目就是）会被拆成两半，
        ## Godot 报 "Invalid project path specified: C:\Users\a"。
        $argLine = '--headless --path "' + $Project + '" -- ' +
                   "--scenario=res://test/scenarios/$Scenario.gd" +
                   " --autopilot-max-seconds=$MaxSeconds"
        $p = Start-Process -FilePath $Godot -PassThru -WindowStyle Hidden `
             -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile `
             -ArgumentList $argLine
        return $p
    } finally {
        $env:APPDATA = $old
    }
}

## 1) Host first: it creates the room and writes the host_ready flag.
$ph = Start-Side -UserDir $hostDir -Scenario 'probe_netplay_pair_host' -MaxSeconds $HostMaxSeconds -OutFile $hostOut -ErrFile $hostErr
Write-Host "[pair] host pid=$($ph.Id)"

## 2) Wait for the rendezvous flag, then bring the client up.
$waited = 0
while (-not (Test-Path -LiteralPath (Join-Path $rdy 'host_ready')) -and $waited -lt 90) {
    Start-Sleep -Seconds 1
    $waited++
}
if (-not (Test-Path -LiteralPath (Join-Path $rdy 'host_ready'))) {
    Write-Host "[pair] FAIL: host never came up (no host_ready after ${waited}s)" -ForegroundColor Red
    if (-not $ph.HasExited) { $ph.Kill() }
    exit 1
}
Write-Host "[pair] host listening after ${waited}s"

$pc = Start-Side -UserDir $clientDir -Scenario 'probe_netplay_pair_client' -MaxSeconds $ClientMaxSeconds -OutFile $clientOut -ErrFile $clientErr
Write-Host "[pair] client pid=$($pc.Id)"

## 3) Wait for both to report (or die).
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
function Test-Report([string]$File, [string]$Marker) {
    if (-not (Test-Path -LiteralPath $File)) { return $false }
    return [bool](Select-String -LiteralPath $File -Pattern $Marker -Quiet -ErrorAction SilentlyContinue)
}
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    $hDone = Test-Report $hostOut '\[PAIR\] result='
    $cDone = Test-Report $clientOut '\[PAIR-CLIENT\] result='
    if ($hDone -and $cDone) { break }
    if ($ph.HasExited -and $pc.HasExited) { break }
    Start-Sleep -Seconds 2
}

## 4) Kill survivors so no wild headless processes are left behind.
foreach ($p in @($ph, $pc)) {
    if ($p -and -not $p.HasExited) {
        Write-Host "[pair] killing leftover pid=$($p.Id)"
        $p.Kill()
        $p.WaitForExit(5000) | Out-Null
    }
}

Write-Host ""
Write-Host "---------------- HOST (matched pairs) ----------------"
if (Test-Path -LiteralPath $hostOut) {
    Get-Content -LiteralPath $hostOut -Encoding UTF8 |
        Select-String -Pattern 'PAIR|\[PAIR\]|!!|error|SCRIPT ERROR' | ForEach-Object { Write-Host $_.Line }
}
Write-Host ""
Write-Host "---------------- CLIENT ----------------"
if (Test-Path -LiteralPath $clientOut) {
    Get-Content -LiteralPath $clientOut -Encoding UTF8 |
        Select-String -Pattern 'PAIR|\[PAIR-CLIENT\]|!!|error|SCRIPT ERROR' | ForEach-Object { Write-Host $_.Line }
}

$hostLine   = ''
$clientLine = ''
if (Test-Path -LiteralPath $hostOut) {
    $m = Select-String -LiteralPath $hostOut -Pattern '\[PAIR\] result=' | Select-Object -Last 1
    if ($m) { $hostLine = $m.Line }
}
if (Test-Path -LiteralPath $clientOut) {
    $m = Select-String -LiteralPath $clientOut -Pattern '\[PAIR-CLIENT\] result=' | Select-Object -Last 1
    if ($m) { $clientLine = $m.Line }
}
Write-Host ""
Write-Host "HOST   : $hostLine"
Write-Host "CLIENT : $clientLine"

$ok = ($hostLine -match 'result=PASS') -and ($clientLine -match 'result=PASS')
if ($ok) { Write-Host "[pair] RESULT=PASS" -ForegroundColor Green } else { Write-Host "[pair] RESULT=FAIL" -ForegroundColor Red }
Write-Host "[pair] logs: $work"

## ⚠️ 日志一律保留：PASS 也要留 —— 这一份"两端每一拍的实际数字"本身就是证据，
## 删掉之后下一次想看细节只能再花四分钟重跑一遍。
if ($ok) { exit 0 } else { exit 1 }
