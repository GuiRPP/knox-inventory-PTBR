# Runs tools\page\dash_frames.lua: KnoxDashboard.lua on the game's own Lua, outside
# the game, playing the scene of the Workshop page's dashboard GIF, and paints its
# frames with tools\dash\snap.ps1 (the panel's own pictures, media\ui\knoxdash).
#   tools\page\dash_frames.ps1 <folder> [-lang EN]   -> <folder>\f0001.png ...
# (tools\make_page_v2.ps1 calls it; the stand-ins for the game are tools\dash\stubs.lua)
param([Parameter(Mandatory = $true)][string]$folder, [string]$lang = "EN", [string]$back = "#0c0e0e")
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = "C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe"
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$pics = (Get-ChildItem (Join-Path $root "42\media\ui\knoxdash") -Filter *.png | ForEach-Object { $_.BaseName }) -join ","
if (Test-Path $folder) { Remove-Item -Recurse -Force $folder }
New-Item -ItemType Directory -Force $folder | Out-Null
$folder = (Resolve-Path $folder).Path
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run "pics=$pics" "root=$($root -replace '\\', '/')" "lang=$lang" "snap=$($folder -replace '\\', '/')" `
        (Join-Path $root "tools\dash\stubs.lua") `
        (Join-Path $root "42\media\lua\client\Knox\KnoxDashDemo.lua") (Join-Path $root "42\media\lua\client\Knox\KnoxDashboard.lua") (Join-Path $PSScriptRoot "dash_frames.lua")
} finally { Pop-Location }
if ($LASTEXITCODE) { throw "dash_frames.lua failed" }
& (Join-Path $root "tools\dash\snap.ps1") $folder -back $back | Out-Null
