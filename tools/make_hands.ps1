# Draws the two open-palm pictures of the hotbar's empty hand tiles:
# 42\media\ui\knox_hand_right.png and knox_hand_left.png (white on transparent,
# smooth; the game tints them grey). The right hand leans to the right, the
# left one is its mirror. Also writes tools\art\hands_preview.png to look at.
param([double]$Tilt = 14, [int]$Size = 128)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ui = Join-Path $root '42\media\ui'

function New-Hand([bool]$right) {
    $bmp = New-Object Drawing.Bitmap $Size, $Size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([Drawing.Color]::Transparent)
    # drawn on a 128 grid, thumb on the left; mirrored for the left hand, then leaned outwards
    $k = $Size / 128.0
    $g.TranslateTransform($Size / 2, $Size / 2)
    if (-not $right) { $g.ScaleTransform(-1, 1) }
    $g.RotateTransform($Tilt)
    $g.ScaleTransform($k * 0.9, $k * 0.9)
    $g.TranslateTransform(-64, -64)
    $white = [Drawing.Color]::White
    $brush = New-Object Drawing.SolidBrush $white
    function Finger([double]$x1, [double]$y1, [double]$x2, [double]$y2, [double]$w) {
        $pen = New-Object Drawing.Pen $white, $w
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($pen, [single]$x1, [single]$y1, [single]$x2, [single]$y2)
        $pen.Dispose()
    }
    # palm: a rounded block
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $x, $y, $w, $h, $r = 38.0, 62.0, 64.0, 52.0, 20.0
    $path.AddArc($x, $y, $r * 2, $r * 2, 180, 90)
    $path.AddArc($x + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
    $path.AddArc($x + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90)
    $path.AddArc($x, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
    # fingers, slightly fanned: index, middle, ring, little
    Finger 46 74 43 28 13
    Finger 62 72 62 17 13
    Finger 78 72 81 24 13
    Finger 94 76 100 42 12
    # thumb
    Finger 46 96 22 66 15
    $g.Dispose()
    return $bmp
}

$r = New-Hand $true
$l = New-Hand $false
$r.Save((Join-Path $ui 'knox_hand_right.png'), [Drawing.Imaging.ImageFormat]::Png)
$l.Save((Join-Path $ui 'knox_hand_left.png'), [Drawing.Imaging.ImageFormat]::Png)

# preview: as on the hotbar - left hand's tile on the left, grey on a dark tile
$art = Join-Path $root 'tools\art'
if (-not (Test-Path $art)) { New-Item -ItemType Directory -Force $art | Out-Null }
$pv = New-Object Drawing.Bitmap 320, 160
$g = [Drawing.Graphics]::FromImage($pv)
$g.Clear([Drawing.Color]::FromArgb(18, 20, 20))
$attr = New-Object Drawing.Imaging.ImageAttributes
$cm = New-Object Drawing.Imaging.ColorMatrix
$cm.Matrix00 = 0.36; $cm.Matrix11 = 0.39; $cm.Matrix22 = 0.39
$attr.SetColorMatrix($cm)
$i = 0
foreach ($b in @($l, $r)) {
    $x = 20 + $i * 150
    $g.FillRectangle((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(14, 16, 16))), $x, 15, 130, 130)
    $g.DrawRectangle((New-Object Drawing.Pen ([Drawing.Color]::FromArgb(60, 65, 65))), $x, 15, 130, 130)
    $g.DrawImage($b, (New-Object Drawing.Rectangle ($x + 20), 35, 90, 90), 0, 0, $b.Width, $b.Height, [Drawing.GraphicsUnit]::Pixel, $attr)
    $i++
}
$g.Dispose()
$pv.Save((Join-Path $art 'hands_preview.png'), [Drawing.Imaging.ImageFormat]::Png)
"hands -> $ui ; preview -> $(Join-Path $art 'hands_preview.png')"
