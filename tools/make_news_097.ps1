# Pictures of the 0.9.7 news post (the stages under the tabs; bag windows and bags
# picked up are searched too), by the approved news rules (see make_news_096.ps1
# and news_ui.ps1): pieces of the Knox screen itself - the top bar with its stage
# plates as KnoxScreen:drawTabStage draws them, a bag window being searched with
# its thread, a worn bag's section being searched - the game's own icons and
# words, captions in capitals, a banner with no words, a picture per language.
#   42\media\knox\news\u097_<name>_<ru|en>.png   banner, art, stages, search
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_097.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        stTitle = "ПОД КАЖДОЙ ВКЛАДКОЙ - ЕЁ СТАДИЯ"
        stA = "ПЕСОЧНАЯ - ТА, НАД КОТОРОЙ МЫ РАБОТАЕМ СЕЙЧАС. У КАРТЫ СТАДИИ НЕТ, ВКЛАДКА «ЖУРНАЛ» УБРАНА."
        seTitle = "ОКНА СУМОК И ПОДОБРАННЫЕ СУМКИ ТОЖЕ ОБЫСКИВАЮТСЯ"
        seA = "ОТКРЫЛИ ПАКЕТ ДВОЙНЫМ ЩЕЛЧКОМ - ВЕЩИ В ЕГО ОКНЕ НАХОДЯТСЯ ПО ОДНОЙ."
        seB = "ПОДОБРАЛИ ЧУЖОЙ РЮКЗАК И НАДЕЛИ НЕ ГЛЯДЯ - ЕГО ОБЫСКИВАЮТ ПРЯМО В ИНВЕНТАРЕ."
        seC = "ПОКА ВЕЩЬ НЕ НАЙДЕНА, ЕЁ НЕ ВИДНО НИГДЕ: НИ В ПОИСКЕ ПО НАЗВАНИЮ, НИ В «НАЙДЕНО», НИ В БЫСТРОМ ВЫБОРЕ СЛОТОВ."
        floor = "ПОЛ"; hiking = "ПОХОДНЫЙ РЮКЗАК"
        artTitle = "СТАДИИ И ЧЕСТНЫЙ ОБЫСК"
    }
    en = @{
        stTitle = "UNDER EVERY TAB - ITS STAGE"
        stA = "THE SAND ONE IS THE STAGE WE ARE WORKING ON NOW. THE MAP HAS NO STAGE, THE JOURNAL TAB IS GONE."
        seTitle = "BAG WINDOWS AND BAGS YOU PICK UP ARE SEARCHED TOO"
        seA = "OPEN A BAG WITH A DOUBLE CLICK - THE THINGS IN ITS WINDOW ARE FOUND ONE BY ONE."
        seB = "PICK UP SOMEONE'S BACKPACK AND PUT IT ON WITHOUT A LOOK - IT IS SEARCHED RIGHT IN YOUR INVENTORY."
        seC = "UNTIL A THING IS FOUND IT SHOWS NOWHERE: NOT IN THE NAME SEARCH, NOT IN FOUND, NOT IN THE QUICK PICK OF SLOTS."
        floor = "GROUND"; hiking = "HIKING BAG"
        artTitle = "STAGES AND HONEST SEARCHING"
    }
}
$TABS = @(@("Equipment", 1), @("Health", 2), @("Skills", 3), @("Crafting", 4), @("Map", 0))

# The top bar's tabs from x (the first active, a sand line under it), and under
# them the stage plates a pad lower, as KnoxScreen draws them.
function TabsWithStages($g, $lang, $x, $y, $w, $px) {
    Fill $g $K.bar $x $y $w 64; Fill $g $K.border $x ($y + 63) $w 1
    $tx = $x + 16; $first = $true
    foreach ($t in $TABS) {
        $name = Up (Tr $lang ("IGUI_Knox_Tab_" + $t[0]))
        $tw = (TextW $g $name "head" $px) + 2 * 22
        TxtCentre $g $name "head" $px $(if ($first) { $K.bright } else { $K.dim }) $tx $y $tw 64
        if ($first) { Fill $g $K.accent $tx ($y + 61) $tw 3 }
        if ($t[1] -gt 0) {
            $now = $t[1] -eq 1
            $label = Up ((Tr $lang $(if ($now) { "IGUI_Knox_TabStageNow" } else { "IGUI_Knox_TabStage" })).Replace("%1", [string]$t[1]))
            $pw = (TextW $g $label "head" 16) + 24; $ph = 28
            $plx = $tx + ($tw - $pw) / 2; $ply = $y + 64 + 16
            if ($now) { Fill $g $K.accent $plx $ply $pw $ph; TxtCentre $g $label "head" 16 $K.ink $plx $ply $pw $ph }
            else { Fill $g $K.header $plx $ply $pw $ph; Frame $g $K.tileEdge $plx $ply $pw $ph 1; TxtCentre $g $label "head" 16 $K.dim $plx $ply $pw $ph }
        }
        $tx += $tw; $first = $false
    }
}

# a thread from a tile to its window (KnoxThread): round the corner at x = mx
function Thread($g, $x1, $y1, $x2, $y2, $mx) {
    Fill $g $K.accent ([math]::Min($x1, $mx)) ($y1 - 1) ([math]::Abs($mx - $x1) + 2) 2
    Fill $g $K.accent ($mx - 1) ([math]::Min($y1, $y2)) 2 ([math]::Abs($y2 - $y1) + 2)
    Fill $g $K.accent ([math]::Min($mx, $x2)) ($y2 - 1) ([math]::Abs($x2 - $mx) + 2) 2
    Fill $g $K.accent ($x1 - 3) ($y1 - 3) 6 6; Fill $g $K.accent ($x2 - 3) ($y2 - 3) 6 6
}

# the thing being found right now (KnoxSearch.drawCurrent): a dark plate filling
# with sand from the bottom, in a sand frame
function Current($g, $gx, $gy, $col, $row, $w, $h, $frac) {
    $x = $gx + $col * $C + 1; $y = $gy + $row * $C + 1; $pw = $w * $C - 1; $ph = $h * $C - 1
    Fill $g $K.header $x $y $pw $ph
    $fh = [math]::Floor($ph * $frac); Fill $g $K.accent $x ($y + $ph - $fh) $pw $fh 0.16
    Frame $g $K.accent $x $y $pw $ph 2 0.7
}

# a bag window (KnoxContainerWindow) being searched: the title, "Searching n / m",
# the cross, the grid with what is found so far
function BagWindow($g, $lang, $x, $y, $cols, $rows, $title, $found, $total) {
    $hdr = 44; $pad = 16
    $info = (Tr $lang "IGUI_Knox_Searching").Replace("%1", [string]$found).Replace("%2", [string]$total)
    # (as KnoxContainerWindow:fitToView: wide enough for the title, the info and the cross)
    $w = [math]::Max($cols * $C + 1 + $pad * 2, (TextW $g (Up $title) "head" 18) + (TextW $g $info "body" 19) + 28 + 56)
    $h = $hdr + $rows * $C + 1 + $pad * 2
    for ($i = 1; $i -le 4; $i++) { Fill $g $K.screen ($x + $i) ($y + 2 * $i) $w $h 0.1 }
    Fill $g $K.window $x $y $w $h; Fill $g $K.header $x $y $w $hdr; Fill $g $K.border $x ($y + $hdr) $w 1
    Frame $g $K.accent $x $y $w $h 2
    TxtMid $g (Up $title) "head" 18 $K.text ($x + 10) $y $hdr
    $bh = 28; $cx = $x + $w - 8 - $bh
    Fill $g $K.buttonBg $cx ($y + 8) $bh $bh; Frame $g $K.tileEdge $cx ($y + 8) $bh $bh 1
    Cross $g ($cx + $bh / 2) ($y + 8 + $bh / 2) 6 $K.bright
    TxtMid $g $info "body" 19 $K.dim ($cx - 10 - (TextW $g $info "body" 19)) $y $hdr
    Grid $g ($x + $pad) ($y + $hdr + $pad) $cols $rows
    return @{x = $x; y = $y; w = $w; h = $h; gx = ($x + $pad); gy = ($y + $hdr + $pad)}
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.7 ($lang):"
    $bagName = GTr $lang "ItemName" "Base.Plasticbag"

    # --- the stages under the tabs
    $bmp, $g = Canvas 1280 310 $K.screen
    Caption $g $s.stTitle 24 26
    TabsWithStages $g $lang 24 80 1232 21
    CapsBlock $g $s.stA 40 236 1180 | Out-Null
    Save $bmp $g "u097_stages_$lang.png"

    # --- searching: a bag window opened from the floor; a worn bag in the inventory column
    $bmp, $g = Canvas 1280 620 $K.screen
    Caption $g $s.seTitle 24 26
    $fx = 40; $fy = 120
    Strip $g $fx 84 (4 * $C + 1) $s.floor "4x4" $null $true
    Grid $g $fx $fy 4 4
    Tile $g $fx $fy 2 0 2 2 "clo" "plasticbag"; Frame $g $K.accent ($fx + 2 * $C + 1) ($fy + 1) (2 * $C - 1) (2 * $C - 1) 1
    Tile $g $fx $fy 0 0 1 2 "food" "bottle"; Tile $g $fx $fy 1 0 1 1 "food" "beans"; Tile $g $fx $fy 0 2 1 1 "tool" "battery"
    $win = BagWindow $g $lang 400 84 4 3 $bagName 2 5
    Thread $g ($fx + 4 * $C) ($fy + $C) ($win.x) ($win.y + 22) 360
    Tile $g $win.gx $win.gy 0 0 1 1 "food" "chips"; Tile $g $win.gx $win.gy 1 0 1 1 "med" "bandage"
    Current $g $win.gx $win.gy 2 0 1 2 0.6
    $yb = CapsBlock $g $s.seA 40 ($fy + 4 * $C + 30) 640
    # the worn bag's section: being searched, its header saying so
    $sx = 820; $sy = 84
    $info = (Tr $lang "IGUI_Knox_Searching").Replace("%1", "1").Replace("%2", "4")
    Strip $g $sx $sy (6 * $C + 1) $s.hiking $info $K.accent
    Grid $g $sx ($sy + 36) 6 5
    Tile $g $sx ($sy + 36) 0 0 1 1 "info" "idcard"
    Current $g $sx ($sy + 36) 1 0 1 1 0.35
    CapsBlock $g $s.seB $sx ($sy + 36 + 5 * $C + 26) 420 | Out-Null
    CapsBlock $g $s.seC 40 ($yb + 14) 700 | Out-Null
    Save $bmp $g "u097_search_$lang.png"

    # --- art: the top bar with its stages; the floor and a bag window being searched
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 60 56 26
    TabsWithStages $g $lang 60 110 840 17
    Column $g 60 250 840 760 (Tr $lang "IGUI_Knox_Tab_Surroundings")
    Row $g 76 310 300 (GTr $lang "IG_UI" "IGUI_ContainerTitle_floor") "c_floor" "4" "full" $true
    $fx = 76; $fy = 426
    Strip $g $fx 390 (5 * $C + 1) $s.floor "5x7" $null $true
    Grid $g $fx $fy 5 7
    Tile $g $fx $fy 3 0 2 2 "clo" "plasticbag"; Frame $g $K.accent ($fx + 3 * $C + 1) ($fy + 1) (2 * $C - 1) (2 * $C - 1) 1
    Tile $g $fx $fy 2 0 1 2 "food" "bottle"; Tile $g $fx $fy 0 0 2 2 "clo" "bag_hiking"; Tile $g $fx $fy 0 2 1 1 "tool" "battery"
    Tile $g $fx $fy 1 2 1 3 "wpn" "bat"
    $win = BagWindow $g $lang 470 470 6 6 $bagName 3 7
    Thread $g ($fx + 5 * $C) ($fy + $C) ($win.x) ($win.y + 22) 440
    Tile $g $win.gx $win.gy 0 0 1 1 "food" "chips"; Tile $g $win.gx $win.gy 1 0 1 1 "med" "bandage"; Tile $g $win.gx $win.gy 2 0 1 1 "food" "beans"
    Current $g $win.gx $win.gy 3 0 1 2 0.55
    Save $bmp $g "u097_art_$lang.png"

    # --- banner: bags of every kind, a few lit
    BannerPattern "u097_banner_$lang.png" @(
        @(7, 0, 2, 2, "clo", "plasticbag", ""), @(9, 0, 2, 2, "clo", "bag_school", "hit"), @(11, 0, 2, 2, "clo", "bag_hiking", ""),
        @(13, 0, 3, 2, "clo", "duffel", ""), @(16, 0, 1, 1, "info", "idcard", ""), @(7, 2, 1, 1, "food", "chips", ""),
        @(8, 2, 1, 1, "med", "bandage", "hit"), @(9, 2, 1, 2, "food", "bottle", ""), @(10, 2, 2, 1, "clo", "fannypack", ""),
        @(12, 2, 1, 1, "food", "beans", ""), @(13, 2, 1, 1, "tool", "battery", "")
    )
}
