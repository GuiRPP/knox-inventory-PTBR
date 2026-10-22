# The pictures of every "technical update" post (fixes, speed, compatibility - no new
# content; the author's idea, 2026-10-22): one banner for all of them and one picture
# on the right, by the approved news rules (see make_news_096.ps1 and news_ui.ps1).
#   42\media\knox\news\tech_banner.png          (no words: one for both languages)
#   42\media\knox\news\tech_art_<ru|en>.png
# The banner is a scene of its own, not a row of icons (the author, 2026-10-22: the gear
# alone, the tools across it taken away): a gear in sand light on a faint drawing grid.
# The big picture's empty dark is filled the same way: the grid all over, the gear huge
# and faint behind, light under the window.
# A post gets them with the "tech" kind (KnoxMenuNews: its pictures unless it has its own).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_news_tech.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")

# the technical update's steel blue (KnoxNews.TECH_COLOR: the card's frame) - the gear,
# its light and the drawing grid in it too (the author, 2026-10-22)
$STEEL = Hex "#86a8bf"
$STEEL_GRID = Hex "#3a4d5a"

$L = @{
    ru = @{
        artTitle = "ТЕХНИЧЕСКИЙ АПДЕЙТ"
        rows = @("ИСПРАВЛЕНИЯ ОШИБОК", "СКОРОСТЬ", "СОВМЕСТИМОСТЬ С ДРУГИМИ МОДАМИ")
        note = "НИЧЕГО НОВОГО В ИГРЕ - ТОЛЬКО ЧТОБЫ ВСЁ РАБОТАЛО ЧИЩЕ, БЫСТРЕЕ И НАДЁЖНЕЕ."
    }
    en = @{
        artTitle = "TECHNICAL UPDATE"
        rows = @("BUG FIXES", "SPEED", "COMPATIBILITY WITH OTHER MODS")
        note = "NOTHING NEW TO PLAY WITH - ONLY EVERYTHING WORKING CLEANER, FASTER AND MORE RELIABLY."
    }
}

# --- the scene's parts, drawn smooth (vector), in the Knox palette ------------------

function Smooth($g) { $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias }
function Sharp($g) { $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None }
function PenOf($c, $a, $w) {
    $p = New-Object System.Drawing.Pen (A $c $a), ([float]$w)
    $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $p
}
function PtF($x, $y) { New-Object System.Drawing.PointF ([float]$x), ([float]$y) }

# a faint drawing grid: lines every `step` px, every fourth a little brighter
function DrawingGrid($g, $x, $y, $w, $h, $step, $a) {
    $i = 0
    for ($gx = $x; $gx -le $x + $w; $gx += $step) {
        $lit = $(if ($i % 4 -eq 0) { 1.8 } else { 1 }); Fill $g $STEEL_GRID $gx $y 1 $h ($a * $lit); $i++
    }
    $i = 0
    for ($gy = $y; $gy -le $y + $h; $gy += $step) {
        $lit = $(if ($i % 4 -eq 0) { 1.8 } else { 1 }); Fill $g $STEEL_GRID $x $gy $w 1 ($a * $lit); $i++
    }
}

# soft round light of colour c at cx, cy (radius r), strongest `a` in the middle
function Glow($g, $cx, $cy, $r, $c, $a) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddEllipse([float]($cx - $r), [float]($cy - $r), [float](2 * $r), [float](2 * $r))
    $b = New-Object System.Drawing.Drawing2D.PathGradientBrush $p
    $b.CenterColor = A $c $a
    $b.SurroundColors = [System.Drawing.Color[]]@((A $c 0))
    $bl = New-Object System.Drawing.Drawing2D.Blend; $bl.Factors = [float[]]@(0, 0.35, 1); $bl.Positions = [float[]]@(0, 0.55, 1); $b.Blend = $bl
    $g.FillPath($b, $p)
}

# a gear: `teeth` teeth between radius rIn and rOut, a hub with its hole, four windows
function GearPath($cx, $cy, $rOut, $rIn, $teeth) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pts = @()
    $step = 2 * [math]::PI / $teeth
    for ($tk = 0; $tk -lt $teeth; $tk++) {
        $a0 = $tk * $step
        foreach ($d in @(@(-0.30, $rIn), @(-0.18, $rOut), @(0.18, $rOut), @(0.30, $rIn))) {
            $an = $a0 + $d[0] * $step * 1.6
            $pts += PtF ($cx + $d[1] * [math]::Cos($an)) ($cy + $d[1] * [math]::Sin($an))
        }
    }
    $p.AddPolygon([System.Drawing.PointF[]]$pts)
    return $p
}
function Gear($g, $cx, $cy, $r, $fillA, $lineA, $lineW) {
    $teeth = 12
    $p = GearPath $cx $cy $r ($r * 0.84) $teeth
    $g.FillPath((Br $K.header $fillA), $p)
    $g.DrawPath((PenOf $STEEL $lineA $lineW), $p)
    # the rim inside the teeth, the hub, its hole and four windows between the spokes
    $g.DrawEllipse((PenOf $STEEL ($lineA * 0.55) ($lineW * 0.8)), [float]($cx - $r * 0.7), [float]($cy - $r * 0.7), [float]($r * 1.4), [float]($r * 1.4))
    for ($wi = 0; $wi -lt 4; $wi++) {
        $w = New-Object System.Drawing.Drawing2D.GraphicsPath
        $a1 = $wi * 90 + 14; $sw = 62
        $w.AddArc([float]($cx - $r * 0.6), [float]($cy - $r * 0.6), [float]($r * 1.2), [float]($r * 1.2), [float]$a1, [float]$sw)
        $w.AddArc([float]($cx - $r * 0.32), [float]($cy - $r * 0.32), [float]($r * 0.64), [float]($r * 0.64), [float]($a1 + $sw), [float](-$sw))
        $w.CloseFigure()
        $g.FillPath((Br $K.screen ($fillA * 0.9)), $w)
        $g.DrawPath((PenOf $STEEL ($lineA * 0.45) ($lineW * 0.7)), $w)
    }
    $g.DrawEllipse((PenOf $STEEL $lineA $lineW), [float]($cx - $r * 0.2), [float]($cy - $r * 0.2), [float]($r * 0.4), [float]($r * 0.4))
    $g.FillEllipse((Br $K.screen $fillA), [float]($cx - $r * 0.11), [float]($cy - $r * 0.11), [float]($r * 0.22), [float]($r * 0.22))
}

# the whole scene: the gear in its light
# (`power`: how strong - full on the banner, faint behind the big picture)
function Scene($g, $cx, $cy, $s, $power) {
    Smooth $g
    Glow $g $cx $cy ($s * 0.9) $STEEL (0.22 * $power)
    Gear $g $cx $cy ($s * 0.42) (0.95 * $power) (0.55 * $power) ([math]::Max(2, $s * 0.008))
    Sharp $g
}

# the toolbox's grid: {col, row, w, h, category, icon, state, count} - the tools at
# their Knox sizes (KnoxFootprintData: wrenches 1x3, a screwdriver 1x2, tape 1x1...)
$box = @(
    @(0, 0, 1, 3, "tool", "wrench", "", $null), @(1, 0, 1, 3, "tool", "pipewrench", "hit", $null),
    @(2, 0, 1, 2, "tool", "screwdriver", "", $null), @(3, 0, 1, 2, "tool", "pliers", "", $null),
    @(4, 0, 1, 2, "tool", "hammer", "", $null), @(5, 0, 1, 2, "tool", "ratchet", "hit", $null),
    @(6, 0, 1, 2, "tool", "multitool", "", $null), @(7, 0, 1, 3, "tool", "hacksaw", "", $null),
    @(8, 0, 1, 1, "mat", "tape", "", "4"), @(9, 0, 1, 1, "mat", "glue", "", "2"),
    @(10, 0, 1, 1, "mat", "nails", "", "40"), @(11, 0, 1, 1, "mat", "scrap", "", "20"),
    @(8, 1, 1, 1, "mat", "screws", "", "25"), @(2, 2, 1, 1, "mat", "tape", "", "3"),
    @(3, 2, 1, 2, "tool", "screwdriver", "", $null)
)

foreach ($lang in "ru", "en") {
    $s = $L[$lang]
    Write-Host "technical update pictures ($lang):"

    # --- art: the drawing grid all over, the scene huge and faint at the bottom right,
    # light under the window; the toolbox, the three switches and the line over it
    # (the whole picture in the kind's colour: the window's frame, the switches, the lit
    # tiles, the title - the post's own palette, as its card; the author, 2026-10-22)
    $sand = $K.accent; $K.accent = $STEEL
    $bmp, $g = Canvas 960 1080 $K.cell
    DrawingGrid $g 0 0 960 1080 32 0.10
    Scene $g 830 960 820 0.2
    Smooth $g; Glow $g 480 360 520 $STEEL 0.07; Sharp $g
    Caption $g $s.artTitle 64 56 30 $K.accent
    $cols = 12; $rows = 5
    $wx = 64; $wy = 140; $ww = $cols * $C + 4 * $P; $wh = 44 + 2 * $P + $rows * $C + 2 * $P
    Win $g $wx $wy $ww $wh (GTr $lang "ItemName" "Base.Toolbox")
    $gx = $wx + 2 * $P; $gy = $wy + 44 + 2 * $P
    Grid $g $gx $gy $cols $rows
    foreach ($t in $box) { Tile $g $gx $gy $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] $t[6] $t[7] }
    $y = $wy + $wh + 56
    foreach ($r in $s.rows) {
        SwitchRow $g ($wx + 8) $y $true $r $null ($ww - 16) $true | Out-Null
        $y += 62
    }
    CapsBlock $g $s.note $wx ($y + 24) $ww 19 $K.accent 28 | Out-Null
    Save $bmp $g "tech_art_$lang.png"
    $K.accent = $sand
}

# --- banner, no words (one for both languages): the scene on the right in its light,
# the drawing grid behind, darkest on the left where the card writes
Write-Host "technical update banner:"
$bmp, $g = Canvas 912 204 $K.screen
DrawingGrid $g 0 0 912 204 26 0.16
Scene $g 738 102 228 1
$r = New-Object System.Drawing.Rectangle 0, 0, 912, 204
$lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $r, (A $K.screen 1), (A $K.screen 0), 0.0
$blend = New-Object System.Drawing.Drawing2D.Blend; $blend.Factors = [float[]]@(0, 0, 0.6, 1); $blend.Positions = [float[]]@(0, 0.28, 0.58, 1); $lg.Blend = $blend
$g.FillRectangle($lg, $r)
Save $bmp $g "tech_banner.png"
