# Runs tools\editor\test.lua: the item editor (its window, its presets, the lines it makes) on the game's Lua, outside the game.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$knox = Join-Path $mod '42\media\lua\client\Knox'
$shared = Join-Path $mod '42\media\lua\shared\Knox'
Push-Location $game      # Kahlua reads stdlib.lua from the working directory
try {
    & $java -cp "$game\projectzomboid.jar" $run `
        (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $here 'stubs.lua') `
        (Join-Path $knox 'KnoxTheme.lua') (Join-Path $knox 'KnoxWindowDrag.lua') `
        (Join-Path $shared 'KnoxFootprintData.lua') (Join-Path $shared 'KnoxBagShapes.lua') (Join-Path $shared 'KnoxFootprint.lua') `
        (Join-Path $shared 'KnoxGrid.lua') (Join-Path $shared 'KnoxPresets.lua') `
        (Join-Path $knox 'KnoxEditorData.lua') (Join-Path $knox 'KnoxEditor.lua') (Join-Path $knox 'KnoxSettings.lua') (Join-Path $here 'test.lua')
} finally { Pop-Location }
