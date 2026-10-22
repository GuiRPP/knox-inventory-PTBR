# Draws the mod's art from a real in-game screenshot of the Knox screen
# (tools\art\screen_stage1.jpg, 2000x1125), in the screen's own frame:
#   42\poster.png  (256x256, mod list and Workshop preview)
#   42\icon.png    (64x64, mod list icon)
# Drawn at 1024 px and scaled down. Fonts: Fira Sans Extra Condensed from
# Zomboid\tools\fonts\candidates (the mod's own font).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_art.ps1 [-Stage "STAGE 1"] [-Screen path.jpg]
# The crop rectangles below are for the stage 1 screenshot; a new screenshot
# (same 2000x1125 Knox screen) needs them checked.

# -Camp draws the poster with the main menu's camp instead (tools\art\screen_menu.jpg,
# 2000x1125); the user chose to keep the inventory one (2026-10-12).
# -Now draws a candidate poster of the mod as it is now (inventory + camp + new game
# screens) to tools\art\poster_now.png / poster_now_1024.png; 42\poster.png is not touched.
param([string]$Lang = "en", [string]$Screen = "", [switch]$Camp, [switch]$Now)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$fontDir = Join-Path $env:USERPROFILE "Zomboid\tools\fonts\candidates"
if (-not $Screen) { $Screen = Join-Path $PSScriptRoot "art\screen_stage1.jpg" }
# texts from tools\art\gallery_<lang>.json (UTF-8); -Lang ru writes only tools\art\poster_ru*.png
$L = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "art\gallery_$Lang.json"), [Text.Encoding]::UTF8) | ConvertFrom-Json
$Stage = $L.poster_stage; $Note = $L.poster_note

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Join-Path $fontDir "FiraSansExtraCondensed-Bold.ttf"))
$pfc.AddFontFile((Join-Path $fontDir "FiraSansExtraCondensed-SemiBold.ttf"))
$family = $pfc.Families | Where-Object { $_.Name -like "*Extra Condensed*" } | Select-Object -First 1

function C([string]$hex, [int]$a = 255) {
    [System.Drawing.Color]::FromArgb($a, [Convert]::ToInt32($hex.Substring(1,2),16),
        [Convert]::ToInt32($hex.Substring(3,2),16), [Convert]::ToInt32($hex.Substring(5,2),16))
}
function Brush($hex, $a = 255) { New-Object System.Drawing.SolidBrush (C $hex $a) }
function Pen($hex, $w, $a = 255) { New-Object System.Drawing.Pen (C $hex $a), ([float]$w) }
function Font($px) { New-Object System.Drawing.Font $family, ([float]$px), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel) }

# Text with letter spacing (the "head" style of the Knox screen: capitals, spaced)
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

# A piece of the screenshot put in a panel frame of the Knox screen
function Piece($g, $img, $sx, $sy, $sw, $sh, $dx, $dy, $dw, $dh) {
    $g.FillRectangle((Brush "#121414"), $dx - 2, $dy - 2, $dw + 4, $dh + 4)
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle $dx, $dy, $dw, $dh), $sx, $sy, $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawRectangle((Pen "#2a2e2e" 3), $dx - 2, $dy - 2, $dw + 3, $dh + 3)
}

function Down($big, $size) {
    $small = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($small)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($big, 0, 0, $size, $size)
    $g.Dispose()
    return $small
}

function Poster([string]$out, [bool]$java) {
    $img = [System.Drawing.Image]::FromFile($Screen)
    $S = 1024
    $bmp = New-Object System.Drawing.Bitmap $S, $S
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear((C "#0b0c0c"))

    # top bar of the Knox screen: the name as the active tab, sand line under it
    $barH = 150
    $g.FillRectangle((Brush "#1a1d1d"), 0, 0, $S, $barH)
    $g.FillRectangle((Brush "#2a2e2e"), 0, $barH - 3, $S, 3)
    $title = Font 104
    $x1 = Spaced $g "KNOX" $title (Brush "#ece8d8") 40 6 4
    $x2 = Spaced $g "INVENTORY" $title (Brush "#d4c38a") ($x1 + 26) 6 4
    $g.FillRectangle((Brush "#d4c38a"), 40, $barH - 14, $x2 - 40, 8)
    if ($java) {
        $jf = Font 46
        $tw = $g.MeasureString("JAVA", $jf).Width
        $g.FillRectangle((Brush "#d4c38a"), $S - $tw - 56, 46, $tw + 22, 58)
        $g.DrawString("JAVA", $jf, (Brush "#141414"), $S - $tw - 46, 50)
    }

    # the screen itself, two rows of its pieces ({x, y, w, h} in the screenshot);
    # the bottom row fills the width, the top row takes the height left, centred
    $overlay = $null
    $gap = 22; $top = $barH + $gap; $bottom = $S - 110 - $gap
    if ($Camp) {
        # the camp: the fire, two of the heroes, the crosses and the lamp (left of the news cards)
        $camp = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot "art\screen_menu.jpg"))
        $dw = $S - 48; $dh = $bottom - $top
        $sh = 738; $sw = [int]($sh * $dw / $dh)
        Piece $g $camp 545 190 $sw $sh 24 $top $dw $dh
        $camp.Dispose()
    }
    $rowA = @(
        @(26, 126, 482, 580),      # equipment slots and the 3D character
        @(765, 371, 450, 503)      # inspect window with the 3D model
    )
    $rowB = @(
        @(1236, 148, 300, 352),    # surroundings grid: tiles, the duffel bag with its threads
        @(1221, 508, 349, 218),    # split dialog
        @(994, 120, 230, 236)      # surroundings list with fill bars
    )
    if ($Now) {
        $campShot = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot "art\screen_081_menu.jpg"))
        $modeShot = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot "art\screen_081_mode.jpg"))
        $rowB = @(
            @(540, 430, 960, 530, $campShot),   # the heroes by the fire
            @(80, 87, 450, 473, $modeShot)      # game mode cards
        )
    }
    # the belt slot's quick pick panel sticks out of the equipment column, as in game
    $popup = @(500, 363, 67, 91)
    function RowWidth($row, $h) { $w = 0; foreach ($p in $row) { $w += [int]($p[2] * $h / $p[3]) }; $w + $gap * ($row.Count - 1) }
    $ratioB = 0; foreach ($p in $rowB) { $ratioB += $p[2] / $p[3] }
    $hB = [int](($S - 48 - $gap * ($rowB.Count - 1)) / $ratioB)
    $hA = $bottom - $top - $gap - $hB
    $rows = @(@($rowA, $top, $hA), @($rowB, ($bottom - $hB), $hB))
    if ($Camp) { $rows = @() }
    foreach ($row in $rows) {
        $pieces, $y, $h = $row[0], $row[1], $row[2]
        $x = [int](($S - (RowWidth $pieces $h)) / 2)
        foreach ($p in $pieces) {
            $w = [int]($p[2] * $h / $p[3])
            $src = $(if ($p.Count -gt 4) { $p[4] } else { $img })
            Piece $g $src $p[0] $p[1] $p[2] $p[3] $x $y $w $h
            if ([object]::ReferenceEquals($p, $rowA[0])) {
                $k = $h / $p[3]
                $dst = New-Object System.Drawing.Rectangle ([int]($x + ($popup[0] - $p[0]) * $k)), ([int]($y + ($popup[1] - $p[1]) * $k)), ([int]($popup[2] * $k)), ([int]($popup[3] * $k))
                $overlay = $dst   # drawn last: it lies over its neighbour, as a popup does
            }
            $x += $w + $gap
        }
    }

    if ($overlay) {
        $g.DrawImage($img, $overlay, $popup[0], $popup[1], $popup[2], $popup[3], [System.Drawing.GraphicsUnit]::Pixel)
        $g.DrawRectangle((Pen "#0b0c0c" 2 120), $overlay.X - 1, $overlay.Y - 1, $overlay.Width + 1, $overlay.Height + 1)
    }

    # bottom bar: the stage in capitals, a key hint like the screen's [Tab] button
    $g.FillRectangle((Brush "#1a1d1d"), 0, $S - 110, $S, 110)
    $g.FillRectangle((Brush "#2a2e2e"), 0, $S - 110, $S, 3)
    $cap = Font 54
    if ($Now) {
        $x = Spaced $g "INVENTORY" $cap (Brush "#ece8d8") 40 ($S - 92) 3
        $x = Spaced $g "MENU" $cap (Brush "#d4c38a") ($x + 34) ($S - 92) 3
        $x = Spaced $g "NEW GAME" $cap (Brush "#ece8d8") ($x + 34) ($S - 92) 3
        $Note = ""
    } else {
    $x = Spaced $g $Stage $cap (Brush "#ece8d8") 40 ($S - 92) 3
    }
    Spaced $g $Note $cap (Brush "#d4c38a") ($x + 22) ($S - 92) 3 | Out-Null
    $kf = Font 40
    $kw = $g.MeasureString("Tab", $kf).Width + 24
    $kx = $S - 40 - $kw
    $g.FillRectangle((Brush "#121414"), $kx, $S - 86, $kw, 60)
    $g.DrawRectangle((Pen "#3c4141" 3), $kx, $S - 86, $kw, 60)
    $g.DrawString("Tab", $kf, (Brush "#d9d6c8"), $kx + 12, $S - 80)

    $g.Dispose()
    $img.Dispose()
    $small = Down $bmp 256
    $small.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    if ($Now) { $bmp.Save((Join-Path $PSScriptRoot "art\poster_now_1024.png"), [System.Drawing.Imaging.ImageFormat]::Png) } elseif (-not $java) {
        $big = $(if ($Lang -eq "en") { "art\poster_1024.png" } else { "art\poster_${Lang}_1024.png" })
        $bmp.Save((Join-Path $PSScriptRoot $big), [System.Drawing.Imaging.ImageFormat]::Png)
    }
    $small.Dispose(); $bmp.Dispose()
}

function Icon([string]$out, [bool]$java) {
    $img = [System.Drawing.Image]::FromFile($Screen)
    $S = 256
    $bmp = New-Object System.Drawing.Bitmap $S, $S
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear((C "#121414"))
    # the character from the screen, in a slot frame with the sand edge
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $S, $S), 150, 150, 230, 230, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawRectangle((Pen "#d4c38a" 12), 6, 6, $S - 12, $S - 12)
    if ($java) {
        $g.FillRectangle((Brush "#d4c38a"), $S - 110, $S - 86, 104, 80)
        $g.DrawString("J", (Font 72), (Brush "#141414"), $S - 86, $S - 92)
    }
    $g.Dispose()
    $img.Dispose()
    $small = Down $bmp 64
    $small.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $small.Dispose(); $bmp.Dispose()
}

if ($Now) {
    Poster (Join-Path $PSScriptRoot "art\poster_now.png") $false
    Write-Host "candidate poster written"
    return
}
if ($Lang -ne "en") {
    # another language: only a poster to look at, the mods keep the English one
    Poster (Join-Path $PSScriptRoot "art\poster_$Lang.png") $false
    Write-Host "art written"
    return
}
Poster (Join-Path $root "42\poster.png") $false
Icon (Join-Path $root "42\icon.png") $false
Write-Host "art written"
