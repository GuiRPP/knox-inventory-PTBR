# Paints the draws tools\gen\test.lua wrote down (test.ps1 -snap <folder>: one .txt a
# frame) into PNGs: the knoxgen pictures tinted as the game tints them, rectangles, the
# turned pictures (needles, the switch, the handle, the cord), the letters straight from
# Knox's font atlases. Not the game's renderer - near enough to check places and colours
# before the author sees it.
#   tools\gen\snap.ps1 <folder>
param([string]$folder, [string]$back = "")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$picDirs = @((Join-Path $root "42\media\ui\knoxgen"), (Join-Path $root "42\media\ui\knoxdash"))
$fontDir = Join-Path $root "42\media\fonts\knox"
$cache = @{}
function Img($name) {
    if (-not $cache.ContainsKey($name)) {
        $cache[$name] = $null
        foreach ($d in $picDirs) {
            $p = Join-Path $d "$name.png"
            if (Test-Path $p) { $cache[$name] = [System.Drawing.Image]::FromFile($p); break }
        }
    }
    return $cache[$name]
}
$fonts = @{}
function Fnt($key) {
    if (-not $fonts.ContainsKey($key)) {
        $chars = @{}
        foreach ($l in [IO.File]::ReadAllLines((Join-Path $fontDir "$key.fnt"))) {
            if ($l -match '^char id=(\d+) x=(\d+) y=(\d+) width=(\d+) height=(\d+) xoffset=(-?\d+) yoffset=(-?\d+) xadvance=(\d+)') {
                $chars[[int]$Matches[1]] = @([int]$Matches[2], [int]$Matches[3], [int]$Matches[4], [int]$Matches[5], [int]$Matches[6], [int]$Matches[7], [int]$Matches[8])
            }
        }
        $fonts[$key] = @{ chars = $chars; img = [System.Drawing.Image]::FromFile((Join-Path $fontDir "$($key)_0.png")) }
    }
    return $fonts[$key]
}
function Attr($r, $g, $b, $a) {
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = [float]$r; $cm.Matrix11 = [float]$g; $cm.Matrix22 = [float]$b; $cm.Matrix33 = [float]$a; $cm.Matrix44 = 1
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm); return $ia
}
function Col($r, $g, $b, $a) { return [System.Drawing.Color]::FromArgb([int](255 * [Math]::Min(1.0, [Math]::Max(0.0, [double]$a))), [int](255 * $r), [int](255 * $g), [int](255 * $b)) }

foreach ($file in Get-ChildItem $folder -Filter *.txt) {
    $ops = [IO.File]::ReadAllLines($file.FullName, [Text.Encoding]::UTF8) | ForEach-Object { , ($_ -split '\|') }
    $win = $ops | Where-Object { $_[0] -eq "W" } | Select-Object -First 1
    $wx = [double]$win[1]; $wy = [double]$win[2]; $ww = [double]$win[3]; $wh = [double]$win[4]
    $ox = [int]($wx - 20); $oy = [int]($wy - 20); $W = [int]($ww + 40); $H = [int]($wh + 40)
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"; $g.InterpolationMode = "HighQualityBilinear"; $g.PixelOffsetMode = "Half"
    if ($back) { $g.Clear([System.Drawing.ColorTranslator]::FromHtml($back)) } else { $g.Clear([System.Drawing.Color]::FromArgb(255, 54, 60, 46)) }
    $g.TranslateTransform(-$ox, -$oy)
    $clips = New-Object System.Collections.Stack
    foreach ($o in $ops) {
        $k = $o[0]
        if ($k -eq "R") {
            $x, $y, $w, $h, $r, $gg, $b, $a = $o[1..8] | ForEach-Object { [double]$_ }
            # (whole pixels, as the game fills a rectangle: 1 px lines were smeared over 2 here)
            $g.SmoothingMode = "None"; $g.PixelOffsetMode = "None"
            $g.FillRectangle((New-Object System.Drawing.SolidBrush (Col $r $gg $b $a)), [float]$x, [float]$y, [float]$w, [float]$h)
            $g.SmoothingMode = "AntiAlias"; $g.PixelOffsetMode = "Half"
        } elseif ($k -eq "P") {
            $img = Img $o[1]; if (-not $img) { continue }
            $x, $y, $w, $h, $r, $gg, $b, $a = $o[2..9] | ForEach-Object { [double]$_ }
            if ($w -le 0 -or $h -le 0) { continue }
            # (on fractions of a pixel, as the game: the shake moves it by less than one)
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF $x, $y), (New-Object System.Drawing.PointF ($x + $w), $y), (New-Object System.Drawing.PointF $x, ($y + $h)))
            $g.DrawImage($img, $pts, (New-Object System.Drawing.RectangleF 0, 0, $img.Width, $img.Height), [System.Drawing.GraphicsUnit]::Pixel, (Attr $r $gg $b $a))
        } elseif ($k -eq "Q") {
            $img = Img $o[1]; if (-not $img) { continue }
            $v = $o[2..13] | ForEach-Object { [double]$_ }
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF $v[0], $v[1]), (New-Object System.Drawing.PointF $v[2], $v[3]), (New-Object System.Drawing.PointF $v[6], $v[7]))
            $g.DrawImage($img, $pts, (New-Object System.Drawing.RectangleF 0, 0, $img.Width, $img.Height), [System.Drawing.GraphicsUnit]::Pixel, (Attr $v[8] $v[9] $v[10] $v[11]))
        } elseif ($k -eq "S") {
            # (the game's clips nest: each inside the last, a clear takes one level off)
            $x, $y, $w, $h = $o[1..4] | ForEach-Object { [float]$_ }
            $clips.Push($g.Clip.Clone())
            $g.SetClip((New-Object System.Drawing.RectangleF $x, $y, $w, $h), [System.Drawing.Drawing2D.CombineMode]::Intersect)
        } elseif ($k -eq "C") {
            if ($clips.Count -gt 0) { $g.Clip = $clips.Pop() } else { $g.ResetClip() }
        } elseif ($k -eq "T") {
            $f = Fnt $o[1]
            $x, $y, $r, $gg, $b, $a = $o[2..7] | ForEach-Object { [double]$_ }
            $s = ($o[8..($o.Count - 1)]) -join '|'
            $ia = Attr $r $gg $b $a
            $pen = 0
            foreach ($ch in $s.ToCharArray()) {
                $c = $f.chars[[int]$ch]
                if (-not $c) { continue }
                if ($c[2] -gt 0 -and $c[3] -gt 0) {
                    $dst = New-Object System.Drawing.Rectangle ([int]($x + $pen + $c[4])), ([int]($y + $c[5])), $c[2], $c[3]
                    $g.DrawImage($f.img, $dst, $c[0], $c[1], $c[2], $c[3], [System.Drawing.GraphicsUnit]::Pixel, $ia)
                }
                $pen += $c[6]
            }
        }
    }
    $g.Dispose()
    $out = [IO.Path]::ChangeExtension($file.FullName, ".png")
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host "snap: $out"
}
foreach ($i in $cache.Values) { if ($i) { $i.Dispose() } }
foreach ($f in $fonts.Values) { $f.img.Dispose() }
