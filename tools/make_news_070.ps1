# Pictures of the 0.7.0 news post (the TV and radio windows, the hands on the
# quick slots bar), made in 2026-10 by the approved news rules (see
# make_news_096.ps1 and news_ui.ps1): the windows as KnoxTVWindow / KnoxRadioWindow
# draw them (their layout at the 64 px cell, their own colours), the hands as
# KnoxHotbar draws them, the game's own words (a fishing tape's subtitles, a news
# broadcast on the tape) and icons, captions in capitals, a banner with no words.
#   42\media\knox\news\u070_<name>_<ru|en>.png   banner, art, tv, radio, hands
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_070.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

# the sets' own colours (KnoxTVWindow, KnoxRadioWindow)
$OSD = [System.Drawing.Color]::FromArgb(255, 158, 224, 138)
$TV_CAB = Hex "#2a2622"; $TV_EDGE = Hex "#3e3933"; $GLASS_ON = [System.Drawing.Color]::FromArgb(255, 13, 19, 20)
$KNOB = Hex "#242828"; $KNOB2 = Hex "#2c3030"; $LED_ON = [System.Drawing.Color]::FromArgb(255, 115, 217, 89)
$RD_CAB = Hex "#2b2219"; $RD_EDGE = Hex "#44362a"; $DIAL = Hex "#16120d"; $DIAL_EDGE = Hex "#4a3c2e"
$AMBER = [System.Drawing.Color]::FromArgb(255, 255, 181, 71); $SCALE = Hex "#8a7a60"
$PAPER = Hex "#e9e2cf"; $PAPER_EDGE = Hex "#b9ae92"; $INK = Hex "#3a342a"; $INK_DIM = Hex "#8a7f68"

$L = @{
    ru = @{
        tvTitle = "ТЕЛЕВИЗОР: ОКНО - ЭТО САМ ТЕЛЕВИЗОР"
        tvA = "ВСЁ, ЧТО ГОВОРЯТ В ПЕРЕДАЧЕ, ИДЁТ СУБТИТРАМИ НА ЭКРАНЕ. НАД ТЕЛЕВИЗОРОМ В МИРЕ ФРАЗЫ БОЛЬШЕ НЕ ВСПЛЫВАЮТ."
        tvB = "ОПЫТ И НАСТРОЕНИЕ ОТ ПЕРЕДАЧИ - ПЛАШКАМИ НА ЭКРАНЕ."
        tvC = "ВИДЕОМАГНИТОФОН: СЛОТ ДЛЯ КАССЕТЫ, ВОСПРОИЗВЕДЕНИЕ, ИЗВЛЕЧЕНИЕ."
        rdTitle = "РАДИО: ШКАЛА, ЛЕНТА ЭФИРА, РУЧКИ"
        rdA = "СТРЕЛКУ ТЯНУТ МЫШЬЮ ИЛИ КОЛЕСОМ. СОХРАНЁННЫЕ СТАНЦИИ - ЗЕЛЁНЫЕ МЕТКИ, «+» ЗАПОМИНАЕТ ЕЩЁ ОДНУ."
        rdB = "ЛЕНТА ПЕЧАТАЕТ ЭФИР С ВРЕМЕНЕМ - И С ЗАКРЫТЫМ ОКНОМ ТОЖЕ."
        rdC = "РАДИО В ДОМЕ, В МАШИНЕ И В РУКАХ."
        hdTitle = "РУКИ - НА ПАНЕЛИ БЫСТРЫХ СЛОТОВ"
        hdA = "ПРАВАЯ, ЛЕВАЯ, ДВУРУЧНОЕ ОРУЖИЕ - НА ОБЕ. ПРОЧНОСТЬ ПОЛОСКОЙ, ПАТРОНЫ В УГЛУ."
        hdB = "ЩЕЛЧОК - УБРАТЬ ИЗ РУКИ, ПКМ - МЕНЮ."
        handL = "Левая рука"; handR = "Правая рука"
        artTitle = "ОКНО ТЕЛЕВИЗОРА И РУКИ НА ПАНЕЛИ"
        skill = "Рыболовство"
    }
    en = @{
        tvTitle = "TV: THE WINDOW IS THE SET ITSELF"
        tvA = "EVERYTHING SAID IN A SHOW RUNS AS SUBTITLES ON THE SCREEN. THE LINES NO LONGER FLOAT OVER THE SET IN THE WORLD."
        tvB = "SKILLS AND MOODS A SHOW GIVES - AS PLATES ON THE SCREEN."
        tvC = "A VIDEO DECK: A TAPE SLOT, PLAY, EJECT."
        rdTitle = "RADIO: THE DIAL, THE BROADCAST TAPE, THE KNOBS"
        rdA = "DRAG THE NEEDLE WITH THE MOUSE OR THE WHEEL. SAVED STATIONS ARE GREEN MARKS, + SAVES ONE MORE."
        rdB = "THE TAPE PRINTS THE BROADCAST WITH THE TIME - ALSO WHILE THE WINDOW IS CLOSED."
        rdC = "RADIOS AT HOME, IN A CAR AND IN HAND."
        hdTitle = "THE HANDS - ON THE QUICK SLOTS BAR"
        hdA = "RIGHT, LEFT, A TWO-HANDED WEAPON ACROSS BOTH. CONDITION AS A BAR, ROUNDS IN THE CORNER."
        hdB = "CLICK - OUT OF THE HAND, RMB - ITS MENU."
        handL = "Left hand"; handR = "Right hand"
        artTitle = "THE TV'S WINDOW AND THE HANDS ON THE BAR"
        skill = "Fishing"
    }
}

# --- drawing pieces of the sets -------------------------------------------------------

function Btn($g, $x, $y, $w, $h, $text, $primary = $false, $px = 17) {
    if ($primary) { Fill $g $K.accent $x $y $w $h; if ($text) { TxtCentre $g $text "head" $px $K.ink $x $y $w $h } }
    else { Fill $g $K.buttonBg $x $y $w $h; Frame $g $K.tileFrame $x $y $w $h 1; if ($text) { TxtCentre $g $text "head" $px $K.bright $x $y $w $h } }
}
# a filled circle, row by row (as the sets draw it)
function Disc($g, $cx, $cy, $r, $col) {
    for ($dy = -$r; $dy -le $r; $dy++) {
        $half = [math]::Floor([math]::Sqrt($r * $r - $dy * $dy) + 0.5)
        Fill $g $col ($cx - $half) ($cy + $dy) ($half * 2 + 1) 1
    }
}
# a knob: rim, face, a notch at `angle` (radians, 0 = up)
function Knob($g, $cx, $cy, $r, $angle) {
    Disc $g $cx $cy $r $K.tileEdge
    Disc $g $cx $cy ($r - 2) $KNOB
    Disc $g $cx ($cy - 1) ($r - 6) $KNOB2
    $sx = [math]::Sin($angle); $sy = -[math]::Cos($angle)
    for ($t = [math]::Floor($r * 0.25); $t -le $r - 5; $t += 2) {
        Fill $g $K.text ([math]::Floor($cx + $sx * $t) - 1) ([math]::Floor($cy + $sy * $t) - 1) 3 3
    }
}
# a small triangle: right (play), up, down
function Tri($g, $x, $y, $s, $dir, $col) {
    for ($i = 0; $i -lt $s; $i++) {
        $len = $s * 2 - 1 - $i * 2
        if ($dir -eq "right") { Fill $g $col ($x + $i) ($y + $i) 1 $len }
        elseif ($dir -eq "up") { Fill $g $col ($x + $i) ($y + $s - 1 - $i) $len 1 }
        else { Fill $g $col ($x + $i) ($y + $i) $len 1 }
    }
}
# a power button with its lamp
function PowerBtn($g, $x, $y, $w, $h, $text) {
    Btn $g $x $y $w $h ""
    $ls = [math]::Floor($h * 0.32); $lx = $x + [math]::Floor($h * 0.35); $ly = $y + [math]::Floor(($h - $ls) / 2)
    Fill $g $LED_ON ($lx - 3) ($ly - 3) ($ls + 6) ($ls + 6) 0.18
    Fill $g $LED_ON $lx $ly $ls $ls
    TxtMid $g (Up $text) "head" 17 $K.text ($lx + $ls + 10) $y $h
}
# a plain window plate: the header with its caps title and a cross, the sand frame half-lit
function Plate($g, $x, $y, $w, $h, $title) {
    for ($i = 1; $i -le 4; $i++) { Fill $g $K.screen ($x + $i) ($y + 2 * $i) $w $h 0.1 }
    Fill $g $K.window $x $y $w $h
    Fill $g $K.header $x $y $w 44; Fill $g $K.border $x ($y + 44) $w 1
    TxtMid $g (Up $title) "head" 19 $K.bright ($x + 16) $y 44
    $bh = 28; $cx = $x + $w - 12 - $bh
    Fill $g $K.buttonBg $cx ($y + 8) $bh $bh; Frame $g $K.tileEdge $cx ($y + 8) $bh $bh 1
    Cross $g ($cx + $bh / 2) ($y + 8 + $bh / 2) 6 $K.bright
    Frame $g $K.accent $x $y $w $h 2 0.5
}

# The TV window (KnoxTVWindow layout at the 64 px cell): a tape playing - PLAY, its
# title, the clock, a skill plate, the line being said; the panel; the deck.
function TVWin($g, $lang, $s, $x0, $y0) {
    $cell = 64; $pad = 16; $hdr = 44   # (not $c: that is the cell $C)
    $bezel = [math]::Floor($cell * 0.3); $scrW = $cell * 7; $scrH = [math]::Floor($scrW * 0.72)
    $ctrlW = [math]::Floor($cell * 2.3); $btnH = 40; $deckH = [math]::Floor($cell * 1.15)
    $cab = @(($x0 + $pad), ($y0 + $hdr + $pad), ($bezel * 3 + $scrW + $ctrlW), ($bezel * 3 + $scrH + $deckH))
    $scr = @(($cab[0] + $bezel), ($cab[1] + $bezel), $scrW, $scrH)
    $px = $scr[0] + $scrW + $bezel; $pw = $ctrlW
    # the panel, top to bottom (its height may make the cabinet taller)
    $y = $scr[1]; $powerY = $y; $y += $btnH + $pad
    $chanCapY = $y; $y += 26; $kr = [math]::Floor($cell * 0.6); $chanKnobY = $y + $kr; $y += $kr * 2 + $pad
    $bs = [math]::Floor(($pw - 8) / 3); $bh = [math]::Floor($bs * 0.75); $btnY = $y; $y += 3 * ($bh + 4) + $pad
    $volCapY = $y; $y += 26; $volKnobY = $y + $kr; $y += $kr * 2 + 4; $volTextY = $y
    $extra = [math]::Max(0, ($y + 24) - ($scr[1] + $scrH + $bezel + $deckH))
    $cab[3] += $extra; $scr[3] += $extra
    $deck = @($scr[0], ($scr[1] + $scr[3] + $bezel), $scrW, $deckH)
    $w = $pad * 2 + $cab[2]; $h = $cab[1] - $y0 + $cab[3] + $pad
    Plate $g $x0 $y0 $w $h (GTr $lang "Moveables" "ValuTech_Television")
    Fill $g $TV_CAB $cab[0] $cab[1] $cab[2] $cab[3]; Frame $g $TV_EDGE $cab[0] $cab[1] $cab[2] $cab[3] 1
    Fill $g ([System.Drawing.Color]::White) ($cab[0] + 1) ($cab[1] + 1) ($cab[2] - 2) 1 0.06
    # the screen: glass, scan lines, the on-screen text, the subtitles
    $sx, $sy, $sw, $sh = $scr
    Fill $g $GLASS_ON $sx $sy $sw $sh
    for ($ly = $sy; $ly -lt $sy + $sh; $ly += 3) { Fill $g ([System.Drawing.Color]::Black) $sx $ly $sw 1 0.16 }
    $ox = $sx + $pad + 4; $oy = $sy + $pad; $fh = 26
    Tri $g $ox ($oy + 2) 13 "right" $OSD
    Txt $g "PLAY" "head" 26 $OSD ($ox + 21) $oy
    $title = GTr $lang "Recorded_Media" "RM_852a6c19-9f8a-4f84-a57d-48cb03993d19"
    Txt $g $title "head" 16 $OSD $ox ($oy + 38) 0.8
    Txt $g "21:50" "head" 26 $OSD ($sx + $sw - $pad - 4 - (TextW $g "21:50" "head" 26)) $oy
    # the skill the show gave: a plate with an arrow up
    $bt = $s.skill; $btw = (TextW $g $bt "head" 16) + 9 * 2 + 18; $bx = $sx + $sw - $pad - 4 - $btw; $by = $oy + 64
    $gc = $K.good
    Fill $g $gc $bx $by $btw 28 0.18; Frame $g $gc $bx $by $btw 28 1
    Txt $g $bt "head" 16 $gc ($bx + 6) ($by + 7)
    Tri $g ($bx + $btw - 22) ($by + 10) 6 "up" $gc
    # the line being said, the one before it fainter above
    $lines = @(@((GTr $lang "Recorded_Media" "RM_993d82d6-3ff3-4d1a-a952-d15869303ef5"), 0.55), @((GTr $lang "Recorded_Media" "RM_e19eb784-9676-4ac4-9f71-56831ade0edd"), 1.0))
    $yy = $sy + $sh - $pad
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $wrapped = @(WrapCaps $g $lines[$i][0] "body" 21 ($sw - $pad * 4))
        for ($j = $wrapped.Count - 1; $j -ge 0; $j--) {
            $tw = TextW $g $wrapped[$j] "body" 21; $yy -= 30
            $lx = $sx + ($sw - $tw) / 2
            Fill $g ([System.Drawing.Color]::Black) ($lx - 6) ($yy - 2) ($tw + 12) 28 (0.6 * $lines[$i][1])
            Txt $g $wrapped[$j] "body" 21 $OSD $lx ($yy + 4) $lines[$i][1]
        }
        $yy -= 6
    }
    Frame $g $TV_EDGE ($sx - 1) ($sy - 1) ($sw + 2) ($sh + 2) 1
    # the panel: power, channel knob and buttons, volume
    PowerBtn $g $px $powerY $pw $btnH (GTr $lang "ContextMenu" "ContextMenu_Turn_Off")
    Txt $g (Up (Tr $lang "IGUI_Knox_TVChannel")) "head" 17 $K.dim $px $chanCapY
    Knob $g ($px + $pw / 2) $chanKnobY $kr (-2.35 + 4.7 * 5 / 8)
    for ($i = 0; $i -lt 9; $i++) {
        $bx2 = $px + ($i % 3) * ($bs + 4); $by2 = $btnY + [math]::Floor($i / 3) * ($bh + 4)
        Btn $g $bx2 $by2 $bs $bh ([string]($i + 1)) ($i -eq 5) 17
    }
    Txt $g (Up (Tr $lang "IGUI_Knox_TVVolume")) "head" 17 $K.dim $px $volCapY
    Knob $g ($px + $pw / 2) $volKnobY $kr (-2.35 + 4.7 * 0.3)
    $vt = "3 / 10"; Txt $g $vt "body" 19 $K.dim ($px + ($pw - (TextW $g $vt "body" 19)) / 2) $volTextY
    # the deck: the tape in its slot, its title, stop and eject
    $dx, $dy, $dw, $dh = $deck
    Fill $g ([System.Drawing.Color]::Black) $dx $dy $dw $dh 0.35; Frame $g $TV_EDGE $dx $dy $dw $dh 1
    $ssh = $dh - $pad * 2; $ssw = [math]::Floor($ssh * 1.9)
    Fill $g $K.info ($dx + $pad) ($dy + $pad) $ssw $ssh
    DrawIcon $g "cassette3" ($dx + $pad) ($dy + $pad) $ssw $ssh 1 ([math]::Floor($ssh * 0.85))
    Frame $g $K.tileFrame ($dx + $pad) ($dy + $pad) $ssw $ssh 2
    $ej = $dx + $dw - $pad - $btnH; $pl = $ej - 4 - $btnH; $bty = $dy + ($dh - $btnH) / 2
    Btn $g $pl $bty $btnH $btnH "" $true
    $q = [math]::Floor($btnH * 0.28)
    Fill $g $K.ink ($pl + $btnH / 2 - $q) ($bty + $btnH / 2 - $q) ($q * 2) ($q * 2)
    Btn $g $ej $bty $btnH $btnH ""
    Tri $g ($ej + $btnH / 2 - $q + 1) ($bty + $btnH / 2 - $q) $q "up" $K.text
    Fill $g $K.text ($ej + $btnH / 2 - $q + 1) ($bty + $btnH / 2 + 2) ($q * 2 - 1) 3
    $tx = $dx + $pad + $ssw + $pad
    $tt = $title; $maxW = $pl - $pad - $tx
    while ((TextW $g $tt "body" 20) -gt $maxW -and $tt.Length -gt 4) { $tt = $tt.Substring(0, $tt.Length - 2) }
    if ($tt -ne $title) { $tt = $tt.TrimEnd() + ".." }
    TxtMid $g $tt "body" 20 $K.bright $tx $dy $dh
    return @{w = $w; h = $h}
}

# The radio window (KnoxRadioWindow layout at the 64 px cell): the dial at 98.0 with
# three saved stations, the tape of a news broadcast, the knobs and the station
# buttons, the battery, headphones and the power switch.
function RadioWin($g, $lang, $x0, $y0) {
    $cell = 64; $pad = 16; $hdr = 44   # (not $c: that is the cell $C)
    $bezel = [math]::Floor($cell * 0.3); $innerW = $cell * 10; $btnH = 40; $ctrlW = [math]::Floor($cell * 2.6)
    $tapeW = $innerW - $ctrlW - $bezel
    $cx0 = $x0 + $pad; $cy0 = $y0 + $hdr + $pad
    $ix = $cx0 + $bezel; $y = $cy0 + $bezel
    $dialR = @($ix, $y, $innerW, [math]::Floor($cell * 1.7)); $y += $dialR[3] + $bezel   # (not $dial: that is the colour $DIAL)
    $tape = @($ix, $y, $tapeW, [math]::Floor($cell * 3.6)); $panel = @(($ix + $tapeW + $bezel), $y, $ctrlW, $tape[3])
    $y += $tape[3] + $bezel; $stH = $btnH + 8; $strip = @($ix, $y, $innerW, $stH); $y += $stH + $bezel
    $cab = @($cx0, $cy0, ($innerW + $bezel * 2), ($y - $cy0))
    $w = $pad * 2 + $cab[2]; $h = $cab[1] - $y0 + $cab[3] + $pad
    Plate $g $x0 $y0 $w $h (GTr $lang "Moveables" "ValuTech_Radio")
    Fill $g $RD_CAB $cab[0] $cab[1] $cab[2] $cab[3]; Frame $g $RD_EDGE $cab[0] $cab[1] $cab[2] $cab[3] 1
    Fill $g ([System.Drawing.Color]::White) ($cab[0] + 1) ($cab[1] + 1) ($cab[2] - 2) 1 0.06
    # the dial: the scale 88..108, the saved stations, the needle, the readout, the signal
    $dx, $dy, $dw, $dh = $dialR
    Fill $g $DIAL $dx $dy $dw $dh; Frame $g $DIAL_EDGE $dx $dy $dw $dh 1
    Fill $g $AMBER ($dx + 1) ($dy + 1) ($dw - 2) ($dh - 2) 0.06
    $scX = $dx + $pad; $scW = $dw - $pad * 2
    $sy = $dy + [math]::Floor($dh * 0.22); $tickH = [math]::Floor($dh * 0.22)
    for ($f = 88.0; $f -le 108.001; $f += 0.8) {
        $xx = $scX + [math]::Floor($scW * ($f - 88) / 20 + 0.5)
        $major = [math]::Abs(($f - 88) / 4 - [math]::Round(($f - 88) / 4)) -lt 0.01
        $hh = $(if ($major) { $tickH } else { [math]::Floor($tickH / 2) })
        Fill $g $SCALE $xx ($sy + $tickH - $hh) 1 $hh
        if ($major) { $lb = [string][math]::Round($f); $lw = TextW $g $lb "head" 15; Txt $g $lb "head" 15 $SCALE ($xx - $lw / 2) ($sy + $tickH + 6) }
    }
    foreach ($st in 93.2, 98.0, 101.4) {
        $xx = $scX + [math]::Floor($scW * ($st - 88) / 20 + 0.5)
        Fill $g $K.good ($xx - 7) ($sy - 9) 15 7
    }
    $nx = $scX + [math]::Floor($scW * 10 / 20 + 0.5)
    Fill $g $AMBER ($nx - 3) ($dy + 3) 7 ($dh - 6) 0.12
    Fill $g $AMBER ($nx - 1) ($dy + 3) 2 ($dh - 6)
    $ry = $dy + $dh - 28
    Txt $g "98.0 MHz  NNR Radio" "body" 20 $AMBER ($dx + $pad) ($ry + 2)
    $bx = $dx + $dw - $pad - 24
    for ($i = 1; $i -le 4; $i++) { $bh = 3 + $i * 3; Fill $g $AMBER ($bx + ($i - 1) * 6) ($ry + 22 - $bh) 4 $bh }
    # the tape: ruled paper, times and lines of the broadcast
    $tx, $ty, $tw, $th = $tape
    Fill $g $PAPER $tx $ty $tw $th; Frame $g $PAPER_EDGE $tx $ty $tw $th 1
    $rowH = 30
    for ($ly = $ty + $pad + $rowH - 2; $ly -lt $ty + $th - 4; $ly += $rowH) { Fill $g ([System.Drawing.Color]::Black) ($tx + 2) $ly ($tw - 4) 1 0.06 }
    $timeW = (TextW $g "00:00" "body" 19) + 10
    $said = @(@("09:00", "RD_2d3855e9-5a1b-4bf7-9e06-dfa73f4cbc5c"), @("09:10", "RD_a56e1c08-f308-4c7c-a256-f1231095dccf"),
              @("09:10", "RD_2d83c263-4c78-48c0-a0cc-bbc0c87e876d"), @("09:20", "RD_4db8924f-f5f8-4f46-850a-14513174b751"))
    $rows = @()
    foreach ($e in $said) {
        $first = $true
        foreach ($line in @(WrapCaps $g (GTr $lang "RadioData" $e[1]) "body" 19 ($tw - $pad * 2 - $timeW))) {
            $rows += , @($(if ($first) { $e[0] } else { "" }), $line); $first = $false
        }
    }
    $visible = [math]::Floor(($th - $pad * 2) / $rowH)
    $start = [math]::Max(0, $rows.Count - $visible)
    $yy = $ty + $pad
    for ($i = $start; $i -lt $rows.Count; $i++) {
        if ($rows[$i][0]) { Txt $g $rows[$i][0] "body" 19 $INK_DIM ($tx + $pad) ($yy + 4) }
        Txt $g $rows[$i][1] "body" 19 $INK ($tx + $pad + $timeW) ($yy + 4)
        $yy += $rowH
    }
    # the panel: tuning and volume knobs, their values, the station buttons
    $px, $py, $pw = $panel[0], $panel[1], $panel[2]
    $kr = [math]::Floor($cell * 0.5); $ky = $py + 26 + $kr
    $k1 = $px + [math]::Floor($pw / 4); $k2 = $px + [math]::Floor($pw * 3 / 4)
    foreach ($kk in @(@($k1, (Tr $lang "IGUI_Knox_RadioTuning"), 0.5, "98.0"), @($k2, (Tr $lang "IGUI_Knox_TVVolume"), 0.8, "8 / 10"))) {
        # (the caption no wider than half the panel: the Russian words are long)
        $cap = Up $kk[1]; $cpx = 16
        while ((TextW $g $cap "head" $cpx) -gt ($pw / 2 - 6) -and $cpx -gt 11) { $cpx-- }
        $cw = TextW $g $cap "head" $cpx
        Txt $g $cap "head" $cpx $K.dim ($kk[0] - $cw / 2) ($py + (16 - $cpx) / 2)
        Knob $g $kk[0] $ky $kr (-2.35 + 4.7 * $kk[2])
        $vw = TextW $g $kk[3] "body" 19; Txt $g $kk[3] "body" 19 $K.dim ($kk[0] - $vw / 2) ($ky + $kr + 6)
    }
    $pby = $ky + $kr + 6 + 24 + $pad
    $bs = [math]::Floor(($pw - 12) / 4); $bh = [math]::Floor($bs * 0.75)
    $labels = @("1", "2", "3", "+")
    for ($i = 0; $i -lt 4; $i++) { Btn $g ($px + $i * ($bs + 4)) $pby $bs $bh $labels[$i] ($i -eq 1) 16 }
    # the strip: battery with its charge, headphones (empty), the power switch
    $sx, $sy2, $sw, $sh = $strip
    $slotW = [math]::Floor($sh * 1.5)
    Fill $g $K.cell $sx $sy2 $slotW $sh; DrawIcon $g "battery" $sx $sy2 $slotW $sh 1 ([math]::Floor($sh * 0.8)); Frame $g $K.tileFrame $sx $sy2 $slotW $sh 2
    TxtMid $g "98%" "body" 20 $K.good ($sx + $slotW + 8) $sy2 $sh
    $hx = $sx + $slotW + 8 + (TextW $g "100%" "body" 20) + $pad
    Fill $g $K.cell $hx $sy2 $slotW $sh; DrawIcon $g "headphones" $hx $sy2 $slotW $sh 0.18 ([math]::Floor($sh * 0.8)); Frame $g $K.tileEdge $hx $sy2 $slotW $sh 2
    $off = GTr $lang "ContextMenu" "ContextMenu_Turn_Off"
    $pwW = (TextW $g (Up $off) "head" 17) + 40 + $btnH
    PowerBtn $g ($sx + $sw - $pwW) ($sy2 + 4) $pwW $btnH $off
    return @{w = $w; h = $h}
}

# The hands on the quick slots bar (KnoxHotbar): the left hand empty (a palm), the
# right one holding a pistol (condition along the bottom, rounds in the corner), a
# line, then the slots.
function HandsBar($g, $lang, $s, $x, $y) {
    $size = 75; $gap = 10
    $w = $size * 2 + $gap + $gap * 3 + 5 * ($size + $gap) + 8
    Fill $g $K.window ($x - 8) ($y - 8) $w ($size + 16); Frame $g $K.border ($x - 8) ($y - 8) $w ($size + 16) 1
    # the left hand: an open palm, grey
    Fill $g $K.cell $x $y $size $size; Frame $g $K.tileEdge $x $y $size $size 1
    $ps = [math]::Floor($size * 0.6); DrawPic $g (Join-Path $ui "knox_hand_left.png") ($x + ($size - $ps) / 2) ($y + ($size - $ps) / 2) $ps $ps 0.28 $true
    # the right hand: a pistol, in a sand frame
    $rx = $x + $size + $gap
    Fill $g $K.wpn $rx $y $size $size
    DrawIcon $g "pistol" $rx $y $size $size 1 ([math]::Floor($size * 0.66))
    Fill $g $K.line ($rx + 4) ($y + $size - 7) ($size - 8) 3; Fill $g $K.good ($rx + 4) ($y + $size - 7) (($size - 8) * 0.8) 3
    $am = "12/30"; Txt $g $am "head" 15 $K.bright ($rx + $size - 5 - (TextW $g $am "head" 15)) ($y + $size - 30)
    Frame $g $K.accent $rx $y $size $size 2
    # the line between the hands and the slots
    $lx = $rx + $size + $gap * 2
    Fill $g $K.border $lx ($y + 8) 1 ($size - 16)
    $qx = $lx + $gap + 1
    $slots = @(@("wpn", "bat"), @("wpn", "knife"), @("tool", "hammer"), $null, $null)
    for ($i = 0; $i -lt 5; $i++) {
        Fill $g $K.cell $qx $y $size $size
        if ($slots[$i]) {
            Fill $g $K[$slots[$i][0]] $qx $y $size $size
            DrawIcon $g $slots[$i][1] $qx $y $size $size 1 ([math]::Floor($size * 0.66))
            Frame $g $K.tileFrame $qx $y $size $size 2
        } else { Frame $g $K.tileEdge $qx $y $size $size 1 }
        Txt $g ([string]($i + 1)) "head" 14 $K.dim ($qx + 5) ($y + 4)
        $qx += $size + $gap
    }

    return $w
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.7.0 ($lang):"

    # --- the TV
    $bmp, $g = Canvas 1280 640 $K.screen
    Caption $g $s.tvTitle 24 26
    $tv = TVWin $g $lang $s 24 76
    $yb = CapsBlock $g $s.tvA 744 96 512
    $yb = CapsBlock $g $s.tvB 744 ($yb + 14) 512
    CapsBlock $g $s.tvC 744 ($yb + 14) 512 | Out-Null
    Save $bmp $g "u070_tv_$lang.png"

    # --- the radio
    $bmp, $g = Canvas 1280 660 $K.screen
    Caption $g $s.rdTitle 24 26
    $rd = RadioWin $g $lang 24 76
    $yb = CapsBlock $g $s.rdA 772 96 484
    $yb = CapsBlock $g $s.rdB 772 ($yb + 14) 484
    CapsBlock $g $s.rdC 772 ($yb + 14) 484 | Out-Null
    Save $bmp $g "u070_radio_$lang.png"

    # --- the hands
    $bmp, $g = Canvas 1280 270 $K.screen
    Caption $g $s.hdTitle 24 26
    Txt $g (Up (Tr $lang "IGUI_Knox_QuickSlots")) "head" 17 $K.dim 40 96
    HandsBar $g $lang $s 48 136 | Out-Null
    $yb = CapsBlock $g $s.hdA 740 120 516
    CapsBlock $g $s.hdB 740 ($yb + 14) 516 | Out-Null
    Save $bmp $g "u070_hands_$lang.png"

    # --- art: the TV, and the hands bar under it
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 60 56 26
    # (the set and the bar under it as one block, in the middle under the caption)
    $probe, $pg0 = Canvas 960 1080 $K.cell
    $th0 = (TVWin $pg0 $lang $s 60 0).h
    $pg0.Dispose(); $probe.Dispose()
    $top = 110 + [math]::Max(0, [math]::Floor((1080 - 110 - 30 - ($th0 + 80 + 91)) / 2))
    $tv = TVWin $g $lang $s 60 $top
    $hy = $top + $tv.h + 80
    Txt $g (Up (Tr $lang "IGUI_Knox_QuickSlots")) "head" 17 $K.dim 60 ($hy - 44)
    HandsBar $g $lang $s 68 $hy | Out-Null
    Save $bmp $g "u070_art_$lang.png"

    # --- banner: sets, tapes and what they take
    BannerPattern "u070_banner_$lang.png" @(
        @(7, 0, 2, 2, "tool", "tv", ""), @(9, 0, 1, 1, "info", "cassette", ""), @(10, 0, 2, 2, "tool", "radio", "hit"),
        @(12, 0, 1, 1, "tool", "battery", ""), @(13, 0, 1, 2, "tool", "walkie", ""), @(14, 0, 1, 1, "info", "disc", "hit"),
        @(15, 0, 2, 1, "tool", "headphones", ""), @(7, 2, 1, 1, "info", "cassette2", ""), @(8, 2, 1, 1, "info", "cassette3", ""),
        @(11, 2, 1, 1, "tool", "microphone", ""), @(15, 1, 2, 2, "tool", "tv", "")
    )
}
