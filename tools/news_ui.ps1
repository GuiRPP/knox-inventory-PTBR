# The parts of the Knox screen for news pictures (dot-sourced by tools\make_news_*.ps1):
# palette (KnoxTheme), fonts (Fira Sans Extra Condensed: title / head / body), panels,
# grids, tiles, plates, rows, the search field, the Found window, the cursor - all at the
# 64 px cell of a 1440p screen, icons from the game's own files (tools\game_icons.ps1).
# Rules for news pictures: see the comment at the top of make_news_096.ps1.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$out = Join-Path $root "42\media\knox\news"
$iconDir = Join-Path $PSScriptRoot "art\gameicons"
$ui = Join-Path $root "42\media\ui"
$fontDir = Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates"
$pfc = New-Object System.Drawing.Text.PrivateFontCollection
foreach ($f in "FiraSansExtraCondensed-Bold.ttf", "FiraSansExtraCondensed-SemiBold.ttf", "FiraSansExtraCondensed-Medium.ttf") {
    $pfc.AddFontFile((Join-Path $fontDir $f))
}
function Fam($word) { $pfc.Families | Where-Object { $_.Name -like "*$word*" } | Select-Object -First 1 }
$famBold = $pfc.Families | Where-Object { $_.Name -eq "Fira Sans Extra Condensed" } | Select-Object -First 1
$famSemi = Fam "SemiBold"
$famMed = Fam "Medium"
if (-not $famSemi) { $famSemi = $famBold }
if (-not $famMed) { $famMed = $famBold }

# the palette (KnoxTheme T.color, T.category)
function Hex([string]$h) { [System.Drawing.Color]::FromArgb(255, [Convert]::ToInt32($h.Substring(1, 2), 16), [Convert]::ToInt32($h.Substring(3, 2), 16), [Convert]::ToInt32($h.Substring(5, 2), 16)) }
$K = @{
    window = Hex "#121414"; header = Hex "#1a1d1d"; border = Hex "#2a2e2e"; cell = Hex "#0e1010"; line = Hex "#242828"
    tileEdge = Hex "#3c4141"; tileFrame = Hex "#5b615c"; text = Hex "#d9d6c8"; bright = Hex "#ece8d8"; dim = Hex "#8f9289"
    accent = Hex "#d4c38a"; ok = Hex "#6ca050"; bad = Hex "#be463c"; ink = Hex "#141414"; buttonBg = Hex "#1f2323"
    screen = Hex "#0c0e0e"; bar = Hex "#151818"; good = Hex "#9fb36a"; warn = Hex "#c9a24a"; tileHover = Hex "#8e938a"
    wpn = Hex "#2a2f22"; med = Hex "#3b2427"; food = Hex "#24331f"; tool = Hex "#1f2d38"; clo = Hex "#2b2a33"; info = Hex "#302640"; mat = Hex "#2f2a24"; misc = Hex "#262929"
}
function A($c, $a) { [System.Drawing.Color]::FromArgb([int]($a * 255), $c.R, $c.G, $c.B) }
function Mix($a, $b, $k) { [System.Drawing.Color]::FromArgb(255, [int]($a.R + ($b.R - $a.R) * $k), [int]($a.G + ($b.G - $a.G) * $k), [int]($a.B + ($b.B - $a.B) * $k)) }
function Br($c, $a = 1) { New-Object System.Drawing.SolidBrush (A $c $a) }
function Fill($g, $c, $x, $y, $w, $h, $a = 1) { $g.FillRectangle((Br $c $a), [float]$x, [float]$y, [float]$w, [float]$h) }
# a frame of t px inside x, y, w, h
function Frame($g, $c, $x, $y, $w, $h, $t = 1, $a = 1) {
    $b = Br $c $a
    $g.FillRectangle($b, [float]$x, [float]$y, [float]$w, [float]$t)
    $g.FillRectangle($b, [float]$x, [float]($y + $h - $t), [float]$w, [float]$t)
    $g.FillRectangle($b, [float]$x, [float]($y + $t), [float]$t, [float]($h - 2 * $t))
    $g.FillRectangle($b, [float]($x + $w - $t), [float]($y + $t), [float]$t, [float]($h - 2 * $t))
}

# Fonts: Knox's three styles at the 64 px cell (T.refresh): title (bold), head
# (semibold capitals, letter-spaced), body (medium)
$fontCache = @{}
function Fnt($style, $px) {
    $key = "$style$px"
    if (-not $fontCache[$key]) {
        $fam = switch ($style) { "title" { $famBold } "head" { $famSemi } default { $famMed } }
        $fontCache[$key] = New-Object System.Drawing.Font $fam, ([float]$px), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    }
    $fontCache[$key]
}
$typo = [System.Drawing.StringFormat]::GenericTypographic
# where the capitals' ink is, as a share of the font size: drawn at y, the top
# of a capital is at y + capTop * size, and capitals are capH * size high
$probe = New-Object System.Drawing.Bitmap 200, 200
$pg = [System.Drawing.Graphics]::FromImage($probe); $pg.Clear([System.Drawing.Color]::Black)
$pg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$pg.DrawString("H", (Fnt "head" 100), [System.Drawing.Brushes]::White, 20, 20, $typo); $pg.Dispose()
$inkTop = 999; $inkBot = -1
for ($y = 0; $y -lt 200; $y++) { for ($x = 0; $x -lt 200; $x += 2) { if ($probe.GetPixel($x, $y).R -gt 128) { if ($y -lt $inkTop) { $inkTop = $y }; $inkBot = $y; break } } }
$probe.Dispose()
$capTop = ($inkTop - 20) / 100.0; $capH = ($inkBot - $inkTop + 1) / 100.0

function TrackOf($style, $px) { if ($style -eq "head") { [math]::Max(1, [math]::Round($px * 0.05)) } else { 0 } }
function TextW($g, $s, $style, $px) {
    $f = Fnt $style $px; $t = TrackOf $style $px; $w = 0
    if ($t -eq 0) { return $g.MeasureString($s, $f, 4000, $typo).Width }
    foreach ($ch in $s.ToCharArray()) { $c = [string]$ch; $w += $(if ($c -eq " ") { $px * 0.26 } else { $g.MeasureString($c, $f, 1000, $typo).Width }) + $t }
    return $w - $t
}
# words broken into lines no wider than w
function WrapCaps($g, $text, $style, $px, $w) {
    $lines = @(); $cur = ""
    foreach ($word in $text.Split(" ")) {
        $try = $(if ($cur) { "$cur $word" } else { $word })
        if ($cur -and (TextW $g $try $style $px) -gt $w) { $lines += $cur; $cur = $word } else { $cur = $try }
    }
    if ($cur) { $lines += $cur }
    return $lines
}
# text drawn with its capitals' top at `top` (the way Knox lines labels up by their ink)
function Txt($g, $s, $style, $px, $c, $x, $top, $a = 1) {
    $f = Fnt $style $px; $t = TrackOf $style $px; $b = Br $c $a
    $y = $top - $capTop * $px
    if ($t -eq 0) { $g.DrawString($s, $f, $b, [float]$x, [float]$y, $typo); return }
    foreach ($ch in $s.ToCharArray()) {
        $cs = [string]$ch
        if ($cs -ne " ") { $g.DrawString($cs, $f, $b, [float]$x, [float]$y, $typo) }
        $x += $(if ($cs -eq " ") { $px * 0.26 } else { $g.MeasureString($cs, $f, 1000, $typo).Width }) + $t
    }
}
# the same, its capitals centred in the height of a box at y, h
function TxtMid($g, $s, $style, $px, $c, $x, $y, $h, $a = 1) { Txt $g $s $style $px $c $x ($y + ($h - $capH * $px) / 2) $a }
function TxtCentre($g, $s, $style, $px, $c, $x, $y, $w, $h, $a = 1) { TxtMid $g $s $style $px $c ($x + ($w - (TextW $g $s $style $px)) / 2) $y $h $a }

$C = 64          # the cell
$P = 16          # T.pad
$icons = @{}
function Icon($name) {
    if (-not $icons[$name]) { $icons[$name] = [System.Drawing.Image]::FromFile((Join-Path $iconDir "$name.png")) }
    $icons[$name]
}
# An icon: a square of `side` px centred in a box, its pixels kept sharp - the
# game's 32 px pixel art drawn without smoothing, as the game draws it (smoothed,
# it came out blurred). `whole`: scaled only by a whole number (the Surroundings
# rows draw container icons so, see KnoxLootPanel).
function DrawIcon($g, $name, $x, $y, $w, $h, $a = 1, $side = $null, $whole = $false) {
    $img = Icon $name
    if (-not $side) { $side = [math]::Floor([math]::Min($w, $h)) }
    if ($whole) { $side = $img.Width * [math]::Max(1, [math]::Floor($side / $img.Width)) }
    $side = [int]$side
    $rect = New-Object System.Drawing.Rectangle ([int]($x + ($w - $side) / 2)), ([int]($y + ($h - $side) / 2)), $side, $side
    $im, $po = $g.InterpolationMode, $g.PixelOffsetMode
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    $ia.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)   # (no half-transparent seam at the edges)
    if ($a -lt 1) { $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$a; $ia.SetColorMatrix($cm) }
    $g.DrawImage($img, $rect, 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.InterpolationMode, $g.PixelOffsetMode = $im, $po
}

function Canvas($w, $h, $bg) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear($bg)
    return @($bmp, $g)
}
function Save($bmp, $g, $name) {
    $g.Dispose()
    $bmp.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  $name"
}

# --- the parts of the screen ------------------------------------------------------

# a grid of cols x rows cells at x, y
function Grid($g, $x, $y, $cols, $rows) {
    Fill $g $K.cell $x $y ($cols * $C) ($rows * $C)
    for ($i = 0; $i -le $cols; $i++) { Fill $g $K.line ($x + $i * $C) $y 1 ($rows * $C + 1) }
    for ($j = 0; $j -le $rows; $j++) { Fill $g $K.line $x ($y + $j * $C) ($cols * $C + 1) 1 }
}
# An item's tile on a grid at gx, gy: at cell col, row, w x h cells.
#   state: "" plain, "hit" (the search finds it: sand frame, lit), "dim" (it doesn't),
#          "ghost" (being dragged away), "drag" (held at the cursor)
function Tile($g, $gx, $gy, $col, $row, $w, $h, $cat, $icon, $state = "", $count = $null) {
    $x = $gx + $col * $C + 1; $y = $gy + $row * $C + 1; $pw = $w * $C - 1; $ph = $h * $C - 1
    $bg = $K[$cat]
    if ($state -eq "hit") { $bg = Mix $bg $K.accent 0.10 }
    Fill $g $bg $x $y $pw $ph
    if ($state -eq "hit" -or $state -eq "drag") { Frame $g $K.accent $x $y $pw $ph 2 }
    else { Frame $g $K.tileFrame $x $y $pw $ph 2 }
    $side = [math]::Min($pw, $ph) * 0.85
    $ia = $(if ($state -eq "ghost") { 0.35 } else { 1 })
    DrawIcon $g $icon $x $y $pw $ph $ia ([math]::Floor([math]::Min($pw, $ph) * 0.85))
    if ($count) { Txt $g $count "head" 16 $K.bright ($x + $pw - 6 - (TextW $g $count "head" 16)) ($y + $ph - 18) }
    if ($state -eq "dim") { Fill $g $K.screen $x $y $pw $ph 0.72 }
}
# A number plate (the Surroundings rows, the Found window): "full" sand with ink,
# "zero" grey with a dim number, "none" grey and empty (never looked into),
# "part" dark in a sand frame with a sand number (searched half-way)
function Plate($g, $x, $y, $h, $s, $kind = "full") {
    $w = [math]::Max($h, (TextW $g $s "head" 19) + 14)
    switch ($kind) {
        "full" { Fill $g $K.accent $x $y $w $h; TxtCentre $g $s "head" 19 $K.ink $x $y $w $h }
        "zero" { Fill $g $K.tileEdge $x $y $w $h; TxtCentre $g $s "head" 19 $K.dim $x $y $w $h }
        "none" { Fill $g $K.tileEdge $x $y $w $h }
        "part" { Fill $g $K.cell $x $y $w $h; Frame $g $K.accent $x $y $w $h 2; TxtCentre $g $s "head" 19 $K.accent $x $y $w $h }
    }
    return $w
}
# a column's panel with its big title and, on the right, the weight meter
function Column($g, $x, $y, $w, $h, $title, $weight = $null) {
    Fill $g $K.window $x $y $w $h
    Frame $g $K.border $x $y $w $h 1
    Txt $g (Up $title) "title" 27 $K.bright ($x + $P) ($y + 20)
    if ($weight) {
        $ww = TextW $g $weight "head" 19
        Txt $g $weight "head" 19 $K.text ($x + $w - $P - $ww) ($y + 22)
        $mx = $x + $w - $P - $ww - 16 - 130
        Fill $g $K.border $mx ($y + 29) 130 2; Fill $g $K.accent $mx ($y + 28) 36 4
    }
}
# a container's header strip over its grid (name in capitals, info on the right)
function Strip($g, $x, $y, $w, $name, $info = $null, $infoC = $null, $active = $false) {
    Fill $g $K.header $x $y $w 36
    if ($active) { Frame $g $K.accent $x $y $w 36 2 }
    TxtMid $g $name "head" 18 $(if ($active) { $K.accent } else { $K.bright }) ($x + 10) $y 36
    if ($info) {
        $c = $(if ($infoC) { $infoC } else { $K.dim })
        TxtMid $g $info "head" 18 $c ($x + $w - 12 - (TextW $g $info "head" 18)) $y 36
    }
}
# a row of the Surroundings list: framed icon, name, number plate
function Row($g, $x, $y, $w, $name, $icon, $plate, $kind, $active = $false, $hover = $false) {
    $h = 64
    Fill $g $(if ($active) { $K.header } else { $K.window }) $x $y $w $h
    if ($active) { Frame $g $K.accent $x $y $w $h 2 } elseif ($hover) { Frame $g (Mix $K.border $K.accent 0.55) $x $y $w $h 2 } else { Frame $g $K.border $x $y $w $h 2 }
    $s = 48; $ix = $x + 8; $iy = $y + 8
    Fill $g $K.header $ix $iy $s $s
    Frame $g $(if ($active) { $K.accent } else { $K.tileEdge }) $ix $iy $s $s 2
    DrawIcon $g $icon $ix $iy $s $s 1 ($s - 8) $true
    $nameC = $(if ($active) { $K.bright } elseif ($kind -eq "full" -or $kind -eq "zero") { $K.dim } else { $K.text })
    TxtMid $g $name "body" 21 $nameC ($ix + $s + 12) $y $h
    $ph = 32
    $pw = [math]::Max($ph, (TextW $g $plate "head" 19) + 14)
    Plate $g ($x + $w - 12 - $pw) ($y + ($h - $ph) / 2) $ph $plate $kind | Out-Null
}
# the search field of the top bar (the lens, the text, a cross)
$lensImg = [System.Drawing.Image]::FromFile((Join-Path $ui "knox_lens.png"))
function SearchField($g, $x, $y, $w, $text) {
    $h = 40
    Fill $g $K.cell $x $y $w $h
    Frame $g $K.accent $x $y $w $h 2
    $g.DrawImage($lensImg, (New-Object System.Drawing.RectangleF ([float]($x + 10)), ([float]($y + 10)), 20, 20))
    TxtMid $g $text "body" 21 $K.bright ($x + 40) $y $h
    # the cross
    $pen = New-Object System.Drawing.Pen (A $K.dim 1), 2
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $cx = $x + $w - 22; $cy = $y + $h / 2
    $g.DrawLine($pen, [float]($cx - 7), [float]($cy - 7), [float]($cx + 7), [float]($cy + 7))
    $g.DrawLine($pen, [float]($cx - 7), [float]($cy + 7), [float]($cx + 7), [float]($cy - 7))
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
}
# a cross (close buttons, the search field)
function Cross($g, $cx, $cy, $r, $c) {
    $pen = New-Object System.Drawing.Pen (A $c 1), 2
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.DrawLine($pen, [float]($cx - $r), [float]($cy - $r), [float]($cx + $r), [float]($cy + $r))
    $g.DrawLine($pen, [float]($cx - $r), [float]($cy + $r), [float]($cx + $r), [float]($cy - $r))
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
}
# "FOUND [n]" next to it
function FoundButton($g, $x, $y, $label, $n) {
    $h = 40
    $lw = TextW $g $label "head" 18
    $pw = [math]::Max(26, (TextW $g $n "head" 18) + 12)
    $w = 14 + $lw + 10 + $pw + 7
    Fill $g $K.window $x $y $w $h
    Frame $g $K.accent $x $y $w $h 2
    TxtMid $g $label "head" 18 $K.accent ($x + 14) $y $h
    Fill $g $K.accent ($x + $w - 7 - $pw) ($y + 7) $pw ($h - 14)
    TxtCentre $g $n "head" 18 $K.ink ($x + $w - 7 - $pw) ($y + 7) $pw ($h - 14)
    return $w
}
# The Found window: a title bar (title, total, Take all, cross) and a card per
# container: {name, mine, n, cols, rows, tiles = @(@(col, row, w, h, cat, icon, state))}
function FoundWindow($g, $x, $y, $w, $title, $total, $take, $mineText, $cards, $hot = -1) {
    # (the window is as wide as whole cells make it: the cards' grids fill them)
    $cols = [math]::Floor(($w - 29) / $C); $w = $cols * $C + 29
    $titleH = 52
    $h = $titleH + 8
    foreach ($cd in $cards) { $h += 36 + $cd.rows * $C + 14 }
    Fill $g $K.window $x $y $w $h
    Frame $g $K.accent $x $y $w $h 2
    TxtMid $g $title "title" 24 $K.bright ($x + 22) $y $titleH
    # cross, Take all, total - right to left, one margin apart
    $bh = 30; $by = $y + ($titleH - $bh) / 2; $m = 8
    $cx = $x + $w - 14 - $bh
    Fill $g $K.buttonBg $cx $by $bh $bh; Frame $g $K.tileEdge $cx $by $bh $bh 1
    Cross $g ($cx + $bh / 2) ($by + $bh / 2) 6 $K.bright
    $tw = (TextW $g $take "head" 17) + 30
    $tx = $cx - $m - $tw
    Fill $g $K.buttonBg $tx $by $tw $bh; Frame $g $K.tileEdge $tx $by $tw $bh 1
    TxtCentre $g $take "head" 17 $K.bright $tx $by $tw $bh
    $pw = [math]::Max($bh, (TextW $g $total "head" 18) + 12)
    $px = $tx - $m - $pw
    Fill $g $K.accent $px ($by + 1) $pw ($bh - 2); TxtCentre $g $total "head" 18 $K.ink $px ($by + 1) $pw ($bh - 2)
    $cy = $y + $titleH
    $i = 0
    foreach ($cd in $cards) {
        $cx0 = $x + 14; $cw = $cols * $C + 1
        Fill $g $K.header $cx0 $cy $cw 36
        $name = $cd.name
        TxtMid $g $name "head" 18 $K.bright ($cx0 + 8) $cy 36
        if ($cd.mine) { TxtMid $g ("  " + $mineText) "head" 18 $K.dim ($cx0 + 8 + (TextW $g $name "head" 18)) $cy 36 }
        $nw = [math]::Max(24, (TextW $g $cd.n "head" 18) + 10)
        Fill $g $K.accent ($cx0 + $cw - 7 - $nw) ($cy + 6) $nw 24
        TxtCentre $g $cd.n "head" 18 $K.ink ($cx0 + $cw - 7 - $nw) ($cy + 6) $nw 24
        $gy = $cy + 36
        Grid $g $cx0 $gy $cols $cd.rows
        foreach ($t in $cd.tiles) { Tile $g $cx0 $gy $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] $t[6] }
        if ($i -eq $hot) {
            # a thing held over this card: it goes there (green)
            Fill $g $K.ok $cx0 $cy $cw (36 + $cd.rows * $C) 0.16
            Frame $g $K.ok $cx0 $cy $cw (36 + $cd.rows * $C) 2
        }
        $cy = $gy + $cd.rows * $C + 14
        $i++
    }
    return $h
}
$cursorImg = [System.Drawing.Image]::FromFile((Join-Path $ui "knox_cursor.png"))
function Cursor($g, $x, $y, $size = 34) {
    $k = $size / $cursorImg.Height
    $g.DrawImage($cursorImg, (New-Object System.Drawing.RectangleF ([float]$x), ([float]$y), ([float]($cursorImg.Width * $k)), ([float]$size)))
}
# a tile held at the cursor: the dragged copy, a little see-through
function Held($g, $x, $y, $w, $h, $cat, $icon) {
    $pw = $w * $C - 1; $ph = $h * $C - 1
    Fill $g $K[$cat] $x $y $pw $ph 0.88
    Frame $g $K.accent $x $y $pw $ph 2
    DrawIcon $g $icon $x $y $pw $ph 1 ([math]::Floor([math]::Min($pw, $ph) * 0.72))
    Cursor $g ($x + $pw * 0.55) ($y + $ph * 0.55)
}
# the top bar's strip (tabs left out: only what the pictures need)
function TopBar($g, $x, $y, $w) {
    Fill $g $K.bar $x $y $w 64
    Fill $g $K.border $x ($y + 63) $w 1
}

# --- strings: the mod's own (IG_UI.json), so a picture says what the game says ----
$trCache = @{}
function Tr($lang, $key) {
    if (-not $trCache[$lang]) {
        $p = Join-Path $root ("42\media\lua\shared\Translate\" + $lang.ToUpper() + "\IG_UI.json")
        $trCache[$lang] = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    $v = $trCache[$lang].$key
    if ($v) { return [string]$v } else { return $key }
}
function Up($s) { return $s.ToUpper() }
# the game's own words (its Translate\<LANG>\<file>.json: ItemName, Fluids, IG_UI...)
$gameTrCache = @{}
function GTr($lang, $file, $key) {
    $id = $lang + "/" + $file
    if (-not $gameTrCache[$id]) {
        $p = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\lua\shared\Translate\" + $lang.ToUpper() + "\" + $file + ".json"
        # (read as text: ItemName.json has keys that differ only in case, which ConvertFrom-Json refuses)
        $gameTrCache[$id] = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
    }
    $m = [regex]::Match($gameTrCache[$id], '"' + [regex]::Escape($key) + '"\s*:\s*"((?:[^"\\]|\\.)*)"')
    if ($m.Success) { return $m.Groups[1].Value.Replace('\"', '"') } else { return $key }
}

# --- captions: what a picture explains is said in capitals (the author's rule) -----
function Caption($g, $text, $x, $y, $px = 28, $c = $null) {
    if (-not $c) { $c = $K.bright }
    Txt $g $text "title" $px $c $x $y
}
# capitals broken into lines; returns the y under the last line
function CapsBlock($g, $text, $x, $y, $w, $px = 18, $c = $null, $lineH = 28) {
    if (-not $c) { $c = $K.text }
    foreach ($line in (WrapCaps $g $text "head" $px $w)) { Txt $g $line "head" $px $c $x $y; $y += $lineH }
    return $y
}
# a small caps tag on a plate (BEFORE / NOW / NEW ...)
function Tag($g, $x, $y, $text, $bg, $fg = $null) {
    if (-not $fg) { $fg = $K.ink }
    $w = (TextW $g $text "head" 17) + 20
    Fill $g $bg $x $y $w 28
    TxtCentre $g $text "head" 17 $fg $x $y $w 28
    return $w
}

# --- windows -------------------------------------------------------------------------
# a Knox window: header strip with its caps title and a cross, sand frame all round
function Win($g, $x, $y, $w, $h, $title, $cross = $true) {
    Fill $g $K.window $x $y $w $h
    Fill $g $K.header $x $y $w 44
    Fill $g $K.border $x ($y + 44) $w 1
    TxtMid $g (Up $title) "head" 19 $K.bright ($x + 2 * $P) $y 44
    if ($cross) {
        $bh = 28; $cx = $x + $w - 12 - $bh; $by = $y + 8
        Fill $g $K.buttonBg $cx $by $bh $bh; Frame $g $K.tileEdge $cx $by $bh $bh 1
        Cross $g ($cx + $bh / 2) ($by + $bh / 2) 6 $K.bright
    }
    Frame $g $K.accent $x $y $w $h 2
}
# a row of tabs under a window's header; the active one underlined in sand
function Tabs($g, $x, $y, $w, $names, $active) {
    $h = 40
    Fill $g $K.border ($x + 2) ($y + $h) ($w - 4) 1
    $tx = $x + 2 * $P
    for ($i = 0; $i -lt $names.Count; $i++) {
        $n = Up $names[$i]
        $tw = (TextW $g $n "head" 17) + 28
        $on = ($i -eq $active)
        TxtCentre $g $n "head" 17 $(if ($on) { $K.bright } else { $K.dim }) $tx $y $tw $h
        if ($on) { Fill $g $K.accent $tx ($y + $h - 2) $tw 3 }
        $tx += $tw + 6
    }
    return $y + $h
}
# a switch (the settings): a square, filled with sand while on; its name and lines
function SwitchRow($g, $x, $y, $on, $name, $info, $w, $caps = $false) {
    $b = 32
    Fill $g $K.cell $x $y $b $b
    Frame $g $(if ($on) { $K.accent } else { $K.tileEdge }) $x $y $b $b 1
    if ($on) { Fill $g $K.accent ($x + 4) ($y + 4) ($b - 8) ($b - 8) }
    $tx = $x + $b + $P
    if ($caps) { TxtMid $g (Up $name) "head" 19 $(if ($on) { $K.bright } else { $K.dim }) $tx $y $b }
    else { TxtMid $g $name "body" 20 $(if ($on) { $K.bright } else { $K.text }) $tx $y $b }
    $ly = $y + $b + 6
    if ($info) {
        foreach ($line in (WrapCaps $g $info "body" 19 ($w - ($tx - $x)))) { Txt $g $line "body" 19 $K.dim $tx $ly; $ly += 26 }
    }
    return $ly
}
# a slider: name on the left, a track with a sand part, the knob, the value on the right
function Slider($g, $x, $y, $w, $name, $frac, $value, $labelW = 330) {
    $h = 32; $sx = $x + $labelW; $sw = $w - $labelW - 90
    TxtMid $g $name "body" 20 $K.text $x $y $h
    Fill $g $K.line $sx ($y + $h / 2 - 1) $sw 3
    Fill $g $K.accent $sx ($y + $h / 2 - 1) ([int]($sw * $frac)) 3
    Fill $g $K.accent ($sx + [int]($sw * $frac) - $h / 2) $y $h $h
    $vw = TextW $g $value "body" 20
    TxtMid $g $value "body" 20 $K.bright ($x + $w - $vw) $y $h
}
# a choice: its name, then a button per value - the chosen one in sand
function Choice($g, $x, $y, $name, $values, $active) {
    TxtMid $g $name "body" 20 $K.bright $x $y 32
    $bx = $x; $by = $y + 42
    for ($i = 0; $i -lt $values.Count; $i++) {
        $t = Up $values[$i]; $bw = (TextW $g $t "head" 17) + 36
        if ($i -eq $active) { Fill $g $K.accent $bx $by $bw 38; TxtCentre $g $t "head" 17 $K.ink $bx $by $bw 38 }
        else { Fill $g $K.buttonBg $bx $by $bw 38; Frame $g $K.tileFrame $bx $by $bw 38 1; TxtCentre $g $t "head" 17 $K.bright $bx $by $bw 38 }
        $bx += $bw + 10
    }
    return $by + 38
}
# a key or mouse gesture on a small framed plate ("RMB", "Shift+LMB", "T")
function KeyPlate($g, $x, $y, $text, $hot = $false) {
    $t = $text; $w = (TextW $g $t "head" 16) + 18
    Fill $g $(if ($hot) { $K.accent } else { $K.cell }) $x $y $w 28
    Frame $g $(if ($hot) { $K.accent } else { $K.tileEdge }) $x $y $w 28 1
    TxtCentre $g $t "head" 16 $(if ($hot) { $K.ink } else { $K.bright }) $x $y $w 28
    return $w
}
# an item tooltip: the coloured header with icon and name, a dim line, label / value rows
function Tooltip($g, $x, $y, $w, $cat, $icon, $name, $sub, $rows) {
    $h = 92 + $rows.Count * 34 + 14
    Fill $g $K.window $x $y $w $h; Frame $g $K.tileFrame $x $y $w $h 1
    Fill $g $K[$cat] ($x + 6) ($y + 6) ($w - 12) 80; Frame $g $K.tileFrame ($x + 6) ($y + 6) ($w - 12) 80 1
    DrawIcon $g $icon ($x + 14) ($y + 14) 64 64 1 64
    Txt $g $name "title" 23 $K.bright ($x + 92) ($y + 22)
    Txt $g $sub "body" 18 $K.dim ($x + 92) ($y + 56)
    $ry = $y + 100
    foreach ($r in $rows) {
        Txt $g $r[0] "body" 19 $K.text ($x + 16) $ry
        if ($r.Count -gt 2 -and $r[2] -ne $null) {
            $bx = $x + $w * 0.55; $bw = $w * 0.38
            Fill $g $K.line $bx ($ry + 4) $bw 6; Fill $g $r[3] $bx ($ry + 4) ([int]($bw * $r[2])) 6
        } else { Txt $g $r[1] "body" 19 $K.bright ($x + $w * 0.55) $ry }
        $ry += 34
    }
    return $h
}

# --- the news card's banner: a background with no words (the card writes over it) ---
# tiles: @(@(col,row,w,h,cat,icon,state)...) on a grid of 52 px cells; darkest on the left
function BannerPattern($name, $tiles, $cols = 17, $rows = 5) {
    $bmp, $g = Canvas 912 204 $K.screen
    $C0 = $script:C; $script:C = 52
    # ((-14), not -14: a bare -14 in a command's arguments is taken for a parameter's
    # name and the rest shift - the banners of 0.9.0 / 0.9.5 / 0.8.1 came out empty)
    Grid $g 8 (-14) $cols $rows
    foreach ($t in $tiles) { Tile $g 8 (-14) $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] $t[6] }
    $script:C = $C0
    Fill $g $K.screen 0 0 912 204 0.45
    $r = New-Object System.Drawing.Rectangle 0, 0, 912, 204
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, (A $K.screen 1), (A $K.screen 0), 0.0
    $blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.55, 1); $blend.Positions = [float[]]@(0, 0.30, 0.62, 1); $lg.Blend = $blend
    $g.FillRectangle($lg, $r)
    Save $bmp $g $name
}
# a picture from the game's files (the modes' raccoons, traits), drawn sharp
function DrawPic($g, $path, $x, $y, $w, $h, $a = 1, $smooth = $false) {
    $img = [System.Drawing.Image]::FromFile($path)
    $k = [math]::Min($w / $img.Width, $h / $img.Height); $dw = [int]($img.Width * $k); $dh = [int]($img.Height * $k)
    $im = $g.InterpolationMode
    $g.InterpolationMode = $(if ($smooth) { [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic } else { [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor })
    $ia = New-Object System.Drawing.Imaging.ImageAttributes; $ia.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    if ($a -lt 1) { $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$a; $ia.SetColorMatrix($cm) }
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]($x + ($w - $dw) / 2)), ([int]($y + ($h - $dh) / 2)), $dw, $dh), 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.InterpolationMode = $im
    $img.Dispose()
}
# a sand arrow (from one state of a thing to the next), pointing right
function ArrowRight($g, $x, $y, $len) {
    Fill $g $K.accent $x ($y - 3) ($len - 14) 6
    $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF ([float]($x + $len - 18)), ([float]($y - 13))), (New-Object System.Drawing.PointF ([float]($x + $len)), ([float]$y)), (New-Object System.Drawing.PointF ([float]($x + $len - 18)), ([float]($y + 13))))
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.FillPolygon((Br $K.accent), $pts)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
}