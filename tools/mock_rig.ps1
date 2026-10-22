# A mockup of "Rigs" (Knox 1.0): bags and rigs with compartments, as Tarkov's - drawn
# with the parts of the Knox screen (news_ui.ps1), for the author to approve the look
# before any code. Same cells as now (2 per capacity unit), shaped into compartments.
#   tools\art\mock_rig.png
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\mock_rig.ps1

. (Join-Path $PSScriptRoot "news_ui.ps1")
$out = Join-Path $PSScriptRoot "art"

$GAP = 10   # between compartments

# a compartment: a grid of its own in a thin frame
function Pouch($g, $x, $y, $cols, $rows) {
    Grid $g $x $y $cols $rows
    Frame $g $K.tileFrame ($x - 2) ($y - 2) ($cols * $script:C + 4) ($rows * $script:C + 4) 2
}

# a bag's section: its header strip, then the compartments at cell offsets
# $parts: @(@(cx, cy, cols, rows)...) in cells, $items: @(@(part, col, row, w, h, cat, icon, count)...)
function BagSection($g, $x, $y, $name, $cells, $parts, $items) {
    $cl = $script:C
    $wCells = 0; $hCells = 0
    foreach ($p in $parts) { $wCells = [math]::Max($wCells, $p[0] + $p[2]); $hCells = [math]::Max($hCells, $p[1] + $p[3]) }
    $px = { param($c) $x + $c * $cl + [math]::Floor($c) * 0 }
    $w = $wCells * $cl + ($parts | ForEach-Object { $_[0] } | Sort-Object -Unique).Count * $GAP
    Strip $g $x $y ([math]::Max($w, 4 * $cl)) (Up $name) "$cells"
    $y0 = $y + 36 + 8
    $origins = @()
    foreach ($p in $parts) {
        # (a compartment further right or down sits a gap away from the ones before it)
        $ox = $x + $p[0] * $cl + ([array]::IndexOf(@($parts | ForEach-Object { $_[0] } | Sort-Object -Unique), $p[0])) * $GAP
        $oy = $y0 + $p[1] * $cl + ([array]::IndexOf(@($parts | ForEach-Object { $_[1] } | Sort-Object -Unique), $p[1])) * $GAP
        Pouch $g $ox $oy $p[2] $p[3]
        $origins += , @($ox, $oy)
    }
    foreach ($it in $items) {
        $o = $origins[$it[0]]
        $cnt = $null; if ($it.Count -gt 7) { $cnt = [string]$it[7] }
        Tile $g $o[0] $o[1] $it[1] $it[2] $it[3] $it[4] $it[5] $it[6] "" $cnt
    }
}

$bmp, $g = Canvas 1680 1000 $K.screen
Caption $g "РАЗГРУЗКА: СУМКИ С ОТСЕКАМИ (МАКЕТ)" 24 26
Txt $g "Клеток столько же, сколько сейчас - меняется форма. Большая вещь не влезет в маленький карман." "body" 20 $K.dim 24 66
$script:C = 52

# chest rig, 10 cells: four magazine pouches 1x2, two small 1x1
BagSection $g 40 120 "Разгрузочный жилет" "10" @(
    @(0, 0, 1, 2), @(1, 0, 1, 2), @(2, 0, 1, 2), @(3, 0, 1, 2), @(4, 0, 1, 1), @(4, 1, 1, 1)
) @(
    @(0, 0, 0, 1, 1, "wpn", "clip9"), @(1, 0, 0, 1, 1, "wpn", "clip9"), @(2, 0, 0, 1, 1, "wpn", "clip9"),
    @(4, 0, 0, 1, 1, "med", "bandage"), @(5, 0, 0, 1, 1, "med", "pills")
)

# school bag, 30: main 5x4, front pocket 3x2, two side pockets 1x2
BagSection $g 40 340 (GTr "ru" "ItemName" "Base.Bag_Schoolbag") "30" @(
    @(0, 0, 1, 2), @(1, 0, 5, 4), @(6, 0, 1, 2), @(2, 4, 3, 2)
) @(
    @(0, 0, 0, 1, 2, "food", "whiskey"), @(1, 0, 0, 2, 2, "info", "book_skill"), @(1, 2, 0, 1, 1, "food", "beans", 3),
    @(1, 0, 2, 1, 2, "tool", "screwdriver"), @(3, 0, 0, 1, 1, "info", "keyring"), @(3, 1, 0, 1, 1, "med", "bandage")
)

# big hiking bag, 42: top 4x2, main 5x6, side pockets 1x2
BagSection $g 560 120 (GTr "ru" "ItemName" "Base.Bag_BigHikingBag") "42" @(
    @(1, 0, 4, 2), @(0, 2, 1, 2), @(1, 2, 5, 6), @(6, 2, 1, 2)
) @(
    @(0, 0, 0, 1, 1, "info", "toiletpaper"), @(0, 1, 0, 1, 1, "tool", "torch"), @(0, 2, 0, 1, 1, "tool", "battery", 4),
    @(1, 0, 0, 1, 2, "food", "bottle"), @(2, 0, 0, 1, 4, "wpn", "bat"), @(2, 1, 0, 2, 2, "clo", "jacket"),
    @(2, 1, 2, 1, 1, "food", "beans", 5), @(2, 3, 0, 1, 2, "tool", "hammer")
)

# ALICE pack, 56: lid 4x2, main 6x6, three outer pouches 2x2
BagSection $g 1080 120 (GTr "ru" "ItemName" "Base.Bag_ALICEpack") "56" @(
    @(1, 0, 4, 2), @(0, 2, 6, 6), @(0, 8, 2, 2), @(2, 8, 2, 2), @(4, 8, 2, 2)
) @(
    @(0, 0, 0, 1, 1, "wpn", "ammobox9", 2), @(0, 1, 0, 1, 1, "med", "pills"),
    @(1, 0, 0, 1, 4, "wpn", "bat"), @(1, 1, 0, 2, 2, "clo", "jacket"), @(1, 3, 0, 1, 2, "food", "bottle"),
    @(1, 1, 2, 1, 1, "food", "beans", 4), @(1, 4, 0, 1, 2, "tool", "hammer"),
    @(2, 0, 0, 1, 1, "wpn", "clip9"), @(2, 1, 0, 1, 1, "wpn", "clip9"), @(3, 0, 0, 1, 1, "med", "bandage"),
    @(4, 0, 0, 1, 1, "info", "keyring")
)

$script:C = 64
Save $bmp $g "mock_rig.png"
