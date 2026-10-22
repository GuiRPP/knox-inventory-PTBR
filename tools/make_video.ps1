# A short showcase video (mp4, 1920 wide, no sound) for Reddit and the like, cut from the
# same screen recordings as the GIFs, with the same caption bar:
#   tools\art\knox_showcase.mp4
# Needs ffmpeg in PATH. Captions: plain ASCII without ' : , % \ (ffmpeg's filter syntax).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_video.ps1 [-Dir folder with the recordings]

param([string]$Dir = "F:\ÌÎÍÒÀÆ\Èãðû\Project Zomboid")

$ErrorActionPreference = "Stop"
$art = Join-Path $PSScriptRoot "art"
$work = Join-Path $env:TEMP "knox_video"
New-Item -ItemType Directory -Force $work | Out-Null
Copy-Item (Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates\FiraSansExtraCondensed-SemiBold.ttf") (Join-Path $work "font.ttf") -Force

$script:n = 0
# $speed: 2 plays the piece twice as fast; $caps: {from, to, text} in seconds of the cut piece (before the speed-up)
function Piece($file, $start, $len, $speed, $caps) {
    $bar = 100
    $f = "fps=30,scale=1920:1080:flags=lanczos,pad=1920:1080+${bar}:0:0:color=0x1a1d1d,drawbox=x=0:y=ih-${bar}:w=iw:h=4:color=0xd4c38a:t=fill,drawbox=x=40:y=ih-61:w=26:h=26:color=0xd4c38a:t=fill"
    foreach ($c in $caps) {
        $f += ",drawtext=fontfile=font.ttf:text='$($c[2].ToUpper())':fontsize=54:fontcolor=0xece8d8:x=92:y=h-48-text_h/2:enable='gte(t\,$($c[0]))*lt(t\,$($c[1]))'"
    }
    $f += ",setpts=PTS/$speed"
    [IO.File]::WriteAllText((Join-Path $work "filter.txt"), $f, (New-Object Text.ASCIIEncoding))
    $script:n++
    $out = "piece$($script:n).mp4"
    Push-Location $work
    try { ffmpeg -v error -y -ss $start -t $len -i (Join-Path $Dir $file) -/filter:v filter.txt -an -r 30 -c:v libx264 -crf 20 -preset slow -pix_fmt yuv420p $out }
    finally { Pop-Location }
    Add-Content -Path (Join-Path $work "list.txt") -Value "file '$out'" -Encoding ascii
}

Set-Content -Path (Join-Path $work "list.txt") -Value $null -Encoding ascii

Piece "Project Zomboid 2026.10.12 - 12.12.41.02.mp4" 7 7.15 1 @(
    @(0, 3.6, "The main menu is a 3D camp with the heroes of your saves"),
    @(3.6, 7.2, "Click a hero - they walk off and the save loads")
)
Piece "Project Zomboid 2026.10.12 - 12.13.06.03.mp4" 3 14 1 @(
    @(0, 2.2, "A grid inventory - every item takes its real space"),
    @(2.2, 5, "Double click a bag - its grid opens in a window"),
    @(5, 10, "Moves take game time - the item waits and then arrives"),
    @(10, 14, "Quick pick - put the bag on straight from the ground")
)
Piece "Project Zomboid 2026.10.12 - 12.16.45.04.mp4" 1 8 1 @(
    @(0, 3, "Point at an empty slot - quick pick shows what fits"),
    @(3, 8, "One click and your character puts it on")
)
Piece "Project Zomboid 2026.10.12 - 12.58.40.05.mp4" 5 38 2 @(
    @(0, 3.4, "Click the tent to start a new survivor"),
    @(3.4, 5.9, "Pick a game mode"),
    @(5.9, 11, "Choose where to begin on the world map"),
    @(11, 18.7, "Sandbox options - every setting is a row"),
    @(18.7, 24.6, "One screen for your survivor - occupation"),
    @(24.6, 29.6, "Traits in one list with filters"),
    @(29.6, 35.7, "Appearance and clothing"),
    @(35.7, 38, "And the loading screen in the same look")
)

Push-Location $work
try { ffmpeg -v error -y -f concat -safe 0 -i list.txt -c copy -movflags +faststart (Join-Path $art "knox_showcase.mp4") }
finally { Pop-Location }
$v = Get-Item (Join-Path $art "knox_showcase.mp4")
Write-Host ("knox_showcase.mp4  {0:N1} MB" -f ($v.Length / 1MB))
