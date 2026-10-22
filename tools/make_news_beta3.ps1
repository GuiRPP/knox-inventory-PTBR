# Pictures of the 1.0 BETA's update 3 news post ("Behind the wheel"), by the approved news
# rules (see make_news_096.ps1 and news_ui.ps1): pieces of the Knox screen itself,
# captions in capitals, a banner with no words, a picture per language.
# The dashboard is not drawn anew here: it is KnoxDashboard's own drawing - tools\dash
# runs the panel on the game's Lua and writes down every draw (test.ps1 -snap), snap.ps1
# paints them with the panel's own pictures (media\ui\knoxdash) - at 1440p, the 64 px
# cell of every news picture. The settings are news_ui's window with the mod's own strings.
#   42\media\knox\news\b3_<name>_<ru|en>.png
#   banner 912x204, art 960x1080, radio, music (1280 wide)
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_beta3.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

$L = @{
    ru = @{
        dashTitle = "ПРИБОРНАЯ ПАНЕЛЬ - КАК В НАСТОЯЩЕЙ МАШИНЕ"
        dashA = "У ДВЕРИ РУЧКА ФАР И КЛАВИША ЗАМКОВ. ПЕРЕД ВОДИТЕЛЕМ ТАХОМЕТР, СПИДОМЕТР С ПЕРЕДАЧЕЙ И КРУИЗОМ, ТОПЛИВО СО СТОРОНОЙ ЛЮЧКА, ЛАМПЫ ЗА СТЕКЛОМ."
        dashB = "НОЧЬЮ ШКАЛЫ ПОДСВЕЧЕНЫ ОТ ФАР. СТРЕЛКИ НА ПРУЖИНАХ, ЛАМПЫ ЗАГОРАЮТСЯ ПО ОЧЕРЕДИ, ПРИ УДАРЕ ПАНЕЛЬ ВЗДРАГИВАЕТ."
        dashC = "ЗАМОК НА КОЛОНКЕ: ЛЕВАЯ КНОПКА - ЗАВЕСТИ И ЗАГЛУШИТЬ, ПРАВАЯ - ВЫНУТЬ КЛЮЧ."
        truckTitle = "ДВА КОРПУСА: СЕДАН И ПИКАП"
        truckA = "ПИКАПЫ, ФУРГОНЫ, ВНЕДОРОЖНИКИ И АВТОБУСЫ ПОЛУЧАЮТ ГРУБУЮ ПАНЕЛЬ: ВЫТЯЖНАЯ РУЧКА ФАР, ПОЛОСА С БОЛТАМИ, РЯД ПЕРЕДАЧ."
        truckB = "БЕЗ КЛЮЧА ИЗ ЗАМКА ТОРЧАТ ПРОВОДА - ОНИ ИСКРЯТ, ПОКА ДВИГАТЕЛЬ ЗАВОДИТСЯ."
        radioTitle = "МАГНИТОЛА И КАССЕТА"
        radioA = "VOL, TUNE, ДИСПЛЕЙ, СТАНЦИИ 1-6, SEEK, FM И TAPE - КАК У НАСТОЯЩЕЙ."
        radioB = "СВОЯ МУЗЫКА - ЭТО КАССЕТА: ЩЕЛЧОК ПО ЩЕЛИ ВСТАВЛЯЕТ, «ИЗВЛЕЧЬ» ВЫТАЛКИВАЕТ. КАТУШКИ КРУТЯТСЯ, ПОКА ИГРАЕТ."
        radioC = "КОЛЕСО МЫШИ: ГРОМКОСТЬ, СТАНЦИЯ, ТРЕК. ЩЕЛЧОК ПО ДИСПЛЕЮ - КАРТОЧКА РАДИО."
        musicTitle = "МУЗЫКА В МАШИНЕ"
        musicA = "ВЫШЛИ ИЗ МАШИНЫ - МУЗЫКА ИГРАЕТ В НЕЙ: ТИШЕ С РАССТОЯНИЕМ, ГЛУХО ЧЕРЕЗ КУЗОВ, ЗВОНЧЕ ПРИ ОТКРЫТОЙ ДВЕРИ."
        musicB = "ОСТАВИЛИ МУЗЫКУ В ОДНОЙ МАШИНЕ И СЕЛИ ЗА РУЛЬ ДРУГОЙ - ИГРАЮТ ОБЕ."
        musicC = "В СЕТЕВОЙ ИГРЕ ЕЁ СЛЫШАТ ИГРОКИ РЯДОМ С МАШИНОЙ. НЕДОСТАЮЩИЙ ФАЙЛ ИДЁТ ЧЕРЕЗ СЕРВЕР, ИМЕНА ФАЙЛОВ НЕ ПЕРЕДАЮТСЯ."
        artTitle = "ЗА РУЛЁМ"
        artSub = "1.0 BETA  ·  ОБНОВЛЕНИЕ 3"
    }
    en = @{
        dashTitle = "A DASHBOARD LIKE A REAL CAR'S"
        dashA = "BY THE DOOR THE LIGHT KNOB AND THE LOCK SWITCH. BEFORE THE DRIVER THE TACHOMETER, THE SPEEDOMETER WITH THE GEAR AND THE CRUISE, THE FUEL WITH THE FILLER SIDE, LAMPS BEHIND GLASS."
        dashB = "AT NIGHT THE DIALS ARE LIT BY THE HEADLIGHTS. NEEDLES ON SPRINGS, THE LAMPS LIGHT ONE BY ONE, THE PANEL SHAKES ON A HIT."
        dashC = "THE LOCK ON THE COLUMN: LEFT CLICK STARTS AND STOPS THE ENGINE, RIGHT CLICK TAKES THE KEY OUT."
        truckTitle = "TWO BODIES: A SEDAN AND A PICKUP"
        truckA = "PICKUPS, VANS, SUVS AND BUSES GET A RUGGED PANEL: A PULL KNOB FOR THE LIGHTS, A BOLTED STRIP, A ROW OF GEARS."
        truckB = "NO KEY - WIRES STICK OUT OF THE LOCK AND SPARK WHILE THE ENGINE CRANKS."
        radioTitle = "THE RADIO AND THE TAPE"
        radioA = "VOL, TUNE, A DISPLAY, PRESETS 1-6, SEEK, FM AND TAPE - LIKE A REAL ONE."
        radioB = "YOUR OWN MUSIC IS A TAPE: CLICK THE SLOT TO PUT IT IN, EJECT PUSHES IT OUT. THE REELS TURN WHILE IT PLAYS."
        radioC = "THE MOUSE WHEEL: THE VOLUME, THE STATION, THE TRACK. A CLICK ON THE DISPLAY - THE RADIO CARD."
        musicTitle = "MUSIC IN THE CAR"
        musicA = "GET OUT - THE MUSIC PLAYS ON IN THE CAR: QUIETER WITH THE DISTANCE, MUFFLED THROUGH THE BODY, CLEARER WITH A DOOR OPEN."
        musicB = "LEAVE MUSIC PLAYING IN ONE CAR AND DRIVE ANOTHER - BOTH PLAY."
        musicC = "IN MULTIPLAYER THE PLAYERS NEAR THE CAR HEAR IT. A FILE THEY LACK GOES THROUGH THE SERVER; FILE NAMES ARE NEVER SENT."
        artTitle = "BEHIND THE WHEEL"
        artSub = "1.0 BETA  ·  UPDATE 3"
    }
}

# --- the dashboard's own frames: tools\dash on the game's Lua, painted on the screen's colour
# (a set per language: the panel's own captions - ФАРЫ / LIGHTS, КМ/Ч / KM/H - are its texts)
function MakeFrames($lang) {
    $script:frames = Join-Path $env:TEMP "knox_news_b3_$lang"
    if (Test-Path $script:frames) { Remove-Item -LiteralPath $script:frames -Recurse -Force }
    & (Join-Path $PSScriptRoot "dash\test.ps1") -snap $script:frames -lang $lang.ToUpper() | Out-Null
    Get-ChildItem $script:frames -Filter *.png | Remove-Item -Force
    & (Join-Path $PSScriptRoot "dash\snap.ps1") $script:frames -back "#0c0e0e" | Out-Null
}
# (snap.ps1 leaves 24 px round the panel and 190 above it for its tooltip)
function Frame3($name) { Join-Path $frames "$name.png" }
function PanelRect($name) {
    $img = [System.Drawing.Image]::FromFile((Frame3 $name))
    $r = @(24, 190, ($img.Width - 48), ($img.Height - 214))
    $img.Dispose()
    return $r
}
# a part (sx, sy, sw, sh) of a frame drawn at x, y, k times its size (1: pixel for pixel)
function Piece($g, $name, $sx, $sy, $sw, $sh, $x, $y, $k = 1) {
    $img = [System.Drawing.Image]::FromFile((Frame3 $name))
    $im = $g.InterpolationMode
    $g.InterpolationMode = $(if ($k -eq 1) { [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor } else { [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic })
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]($sw * $k)), ([int]($sh * $k))), [int]$sx, [int]$sy, [int]$sw, [int]$sh, [System.Drawing.GraphicsUnit]::Pixel)
    $g.InterpolationMode = $im
    $img.Dispose()
}
# the whole panel of a frame, centred in a picture w wide, at y; returns its height
function Panel($g, $name, $w, $y, $k = 1) {
    $r = PanelRect $name
    Piece $g $name $r[0] $r[1] $r[2] $r[3] ([math]::Floor(($w - $r[2] * $k) / 2)) $y $k
    return [int]($r[3] * $k)
}

# the sedan's radio plate in its 4K frame (SEDAN.plates[4] {510, 8, 294, 142} x 96/48): drawn
# pixel for pixel - blown up from the 1440p frame it came out soft (the author, 2026-10-21)
$RS = 96 / 48
$radio = @((24 + [math]::Floor(510 * $RS)), (190 + [math]::Floor(8 * $RS)), ([math]::Ceiling(294 * $RS) + 1), ([math]::Ceiling(142 * $RS) + 1))

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    MakeFrames $lang
    Write-Host "news pictures 1.0 BETA update 3 ($lang):"

    # (the dashboard and the pickup are no pictures: the post shows the panel itself,
    # live - its "@dash sedan" / "@dash pickup hot" lines, KnoxDashboard.newsDemo)

    # --- the radio with the tape in, half as big again, the words beside it
    $zoom = 1
    $bmp, $g = Canvas 1280 (84 + [int]($radio[3] * $zoom) + 60) $K.screen
    Caption $g $s.radioTitle 24 26
    Piece $g "news_tape_2160" $radio[0] $radio[1] $radio[2] $radio[3] 40 84 $zoom
    $tx = 40 + [int]($radio[2] * $zoom) + 40; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.radioA $tx 110 $tw 19 $null 28
    $ty = CapsBlock $g $s.radioB $tx ($ty + 14) $tw 19 $K.accent 28
    CapsBlock $g $s.radioC $tx ($ty + 14) $tw 19 $null 28 | Out-Null
    Save $bmp $g "b3_radio_$lang.png"

    # --- the music: the settings on their Game page, the three new rows
    $bmp, $g = Canvas 1280 600 $K.screen
    Caption $g $s.musicTitle 24 26
    $wx = 40; $wy = 84; $ww = 700; $wh = 480
    Win $g $wx $wy $ww $wh (Tr $lang "IGUI_Knox_Settings")
    $pages = @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_game"),
               (Tr $lang "IGUI_Knox_Page_order"), (Tr $lang "IGUI_Knox_Page_controls"))
    $y = Tabs $g $wx ($wy + 44) $ww $pages 2
    $mx = $wx + 2 * $P; $mw = $ww - 4 * $P
    $y += 26
    $y = SwitchRow $g $mx $y $true (Tr $lang "IGUI_Knox_Switch_musicShare") (Tr $lang "IGUI_Knox_Switch_musicShare_Info") $mw
    $y += 14; Fill $g $K.line $mx ($y - 6) $mw 1
    $y = SwitchRow $g $mx $y $true (Tr $lang "IGUI_Knox_Switch_musicHear") (Tr $lang "IGUI_Knox_Switch_musicHear_Info") $mw
    $y += 14; Fill $g $K.line $mx ($y - 6) $mw 1
    Slider $g $mx $y $mw (Tr $lang "IGUI_Knox_music_others") 0.7 "70%" 300
    $tx = $wx + $ww + 40; $tw = 1280 - $tx - 40
    $ty = CapsBlock $g $s.musicA $tx 150 $tw 19 $null 28
    $ty = CapsBlock $g $s.musicB $tx ($ty + 14) $tw 19 $K.accent 28
    CapsBlock $g $s.musicC $tx ($ty + 14) $tw 19 $null 28 | Out-Null
    Save $bmp $g "b3_music_$lang.png"

    # --- art: the sedan and the pickup at night, the radio big, on the frame's colour
    $bmp, $g = Canvas 960 1080 $K.cell
    Caption $g $s.artTitle 64 56 34 $K.accent
    # (the update's name only - no "1.0 BETA, update 3": the author, 2026-10-21)
    $rSed = PanelRect "news_sedan_1440"; $kk = 832 / $rSed[2]
    $y = 180
    $y += (Panel $g "news_sedan_1440" 960 $y $kk) + 36
    $rt = PanelRect "news_truck_1440"; $kt = 832 / $rt[2]
    $y += (Panel $g "news_truck_1440" 960 $y $kt) + 48
    $kr = [math]::Min(1, [math]::Min(832 / $radio[2], (1080 - 64 - $y) / $radio[3]))
    Piece $g "news_tape_2160" $radio[0] $radio[1] $radio[2] $radio[3] ([math]::Floor((960 - $radio[2] * $kr) / 2)) $y $kr
    Save $bmp $g "b3_art_$lang.png"

    # --- banner, no words: the sedan's dials at night, darkest on the left
    $bmp, $g = Canvas 912 204 $K.screen
    $rSed = PanelRect "news_sedan_1440"
    # (the cluster from its first well to the fuel dial, as high as the banner)
    $cx0 = $rSed[0] + [int](106 * 64 / 48); $cw = [int](338 * 64 / 48)
    $kb = 204 / ($rSed[3] - 8)
    Piece $g "news_sedan_1440" $cx0 ($rSed[1] + 4) $cw ($rSed[3] - 8) (912 - [int]($cw * $kb) - 24) 0 $kb
    Fill $g $K.screen 0 0 912 204 0.25
    $rr = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rr, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $rr)
    Save $bmp $g "b3_banner_$lang.png"
}
Get-ChildItem $env:TEMP -Directory -Filter "knox_news_b3_*" | Remove-Item -Recurse -Force
