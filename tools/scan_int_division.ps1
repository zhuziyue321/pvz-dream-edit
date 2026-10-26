#requires -Version 5.1
## 扫描 .gd 文件中可能的 INTEGER_DIVISION 候选（int / int）。
## 只做粗筛，结果需人工复核类型。
$ErrorActionPreference = 'Stop'
$root = 'c:\Users\a a\Desktop\Dream'
$dirs = @('src', 'test', 'mods_builtin', 'tools')
$files = foreach ($d in $dirs) {
    $p = Join-Path $root $d
    if (Test-Path $p) { Get-ChildItem $p -Recurse -Filter *.gd -File }
}
$hits = @()
foreach ($f in $files) {
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # 去掉字符串字面量，避免字符串里的 / 干扰
        $code = [regex]::Replace($line, '"[^"]*"', '""')
        # 去掉注释
        $code = [regex]::Replace($code, '#.*$', '')
        # 找所有除号（排除注释里已去掉的），取左右 token
        foreach ($m in [regex]::Matches($code, '([\w\)\]]+)\s*/\s*([A-Za-z0-9_\.]+)')) {
            $left = $m.Groups[1].Value.Trim()
            $right = $m.Groups[2].Value.Trim()
            # 除号两边都不是数字/标识符的（如行尾续行）跳过
            if ($left -eq '' -or $right -eq '') { continue }
            # 排除节点路径 $A/B 与场景内相对路径
            if ($left.StartsWith('$')) { continue }
            # 排除纯资源路径片段（左或右是引号内路径，已在字符串清理时处理）
            # 除数是浮点字面量 -> 无警告
            if ($right -match '\.\d') { continue }
            # 左侧以 . 结尾的成员访问链，取最后一段判断
            $lbase = $left
            if ($lbase.EndsWith(')') -or $lbase.EndsWith(']')) { $lcall = $lbase } else { $lcall = ($lbase -split '[\.\(]')[-1] }
            # 已知 float 语义的标识符（粗匹配）
            $floatHint = '(_?pos|position|duration|time|scale|alpha|speed|size\.x|size\.y|x$|y$|width|height|progress|ratio|factor|percent|value|amount|interval|gap|offset|vel|accel|weight|prob|chance|damage|hp|health|max_health|radius|dist|angle|deg|rad|coord|pixel|px|frame_time|delta)'
            $rightIsIntLiteral = ($right -match '^\d+$')
            $leftLooksInt = ($lcall -match '(msec|count|num|index|idx|wave|stage|level|round|row|col|length|ticks|randi|exp|points|power|slot|size$|batch|quota|total|sum|n$|i$|j$|k$|^i|^j|^k|^num|^count|^max|^min_?|^stage|^wave|^level|^round|^row|^col)') -or ($lcall -match '^[a-z_]*[A-Z_]+$' -and $lcall -cmatch '^[A-Z0-9_]+$')
            $parenLeft = ($left -match '[\)\d]$') -and ($right -match '^[A-Za-z_]\w*$')
            if ($rightIsIntLiteral -or ($leftLooksInt -and $lcall -notmatch $floatHint) -or $parenLeft) {
                $hits += [pscustomobject]@{
                    File = $f.FullName.Substring($root.Length + 1)
                    Line = $i + 1
                    Left = $left
                    Right = $right
                    Text = $line.Trim()
                }
            }
        }
    }
}
$outFile = Join-Path $env:TEMP 'int_division_candidates.txt'
$hits | Sort-Object File, Line | ForEach-Object {
    '{0}:{1}: [{2} / {3}]  {4}' -f $_.File, $_.Line, $_.Left, $_.Right, $_.Text
} | Set-Content -LiteralPath $outFile -Encoding UTF8
Write-Host ("TOTAL CANDIDATES: " + $hits.Count)
Write-Host ("OUTPUT: " + $outFile)
