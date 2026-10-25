# The banner of the crosshair panel's news post ("In your sights", 2026-10-25, the author:
# "a news post in the same style as the last ones"), by the approved news rules (see
# make_news_096.ps1 and news_ui.ps1): a piece of the Knox screen itself - Viewpoint's
# crosshair and, beside it, Knox's panel over a fridge, its chosen row being taken.
# The post's art is no picture: "@art vp" draws the panel itself (KnoxCrosshairDemo).
# Sizes are KnoxCrosshair's own (its `sizes()`), at the 64 px cell of a 1440p screen.
#   42\media\knox\news\x1_banner_<ru|en>.png   912 x 204
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_vp.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$S = 64 / 48
function Px($n) { [int][math]::Max(1, [math]::Floor($n * $S + 0.5)) }
$ROW = Px 32; $CELL = Px 26; $IC = Px 22; $L = (Px 8) + (Px 7); $TX = $L + $CELL + (Px 10)
$GROW_H = Px 6; $GROW_CELL = Px 4; $PH = (Px 7) * 2 + (Px 26); $W = Px 340

# a fade into the backdrop's colour (alpha a0 at one end, a1 at the other) over a band
function Fade($g, $x, $y, $w, $h, $a0, $a1, $vertical) {
    $rr = New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$w), ([int]$h)
    $angle = $(if ($vertical) { 90.0 } else { 0.0 })
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, (A $K.screen $a0), (A $K.screen $a1), $angle
    $g.FillRectangle($lg, $rr)
}

# Viewpoint's crosshair: four short strokes about a gap, a dot in the middle
function Sight($g, $cx, $cy) {
    $arm = 14; $gap = 7
    foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
        $x0 = $cx + $d[0] * $gap; $y0 = $cy + $d[1] * $gap
        $x1 = $cx + $d[0] * ($gap + $arm); $y1 = $cy + $d[1] * ($gap + $arm)
        Fill $g $K.bright ([math]::Min($x0, $x1) - ([int]($d[1] -ne 0))) ([math]::Min($y0, $y1) - ([int]($d[0] -ne 0))) `
            ([math]::Abs($x1 - $x0) + 2 * [int]($d[1] -ne 0)) ([math]::Abs($y1 - $y0) + 2 * [int]($d[0] -ne 0)) 0.9
    }
    Fill $g $K.bright ($cx - 1) ($cy - 1) 2 2 0.9
}

# a row of the panel: the tile with its picture, the name (a size up when chosen), the weight
function VpRow($g, $x, $y, $name, $icon, $wt, $n, $chosen, $taking) {
    $grow = $(if ($chosen) { 1 } else { 0 })
    $rh = $ROW + $GROW_H * $grow
    if ($taking) {
        $fw = [int](($W - 2) * $taking)
        Fill $g $K.accent ($x + 1) $y $fw $rh 0.16
        Fill $g $K.accent ($x + $fw - 1) $y 2 $rh 0.9
    }
    $cs = $CELL + $GROW_CELL * $grow; $is = $IC + $GROW_CELL * $grow
    $ccx = $x + $L + $CELL / 2; $ccy = $y + $rh / 2
    $fx = [int]($ccx - $cs / 2); $fy = [int]($ccy - $cs / 2)
    Fill $g $K.food $fx $fy $cs $cs
    DrawIcon $g $icon $fx $fy $cs $cs 1 $is
    Frame $g $(if ($taking) { $K.accent } else { $K.tileEdge }) $fx $fy $cs $cs 1
    $px = $(if ($chosen) { 23 } else { 20 })
    TxtMid $g $name "body" $px $(if ($chosen) { $K.bright } else { $K.text }) ($x + $TX) $y $rh
    if ($n) { TxtMid $g $n "body" 20 $K.dim ($x + $TX + (TextW $g $name "body" $px) + (Px 5)) $y $rh }
    TxtMid $g $wt "body" 20 $K.dim ($x + $W - $L - (TextW $g $wt "body" 20)) $y $rh
    return $rh
}

foreach ($lang in "ru", "en") {
    Write-Host "news banner, the crosshair panel ($lang):"
    $dot = $(if ($lang -eq "ru") { "," } else { "." })
    $bmp, $g = Canvas 912 204 $K.screen
    # the panel on the right, the crosshair to its left (Viewpoint's AWAY from it)
    $x = 912 - 34 - $W
    $cx = $x - (Px 48); $cy = 96
    Sight $g $cx $cy
    $y = 14
    Fill $g $K.window $x $y $W 260
    Frame $g $K.border $x $y $W 260 1
    # the header: the container's picture and its name
    Fill $g $K.header ($x + 1) ($y + 1) ($W - 2) ($PH - 1)
    DrawIcon $g "c_fridge" ($x + $L) ($y + ($PH - $CELL) / 2) $CELL $CELL 1 $CELL $true
    TxtMid $g (Up (Tr $lang "IGUI_Knox_VPDemo_Fridge")) "head" 20 $K.accent ($x + $TX) $y $PH
    Fill $g $K.border ($x + 1) ($y + $PH) ($W - 2) 1
    $ry = $y + $PH + (Px 4)
    $ry += VpRow $g $x $ry (Tr $lang "IGUI_Knox_VPDemo_Sausage") "sausage" "0${dot}2" $null $false $null
    $ry += VpRow $g $x $ry (Tr $lang "IGUI_Knox_VPDemo_Steak") "steak" "0${dot}6" "x2" $true 0.58
    $ry += VpRow $g $x $ry (Tr $lang "IGUI_Knox_VPDemo_Cucumber") "cucumber" "0${dot}2" $null $false $null
    $ry += VpRow $g $x $ry (Tr $lang "IGUI_Knox_VPDemo_Dinner") "tvdinner" "0${dot}4" $null $false $null
    Fill $g $K.screen 0 0 912 204 0.2
    # the left: the card's words go there (as the other posts' banners)
    $rr = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $rr)
    # top, bottom and right: no hard cut of the panel
    Fade $g 0 0 912 22 0.9 0 $true
    Fade $g 0 150 912 54 0 1 $true
    Fade $g 870 0 42 204 0 0.85 $false
    Save $bmp $g "x1_banner_$lang.png"
}
