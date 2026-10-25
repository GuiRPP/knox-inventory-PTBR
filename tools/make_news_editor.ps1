# Pictures of the item editor's news post ("Make it yours", 2026-10-25, the author: "write
# the news"), by the approved news rules (see make_news_096.ps1 and news_ui.ps1): captions in
# capitals, and pieces of the Knox screen itself - here the editor's own drawing, pixel for
# pixel: tools\editor\snap runs the real KnoxEditor on the game's Lua and paints its calls
# with Knox's font atlases and the game's item icons (as make_news_gen.ps1 does with the
# generator's window). Nothing is scaled.
#   42\media\knox\news\e1_banner_<ru|en>.png   912 x 204
#   42\media\knox\news\e1_art_<ru|en>.png      960 x 1080
#   42\media\knox\news\e1_<bags|clothes|presets|share>_<ru|en>.png   1280 wide
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_editor.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        art = "ПОД СЕБЯ"
        bags = "СУМКА ИЗНУТРИ - КАК ВАМ УДОБНО"
        bagsA = "ОТСЕКИ, ОДНА СЕТКА ИЛИ ПО КЛЕТКАМ. ПО КЛЕТКАМ ФОРМА РИСУЕТСЯ МЫШЬЮ: ЛКМ ДОБАВЛЯЕТ КЛЕТКУ, ПКМ УБИРАЕТ."
        bagsB = "КЛЕТКИ, ЧТО КАСАЮТСЯ СТОРОНАМИ, - ОДИН ОТСЕК. РЯДОМ - СКОЛЬКО КЛЕТОК ВЫШЛО И СКОЛЬКО ДАЁТ ВМЕСТИМОСТЬ ИГРЫ."
        clo = "КАРМАНЫ И СТОПКИ"
        cloA = "КАРМАНЫ: СКОЛЬКО КЛЕТОК ДАЁТ ОДЕЖДА - ОДНОЙ ВЕЩИ ИЛИ СРАЗУ ВСЕМ ВЕЩАМ ЭТОГО МЕСТА."
        cloB = "СТОПКА: ЛЮБУЮ ВЕЩЬ, КРОМЕ СУМОК, МОЖНО СКЛАДЫВАТЬ ПО НЕСКОЛЬКО В КЛЕТКУ. ЛЯГУТ ТОЛЬКО ОДИНАКОВЫЕ."
        pre = "ПРЕСЕТЫ"
        preA = "ОБЩИЙ - ДЛЯ ВСЕХ ВЕЩЕЙ, РАЗДЕЛА - НАПРИМЕР, ТОЛЬКО ДЛЯ СУМОК, МОДА - ДЛЯ ЕГО ВЕЩЕЙ. УЗКИЙ ДЕЙСТВУЕТ ПОВЕРХ ОБЩЕГО."
        preB = "КАРАНДАШ - ПРЕСЕТ, В КОТОРЫЙ СЕЙЧАС ИДУТ ПРАВКИ."
        share = "ПОДЕЛИТЬСЯ"
        shareA = "ЭКСПОРТ - В БУФЕР ОБМЕНА ИЛИ В ФАЙЛ."
        shareB = "ИМПОРТ ПОКАЖЕТ КАЖДУЮ СТРОКУ, А ЧУЖИЕ И ОШИБОЧНЫЕ ПРОПУСТИТ."
    }
    en = @{
        art = "MAKE IT YOURS"
        bags = "THE INSIDE OF A BAG, YOUR WAY"
        bagsA = "COMPARTMENTS, ONE GRID OR CELL BY CELL. CELL BY CELL, YOU DRAW THE SHAPE WITH THE MOUSE: LEFT CLICK ADDS A CELL, RIGHT CLICK REMOVES IT."
        bagsB = "CELLS THAT TOUCH BY THEIR SIDES ARE ONE COMPARTMENT. BESIDE IT: THE CELLS YOU MADE AND WHAT THE GAME'S CAPACITY GIVES."
        clo = "POCKETS AND STACKS"
        cloA = "POCKETS: HOW MANY CELLS A PIECE OF CLOTHING GIVES - FOR ONE ITEM OR FOR EVERYTHING WORN THERE."
        cloB = "STACKS: ANY ITEM BUT A BAG CAN BE STACKED SEVERAL TO A CELL. ONLY IDENTICAL ONES GO TOGETHER."
        pre = "PRESETS"
        preA = "GENERAL - FOR EVERY ITEM, TAB - SAY, BAGS ONLY, MOD - FOR ITS ITEMS. THE NARROWER ONE GOES OVER THE GENERAL ONE."
        preB = "THE PENCIL MARKS THE PRESET YOUR EDITS GO TO."
        share = "SHARE"
        shareA = "EXPORT - TO THE CLIPBOARD OR TO A FILE."
        shareB = "IMPORT SHOWS EVERY LINE, AND SKIPS THE ONES FOR OTHER MODS AND THE BROKEN ONES."
    }
}

# --- the editor's snaps (tools\editor\snap), a folder per run
$snaps = Join-Path $env:TEMP "knox_news_editor"
foreach ($lang in "ru", "en") {
    & (Join-Path $PSScriptRoot "editor\snap\snap.ps1") -out $snaps -lang $lang | Out-Null
}
$imgs = @{}
function Snap($lang, $name) {
    $k = "$lang/$name"
    if (-not $imgs[$k]) { $imgs[$k] = New-Object System.Drawing.Bitmap (Join-Path $snaps "png_$lang\$name.png") }
    $imgs[$k]
}
# where the window's columns are on a snap: the item page starts right of the list's line,
# the window's sand frame closes it (the languages' windows differ by a pixel or two)
function Page($img) {
    $line = [System.Drawing.Color]::FromArgb(255, 42, 46, 46)
    $x0 = 0
    for ($x = 500; $x -lt 600; $x++) { if ($img.GetPixel($x, 300).ToArgb() -eq $line.ToArgb()) { $x0 = $x + 1; break } }
    $x1 = $img.Width - 1
    while ($x1 -gt 0 -and $img.GetPixel($x1, 300).ToArgb() -ne $K.accent.ToArgb()) { $x1-- }
    return @($x0, ($x1 - 1))   # (the frame is 2 px: its inner pixel left out too)
}
function ListX($img) {
    $line = [System.Drawing.Color]::FromArgb(255, 42, 46, 46)
    for ($x = 150; $x -lt 260; $x++) { if ($img.GetPixel($x, 300).ToArgb() -eq $line.ToArgb()) { return $x + 1 } }
    return 0
}
# a piece of a snap, pixel for pixel, in a sand frame as a Knox window's
function Piece($g, $img, $sx, $sy, $sw, $sh, $x, $y) {
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $src = New-Object System.Drawing.Rectangle ([int]$sx), ([int]$sy), ([int]$sw), ([int]$sh)
    $dst = New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$sw), ([int]$sh)
    $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    Frame $g $K.accent ($x - 2) ($y - 2) ($sw + 4) ($sh + 4) 2
}
function Fade($g, $x, $y, $w, $h, $a0, $a1, $vertical) {
    $rr = New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$w), ([int]$h)
    $angle = $(if ($vertical) { 90.0 } else { 0.0 })
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, (A $K.screen $a0), (A $K.screen $a1), $angle
    $g.FillRectangle($lg, $rr)
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures, the item editor ($lang):"
    $alice = Snap $lang "20_alice"; $ap = Page $alice

    # --- banner: the military backpack's compartments and their controls, words on the left
    $bmp, $g = Canvas 912 204 $K.screen
    $sw = $ap[1] - $ap[0] - 20
    $g.DrawImage($alice, (New-Object System.Drawing.Rectangle (912 - $sw), 0, $sw, 204),
        (New-Object System.Drawing.Rectangle ($ap[0] + 20), 400, $sw, 204), [System.Drawing.GraphicsUnit]::Pixel)
    Fill $g $K.screen 0 0 912 204 0.2
    $rr = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $rr)
    Fade $g 0 0 912 22 0.9 0 $true
    Fade $g 0 150 912 54 0 1 $true
    Fade $g 870 0 42 204 0 0.85 $false
    Save $bmp $g "e1_banner_$lang.png"

    # --- art: the item's page, whole down to the compartments
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.art 64 56 30 $K.accent
    $pw = $ap[1] - $ap[0] + 1
    Piece $g $alice $ap[0] 46 $pw 724 ([int]((960 - $pw) / 2)) 150
    Save $bmp $g "e1_art_$lang.png"

    # --- bags: the inside, cell by cell
    $mask = Snap $lang "21_mask_hiking"; $mp = Page $mask; $pw = $mp[1] - $mp[0] + 1
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.bags 24 26
    Piece $g $mask $mp[0] 304 $pw 350 40 92
    $ty = CapsBlock $g $s.bagsA 40 480 1200 19 $null 28
    CapsBlock $g $s.bagsB 40 ($ty + 8) 1200 19 $K.accent 28 | Out-Null
    Save $bmp $g "e1_bags_$lang.png"

    # --- clothes: the jacket's pockets, the pistol's stack
    $jk = Snap $lang "04_clothing_pockets"; $jp = Page $jk; $pw = $jp[1] - $jp[0] + 1
    $ps = Snap $lang "05_stack"; $pp = Page $ps; $pw2 = $pp[1] - $pp[0] + 1
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.clo 24 26
    Piece $g $jk $jp[0] 304 $pw 260 40 92
    Piece $g $ps $pp[0] 304 $pw2 170 40 372
    $ty = CapsBlock $g $s.cloA 40 576 1200 19 $null 28
    CapsBlock $g $s.cloB 40 ($ty + 8) 1200 19 $K.accent 28 | Out-Null
    Save $bmp $g "e1_clothes_$lang.png"

    # --- presets: the list and a preset's page
    $pr = Snap $lang "10_preset_page"; $prp = Page $pr; $lx = ListX $pr
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.pre 24 26
    $pw = $prp[1] - $lx + 1
    Piece $g $pr $lx 46 $pw 370 ([int]((1280 - $pw) / 2)) 92
    $ty = CapsBlock $g $s.preA 40 500 1200 19 $null 28
    CapsBlock $g $s.preB 40 ($ty + 8) 1200 19 $K.accent 28 | Out-Null
    Save $bmp $g "e1_presets_$lang.png"

    # --- share: the import read line by line, its words on the right
    $im = Snap $lang "12_import"; $ip = Page $im; $pw = $ip[1] - $ip[0] + 1
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.share 24 26
    Piece $g $im $ip[0] 176 $pw 560 40 92
    $tx = 40 + $pw + 44
    $ty = CapsBlock $g $s.shareA $tx 100 (1240 - $tx) 19 $null 28
    CapsBlock $g $s.shareB $tx ($ty + 8) (1240 - $tx) 19 $K.accent 28 | Out-Null
    Save $bmp $g "e1_share_$lang.png"
}
foreach ($i in $imgs.Values) { $i.Dispose() }
