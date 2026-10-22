# Pictures of the 0.6.0 news post (the fluid transfer window in Knox's look, the
# Split window with its thread, the news behind the mod's name), made in 2026-10
# by the approved news rules (see make_news_096.ps1 and news_ui.ps1): the windows
# as KnoxFluidWindow / KnoxSplitDialog draw them, the game's and the mod's own
# words, the game's icons, captions in capitals, a banner with no words.
#   42\media\knox\news\u060_<name>_<ru|en>.png   banner, art, fluid, split
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_060.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$WATER = Hex "#3f78b5"
$L = @{
    ru = @{
        flTitle = "ПЕРЕЛИВАНИЕ - ОКНО В СТИЛЕ KNOX"
        flA = "БАКИ ПОКАЗЫВАЮТ ЖИДКОСТЬ ЕЁ ЦВЕТОМ И ЗАРАНЕЕ - СКОЛЬКО УЙДЁТ И СКОЛЬКО ПРИДЁТ."
        flB = "ЁМКОСТЬ ПЕРЕТАСКИВАЕТСЯ В СЛОТ ПРЯМО ИЗ СЕТКИ. КНОПКИ 25 / 50 / 75% / ВСЁ - ИЛИ ПОЛЗУНОК."
        spTitle = "РАЗДЕЛИТЬ: НИТЬ К СТОПКЕ, РАМКА, КРЕСТИК"
        newsTitle = "НОВОСТИ - ЩЕЛЧОК ПО НАЗВАНИЮ МОДА"
        newsA = "СПИСКИ ИЗМЕНЕНИЙ ТЕПЕРЬ ПРЯМО В ИГРЕ. ТОЧКА НА ПЛАШКЕ - ЕСТЬ НЕПРОЧИТАННОЕ."
        artTitle = "ПЕРЕЛИТЬ, НЕ ЗАКРЫВАЯ ИНВЕНТАРЬ"
        bag = "ПОХОДНЫЙ РЮКЗАК"
    }
    en = @{
        flTitle = "POURING - A WINDOW IN KNOX'S LOOK"
        flA = "THE TANKS SHOW THE LIQUID IN ITS COLOUR, AND BEFOREHAND - HOW MUCH LEAVES AND HOW MUCH COMES."
        flB = "DRAG A CONTAINER INTO A SLOT RIGHT FROM A GRID. BUTTONS 25 / 50 / 75% / ALL - OR THE SLIDER."
        spTitle = "SPLIT: A THREAD TO THE STACK, A FRAME, A CROSS"
        newsTitle = "NEWS - A CLICK ON THE MOD'S NAME"
        newsA = "THE CHANGE LISTS ARE RIGHT IN THE GAME NOW. A DOT ON THE PLATE - SOMETHING UNREAD."
        artTitle = "POUR WITHOUT CLOSING THE INVENTORY"
        bag = "HIKING BAG"
    }
}

# a button as T.button draws it: sand (primary / active) or dark in a grey frame
function Btn($g, $x, $y, $w, $h, $text, $primary = $false, $px = 17) {
    if ($primary) { Fill $g $K.accent $x $y $w $h; TxtCentre $g $text "head" $px $K.ink $x $y $w $h }
    else { Fill $g $K.buttonBg $x $y $w $h; Frame $g $K.tileFrame $x $y $w $h 1; TxtCentre $g $text "head" $px $K.bright $x $y $w $h }
}

# A thread from a tile to its window (KnoxThread): a sand line round the corner,
# a small square at both ends.
function Thread($g, $x1, $y1, $x2, $y2, $mx = $null) {
    if ($null -eq $mx) { $mx = [math]::Floor(($x1 + $x2) / 2) }
    Fill $g $K.accent ([math]::Min($x1, $mx)) ($y1 - 1) ([math]::Abs($mx - $x1) + 2) 2
    Fill $g $K.accent ($mx - 1) ([math]::Min($y1, $y2)) 2 ([math]::Abs($y2 - $y1) + 2)
    Fill $g $K.accent ([math]::Min($mx, $x2)) ($y2 - 1) ([math]::Abs($x2 - $mx) + 2) 2
    Fill $g $K.accent ($x1 - 3) ($y1 - 3) 6 6
    Fill $g $K.accent ($x2 - 3) ($y2 - 3) 6 6
}

# the same, going up first: from a tile's top to the window's bottom edge
function ThreadV($g, $x1, $y1, $x2, $y2) {
    $my = [math]::Floor(($y1 + $y2) / 2)
    Fill $g $K.accent ($x1 - 1) ([math]::Min($y1, $my)) 2 ([math]::Abs($my - $y1) + 2)
    Fill $g $K.accent ([math]::Min($x1, $x2)) ($my - 1) ([math]::Abs($x2 - $x1) + 2) 2
    Fill $g $K.accent ($x2 - 1) ([math]::Min($my, $y2)) 2 ([math]::Abs($y2 - $my) + 2)
    Fill $g $K.accent ($x1 - 3) ($y1 - 3) 6 6
    Fill $g $K.accent ($x2 - 3) ($y2 - 3) 6 6
}

# A tank (KnoxFluidWindow drawTank): the liquid from the bottom; what leaves is
# shaded (source), what comes is lit (target), a sand line at the new level; marks
# at the quarters.
function Tank($g, $x, $y, $w, $h, $ratio, $newRatio) {
    Fill $g $K.cell $x $y $w $h
    $fh = [math]::Floor($h * $ratio)
    if ($fh -gt 0) { Fill $g $WATER $x ($y + $h - $fh) $w $fh 0.85 }
    $nh = [math]::Floor($h * $newRatio)
    if ($nh -lt $fh) { Fill $g (Hex "#0a0d0d") $x ($y + $h - $fh) $w ($fh - $nh) 0.6 }
    elseif ($nh -gt $fh) { Fill $g $WATER $x ($y + $h - $nh) $w ($nh - $fh) 0.55 }
    Fill $g $K.accent $x ($y + $h - $nh - 1) $w 2
    for ($i = 1; $i -le 3; $i++) {
        $my = $y + $h - [math]::Floor($h * $i / 4); $q = [math]::Floor($w / 4)
        Fill $g $K.tileFrame $x $my $q 1; Fill $g $K.tileFrame ($x + $w - $q) $my $q 1
    }
    Frame $g $K.tileFrame $x $y $w $h 2
}

# The fluid window at x, y (the 64 px cell): a bucket of water poured into a pot,
# half of what can go. Returns the slots' rectangles (for threads).
function FluidWin($g, $lang, $x, $y) {
    $cell = 64; $pad = 16   # (no $c / $l / $slots here: PowerShell names ignore case - $C, $L, $slotS)
    $colW = [math]::Floor($cell * 3.4); $midW = $cell * 5; $slotS = [math]::Floor($cell * 1.5)
    $tankW = [math]::Floor($cell * 1.1); $tankH = [math]::Floor($cell * 3.4); $btnH = 40
    $hdr = 44; $capY = $y + $hdr + $pad; $slotY = $capY + 30; $nameY = $slotY + $slotS + 8
    $tankY = $nameY + 34; $amountY = $tankY + $tankH + 8; $btnY = $amountY + 50
    $w = $pad * 4 + $colW * 2 + $midW; $h = $btnY - $y + $btnH + $pad
    $lit = Tr $lang "IGUI_Knox_LitersShort"
    Win $g $x $y $w $h (GTr $lang "Fluids" "Fluid_Transfer_Fluids")
    $sides = @(@(($x + $pad), (GTr $lang "Fluids" "Fluid_Source"), "bucket", (GTr $lang "Fluids" "Fluid_Container_Bucket"), 0.8, 0.6, "8 $lit / 10 $lit"),
               @(($x + $pad * 3 + $colW + $midW), (GTr $lang "Fluids" "Fluid_Target"), "pot", (GTr $lang "Fluids" "Fluid_Container_Pot"), 0.25, 0.75, "1 $lit / 4 $lit"))
    $slotRects = @()
    foreach ($sd in $sides) {
        $sx = $sd[0]
        $cap = Up $sd[1]; $cw = TextW $g $cap "head" 17
        Txt $g $cap "head" 17 $K.dim ($sx + ($colW - $cw) / 2) $capY
        $rx = $sx + [math]::Floor(($colW - $slotS) / 2)
        Fill $g $K.clo $rx $slotY $slotS $slotS
        DrawIcon $g $sd[2] $rx $slotY $slotS $slotS 1 ([math]::Floor($slotS * 0.8))
        Frame $g $K.tileFrame $rx $slotY $slotS $slotS 2
        $slotRects += , @($rx, $slotY, $slotS, $slotS)
        $nw = TextW $g $sd[3] "body" 20
        Txt $g $sd[3] "body" 20 $K.text ($sx + ($colW - $nw) / 2) $nameY
        Tank $g ($sx + [math]::Floor(($colW - $tankW) / 2)) $tankY $tankW $tankH $sd[4] $sd[5]
        $aw = TextW $g $sd[6] "body" 19
        Txt $g $sd[6] "body" 19 $K.dim ($sx + ($colW - $aw) / 2) $amountY
    }
    # the middle: swap, the liquid's name, the presets, the slider, how much
    $mx = $x + $pad * 2 + $colW; $cx = $mx + $midW / 2
    $swX = $mx + [math]::Floor($midW * 0.15); $swW = [math]::Floor($midW * 0.7); $swY = $slotY + [math]::Floor(($slotS - $btnH) / 2)
    Fill $g $K.buttonBg $swX $swY $swW $btnH; Frame $g $K.tileFrame $swX $swY $swW $btnH 1
    $sw = Up (GTr $lang "Fluids" "Fluid_Swap"); $s = 11; $gap = 14
    $tot = $s * 2 + $gap + (TextW $g $sw "head" 17); $ax = $swX + ($swW - $tot) / 2; $ay = $swY + $btnH / 2
    foreach ($dir in -1, 1) {   # (not $k: that is the palette $K)
        $yy = $ay + $dir * [math]::Floor($s / 2)
        Fill $g $K.text $ax ($yy - 1) ($s * 2) 2
        for ($i = 0; $i -le [math]::Floor($s / 2); $i++) {
            $tip = $(if ($dir -lt 0) { $ax + $i } else { $ax + $s * 2 - $i })
            Fill $g $K.text $tip ($yy - $i - 1) 2 2; Fill $g $K.text $tip ($yy + $i - 1) 2 2
        }
    }
    TxtMid $g $sw "head" 17 $K.text ($ax + $s * 2 + $gap) $swY $btnH
    $fname = GTr $lang "Fluids" "Fluid_Name_Water"; $fw = TextW $g $fname "body" 20
    $fx = $cx - ($fw + 18) / 2
    Fill $g $WATER $fx ($tankY + 6) 12 12
    Txt $g $fname "body" 20 $K.bright ($fx + 18) $tankY
    $py = $tankY + 44; $pw = [math]::Floor(($midW - 12) / 4)
    $labels = @("25%", "50%", "75%", (Tr $lang "IGUI_Knox_FluidAll"))
    for ($i = 0; $i -lt 4; $i++) { Btn $g ($mx + $i * ($pw + 4)) $py $pw $btnH $labels[$i] ($i -eq 1) 16 }
    $ty = $py + $btnH + $pad; $kh = 21
    Fill $g $K.line $mx ($ty + 9) $midW 3; Fill $g $K.accent $mx ($ty + 9) ($midW / 2) 3
    Fill $g $K.accent ($mx + $midW / 2 - 10) $ty $kh $kh
    $big = "2 $lit"; $bw = TextW $g $big "title" 34
    Txt $g $big "title" 34 $K.bright ($cx - $bw / 2) ($ty + 40)
    $of = (Tr $lang "IGUI_Knox_FluidOfMax").Replace("%1", "3 $lit"); $ow = TextW $g $of "body" 19
    Txt $g $of "body" 19 $K.dim ($cx - $ow / 2) ($ty + 84)
    # Pour (sand) and Cancel at the bottom right
    $pour = Up (GTr $lang "Fluids" "Fluid_Transfer"); $close = Up (GTr $lang "Fluids" "Fluid_Close")
    $cw2 = (TextW $g $close "head" 17) + 40; $pw2 = (TextW $g $pour "head" 17) + 40
    Btn $g ($x + $w - $pad - $cw2) $btnY $cw2 $btnH $close
    Btn $g ($x + $w - $pad * 2 - $cw2 - $pw2) $btnY $pw2 $btnH $pour $true
    return @{w = $w; h = $h; slots = $slotRects}
}

# The Split window (KnoxSplitDialog): its count in the header, the stack's name,
# 15 / 30 with - and +, the slider, Cancel and OK.
function SplitWin($g, $lang, $x, $y, $name) {
    $w = 448; $h = 300; $pad = 16
    Win $g $x $y $w $h (Tr $lang "IGUI_Knox_Split")
    Txt $g "30" "body" 20 $K.dim ($x + $w - 12 - 28 - 12 - (TextW $g "30" "body" 20)) ($y + 12)
    Txt $g $name "body" 21 $K.text ($x + $pad) ($y + 60)
    $vy = $y + 100
    Btn $g ($x + $pad) $vy 48 48 "-"; Btn $g ($x + $w - $pad - 48) $vy 48 48 "+"
    $v = "15 / 30"; $vw = TextW $g $v "title" 32
    Txt $g $v "title" 32 $K.bright ($x + ($w - $vw) / 2) ($vy + 10)
    $ty = $vy + 66
    Fill $g $K.line ($x + $pad) ($ty + 9) ($w - 2 * $pad) 3; Fill $g $K.accent ($x + $pad) ($ty + 9) (($w - 2 * $pad) / 2) 3
    Fill $g $K.accent ($x + $w / 2 - 10) $ty 21 21
    Txt $g "1" "head" 15 $K.dim ($x + $pad) ($ty + 32); Txt $g "29" "head" 15 $K.dim ($x + $w - $pad - (TextW $g "29" "head" 15)) ($ty + 32)
    $ok = Up (Tr $lang "IGUI_Knox_OK"); $cn = Up (Tr $lang "IGUI_Knox_Cancel")
    $okW = (TextW $g $ok "head" 17) + 40; $cnW = (TextW $g $cn "head" 17) + 40
    Btn $g ($x + $w - $pad - $okW) ($y + $h - $pad - 40) $okW 40 $ok $true
    Btn $g ($x + $w - $pad * 2 - $okW - $cnW) ($y + $h - $pad - 40) $cnW 40 $cn
}

# the bottom bar's mod name and stage plate, with the unread dot
function BrandPlate($g, $lang, $right, $y, $h) {
    $stage = Up (Tr $lang "IGUI_Knox_Stage")
    $sw = (TextW $g $stage "head" 15) + 16; $sh = 28
    $sx = $right - $sw; $sy = $y + ($h - $sh) / 2
    Fill $g $K.accent $sx $sy $sw $sh 0.18; Frame $g $K.accent $sx $sy $sw $sh 1
    TxtCentre $g $stage "head" 15 $K.accent $sx $sy $sw $sh
    Fill $g $K.accent ($sx + $sw - 5) ($sy - 4) 9 9
    $wI = TextW $g "INVENTORY" "head" 19; $wK = TextW $g "KNOX" "head" 19
    TxtMid $g "INVENTORY" "head" 19 $K.accent ($sx - 14 - $wI) $y $h
    TxtMid $g "KNOX" "head" 19 $K.bright ($sx - 14 - $wI - 8 - $wK) $y $h
    return $sx - 14 - $wI - 8 - $wK - 16
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.6.0 ($lang):"

    # --- the fluid window and what it does
    $bmp, $g = Canvas 1280 640 $K.screen
    Caption $g $s.flTitle 24 26
    $fw = FluidWin $g $lang 24 80
    $yb = CapsBlock $g $s.flA 892 100 364
    CapsBlock $g $s.flB 892 ($yb + 14) 364 | Out-Null
    Save $bmp $g "u060_fluid_$lang.png"

    # --- split: a stack, its thread, the window; the news behind the mod's name
    $bmp, $g = Canvas 1280 480 $K.screen
    Caption $g $s.spTitle 24 26
    $gx = 40; $gy = 120
    Strip $g $gx 84 (4 * $C + 1) $s.bag "4x5" $null $true
    Grid $g $gx $gy 4 5
    # (the stack at the grid's right edge: its thread goes out without crossing a tile)
    Tile $g $gx $gy 3 0 1 1 "wpn" "shells" "" "30"; Frame $g $K.accent ($gx + 3 * $C + 1) ($gy + 1) ($C - 1) ($C - 1) 1
    Tile $g $gx $gy 2 0 1 2 "food" "bottle"; Tile $g $gx $gy 0 0 2 2 "clo" "jacket"; Tile $g $gx $gy 3 1 1 1 "med" "bandage"
    Thread $g ($gx + 4 * $C) ($gy + $C / 2) 380 106 340
    SplitWin $g $lang 380 84 (GTr $lang "ItemName" "Base.ShotgunShells")
    # the bottom bar's corner
    Txt $g $s.newsTitle "title" 24 $K.bright 880 84
    Fill $g $K.bar 880 130 376 84; Fill $g $K.border 880 130 376 1
    BrandPlate $g $lang 1240 130 84 | Out-Null
    Cursor $g 1180 186 34
    CapsBlock $g $s.newsA 880 240 376 | Out-Null
    Save $bmp $g "u060_split_$lang.png"

    # --- art: a bag with the two containers, threads up to the window
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 60 56 26
    $wx = 70
    $fw = FluidWin $g $lang $wx 110
    $gy = 110 + $fw.h + 120
    Strip $g 60 ($gy - 36) (7 * $C + 1) $s.bag "7x3" $null $true
    Grid $g 60 $gy 7 3
    Tile $g 60 $gy 0 0 2 2 "clo" "bucket"; Tile $g 60 $gy 5 0 2 2 "food" "pot"
    Tile $g 60 $gy 2 0 1 2 "food" "bottle"; Tile $g 60 $gy 3 0 1 1 "food" "beans"; Tile $g 60 $gy 4 0 1 1 "med" "pills"
    Tile $g 60 $gy 2 2 2 1 "wpn" "pistol"; Tile $g 60 $gy 0 2 1 1 "tool" "battery"
    # threads: each tile's top to its slot's bottom
    $winBottom = 110 + $fw.h
    ThreadV $g (60 + $C) ($gy - 36) ($fw.slots[0][0] + $fw.slots[0][2] / 2) $winBottom
    ThreadV $g (60 + 6 * $C) ($gy - 36) ($fw.slots[1][0] + $fw.slots[1][2] / 2) $winBottom
    Save $bmp $g "u060_art_$lang.png"

    # --- banner: liquids and their containers
    BannerPattern "u060_banner_$lang.png" @(
        @(7, 0, 2, 2, "clo", "bucket", ""), @(9, 0, 1, 2, "food", "bottle", "hit"), @(10, 0, 2, 2, "food", "pot_water", ""),
        @(12, 0, 2, 2, "food", "saucepan", ""), @(14, 0, 1, 2, "food", "bottle", ""), @(15, 0, 2, 2, "food", "pot", ""),
        @(7, 2, 1, 1, "wpn", "shells", ""), @(8, 2, 1, 1, "food", "beans", ""), @(11, 2, 2, 1, "wpn", "pistol", ""),
        @(13, 2, 1, 1, "med", "pills", "hit"), @(14, 2, 1, 1, "tool", "battery", "")
    )
}
