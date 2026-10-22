# Runs tools\search\test.lua: KnoxSearch.lua on the game's own Lua, outside the game.
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = "C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe"
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $PSScriptRoot "stubs.lua") `
        (Join-Path $root "42\media\lua\shared\Knox\KnoxMaterial.lua") `
        (Join-Path $root "42\media\lua\shared\Knox\KnoxSoundLevelData.lua") `
        (Join-Path $root "42\media\lua\client\Knox\KnoxSearchSound.lua") `
        (Join-Path $root "42\media\lua\client\Knox\KnoxUISound.lua") `
        (Join-Path $root "42\media\lua\client\Knox\KnoxSearch.lua") (Join-Path $PSScriptRoot "test.lua")
} finally { Pop-Location }
