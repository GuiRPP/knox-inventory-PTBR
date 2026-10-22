# Pictures of the 0.8.1 news post (the new game's screens: mode, spawn, sandbox,
# character, loading screen, the hero's menu), made anew in 2026-10 by the approved
# news rules (see make_news_096.ps1 and news_ui.ps1): the game's own mode pictures,
# trait and occupation icons and town maps, the game's and the mod's own words.
#   42\media\knox\news\u081_<name>_<ru|en>.png
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_081.ps1

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "news_ui.ps1")
$gameUi = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\ui"
$modes = Join-Path $PSScriptRoot "art\gameicons\modes"
$traitDir = Join-Path $PSScriptRoot "art\gameicons\traits"

# the new game's steps on top: done ones bright, the current in sand, the rest dim
function Steps($g, $x, $y, $names, $at) {
    $tx = $x
    for ($i = 0; $i -lt $names.Count; $i++) {
        $n = Up $names[$i]
        $c = $(if ($i -eq $at) { $K.accent } elseif ($i -lt $at) { $K.bright } else { $K.dim })
        Txt $g $n "head" 18 $c $tx $y
        $tx += (TextW $g $n "head" 18) + 14
        if ($i -lt $names.Count - 1) { Txt $g "›" "head" 18 $K.tileFrame $tx $y; $tx += 26 }
    }
}
# a big list row of a new game screen: a picture in its frame, a caps name
function BigRow($g, $x, $y, $w, $h, $pic, $name, $active) {
    Fill $g $(if ($active) { $K.header } else { $K.window }) $x $y $w $h
    Frame $g $(if ($active) { $K.accent } else { $K.border }) $x $y $w $h 2
    $s = $h - 16
    Fill $g $K.cell ($x + 8) ($y + 8) $s $s; Frame $g $K.tileEdge ($x + 8) ($y + 8) $s $s 1
    if ($pic) { DrawPic $g $pic ($x + 10) ($y + 10) ($s - 4) ($s - 4) 1 $true }
    TxtMid $g (Up $name) "head" 20 $(if ($active) { $K.bright } else { $K.dim }) ($x + $s + 26) $y $h
}
# a line of text wrapped in the body font; returns the y under it
function Para($g, $text, $x, $y, $w, $px = 20, $c = $null, $lineH = 28) {
    if (-not $c) { $c = $K.text }
    foreach ($line in @(WrapCaps $g $text "body" $px $w)) { Txt $g $line "body" $px $c $x $y; $y += $lineH }
    return $y
}

$L = @{
    ru = @{
        moTitle = "РЕЖИМ: СПИСОК СЛЕВА, ОПИСАНИЕ СПРАВА"
        modes = @(@("Sandbox", "Песочница"), @("Apocalypse", "Апокалипсис"), @("Outbreak", "Вспышка заражения"), @("Rising", "Возрождение"), @("Extinction", "Вымирание"), @("Challenges", "Испытания"))
        sandboxDesc = "Для тех, кто хочет настроить свой собственный зомби-апокалипсис!"
        spTitle = "МЕСТО: ГОРОДА, КАРТА ИГРЫ, ДОСЬЕ ГОРОДА"
        spA = "КАРТА ДВИГАЕТСЯ МЫШЬЮ И ПРИБЛИЖАЕТСЯ КОЛЕСОМ. ВЫБРАЛИ ГОРОД - ОНА САМА К НЕМУ ПЕРЕЕДЕТ."
        save = "Имя сохранения"; seed = "Ключ мира"
        sbTitle = "ПЕСОЧНИЦА: КАЖДАЯ НАСТРОЙКА - СТРОКА, СПРАВКА СПРАВА"
        sbSections = @("Зомби", "Время", "Мир", "Природа", "Добыча"); sbMods = @("Knox Inventory")
        sbRows = @(@("Множитель популяции", "1.0", $false), @("Скорость зомби", "Медленно ходят", $true), @("Начальный месяц", "Июль", $false), @("Продолжительность игрового дня", "2 часа", $true), @("Редкость добычи", "Редкая", $false))
        sbHelpName = "Скорость зомби"; sbHelp = "Как быстро передвигаются заражённые."; sbDefault = "Ходят"
        chTitle = "ПЕРСОНАЖ: ОДИН ЭКРАН ВМЕСТО ДВУХ"
        hero = "Кейт Робертс"; prof = "Охранник"
        traits = @(@("trait_nightowl", "Ночная сова", "-2", "sel"), @("trait_athletic", "Атлетичный", "-6", "sel"), @("trait_brave", "Храбрый", "-4", ""), @("trait_fastreader", "Быстрый читатель", "-2", "sel"), @("trait_slowreader", "Медленный читатель", "+2", "excl"), @("trait_firstaid", "Первая помощь", "-4", ""), @("trait_allthumbs", "Нерасторопный", "+2", ""))
        exclBy = "Быстрый читатель"
        ldTitle = "ЭКРАН ЗАГРУЗКИ: ТЕ ЖЕ СЛОВА, НОВОЕ ОФОРМЛЕНИЕ"
        tip = "Шум привлекает зомби. Бегайте только тогда, когда это действительно нужно."
        mnTitle = "МЕНЮ ГЕРОЯ: ПРАВЫЙ ЩЕЛЧОК У КОСТРА"; saveName = "Sandbox\Брайан"
    }
    en = @{
        moTitle = "MODE: A LIST ON THE LEFT, ITS DESCRIPTION ON THE RIGHT"
        modes = @(@("Sandbox", "Custom Sandbox"), @("Apocalypse", "Apocalypse"), @("Outbreak", "Outbreak"), @("Rising", "Rising"), @("Extinction", "Extinction"), @("Challenges", "Challenges"))
        sandboxDesc = "Choose your own zombie apocalypse. A horde of custom options that impact the world, the undead and much more."
        spTitle = "SPAWN: TOWNS, THE GAME'S MAP, THE TOWN'S FILE"
        spA = "DRAG THE MAP WITH THE MOUSE, ZOOM WITH THE WHEEL. PICK A TOWN AND THE MAP MOVES TO IT."
        save = "Save name"; seed = "World seed"
        sbTitle = "SANDBOX: EVERY SETTING A ROW, HELP ON THE RIGHT"
        sbSections = @("Zombies", "Time", "World", "Nature", "Loot"); sbMods = @("Knox Inventory")
        sbRows = @(@("Population Multiplier", "1.0", $false), @("Zombie Speed", "Shamblers", $true), @("Start Month", "July", $false), @("Day Length", "2 Hours", $true), @("Loot Rarity", "Rare", $false))
        sbHelpName = "Zombie Speed"; sbHelp = "How fast the infected move."; sbDefault = "Fast Shamblers"
        chTitle = "CHARACTER: ONE SCREEN INSTEAD OF TWO"
        hero = "Kate Roberts"; prof = "Security Guard"
        traits = @(@("trait_nightowl", "Night Owl", "-2", "sel"), @("trait_athletic", "Athletic", "-6", "sel"), @("trait_brave", "Brave", "-4", ""), @("trait_fastreader", "Fast Reader", "-2", "sel"), @("trait_slowreader", "Slow Reader", "+2", "excl"), @("trait_firstaid", "First Aider", "-4", ""), @("trait_allthumbs", "All Thumbs", "+2", ""))
        exclBy = "Fast Reader"
        ldTitle = "LOADING SCREEN: THE SAME WORDS, A NEW LOOK"
        tip = "Noise attracts zombies. Only run when you really need to."
        mnTitle = "THE HERO'S MENU: RIGHT CLICK BY THE FIRE"; saveName = "Sandbox\Brian"
    }
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.8.1 ($lang):"
    $steps = @((Tr $lang "IGUI_Knox_New_Mode"), (Tr $lang "IGUI_Knox_New_Spawn"), (Tr $lang "IGUI_Knox_New_World"), (Tr $lang "IGUI_Knox_New_Character"))

    # --- mode
    $bmp, $g = Canvas 1280 680 $K.screen
    Caption $g $s.moTitle 24 26
    Steps $g 24 76 $steps 0
    $ry = 116
    for ($i = 0; $i -lt $s.modes.Count; $i++) {
        BigRow $g 24 $ry 420 84 (Join-Path $modes ($s.modes[$i][0] + ".png")) $s.modes[$i][1] ($i -eq 0)
        $ry += 92
    }
    Fill $g $K.window 464 116 792 544; Frame $g $K.border 464 116 792 544 1
    Fill $g $K.cell 480 132 760 360; Frame $g $K.accent 480 132 760 360 2
    DrawPic $g (Join-Path $modes "Sandbox.png") 480 140 760 344 1 $true
    Txt $g (Up $s.modes[0][1]) "title" 30 $K.bright 488 516
    Fill $g $K.accent 488 556 70 3
    Para $g $s.sandboxDesc 488 576 740 | Out-Null
    Save $bmp $g "u081_mode_$lang.png"

    # --- spawn: towns, the town's paper map from the game, its file
    $bmp, $g = Canvas 1280 680 $K.screen
    Caption $g $s.spTitle 24 26
    Steps $g 24 76 $steps 1
    $ty = 116
    foreach ($town in "MULDRAUGH, KY", "WEST POINT, KY", "RIVERSIDE, KY", "ROSEWOOD, KY", "MARCH RIDGE, KY", "ECHO CREEK, KY", "BRANDENBURG, KY") {
        $on = ($town -eq "MULDRAUGH, KY")
        Fill $g $(if ($on) { $K.header } else { $K.window }) 24 $ty 300 46; Frame $g $(if ($on) { $K.accent } else { $K.border }) 24 $ty 300 46 2
        TxtMid $g $town "head" 17 $(if ($on) { $K.bright } else { $K.dim }) 40 $ty 46
        $ty += 52
    }
    Fill $g $K.cell 340 116 560 544; Frame $g $K.accent 340 116 560 544 2
    $map = [System.Drawing.Image]::FromFile((Join-Path $gameUi "LootableMaps\muldraughmap.png"))
    $g.SetClip((New-Object System.Drawing.Rectangle 342, 118, 556, 540))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $mk = 556 / ($map.Width * 0.55)
    $g.DrawImage($map, (New-Object System.Drawing.Rectangle 342, 118, ([int]($map.Width * $mk)), ([int]($map.Height * $mk))), [int]($map.Width * 0.2), [int]($map.Height * 0.15), $map.Width, $map.Height, [System.Drawing.GraphicsUnit]::Pixel)
    $g.ResetClip(); $map.Dispose()
    Fill $g $K.window 916 116 340 544; Frame $g $K.border 916 116 340 544 1
    Txt $g "MULDRAUGH, KY" "title" 26 $K.bright 932 140
    Fill $g $K.accent 932 178 60 3
    CapsBlock $g $s.spA 932 200 310 | Out-Null
    foreach ($fld in @(@($s.save, "Muldraugh 1993"), @($s.seed, "7F3A-91C2"))) {
        Txt $g $fld[0] "body" 18 $K.dim 932 ($ty = $(if ($fld[0] -eq $s.save) { 460 } else { 560 }))
        Fill $g $K.cell 932 ($ty + 26) 308 40; Frame $g $K.tileEdge 932 ($ty + 26) 308 40 1
        TxtMid $g $fld[1] "body" 20 $K.bright 944 ($ty + 26) 40
    }
    Save $bmp $g "u081_spawn_$lang.png"

    # --- sandbox: sections, rows with changed ones in sand, the help
    $bmp, $g = Canvas 1280 640 $K.screen
    Caption $g $s.sbTitle 24 26
    Steps $g 24 76 $steps 2
    Fill $g $K.window 24 116 240 500; Frame $g $K.border 24 116 240 500 1
    Txt $g (Up (Tr $lang "IGUI_Knox_Sandbox_Game")) "head" 17 $K.accent 40 136
    $sy = 168
    for ($i = 0; $i -lt $s.sbSections.Count; $i++) {
        $on = ($i -eq 0)
        if ($on) { Fill $g $K.header 32 ($sy - 8) 224 38; Fill $g $K.accent 32 ($sy - 8) 3 38 }
        Txt $g $s.sbSections[$i] "body" 20 $(if ($on) { $K.bright } else { $K.text }) 46 $sy; $sy += 42
    }
    Txt $g (Up (Tr $lang "IGUI_Knox_Sandbox_Mods")) "head" 17 $K.accent 40 ($sy + 16)
    Txt $g $s.sbMods[0] "body" 20 $K.text 46 ($sy + 50)
    Fill $g $K.window 280 116 600 500; Frame $g $K.border 280 116 600 500 1
    $ry = 132
    foreach ($r in $s.sbRows) {
        $hot = ($r[0] -eq $s.sbHelpName)
        Fill $g $(if ($hot) { $K.header } else { $K.window }) 290 $ry 580 56
        Fill $g $K.line 290 ($ry + 56) 580 1
        TxtMid $g $r[0] "body" 20 $(if ($r[2]) { $K.accent } else { $K.text }) 304 $ry 56
        $vw = (TextW $g $r[1] "body" 20) + 24
        Fill $g $K.cell (860 - $vw) ($ry + 10) $vw 36; Frame $g $(if ($r[2]) { $K.accent } else { $K.tileEdge }) (860 - $vw) ($ry + 10) $vw 36 1
        TxtCentre $g $r[1] "body" 20 $(if ($r[2]) { $K.accent } else { $K.bright }) (860 - $vw) ($ry + 10) $vw 36
        $ry += 64
    }
    Fill $g $K.window 896 116 360 500; Frame $g $K.border 896 116 360 500 1
    Txt $g $s.sbHelpName "title" 24 $K.bright 912 140
    $hy = Para $g $s.sbHelp 912 186 320
    Txt $g ((Tr $lang "IGUI_Knox_Sandbox_Default") + ": " + $s.sbDefault) "body" 19 $K.dim 912 ($hy + 12)
    Tag $g 912 ($hy + 50) (Up (Tr $lang "IGUI_Knox_Sandbox_Changed")) $K.accent | Out-Null
    Save $bmp $g "u081_sandbox_$lang.png"

    # --- character: tabs, the summary on the left, traits with filters
    $bmp, $g = Canvas 1280 700 $K.screen
    Caption $g $s.chTitle 24 26
    Steps $g 24 76 $steps 3
    Fill $g $K.window 24 116 380 560; Frame $g $K.border 24 116 380 560 1
    Txt $g (Up (Tr $lang "IGUI_Knox_Char_Title")) "head" 17 $K.accent 40 136
    Txt $g $s.hero "title" 26 $K.bright 40 170
    Fill $g $K.cell 40 214 64 64; Frame $g $K.tileEdge 40 214 64 64 1
    DrawPic $g (Join-Path $traitDir "profession_securityguard2.png") 44 218 56 56
    TxtMid $g $s.prof "body" 21 $K.bright 118 214 64
    Txt $g (Up (Tr $lang "IGUI_Knox_Char_Points")) "head" 16 $K.dim 40 304
    Txt $g "0" "title" 26 $K.accent (388 - (TextW $g "0" "title" 26)) 300
    Txt $g (Up (Tr $lang "IGUI_Knox_Char_Traits")) "head" 16 $K.dim 40 352
    $cy = 382
    foreach ($t in $s.traits) {
        if ($t[3] -ne "sel") { continue }
        Fill $g $K.header 40 $cy 348 42; Frame $g $K.tileEdge 40 $cy 348 42 1
        DrawPic $g (Join-Path $traitDir ($t[0] + ".png")) 46 ($cy + 5) 32 32
        TxtMid $g $t[1] "body" 19 $K.bright 88 $cy 42
        $cy += 48
    }
    # the traits page
    Fill $g $K.window 420 116 836 560; Frame $g $K.border 420 116 836 560 1
    $ty = Tabs $g 420 120 836 @((Tr $lang "IGUI_Knox_Char_Prof"), (Tr $lang "IGUI_Knox_Char_Traits"), (Tr $lang "IGUI_Knox_Char_Look"), (Tr $lang "IGUI_Knox_Char_Clothes")) 1
    $fx = 452
    foreach ($fi in @((Tr $lang "IGUI_Knox_Char_All"), (Tr $lang "IGUI_Knox_Char_Good"), (Tr $lang "IGUI_Knox_Char_Bad"))) {
        $t = Up $fi; $bw = (TextW $g $t "head" 16) + 30; $on = ($fi -eq (Tr $lang "IGUI_Knox_Char_All"))
        if ($on) { Fill $g $K.accent $fx ($ty + 14) $bw 34; TxtCentre $g $t "head" 16 $K.ink $fx ($ty + 14) $bw 34 }
        else { Fill $g $K.buttonBg $fx ($ty + 14) $bw 34; Frame $g $K.tileFrame $fx ($ty + 14) $bw 34 1; TxtCentre $g $t "head" 16 $K.bright $fx ($ty + 14) $bw 34 }
        $fx += $bw + 8
    }
    $ry = $ty + 64
    foreach ($t in $s.traits) {
        $sel = ($t[3] -eq "sel"); $excl = ($t[3] -eq "excl")
        Fill $g $(if ($sel) { $K.header } else { $K.cell }) 452 $ry 772 50
        Frame $g $(if ($sel) { $K.accent } else { $K.border }) 452 $ry 772 50 $(if ($sel) { 2 } else { 1 })
        DrawPic $g (Join-Path $traitDir ($t[0] + ".png")) 462 ($ry + 9) 32 32 $(if ($excl) { 0.35 } else { 1 })
        TxtMid $g $t[1] "body" 20 $(if ($excl) { $K.tileFrame } else { $K.bright }) 506 $ry 50
        $right = $(if ($excl) { (Tr $lang "IGUI_Knox_Char_Excluded").Replace("%1", $s.exclBy) } else { $t[2] })
        $rc = $(if ($excl) { $K.tileFrame } elseif ($t[2].StartsWith("+")) { $K.good } else { $K.accent })
        TxtMid $g $right "body" 19 $rc (1208 - (TextW $g $right "body" 19)) $ry 50
        $ry += 56
    }
    Save $bmp $g "u081_character_$lang.png"

    # --- loading screen: the phrase in the middle, the tip, the sand bar, Start
    $bmp, $g = Canvas 1280 560 (Hex "#060707")
    Caption $g $s.ldTitle 24 26
    $ph = (Tr $lang "UI_Intro3")
    $phrase = $(if ($lang -eq "ru") { "ЭТО ИСТОРИЯ ВАШЕЙ СМЕРТИ" } else { "THIS IS HOW YOU DIED" })
    $pw = TextW $g $phrase "title" 44
    Txt $g $phrase "title" 44 $K.bright ((1280 - $pw) / 2) 200
    # the tip, on a plate at the bottom
    $tipW = 900; $tx = (1280 - $tipW) / 2
    Fill $g $K.window $tx 372 $tipW 70; Frame $g $K.tileFrame $tx 372 $tipW 70 1
    Tag $g ($tx + 14) 393 (Up (Tr $lang "IGUI_Knox_Load_Tip")) $K.accent | Out-Null
    TxtMid $g $s.tip "body" 20 $K.text ($tx + 110) 372 70
    # Start, as a key hint; the sand bar full along the bottom edge
    $kw = KeyPlate $g 1090 480 (Tr $lang "IGUI_Knox_Load_Click") $true
    TxtMid $g (Up (Tr $lang "IGUI_Knox_Load_Start")) "head" 18 $K.bright (1090 + $kw + 12) 480 28
    Fill $g $K.accent 0 552 1280 8
    Save $bmp $g "u081_loading_$lang.png"

    # --- the hero's menu by the fire, and the question before a save is deleted
    $bmp, $g = Canvas 1280 520 $K.screen
    Caption $g $s.mnTitle 24 26
    $mx = 60; $my = 100; $mw = 420
    $items = @((Tr $lang "IGUI_Knox_Menu_CtxLoad"), (Tr $lang "IGUI_Knox_Menu_CtxNew"), (Tr $lang "IGUI_Knox_Menu_CtxFolder"), (Tr $lang "IGUI_Knox_Menu_CtxDelete"))
    $mh = $items.Count * 46 + 16
    Fill $g $K.window $mx $my $mw $mh; Frame $g $K.accent $mx $my $mw $mh 2
    $iy = $my + 8
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($i -eq 3) { Fill $g $K.header ($mx + 4) $iy ($mw - 8) 46; Fill $g $K.accent ($mx + 4) $iy 3 46 }
        TxtMid $g $items[$i] "body" 20 $(if ($i -eq 3) { $K.bright } else { $K.text }) ($mx + 24) $iy 46
        $iy += 46
    }
    Cursor $g ($mx + 240) ($my + 8 + 3 * 46 + 18) 36
    # the question
    $dx = 620; $dy = 140; $dw = 600; $dh = 220
    Fill $g $K.window $dx $dy $dw $dh; Frame $g $K.accent $dx $dy $dw $dh 2
    $q = (Tr $lang "IGUI_Knox_Menu_CtxDeleteAsk").Replace("%1", $s.saveName)
    $qw = TextW $g $q "title" 24
    Txt $g $q "title" 24 $K.bright ($dx + ($dw - $qw) / 2) ($dy + 50)
    $yes = Up (Tr $lang "IGUI_Knox_Menu_CtxDeleteYes"); $no = Up (Tr $lang "IGUI_Knox_Menu_CtxCancel")
    $yw = (TextW $g $yes "head" 17) + 40; $nw = (TextW $g $no "head" 17) + 40
    $bx = $dx + ($dw - $yw - $nw - 16) / 2
    Fill $g $K.bad $bx ($dy + 130) $yw 44; TxtCentre $g $yes "head" 17 $K.bright $bx ($dy + 130) $yw 44
    Fill $g $K.buttonBg ($bx + $yw + 16) ($dy + 130) $nw 44; Frame $g $K.tileFrame ($bx + $yw + 16) ($dy + 130) $nw 44 1
    TxtCentre $g $no "head" 17 $K.bright ($bx + $yw + 16) ($dy + 130) $nw 44
    Save $bmp $g "u081_menu_$lang.png"

    # --- banner: the modes' pictures, a background
    $bmp, $g = Canvas 912 204 $K.screen
    $bx = 330
    foreach ($m in "Sandbox", "Apocalypse", "Outbreak", "Rising", "Extinction", "Challenges") {
        Fill $g $K.cell $bx 22 92 160; Frame $g $K.border $bx 22 92 160 1
        DrawPic $g (Join-Path $modes "$m.png") ($bx + 4) 30 84 144 1 $true
        $bx += 98
    }
    Fill $g $K.screen 0 0 912 204 0.45
    $r = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $r)
    Save $bmp $g "u081_banner_$lang.png"

    # --- art: the steps and the mode list
    $bmp, $g = Canvas 960 1080 $K.cell
    Steps $g 60 60 $steps 0
    $ry = 110
    for ($i = 0; $i -lt $s.modes.Count; $i++) {
        BigRow $g 60 $ry 840 140 (Join-Path $modes ($s.modes[$i][0] + ".png")) $s.modes[$i][1] ($i -eq 0)
        $ry += 152
    }
    Save $bmp $g "u081_art_$lang.png"
}
