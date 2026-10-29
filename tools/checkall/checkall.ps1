# Every offline check of Knox Inventory in one go (the big check-up, 2026-10-21):
# LuaCheck (syntax), GlobalScan (globals new or gone against globals_baseline.txt -
# a new READ-ONLY name that isn't game API is a typo), the three translations read
# as JSON, every test suite, uilint. One line per check.
#   tools\checkall\checkall.ps1 [-baseline]   (-baseline: take today's globals as the baseline)
param([switch]$baseline)
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$t = Join-Path $mod 'java\tools\luacheck'
$files = (Get-ChildItem -Recurse -Filter *.lua (Join-Path $mod '42\media\lua')).FullName
"LuaCheck: " + ((& $java -cp "$game\projectzomboid.jar" "$t\LuaCheck.java" $files) -join ' ')
$now = & $java -cp "$game\projectzomboid.jar" "$t\GlobalScan.java" $files
$base = Join-Path $here 'globals_baseline.txt'
if ($baseline) { [IO.File]::WriteAllLines($base, [string[]]$now, (New-Object Text.UTF8Encoding($false))) }
$nameOf = { param($l) if ($l -match '^(READ-ONLY|SET) (\S+)') { $Matches[1] + ' ' + $Matches[2] } }
$b = @{}; foreach ($l in (Get-Content $base)) { $k = & $nameOf $l; if ($k) { $b[$k] = $true } }
$n = @{}; $newG = @(); foreach ($l in $now) { $k = & $nameOf $l; if ($k) { $n[$k] = $true; if (-not $b.ContainsKey($k)) { $newG += $l } } }
$gone = @(); foreach ($k in $b.Keys) { if (-not $n.ContainsKey($k)) { $gone += $k } }
"GlobalScan: new [" + ($newG -join '; ') + "] gone [" + ($gone -join ', ') + "]"
foreach ($l in 'EN', 'RU', 'CN') {
    $f = Join-Path $mod "42\media\lua\shared\Translate\$l\IG_UI.json"
    try { $o = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json; "JSON ${l}: ok, " + @($o.PSObject.Properties).Count + " keys" } catch { "JSON ${l}: BROKEN " + $_ }
}
foreach ($s in 'footprint', 'order', 'search', 'saveguard', 'net', 'carradio', 'dash', 'menu', 'gen', 'perf', 'crosshair', 'settings', 'editor', 'pinned', 'lists') {
    $out = & (Join-Path $mod "tools\$s\test.ps1") 2>&1 | Out-String
    $lines = ($out -split "`r?`n") | Where-Object { $_ -match 'pass|FAIL|rror' }
    "${s}: " + ($lines -join ' | ')
}
"uilint: " + ((& (Join-Path $mod 'tools\uilint\uilint.ps1') 2>&1 | Select-Object -Last 1) -join ' ')
