# Runs tools\pinned\test.lua: the pinned post (its roadmap, Boosty, the coin's link) on the game's Lua, outside the game.
#   tools\pinned\test.ps1 [-lang en]
param([string]$lang = 'ru')
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$k = Join-Path $mod '42\media\lua\client\Knox'
# (the roadmap's pictures: every @road line's one there, in both languages)
foreach ($l in 'ru', 'en') {
    foreach ($line in Get-Content -Encoding UTF8 (Join-Path $mod "42\media\knox\news_$l.txt")) {
        if ($line -match '^\s*@road\s') {
            $f = $line -split [regex]::Escape("|"); $pv = if ($f.Count -gt 4) { $f[4].Trim() } else { "" }
            if ($pv -and -not (Test-Path (Join-Path $mod "42\media\knox\news\road\road_$($pv)_$l.png"))) { Write-Output "FAIL no picture road_$($pv)_$l.png" }
        }
    }
}
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $here 'stubs.lua') (Join-Path $k 'KnoxNews.lua') (Join-Path $k 'KnoxNewsBack.lua') (Join-Path $k 'KnoxRoadmap.lua') (Join-Path $k 'KnoxPinned.lua') (Join-Path $k 'KnoxMenuNews.lua') (Join-Path $here 'test.lua') "mod=$($mod.Replace([char]92, '/'))" "lang=$lang"
} finally { Pop-Location }
