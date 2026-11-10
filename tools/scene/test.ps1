# Runs tools\scene\test.lua: the menu's frame itself - KnoxMenuScene, KnoxMenuPlace and KnoxMenuSceneBar,
# all three real, over a stub of the game. What the frame does with H, Tab, the swipe, the narrator's look
# (tools\bar has the bar's build alone, tools\menu the look of the camp).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = "C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe"
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$knox = Join-Path $root "42\media\lua\client\Knox"
$files = 'KnoxMenuScene.lua', 'KnoxMenuPlace.lua', 'KnoxMenuSceneBar.lua' | ForEach-Object { Join-Path $knox $_ }
# (Knox's Java as these files call it: what stubs.lua doesn't answer itself answers nil)
$names = ($files | ForEach-Object { [regex]::Matches([IO.File]::ReadAllText($_), '\bknox[A-Z]\w+') } | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ' '
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $PSScriptRoot "stubs.lua") $files[0] $files[1] $files[2] `
        (Join-Path $PSScriptRoot "test.lua") "KNOX_CALLS=$names"
} finally { Pop-Location }
