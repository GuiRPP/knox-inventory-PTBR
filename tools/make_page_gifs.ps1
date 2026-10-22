# Animated pictures for the Workshop page (2026-10-19), a style of their own (the
# author: not the news' - no empty room, more to read): a window of the Knox screen
# filling the picture - on the left the real columns doing the thing, on the right
# a panel in Knox's look with numbered points, the one being shown lit. Everything
# drawn from Knox's own parts (tools\news_ui.ps1: palette, fonts, grids, tiles at
# Knox's sizes) and the game's icons; a GIF per language, written in that language.
#   tools\art\page\<name>_<ru|en>.gif
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_page_gifs.ps1 [-Only name]

param([string]$Only = "")

. (Join-Path $PSScriptRoot "news_ui.ps1")
$out = Join-Path $PSScriptRoot "art\page"
New-Item -ItemType Directory -Force $out | Out-Null
$frames = Join-Path $env:TEMP "knox_page_frames"

$W, $H = 960, 600
$FPS = 12

# --- frames and the GIF -------------------------------------------------------------
$script:fi = 0
function BeginGif() {
    if (Test-Path $frames) { Remove-Item -Recurse -Force $frames }
    New-Item -ItemType Directory -Force $frames | Out-Null
    $script:fi = 0
}
function Frame-Save($bmp, $g, $times = 1) {
    $g.Dispose()
    for ($i = 0; $i -lt $times; $i++) {
        $bmp.Save((Join-Path $frames ("f{0:D4}.png" -f $script:fi)), [System.Drawing.Imaging.ImageFormat]::Png)
        $script:fi++
    }
    $bmp.Dispose()
}
function EndGif($name) {
    $gif = Join-Path $out "$name.gif"
    $pal = Join-Path $frames "palette.png"
    ffmpeg -v error -y -framerate $FPS -i (Join-Path $frames "f%04d.png") -vf "palettegen=max_colors=128:stats_mode=full" $pal
    ffmpeg -v error -y -framerate $FPS -i (Join-Path $frames "f%04d.png") -i $pal -lavfi "paletteuse=dither=none:diff_mode=rectangle" -loop 0 $gif
    Write-Host ("  {0}.gif  {1} frames  {2:N2} MB" -f $name, $script:fi, ((Get-Item $gif).Length / 1MB))
}
function Ease($t) { if ($t -le 0) { 0 } elseif ($t -ge 1) { 1 } else { 1 - (1 - $t) * (1 - $t) * (1 - $t) } }
function Lerp($a, $b, $t) { $a + ($b - $a) * $t }
function Kg($v, $lang) { $s = ("{0:0.0}" -f $v).Replace(",", "."); if ($lang -eq "ru") { $s = $s.Replace(".", ",") }; $s }

# --- a bag drawn cell by cell, as KnoxBagShapes.MASKS / KnoxGridView.drawShape ----------
function BagGeo($mask, $x, $y, $cs) {
    $gap = [math]::Max(4, [math]::Round($cs * 0.2))
    $cols = ($mask | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $colX = @{}; $px = $x
    for ($ci = 0; $ci -lt $cols; $ci++) {
        $colX[$ci] = $px
        $any = $false; foreach ($l in $mask) { if ($ci -lt $l.Length -and $l[$ci] -eq '#') { $any = $true; break } }
        $px += $(if ($any) { $cs } else { $gap })
    }
    $rowY = @{}; $py = $y
    for ($ri = 0; $ri -lt $mask.Count; $ri++) { $rowY[$ri] = $py; $py += $(if ($mask[$ri].Contains("#")) { $cs } else { $gap }) }
    return @{ mask = $mask; colX = $colX; rowY = $rowY; cs = $cs; w = $px - $x; h = $py - $y; cols = $cols }
}
function On($geo, $ci, $ri) { $ri -ge 0 -and $ri -lt $geo.mask.Count -and $ci -ge 0 -and $ci -lt $geo.mask[$ri].Length -and $geo.mask[$ri][$ci] -eq '#' }
function DrawBag($g, $geo) {
    $cs = $geo.cs
    for ($ri = 0; $ri -lt $geo.mask.Count; $ri++) {
        for ($ci = 0; $ci -lt $geo.cols; $ci++) {
            if (On $geo $ci $ri) {
                $px = $geo.colX[$ci]; $py = $geo.rowY[$ri]
                Fill $g $K.cell $px $py $cs $cs
                Fill $g $K.line $px $py 1 ($cs + 1); Fill $g $K.line ($px + $cs) $py 1 ($cs + 1)
                Fill $g $K.line $px $py ($cs + 1) 1; Fill $g $K.line $px ($py + $cs) ($cs + 1) 1
                if (-not (On $geo ($ci - 1) $ri)) { Fill $g $K.tileEdge ($px - 1) ($py - 1) 1 ($cs + 3) 0.55 }
                if (-not (On $geo ($ci + 1) $ri)) { Fill $g $K.tileEdge ($px + $cs + 1) ($py - 1) 1 ($cs + 3) 0.55 }
                if (-not (On $geo $ci ($ri - 1))) { Fill $g $K.tileEdge ($px - 1) ($py - 1) ($cs + 3) 1 0.55 }
                if (-not (On $geo $ci ($ri + 1))) { Fill $g $K.tileEdge ($px - 1) ($py + $cs + 1) ($cs + 3) 1 0.55 }
            }
        }
    }
}
# a tile in such a bag at cell col, row (w x h cells)
# (no $c here: PowerShell names ignore case, and Tile reads the cell size $C)
function BagTile($g, $geo, $col, $row, $w, $h, $cat, $icon, $state = "", $count = $null) {
    $C0 = $script:C; $script:C = $geo.cs
    Tile $g ($geo.colX[$col] - $col * $geo.cs) ($geo.rowY[$row] - $row * $geo.cs) $col $row $w $h $cat $icon $state $count
    $script:C = $C0
}
# the drop highlight over w x h cells: green or red, as KnoxGridView draws it
function DropMark($g, $geo, $cx, $ry, $w, $h, $ok) {
    $mc = $(if ($ok) { $K.ok } else { $K.bad })
    $x = $geo.colX[$cx] + 1; $y = $geo.rowY[$ry] + 1; $pw = $w * $geo.cs - 1; $ph = $h * $geo.cs - 1
    Fill $g $mc $x $y $pw $ph 0.22
    Frame $g $mc $x $y $pw $ph 1
}
# the tile under the mouse, lifted a little with a sand-ish frame (KnoxGridView's hover)
function HoverTile($g, $geo, $col, $row, $w, $h, $cat, $icon) {
    BagTile $g $geo $col $row $w $h $cat $icon "hit"
}
# a held tile at the cursor, at the given cell size
function HeldAt($g, $x, $y, $w, $h, $cat, $icon, $cs) {
    $C0 = $script:C; $script:C = $cs
    Held $g $x $y $w $h $cat $icon
    $script:C = $C0
}
# the game's red words over the character when something is refused (HaloTextHelper)
function Halo($g, $text, $cx, $y, $a) {
    $w = TextW $g $text "head" 22
    Fill $g $K.screen ($cx - $w / 2 - 10) ($y - 6) ($w + 20) 36 (0.7 * $a)
    Txt $g $text "head" 22 $K.bad ($cx - $w / 2) $y $a
}

# --- the page's frame: a Knox window across the picture ------------------------------
# header: a sand square, the section in bold caps, the subject dim; steps on the right
function PageHeader($g, $section, $subject, $steps, $active) {
    Fill $g $K.header 0 0 $W 52
    Fill $g $K.border 0 52 $W 1
    Fill $g $K.accent 18 20 12 12
    Txt $g $section "title" 25 $K.bright 42 15
    $sx = 42 + (TextW $g $section "title" 25) + 14
    Txt $g $subject "head" 19 $K.dim $sx 21
    # the steps: small plates, the one shown in sand
    $px = $W - 18
    for ($i = $steps; $i -ge 1; $i--) {
        $pw = 28; $px -= $pw
        if ($i -eq $active) { Fill $g $K.accent $px 12 $pw 28; TxtCentre $g "$i" "head" 17 $K.ink $px 12 $pw 28 }
        else { Fill $g $K.cell $px 12 $pw 28; Frame $g $K.tileEdge $px 12 $pw 28 1; TxtCentre $g "$i" "head" 17 $K.dim $px 12 $pw 28 }
        $px -= 6
    }
    Frame $g $K.accent 0 0 $W $H 2
}
# the right panel: numbered points, the active one lit (sand bar, bright text)
function Points($g, $x, $y, $w, $points, $active) {
    for ($i = 0; $i -lt $points.Count; $i++) {
        $on = ($i + 1) -eq $active
        $lines = WrapCaps $g $points[$i] "body" 19 ($w - 52)
        $h = 16 + $lines.Count * 24
        if ($on) { Fill $g $K.header $x $y $w $h; Fill $g $K.accent $x $y 3 $h }
        $nb = 26
        if ($on) { Fill $g $K.accent ($x + 12) ($y + 9) $nb $nb; TxtCentre $g "$($i + 1)" "head" 17 $K.ink ($x + 12) ($y + 9) $nb $nb }
        else { Fill $g $K.cell ($x + 12) ($y + 9) $nb $nb; Frame $g $K.tileEdge ($x + 12) ($y + 9) $nb $nb 1; TxtCentre $g "$($i + 1)" "head" 17 $K.dim ($x + 12) ($y + 9) $nb $nb }
        $ly = $y + 12
        foreach ($line in $lines) { Txt $g $line "body" 19 $(if ($on) { $K.bright } else { $K.dim }) ($x + 50) $ly; $ly += 24 }
        $y += $h + 6
    }
    return $y
}
# a labelled meter: the name, the value on the right, a bar
function Meter2($g, $x, $y, $w, $name, $frac, $value, $c) {
    Txt $g $name "head" 17 $K.dim $x $y
    Txt $g $value "head" 17 $K.bright ($x + $w - (TextW $g $value "head" 17)) $y
    Fill $g $K.line $x ($y + 26) $w 6
    Fill $g $c $x ($y + 26) ([int]($w * [math]::Min(1, $frac))) 6
}
# key plates with what they do, in a row (wrapping)
function Keys($g, $x, $y, $w, $pairs) {
    $cx = $x
    foreach ($p in $pairs) {
        $kw = (TextW $g $p[0] "head" 15) + 16
        $tw = TextW $g $p[1] "body" 17
        if ($cx + $kw + 8 + $tw -gt $x + $w) { $cx = $x; $y += 36 }
        Fill $g $K.cell $cx $y $kw 26; Frame $g $K.tileEdge $cx $y $kw 26 1
        TxtCentre $g $p[0] "head" 15 $K.bright $cx $y $kw 26
        TxtMid $g $p[1] "body" 17 $K.dim ($cx + $kw + 8) $y 26
        $cx += $kw + 8 + $tw + 18
    }
    return $y + 26
}

# --- texts (written in each language, not translated) ----------------------------------
$L = @{
    ru = @{
        section = "ИНВЕНТАРЬ"; subject = "МЕСТО И ВЕС"
        inv = "ИНВЕНТАРЬ"; around = "ОКРУЖЕНИЕ"; floor = "Пол"; floorCap = "ПОЛ"; pockets = "КАРМАНЫ"; bag = "ШКОЛЬНЫЙ РЮКЗАК"
        space = "МЕСТО В РЮКЗАКЕ"; weight = "ВЕС РЮКЗАКА"; cells = "КЛЕТОК"; kg = "КГ"
        points = @(
            "Вещь занимает столько клеток, сколько места в ней на самом деле: куртка - 2x3, банка - одна.",
            "У рюкзака два предела: его клетки и его вес. Вес - как в обычной игре, школьный держит 15 кг.",
            "Одежда и еда лёгкие, но объёмные - они забирают место.",
            "Патроны, гвозди, инструменты тяжёлые - упрётесь в вес. Knox скажет, во что именно."
        )
        keys = @(@("R", "повернуть"), @("Shift+ЛКМ", "перенести"), @("Ctrl+S", "сортировать"))
        heavy = "Тяжело: {0} / 15 кг"
    }
    en = @{
        section = "INVENTORY"; subject = "SPACE AND WEIGHT"
        inv = "INVENTORY"; around = "SURROUNDINGS"; floor = "Floor"; floorCap = "FLOOR"; pockets = "POCKETS"; bag = "SCHOOL BAG"
        space = "BACKPACK SPACE"; weight = "BACKPACK WEIGHT"; cells = "CELLS"; kg = "KG"
        points = @(
            "An item takes as many cells as the room it really needs: a jacket is 2x3, a can is one.",
            "A backpack has two limits: its cells and its weight. Weight works as in the base game - a school bag holds 15 kg.",
            "Clothes and food are light but bulky - they eat the space.",
            "Ammo, nails and tools are heavy - you hit the weight first. Knox tells you which limit you hit."
        )
        keys = @(@("R", "rotate"), @("Shift+LMB", "move across"), @("Ctrl+S", "sort"))
        heavy = "Too heavy: {0} / 15 kg"
    }
}

# --- 1. inventory: space and weight ------------------------------------------------------
function GifSpaceWeight($lang) {
    $s = $L[$lang]
    BeginGif
    $cs = 36
    $mask = @("..####..", "..####..", "..####..", "#.####.#", "#.####.#", "#.####.#", "........", "..####..", "..####..")
    # the inventory column
    $ix = 14; $iy = 66; $iw = 384; $ih = 520
    $pocketGeo = BagGeo @("####", "####") ($ix + 14) ($iy + 50 + 36) $cs
    $bagY = $iy + 50 + 36 + 2 * $cs + 12 + 36 + 8
    $geo = BagGeo $mask 0 0 $cs
    $geo = BagGeo $mask ($ix + [int](($iw - $geo.w) / 2)) $bagY $cs
    # the surroundings column: its list (a row) and the floor's grid
    $sx = $ix + $iw + 10; $sw = 212
    $floorGeo = BagGeo @("#####", "#####", "#####", "#####", "#####", "#####", "#####", "#####", "#####") ($sx + 14 + 8) ($iy + 50 + 64 + 10 + 36) $cs
    $panelX = $sx + $sw + 10; $panelW = $W - $panelX - 14

    $start = @(
        @(2, 0, 1, 2, "food", "bottle", 0.7), @(3, 0, 1, 1, "wpn", "ammobox9", 1.2), @(4, 0, 1, 1, "wpn", "ammobox9", 1.2),
        @(5, 0, 1, 1, "mat", "nails", 1.0), @(3, 1, 1, 1, "mat", "screws", 1.0), @(4, 1, 2, 1, "tool", "hammer", 1.0),
        @(0, 3, 1, 2, "tool", "screwdriver", 0.3), @(7, 3, 1, 1, "food", "beans", 0.6), @(2, 7, 1, 2, "tool", "torch", 0.6),
        @(3, 7, 1, 1, "med", "pills", 0.2), @(4, 7, 2, 2, "tool", "toolbox", 3.3), @(3, 8, 1, 1, "med", "bandage", 0.1)
    )
    $kg0 = ($start | ForEach-Object { $_[6] } | Measure-Object -Sum).Sum
    $cells0 = ($start | ForEach-Object { $_[2] * $_[3] } | Measure-Object -Sum).Sum
    $total = 38
    $jacketKg = 1.4; $potKg = 2.6

    function Scene($g, $kg, $cells, $step, $jacketWhere, $potWhere, $kgRed = $false) {
        Fill $g $K.screen 0 0 $W $H
        PageHeader $g $s.section $s.subject 4 $step
        # inventory column: title, the character's load, the pockets and the bag
        Fill $g $K.window $ix $iy $iw $ih; Frame $g $K.border $ix $iy $iw $ih 1
        Txt $g $s.inv "title" 23 $K.bright ($ix + 14) ($iy + 16)
        Strip $g ($ix + 14) ($iy + 50) ($iw - 28) $s.pockets "4x2"
        DrawBag $g $pocketGeo
        BagTile $g $pocketGeo 0 0 1 1 "info" "idcard"; BagTile $g $pocketGeo 1 0 1 1 "misc" "keyring"; BagTile $g $pocketGeo 0 1 1 1 "misc" "wallet"
        Strip $g ($ix + 14) ($bagY - 44) ($iw - 28) $s.bag ("4x6+14  " + (Kg $kg $lang) + "/15 " + $s.kg) $(if ($kgRed) { $K.bad } else { $null })
        DrawBag $g $geo
        foreach ($t in $start) { BagTile $g $geo $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] }
        if ($jacketWhere -eq "bag") { BagTile $g $geo 2 2 2 3 "clo" "jacket" }
        # surroundings column
        Fill $g $K.window $sx $iy $sw $ih; Frame $g $K.border $sx $iy $sw $ih 1
        Txt $g $s.around "title" 23 $K.bright ($sx + 14) ($iy + 16)
        Row $g ($sx + 14) ($iy + 50) ($sw - 28) $s.floor "c_floor" "2" "full" $true
        Strip $g ($sx + 14) ($iy + 50 + 64 + 10) ($sw - 28) $s.floorCap "5x9"

        DrawBag $g $floorGeo
        # what else lies about (it stays where it is)
        BagTile $g $floorGeo 0 4 1 2 "info" "book"; BagTile $g $floorGeo 1 4 1 1 "misc" "rag"; BagTile $g $floorGeo 2 4 1 2 "food" "chips"
        BagTile $g $floorGeo 4 3 1 4 "wpn" "bat"; BagTile $g $floorGeo 1 5 1 1 "food" "apple"; BagTile $g $floorGeo 0 7 2 2 "clo" "trousers"
        BagTile $g $floorGeo 3 7 1 1 "tool" "battery"; BagTile $g $floorGeo 2 7 1 1 "misc" "toiletpaper"
        if ($jacketWhere -eq "floor") { BagTile $g $floorGeo 0 0 2 3 "clo" "jacket" }
        if ($jacketWhere -eq "floorHover") { HoverTile $g $floorGeo 0 0 2 3 "clo" "jacket" }
        if ($jacketWhere -eq "ghost") { BagTile $g $floorGeo 0 0 2 3 "clo" "jacket" "ghost" }
        if ($potWhere -eq "floor") { BagTile $g $floorGeo 3 0 2 2 "food" "pot_water" }
        if ($potWhere -eq "ghost") { BagTile $g $floorGeo 3 0 2 2 "food" "pot_water" "ghost" }
        # the panel: the points, the two limits, the keys
        Fill $g $K.window $panelX $iy $panelW $ih; Frame $g $K.border $panelX $iy $panelW $ih 1
        $py = Points $g ($panelX + 8) ($iy + 10) ($panelW - 16) $s.points $step
        $py += 8
        Meter2 $g ($panelX + 20) $py ($panelW - 40) $s.space ($cells / $total) ("$cells / $total " + $s.cells) $K.accent
        Meter2 $g ($panelX + 20) ($py + 46) ($panelW - 40) $s.weight ($kg / 15) ((Kg $kg $lang) + " / 15 " + $s.kg) $(if ($kgRed) { $K.bad } else { $K.accent })
    }

    # 1) the jacket under the mouse: a thing of 2x3 (2 s)
    for ($i = 0; $i -lt 24; $i++) {
        $bmp, $g = Canvas $W $H $K.screen
        Scene $g $kg0 $cells0 1 $(if ($i -ge 6) { "floorHover" } else { "floor" }) "floor"
        if ($i -ge 6) { Cursor $g ($floorGeo.colX[1] + 4) ($floorGeo.rowY[1] + 8) }
        Frame-Save $bmp $g 1
    }
    # 2) the two limits (2 s)
    $bmp, $g = Canvas $W $H $K.screen
    Scene $g $kg0 $cells0 2 "floor" "floor"
    Frame-Save $bmp $g 24
    # 3) the jacket goes in, by space (2.5 s)
    $from = @(($floorGeo.colX[0] + 8), ($floorGeo.rowY[0] + 8)); $to = @(($geo.colX[2] + 8), ($geo.rowY[2] + 8))
    for ($i = 0; $i -lt 18; $i++) {
        $t = Ease ($i / 17)
        $bmp, $g = Canvas $W $H $K.screen
        Scene $g $kg0 $cells0 3 "ghost" "floor"
        if ($t -gt 0.7) { DropMark $g $geo 2 2 2 3 $true }
        HeldAt $g (Lerp $from[0] $to[0] $t) (Lerp $from[1] $to[1] $t) 2 3 "clo" "jacket" $cs
        Frame-Save $bmp $g 1
    }
    $kg1 = $kg0 + $jacketKg; $cells1 = $cells0 + 6
    $bmp, $g = Canvas $W $H $K.screen
    Scene $g $kg1 $cells1 3 "bag" "floor"
    Frame-Save $bmp $g 14
    # 4) the pot of water: there is room, but it is too heavy (4 s)
    $from = @(($floorGeo.colX[3] + 8), ($floorGeo.rowY[0] + 8)); $to = @(($geo.colX[4] + 8), ($geo.rowY[3] + 8))
    for ($i = 0; $i -lt 16; $i++) {
        $t = Ease ($i / 15)
        $bmp, $g = Canvas $W $H $K.screen
        Scene $g $kg1 $cells1 4 "bag" "ghost"
        if ($t -gt 0.7) { DropMark $g $geo 4 3 2 2 $false }
        HeldAt $g (Lerp $from[0] $to[0] $t) (Lerp $from[1] $to[1] $t) 2 2 "food" "pot_water" $cs
        Frame-Save $bmp $g 1
    }
    $heavy = $s.heavy -f (Kg ($kg1 + $potKg) $lang)
    for ($i = 0; $i -lt 30; $i++) {
        $t = $i / 29
        $bmp, $g = Canvas $W $H $K.screen
        Scene $g $kg1 $cells1 4 "bag" "floor" ($i -lt 18)
        Halo $g $heavy ($geo.colX[4] + $cs) ($geo.rowY[3] - 34 - 26 * $t) (1 - [math]::Max(0, ($t - 0.65) / 0.35))
        Frame-Save $bmp $g 1
    }
    # hold (1.5 s)
    $bmp, $g = Canvas $W $H $K.screen
    Scene $g $kg1 $cells1 4 "bag" "floor"
    Frame-Save $bmp $g 18
    EndGif "space_weight_$lang"
}

$script:C = 64
foreach ($lang in "ru", "en") {
    Write-Host "page GIFs ($lang):"
    if (-not $Only -or $Only -eq "space_weight") { GifSpaceWeight $lang }
}
