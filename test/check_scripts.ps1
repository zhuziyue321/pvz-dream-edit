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

    KNOWN LIMITATION 1: Godot only compiles scripts reachable from something it loads,
    so a brand-new script that nothing imports yet may slip through unnoticed. Run it
    again after the file has been referenced (or after a full editor scan).

    KNOWN LIMITATION 2 (实测 2026-10-07，**勿把 PASS 当成「没有问题」**):
    `--import` 并不对所有脚本做**方法调用解析**，因此「在某个基类上不存在的方法」抓不到。
    实证：`src/managers/portal_manager.gd` 是 `extends MainGameSubManager`（再往上是 Node），
    却在 self 上调用 `get_world_2d()`（那是 CanvasItem / Viewport 的方法）。
    Godot 编辑器明确报错 `Function "get_world_2d()" not found in base self`，
    而本门禁当时输出 **PASS（real compile errors = 0）**，stderr 里连一行相关输出都没有。
    该文件挂在 `main_game_base.tscn` 上，说明 --import 并未完整分析到它。

    所以本门禁能抓：语法错误、类型推断问题、循环依赖、缺失的类与全局符号。
    抓不到：方法在基类上不存在、参数个数/类型不匹配这类**语义**错误
    （EventBus 的 payload 同理，靠运行期校验兜，见 EventBus._validate_payload）。

    规避：改动涉及「在非 CanvasItem 的 Node 上调 2D 方法」时，务必在 Godot 编辑器里
    看一眼（编辑器实时下划线会标出来），或真正打开游戏跑到那段逻辑。

    KNOWN LIMITATION 3 (实测 2026-10-12)：**本门禁抓不到 GDScript 分析类告警**
    （UNUSED_SIGNAL / UNUSED_PARAMETER / SHADOWED_VARIABLE / INTEGER_DIVISION /
    INCOMPATIBLE_TERNARY 等）。实测结论：
      · `--headless --import`、`--headless --editor --quit-after`、跑 `probe_*.gd`
        三种方式都**不输出**这些告警 —— 往 script 里临时插一个未使用参数（对照组）
        同样一条都没报出来，所以「跑完安静」不等于「没有告警」；
      · 它们只在 **Godot 编辑器界面 / 运行游戏的 `GDScript::reload`** 里出现，
        就是带着 `W 0:00:02:621  <GDScript 警告> UNUSED_SIGNAL` 那种输出。
    所以要确认某条告警消没消失，只能**打开编辑器或真跑一次游戏**看那些 `GDScript::reload`
    行；本门禁只能证明「脚本能编译」（它确实也要跑，因为它们是编译级错误的上游）。

    定位同类告警的土办法（2026-10-14 实测：连 `--editor --quit-after` 的 stdout/stderr 都
    **一条告警都没有**，只能人肉在编辑器里翻）：
    写个脚本按 func 块切分 .gd，统计每个局部变量的出现次数 —— **纯赋值（`x = 1` /
    `x += 1`）不算「使用」**（Godot 的 UNUSED_VARIABLE 就是这个口径，只写不读照样报），
    下划线前缀本来就豁免。扫出的候选人工复核后按「删掉 / 加 `_` 前缀」处理，
    比在编辑器里一条条翻快得多。

    A curated list of messages that are noisy but harmless is skipped (see $Known below).
    Exit code: 0 = no unexpected errors, 1 = at least one real compile problem.
#>
param(
    ## 2026-10-13：默认路径指向的 Godot_v4.6.2-stable_win64.exe 在本机已不存在（实际叫 godot.exe），
    ## 结果 Godot 根本没启动、stderr 只有两条 cmd 报错，门禁却照样 PASS（假绿）。已改成真实路径。
    [string]$Godot = 'C:\Users\a a\Desktop\godot.exe',
    [switch]$ShowIgnored
)

$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) 'pvz_check_scripts'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$outF = Join-Path $tmp 'out.txt'
$errF = Join-Path $tmp 'err.txt'
Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue

## Godot 可执行文件不存在时**直接判 FAIL**：否则 cmd 只是打两行「找不到命令」，
## 脚本照样走到最后输出 PASS（2026-10-13 实测过一次假绿）。
if (-not (Test-Path -LiteralPath $Godot)) {
    Write-Host ('[check] Godot executable not found: {0}' -f $Godot) -ForegroundColor Red
    Write-Host '[check] 传 -Godot "<真实路径>" 或改本脚本的默认值' -ForegroundColor Red
    Write-Host '[check] result=FAIL' -ForegroundColor Red
    exit 1
}

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

## ── 第二道：探针脚本 `test/scenarios/*.gd` ────────────────────────────────
## ⚠️ 上面那道 `--import` **覆盖不到**探针脚本：它们只在运行期按路径 `load()`，
## 没有任何资源 / 脚本引用它们，于是永远进不了资源管线（见 KNOWN LIMITATION 1）。
## 实测连着两次「`var x :=` 推断不出类型」的解析错误都被放行成 PASS，
## 每次都要等一整轮双进程实测（约 4 分钟）才由输出里的 SCRIPT ERROR 暴露出来。
## 这里用 `tool_compile_scenarios.gd` 把它们逐个 load 一遍，补上这个洞。
Write-Host '[check] compiling test/scenarios/*.gd (NOT covered by --import)...'
$sDir = Join-Path ([System.IO.Path]::GetTempPath()) 'pvz_check_scenarios'
New-Item -ItemType Directory -Force -Path $sDir | Out-Null
$sOut = Join-Path $sDir 'out.txt'
$sErr = Join-Path $sDir 'err.txt'
Remove-Item -LiteralPath $sOut, $sErr -Force -ErrorAction SilentlyContinue
$oldAppData = $env:APPDATA
$env:APPDATA = $sDir
try {
    $line2 = '"' + $Godot + '" --headless --path "' + $project + '" -- ' +
             '--scenario=res://test/scenarios/tool_compile_scenarios.gd ' +
             '--autopilot-max-seconds=120 > "' + $sOut + '" 2> "' + $sErr + '"'
    cmd.exe /c $line2 | Out-Null
} finally {
    $env:APPDATA = $oldAppData
}

$sRaw = @()
if (Test-Path -LiteralPath $sOut) { $sRaw = @(Get-Content -LiteralPath $sOut -Encoding UTF8) }
$sErrRaw = @()
if (Test-Path -LiteralPath $sErr) { $sErrRaw = @(Get-Content -LiteralPath $sErr -Encoding UTF8) }
$m2 = $sRaw | Select-String -Pattern '\[COMPILE\] scripts=' | Select-Object -Last 1
if ($m2) { $sLine = $m2.Line.Trim() } else { $sLine = '[COMPILE] scripts=? (autopilot did not finish)' }
Write-Host ('[check] scenarios            : {0}' -f $sLine)

## ⚠️ 判据跟 `--import` 那道**同一个**（ Parse Error / SCRIPT ERROR ... ），且要扫 **stdout + stderr**：
## Godot 有时把 SCRIPT ERROR 打到 stdout（`--import` 那道打进 stderr，别照抄只扫一边）。

$sBad = @()
$sBad += @($sRaw | Select-String -Pattern $RealPattern | ForEach-Object { $_.Line })
$sBad += @($sErrRaw | Select-String -Pattern $RealPattern | ForEach-Object { $_.Line })
$sBad = @($sBad | Where-Object {
    $l = $_
    -not ($Known | Where-Object { $l -match $_ })
})
if ($sBad.Count -gt 0) {
    Write-Host ''
    Write-Host '---- PROBLEMS IN test/scenarios ----' -ForegroundColor Red
    $sBad | Select-Object -First 20 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
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
