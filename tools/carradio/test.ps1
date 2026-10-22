# Runs tools\carradio\test.lua: KnoxCarRadio.lua on the game's own Lua, outside the game
# (own music left in one car while the driver drives another, and back), then
# tools\carradio\net.lua: KnoxMusicNet.lua - that music heard by the other players
# (a server and two clients in one Lua, the network between them stubbed).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = "C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe"
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$test = Join-Path $PSScriptRoot "test.lua"
$net = Join-Path $PSScriptRoot "net.lua"
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run $test (Join-Path $root "42\media\lua\client\Knox\KnoxCarRadio.lua") $test
    & $java -cp "$game\projectzomboid.jar" $run $net ("MN_PATH=" + (Join-Path $root "42\media\lua\shared\Knox\KnoxMusicNet.lua"))
} finally { Pop-Location }
