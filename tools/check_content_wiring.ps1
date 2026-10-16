<#
.SYNOPSIS
    check_content_wiring.ps1 —— 「新增一个角色要动哪几处」的可执行版本（docs/TODO清单.md H-14①）

.DESCRIPTION
    架构总览.md §14 列了一张人读的表：加一只植物要动 7 处、加一只僵尸 5 处、加一关 4 处。
    那是「纪律」却没有任何东西证明「新单位真的登记齐了」。本脚本把这张表机械化：
      遍历 PlantIds.ALL / ZombieIds.ALL，逐个校验
        (1) 注册表数值表（PLANT_INFO / ZOMBIE_INFO）里有条目；
        (2) 条目里的场景 preload("res://...tscn") 文件确实存在。
    缺一项即 exit 1 —— 与 H-10 的玩法链路探针同一条思路：「把文档里的纪律变成可执行的纪律」。

    验证方式（写检查必须自证拦得住，见 H-09 的教训）：
      故意把某个 preload 路径改坏（或把某条目从 ALL 里删掉而没从数值表删），重跑必 FAIL。

.PARAMETER RepoRoot
    仓库根目录，默认当前目录。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/check_content_wiring.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = "."
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path $RepoRoot
$problems = 0
$checks = 0

function ResolveRes($path) {
    # res://... -> 仓库内相对路径
    if ($path -notmatch '^res://') { return $null }
    return Join-Path $RepoRoot $path.Substring(6).TrimStart('/')
}

function CheckScene($kind, $idConst, $scenePath) {
    $script:checks++
    if ([string]::IsNullOrEmpty($scenePath)) {
        $script:problems++
        Write-Host ('[wiring] FAIL {0} {1}: no scene preload found in registry data' -f $kind, $idConst) -ForegroundColor Red
        return
    }
    $fp = ResolveRes $scenePath
    if ($null -eq $fp -or -not (Test-Path -LiteralPath $fp)) {
        $script:problems++
        Write-Host ('[wiring] FAIL {0} {1}: scene missing -> {2}' -f $kind, $idConst, $scenePath) -ForegroundColor Red
    }
}

function CheckEntry($kind, $idConst, $hasEntry) {
    $script:checks++
    if (-not $hasEntry) {
        $script:problems++
        Write-Host ('[wiring] FAIL {0} {1}: not registered in data table' -f $kind, $idConst) -ForegroundColor Red
    }
}

# --- 解析一个 id 常量表文件里的 ALL 数组（返回常量名列表）--------------------
function GetAllIds($filePath) {
    $txt = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
    $m = [regex]::Match($txt, 'const ALL:.*?= \[([\s\S]*?)\]')
    if (-not $m.Success) { throw "cannot find `const ALL` in $filePath" }
    return [regex]::Matches($m.Groups[1].Value, '[A-Z][A-Z0-9_]+') |
           ForEach-Object { $_.Value }
}

# --- 解析数值表：返回 @{ 常量名 = 场景路径或 $null } -------------------------
function GetInfoTable($filePath, $prefix, $sceneAttr) {
    $txt = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
    $out = @{}
    # 每个条目：前缀.常量名 : { ... }
    foreach ($entry in [regex]::Matches($txt, [regex]::Escape($prefix) + '\.(\w+)\s*:\s*\{([^}]*)\}')) {
        $name = $entry.Groups[1].Value
        $body = $entry.Groups[2].Value
        $sm = [regex]::Match($body, [regex]::Escape($sceneAttr) + '\s*:\s*preload\("([^"]+)"\)')
        $out[$name] = if ($sm.Success) { $sm.Groups[1].Value } else { $null }
    }
    return $out
}

# --- 植物 ------------------------------------------------------------------
$plantAll = GetAllIds (Join-Path $RepoRoot 'src/core/consts/plant_ids.gd')
$plantInfo = GetInfoTable (Join-Path $RepoRoot 'data/character/registry_data/plant_info_data.gd') 'PlantIds' 'PlantScenes'
## 已知例外：运行期由模组注入、故意不在数值表里的空槽位（见 PlantIds.WATER_BOWL 注释）
$plantExceptions = @('WATER_BOWL')
foreach ($id in $plantAll) {
    if ($id -in $plantExceptions) { continue }
    $has = $plantInfo.ContainsKey($id)
    CheckEntry 'plant' $id $has
    if ($has) { CheckScene 'plant' $id $plantInfo[$id] }
}

# --- 僵尸 ------------------------------------------------------------------
$zombieAll = GetAllIds (Join-Path $RepoRoot 'src/core/consts/zombie_ids.gd')
$zombieInfo = GetInfoTable (Join-Path $RepoRoot 'data/character/registry_data/zombie_info_data.gd') 'ZombieIds' 'ZombieScenes'
## 僵尸目前无已知例外（42 个 ALL id 全部在 ZOMBIE_INFO 中，见本轮实测）
foreach ($id in $zombieAll) {
    $has = $zombieInfo.ContainsKey($id)
    CheckEntry 'zombie' $id $has
    if ($has) { CheckScene 'zombie' $id $zombieInfo[$id] }
}

# --- 汇总 ------------------------------------------------------------------
Write-Host ''
if ($problems -gt 0) {
    Write-Host ('[wiring] result=FAIL  checks={0} problems={1}' -f $checks, $problems) -ForegroundColor Red
    exit 1
} else {
    Write-Host ('[wiring] result=PASS  checks={0} problems=0' -f $checks) -ForegroundColor Green
    exit 0
}
