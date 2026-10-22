# Pictures of the 0.8.2 news post (the mod's parts switched on and off), made in
# 2026-10 by the approved news rules (see make_news_096.ps1 and news_ui.ps1): the
# main menu's plate and the modules window as Knox draws them, the mod's own
# words (0.8.2 had no tabs yet: one window, "Knox Inventory: modules"), captions
# in capitals, a banner with no words, a picture per language.
#   42\media\knox\news\u082_<name>_<ru|en>.png   banner, art, modules
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_082.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        title = "МОД ВКЛЮЧАЕТСЯ ПО ЧАСТЯМ"
        a = "ВЫКЛЮЧЕННАЯ ЧАСТЬ ВОЗВРАЩАЕТ ЭКРАНЫ САМОЙ ИГРЫ."
        b = "ПОСЛЕ «ПРИМЕНИТЬ» ИГРА САМА ПЕРЕЗАГРУЖАЕТ ИНТЕРФЕЙС - ПЕРЕЗАПУСК НЕ НУЖЕН."
        c = "ПЛАШКА В МЕНЮ ОСТАЁТСЯ ПРИ ЛЮБЫХ ВЫКЛЮЧЕННЫХ ЧАСТЯХ: ВСЁ МОЖНО ВКЛЮЧИТЬ ОБРАТНО."
        artTitle = "ОСТАВЬТЕ ТОЛЬКО ТО, ЧТО НУЖНО"
    }
    en = @{
        title = "THE MOD SWITCHES ON PART BY PART"
        a = "A PART SWITCHED OFF GIVES THE GAME'S OWN SCREENS BACK."
        b = ("AFTER " + [char]0x201C + "APPLY" + [char]0x201D + " THE GAME RELOADS ITS INTERFACE BY ITSELF - NO RESTART.")
        c = "THE PLATE IN THE MENU STAYS WHATEVER IS OFF: ANYTHING CAN BE SWITCHED BACK ON."
        artTitle = "KEEP ONLY WHAT YOU NEED"
    }
}

# the plate at the top of the main menu: KNOX INVENTORY | MODULES, lit (the mouse is on it)
function MenuPlate($g, $x, $y, $label) {
    $f = 20; $padX = 18
    $wK = TextW $g "KNOX" "head" $f; $wI = TextW $g "INVENTORY" "head" $f; $wL = TextW $g $label "head" $f
    $w = $padX + $wK + 10 + $wI + 16 + 1 + 16 + $wL + $padX; $h = 48
    Fill $g $K.header $x $y $w $h 0.96
    Frame $g $K.accent $x $y $w $h 2
    $cx = $x + $padX
    TxtMid $g "KNOX" "head" $f $K.bright $cx $y $h; $cx += $wK + 10
    TxtMid $g "INVENTORY" "head" $f $K.accent $cx $y $h; $cx += $wI + 16
    Fill $g $K.tileEdge $cx ($y + 12) 1 ($h - 24); $cx += 17
    TxtMid $g $label "head" $f $K.bright $cx $y $h
    return $w
}

# A row of the modules window: the switch square (sand while on), the part's name
# in capitals, what it holds under it; a "after a reload" mark when it waits.
function ModRow($g, $x, $y, $w, $on, $name, $info, $pending) {
    $box = 32; $tx = $x + $box + 20
    Fill $g $K.line $x $y $w 1
    $by = $y + 16
    Fill $g $K.cell $x $by $box $box
    Frame $g $(if ($on) { $K.accent } else { $K.tileEdge }) $x $by $box $box 1
    if ($on) { Fill $g $K.accent ($x + 4) ($by + 4) ($box - 8) ($box - 8) }
    Txt $g (Up $name) "head" 19 $(if ($on) { $K.bright } else { $K.dim }) $tx ($by + 6)
    if ($pending) { $pw = TextW $g (Up $pending) "head" 17; Txt $g (Up $pending) "head" 17 $K.accent ($x + $w - $pw) ($by + 7) }
    $ly = $by + 40
    foreach ($line in (WrapCaps $g $info "body" 19 ($w - ($tx - $x)))) { Txt $g $line "body" 19 $(if ($on) { $K.text } else { $K.dim }) $tx $ly; $ly += 26 }
    return $ly + 10
}

# the window's height for width w (its rows' text wraps)
function ModulesHeight($g, $lang, $w) {
    $h = 44 + 60
    foreach ($n in "ingame", "menu", "newgame") { $h += 16 + 40 + 26 * @(WrapCaps $g (Tr $lang ("IGUI_Knox_Module_" + $n + "_Info")) "body" 19 ($w - 64 - 52)).Count + 10 }
    return $h + 16 + 24 * @(WrapCaps $g (Tr $lang "IGUI_Knox_Modules_NoteMenu") "body" 18 ($w - 64)).Count + 24 + 40 + 24
}

# the window: the title, MODULES in sand, three rows, the note, Apply and Close
function ModulesWindow($g, $lang, $x, $y, $w) {
    $rows = @(@("ingame", $true, $null), @("menu", $true, $null), @("newgame", $false, (Tr $lang "IGUI_Knox_Modules_Pending")))
    $h = ModulesHeight $g $lang $w
    $note = WrapCaps $g (Tr $lang "IGUI_Knox_Modules_NoteMenu") "body" 18 ($w - 64)
    Win $g $x $y $w $h (Tr $lang "IGUI_Knox_Modules")
    Txt $g (Up (Tr $lang "IGUI_Knox_Modules_Title")) "head" 18 $K.accent ($x + 32) ($y + 44 + 22)
    $ry = $y + 44 + 60
    foreach ($r in $rows) {
        $ry = ModRow $g ($x + 32) $ry ($w - 64) $r[1] (Tr $lang ("IGUI_Knox_Module_" + $r[0])) (Tr $lang ("IGUI_Knox_Module_" + $r[0] + "_Info")) $r[2]
    }
    $ry += 16
    foreach ($line in $note) { Txt $g $line "body" 18 $K.dim ($x + 32) $ry; $ry += 24 }
    # Apply (sand) and Close, at the bottom right
    $by = $y + $h - 24 - 40
    $close = Up (Tr $lang "IGUI_Knox_Close"); $apply = Up (Tr $lang "IGUI_Knox_Apply")
    $cw = (TextW $g $close "head" 17) + 40; $aw = (TextW $g $apply "head" 17) + 40
    $cx = $x + $w - 32 - $cw; $ax = $cx - 10 - $aw
    Fill $g $K.accent $ax $by $aw 40; TxtCentre $g $apply "head" 17 $K.ink $ax $by $aw 40
    Fill $g $K.buttonBg $cx $by $cw 40; Frame $g $K.tileFrame $cx $by $cw 40 1; TxtCentre $g $close "head" 17 $K.bright $cx $by $cw 40
    return @{h = $h; applyX = $ax; applyY = $by; applyW = $aw}
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.8.2 ($lang):"
    $label = Up (Tr $lang "IGUI_Knox_Modules_Title")

    # --- modules: the plate in the menu, the window it opens, what it means
    $probe, $pg0 = Canvas 10 10 $K.screen
    $mh = ModulesHeight $pg0 $lang 720
    $pg0.Dispose(); $probe.Dispose()
    $bmp, $g = Canvas 1280 (156 + $mh + 40) $K.screen
    Caption $g $s.title 24 26
    $pw = MenuPlate $g 40 84 $label
    Cursor $g (40 + $pw - 60) 112 34
    $win = ModulesWindow $g $lang 40 156 720
    $yb = CapsBlock $g $s.a 800 176 440
    $yb = CapsBlock $g $s.b 800 ($yb + 14) 440
    CapsBlock $g $s.c 800 ($yb + 14) 440 | Out-Null
    Save $bmp $g "u082_modules_$lang.png"

    # --- art: the plate on the menu's top, the window under it, the cursor on Apply
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 60 56 26
    # (the plate and the window as one block, in the middle of the picture under the caption)
    $mh = ModulesHeight $g $lang 840
    $top = 110 + [math]::Max(0, [math]::Floor((1080 - 110 - 40 - (48 + 38 + $mh)) / 2))
    $pw = MenuPlate $g 60 $top $label
    $win = ModulesWindow $g $lang 60 ($top + 86) 840
    Cursor $g ($win.applyX + $win.applyW - 12) ($win.applyY + 26) 34
    Save $bmp $g "u082_art_$lang.png"

    # --- banner: switches and the things of the parts they hold, no words
    BannerPattern "u082_banner_$lang.png" @(
        @(7, 0, 2, 2, "tool", "tv", ""), @(9, 0, 1, 1, "tool", "radio", "hit"), @(10, 0, 2, 2, "clo", "bag_hiking", ""),
        @(12, 0, 1, 2, "food", "bottle", ""), @(13, 0, 2, 1, "wpn", "pistol", ""), @(15, 0, 1, 1, "info", "book", ""),
        @(9, 1, 1, 1, "info", "cassette", ""), @(13, 1, 1, 1, "med", "bandage", "hit"), @(14, 1, 2, 2, "food", "pot", ""),
        @(7, 2, 1, 1, "info", "keyring", ""), @(8, 2, 2, 1, "wpn", "shotgun", ""), @(12, 2, 1, 1, "tool", "battery", ""),
        @(16, 1, 1, 2, "clo", "tshirt", "")
    )
}
