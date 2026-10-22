# Builds 42\media\lua\shared\Knox\KnoxFootprintData.lua and tools\footprint\report.txt from
# tools\footprint\knox_measure.txt with the mod's own rules (KnoxFootprint.lua), run on the
# game's Lua outside the game. See gen.lua.
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
        (Join-Path $here 'stubs.lua') (Join-Path $shared 'KnoxFootprint.lua') (Join-Path $here 'gen.lua') `
        "measure=$(Join-Path $here 'knox_measure.txt')" "out=$(Join-Path $shared 'KnoxFootprintData.lua')" `
        "report=$(Join-Path $here 'report.txt')"
} finally {
    Pop-Location
}
