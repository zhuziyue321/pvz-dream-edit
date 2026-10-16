#requires -Version 5.1
<#
    Check "facts the docs claim" against the working tree.

    Why this exists (2026-10-16, TODO 清单 H-09):
        One manual "health check" of this repo found four doc drifts in a single
        pass - script counts, doc counts, the autoload count, and a file the docs
        recorded as "already deleted" that was still on disk. Counting by hand
        does not scale and does not repeat; this script does both.

    What it checks:
        A. leftover files in the repo root (the H-06 patterns) - FAIL only if such
           a file is actually TRACKED by git (ignored ones are fine on disk);
        B. the autoload count in project.godot vs what AGENTS.md / 架构总览.md claim;
        C. scale numbers (script / doc / scenario counts) vs what the docs claim;
        D. .md links between the top-level docs (broken links are a doc drift too);
        E. the "assets/ is not in version control" claim vs `git ls-files assets`
           (2026-10-16, TODO H-12: three top-level docs claimed assets/ was not in
           git while thousands of asset files were tracked, and this script - which
           was written to catch exactly this class of drift - did not cover it).

    Design rule: a pattern that no longer matches the doc is reported as SKIP,
    NOT as a failure - doc wording changes are allowed (see E-08). Only a
    matching claim that disagrees with reality is a FAIL.

    Usage:
        powershell -ExecutionPolicy Bypass -File tools/check_doc_facts.ps1
        powershell -ExecutionPolicy Bypass -File tools/check_doc_facts.ps1 -ShowOk

    Exit code: 0 = no problem, 1 = at least one mismatch.
    This file is ASCII-only on purpose (PowerShell 5.1 reads BOM-less scripts as ANSI).
#>
param(
    [string]$Project = '',
    ## Print the checks that passed as well (default: only problems + summary).
    [switch]$ShowOk
)

$ErrorActionPreference = 'Stop'
if (-not $Project) {
    if ($PSScriptRoot) { $Project = Split-Path $PSScriptRoot -Parent } else { $Project = (Get-Location).Path }
}
Push-Location $Project

$script:checks = 0
$script:problems = 0
$script:skips = 0

function Report([string]$name, $claimed, $actual) {
    $script:checks++
    if ("$claimed" -eq "$actual") {
        if ($ShowOk) { Write-Host ("[doc-facts] OK   {0,-38} claimed={1} actual={2}" -f $name, $claimed, $actual) }
    } else {
        $script:problems++
        Write-Host ("[doc-facts] FAIL {0,-38} claimed={1} actual={2}" -f $name, $claimed, $actual) -ForegroundColor Red
    }
}

function Skip([string]$name, [string]$why) {
    $script:skips++
    if ($ShowOk) { Write-Host ("[doc-facts] SKIP {0,-38} {1}" -f $name, $why) -ForegroundColor DarkGray }
}

function CountFiles([string]$dir, [string]$filter) {
    ## Count TRACKED files only: a doc that is not committed yet is not part of
    ## the repo's size yet, and counting the working tree would make this script
    ## flip back and forth depending on what someone else has on disk.
    $ext = $filter -replace '^\*', ''
    return @(git -c core.quotepath=false ls-files -- "$dir" 2>$null | Where-Object { $_ -like "*$ext" }).Count
}

## Returns capture group $Group of the first $pattern match in $file, or $null.
function DocNumber([string]$file, [string]$pattern, [int]$Group = 1) {
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) { return $null }
    return $m.Groups[$Group].Value
}

Write-Host "[doc-facts] project: $Project"

# --- A. leftover files in the repo root ---------------------------------------
$leftoverPatterns = @("'", 'error_log.txt', 'package.json', 'package-lock.json')
foreach ($f in $leftoverPatterns) {
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $script:checks++
    $tracked = @(git ls-files --error-unmatch -- "$f" 2>$null).Count
    if ($tracked -gt 0) {
        $script:problems++
        Write-Host ("[doc-facts] FAIL leftover file is TRACKED: {0}" -f $f) -ForegroundColor Red
    } elseif ($ShowOk) {
        Write-Host ("[doc-facts] OK   leftover on disk but ignored: {0}" -f $f)
    }
}

# --- A2. assets-in-version-control claim --------------------------------------
## Deliberately limited to the top-level docs: the work records under docs/ are
## records of what was true at the time, not claims about the tree today.
## NOTE on encoding: this script is saved as UTF-8 *with BOM*, so PowerShell 5.1
## reads it correctly even though it already contains Chinese file names (e.g.
## 架构总览.md) elsewhere. The \uXXXX escapes below are therefore optional - kept
## only so the regex reads cleanly next to its English `what` label. (Correcting
## my earlier wrong note that this file had to be ASCII-only.)
$assetsActual = @(git -c core.quotepath=false ls-files -- assets 2>$null).Count
$staleClaims = @(
    @{ re = '\u4e0d\u5165\s*git';       what = 'not in git' },          # 不入 git
    @{ re = '\u81ea\u884c\u51c6\u5907'; what = 'prepare it yourself' }  # 自行准备
)
foreach ($doc in @('AGENTS.md', 'README.md', '架构总览.md')) {
    if (-not (Test-Path -LiteralPath $doc)) { continue }
    $script:checks++
    $text = Get-Content -LiteralPath $doc -Raw -Encoding UTF8
    $bad = @($staleClaims | Where-Object { $text -match $_.re })
    if ($bad.Count -gt 0) {
        $script:problems++
        Write-Host ('[doc-facts] FAIL {0} still claims assets/ is {1}' -f $doc, (($bad | ForEach-Object { $_.what }) -join ', ')) -ForegroundColor Red
    } elseif ($ShowOk) {
        Write-Host ('[doc-facts] OK   assets claim in {0}' -f $doc)
    }
}
$v = DocNumber 'AGENTS.md' '`git ls-files assets`\s*=\s*(\d+)'
if ($null -eq $v) { Skip 'AGENTS.md assets count' 'pattern not found' } else { Report 'AGENTS.md assets count' $v $assetsActual }

# --- B. autoload count --------------------------------------------------------
$autoloadActual = @(Get-Content -LiteralPath 'project.godot' -Encoding UTF8 |
    Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*="\*res://' }).Count

$v = DocNumber 'AGENTS.md' '(\d+) 个 autoload 单例'
if ($null -eq $v) { Skip 'AGENTS.md autoload count' 'pattern not found' } else { Report 'AGENTS.md autoload count' $v $autoloadActual }

$v = DocNumber '架构总览.md' 'autoload 单例（(\d+) 个'
if ($null -eq $v) { Skip '架构总览 autoload count' 'pattern not found' } else { Report '架构总览 autoload count' $v $autoloadActual }

# --- C. scale numbers ---------------------------------------------------------
$srcGd = CountFiles 'src' '*.gd'
$srcTscn = CountFiles 'src' '*.tscn'
$dataTres = CountFiles 'data' '*.tres'
$docsMd = CountFiles 'docs' '*.md'
$animAll = (CountFiles 'animation' '*.tres') + (CountFiles 'animation' '*.res')
$testGd = CountFiles 'test' '*.gd'
$scenarios = CountFiles 'test/scenarios' '*.gd'
$refMd = CountFiles 'docs/参考存档' '*.md'
$workMd = CountFiles 'docs/工作记录' '*.md'

## AGENTS.md  §1 规模行
$v = DocNumber 'AGENTS.md' '`src/` (\d+) 个 `\.gd`'
if ($null -eq $v) { Skip 'AGENTS.md src .gd' 'pattern not found' } else { Report 'AGENTS.md src .gd' $v $srcGd }
$v = DocNumber 'AGENTS.md' '`src/` \d+ 个 `\.gd` \+ (\d+) 个 `\.tscn`'
if ($null -eq $v) { Skip 'AGENTS.md src .tscn' 'pattern not found' } else { Report 'AGENTS.md src .tscn' $v $srcTscn }
$v = DocNumber 'AGENTS.md' '`data/` (\d+) 个 `\.tres`'
if ($null -eq $v) { Skip 'AGENTS.md data .tres' 'pattern not found' } else { Report 'AGENTS.md data .tres' $v $dataTres }
$v = DocNumber 'AGENTS.md' '`animation/` (\d+) 段动画'
if ($null -eq $v) { Skip 'AGENTS.md animation' 'pattern not found' } else { Report 'AGENTS.md animation' $v $animAll }
$v = DocNumber 'AGENTS.md' '`docs/` (\d+) 份 `\.md`'
if ($null -eq $v) { Skip 'AGENTS.md docs .md' 'pattern not found' } else { Report 'AGENTS.md docs .md' $v $docsMd }

## 架构总览  §1 口径表
$v = DocNumber '架构总览.md' '`src/`：\*\*(\d+) 个 `\.gd`\*\*'
if ($null -eq $v) { Skip '架构总览 src .gd' 'pattern not found' } else { Report '架构总览 src .gd' $v $srcGd }
$v = DocNumber '架构总览.md' '`src/`：\*\*\d+ 个 `\.gd`\*\* \+ \*\*(\d+) 个 `\.tscn`\*\*'
if ($null -eq $v) { Skip '架构总览 src .tscn' 'pattern not found' } else { Report '架构总览 src .tscn' $v $srcTscn }
$v = DocNumber '架构总览.md' '`data/`：\*\*(\d+) 个 `\.tres`\*\*'
if ($null -eq $v) { Skip '架构总览 data .tres' 'pattern not found' } else { Report '架构总览 data .tres' $v $dataTres }
$v = DocNumber '架构总览.md' '`docs/`：(\d+) 个 `\.md`'
if ($null -eq $v) { Skip '架构总览 docs .md' 'pattern not found' } else { Report '架构总览 docs .md' $v $docsMd }
$v = DocNumber '架构总览.md' '`test/`：\*\*(\d+) 个 `\.gd`\*\*'
if ($null -eq $v) { Skip '架构总览 test .gd' 'pattern not found' } else { Report '架构总览 test .gd' $v $testGd }
$v = DocNumber '架构总览.md' '`scenarios/` (\d+) 个'
if ($null -eq $v) { Skip '架构总览 scenarios' 'pattern not found' } else { Report '架构总览 scenarios' $v $scenarios }

## 架构总览  §15 统计表（第一列数字）
$v = DocNumber '架构总览.md' '\| `src/` \| (\d+) \|'
if ($null -eq $v) { Skip '架构总览 §15 src .gd' 'pattern not found' } else { Report '架构总览 §15 src .gd' $v $srcGd }
$v = DocNumber '架构总览.md' '\| `src/` \| \d+ \| (\d+) \|'
if ($null -eq $v) { Skip '架构总览 §15 src .tscn' 'pattern not found' } else { Report '架构总览 §15 src .tscn' $v $srcTscn }
$v = DocNumber '架构总览.md' '\| `test/` \| (\d+) \|'
if ($null -eq $v) { Skip '架构总览 §15 test .gd' 'pattern not found' } else { Report '架构总览 §15 test .gd' $v $testGd }

## docs/README.md 的参考存档份数
$v = DocNumber 'docs/README.md' '\| (\d+) 份\*\*项目相关\*\*参考文档'
if ($null -eq $v) { Skip 'docs/README 参考存档份数' 'pattern not found' } else { Report 'docs/README 参考存档份数' $v $refMd }

## 架构总览 §13 文档体系（标题 + 表）
$v = DocNumber '架构总览.md' '## 13\. 文档体系（`docs/`，(\d+) 个 `\.md`）'
if ($null -eq $v) { Skip '架构总览 §13 标题 docs .md' 'pattern not found' } else { Report '架构总览 §13 标题 docs .md' $v $docsMd }

$v = DocNumber '架构总览.md' '`docs/工作记录/` \| (\d+) \|'
if ($null -eq $v) { Skip '架构总览 §13 工作记录份数' 'pattern not found' } else { Report '架构总览 §13 工作记录份数' $v $workMd }

# --- D. links between the top-level docs --------------------------------------
$linkDocs = @('AGENTS.md', 'README.md', '架构总览.md', 'docs/README.md', 'docs/项目规范.md', 'docs/验证流程.md')
$brokenTotal = 0
foreach ($doc in $linkDocs) {
    if (-not (Test-Path -LiteralPath $doc)) { continue }
    $text = Get-Content -LiteralPath $doc -Raw -Encoding UTF8
    $base = Split-Path -Path $doc -Parent
    if (-not $base) { $base = '.' }
    foreach ($m in [regex]::Matches($text, '\]\((?!https?:)([^)#]+\.md)(?:#[^)]*)?\)')) {
        $rel = $m.Groups[1].Value
        $target = Join-Path $base $rel
        if (-not (Test-Path -LiteralPath $target)) {
            $brokenTotal++
            Write-Host ("[doc-facts] FAIL broken link in {0}: {1}" -f $doc, $rel) -ForegroundColor Red
        }
    }
}
if ($brokenTotal -eq 0) {
    $script:checks++
    if ($ShowOk) { Write-Host ("[doc-facts] OK   doc links ({0} files scanned)" -f $linkDocs.Count) }
} else {
    $script:problems++
}

# --- summary ------------------------------------------------------------------
Write-Host ""
Write-Host ("[doc-facts] checks={0}  problems={1}  skipped={2}" -f $script:checks, $script:problems, $script:skips)
if ($script:problems -eq 0) {
    Write-Host ('[doc-facts] result=PASS')
    Pop-Location
    exit 0
}
Write-Host ('[doc-facts] result=FAIL')
Write-Host '[doc-facts] fix the docs (or the tree), then re-run. See docs/参考存档/规范细则存档.md E-08.'
Pop-Location
exit 1
