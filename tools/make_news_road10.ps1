# Pictures of the "Road to 1.0" news post (the 1.0 diary: one post that grows, a
# section per day), by the approved news rules (see make_news_096.ps1 and news_ui.ps1):
# pieces of the Knox screen itself, the game's own icons, captions in capitals, a
# banner with no words, a picture per language.
#   42\media\knox\news\r10_<name>_<ru|en>.png
#   17.10.2026: banner, art, rigs, column, modules, walkie
#   18.10.2026: menu, icons, recipes, alarm, fluid, weight (the item menu and around it);
#               dash, carradio (the car's dashboard and its radio)
# A new day of the diary: add its pictures here (r10_<name>), keep the old ones.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_road10.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        rigTitle = "РАЗГРУЗКА: СУМКИ С ОТСЕКАМИ"
        rigA = "33 СЕМЬИ СУМОК ИГРЫ ПОЛУЧИЛИ ОТСЕКИ: ОСНОВНОЕ ОТДЕЛЕНИЕ, КЛАПАН, ПОДСУМКИ, БОКОВЫЕ КАРМАНЫ. ВСЕ СИММЕТРИЧНЫ."
        rigB = "ВЕЩЬ ЛЕЖИТ ЦЕЛИКОМ В ОДНОМ ОТСЕКЕ. ЧТО НИКУДА НЕ ВЛЕЗЛО - В КРАСНЫХ РЯДАХ ПОД НИМИ."
        colTitle = "КОЛОНКА ИНВЕНТАРЯ"
        colA = "СЕКЦИИ СВОРАЧИВАЮТСЯ ПЛАВНО: СЕТКА УЕЗЖАЕТ ПОД ЗАГОЛОВОК."
        colB = "ЧТО УХОДИТ ЗА КРАЙ КОЛОНКИ, МЯГКО РАСТВОРЯЕТСЯ, А НЕ ОБРЕЗАЕТСЯ."
        colC = "ПОЛОСА ПРОКРУТКИ - С УРОВНЯ ПЕРВОГО ЗАГОЛОВКА, С ВОЗДУХОМ ОТ КРАЯ."
        modTitle = "СЕМЬ МОДУЛЕЙ ВМЕСТО ОДНОГО"
        modA = "КАЖДУЮ ЧАСТЬ KNOX В ИГРЕ МОЖНО ВЫКЛЮЧИТЬ ОТДЕЛЬНО."
        modB = "НАПРИМЕР: ИНВЕНТАРЬ ИГРЫ ИЛИ ДРУГОГО МОДА - И ОКНА ТЕЛЕВИЗОРА, РАДИО И ПЛИТЫ ОТ KNOX."
        modC = "ЕСЛИ «ИНТЕРФЕЙС В ИГРЕ» БЫЛ ВЫКЛЮЧЕН, ВЫКЛЮЧЕНЫ ВСЕ СЕМЬ."
        walkTitle = "РАЦИЯ В РУКАХ - ОКНО KNOX"
        walkA = "ВОЗЬМИТЕ РАЦИЮ В РУКУ - ОТКРОЕТСЯ АППАРАТ KNOX В ТЁМНОМ ПЛАСТИКЕ."
        walkB = "ЧАСТОТА НА ШКАЛЕ, ГРОМКОСТЬ, СТАНЦИИ, МИКРОФОН, БАТАРЕЙКА - ВСЁ, ЧТО В ОКНЕ ИГРЫ."
        walkC = "КАНАЛЫ ТЕЛЕВИЗОРА КОЛЕСОМ: ОДНО ДЕЙСТВИЕ, КОГДА КОЛЕСО ОСТАНОВИЛОСЬ."
        tune = "НАСТРОЙКА"; volume = "ГРОМКОСТЬ"; mhz = "МГЦ"
        artTitle = "ДОРОГА К 1.0"
        artSub = "РАЗГРУЗКА"
    }
    en = @{
        rigTitle = "RIGS: BAGS WITH COMPARTMENTS"
        rigA = "33 FAMILIES OF THE GAME'S BAGS GOT COMPARTMENTS: THE MAIN ROOM, A LID, POUCHES, SIDE POCKETS. ALL SYMMETRIC."
        rigB = "A THING LIES WHOLE IN ONE COMPARTMENT. WHAT FITS NOWHERE LIES IN THE RED ROWS UNDER THEM."
        colTitle = "THE INVENTORY COLUMN"
        colA = "SECTIONS FOLD SMOOTHLY: THE GRID SLIDES UNDER ITS HEADER."
        colB = "WHAT GOES PAST THE COLUMN'S EDGE FADES SOFTLY INSTEAD OF BEING CUT OFF."
        colC = "THE SCROLL BAR STARTS LEVEL WITH THE FIRST HEADER, WITH AIR FROM THE EDGE."
        modTitle = "SEVEN MODULES INSTEAD OF ONE"
        modA = "EVERY PART OF KNOX IN A GAME CAN BE SWITCHED OFF ON ITS OWN."
        modB = "FOR EXAMPLE: THE GAME'S OR ANOTHER MOD'S INVENTORY - WITH KNOX'S TV, RADIO AND STOVE WINDOWS."
        modC = "IF YOU HAD THE IN-GAME INTERFACE OFF, ALL SEVEN ARE OFF."
        walkTitle = "A WALKIE-TALKIE IN HAND - A KNOX WINDOW"
        walkA = "TAKE A WALKIE-TALKIE IN YOUR HAND - THE KNOX SET OPENS, IN DARK PLASTIC."
        walkB = "THE FREQUENCY ON THE DIAL, VOLUME, STATIONS, MICROPHONE, BATTERY - ALL THE GAME'S WINDOW HAS."
        walkC = "TV CHANNELS BY THE WHEEL: ONE ACTION ONCE THE WHEEL STOPS."
        tune = "TUNING"; volume = "VOLUME"; mhz = "MHZ"
        artTitle = "THE ROAD TO 1.0"
        artSub = "RIGS"
    }
}

# --- a bag with compartments, as KnoxBagShapes lays it out --------------------------
# spec "4x2 / 6x6 / 2x2 2x2 2x2": rows of parts, each row centred under the widest,
# each part centred on its row's height, a gap of max(4, cell * 0.2) between them;
# the rows of what doesn't fit under them all, centred, a gap above them.
function ShapeGeo($spec, $cell) {
    $gap = [math]::Max(4, [math]::Floor($cell * 0.2 + 0.5))
    $rowsSpec = @()
    foreach ($rt in $spec.Split("/")) {
        $row = @()
        foreach ($m in [regex]::Matches($rt, "(\d+)x(\d+)")) { $row += , @([int]$m.Groups[1].Value, [int]$m.Groups[2].Value) }
        if ($row.Count -gt 0) { $rowsSpec += , $row }
    }
    $geo = @{ cell = $cell; gap = $gap; parts = @(); w = 0; h = 0; ovCols = 0 }
    $rowW = @(); $rowH = @()
    foreach ($row in $rowsSpec) {
        $rw = -$gap; $rh = 0; $cw = 0
        foreach ($pt in $row) { $rw += $pt[0] * $cell + $gap; $rh = [math]::Max($rh, $pt[1] * $cell); $cw += $pt[0] }
        $rowW += $rw; $rowH += $rh
        $geo.w = [math]::Max($geo.w, $rw); $geo.ovCols = [math]::Max($geo.ovCols, $cw)
    }
    $top = 0
    for ($ri = 0; $ri -lt $rowsSpec.Count; $ri++) {
        $px = [math]::Floor(($geo.w - $rowW[$ri]) / 2)
        foreach ($pt in $rowsSpec[$ri]) {
            $geo.parts += , @{ x = $px; y = $top + [math]::Floor(($rowH[$ri] - $pt[1] * $cell) / 2); cols = $pt[0]; rows = $pt[1] }
            $px += $pt[0] * $cell + $gap
        }
        $top += $rowH[$ri] + $gap
    }
    $geo.h = $top - $gap
    $geo.ovX = [math]::Max(0, [math]::Floor(($geo.w - $geo.ovCols * $cell) / 2))
    $geo.ovY = $geo.h + $gap
    return $geo
}
# its compartments at x, y: each a grid in a frame just outside its lines
function DrawShape($g, $x, $y, $geo) {
    $script:C = $geo.cell
    foreach ($pt in $geo.parts) {
        $gx = $x + $pt.x; $gy = $y + $pt.y
        Grid $g $gx $gy $pt.cols $pt.rows
        Frame $g $K.tileEdge ($gx - 1) ($gy - 1) ($pt.cols * $geo.cell + 3) ($pt.rows * $geo.cell + 3) 1 0.55
    }
}
# a tile in compartment `idx` (0-based, in the spec's order)
function PartTile($g, $x, $y, $geo, $idx, $col, $row, $tw, $th, $cat, $icon, $state = "", $count = $null) {
    $script:C = $geo.cell
    $pt = $geo.parts[$idx]
    Tile $g ($x + $pt.x) ($y + $pt.y) $col $row $tw $th $cat $icon $state $count
}
# the rows of what doesn't fit: cells, a red tint, a 2 px red frame all round
function DrawOverflow($g, $x, $y, $geo, $rows) {
    $script:C = $geo.cell
    $ox = $x + $geo.ovX; $oy = $y + $geo.ovY
    $ow = $geo.ovCols * $geo.cell; $oh = $rows * $geo.cell
    Grid $g $ox $oy $geo.ovCols $rows
    Fill $g $K.bad $ox $oy $ow $oh 0.10
    Frame $g $K.bad $ox $oy ($ow + 1) ($oh + 1) 2 0.9
    return @($ox, $oy)
}

# --- the three bags of the rigs picture ------------------------------------------------
function AliceBag($g, $x, $y, $cell) {
    $geo = ShapeGeo "4x2 / 6x6 / 2x2 2x2 2x2" $cell
    DrawShape $g $x $y $geo
    # the lid
    PartTile $g $x $y $geo 0 0 0 1 1 "med" "bandage" "" "4"
    PartTile $g $x $y $geo 0 1 0 1 1 "med" "pills"
    PartTile $g $x $y $geo 0 2 0 1 2 "tool" "torch"
    PartTile $g $x $y $geo 0 3 0 1 1 "wpn" "ammo9" "" "24"
    # the main room
    PartTile $g $x $y $geo 1 0 0 1 3 "wpn" "axe"
    PartTile $g $x $y $geo 1 1 0 2 2 "clo" "tshirt"
    PartTile $g $x $y $geo 1 3 0 1 2 "food" "bottle"
    PartTile $g $x $y $geo 1 4 0 1 1 "food" "beans" "" "2"
    PartTile $g $x $y $geo 1 5 0 1 1 "food" "apple"
    PartTile $g $x $y $geo 1 1 2 2 2 "info" "book"
    PartTile $g $x $y $geo 1 3 2 1 2 "tool" "hammer"
    PartTile $g $x $y $geo 1 4 1 1 1 "food" "chips"
    PartTile $g $x $y $geo 1 0 4 2 2 "clo" "jacket"
    PartTile $g $x $y $geo 1 4 4 1 2 "tool" "screwdriver"
    # the pouches
    PartTile $g $x $y $geo 2 0 0 1 1 "mat" "nails" "" "20"
    PartTile $g $x $y $geo 2 1 0 1 1 "mat" "tape"
    PartTile $g $x $y $geo 3 0 0 2 1 "wpn" "clip9" "" "2"
    PartTile $g $x $y $geo 4 0 0 1 2 "mat" "thread"
    return $geo
}
function SchoolBag($g, $x, $y, $cell) {
    $geo = ShapeGeo "1x2 4x5 1x2 / 3x2" $cell
    DrawShape $g $x $y $geo
    PartTile $g $x $y $geo 0 0 0 1 2 "food" "bottle"
    PartTile $g $x $y $geo 2 0 0 1 2 "tool" "torch"
    PartTile $g $x $y $geo 1 0 0 2 2 "info" "book_skill"
    PartTile $g $x $y $geo 1 2 0 1 1 "food" "chips"
    PartTile $g $x $y $geo 1 3 0 1 1 "food" "beans"
    PartTile $g $x $y $geo 1 2 1 1 2 "tool" "knife"
    PartTile $g $x $y $geo 1 0 3 2 2 "clo" "hoodie"
    PartTile $g $x $y $geo 3 0 0 1 1 "misc" "idcard"
    PartTile $g $x $y $geo 3 1 0 1 1 "misc" "keyring"
    PartTile $g $x $y $geo 3 2 0 1 1 "misc" "wallet"
    return $geo
}
function ChestRig($g, $x, $y, $cell) {
    $geo = ShapeGeo "1x2 1x2 1x2 1x2 / 2x1" $cell
    DrawShape $g $x $y $geo
    PartTile $g $x $y $geo 0 0 0 1 1 "wpn" "clip9"
    PartTile $g $x $y $geo 1 0 0 1 1 "wpn" "clip9"
    PartTile $g $x $y $geo 2 0 0 1 2 "tool" "walkie"
    PartTile $g $x $y $geo 3 0 0 1 1 "wpn" "shells" "" "8"
    PartTile $g $x $y $geo 4 0 0 1 1 "med" "bandage"
    $o = DrawOverflow $g $x $y $geo 4
    Tile $g $o[0] $o[1] 0 0 1 4 "wpn" "rifle"
    return $geo
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures Road to 1.0 ($lang):"

    # --- rigs: three bags side by side, their strips over them
    $bmp, $g = Canvas 1280 790 $K.screen
    Caption $g $s.rigTitle 24 26
    $cell = 48; $top = 92
    $bags = @(
        @{ ft = "Base.Bag_ALICEpack"; size = "6x6+20"; fn = "AliceBag"; w = 288 },
        @{ ft = "Base.Bag_Schoolbag"; size = "4x5+10"; fn = "SchoolBag"; w = 308 },
        @{ ft = "Base.Bag_ChestRig"; size = "1x2+8"; fn = "ChestRig"; w = 222 }
    )
    # (each strip as wide as its name and size need, the three centred on the picture)
    foreach ($b in $bags) {
        $b.name = Up (GTr $lang "ItemName" $b.ft)
        $b.info = $b.size; $b.infoC = $null
        if ($b.fn -eq "ChestRig") { $b.info = ((Tr $lang "IGUI_Knox_Overflow") -replace "%1", "1") + "  " + $b.size; $b.infoC = $K.bad }
        $b.stripW = [math]::Max($b.w + 40, (TextW $g $b.name "head" 18) + (TextW $g $b.info "head" 18) + 50)
    }
    $total = ($bags | ForEach-Object { $_.stripW } | Measure-Object -Sum).Sum + 34 * ($bags.Count - 1)
    $bx = [math]::Floor((1280 - $total) / 2)
    foreach ($b in $bags) {
        $stripW = $b.stripW; $name = $b.name; $info = $b.info; $infoC = $b.infoC
        Strip $g $bx $top $stripW $name $info $infoC
        $gx = $bx + [math]::Floor(($stripW - $b.w) / 2)
        & $b.fn $g $gx ($top + 52) $cell | Out-Null
        $bx += $stripW + 34
    }
    $script:C = 64
    $ty = CapsBlock $g $s.rigA 40 690 1200 19 $null 28
    CapsBlock $g $s.rigB 40 ($ty + 6) 1200 19 $K.accent 28 | Out-Null
    Save $bmp $g "r10_rigs_$lang.png"

    # --- the inventory column: pockets, the pack's compartments fading at the bottom, the bar
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.colTitle 24 26
    $script:C = 64
    $cx = 40; $cy = 84; $cw = 8 * 64 + 2 * $P + 7; $ch = 610
    Column $g $cx $cy $cw $ch (Tr $lang "IGUI_Knox_Inventory") "8.3 / 12"
    $sx = $cx + $P; $sy = $cy + 70
    $hw = 8 * 64 + 1
    Strip $g $sx $sy $hw (Up (Tr $lang "IGUI_Knox_Pockets")) "4x2"
    Grid $g $sx ($sy + 36) 4 2
    Tile $g $sx ($sy + 36) 0 0 1 1 "misc" "idcard"
    Tile $g $sx ($sy + 36) 1 0 1 1 "misc" "keyring"
    Tile $g $sx ($sy + 36) 2 0 1 2 "tool" "knife_pocket"
    Tile $g $sx ($sy + 36) 0 1 1 1 "misc" "wallet"
    $py = $sy + 36 + 2 * 64 + 14
    Strip $g $sx $py $hw (Up (GTr $lang "ItemName" "Base.Bag_ALICEpack")) "6x6+20  11.3/36"
    $geo = ShapeGeo "4x2 / 6x6 / 2x2 2x2 2x2" 64
    $ax = $sx + [math]::Floor(($hw - $geo.w) / 2)
    # (clipped at the column's bottom edge, a pad above it)
    $clipH = $cy + $ch - $P - ($py + 36)
    $clip = New-Object System.Drawing.Rectangle ([int]$cx), ([int]($py + 36)), ([int]$cw), ([int]$clipH)
    $g.SetClip($clip)
    AliceBag $g $ax ($py + 46) 64 | Out-Null
    $g.ResetClip()
    $script:C = 64
    # the soft fade into the column, inside its frame
    $band = [math]::Floor(64 * 1.3); $bot = $cy + $ch - $P
    for ($i = 0; $i -lt $band; $i += 2) {
        $f = 1 - $i / $band
        Fill $g $K.window ($cx + 1) ($bot - $i - 2) ($cw - 2) 2 ($f * $f * 0.95)
    }
    # the scroll bar: from the first header down, in the middle of the strip right of the headers
    $barX = $sx + $hw + [math]::Floor(($cx + $cw - ($sx + $hw) - 3) / 2)
    Fill $g $K.tileEdge $barX $sy 3 ([math]::Floor(($bot - $sy) * 0.62))
    $tx = $cx + $cw + 50; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.colA $tx 150 $tw 19 $null 28
    $ty = CapsBlock $g $s.colB $tx ($ty + 14) $tw 19 $null 28
    CapsBlock $g $s.colC $tx ($ty + 14) $tw 19 $K.accent 28 | Out-Null
    Save $bmp $g "r10_column_$lang.png"

    # --- modules: the settings window on its Modules page, two groups of switches
    $bmp, $g = Canvas 1280 1090 $K.screen
    Caption $g $s.modTitle 24 26
    $wx = 40; $wy = 84; $ww = 740; $wh = 970
    Win $g $wx $wy $ww $wh (Tr $lang "IGUI_Knox_Settings")
    $pages = @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_game"),
               (Tr $lang "IGUI_Knox_Page_order"), (Tr $lang "IGUI_Knox_Page_controls"))
    $y = Tabs $g $wx ($wy + 44) $ww $pages 0
    $mx = $wx + 2 * $P; $mw = $ww - 4 * $P
    $y += 22
    Txt $g (Up (Tr $lang "IGUI_Knox_Modules_Title")) "head" 19 $K.accent $mx $y
    $y += 38
    $groups = @(
        @("game", @("inventory", "hotbar", "devices", "stove", "fluids", "tooltips", "menus")),
        @("out", @("menu", "newgame"))
    )
    foreach ($grp in $groups) {
        Txt $g (Up (Tr $lang ("IGUI_Knox_Modules_Group_" + $grp[0]))) "body" 18 $K.dim $mx $y
        $y += 30
        foreach ($name in $grp[1]) {
            Fill $g $K.line $mx ($y - 6) $mw 1
            # (the example: the game's inventory with Knox's windows)
            $on = $name -ne "inventory"
            $y = SwitchRow $g $mx $y $on (Tr $lang ("IGUI_Knox_Module_" + $name)) (Tr $lang ("IGUI_Knox_Module_" + $name + "_Info")) $mw $true
            $y += 10
        }
        $y += 10
    }
    $tx = $wx + $ww + 40; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.modA $tx 150 $tw 19 $null 28
    $ty = CapsBlock $g $s.modB $tx ($ty + 14) $tw 19 $K.accent 28
    CapsBlock $g $s.modC $tx ($ty + 14) $tw 19 $null 28 | Out-Null
    Save $bmp $g "r10_modules_$lang.png"

    # --- the walkie-talkie: the Knox set in dark plastic
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.walkTitle 24 26
    $wx = 40; $wy = 84; $ww = 700; $wh = 534
    Win $g $wx $wy $ww $wh (GTr $lang "ItemName" "Base.WalkieTalkie3")
    $body = Hex "#20241d"; $bodyEdge = Hex "#3b4235"; $glass = Hex "#0f120e"; $glassEdge = Hex "#3a4336"
    $amber = Hex "#ffb547"; $scale = Hex "#8a7a60"; $paper = Hex "#e9e2cf"; $ink = Hex "#3a342a"; $inkDim = Hex "#8a7f68"
    $bz = 18
    $kx = $wx + $P; $ky = $wy + 44 + $P; $kw = $ww - 2 * $P; $kh = $wh - 44 - 2 * $P
    Fill $g $body $kx $ky $kw $kh; Frame $g $bodyEdge $kx $ky $kw $kh 1
    # the dial: a band 25..300 MHz with its marks and the amber needle
    $dx = $kx + $bz; $dy = $ky + $bz; $dw = $kw - 2 * $bz; $dh = 110
    Fill $g $glass $dx $dy $dw $dh; Frame $g $glassEdge $dx $dy $dw $dh 1
    $lo = 25; $hi = 300
    for ($f = 25; $f -le 300; $f += 25) {
        $fx = $dx + 20 + ($dw - 40) * ($f - $lo) / ($hi - $lo)
        $mh = $(if ($f % 50 -eq 0) { 18 } else { 10 })
        Fill $g $scale $fx ($dy + 60) 2 $mh
        if ($f % 50 -eq 0) { TxtCentre $g "$f" "body" 15 $scale ($fx - 20) ($dy + 82) 40 18 }
    }
    $nx = $dx + 20 + ($dw - 40) * (112.6 - $lo) / ($hi - $lo)
    Fill $g $amber $nx ($dy + 46) 3 54
    Txt $g ("112.6 " + $s.mhz) "title" 26 $amber ($dx + 16) ($dy + 14)
    # the signal bars
    for ($i = 0; $i -lt 4; $i++) { Fill $g $(if ($i -lt 3) { $amber } else { $scale }) ($dx + $dw - 70 + $i * 14) ($dy + 34 - $i * 6) 8 (8 + $i * 6) }
    # the paper tape and the knobs
    $py2 = $dy + $dh + $bz
    $tw2 = [math]::Floor($dw * 0.66); $th2 = 230
    Fill $g $paper $dx $py2 $tw2 $th2; Frame $g (Hex "#b9ae92") $dx $py2 $tw2 $th2 1
    $ly = $py2 + 20
    foreach ($ln in @(@(0.82, $ink), @(0.64, $ink), @(0.9, $inkDim), @(0.55, $ink), @(0.74, $ink), @(0.4, $inkDim))) {
        Fill $g $inkDim ($dx + 16) ($ly + 3) 34 6
        Fill $g $ln[1] ($dx + 62) ($ly + 3) ([int](($tw2 - 80) * $ln[0])) 6
        $ly += 34
    }
    $pnx = $dx + $tw2 + $bz; $pnw = $dw - $tw2 - $bz
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    foreach ($kn in @(@(0.27, $s.tune), @(0.73, $s.volume))) {
        $kcx = $pnx + $pnw * $kn[0]; $kcy = $py2 + 70; $kr = 30
        $g.FillEllipse((Br (Hex "#14170f")), [float]($kcx - $kr), [float]($kcy - $kr), [float](2 * $kr), [float](2 * $kr))
        $g.DrawEllipse((New-Object System.Drawing.Pen (A $bodyEdge 1), 2), [float]($kcx - $kr), [float]($kcy - $kr), [float](2 * $kr), [float](2 * $kr))
        $g.FillRectangle((Br $amber), [float]($kcx - 2), [float]($kcy - $kr + 4), 4, 14)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        TxtCentre $g $kn[1] "head" 14 $K.dim ($kcx - 60) ($kcy + $kr + 8) 120 16
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    # the bottom strip: battery, headphones, the microphone and the power switch
    $sy2 = $py2 + $th2 + $bz; $sh2 = 56
    Fill $g (Hex "#181b15") $dx $sy2 $dw $sh2
    $script:C = 64
    $slotW = 76
    Fill $g $K.cell ($dx + 8) ($sy2 + 6) $slotW ($sh2 - 12); Frame $g $K.tileEdge ($dx + 8) ($sy2 + 6) $slotW ($sh2 - 12) 1
    DrawIcon $g "battery" ($dx + 8) ($sy2 + 6) $slotW ($sh2 - 12) 1 36
    Txt $g "84%" "head" 17 $K.bright ($dx + 8 + $slotW + 10) ($sy2 + 20)
    Fill $g $K.cell ($dx + 150) ($sy2 + 6) $slotW ($sh2 - 12); Frame $g $K.tileEdge ($dx + 150) ($sy2 + 6) $slotW ($sh2 - 12) 1
    DrawIcon $g "headphones" ($dx + 150) ($sy2 + 6) $slotW ($sh2 - 12) 0.35 36
    $pwrT = Up (GTr $lang "ContextMenu" "ContextMenu_Turn_Off"); $micT = Up (Tr $lang "IGUI_Knox_RadioMic")
    $pw2 = (TextW $g $pwrT "head" 16) + 50; $mw2 = (TextW $g $micT "head" 16) + 50
    $pxx = $dx + $dw - 8 - $pw2; $mxx = $pxx - 8 - $mw2; $byy = $sy2 + 10; $bh2 = $sh2 - 20
    Fill $g $K.buttonBg $mxx $byy $mw2 $bh2; Frame $g $K.tileFrame $mxx $byy $mw2 $bh2 1
    Fill $g (Hex "#73d959") ($mxx + 12) ($byy + $bh2 / 2 - 5) 10 10
    TxtMid $g $micT "head" 16 $K.bright ($mxx + 30) $byy $bh2
    Fill $g $K.accent $pxx $byy $pw2 $bh2
    TxtCentre $g $pwrT "head" 16 $K.ink $pxx $byy $pw2 $bh2
    $tx = $wx + $ww + 40; $tw = 1280 - $tx - 40
    $script:C = 64
    Tile $g $tx 150 0 0 1 2 "tool" "walkie2"
    $ty = CapsBlock $g $s.walkA $tx 300 $tw 19 $null 28
    $ty = CapsBlock $g $s.walkB $tx ($ty + 14) $tw 19 $null 28
    CapsBlock $g $s.walkC $tx ($ty + 14) $tw 19 $K.accent 28 | Out-Null
    Save $bmp $g "r10_walkie_$lang.png"

    # --- art: the ALICE pack's compartments, big, on the frame's colour
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 64 56 34 $K.accent
    Txt $g $s.artSub "head" 22 $K.dim 64 112
    $geo = ShapeGeo "4x2 / 6x6 / 2x2 2x2 2x2" 80
    AliceBag $g ([math]::Floor((960 - $geo.w) / 2)) 170 80 | Out-Null
    $script:C = 64
    Save $bmp $g "r10_art_$lang.png"

    # --- banner, no words: a grid in the dark with pouches' things, darkest on the left
    BannerPattern "r10_banner_$lang.png" @(
        @(10, 1, 1, 2, "tool", "walkie2", ""), @(11, 0, 1, 1, "wpn", "clip9", "hit"),
        @(11, 1, 1, 1, "wpn", "clip9", ""), @(12, 2, 1, 1, "med", "bandage", ""),
        @(13, 0, 2, 2, "clo", "alice", ""), @(15, 1, 1, 1, "med", "firstaid", ""),
        @(14, 2, 1, 1, "mat", "tape", ""), @(16, 0, 1, 1, "tool", "chestrig", ""))
}

# ======================================================================================
# 18.10.2026: the item menu (KnoxContextMenu), its icons and recipes, the alarm window,
# the container info window, the weight of things with something in them.

$L18 = @{
    ru = @{
        menuTitle = "МЕНЮ ВЕЩИ: ИЗ ПОДСКАЗКИ - В МЕНЮ"
        tip = "ПОДСКАЗКА"; menu = "МЕНЮ ПРАВОЙ КНОПКИ"
        menuA = "ШАПКА ТА ЖЕ, ЧТО У ПОДСКАЗКИ: МЕНЮ ОТКРЫВАЕТСЯ ИЗ НЕЁ, ШАПКА ОСТАЁТСЯ НА МЕСТЕ."
        menuB = "НАВЕРХУ - САМОЕ НУЖНОЕ: ОСМОТРЕТЬ, ГЛАВНОЕ ДЕЙСТВИЕ ВЕЩИ, ЕЁ СОБСТВЕННЫЕ ДЕЙСТВИЯ. ДАЛЬШЕ - ГРУППЫ."
        menuC = "ЧЕТВЕРТЬ, ПОЛОВИНА, ЦЕЛИКОМ - КВАДРАТИКАМИ ПРЯМО В СТРОКЕ. «ПРОЧЕЕ» СВЁРНУТО ДО НАВЕДЕНИЯ."
        foodSub = "Еда  ·  1×1  ·  0.3 кг"; bread = "Хлеб (свежее)"
        tipRows = @(@("Голод:", "-15"), @("Калории:", "720.0"), @("Углеводы:", "72.0"), @("Белки:", "4.5"))
        iconsTitle = "47 ИКОНОК В СТИЛЕ KNOX"
        iconsA = "У КАЖДОГО ПУНКТА МЕНЮ ИГРЫ - СВОЯ ИКОНКА, ОДНОЙ ЛИНИЕЙ."
        iconsB = "В ПОКОЕ СЕРЫЕ, ПОД МЫШЬЮ ПЕСОЧНЫЕ, У ОПАСНЫХ - КРАСНЫЕ."
        iconsC = "ПУНКТЫ ДРУГИХ МОДОВ ОСТАВЛЯЮТ СВОИ КАРТИНКИ."
        recTitle = "РЕЦЕПТЫ ВЕЩИ - «ВЗАИМОДЕЙСТВИЕ»"
        recA = "ПОДМЕНЮ, КОТОРОЕ НАЗЫВАЛОСЬ КАК САМА ВЕЩЬ, ТЕПЕРЬ «ВЗАИМОДЕЙСТВИЕ». У КАЖДОГО РЕЦЕПТА СВОЯ ИКОНКА."
        recB = "ЧТО ЕЩЁ НУЖНО РЕЦЕПТУ - ПРЯМО ПОД НИМ. ВСПЛЫВАЮЩИЕ ПОДСКАЗКИ БОЛЬШЕ НЕ ПОВТОРЯЮТ ПУНКТ."
        axeSub = "Инструменты / Оружие  ·  1×4  ·  3 кг"; sheetSub = "Материалы  ·  2×3  ·  до 4 в стопке  ·  1 кг"
        alarmTitle = "БУДИЛЬНИК - КАК САМИ ЧАСЫ"
        alarmA = "НАРУЧНЫЕ ЧАСЫ С РЕМЕШКОМ ИЛИ БУДИЛЬНИК НА НОЖКАХ. ЯНТАРНЫЕ ЦИФРЫ, СТРЕЛКИ И КОЛЕСО МЫШИ."
        alarmB = "БУДИЛЬНИК ВКЛЮЧАЕТСЯ КНОПКОЙ НА САМИХ ЧАСАХ: ВКЛЮЧЁН - КНОПКА ВДАВЛЕНА, НА ЭКРАНЕ ГОРИТ «AL»."
        alarmC = "КРЕСТИК ИЛИ ESC - ВРЕМЯ СОХРАНЕНО. К ЧАСАМ ТЯНЕТСЯ НИТЬ, САМИ ЧАСЫ ПОДСВЕЧЕНЫ."
        on = "ВКЛЮЧЁН"; off = "ВЫКЛЮЧЕН"
        fluidTitle = "ИНФОРМАЦИЯ О ЁМКОСТИ - ОКНО KNOX"
        fluidA = "БАК С ЖИДКОСТЬЮ ЕЁ ЦВЕТА, ИМЯ ЁМКОСТИ, СКОЛЬКО ВЛЕЗАЕТ, НАЛИТО И СВОБОДНО."
        fluidB = "ОСТАЛЬНЫЕ ПОДСКАЗКИ ИГРЫ - НА ПЛАШКЕ И ШРИФТОМ KNOX."
        water = "Вода"; litre = "л"
        weightTitle = "ВЕС ВЕЩЕЙ С СОДЕРЖИМЫМ"
        before = "БЫЛО"; now = "СТАЛО"
        weightA = "ПОДСКАЗКА, ОСМОТР, СОРТИРОВКА ПО ВЕСУ И «+/-» ПРИ ПЕРЕНОСЕ СЧИТАЮТ ВОДУ В БУТЫЛКЕ, ПАТРОНЫ В МАГАЗИНЕ И ВЕЩИ В СУМКЕ."
        weightB = "ОБЩИЙ ВЕС ПЕРСОНАЖА БЫЛ ВЕРНЫМ И РАНЬШЕ."
        frozenA = "ЗАМОРОЖЕННАЯ ЕДА - В ГОЛУБОЙ РАМКЕ, ПОД ЦВЕТ ЛЬДА."
        bottle = "Бутылка воды"; bottleSub1 = "Вода  ·  1×2  ·  0.15 кг"; bottleSub2 = "Вода  ·  1×2  ·  1.15 кг"
    }
    en = @{
        menuTitle = "THE ITEM MENU: FROM THE TOOLTIP INTO THE MENU"
        tip = "TOOLTIP"; menu = "RIGHT-CLICK MENU"
        menuA = "THE SAME HEADER AS THE TOOLTIP'S: THE MENU OPENS OUT OF IT, THE HEADER STAYS PUT."
        menuB = "ON TOP WHAT YOU NEED MOST: INSPECT, THE ITEM'S MAIN ACTION, ITS OWN ACTIONS. THEN THE GROUPS."
        menuC = "A QUARTER, A HALF, ALL OF IT - AS SQUARES RIGHT ON THE ROW. OTHER STAYS FOLDED UNTIL HOVERED."
        foodSub = "Food  ·  1×1  ·  0.3 kg"; bread = "Bread (Fresh)"
        tipRows = @(@("Hunger:", "-15"), @("Calories:", "720.0"), @("Carbohydrates:", "72.0"), @("Proteins:", "4.5"))
        iconsTitle = "47 ICONS IN KNOX'S STYLE"
        iconsA = "EVERY OPTION OF THE GAME'S MENUS HAS AN ICON OF ITS OWN, IN ONE LINE."
        iconsB = "GREY AT REST, SAND UNDER THE MOUSE, RED FOR THE DANGEROUS ONES."
        iconsC = "OTHER MODS' OPTIONS KEEP THEIR OWN PICTURES."
        recTitle = "AN ITEM'S RECIPES - INTERACT"
        recA = "THE SUB MENU NAMED AFTER THE ITEM ITSELF IS NOW INTERACT. EVERY RECIPE HAS AN ICON OF ITS OWN."
        recB = "WHAT ELSE A RECIPE TAKES IS RIGHT UNDER IT. TOOLTIPS NO LONGER REPEAT THE OPTION."
        axeSub = "Tools / Weapons  ·  1×4  ·  3 kg"; sheetSub = "Material  ·  2×3  ·  stack of 4  ·  1 kg"
        alarmTitle = "THE ALARM - LIKE THE CLOCK ITSELF"
        alarmA = "A WRISTWATCH ON ITS STRAP OR A DESK CLOCK ON ITS FEET. AMBER DIGITS, ARROWS AND THE MOUSE WHEEL."
        alarmB = "THE ALARM IS SWITCHED BY A BUTTON ON THE CLOCK ITSELF: ON - PUSHED IN, AND AL LIT ON THE DISPLAY."
        alarmC = "THE CROSS OR ESC - THE TIME IS SET. A THREAD RUNS TO THE CLOCK, AND THE CLOCK IS LIT."
        on = "ON"; off = "OFF"
        fluidTitle = "CONTAINER INFO - A KNOX WINDOW"
        fluidA = "A TANK WITH THE FLUID IN ITS COLOUR, THE CONTAINER'S NAME, WHAT IT HOLDS, WHAT IS IN IT, WHAT IS FREE."
        fluidB = "THE GAME'S OTHER TOOLTIPS - ON KNOX'S PLATE IN KNOX'S FONT."
        water = "Water"; litre = "L"
        weightTitle = "THE WEIGHT OF THINGS WITH SOMETHING IN THEM"
        before = "BEFORE"; now = "NOW"
        weightA = "THE TOOLTIP, INSPECT, SORT BY WEIGHT AND THE +/- OF A MOVE COUNT THE WATER IN A BOTTLE, THE ROUNDS IN A MAGAZINE, THE THINGS IN A BAG."
        weightB = "THE CHARACTER'S TOTAL WEIGHT WAS RIGHT BEFORE TOO."
        frozenA = "FROZEN FOOD HAS A BLUE FRAME, THE COLOUR OF ICE."
        bottle = "Water Bottle"; bottleSub1 = "Water  ·  1×2  ·  0.15 kg"; bottleSub2 = "Water  ·  1×2  ·  1.15 kg"
    }
}

$menuIconDir = Join-Path $root "42\media\ui\knoxicons"
$RED = Hex "#d98a7c"; $HOVER = Hex "#23272a"; $AMBER = Hex "#ffb547"; $ICE = Hex "#80b0de"
# one of Knox's menu icons, white lines tinted as the row
function KIcon($g, $name, $x, $y, $s, $c, $a = 1) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $menuIconDir "menu_$name.png"))
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = $c.R / 255; $cm.Matrix11 = $c.G / 255; $cm.Matrix22 = $c.B / 255; $cm.Matrix33 = [float]$a; $cm.Matrix44 = 1
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $im = $g.InterpolationMode; $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$s), ([int]$s)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.InterpolationMode = $im
    $img.Dispose()
}
# the item header, as the tooltip's (news_ui Tooltip): the category plate, icon, name, line under it
function ItemHeader($g, $x, $y, $w, $cat, $icon, $name, $sub) {
    Fill $g $K[$cat] ($x + 6) ($y + 6) ($w - 12) 80; Frame $g $K.tileFrame ($x + 6) ($y + 6) ($w - 12) 80 1
    DrawIcon $g $icon ($x + 14) ($y + 14) 64 64 1 64
    Txt $g $name "title" 23 $K.bright ($x + 92) ($y + 22)
    Txt $g $sub "body" 18 $K.dim ($x + 92) ($y + 56)
}
# a chevron (sub menus, "Other"): dir "r" right, "d" down, "u" up
function Chev($g, $cx, $cy, $c, $dir = "r") {
    $pen = New-Object System.Drawing.Pen (A $c 1), 2
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    switch ($dir) {
        "r" { $g.DrawLines($pen, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([float]($cx - 3)), ([float]($cy - 6))), (New-Object System.Drawing.PointF ([float]($cx + 3)), ([float]$cy)), (New-Object System.Drawing.PointF ([float]($cx - 3)), ([float]($cy + 6))))) }
        "d" { $g.DrawLines($pen, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([float]($cx - 6)), ([float]($cy - 3))), (New-Object System.Drawing.PointF ([float]$cx), ([float]($cy + 3))), (New-Object System.Drawing.PointF ([float]($cx + 6)), ([float]($cy - 3))))) }
        "u" { $g.DrawLines($pen, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([float]($cx - 6)), ([float]($cy + 3))), (New-Object System.Drawing.PointF ([float]$cx), ([float]($cy - 3))), (New-Object System.Drawing.PointF ([float]($cx + 6)), ([float]($cy + 3))))) }
    }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
}
# Knox's item menu at x, y, w wide: rows of
#   @{k="head"; cat; icon; name; sub}     the tooltip's header
#   @{k="opt"; icon; name; hover; danger; off; reason; needs; chips (fractions); lit (chip index); sub}
#   @{k="label"; text; fold ("d"/"u")}   a group's title: small dim caps and a line
#   @{k="sep"}                            the line over the dangerous ones
# returns its height. $framed: the sand frame of an item's menu.
$RowH = 44; $PadX = 16; $MenuIcon = 24   # (not $MenuIcon: PowerShell takes it for news_ui's $icons)
function MenuPlate($g, $x, $y, $w, $rows, $framed = $true) {
    $h = 8
    foreach ($r in $rows) {
        switch ($r.k) { "head" { $h += 92 } "label" { $h += 40 } "sep" { $h += 16 } default { $h += $(if ($r.reason -or $r.needs) { 62 } else { $RowH }) } }
    }
    $h += 8
    Fill $g $K.screen ($x + 4) ($y + 6) $w $h 0.45
    Fill $g $K.window $x $y $w $h
    if ($framed) { Frame $g $K.accent $x $y $w $h 2 } else { Frame $g (Hex "#4a4f4f") $x $y $w $h 1 }
    $cy = $y + 8
    $tx = $x + $PadX + $MenuIcon + 14
    foreach ($r in $rows) {
        switch ($r.k) {
            "head" { ItemHeader $g $x ($cy - 2) $w $r.cat $r.icon $r.name $r.sub; $cy += 92 }
            "label" {
                $t = Up $r.text
                Txt $g $t "head" 15 $K.dim ($x + $PadX) ($cy + 20) 0.8
                $lx = $x + $PadX + (TextW $g $t "head" 15) + 12
                $rx = $x + $w - $PadX
                if ($r.fold) { Chev $g ($rx - 6) ($cy + 26) $K.dim $r.fold; $rx -= 26 }
                Fill $g $K.border $lx ($cy + 26) ($rx - $lx) 1
                $cy += 40
            }
            "sep" { Fill $g $K.border ($x + $PadX) ($cy + 8) ($w - 2 * $PadX) 1; $cy += 16 }
            default {
                $rh = $(if ($r.reason -or $r.needs) { 62 } else { $RowH })
                if ($r.hover) { Fill $g $HOVER ($x + 2) $cy ($w - 4) $rh; if (-not $r.off) { Fill $g $K.accent ($x + 2) $cy 2 $rh } }
                $col = $(if ($r.off) { $K.dim } elseif ($r.danger) { $RED } elseif ($r.hover) { $K.bright } else { $K.text })
                $ic = $(if ($r.off) { $K.dim } elseif ($r.danger) { $RED } elseif ($r.hover) { $K.accent } else { $K.dim })
                $alpha = $(if ($r.off) { 0.5 } else { 1 })
                if ($r.reason -or $r.needs) {
                    # two lines: the name's capitals and the line under it centred together
                    # in the row; the option's icon on the name's line, the toolbox on its own
                    $nCap = $capH * 20; $sCap = $capH * 16; $gap = 9
                    $top = $cy + ($rh - ($nCap + $gap + $sCap)) / 2
                    $sTop = $top + $nCap + $gap
                    if ($r.icon) { KIcon $g $r.icon ($x + $PadX) ($top + $nCap / 2 - $MenuIcon / 2) $MenuIcon $ic $alpha }
                    Txt $g $r.name "body" 20 $col $tx $top $(if ($r.off) { 0.75 } else { 1 })
                    if ($r.reason) { Txt $g $r.reason "body" 16 $K.dim $tx $sTop }
                    if ($r.needs) {
                        KIcon $g "needs" $tx ($sTop + $sCap / 2 - 8) 16 $K.dim 0.9
                        Txt $g $r.needs "body" 16 $K.dim ($tx + 24) $sTop
                    }
                } else {
                    if ($r.icon) { KIcon $g $r.icon ($x + $PadX) ($cy + ($RowH - $MenuIcon) / 2) $MenuIcon $ic $alpha }
                    TxtMid $g $r.name "body" 20 $col $tx $cy $RowH $(if ($r.off) { 0.75 } else { 1 })
                }
                if ($r.sub) { Chev $g ($x + $w - $PadX - 4) ($cy + $rh / 2) $(if ($r.hover) { $K.accent } else { $K.dim }) "r" }
                if ($r.chips) {
                    $s = 18; $cw = $s + 10
                    $cx = $x + $w - $PadX - $r.chips.Count * $cw
                    for ($i = 0; $i -lt $r.chips.Count; $i++) {
                        $f = $r.chips[$i]; $qx = $cx + $i * $cw + 5; $qy = $cy + ($RowH - $s) / 2
                        $lit = ($i -eq $r.lit)
                        Fill $g $K.cell $qx $qy $s $s
                        $fa = $(if ($lit) { 0.95 } else { 0.5 })
                        if ($f -ge 1) { Fill $g $K.accent $qx $qy $s $s $fa }
                        elseif ($f -ge 0.5) { Fill $g $K.accent $qx ($qy + $s / 2) $s ($s / 2) $fa }
                        else { Fill $g $K.accent $qx ($qy + $s / 2) ($s / 2) ($s / 2) $fa }
                        Frame $g $(if ($lit) { $K.accent } else { $K.tileFrame }) $qx $qy $s $s 2
                    }
                }
                $cy += $rh
            }
        }
    }
    return $h
}
# the alarm window (KnoxAlarmWindow): a wristwatch on its strap or a desk clock, the display
function AlarmWin($g, $x, $y, $title, $wrist, $hh, $mm, $on) {
    $caseW = 300; $caseH = 150; $strapH = $(if ($wrist) { 64 } else { 0 }); $keyOut = 10
    $topH = $(if ($wrist) { 0 } else { $keyOut }); $feetH = $(if ($wrist) { 0 } else { 16 })
    $w = $caseW + 2 * ($keyOut + $P) + 2 * $P
    $h = 44 + $P + 2 * $strapH + $topH + $caseH + $feetH + $P
    Win $g $x $y $w $h $title
    $case = Hex "#20241d"; $caseEdge = Hex "#3b4235"; $strap = Hex "#171916"; $strapEdge = Hex "#2c302a"; $lcd = Hex "#0f120e"; $lcdEdge = Hex "#3a4336"
    $cx0 = $x + ($w - $caseW) / 2; $cy0 = $y + 44 + $P + $strapH + $topH
    if ($wrist) {
        $sw = $caseW * 0.56; $sx = $cx0 + ($caseW - $sw) / 2
        Fill $g $strap $sx ($y + 44 + $P) $sw ($strapH + 4); Frame $g $strapEdge $sx ($y + 44 + $P) $sw ($strapH + 4) 1
        Fill $g $strap $sx ($cy0 + $caseH - 4) $sw ($strapH + 4); Frame $g $strapEdge $sx ($cy0 + $caseH - 4) $sw ($strapH + 4) 1
        for ($i = 1; $i -le 3; $i++) { Fill $g $lcd ($cx0 + $caseW / 2 - 3) ($cy0 + $caseH + $strapH * $i / 4 - 3) 6 6 }
        Fill $g $caseEdge ($cx0 + $caseW) ($cy0 + $caseH / 2 - 8) 6 16
        # the alarm key on the left side, pushed in while on
        $kw = $(if ($on) { 5 } else { $keyOut }); Fill $g $(if ($on) { $caseEdge } else { $strapEdge }) ($cx0 - $kw) ($cy0 + $caseH * 0.25) ($kw + 2) 34
        if ($on) { Fill $g $AMBER ($cx0 - $kw) ($cy0 + $caseH * 0.25) 1 34 }
    } else {
        $fw = $caseW * 0.16
        Fill $g $caseEdge ($cx0 + $fw) ($cy0 + $caseH - 2) $fw ($feetH + 2); Fill $g $caseEdge ($cx0 + $caseW - 2 * $fw) ($cy0 + $caseH - 2) $fw ($feetH + 2)
        $kh = $(if ($on) { 5 } else { $keyOut }); $kx = $cx0 + ($caseW - 70) / 2
        Fill $g $(if ($on) { $caseEdge } else { $strapEdge }) $kx ($cy0 - $kh) 70 ($kh + 2)
        if ($on) { Fill $g $AMBER $kx ($cy0 - $kh) 70 1 }
    }
    Fill $g $case $cx0 $cy0 $caseW $caseH; Frame $g $caseEdge $cx0 $cy0 $caseW $caseH 1; Frame $g $caseEdge ($cx0 + 1) ($cy0 + 1) ($caseW - 2) ($caseH - 2) 1 0.5
    $lx = $cx0 + 20; $ly = $cy0 + 20; $lw = $caseW - 40; $lh = $caseH - 40
    Fill $g $lcd $lx $ly $lw $lh; Frame $g $lcdEdge $lx $ly $lw $lh 1
    # each digit in a cell of its own, the colon in the middle of its own
    $px = 54; $cellW = (TextW $g "8" "title" $px) + 4; $colW = [math]::Floor($cellW * 0.6)
    $dw = 4 * $cellW + $colW; $dx = $lx + ($lw - $dw) / 2
    $digits = "{0:D2}{1:D2}" -f $hh, $mm
    $lit = $(if ($on) { 1 } else { 0.55 })
    $cells = @($dx, ($dx + $cellW), ($dx + 2 * $cellW + $colW), ($dx + 3 * $cellW + $colW))
    for ($i = 0; $i -lt 4; $i++) {
        TxtCentre $g "8" "title" $px $AMBER $cells[$i] $ly $cellW $lh 0.07
        TxtCentre $g $digits.Substring($i, 1) "title" $px $AMBER $cells[$i] $ly $cellW $lh $lit
    }
    TxtCentre $g ":" "title" $px $AMBER ($dx + 2 * $cellW) $ly $colW $lh $lit
    # the small arrows over and under the hours and the minutes
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    foreach ($gx in @(($dx + $cellW), ($dx + 3 * $cellW + $colW))) {
        foreach ($d in 1, -1) {
            $ay = $(if ($d -gt 0) { $ly + 10 } else { $ly + $lh - 10 })
            $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([float]($gx - 6)), ([float]($ay + 3 * $d))), (New-Object System.Drawing.PointF ([float]$gx), ([float]($ay - 3 * $d))), (New-Object System.Drawing.PointF ([float]($gx + 6)), ([float]($ay + 3 * $d))))
            $g.FillPolygon((Br $lcdEdge), $pts)
        }
    }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    Txt $g "AL" "head" 14 $AMBER ($lx + 8) ($ly + $lh - 22) $(if ($on) { 1 } else { 0.12 })
    return @($w, $h)
}

foreach ($lang in "ru", "en") {
    $s = $L18[$lang]
    Write-Host "news pictures Road to 1.0, 18.10 ($lang):"
    $cm = "ContextMenu"
    $inspect = Tr $lang "IGUI_Knox_Inspect"

    # --- the menu: the tooltip on the left, the menu it turns into on the right
    $bmp, $g = Canvas 1280 680 $K.screen
    Caption $g $s.menuTitle 24 26
    Tag $g 40 84 $s.tip $K.tileFrame $K.bright | Out-Null
    Tooltip $g 40 124 470 "food" "bread" $s.bread $s.foodSub $s.tipRows | Out-Null
    ArrowRight $g 528 230 90
    Tag $g 640 84 $s.menu $K.accent | Out-Null
    MenuPlate $g 640 124 470 @(
        @{k = "head"; cat = "food"; icon = "bread"; name = $s.bread; sub = $s.foodSub},
        @{k = "opt"; icon = "inspect"; name = $inspect},
        @{k = "opt"; icon = "eat"; name = (GTr $lang $cm "ContextMenu_Eat"); hover = $true; chips = @(0.25, 0.5, 1); lit = 2},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuMove")},
        @{k = "opt"; icon = "unpack"; name = (GTr $lang $cm "ContextMenu_Unpack")},
        @{k = "opt"; icon = "place"; name = (GTr $lang $cm "ContextMenu_PlaceItemOnGround")},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuCraft")},
        @{k = "opt"; icon = "recipes"; name = (GTr $lang $cm "ContextMenu_ShowCraftRecipesUsed")},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuOther"); fold = "d"},
        @{k = "sep"},
        @{k = "opt"; icon = "drop"; name = (GTr $lang $cm "ContextMenu_Drop"); danger = $true}
    ) | Out-Null
    $ty = CapsBlock $g $s.menuA 40 410 560 19 $null 28
    $ty = CapsBlock $g $s.menuB 40 ($ty + 12) 560 19 $null 28
    CapsBlock $g $s.menuC 40 ($ty + 12) 560 19 $K.accent 28 | Out-Null
    Save $bmp $g "r10_menu_$lang.png"

    # --- the icons: all of them, a few lit as under the mouse, the dangerous ones red
    $names = Get-ChildItem $menuIconDir -Filter "menu_*.png" | ForEach-Object { $_.BaseName.Substring(5) } | Sort-Object
    $cols = 16; $cell = 70
    $rowsN = [math]::Ceiling($names.Count / $cols)
    $bmp, $g = Canvas 1280 (150 + $rowsN * $cell + 150) $K.screen
    Caption $g $s.iconsTitle 24 26
    $gx = (1280 - $cols * $cell) / 2
    for ($i = 0; $i -lt $names.Count; $i++) {
        $n = $names[$i]; $ix = $gx + ($i % $cols) * $cell; $iy = 96 + [math]::Floor($i / $cols) * $cell
        Fill $g $K.window ($ix + 4) ($iy + 4) ($cell - 8) ($cell - 8); Frame $g $K.border ($ix + 4) ($iy + 4) ($cell - 8) ($cell - 8) 1
        $c = $(if ($n -eq "drop" -or $n -eq "pour") { $RED } elseif (@("eat", "wear", "inspect", "attach", "needs") -contains $n) { $K.accent } else { $K.dim })
        KIcon $g $n ($ix + 19) ($iy + 19) 32 $c
    }
    $ty = 96 + $rowsN * $cell + 30
    $ty = CapsBlock $g $s.iconsA 40 $ty 1200 19 $null 28
    $ty = CapsBlock $g $s.iconsB 40 ($ty + 6) 1200 19 $K.accent 28
    CapsBlock $g $s.iconsC 40 ($ty + 6) 1200 19 $null 28 | Out-Null
    Save $bmp $g "r10_icons_$lang.png"

    # --- recipes: the axe's menu (what else it takes) and the sheet's Interact sub menu
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.recTitle 24 26
    $axe = GTr $lang "ItemName" "Base.Axe"; $hammer = GTr $lang "ItemName" "Base.Hammer"
    MenuPlate $g 40 90 410 @(
        @{k = "head"; cat = "tool"; icon = "axe"; name = $axe; sub = $s.axeSub},
        @{k = "opt"; icon = "inspect"; name = $inspect},
        @{k = "opt"; icon = "attach"; name = (GTr $lang $cm "ContextMenu_Attach"); sub = $true},
        @{k = "opt"; icon = "dismantle"; name = (GTr $lang "Recipes" "DismantleLongImplement"); needs = $hammer; hover = $true},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuEquip")},
        @{k = "opt"; icon = "hands"; name = (GTr $lang $cm "ContextMenu_Equip_Two_Hands")}
    ) | Out-Null
    $sheet = GTr $lang "ItemName" "Base.Sheet"
    $sh = MenuPlate $g 462 90 388 @(
        @{k = "head"; cat = "mat"; icon = "sheet"; name = $sheet; sub = $s.sheetSub},
        @{k = "opt"; icon = "inspect"; name = $inspect},
        @{k = "opt"; icon = "hand_main"; name = (GTr $lang $cm "ContextMenu_Equip_Primary")},
        @{k = "opt"; icon = "craft"; name = (Tr $lang "IGUI_Knox_MenuInteract"); sub = $true; hover = $true},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuEquip")},
        @{k = "opt"; icon = "hand_off"; name = (GTr $lang $cm "ContextMenu_Equip_Secondary")}
    )
    MenuPlate $g 852 (90 + 8 + 92 + 2 * $RowH - 8) 400 @(
        @{k = "opt"; icon = "rope"; name = (GTr $lang "Recipes" "CraftSheetRope")},
        @{k = "opt"; icon = "rip"; name = (GTr $lang "Recipes" "RipSheets"); hover = $true},
        @{k = "opt"; icon = "bag"; name = (GTr $lang "Recipes" "MakeSheetSlingBag")}
    ) | Out-Null
    $ty = CapsBlock $g $s.recA 40 (90 + $sh + 50) 1200 19 $null 28
    CapsBlock $g $s.recB 40 ($ty + 8) 1200 19 $K.accent 28 | Out-Null
    Save $bmp $g "r10_recipes_$lang.png"

    # --- the alarm: the wristwatch (off) and the desk clock (on), side by side
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.alarmTitle 24 26
    $title = GTr $lang $cm "ContextMenu_SetAlarm"
    $a1 = AlarmWin $g 40 120 $title $true 7 30 $false
    Tag $g 40 84 ((GTr $lang "ItemName" "Base.WristWatch_Left_DigitalBlack") + "  ·  " + $s.off) $K.tileFrame $K.bright | Out-Null
    $a2 = AlarmWin $g 520 120 $title $false 18 50 $true
    Tag $g 520 84 ((GTr $lang "ItemName" "Base.AlarmClock2") + "  ·  " + $s.on) $K.accent | Out-Null
    $tx = 980; $tw = 260
    $script:C = 64
    Tile $g $tx 120 0 0 1 1 "misc" "watch" "hit"
    Tile $g ($tx + 80) 120 0 0 1 1 "misc" "alarmclock"
    $ty = CapsBlock $g $s.alarmA $tx 220 $tw 18 $null 27
    $ty = CapsBlock $g $s.alarmB $tx ($ty + 12) $tw 18 $K.accent 27
    CapsBlock $g $s.alarmC $tx ($ty + 12) $tw 18 $null 27 | Out-Null
    Save $bmp $g "r10_alarm_$lang.png"

    # --- container info: the tank, the bottle, the figures
    $bmp, $g = Canvas 1280 470 $K.screen
    Caption $g $s.fluidTitle 24 26
    $wx = 40; $wy = 90; $ww = 520; $wh = 340
    Win $g $wx $wy $ww $wh (GTr $lang "Fluids" "Fluid_Info_Panel")
    $tkx = $wx + $P; $tky = $wy + 44 + $P; $tkw = 70; $tkh = 260
    Fill $g $K.cell $tkx $tky $tkw $tkh
    $lvl = [int]($tkh * 0.6); Fill $g (Hex "#6fa3d8") $tkx ($tky + $tkh - $lvl) $tkw $lvl 0.85
    for ($i = 1; $i -le 3; $i++) { $my = $tky + $tkh - [int]($tkh * $i / 4); Fill $g $K.tileFrame $tkx $my 18 1; Fill $g $K.tileFrame ($tkx + $tkw - 18) $my 18 1 }
    Frame $g $K.tileFrame $tkx $tky $tkw $tkh 2
    $ix = $tkx + $tkw + $P; $iw = $ww - ($ix - $wx) - $P
    $script:C = 64
    Fill $g $K.food $ix $tky 72 72; Frame $g $K.tileFrame $ix $tky 72 72 2; DrawIcon $g "bottle" $ix $tky 72 72 1 58
    TxtMid $g $s.bottle "body" 21 $K.bright ($ix + 88) $tky 72
    $ry = $tky + 72 + $P
    Fill $g (Hex "#6fa3d8") $ix ($ry + 5) 12 12; Txt $g $s.water "body" 20 $K.text ($ix + 20) $ry
    $ry += 40; Fill $g $K.border $ix $ry $iw 1; $ry += 14
    foreach ($row in @(@((GTr $lang "Fluids" "Fluid_Capacity"), ("1.0 " + $s.litre)), @((Tr $lang "IGUI_Knox_FluidHeld"), ("0.6 " + $s.litre)), @((Tr $lang "IGUI_Knox_FluidFree"), ("0.4 " + $s.litre)))) {
        Txt $g $row[0] "body" 20 $K.dim $ix $ry
        Txt $g $row[1] "body" 20 $K.bright ($ix + $iw - (TextW $g $row[1] "body" 20)) $ry
        $ry += 34
    }
    $tx = $wx + $ww + 50; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.fluidA $tx 150 $tw 19 $null 28
    CapsBlock $g $s.fluidB $tx ($ty + 14) $tw 19 $K.accent 28 | Out-Null
    Save $bmp $g "r10_fluid_$lang.png"

    # --- the weight: the bottle's header before and now; frozen tiles in their blue frame
    $bmp, $g = Canvas 1280 470 $K.screen
    Caption $g $s.weightTitle 24 26
    Tag $g 40 84 $s.before $K.tileFrame $K.bright | Out-Null
    Fill $g $K.window 40 124 520 98; Frame $g $K.tileFrame 40 124 520 98 1
    ItemHeader $g 40 124 520 "food" "bottle" $s.bottle $s.bottleSub1
    ArrowRight $g 590 173 90
    Tag $g 710 84 $s.now $K.accent | Out-Null
    Fill $g $K.window 710 124 520 98; Frame $g $K.tileFrame 710 124 520 98 1
    ItemHeader $g 710 124 520 "food" "bottle" $s.bottle $s.bottleSub2
    $ty = CapsBlock $g $s.weightA 40 260 1200 19 $null 28
    $ty = CapsBlock $g $s.weightB 40 ($ty + 6) 1200 19 $K.dim 28
    # frozen food: the tiles blue, their frame the ice's own colour
    $script:C = 64
    $fy = $ty + 30
    Grid $g 40 $fy 5 1
    foreach ($i in 0..4) {
        $icon = @("steak", "sausage", "tvdinner", "cucumber", "apple")[$i]
        $tx0 = 40 + $i * 64 + 1; $ty0 = $fy + 1
        Fill $g (Hex "#4a8fd1") $tx0 $ty0 63 63 0.55
        Frame $g $ICE $tx0 $ty0 63 63 2
        DrawIcon $g $icon $tx0 $ty0 63 63 1 54
    }
    CapsBlock $g $s.frozenA 400 ($fy + 18) 840 19 $K.accent 28 | Out-Null
    Save $bmp $g "r10_weight_$lang.png"
}

# ======================================================================================
# 18.10.2026, later: the car's dashboard (KnoxDashboard) and its radio (KnoxCarRadio).
# The panel is put together from its own pictures (media\ui\knoxdash, make_dash.ps1),
# as the game draws it, at twice its mockup size.

$L18d = @{
    ru = @{
        dashTitle = "ПРИБОРНАЯ ПАНЕЛЬ МАШИНЫ"
        dashA = "ВНИЗУ ПОСЕРЕДИНЕ, КАК В ИГРЕ, НО НИЗКАЯ И ШИРОКАЯ: ЛАМПОЧКИ СЕТКОЙ СЛЕВА, ТАХОМЕТР, СПИДОМЕТР, ТОПЛИВО И ЗАМОК В РЯД."
        dashB = "СТРЕЛКИ НА ПРУЖИНАХ. ЗАЖИГАНИЕ ВКЛЮЧИЛИ - СТРЕЛКИ ДОХОДЯТ ДО КОНЦА, ЛАМПОЧКИ ЗАГОРАЮТСЯ ПО ОЧЕРЕДИ."
        dashC = "КЛЮЧ ВХОДИТ В ЗАМОК И ПОВОРАЧИВАЕТСЯ. БЕЗ КЛЮЧА - ПРОВОДА, КОТОРЫЕ ИСКРЯТ ПРИ ЗАПУСКЕ."
        radioTitle = "РАДИО В МАШИНЕ"
        radioA = "НАВЕДИТЕ МЫШЬ НА ЛАМПОЧКУ РАДИО - ПОЯВИТСЯ ТА ЖЕ КАРТОЧКА, ЧТО У РАДИО В ЛАГЕРЕ."
        radioB = "«ЭФИР» - САМА МАГНИТОЛА: СТАНЦИИ СПИСКОМ, ГРОМКОСТЬ - ЕЁ РУЧКА."
        radioC = "«СВОЯ» - ВАША МУЗЫКА ИЗ ДИНАМИКА МАШИНЫ. НУЖНЫ ПИТАНИЕ И ВКЛЮЧЁННАЯ МАГНИТОЛА, ЗОМБИ ЕЁ СЛЫШАТ."
        stations = @(@("89.4", "Knox Country"), @("93.2", "LBMW - Kentucky Radio"), @("98.0", "NNR Radio"), @("99.6", "Knox County Radio"), @("101.2", "KnoxTalk Radio"))
    }
    en = @{
        dashTitle = "THE CAR'S DASHBOARD"
        dashA = "AT THE BOTTOM IN THE MIDDLE, AS IN THE GAME, BUT LOW AND WIDE: THE LAMPS IN A GRID ON THE LEFT, THE TACHOMETER, SPEEDOMETER, FUEL AND IGNITION IN A ROW."
        dashB = "THE NEEDLES SWING ON SPRINGS. THE IGNITION COMES ON - THE NEEDLES SWEEP TO THE END, THE LAMPS LIGHT ONE AFTER ANOTHER."
        dashC = "THE KEY GOES INTO THE LOCK AND TURNS. NO KEY - WIRES THAT SPARK AS THE ENGINE CRANKS."
        radioTitle = "THE CAR'S RADIO"
        radioA = "HOVER THE RADIO'S LAMP - THE SAME CARD AS THE CAMP RADIO'S COMES UP."
        radioB = "BROADCAST - THE CAR'S OWN SET: ITS STATIONS IN A LIST, THE VOLUME IS ITS KNOB."
        radioC = "MINE - YOUR MUSIC FROM THE CAR'S SPEAKER. IT NEEDS POWER AND THE SET ON; ZOMBIES HEAR IT."
        stations = @(@("89.4", "Knox Country"), @("93.2", "LBMW - Kentucky Radio"), @("98.0", "NNR Radio"), @("99.6", "Knox County Radio"), @("101.2", "KnoxTalk Radio"))
    }
}

$dashDir = Join-Path $root "42\media\ui\knoxdash"
$NEEDLE = Hex "#ffb547"
# one of the dashboard's white pictures, tinted, in x, y, w, h (turned by deg round its middle)
function DashTex($g, $name, $x, $y, $w, $h, $c, $a = 1, $deg = 0) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $dashDir "$name.png"))
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = $c.R / 255; $cm.Matrix11 = $c.G / 255; $cm.Matrix22 = $c.B / 255; $cm.Matrix33 = [float]$a; $cm.Matrix44 = 1
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $im = $g.InterpolationMode; $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $st = $g.Save()
    $g.TranslateTransform([float]($x + $w / 2), [float]($y + $h / 2)); $g.RotateTransform([float]$deg)
    # (fractions of a pixel: the overload with three corners - the one with a
    # rectangle and image attributes takes whole pixels only)
    $dst = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([float](-$w / 2)), ([float](-$h / 2))),
        (New-Object System.Drawing.PointF ([float]($w / 2)), ([float](-$h / 2))), (New-Object System.Drawing.PointF ([float](-$w / 2)), ([float]($h / 2))))
    $src = New-Object System.Drawing.RectangleF 0, 0, $img.Width, $img.Height
    $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.Restore($st)
    $g.InterpolationMode = $im
    $img.Dispose()
}
function DPt($cx, $cy, $r, $deg) { $a = $deg * [math]::PI / 180; return @(($cx + $r * [math]::Cos($a)), ($cy - $r * [math]::Sin($a))) }
# a needle: tapered, with its glow
function DNeedle($g, $cx, $cy, $deg, $len, $tail, $w) {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $t = DPt $cx $cy $len $deg; $b = DPt $cx $cy (-$tail) $deg
    $a = $deg * [math]::PI / 180; $nx = [math]::Sin($a); $ny = [math]::Cos($a)
    foreach ($gl in @(@(4.0, 0.08), @(2.6, 0.12), @(1.6, 0.18))) {
        $pen = New-Object System.Drawing.Pen (A $NEEDLE $gl[1]), ([float]($w * $gl[0])); $pen.StartCap = "Round"; $pen.EndCap = "Round"
        $g.DrawLine($pen, [float]$b[0], [float]$b[1], [float]$t[0], [float]$t[1])
    }
    $pts = @(
        (New-Object System.Drawing.PointF ([float]($t[0] + $nx * $w * 0.13)), ([float]($t[1] + $ny * $w * 0.13))),
        (New-Object System.Drawing.PointF ([float]($t[0] - $nx * $w * 0.13)), ([float]($t[1] - $ny * $w * 0.13))),
        (New-Object System.Drawing.PointF ([float]($b[0] - $nx * $w * 0.5)), ([float]($b[1] - $ny * $w * 0.5))),
        (New-Object System.Drawing.PointF ([float]($b[0] + $nx * $w * 0.5)), ([float]($b[1] + $ny * $w * 0.5))))
    $g.FillPolygon((Br $NEEDLE), [System.Drawing.PointF[]]$pts)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
}
function DHub($g, $cx, $cy, $r) {
    DashTex $g "hub" ($cx - $r - 2) ($cy - $r - 2) (2 * $r + 4) (2 * $r + 4) $K.tileEdge
    DashTex $g "hub" ($cx - $r) ($cy - $r) (2 * $r) (2 * $r) $K.header
}
# the panel, all lit, a car on the move: kk pixels a mockup unit
# (its scale is $kk: PowerShell names ignore case, a $k hid the palette $K)
function DashPanel($g, $x0, $y0, $kk, $lang) {
    function U($v) { $v * $kk }
    $W = U 600; $H = U 150
    Fill $g $K.window $x0 $y0 $W $H 0.97
    Frame $g $K.accent $x0 $y0 $W $H ([math]::Round((U 3)))
    $pi = U 6
    Fill $g $K.header ($x0 + $pi) ($y0 + $pi) ($W - 2 * $pi) ($H - 2 * $pi)
    Frame $g $K.tileEdge ($x0 + $pi) ($y0 + $pi) ($W - 2 * $pi) ($H - 2 * $pi) 1
    $scale = $K.dim
    # the dials: face, edge, marks, red zone, numbers
    foreach ($d in @(@("tach", 186, 75, 58), @("speed", 322, 75, 66), @("fuel", 448, 75, 48))) {
        $r = U $d[3]; $x = $x0 + (U $d[1]) - $r; $y = $y0 + (U $d[2]) - $r
        DashTex $g "disc" $x $y (2 * $r) (2 * $r) $K.cell
        DashTex $g "rim" $x $y (2 * $r) (2 * $r) $K.tileEdge
        DashTex $g "$($d[0])_ticks" $x $y (2 * $r) (2 * $r) $scale
        DashTex $g "$($d[0])_red" $x $y (2 * $r) (2 * $r) $K.bad
        DashTex $g "$($d[0])_nums" $x $y (2 * $r) (2 * $r) $scale
    }
    $tcx = $x0 + (U 186); $scx = $x0 + (U 322); $fcx = $x0 + (U 448); $cy = $y0 + (U 75)
    # the speed's sand arc to 62 (the game's fake speed), the cruise mark at 60
    $sp = 62 / 120
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $ar = U 58.8
    $pen = New-Object System.Drawing.Pen (A $K.accent 1), ([float](U 3))
    $g.DrawArc($pen, [float]($scx - $ar), [float]($cy - $ar), [float](2 * $ar), [float](2 * $ar), [float](-210), [float](240 * $sp))
    $cd = 210 - 240 * 60 / 120
    $p0 = DPt $scx $cy (U 61.8) $cd; $p1 = DPt $scx $cy (U 67.8) $cd
    $g.DrawLine((New-Object System.Drawing.Pen (A $K.good 1), ([float](U 3))), [float]$p0[0], [float]$p0[1], [float]$p1[0], [float]$p1[1])
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    # captions and figures
    TxtCentre $g (Tr $lang "IGUI_Knox_Dash_Rpm1000") "head" ([math]::Round((U 10.5))) $scale ($tcx - 60) ($cy + (U 32) - 10) 120 20
    TxtCentre $g "62" "title" ([math]::Round((U 22))) $NEEDLE ($scx - 60) ($cy + (U 20) - 20) 120 40
    $gx = $scx - (U 16); $gy = $cy + (U 35); $gw = U 32; $gh = U 20
    Fill $g $K.cell $gx $gy $gw $gh; Frame $g $K.accent $gx $gy $gw $gh 2
    TxtCentre $g "3" "title" ([math]::Round((U 14))) $NEEDLE $gx $gy $gw $gh
    # the fuel: the pump with the filler's arrow, a third left
    $is = U 22; $pcy = $cy + (U 22); $mid = $fcx + (U 4.25)
    DashTex $g "lamp_fuel" ($mid - $is / 2) ($pcy - $is / 2) $is $is $scale
    $tx = $mid - ($is * 25 / 40 / 2) - (U 3.5)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $tri = @((New-Object System.Drawing.PointF ([float]($tx - (U 5))), ([float]$pcy)), (New-Object System.Drawing.PointF ([float]$tx), ([float]($pcy - (U 3.5)))), (New-Object System.Drawing.PointF ([float]$tx), ([float]($pcy + (U 3.5)))))
    $g.FillPolygon((Br $K.accent), [System.Drawing.PointF[]]$tri)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    # the needles: 2400 rpm, 62, a third of the tank
    DNeedle $g $tcx $cy (210 - 240 * 2400 / 7000) (U 43) (U 10) (U 2.6); DHub $g $tcx $cy (U 5)
    DNeedle $g $scx $cy (210 - 240 * $sp) (U 53) (U 11) (U 3); DHub $g $scx $cy (U 6)
    DNeedle $g $fcx $cy (150 - 120 * 0.33) (U 33) (U 8) (U 2.4); DHub $g $fcx $cy (U 4.5)
    # the ignition: the lock, its marks, the key at ON
    $icx = $x0 + (U 548); $icy = $y0 + (U 68); $ir = U 30; $inr = U 22
    DashTex $g "disc" ($icx - $ir) ($icy - $ir) (2 * $ir) (2 * $ir) $K.cell
    DashTex $g "rim" ($icx - $ir) ($icy - $ir) (2 * $ir) (2 * $ir) $K.tileEdge
    DashTex $g "disc" ($icx - $inr) ($icy - $inr) (2 * $inr) (2 * $inr) $K.header
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    foreach ($m in @(@(-35, $K.dim), @(35, $NEEDLE), @(68, $K.tileEdge))) {
        $q0 = DPt $icx $icy (U 25) (90 - $m[0]); $q1 = DPt $icx $icy (U 29) (90 - $m[0])
        $g.DrawLine((New-Object System.Drawing.Pen (A $m[1] 1), ([float](U 2))), [float]$q0[0], [float]$q0[1], [float]$q1[0], [float]$q1[1])
    }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $ks = U 88; $blade = Mix $K.accent $K.ink 0.22
    DashTex $g "key_shadow" ($icx - $ks / 2 + 3) ($icy - $ks / 2 + 3) $ks $ks (Hex "#000000") 0.5 35
    DashTex $g "key_blade" ($icx - $ks / 2) ($icy - $ks / 2) $ks $ks $blade 1 35
    DashTex $g "key_head" ($icx - $ks / 2) ($icy - $ks / 2) $ks $ks $K.accent 1 35
    DashTex $g "key_groove" ($icx - $ks / 2) ($icy - $ks / 2) $ks $ks $blade 1 35
    DashTex $g "key_edge" ($icx - $ks / 2) ($icy - $ks / 2) $ks $ks $K.bright 0.7 35
    TxtCentre $g (Tr $lang "IGUI_Knox_Dash_Ignition") "head" ([math]::Round((U 10.5))) $scale ($icx - 80) ($icy + (U 47) - 10) 160 20
    # the lamps: engine, battery, lights / doors, heater, radio (a note: own music) / cruise, its 60, trunk
    $lamps = @(@("engine", $K.good), @("battery", $K.good), @("lights", $K.good), @("doors", $K.good), @("heater", $null), @("note", $K.good), @("cruise", $K.good), @("60", $K.good), @("trunk", $null))
    for ($i = 0; $i -lt 9; $i++) {
        $col = $i % 3; $row = [math]::Floor($i / 3)
        $lx = $x0 + (U (18 + $col * 34)); $ly = $y0 + (U (24 + $row * 38)); $ls = U 26
        $c = $lamps[$i][1]
        Fill $g $K.cell $lx $ly $ls $ls
        if ($c) { Fill $g $c ($lx + 2) ($ly + 2) ($ls - 4) ($ls - 4) 0.14 }
        Frame $g $(if ($c) { Mix $K.tileEdge $c 0.85 } else { $K.tileEdge }) $lx $ly $ls $ls 2
        if ($lamps[$i][0] -eq "60") {
            TxtCentre $g "60" "title" ([math]::Round((U 12))) $K.good $lx $ly $ls $ls
        } else {
            $is2 = [math]::Floor($ls * 0.76)
            DashTex $g "lamp_$($lamps[$i][0])" ($lx + ($ls - $is2) / 2) ($ly + ($ls - $is2) / 2) $is2 $is2 $(if ($c) { $c } else { $K.dim }) $(if ($c) { 1 } else { 0.45 })
        }
    }
}

# the radio's card in the car (KnoxRadioCard, MM.ctx = "car"): the broadcast, a station on
function CarCard($g, $x, $y, $w, $lang, $s) {
    $f = 4; $p = 14
    $h = 502   # (the rows below: head 90, seek 48, buttons 60, volume 38, five stations 184, chips 60, frame and pads)
    Fill $g $K.window $x $y $w $h 0.97
    Frame $g $K.accent $x $y $w $h $f
    $ix = $x + $f + $p; $iw = $w - 2 * ($f + $p); $yy = $y + $f + $p
    # head: the set in its square, the station, the theme and which of how many
    $ps = 76
    Fill $g $K.cell $ix $yy $ps $ps; Frame $g $K.tileFrame $ix $yy $ps $ps 2
    $mus = Join-Path $root "42\media\ui"
    function MIcon($name, $x1, $y1, $sz, $c) {
        $img = [System.Drawing.Image]::FromFile((Join-Path $mus "knox_music_$name.png"))
        $cm = New-Object System.Drawing.Imaging.ColorMatrix
        $cm.Matrix00 = $c.R / 255; $cm.Matrix11 = $c.G / 255; $cm.Matrix22 = $c.B / 255; $cm.Matrix33 = 1; $cm.Matrix44 = 1
        $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]$x1), ([int]$y1), ([int]$sz), ([int]$sz)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        $img.Dispose()
    }
    MIcon "radio" ($ix + 14) ($yy + 14) 48 $K.accent
    Txt $g ("NNR Radio   98.0") "title" 24 $K.bright ($ix + $ps + 14) ($yy + 12)
    Txt $g ((Tr $lang "IGUI_KnoxMusic_car") + "   3 / 5") "head" 15 $K.accent ($ix + $ps + 14) ($yy + 50)
    $yy += $ps + $p
    # the seek line (no seeking on the air) and its times
    Fill $g $K.cell $ix ($yy + 6) $iw 6
    Txt $g "-:--" "head" 14 $K.dim $ix ($yy + 22); Txt $g "-:--" "head" 14 $K.dim ($ix + $iw - (TextW $g "-:--" "head" 14)) ($yy + 22)
    $yy += 48
    # the buttons: repeat, shuffle (off on the air), back, pause (the set on), next, the speaker's sound
    $bs = 46; $gap = ($iw - 6 * $bs) / 5
    $names = @("repeat", "shuffle", "prev", "pause", "next", "radio")
    for ($i = 0; $i -lt 6; $i++) {
        $bx = $ix + $i * ($bs + $gap)
        $off = $i -lt 2 -or $i -eq 5
        Fill $g $K.cell $bx $yy $bs $bs; Frame $g $K.tileFrame $bx $yy $bs $bs 2
        MIcon $names[$i] ($bx + 11) ($yy + 11) 24 $(if ($off) { $K.tileEdge } else { $K.text })
    }
    $yy += $bs + $p
    # the volume: the set's knob
    MIcon "vol2" ($ix + 11) ($yy) 24 $K.text
    $vx = $ix + $bs + $gap; $vw = $iw - ($vx - $ix) - 50
    Fill $g $K.cell $vx ($yy + 9) $vw 6; Fill $g $K.accent $vx ($yy + 9) ([int]($vw * 0.6)) 6
    Fill $g $K.bright ($vx + [int]($vw * 0.6) - 3) ($yy + 5) 6 14
    Txt $g "60%" "head" 15 $K.dim ($ix + $iw - (TextW $g "60%" "head" 15)) ($yy + 4)
    $yy += 24 + $p
    # the stations: the one tuned in marked, one under the mouse
    $rh = 34
    for ($i = 0; $i -lt $s.stations.Count; $i++) {
        $st2 = $s.stations[$i]; $ry = $yy + $i * $rh
        $cur = $i -eq 2; $hot = $i -eq 3
        Fill $g $(if ($cur -or $hot) { $K.header } else { $K.cell }) $ix $ry $iw ($rh - 2)
        if ($cur) { Fill $g $K.accent $ix $ry 3 ($rh - 2) }
        if ($hot) { Frame $g $K.accent $ix $ry $iw ($rh - 2) 1 }
        TxtMid $g ("0" + ($i + 1)) "head" 14 $(if ($cur) { $K.accent } else { $K.dim }) ($ix + 10) $ry ($rh - 2)
        TxtMid $g ($st2[0] + "   " + $st2[1]) "body" 17 $(if ($cur) { $K.bright } elseif ($hot) { $K.accent } else { $K.text }) ($ix + 40) $ry ($rh - 2)
    }
    $yy += $s.stations.Count * $rh + $p
    # the chips: the broadcast chosen, own music
    $cw = 2 * $bs + $gap
    Fill $g $K.accent $ix $yy $cw $bs
    TxtCentre $g (Up (Tr $lang "IGUI_KnoxMusic_Chip_car")) "head" 15 $K.ink $ix $yy $cw $bs
    $cx2 = $ix + $cw + $gap
    Fill $g $K.cell $cx2 $yy $cw $bs; Frame $g $K.tileFrame $cx2 $yy $cw $bs 2
    TxtCentre $g (Up (Tr $lang "IGUI_KnoxMusic_Chip_mine")) "head" 15 $K.text $cx2 $yy $cw $bs
    $fx = $ix + $iw - $bs
    Fill $g $K.cell $fx $yy $bs $bs; Frame $g $K.tileFrame $fx $yy $bs $bs 2
    MIcon "folder" ($fx + 11) ($yy + 11) 24 $K.text
    return ($yy + $bs + $p + $f) - $y
}

foreach ($lang in "ru", "en") {
    $s = $L18d[$lang]
    # --- the dashboard: the whole panel, twice its size, the words under it
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.dashTitle 24 26
    DashPanel $g 40 84 2 $lang
    $ty = CapsBlock $g $s.dashA 40 410 1200 19 $null 28
    $ty = CapsBlock $g $s.dashB 40 ($ty + 6) 1200 19 $K.accent 28
    CapsBlock $g $s.dashC 40 ($ty + 6) 1200 19 $null 28 | Out-Null
    Save $bmp $g "r10_dash_$lang.png"

    # --- the car's radio: its card, the words beside it
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.radioTitle 24 26
    CarCard $g 40 84 460 $lang $s | Out-Null
    $tx = 560; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.radioA $tx 150 $tw 19 $null 28
    $ty = CapsBlock $g $s.radioB $tx ($ty + 14) $tw 19 $K.accent 28
    CapsBlock $g $s.radioC $tx ($ty + 14) $tw 19 $null 28 | Out-Null
    Save $bmp $g "r10_carradio_$lang.png"
}
