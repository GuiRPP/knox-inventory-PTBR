# Pictures of the 0.9.6 news post, in the look of the Knox screen itself: its
# panels, header strips, grids, tiles, number plates, the search field and the
# Found window, at the 64 px cell of a 1440p screen, with the game's own item and
# container icons out of its texture packs (tools\game_icons.ps1 -> tools\art\gameicons;
# not cut from screenshots - the author asked for the game's files). Not schemes on a
# gridded backdrop as in 0.9.0 / 0.9.5: those did not look like the interface.
#
# Text on them is the mod's own strings, so there is a picture per language:
#   42\media\knox\news\u096_<name>_<ru|en>.png
#   banner   912x204  the card in the main menu (its left part lies under the card's text)
#   art      960x1080 the big picture of the opened post (drawn whole on the frame's colour)
#   search, found, bags, rummage, speed   1280 wide, one per section
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_096.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")


# --- the strings, per language ----------------------------------------------------
$L = @{
    ru = @{
        q = "нож"; found = "НАЙДЕНО"; foundTitle = "НАЙДЕНО: «НОЖ»"; take = "ЗАБРАТЬ ВСЁ"; mine = "· У ВАС"
        inv = "ИНВЕНТАРЬ"; sur = "ОКРУЖЕНИЕ"; equip = "СНАРЯЖЕНИЕ"; pockets = "КАРМАНЫ"; school = "ШКОЛЬНЫЙ РЮКЗАК"; hiking = "ПОХОДНЫЙ РЮКЗАК"
        dish = "ШКАФ"; dishRow = "Шкаф"; cabinet = "Комод"; kcab = "Полки"; dresser = "Шкаф"; fridge = "Холодильник"; floor = "Пол"; floorCap = "ПОЛ"
        hikingRow = "Походный рюкзак"; slotBack = "РЮКЗАК"; slotBackAttach = "СПИНА"
        searching = "Обыск 2 / 7"; kcabCap = "ПОЛКИ"
        legendNone = "ЕЩЁ НЕ ЗАГЛЯДЫВАЛИ"; legendPart = "ОБЫСКАН ЧАСТИЧНО: СТОЛЬКО УЖЕ НАШЛИ"; legendFull = "ОБЫСКАН ВЕСЬ: СТОЛЬКО ВСЕГО ВЕЩЕЙ"
        spTitle = "ГОРА ВЕЩЕЙ НА ПОЛУ БОЛЬШЕ НЕ ТОРМОЗИТ ИГРУ"; spPile = "ПОЛ  ·  600 ВЕЩЕЙ"
        before = "БЫЛО"; beforeNum = "0,55 С"; beforeText = "СТОЛЬКО УХОДИЛО НА ОДНУ РАСКЛАДКУ ВСЕЙ КУЧИ ПО СЕТКЕ. И ТАК ЧЕТЫРЕ РАЗА В СЕКУНДУ - ИГРА ПОЧТИ ЗАМИРАЛА, ДО 5 КАДРОВ В СЕКУНДУ."
        after = "СТАЛО"; afterNum = "0,085 С"; afterText = "РАСКЛАДКА В 7 РАЗ БЫСТРЕЕ И ТОЛЬКО ТОГДА, КОГДА В КУЧЕ ЧТО-ТО ПОМЕНЯЛОСЬ: ВЕЩЬ ВЗЯЛИ, ПОЛОЖИЛИ ИЛИ ПЕРЕЛОЖИЛИ."
        drop = "ОТПУСТИТЕ, ЧТОБЫ НАДЕТЬ"; weight = "4.6 / 12 КГ"; weight2 = "6 / 32 КГ"
    }
    en = @{
        q = "knife"; found = "FOUND"; foundTitle = ("FOUND: " + [char]0x201C + "KNIFE" + [char]0x201D); take = "TAKE ALL"; mine = "· ON YOU"
        inv = "INVENTORY"; sur = "SURROUNDINGS"; equip = "EQUIPMENT"; pockets = "POCKETS"; school = "SCHOOL BAG"; hiking = "HIKING BAG"
        dish = "CUPBOARD"; dishRow = "Cupboard"; cabinet = "Drawer"; kcab = "Shelves"; dresser = "Cupboard"; fridge = "Fridge"; floor = "Ground"; floorCap = "GROUND"
        hikingRow = "Hiking Bag"; slotBack = "BACKPACK"; slotBackAttach = "BACK"
        searching = "Searching 2 / 7"; kcabCap = "SHELVES"
        legendNone = "NOT LOOKED INTO YET"; legendPart = "SEARCHED IN PART: FOUND SO FAR"; legendFull = "SEARCHED THROUGH: ALL THINGS IN IT"
        spTitle = "A MOUNTAIN OF LOOT NO LONGER SLOWS THE GAME DOWN"; spPile = "GROUND  ·  600 THINGS"
        before = "BEFORE"; beforeNum = "0.55 S"; beforeText = "THAT IS HOW LONG ONE LAYOUT OF THE WHOLE PILE ON THE GRID TOOK. FOUR TIMES A SECOND - THE GAME NEARLY FROZE, DOWN TO 5 FRAMES PER SECOND."
        after = "NOW"; afterNum = "0.085 S"; afterText = "THE LAYOUT IS 7 TIMES FASTER AND ONLY HAPPENS WHEN SOMETHING IN THE PILE CHANGES: A THING TAKEN, DROPPED OR MOVED."
        drop = "RELEASE TO WEAR"; weight = "4.6 / 12 KG"; weight2 = "6 / 32 KG"
    }
}

# the Found window's cards, the same in every picture
function FoundCards($s) {
    return @(
        @{ name = $s.dish; mine = $false; n = "1"; cols = 8; rows = 1; tiles = @(, @(0, 0, 1, 1, "wpn", "knife", "hit")) },
        @{ name = $s.pockets; mine = $true; n = "1"; cols = 8; rows = 1; tiles = @(, @(0, 0, 1, 1, "wpn", "knife_pocket", "hit")) },
        @{ name = $s.school; mine = $true; n = "2"; cols = 8; rows = 3; tiles = @(@(0, 0, 1, 3, "wpn", "knife", "hit"), @(1, 0, 1, 3, "wpn", "knife", "hit")) }
    )
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.6 ($lang):"

    # --- search: the field, matches lit in sand, the rest dimmed, counts on the rows
    $bmp, $g = Canvas 1280 600 $K.screen
    TopBar $g 0 0 1280
    SearchField $g 24 12 360 $s.q
    FoundButton $g 398 12 $s.found "4" | Out-Null
    Column $g 24 88 452 496 $s.inv $s.weight
    Strip $g 40 148 420 $s.pockets "4x2" $null $true
    Grid $g 40 184 4 2
    Tile $g 40 184 0 0 1 2 "food" "bottle" "dim"
    Tile $g 40 184 1 0 1 2 "food" "chips" "dim"
    Tile $g 40 184 2 0 1 1 "info" "idcard" "dim"
    Tile $g 40 184 3 0 1 1 "info" "keyring" "dim"
    Strip $g 40 328 420 $s.school "5x6  5.1/19"
    Grid $g 40 364 5 3
    Tile $g 40 364 0 0 1 3 "wpn" "knife" "hit"
    Tile $g 40 364 1 0 1 1 "wpn" "knife_pocket" "hit"
    Tile $g 40 364 1 1 1 1 "tool" "pliers" "dim"
    Tile $g 40 364 2 0 1 3 "wpn" "knife" "hit"
    Tile $g 40 364 3 0 1 1 "info" "book" "dim"
    Column $g 496 88 760 496 $s.sur $s.weight2
    Row $g 512 148 286 $s.dishRow "c_counter" "1" "full" $true
    Row $g 512 220 286 $s.cabinet "c_dresser" "0" "zero"
    Row $g 512 292 286 $s.fridge "c_fridge" "0" "zero"
    Row $g 512 364 286 $s.floor "c_floor" "0" "zero"
    Strip $g 812 148 (6 * $C) $s.dish "6x5"
    Grid $g 812 184 6 5
    Tile $g 812 184 0 0 1 1 "wpn" "knife" "hit"
    Tile $g 812 184 1 0 1 1 "food" "steak" "dim"
    Tile $g 812 184 2 0 1 1 "food" "cucumber" "dim"
    Save $bmp $g "u096_search_$lang.png"

    # --- found: the window with every match by container; a thing carried onto a card
    $bmp, $g = Canvas 1280 640 $K.screen
    TopBar $g 0 0 1280
    SearchField $g 24 12 360 $s.q
    FoundButton $g 398 12 $s.found "4" | Out-Null
    $cards = FoundCards $s
    $wh = FoundWindow $g 330 88 620 $s.foundTitle "4" $s.take $s.mine $cards 1
    # the knife from the first card held over the pockets' card
    Fill $g $K.screen (330 + 14 + 1) (88 + 52 + 36 + 1) ($C - 1) ($C - 1) 0.55
    Held $g (330 + 14 + 2 * $C + 20) (88 + 52 + 36 + $C + 14 + 36 + 6) 1 1 "wpn" "knife"
    Save $bmp $g "u096_found_$lang.png"

    # --- bags: a bag in the Surroundings taken by its row and put on the back
    $bmp, $g = Canvas 1280 560 $K.screen
    Column $g 24 24 380 512 $s.equip
    # the rest of the body's slots, empty
    foreach ($sl in @(@(40, 296), @(220, 296))) { Fill $g $K.cell $sl[0] $sl[1] 168 100; Frame $g $K.border $sl[0] $sl[1] 168 100 2 }
    Fill $g $K.cell 40 412 348 108; Frame $g $K.border 40 412 348 108 2
    # the back slot, lit green: the bag goes there
    $sx = 40; $sy = 84
    Fill $g $K.cell $sx $sy 168 196; Frame $g $K.ok $sx $sy 168 196 2; Fill $g $K.ok $sx $sy 168 196 0.14
    Txt $g $s.slotBack "head" 15 $K.dim ($sx + 8) ($sy + 8)
    Fill $g $K.cell 220 84 168 196; Frame $g $K.border 220 84 168 196 2
    Txt $g $s.slotBackAttach "head" 15 $K.dim 228 92
    Column $g 424 24 832 512 $s.sur
    Row $g 440 84 290 $s.hikingRow "bag_hiking" "3" "full" $true $true
    Row $g 440 156 290 $s.dresser "c_counter" "0" "zero"
    Row $g 440 228 290 $s.floor "c_floor" "1" "full"
    # the bag's own grid, its header in a pale sand frame (it can be taken by it)
    Strip $g 746 84 (6 * $C) $s.hiking "6x5" $null $false
    Frame $g (Mix $K.border $K.accent 0.55) 746 84 (6 * $C) 36 2
    Grid $g 746 120 6 5
    Tile $g 746 120 0 0 1 2 "food" "bottle"
    Tile $g 746 120 1 0 1 2 "food" "chips"
    Tile $g 746 120 2 0 1 1 "info" "keyring"
    Tile $g 746 120 3 0 2 2 "clo" "jacket"
    # the bag held at the cursor, on its way to the back
    Held $g 62 120 2 2 "clo" "bag_hiking"
    Save $bmp $g "u096_bags_$lang.png"

    # --- rummage: three looks of a container's plate, and a search taken up again
    $bmp, $g = Canvas 1280 600 $K.screen
    Column $g 24 24 1232 552 $s.sur
    Row $g 40 84 300 $s.cabinet "c_dresser" "" "none"
    Row $g 40 156 300 $s.kcab "c_shelves" "2" "part" $true
    Row $g 40 228 300 $s.dresser "c_counter" "5" "full"
    # the legend, under everything, across the whole width
    Fill $g $K.border 40 388 1200 1
    $ly = 412
    foreach ($e in @(@("", "none", $s.legendNone), @("2", "part", $s.legendPart), @("5", "full", $s.legendFull))) {
        Plate $g 48 $ly 30 $e[0] $e[1] | Out-Null
        TxtMid $g $e[2] "head" 18 $K.text 92 $ly 30
        $ly += 46
    }
    # the half searched cabinet, searched on
    Strip $g 356 84 (13 * $C) $s.kcabCap $s.searching $K.accent
    Grid $g 356 120 13 4
    Tile $g 356 120 0 0 1 2 "food" "bottle"
    Tile $g 356 120 1 0 1 1 "info" "book"
    # the thing being found now: a dark plate filling with sand, in a sand frame
    $fx = 356 + 2 * $C + 1; $fy = 120 + 1; $fw = 2 * $C - 1; $fh = 2 * $C - 1
    Fill $g $K.cell $fx $fy $fw $fh
    Fill $g $K.accent $fx ($fy + $fh * 0.42) $fw ($fh * 0.58) 0.30
    Frame $g $K.accent $fx $fy $fw $fh 2
    Save $bmp $g "u096_rummage_$lang.png"

    # --- speed: what was slow and what is now, said in capitals next to the pile
    $bmp, $g = Canvas 1280 600 $K.screen
    Txt $g $s.spTitle "title" 30 $K.bright 24 26
    # the pile: a floor of hundreds of things
    Column $g 24 76 608 500 $s.sur
    Strip $g 40 136 (9 * $C) $s.spPile
    Grid $g 40 172 9 6
    $pool = @(@("food", "bottle", 1, 2), @("food", "chips", 1, 2), @("info", "book", 1, 1), @("wpn", "knife", 1, 1), @("food", "steak", 1, 1),
              @("food", "cucumber", 1, 1), @("info", "keyring", 1, 1), @("tool", "pliers", 1, 1), @("info", "idcard", 1, 1), @("food", "sausage", 1, 2))
    $n = 0
    for ($row = 0; $row -lt 6; $row += 2) {
        for ($col = 0; $col -lt 9; $col++) {
            $pk = $pool[$n % $pool.Count]; $n++
            if ($pk[3] -eq 2) { Tile $g 40 172 $col $row 1 2 $pk[0] $pk[1] "" $(if ($n % 3 -eq 0) { "12" } else { $null }) }
            else {
                Tile $g 40 172 $col $row 1 1 $pk[0] $pk[1] "" $(if ($n % 4 -eq 0) { "40" } else { $null })
                $qk = $pool[($n + 3) % $pool.Count]
                if ($qk[3] -eq 1) { Tile $g 40 172 $col ($row + 1) 1 1 $qk[0] $qk[1] } else { Tile $g 40 172 $col ($row + 1) 1 1 "food" "steak" }
            }
        }
    }
    # before and now: a tag, the time one layout of the pile takes, what it meant
    $cx = 652; $cw = 604
    foreach ($card in @(@(76, $K.bad, $s.before, $s.beforeNum, $s.beforeText, $K.dim), @(336, $K.accent, $s.after, $s.afterNum, $s.afterText, $K.accent))) {
        $cy = $card[0]
        Fill $g $K.window $cx $cy $cw 240; Frame $g $card[1] $cx $cy $cw 240 2
        $tw = (TextW $g $card[2] "head" 18) + 22
        Fill $g $card[1] ($cx + 24) ($cy + 22) $tw 30
        TxtCentre $g $card[2] "head" 18 $K.ink ($cx + 24) ($cy + 22) $tw 30
        Txt $g $card[3] "title" 64 $card[5] ($cx + 24) ($cy + 70)
        if ($card[2] -eq $s.before) {
            $ow = TextW $g $card[3] "title" 64
            Fill $g $K.bad ($cx + 18) ($cy + 70 + $capH * 64 / 2 - 2) ($ow + 12) 5
        }
        $ly = $cy + 70 + $capH * 64 + 26
        foreach ($line in (WrapCaps $g $card[4] "head" 18 ($cw - 48))) {
            Txt $g $line "head" 18 $K.text ($cx + 24) $ly
            $ly += 28
        }
    }
    Save $bmp $g "u096_speed_$lang.png"
    # --- banner (the card in the main menu): a background, not a picture with words.
    # The card writes its tag, title and first line across nearly its whole width
    # over it (KnoxMenuNews drawCard): any text here ran under those lines and the
    # two read over each other (the author's remark, 2026-10-14). So: a grid of
    # tiles with a few matches lit in sand, dimmed, darkest on the left.
    $bmp, $g = Canvas 912 204 $K.screen
    $bc = 52; $C0 = $C; $C = $bc
    $gx = 8; $gy = -14
    Grid $g $gx $gy 17 5
    $lay = @(
        @(6, 0, 1, 2, "food", "bottle", "dim"), @(7, 1, 1, 1, "info", "keyring", "dim"), @(8, 0, 1, 1, "wpn", "knife", "hit"),
        @(9, 0, 1, 3, "wpn", "knife", "hit"), @(10, 1, 1, 1, "food", "steak", "dim"), @(11, 0, 1, 1, "info", "book", "dim"),
        @(11, 2, 1, 1, "wpn", "knife_pocket", "hit"), @(12, 1, 1, 2, "food", "chips", "dim"), @(13, 0, 1, 1, "tool", "pliers", "dim"),
        @(13, 2, 1, 1, "info", "idcard", "dim"), @(14, 1, 1, 1, "wpn", "knife", "hit"), @(15, 0, 1, 2, "food", "bottle", "dim"),
        @(15, 3, 1, 1, "food", "cucumber", "dim"), @(16, 1, 1, 1, "info", "keyring", "dim"), @(7, 3, 1, 1, "info", "book", "dim"),
        @(10, 3, 1, 1, "food", "sausage", "dim"), @(12, 3, 1, 1, "wpn", "knife", "hit"), @(16, 3, 1, 1, "food", "steak", "dim")
    )
    foreach ($t in $lay) { Tile $g $gx $gy $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] $t[6] }
    $C = $C0
    # all of it a step back, and the left - under the card's words - darkest
    Fill $g $K.screen 0 0 912 204 0.45
    $r = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $r)
    Save $bmp $g "u096_banner_$lang.png"
    # --- art (the opened post's big picture): field and button, the Found window, the rows
    $bmp, $g = Canvas 960 1080 $K.cell
    $ox = 70
    SearchField $g $ox 56 420 $s.q
    FoundButton $g ($ox + 436) 56 $s.found "4" | Out-Null
    $cards = FoundCards $s
    $wh = FoundWindow $g $ox 128 820 $s.foundTitle "4" $s.take $s.mine $cards
    $ry = 128 + $wh + 40
    Row $g $ox $ry 400 $s.cabinet "c_dresser" "" "none"
    Row $g $ox ($ry + 76) 400 $s.kcab "c_shelves" "2" "part" $true
    Row $g $ox ($ry + 152) 400 $s.dresser "c_counter" "5" "full"
    Row $g ($ox + 420) $ry 400 $s.hikingRow "bag_hiking" "3" "full" $false $true
    Row $g ($ox + 420) ($ry + 76) 400 $s.floor "c_floor" "0" "zero"
    Save $bmp $g "u096_art_$lang.png"
}
$cursorImg.Dispose(); $lensImg.Dispose()
foreach ($i in $icons.Values) { $i.Dispose() }
