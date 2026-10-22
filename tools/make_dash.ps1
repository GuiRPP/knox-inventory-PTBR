# The car dashboard's pictures (42\media\ui\knoxdash\*.png) for KnoxDashboard.lua:
# white on transparent, drawn big and anti-aliased, scaled down and tinted in the
# game (so Knox's skins colour them too). Each dial is in layers, one per colour:
#   <dial>_ticks   its marks, big / middle / small    (the scale's paint or light)
#   <dial>_red     its red zone                       (bad)
#   <dial>_nums    its numbers                        (the scale's paint or light)
#   <dial>_glow    marks and numbers blurred: the backlight's halo at night
# and the parts every dial shares: disc (the face), shade_disc (the well's wall and
# the visor's shade), face_glow, ring_<px> (2 px rings), cap_light, hub.
# The lamps' icons: lamp_<name>.png, line icons as the menu's (make_menu_icons.ps1).
# The geometry is the approved mockup's (mockup 2, the author 2026-10-21: the
# dashboard as a car's - switches, cluster, column, the radio and the heater):
# each dial's picture is its face's square, the face's radius = half its side;
# the sedan's visor (hood_sedan_*) is drawn from the same numbers as the SEDAN
# layout in KnoxDashboard.lua - change both together.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_dash.ps1 [sheet.png]

param([string]$sheet)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui\knoxdash"
New-Item -ItemType Directory -Force $dir | Out-Null
$fontDir = Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates"
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $fontDir "FiraSansExtraCondensed-SemiBold.ttf"))
$fam = $pfc.Families[0]
$white = [System.Drawing.Color]::White
$brush = New-Object System.Drawing.SolidBrush $white
$script:made = @()

function F($v) { [float]$v }
function Pen($w) {
    $p = New-Object System.Drawing.Pen $white, (F $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    return $p
}
function NewPic($n) {
    $bmp = New-Object System.Drawing.Bitmap $n, $n
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}
function SavePic($bmp, $g, $name) {
    $g.Dispose()
    $bmp.Save((Join-Path $dir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $script:made += $name
}
# a point at angle `deg` (0 = right, counter-clockwise, as the mockup) and radius r round c
function Pt($c, $r, $deg) {
    $a = $deg * [Math]::PI / 180
    return @(($c + $r * [Math]::Cos($a)), ($c - $r * [Math]::Sin($a)))
}

function NewPicWH($w, $h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}
function FlatPen($w, $a = 255) {
    $p = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($a, 255, 255, 255)), (F $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat; $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
    return $p
}
# A soft copy of a picture (a halo): stamped round itself, faint, in two rings.
function Blur($src, $radius) {
    $w = $src.Width; $h = $src.Height
    $bmp, $g = NewPicWH $w $h
    $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = 0.11
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    foreach ($rr in ($radius * 0.45), $radius) {
        for ($a = 0; $a -lt 360; $a += 30) {
            $dx = [int][Math]::Round($rr * [Math]::Cos($a * [Math]::PI / 180)); $dy = [int][Math]::Round($rr * [Math]::Sin($a * [Math]::PI / 180))
            $g.DrawImage($src, (New-Object System.Drawing.Rectangle $dx, $dy, $w, $h), 0, 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        }
    }
    return @($bmp, $g)
}

# One dial's layers, as the mockup draws them. Its face's radius R (units); the
# scale on 0.9 R from `start` degrees through `sweep` (clockwise), `vmin`..`vmax`:
# big marks every `major` (the numbers' places), middle ones every `mid`, small
# every `minor`; `labels` value -> text, on `numR` R, `numK` R high; the red zone
# `red0`..`red1` (none: equal). The picture: the face's square at 2 px a unit -
# the dial's size on a 4K screen; smaller screens scale it down.
function Dial($name, $R, $start, $sweep, $vmin, $vmax, $major, $mid, $minor, $labels, $numR, $numK, $red0, $red1) {
    $k = 2.0
    $N = [int]([Math]::Ceiling($R * 2 * $k / 8) * 8)
    $c = $N / 2; $Rp = $N / 2
    $rO = 0.9 * $Rp
    $deg = { param($v) $start - $sweep * ($v - $vmin) / ($vmax - $vmin) }
    $near = { param($v, $st) [Math]::Abs($v / $st - [Math]::Round($v / $st)) -lt 1e-6 }
    # the marks: big, middle, small (the small ones fainter)
    $bmp, $g = NewPic $N
    # (not $n: PowerShell's names ignore case - it was $N, the picture's size)
    $marks = [int][Math]::Round(($vmax - $vmin) / $minor)
    for ($i = 0; $i -le $marks; $i++) {
        $v = $vmin + $i * $minor
        $lvl = 0
        if (& $near $v $major) { $lvl = 2 } elseif (& $near $v $mid) { $lvl = 1 }
        $len = @(0.065, 0.1, 0.16)[$lvl] * $Rp
        $d = & $deg $v
        $p1 = Pt $c $rO $d; $p2 = Pt $c ($rO - $len) $d
        $g.DrawLine((FlatPen (@(1.0, 1.5, 2.4)[$lvl] * $k) (@(180, 255, 255)[$lvl])), (F $p1[0]), (F $p1[1]), (F $p2[0]), (F $p2[1]))
    }
    SavePic $bmp $g "${name}_ticks"
    # the red zone: a band just inside the marks
    $bmp, $g = NewPic $N
    if ($red1 -ne $red0) {
        $t0 = -(& $deg $red0); $t1 = -(& $deg $red1)
        $rr = $rO - 0.035 * $Rp
        $g.DrawArc((FlatPen (0.07 * $Rp)), (F ($c - $rr)), (F ($c - $rr)), (F (2 * $rr)), (F (2 * $rr)), (F ([Math]::Min($t0, $t1))), (F ([Math]::Abs($t1 - $t0))))
    }
    SavePic $bmp $g "${name}_red"
    # the numbers, centred on their places
    $bmp, $g = NewPic $N
    $font = New-Object System.Drawing.Font $fam, (F ($numK * $Rp)), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
    foreach ($l in $labels) {
        $p = Pt $c ($numR * $Rp) (& $deg $l[0])
        $g.DrawString([string]$l[1], $font, $brush, (New-Object System.Drawing.RectangleF (F ($p[0] - $Rp)), (F ($p[1] - $Rp / 2)), (F (2 * $Rp)), (F $Rp)), $sf)
    }
    SavePic $bmp $g "${name}_nums"
    # the halo: the marks blurred a little (the numbers are Knox's font in the game;
    # wider, the halo smeared the scale - the author, 2026-10-21)
    $both, $g = NewPic $N
    $img = [System.Drawing.Image]::FromFile((Join-Path $dir "${name}_ticks.png")); $g.DrawImage($img, 0, 0, $N, $N); $img.Dispose()
    $g.Dispose()
    $bmp, $g = Blur $both (0.03 * $Rp)
    $both.Dispose()
    SavePic $bmp $g "${name}_glow"
}

# the sedan's dials (the pickup's are a little smaller: the same pictures scaled)
$TACH_L = @(); for ($i = 0; $i -le 7; $i++) { $TACH_L += , @($i, "$i") }
$SPEED_L = @(); for ($v = 0; $v -le 120; $v += 20) { $SPEED_L += , @($v, "$v") }
# tachometer: 0..7 thousand, red from 6
Dial "tach" 44 210 240 0 7 1 0.5 0.25 $TACH_L 0.6 0.22 6 7
# speedometer: 0..120 km/h, numbers every 20, marks every 10 and 5
Dial "speed" 60 210 240 0 120 20 10 5 $SPEED_L 0.6 0.17 0 0
# fuel: E, 1/2, F over 120 degrees, quarters, red at E
Dial "fuel" 38 150 120 0 1 0.5 0.25 0.125 @(@(0, "E"), @(0.5, ([string][char]0xBD)), @(1, "F")) 0.58 0.24 0 0.125

# the shared parts: the face (a disc), its edge (a ring), the needle's hub
$bmp, $g = NewPic 256; $g.FillEllipse($brush, 1, 1, 254, 254); SavePic $bmp $g "disc"
$bmp, $g = NewPic 256; $g.DrawEllipse((Pen 3), 2, 2, 252, 252); SavePic $bmp $g "rim"
$bmp, $g = NewPic 32; $g.FillEllipse($brush, 1, 1, 30, 30); SavePic $bmp $g "hub"
# a soft dot: sparks of the hot-wired ignition, the lamps' glow
$bmp, $g = NewPic 64
$p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(0, 0, 64, 64)
$pb = New-Object System.Drawing.Drawing2D.PathGradientBrush $p
$pb.CenterColor = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$pb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
$g.FillEllipse($pb, 0, 0, 64, 64); SavePic $bmp $g "soft"

# The needle (drawn on a turned quad: its tip at the top, its hub's end at the
# bottom; the shape in the middle third, the sides left clear for the edges'
# smoothing) and its glow; a bar: one piece of a drawn arc or line, soft along
# its long edges (the quad's top and bottom).
$bmp = New-Object System.Drawing.Bitmap 48, 256
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = "AntiAlias"; $g.Clear([System.Drawing.Color]::Transparent)
$pts = @((New-Object System.Drawing.PointF 22.5, 2), (New-Object System.Drawing.PointF 25.5, 2), (New-Object System.Drawing.PointF 30, 254), (New-Object System.Drawing.PointF 18, 254))
$g.FillPolygon($brush, [System.Drawing.PointF[]]$pts); SavePic $bmp $g "needle"
$bmp = New-Object System.Drawing.Bitmap 48, 256
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = "AntiAlias"; $g.Clear([System.Drawing.Color]::Transparent)
for ($i = 12; $i -ge 1; $i--) {
    $a = [int](22 * (1 - $i / 13.0) + 4)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($a, 255, 255, 255)), (F (6 + $i * 2.6))
    $pen.StartCap = "Round"; $pen.EndCap = "Round"
    $g.DrawLine($pen, 24, 14, 24, 244)
}
SavePic $bmp $g "glow"
$bmp = New-Object System.Drawing.Bitmap 16, 16
for ($y = 0; $y -lt 16; $y++) {
    $a = [Math]::Min(1.0, [Math]::Min($y + 0.5, 15.5 - $y) / 4.0)
    for ($x = 0; $x -lt 16; $x++) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int](255 * $a), 255, 255, 255)) }
}
$bmp.Save((Join-Path $dir "bar.png"), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $script:made += "bar"

# The ignition's key, in layers on one square, the turning point in its middle:
# a key as one draws a key - the bow with its hole sticking out of the lock (up),
# the blade with its teeth going into it (its tip at the middle). (The first one,
# a plain bar and a small head, didn't read as a key - the author, 2026-10-18.)
# Mockup units (100 x 100), drawn twice as big.
function KeyPic($name, [scriptblock]$draw) {
    $bmp, $g = NewPic 200
    $g.ScaleTransform(2, 2); $g.TranslateTransform(50, 50)
    & $draw $g
    SavePic $bmp $g "key_$name"
}
function BladePath {
    $pts = @(-3.5, -17, -3.5, 1, -1, 3.5, 3.5, 1, 3.5, -1, 5.8, -3.2, 3.5, -5.5, 5.8, -7.7, 3.5, -10, 5.8, -12.2, 3.5, -14.5, 3.5, -17)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pf = New-Object 'System.Drawing.PointF[]' ($pts.Count / 2)
    for ($i = 0; $i -lt $pf.Length; $i++) { $pf[$i] = New-Object System.Drawing.PointF (F $pts[2 * $i]), (F $pts[2 * $i + 1]) }
    $p.AddPolygon($pf)
    return $p
}
function BowPath {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddRectangle((New-Object System.Drawing.RectangleF (F -6.5), (F -20.5), (F 13), (F 4.5)))
    $p.AddEllipse((F -12.5), (F -42), (F 25), (F 23))
    return $p
}
function HolePath {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddEllipse((F -3.6), (F -37.6), (F 7.2), (F 7.2))
    return $p
}
function Rounded($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc((F $x), (F $y), (F (2 * $r)), (F (2 * $r)), 180, 90)
    $p.AddArc((F ($x + $w - 2 * $r)), (F $y), (F (2 * $r)), (F (2 * $r)), 270, 90)
    $p.AddArc((F ($x + $w - 2 * $r)), (F ($y + $h - 2 * $r)), (F (2 * $r)), (F (2 * $r)), 0, 90)
    $p.AddArc((F $x), (F ($y + $h - 2 * $r)), (F (2 * $r)), (F (2 * $r)), 90, 90)
    $p.CloseFigure()
    return $p
}
KeyPic "blade" { param($g); $g.FillPath($brush, (BladePath)) }
KeyPic "head" { param($g)
    $reg = New-Object System.Drawing.Region (BowPath); $reg.Exclude((HolePath))
    $g.FillRegion($brush, $reg) }
# the grip's ridges across the bow, under its hole
KeyPic "groove" { param($g)
    foreach ($y in -27.5, -24.5) { $g.FillRectangle($brush, (F -7.5), (F $y), (F 15), (F 1.4)) } }
# the outline of the whole key (bow and blade), and its shadow (filled)
KeyPic "edge" { param($g)
    $pen = New-Object System.Drawing.Pen $white, (F 1.1); $pen.LineJoin = "Round"
    $reg = New-Object System.Drawing.Drawing2D.GraphicsPath; $reg.AddPath((BowPath), $false)
    $g.DrawPath($pen, (BowPath)); $g.DrawPath($pen, (BladePath)); $g.DrawPath($pen, (HolePath)) }
KeyPic "shadow" { param($g); $g.FillPath($brush, (BowPath)); $g.FillPath($brush, (BladePath)) }

# The lamps (64-unit line icons, as the mockup's; 40 px, about twice their size
# on a 1080p screen) ----------------------------------------------------------------
$LW = 4.5
# (each one moved to the middle of its picture by where its pixels are: drawn in
# their 64-unit boxes some sat off the middle of their lamps - the author, 2026-10-18)
function Icon($name, [scriptblock]$draw) {
    $bmp, $g = NewPic 40
    $g.ScaleTransform((40 / 64), (40 / 64))
    & $draw $g
    $g.Dispose()
    $x0 = 40; $y0 = 40; $x1 = -1; $y1 = -1
    for ($y = 0; $y -lt 40; $y++) { for ($x = 0; $x -lt 40; $x++) {
        if ($bmp.GetPixel($x, $y).A -gt 24) { if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }; if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y } }
    } }
    # (whole pixels: a picture moved by a fraction comes out blurred)
    $dx = [Math]::Round(20 - ($x0 + $x1 + 1) / 2.0); $dy = [Math]::Round(20 - ($y0 + $y1 + 1) / 2.0)
    $out, $g2 = NewPic 40
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.DrawImage($bmp, (F $dx), (F $dy), (F 40), (F 40))
    $bmp.Dispose()
    SavePic $out $g2 "lamp_$name"
}
function Ln($g, $a) {
    $pts = New-Object 'System.Drawing.PointF[]' ($a.Count / 2)
    for ($i = 0; $i -lt $pts.Length; $i++) { $pts[$i] = New-Object System.Drawing.PointF (F $a[2 * $i]), (F $a[2 * $i + 1]) }
    $g.DrawLines((Pen $LW), $pts)
}
function Box($g, $x, $y, $w, $h) { $g.DrawRectangle((Pen $LW), (F $x), (F $y), (F $w), (F $h)) }
Icon "engine" { param($g); Box $g 14 24 32 22; Ln $g @(22, 24, 22, 16, 38, 16, 38, 24); Ln $g @(46, 30, 52, 30, 52, 40, 46, 40); Ln $g @(14, 34, 8, 34) }
Icon "battery" { param($g); Box $g 10 20 44 28; Ln $g @(18, 20, 18, 14); Ln $g @(46, 20, 46, 14); Ln $g @(18, 34, 26, 34); Ln $g @(38, 34, 46, 34); Ln $g @(42, 30, 42, 38) }
Icon "lights" { param($g)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 30), (F 14), (F 16), (F 14), (F 10), (F 24), (F 10), (F 32))
    $p.AddBezier((F 10), (F 32), (F 10), (F 40), (F 16), (F 50), (F 30), (F 50))
    $p.CloseFigure(); $g.DrawPath((Pen $LW), $p)
    Ln $g @(38, 20, 54, 20); Ln $g @(38, 32, 54, 32); Ln $g @(38, 44, 54, 44) }
Icon "doors" { param($g); Box $g 18 30 28 20; $g.DrawArc((Pen $LW), 23, 14, 18, 22, 180, 180); Ln $g @(23, 25, 23, 30); Ln $g @(41, 25, 41, 30) }
Icon "heater" { param($g)
    foreach ($x in 18, 32, 46) {
        $p = New-Object System.Drawing.Drawing2D.GraphicsPath
        $p.AddBezier((F $x), (F 50), (F ($x - 8)), (F 42), (F ($x + 8)), (F 32), (F $x), (F 24))
        $p.AddBezier((F $x), (F 24), (F ($x - 6)), (F 18), (F ($x + 2)), (F 14), (F $x), (F 10))
        $g.DrawPath((Pen $LW), $p)
    } }
Icon "radio" { param($g); Box $g 10 26 44 26; $g.DrawEllipse((Pen $LW), 34, 32, 14, 14); Ln $g @(16, 34, 26, 34); Ln $g @(16, 42, 26, 42); Ln $g @(20, 26, 40, 10) }
Icon "cruise" { param($g); $g.DrawArc((Pen $LW), 12, 16, 40, 40, 180, 180); Ln $g @(32, 36, 42, 24); Ln $g @(14, 44, 20, 44); Ln $g @(44, 44, 50, 44) }
Icon "trunk" { param($g); Ln $g @(10, 46, 54, 46, 54, 32, 46, 20, 18, 20, 10, 32, 10, 46); Ln $g @(10, 32, 54, 32); Ln $g @(28, 39, 36, 39) }
Icon "fuel" { param($g); Box $g 16 16 22 34; Ln $g @(38, 24, 44, 24, 50, 30, 50, 44); $g.DrawArc((Pen $LW), 44, 40, 6, 6, 0, 180); Ln $g @(21, 24, 33, 24) }
# a note: the radio's lamp while the car plays the player's own music
Icon "note" { param($g); $g.FillEllipse($brush, 14, 38, 14, 11); $g.FillEllipse($brush, 36, 34, 14, 11); Ln $g @(27, 43, 27, 14, 49, 10, 49, 39); Ln $g @(27, 21, 49, 17) }

# the doors' rocker: locked (its top half) and open (its bottom half)
Icon "lockc" { param($g); Box $g 16 30 32 22; $g.DrawArc((Pen $LW), 21, 12, 22, 24, 180, 180); Ln $g @(21, 24, 21, 30); Ln $g @(43, 24, 43, 30) }
Icon "locko" { param($g); Box $g 12 30 32 22; $g.DrawArc((Pen $LW), 30, 8, 22, 24, 180, 180); Ln $g @(52, 20, 52, 26) }
# the radio's MIX and RPT (RPT 1: one track) as signs - words didn't fit under its
# keys and on its display with the smallest font at 1280 x 1024 (tools\dash\test)
Icon "mix" { param($g)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddBezier(8, 18, 30, 18, 30, 46, 52, 46); $g.DrawPath((Pen $LW), $p)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddBezier(8, 46, 30, 46, 30, 18, 52, 18); $g.DrawPath((Pen $LW), $p)
    Ln $g @(44, 10, 54, 18, 44, 26); Ln $g @(44, 38, 54, 46, 44, 54) }
Icon "rpt" { param($g); $g.DrawArc((Pen $LW), 10, 14, 44, 36, 200, 300); Ln $g @(4, 22, 12, 32, 20, 22) }
Icon "rpt1" { param($g); $g.DrawArc((Pen $LW), 10, 14, 44, 36, 200, 300); Ln $g @(4, 22, 12, 32, 20, 22); Ln $g @(28, 28, 33, 24, 33, 42) }

# The wells, the caps, the knobs -----------------------------------------------------

# the well's wall and the visor's shade on a face: a disc dark at the top, clear
# from a little over half way down (tinted black)
$bmp, $g = NewPic 256
$g.SetClip((New-Object System.Drawing.Rectangle 0, 0, 256, 141))
$lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, 256, 142), ([System.Drawing.Color]::FromArgb(255, 255, 255, 255)), ([System.Drawing.Color]::FromArgb(0, 255, 255, 255)), 90
$g.FillEllipse($lg, 1, 1, 254, 254); SavePic $bmp $g "shade_disc"
# the backlight on a face: faint toward its rim, clear in the middle
$bmp, $g = NewPic 256
$p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(1, 1, 254, 254)
$pb = New-Object System.Drawing.Drawing2D.PathGradientBrush $p
$cb = New-Object System.Drawing.Drawing2D.ColorBlend 4
$cb.Colors = @([System.Drawing.Color]::FromArgb(115, 255, 255, 255), [System.Drawing.Color]::FromArgb(255, 255, 255, 255), [System.Drawing.Color]::FromArgb(0, 255, 255, 255), [System.Drawing.Color]::FromArgb(0, 255, 255, 255))
$cb.Positions = @([single]0, [single]0.2, [single]0.8, [single]1)
$pb.InterpolationColors = $cb
$g.FillEllipse($pb, 1, 1, 254, 254); SavePic $bmp $g "face_glow"
# 2 px rings for a well's rim, a knob, the lock: ring_<d> is 2 px wide at d px
# across (drawn twice as big); the game takes the one nearest the size it needs
foreach ($d in 16, 22, 30, 40, 54, 72, 96, 128, 170, 226) {
    # (drawn at the size it is shown: scaled down twice the game left its edge jagged)
    $bmp, $g = NewPic $d
    $g.DrawEllipse((New-Object System.Drawing.Pen $white, 2), 1, 1, ($d - 2), ($d - 2)); SavePic $bmp $g "ring_$d"
}
# the light on a cap or a knob's top, from the upper left
$bmp, $g = NewPic 128
$p = New-Object System.Drawing.Drawing2D.GraphicsPath; $p.AddEllipse(1, 1, 126, 126)
$pb = New-Object System.Drawing.Drawing2D.PathGradientBrush $p
$pb.CenterPoint = New-Object System.Drawing.PointF 44, 38
$pb.CenterColor = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$pb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
$g.FillEllipse($pb, 1, 1, 126, 126); SavePic $bmp $g "cap_light"
# a knob's grip: 28 ridges round its edge (turned with the knob)
$bmp, $g = NewPic 256
for ($i = 0; $i -lt 28; $i++) {
    $a = $i * 360 / 28
    $p1 = Pt 128 102 $a; $p2 = Pt 128 125 $a
    $g.DrawLine((FlatPen 8), (F $p1[0]), (F $p1[1]), (F $p2[0]), (F $p2[1]))
}
SavePic $bmp $g "knurl"
# a shade fading downwards (shadows under a shelf, a figure drum's top and bottom)
$bmp = New-Object System.Drawing.Bitmap 8, 64
for ($y = 0; $y -lt 64; $y++) { for ($x = 0; $x -lt 8; $x++) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb([int](255 * (1 - $y / 63.0)), 255, 255, 255)) } }
$bmp.Save((Join-Path $dir "grad.png"), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $script:made += "grad"

# The sedan's visor: one shelf over the three wells, its lower edge bent up over each
# (a brow), wrapping down the outer wells' sides. In the SEDAN layout's units: the
# dials (cx, cy, R, wall), the shelf's top T and its lower edge B between the
# wells, `over` its brows' room over the wells. The picture covers units
# HX..HX+HW, HY..HY+HH at 2 px a unit; its layers: _fill (cell), _dark (its top
# darker), _edge (tile edge: the sides and top), _lip (sand: the lower edge),
# _shadow (blurred, a little down: cast on the plate and the faces).
$HX = 96; $HY = 2; $HW = 356; $HH = 92; $HK = 2
# (the shelf fills the cluster's plate from its frame's inner edges - 106..444, from
# 10 down: standing apart from it with its own grey sides and top, it lay over the
# frame on the left and looked peeled off on the right - the author, 2026-10-21)
$VD = @(@(162, 65, 44, 5), @(281, 82, 60, 5), @(394, 65, 38, 5)); $VT = 10; $VB = 66; $VO = 3; $VL = 106; $VR = 444
function HP($u, $v) { return New-Object System.Drawing.PointF (F (($u - $HX) * $HK)), (F (($v - $HY) * $HK)) }
function VisorEdge($p) {
    for ($i = 0; $i -lt $VD.Count; $i++) {
        $cx = $VD[$i][0]; $cy = $VD[$i][1]; $Rh = $VD[$i][2] + $VD[$i][3] + $VO
        $dy = $VB - $cy; $dx = [Math]::Sqrt([Math]::Max(0, $Rh * $Rh - $dy * $dy))
        $a0 = [Math]::Atan2($dy, -$dx) * 180 / [Math]::PI; $a1 = [Math]::Atan2($dy, $dx) * 180 / [Math]::PI
        if ($i -eq 0) { $a0 = 180 }
        if ($i -eq $VD.Count - 1) { $a1 = 360 }
        $sweep = $a1 - $a0; while ($sweep -le 0) { $sweep += 360 }
        $tl = HP ($cx - $Rh) ($cy - $Rh)
        $p.AddArc($tl.X, $tl.Y, (F (2 * $Rh * $HK)), (F (2 * $Rh * $HK)), (F $a0), (F $sweep))
    }
}
$first = $VD[0]; $last = $VD[$VD.Count - 1]
$xL = $VL; $xR = $VR
$shape = New-Object System.Drawing.Drawing2D.GraphicsPath
$shape.AddLine((HP $xL $VT), (HP $xL $first[1])); VisorEdge $shape; $shape.AddLine((HP $xR $last[1]), (HP $xR $VT)); $shape.CloseFigure()
$W = $HW * $HK; $H = $HH * $HK
$bmp, $g = NewPicWH $W $H; $g.FillPath($brush, $shape); SavePic $bmp $g "hood_sedan_fill"
$bmp, $g = NewPicWH $W $H
$lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (HP 0 ($VT - 1)), (HP 0 ($VB + 1)), ([System.Drawing.Color]::FromArgb(255, 255, 255, 255)), ([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
$g.FillPath($lg, $shape); SavePic $bmp $g "hood_sedan_dark"
# (lines 2 px on a 1080p screen: the panel is drawn at a px a unit there)
$LP = 2 * $HK
# the sand lip along the whole lower edge, from the frame on the left to the frame on
# the right (its own line inside the shape: none of it outside the plate)
$lip = New-Object System.Drawing.Drawing2D.GraphicsPath
$lip.AddLine((HP $xL ($first[1] - 1)), (HP $xL ($first[1] - 1))); VisorEdge $lip; $lip.AddLine((HP $xR ($last[1] - 1)), (HP $xR ($last[1] - 1)))
$bmp, $g = NewPicWH $W $H; $g.SetClip($shape); $g.DrawPath((FlatPen (2 * $LP)), $lip); SavePic $bmp $g "hood_sedan_lip"
# its shadow, down on the faces and the plate - clipped to the plate's inside
$sh, $g = NewPicWH $W $H
$g.TranslateTransform(0, (F (3 * $HK))); $g.FillPath($brush, $shape); $g.Dispose()
$bl, $g = Blur $sh (4.5 * $HK); $sh.Dispose(); $g.Dispose()
$bmp, $g = NewPicWH $W $H
$a = HP $xL $VT; $b = HP $xR ($HY + $HH)
$g.SetClip((New-Object System.Drawing.RectangleF $a.X, $a.Y, ($b.X - $a.X), ($b.Y - $a.Y)))
$g.DrawImage($bl, 0, 0, $W, $H); $bl.Dispose()
SavePic $bmp $g "hood_sedan_shadow"

# The radio ---------------------------------------------------------------------------

# its display's figures, as a VFD's seven segments, slanted: seg_<d> (and a soft
# copy seg_<d>g, their glow); every place shows a faint 8 behind (seg_8). The
# figure is 56 px high from y 4 in a 48 x 64 picture.
$SEGS = @{ "0" = "abcdef"; "1" = "bc"; "2" = "abdeg"; "3" = "abcdg"; "4" = "bcfg"; "5" = "acdfg"; "6" = "acdefg"; "7" = "abc"; "8" = "abcdefg"; "9" = "abcdfg" }
$sh = 56; $sw = $sh * 0.5; $st = $sh * 0.14; $sl = $sh * 0.1; $sx = 6; $sy = 4
$SP = @{ a = @(0, 0, $sw, 0); b = @($sw, 0, $sw, ($sh / 2)); c = @($sw, ($sh / 2), $sw, $sh); d = @(0, $sh, $sw, $sh); e = @(0, ($sh / 2), 0, $sh); f = @(0, 0, 0, ($sh / 2)); g = @(0, ($sh / 2), $sw, ($sh / 2)) }
function SegX($x, $y) { return $sx + $x + ($sh - $y) * $sl / $sh }
foreach ($digit in $SEGS.Keys) {
    $bmp, $g = NewPicWH 48 64
    $pen = Pen $st
    foreach ($s in $SEGS[$digit].ToCharArray()) {
        $q = $SP["$s"]
        $dx = $q[2] - $q[0]; $dy = $q[3] - $q[1]; $l = [Math]::Sqrt($dx * $dx + $dy * $dy); $ux = $dx / $l; $uy = $dy / $l; $cut = $st * 0.7
        $x0 = $q[0] + $ux * $cut; $y0 = $q[1] + $uy * $cut; $x1 = $q[2] - $ux * $cut; $y1 = $q[3] - $uy * $cut
        $g.DrawLine($pen, (F (SegX $x0 $y0)), (F ($sy + $y0)), (F (SegX $x1 $y1)), (F ($sy + $y1)))
    }
    $g.Dispose(); $bmp.Save((Join-Path $dir "seg_$digit.png"), [System.Drawing.Imaging.ImageFormat]::Png); $script:made += "seg_$digit"
    $gl, $g = Blur $bmp 5; $bmp.Dispose(); SavePic $gl $g "seg_${digit}g"
}
# a tape's reel: its ring, hub and three spokes (turned as it plays)
$bmp, $g = NewPic 64
$g.DrawEllipse((Pen 5), 6, 6, 52, 52); $g.FillEllipse($brush, 25, 25, 14, 14)
foreach ($a in 90, 210, 330) { $p1 = Pt 32 8 $a; $p2 = Pt 32 25 $a; $g.DrawLine((Pen 5), (F $p1[0]), (F $p1[1]), (F $p2[0]), (F $p2[1])) }
SavePic $bmp $g "reel"

# The heater: the temperature knob's scale, cold blue to hot red (in colour: these
# two keep their colours whatever the skin), and the pickup's lever's slot. The
# knob's picture covers its radius + 12 units (14 + 12 = 26): the band on 19, the
# seven places' dots on 24.
$COLD = @(115, 168, 219); $HOT = @(219, 92, 71)
function Mixc($t) { return [System.Drawing.Color]::FromArgb(255, [int]($COLD[0] + ($HOT[0] - $COLD[0]) * $t), [int]($COLD[1] + ($HOT[1] - $COLD[1]) * $t), [int]($COLD[2] + ($HOT[2] - $COLD[2]) * $t)) }
$bmp, $g = NewPic 256
$rb = 128 * 19 / 26; $wb = 128 * 2.6 / 26
for ($i = 0; $i -lt 48; $i++) {
    $a0 = -120 + 240 * $i / 48
    $pen = New-Object System.Drawing.Pen (Mixc ($i / 47)), (F $wb); $pen.StartCap = "Flat"; $pen.EndCap = "Flat"
    $g.DrawArc($pen, (F (128 - $rb)), (F (128 - $rb)), (F (2 * $rb)), (F (2 * $rb)), (F ($a0 - 90)), (F (240 / 48 + 0.6)))
}
for ($i = 0; $i -lt 7; $i++) {
    $p = Pt 128 (128 * 24 / 26) (90 - (-120 + 40 * $i))
    $col = if ($i -eq 3) { [System.Drawing.Color]::FromArgb(255, 160, 162, 154) } else { Mixc ($i / 6) }
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $col), (F ($p[0] - 5)), (F ($p[1] - 5)), 10, 10)
}
SavePic $bmp $g "temp_arc"
$bmp = New-Object System.Drawing.Bitmap 256, 8
for ($x = 0; $x -lt 256; $x++) { $c = Mixc ($x / 255); for ($y = 0; $y -lt 8; $y++) { $bmp.SetPixel($x, $y, $c) } }
$bmp.Save((Join-Path $dir "temp_track.png"), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $script:made += "temp_track"

# Smaller copies, as mipmaps are (2026-10-21: "on the mockup it is smooth, in the game
# it pixelates" - the game scales a picture down without them, and a knob's grip of
# 256 px shown at 37 came out jagged). Each picture with hard edges gets copies scaled
# down well (bicubic, filtered); the dashboard takes the one nearest the size it shows.
#   <name>_<px>     square pictures, px across (only smaller than the picture)
#   <name>_k<NN>    the dials' layers and the visor, at NN/100 px a unit (made at 2)
#   seg_<d>_h<px>   the display's figures, px high (their picture's height)
function Resample($name, $w, $h, $out) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $dir "$name.png"))
    $bmp, $g = NewPicWH ([int][Math]::Max(1, [Math]::Round($w))) ([int][Math]::Max(1, [Math]::Round($h)))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $img.Dispose()
    SavePic $bmp $g $out
}
$SQ = @(10, 13, 16, 20, 26, 34, 44, 58, 76, 100, 130, 170, 226)
$SQUARE = @("disc", "hub", "knurl", "reel", "temp_arc", "lamp_engine", "lamp_battery", "lamp_lights", "lamp_cruise", "lamp_trunk", "lamp_fuel",
    "lamp_doors", "lamp_heater", "lamp_lockc", "lamp_locko", "lamp_mix", "lamp_rpt", "lamp_rpt1",
    "key_shadow", "key_blade", "key_head", "key_groove", "key_edge")
foreach ($n in $SQUARE) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $dir "$n.png")); $base = $img.Width; $img.Dispose()
    foreach ($px in $SQ) { if ($px -lt $base) { Resample $n $px $px "${n}_$px" } }
}
$KS = @(80, 100, 133, 160)
$LAYERS = @("tach_ticks", "tach_red", "tach_glow", "speed_ticks", "speed_red", "speed_glow", "fuel_ticks", "fuel_red", "fuel_glow",
    "hood_sedan_fill", "hood_sedan_dark", "hood_sedan_lip", "hood_sedan_shadow")
foreach ($n in $LAYERS) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $dir "$n.png")); $w = $img.Width; $h = $img.Height; $img.Dispose()
    foreach ($k in $KS) { Resample $n ($w * $k / 200) ($h * $k / 200) "${n}_k$k" }
    Copy-Item (Join-Path $dir "$n.png") (Join-Path $dir "${n}_k200.png") -Force; $script:made += "${n}_k200"
}
foreach ($d in 0..9) {
    foreach ($ph in 22, 28, 36, 46) {
        Resample "seg_$d" ($ph * 48 / 64) $ph "seg_${d}_h$ph"
        Resample "seg_${d}g" ($ph * 48 / 64) $ph "seg_${d}g_h$ph"
    }
}

Write-Host ("{0} pictures in {1}" -f $script:made.Count, $dir)

# a sheet to look at: the three dials put together as in the game, the lamps
if ($sheet) {
    $W = 1360; $H = 560
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 0x18, 0x1b, 0x16))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    function Tint($name, $x, $y, $s, $r, $gg, $b) {
        $img = [System.Drawing.Image]::FromFile((Join-Path $dir "$name.png"))
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        $cm.Matrix00 = $r / 255; $cm.Matrix11 = $gg / 255; $cm.Matrix22 = $b / 255; $cm.Matrix33 = 1; $cm.Matrix44 = 1
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$s), ([int]$s)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $img.Dispose()
    }
    $k = 2   # the mockup's units, twice
    foreach ($d in @(@("tach", 110, 154, 44), @("speed", 340, 152, 60), @("fuel", 530, 158, 38))) {
        $s = $d[3] * 2 * $k; $x = $d[1] * $k - $s / 2; $y = $d[2] * $k - $s / 2
        Tint "disc" $x $y $s 0x0f 0x12 0x0e; Tint "rim" $x $y $s 0x3b 0x42 0x35
        Tint "$($d[0])_ticks" $x $y $s 0x8f 0x92 0x89; Tint "$($d[0])_red" $x $y $s 0xbe 0x46 0x3c; Tint "$($d[0])_nums" $x $y $s 0x8f 0x92 0x89
    }
    $i = 0
    foreach ($ln in "engine", "battery", "lights", "doors", "heater", "radio", "cruise", "trunk", "fuel", "note") {
        Tint "lamp_$ln" (40 + $i * 60) 490 48 0xd4 0xc3 0x8a; $i++
    }
    $g.Dispose(); $bmp.Save($sheet, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host "sheet: $sheet"
}
