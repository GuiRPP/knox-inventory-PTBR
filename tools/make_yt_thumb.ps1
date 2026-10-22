# The YouTube thumbnail of the 1.0 overview video (2026-10-15): 1280 x 720, EN and RU.
#   back   - the camp of the main menu, the heroes by the fire (the mood)
#   top    - KNOX INVENTORY and a sand "1.0" plate, a line of what it is under it
#   bottom - left: a big sand plate FULL OVERVIEW; right: a Knox grid, a generator
#            held at the cursor (shaking: hard to hold), a pot glowing hot
# Writes tools\art\yt_thumb_en.png and yt_thumb_ru.png (and _small: how it reads
# at the size YouTube lists it).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_yt_thumb.ps1
# (saved with a UTF-8 BOM: the Russian lines)

. (Join-Path $PSScriptRoot "news_ui.ps1")
$art = Join-Path $PSScriptRoot "art"
$K.ammo = Hex "#3a321c"

$W = 1280; $H = 720
$TEXTS = @{
    en = @{ sub = "UI OVERHAUL FOR PROJECT ZOMBOID"; plate = "FULL OVERVIEW"; bag = "LARGE BACKPACK" }
    ru = @{ sub = "НОВЫЙ ИНТЕРФЕЙС PROJECT ZOMBOID"; plate = "ПОЛНЫЙ ОБЗОР"; bag = "БОЛЬШОЙ РЮКЗАК" }
}

function Make($lang) {
    $tx = $TEXTS[$lang]
    $bmp, $g = Canvas $W $H $K.screen
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # --- the camp: the heroes in the middle, the news cards under the grid ---
    $shot = [System.Drawing.Image]::FromFile((Join-Path $art "screen_081_menu.jpg"))
    $g.DrawImage($shot, (New-Object System.Drawing.Rectangle 0, 0, $W, $H), 380, 225, 1600, 900, [System.Drawing.GraphicsUnit]::Pixel)
    $shot.Dispose()
    function VFade($y0, $y1, $a0, $a1) {
        $r = New-Object System.Drawing.Rectangle 0, ([int]$y0), $W, ([int]($y1 - $y0))
        $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, (A $K.screen $a0), (A $K.screen $a1), 90.0
        $g.FillRectangle($lg, $r)
    }
    VFade 0 300 0.97 0.0
    VFade 0 170 0.9 0.0
    VFade ($H - 170) ($H + 1) 0.0 0.85
    VFade ($H - 40) ($H + 1) 0.5 1.0      # (the game's version line at the bottom)
    # the game's logo peeks in at the top left: under the dark
    $lgL = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, 260, 140), (A $K.screen 1.0), (A $K.screen 0.0), 0.0
    $g.FillRectangle($lgL, 0, 0, 260, 140)
    # the edges darker, the fire the brightest thing
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(-300, -100, $W + 600, $H + 260)
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
    $pg.CenterColor = A $K.screen 0
    $pg.SurroundColors = [System.Drawing.Color[]]@((A $K.screen 0.8))
    $pg.FocusScales = New-Object System.Drawing.PointF 0.5, 0.4
    $g.FillRectangle($pg, 0, 0, $W, $H)

    # --- the name and 1.0 ---
    $tp = 124
    $wK = TextW $g "KNOX" "title" $tp; $wI = TextW $g "INVENTORY" "title" $tp; $sp = 26
    $vp = 116; $vText = "1.0"; $vW = (TextW $g $vText "title" $vp) + 48; $vH = [int]($capH * $vp + 44)
    $total = $wK + $sp + $wI + 30 + $vW
    $x0 = ($W - $total) / 2; $ty = 34
    Txt $g "KNOX" "title" $tp $K.bright $x0 $ty
    Txt $g "INVENTORY" "title" $tp $K.accent ($x0 + $wK + $sp) $ty
    $vx = $x0 + $wK + $sp + $wI + 30
    $vy = $ty + ($capH * $tp - $vH) / 2
    Fill $g $K.accent $vx $vy $vW $vH
    TxtCentre $g $vText "title" $vp $K.ink $vx $vy $vW $vH
    # what it is, between two sand lines
    $sub = $tx.sub; $subPx = 36
    $subW = TextW $g $sub "head" $subPx
    $ly = $ty + $capH * $tp + 30
    Fill $g $K.accent (($W - $subW) / 2 - 76) ($ly + $capH * $subPx / 2 - 1) 52 3
    Fill $g $K.accent (($W + $subW) / 2 + 24) ($ly + $capH * $subPx / 2 - 1) 52 3
    Txt $g $sub "head" $subPx $K.text (($W - $subW) / 2) $ly

    # --- the grid, bottom right (over the news cards of the screenshot) ---
    $cell = 88
    $cols = 4; $rows = 3; $stripH = 40
    $gw = $cols * $cell + 1
    $gx = $W - 36 - $gw; $gy = $H - 34 - $rows * $cell; $py = $gy - $stripH
    for ($i = 1; $i -le 6; $i++) { Fill $g $K.screen ($gx - 10 - 5 * $i) ($py - 10 - 5 * $i) ($gw + 20 + 10 * $i) ($stripH + $rows * $cell + 21 + 10 * $i) 0.12 }
    Fill $g $K.window ($gx - 10) ($py - 10) ($gw + 20) ($stripH + $rows * $cell + 21)
    Frame $g $K.border ($gx - 10) ($py - 10) ($gw + 20) ($stripH + $rows * $cell + 21) 2
    Fill $g $K.header $gx $py $gw $stripH
    Frame $g $K.accent $gx $py $gw $stripH 2
    TxtMid $g $tx.bag "head" 20 $K.accent ($gx + 12) $py $stripH
    TxtMid $g "4x3" "head" 20 $K.dim ($gx + $gw - 12 - (TextW $g "4x3" "head" 20)) $py $stripH
    Fill $g $K.cell $gx $gy ($cols * $cell) ($rows * $cell)
    for ($i = 0; $i -le $cols; $i++) { Fill $g $K.line ($gx + $i * $cell) $gy 1 ($rows * $cell + 1) }
    for ($j = 0; $j -le $rows; $j++) { Fill $g $K.line $gx ($gy + $j * $cell) ($cols * $cell + 1) 1 }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    function TileAt($t) {
        # {col, row, w, h, category, icon, count, heat}
        $x = $gx + $t[0] * $cell + 1; $y = $gy + $t[1] * $cell + 1; $pw = $t[2] * $cell - 1; $ph = $t[3] * $cell - 1
        Fill $g $K[$t[4]] $x $y $pw $ph
        if ($t.Count -gt 7 -and $t[7]) { Fill $g (Hex "#d92e1f") $x $y $pw $ph 0.55 }   # hot: red, as on a stove
        Frame $g $K.tileFrame $x $y $pw $ph 2
        DrawIcon $g $t[5] $x $y $pw $ph 1 ([math]::Floor([math]::Min($pw, $ph) * 0.85))
        if ($t.Count -gt 6 -and $t[6]) { Txt $g $t[6] "head" 20 $K.bright ($x + $pw - 7 - (TextW $g $t[6] "head" 20)) ($y + $ph - 24) }
    }
    foreach ($t in @(
        @(0, 0, 1, 2, "wpn", "axe"),
        @(1, 0, 1, 1, "ammo", "ammo9", "30"),
        @(1, 1, 1, 1, "med", "bandage"),
        @(0, 2, 1, 1, "food", "beans"),
        @(2, 0, 2, 1, "wpn", "pistol"),
        @(1, 2, 1, 1, "tool", "pot_water", $null, $true)
    )) { TileAt $t }
    # the free spot lit green, the generator held over it: shaking (two faint copies a few px off)
    $sx = $gx + 2 * $cell + 1; $sy = $gy + 1 * $cell + 1; $sw = 2 * $cell - 1
    Fill $g $K.ok $sx $sy $sw $sw 0.20
    Frame $g $K.ok $sx $sy $sw $sw 2
    $hx = $sx - 26; $hy = $sy - 52
    for ($i = 1; $i -le 4; $i++) { Fill $g $K.screen ($hx + 4 + 3 * $i) ($hy + 6 + 3 * $i) $sw $sw 0.14 }
    foreach ($o in @(@(-7, 3, 0.18), @(6, -4, 0.22))) {
        Frame $g $K.accent ($hx + $o[0]) ($hy + $o[1]) $sw $sw 2 $o[2]
        DrawIcon $g "generator" ($hx + $o[0]) ($hy + $o[1]) $sw $sw $o[2] ([math]::Floor($sw * 0.86))
    }
    Fill $g $K.tool $hx $hy $sw $sw 0.95
    Frame $g $K.accent $hx $hy $sw $sw 3
    DrawIcon $g "generator" $hx $hy $sw $sw 1 ([math]::Floor($sw * 0.86))
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    # shake marks either side
    $pen = New-Object System.Drawing.Pen (A $K.accent 0.9), 5
    foreach ($m in @(@(-26, 40), @(-36, 76), @(-26, 112))) { $g.DrawLine($pen, [float]($hx + $m[0]), [float]($hy + $m[1]), [float]($hx + $m[0] + 16), [float]($hy + $m[1])) }
    foreach ($m in @(@(10, 40), @(20, 76), @(10, 112))) { $g.DrawLine($pen, [float]($hx + $sw + $m[0]), [float]($hy + $m[1]), [float]($hx + $sw + $m[0] + 16), [float]($hy + $m[1])) }
    Cursor $g ($hx + $sw * 0.64) ($hy + $sw * 0.6) 46

    # --- FULL OVERVIEW, bottom left ---
    $op = 72
    $ow = (TextW $g $tx.plate "title" $op) + 56; $oh = [int]($capH * $op + 46)
    $ox = 40; $oy = $H - 44 - $oh
    for ($i = 1; $i -le 5; $i++) { Fill $g $K.screen ($ox + 3 * $i) ($oy + 4 * $i) $ow $oh 0.12 }
    Fill $g $K.accent $ox $oy $ow $oh
    TxtCentre $g $tx.plate "title" $op $K.ink $ox $oy $ow $oh

    $g.Dispose()
    $file = Join-Path $art "yt_thumb_$lang.png"
    $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    # how it reads in YouTube's list (about 360 px wide)
    $small = New-Object System.Drawing.Bitmap 360, 203
    $g2 = [System.Drawing.Graphics]::FromImage($small)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g2.DrawImage($bmp, 0, 0, 360, 203)
    $g2.Dispose()
    $small.Save((Join-Path $art "yt_thumb_${lang}_small.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $small.Dispose(); $bmp.Dispose()
    Write-Host "  $file"
}

Make "en"
Make "ru"
