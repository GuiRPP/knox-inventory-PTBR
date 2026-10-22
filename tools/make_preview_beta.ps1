# The Workshop preview with "1.0 BETA" on it (the author, 2026-10-20: "put in the
# preview gif that the 1.0 BETA is out, somewhere nicely"). The GIF of
# make_poster_gif.ps1 stays as it was; a small green plate is laid in the middle
# under the line "TARKOV-STYLE UI OVERHAUL". A light sweeps over it once a loop.
#   tools\art\preview_workshop_0987.gif   the preview before (kept: the base, and to go back)
#   tools\art\preview_workshop.gif        the preview with the plate (upload_page.ps1 sends it)
#   tools\art\gif_beta\b_%03d.png         the plate a frame (1024 px, transparent)
# Steam takes a preview under 1 000 000 bytes.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_preview_beta.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")
$art = Join-Path $PSScriptRoot "art"
$base = Join-Path $art "preview_workshop_0987.gif"
$gif = Join-Path $art "preview_workshop.gif"
if (-not (Test-Path $base)) { Copy-Item -LiteralPath $gif -Destination $base }
$frames = Join-Path $art "gif_beta"
if (Test-Path $frames) { Remove-Item -LiteralPath $frames -Recurse -Force }
New-Item -ItemType Directory -Force $frames | Out-Null

$N = 28              # the GIF's frames (8 fps, 3.5 s)
$S = 1024            # drawn at twice the GIF's size, scaled down by ffmpeg
# A small green plate, straight, in the middle under "TARKOV-STYLE UI OVERHAUL" (the
# author, 2026-10-20: the first one - a big tilted sand sticker on the right -
# covered the right hero's face)
$text = "1.0 BETA  " + [string][char]0x00B7 + "  NOW AVAILABLE"
$px = 26             # the head font's size
$H = 44
$cy = 214            # its middle (the tagline's line is at about 170)

for ($f = 0; $f -lt $N; $f++) {
    $bmp, $g = Canvas $S $S ([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $W = [math]::Ceiling((TextW $g $text "head" $px) + 2 * 22)
    $x0, $y0 = [math]::Floor(($S - $W) / 2), ($cy - $H / 2)
    # the green plate with Knox's 2 px frame, a darker green; dark letters
    Fill $g $K.ok $x0 $y0 $W $H
    Frame $g (Mix $K.ok $K.ink 0.45) $x0 $y0 $W $H 2
    TxtCentre $g $text "head" $px $K.ink $x0 $y0 $W $H
    # the light: a band across the plate in the loop's first frames
    $sweep = 10
    if ($f -lt $sweep) {
        # (not $k: PowerShell's names ignore case - it was news_ui's palette $K)
        $prog = $f / ($sweep - 1)
        $bx = $x0 - 70 + ($W + 140) * $prog
        $band = 0
        $clip = New-Object System.Drawing.Region (New-Object System.Drawing.RectangleF ([float]$x0), ([float]$y0), ([float]$W), ([float]($H - $band)))
        $g.Clip = $clip
        $pts = [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF ([float]$bx), ([float]($y0 - 10))),
            (New-Object System.Drawing.PointF ([float]($bx + 34)), ([float]($y0 - 10))),
            (New-Object System.Drawing.PointF ([float]($bx + 4)), ([float]($y0 + $H))),
            (New-Object System.Drawing.PointF ([float]($bx - 30)), ([float]($y0 + $H))))
        $g.FillPolygon((Br $K.bright 0.35), $pts)
        $g.ResetClip()
    }
    $g.Dispose()
    $bmp.Save((Join-Path $frames ("b_{0:D3}.png" -f $f)), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# laid over the GIF frame by frame; one palette for all frames, as make_poster_gif.ps1
$comp = "[1:v]scale=512:512:flags=lanczos[b];[0:v][b]overlay=0:0:shortest=1,split[a][c]"
$pal = "[a]palettegen=max_colors=112:stats_mode=full[p];[c][p]paletteuse=dither=none:diff_mode=rectangle"
ffmpeg -v error -y -i $base -framerate 8 -i (Join-Path $frames "b_%03d.png") -filter_complex "$comp;$pal" -loop 0 $gif
$bytes = (Get-Item $gif).Length
Write-Host "preview_workshop.gif: $([math]::Round($bytes / 1024)) KB$(if ($bytes -ge 1000000) { '  - OVER Steam''s limit (1 000 000 bytes)' })"
