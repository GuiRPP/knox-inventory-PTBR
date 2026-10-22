# The roadmap picture for the Workshop description (1600 px wide, shown at ~640):
#   tools\art\roadmap.png
# A vertical track: what is released, Stage 1 (inventory) release by release, the later stages.
# Texts are below (ASCII only: Windows PowerShell reads .ps1 files in the ANSI code page).
# Keep it in step with ROADMAP.md.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_roadmap.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$art = Join-Path $PSScriptRoot "art"
$fontDir = Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates"
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
function SpacedWidth($g, $text, $font, $track) {
    $x = 0
    foreach ($ch in $text.ToCharArray()) {
        $s = [string]$ch
        $w = $g.MeasureString($s, $font, 1000, [System.Drawing.StringFormat]::GenericTypographic).Width
        if ($s -eq " ") { $w = $font.Size * 0.28 }
        $x += $w + $track
    }
    return $x
}
# a filled or outlined plate with spaced capitals; returns its width
function Plate($g, $text, $px, $x, $y, $filled, $hex = "#d4c38a") {
    $f = Bold $px
    $w = (SpacedWidth $g $text $f 2) + $px * 0.9
    $h = [int]($px * 1.5)
    if ($filled) {
        $g.FillRectangle((Brush $hex), $x, $y, $w, $h)
        Spaced $g $text $f (Brush "#141414") ($x + $px * 0.38) ($y + $px * 0.12) 2 | Out-Null
    } else {
        $g.DrawRectangle((Pen $hex 2), $x, $y, $w, $h)
        Spaced $g $text $f (Brush $hex) ($x + $px * 0.38) ($y + $px * 0.12) 2 | Out-Null
    }
    return $w
}
# a node of the track: a square on the line
function Node($g, $y, $state) {
    $x = 86; $s = 30
    $g.FillRectangle((Brush "#0b0c0c"), $x - 6, $y - 6, $s + 12, $s + 12)
    if ($state -eq "done") {
        $g.FillRectangle((Brush "#d4c38a"), $x, $y, $s, $s)
        $p = Pen "#141414" 4
        $g.DrawLines($p, @((New-Object System.Drawing.PointF ($x + 7), ($y + 16)), (New-Object System.Drawing.PointF ($x + 13), ($y + 22)), (New-Object System.Drawing.PointF ($x + 23), ($y + 9))))
    } elseif ($state -eq "now") {
        $g.DrawRectangle((Pen "#d4c38a" 4), $x + 2, $y + 2, $s - 4, $s - 4)
        $g.FillRectangle((Brush "#d4c38a"), $x + 10, $y + 10, $s - 20, $s - 20)
    } else {
        $g.DrawRectangle((Pen "#3c4141" 3), $x + 1, $y + 1, $s - 3, $s - 3)
    }
}
function Thumb($g, $file, $r, $dx, $dy, $dw, $dh) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $art $file))
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh), $r[0], $r[1], $r[2], $r[3], [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawRectangle((Pen "#3c4141" 3), $dx, $dy, $dw - 1, $dh - 1)
    $img.Dispose()
}

$dot = [string][char]0xB7
$W = 1600; $CH = 1610
$bmp = New-Object System.Drawing.Bitmap $W, $CH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear((C "#0b0c0c"))

# header
$g.FillRectangle((Brush "#1a1d1d"), 0, 0, $W, 230)
$g.FillRectangle((Brush "#2a2e2e"), 0, 227, $W, 3)
$x = Spaced $g "KNOX" (Bold 40) (Brush "#ece8d8") 60 34 3
Spaced $g "INVENTORY" (Bold 40) (Brush "#d4c38a") ($x + 12) 34 3 | Out-Null
$xe = Spaced $g "ROADMAP" (Bold 120) (Brush "#ece8d8") 56 72 6
$g.FillRectangle((Brush "#d4c38a"), 60, 212, $xe - 66, 9)
$pw = (SpacedWidth $g "ONE RELEASE - ONE THEME" (Bold 34) 2) + 34 * 0.9
Plate $g "ONE RELEASE - ONE THEME" 34 ($W - 60 - $pw) 118 $false | Out-Null

# the track
$g.FillRectangle((Brush "#2a2e2e"), 99, 290, 4, $CH - 290 - 150)
$g.FillRectangle((Brush "#d4c38a"), 99, 290, 4, 330)

$cx = 170; $cw = $W - 60 - $cx

# --- released ---------------------------------------------------------------
$y = 280; $h = 300
$g.FillRectangle((Brush "#121414"), $cx, $y, $cw, $h)
$g.DrawRectangle((Pen "#2a2e2e" 3), $cx + 1, $y + 1, $cw - 3, $h - 3)
Node $g ($y + 26) "done"
Spaced $g "RELEASED" (Bold 38) (Brush "#d4c38a") ($cx + 32) ($y + 18) 3 | Out-Null
$done = @(@("0.5", "PUBLIC TEST"), @("0.6", "LIQUIDS"), @("0.7", "TV AND RADIO"), @("0.8", "MENU, NEW GAME"))
for ($i = 0; $i -lt 4; $i++) {
    $rx = $cx + 32 + ($i % 2) * 420; $ry = $y + 92 + [math]::Floor($i / 2) * 96
    $g.FillRectangle((Brush "#1a1d1d"), $rx, $ry, 400, 78)
    $g.FillRectangle((Brush "#d4c38a"), $rx, $ry, 6, 78)
    $g.DrawString($done[$i][0], (Bold 46), (Brush "#d4c38a"), $rx + 20, $ry + 10)
    Spaced $g $done[$i][1] (Bold 32) (Brush "#ece8d8") ($rx + 104) ($ry + 20) 1 | Out-Null
}
$tx = $cx + 32 + 840 + 24; $tw = $cx + $cw - 32 - $tx
$th = [int](($h - 92 - 30 - 14) / 2)
Thumb $g "screen_stage1.jpg" @(26, 130, 1200, 307) $tx ($y + 30) $tw ($th + 30)
Thumb $g "screen_081_menu.jpg" @(380, 560, 1290, 330) $tx ($y + 30 + $th + 44) $tw ($th + 30)

# --- stage 1 ----------------------------------------------------------------
$y = 620; $h = 580
$g.FillRectangle((Brush "#121414"), $cx, $y, $cw, $h)
$g.FillRectangle((Brush "#1a1d1d"), $cx, $y, $cw, 104)
$g.DrawRectangle((Pen "#d4c38a" 4), $cx + 2, $y + 2, $cw - 4, $h - 4)
Node $g ($y + 36) "now"
$x = Spaced $g "STAGE 1" (Bold 38) (Brush "#d4c38a") ($cx + 32) ($y + 30) 3
Spaced $g "INVENTORY" (Bold 64) (Brush "#ece8d8") ($x + 26) ($y + 10) 3 | Out-Null
$pw = (SpacedWidth $g "IN PROGRESS" (Bold 32) 2) + 32 * 0.9
Plate $g "IN PROGRESS" 32 ($cx + $cw - 32 - $pw) ($y + 28) $true | Out-Null
# 0.9.0 is the next release; an open run of updates follows it, and 1.0 closes the stage
$ry = $y + 124
$g.DrawString("0.9.0", (Bold 62), (Brush "#d4c38a"), $cx + 26, $ry + 6)
$x = Spaced $g "CONVENIENCE AND SETTINGS" (Bold 40) (Brush "#ece8d8") ($cx + 220) ($ry + 2) 2
Plate $g "NEXT" 26 ($x + 20) ($ry + 8) $true | Out-Null
$g.DrawString("Search and filters, favorites and item locks, sorting rules, settings:`nbackground opacity, mouse scheme and keys, mod modules on / off and more", (Plain 33), (Brush "#b9b7aa"), (New-Object System.Drawing.RectangleF ($cx + 221), ($ry + 50), ($cw - 221 - 6), 100))

$ry = $y + 290
$dash = Pen "#3c4141" 2
$dash.DashPattern = [single[]](6, 6)
$g.DrawLine($dash, $cx + 32, $ry, $cx + $cw - 32, $ry)
$g.DrawLine($dash, $cx + 32, $ry + 126, $cx + $cw - 32, $ry + 126)
for ($i = 0; $i -lt 3; $i++) { $g.FillRectangle((Brush "#8f9289"), $cx + 84, $ry + 30 + $i * 28, 12, 12) }
Spaced $g "MORE UPDATES IN BETWEEN" (Bold 36) (Brush "#8f9289") ($cx + 221) ($ry + 20) 2 | Out-Null
$g.DrawString("As many as the inventory needs - your feedback decides what goes in", (Plain 33), (Brush "#8f9289"), $cx + 221, $ry + 64)

$ry = $y + 440
$g.DrawString("1.0", (Bold 62), (Brush "#8f9289"), $cx + 26, $ry + 6)
Spaced $g "STAGE 1 COMPLETE" (Bold 40) (Brush "#ece8d8") ($cx + 220) ($ry + 2) 2 | Out-Null
$g.DrawString("The inventory is finished: everything works, plays well and is polished", (Plain 33), (Brush "#b9b7aa"), $cx + 221, $ry + 50)

# --- later stages -----------------------------------------------------------
$y = 1240; $h = 220; $gap = 26
$later = @(
    @("STAGE 2", "HEALTH", "2.0", "Injuries on your character's body, treatment in a click"),
    @("STAGE 3", "SKILLS, MAP", "2.5", "Skills and progress, the world map"),
    @("STAGE 4", "THE REST", "3.0", "Crafting, building, vehicles - you vote on the order")
)
Node $g ($y + 24) "later"
$w3 = [int](($cw - 2 * $gap) / 3)
for ($i = 0; $i -lt 3; $i++) {
    $s = $later[$i]; $x0 = $cx + $i * ($w3 + $gap)
    $g.FillRectangle((Brush "#121414"), $x0, $y, $w3, $h)
    $g.DrawRectangle((Pen "#3c4141" 3), $x0 + 1, $y + 1, $w3 - 3, $h - 3)
    Spaced $g $s[0] (Bold 30) (Brush "#8f9289") ($x0 + 27) ($y + 16) 3 | Out-Null
    $vf = Bold 30
    $vw = $g.MeasureString($s[2], $vf).Width
    $g.DrawString($s[2], $vf, (Brush "#8f9289"), $x0 + $w3 - $vw - 18, $y + 16)
    Spaced $g $s[1] (Bold 52) (Brush "#d9d6c8") ($x0 + 23) ($y + 52) 2 | Out-Null
    $g.DrawString($s[3], (Plain 31), (Brush "#8f9289"), (New-Object System.Drawing.RectangleF ($x0 + 27), ($y + 124), ($w3 - 44), 90))
}

# footer
$g.FillRectangle((Brush "#1a1d1d"), 0, $CH - 110, $W, 110)
$g.FillRectangle((Brush "#2a2e2e"), 0, $CH - 110, $W, 3)
$g.DrawString("No dates on purpose: a release is announced when it is ready. Not soon: multiplayer, controller.", (Plain 34), (Brush "#8f9289"), 60, $CH - 78)

$g.Dispose()
$bmp.Save((Join-Path $art "roadmap.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "roadmap.png written"
