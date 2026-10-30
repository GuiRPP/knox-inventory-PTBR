# Runs tools\lists\test.lua: the ready lists' Lua side (KnoxTheme T.listDraw) on the game's Lua, outside the game.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$knox = Join-Path $mod '42\media\lua\client\Knox'
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') (Join-Path $here 'test.lua')
    # an equipment slot with its list (stage 2, 2026-10-29)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'slot_pre.lua') (Join-Path $knox 'KnoxEquipment.lua') (Join-Path $here 'slot.lua')
    # a grid with its lists: the cells, the quiet tiles (stage 3, 2026-10-29)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'grid_pre.lua') (Join-Path $knox 'KnoxSelect.lua') (Join-Path $knox 'KnoxGridView.lua') (Join-Path $here 'grid.lua')
    # the battery panel: the one in it and the character's to choose from (2026-10-29)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'picker_pre.lua') (Join-Path $knox 'KnoxSlotPicker.lua') (Join-Path $here 'picker.lua')
} finally { Pop-Location }
