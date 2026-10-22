# A candidate poster (2026-10-14): one idea per part, nothing piled up.
#   top    - the name and one line of what the mod is
#   middle - the camp of the main menu, the heroes by the fire (the mood)
#   bottom - a Knox grid with a bag being dragged into place (the inventory)
#   band   - VIEWPOINT COMPATIBLE
# THE poster since 2026-10-14 (replaced make_poster.ps1's four tiles). Writes
# tools\art\poster2_1024.png / poster_1024.png, tools\art\preview_workshop.jpg (the
# Workshop page, upload_page.ps1), 42\poster.png (256, the game's mod list) and
# tools\art\poster2_322.png (how it reads in the Workshop's tile).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_poster2.ps1
#   -Overlay: no poster files - everything but the camp, on a
#   transparent picture (the camp's fades half see-through), for the animated
#   preview: tools\make_poster_gif.ps1 lays a video of the camp under it.
#   (with -Fps and -Length: tools\art\gif_frames\ov_000.png... - one a frame, the
#   grid filling up; see DrawGridAt)
param([switch]$Overlay, [int]$Fps = 8, [double]$Length = 3.5)

. (Join-Path $PSScriptRoot "news_ui.ps1")
$art = Join-Path $PSScriptRoot "art"
$K.ammo = Hex "#3a321c"   # (T.category.ammo, news_ui has no ammo)

$S = 1024
$bmp, $g = Canvas $S $S $K.screen
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# --- the camp: full width, fading into the screen's dark at the top and bottom ---
$sceneH = 700
if ($Overlay) {
    $g.Clear([System.Drawing.Color]::Transparent)
    Fill $g $K.screen 0 $sceneH $S ($S - $sceneH)
} else {
    $shot = [System.Drawing.Image]::FromFile((Join-Path $art "screen_081_menu.jpg"))
    # (left of the news cards and the third hero; the logo stays above the crop)
    $sw = 1150; $sh = [int]($sw * $sceneH / $S); $sx = 400; $sy = 1062 - $sh
    $g.DrawImage($shot, (New-Object System.Drawing.Rectangle 0, 0, $S, $sceneH), $sx, $sy, $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel)
    $shot.Dispose()
}
function VFade($y0, $y1, $a0, $a1) {
    $r = New-Object System.Drawing.Rectangle 0, ([int]$y0), $S, ([int]($y1 - $y0))
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, (A $K.screen $a0), (A $K.screen $a1), 90.0
    $g.FillRectangle($lg, $r)
}
if ($Overlay) {
    # (the video's heroes stand higher and bigger: the dark ends right under the subtitle)
    VFade 0 240 1.0 0.0
    VFade 0 150 0.9 0.0
} else {
    VFade 0 320 1.0 0.0
    VFade 0 160 0.95 0.0
}
VFade ($sceneH - 230) ($sceneH + 1) 0.0 1.0
# the sides a little darker, the fire stays the brightest thing
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(-260, -120, $S + 520, $sceneH + 200)
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
$pg.CenterColor = A $K.screen 0
$pg.SurroundColors = [System.Drawing.Color[]]@((A $K.screen $(if ($Overlay) { 0.45 } else { 0.85 })))   # (the video: the hero on the right is near the edge)
$pg.FocusScales = New-Object System.Drawing.PointF 0.55, 0.45
$g.FillRectangle($pg, 0, 0, $S, $sceneH)

# --- the name ---
$tp = 128
$wK = TextW $g "KNOX" "title" $tp; $wI = TextW $g "INVENTORY" "title" $tp; $sp = 30
$tx = ($S - ($wK + $sp + $wI)) / 2
Txt $g "KNOX" "title" $tp $K.bright $tx 44
Txt $g "INVENTORY" "title" $tp $K.accent ($tx + $wK + $sp) 44
$ly = 44 + $capH * $tp + 26
$sub = "TARKOV-STYLE UI OVERHAUL"
$subPx = 34
$subW = TextW $g $sub "head" $subPx
Fill $g $K.accent (($S - $subW) / 2 - 70) ($ly + 14) 48 3
Fill $g $K.accent (($S + $subW) / 2 + 22) ($ly + 14) 48 3
Txt $g $sub "head" $subPx $K.text (($S - $subW) / 2) ($ly)

# --- the inventory's layout (the tags line up with its panel) ---
$C = 92
$cols = 10; $rows = 3
$gw = $cols * $C + 1
$gx = [int](($S - $gw) / 2)
$stripH = 50
$bandH = 96; $bandY = $S - $bandH
$gy = $bandY - 36 - $rows * $C
$py = $gy - $stripH
# a shadow under the panel (drawn before the tags: it reaches up to them)
for ($i = 1; $i -le 6; $i++) { Fill $g $K.screen ($gx - 6 * $i) ($py - 6 * $i) ($gw + 12 * $i) ($stripH + $rows * $C + 12 * $i) 0.10 }

# what the mod has: one row of sand tags right over the panel, as wide as it,
# the spare room shared out as padding so the row ends flush with the panel
$tagList = @("3D MENU", "3D CHARACTER", "NEW GAME", "SEARCH", "TV & RADIO")
$tagH = 58; $tagGap = 10; $tagStyle = "title"   # bold, untracked: big enough to read in the 322 px tile
$rowX = $gx - 10; $rowW = $gw + 20
$tagPx = 44
do {
    $textW = 0; foreach ($t in $tagList) { $textW += TextW $g $t $tagStyle $tagPx }
    $pad = ($rowW - $textW - $tagGap * ($tagList.Count - 1)) / $tagList.Count
    if ($pad -lt 20) { $tagPx-- }
} while ($pad -lt 20)
$ty = $py - 10 - 16 - $tagH
$x = $rowX
foreach ($t in $tagList) {
    $w = (TextW $g $t $tagStyle $tagPx) + $pad
    Fill $g $K.accent $x $ty $w $tagH
    TxtCentre $g $t $tagStyle $tagPx $K.ink $x $ty $w $tagH
    $x += $w + $tagGap
}

# --- the inventory: a bag's grid, big cells, one bag held over a free spot ---
# the window behind the grid
Fill $g $K.window ($gx - 10) ($py - 10) ($gw + 20) ($stripH + $rows * $C + 21)
Frame $g $K.border ($gx - 10) ($py - 10) ($gw + 20) ($stripH + $rows * $C + 21) 2
# the header strip, active (sand frame), like the bag you are working in
Fill $g $K.header $gx $py $gw $stripH
Frame $g $K.accent $gx $py $gw $stripH 2
TxtMid $g "LARGE BACKPACK" "head" 24 $K.accent ($gx + 16) $py $stripH
$info = "10x3"
TxtMid $g $info "head" 24 $K.dim ($gx + $gw - 16 - (TextW $g $info "head" 24)) $py $stripH
Grid $g $gx $gy $cols $rows
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
# {col, row, w, h, category, icon, count}
$tiles = @(
    @(0, 0, 4, 1, "wpn", "rifle"),
    @(0, 1, 2, 2, "clo", "bag_hiking"),
    @(2, 1, 1, 1, "med", "pills"),
    @(3, 1, 1, 1, "med", "bandage"),
    @(2, 2, 1, 1, "food", "beans"),
    @(3, 2, 1, 1, "food", "bottle"),
    @(4, 0, 2, 1, "wpn", "pistol"),
    @(6, 0, 1, 1, "ammo", "ammo9", "30"),
    @(7, 0, 1, 1, "ammo", "shells", "12"),
    @(4, 1, 1, 2, "tool", "hammer"),
    @(5, 1, 1, 2, "wpn", "knife"),
    @(6, 1, 1, 1, "tool", "battery"),
    @(9, 0, 1, 1, "info", "book")
)
$duffel = @(7, 1, 3, 2, "clo", "duffel")

# a tile at its cells, see-through by `a`, lifted `dy` px (settling into place)
function TileA($g, $t, $a = 1, $dy = 0) {
    $x = $gx + $t[0] * $C + 1; $y = $gy + $t[1] * $C + 1 - $dy; $pw = $t[2] * $C - 1; $ph = $t[3] * $C - 1
    Fill $g $K[$t[4]] $x $y $pw $ph $a
    Frame $g $K.tileFrame $x $y $pw $ph 2 $a
    DrawIcon $g $t[5] $x $y $pw $ph $a ([math]::Floor([math]::Min($pw, $ph) * 0.85))
    if ($t.Count -gt 6 -and $a -gt 0.5) {
        Txt $g $t[6] "head" 22 $K.bright ($x + $pw - 8 - (TextW $g $t[6] "head" 22)) ($y + $ph - 26) $a
    }
}
# the green of the free cells a held tile would go to
function Spot($g, $t, $a = 1) {
    $x = $gx + $t[0] * $C + 1; $y = $gy + $t[1] * $C + 1; $pw = $t[2] * $C - 1; $ph = $t[3] * $C - 1
    Fill $g $K.ok $x $y $pw $ph (0.20 * $a)
    Frame $g $K.ok $x $y $pw $ph 2 $a
}
# a tile held at the cursor: its top left at hx, hy
function HeldA($g, $t, $hx, $hy, $a = 1) {
    $pw = $t[2] * $C - 1; $ph = $t[3] * $C - 1
    for ($i = 1; $i -le 4; $i++) { Fill $g $K.screen ($hx + 4 + 3 * $i) ($hy + 6 + 3 * $i) $pw $ph (0.12 * $a) }
    Fill $g $K[$t[4]] $hx $hy $pw $ph (0.94 * $a)
    Frame $g $K.accent $hx $hy $pw $ph 3 $a
    DrawIcon $g $t[5] $hx $hy $pw $ph $a ([math]::Floor([math]::Min($pw, $ph) * 0.86))
    if ($a -gt 0.6) { Cursor $g ($hx + $pw * 0.62) ($hy + $ph * 0.58) 46 }
}

# The animated preview's grid (make_poster_gif.ps1): things are put into the bag
# one by one. Each is picked up above the panel, carried to its free spot (the
# spot lights green), let go, and settles into its cells; the last is the
# duffel bag. Before the loop starts again, what was put in fades away.
# {tile index or "duffel", start s, from dx, from dy (px, from its cells)}
$arrivals = @(
    @(6, 0.10, -70, -190),
    @(8, 0.70, 60, -200),
    @(4, 1.30, 120, -260),
    @(5, 1.90, -80, -250),
    @("duffel", 2.40, -120, -230)
)
$MOVE, $SETTLE, $FADE_AT = 0.45, 0.16, 3.15
function Ease([double]$v) { $v = [math]::Max([double]0, [math]::Min([double]1, $v)); return $v * $v * (3 - 2 * $v) }   # (not $k: PowerShell names ignore case - it would be the palette $K)
function DrawGridAt($g, $time, $length) {
    $moving = @{}
    foreach ($ar in $arrivals) { if ($ar[0] -ne "duffel") { $moving[[int]$ar[0]] = $ar } }
    # what lies there from the start
    for ($i = 0; $i -lt $tiles.Count; $i++) { if (-not $moving.ContainsKey($i)) { TileA $g $tiles[$i] } }
    $fade = 1 - (Ease (($time - $FADE_AT) / ($length - $FADE_AT)))
    foreach ($ar in $arrivals) {
        $t = $(if ($ar[0] -eq "duffel") { $duffel } else { $tiles[[int]$ar[0]] })
        $u = $time - $ar[1]
        if ($u -lt 0) { continue }
        if ($u -lt $MOVE) {
            # carried: picked up (fading in), eased along, the spot lighting up as it nears
            $prog = Ease ($u / $MOVE)
            $x = $gx + $t[0] * $C + 1 + $ar[2] * (1 - $prog)
            $y = $gy + $t[1] * $C + 1 + $ar[3] * (1 - $prog) - 16 * $prog
            Spot $g $t (Ease (($u / $MOVE - 0.3) / 0.5))
            HeldA $g $t $x $y ([math]::Min([double]1, $u / 0.12))
        } elseif ($u -lt $MOVE + $SETTLE) {
            # let go: it drops the last bit into its cells
            $prog = Ease (($u - $MOVE) / $SETTLE)
            TileA $g $t (0.35 + 0.65 * $prog) ([math]::Floor(16 * (1 - $prog) * (1 - $prog)))
        } else {
            TileA $g $t $fade
        }
    }
}
if (-not $Overlay) {
    foreach ($t in $tiles) { TileA $g $t }
    # the free spot lit green, the duffel bag held over it, a little off, with the cursor
    Spot $g $duffel
    HeldA $g $duffel ($gx + 7 * $C + 22) ($gy + $C - 16)
}

# --- the band: Viewpoint, ink on sand ---
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
Fill $g $K.accent 0 $bandY $S $bandH
$vp = "VIEWPOINT"; $cp = "COMPATIBLE"; $bp = 58
$cr = 26
$wv = TextW $g $vp "title" $bp; $wc = TextW $g $cp "title" $bp
$total = 2 * $cr + 28 + $wv + 22 + $wc
$x0 = ($S - $total) / 2
$ccx = $x0 + $cr; $ccy = $bandY + $bandH / 2
$pen = New-Object System.Drawing.Pen (A $K.ink 1), 6
$g.DrawEllipse($pen, [float]($ccx - $cr), [float]($ccy - $cr), [float](2 * $cr), [float](2 * $cr))
$g.FillEllipse((Br $K.ink), [float]($ccx - 6), [float]($ccy - 6), 12, 12)
foreach ($d in @(@(1,0), @(-1,0), @(0,1), @(0,-1))) {
    $g.DrawLine($pen, [float]($ccx + $d[0] * ($cr - 12)), [float]($ccy + $d[1] * ($cr - 12)), [float]($ccx + $d[0] * ($cr + 12)), [float]($ccy + $d[1] * ($cr + 12)))
}
$vx = $ccx + $cr + 28
TxtMid $g $vp "title" $bp $K.ink $vx $bandY $bandH
TxtMid $g $cp "title" $bp (Hex "#5a5136") ($vx + $wv + 22) $bandY $bandH

$g.Dispose()
if ($Overlay) {
    # one overlay a frame: the poster with the grid as it is at that moment
    $dir = Join-Path $art "gif_frames"
    if (Test-Path $dir) { Get-ChildItem $dir -Filter "ov_*.png" | Remove-Item -Force }
    New-Item -ItemType Directory -Force $dir | Out-Null
    $n = [int][math]::Round($Length * $Fps)
    $rect = New-Object System.Drawing.Rectangle 0, 0, $S, $S
    for ($f = 0; $f -lt $n; $f++) {
        $fb = $bmp.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $fg = [System.Drawing.Graphics]::FromImage($fb)
        $fg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $fg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $fg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        DrawGridAt $fg ($f / $Fps) $Length
        $fg.Dispose()
        $fb.Save((Join-Path $dir ("ov_{0:D3}.png" -f $f)), [System.Drawing.Imaging.ImageFormat]::Png)
        $fb.Dispose()
    }
    $bmp.Dispose()
    Write-Host "overlay written: $n frames"
    return
}
$bmp.Save((Join-Path $art "poster2_1024.png"), [System.Drawing.Imaging.ImageFormat]::Png)
# the mod's poster since 2026-10-14 (the user chose it): the Workshop page's preview,
# a JPEG under Steam's 1 MB (upload_page.ps1 sends it), and the 256 one for the game's mod list
$bmp.Save((Join-Path $art "poster_1024.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$jpg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]92)
$bmp.Save((Join-Path $art "preview_workshop.jpg"), $jpg, $ep)
$p256 = New-Object System.Drawing.Bitmap 256, 256
$g3 = [System.Drawing.Graphics]::FromImage($p256)
$g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g3.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g3.DrawImage($bmp, 0, 0, 256, 256)
$g3.Dispose()
$p256.Save((Join-Path $root "42\poster.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$p256.Dispose()
# how it reads in the Workshop's 322 px tile
$small = New-Object System.Drawing.Bitmap 322, 322
$g2 = [System.Drawing.Graphics]::FromImage($small)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g2.DrawImage($bmp, 0, 0, 322, 322)
$g2.Dispose()
$small.Save((Join-Path $art "poster2_322.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose(); $bmp.Dispose()
Write-Host "poster2 written"
