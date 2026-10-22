# Icons of the context menu's options (42\media\ui\knoxicons\menu_<name>.png):
# smooth white line icons on transparent, drawn big (64 px) and scaled down in
# the game, tinted there by the option's colour (KnoxContextMenu.lua) - the same
# look as the music player's icons (make_music_icons.ps1). The author's wish,
# 2026-10-18: one Knox style for every option, the game's own pictures (item
# icons, recipe pictures) replaced.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_menu_icons.ps1 [sheet.png]
#   sheet.png (optional): all icons on the menu's dark plate, big and at menu size, to look at.

param([string]$sheet)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui\knoxicons"
New-Item -ItemType Directory -Force $dir | Out-Null
$N = 64
$white = [System.Drawing.Color]::White
$brush = New-Object System.Drawing.SolidBrush $white
$clear = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Transparent)
$script:LW = 4.5   # line width at 64 px (about 1.5 px in the menu)
$script:names = @()

function F($v) { [float]$v }
function Pen($w = $script:LW) {
    $p = New-Object System.Drawing.Pen $white, (F $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    return $p
}
function Pts($a) {
    $arr = New-Object 'System.Drawing.PointF[]' ($a.Count / 2)
    for ($i = 0; $i -lt $arr.Length; $i++) { $arr[$i] = New-Object System.Drawing.PointF (F $a[2 * $i]), (F $a[2 * $i + 1]) }
    return ,$arr
}
function Line($g, $x1, $y1, $x2, $y2, $lw = $script:LW) { $g.DrawLine((Pen $lw), (F $x1), (F $y1), (F $x2), (F $y2)) }
function Lines($g, $a, $lw = $script:LW) { $g.DrawLines((Pen $lw), (Pts $a)) }
function Shape($g, $a, $lw = $script:LW) { $g.DrawPolygon((Pen $lw), (Pts $a)) }
function Fill($g, $a) { $g.FillPolygon($brush, (Pts $a)) }
function Circle($g, $cx, $cy, $r, $lw = $script:LW) { $g.DrawEllipse((Pen $lw), (F ($cx - $r)), (F ($cy - $r)), (F (2 * $r)), (F (2 * $r))) }
function Dot($g, $cx, $cy, $r) { $g.FillEllipse($brush, (F ($cx - $r)), (F ($cy - $r)), (F (2 * $r)), (F (2 * $r))) }
function Arc($g, $cx, $cy, $r, $from, $sweep, $lw = $script:LW) {
    $g.DrawArc((Pen $lw), (F ($cx - $r)), (F ($cy - $r)), (F (2 * $r)), (F (2 * $r)), (F $from), (F $sweep))
}
function RRect($g, $x, $y, $w, $h, $r, $pw = $script:LW, [switch]$fill) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc((F $x), (F $y), (F $d), (F $d), 180, 90)
    $p.AddArc((F ($x + $w - $d)), (F $y), (F $d), (F $d), 270, 90)
    $p.AddArc((F ($x + $w - $d)), (F ($y + $h - $d)), (F $d), (F $d), 0, 90)
    $p.AddArc((F $x), (F ($y + $h - $d)), (F $d), (F $d), 90, 90)
    $p.CloseFigure()
    if ($fill) { $g.FillPath($brush, $p) } else { $g.DrawPath((Pen $pw), $p) }
}
# an arrow from (x1, y1) to (x2, y2) with an open head
function Arrow($g, $x1, $y1, $x2, $y2, $head = 10, $lw = $script:LW) {
    Line $g $x1 $y1 $x2 $y2 $lw
    $a = [Math]::Atan2($y2 - $y1, $x2 - $x1)
    foreach ($s in -1, 1) {
        $b = $a + [Math]::PI + $s * 0.62
        Line $g $x2 $y2 ($x2 + $head * [Math]::Cos($b)) ($y2 + $head * [Math]::Sin($b)) $lw
    }
}
function Drop($g, $cx, $top, $r, $lw = $script:LW, [switch]$fill) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F $cx), (F $top), (F ($cx + $r * 0.4)), (F ($top + $r * 0.9)), (F ($cx + $r)), (F ($top + $r * 1.4)), (F ($cx + $r)), (F ($top + $r * 2.1)))
    $p.AddArc((F ($cx - $r)), (F ($top + $r * 1.1)), (F (2 * $r)), (F (2 * $r)), 0, 180)
    $p.AddBezier((F ($cx - $r)), (F ($top + $r * 2.1)), (F ($cx - $r)), (F ($top + $r * 1.4)), (F ($cx - $r * 0.4)), (F ($top + $r * 0.9)), (F $cx), (F $top))
    $p.CloseFigure()
    if ($fill) { $g.FillPath($brush, $p) } else { $g.DrawPath((Pen $lw), $p) }
}
function Magnifier($g, $cx, $cy, $r) {
    Circle $g $cx $cy $r
    $d = $r * 0.72
    Line $g ($cx + $d) ($cy + $d) ($cx + $d + $r * 0.75) ($cy + $d + $r * 0.75) ($script:LW + 1.5)
}
# the shapes in a box (x, y, size) by moving and scaling the drawing
function Push($g, $x, $y, $s) { $st = $g.Save(); $g.TranslateTransform((F $x), (F $y)); $g.ScaleTransform((F $s), (F $s)); return $st }

function Icon($name, [scriptblock]$draw) {
    $bmp = New-Object System.Drawing.Bitmap $N, $N
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    & $draw $g
    $g.Dispose()
    $bmp.Save((Join-Path $dir "menu_$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $script:names += $name
}

# Shapes used by several icons --------------------------------------------------------

function Shirt($g) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLines((Pts @(24, 9, 10, 16, 6, 28, 15, 31, 17, 27, 17, 55, 47, 55, 47, 27, 49, 31, 58, 28, 54, 16, 40, 9)))
    $p.AddBezier((F 40), (F 9), (F 38), (F 17), (F 26), (F 17), (F 24), (F 9))
    $p.CloseFigure()
    $g.DrawPath((Pen), $p)
}
# a hand, palm on, fingers up; $mirror: the left one
function Hand($g, [switch]$mirror) {
    $st = $g.Save()
    if ($mirror) { $g.TranslateTransform(64, 0); $g.ScaleTransform(-1, 1) }
    RRect $g 20 30 26 26 9
    Line $g 24 31 24 14
    Line $g 31 30 31 9
    Line $g 38 30 38 11
    Line $g 45 33 45 17
    Line $g 21 44 12 33
    $g.Restore($st)
}
function Box($g, $x, $y, $w, $h) {
    Shape $g @($x, $y, ($x + $w), $y, ($x + $w), ($y + $h), $x, ($y + $h))
}
function Hammer($g) {
    Line $g 14 52 38 28 ($script:LW + 1)
    Shape $g @(30, 14, 44, 28, 50, 22, 36, 8)
    Line $g 47 25 53 31
}
function Bricks($g) {
    Box $g 8 18 48 34
    Line $g 8 29 56 29; Line $g 8 40 56 40
    Line $g 24 18 24 29; Line $g 40 18 40 29
    Line $g 16 29 16 40; Line $g 32 29 32 40; Line $g 48 29 48 40
    Line $g 24 40 24 52; Line $g 40 40 40 52
}

# Using ----------------------------------------------------------------------------

Icon "eat" {
    param($g)
    Line $g 18 8 18 20; Line $g 24 8 24 20; Line $g 30 8 30 20
    Arc $g 24 20 6 0 180
    Line $g 24 26 24 56
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLines((Pts @(44, 8, 44, 34)))
    $p.AddBezier((F 44), (F 34), (F 52), (F 32), (F 52), (F 14), (F 44), (F 8))
    $g.DrawPath((Pen), $p)
    Line $g 44 34 44 56
}
Icon "drink" {
    param($g)
    Shape $g @(14, 10, 50, 10, 45, 56, 19, 56)
    Fill $g @(17.5, 30, 46.5, 30, 44, 53, 20, 53)
}
Icon "read" {
    param($g)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 32), (F 18), (F 24), (F 12), (F 14), (F 12), (F 6), (F 14))
    $p.AddLine((F 6), (F 14), (F 6), (F 50))
    $p.AddBezier((F 6), (F 50), (F 14), (F 48), (F 24), (F 48), (F 32), (F 54))
    $p.AddBezier((F 32), (F 54), (F 40), (F 48), (F 50), (F 48), (F 58), (F 50))
    $p.AddLine((F 58), (F 50), (F 58), (F 14))
    $p.AddBezier((F 58), (F 14), (F 50), (F 12), (F 40), (F 12), (F 32), (F 18))
    $p.CloseFigure()
    $g.DrawPath((Pen), $p)
    Line $g 32 18 32 54
}
Icon "smoke" {
    param($g)
    RRect $g 6 36 44 10 3
    Line $g 38 36 38 46
    Line $g 56 36 56 46
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 48), (F 28), (F 40), (F 22), (F 54), (F 16), (F 46), (F 8))
    $g.DrawPath((Pen), $p)
}
Icon "pill" {
    param($g)
    # (turned about the middle; drawn from the box's corner - negative arguments
    # were read as parameter names and the shape broke)
    $st = $g.Save(); $g.TranslateTransform(32, 32); $g.RotateTransform(-45); $g.TranslateTransform(-24, -10)
    RRect $g 0 0 48 20 10
    Line $g 24 0 24 20
    $g.Restore($st)
}
Icon "bandage" {
    param($g)
    $st = $g.Save(); $g.TranslateTransform(32, 32); $g.RotateTransform(-45); $g.TranslateTransform(-27, -10)
    RRect $g 0 0 54 20 9
    RRect $g 18 0 18 20 2
    $g.Restore($st)
    Dot $g 29 29 1.8; Dot $g 35 35 1.8; Dot $g 35 29 1.8; Dot $g 29 35 1.8
}
Icon "cook" {
    param($g)
    RRect $g 12 28 40 24 6
    Line $g 8 23 56 23
    Line $g 6 33 12 33; Line $g 52 33 58 33
    Line $g 28 17 36 17
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 24), (F 12), (F 20), (F 8), (F 28), (F 6), (F 24), (F 2))
    $g.DrawPath((Pen 3), $p)
    $p2 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p2.AddBezier((F 40), (F 12), (F 36), (F 8), (F 44), (F 6), (F 40), (F 2))
    $g.DrawPath((Pen 3), $p2)
}
Icon "map" {
    param($g)
    Shape $g @(6, 14, 22, 8, 42, 14, 58, 8, 58, 50, 42, 56, 22, 50, 6, 56)
    Line $g 22 8 22 50; Line $g 42 14 42 56
}
Icon "magazine" {
    param($g)
    Shape $g @(22, 16, 40, 16, 46, 56, 28, 56)
    RRect $g 27 6 10 12 4
    Line $g 31 30 42 30 3; Line $g 32 40 44 40 3
}
Icon "clock" {
    param($g)
    Circle $g 32 34 22
    Line $g 32 34 32 20; Line $g 32 34 42 40
    Line $g 12 12 18 8; Line $g 52 12 46 8
}
Icon "device" {
    param($g)
    Line $g 16 10 16 54; Line $g 32 10 32 54; Line $g 48 10 48 54
    RRect $g 10 32 12 8 3 -fill; RRect $g 26 18 12 8 3 -fill; RRect $g 42 40 12 8 3 -fill
}
Icon "dry" {
    param($g)
    RRect $g 12 8 40 40 4
    Line $g 12 18 52 18
    Line $g 22 26 42 26 3; Line $g 22 34 42 34 3
    Drop $g 24 48 3 -fill; Drop $g 40 48 3 -fill
}
Icon "merge" {
    param($g)
    Line $g 12 10 32 32; Line $g 52 10 32 32
    Arrow $g 32 32 32 56
}

# Wearing and holding ------------------------------------------------------------------

Icon "hand_main" { param($g); Hand $g }
Icon "hand_off" { param($g); Hand $g -mirror }
Icon "hands" {
    param($g)
    $st = Push $g -4 10 0.66; Hand $g -mirror; $g.Restore($st)
    $st = Push $g 26 10 0.66; Hand $g; $g.Restore($st)
}
Icon "wear" { param($g); Shirt $g }
Icon "unequip" {
    param($g)
    $st = Push $g 0 10 0.8; Shirt $g; $g.Restore($st)
    Arrow $g 44 26 58 8 9
}
Icon "attach" {
    param($g)
    RRect $g 4 24 56 16 4
    RRect $g 24 18 16 28 3
    Line $g 32 26 32 38
}

# Moving -------------------------------------------------------------------------------

Icon "grab" {
    param($g)
    Lines $g @(8, 38, 8, 56, 56, 56, 56, 38)
    Arrow $g 32 46 32 6 12
}
Icon "put" {
    param($g)
    Box $g 10 30 44 26
    Line $g 10 30 4 22; Line $g 54 30 60 22
    Arrow $g 32 4 32 44 12
}
Icon "move" {
    param($g)
    Lines $g @(30, 12, 56, 12, 56, 52, 30, 52)
    Arrow $g 6 32 44 32 12
}
Icon "place" {
    param($g)
    Line $g 6 56 58 56
    Box $g 20 30 24 20
    Arrow $g 32 4 32 22 9
}
Icon "unpack" {
    param($g)
    Box $g 10 32 44 24
    Line $g 10 32 2 24; Line $g 54 32 62 24
    Arrow $g 32 46 32 6 12
}
Icon "all" {
    param($g)
    Lines $g @(12, 14, 30, 32, 12, 50)
    Lines $g @(32, 14, 50, 32, 32, 50)
}
Icon "drop" {
    param($g)
    Arrow $g 32 6 32 42 12
    Line $g 8 54 20 54; Line $g 26 54 38 54; Line $g 44 54 56 54
}

# The world's menu (2026-10-18, the author: a sink's, the ground's options had none) ---

# washing: a drop with bubbles; what is washed next to a small drop
Icon "wash" {
    param($g)
    Drop $g 26 6 14
    Circle $g 48 14 5; Circle $g 52 32 3.5; Circle $g 46 48 2.5
}
# a room's things (the author, 2026-10-18: "Rest" and a window's header had none)
Icon "rest" {
    param($g)
    # an armchair
    RRect $g 14 12 36 26 6
    Lines $g @(8, 30, 8, 48, 56, 48, 56, 30)
    Line $g 8 30 14 30; Line $g 50 30 56 30
    Line $g 12 48 12 56; Line $g 52 48 52 56
}
Icon "window" {
    param($g)
    Box $g 10 8 44 48
    Line $g 32 8 32 56; Line $g 10 32 54 32
}
Icon "curtains" {
    param($g)
    Line $g 6 8 58 8
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLines((Pts @(10, 8, 10, 56, 22, 56)))
    $p.AddBezier((F 22), (F 56), (F 18), (F 40), (F 26), (F 22), (F 26), (F 8))
    $g.DrawPath((Pen), $p)
    $q = New-Object System.Drawing.Drawing2D.GraphicsPath
    $q.AddLines((Pts @(54, 8, 54, 56, 42, 56)))
    $q.AddBezier((F 42), (F 56), (F 46), (F 40), (F 38), (F 22), (F 38), (F 8))
    $g.DrawPath((Pen), $q)
}
Icon "door" {
    param($g)
    Line $g 8 58 56 58
    Lines $g @(16, 58, 16, 6, 48, 6, 48, 58)
    Dot $g 40 34 3
}
Icon "lock" {
    param($g)
    Box $g 14 28 36 28
    Arc $g 32 26 11 180 180
    Line $g 21 26 21 28; Line $g 43 26 43 28
    Line $g 32 38 32 46
}
Icon "smash" {
    param($g)
    Box $g 8 8 48 48
    Lines $g @(30, 8, 26, 22, 36, 30, 28, 42, 34, 56)
    Lines $g @(36, 30, 56, 26); Lines $g @(26, 22, 8, 26)
}
Icon "light" {
    param($g)
    Arc $g 32 24 16 150 240
    Lines $g @(18, 32, 24, 44, 40, 44, 46, 32)
    Line $g 25 50 39 50; Line $g 28 56 36 56
}
# the world menu's header: the place clicked (a pin)
Icon "here" {
    param($g)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc((F 14), (F 6), (F 36), (F 36), 150, 240)
    $p.AddLine((F 47.6), (F 33), (F 32), (F 58))
    $p.AddLine((F 32), (F 58), (F 16.4), (F 33))
    $p.CloseFigure()
    $g.DrawPath((Pen), $p)
    Circle $g 32 24 6
}
# filling: a drop falling into an open jar (the author, 2026-10-18: a sink's "Fill" had none)
Icon "fill" {
    param($g)
    Lines $g @(14, 30, 18, 58, 46, 58, 50, 30)
    Line $g 10 30 54 30
    Line $g 20 46 44 46
    Drop $g 32 2 7 -fill
}
Icon "wash_self" {
    param($g)
    Circle $g 26 20 10
    Arc $g 26 62 22 200 140
    Drop $g 50 6 6 -fill
}
Icon "wash_clothes" {
    param($g)
    $st = Push $g 0 10 0.8; Shirt $g; $g.Restore($st)
    Drop $g 52 2 6 -fill
}
Icon "wash_bandages" {
    param($g)
    # a bandage and a drop (the author, 2026-10-19: "All bandages" had none)
    $st = $g.Save(); $g.TranslateTransform(28, 36); $g.RotateTransform(-45); $g.TranslateTransform(-22, -8)
    RRect $g 0 0 44 16 7
    RRect $g 15 0 14 16 2
    $g.Restore($st)
    Drop $g 52 2 6 -fill
}
# a curtain taken down: the rail, one curtain folded over the arm, an arrow down
Icon "curtains_off" {
    param($g)
    Line $g 6 8 58 8
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLines((Pts @(10, 8, 10, 48, 22, 48)))
    $p.AddBezier((F 22), (F 48), (F 18), (F 34), (F 26), (F 20), (F 26), (F 8))
    $g.DrawPath((Pen), $p)
    Arrow $g 46 18 46 54 9
}
Icon "wash_containers" {
    param($g)
    Shape $g @(10, 26, 44, 26, 39, 58, 15, 58)
    Arc $g 27 26 15 180 180
    Drop $g 54 6 6 -fill
}
Icon "wash_weapons" {
    param($g)
    # a knife: the handle, the guard, the blade to its point (a plain bar read as a pencil)
    Line $g 9 55 19 45 ($script:LW + 3)
    Line $g 15 37 27 49
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLines((Pts @(21, 43, 48, 16)))
    $p.AddBezier((F 48), (F 16), (F 52), (F 22), (F 44), (F 34), (F 25), (F 47))
    $p.CloseFigure()
    $g.DrawPath((Pen), $p)
    Drop $g 52 2 6 -fill
}
Icon "sleep" {
    param($g)
    Line $g 6 24 6 56; Line $g 6 46 58 46; Line $g 58 46 58 56
    RRect $g 10 34 14 10 3
    Lines $g @(28, 46, 28, 38, 58, 38, 58, 46)
    Lines $g @(38, 8, 50, 8, 38, 22, 50, 22)
}
Icon "sit" {
    param($g)
    Circle $g 28 10 6
    Lines $g @(28, 17, 28, 38, 46, 38, 46, 56)
    Line $g 28 25 40 31
    Line $g 6 56 58 56
}
Icon "walk" {
    param($g)
    Circle $g 34 9 6
    Line $g 33 16 29 36
    Lines $g @(29, 36, 21, 56)
    Lines $g @(29, 36, 40, 45, 38, 56)
    Lines $g @(32, 22, 22, 31); Lines $g @(32, 22, 44, 29)
}
Icon "glass" {
    param($g)
    Shape $g @(8, 54, 20, 18, 30, 54)
    Shape $g @(32, 56, 44, 30, 56, 56)
    Line $g 46 8 46 18; Line $g 41 13 51 13
}

# Fluids -------------------------------------------------------------------------------

Icon "pour" {
    param($g)
    $st = $g.Save(); $g.TranslateTransform(26, 24); $g.RotateTransform(-35)
    Shape $g @(-14, -14, 14, -14, 11, 20, -11, 20)
    $g.Restore($st)
    Drop $g 46 34 4 -fill; Drop $g 54 46 3 -fill
}
Icon "fluid_info" {
    param($g)
    Drop $g 32 4 20
    Dot $g 32 32 3
    Line $g 32 40 32 52
}
Icon "fluid_move" {
    param($g)
    Drop $g 14 12 9
    Drop $g 50 12 9
    Arrow $g 24 46 42 46 8
}

# Looking -------------------------------------------------------------------------------

Icon "inspect" {
    param($g)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 4), (F 32), (F 16), (F 12), (F 48), (F 12), (F 60), (F 32))
    $p.AddBezier((F 60), (F 32), (F 48), (F 52), (F 16), (F 52), (F 4), (F 32))
    $p.CloseFigure()
    $g.DrawPath((Pen), $p)
    Circle $g 32 32 9
    Dot $g 32 32 3.5
}
Icon "more" { param($g); Dot $g 14 32 5; Dot $g 32 32 5; Dot $g 50 32 5 }
Icon "rename" {
    param($g)
    $st = $g.Save(); $g.TranslateTransform(32, 32); $g.RotateTransform(-45)
    Shape $g @(-20, -7, 16, -7, 16, 7, -20, 7)
    Shape $g @(16, -7, 28, 0, 16, 7)
    Line $g -10 -7 -10 7
    $g.Restore($st)
}
Icon "star" {
    param($g)
    $a = @()
    for ($i = 0; $i -lt 10; $i++) {
        $r = if ($i % 2 -eq 0) { 26 } else { 11 }
        $t = -[Math]::PI / 2 + $i * [Math]::PI / 5
        $a += 32 + $r * [Math]::Cos($t); $a += 34 + $r * [Math]::Sin($t)
    }
    Shape $g $a
}
Icon "sort" {
    param($g)
    Line $g 8 14 40 14; Line $g 8 28 32 28; Line $g 8 42 24 42; Line $g 8 56 16 56
    Arrow $g 52 10 52 54 9
}

# a lamp's bulb taken out / put in (the author, 2026-10-22: "Remove light bulb" had none)
function Bulb($g) {
    Arc $g 26 26 14 150 240
    Lines $g @(13.9, 33, 19, 43, 33, 43, 38.1, 33)
    Line $g 20 49 32 49; Line $g 22 55 30 55
}
Icon "bulb_out" { param($g); Bulb $g; Arrow $g 42 22 58 6 9 }
Icon "bulb_in" { param($g); Bulb $g; Arrow $g 58 6 44 20 9 }

# a generator to the house and off it (the author, 2026-10-22: its options had none):
# a plug, its two pins, its cord; the arrow - in or out
function Plug($g) {
    RRect $g 10 24 28 22 4
    Line $g 18 10 18 24; Line $g 30 10 30 24
    Line $g 24 46 24 58
}
Icon "plug_in" { param($g); Plug $g; Arrow $g 52 42 52 10 9 }
Icon "plug_out" { param($g); Plug $g; Arrow $g 52 10 52 42 9 }

# the ground's gardening and an item marked unwanted (the author, 2026-10-22: none)
Icon "garden" {
    param($g)
    # a sprout from the soil: a stem, two leaves, the ground's line
    Line $g 8 56 56 56
    Line $g 32 56 32 24
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 32), (F 34), (F 18), (F 34), (F 10), (F 24), (F 10), (F 14))
    $p.AddBezier((F 10), (F 14), (F 24), (F 14), (F 32), (F 22), (F 32), (F 34))
    $g.DrawPath((Pen), $p)
    $q = New-Object System.Drawing.Drawing2D.GraphicsPath
    $q.AddBezier((F 32), (F 26), (F 44), (F 26), (F 54), (F 18), (F 54), (F 6))
    $q.AddBezier((F 54), (F 6), (F 42), (F 6), (F 32), (F 14), (F 32), (F 26))
    $g.DrawPath((Pen), $q)
}
Icon "unwanted" {
    param($g)
    # a bin: its lid and handle, the body narrowing down, two ribs
    Line $g 8 16 56 16
    Lines $g @(24, 16, 26, 8, 38, 8, 40, 16)
    Shape $g @(14, 16, 50, 16, 46, 58, 18, 58)
    Line $g 26 26 27 48; Line $g 38 26 37 48
}

# a grid's header menu (the author, 2026-10-22: the bag's menu had no icons)
function Grid3($g) {
    Box $g 8 8 40 40
    Line $g 21.3 8 21.3 48; Line $g 34.6 8 34.6 48
    Line $g 8 21.3 48 21.3; Line $g 8 34.6 48 34.6
}
Icon "sort_rule" {
    param($g)
    Dot $g 10 14 3.5; Line $g 20 14 56 14
    Dot $g 10 32 3.5; Line $g 20 32 48 32
    Dot $g 10 50 3.5; Line $g 20 50 40 50
}
Icon "layout_save" { param($g); Grid3 $g; Lines $g @(36, 50, 44, 58, 60, 40) }
Icon "layout_forget" { param($g); Grid3 $g; Line $g 40 42 58 60; Line $g 58 42 40 60 }
Icon "move_top" { param($g); Line $g 10 8 54 8; Arrow $g 32 58 32 18 12 }
Icon "move_up" { param($g); Arrow $g 32 56 32 10 12 }
Icon "move_down" { param($g); Arrow $g 32 8 32 54 12 }
# the rules of Sort
Icon "rule_zones" {
    param($g)
    Box $g 6 6 24 24; Box $g 34 6 24 24
    Box $g 6 34 24 24; Dot $g 46 46 6
}
Icon "rule_dense" {
    param($g)
    Box $g 6 6 52 52
    RRect $g 12 12 18 18 2 -fill; RRect $g 34 12 18 18 2 -fill
    RRect $g 12 34 18 18 2 -fill; RRect $g 34 34 18 18 2 -fill
}
Icon "rule_name" {
    param($g)
    Lines $g @(6, 52, 18, 12, 30, 52); Line $g 10 38 26 38
    Arrow $g 46 10 46 54 9
}
Icon "rule_weight" {
    param($g)
    # a weight: a trapezoid with a ring on top
    Circle $g 32 14 7
    Shape $g @(18, 24, 46, 24, 56, 56, 8, 56)
}

# Making ---------------------------------------------------------------------------------

Icon "craft" { param($g); Hammer $g }
Icon "recipes" {
    param($g)
    RRect $g 12 10 40 48 4
    RRect $g 23 5 18 10 3
    Line $g 21 28 43 28; Line $g 21 38 43 38; Line $g 21 48 35 48
}
Icon "craft_search" {
    param($g)
    $st = Push $g -2 12 0.78; Hammer $g; $g.Restore($st)
    Magnifier $g 42 20 12
}
Icon "build_search" {
    param($g)
    $st = Push $g -2 14 0.72; Bricks $g; $g.Restore($st)
    Magnifier $g 44 20 12
}
Icon "repair" {
    param($g)
    # a wrench: the handle into a ring open at the top right
    Line $g 12 52 34 30 ($script:LW + 2)
    Arc $g 43 21 12 330 300 ($script:LW + 1)
}
Icon "sew" {
    param($g)
    Line $g 12 52 48 16
    Circle $g 50 14 4 3
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 52), (F 18), (F 58), (F 40), (F 30), (F 34), (F 30), (F 58))
    $g.DrawPath((Pen 3), $p)
}

# Recipes (the options of an item's "Interact" sub menu, by what the recipe does) --------

Icon "rip" {
    param($g)
    # cloth torn in two, the halves apart
    Shape $g @(6, 12, 28, 12, 24, 20, 30, 28, 22, 36, 28, 44, 24, 52, 6, 52)
    Shape $g @(36, 12, 58, 12, 58, 52, 34, 52, 38, 44, 32, 36, 40, 28, 34, 20, 38, 12)
}
Icon "rope" {
    param($g)
    Circle $g 30 30 22
    Circle $g 30 30 13
    Circle $g 30 30 4 3
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 46), (F 46), (F 52), (F 52), (F 56), (F 50), (F 60), (F 58))
    $g.DrawPath((Pen), $p)
}
Icon "bag" {
    param($g)
    RRect $g 12 18 40 40 9
    Arc $g 32 18 10 180 180
    RRect $g 20 36 24 14 4
    Line $g 12 30 52 30
}
Icon "open" {
    param($g)
    # a can, its lid lifted on a hinge
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLine((F 12), (F 30), (F 12), (F 54))
    $p.AddArc((F 12), (F 48), (F 40), (F 12), 180, -180)
    $p.AddLine((F 52), (F 54), (F 52), (F 30))
    $g.DrawPath((Pen), $p)
    $g.DrawEllipse((Pen), (F 12), (F 24), (F 40), (F 12))
    $st = $g.Save(); $g.TranslateTransform(12, 26); $g.RotateTransform(-38)
    $g.DrawEllipse((Pen), (F 0), (F -12), (F 40), (F 12))
    $g.Restore($st)
}
Icon "dismantle" {
    param($g)
    # a screwdriver
    $st = $g.Save(); $g.TranslateTransform(32, 32); $g.RotateTransform(45); $g.TranslateTransform(-8, -28)
    RRect $g 0 0 16 24 5
    Line $g 8 24 8 50
    Line $g 4 54 12 54
    $g.Restore($st)
}

# autodrink on / off: a drop inside a round arrow (it drinks by itself, again and again)
Icon "autodrink" {
    param($g)
    Drop $g 32 18 9
    Arc $g 32 32 25 -60 300
    $a = -60 * [Math]::PI / 180
    $ex, $ey = (32 + 25 * [Math]::Cos($a)), (32 + 25 * [Math]::Sin($a))
    Line $g $ex $ey ($ex - 10) ($ey - 2)
    Line $g $ex $ey ($ex + 2) ($ey + 10)
}

# what else a recipe takes (under its name in the menu): a toolbox
Icon "needs" {
    param($g)
    RRect $g 6 24 52 30 4
    Lines $g @(22, 24, 22, 14, 42, 14, 42, 24)
    Line $g 6 36 58 36
    RRect $g 27 32 10 8 2 -fill
}

# The health tab (KnoxHealthCare: the body part menus' treatments, their headers) ----------

Icon "heal" {
    param($g)
    # a medical cross: quick treatment
    Shape $g @(24, 8, 40, 8, 40, 24, 56, 24, 56, 40, 40, 40, 40, 56, 24, 56, 24, 40, 8, 40, 8, 24, 24, 24)
}
Icon "disinfect" {
    param($g)
    # a bottle with a cross on its label
    RRect $g 26 4 12 8 2
    Lines $g @(26, 12, 26, 18, 16, 26, 16, 56, 48, 56, 48, 26, 38, 18, 38, 12)
    Line $g 32 31 32 47 4; Line $g 24 39 40 39 4
}
Icon "unbandage" {
    param($g)
    # a bandage lifted off, an arrow away from the skin
    $st = $g.Save(); $g.TranslateTransform(26, 38); $g.RotateTransform(-45); $g.TranslateTransform(-20, -8)
    RRect $g 0 0 40 16 7
    RRect $g 13 0 14 16 2
    $g.Restore($st)
    Arrow $g 40 24 56 8 9
}
Icon "splint" {
    param($g)
    # two boards along a limb, two straps round them
    RRect $g 14 6 10 52 3
    RRect $g 40 6 10 52 3
    Line $g 10 20 54 20; Line $g 10 44 54 44
}
Icon "tweezers" {
    param($g)
    Lines $g @(30, 6, 18, 50, 22, 56)
    Lines $g @(34, 6, 46, 50, 42, 56)
    Line $g 28 6 36 6
}
Icon "burn" {
    param($g)
    # a flame
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 32), (F 4), (F 36), (F 18), (F 52), (F 26), (F 50), (F 42))
    $p.AddBezier((F 50), (F 42), (F 48), (F 54), (F 40), (F 58), (F 32), (F 58))
    $p.AddBezier((F 32), (F 58), (F 22), (F 58), (F 14), (F 52), (F 14), (F 42))
    $p.AddBezier((F 14), (F 42), (F 14), (F 32), (F 22), (F 28), (F 24), (F 20))
    $p.AddBezier((F 24), (F 20), (F 28), (F 26), (F 28), (F 30), (F 30), (F 32))
    $p.AddBezier((F 30), (F 32), (F 34), (F 24), (F 34), (F 14), (F 32), (F 4))
    $p.CloseFigure()
    $g.DrawPath((Pen), $p)
}
Icon "poultice" {
    param($g)
    # a leaf, its vein
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddBezier((F 10), (F 54), (F 8), (F 26), (F 28), (F 8), (F 56), (F 8))
    $p.AddBezier((F 56), (F 8), (F 56), (F 36), (F 38), (F 56), (F 10), (F 54))
    $p.CloseFigure()
    $g.DrawPath((Pen), $p)
    Line $g 10 54 42 22 3.5
}
Icon "unstitch" {
    param($g)
    # stitches being cut: a stitched line and scissors' blades
    Line $g 6 46 34 46 3.5
    Line $g 10 40 10 52 3; Line $g 18 40 18 52 3; Line $g 26 40 26 52 3
    Circle $g 44 16 6; Circle $g 54 30 6
    Line $g 40 21 30 40; Line $g 48 32 30 40
}
Icon "unsplint" {
    param($g)
    RRect $g 12 14 9 44 3
    RRect $g 36 14 9 44 3
    Line $g 8 34 49 34
    Arrow $g 48 22 58 6 8
}
# the body's zones (a body part menu's header)
Icon "zone_head" {
    param($g)
    Circle $g 32 24 15
    Line $g 26 40 26 50; Line $g 38 40 38 50
    Lines $g @(12, 58, 18, 52, 46, 52, 52, 58)
}
Icon "zone_thorax" {
    param($g)
    # the rib cage
    Lines $g @(14, 10, 10, 30, 14, 54); Lines $g @(50, 10, 54, 30, 50, 54)
    Line $g 32 8 32 50
    Arc $g 32 22 14 200 140 3.5; Arc $g 32 32 16 200 140 3.5; Arc $g 32 42 16 200 140 3.5
}
Icon "zone_stomach" {
    param($g)
    # the belly down to the hips, the navel
    Lines $g @(16, 6, 14, 26, 10, 44, 12, 58)
    Lines $g @(48, 6, 50, 26, 54, 44, 52, 58)
    Lines $g @(12, 58, 32, 50, 52, 58)
    Dot $g 32 30 3
}
Icon "zone_arm" {
    param($g)
    # an arm hanging down: the shoulder, the elbow, the hand
    Circle $g 20 10 6
    Lines $g @(14, 14, 18, 32, 30, 48)
    Lines $g @(26, 12, 28, 30, 38, 42)
    RRect $g 30 42 16 16 6
}
Icon "zone_leg" {
    param($g)
    # the thigh, the knee, the shin, the foot
    Lines $g @(18, 4, 20, 26, 24, 50, 22, 58, 50, 58, 48, 52, 38, 48, 36, 26, 40, 4)
    Arc $g 29 27 5 0 360 3
}

Write-Host ("{0} icons in {1}" -f $script:names.Count, $dir)

# The sheet: each icon big and at menu size, on the menu's plate, in Knox's text colour
if ($sheet) {
    $cols = 8
    $cw, $ch = 120, 120
    $rows = [Math]::Ceiling($script:names.Count / $cols)
    $bmp = New-Object System.Drawing.Bitmap ($cols * $cw), ($rows * $ch)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 0x12, 0x14, 0x14))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $font = New-Object System.Drawing.Font "Arial", 10, ([System.Drawing.GraphicsUnit]::Pixel)
    $tb = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0x8f, 0x92, 0x89))
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = 0xd9 / 255; $cm.Matrix11 = 0xd6 / 255; $cm.Matrix22 = 0xc8 / 255; $cm.Matrix33 = 1; $cm.Matrix44 = 1
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    $ia.SetColorMatrix($cm)
    for ($i = 0; $i -lt $script:names.Count; $i++) {
        $n = $script:names[$i]
        $x = ($i % $cols) * $cw; $y = [Math]::Floor($i / $cols) * $ch
        $img = [System.Drawing.Image]::FromFile((Join-Path $dir "menu_$n.png"))
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle ($x + 8), ($y + 8), 64, 64), 0, 0, 64, 64, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle ($x + 84), ($y + 30), 22, 22), 0, 0, 64, 64, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $img.Dispose()
        $g.DrawString($n, $font, $tb, (F ($x + 8)), (F ($y + 98)))
    }
    $g.Dispose()
    $bmp.Save($sheet, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "sheet: $sheet"
}
