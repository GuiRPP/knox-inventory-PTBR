# Draws the cog of the Knox screen's settings button: 42\media\ui\knox_gear.png
# (white on transparent, smooth; the game tints it). Also tools\art\gear_preview.png.
param([int]$Size = 96, [int]$Teeth = 8)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$bmp = New-Object Drawing.Bitmap $Size, $Size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([Drawing.Color]::Transparent)
$c = $Size / 2.0
$rOut = $Size * 0.46; $rIn = $Size * 0.35; $rHole = $Size * 0.15
# the outline: for every tooth, a flat top between two slopes, then the valley
$pts = New-Object System.Collections.Generic.List[Drawing.PointF]
$step = 2 * [math]::PI / $Teeth
for ($i = 0; $i -lt $Teeth; $i++) {
    $a = $i * $step
    foreach ($q in @(@(-0.30, $rIn), @(-0.17, $rOut), @(0.17, $rOut), @(0.30, $rIn))) {
        $ang = $a + $q[0] * $step
        $pts.Add((New-Object Drawing.PointF ([single]($c + $q[1] * [math]::Cos($ang))), ([single]($c + $q[1] * [math]::Sin($ang)))))
    }
}
$path = New-Object Drawing.Drawing2D.GraphicsPath
$path.AddPolygon($pts.ToArray())
$path.AddEllipse([single]($c - $rHole), [single]($c - $rHole), [single]($rHole * 2), [single]($rHole * 2))   # the hole (even-odd fill)
$g.FillPath([Drawing.Brushes]::White, $path)
$g.Dispose()
$out = Join-Path $root '42\media\ui\knox_gear.png'
$bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png)

$art = Join-Path $root 'tools\art'
if (-not (Test-Path $art)) { New-Item -ItemType Directory -Force $art | Out-Null }
$pv = New-Object Drawing.Bitmap 120, 120
$g = [Drawing.Graphics]::FromImage($pv)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([Drawing.Color]::FromArgb(26, 29, 29))
$g.DrawRectangle((New-Object Drawing.Pen ([Drawing.Color]::FromArgb(60, 65, 65))), 40, 40, 40, 40)
$attr = New-Object Drawing.Imaging.ImageAttributes
$cm = New-Object Drawing.Imaging.ColorMatrix
$cm.Matrix00 = 0.85; $cm.Matrix11 = 0.84; $cm.Matrix22 = 0.78
$attr.SetColorMatrix($cm)
$g.DrawImage($bmp, (New-Object Drawing.Rectangle 47, 47, 26, 26), 0, 0, $bmp.Width, $bmp.Height, [Drawing.GraphicsUnit]::Pixel, $attr)
$g.Dispose()
$pv.Save((Join-Path $art 'gear_preview.png'), [Drawing.Imaging.ImageFormat]::Png)
"gear -> $out"
