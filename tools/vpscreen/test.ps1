# Runs tools\vpscreen\test.lua: Viewpoint 0.1.7's inventory key and sidebar answered by Knox's screen, on the game's Lua, outside the game.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod '42\media\lua\client\Knox\KnoxCompat.lua') (Join-Path $here 'test.lua')
} finally { Pop-Location }
