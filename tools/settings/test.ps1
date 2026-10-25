# Runs tools\settings\test.lua: the settings window (pages in a column, a view that scrolls) on the game's Lua, outside the game.
#   tools\settings\test.ps1 [-file <another KnoxSettings.lua>]
param([string]$file)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$knox = Join-Path $mod '42\media\lua\client\Knox'
if (-not $file) { $file = Join-Path $knox 'KnoxSettings.lua' }
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $here 'stubs.lua') (Join-Path $knox 'KnoxTheme.lua') (Join-Path $knox 'KnoxControls.lua') (Join-Path $knox 'KnoxOrder.lua') (Join-Path $knox 'KnoxWindowDrag.lua') $file (Join-Path $here 'test.lua')
} finally { Pop-Location }
