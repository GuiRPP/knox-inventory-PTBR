# The favorite's star (42\media\ui\knox_star.png): a smooth five-pointed star,
# white on transparent, anti-aliased - drawn on tiles in the skin's main colour
# (KnoxGridView, the game's Favorite mark). Made big and drawn smaller, as the
# search lens (make_lens.ps1).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_star.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$out = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui\knox_star.png"
$n = 64
$bmp = New-Object System.Drawing.Bitmap $n, $n
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)
$cx = $n / 2; $cy = $n / 2 + $n * 0.05
$outer = $n * 0.5; $inner = $outer * 0.45
$pts = New-Object 'System.Drawing.PointF[]' 10
for ($i = 0; $i -lt 10; $i++) {
    $a = -[math]::PI / 2 + $i * [math]::PI / 5
    $rad = $(if ($i % 2 -eq 0) { $outer } else { $inner })
    $pts[$i] = New-Object System.Drawing.PointF ([float]($cx + $rad * [math]::Cos($a))), ([float]($cy + $rad * [math]::Sin($a)))
}
$g.FillPolygon([System.Drawing.Brushes]::White, $pts)
$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "saved $out"
