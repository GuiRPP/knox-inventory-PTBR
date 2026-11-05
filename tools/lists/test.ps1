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
    # the game's hotbar with its list (the overhaul's stage 3, 2026-11-04)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'hotbar_pre.lua') (Join-Path $knox 'KnoxHotbarOrder.lua') (Join-Path $knox 'KnoxHotbar.lua') (Join-Path $here 'hotbar.lua')
    # a grid with its lists: the cells, the quiet tiles (stage 3, 2026-10-29)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'grid_pre.lua') (Join-Path $knox 'KnoxSelect.lua') (Join-Path $knox 'KnoxGridView.lua') (Join-Path $here 'grid.lua')
    # rounds dropped onto a magazine (2026-11-05)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') (Join-Path $here 'dragmag_pre.lua') (Join-Path $knox 'KnoxDrag.lua') (Join-Path $here 'dragmag.lua')
    # the battery panel: the one in it and the character's to choose from (2026-10-29)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'picker_pre.lua') (Join-Path $knox 'KnoxSlotPicker.lua') (Join-Path $here 'picker.lua')
    # a thing's state as its category's colour (condition_v3, 2026-10-31)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') (Join-Path $here 'condition.lua')
    # magazines, rounds and guns: what fits, what is lit up, the panel and its actions (2026-10-30)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'load_pre.lua') (Join-Path $knox 'KnoxSlotPicker.lua') (Join-Path $knox 'KnoxLoad.lua') (Join-Path $here 'load.lua')
    # the menu on R (ammo_live, 2026-10-31)
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $here 'load_pre.lua') (Join-Path $here 'rmenu_pre.lua') (Join-Path $knox 'KnoxSlotPicker.lua') (Join-Path $knox 'KnoxLoad.lua') `
        (Join-Path $mod '42\media\lua\shared\Knox\KnoxMagKnown.lua') (Join-Path $knox 'KnoxRMenu.lua') (Join-Path $here 'rmenu.lua')
} finally { Pop-Location }
