# Pictures of the 0.9.0 news post (Scavenger: real sizes, bag shapes, stacks,
# pockets, the Surroundings, cooking, convenience, searching, settings), made anew in
# 2026-10 by the approved news rules (see make_news_096.ps1 and news_ui.ps1).
#   42\media\knox\news\u090_<name>_<ru|en>.png
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_090.ps1

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "news_ui.ps1")

# a tile's size written in its corner ("1x6"), on a dark plate
function SizeTag($g, $gx, $gy, $col, $row, $text) {
    $x = $gx + $col * $C + 4; $y = $gy + $row * $C + 4
    $w = (TextW $g $text "head" 14) + 10
    Fill $g $K.screen $x $y $w 20 0.85
    TxtCentre $g $text "head" 14 $K.accent $x $y $w 20
}
# a container's header strip with the action buttons Knox draws (take all, to the left, sort)
function StripActions($g, $x, $y, $w, $name, $info, $active, $lit = $false) {
    Strip $g $x $y $w $name $info $null $active
    $bx = $x + $w - 12 - 3 * 30 - (TextW $g $info "head" 18) - 16
    foreach ($i in 0..2) {
        $ax = $bx + $i * 30; $ay = $y + 6
        Fill $g $K.buttonBg $ax $ay 24 24; Frame $g $K.tileEdge $ax $ay 24 24 1
        $c = $(if ($lit -and $i -eq 0) { $K.ok } else { $K.text })
        switch ($i) {
            0 { if ($lit) { $pen = New-Object System.Drawing.Pen (A $c 1), 2; $g.SmoothingMode = 'AntiAlias'; $g.DrawArc($pen, $ax + 6, $ay + 6, 12, 12, -60, 300); $g.DrawLine($pen, $ax + 12, $ay + 4, $ax + 12, $ay + 11); $g.SmoothingMode = 'None' }
                else { Fill $g $c ($ax + 11) ($ay + 5) 2 10; Fill $g $c ($ax + 6) ($ay + 17) 12 2 } }
            1 { Fill $g $c ($ax + 6) ($ay + 6) 2 12; Fill $g $c ($ax + 10) ($ay + 11) 9 2 }
            2 { Fill $g $c ($ax + 6) ($ay + 7) 12 2; Fill $g $c ($ax + 6) ($ay + 11) 9 2; Fill $g $c ($ax + 6) ($ay + 15) 6 2 }
        }
    }
}
# the food tile's state over it (KnoxTheme T.cookBar): a tint, a bar filling from below
$COOK_BLUE = [System.Drawing.Color]::FromArgb(255, 74, 143, 209); $COOK_ORANGE = [System.Drawing.Color]::FromArgb(255, 224, 138, 43)
function CookTile($g, $gx, $gy, $col, $row, $w, $h, $icon, $base, $bar, $frac) {
    Tile $g $gx $gy $col $row $w $h "food" $icon
    $x = $gx + $col * $C + 1; $y = $gy + $row * $C + 1; $pw = $w * $C - 1; $ph = $h * $C - 1
    if ($base) { Fill $g $base $x $y $pw $ph 0.22 }
    $fh = [int]($ph * $frac)
    if ($fh -gt 0) { Fill $g $bar $x ($y + $ph - $fh) $pw $fh 0.5; Fill $g $bar $x ($y + $ph - $fh) $pw 2 0.95 }
    DrawIcon $g $icon $x $y $pw $ph 1 ([math]::Floor([math]::Min($pw, $ph) * 0.85))
}
# a hand slot with the mod's palm picture
function HandSlot($g, $x, $y, $w, $h, $label, $png) {
    Fill $g $K.cell $x $y $w $h; Frame $g $K.border $x $y $w $h 2
    Txt $g (Up $label) "head" 15 $K.dim ($x + 8) ($y + 8)
    DrawPic $g (Join-Path $ui $png) ($x + $w / 2 - 34) ($y + $h / 2 - 26) 68 68 0.55 $true
}

$L = @{
    ru = @{
        szTitle = "РАЗМЕР ВЕЩИ - ПО ЕЁ 3D-МОДЕЛИ"; szA = "ОРУЖИЕ И ВЕЩИ"; szB = "ОДЕЖДА - ПО МЕСТУ, КУДА НАДЕВАЕТСЯ"
        bgTitle = "ВМЕСТИМОСТЬ ПРЕЖНЯЯ, ФОРМА У КАЖДОЙ СУМКИ СВОЯ"
        school = "ШКОЛЬНЫЙ РЮКЗАК"; duffel = "СПОРТИВНАЯ СУМКА"; rcase = "ЧЕХОЛ ДЛЯ ВИНТОВКИ"; fanny = "ПОЯСНАЯ СУМКА"
        bgA = "В ШКАФАХ, НА ПОЛКАХ И В БАГАЖНИКАХ МЕСТА БОЛЬШЕ: ТРИ КЛЕТКИ НА ЕДИНИЦУ ВМЕСТИМОСТИ."
        bgB = "СУМКУ С ВЕЩАМИ В ДРУГУЮ СУМКУ НЕ ПОЛОЖИТЬ - РАМКА КРАСНАЯ."
        skTitle = "ОКОЛО ДВУХ КИЛОГРАММОВ МЕЛОЧИ НА КЛЕТКУ"
        skNames = @("ГВОЗДИ", "ШУРУПЫ", "ПАТРОНЫ 9 ММ", "ДРОБЬ", "БАТАРЕЙКИ", "БИНТЫ", "ТАБЛЕТКИ")
        skA = "ЧТО НЕ ВЛЕЗЛО В СТОПКУ, ЛОЖИТСЯ В СОСЕДНЮЮ КЛЕТКУ. СКОЛЬКО ВЛЕЗАЕТ - НАПИСАНО В ПОДСКАЗКЕ."
        nails = "Гвозди"; nailsSub = "Материалы · 1x1 · 0.01 кг"
        pkTitle = "КАРМАНЫ - ОТ ОДЕЖДЫ"; pkA = "ГОЛЫШОМ У ВАС 4 КЛЕТКИ: РУКИ ДА ПОЯС. КАЖДАЯ ВЕЩЬ ДОБАВЛЯЕТ СВОИ. НАВЕДИТЕ МЫШЬ НА «КАРМАНЫ» - УВИДИТЕ, ЧТО СКОЛЬКО ДАЁТ."
        jeans = "Джинсы"; jacket = "Куртка"; vest = "Бронежилет"
        lootTitle = "ОКРУЖЕНИЕ: ЗНАЧКИ, СЧЁТЧИКИ, ДЕЙСТВИЯ"
        stove = "Плита"; stoveCap = "ПЛИТА"; fridge = "Холодильник"; cab = "Шкаф"; floor = "Пол"
        lootA = "СЕРАЯ ПУСТАЯ ПЛАШКА - СЮДА ЕЩЁ НЕ ЗАГЛЯДЫВАЛИ. ДЕЙСТВИЯ КОНТЕЙНЕРА - ЗНАЧКАМИ В ЕГО ЗАГОЛОВКЕ, РАБОТАЮЩИЙ ПРИБОР ПОДСВЕЧЕН."
        lootB = "ВЕЩЬ МОЖНО БРОСИТЬ ПРЯМО НА СТРОКУ КОНТЕЙНЕРА."
        ckTitle = "ГОТОВКУ ВИДНО ПО ПЛИТКЕ"; ckNames = @("ГОТОВИТСЯ", "ГОТОВО", "ПОДГОРЕЛО", "ЗАМЁРЗЛО")
        ckA = "У ПЛИТЫ И МИКРОВОЛНОВКИ СВОЁ ОКНО: ТЕМПЕРАТУРА, ТАЙМЕР, ВКЛЮЧЕНИЕ."
        temp = "Температура"; timer = "Таймер"; turnOff = "ВЫКЛЮЧИТЬ"
        cvTitle = "ЗАМОК, ПОДСКАЗКА ВЕСА, ЛАДОНИ"
        cvA = "T - ЗАМОК: ЗАКРЕПЛЁННАЯ ВЕЩЬ ОСТАЁТСЯ НА МЕСТЕ ПРИ «ВЗЯТЬ ВСЁ», СОРТИРОВКЕ И БЫСТРОМ ПЕРЕНОСЕ."
        cvB = "НАВЕЛИ ВЕЩЬ НА КОНТЕЙНЕР - СТРОКА ВЕСА ПОКАЖЕТ, СКОЛЬКО ПРИБАВИТСЯ. ТОЧКА - НОВОЕ С ПРОШЛОГО РАЗА."
        handL = "Левая рука"; handR = "Правая рука"
        seTitle = "ОБЫСК: ВЕЩИ НАХОДЯТСЯ ПО ОДНОЙ"
        seA = "ПО УМОЛЧАНИЮ ВЫКЛЮЧЕН. ВКЛЮЧАЕТСЯ В НАСТРОЙКАХ, НА ВКЛАДКЕ «ИГРА»."
        crate = "Ящик"; crateCap = "ЯЩИК"
        stTitle = "НАСТРОЙКИ: ВКЛАДКИ, ПОЛЗУНКИ, СВОИ КЛАВИШИ"
        weight = "5.4 / 12 КГ"; weightAdd = "+0.8"; weightLoot = "3.2 / 50 КГ"
    }
    en = @{
        szTitle = "AN ITEM'S SIZE COMES FROM ITS 3D MODEL"; szA = "WEAPONS AND THINGS"; szB = "CLOTHES - BY WHERE THEY ARE WORN"
        bgTitle = "THE SAME CAPACITY, EVERY BAG ITS OWN SHAPE"
        school = "SCHOOL BAG"; duffel = "DUFFEL BAG"; rcase = "RIFLE CASE"; fanny = "FANNY PACK"
        bgA = "CUPBOARDS, SHELVES AND CAR TRUNKS HAVE MORE ROOM: THREE CELLS PER UNIT OF CAPACITY."
        bgB = "A BAG WITH THINGS IN IT DOES NOT GO INTO ANOTHER BAG - THE FRAME TURNS RED."
        skTitle = "ABOUT TWO KILOGRAMS OF SMALL THINGS PER CELL"
        skNames = @("NAILS", "SCREWS", "9MM ROUNDS", "SHELLS", "BATTERIES", "BANDAGES", "PILLS")
        skA = "WHAT DOES NOT FIT INTO A STACK TAKES THE NEXT CELL. HOW MANY FIT IS IN THE ITEM'S TOOLTIP."
        nails = "Nails"; nailsSub = "Material · 1x1 · 0.01 kg"
        pkTitle = "POCKETS COME FROM YOUR CLOTHES"; pkA = "NAKED YOU HAVE 4 CELLS: HANDS AND WAISTBAND. EVERY PIECE OF CLOTHING ADDS ITS OWN. REST THE MOUSE ON POCKETS TO SEE WHAT GIVES WHAT."
        jeans = "Jeans"; jacket = "Jacket"; vest = "Bulletproof Vest"
        lootTitle = "SURROUNDINGS: ICONS, COUNTS, ACTIONS"
        stove = "Oven"; stoveCap = "OVEN"; fridge = "Fridge"; cab = "Cupboard"; floor = "Ground"
        lootA = "A GREY EMPTY PLATE - NOT LOOKED INTO YET. A CONTAINER'S ACTIONS ARE ICONS IN ITS HEADER, A RUNNING APPLIANCE IS LIT."
        lootB = "DROP A THING RIGHT ON A CONTAINER'S ROW."
        ckTitle = "COOKING SHOWS ON THE TILE"; ckNames = @("COOKING", "COOKED", "BURNT", "FROZEN")
        ckA = "OVENS AND MICROWAVES HAVE A WINDOW OF THEIR OWN: TEMPERATURE, TIMER, ON AND OFF."
        temp = "Temperature"; timer = "Timer"; turnOff = "TURN OFF"
        cvTitle = "LOCK, WEIGHT PREVIEW, PALMS"
        cvA = "T LOCKS AN ITEM: IT STAYS PUT ON TAKE ALL, SORT AND QUICK MOVE."
        cvB = "HOLD A THING OVER A CONTAINER AND ITS WEIGHT LINE SHOWS WHAT IT ADDS. A DOT MARKS WHAT IS NEW SINCE LAST TIME."
        handL = "Left hand"; handR = "Right hand"
        seTitle = "SEARCHING: THINGS ARE FOUND ONE BY ONE"
        seA = "OFF BY DEFAULT. TURN IT ON IN THE SETTINGS, ON THE GAME TAB."
        crate = "Crate"; crateCap = "CRATE"
        stTitle = "SETTINGS: TABS, SLIDERS, YOUR OWN KEYS"
        weight = "5.4 / 12 KG"; weightAdd = "+0.8"; weightLoot = "3.2 / 50 KG"
    }
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.0 ($lang):"
    $tabNames = @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_controls"), (Tr $lang "IGUI_Knox_Page_game"))

    # --- sizes: things by their model, clothes by their slot
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.szTitle 24 26
    Txt $g $s.szA "head" 18 $K.accent 40 84
    Txt $g $s.szB "head" 18 $K.accent (40 + 7 * $C) 84
    $gx = 40; $gy = 116
    Grid $g $gx $gy 18 6
    Tile $g $gx $gy 0 0 1 6 "wpn" "rifle"; SizeTag $g $gx $gy 0 0 "1x6"
    Tile $g $gx $gy 1 0 1 4 "wpn" "bat"; SizeTag $g $gx $gy 1 0 "1x4"
    Tile $g $gx $gy 2 0 1 2 "wpn" "pistol"; SizeTag $g $gx $gy 2 0 "1x2"
    Tile $g $gx $gy 2 2 1 1 "food" "beans"; SizeTag $g $gx $gy 2 2 "1x1"
    Tile $g $gx $gy 3 0 4 6 "tool" "generator"; SizeTag $g $gx $gy 3 0 "4x6"
    Tile $g $gx $gy 7 0 1 2 "clo" "tshirt"; SizeTag $g $gx $gy 7 0 "1x2"
    Tile $g $gx $gy 8 0 2 2 "clo" "trousers"; SizeTag $g $gx $gy 8 0 "2x2"
    Tile $g $gx $gy 10 0 2 2 "clo" "jacket"; SizeTag $g $gx $gy 10 0 "2x2"
    Tile $g $gx $gy 12 0 2 3 "clo" "vest"; SizeTag $g $gx $gy 12 0 "2x3"
    Tile $g $gx $gy 14 0 2 2 "clo" "boots"; SizeTag $g $gx $gy 14 0 "2x2"
    Tile $g $gx $gy 16 0 1 2 "clo" "shoes"; SizeTag $g $gx $gy 16 0 "1x2"
    Tile $g $gx $gy 8 2 2 2 "clo" "helmet"; SizeTag $g $gx $gy 8 2 "2x2"
    Tile $g $gx $gy 10 2 1 1 "clo" "cap"; SizeTag $g $gx $gy 10 2 "1x1"
    Save $bmp $g "u090_sizes_$lang.png"

    # --- bags: their shapes; a full bag refused by another
    $bmp, $g = Canvas 1280 600 $K.screen
    Caption $g $s.bgTitle 24 26
    Strip $g 40 84 (4 * $C + 1) $s.school "4x6"; Grid $g 40 120 4 6
    Tile $g 40 120 0 0 1 2 "food" "bottle"; Tile $g 40 120 1 0 2 2 "clo" "jacket"
    Strip $g 330 84 (8 * $C + 1) $s.duffel "8x3"; Grid $g 330 120 8 3
    Tile $g 330 120 0 0 1 2 "wpn" "pistol"; Tile $g 330 120 1 0 2 2 "clo" "trousers"
    Strip $g 330 336 (8 * $C + 1) $s.rcase "8x1"; Grid $g 330 372 8 1
    Tile $g 330 372 0 0 6 1 "wpn" "rifle"
    Strip $g 880 84 (5 * $C + 1) $s.fanny "2x1"; Grid $g 880 120 2 1
    Tile $g 880 120 0 0 1 1 "med" "bandage"
    # a bag with things held over the duffel bag: refused, red
    Fill $g $K.bad 330 120 (8 * $C + 1) (3 * $C + 1) 0.14; Frame $g $K.bad 330 120 (8 * $C + 1) (3 * $C + 1) 2
    Held $g (330 + 4 * $C + 20) (120 + 40) 2 2 "clo" "bag_school"
    $yb = CapsBlock $g $s.bgA 880 220 376
    CapsBlock $g $s.bgB 880 ($yb + 14) 376 | Out-Null
    Save $bmp $g "u090_bags_$lang.png"

    # --- stacks: how many fit, and the tooltip saying so
    $bmp, $g = Canvas 1280 360 $K.screen
    Caption $g $s.skTitle 24 26
    $gx = 40; $gy = 100
    $sk = @(@("mat", "nails", "40"), @("mat", "screws", "40"), @("wpn", "ammo9", "100"), @("wpn", "shells", "30"), @("tool", "battery", "20"), @("med", "bandage", "20"), @("med", "pills", "10"))
    for ($i = 0; $i -lt $sk.Count; $i++) {
        $cx = $gx + $i * 94
        Grid $g $cx $gy 1 1
        Tile $g $cx $gy 0 0 1 1 $sk[$i][0] $sk[$i][1] "" $sk[$i][2]
        $nm = $s.skNames[$i]; $nw = TextW $g $nm "head" 14
        Txt $g $nm "head" 14 $K.dim ($cx + ($C - $nw) / 2) ($gy + $C + 12)
    }
    CapsBlock $g $s.skA 40 220 620 | Out-Null
    Tooltip $g 720 90 460 "mat" "nails" $s.nails $s.nailsSub @(@((Tr $lang "IGUI_Knox_Weight"), "0.01"), @(((Tr $lang "IGUI_Knox_StackOf").Replace("%1", "40")), "")) | Out-Null
    Save $bmp $g "u090_stacks_$lang.png"

    # --- pockets: the pockets' header hovered, what gives the cells
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.pkTitle 24 26
    Column $g 24 76 420 460 (Tr $lang "IGUI_Knox_Inventory") $s.weight
    Strip $g 40 136 (4 * $C + 1) (Up (Tr $lang "IGUI_Knox_Pockets")) "4x4" $null $true
    Grid $g 40 172 4 4
    Tile $g 40 172 0 0 1 1 "info" "idcard"; Tile $g 40 172 1 0 1 1 "info" "keyring"; Tile $g 40 172 2 0 1 2 "food" "bottle"
    # the pockets' tooltip: where every cell comes from
    $tx = 330; $ty = 130; $tw = 420
    $rows = @(@("c_pocket", (Tr $lang "IGUI_Knox_PocketsHands"), "4"), @("trousers", $s.jeans, "+4"), @("jacket", $s.jacket, "+4"), @("vest", $s.vest, "+4"))
    $th = 56 + $rows.Count * 52 + 52
    Fill $g $K.window $tx $ty $tw $th; Frame $g $K.tileFrame $tx $ty $tw $th 1
    Fill $g $K.header ($tx + 1) ($ty + 1) ($tw - 2) 46
    TxtMid $g (Up (Tr $lang "IGUI_Knox_Pockets")) "head" 18 $K.bright ($tx + 16) $ty 48
    TxtMid $g "16" "head" 18 $K.accent ($tx + $tw - 40) $ty 48
    $ry = $ty + 56
    foreach ($r in $rows) {
        Fill $g $K.cell ($tx + 14) $ry 44 44; Frame $g $K.tileEdge ($tx + 14) $ry 44 44 1
        DrawIcon $g $r[0] ($tx + 14) $ry 44 44 1 32
        TxtMid $g $r[1] "body" 20 $K.text ($tx + 72) $ry 44
        TxtMid $g $r[2] "head" 19 $K.accent ($tx + $tw - 20 - (TextW $g $r[2] "head" 19)) $ry 44
        $ry += 52
    }
    Fill $g $K.border ($tx + 14) ($ry + 4) ($tw - 28) 1
    TxtMid $g "= 16" "head" 19 $K.bright ($tx + $tw - 20 - (TextW $g "= 16" "head" 19)) ($ry + 8) 40
    Cursor $g 200 142 36
    CapsBlock $g $s.pkA 790 96 466 | Out-Null
    Save $bmp $g "u090_pockets_$lang.png"

    # --- the Surroundings: icons, counts, action buttons, a drop on a row
    $bmp, $g = Canvas 1280 600 $K.screen
    Caption $g $s.lootTitle 24 26
    Column $g 24 76 840 500 (Tr $lang "IGUI_Knox_Tab_Surroundings") $s.weightLoot
    Row $g 40 136 300 $s.stove "c_stove" "2" "full" $true
    Row $g 40 208 300 $s.fridge "c_fridge" "5" "full" $false $true
    Row $g 40 280 300 $s.cab "c_counter" "" "none"
    Row $g 40 352 300 $s.floor "c_floor" "0" "zero"
    # a can held over the fridge's row: it goes there
    Fill $g $K.ok 40 208 300 64 0.14; Frame $g $K.ok 40 208 300 64 2
    Held $g 150 202 1 1 "food" "beans"
    StripActions $g 356 136 (7 * $C + 1) $s.stoveCap "7x4" $false $true
    Grid $g 356 172 7 4
    CookTile $g 356 172 0 0 2 2 "pot_water" $K.accent $COOK_ORANGE 0.55
    Tile $g 356 172 2 0 1 1 "food" "saucepan"
    $yb = CapsBlock $g $s.lootA 888 96 368
    CapsBlock $g $s.lootB 888 ($yb + 14) 368 | Out-Null
    Save $bmp $g "u090_loot_$lang.png"

    # --- cooking: the tile's colours; the oven's window
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.ckTitle 24 26
    $gx = 40; $gy = 100
    Grid $g $gx $gy 8 2
    CookTile $g $gx $gy 0 0 2 2 "pot_water" $K.accent $COOK_ORANGE 0.6
    CookTile $g $gx $gy 2 0 2 2 "saucepan" $COOK_ORANGE $K.bad 0.15
    CookTile $g $gx $gy 4 0 2 2 "tvdinner" $null $K.bad 1.0
    CookTile $g $gx $gy 6 0 2 2 "steak" $null $COOK_BLUE 1.0
    for ($i = 0; $i -lt 4; $i++) { $nm = $s.ckNames[$i]; $nw = TextW $g $nm "head" 16; Txt $g $nm "head" 16 $K.text ($gx + $i * 2 * $C + ($C * 2 - $nw) / 2) ($gy + 2 * $C + 14) }
    CapsBlock $g $s.ckA 40 320 500 | Out-Null
    # the oven's window
    Win $g 640 80 600 290 (Tr $lang "IGUI_Knox_Stove")
    Fill $g $K.cell 664 148 120 120; Frame $g $K.tileFrame 664 148 120 120 2; DrawIcon $g "c_stove" 664 148 120 120 1 96
    TxtMid $g (Tr $lang "IGUI_Knox_Stove_On") "head" 19 $K.ok 808 148 40
    Slider $g 808 200 410 $s.temp 0.7 "180°" 150
    Slider $g 808 250 410 $s.timer 0.35 "20:00" 150
    $bw = (TextW $g $s.turnOff "head" 17) + 40
    Fill $g $K.accent 664 300 $bw 40; TxtCentre $g $s.turnOff "head" 17 $K.ink 664 300 $bw 40
    Save $bmp $g "u090_cook_$lang.png"

    # --- convenience: a lock, new dots, the weight preview, palms in empty hands
    $bmp, $g = Canvas 1280 600 $K.screen
    Caption $g $s.cvTitle 24 26
    Column $g 24 76 560 500 (Tr $lang "IGUI_Knox_Inventory") $s.weight
    # the weight line with what the held thing adds, in red
    Fill $g $K.bad (24 + 560 - 16 - (TextW $g $s.weight "head" 19) - 16 - 130 + 36) (76 + 28) 22 4
    Txt $g $s.weightAdd "head" 17 $K.bad (24 + 560 - 16 - (TextW $g $s.weight "head" 19) - 16 - 130 + 40) (76 + 44)
    Strip $g 40 136 (6 * $C + 1) $s.school "6x5" $null $true
    Grid $g 40 172 6 5
    Tile $g 40 172 0 0 1 4 "wpn" "bat"
    # locked: a small sand padlock in the corner
    $lx = 40 + 6; $ly = 172 + 6; $u = 3
    Fill $g $K.accent ($lx + $u) $ly ($u * 3) $u; Fill $g $K.accent ($lx + $u) $ly $u ($u * 2); Fill $g $K.accent ($lx + $u * 3) $ly $u ($u * 2); Fill $g $K.accent $lx ($ly + $u * 2) ($u * 5) ($u * 3)
    Tile $g 40 172 1 0 1 1 "food" "beans"
    Tile $g 40 172 2 0 1 2 "food" "bottle"
    Tile $g 40 172 3 0 1 1 "med" "bandage"
    # new since last time: a sand dot
    Fill $g $K.accent (40 + 3 * $C + 5) (172 + $C - 15) 9 9
    Fill $g $K.accent (40 + 1 * $C + 5) (172 + $C - 15) 9 9
    Held $g (40 + 3 * $C + 20) (172 + 2 * $C + 10) 2 2 "food" "pot"
    HandSlot $g 608 96 260 150 $s.handR "knox_hand_right.png"
    HandSlot $g 880 96 260 150 $s.handL "knox_hand_left.png"
    $yb = CapsBlock $g $s.cvA 608 290 640
    CapsBlock $g $s.cvB 608 ($yb + 14) 640 | Out-Null
    Save $bmp $g "u090_convenience_$lang.png"

    # --- searching: found one by one
    $bmp, $g = Canvas 1280 520 $K.screen
    Caption $g $s.seTitle 24 26
    Column $g 24 76 840 420 (Tr $lang "IGUI_Knox_Tab_Surroundings")
    Row $g 40 136 300 $s.crate "c_crate" "3" "part" $true
    Strip $g 356 136 (7 * $C + 1) $s.crateCap ((Tr $lang "IGUI_Knox_Searching").Replace("%1", "3").Replace("%2", "8")) $K.accent
    Grid $g 356 172 7 4
    Tile $g 356 172 0 0 1 4 "tool" "sledge"
    Tile $g 356 172 1 0 1 1 "tool" "hammer"
    Tile $g 356 172 2 0 1 1 "mat" "nails" "" "40"
    $fx = 356 + 3 * $C + 1; $fy = 172 + 1
    Fill $g $K.cell $fx $fy (2 * $C - 1) (2 * $C - 1); Fill $g $K.accent $fx ($fy + 70) (2 * $C - 1) (2 * $C - 71) 0.3; Frame $g $K.accent $fx $fy (2 * $C - 1) (2 * $C - 1) 2
    SwitchRow $g 888 96 $true (Tr $lang "IGUI_Knox_Switch_search") $null 360 | Out-Null
    CapsBlock $g $s.seA 888 160 368 | Out-Null
    Save $bmp $g "u090_search_$lang.png"

    # --- settings: the look's sliders, the switches
    $bmp, $g = Canvas 1280 640 $K.screen
    Caption $g $s.stTitle 24 26
    Win $g 24 76 820 540 (Tr $lang "IGUI_Knox_Settings")
    $ty = Tabs $g 24 122 820 $tabNames 1
    Txt $g (Up (Tr $lang "IGUI_Knox_Look_Title")) "head" 18 $K.accent 56 ($ty + 22)
    $sy = $ty + 60
    foreach ($sl in @(@("IGUI_Knox_look_all", 1.0, "100%"), @("IGUI_Knox_look_bg", 0.85, "85%"), @("IGUI_Knox_look_grid", 0.7, "70%"), @("IGUI_Knox_look_line", 0.4, "2 px"), @("IGUI_Knox_look_slot", 0.9, "90%"), @("IGUI_Knox_look_model", 0.6, "60%"))) {
        Slider $g 56 $sy 760 (Tr $lang $sl[0]) $sl[1] $sl[2]; $sy += 48
    }
    $sy = SwitchRow $g 56 ($sy + 12) $true (Tr $lang "IGUI_Knox_Switch_anim") $null 760
    # the controls page, beside: your own keys and clicks
    Txt $g (Up (Tr $lang "IGUI_Knox_Controls_Title")) "head" 18 $K.accent 880 96
    $by = 136
    foreach ($b in @(@("IGUI_Knox_Act_quickMove", $(if ($lang -eq "ru") { "SHIFT+ЛКМ" } else { "SHIFT+LMB" })), @("IGUI_Knox_Act_lock", "T"), @("IGUI_Knox_Act_inspect", $(if ($lang -eq "ru") { "СКМ" } else { "MMB" })), @("IGUI_Knox_Act_rotate", "R"))) {
        foreach ($line in @(WrapCaps $g (Tr $lang $b[0]) "body" 19 370)) { Txt $g $line "body" 19 $K.text 880 $by; $by += 26 }
        KeyPlate $g 880 ($by + 4) $b[1] | Out-Null
        $by += 52
    }
    Save $bmp $g "u090_settings_$lang.png"

    # --- banner: a background of things of every size
    BannerPattern "u090_banner_$lang.png" @(
        @(6, 0, 1, 5, "wpn", "rifle", ""), @(7, 0, 1, 3, "wpn", "bat", ""), @(8, 0, 2, 2, "clo", "jacket", ""), @(10, 0, 1, 2, "food", "bottle", ""),
        @(11, 0, 1, 1, "food", "beans", "hit"), @(12, 0, 2, 3, "clo", "vest", ""), @(14, 0, 2, 2, "clo", "boots", ""), @(16, 0, 1, 1, "mat", "nails", ""),
        @(8, 2, 1, 2, "wpn", "pistol", ""), @(9, 2, 2, 2, "clo", "trousers", ""), @(11, 1, 1, 1, "med", "bandage", ""), @(14, 2, 2, 2, "food", "pot", ""),
        @(16, 1, 1, 2, "clo", "tshirt", "")
    )

    # --- art: the screen's top with the clock, things at their real sizes
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.szTitle 60 56 26
    Column $g 60 110 840 900 (Tr $lang "IGUI_Knox_Inventory") $s.weight
    Strip $g 76 170 (12 * $C + 1) $s.duffel "12x12" $null $true
    $gx = 76; $gy = 206
    Grid $g $gx $gy 12 12
    Tile $g $gx $gy 0 0 1 6 "wpn" "rifle"; Tile $g $gx $gy 1 0 1 4 "wpn" "bat"; Tile $g $gx $gy 2 0 1 2 "wpn" "pistol"
    Tile $g $gx $gy 2 2 1 1 "food" "beans"; Tile $g $gx $gy 3 0 2 3 "clo" "vest"; Tile $g $gx $gy 5 0 2 2 "clo" "jacket"
    Tile $g $gx $gy 7 0 2 2 "clo" "trousers"; Tile $g $gx $gy 9 0 1 2 "clo" "tshirt"; Tile $g $gx $gy 10 0 2 2 "clo" "helmet"
    Tile $g $gx $gy 5 2 2 2 "clo" "boots"; Tile $g $gx $gy 7 2 1 1 "mat" "nails" "" "40"; Tile $g $gx $gy 8 2 1 1 "wpn" "ammo9" "" "100"
    Tile $g $gx $gy 3 4 4 6 "tool" "generator"; Tile $g $gx $gy 9 2 2 2 "food" "pot"
    Save $bmp $g "u090_art_$lang.png"
}
