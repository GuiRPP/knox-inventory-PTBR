# Steam gallery images (1920x1080) in the Knox screen's own look, cut from a
# real in-game screenshot (tools\art\screen_stage1.jpg, 2000x1125):
#   tools\art\gallery_1_overview.png ... gallery_5_roadmap.png
# Fonts: Fira Sans Extra Condensed (the mod's font) from Zomboid\tools\fonts\candidates.
#
# Texts: tools\art\gallery_<lang>.json (UTF-8; Windows PowerShell reads .ps1 files
# in the ANSI code page, so no text lives here). -Lang ru writes gallery_ru_*.png.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_gallery.ps1 [-Lang en|ru] [-Screen path.jpg]
# The crop rectangles are for the stage 1 screenshot; check them for a new one.

param([string]$Lang = "en", [string]$Screen = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$art = Join-Path $PSScriptRoot "art"
if (-not $Screen) { $Screen = Join-Path $art "screen_stage1.jpg" }
$fontDir = Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates"
$L = [IO.File]::ReadAllText((Join-Path $art "gallery_$Lang.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$prefix = $(if ($Lang -eq "en") { "gallery_" } else { "gallery_${Lang}_" })

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($f in "FiraSansExtraCondensed-Bold.ttf", "FiraSansExtraCondensed-SemiBold.ttf", "FiraSansExtraCondensed-Medium.ttf") {
    $pfc.AddFontFile((Join-Path $fontDir $f))
}
$family = $pfc.Families | Where-Object { $_.Name -like "*Extra Condensed*" } | Select-Object -First 1

function C([string]$hex, [int]$a = 255) {
    [System.Drawing.Color]::FromArgb($a, [Convert]::ToInt32($hex.Substring(1,2),16),
        [Convert]::ToInt32($hex.Substring(3,2),16), [Convert]::ToInt32($hex.Substring(5,2),16))
}
function Brush($hex, $a = 255) { New-Object System.Drawing.SolidBrush (C $hex $a) }
function Pen($hex, $w, $a = 255) { New-Object System.Drawing.Pen (C $hex $a), ([float]$w) }
function Bold($px) { New-Object System.Drawing.Font $family, ([float]$px), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel) }
function Plain($px) { New-Object System.Drawing.Font $family, ([float]$px), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel) }

$W = 1920; $H = 1080; $TOP = 120; $BOT = 96

# capitals with letter spacing, like the screen's tabs and section titles
function Spaced($g, $text, $font, $brush, $x, $y, $track) {
    foreach ($ch in $text.ToCharArray()) {
        $s = [string]$ch
        $g.DrawString($s, $font, $brush, $x, $y)
        $w = $g.MeasureString($s, $font, 1000, [System.Drawing.StringFormat]::GenericTypographic).Width
        if ($s -eq " ") { $w = $font.Size * 0.28 }
        $x += $w + $track
    }
    return $x
}

function NewCanvas() {
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear((C "#0b0c0c"))
    return @($bmp, $g)
}

# top bar: KNOX INVENTORY small on the left, the image's title as the active
# tab (sand line under it), the stage on the right
function TopBar($g, $title) {
    $g.FillRectangle((Brush "#1a1d1d"), 0, 0, $W, $TOP)
    $g.FillRectangle((Brush "#2a2e2e"), 0, $TOP - 2, $W, 2)
    $x = Spaced $g "KNOX" (Bold 34) (Brush "#ece8d8") 40 40 2
    $x = Spaced $g "INVENTORY" (Bold 34) (Brush "#d4c38a") ($x + 10) 40 2
    $g.FillRectangle((Brush "#3c4141"), $x + 30, 34, 2, 52)
    $tx = $x + 64
    $te = Spaced $g $title (Bold 58) (Brush "#ece8d8") $tx 26 3
    $g.FillRectangle((Brush "#d4c38a"), $tx, $TOP - 8, $te - $tx, 6)
    $sf = Bold 28
    $stage = $L.stage
    $sw = $g.MeasureString($stage, $sf).Width
    $g.FillRectangle((Brush "#121414"), $W - $sw - 64, 38, $sw + 24, 46)
    $g.DrawRectangle((Pen "#d4c38a" 2), $W - $sw - 64, 38, $sw + 24, 46)
    $g.DrawString($stage, $sf, (Brush "#d4c38a"), $W - $sw - 52, 44)
}

# bottom bar: key hints as on the screen ({key, label} pairs), or a line of text
function BottomBar($g, $hints, $text) {
    $g.FillRectangle((Brush "#1a1d1d"), 0, $H - $BOT, $W, $BOT)
    $g.FillRectangle((Brush "#2a2e2e"), 0, $H - $BOT, $W, 2)
    $kf = Bold 26; $lf = Plain 30
    $x = 40; $y = $H - $BOT + 26
    if ($text) { $g.DrawString($text, $lf, (Brush "#8f9289"), $x, $y - 2) }
    foreach ($h in $hints) {
        $kw = $g.MeasureString($h[0], $kf).Width + 18
        $g.FillRectangle((Brush "#121414"), $x, $y, $kw, 42)
        $g.DrawRectangle((Pen "#3c4141" 2), $x, $y, $kw, 42)
        $g.DrawString($h[0], $kf, (Brush "#d9d6c8"), $x + 9, $y + 5)
        $x += $kw + 12
        $g.DrawString($h[1], $lf, (Brush "#8f9289"), $x, $y + 2)
        $x += $g.MeasureString($h[1], $lf).Width + 34
    }
}

# a piece of the screenshot in a panel frame
function Piece($g, $img, $r, $dx, $dy, $dw, $dh) {
    $g.FillRectangle((Brush "#121414"), $dx - 3, $dy - 3, $dw + 6, $dh + 6)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh), $r[0], $r[1], $r[2], $r[3], [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawRectangle((Pen "#2a2e2e" 4), $dx - 3, $dy - 3, $dw + 5, $dh + 5)
}

# a sand callout: number square + label, pointing at a spot
function Callout($g, $n, $label, $x, $y) {
    $g.FillRectangle((Brush "#d4c38a"), $x, $y, 48, 48)
    $f = Bold 34
    $nw = $g.MeasureString($n, $f).Width
    $g.DrawString($n, $f, (Brush "#141414"), $x + (48 - $nw) / 2 + 1, $y + 3)
    $lf = Bold 30
    $lw = $g.MeasureString($label, $lf).Width
    $g.FillRectangle((Brush "#121414" 235), $x + 48, $y, $lw + 24, 48)
    $g.DrawRectangle((Pen "#d4c38a" 2), $x + 48, $y + 1, $lw + 23, 46)
    $g.DrawString($label, $lf, (Brush "#ece8d8"), $x + 60, $y + 6)
}

# right text column: a lead line, then points with sand markers (wrapped)
function Points($g, $x, $y, $w, $lead, $points, $size = 31, $leadSize = 40) {
    if ($lead) {
        $lf = Bold $leadSize
        $rect = New-Object System.Drawing.RectangleF $x, $y, $w, 400
        $g.DrawString($lead, $lf, (Brush "#ece8d8"), $rect)
        $y += $g.MeasureString($lead, $lf, [int]$w).Height + 26
    }
    $pf = Plain $size; $bf = Bold $size
    foreach ($p in $points) {
        $g.FillRectangle((Brush "#d4c38a"), $x, $y + 12, 12, 12)
        $tx = $x + 30; $tw = $w - 30
        $head = $p[0]; $body = $p[1]
        $g.DrawString($head, $bf, (Brush "#d4c38a"), (New-Object System.Drawing.RectangleF $tx, $y, $tw, 200))
        $y += $g.MeasureString($head, $bf, [int]$tw).Height
        if ($body) {
            $g.DrawString($body, $pf, (Brush "#d9d6c8"), (New-Object System.Drawing.RectangleF $tx, $y, $tw, 300))
            $y += $g.MeasureString($body, $pf, [int]$tw).Height
        }
        $y += [int]($size * 0.6)
    }
    return $y
}

function Save($bmp, $g, $name) {
    $g.Dispose()
    $name = $prefix + $name
    $bmp.Save((Join-Path $art $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  $name"
}

$img = [System.Drawing.Image]::FromFile($Screen)
$areaTop = $TOP + 30; $areaBot = $H - $BOT - 30; $areaH = $areaBot - $areaTop

# 1. Overview: the whole screen, its three columns named -------------------------
$c = NewCanvas; $bmp = $c[0]; $g = $c[1]
TopBar $g $L.s1_title
$sh = $areaH; $sw = [int](2000 * $sh / 1125)
$sx = 36
Piece $g $img @(0, 0, 2000, 1125) $sx $areaTop $sw $sh
$k = $sh / 1125
Callout $g "1" $L.s1_callouts[0] ([int]($sx + 40 * $k)) ([int]($areaTop + 560 * $k))
Callout $g "2" $L.s1_callouts[1] ([int]($sx + 560 * $k)) ([int]($areaTop + 900 * $k))
Callout $g "3" $L.s1_callouts[2] ([int]($sx + 1000 * $k)) ([int]($areaTop + 880 * $k))
$tx = $sx + $sw + 44
Points $g $tx ($areaTop + 6) ($W - $tx - 36) $L.s1_lead $L.s1_points 27 34 | Out-Null
BottomBar $g $L.s1_hints $null
Save $bmp $g "1_overview.png"

# 2. Grid ---------------------------------------------------------------------
$c = NewCanvas; $bmp = $c[0]; $g = $c[1]
TopBar $g $L.s2_title
# surroundings grid with stacks and the duffel bag, and the split dialog under it
$grid = @(1236, 148, 300, 352)
$gh = $areaH; $gw = [int]($grid[2] * $gh / $grid[3])
Piece $g $img $grid 40 $areaTop $gw $gh
$tx = 40 + $gw + 70
Points $g $tx ($areaTop + 6) ($W - $tx - 40) $L.s2_lead $L.s2_points | Out-Null
BottomBar $g $L.s2_hints $null
Save $bmp $g "2_grid.png"

# 3. Character ----------------------------------------------------------------
$c = NewCanvas; $bmp = $c[0]; $g = $c[1]
TopBar $g $L.s3_title
$eq = @(26, 126, 482, 775)
$eh = $areaH; $ew = [int]($eq[2] * $eh / $eq[3])
$ex = 60
Piece $g $img $eq $ex $areaTop $ew $eh
$k = $eh / $eq[3]
# the belt slot's quick pick panel, sticking out of the column as in game
$popup = @(500, 363, 67, 91)
$g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]($ex + ($popup[0] - $eq[0]) * $k)), ([int]($areaTop + ($popup[1] - $eq[1]) * $k)), ([int]($popup[2] * $k)), ([int]($popup[3] * $k))), $popup[0], $popup[1], $popup[2], $popup[3], [System.Drawing.GraphicsUnit]::Pixel)
Callout $g "1" $L.s3_callouts[0] ([int]($ex + $ew + 70)) ([int]($areaTop + 330 * $k))
Callout $g "2" $L.s3_callouts[1] ([int]($ex + $ew + 70)) ([int]($areaTop + 260 * $k))
$tx = $ex + $ew + 400
Points $g $tx ($areaTop + 6) ($W - $tx - 40) $L.s3_lead $L.s3_points | Out-Null
BottomBar $g $null $L.s3_bottom
Save $bmp $g "3_character.png"

# 4. Windows and moves --------------------------------------------------------
$c = NewCanvas; $bmp = $c[0]; $g = $c[1]
TopBar $g $L.s4_title
$insp = @(765, 371, 450, 503); $bags = @(1220, 148, 684, 622)
$ih = $areaH; $iw = [int]($insp[2] * $ih / $insp[3])
Piece $g $img $insp 40 $areaTop $iw $ih
$bh = [int]($areaH * 0.78); $bw = [int]($bags[2] * $bh / $bags[3])
Piece $g $img $bags (40 + $iw + 30) $areaTop $bw $bh
$tx = 40 + $iw + 30 + $bw + 44
Points $g $tx ($areaTop + 6) ($W - $tx - 36) $null $L.s4_points 27 34 | Out-Null
BottomBar $g $L.s4_hints $null
Save $bmp $g "4_windows.png"

# 5. Roadmap ------------------------------------------------------------------
$c = NewCanvas; $bmp = $c[0]; $g = $c[1]
TopBar $g $L.s5_title
$lf = Bold 44
$g.DrawString($L.s5_lead, $lf, (Brush "#ece8d8"), (New-Object System.Drawing.RectangleF 60, ($areaTop + 6), ($W - 120), 120))
$g.DrawString($L.s5_sub, (Plain 32), (Brush "#8f9289"), (New-Object System.Drawing.RectangleF 60, ($areaTop + 70), ($W - 120), 80))
$stages = $L.s5_stages
$cw = [int](($W - 120 - 3 * 30) / 4); $cy = $areaTop + 190; $ch = $areaBot - $cy
for ($i = 0; $i -lt 4; $i++) {
    $s = $stages[$i]; $x = 60 + $i * ($cw + 30)
    $now = $i -eq 0
    $g.FillRectangle((Brush "#121414"), $x, $cy, $cw, $ch)
    $g.FillRectangle((Brush "#1a1d1d"), $x, $cy, $cw, 120)
    if ($now) {
        $g.DrawRectangle((Pen "#d4c38a" 4), $x + 2, $cy + 2, $cw - 4, $ch - 4)
    } else {
        $g.DrawRectangle((Pen "#3c4141" 3), $x + 1, $cy + 1, $cw - 3, $ch - 3)
    }
    $g.FillRectangle((Brush ($(if ($now) { "#d4c38a" } else { "#3c4141" }))), $x, $cy + 118, $cw, 3)
    Spaced $g $s[0] (Bold 30) (Brush ($(if ($now) { "#d4c38a" } else { "#8f9289" }))) ($x + 28) ($cy + 16) 3 | Out-Null
    Spaced $g $s[1] (Bold 46) (Brush ($(if ($now) { "#ece8d8" } else { "#d9d6c8" }))) ($x + 28) ($cy + 52) 2 | Out-Null
    # status plate
    $pf = Bold 26
    $pw = $g.MeasureString($s[2], $pf).Width + 22
    if ($now) {
        $g.FillRectangle((Brush "#d4c38a"), $x + 28, $cy + 150, $pw, 40)
        $g.DrawString($s[2], $pf, (Brush "#141414"), $x + 39, $cy + 155)
    } else {
        $g.DrawRectangle((Pen "#3c4141" 2), $x + 28, $cy + 150, $pw, 40)
        $g.DrawString($s[2], $pf, (Brush "#8f9289"), $x + 39, $cy + 155)
    }
    $g.DrawString($s[3], (Plain 33), (Brush ($(if ($now) { "#d9d6c8" } else { "#8f9289" }))), (New-Object System.Drawing.RectangleF ($x + 28), ($cy + 220), ($cw - 56), ($ch - 240)))
    if ($now) {
        # a strip of the real screen at the bottom of the current stage
        $strip = @(1236, 148, 404, 152)
        $stw = $cw - 56; $sth = [int]($strip[3] * $stw / $strip[2])
        Piece $g $img $strip ($x + 28) ($cy + $ch - $sth - 28) $stw $sth
    }
}
BottomBar $g $null $L.s5_bottom
Save $bmp $g "5_roadmap.png"

# 6-9. The main menu (0.8.0): screenshots tools\art\screen_menu*.jpg (2000x1125) -----
if ($L.m1_title) {
    $menu = [System.Drawing.Image]::FromFile((Join-Path $art "screen_menu.jpg"))
    $c = NewCanvas; $bmp = $c[0]; $g = $c[1]
    TopBar $g $L.m1_title
    $sh = $areaH; $sw = [int](2000 * $sh / 1125); $sx = 36; $k = $sh / 1125
    Piece $g $menu @(0, 0, 2000, 1125) $sx $areaTop $sw $sh
    Callout $g "1" $L.m1_callouts[0] ([int]($sx + 880 * $k)) ([int]($areaTop + 985 * $k))
    Callout $g "2" $L.m1_callouts[1] ([int]($sx + 1010 * $k)) ([int]($areaTop + 285 * $k))
    Callout $g "3" $L.m1_callouts[2] ([int]($sx + 1560 * $k)) ([int]($areaTop + 700 * $k))
    $tx = $sx + $sw + 44
    Points $g $tx ($areaTop + 6) ($W - $tx - 36) $L.m1_lead $L.m1_points 27 34 | Out-Null
    BottomBar $g $L.m1_hints $null
    Save $bmp $g "6_menu.png"
    $menu.Dispose()

    $shot = [System.Drawing.Image]::FromFile((Join-Path $art "screen_menu_card_centre.jpg"))
    $c = NewCanvas; $bmp = $c[0]; $g = $c[1]
    TopBar $g $L.m2_title
    $r = @(700, 180, 860, 700); $ph = $areaH; $pw = [int]($r[2] * $ph / $r[3])
    Piece $g $shot $r 40 $areaTop $pw $ph
    $tx = 40 + $pw + 60
    Points $g $tx ($areaTop + 6) ($W - $tx - 40) $L.m2_lead $L.m2_points | Out-Null
    BottomBar $g $null $L.m2_bottom
    Save $bmp $g "7_passport.png"
    $shot.Dispose()

    $shot = [System.Drawing.Image]::FromFile((Join-Path $art "screen_menu_card_dead.jpg"))
    $c = NewCanvas; $bmp = $c[0]; $g = $c[1]
    TopBar $g $L.m3_title
    $r = @(780, 10, 800, 560); $ph = $areaH; $pw = [int]($r[2] * $ph / $r[3])
    Piece $g $shot $r 40 $areaTop $pw $ph
    $tx = 40 + $pw + 60
    Points $g $tx ($areaTop + 6) ($W - $tx - 40) $L.m3_lead $L.m3_points | Out-Null
    BottomBar $g $null $L.m3_bottom
    Save $bmp $g "8_fallen.png"
    $shot.Dispose()

    $shot = [System.Drawing.Image]::FromFile((Join-Path $art "screen_menu_reader.jpg"))
    $c = NewCanvas; $bmp = $c[0]; $g = $c[1]
    TopBar $g $L.m4_title
    $r = @(90, 15, 1820, 1045); $ph = $areaH; $pw = [int]($r[2] * $ph / $r[3])
    Piece $g $shot $r 36 $areaTop $pw $ph
    $tx = 36 + $pw + 44
    Points $g $tx ($areaTop + 6) ($W - $tx - 36) $null $L.m4_points 27 34 | Out-Null
    BottomBar $g $L.m4_hints $null
    Save $bmp $g "9_news.png"
    $shot.Dispose()
}

# 10-14. The new game screens (0.8.1): screenshots tools\art\screen_081_*.jpg (2000x1125),
# the screen's content without the header's left corner (ZombieBuddy's overlay sits there)
if ($L.n_shots) {
    $n = 10
    foreach ($s in $L.n_shots) {
        $shot = [System.Drawing.Image]::FromFile((Join-Path $art $s.file))
        $c = NewCanvas; $bmp = $c[0]; $g = $c[1]
        TopBar $g $s.title
        $r = $s.rect; $pw = 1400; $ph = [int]($r[3] * $pw / $r[2])
        if ($ph -gt $areaH) { $ph = $areaH; $pw = [int]($r[2] * $ph / $r[3]) }
        Piece $g $shot $r 36 ($areaTop + [int](($areaH - $ph) / 2)) $pw $ph
        $tx = 36 + $pw + 44
        Points $g $tx ($areaTop + 6) ($W - $tx - 36) $s.lead $s.points 27 34 | Out-Null
        BottomBar $g $null $s.bottom
        Save $bmp $g ("{0}_{1}.png" -f $n, $s.name)
        $shot.Dispose()
        $n++
    }
}

$img.Dispose()
Write-Host "gallery written to $art"
