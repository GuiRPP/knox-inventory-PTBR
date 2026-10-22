# Runs tools\menu\test.lua: Knox's context menu layout on the game's Lua, outside the game.
#   tools\menu\test.ps1 [-file <another KnoxContextMenu.lua>]   (an older copy, to see a test catch it)
param([string]$file)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
if (-not $file) { $file = Join-Path $mod '42\media\lua\client\Knox\KnoxContextMenu.lua' }
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $here 'stubs.lua') $file (Join-Path $here 'test.lua')
} finally { Pop-Location }
