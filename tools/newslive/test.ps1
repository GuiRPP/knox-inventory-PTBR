# Runs tools\newslive\test.lua: the live inventory and menu on R of a news post (KnoxNewsLive) on the game's Lua, outside the game.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$knox = Join-Path $mod '42\media\lua\client\Knox'
$lists = Join-Path $mod 'tools\lists'
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $knox 'KnoxTheme.lua') `
        (Join-Path $lists 'load_pre.lua') (Join-Path $lists 'rmenu_pre.lua') (Join-Path $here 'pre.lua') `
        (Join-Path $knox 'KnoxSlotPicker.lua') (Join-Path $knox 'KnoxLoad.lua') (Join-Path $mod '42\media\lua\shared\Knox\KnoxMagKnown.lua') `
        (Join-Path $knox 'KnoxRMenu.lua') (Join-Path $knox 'KnoxSelect.lua') (Join-Path $knox 'KnoxGridView.lua') (Join-Path $knox 'KnoxNewsLive.lua') (Join-Path $here 'test.lua')
} finally { Pop-Location }
