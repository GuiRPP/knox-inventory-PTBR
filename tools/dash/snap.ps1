# Paints the draws tools\dash\test.lua wrote down (snap=<folder>: one .txt a frame)
# into PNGs: the knoxdash pictures tinted as the game tints them, rectangles, the
# quads (needles, the key, knobs' grips), the text in Fira Sans. Not the game's
# renderer - near enough to see the layout, the colours and what stands where.
#   tools\dash\snap.ps1 <folder> [-back #rrggbb]   (the backdrop; the news pictures give the screen's)
param([string]$folder, [string]$back = "")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$pics = Join-Path $root "42\media\ui\knoxdash"
$fontDir = Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates"
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $fontDir "FiraSansCondensed-SemiBold.ttf"))
$pfc.AddFontFile((Join-Path $fontDir "FiraSansCondensed-Medium.ttf"))
$famHead = $pfc.Families | Where-Object { $_.Name -match "SemiBold" } | Select-Object -First 1
if (-not $famHead) { $famHead = $pfc.Families[0] }
$cache = @{}
function Img($name) {
    if (-not $cache.ContainsKey($name)) {
        $p = Join-Path $pics "$name.png"
        $cache[$name] = if (Test-Path $p) { [System.Drawing.Image]::FromFile($p) } else { $null }
    }
    return $cache[$name]
}
# where the capitals' ink is, as a share of the font size (as news_ui.ps1 measures it)
$typo = [System.Drawing.StringFormat]::GenericTypographic
$probe = New-Object System.Drawing.Bitmap 200, 200
$pg = [System.Drawing.Graphics]::FromImage($probe); $pg.Clear([System.Drawing.Color]::Black)
$pg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$pg.DrawString("H", (New-Object System.Drawing.Font $famHead, 100.0, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)), [System.Drawing.Brushes]::White, 20, 20, $typo); $pg.Dispose()
$inkTop = 999; $inkBot = -1
for ($py = 0; $py -lt 200; $py++) { for ($px = 0; $px -lt 200; $px += 2) { if ($probe.GetPixel($px, $py).R -gt 128) { if ($py -lt $inkTop) { $inkTop = $py }; $inkBot = $py; break } } }
$probe.Dispose()
$capTop = ($inkTop - 20) / 100.0; $capH = ($inkBot - $inkTop + 1) / 100.0
function Attr($r, $g, $b, $a) {
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = [float]$r; $cm.Matrix11 = [float]$g; $cm.Matrix22 = [float]$b; $cm.Matrix33 = [float]$a; $cm.Matrix44 = 1
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm); return $ia
}
function Col($r, $g, $b, $a) { return [System.Drawing.Color]::FromArgb([int](255 * [Math]::Min(1, [Math]::Max(0, $a))), [int](255 * $r), [int](255 * $g), [int](255 * $b)) }

foreach ($file in Get-ChildItem $folder -Filter *.txt) {
    $ops = [IO.File]::ReadAllLines($file.FullName) | ForEach-Object { , ($_ -split '\|') }
    # the panel: the first rectangle (its case); the picture: it and room above for the tip
    $case = $ops | Where-Object { $_[0] -eq "R" } | Select-Object -First 1
    $px = [double]$case[2]; $py = [double]$case[3]; $pw = [double]$case[4]; $ph = [double]$case[5]
    $ox = [int]($px - 24); $oy = [int]($py - 190); $W = [int]($pw + 48); $H = [int]($ph + 214)
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"; $g.InterpolationMode = "HighQualityBilinear"; $g.PixelOffsetMode = "Half"; $g.TextRenderingHint = "AntiAliasGridFit"
    if ($back) { $g.Clear([System.Drawing.ColorTranslator]::FromHtml($back)) }
    else { $g.Clear([System.Drawing.Color]::FromArgb(255, 54, 60, 46)) }
    $g.TranslateTransform(-$ox, -$oy)
    foreach ($o in $ops) {
        $k = $o[0]
        if ($k -eq "R") {
            $x, $y, $w, $h, $r, $gg, $b, $a = $o[2..9] | ForEach-Object { [double]$_ }
            $g.FillRectangle((New-Object System.Drawing.SolidBrush (Col $r $gg $b $a)), [float]$x, [float]$y, [float]$w, [float]$h)
        } elseif ($k -eq "P") {
            $img = Img $o[1]; if (-not $img) { continue }
            $x, $y, $w, $h, $r, $gg, $b, $a = $o[2..9] | ForEach-Object { [double]$_ }
            if ($w -le 0 -or $h -le 0) { continue }
            $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int][Math]::Round($x)), ([int][Math]::Round($y)), ([int][Math]::Max(1, [Math]::Round($w))), ([int][Math]::Max(1, [Math]::Round($h)))), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, (Attr $r $gg $b $a))
        } elseif ($k -eq "Q") {
            $v = $o[2..13] | ForEach-Object { [double]$_ }
            $r, $gg, $b, $a = $v[8..11]
            $img = Img $o[1]
            if ($o[1] -eq "white" -or -not $img) {
                $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF $v[0], $v[1]), (New-Object System.Drawing.PointF $v[2], $v[3]), (New-Object System.Drawing.PointF $v[4], $v[5]), (New-Object System.Drawing.PointF $v[6], $v[7]))
                $g.FillPolygon((New-Object System.Drawing.SolidBrush (Col $r $gg $b $a)), $pts)
            } else {
                $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF $v[0], $v[1]), (New-Object System.Drawing.PointF $v[2], $v[3]), (New-Object System.Drawing.PointF $v[6], $v[7]))
                $g.DrawImage($img, $pts, (New-Object System.Drawing.RectangleF 0, 0, $img.Width, $img.Height), [System.Drawing.GraphicsUnit]::Pixel, (Attr $r $gg $b $a))
            }
        } elseif ($k -eq "L") {
            $s = $o[1]
            $x, $y, $w, $h, $size, $r, $gg, $b, $a = $o[2..10] | ForEach-Object { [double]$_ }
            $align = $o[11]
            $fs = $size * 0.92
            $font = New-Object System.Drawing.Font $famHead, ([float]$fs), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
            # by the ink, as KnoxTheme's layout kit lines labels up: the capitals' height
            # in the middle of the band (the font's line box put them off by a few pixels)
            $tw = $g.MeasureString($s, $font, 4000, $typo).Width
            $tx = if ($align -eq "centre") { $x + ($w - $tw) / 2 } elseif ($align -eq "right") { $x + $w - $tw } else { $x }
            $ty = $y + ($h - $capH * $fs) / 2 - $capTop * $fs
            $g.DrawString($s, $font, (New-Object System.Drawing.SolidBrush (Col $r $gg $b $a)), [float]$tx, [float]$ty, $typo)
        }
    }
    $g.Dispose()
    $out = [IO.Path]::ChangeExtension($file.FullName, ".png")
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host "snap: $out"
}
foreach ($i in $cache.Values) { if ($i) { $i.Dispose() } }
