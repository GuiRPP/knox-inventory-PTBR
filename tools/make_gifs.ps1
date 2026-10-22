# GIFs for the Workshop page from screen recordings (2560x1440), each with a
# caption bar under the picture saying what is being shown:
#   tools\art\gif_inventory.gif, gif_equipment.gif, gif_menu.gif, gif_newgame.gif, gif_survivor.gif
# (pictures in the description: Steam takes up to 5 MB each)
# -Gallery writes smaller copies for the item's own gallery, under 2 MB each: gif_*_2mb.gif
# Needs ffmpeg in PATH. Captions: plain ASCII without ' : , % \ (ffmpeg's filter syntax).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_gifs.ps1 [-Gallery] [-Dir folder with the recordings]

param([string]$Dir = "F:\ÌÎÍÒÀÆ\Èãðû\Project Zomboid", [switch]$Gallery)

$ErrorActionPreference = "Stop"
$art = Join-Path $PSScriptRoot "art"
$work = Join-Path $env:TEMP "knox_gifs"
New-Item -ItemType Directory -Force $work | Out-Null
# ffmpeg's drawtext can't take a Windows path with a drive colon: the font is read from the working folder
Copy-Item (Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates\FiraSansExtraCondensed-SemiBold.ttf") (Join-Path $work "font.ttf") -Force

# the gallery copies: {width, fps, colors}
$small = @{
    inventory = @(750, 11, 128); equipment = @(690, 12, 128); menu = @(450, 9, 96)
    newgame = @(440, 8, 96); survivor = @(550, 9, 96)
}

# $crop: "" or "crop=w:h:x:y," of the recording; $caps: {from, to, text} in seconds of the cut piece
function Gif($name, $file, $start, $len, $crop, $width, $fps, $colors, $caps) {
    $out = "gif_$name.gif"
    if ($Gallery) { $width, $fps, $colors = $small[$name]; $out = "gif_${name}_2mb.gif" }
    # the caption bar keeps its proportions on narrow pictures
    $k = [math]::Min(1.0, ($width / 640.0))
    $bar = [int](48 * $k); $font = [int](25 * $k); $sq = [int](12 * $k)
    $f = "fps=$fps,${crop}scale=${width}:-1:flags=lanczos,pad=iw:ih+${bar}:0:0:color=0x1a1d1d,drawbox=x=0:y=ih-${bar}:w=iw:h=2:color=0xd4c38a:t=fill,drawbox=x=$([int](18 * $k)):y=ih-$([int]($bar / 2 - 1 + $sq / 2)):w=${sq}:h=${sq}:color=0xd4c38a:t=fill"
    foreach ($c in $caps) {
        $f += ",drawtext=fontfile=font.ttf:text='$($c[2].ToUpper())':fontsize=${font}:fontcolor=0xece8d8:x=$([int](42 * $k)):y=h-$([int]($bar / 2 - 1))-text_h/2:enable='gte(t\,$($c[0]))*lt(t\,$($c[1]))'"
    }
    $f += ",split[a][b];[a]palettegen=max_colors=${colors}:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle"
    [IO.File]::WriteAllText((Join-Path $work "filter.txt"), $f, (New-Object Text.ASCIIEncoding))
    Push-Location $work
    try { ffmpeg -v error -y -ss $start -t $len -i (Join-Path $Dir $file) -/filter_complex filter.txt (Join-Path $art $out) }
    finally { Pop-Location }
    Write-Host ("  {0}  {1:N2} MB" -f $out, ((Get-Item (Join-Path $art $out)).Length / 1MB))
}

Gif "inventory" "Project Zomboid 2026.10.12 - 12.13.06.03.mp4" 3 14 "" 800 12 160 @(
    @(0, 2.2, "Point at an item to see what it is"),
    @(2.2, 5, "Double click a bag - its grid opens in a window"),
    @(5, 10, "Moves take game time - the item waits and then arrives"),
    @(10, 14, "Quick pick - put the bag on straight from the ground")
)

Gif "equipment" "Project Zomboid 2026.10.12 - 12.16.45.04.mp4" 1 8 "crop=1240:1100:20:84," 720 12 160 @(
    @(0, 3, "Point at an empty slot - quick pick shows what fits"),
    @(3, 8, "One click and your character puts it on")
)

Gif "menu" "Project Zomboid 2026.10.12 - 12.12.41.02.mp4" 7 7.15 "" 640 12 128 @(
    @(0, 3.6, "Point at a hero by the fire to see who they are"),
    @(3.6, 7.2, "Click - the hero walks off and the save loads")
)

# the new game flow in two parts: Steam takes pictures up to 5 MB
Gif "newgame" "Project Zomboid 2026.10.12 - 12.58.40.05.mp4" 5 18.7 "" 600 10 128 @(
    @(0, 3.4, "Click the tent to start a new survivor"),
    @(3.4, 5.9, "Pick a game mode"),
    @(5.9, 11, "Choose where to begin on the world map"),
    @(11, 18.7, "Sandbox options - every setting is a row")
)

Gif "survivor" "Project Zomboid 2026.10.12 - 12.58.40.05.mp4" 23.7 19.3 "" 640 10 128 @(
    @(0, 5.9, "One screen for your survivor - occupation"),
    @(5.9, 10.9, "Traits in one list with filters"),
    @(10.9, 17, "Appearance and clothing"),
    @(17, 19.3, "And the loading screen in the same look")
)
