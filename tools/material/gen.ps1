# Every item of the game -> its material by the mod's own rules (KnoxMaterial.lua), for the eye:
# tools\material\report.txt. parse.ps1 first reads the game's scripts into items.tsv.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$mod = Split-Path -Parent (Split-Path -Parent $here)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')

& (Join-Path $here 'parse.ps1') | Out-Null
Push-Location $game      # Kahlua reads stdlib.lua from the working directory
try {
    & $java -cp "$game\projectzomboid.jar" $run `
        (Join-Path $mod '42\media\lua\shared\Knox\KnoxMaterial.lua') (Join-Path $here 'gen.lua') `
        "items=$(Join-Path $here 'items.tsv')" "report=$(Join-Path $here 'report.txt')"
} finally {
    Pop-Location
}
