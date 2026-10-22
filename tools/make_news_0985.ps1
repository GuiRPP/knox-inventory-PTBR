# Pictures of the 0.9.8.5 news post (Signal: the radio by the fire, the camp
# alive), by the approved news rules (see make_news_096.ps1 and news_ui.ps1):
# pieces of the Knox screen itself (here the radio's card, drawn as
# KnoxMenuMusic.lua lays it out, with the mod's own icons), captions in
# capitals, a banner with no words, a picture per language.
#   42\media\knox\newsঅ_<name>_<ru|en>.png   banner, art, radio
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_0985.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")
$musicIcons = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui"

$L = @{
    ru = @{
        raTitle = "РАДИО У КОСТРА"
        raA = "НАВЕДИТЕ МЫШЬ НА РАДИО В ЛАГЕРЕ - ПОЯВИТСЯ ЕГО КАРТОЧКА."
        raB = "СВОЯ МУЗЫКА: ПОЛОЖИТЕ ФАЙЛЫ В ПАПКУ ZOMBOID/KNOX_MUSIC (КНОПКА С ПАПКОЙ ОТКРОЕТ ЕЁ). КАЖДАЯ ПОДПАПКА - СВОЙ ПЛЕЙЛИСТ."
        raC = "КНОПКА С РАДИО: МУЗЫКА ИГРАЕТ ИЗ ЕГО ДИНАМИКА - ГЛУХО, С ШИПЕНИЕМ, С ЗАМИРАНИЕМ ЭФИРА."
        raD = "ПОВТОР, СЛУЧАЙНЫЙ ПОРЯДОК, ПЕРЕМОТКА, ГРОМКОСТЬ И СПИСОК ТРЕКОВ. ВСЁ ЗАПОМИНАЕТСЯ."
        artTitle = "СИГНАЛ"
        hint = "Музыка звучит из радио"
    }
    en = @{
        raTitle = "THE RADIO BY THE FIRE"
        raA = "REST THE MOUSE ON THE RADIO IN THE CAMP - ITS CARD COMES UP."
        raB = "YOUR OWN MUSIC: PUT FILES IN ZOMBOID/KNOX_MUSIC (THE FOLDER BUTTON OPENS IT). EACH SUBFOLDER IS A PLAYLIST OF ITS OWN."
        raC = "THE RADIO BUTTON: THE MUSIC PLAYS FROM ITS SPEAKER - MUFFLED, HISSING, FADING IN AND OUT OF THE AIR."
        raD = "REPEAT, SHUFFLE, SEEK, VOLUME AND THE TRACK LIST. EVERYTHING IS REMEMBERED."
        artTitle = "SIGNAL"
        hint = "The music plays from the radio"
    }
}

# one of the player's icons (smooth white, 64 px), tinted as the card tints it
function TintIcon($g, $name, $x, $y, $s, $c, $a = 1) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $musicIcons ("knox_music_" + $name + ".png")))
    $cm = New-Object System.Drawing.Imaging.ColorMatrix
    $cm.Matrix00 = [float]($c.R / 255); $cm.Matrix11 = [float]($c.G / 255); $cm.Matrix22 = [float]($c.B / 255); $cm.Matrix33 = [float]$a
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetColorMatrix($cm)
    $im = $g.InterpolationMode; $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$s), ([int]$s)), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.InterpolationMode = $im
    $img.Dispose()
}

# the radio's card as KnoxMenuMusic.lua lays it out (RC:layout), at the cell $cl;
# returns its height
function RadioCard($g, $x0, $y0, $cl, $lang, $hintLine = $null) {
    $pad = [math]::Round($cl * 0.19); $f = [math]::Max(3, [math]::Round($cl / 16))
    $w = [math]::Floor($cl * 6.6); $inX = $x0 + $f + $pad; $inW = $w - 2 * ($f + $pad)
    $ps = [math]::Floor($cl * 1.25); $btn = [math]::Floor($cl * 0.7); $icon = [math]::Floor($btn * 0.56)
    $ft = [math]::Round($cl * 0.25); $fh = [math]::Round($cl * 0.42); $fn = [math]::Round($cl * 0.31)
    $rowH = [math]::Round($fn * 1.25 + $pad / 2 + 2)
    # (the height first: the window under everything)
    $tracks = @("Night Road", "Old Highway", "Embers", "Last Broadcast", "Rain on Tin")
    $h = $f + $pad + $ps + $pad + 18 + 2 + $ft + $pad + $btn + $pad + [math]::Max($icon, 16) + $pad + $tracks.Count * $rowH + $pad + $btn + $pad + $f
    Fill $g $K.window $x0 $y0 $w $h 0.96
    Frame $g $K.accent $x0 $y0 $w $h $f
    $y = $y0 + $f + $pad
    # head: the radio in its square, lit; the title, the theme, which of how many
    Fill $g $K.cell $inX $y $ps $ps; Frame $g $K.tileFrame $inX $y $ps $ps 2
    $is = [math]::Floor($ps * 0.62)
    TintIcon $g "radio" ($inX + ($ps - $is) / 2) ($y + ($ps - $is) / 2) $is $K.accent
    $tx = $inX + $ps + $pad
    $theme = (Tr $lang "IGUI_KnoxMusic_mine") + "   1 / " + $tracks.Count
    $line2 = $(if ($hintLine) { $hintLine } else { $theme })
    $blockH = $fh * 0.72 + 10 + $ft * 0.72
    $ty = $y + ($ps - $blockH) / 2
    Txt $g $tracks[0] "title" $fh $K.bright $tx $ty
    Txt $g $line2 "body" $ft $K.accent $tx ($ty + $fh * 0.72 + 10)
    $y += $ps + $pad
    # seek: the line, its knob, the times
    Fill $g $K.cell $inX ($y + 6) $inW 6
    $frac = 0.38
    Fill $g $K.accent $inX ($y + 6) ([math]::Floor($inW * $frac)) 6 0.85
    Fill $g $K.accent ($inX + [math]::Floor($inW * $frac) - 3) ($y + 2) 6 14
    $y += 18 + 2
    TxtMid $g "1:52" "head" $ft $K.dim $inX $y $ft
    TxtMid $g "4:37" "head" $ft $K.dim ($inX + $inW - (TextW $g "4:37" "head" $ft)) $y $ft
    $y += $ft + $pad
    # the buttons: repeat (on), shuffle, back, pause, next, the radio (on)
    $names = @("loop", "shuffle", "prev", "play", "next", "radio")
    $icons = @("repeat", "shuffle", "prev", "pause", "next", "radio")
    $on = @($true, $false, $false, $false, $false, $true)
    $gap = ($inW - $btn * 6) / 5
    $cols = @()
    for ($i = 0; $i -lt 6; $i++) {
        $bx = [math]::Floor($inX + $i * ($btn + $gap) + 0.5); $cols += $bx
        Fill $g $(if ($on[$i]) { $K.accent } else { $K.cell }) $bx $y $btn $btn
        Frame $g $K.tileFrame $bx $y $btn $btn 2
        TintIcon $g $icons[$i] ($bx + ($btn - $icon) / 2) ($y + ($btn - $icon) / 2) $icon $(if ($on[$i]) { $K.ink } else { $K.text })
    }
    $y += $btn + $pad
    # the volume: the speaker under the first button, the line, the per cent
    $vh = [math]::Max($icon, 16)
    TintIcon $g "vol3" ($cols[0] + ($btn - $icon) / 2) ($y + ($vh - $icon) / 2) $icon $K.text
    $numW = TextW $g "100%" "head" $ft
    $vx = $cols[1]; $vw = $inX + $inW - $numW - $pad - $vx; $vy = $y + ($vh - 6) / 2
    Fill $g $K.cell $vx $vy $vw 6; Fill $g $K.accent $vx $vy ([math]::Floor($vw * 0.8)) 6 0.85
    Fill $g $K.accent ($vx + [math]::Floor($vw * 0.8) - 3) ($vy - 4) 6 14
    TxtMid $g "80%" "head" $ft $K.dim ($inX + $inW - (TextW $g "80%" "head" $ft)) $y $vh
    $y += $vh + $pad
    # the tracks: the one playing marked with a sand bar
    $half = [math]::Floor($pad / 2); $numCol = (TextW $g "00" "head" $ft) + $half
    for ($i = 0; $i -lt $tracks.Count; $i++) {
        $ry = $y + $i * $rowH
        if ($i -eq 0) { Fill $g $K.cell $inX $ry $inW $rowH; Fill $g $K.accent $inX $ry 3 $rowH }
        $x1 = $inX + 3 + $half
        TxtMid $g ("0" + ($i + 1)) "head" $ft $(if ($i -eq 0) { $K.accent } else { $K.dim }) $x1 $ry $rowH
        TxtMid $g $tracks[$i] "body" $fn $(if ($i -eq 0) { $K.bright } else { $K.text }) ($x1 + $numCol) $ry $rowH
    }
    $y += $tracks.Count * $rowH + $pad
    # the themes on the buttons' columns, the folder under the radio's button
    $chipW = $cols[1] + $btn - $cols[0]
    $game = Up (Tr $lang "IGUI_KnoxMusic_Chip_game"); $mine = Up (Tr $lang "IGUI_KnoxMusic_Chip_mine")
    Fill $g $K.cell $cols[0] $y $chipW $btn; Frame $g $K.tileFrame $cols[0] $y $chipW $btn 2
    TxtCentre $g $game "head" $ft $K.text $cols[0] $y $chipW $btn
    Fill $g $K.accent $cols[2] $y $chipW $btn; Frame $g $K.accent $cols[2] $y $chipW $btn 2
    TxtCentre $g $mine "head" $ft $K.ink $cols[2] $y $chipW $btn
    Fill $g $K.cell $cols[5] $y $btn $btn; Frame $g $K.tileFrame $cols[5] $y $btn $btn 2
    TintIcon $g "folder" ($cols[5] + ($btn - $icon) / 2) ($y + ($btn - $icon) / 2) $icon $K.text
    return $h
}

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "news pictures 0.9.8.5 ($lang):"

    # --- the radio's card, with what it does
    $bmp, $g = Canvas 1280 720 $K.screen
    Caption $g $s.raTitle 24 26
    $cardH = RadioCard $g 40 84 80 $lang
    $tx = 40 + [math]::Floor(80 * 6.6) + 48; $ty = 110; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.raA $tx $ty $tw 19
    $ty = CapsBlock $g $s.raB $tx ($ty + 16) $tw 19
    $ty = CapsBlock $g $s.raC $tx ($ty + 16) $tw 19
    CapsBlock $g $s.raD $tx ($ty + 16) $tw 19 | Out-Null
    Save $bmp $g "u0985_radio_$lang.png"

    # --- art: the card, big, on the frame's colour, a faint air of waves behind it
    $bmp, $g = Canvas 960 1080 $K.cell
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    for ($r = 1; $r -le 9; $r++) {
        $pen = New-Object System.Drawing.Pen (A $K.accent (0.10 - $r * 0.009)), 3
        $rad = 120 + $r * 70
        $g.DrawArc($pen, [float](480 - $rad), [float](540 - $rad), [float](2 * $rad), [float](2 * $rad), -60, 120)
        $g.DrawArc($pen, [float](480 - $rad), [float](540 - $rad), [float](2 * $rad), [float](2 * $rad), 120, 120)
    }
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    Caption $g $s.artTitle 64 56 30 $K.accent
    $cl = 120; $cw = [math]::Floor($cl * 6.6)
    RadioCard $g ((960 - $cw) / 2) 150 $cl $lang $s.hint | Out-Null
    Save $bmp $g "u0985_art_$lang.png"

    # --- banner, no words: a radio's tuning dial in the dark, its needle lit,
    # darkest on the left where the card writes its title
    $bmp, $g = Canvas 912 204 $K.screen
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    Fill $g $K.window 0 46 912 112
    Fill $g $K.border 0 46 912 2; Fill $g $K.border 0 156 912 2
    for ($x = 6; $x -lt 912; $x += 9) {
        $long = (($x - 6) / 9) % 5 -eq 0
        Fill $g $K.tileFrame $x $(if ($long) { 66 } else { 76 }) 2 $(if ($long) { 30 } else { 14 }) $(if ($long) { 0.9 } else { 0.55 })
    }
    # the air: a slow wave along the dial, sand, faint
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    for ($x = 0; $x -le 912; $x += 4) { $pts.Add((New-Object System.Drawing.PointF ([float]$x), ([float](124 + 10 * [math]::Sin($x / 23.0) * [math]::Sin($x / 97.0))))) }
    $g.DrawLines((New-Object System.Drawing.Pen (A $K.accent 0.35), 2), $pts.ToArray())
    # the needle, on a station
    $nx = 700
    foreach ($gw in 40, 26, 14) { Fill $g $K.accent ($nx - $gw / 2) 50 $gw 104 (0.05) }
    Fill $g $K.accent ($nx - 2) 50 4 104
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $rect = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $rect)
    Save $bmp $g "u0985_banner_$lang.png"
}
