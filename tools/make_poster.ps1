# OLD: replaced by make_poster2.ps1 on 2026-10-14 - running this puts the old poster back.
# The mod's poster / Workshop preview (since 2026-10-14): the name, four tagged pictures
# of what the mod has - 3D MAIN MENU, NEW GAME, UI, INVENTORY - edge to edge, and a
# sand band "VIEWPOINT COMPATIBLE" under them.
#   tools\art\poster_1024.png
#   tools\art\preview_workshop.jpg (1024x1024: the Workshop page's preview, upload_page.ps1)
#   42\poster.png (256x256: the game's mod list and Workshop\KnoxInventory\preview.png)
# The Workshop shows previews in 322x322 tiles and pads a smaller picture with black:
# 256x256 got a black frame there, so the page gets the big one.
# Cut from screenshots in tools\art (2000x1125). make_art.ps1 still draws the icon
# and the older posters; do not run it without -Now after this, it rewrites 42\poster.png.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_poster.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$art = Join-Path $PSScriptRoot "art"
$fontDir = Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates"
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $fontDir "FiraSansExtraCondensed-Bold.ttf"))
$family = $pfc.Families | Select-Object -First 1

function C([string]$hex, [int]$a = 255) {
    [System.Drawing.Color]::FromArgb($a, [Convert]::ToInt32($hex.Substring(1,2),16),
        [Convert]::ToInt32($hex.Substring(3,2),16), [Convert]::ToInt32($hex.Substring(5,2),16))
}
function Brush($hex, $a = 255) { New-Object System.Drawing.SolidBrush (C $hex $a) }
function Pen($hex, $w) { New-Object System.Drawing.Pen (C $hex), ([float]$w) }
function Font($px) { New-Object System.Drawing.Font $family, ([float]$px), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel) }
function CharWidth($g, $s, $font) {
    if ($s -eq " ") { return $font.Size * 0.28 }
    $g.MeasureString($s, $font, 1000, [System.Drawing.StringFormat]::GenericTypographic).Width
}
function SpacedWidth($g, $text, $font, $track) {
    $w = 0; foreach ($ch in $text.ToCharArray()) { $w += (CharWidth $g ([string]$ch) $font) + $track }; $w - $track
}
function Spaced($g, $text, $font, $brush, $x, $y, $track) {
    foreach ($ch in $text.ToCharArray()) {
        $s = [string]$ch
        $g.DrawString($s, $font, $brush, $x, $y)
        $x += (CharWidth $g $s $font) + $track
    }
    return $x
}

$SAND = "#d4c38a"; $INK = "#141414"; $BRIGHT = "#ece8d8"

$S = 1024
$bmp = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear((C $INK))

# the name as the active tab of the Knox screen, centred
$barH = 132
$g.FillRectangle((Brush "#1a1d1d"), 0, 0, $S, $barH)
$title = Font 100
$wK = SpacedWidth $g "KNOX" $title 4; $wI = SpacedWidth $g "INVENTORY" $title 4
$x0 = ($S - ($wK + 26 + $wI)) / 2 - 6
$x1 = Spaced $g "KNOX" $title (Brush $BRIGHT) $x0 0 4
$x2 = Spaced $g "INVENTORY" $title (Brush $SAND) ($x1 + 26) 0 4
$g.FillRectangle((Brush $SAND), $x0 + 4, $barH - 14, $x2 - $x0 - 8, 8)

# the Viewpoint band at the bottom: a crosshair and the words, ink on sand
$bandH = 214; $bandY = $S - $bandH
$gap = 8
# four tiles between the name and the band, edge to edge: {tag, screenshot, crop x, y, crop w}
$tiles = @(
    @("3D MAIN MENU", "screen_camp_two.png", 6, 0, 802),
    @("NEW GAME", "screen_081_spawn.jpg", 80, 88, 1220),
    @("UI", "screen_radio.png", 30, 42, 458),
    @("INVENTORY", "screen_stage1.jpg", 26, 126, 864)
)
$top = $barH + $gap
$tw = [int](($S - $gap) / 2); $th = [int](($bandY - $gap - $top - $gap) / 2)
$labelH = 70
for ($i = 0; $i -lt 4; $i++) {
    $t = $tiles[$i]
    $x = ($i % 2) * ($tw + $gap); $y = $top + [math]::Floor($i / 2) * ($th + $gap)
    $img = [System.Drawing.Image]::FromFile((Join-Path $art $t[1]))
    $sw = $t[4]; $sh = [int]($sw * $th / $tw)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle $x, $y, $tw, $th), $t[2], $t[3], $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
    # the switch in the picture's corner: every part of the mod can be turned on and off
    $sw2 = 66; $sh2 = 46; $sx = $x + $tw - 2 * $sw2 - 14; $sy = $y + 14
    $g.FillRectangle((Brush "#0b0c0c" 235), $sx - 5, $sy - 5, 2 * $sw2 + 10, $sh2 + 10)
    $g.FillRectangle((Brush $SAND), $sx, $sy, $sw2, $sh2)
    $g.FillRectangle((Brush "#1a1d1d"), $sx + $sw2, $sy, $sw2, $sh2)
    $g.DrawRectangle((Pen $SAND 3), $sx - 3, $sy - 3, 2 * $sw2 + 5, $sh2 + 5)
    $sf = Font 34
    $w = SpacedWidth $g "ON" $sf 2
    Spaced $g "ON" $sf (Brush $INK) ($sx + ($sw2 - $w) / 2 - 4) ($sy + 2) 2 | Out-Null
    $w = SpacedWidth $g "OFF" $sf 2
    Spaced $g "OFF" $sf (Brush "#6a6f6a") ($sx + $sw2 + ($sw2 - $w) / 2 - 4) ($sy + 2) 2 | Out-Null
    # the tag: a dark plate over the picture's bottom, sand capitals
    $g.FillRectangle((Brush "#0b0c0c" 215), $x, $y + $th - $labelH, $tw, $labelH)
    $g.FillRectangle((Brush $SAND), $x, $y + $th - $labelH, $tw, 4)
    $f = Font 56
    $w = SpacedWidth $g $t[0] $f 3
    Spaced $g $t[0] $f (Brush $SAND) ($x + ($tw - $w) / 2 - 6) ($y + $th - $labelH + 2) 3 | Out-Null
}

$g.FillRectangle((Brush $SAND), 0, $bandY, $S, $bandH)
$g.FillRectangle((Brush $INK), 0, $bandY, $S, 6)
# the crosshair: a ring and four ticks, the first-person sign
$cr = 64; $ccx = 40 + $cr + 14; $ccy = $bandY + $bandH / 2 + 3
$p = Pen $INK 13
$g.DrawEllipse($p, $ccx - $cr, $ccy - $cr, 2 * $cr, 2 * $cr)
$g.FillEllipse((Brush $INK), $ccx - 13, $ccy - 13, 26, 26)
foreach ($d in @(@(1,0), @(-1,0), @(0,1), @(0,-1))) {
    $g.DrawLine($p, $ccx + $d[0] * ($cr - 28), $ccy + $d[1] * ($cr - 28), $ccx + $d[0] * ($cr + 26), $ccy + $d[1] * ($cr + 26))
}
# the words fill what is left of the band
$tx = $ccx + $cr + 54; $room = $S - $tx - 40
$big = 124
do { $fb = Font $big; $wb = SpacedWidth $g "VIEWPOINT" $fb 6; $big -= 2 } while ($wb -gt $room)
# COMPATIBLE under it, spaced out to the same width
$fs = Font 58
$ws = SpacedWidth $g "COMPATIBLE" $fs 0
$track = ($wb - $ws) / 9
$lx = $tx + ($room - $wb) / 2 - 6
Spaced $g "VIEWPOINT" $fb (Brush $INK) $lx ($bandY + 10) 6 | Out-Null
Spaced $g "COMPATIBLE" $fs (Brush "#3a3a32") ($lx + 2) ($bandY + 18 + $fb.Size) $track | Out-Null

$g.Dispose()
$bmp.Save((Join-Path $art "poster_1024.png"), [System.Drawing.Imaging.ImageFormat]::Png)
# the Workshop page's preview: a JPEG under Steam's 1 MB
$jpg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]92)
$bmp.Save((Join-Path $art "preview_workshop.jpg"), $jpg, $ep)
$small = New-Object System.Drawing.Bitmap 256, 256
$g = [System.Drawing.Graphics]::FromImage($small)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.DrawImage($bmp, 0, 0, 256, 256)
$g.Dispose()
$small.Save((Join-Path $root "42\poster.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose(); $bmp.Dispose()
Write-Host "poster written"
