# The animated Workshop preview (2026-10-14): the poster of make_poster2.ps1 with
# a piece of a video of the main menu's camp moving under it.
#   1. make_poster2.ps1 -Overlay draws everything but the camp, a picture a frame:
#      the bag's grid is filled thing by thing (tools\art\gif_frames)
#   2. ffmpeg crops the video to the two heroes by the fire, lays it under the
#      overlay, and writes a looping GIF with one palette for all its frames
#   tools\art\preview_workshop.gif   (Steam takes a preview under 1 000 000 bytes - 1 016 336 was refused,
#                                     the frame rate and the length are cut to fit)
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_poster_gif.ps1 -Video <mp4>
#        [-Start 17] [-Length 3.5] [-Size 512] [-Fps 8] [-Colors 112]   (961 081 bytes on 2026-10-14, with the grid filling up)
# The crop (x y w h in the video) is for the 2560x1070 recording of 2026-10-14.

param([Parameter(Mandatory = $true)][string]$Video, [double]$Start = 17, [double]$Length = 3.5,
      [int]$Size = 512, [int]$Fps = 8, [string]$Crop = "1110:759:1020:250", [int]$Colors = 112, [string]$Dither = "none")

$ErrorActionPreference = "Stop"
$art = Join-Path $PSScriptRoot "art"
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "make_poster2.ps1") -Overlay -Fps $Fps -Length $Length | Out-Null
$overlay = Join-Path $art "gif_frames\ov_%03d.png"   # (one a frame: the grid filling up)
$out = Join-Path $art "preview_workshop.gif"

# the camp 1024 x 700 at the top of a 1024 square, the poster over it, then the
# whole scaled down; a palette made from the frames themselves, dithered lightly
# A seamless loop: the clip's last half second fades into its first, which is
# cut from the front (the GIF is `Length` long, the video read `Length` + 0.5).
$x = 0.5
$read = $Length + $x
$cut = "[0:v]crop=$Crop,scale=1024:700:flags=lanczos,fps=$Fps,split[s1][s2]"
$loop = "[s1]trim=start=${x}:end=${read},setpts=PTS-STARTPTS[a0];[s2]trim=start=0:end=${x},setpts=PTS-STARTPTS[b0];" +
        "[a0][b0]xfade=transition=fade:duration=${x}:offset=$($Length - $x)[lp]"
$scene = "[lp]pad=1024:1024:0:0:color=0x0c0e0e[sc]"
$comp = "[sc][1:v]overlay=0:0:shortest=1,scale=${Size}:${Size}:flags=lanczos,split[a][b]"
$pal = "[a]palettegen=max_colors=${Colors}:stats_mode=full[p];[b][p]paletteuse=dither=${Dither}:diff_mode=rectangle"
$culture = [Globalization.CultureInfo]::InvariantCulture
ffmpeg -v error -y -ss $Start.ToString($culture) -t $read.ToString($culture) -i $Video -framerate $Fps -i $overlay `
    -filter_complex "$cut;$loop;$scene;$comp;$pal" -loop 0 $out
$bytes = (Get-Item $out).Length; $kb = [math]::Round($bytes / 1024)
Write-Host "preview_workshop.gif: $Size px, $Fps fps, $Length s, $kb KB$(if ($bytes -ge 1000000) { '  - OVER Steam''s limit (1 000 000 bytes)' })"
