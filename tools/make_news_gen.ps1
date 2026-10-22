# The banner of the generator's news post ("Keep the lights on"), by the approved news rules
# (see make_news_096.ps1 and news_ui.ps1): a piece of the Knox screen itself, no words.
# The post's art is no picture: "@art gen" draws the generator itself in the frame
# (KnoxMenuNews), sharp on any screen; its sections show it live ("@gen", "@gen worn").
# The banner is not drawn anew here: it is KnoxGeneratorWindow's own drawing - tools\gen runs
# the window's news demo on the game's Lua and writes down every draw (test.ps1 -snap, its
# frame "news_banner": the load dial exactly 204 px high, so nothing is scaled), snap.ps1
# paints them with the window's own pictures (media\ui\knoxgen) and Knox's font atlases.
#   42\media\knox\news\g1_banner_<ru|en>.png   912 x 204
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_gen.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

# --- the window's own frames (a set per language: its numbers' point is the language's)
function MakeFrames($lang) {
    $script:frames = Join-Path $env:TEMP "knox_news_gen_$lang"
    if (Test-Path $script:frames) { Remove-Item -LiteralPath $script:frames -Recurse -Force }
    & (Join-Path $PSScriptRoot "gen\test.ps1") -snap $script:frames -lang $lang.ToUpper() | Out-Null
    Get-ChildItem $script:frames -Filter *.png | Remove-Item -Force
    Get-ChildItem $script:frames -Filter *.txt | Where-Object { $_.BaseName -ne "news_banner" } | Remove-Item -Force
    & (Join-Path $PSScriptRoot "gen\snap.ps1") $script:frames -back "#0c0e0e" | Out-Null
}
# the banner frame's scale: the dial (144 units) 204 px high - as test.lua draws it
$GenK = 204 / 144
# a part of the frame in the window's units (x, y, w, h), pixel for pixel at x, y
function Units($g, $ux, $uy, $uw, $uh, $x, $y) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $frames "news_banner.png"))
    $sx = [int][math]::Round(20 + $ux * $GenK); $sy = [int][math]::Round(20 + $uy * $GenK)
    $sw = [int][math]::Round($uw * $GenK); $sh = [int][math]::Round($uh * $GenK)
    $im = $g.InterpolationMode
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), $sw, $sh), $sx, $sy, $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel)
    $g.InterpolationMode = $im
    $img.Dispose()
    return $sw
}
# a fade into the backdrop's colour (alpha a0 at one end, a1 at the other) over a band
function Fade($g, $x, $y, $w, $h, $a0, $a1, $vertical) {
    $rr = New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$w), ([int]$h)
    $angle = $(if ($vertical) { 90.0 } else { 0.0 })
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, (A $K.screen $a0), (A $K.screen $a1), $angle
    $g.FillRectangle($lg, $rr)
}

# a piece's edges dissolved into the backdrop, f px deep on every side (no rectangle shows)
function Feather($g, $x, $y, $w, $h, $f) {
    Fade $g $x $y $w $f 1 0 $true
    Fade $g $x ($y + $h - $f) $w $f 0 1 $true
    Fade $g $x $y $f $h 1 0 $false
    Fade $g ($x + $w - $f) $y $f $h 0 1 $false
}

foreach ($lang in "ru", "en") {
    MakeFrames $lang
    Write-Host "news banner, the generator ($lang):"
    # --- no words: the load dial and the hour meter's drums at work, on the right; the
    # backdrop's dark over all of it, darkest on the left, fading at every edge
    $bmp, $g = Canvas 912 204 $K.screen
    $dialW = [int][math]::Round(144 * $GenK)
    $meterW = [int][math]::Round(100 * $GenK)
    $mx = 912 - 40 - $meterW
    $dx = $mx - 28 - $dialW
    Units $g 200 212 144 144 $dx 0 | Out-Null
    Feather $g $dx 0 $dialW 204 26
    $my = [int]((204 - 44 * $GenK) / 2); $meterH = [int][math]::Round(44 * $GenK)
    Units $g 370 210 100 44 $mx $my | Out-Null
    Feather $g $mx $my $meterW $meterH 10
    Fill $g $K.screen 0 0 912 204 0.35
    # the left: the card's words go there (as the other posts' banners)
    $rr = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $rr)
    # top, bottom and right: no hard cut of the machine
    Fade $g 0 0 912 36 0.95 0 $true
    Fade $g 0 168 912 36 0 0.95 $true
    Fade $g 860 0 52 204 0 0.9 $false
    Save $bmp $g "g1_banner_$lang.png"
}
Get-ChildItem $env:TEMP -Directory -Filter "knox_news_gen_*" | Remove-Item -Recurse -Force
