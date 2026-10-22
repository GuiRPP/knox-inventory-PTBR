# Runs tools\footprint\bench.lua: how long KnoxGrid.build takes on big containers, outside the game.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$shared = Join-Path $mod '42\media\lua\shared\Knox'

Push-Location $game      # Kahlua reads stdlib.lua from the working directory
try {
    & $java -cp "$game\projectzomboid.jar" $run `
        (Join-Path $here 'stubs.lua') (Join-Path $shared 'KnoxFootprintData.lua') (Join-Path $shared 'KnoxBagShapes.lua') `
        (Join-Path $shared 'KnoxFootprint.lua') `
        (Join-Path $shared 'KnoxGrid.lua') (Join-Path $here 'bench.lua')
} finally {
    Pop-Location
}