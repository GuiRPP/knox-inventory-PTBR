# Pictures of the 0.9.8 news post (Order: Sort by category, layouts with their
# silhouettes and the eye, things going to their places, stacks topped up and lit,
# the Order tab of the settings), by the approved news rules (see make_news_096.ps1
# and news_ui.ps1): pieces of the Knox screen itself, the game's own icons and words,
# captions in capitals, a banner with no words, a picture per language.
#   42\media\knox\news\u098_<name>_<ru|en>.png   banner, art, sort, layout, stacks, settings
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_098.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")
$K.ammo = Hex "#3a321c"   # (KnoxTheme T.category.ammo: not in news_ui yet)

$L = @{
    ru = @{
        soTitle = "СОРТИРОВКА РАСКЛАДЫВАЕТ ВЕЩИ ПО КАТЕГОРИЯМ"
        before = "ДО"; after = "ПОСЛЕ"
        soA = "КАЖДАЯ КАТЕГОРИЯ - СВОИМ БЛОКОМ, В ВАШЕМ ПОРЯДКЕ."
        soB = "ДВЕ НЕПОЛНЫЕ СТОПКИ БИНТОВ СЛИЛИСЬ В ОДНУ."
        soC = "ЕДА, КОТОРАЯ ИСПОРТИТСЯ РАНЬШЕ, - ПЕРВОЙ. ВЕЩИ ПОД ЗАМКОМ ОСТАЮТСЯ НА МЕСТЕ."
        soD = "КНОПКА СОРТИРОВКИ ТЕПЕРЬ ЕСТЬ И У ВАШИХ СУМОК. ПКМ ПО ЗАГОЛОВКУ - ДРУГИЕ ПРАВИЛА: ПЛОТНО, ПО НАЗВАНИЮ, ПО ВЕСУ."
        laTitle = "РАЗЛОЖИТЕ ОДИН РАЗ - ВЕЩИ САМИ ВЕРНУТСЯ НА СВОИ МЕСТА"
        laA = "ПКМ ПО ЗАГОЛОВКУ - «ЗАПОМНИТЬ РАСКЛАДКУ». МЕСТО ВЕЩИ, КОТОРОЙ НЕТ, ВИДНО БЛЕДНЫМ СИЛУЭТОМ."
        laB = "ПОДОБРАННАЯ ВЕЩЬ ЛОЖИТСЯ НА СВОЁ МЕСТО. НЕТ СВОЕГО - ЗАЙМЁТ МЕСТО СВОЕЙ КАТЕГОРИИ: ТОПОР ЛЯЖЕТ ТУДА, ГДЕ ЛЕЖАЛА БИТА."
        laC = "ГЛАЗ РЯДОМ С КНОПКОЙ СОРТИРОВКИ ПРЯЧЕТ И ПОКАЗЫВАЕТ СИЛУЭТЫ."
        picked = "ПОДОБРАЛИ ТОПОР"
        stTitle = "SHIFT ДОКЛАДЫВАЕТ В ВАШУ СТОПКУ, В КАКОЙ БЫ СУМКЕ ОНА НИ ЛЕЖАЛА"
        stA = "НАВЕЛИ НА ВЕЩЬ ВОКРУГ - ВАШИ СТОПКИ ТОГО ЖЕ ВИДА ЗАГОРАЮТСЯ."
        green = "ЗЕЛЁНАЯ - В НЕЁ ЕЩЁ ВЛЕЗЕТ"; red = "КРАСНАЯ - ПОЛНАЯ"
        stB = "SHIFT+ЩЕЛЧОК И «ЗАБРАТЬ ВСЁ» СНАЧАЛА ПОПОЛНЯЮТ СТОПКИ, ПОТОМ ИЩУТ МЕСТО. НЕ ВЛЕЗЛО ЦЕЛИКОМ - ОСТАТОК ЛЯЖЕТ ОТДЕЛЬНО."
        seTitle = "НОВАЯ ВКЛАДКА НАСТРОЕК - «ПОРЯДОК»"
        seA = "ПРАВИЛО СОРТИРОВКИ И КУДА ЛОЖАТСЯ НОВЫЕ ВЕЩИ."
        seB = "ПОРЯДОК КАТЕГОРИЙ - ПЕРЕТАЩИТЕ СТРОКУ МЫШЬЮ ИЛИ НАЖМИТЕ СТРЕЛКИ СЛЕВА."
        seC = "СВОЮ КАТЕГОРИЮ ДЛЯ ЛЮБОЙ ВЕЩИ МОЖНО ЗАДАТЬ В KNOX_OVERRIDES.TXT."
        artTitle = "ВСЁ НА СВОИХ МЕСТАХ"
        floor = "ПОЛ"
        skTitle = "СКИНЫ: ВЫБЕРИТЕ ГЛАВНЫЙ ЦВЕТ ИНВЕНТАРЯ"
        skA = "НАСТРОЙКИ > ВИД > СКИН. ШЕСТЬ ГОТОВЫХ ИЛИ СВОЙ: ОТТЕНОК, НАСЫЩЕННОСТЬ И ЯРКОСТЬ. МЕНЯЕТСЯ СРАЗУ, ВМЕСТЕ С КУРСОРОМ, ПОДСКАЗКАМИ И ЭКРАНОМ ЗАГРУЗКИ."
        skB = "ЦВЕТА КАТЕГОРИЙ У ПЛИТОК ОСТАЮТСЯ - ПО НИМ ВЕЩИ УЗНАЮТСЯ С ПЕРВОГО ВЗГЛЯДА."
    }
    en = @{
        soTitle = "SORT LAYS THINGS OUT BY CATEGORY"
        before = "BEFORE"; after = "AFTER"
        soA = "EACH CATEGORY IN A BLOCK OF ITS OWN, IN YOUR ORDER."
        soB = "TWO PART STACKS OF BANDAGES BECAME ONE."
        soC = "FOOD THAT SPOILS SOONER GOES FIRST. LOCKED THINGS STAY WHERE THEY ARE."
        soD = "YOUR OWN BAGS HAVE THE SORT BUTTON TOO. RIGHT CLICK THE HEADER FOR OTHER RULES: TIGHT, BY NAME, BY WEIGHT."
        laTitle = "LAY A BAG OUT ONCE - THINGS GO BACK TO THEIR PLACES BY THEMSELVES"
        laA = "RIGHT CLICK THE HEADER - SAVE LAYOUT. THE PLACE OF A THING THAT IS MISSING SHOWS AS A PALE SILHOUETTE."
        laB = "A THING YOU PICK UP GOES TO ITS PLACE. NO PLACE OF ITS OWN - IT TAKES ONE OF ITS CATEGORY: THE AXE GOES WHERE THE BAT WAS."
        laC = "THE EYE BY THE SORT BUTTON HIDES AND SHOWS THE SILHOUETTES."
        picked = "PICKED UP AN AXE"
        stTitle = "SHIFT ADDS TO YOUR STACK, WHICHEVER BAG IT IS IN"
        stA = "REST THE MOUSE ON A THING AROUND - YOUR STACKS OF ITS KIND LIGHT UP."
        green = "GREEN - THERE IS ROOM"; red = "RED - IT IS FULL"
        stB = "SHIFT+CLICK AND TAKE ALL TOP UP YOUR STACKS FIRST, THEN LOOK FOR A PLACE. IF NOT ALL OF IT FITS, THE REST GOES APART."
        seTitle = "A NEW SETTINGS TAB - ORDER"
        seA = "THE SORT RULE AND WHERE NEW THINGS GO."
        seB = "THE ORDER OF CATEGORIES - DRAG A ROW WITH THE MOUSE OR PRESS THE ARROWS ON THE LEFT."
        seC = "ANY THING'S CATEGORY CAN BE SET IN KNOX_OVERRIDES.TXT."
        artTitle = "EVERYTHING IN ITS PLACE"
        floor = "GROUND"
        skTitle = "SKINS: PICK THE INVENTORY'S MAIN COLOUR"
        skA = "SETTINGS > LOOK > SKIN. SIX READY ONES OR YOUR OWN: HUE, SATURATION AND BRIGHTNESS. IT CHANGES AT ONCE, WITH THE CURSOR, THE TOOLTIPS AND THE LOADING SCREEN."
        skB = "TILES KEEP THEIR CATEGORY COLOURS - THEY TELL THINGS APART AT A GLANCE."
    }
}

# --- small parts -------------------------------------------------------------------------

# the Sort button (three bars, each shorter) and the eye, as KnoxLootPanel draws them
function SortBtn($g, $x, $y, $s, $c) {
    Fill $g $K.buttonBg $x $y $s $s; Frame $g $K.tileEdge $x $y $s $s 1
    $u = [math]::Max(2, [math]::Round($s / 9)); $p = [math]::Round($s * 0.24); $w = $s - 2 * $p
    $step = [math]::Floor(($w - $u) / 2)
    Fill $g $c ($x + $p) ($y + $p) $w $u
    Fill $g $c ($x + $p) ($y + $p + $step) ([math]::Round($w * 0.66)) $u
    Fill $g $c ($x + $p) ($y + $p + 2 * $step) ([math]::Round($w * 0.33)) $u
}
function EyeBtn($g, $x, $y, $s, $c, $openK = 1) {   # (not $k: that is the palette $K)
    Fill $g $K.buttonBg $x $y $s $s; Frame $g $K.tileEdge $x $y $s $s 1
    $u = [math]::Max(2, [math]::Round($s / 10)); $cx = $x + [math]::Floor($s / 2); $cy = $y + [math]::Floor($s / 2)
    $half = [math]::Floor($s * 0.36); $open = $s * 0.27 * $openK
    for ($dx = -$half; $dx -le $half; $dx++) {
        $t = $dx / $half; $h = [math]::Floor($open * (1 - $t * $t) + 0.5)
        Fill $g $c ($cx + $dx) ($cy - $h - [math]::Floor($u / 2)) 1 $u
        if ($h -gt 0) { Fill $g $c ($cx + $dx) ($cy + $h - [math]::Floor($u / 2)) 1 $u }
    }
    $pr = [math]::Floor($s * 0.15 + 0.5); $inside = [math]::Floor($open) - $u
    for ($dy = -$pr; $dy -le $pr; $dy++) {
        if ([math]::Abs($dy) -le $inside) { $w = [math]::Floor([math]::Sqrt([math]::Max(0, $pr * $pr - $dy * $dy)) + 0.5); Fill $g $c ($cx - $w) ($cy + $dy) ($w * 2 + 1) 1 }
    }
    if ($openK -lt 0.5) {
        $len = [math]::Max(2, [math]::Floor($s * 0.1))
        foreach ($d in @(-[math]::Floor($half * 0.6), 0, [math]::Floor($half * 0.6))) { Fill $g $c ($cx + $d - [math]::Floor($u / 2)) ($cy + [math]::Floor($u / 2) + 1) $u $len }
    }
}
# a bag's header strip with the Sort button and (when it has a layout) the eye at its right end
function BagStrip($g, $x, $y, $w, $name, $info, $eye = $null) {
    Strip $g $x $y $w $name $null
    $s = 28; $bx = $x + $w - 4 - $s
    SortBtn $g $bx ($y + 4) $s $K.text
    if ($eye -ne $null) { $bx -= $s + 4; EyeBtn $g $bx ($y + 4) $s $K.text $eye }
    if ($info) { TxtMid $g $info "head" 18 $K.dim ($bx - 10 - (TextW $g $info "head" 18)) $y 36 }
}
# a layout's place waiting for its thing: a pale plate of its category, its icon faint
function Silhouette($g, $gx, $gy, $col, $row, $w, $h, $cat, $icon) {
    $x = $gx + $col * $C + 1; $y = $gy + $row * $C + 1; $pw = $w * $C - 1; $ph = $h * $C - 1
    Fill $g $K[$cat] $x $y $pw $ph 0.35
    Frame $g $K.tileEdge $x $y $pw $ph 1 0.6
    DrawIcon $g $icon $x $y $pw $ph 0.22 ([math]::Floor([math]::Min($pw, $ph) * 0.85))
}
# a tile lit by the stack hint: green (room) or red (full)
function Hint($g, $gx, $gy, $col, $row, $w, $h, $hintColor) {
    # (not $c: PowerShell names ignore case, and $c is the cell $C)
    $x = $gx + $col * $C + 1; $y = $gy + $row * $C + 1; $pw = $w * $C - 1; $ph = $h * $C - 1
    Fill $g $hintColor $x $y $pw $ph 0.18; Frame $g $hintColor $x $y $pw $ph 2
}
# an arrow button (the Order tab's rows)
function ArrowBtn($g, $x, $y, $s, $up, $c) {
    Fill $g $K.buttonBg $x $y $s $s; Frame $g $K.tileEdge $x $y $s $s 1
    $n = [math]::Max(3, [math]::Floor($s / 5)); $cx = $x + [math]::Floor($s / 2); $top = $y + [math]::Floor(($s - $n) / 2)
    for ($i = 0; $i -lt $n; $i++) { $hw = $(if ($up) { $i } else { $n - 1 - $i }); Fill $g $c ($cx - $hw) ($top + $i) ($hw * 2 + 1) 1 }
}

# the backpack's contents, messy and sorted (col, row, w, h, cat, icon, count)
$MESS = @(
    @(0, 0, 2, 2, "clo", "tshirt", $null), @(2, 0, 1, 1, "med", "bandage", "2"), @(3, 0, 1, 4, "wpn", "axe", $null),
    @(4, 0, 1, 1, "food", "chips", $null), @(5, 0, 1, 1, "mat", "nails", "40"), @(2, 1, 1, 2, "tool", "hammer", $null),
    @(4, 1, 1, 2, "food", "bottle", $null), @(5, 1, 1, 1, "med", "pills", $null), @(0, 2, 1, 1, "ammo", "ammo9", "24"),
    @(1, 2, 1, 2, "tool", "screwdriver", $null), @(5, 2, 1, 1, "med", "bandage", "1"), @(0, 3, 1, 1, "food", "beans", $null),
    @(2, 3, 1, 2, "wpn", "knife", $null), @(4, 3, 1, 1, "info", "book", $null), @(5, 3, 1, 1, "mat", "tape", $null)
)
$SORTED = @(
    @(0, 0, 1, 4, "wpn", "axe", $null), @(1, 0, 1, 2, "wpn", "knife", $null), @(2, 0, 1, 1, "ammo", "ammo9", "24"),
    @(3, 0, 1, 1, "med", "bandage", "3"), @(4, 0, 1, 1, "med", "pills", $null), @(5, 0, 1, 1, "food", "apple", $null),
    @(2, 1, 1, 2, "food", "bottle", $null), @(3, 1, 1, 1, "food", "beans", $null), @(4, 1, 1, 2, "tool", "hammer", $null),
    @(5, 1, 1, 2, "tool", "screwdriver", $null), @(1, 2, 1, 1, "mat", "nails", "40"), @(3, 2, 1, 1, "mat", "tape", $null),
    @(1, 3, 2, 2, "clo", "tshirt", $null), @(3, 3, 1, 1, "info", "book", $null)
)
function Tiles($g, $gx, $gy, $list) {
    foreach ($t in $list) { Tile $g $gx $gy $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] "" $t[6] }
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.8 ($lang):"
    $pack = GTr $lang "ItemName" "Base.Bag_ALICEpack"
    if ($pack -eq "Base.Bag_ALICEpack") { $pack = $(if ($lang -eq "ru") { "Военный рюкзак" } else { "Military Backpack" }) }
    $pack = Up $pack
    $pockets = Up (Tr $lang "IGUI_Knox_Pockets")

    # --- Sort: before and after
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.soTitle 24 26
    $gx1 = 40; $gy = 150
    Tag $g $gx1 84 $s.before $K.tileEdge $K.bright | Out-Null
    BagStrip $g $gx1 114 (6 * $C + 1) $pack $null
    Grid $g $gx1 $gy 6 5; Tiles $g $gx1 $gy $MESS
    ArrowRight $g ($gx1 + 6 * $C + 22) ($gy + 2.5 * $C) 70
    $gx2 = $gx1 + 6 * $C + 112
    Tag $g $gx2 84 $s.after $K.accent | Out-Null
    BagStrip $g $gx2 114 (6 * $C + 1) $pack $null
    Grid $g $gx2 $gy 6 5; Tiles $g $gx2 $gy $SORTED
    # the Sort button pressed: a sand frame on it
    Frame $g $K.accent ($gx2 + 6 * $C + 1 - 4 - 28) 118 28 28 2
    $tx = $gx2 + 6 * $C + 36; $ty = 120; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.soA $tx $ty $tw; $ty = CapsBlock $g $s.soB $tx ($ty + 12) $tw
    $ty = CapsBlock $g $s.soC $tx ($ty + 12) $tw
    CapsBlock $g $s.soD $tx ($ty + 12) $tw | Out-Null
    Save $bmp $g "u098_sort_$lang.png"

    # --- the layout: silhouettes; a picked-up axe goes to the bat's place
    $bmp, $g = Canvas 1280 640 $K.screen
    Caption $g $s.laTitle 24 26
    $gx1 = 40; $gy = 130
    BagStrip $g $gx1 94 (6 * $C + 1) $pack $null 1
    Grid $g $gx1 $gy 6 5
    Silhouette $g $gx1 $gy 0 0 1 4 "wpn" "bat"
    foreach ($t in $SORTED) { if ($t[5] -ne "axe" -and $t[5] -ne "hammer") { Tile $g $gx1 $gy $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] "" $t[6] } }
    Silhouette $g $gx1 $gy 4 1 1 2 "tool" "hammer"
    # the axe at the cursor, on its way
    $hx = $gx1 + 6 * $C + 36; $hy = $gy + 40
    CapsBlock $g $s.picked $hx ($hy - 34) 220 17 $K.accent | Out-Null
    Held $g $hx $hy 1 4 "wpn" "axe"
    ArrowRight $g ($hx + $C + 16) ($gy + 2.5 * $C) 60
    $gx2 = $hx + $C + 96
    BagStrip $g $gx2 94 (6 * $C + 1) $pack $null 1
    Grid $g $gx2 $gy 6 5
    foreach ($t in $SORTED) { if ($t[5] -ne "hammer") { Tile $g $gx2 $gy $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] "" $t[6] } }
    Silhouette $g $gx2 $gy 4 1 1 2 "tool" "hammer"
    Frame $g $K.accent ($gx2 + 1) ($gy + 1) ($C - 1) (4 * $C - 1) 2
    # the eye: open and shut
    $ex = $gx2 + 6 * $C + 30; $ey = 100
    EyeBtn $g $ex $ey 40 $K.accent 1; EyeBtn $g ($ex + 52) $ey 40 $K.dim 0
    $ty = $gy + 5 * $C + 26
    $ty = CapsBlock $g $s.laA 40 $ty 1200; $ty = CapsBlock $g $s.laB 40 ($ty + 8) 1200
    CapsBlock $g $s.laC 40 ($ty + 8) 1200 | Out-Null
    Save $bmp $g "u098_layout_$lang.png"

    # --- stacks: lit by a thing around, topped up by Shift
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.stTitle 24 26
    $fx = 40; $fy = 130
    Strip $g $fx 94 (4 * $C + 1) $s.floor "4x3" $null $true
    Grid $g $fx $fy 4 3
    Tile $g $fx $fy 0 0 1 1 "med" "bandage" "" "2"; Tile $g $fx $fy 1 0 2 2 "clo" "jacket"; Tile $g $fx $fy 0 1 1 2 "food" "bottle"
    Frame $g $K.tileHover ($fx + 1) ($fy + 1) ($C - 1) ($C - 1) 2
    Cursor $g ($fx + 30) ($fy + 30)
    ArrowRight $g ($fx + 4 * $C + 20) ($fy + 1.5 * $C) 70
    $px = $fx + 4 * $C + 110
    Strip $g $px 94 (4 * $C + 1) $pockets "4x2"
    Grid $g $px $fy 4 2
    Tile $g $px $fy 0 0 1 1 "med" "bandage" "" "3"; Tile $g $px $fy 1 0 1 1 "info" "idcard"; Tile $g $px $fy 2 0 1 1 "tool" "battery"
    Hint $g $px $fy 0 0 1 1 $K.ok
    $bx = $px + 4 * $C + 40
    BagStrip $g $bx 94 (5 * $C + 1) $pack $null
    Grid $g $bx $fy 5 3
    Tile $g $bx $fy 0 0 1 1 "med" "bandage" "" "10"; Tile $g $bx $fy 1 0 1 2 "food" "bottle"; Tile $g $bx $fy 2 0 2 2 "clo" "tshirt"; Tile $g $bx $fy 4 0 1 1 "med" "pills"
    Hint $g $bx $fy 0 0 1 1 $K.bad
    Tag $g $px ($fy + 2 * $C + 16) $s.green $K.ok | Out-Null
    Tag $g $bx ($fy + 3 * $C + 16) $s.red $K.bad $K.bright | Out-Null
    $ty = $fy + 3 * $C + 64
    $ty = CapsBlock $g $s.stA 40 $ty 1200
    CapsBlock $g $s.stB 40 ($ty + 8) 1200 | Out-Null
    Save $bmp $g "u098_stacks_$lang.png"

    # --- the Order tab of the settings
    $bmp, $g = Canvas 1280 700 $K.screen
    Caption $g $s.seTitle 24 26
    $wx = 40; $wy = 80; $ww = 760; $wh = 600
    Win $g $wx $wy $ww $wh (Tr $lang "IGUI_Knox_Settings")
    $pages = @(); foreach ($pageName in "modules", "look", "game", "order", "controls") { $pages += Tr $lang ("IGUI_Knox_Page_" + $pageName) }   # (not $p: that is the pad $P)
    $ty = Tabs $g $wx ($wy + 44) $ww $pages 3
    $cx = $wx + 2 * $P; $cy = $ty + 20
    $rules = @(); foreach ($r in "zones", "dense", "name", "weight") { $rules += Tr $lang ("IGUI_Knox_Choice_order_rule_" + $r) }
    $cy = Choice $g $cx $cy (Tr $lang "IGUI_Knox_Choice_order_rule") $rules 0
    $autos = @(); foreach ($r in "layout", "zones", "off") { $autos += Tr $lang ("IGUI_Knox_Choice_order_auto_" + $r) }
    $cy = Choice $g $cx ($cy + 18) (Tr $lang "IGUI_Knox_Choice_order_auto") $autos 0
    TxtMid $g (Tr $lang "IGUI_Knox_Order_Cats") "body" 20 $K.bright $cx ($cy + 18) 32
    $ry = $cy + 60; $rh = 36; $bs = 36
    $cats = @("food", "wpn", "ammo", "med", "tool", "mat")
    for ($i = 0; $i -lt $cats.Count; $i++) {
        $cat = $cats[$i]; $y = $ry + $i * ($rh + 4)
        ArrowBtn $g $cx $y $bs $true $(if ($i -eq 0) { $K.tileEdge } else { $K.text })
        ArrowBtn $g ($cx + $bs + 4) $y $bs $false $K.text
        $plx = $cx + 2 * $bs + 12; $plw = $ww - 4 * $P - 2 * $bs - 12
        $held = $i -eq 1
        Fill $g $K[$cat] $plx $y $plw $rh
        Frame $g $(if ($held) { $K.accent } else { $K.tileFrame }) $plx $y $plw $rh 2
        TxtMid $g ("" + ($i + 1) + ".  " + (Tr $lang ("IGUI_Knox_Cat_" + $cat))) "body" 20 $(if ($held) { $K.accent } else { $K.bright }) ($plx + 14) $y $rh
        if ($held) { Cursor $g ($plx + $plw * 0.6) ($y + 12) }
    }
    $tx = $wx + $ww + 40; $ty = 120
    $ty = CapsBlock $g $s.seA $tx $ty 400; $ty = CapsBlock $g $s.seB $tx ($ty + 14) 400
    CapsBlock $g $s.seC $tx ($ty + 14) 400 | Out-Null
    Save $bmp $g "u098_settings_$lang.png"

    # --- art: the inventory column, a big pack laid out, its silhouettes, sort and eye
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 60 56 26
    Column $g 60 110 840 600 (Tr $lang "IGUI_Knox_Inventory")
    $ax = 108; $ay = 220
    BagStrip $g $ax 180 (11 * $C + 1) $pack "11x7" 1
    Grid $g $ax $ay 11 7
    $ART = @(
        @(0, 0, 2, 4, "wpn", "rifle"), @(2, 0, 1, 4, "wpn", "axe"), @(3, 0, 1, 2, "wpn", "knife"), @(3, 2, 2, 2, "wpn", "pistol"),
        @(5, 0, 1, 1, "ammo", "ammo9", "60"), @(6, 0, 1, 1, "ammo", "shells", "24"),
        @(7, 0, 1, 1, "med", "bandage", "6"), @(8, 0, 1, 1, "med", "pills"), @(9, 0, 1, 1, "med", "bandage", "2"),
        @(5, 1, 1, 2, "food", "bottle"), @(6, 1, 1, 1, "food", "beans"), @(7, 1, 1, 1, "food", "beans"), @(8, 1, 1, 1, "food", "chips"), @(9, 1, 1, 1, "food", "apple"),
        @(6, 2, 1, 2, "tool", "hammer"), @(7, 2, 1, 2, "tool", "screwdriver"), @(8, 2, 1, 2, "tool", "torch"), @(9, 2, 1, 1, "tool", "battery"),
        @(0, 4, 1, 1, "mat", "nails", "80"), @(1, 4, 1, 1, "mat", "screws", "40"), @(2, 4, 1, 1, "mat", "tape"), @(3, 4, 1, 1, "mat", "glue"),
        @(0, 5, 2, 2, "clo", "tshirt"), @(2, 5, 2, 2, "clo", "hoodie"), @(4, 5, 2, 2, "clo", "trousers"),
        @(6, 5, 1, 1, "info", "book"), @(7, 5, 1, 1, "info", "idcard"), @(8, 5, 1, 1, "info", "keyring")
    )
    foreach ($t in $ART) { Tile $g $ax $ay $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] "" $(if ($t.Count -gt 6) { $t[6] } else { $null }) }
    Silhouette $g $ax $ay 10 0 1 2 "food" "bottle"; Silhouette $g $ax $ay 9 3 1 1 "tool" "pliers"; Silhouette $g $ax $ay 6 4 2 1 "info" "book"
    Silhouette $g $ax $ay 4 4 1 1 "mat" "thread"
    # under it: the order of the categories, as the settings tab shows it
    TxtMid $g (Up (Tr $lang "IGUI_Knox_Order_Cats")) "head" 19 $K.accent 60 744 32
    $cats = @("wpn", "ammo", "med", "food", "tool", "mat"); $bs = 36
    for ($i = 0; $i -lt $cats.Count; $i++) {
        $y = 792 + $i * 40
        ArrowBtn $g 60 $y $bs $true $(if ($i -eq 0) { $K.tileEdge } else { $K.text })
        ArrowBtn $g (60 + $bs + 4) $y $bs $false $K.text
        $plx = 60 + 2 * $bs + 12; $plw = 840 - 2 * $bs - 12
        Fill $g $K[$cats[$i]] $plx $y $plw $bs; Frame $g $K.tileFrame $plx $y $plw $bs 2
        TxtMid $g ("" + ($i + 1) + ".  " + (Tr $lang ("IGUI_Knox_Cat_" + $cats[$i]))) "body" 20 $K.bright ($plx + 14) $y $bs
    }
    Save $bmp $g "u098_art_$lang.png"

    # --- skins (beta): the same piece of the inventory in each preset, its cursor too
    $palette0 = @{}; foreach ($pk in @($K.Keys)) { $palette0[$pk] = $K[$pk] }
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.skTitle 24 26
    $tw0 = Tag $g (24 + (TextW $g $s.skTitle "title" 28) + 16) 24 (Up (Tr $lang "IGUI_Knox_Beta")) $K.warn
    $skinList = @(
        @{id = "sand"},
        @{id = "blood"; accent = "#d8705f"; window = "#151111"; header = "#1d1616"; border = "#2e2424"; cell = "#100c0c"; line = "#2a2020"; tileEdge = "#443838"; tileFrame = "#634f4f"; text = "#ddd2cc"; bright = "#f0e6e2"; dim = "#978986"; buttonBg = "#221a1a"; screen = "#0d0909"},
        @{id = "pine"; accent = "#b5c278"; window = "#111411"; header = "#181d18"; border = "#273027"; cell = "#0c100c"; line = "#212821"; tileEdge = "#384238"; tileFrame = "#566255"; text = "#d3d9c8"; bright = "#e7ecdc"; dim = "#899282"; buttonBg = "#1b221b"; screen = "#0a0d0a"},
        @{id = "ice"; accent = "#8ec5e0"; window = "#101317"; header = "#171c21"; border = "#262e36"; cell = "#0b0f12"; line = "#20272e"; tileEdge = "#37414a"; tileFrame = "#535e69"; text = "#d0d8de"; bright = "#e6edf2"; dim = "#87929b"; buttonBg = "#1a2026"; screen = "#090c0f"},
        @{id = "night"; accent = "#86f07e"; window = "#070d07"; header = "#0c150c"; border = "#173017"; cell = "#050a05"; line = "#122412"; tileEdge = "#1f4a1f"; tileFrame = "#2f6a2f"; text = "#a8f0a0"; bright = "#d0ffc8"; dim = "#5f9f5a"; buttonBg = "#0d1a0d"; screen = "#040804"},
        @{id = "coal"; accent = "#cfcfcf"; window = "#121212"; header = "#1a1a1a"; border = "#2b2b2b"; cell = "#0d0d0d"; line = "#242424"; tileEdge = "#3e3e3e"; tileFrame = "#5c5c5c"; text = "#d8d8d8"; bright = "#ededed"; dim = "#8f8f8f"; buttonBg = "#202020"; screen = "#0a0a0a"}
    )
    $panW = 400; $panH = 250
    for ($n = 0; $n -lt $skinList.Count; $n++) {
        foreach ($pk in @($palette0.Keys)) { $K[$pk] = $palette0[$pk] }
        $skinOne = $skinList[$n]
        foreach ($pk in @($skinOne.Keys)) { if ($pk -ne "id") { $K[$pk] = Hex $skinOne[$pk] } }
        $lum = 0.2126 * $K.accent.R / 255 + 0.7152 * $K.accent.G / 255 + 0.0722 * $K.accent.B / 255
        $inkC = $(if ($lum -gt 0.45) { Hex "#141414" } else { Hex "#ece8d8" })
        $px0 = 24 + ($n % 3) * ($panW + 16); $py0 = 84 + [math]::Floor($n / 3) * ($panH + 16)
        Fill $g $K.window $px0 $py0 $panW $panH; Frame $g $K.border $px0 $py0 $panW $panH 1
        Txt $g (Up (Tr $lang ("IGUI_Knox_Skin_" + $skinOne.id))) "head" 19 $K.accent ($px0 + 16) ($py0 + 16)
        $gx = $px0 + 16; $gy = $py0 + 92
        Strip $g $gx ($gy - 36) (4 * $C + 1) $pack $null $null $true
        Grid $g $gx $gy 4 2
        Tile $g $gx $gy 0 0 1 2 "wpn" "axe"; Tile $g $gx $gy 1 0 1 1 "med" "bandage" "" "3"; Tile $g $gx $gy 2 0 2 2 "clo" "tshirt"; Tile $g $gx $gy 1 1 1 1 "food" "apple"
        Frame $g $K.accent ($gx + $C + 1) ($gy + 1) ($C - 1) ($C - 1) 2
        $bx = $gx + 4 * $C + 16; $bw = $panW - (4 * $C + 48)
        Fill $g $K.accent $bx $gy $bw 36; TxtCentre $g (Up (Tr $lang "IGUI_Knox_TakeAll")) "head" 15 $inkC $bx $gy $bw 36
        Fill $g $K.buttonBg $bx ($gy + 46) $bw 36; Frame $g $K.tileEdge $bx ($gy + 46) $bw 36 1
        TxtCentre $g (Up (Tr $lang "IGUI_Knox_Sort")) "head" 15 $K.text $bx ($gy + 46) $bw 36
        # the cursor of this skin
        $curFile = Join-Path $ui $(if ($skinOne.id -eq "sand") { "knox_cursor.png" } else { "knox_cursor_" + $skinOne.id + ".png" })
        $curImg = [System.Drawing.Image]::FromFile($curFile)
        $g.DrawImage($curImg, (New-Object System.Drawing.RectangleF ([float]($bx + $bw / 2 + 6)), ([float]($gy + 18)), 34, 34))
        $curImg.Dispose()
    }
    foreach ($pk in @($palette0.Keys)) { $K[$pk] = $palette0[$pk] }
    $ty = 84 + 2 * ($panH + 16) + 8
    $ty = CapsBlock $g $s.skA 24 $ty 1230
    CapsBlock $g $s.skB 24 ($ty + 6) 1230 | Out-Null
    Save $bmp $g "u098_skins_$lang.png"

    # --- banner: a grid sorted into blocks of colour, several lit - in the post's
    # green (@frame: the skins came with this update), not sand
    $accent0 = $K.accent; $K.accent = Hex "#7cc35a"
    BannerPattern "u098_banner_$lang.png" @(
        @(7, 0, 1, 3, "wpn", "axe", "hit"), @(8, 0, 1, 2, "wpn", "knife", ""), @(9, 0, 1, 1, "ammo", "ammo9", "hit"), @(10, 0, 1, 1, "ammo", "shells", ""),
        @(11, 0, 1, 1, "med", "bandage", "hit"), @(12, 0, 1, 1, "med", "pills", ""), @(13, 0, 1, 2, "food", "bottle", ""), @(14, 0, 1, 1, "food", "beans", "hit"),
        @(15, 0, 1, 1, "food", "apple", "hit"), @(16, 0, 1, 1, "food", "chips", ""),
        @(9, 1, 1, 2, "tool", "hammer", ""), @(10, 1, 1, 2, "tool", "screwdriver", "hit"), @(11, 1, 1, 1, "mat", "nails", ""), @(12, 1, 1, 1, "mat", "tape", "hit"),
        @(14, 1, 2, 2, "clo", "tshirt", "hit"), @(16, 1, 1, 1, "info", "book", ""), @(8, 2, 1, 1, "mat", "screws", ""), @(11, 2, 1, 1, "tool", "battery", "hit"),
        @(12, 2, 2, 2, "clo", "hoodie", ""), @(16, 2, 1, 1, "info", "idcard", "hit")
    )
    $K.accent = $accent0
}
