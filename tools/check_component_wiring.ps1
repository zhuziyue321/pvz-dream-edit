<#
.SYNOPSIS
    check_component_wiring.ps1 —— 暴露「组件内硬编码宿主相对路径」违规（docs/TODO清单.md H-16）

.DESCRIPTION
    硬约束 §1-2 要求组件只经 `owner` / 信号 / 场景配置通信；U-14 已记「组件里拼 `$"../X"` /
    `get_node_or_null("../X")`」这类写法，且 `host_node_of()` 入口全仓 0 实际使用。
    门禁 `check_scripts.ps1` 与 `check_content_wiring.ps1` 都不检查这类「组件内硬编码宿主相对路径」，
    于是规范在代码里被绕过却无人知晓。

    本脚本把这条纪律机械化：遍历 `src/` 下所有 `.gd`，凡**路径含 `component`** 的视为组件文件，
    逐行检查是否命中下列违规模式（命中且不在 `host_node_of` 白名单内即记录）：
      - get_node("../...
      - get_node_or_null("../...
      - get_node_and_resource("../...
      - $"../...
      - owner.get_node(...   （U-15：组件间硬编码兄弟组件 / 宿主子节点名）

    验证方式（写检查必须自证拦得住，见 H-09 的教训）：
      故意在组件里插一行 `get_node_or_null("../Foo")` 重跑，必出现一条 VIOLATION。

    路线（见 H-16 方向）：当前为「先把现有违规列出来」阶段，默认报告模式 exit 0；
    等违规逐条改走 `host_node_of()` 后，再传 `-Strict` 接入编译门禁，缺失即 exit 1。

.PARAMETER RepoRoot
    仓库根目录，默认当前目录。

.PARAMETER Strict
    若有违规则 exit 1（用于将来接入门禁）；默认报告模式 exit 0。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/check_component_wiring.ps1
    powershell -ExecutionPolicy Bypass -File tools/check_component_wiring.ps1 -Strict
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = ".",
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path $RepoRoot
$violations = 0

## 组件文件 = 路径含 "component"（不区分大小写）
$files = Get-ChildItem -Path (Join-Path $RepoRoot 'src') -Recurse -Filter *.gd
foreach ($f in $files) {
    if ($f.FullName -notmatch 'component') { continue }
    $rel = $f.FullName.Substring($RepoRoot.Path.Length + 1)
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        ## 白名单：已走 host_node_of 入口的跳过
        if ($line -match 'host_node_of') { continue }
        $isViolation = $false
        if ($line -match '(get_node(_or_null|_and_resource)?)\s*\(\s*"\.{2}/') { $isViolation = $true }
        elseif ($line -match '\$"\.{2}/') { $isViolation = $true }
        elseif ($line -match 'owner\.get_node') { $isViolation = $true }
        if ($isViolation) {
            $violations++
            Write-Host ('[component-wiring] VIOLATION {0}:{1}: {2}' -f $rel, ($i + 1), $line.Trim())
        }
    }
}

Write-Host ''
if ($violations -gt 0) {
    Write-Host ('[component-wiring] found {0} violation(s). These are known component-hardcoded-host-path issues (see U-14); migrate to host_node_of().' -f $violations) -ForegroundColor Yellow
    if ($Strict) {
        Write-Host '[component-wiring] result=FAIL (Strict)' -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host '[component-wiring] result=PASS (no component hardcoded host paths)' -ForegroundColor Green
}
exit 0
