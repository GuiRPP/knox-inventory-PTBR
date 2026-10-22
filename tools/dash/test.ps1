# Runs tools\dash\test.lua: KnoxDashboard.lua on the game's own Lua, outside the game
# (both bodies, every state, every control, four screens).
#   tools\dash\test.ps1 [-snap <folder>]   also a frame of each state as a PNG (snap.ps1)
#                       [-lang EN]          the texts of that language (RU by default)
param([string]$snap, [string]$lang = "RU")
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = "C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe"
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$pics = (Get-ChildItem (Join-Path $root "42\media\ui\knoxdash") -Filter *.png | ForEach-Object { $_.BaseName }) -join ","
$extra = @("lang=$lang")
if ($snap) {
    New-Item -ItemType Directory -Force $snap | Out-Null
    $snap = (Resolve-Path $snap).Path
    $extra += "snap=$($snap -replace '\\', '/')"
}
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run "pics=$pics" "root=$($root -replace '\\', '/')" @extra (Join-Path $PSScriptRoot "stubs.lua") `
        (Join-Path $root "42\media\lua\client\Knox\KnoxDashDemo.lua") (Join-Path $root "42\media\lua\client\Knox\KnoxDashboard.lua") (Join-Path $PSScriptRoot "test.lua")
} finally { Pop-Location }
if ($snap) { & (Join-Path $PSScriptRoot "snap.ps1") $snap }
