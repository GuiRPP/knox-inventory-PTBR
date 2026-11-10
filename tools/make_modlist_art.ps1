# The game's mod list pictures: 42\poster.png (256) and 42\icon.png (64), the author's
# pick of 2026-11-08 - the ice badge and the winter bar without the plate. The ONLY
# script that writes them (make_art / make_poster / make_poster2 write into tools\art).
#   1. make_poster2.ps1 -Overlay -Winter draws the poster over a transparent scene, a
#      picture a frame, into tools\art\gif_frames - kept aside and put back after, so
#      the frames of the animated preview are not lost; frame 25 = a bag carried in
#   2. ffmpeg takes the bar from the winter menu video (the crop of the Workshop GIF)
#   3. make_modlist_art.py rubs out the plate and lays the frame over the bar
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_modlist_art.ps1 [-Frame 25] [-At 11.2]
#   (needs ffmpeg and python with Pillow)

param([int]$Frame = 25, [double]$At = 11.2,
      [string]$Video = "", [string]$Crop = "1550:1060:300:0")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$art = Join-Path $PSScriptRoot "art"
if (-not $Video) { $Video = Join-Path $art "menu_winter_2026-11-04.mp4" }
if (-not (Test-Path $Video)) { throw "No video of the winter menu: $Video" }

$tmp = Join-Path $env:TEMP "knox_modlist_art"
if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
$keep = Join-Path $tmp "gif_frames"
New-Item -ItemType Directory -Force $keep | Out-Null
$frames = Join-Path $art "gif_frames"
if (Test-Path $frames) { Copy-Item -Path (Join-Path $frames "*") -Destination $keep -Force }
try {
    # (9 fps over 3.5 s as the winter GIF: 32 frames)
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "make_poster2.ps1") -Overlay -Winter -Fps 9 -Length 3.5 | Out-Null
    $ov = Join-Path $frames ("ov_{0:D3}.png" -f $Frame)
    if (-not (Test-Path $ov)) { throw "make_poster2.ps1 drew no frame $Frame" }
    Copy-Item -LiteralPath $ov -Destination (Join-Path $tmp "ov.png")
} finally {
    # the animated preview's frames back as they were
    if (Test-Path $frames) { Remove-Item -Path (Join-Path $frames "*") -Force }
    Copy-Item -Path (Join-Path $keep "*") -Destination $frames -Force -ErrorAction SilentlyContinue
}

$vid = Join-Path $tmp "bar.png"
$culture = [Globalization.CultureInfo]::InvariantCulture
ffmpeg -v error -y -ss $At.ToString($culture) -i $Video -frames:v 1 -vf "crop=$Crop,scale=1024:700:flags=lanczos" $vid
if (-not (Test-Path $vid)) { throw "ffmpeg took no frame from $Video" }

& python (Join-Path $PSScriptRoot "make_modlist_art.py") $root (Join-Path $tmp "ov.png") $vid
if ($LASTEXITCODE -ne 0) { throw "make_modlist_art.py failed" }
Remove-Item -LiteralPath $tmp -Recurse -Force
