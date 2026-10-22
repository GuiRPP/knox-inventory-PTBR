# Draws the magnifier of the Knox screen's search field: 42\media\ui\knox_lens.png
# (white on transparent, smooth; the game tints it) - as make_gear.ps1 does the cog.
# Also tools\art\lens_preview.png (the picture at its size in game, on the field's dark).
param([int]$Size = 96)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$bmp = New-Object Drawing.Bitmap $Size, $Size, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([Drawing.Color]::Transparent)
# the ring: its middle up and left, so that the handle has room towards the corner
$stroke = $Size * 0.11
$r = $Size * 0.30
$cx = $Size * 0.40; $cy = $Size * 0.40
$pen = New-Object Drawing.Pen ([Drawing.Color]::White), ([single]$stroke)
$g.DrawEllipse($pen, [single]($cx - $r), [single]($cy - $r), [single]($r * 2), [single]($r * 2))
# the handle: a thicker bar with round ends, from the ring's edge to the corner
$hp = New-Object Drawing.Pen ([Drawing.Color]::White), ([single]($stroke * 1.25))
$hp.StartCap = [Drawing.Drawing2D.LineCap]::Round
$hp.EndCap = [Drawing.Drawing2D.LineCap]::Round
$k = [math]::Sqrt(0.5)
$x0 = $cx + ($r + $stroke * 0.35) * $k; $y0 = $cy + ($r + $stroke * 0.35) * $k
$x1 = $Size * 0.88; $y1 = $Size * 0.88
$g.DrawLine($hp, [single]$x0, [single]$y0, [single]$x1, [single]$y1)
$g.Dispose()
$out = Join-Path $root '42\media\ui\knox_lens.png'
$bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png)

$art = Join-Path $root 'tools\art'
if (-not (Test-Path $art)) { New-Item -ItemType Directory -Force $art | Out-Null }
$pv = New-Object Drawing.Bitmap 120, 60
$g = [Drawing.Graphics]::FromImage($pv)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([Drawing.Color]::FromArgb(14, 15, 15))
$attr = New-Object Drawing.Imaging.ImageAttributes
$cm = New-Object Drawing.Imaging.ColorMatrix
$cm.Matrix00 = 0.91; $cm.Matrix11 = 0.79; $cm.Matrix22 = 0.54
$attr.SetColorMatrix($cm)
foreach ($s in @(14, 18, 24)) {
    $x = @{14 = 8; 18 = 32; 24 = 62}[$s]
    $g.DrawImage($bmp, (New-Object Drawing.Rectangle $x, (30 - [int]($s / 2)), $s, $s), 0, 0, $bmp.Width, $bmp.Height, [Drawing.GraphicsUnit]::Pixel, $attr)
}
$g.Dispose()
$pv.Save((Join-Path $art 'lens_preview.png'), [Drawing.Imaging.ImageFormat]::Png)
"lens -> $out"
