# The Boosty page's cover (2026-10-25, the author asked: boosty.to/knoxinventory).
# Boosty draws the cover 240 px high across the whole page, centred (8:1 on a 1920
# screen), so the picture is 2560 x 320 and everything that matters sits in the
# middle 1300 px (a 1024 px window still shows it).
#   back - the camp by the fire (the author's screenshot, tools\art\screen_camp_three.png)
#   text - KNOX INVENTORY, under it a line of what the page is, between sand lines
# Writes tools\art\boosty_cover.png (and _view: how it reads on a 1280 px page).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_boosty.ps1
# (saved with a UTF-8 BOM: the Russian lines)

. (Join-Path $PSScriptRoot "news_ui.ps1")
$art = Join-Path $PSScriptRoot "art"

$W = 2560; $H = 320
$bmp, $g = Canvas $W $H $K.screen
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# --- the camp: the author's screenshot (2026-10-25) - three heroes round the fire ---
# 1500 px wide in the middle (the heroes away from the edges of a 1280 page), faces just above the name, the flames under it
$shot = [System.Drawing.Image]::FromFile((Join-Path $art "screen_camp_three.png"))
$sw = 1500; $sk = $sw / $shot.Width; $sx = ($W - $sw) / 2
$g.DrawImage($shot, [float]$sx, [float](-140 * $sk), [float]$sw, [float]($shot.Height * $sk))
$shot.Dispose()
Fill $g $K.screen 0 0 $W $H 0.05
# the middle a little darker under the logo, the fire still glows through
# (softer since 2026-10-25, the author: "the darkening is too hard")
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(($W / 2 - 600), -60, 1200, ($H + 120))
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
$pg.CenterColor = A $K.screen 0.4
$pg.SurroundColors = [System.Drawing.Color[]]@((A $K.screen 0))
$pg.FocusScales = New-Object System.Drawing.PointF 0.4, 0.2
$g.FillPath($pg, $path)
# the screenshot's edges into the dark of the page
# (340 px and eased since 2026-10-25, so the dark does not start in a hard band)
$fe = 340
$lgL = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle ($sx - 1), 0, ($fe + 1), $H), (A $K.screen 1.0), (A $K.screen 0.0), 0.0
$lgL.SetSigmaBellShape(1.0, 1.0)
$g.FillRectangle($lgL, $sx, 0, $fe, $H)
$lgR = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle ($sx + $sw - $fe), 0, ($fe + 1), $H), (A $K.screen 0.0), (A $K.screen 1.0), 0.0
$lgR.SetSigmaBellShape(1.0, 1.0)
$g.FillRectangle($lgR, ($sx + $sw - $fe), 0, $fe, $H)

# --- the logo (2026-10-25: the search-mark logo the author chose, tools\art\knox_logo_clear.png,
# exported from .claude\mockups\logo.html; its ink is at 574,119 - 1714,618), and the logo with
# the line under it in the middle of the height (the author: the name sat too high) ---
$logo = [System.Drawing.Image]::FromFile((Join-Path $art "knox_logo_clear.png"))
$lsrc = New-Object System.Drawing.Rectangle 574, 119, 1140, 499
$lh = 178; $lw = $lh * $lsrc.Width / $lsrc.Height
$sub = "ДНЕВНИКИ РАЗРАБОТКИ"; $subPx = 30
$subW = TextW $g $sub "head" $subPx
$gapL = 26
$blockH = $lh + $gapL + $capH * $subPx
$ty = ($H - $blockH) / 2
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($logo, (New-Object System.Drawing.RectangleF (($W - $lw) / 2), $ty, $lw, $lh), $lsrc, [System.Drawing.GraphicsUnit]::Pixel)
$logo.Dispose()
# what the page is, between two sand lines
$ly = $ty + $lh + $gapL
Fill $g $K.accent (($W - $subW) / 2 - 72) ($ly + $capH * $subPx / 2 - 1) 48 3
Fill $g $K.accent (($W + $subW) / 2 + 24) ($ly + $capH * $subPx / 2 - 1) 48 3
Txt $g $sub "head" $subPx $K.text (($W - $subW) / 2) $ly

$g.Dispose()
$file = Join-Path $art "boosty_cover.png"
$bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
# how it reads on a 1280 px page: 240 px high, the middle 1280 px
$view = New-Object System.Drawing.Bitmap 1280, 240
$g2 = [System.Drawing.Graphics]::FromImage($view)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, 1280, 240), [int](($W - 1280 * 4 / 3) / 2), 0, [int](1280 * 4 / 3), $H, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$view.Save((Join-Path $art "boosty_cover_view.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$view.Dispose(); $bmp.Dispose()
Write-Host "  $file"

# --- the levels' covers ---
# each level its RPG rarity colour (the author, 2026-10-25): the frame and the tile's edge
# - grey, white, green, blue, purple, orange; the rank white, the top two in their colour
$TIERS = @(
    @{ n = 1; name = "ЗОМБИ"; price = "150 ₽"; icon = "c_corpse"; cat = "med"; rare = "#9d9d9d" }
    @{ n = 2; name = "ДОХОДЯГА"; price = "300 ₽"; icon = "beans"; cat = "food"; rare = "#eeeeee" }
    @{ n = 3; name = "ВЫЖИВШИЙ"; price = "500 ₽"; icon = "pistol"; cat = "wpn"; rare = "#4cc94c" }
    @{ n = 4; name = "ЛИДЕР ГРУППЫ"; price = "1 000 ₽"; icon = "hat_police"; cat = "clo"; rare = "#3f92ea" }
    @{ n = 5; name = "ГУБЕРНАТОР"; price = "10 000 ₽"; icon = "m16"; cat = "wpn"; rare = "#b157ef"; tint = $true }
    @{ n = 6; name = "ЛЕГЕНДА НОКСА"; price = "20 000 ₽"; icon = "c_campfire"; cat = "mat"; rare = "#ff8a1e"; tint = $true }
)
$TW = 480; $TH = 300
$camp = [System.Drawing.Image]::FromFile((Join-Path $art "screen_camp_three.png"))
foreach ($t in $TIERS) {
    $bmp, $g = Canvas $TW $TH $K.screen
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    # the fire in the middle of the screenshot, dark
    $g.DrawImage($camp, (New-Object System.Drawing.Rectangle 0, 0, $TW, $TH), 420, 200, 640, 400, [System.Drawing.GraphicsUnit]::Pixel)
    Fill $g $K.screen 0 0 $TW $TH 0.72
    $rare = Hex $t.rare
    Frame $g $rare 0 0 $TW $TH 4
    # the tile: 3 x 3 cells' worth, the category's colour, the icon sharp
    $ts = 168; $tx = 30; $ty = ($TH - $ts) / 2
    for ($i = 1; $i -le 4; $i++) { Fill $g $K.screen ($tx + 2 * $i) ($ty + 3 * $i) $ts $ts 0.15 }
    Fill $g $K[$t.cat] $tx $ty $ts $ts
    Frame $g $rare $tx $ty $ts $ts 3
    DrawIcon $g $t.icon $tx $ty $ts $ts 1 128 $true
    # the rank (one line, or two if it does not fit) and the price
    $rx = $tx + $ts + 28; $rw = $TW - $rx - 26
    $px = 58
    $lines = @($t.name)
    if ((TextW $g $t.name "title" $px) -gt $rw) { $lines = WrapCaps $g $t.name "title" $px $rw }
    while (($lines | ForEach-Object { TextW $g $_ "title" $px } | Measure-Object -Maximum).Maximum -gt $rw) { $px -= 2 }
    $lineH = [int]($capH * $px + 14)
    $plH = 44; $gap = 22
    $blockH = $lines.Count * $lineH - 14 + $gap + $plH
    $y = ($TH - $blockH) / 2
    foreach ($l in $lines) { Txt $g $l "title" $px $(if ($t.tint) { $rare } else { $K.bright }) $rx $y; $y += $lineH }
    $y += $gap - 14
    $pw = (TextW $g $t.price "head" 26) + 26
    Fill $g $K.accent $rx $y $pw $plH
    TxtCentre $g $t.price "head" 26 $K.ink $rx $y $pw $plH
    $g.Dispose()
    $f = Join-Path $art "boosty_tier_$($t.n).png"
    $bmp.Save($f, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host "  $f"
}
$camp.Dispose()

# --- the avatar (2026-10-25): Boosty cuts it to a circle and shows it about 160 px.
# a - the hero behind the fire (the author's screenshot), b - the same in a sand ring,
# c - a sand K on the dark of the window. Writes tools\art\boosty_avatar_<a|b|c>.png.
$AV = 512
$camp = [System.Drawing.Image]::FromFile((Join-Path $art "screen_camp_three.png"))
foreach ($v in "a", "b", "c") {
    $bmp, $g = Canvas $AV $AV $K.screen
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    if ($v -ne "c") {
        $g.DrawImage($camp, (New-Object System.Drawing.Rectangle 0, 0, $AV, $AV), 520, 85, 360, 360, [System.Drawing.GraphicsUnit]::Pixel)
        # the edge of the circle a little darker, the face and the fire as they are
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddEllipse(-60, -60, $AV + 120, $AV + 120)
        $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
        $pg.CenterColor = A $K.screen 0
        $pg.SurroundColors = [System.Drawing.Color[]]@((A $K.screen 0.7))
        $pg.FocusScales = New-Object System.Drawing.PointF 0.55, 0.55
        $g.FillRectangle($pg, 0, 0, $AV, $AV)
        if ($v -eq "b") {
            $pen = New-Object System.Drawing.Pen $K.accent, 18
            $g.DrawEllipse($pen, 9, 9, $AV - 18, $AV - 18)
        }
    } else {
        Fill $g $K.window 0 0 $AV $AV
        $pen = New-Object System.Drawing.Pen $K.accent, 10
        $g.DrawEllipse($pen, 22, 22, $AV - 44, $AV - 44)
        $kp = 300
        $kw = TextW $g "K" "title" $kp
        Txt $g "K" "title" $kp $K.accent (($AV - $kw) / 2) (($AV - $capH * $kp) / 2)
    }
    $g.Dispose()
    $f = Join-Path $art "boosty_avatar_$v.png"
    $bmp.Save($f, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host "  $f"
}
$camp.Dispose()
