# Pictures of the 0.9.8.7 news post (By Ear: things sound like what they are made of,
# all on one level; the new sliders; magazines apart), by the approved news rules (see
# make_news_096.ps1 and news_ui.ps1): pieces of the Knox screen itself, the game's own
# icons, captions in capitals, a banner with no words, a picture per language.
#   42\media\knox\newsই_<name>_<ru|en>.png   banner, art, sound, settings, mags
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_0987.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        soundTitle = "КАЖДАЯ ВЕЩЬ ЗВУЧИТ СВОИМ МАТЕРИАЛОМ"
        before = "БЫЛО"; now = "СТАЛО"
        mats = @("МЯГКАЯ БУМАГА", "ЖЕСТЬ", "КНИГА", "СТЕКЛО", "ПАТРОНЫ")
        soundA = "ВЗЯЛИ, ПОЛОЖИЛИ, ПОВЕРНУЛИ, НАШЛИ ПРИ ОБЫСКЕ - СЛЫШНО, ИЗ ЧЕГО ВЕЩЬ. ТУАЛЕТНАЯ БУМАГА БОЛЬШЕ НЕ ХЛОПАЕТ КАК КНИГА."
        soundB = "ВСЕ ЗВУКИ ИЗМЕРЕНЫ И ВЫРОВНЕНЫ: НИЧТО НЕ ШЕПЧЕТ И НЕ ГРЕМИТ НА ФОНЕ ОСТАЛЬНОГО."
        setTitle = "ДВА НОВЫХ ПОЛЗУНКА"
        newTag = "НОВОЕ"
        setA = "ЗВУКИ ОБЫСКА: РУКИ ШАРЯТ В ЯЩИКЕ, КАЖДАЯ НАЙДЕННАЯ ВЕЩЬ ЗВУЧИТ."
        setB = "ЗВУКИ ИНТЕРФЕЙСА: ВЕЩЬ ВЗЯЛИ, ПОЛОЖИЛИ, ПОВЕРНУЛИ; СУМКА ОТКРЫЛАСЬ СВОЕЙ ЗАСТЁЖКОЙ."
        setC = "0% - ТИШИНА, 200% - ВДВОЕ ГРОМЧЕ. НАСТРОЙКИ KNOX, ВКЛАДКА «ИГРА»."
        magTitle = "МАГАЗИНЫ БОЛЬШЕ НЕ СМЕШИВАЮТСЯ"
        full = "ПОЛНЫЕ"; empty = "ПУСТОЙ"; mixed = "ВПЕРЕМЕШКУ"
        magA = "ПОЛНЫЕ И ПУСТЫЕ МАГАЗИНЫ ЛЕЖАТ РАЗНЫМИ ПЛИТКАМИ: КАЖДЫЙ МОЖНО ЗАРЯДИТЬ, НЕ РАЗБИРАЯ СТОПКУ."
        artTitle = "НА СЛУХ"
    }
    en = @{
        soundTitle = "EVERY THING SOUNDS LIKE WHAT IT IS MADE OF"
        before = "BEFORE"; now = "NOW"
        mats = @("SOFT PAPER", "TIN", "BOOK", "GLASS", "AMMO")
        soundA = "PICKED UP, PUT DOWN, TURNED, FOUND IN A SEARCH - YOU HEAR WHAT IT IS MADE OF. TOILET PAPER NO LONGER SLAMS LIKE A BOOK."
        soundB = "EVERY SOUND MEASURED AND LEVELLED: NOTHING WHISPERS OR BOOMS NEXT TO THE REST."
        setTitle = "TWO NEW SLIDERS"
        newTag = "NEW"
        setA = "SEARCH SOUNDS: HANDS RUMMAGE THROUGH THE BOX, EVERY THING FOUND MAKES ITS SOUND."
        setB = "INTERFACE SOUNDS: A THING PICKED UP, PUT DOWN, TURNED; A BAG OPENS WITH ITS OWN ZIP."
        setC = "0% - SILENCE, 200% - TWICE AS LOUD. KNOX SETTINGS, THE GAME TAB."
        magTitle = "MAGAZINES NO LONGER MIX"
        full = "FULL"; empty = "EMPTY"; mixed = "MIXED"
        magA = "FULL AND EMPTY MAGAZINES ARE TILES OF THEIR OWN: EACH CAN BE LOADED WITHOUT TAKING THE STACK APART."
        artTitle = "BY EAR"
    }
}

# the things, their category colours and the game's names for them
$things = @(
    @("misc", "toiletpaper", "Base.ToiletPaper"),
    @("food", "beans", "Base.TinnedBeans"),
    @("info", "book_skill", "Base.BookCarpentry1"),
    @("food", "whiskey", "Base.Whiskey"),
    @("wpn", "ammobox9", "Base.Bullets9mmBox")
)
# how loud each was before (game events raw, -26..-54 dB) and now: segments of 12
$beforeLit = @(4, 6, 10, 8, 11)   # measured: soft paper -46 dB, tin -42, book -30, glass -36, rounds' own loud sound (2.5 dB a segment)
$NOW_LIT = 8

# a level meter: 12 segments, the first `lit` in sand (or dim for the old levels)
function Meter($g, $x, $y, $lit, $c, $seg = 16, $gap = 4, $h = 22) {
    for ($i = 0; $i -lt 12; $i++) {
        $sx = $x + $i * ($seg + $gap)
        if ($i -lt $lit) { Fill $g $c $sx $y $seg $h } else { Fill $g $K.line $sx $y $seg $h }
    }
}

# rows of things: the tile, its material in caps, the game's name, the meters
function ThingRows($g, $x, $y, $lang, $rowH, $withBefore, $meterX, $nowX) {
    for ($i = 0; $i -lt $things.Count; $i++) {
        $t = $things[$i]; $ry = $y + $i * $rowH
        Grid $g $x $ry 1 1
        Tile $g $x $ry 0 0 1 1 $t[0] $t[1]
        $cl = $script:C
        Txt $g $L[$lang].mats[$i] "head" 19 $K.bright ($x + $cl + 20) ($ry + 10)
        Txt $g (GTr $lang "ItemName" $t[2]) "body" 18 $K.dim ($x + $cl + 20) ($ry + 38)
        $my = $ry + [math]::Floor(($cl - 22) / 2)
        if ($withBefore) { Meter $g $meterX $my $beforeLit[$i] $K.dim }
        Meter $g $nowX $my $NOW_LIT $K.accent
    }
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.8.7 ($lang):"

    # --- sounds by material, before and now
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.soundTitle 24 26
    $script:C = 64
    $mx = 560; $nx = 860
    Tag $g $mx 84 $s.before $K.tileFrame $K.bright | Out-Null
    Tag $g $nx 84 $s.now $K.accent | Out-Null
    ThingRows $g 40 128 $lang 86 $true $mx $nx
    $ty = CapsBlock $g $s.soundA 40 572 1200 19 $null 28
    CapsBlock $g $s.soundB 40 ($ty + 8) 1200 19 $K.accent 28 | Out-Null
    Save $bmp $g "u0987_sound_$lang.png"

    # --- the settings' Game tab with the two new sliders
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.setTitle 24 26
    $wx = 40; $wy = 90; $ww = 720; $wh = 360
    Win $g $wx $wy $ww $wh (Tr $lang "IGUI_Knox_Settings")
    $pages = @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_game"),
               (Tr $lang "IGUI_Knox_Page_order"), (Tr $lang "IGUI_Knox_Page_controls"))
    $y = Tabs $g $wx ($wy + 44) $ww $pages 2
    $sx = $wx + 2 * $P; $sw = $ww - 4 * $P
    $y += 40
    Slider $g $sx $y $sw (Tr $lang "IGUI_Knox_search_time") 0.2 "100%" 300
    $y += 70
    Slider $g $sx $y $sw (Tr $lang "IGUI_Knox_search_sound") 0.5 "100%" 300
    Tag $g ($wx + $ww + 16) ($y + 2) $s.newTag $K.accent | Out-Null
    $y += 70
    Slider $g $sx $y $sw (Tr $lang "IGUI_Knox_ui_sound") 0.5 "100%" 300
    Tag $g ($wx + $ww + 16) ($y + 2) $s.newTag $K.accent | Out-Null
    $tx = 40; $ty = $wy + $wh + 40
    $ty = CapsBlock $g $s.setA $tx $ty 1200 19 $null 28
    $ty = CapsBlock $g $s.setB $tx ($ty + 8) 1200 19 $null 28
    CapsBlock $g $s.setC $tx ($ty + 8) 1200 19 $K.accent 28 | Out-Null
    Save $bmp $g "u0987_settings_$lang.png"

    # --- magazines: one mixed stack before, full and empty apart now
    $bmp, $g = Canvas 1280 560 $K.screen
    Caption $g $s.magTitle 24 26
    $script:C = 72
    $gx1 = 60; $gx2 = 600; $gy = 150
    Tag $g $gx1 96 $s.before $K.tileFrame $K.bright | Out-Null
    Grid $g $gx1 $gy 4 2
    Tile $g $gx1 $gy 0 0 1 1 "wpn" "clip9" "" "3"
    Txt $g $s.mixed "head" 17 $K.dim $gx1 ($gy + 2 * $script:C + 14)
    ArrowRight $g ($gx1 + 4 * $script:C + 40) ($gy + $script:C) 120
    Tag $g $gx2 96 $s.now $K.accent | Out-Null
    Grid $g $gx2 $gy 4 2
    Tile $g $gx2 $gy 0 0 1 1 "wpn" "clip9" "" "2"
    Tile $g $gx2 $gy 1 0 1 1 "wpn" "clip9" "hit"
    Txt $g $s.full "head" 17 $K.bright $gx2 ($gy + 2 * $script:C + 14)
    Txt $g $s.empty "head" 17 $K.accent ($gx2 + $script:C) ($gy + 2 * $script:C + 14)
    $script:C = 64
    CapsBlock $g $s.magA 60 420 1160 19 $null 28 | Out-Null
    Save $bmp $g "u0987_mags_$lang.png"

    # --- art: the things, big, all at one level, on the frame's colour
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 64 56 30 $K.accent
    $script:C = 96
    ThingRows $g 70 150 $lang 168 $false 0 620
    $script:C = 64
    Save $bmp $g "u0987_art_$lang.png"

    # --- banner, no words: a grid in the dark with the things, darkest on the left
    BannerPattern "u0987_banner_$lang.png" @(
        @(10, 1, 1, 1, "misc", "toiletpaper", ""), @(11, 2, 1, 1, "food", "beans", "hit"),
        @(12, 0, 1, 1, "info", "book", ""), @(13, 1, 1, 1, "food", "whiskey", ""),
        @(14, 2, 1, 1, "wpn", "ammobox9", ""), @(15, 0, 1, 1, "wpn", "clip9", ""),
        @(12, 3, 1, 1, "info", "magazine", ""), @(16, 2, 1, 1, "mat", "nails", ""))
}
