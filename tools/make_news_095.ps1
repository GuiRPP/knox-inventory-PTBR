# Pictures of the 0.9.5 news post (Viewpoint, mixed stacks, searching, controls),
# made anew in 2026-10 by the approved news rules (see make_news_096.ps1 and
# news_ui.ps1): pieces of the Knox screen itself, the game's own icons, captions in
# capitals, a banner with no words, a picture per language.
#   42\media\knox\news\u095_<name>_<ru|en>.png
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_095.ps1

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        cab = "Шкаф"; cabCap = "ШКАФ"; floor = "Пол"; corpse = "Труп"; corpseCap = "ТРУП"
        vpTitle = "VIEWPOINT: ИНВЕНТАРЬ ОТ ПЕРВОГО ЛИЦА"
        vpA = "ОТКРЫЛИ ЛЮБОЕ ОКНО KNOX - КУРСОР УЖЕ НА МЕСТЕ, СРЕДНЯЯ КНОПКА НЕ НУЖНА."
        vpB = "КЛАВИША ЛУТА VIEWPOINT ОТКРЫВАЕТ KNOX НА ЯЩИКЕ ПЕРЕД ВАМИ. С КАМЕРОЙ VIEWPOINT В ОКРУЖЕНИИ ТОЛЬКО ОН И ПОЛ."
        stTitle = "РАЗНЫЕ ВЕЩИ ОДНОГО ВИДА - В ОДНОЙ СТОПКЕ"
        stA = "КЛЮЧИ ОТ РАЗНЫХ ДВЕРЕЙ, РАЗНЫЕ КАССЕТЫ, БАТАРЕЙКИ С РАЗНЫМ ЗАРЯДОМ. ЧИСЛО У ТАКОЙ СТОПКИ ПЕСОЧНОЕ."
        stB = "ЗАДЕРЖИТЕ НА НЕЙ МЫШЬ: КАЖДАЯ ВЕЩЬ ЛЕЖИТ ОТДЕЛЬНО. ВЫТАЩИТЕ НУЖНУЮ ИЛИ ЩЁЛКНИТЕ ПО НЕЙ."
        stC = "КОШЕЛЁК И СВЯЗКА КЛЮЧЕЙ: ВНУТРИ 4 КЛЕТКИ, СНАРУЖИ ПО-ПРЕЖНЕМУ ОДНА."
        seTitle = "ОБЫСК: ОДЕЖДУ НА ТРУПЕ ВИДНО СРАЗУ"
        seA = "ИЩЕТСЯ ТОЛЬКО ТО, ЧТО В КАРМАНАХ. ЧЕМ БОЛЬШЕ ВЕЩЬ, ТЕМ ДОЛЬШЕ ЕЁ ИЩЕШЬ."
        coTitle = "ПОВОРОТ ВЕЩИ - НА КНОПКУ МЫШИ"
        coA = "ПОКА ВЫ НЕСЁТЕ ВЕЩЬ, ПКМ ЕЁ ПОВОРАЧИВАЕТ, А МЕНЮ НЕ ОТКРЫВАЕТ."
        rmb = "ПКМ"; mmb = "СКМ"; shiftLmb = "SHIFT+ЛКМ"; lmb2 = "2xЛКМ"
    }
    en = @{
        cab = "Cupboard"; cabCap = "CUPBOARD"; floor = "Ground"; corpse = "Corpse"; corpseCap = "CORPSE"
        vpTitle = "VIEWPOINT: THE INVENTORY IN FIRST PERSON"
        vpA = "OPEN ANY KNOX WINDOW AND THE CURSOR IS THERE AT ONCE - NO MIDDLE BUTTON NEEDED."
        vpB = "VIEWPOINT'S LOOT KEY OPENS KNOX ON THE CONTAINER IN FRONT OF YOU. WITH VIEWPOINT'S CAMERA THE SURROUNDINGS SHOW ONLY IT AND THE GROUND."
        stTitle = "THINGS OF ONE TYPE, NOT ALIKE - IN ONE STACK"
        stA = "KEYS TO DIFFERENT DOORS, DIFFERENT TAPES, BATTERIES WITH DIFFERENT CHARGE. SUCH A STACK HAS A SAND COUNT."
        stB = "REST THE MOUSE ON IT: EVERY THING LIES APART. DRAG OUT THE ONE YOU NEED OR CLICK IT."
        stC = "THE WALLET AND THE KEY RING: 4 CELLS INSIDE, STILL ONE OUTSIDE."
        seTitle = "SEARCHING: CLOTHES ON A BODY ARE SEEN AT ONCE"
        seA = "ONLY THE POCKETS ARE SEARCHED. THE BIGGER A THING, THE LONGER IT TAKES TO FIND."
        coTitle = "TURN THE HELD ITEM WITH A MOUSE BUTTON"
        coA = "WHILE YOU CARRY AN ITEM, RMB TURNS IT AND OPENS NO MENU."
        rmb = "RMB"; mmb = "MMB"; shiftLmb = "SHIFT+LMB"; lmb2 = "2xLMB"
    }
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.5 ($lang):"

    # --- viewpoint: the setting, the Surroundings with only the opened container
    $bmp, $g = Canvas 1280 640 $K.screen
    Caption $g $s.vpTitle 24 26
    Win $g 24 76 560 300 (Tr $lang "IGUI_Knox_Settings")
    $ty = Tabs $g 24 122 560 @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_controls"), (Tr $lang "IGUI_Knox_Page_game")) 3
    Txt $g (Up (Tr $lang "IGUI_Knox_Game_Title")) "head" 18 $K.accent 56 ($ty + 22)
    Choice $g 56 ($ty + 56) (Tr $lang "IGUI_Knox_Choice_loot_scope") @((Tr $lang "IGUI_Knox_Choice_loot_scope_auto"), (Tr $lang "IGUI_Knox_Choice_loot_scope_opened"), (Tr $lang "IGUI_Knox_Choice_loot_scope_all")) 0 | Out-Null
    $yb = CapsBlock $g $s.vpA 24 410 560
    CapsBlock $g $s.vpB 24 ($yb + 14) 560 | Out-Null
    Column $g 608 76 648 540 (Tr $lang "IGUI_Knox_Tab_Surroundings")
    Row $g 624 136 250 $s.cab "c_counter" "4" "full" $true
    Row $g 624 208 250 $s.floor "c_floor" "0" "zero"
    Strip $g 888 136 (5 * $C) $s.cabCap "5x6"
    Grid $g 888 172 5 6
    Tile $g 888 172 0 0 1 2 "food" "bottle"
    Tile $g 888 172 1 0 1 1 "food" "beans"
    Tile $g 888 172 2 0 2 2 "clo" "jacket"
    Tile $g 888 172 1 1 1 1 "med" "bandage"
    Cursor $g (888 + 2.6 * $C) (172 + 1.3 * $C) 40
    Save $bmp $g "u095_viewpoint_$lang.png"

    # --- stacks: a sand count, and the stack's things one by one beside it
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.stTitle 24 26
    Column $g 24 76 600 460 (Tr $lang "IGUI_Knox_Inventory")
    Strip $g 40 136 (5 * $C) (Up (Tr $lang "IGUI_Knox_Pockets")) "5x5" $null $true
    Grid $g 40 172 5 5
    Tile $g 40 172 0 0 1 1 "info" "key1" "" "4"
    Tile $g 40 172 1 0 1 1 "info" "cassette" "" "3"
    Tile $g 40 172 2 0 1 1 "tool" "battery" "" "6"
    Tile $g 40 172 3 0 1 2 "food" "bottle"
    Tile $g 40 172 4 3 1 1 "info" "idcard"
    # sand counts on the mixed stacks (Tile writes them white: over them in sand)
    foreach ($m in @(@(0, "4"), @(1, "3"), @(2, "6"))) {
        $tx = 40 + $m[0] * $C + 1; $pw = $C - 1
        Fill $g $K[$(if ($m[0] -eq 0) { "info" } elseif ($m[0] -eq 1) { "info" } else { "tool" })] ($tx + $pw - 22) (172 + $C - 22) 20 20
        Txt $g $m[1] "head" 16 $K.accent ($tx + $pw - 6 - (TextW $g $m[1] "head" 16)) (172 + $C - 18)
    }
    Frame $g $K.tileHover 41 173 ($C - 1) ($C - 1) 2
    # the stack's panel: "In this stack", every kind its own tile
    $px = 48; $py = 172 + $C + 10
    Fill $g $K.window $px $py 300 120; Frame $g $K.accent $px $py 300 120 2
    TxtMid $g (Up (Tr $lang "IGUI_Knox_StackKinds")) "head" 17 $K.bright ($px + 14) $py 38
    $kx = $px + 12
    foreach ($kn in "key1", "key2", "key3", "key4") { Fill $g $K.info $kx ($py + 44) 63 63; Frame $g $K.tileFrame $kx ($py + 44) 63 63 2; DrawIcon $g $kn $kx ($py + 44) 63 63 1 53; $kx += 69 }
    Frame $g $K.accent ($px + 12 + 69) ($py + 44) 63 63 2
    Cursor $g ($px + 12 + 69 + 34) ($py + 44 + 34) 38
    $yb = CapsBlock $g $s.stA 660 96 600
    CapsBlock $g $s.stB 660 ($yb + 14) 600 | Out-Null
    # the wallet and the key ring: a 4x1 grid inside, one cell outside
    CapsBlock $g $s.stC 660 300 600 | Out-Null
    Fill $g $K.header 660 344 (4 * $C + 1) 36
    TxtMid $g $(if ($lang -eq "ru") { "КОШЕЛЁК" } else { "WALLET" }) "head" 18 $K.bright 670 344 36
    TxtMid $g "4x1" "head" 18 $K.dim (660 + 4 * $C - 40) 344 36
    Grid $g 660 380 4 1
    Tile $g 660 380 0 0 1 1 "info" "idcard"
    Save $bmp $g "u095_stacks_$lang.png"

    # --- searching: the switch and the slider; a body with its clothes seen at once
    $bmp, $g = Canvas 1280 620 $K.screen
    Caption $g $s.seTitle 24 26
    Win $g 24 76 600 340 (Tr $lang "IGUI_Knox_Settings")
    $ty = Tabs $g 24 122 600 @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_controls"), (Tr $lang "IGUI_Knox_Page_game")) 3
    $sy = SwitchRow $g 56 ($ty + 28) $true (Tr $lang "IGUI_Knox_Switch_search") $null 540
    Slider $g 56 ($sy + 30) 540 (Tr $lang "IGUI_Knox_search_time") 0.25 "100%"
    CapsBlock $g $s.seA 24 450 600 | Out-Null
    Column $g 648 76 608 520 (Tr $lang "IGUI_Knox_Tab_Surroundings")
    Row $g 664 136 576 $s.corpse "c_corpse" "2" "part" $true
    Strip $g 664 216 (8 * $C + 1) $s.corpseCap (Tr $lang "IGUI_Knox_Searching").Replace("%1", "3").Replace("%2", "6") $K.accent
    Grid $g 664 252 8 5
    Tile $g 664 252 0 0 2 2 "clo" "jacket"
    Tile $g 664 252 2 0 2 2 "clo" "trousers"
    Tile $g 664 252 4 0 2 2 "clo" "boots"
    # the pocket thing being found: a dark plate filling with sand
    $fx = 664 + 6 * $C + 1; $fy = 252 + 1
    Fill $g $K.cell $fx $fy ($C - 1) ($C - 1); Fill $g $K.accent $fx ($fy + 26) ($C - 1) ($C - 27) 0.3; Frame $g $K.accent $fx $fy ($C - 1) ($C - 1) 2
    Save $bmp $g "u095_search_$lang.png"

    # --- controls: rotate on a mouse button
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.coTitle 24 26
    Win $g 24 76 760 400 (Tr $lang "IGUI_Knox_Settings")
    $ty = Tabs $g 24 122 760 @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_controls"), (Tr $lang "IGUI_Knox_Page_game")) 2
    Txt $g (Up (Tr $lang "IGUI_Knox_Controls_Title")) "head" 18 $K.accent 56 ($ty + 22)
    $ry = $ty + 60
    foreach ($b in @(@("IGUI_Knox_Act_quickMove", $s.shiftLmb, $false), @("IGUI_Knox_Act_open", $s.lmb2, $false), @("IGUI_Knox_Act_inspect", $s.mmb, $false), @("IGUI_Knox_Act_rotate", "R", $false), @("IGUI_Knox_Act_menu", $s.rmb, $false))) {
        TxtMid $g (Tr $lang $b[0]) "body" 20 $K.text 56 $ry 40
        $pw = KeyPlate $g 520 ($ry + 6) $b[1]
        if ($b[0] -eq "IGUI_Knox_Act_rotate") { KeyPlate $g (520 + $pw + 8) ($ry + 6) $s.rmb $true | Out-Null }
        $ry += 48
    }
    CapsBlock $g $s.coA 820 96 436 | Out-Null
    # the held rifle turned: lying at the cursor, RMB, standing
    $hx = 830; $hy = 250
    Fill $g $K.wpn $hx $hy (3 * $C - 1) ($C - 1) 0.88; Frame $g $K.accent $hx $hy (3 * $C - 1) ($C - 1) 2
    DrawIcon $g "rifle" $hx $hy (3 * $C - 1) ($C - 1) 1 45
    ArrowRight $g ($hx + 3 * $C + 14) ($hy + $C / 2) 70
    KeyPlate $g ($hx + 3 * $C + 22) ($hy + $C / 2 + 22) $s.rmb $true | Out-Null
    Held $g ($hx + 3 * $C + 104) ($hy - $C) 1 3 "wpn" "rifle"
    Save $bmp $g "u095_controls_$lang.png"

    # --- banner: a background - keys and tapes in mixed stacks
    BannerPattern "u095_banner_$lang.png" @(
        @(6, 0, 1, 1, "info", "key1", ""), @(7, 0, 1, 1, "info", "key2", "hit"), @(8, 0, 1, 1, "info", "key3", ""), @(9, 1, 1, 1, "info", "key4", ""),
        @(10, 0, 1, 2, "food", "bottle", ""), @(11, 1, 1, 1, "info", "cassette", "hit"), @(12, 0, 1, 1, "info", "cassette2", ""), @(13, 1, 1, 1, "tool", "battery", ""),
        @(14, 0, 2, 2, "clo", "jacket", ""), @(16, 1, 1, 1, "info", "cassette3", ""), @(7, 2, 1, 1, "med", "bandage", ""), @(12, 2, 2, 1, "wpn", "rifle", ""),
        @(15, 3, 1, 1, "info", "key1", "hit"), @(9, 3, 1, 1, "food", "beans", "")
    )

    # --- art: the setting on top, the Surroundings, the stack's panel
    $bmp, $g = Canvas 960 1080 $K.cell
    Win $g 60 50 840 250 (Tr $lang "IGUI_Knox_Settings")
    $ty = Tabs $g 60 96 840 @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_controls"), (Tr $lang "IGUI_Knox_Page_game")) 3
    Txt $g (Up (Tr $lang "IGUI_Knox_Game_Title")) "head" 18 $K.accent 92 ($ty + 22)
    Choice $g 92 ($ty + 56) (Tr $lang "IGUI_Knox_Choice_loot_scope") @((Tr $lang "IGUI_Knox_Choice_loot_scope_auto"), (Tr $lang "IGUI_Knox_Choice_loot_scope_opened"), (Tr $lang "IGUI_Knox_Choice_loot_scope_all")) 0 | Out-Null
    Column $g 60 340 840 690 (Tr $lang "IGUI_Knox_Tab_Surroundings")
    Row $g 76 400 300 $s.cab "c_counter" "4" "full" $true
    Row $g 76 472 300 $s.floor "c_floor" "0" "zero"
    Strip $g 392 400 (7 * $C + 1) $s.cabCap "7x8"
    Grid $g 392 436 7 8
    Tile $g 392 436 0 0 1 1 "info" "key1" "" "4"
    Fill $g $K.info (392 + $C - 22) (436 + $C - 22) 20 20; Txt $g "4" "head" 16 $K.accent (392 + $C - 6 - (TextW $g "4" "head" 16)) (436 + $C - 18)
    Tile $g 392 436 1 0 1 2 "food" "bottle"
    Tile $g 392 436 2 0 2 2 "clo" "jacket"
    Tile $g 392 436 4 0 1 1 "food" "beans"
    $px = 392 + 20; $py = 436 + $C + 10
    Fill $g $K.window $px $py 300 120; Frame $g $K.accent $px $py 300 120 2
    TxtMid $g (Up (Tr $lang "IGUI_Knox_StackKinds")) "head" 17 $K.bright ($px + 14) $py 38
    $kx = $px + 12
    foreach ($kn in "key1", "key2", "key3", "key4") { Fill $g $K.info $kx ($py + 44) 63 63; Frame $g $K.tileFrame $kx ($py + 44) 63 63 2; DrawIcon $g $kn $kx ($py + 44) 63 63 1 53; $kx += 69 }
    Cursor $g ($px + 12 + 34) ($py + 44 + 34) 38
    Save $bmp $g "u095_art_$lang.png"
}
