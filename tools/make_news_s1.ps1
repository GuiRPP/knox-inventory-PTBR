# Pictures of the two posts without a version - "Stage 1: Public test" and
# "What's next?" - made in 2026-10 by the approved news rules (see
# make_news_096.ps1 and news_ui.ps1): the Knox screen itself (its top bar with
# the tabs that are the stages, the inventory and surroundings columns, the
# bottom bar), the game's own icons, captions in capitals, banners with no
# words, a picture per language.
#   42\media\knox\news\s1_<name>_<ru|en>.png      banner, art, tabs
#   42\media\knox\news\plans_<name>_<ru|en>.png   banner, art
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_s1.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        s1Title = "СТАДИЯ 1: ИНВЕНТАРЬ"; weight = "4.6 / 12 КГ"; school = "ШКОЛЬНЫЙ РЮКЗАК"; cab = "Шкаф"; cabCap = "ШКАФ"; floor = "Пол"
        tabsTitle = "ВКЛАДКИ - ЭТО СТАДИИ"; now = "СЕЙЧАС"; stage = "СТАДИЯ"
        tabsA = "КАЖДАЯ СТАДИЯ СНАЧАЛА ПРОХОДИТ ОТКРЫТЫЙ ТЕСТ. ПОКА СТАДИЯ НЕ ГОТОВА, ЕЁ ВКЛАДКА ОТКРЫВАЕТ ОБЫЧНОЕ ОКНО ИГРЫ."
        plansTitle = "ЧТО ДАЛЬШЕ"
        st = @(@("ИНВЕНТАРЬ", "Сетки, снаряжение на персонаже, окружение, окна сумок и обыск. Всё это уже в игре."),
               @("ЗДОРОВЬЕ", "Травмы прямо на теле персонажа, лечение одним щелчком или броском предмета на рану."),
               @("НАВЫКИ И КАРТА", "Навыки и прогресс, карта мира в стиле Knox."),
               @("ВЕСЬ ИНТЕРФЕЙС", "Крафт, строительство, машины, меню - остальные окна игры, одно за другим."))
        plansNote = "ЧТО БУДЕТ РАНЬШЕ, РЕШАЮТ ВАШИ ОТЗЫВЫ."
    }
    en = @{
        s1Title = "STAGE 1: THE INVENTORY"; weight = "4.6 / 12 KG"; school = "SCHOOL BAG"; cab = "Cupboard"; cabCap = "CUPBOARD"; floor = "Ground"
        tabsTitle = "THE TABS ARE THE STAGES"; now = "NOW"; stage = "STAGE"
        tabsA = "EVERY STAGE IS TESTED IN PUBLIC FIRST. UNTIL A STAGE LANDS, ITS TAB OPENS THE GAME'S OWN WINDOW."
        plansTitle = "WHAT'S NEXT"
        st = @(@("THE INVENTORY", "Grids, the gear on your character, the surroundings, bag windows and searching. All in the game already."),
               @("HEALTH", "Your injuries on your character's body, treatment in a click or by dropping an item on a wound."),
               @("SKILLS AND MAP", "Skills and progress, and the world map, in the Knox style."),
               @("THE WHOLE UI", "Crafting, building, vehicles, menus - the rest of the game's windows, one by one."))
        plansNote = "YOUR FEEDBACK DECIDES WHAT COMES FIRST."
    }
}
# the screen's tabs in its order, and the stage each of them is
$TABS = @(@("Equipment", 1), @("Health", 2), @("Skills", 3), @("Crafting", 4), @("Map", 0))   # (as KnoxScreen: no journal, no stage under the map)

# The top bar's tabs from x: caps, the active one bright with a sand line under
# it, the rest dim. Returns each tab's {x, w}.
function TabRow($g, $lang, $x, $y, $h, $px, $gap) {
    $out = @()
    $first = $true
    foreach ($t in $TABS) {
        $name = Up (Tr $lang ("IGUI_Knox_Tab_" + $t[0]))
        $w = (TextW $g $name "head" $px) + 2 * $gap
        TxtCentre $g $name "head" $px $(if ($first) { $K.bright } else { $K.dim }) $x $y $w $h
        if ($first) { Fill $g $K.accent $x ($y + $h - 3) $w 3 }
        $out += , @($x, $w)
        $x += $w
        $first = $false
    }
    return , $out
}

# the bottom bar's mod name and stage plate: KNOX INVENTORY [STAGE 1]
function BrandPlate($g, $lang, $right, $y, $h) {
    $stage = Up (Tr $lang "IGUI_Knox_Stage")
    $sw = (TextW $g $stage "head" 15) + 16; $sh = 28
    $sx = $right - $sw; $sy = $y + ($h - $sh) / 2
    Frame $g $K.accent $sx $sy $sw $sh 1
    TxtCentre $g $stage "head" 15 $K.accent $sx $sy $sw $sh
    $wI = TextW $g "INVENTORY" "head" 19; $wK = TextW $g "KNOX" "head" 19
    TxtMid $g "INVENTORY" "head" 19 $K.accent ($sx - 14 - $wI) $y $h
    TxtMid $g "KNOX" "head" 19 $K.bright ($sx - 14 - $wI - 8 - $wK) $y $h
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures, stage 1 and plans ($lang):"

    # --- stage 1, the big picture: the Knox screen, small - tabs, inventory, surroundings, quick slots
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.s1Title 60 56 26
    $x0 = 60; $w0 = 840
    Fill $g $K.bar $x0 110 $w0 56; Fill $g $K.border $x0 165 $w0 1
    TabRow $g $lang ($x0 + 8) 110 56 17 14 | Out-Null
    $C = 52
    Column $g $x0 184 410 720 (Tr $lang "IGUI_Knox_Inventory") $s.weight
    Strip $g ($x0 + 16) 244 (4 * $C + 1) (Up (Tr $lang "IGUI_Knox_Pockets")) "4x3" $null $true
    $gx = $x0 + 16; $gy = 280
    Grid $g $gx $gy 4 3
    Tile $g $gx $gy 0 0 1 1 "info" "idcard"; Tile $g $gx $gy 1 0 1 1 "info" "keyring"; Tile $g $gx $gy 2 0 1 2 "food" "bottle"
    Tile $g $gx $gy 3 0 1 1 "med" "pills"
    Strip $g ($x0 + 16) 452 (7 * $C + 1) $s.school "7x7"
    $gy = 488
    Grid $g $gx $gy 7 7
    Tile $g $gx $gy 0 0 1 4 "wpn" "bat"; Tile $g $gx $gy 1 0 2 2 "clo" "jacket"; Tile $g $gx $gy 3 0 1 2 "clo" "tshirt"
    Tile $g $gx $gy 4 0 1 1 "food" "beans"; Tile $g $gx $gy 5 0 1 1 "food" "beans"; Tile $g $gx $gy 6 0 1 2 "tool" "hammer"
    Tile $g $gx $gy 1 2 1 1 "med" "bandage" "" "4"; Tile $g $gx $gy 2 2 1 1 "tool" "battery"; Tile $g $gx $gy 3 2 2 2 "food" "pot"
    Tile $g $gx $gy 5 1 1 1 "mat" "nails" "" "40"; Tile $g $gx $gy 1 3 2 1 "wpn" "pistol"; Tile $g $gx $gy 5 2 1 2 "food" "bottle"
    $rx = $x0 + 430
    Column $g $rx 184 410 720 (Tr $lang "IGUI_Knox_Tab_Surroundings")
    Row $g ($rx + 16) 244 378 $s.cab "c_counter" "6" "full" $true
    Row $g ($rx + 16) 316 378 $s.floor "c_floor" "1" "full"
    Strip $g ($rx + 16) 396 (7 * $C + 1) $s.cabCap "7x8" $null $true
    $gx = $rx + 16; $gy = 432
    Grid $g $gx $gy 7 8
    Tile $g $gx $gy 0 0 1 6 "wpn" "rifle"; Tile $g $gx $gy 1 0 2 2 "clo" "trousers"; Tile $g $gx $gy 3 0 1 1 "food" "chips"
    Tile $g $gx $gy 4 0 1 2 "wpn" "knife"; Tile $g $gx $gy 5 0 2 2 "clo" "boots"; Tile $g $gx $gy 1 2 1 1 "wpn" "ammo9" "" "30"
    Tile $g $gx $gy 2 2 1 1 "food" "sausage"
    Held $g ($gx + 3 * $C + 20) ($gy + 3 * $C + 10) 2 2 "clo" "jacket"
    $C = 64
    # the bottom bar: quick slots, the mod's name and stage
    $by = 920
    Fill $g $K.bar $x0 $by $w0 84; Fill $g $K.border $x0 $by $w0 1
    TxtMid $g (Up (Tr $lang "IGUI_Knox_QuickSlots")) "head" 17 $K.dim ($x0 + 20) $by 84
    $qx = $x0 + 40 + (TextW $g (Up (Tr $lang "IGUI_Knox_QuickSlots")) "head" 17)
    foreach ($ic in "bat", "knife", "") {
        Fill $g $K.cell $qx ($by + 12) 60 60; Frame $g $K.tileEdge $qx ($by + 12) 60 60 1
        if ($ic) { DrawIcon $g $ic $qx ($by + 12) 60 60 1 48 }
        $qx += 68
    }
    BrandPlate $g $lang ($x0 + $w0 - 20) $by 84
    Save $bmp $g "s1_art_$lang.png"

    # --- the tabs are the stages
    $bmp, $g = Canvas 1280 330 $K.screen
    Caption $g $s.tabsTitle 24 26
    TopBar $g 24 80 1232
    $tabPos = TabRow $g $lang 40 80 64 21 22   # (not $tabs: PowerShell names ignore case - it is $TABS)
    for ($i = 0; $i -lt $TABS.Count; $i++) {
        $n = $TABS[$i][1]
        if ($n -eq 0) { continue }
        $text = $s.stage + " " + $n + $(if ($n -eq 1) { " · " + $s.now } else { "" })
        $tw = (TextW $g $text "head" 17) + 20
        $tx = $tabPos[$i][0] + ($tabPos[$i][1] - $tw) / 2
        if ($n -eq 1) { Tag $g $tx 160 $text $K.accent | Out-Null }
        else { Fill $g $K.header $tx 160 $tw 28; Frame $g $K.tileEdge $tx 160 $tw 28 1; TxtCentre $g $text "head" 17 $K.dim $tx 160 $tw 28 }
    }
    CapsBlock $g $s.tabsA 40 232 1180 | Out-Null
    Save $bmp $g "s1_tabs_$lang.png"

    # --- stage 1 banner: the inventory's grid, things of all sizes
    BannerPattern "s1_banner_$lang.png" @(
        @(7, 0, 1, 4, "wpn", "bat", ""), @(8, 0, 2, 2, "clo", "jacket", ""), @(10, 0, 1, 1, "info", "idcard", "hit"),
        @(11, 0, 2, 2, "clo", "bag_school", ""), @(13, 0, 1, 2, "food", "bottle", ""), @(14, 0, 1, 1, "med", "pills", ""),
        @(15, 0, 2, 1, "wpn", "pistol", ""), @(8, 2, 1, 1, "food", "beans", ""), @(9, 2, 2, 2, "food", "pot", ""),
        @(14, 1, 1, 1, "mat", "nails", "hit"), @(15, 1, 1, 2, "tool", "hammer", ""), @(12, 2, 2, 1, "wpn", "shotgun", "")
    )

    # --- plans, the big picture: the four stages, the first one now
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.plansTitle 60 56 26
    $stageIcons = @(@("clo", "bag_hiking"), @("med", "bandage"), @("info", "book"), @("tool", "hammer"))
    $cy = 116
    for ($i = 0; $i -lt 4; $i++) {
        $now = $i -eq 0
        $ch = 196
        Fill $g $K.window 60 $cy 840 $ch
        Frame $g $(if ($now) { $K.accent } else { $K.border }) 60 $cy 840 $ch 2
        # the stage's number on a plate: sand for the one that is now
        $nx = 84; $ny = $cy + 24
        if ($now) { Fill $g $K.accent $nx $ny 72 72; TxtCentre $g ([string]($i + 1)) "title" 44 $K.ink $nx $ny 72 72 }
        else { Fill $g $K.cell $nx $ny 72 72; Frame $g $K.tileEdge $nx $ny 72 72 1; TxtCentre $g ([string]($i + 1)) "title" 44 $K.dim $nx $ny 72 72 }
        Txt $g ($s.stage + " " + ($i + 1)) "head" 16 $(if ($now) { $K.accent } else { $K.dim }) 180 ($cy + 28)
        if ($now) { Tag $g (180 + (TextW $g ($s.stage + " 1") "head" 16) + 14) ($cy + 22) $s.now $K.accent | Out-Null }
        Txt $g $s.st[$i][0] "title" 30 $(if ($now) { $K.bright } else { $K.text }) 180 ($cy + 58)
        $ly = $cy + 108
        foreach ($line in (WrapCaps $g $s.st[$i][1] "body" 20 520)) { Txt $g $line "body" 20 $(if ($now) { $K.text } else { $K.dim }) 180 $ly; $ly += 28 }
        # the stage's thing: a tile of the game's own icon
        $C0 = $C; $C = 72
        Tile $g 740 ($cy + 26) 0 0 2 2 $stageIcons[$i][0] $stageIcons[$i][1] $(if ($now) { "hit" } else { "" })
        $C = $C0
        $cy += $ch + 22
    }
    Txt $g $s.plansNote "head" 18 $K.dim 60 ($cy + 10)
    Save $bmp $g "plans_art_$lang.png"

    # --- plans banner: the things of the stages to come
    BannerPattern "plans_banner_$lang.png" @(
        @(7, 0, 1, 1, "med", "bandage", ""), @(8, 0, 1, 1, "med", "pills", ""), @(9, 0, 2, 2, "info", "book", "hit"),
        @(11, 0, 1, 2, "tool", "hammer", ""), @(12, 0, 2, 2, "tool", "generator", ""), @(14, 0, 1, 1, "info", "idcard", ""),
        @(15, 0, 2, 2, "tool", "radio", ""), @(7, 1, 2, 2, "clo", "bag_hiking", ""), @(11, 2, 1, 1, "mat", "nails", ""),
        @(14, 1, 1, 1, "med", "bandage", "hit"), @(12, 2, 2, 1, "wpn", "rifle", "")
    )
}
