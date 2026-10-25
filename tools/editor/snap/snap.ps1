# Snaps of the item editor for the news (2026-10-25, the author: "write the news"): the real
# KnoxEditor runs on the game's Lua outside the game (as tools\editor\test.ps1), its scenes
# (scenes.lua) are drawn into lists of calls (snapstubs.lua), and render.py paints them with
# Knox's font atlases, its lens and the game's own item icons (out of the game's texture
# packs, as tools\game_icons.ps1). Not the game: no world behind, the game's code font drawn
# as Knox's body font. Writes <out>\png_<lang>\<scene>.png.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\editor\snap\snap.ps1 -out <folder> [-lang ru|en]
param([Parameter(Mandatory = $true)][string]$out, [string]$lang = "ru")
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$mod = (Resolve-Path (Join-Path $here '..\..\..')).Path
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = Join-Path $env:USERPROFILE 'Zomboid\tools\jdk-25\bin\java.exe'
$run = Join-Path $mod 'java\tools\luacheck\LuaRun.java'
$knox = Join-Path $mod '42\media\lua\client\Knox'
$shared = Join-Path $mod '42\media\lua\shared\Knox'
New-Item -ItemType Directory -Force $out | Out-Null
$out = (Resolve-Path $out).Path
$rec = Join-Path $out "rec_$lang"; $png = Join-Path $out "png_$lang"; $icons = Join-Path $out 'icons'
New-Item -ItemType Directory -Force $rec, $png, $icons | Out-Null

# the fonts, the texts of both languages, the items' icons (once per folder)
if (-not (Test-Path (Join-Path $out 'fonts.lua'))) { & python -I (Join-Path $here 'fonts.py') $mod $out | Out-Null }
& python -I (Join-Path $here 'strings.py') $mod $out | Out-Null
if (-not (Get-ChildItem $icons -Filter *.png -ErrorAction SilentlyContinue)) {
    $names = [regex]::Matches([IO.File]::ReadAllText((Join-Path $here 'items.lua')), '\{"[^"]+", "([^"]+)"') | ForEach-Object { [regex]::Escape($_.Groups[1].Value) }
    $regex = '^Item_(' + (($names | Select-Object -Unique) -join '|') + ')$'
    foreach ($pack in 'UI2.pack', 'UI.pack') {
        & $java (Join-Path $mod 'java\tools\pack\PackExtract.java') (Join-Path $game "media\texturepacks\$pack") $icons $regex | Out-Null
    }
}
[IO.File]::WriteAllText((Join-Path $out 'dir.lua'), "SHOTDIR = [[$rec]]`nSHOTSRC = [[$out]]`nLANG = `"$lang`"`n")
# (the editor's two non-ASCII literals as stand-ins: LuaRun cuts such literals; snapstubs.lua's BYTE gives them back)
$ed = [IO.File]::ReadAllText((Join-Path $knox 'KnoxEditor.lua'), [Text.Encoding]::UTF8)
$ed = $ed.Replace([string][char]0xB7, '\1').Replace([string][char]0xD7, '\2')
[IO.File]::WriteAllText((Join-Path $out 'KnoxEditor_esc.lua'), $ed, (New-Object Text.UTF8Encoding $false))
Push-Location $game      # Kahlua reads stdlib.lua from the working directory
try {
    & $java -cp "$game\projectzomboid.jar" $run `
        (Join-Path $mod 'tools\settings\stubs.lua') (Join-Path $out 'dir.lua') (Join-Path $here 'strload.lua') (Join-Path $here 'items.lua') `
        (Join-Path $mod 'tools\editor\stubs.lua') (Join-Path $out 'fonts.lua') (Join-Path $here 'snapstubs.lua') `
        (Join-Path $knox 'KnoxTheme.lua') (Join-Path $knox 'KnoxWindowDrag.lua') `
        (Join-Path $shared 'KnoxFootprintData.lua') (Join-Path $shared 'KnoxBagShapes.lua') (Join-Path $shared 'KnoxFootprint.lua') `
        (Join-Path $shared 'KnoxGrid.lua') (Join-Path $shared 'KnoxPresets.lua') `
        (Join-Path $knox 'KnoxEditorData.lua') (Join-Path $out 'KnoxEditor_esc.lua') (Join-Path $here 'scenes.lua')
} finally { Pop-Location }
& python -I (Join-Path $here 'render.py') $mod $rec $png $icons
