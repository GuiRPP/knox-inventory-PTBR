# "Every file loaded twice" (the author's plan 2026-11-10, DEV reloader): all of Knox's Lua
# files in the game's own Lua over stubs.lua, then each run again twice by the DEV reloader's
# engine (java\src\knox\java\KnoxHotEngine.java - the very code the game runs). HotLuaTest.java
# says what is checked. Then the Java part (javatest\test.ps1): classes swapped as in the game.
#   tools\hot\test.ps1 [-brief]   (-brief: only what failed and the totals - for checkall)
param([switch]$brief)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$mod = (Resolve-Path (Join-Path $here '..\..')).Path
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$jdk = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin'
$tmp = Join-Path $env:TEMP 'knox_hot_luatest'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force $tmp | Out-Null
$ErrorActionPreference = 'Continue'   # (javac's notes on stderr are not errors)
& "$jdk\javac.exe" --release 17 -encoding UTF-8 -nowarn -cp "$game\projectzomboid.jar" -d $tmp `
    (Join-Path $mod 'java\src\knox\java\KnoxHotEngine.java') (Join-Path $here 'HotLuaTest.java') (Join-Path $here 'HotScenario.java') 2>&1 | Where-Object { "$_" -notmatch '^Note:' }
if ($LASTEXITCODE -ne 0) { "hot: FAIL (javac)"; exit 1 }
Push-Location $game
try {
    $out = @(& "$jdk\java.exe" -cp "$tmp;$game\projectzomboid.jar" HotLuaTest (Join-Path $here 'stubs.lua') (Join-Path $mod '42\media\lua') 2>&1 | ForEach-Object { "$_" })
} finally { Pop-Location }
$out += @(& (Join-Path $here 'javatest\test.ps1') | ForEach-Object { "$_" })
if ($brief) { $out | Where-Object { $_ -match '^(FAIL|scenario:|hot:|javatest:)|Exception' } } else { $out }
