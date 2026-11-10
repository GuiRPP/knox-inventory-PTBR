# The chamber's pointed part of the menu on R (42\media\ui\knox_chamber_<h>.png, the
# author's choice G in ammo_rw.html, 2026-10-31): a part of the scale with a pointed end,
# a round lying on its side - white on transparent, anti-aliased, drawn 1:1 in its colour
# (KnoxRMenu). One picture per height of the scale, as the mockup's 18 x 5: 12 straight,
# 6 to the point.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_chamber.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui"
foreach ($h in 4..12) {
    $w = [int][math]::Round($h * 3.6)
    $body = [int][math]::Round($h * 2.4)
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $pts = New-Object 'System.Drawing.PointF[]' 5
    $pts[0] = New-Object System.Drawing.PointF 0, 0
    $pts[1] = New-Object System.Drawing.PointF $body, 0
    $pts[2] = New-Object System.Drawing.PointF $w, ([float]($h / 2))
    $pts[3] = New-Object System.Drawing.PointF $body, $h
    $pts[4] = New-Object System.Drawing.PointF 0, $h
    $g.FillPolygon([System.Drawing.Brushes]::White, $pts)
    $g.Dispose()
    $bmp.Save((Join-Path $dir "knox_chamber_$h.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}
Write-Host "saved chambers"
