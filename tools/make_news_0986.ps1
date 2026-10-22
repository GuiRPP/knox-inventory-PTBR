# Pictures of the 0.9.8.6 news post (Belongings: the hero's bag at the fire,
# keepsakes in the camp), by the approved news rules (see make_news_096.ps1 and
# news_ui.ps1): pieces of the Knox screen itself (here the bag's card, drawn as
# KnoxMenuBag.lua lays it out, its tiles with the game's own icons), captions in
# capitals, a banner with no words, a picture per language.
#   42\media\knox\newsআ_<name>_<ru|en>.png   banner, art, bag, keep
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_0986.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        hero = "Брайан"
        bagTitle = "РЮКЗАК У КОСТРА"
        bagA = "ГЕРОЙ СНЯЛ РЮКЗАК И ПОЛОЖИЛ РЯДОМ. ЩЁЛКНИТЕ ПО НЕМУ - ОТКРОЕТСЯ ВСЁ, ЧТО У НЕГО С СОБОЙ."
        bagB = "КАРМАНЫ И КАЖДАЯ НАДЕТАЯ СУМКА - КАК В ИНВЕНТАРЕ: КАЖДАЯ ВЕЩЬ НА СВОЁМ МЕСТЕ."
        bagC = "У КАЖДОЙ СУМКИ СВОЙ ЗВУК: РЮКЗАК РАССТЁГИВАЕТСЯ МОЛНИЕЙ, СУМКА ИЗ ПРОСТЫНИ ШУРШИТ ТКАНЬЮ."
        keepTitle = "НА ПАМЯТЬ"
        keepA = "ЗАЖМИТЕ ВЕЩЬ И ВЫТАЩИТЕ В ЛАГЕРЬ - ОНА ЛЯЖЕТ НА ЗЕМЛЮ. R ПОВОРАЧИВАЕТ."
        keepB = "ЭТО ТОЛЬКО ПАМЯТЬ: САМА ВЕЩЬ ОСТАЁТСЯ У ГЕРОЯ В СУМКЕ, СОХРАНЕНИЕ НЕ МЕНЯЕТСЯ."
        keepC = "ПЕРЕТАЩИТЕ, ЧТОБЫ ПЕРЕЛОЖИТЬ. ПКМ ИЛИ НА СУМКУ - УБРАТЬ."
        artTitle = "ПОЖИТКИ"
    }
    en = @{
        hero = "Brian"
        bagTitle = "THE BAG BY THE FIRE"
        bagA = "THE HERO HAS TAKEN THE BACKPACK OFF AND PUT IT DOWN. CLICK IT - EVERYTHING THEY CARRY OPENS UP."
        bagB = "THE POCKETS AND EVERY BAG WORN, AS IN THE INVENTORY: EACH THING IN ITS PLACE."
        bagC = "EACH BAG SOUNDS LIKE ITSELF: A BACKPACK UNZIPS, A BAG MADE OF A SHEET RUSTLES."
        keepTitle = "KEEPSAKES"
        keepA = "HOLD A THING AND DRAG IT OUT INTO THE CAMP - IT LIES DOWN ON THE GROUND. R TURNS IT."
        keepB = "ONLY ITS LIKENESS: THE THING ITSELF STAYS IN THE HERO'S BAG, THE SAVE IS NEVER TOUCHED."
        keepC = "DRAG IT TO MOVE IT. RIGHT CLICK, OR DROP IT ON A BAG, TO TAKE IT AWAY."
        artTitle = "BELONGINGS"
    }
}

# The bag's card as KnoxMenuBag.lua lays it out (BC:layout / drawSection) at the
# cell $script:C: the head (WHAT THEY CARRY, the hero's name), the pockets 4x2,
# a school bag 5x6 - what the author's hero carried. $taken: the bat is out
# (a faded tile in a sand frame). Returns {w, h}, and the bat's tile in $script:batAt.
function BagCard($g, $x0, $y0, $lang, $taken = $false) {
    $cl = $script:C
    $f = 4; $pad = [math]::Max(8, [math]::Round($cl * 0.19))
    $gw = 5 * $cl
    $w = $gw + 2 * ($f + $pad)
    $headH = 30 + 40
    $secH = 36
    $h = $f + $pad + $headH + $pad + ($secH + 2 * $cl) + $pad + ($secH + 6 * $cl) + $pad + $f
    Fill $g $K.window $x0 $y0 $w $h 0.97
    Frame $g $K.accent $x0 $y0 $w $h $f
    $x = $x0 + $f + $pad; $y = $y0 + $f + $pad
    Txt $g (Up (Tr $lang "IGUI_Knox_MenuBag")) "head" 18 $K.accent $x $y
    Txt $g $L[$lang].hero "title" 28 $K.bright $x ($y + 26)
    $y += $headH + $pad
    # the pockets
    Strip $g $x $y (4 * $cl) (Up (Tr $lang "IGUI_Knox_Pockets")) "4x2"
    $y += $secH
    Grid $g $x $y 4 2
    Tile $g $x $y 3 0 1 1 "info" "idcard"
    Tile $g $x $y 3 1 1 1 "info" "keyring"
    $y += 2 * $cl + $pad
    # the school bag
    Strip $g $x $y $gw (Up (GTr $lang "ItemName" "Base.Bag_Schoolbag")) "5x6"
    $y += $secH
    Grid $g $x $y 5 6
    Tile $g $x $y 3 0 1 1 "food" "bottle"
    Tile $g $x $y 4 0 1 1 "food" "chips"
    if ($taken) {
        Tile $g $x $y 0 2 1 3 "wpn" "bat" "ghost"
        $bx = $x + 1; $by = $y + 2 * $cl + 1
        Frame $g $K.accent $bx $by ($cl - 1) (3 * $cl - 1) 2 0.9
    } else {
        Tile $g $x $y 0 2 1 3 "wpn" "bat"
    }
    Tile $g $x $y 1 3 1 2 "tool" "hammer"
    $script:batAt = @(($x + 1), ($y + 2 * $cl + 1))
    return @($w, $h)
}

# the plate by the mouse while a thing is carried over the camp (M:drawKeepHint)
function KeepHint($g, $x, $y, $lang) {
    $lines = @((GTr $lang "ItemName" "Base.BaseballBat"),
               ((Tr $lang "IGUI_Knox_Keep_Whose") -replace "%1", $L[$lang].hero),
               (Tr $lang "IGUI_Knox_Keep_Turn"))
    $px = 20; $lh = 28; $pad = 10
    $w = 0; foreach ($s in $lines) { $w = [math]::Max($w, (TextW $g $s "body" $px)) }
    $bw = $w + 2 * $pad; $bh = $lines.Count * $lh + 2 * $pad - 6
    Fill $g $K.header $x $y $bw $bh 0.95
    Frame $g $K.accent $x $y $bw $bh 1
    $cs = @($K.bright, $K.text, $K.dim)
    for ($i = 0; $i -lt $lines.Count; $i++) { Txt $g $lines[$i] "body" $px $cs[$i] ($x + $pad) ($y + $pad + $i * $lh) }
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.8.6 ($lang):"

    # --- the bag's card, with what it does
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.bagTitle 24 26
    $script:C = 52
    $wh = BagCard $g 40 84 $lang
    $script:C = 64
    $tx = 40 + $wh[0] + 56; $ty = 120; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.bagA $tx $ty $tw 20 $null 30
    $ty = CapsBlock $g $s.bagB $tx ($ty + 18) $tw 20 $null 30
    CapsBlock $g $s.bagC $tx ($ty + 18) $tw 20 $null 30 | Out-Null
    Save $bmp $g "u0986_bag_$lang.png"

    # --- keepsakes: the bat taken out of the card, carried off, the plate by the mouse
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.keepTitle 24 26
    $script:C = 44
    $wh = BagCard $g 40 84 $lang $true
    $from = $script:batAt
    # (the arrow from the bat's upper end, over the empty cells beside it - not across other things)
    $cl = $script:C
    $ay = $from[1] + [math]::Floor($cl / 2)
    $hx = 40 + $wh[0] + 150; $hy = $ay - [math]::Floor($cl / 2)
    ArrowRight $g ($from[0] + $cl + 8) $ay ($hx - $from[0] - $cl - 22)
    Held $g $hx $hy 1 3 "wpn" "bat"
    KeepHint $g ($hx + $cl + 26) ($hy + [math]::Floor($cl * 1.6)) $lang
    $script:C = 64
    $tx = 40 + $wh[0] + 90; $ty = 110; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.keepA $tx $ty $tw 19 $null 28
    $ty = CapsBlock $g $s.keepB $tx ($ty + 12) $tw 19 $K.accent 28
    CapsBlock $g $s.keepC $tx ($ty + 12) $tw 19 $null 28 | Out-Null
    Save $bmp $g "u0986_keep_$lang.png"

    # --- art: the card, big, on the frame's colour, the bat on its way out of it
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 64 56 30 $K.accent
    $script:C = 84
    $wh = BagCard $g 70 130 $lang $true
    # (the bat in hand, out past the card's edge: on its way to the camp)
    Held $g (70 + $wh[0] + 60) ($script:batAt[1] - 40) 1 3 "wpn" "bat"
    $script:C = 64
    Save $bmp $g "u0986_art_$lang.png"

    # --- banner, no words: a bag's grid in the dark, its things, darkest on the left
    BannerPattern "u0986_banner_$lang.png" @(
        @(10, 1, 1, 3, "wpn", "bat", ""), @(11, 2, 1, 2, "tool", "hammer", ""),
        @(12, 0, 1, 1, "food", "bottle", ""), @(13, 0, 1, 1, "food", "chips", ""),
        @(14, 1, 2, 2, "clo", "bag_school", "hit"), @(12, 3, 1, 1, "info", "idcard", ""),
        @(16, 3, 1, 1, "info", "keyring", ""), @(8, 2, 1, 1, "tool", "screwdriver", ""))
}
