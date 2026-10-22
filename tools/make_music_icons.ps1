# The menu music player's icons (42\media\ui\knox_music_<name>.png): smooth white
# shapes on transparent, anti-aliased, drawn big (64 px) and scaled down in the
# game, tinted there (KnoxMenuMusic.lua). Drawn of rectangles 1 px at a time they
# came out jagged - the author, 2026-10-15 (as the favourite's star: make_star.ps1).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_music_icons.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui"
$N = 64
$white = [System.Drawing.Color]::White

function NewIcon {
    $bmp = New-Object System.Drawing.Bitmap $N, $N
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    return @($bmp, $g)
}
function SaveIcon($bmp, $g, $name) {
    $g.Dispose()
    $bmp.Save((Join-Path $dir "knox_music_$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  knox_music_$name.png"
}
function Pen($w) {
    $p = New-Object System.Drawing.Pen $white, ([float]$w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    return $p
}
$brush = New-Object System.Drawing.SolidBrush $white
function Poly($g, $pts) {
    $arr = New-Object 'System.Drawing.PointF[]' ($pts.Count / 2)
    for ($i = 0; $i -lt $arr.Length; $i++) { $arr[$i] = New-Object System.Drawing.PointF ([float]$pts[2 * $i]), ([float]$pts[2 * $i + 1]) }
    $g.FillPolygon($brush, $arr)
}
function RoundRect($g, $x, $y, $w, $h, $r, $pen) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc([float]$x, [float]$y, [float]$d, [float]$d, 180, 90)
    $p.AddArc([float]($x + $w - $d), [float]$y, [float]$d, [float]$d, 270, 90)
    $p.AddArc([float]($x + $w - $d), [float]($y + $h - $d), [float]$d, [float]$d, 0, 90)
    $p.AddArc([float]$x, [float]($y + $h - $d), [float]$d, [float]$d, 90, 90)
    $p.CloseFigure()
    if ($pen) { $g.DrawPath($pen, $p) } else { $g.FillPath($brush, $p) }
}

# play: a triangle with softened corners
$bmp, $g = NewIcon
$tri = New-Object System.Drawing.Drawing2D.GraphicsPath
$tri.AddPolygon([System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 18, 10), (New-Object System.Drawing.PointF 52, 32), (New-Object System.Drawing.PointF 18, 54)))
$g.FillPath($brush, $tri); $g.DrawPath((Pen 5), $tri)
SaveIcon $bmp $g "play"

# pause: two rounded bars
$bmp, $g = NewIcon
RoundRect $g 16 12 11 40 4 $null
RoundRect $g 37 12 11 40 4 $null
SaveIcon $bmp $g "pause"

# next / prev: a triangle and a bar
foreach ($dirName in "next", "prev") {
    $bmp, $g = NewIcon
    $t = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($dirName -eq "next") {
        $t.AddPolygon([System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 12, 14), (New-Object System.Drawing.PointF 40, 32), (New-Object System.Drawing.PointF 12, 50)))
        RoundRect $g 43 14 8 36 3 $null
    } else {
        $t.AddPolygon([System.Drawing.PointF[]]@((New-Object System.Drawing.PointF 52, 14), (New-Object System.Drawing.PointF 24, 32), (New-Object System.Drawing.PointF 52, 50)))
        RoundRect $g 13 14 8 36 3 $null
    }
    $g.FillPath($brush, $t); $g.DrawPath((Pen 4), $t)
    SaveIcon $bmp $g $dirName
}

# shuffle: two crossing arrows
$bmp, $g = NewIcon
$p = Pen 5
$g.DrawBezier($p, 8, 18, 26, 18, 34, 46, 50, 46)
$g.DrawBezier($p, 8, 46, 26, 46, 34, 18, 50, 18)
Poly $g @(46, 9, 58, 18, 46, 27)
Poly $g @(46, 37, 58, 46, 46, 55)
SaveIcon $bmp $g "shuffle"

# repeat (and repeat one): a rounded loop with two arrow heads
foreach ($one in $false, $true) {
    $bmp, $g = NewIcon
    $p = Pen 5
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(8, 16, 16, 16, 180, 90); $path.AddLine(16, 16, 46, 16)
    $g.DrawPath($p, $path)
    $path2 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path2.AddArc(40, 32, 16, 16, 0, 90); $path2.AddLine(48, 48, 18, 48)
    $g.DrawPath($p, $path2)
    $g.DrawLine($p, 8, 24, 8, 30)
    $g.DrawLine($p, 56, 40, 56, 34)
    Poly $g @(44, 7, 56, 16, 44, 25)
    Poly $g @(20, 39, 8, 48, 20, 57)
    if ($one) {
        $f = New-Object System.Drawing.Font "Arial", 15, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = "Center"; $sf.LineAlignment = "Center"
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.DrawString("1", $f, $brush, (New-Object System.Drawing.RectangleF 22, 22, 20, 20), $sf)
    }
    SaveIcon $bmp $g $(if ($one) { "repeat_one" } else { "repeat" })
}

# radio: a body with a grille, a dial and an aerial
$bmp, $g = NewIcon
$p = Pen 4
RoundRect $g 6 24 52 32 6 $p
foreach ($y in 33, 40, 47) { $g.DrawLine($p, 14, $y, 32, $y) }
$g.DrawEllipse($p, 38, 32, 14, 14)
$g.DrawLine($p, 44, 24, 30, 6)
$g.FillEllipse($brush, 26, 2, 8, 8)
SaveIcon $bmp $g "radio"

# folder: the player's own music folder (opened in the system's file manager)
$bmp, $g = NewIcon
$p = Pen 4
$fp = New-Object System.Drawing.Drawing2D.GraphicsPath
$fp.AddLine(8, 18, 24, 18); $fp.AddLine(24, 18, 29, 24); $fp.AddLine(29, 24, 56, 24)
$fp.AddLine(56, 24, 56, 52); $fp.AddLine(56, 52, 8, 52); $fp.CloseFigure()
$g.DrawPath($p, $fp)
$g.DrawLine($p, 8, 30, 56, 30)
SaveIcon $bmp $g "folder"

# speaker with 0..3 waves
for ($w = 0; $w -le 3; $w++) {
    $bmp, $g = NewIcon
    Poly $g @(6, 24, 16, 24, 30, 11, 30, 53, 16, 40, 6, 40)
    $p = Pen 4
    for ($i = 1; $i -le $w; $i++) {
        $r = 6 + $i * 8
        $g.DrawArc($p, [float](30 - $r), [float](32 - $r), [float](2 * $r), [float](2 * $r), -45, 90)
    }
    if ($w -eq 0) { $g.DrawLine($p, 40, 24, 56, 40); $g.DrawLine($p, 56, 24, 40, 40) }
    SaveIcon $bmp $g "vol$w"
}
