# gen_worklog_index.ps1
# Regenerate docs/工作记录/README.md index section (between markers) from filenames.
# No Chinese literals on purpose: zh-CN PowerShell reads .ps1 as GBK by default, so
# non-ASCII in this file would mojibake. The Chinese dir name is matched via a
# Unicode codepoint ([char]0x5F55 == U+5F55 'u5f55'). Explanatory Chinese lives in the
# static README (outside the markers).
#
# Usage (run at repo root):
#   powershell -ExecutionPolicy Bypass -File tools/gen_worklog_index.ps1

param(
    [string]$WorkLogDir = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not $WorkLogDir) {
    # Find docs/<dir ending with U+5F55 '/u5f55'>/README.md (i.e. docs/工作记录)
    $candidate = Get-ChildItem -Path (Join-Path $RepoRoot "docs") -Recurse -Filter README.md |
        Where-Object { $_.Directory.Name.EndsWith([string][char]0x5F55) } |
        Select-Object -First 1
    if (-not $candidate) {
        Write-Error "Cannot locate docs/工作记录/README.md"
        exit 1
    }
    $WorkLogDir = $candidate.Directory.FullName
}

$ReadmePath = Join-Path $WorkLogDir "README.md"

if (-not (Test-Path $ReadmePath)) {
    Write-Error "Cannot find $ReadmePath"
    exit 1
}

$StartDate = "<!-- WORKLOG-INDEX-START -->"
$EndDate   = "<!-- WORKLOG-INDEX-END -->"

$files = Get-ChildItem -Path $WorkLogDir -Recurse -Filter *.md |
    Where-Object { $_.Name -ne "README.md" }

$entries = @()
foreach ($f in $files) {
    if ($f.Name -match '^(\d{4}-\d{2}-\d{2})_(.+)\.md$') {
        $date = $Matches[1]
        $title = $Matches[2]
    } else {
        $date = $f.LastWriteTime.ToString("yyyy-MM-dd")
        $title = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    }
    $rel = ($f.FullName.Substring($WorkLogDir.Length + 1)) -replace '\\', '/'
    $entries += [PSCustomObject]@{ Date = $date; Title = $title; Rel = $rel }
}

$grouped = $entries | Sort-Object @{Expression = 'Date'; Descending = $true}, @{Expression = 'Rel'; Descending = $false} |
    Group-Object Date

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("## 2. Index (by date, auto-generated)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Total $($entries.Count) records.")
[void]$sb.AppendLine("")

foreach ($g in $grouped) {
    [void]$sb.AppendLine("### $($g.Name)")
    [void]$sb.AppendLine("")
    foreach ($e in $g.Group) {
        [void]$sb.AppendLine("- [$($e.Title)]($($e.Rel))")
    }
    [void]$sb.AppendLine("")
}

$generated = $sb.ToString().TrimEnd() + "`n"

$content = Get-Content -Path $ReadmePath -Raw -Encoding UTF8
if (-not $content.Contains($StartDate) -or -not $content.Contains($EndDate)) {
    Write-Error "README.md missing $StartDate / $EndDate markers."
    exit 1
}
$idxStart = $content.IndexOf($StartDate)
$idxEnd = $content.IndexOf($EndDate) + $EndDate.Length
$head = $content.Substring(0, $idxStart)
$tail = $content.Substring($idxEnd)

if (-not $head.EndsWith("`n")) { $head += "`n" }
if (-not $tail.StartsWith("`n")) { $tail = "`n" + $tail }

$newContent = $head + $StartDate + "`n" + $generated + $EndDate + $tail

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($ReadmePath, $newContent, $utf8NoBom)

Write-Host "Regenerated index: $($entries.Count) records -> $ReadmePath"
