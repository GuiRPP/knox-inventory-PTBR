# Pictures of the Workshop page, version 2 (2026-10-21): the page tells Knox as one
# interface of the whole game, a module at a time, a picture or GIF for each. By the
# news rules (see make_news_096.ps1 and news_ui.ps1): only Knox's own interface, drawn
# from the mod's and the game's files - news_ui's parts, the pieces make_news_road10.ps1
# draws (rigs, the item menu, the alarm) - or drawn for real: the dashboard is
# KnoxDashboard.lua itself run outside the game (tools\page\dash_frames.ps1, painted by
# tools\dash\snap.ps1); the device windows are the news pictures' own windows. Captions
# in capitals, in a bar under the picture, as the page's GIFs of 0.8 had them. English
# only (the page is in English).
#   tools\art\page_v2\<name>.gif / .png   800 px wide, the bar 48 px
#     hero      the pieces of Knox one after another - one interface
#     modules   the Modules page, switches going off and on
#     rigs      a bag's compartments, a thing and a bag going in, the cubes, a section folding
#     search    a cupboard searched thing by thing, the loot scattered, Ctrl+S
#     menu      the tooltip opening into the menu, groups, chips, recipes
#     devices   TV, radio, walkie-talkie, stove, pouring, container info, alarm
#     dash      the sedan at night: key, lamp check, start, lights, gears, the tape; the pickup on wires
#     music     the radio by the fire and the car's tape (still)
#     extras    the tooltip and the sound sliders (still)
#   inv_space.gif: a copy of tools\art\page\space_weight_en.gif (make_page_gifs.ps1)
# Needs ffmpeg in PATH.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_page_v2.ps1 [-Only name[,name]]

param([string]$Only = "")

. (Join-Path $PSScriptRoot "news_ui.ps1")

# the drawing pieces of the Road to 1.0 news (its functions and their settings, not its pictures)
function Get-Defs($file) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null)
    $keep = foreach ($st in $ast.EndBlock.Statements) {
        if ($st -is [System.Management.Automation.Language.ForEachStatementAst]) { continue }
        if ($st.Extent.Text -match 'news_ui\.ps1') { continue }
        $st.Extent.Text
    }
    return ($keep -join "`n")
}
. ([scriptblock]::Create((Get-Defs (Join-Path $PSScriptRoot "make_news_road10.ps1"))))

$out = Join-Path $PSScriptRoot "art\page_v2"
New-Item -ItemType Directory -Force $out | Out-Null
$work = Join-Path $env:TEMP "knox_page_v2"
New-Item -ItemType Directory -Force $work | Out-Null
$news = Join-Path $root "42\media\knox\news"
$lang = "en"
$PW = 800; $BAR = 48

# The backdrop: the main menu's camp itself (a screenshot of the game, tools\art\screen_menu.jpg -
# the fire and the heroes, without the menu's words and news cards), blurred and dimmed behind
# every scene, so that the windows don't stand in an empty dark (the author, 2026-10-21)
$campBlur = Join-Path $work "camp_blur.png"
ffmpeg -v error -y -i (Join-Path $PSScriptRoot "art\screen_menu.jpg") -vf "crop=1020:574:520:330,scale=1600:900,gblur=sigma=24,eq=saturation=0.85" $campBlur
$campImg = [System.Drawing.Image]::FromFile($campBlur)
function Backdrop($w, $h) {
    $bmp, $g = Canvas $w $h $K.screen
    $k2 = [math]::Max([double]($w / $campImg.Width), [double]($h / $campImg.Height))
    $dw = $campImg.Width * $k2; $dh = $campImg.Height * $k2
    $g.DrawImage($campImg, (New-Object System.Drawing.RectangleF ([float](($w - $dw) / 2)), ([float](($h - $dh) / 2)), ([float]$dw), ([float]$dh)))
    Fill $g $K.screen 0 0 $w $h 0.32
    return @($bmp, $g)
}

# --- frames, the caption bar, the GIF ---------------------------------------------------
$script:fi = 0
$frames = Join-Path $work "frames"
function BeginGif() {
    if (Test-Path $frames) { Remove-Item -Recurse -Force $frames }
    New-Item -ItemType Directory -Force $frames | Out-Null
    $script:fi = 0
}
# the scene (any size) scaled to the page's width, the caption in a bar under it
function Shot($scene, $caption) {
    $ch = [int][math]::Round($scene.Height * $PW / $scene.Width)
    $bmp = New-Object System.Drawing.Bitmap $PW, ($ch + $BAR)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear($K.screen)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($scene, (New-Object System.Drawing.Rectangle 0, 0, $PW, $ch))
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    Fill $g $K.header 0 $ch $PW $BAR
    Fill $g $K.accent 0 $ch $PW 2
    Fill $g $K.accent 18 ($ch + 19) 12 12
    $t = $caption.ToUpper(); $px = 22
    while ($px -gt 15 -and (TextW $g $t "head" $px) -gt ($PW - 60)) { $px-- }
    TxtMid $g $t "head" $px $K.bright 42 ($ch + 2) ($BAR - 2)
    $g.Dispose()
    return $bmp
}
function Add($scene, $caption, $times = 1) {
    $bmp = Shot $scene $caption
    for ($i = 0; $i -lt $times; $i++) {
        $bmp.Save((Join-Path $frames ("f{0:D4}.png" -f $script:fi)), [System.Drawing.Imaging.ImageFormat]::Png)
        $script:fi++
    }
    $bmp.Dispose()
}
function EndGif($name, $fps = 12, $colors = 160, $dither = "bayer") {
    $gif = Join-Path $out "$name.gif"
    $pal = Join-Path $frames "palette.png"
    $use = $(if ($dither -eq "none") { "paletteuse=dither=none:diff_mode=rectangle" } else { "paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" })
    ffmpeg -v error -y -framerate $fps -i (Join-Path $frames "f%04d.png") -vf "palettegen=max_colors=${colors}:stats_mode=full" $pal
    ffmpeg -v error -y -framerate $fps -i (Join-Path $frames "f%04d.png") -i $pal -lavfi $use -loop 0 $gif
    Write-Host ("  {0}.gif  {1} frames  {2:N0} bytes" -f $name, $script:fi, (Get-Item $gif).Length)
}
function SavePng($scene, $caption, $name) {
    $bmp = Shot $scene $caption
    $p = Join-Path $out "$name.png"
    $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host ("  {0}.png  {1:N0} bytes" -f $name, (Get-Item $p).Length)
}
function Ease($t) { if ($t -le 0) { 0 } elseif ($t -ge 1) { 1 } else { 1 - (1 - $t) * (1 - $t) * (1 - $t) } }
function Lerp($a, $b, $t) { $a + ($b - $a) * $t }
# a piece of a picture file drawn into x, y, w, h (the news pictures' windows)
function Crop($g, $file, $sx, $sy, $sw, $sh, $x, $y, $w, $h, $a = 1) {
    $img = [System.Drawing.Image]::FromFile($file)
    $ia = New-Object System.Drawing.Imaging.ImageAttributes
    if ($a -lt 1) { $cm = New-Object System.Drawing.Imaging.ColorMatrix; $cm.Matrix33 = [float]$a; $ia.SetColorMatrix($cm) }
    $im = $g.InterpolationMode; $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle ([int]$x), ([int]$y), ([int]$w), ([int]$h)), $sx, $sy, $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel, $ia)
    $g.InterpolationMode = $im
    $img.Dispose()
}
function Want($name) { -not $Only -or ($Only.Split(",") -contains $name) }

# --- the inventory's parts at the 48 px cell (1080p), as KnoxInventoryPanel draws them ------
# a bag's header: its name, the cubes of the cells (sand) and of the weight (green,
# yellow from 80 %, red over), the numbers right of each, the fold button at the end
#   prev: @(used, weight) before the last change, t 0..1: the cubes easing from it (shownLit)
function BagHeader($g, $x, $y, $w, $name, $used, $total, $wt, $cap, $prev = $null, $t = 1) {
    Fill $g $K.header $x $y $w 36
    TxtMid $g (Up $name) "head" 18 $K.bright ($x + 10) $y 36
    # the fold button
    $bx = $x + $w - 32; Fill $g $K.buttonBg $bx ($y + 4) 28 28; Frame $g $K.tileEdge $bx ($y + 4) 28 28 1
    Chev $g ($bx + 14) ($y + 18) $K.dim "d"
    $right = $bx - 12
    $fw = $wt / $cap
    $wc = $(if ($fw -gt 1) { $K.bad } elseif ($fw -ge 0.8) { $K.warn } else { $K.good })
    # (round1 in Lua: 15 stays "15", 3.4 is "3.4")
    if (-not $prev) { $prev = @($used, $wt) }
    $meters = @(@((("{0:0.#}/{1:0.#} kg" -f $wt, $cap).Replace(",", ".")), $fw, $wc, ($prev[1] / $cap)), @("$used/$total", ($used / $total), $K.accent, ($prev[0] / $total)))
    # ten cubes a meter; five where ten would cut the bag's name
    $cs = 7; $gap = 2; $n = 10
    $need = $x + 10 + (TextW $g (Up $name) "head" 18) + 26
    $left = $right; foreach ($m in $meters) { $left -= (TextW $g $m[0] "body" 17) + 6 + 10 * $cs + 9 * $gap + 12 }
    if ($left -lt $need) { $n = 5 }
    $mw = $n * $cs + ($n - 1) * $gap
    foreach ($m in $meters) {
        $tw = TextW $g $m[0] "body" 17
        Txt $g $m[0] "body" 17 $K.dim ($right - $tw) ($y + 12)
        $cx0 = $right - $tw - 6 - $mw
        $litOf = { param($f) if ($f -gt 0) { [math]::Max(1, [math]::Min($n, [math]::Ceiling($f * $n - 1e-6))) } else { 0 } }
        $lit = Lerp (& $litOf $m[3]) (& $litOf $m[1]) $t
        for ($i = 0; $i -lt $n; $i++) {
            $qx = $cx0 + $i * ($cs + $gap); $qy = $y + [math]::Floor((36 - $cs) / 2)
            Fill $g $K.border $qx $qy $cs $cs
            $a = [math]::Max(0, [math]::Min(1, $lit - $i))
            if ($a -gt 0) { Fill $g $m[2] $qx $qy $cs $cs $a }
        }
        $right = $cx0 - 12
    }
}
# where cell col, row of compartment idx of a shape at x, y is on the picture
function CellXY($geo, $x, $y, $idx, $col, $row) {
    $pt = $geo.parts[$idx]
    return @(($x + $pt.x + $col * $geo.cell), ($y + $pt.y + $row * $geo.cell))
}
function DropOn($g, $px, $py, $w, $h, $cell, $ok) {
    $mc = $(if ($ok) { $K.ok } else { $K.bad })
    Fill $g $mc ($px + 1) ($py + 1) ($w * $cell - 1) ($h * $cell - 1) 0.22
    Frame $g $mc ($px + 1) ($py + 1) ($w * $cell - 1) ($h * $cell - 1) 1
}
function HeldTile($g, $x, $y, $w, $h, $cat, $icon, $cell) {
    $script:C = $cell
    Held $g $x $y $w $h $cat $icon
    $script:C = 64
}

# the small backpack (KnoxBagShapes: side pockets, the main room, the front pocket) with
# things at their Knox sizes (KnoxFootprintData: books, hoodies and crisps 1x2)
function SchoolBagV2($g, $x, $y, $cell) {
    $geo = ShapeGeo "1x2 4x5 1x2 / 3x2" $cell
    DrawShape $g $x $y $geo
    PartTile $g $x $y $geo 0 0 0 1 2 "food" "bottle"
    PartTile $g $x $y $geo 2 0 0 1 2 "tool" "torch"
    PartTile $g $x $y $geo 1 0 0 1 2 "info" "book_skill"
    PartTile $g $x $y $geo 1 1 0 1 2 "food" "chips"
    PartTile $g $x $y $geo 1 2 0 1 1 "food" "beans"
    PartTile $g $x $y $geo 1 2 1 1 2 "tool" "knife"
    PartTile $g $x $y $geo 1 0 2 1 2 "clo" "hoodie"
    PartTile $g $x $y $geo 3 0 0 1 1 "misc" "idcard"
    PartTile $g $x $y $geo 3 1 0 1 1 "misc" "keyring"
    PartTile $g $x $y $geo 3 2 0 1 1 "misc" "wallet"
}
# the inventory column at x, y, w, h: pockets (folded by `fold` 0..1) and the small backpack
# with what is in it (`extra`: @{idx; col; row; w; h; cat; icon}); returns the bag's geometry
# and where it lies
function InvColumn($g, $x, $y, $w, $h, $fold, $extra, $used, $wt, $prev = $null, $t = 1) {
    Column $g $x $y $w $h (Tr $lang "IGUI_Knox_Inventory") "6.8 / 12"
    $cell = 48; $script:C = $cell
    $sx = $x + $P; $hw = $w - 2 * $P
    $sy = $y + 64
    Strip $g $sx $sy $hw (Up (Tr $lang "IGUI_Knox_Pockets")) "4x2"
    $gh = [math]::Round(2 * $cell * (1 - $fold))
    if ($gh -gt 0) {
        $g.SetClip((New-Object System.Drawing.Rectangle ([int]$sx), ([int]($sy + 36)), ([int]$hw), ([int]$gh + 1)))
        $gy = $sy + 36 - (2 * $cell - $gh)
        Grid $g $sx $gy 4 2
        Tile $g $sx $gy 0 0 1 1 "misc" "idcard"; Tile $g $sx $gy 1 0 1 1 "misc" "keyring"
        Tile $g $sx $gy 2 0 1 1 "tool" "knife_pocket"; Tile $g $sx $gy 0 1 1 1 "misc" "wallet"
        $g.ResetClip()
    }
    $by = $sy + 36 + $gh + 14
    BagHeader $g $sx $by $hw (GTr $lang "ItemName" "Base.Bag_Schoolbag") $used 30 $wt 15 $prev $t
    $geo = ShapeGeo "1x2 4x5 1x2 / 3x2" $cell
    $ax = $sx + [math]::Floor(($hw - $geo.w) / 2); $ay = $by + 36 + 12
    SchoolBagV2 $g $ax $ay $cell
    foreach ($e in $extra) { PartTile $g $ax $ay $geo $e.idx $e.col $e.row $e.w $e.h $e.cat $e.icon }
    $script:C = 64
    return @{ geo = $geo; x = $ax; y = $ay }
}

# --- modules ----------------------------------------------------------------------------
function ModulesScene($off, $mouse, $hot) {
    $sh = 1110
    $bmp, $g = Backdrop 1280 $sh
    $wx = 30; $wy = 24; $ww = 780; $wh = $sh - 48
    Win $g $wx $wy $ww $wh (Tr $lang "IGUI_Knox_Settings")
    $pages = @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_game"),
               (Tr $lang "IGUI_Knox_Page_order"), (Tr $lang "IGUI_Knox_Page_controls"))
    $y = Tabs $g $wx ($wy + 44) $ww $pages 0
    $mx = $wx + 2 * $P; $mw = $ww - 4 * $P
    $y += 22
    Txt $g (Up (Tr $lang "IGUI_Knox_Modules_Title")) "head" 19 $K.accent $mx $y
    $y += 36
    $rows = @{}
    foreach ($grp in @(@("game", @("inventory", "hotbar", "devices", "stove", "fluids", "tooltips", "menus", "dashboard")), @("out", @("menu", "newgame")))) {
        Txt $g (Up (Tr $lang ("IGUI_Knox_Modules_Group_" + $grp[0]))) "body" 18 $K.dim $mx $y
        $y += 28
        foreach ($name in $grp[1]) {
            Fill $g $K.line $mx ($y - 6) $mw 1
            $rows[$name] = @($mx, $y)
            if ($hot -eq $name) { Fill $g $K.header ($mx - 6) ($y - 4) ($mw + 12) 40 }
            $on = -not ($off -contains $name)
            $y2 = SwitchRow $g $mx $y $on (Tr $lang ("IGUI_Knox_Module_" + $name)) (Tr $lang ("IGUI_Knox_Module_" + $name + "_Info")) $mw $true
            if (-not $on) { $pend = Tr $lang "IGUI_Knox_Modules_Pending"; TxtMid $g $pend "body" 19 $K.accent ($mx + $mw - (TextW $g $pend "body" 19)) $y 32 }
            $y = $y2 + 8
        }
        $y += 8
    }
    foreach ($line in (WrapCaps $g (Tr $lang "IGUI_Knox_Modules_NoteGame") "body" 18 $mw)) { Txt $g $line "body" 18 $K.dim $mx $y; $y += 24 }
    $tx = $wx + $ww + 40; $tw = 1280 - $tx - 30
    $ty = CapsBlock $g "EVERY PART OF KNOX IS A MODULE OF ITS OWN." $tx 120 $tw 24 $null 36
    $ty = CapsBlock $g "SWITCH ONE OFF - THE GAME'S OWN WINDOW COMES BACK, OR ANOTHER MOD'S." $tx ($ty + 18) $tw 24 $K.accent 36
    CapsBlock $g "KNOX SETTINGS, THE MODULES PAGE. IN THE MAIN MENU - THE KNOX INVENTORY PLATE AT THE TOP." $tx ($ty + 18) $tw 24 $null 36 | Out-Null
    if ($mouse) { Cursor $g $mouse[0] $mouse[1] 40 }
    $g.Dispose()
    return @($bmp, $rows)
}
function GifModules() {
    BeginGif
    $cap = "Ten modules - each one on or off"
    $s0, $rows = ModulesScene @() $null $null
    Add $s0 $cap 14; $s0.Dispose()
    $sw = { param($n) @(($rows[$n][0] + 14), ($rows[$n][1] + 12)) }
    $plan = @(
        @{ to = "inventory"; off = @("inventory") },
        @{ to = "dashboard"; off = @("inventory", "dashboard") },
        @{ to = "menu"; off = @("inventory", "dashboard", "menu") },
        @{ to = "inventory"; off = @("dashboard", "menu") },
        @{ to = "dashboard"; off = @("menu") },
        @{ to = "menu"; off = @() }
    )
    $at = @(1000, 600); $off = @()
    foreach ($st in $plan) {
        $dst = & $sw $st.to
        for ($i = 1; $i -le 7; $i++) {
            $t = Ease ($i / 7)
            $s, $null = ModulesScene $off @((Lerp $at[0] $dst[0] $t), (Lerp $at[1] $dst[1] $t)) $null
            Add $s $cap; $s.Dispose()
        }
        $off = $st.off; $at = $dst
        $s, $null = ModulesScene $off $dst $st.to
        Add $s $cap 14; $s.Dispose()
    }
    EndGif "modules"
}

# --- rigs ----------------------------------------------------------------------------------
$RIG_W = 990; $RIG_H = 680
# the floor around: @{key = @(col, row, w, h, cat, icon)}
function FloorThings() {
    [ordered]@{
        ammo = @(0, 0, 1, 1, "wpn", "ammobox9"); fanny = @(2, 0, 1, 2, "clo", "fannypack"); jacket = @(4, 0, 2, 2, "clo", "jacket")
        bat = @(7, 0, 1, 4, "wpn", "bat"); apple = @(0, 2, 1, 1, "food", "apple"); book = @(1, 3, 1, 2, "info", "book")
        rag = @(3, 3, 1, 2, "misc", "rag"); tp = @(5, 4, 1, 1, "misc", "toiletpaper")
    }
}
function FloorColumn($g, $x, $y, $w, $h, $gone, $ghost) {
    Column $g $x $y $w $h (Tr $lang "IGUI_Knox_Tab_Surroundings")
    $cell = 48; $script:C = $cell
    Row $g ($x + $P) ($y + 64) ($w - 2 * $P) (GTr $lang "IG_UI" "IGUI_ContainerTitle_floor") "c_floor" ("" + (8 - @($gone).Count)) "full" $true
    $fy = $y + 64 + 64 + 12
    Strip $g ($x + $P) $fy ($w - 2 * $P) (Up (GTr $lang "IG_UI" "IGUI_ContainerTitle_floor")) "8x6"
    $gx = $x + $P + [math]::Floor(($w - 2 * $P - 8 * $cell) / 2); $gy = $fy + 36 + 8
    Grid $g $gx $gy 8 6
    $things = FloorThings
    foreach ($k2 in $things.Keys) {
        if ($gone -contains $k2) { continue }
        $t = $things[$k2]
        Tile $g $gx $gy $t[0] $t[1] $t[2] $t[3] $t[4] $t[5] $(if ($ghost -eq $k2) { "ghost" } else { "" })
    }
    $script:C = 64
    return @($gx, $gy)
}
function RigScene($o) {
    $bmp, $g = Backdrop $RIG_W $RIG_H
    $inv = InvColumn $g 30 20 470 640 $o.fold $o.extra $o.used $o.wt $o.prev $o.t
    $fl = FloorColumn $g 520 20 440 640 $o.gone $o.ghost
    if ($o.drop) { $d = $o.drop; $xy = CellXY $inv.geo $inv.x $inv.y $d[0] $d[1] $d[2]; DropOn $g $xy[0] $xy[1] $d[3] $d[4] 48 $true }
    if ($o.held) { $hd = $o.held; HeldTile $g $hd[0] $hd[1] $hd[2] $hd[3] $hd[4] $hd[5] 48 }
    if ($o.mouse) { Cursor $g $o.mouse[0] $o.mouse[1] 34 }
    $g.Dispose()
    return @($bmp, $inv, $fl)
}
function GifRigs() {
    BeginGif
    $base = @{ fold = 0; extra = @(); used = 16; wt = 3.4; gone = @(); ghost = $null }
    $c1 = "Rigs: every bag has compartments of its own shape"
    $s, $inv, $fl = RigScene $base
    Add $s $c1 18; $s.Dispose()
    $things = FloorThings
    # a thing and a bag go in: from the floor to their cell, the cubes catch up
    $moves = @(
        @{ key = "ammo"; idx = 3; col = 0; row = 1; cap = "A thing goes in whole, where it fits"; used = 17; wt = 3.9 },
        @{ key = "jacket"; idx = 1; col = 2; row = 3; cap = "Cubes in the header: how full the bag is, cells and weight"; used = 21; wt = 5.1 },
        @{ key = "fanny"; idx = 1; col = 3; row = 0; cap = "A bag goes into a bag"; used = 23; wt = 5.3 }
    )
    $st = $base.Clone()
    foreach ($m in $moves) {
        $t0 = $things[$m.key]
        $from = @(($fl[0] + $t0[0] * 48 + 6), ($fl[1] + $t0[1] * 48 + 6))
        $to = CellXY $inv.geo $inv.x $inv.y $m.idx $m.col $m.row
        for ($i = 0; $i -le 14; $i++) {
            $t = Ease ($i / 14)
            $o = $st.Clone(); $o.ghost = $m.key
            $o.held = @((Lerp $from[0] $to[0] $t), (Lerp $from[1] $to[1] $t), $t0[2], $t0[3], $t0[4], $t0[5])
            if ($t -gt 0.75) { $o.drop = @($m.idx, $m.col, $m.row, $t0[2], $t0[3]) }
            $s, $null, $null = RigScene $o
            Add $s $m.cap; $s.Dispose()
        }
        $st.gone = @($st.gone) + $m.key
        $st.extra = @($st.extra) + @{ idx = $m.idx; col = $m.col; row = $m.row; w = $t0[2]; h = $t0[3]; cat = $t0[4]; icon = $t0[5] }
        $was = @($st.used, $st.wt)
        $st.used = $m.used; $st.wt = $m.wt
        # the cubes come up over a fifth of a second (KnoxInventoryPanel shownLit)
        for ($i = 1; $i -le 3; $i++) {
            $o = $st.Clone(); $o.prev = $was; $o.t = $i / 3
            $s, $null, $null = RigScene $o
            Add $s $m.cap; $s.Dispose()
        }
        $s, $null, $null = RigScene $st
        Add $s $m.cap 18; $s.Dispose()
    }
    # the pockets fold and unfold
    $c4 = "Sections fold - the grid slides under its header"
    foreach ($dir in 1, 0) {
        for ($i = 1; $i -le 5; $i++) {
            $o = $st.Clone(); $f = Ease ($i / 5); $o.fold = $(if ($dir) { $f } else { 1 - $f })
            $o.mouse = @(470, 96)
            $s, $null, $null = RigScene $o
            Add $s $c4; $s.Dispose()
        }
        $o = $st.Clone(); $o.fold = $dir; $o.mouse = @(470, 96)
        $s, $null, $null = RigScene $o
        Add $s $c4 12; $s.Dispose()
    }
    EndGif "rigs"
}

# --- search and sort ---------------------------------------------------------------------
$LOOT = @(
    # cat, icon, w, h, scattered col/row, sorted col/row
    @("tool", "saucepan", 1, 2, 5, 2, 0, 0), @("tool", "knife", 1, 2, 1, 1, 1, 0), @("tool", "battery", 1, 1, 0, 4, 2, 0),
    @("mat", "tape", 1, 1, 3, 0, 3, 0), @("mat", "glue", 1, 1, 7, 4, 4, 0), @("food", "beans", 1, 1, 4, 1, 5, 0), @("food", "bread", 1, 1, 6, 0, 6, 0)
)
function SearchScene($found, $sortT, $mouse, $keys) {
    $bmp, $g = Backdrop $RIG_W $RIG_H
    $x = 30; $y = 20; $w = 440
    Column $g $x $y $w 640 (Tr $lang "IGUI_Knox_Tab_Surroundings")
    $cell = 48; $script:C = $cell
    $n = $LOOT.Count
    $kind = $(if ($found -ge $n) { "full" } elseif ($found -gt 0) { "part" } else { "none" })
    $cup = GTr $lang "IG_UI" "IGUI_ContainerTitle_counter"
    Row $g ($x + $P) ($y + 64) ($w - 2 * $P) $cup "c_counter" "$found" $kind $true
    Row $g ($x + $P) ($y + 64 + 72) ($w - 2 * $P) (GTr $lang "IG_UI" "IGUI_ContainerTitle_fridge") "c_fridge" "3" "full"
    Row $g ($x + $P) ($y + 64 + 144) ($w - 2 * $P) (GTr $lang "IG_UI" "IGUI_ContainerTitle_floor") "c_floor" "0" "zero"
    $sy = $y + 64 + 216 + 12
    $info = $(if ($found -lt $n) { ((Tr $lang "IGUI_Knox_Searching") -replace "%1", "$found") -replace "%2", "$n" } else { "8x5" })
    Strip $g ($x + $P) $sy ($w - 2 * $P) (Up $cup) $info $(if ($found -lt $n) { $K.accent } else { $null })
    $gx = $x + $P + [math]::Floor(($w - 2 * $P - 8 * $cell) / 2); $gy = $sy + 36 + 8
    Grid $g $gx $gy 8 5
    for ($i = 0; $i -lt [math]::Min($found, $n); $i++) {
        $t = $LOOT[$i]; $e = Ease $sortT
        $tx = $gx + (Lerp $t[4] $t[6] $e) * $cell; $ty = $gy + (Lerp $t[5] $t[7] $e) * $cell
        Tile $g $tx $ty 0 0 $t[2] $t[3] $t[0] $t[1] $(if ($i -eq $found - 1 -and $found -lt $n) { "hit" } else { "" })
    }
    # the inventory beside it, as it is
    InvColumn $g 490 20 470 640 0 @() 16 3.4 | Out-Null
    if ($keys) { KeyPlate $g ($mouse[0] + 30) ($mouse[1] - 40) "CTRL+S" $true | Out-Null }
    if ($mouse) { Cursor $g $mouse[0] $mouse[1] 34 }
    $script:C = 64
    $g.Dispose()
    return $bmp
}
function GifSearch() {
    BeginGif
    $c1 = "Search: things turn up one by one, each with its sound"
    $s = SearchScene 0 0 $null $false; Add $s $c1 8; $s.Dispose()
    for ($f = 1; $f -le $LOOT.Count; $f++) { $s = SearchScene $f 0 $null $false; Add $s $c1 5; $s.Dispose() }
    $c2 = "Found loot lies scattered, as it was left"
    $s = SearchScene $LOOT.Count 0 @(300, 480) $false; Add $s $c2 16; $s.Dispose()
    $c3 = "Ctrl+S sorts the grid under the mouse"
    $s = SearchScene $LOOT.Count 0 @(300, 480) $true; Add $s $c3 6; $s.Dispose()
    for ($i = 1; $i -le 9; $i++) { $s = SearchScene $LOOT.Count ($i / 9) @(300, 480) $true; Add $s $c3; $s.Dispose() }
    $s = SearchScene $LOOT.Count 1 @(300, 480) $false; Add $s $c3 20; $s.Dispose()
    EndGif "search"
}

# --- the item menu ---------------------------------------------------------------------------
$s18 = $L18[$lang]
$cm = "ContextMenu"
function BreadMenuRows($hover, $lit) {
    @(
        @{k = "head"; cat = "food"; icon = "bread"; name = $s18.bread; sub = $s18.foodSub},
        @{k = "opt"; icon = "inspect"; name = (Tr $lang "IGUI_Knox_Inspect"); hover = ($hover -eq 1)},
        @{k = "opt"; icon = "eat"; name = (GTr $lang $cm "ContextMenu_Eat"); hover = ($hover -eq 2); chips = @(0.25, 0.5, 1); lit = $lit},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuMove")},
        @{k = "opt"; icon = "unpack"; name = (GTr $lang $cm "ContextMenu_Unpack"); hover = ($hover -eq 3)},
        @{k = "opt"; icon = "place"; name = (GTr $lang $cm "ContextMenu_PlaceItemOnGround")},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuCraft")},
        @{k = "opt"; icon = "recipes"; name = (GTr $lang $cm "ContextMenu_ShowCraftRecipesUsed")},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuOther"); fold = "d"},
        @{k = "sep"},
        @{k = "opt"; icon = "drop"; name = (GTr $lang $cm "ContextMenu_Drop"); danger = $true}
    )
}
$MX = 400; $MY = 70; $MW = 470
function BagGrid($g) {
    $script:C = 64
    Strip $g 40 $MY (4 * 64 + 1) (Up (GTr $lang "ItemName" "Base.Bag_Schoolbag"))
    Grid $g 40 ($MY + 36) 4 4
    Tile $g 40 ($MY + 36) 0 0 1 2 "food" "bottle"; Tile $g 40 ($MY + 36) 2 0 1 1 "food" "beans"
    Tile $g 40 ($MY + 36) 3 0 1 2 "tool" "knife"; Tile $g 40 ($MY + 36) 2 2 1 1 "food" "apple"
    Tile $g 40 ($MY + 36) 0 2 1 2 "clo" "tshirt"
}
# the bread's tooltip or menu (morph 0..1: the tooltip opening into the menu, as
# KnoxTooltip.startFold - the plate grows from the tooltip's height, the menu comes over it)
function MenuScene($morph, $hover, $lit, $mouse, $tip = $true) {
    $bmp, $g = Backdrop 1100 720
    BagGrid $g
    Tile $g 40 ($MY + 36) 1 1 1 1 "food" "bread" "hit"
    if ($tip) {
        $tb, $tg = Canvas 600 720 $K.screen; $tg.Clear([System.Drawing.Color]::Transparent)
        $th = Tooltip $tg 0 0 $MW "food" "bread" $s18.bread $s18.foodSub $s18.tipRows
        $tg.Dispose()
        $mb, $mg = Canvas 600 720 $K.screen; $mg.Clear([System.Drawing.Color]::Transparent)
        $mh = MenuPlate $mg 0 0 $MW (BreadMenuRows $hover $lit)
        $mg.Dispose()
        $hh = [int](Lerp $th $mh $morph)
        $ia = New-Object System.Drawing.Imaging.ImageAttributes
        if ($morph -lt 1) {
            $cmx = New-Object System.Drawing.Imaging.ColorMatrix; $cmx.Matrix33 = [float](1 - $morph); $ia.SetColorMatrix($cmx)
            $g.DrawImage($tb, (New-Object System.Drawing.Rectangle $MX, $MY, 600, $th), 0, 0, 600, $th, [System.Drawing.GraphicsUnit]::Pixel, $ia)
        }
        if ($morph -gt 0) {
            $ib = New-Object System.Drawing.Imaging.ImageAttributes
            $cmx = New-Object System.Drawing.Imaging.ColorMatrix; $cmx.Matrix33 = [float]$morph; $ib.SetColorMatrix($cmx)
            $g.DrawImage($mb, (New-Object System.Drawing.Rectangle $MX, $MY, 600, $hh), 0, 0, 600, $hh, [System.Drawing.GraphicsUnit]::Pixel, $ib)
        }
        $tb.Dispose(); $mb.Dispose()
    }
    if ($mouse) { Cursor $g $mouse[0] $mouse[1] 40 }
    $g.Dispose()
    return $bmp
}
# the axe's menu (what a recipe still needs) and the sheet's Interact, as the news drew them
function RecipeScene($step, $mouse) {
    $bmp, $g = Backdrop 1100 720
    # (the menus in the middle of the picture: all of it, the cursor too, 120 px down)
    $g.TranslateTransform(0, 120)
    $axe = GTr $lang "ItemName" "Base.Axe"; $hammer = GTr $lang "ItemName" "Base.Hammer"
    MenuPlate $g 30 70 360 @(
        @{k = "head"; cat = "tool"; icon = "axe"; name = $axe; sub = $s18.axeSub},
        @{k = "opt"; icon = "inspect"; name = (Tr $lang "IGUI_Knox_Inspect")},
        @{k = "opt"; icon = "attach"; name = (GTr $lang $cm "ContextMenu_Attach"); sub = $true},
        @{k = "opt"; icon = "dismantle"; name = (GTr $lang "Recipes" "DismantleLongImplement"); needs = $hammer; hover = ($step -eq 0)},
        @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuEquip")},
        @{k = "opt"; icon = "hands"; name = (GTr $lang $cm "ContextMenu_Equip_Two_Hands")}
    ) | Out-Null
    if ($step -ge 1) {
        $sheet = GTr $lang "ItemName" "Base.Sheet"
        MenuPlate $g 400 70 330 @(
            @{k = "head"; cat = "mat"; icon = "sheet"; name = $sheet; sub = $s18.sheetSub},
            @{k = "opt"; icon = "inspect"; name = (Tr $lang "IGUI_Knox_Inspect")},
            @{k = "opt"; icon = "hand_main"; name = (GTr $lang $cm "ContextMenu_Equip_Primary")},
            @{k = "opt"; icon = "craft"; name = (Tr $lang "IGUI_Knox_MenuInteract"); sub = $true; hover = $true},
            @{k = "label"; text = (Tr $lang "IGUI_Knox_MenuEquip")},
            @{k = "opt"; icon = "hand_off"; name = (GTr $lang $cm "ContextMenu_Equip_Secondary")}
        ) | Out-Null
        if ($step -ge 2) {
            MenuPlate $g 732 (70 + 8 + 92 + 2 * $RowH - 8) 340 @(
                @{k = "opt"; icon = "rope"; name = (GTr $lang "Recipes" "CraftSheetRope"); hover = ($step -eq 2)},
                @{k = "opt"; icon = "rip"; name = (GTr $lang "Recipes" "RipSheets"); hover = ($step -eq 3)},
                @{k = "opt"; icon = "bag"; name = (GTr $lang "Recipes" "MakeSheetSlingBag")}
            ) | Out-Null
        }
    }
    if ($mouse) { Cursor $g $mouse[0] $mouse[1] 40 }
    $g.Dispose()
    return $bmp
}
function GifMenu() {
    BeginGif
    $bread = @((40 + 64 + 36), ($MY + 36 + 64 + 30))
    $c1 = "Point at a thing - its tooltip"
    $s = MenuScene 0 0 -1 @(300, 420) $false; Add $s $c1 4; $s.Dispose()
    for ($i = 1; $i -le 5; $i++) { $t = Ease ($i / 5); $s = MenuScene 0 0 -1 @((Lerp 300 $bread[0] $t), (Lerp 420 $bread[1] $t)) $false; Add $s $c1; $s.Dispose() }
    $s = MenuScene 0 0 -1 $bread; Add $s $c1 14; $s.Dispose()
    $c2 = "Right click - the menu opens out of the tooltip"
    for ($i = 1; $i -le 3; $i++) { $s = MenuScene (Ease ($i / 3)) 0 -1 $bread; Add $s $c2; $s.Dispose() }
    $s = MenuScene 1 0 -1 $bread; Add $s $c2 14; $s.Dispose()
    $c3 = "Groups and icons. Eat a quarter, a half or all of it"
    $eatY = $MY + 8 + 92 + 44 + 22
    $s = MenuScene 1 2 -1 @(($MX + 120), $eatY); Add $s $c3 6; $s.Dispose()
    foreach ($l in 0, 1, 2) {
        $cx = $MX + $MW - $PadX - 3 * 28 + $l * 28 + 14
        $s = MenuScene 1 2 $l @($cx, $eatY); Add $s $c3 7; $s.Dispose()
    }
    $c4 = "Recipes: what else one takes is written under it"
    $s = RecipeScene 0 @(230, (70 + 8 + 92 + 2 * 44 + 30)); Add $s $c4 22; $s.Dispose()
    $c5 = "An item's recipes are in Interact, each with its icon"
    $iy = 70 + 8 + 92 + 2 * 44 + 22
    $s = RecipeScene 1 @(560, $iy); Add $s $c5 6; $s.Dispose()
    $s = RecipeScene 2 @(840, ($iy + 2)); Add $s $c5 10; $s.Dispose()
    $s = RecipeScene 3 @(860, ($iy + 46)); Add $s $c5 14; $s.Dispose()
    EndGif "menu"
}

# --- the device windows: each the news picture's own window ---------------------------------
$DEVICES = @(
    @("u070_tv", 24, 76, 684, 548, "TV - subtitles on its screen, a video deck"),
    @("u070_radio", 24, 76, 710, 538, "Radio - the dial and a tape of the broadcast"),
    @("r10_walkie", 40, 84, 700, 534, "A walkie-talkie in hand - a set of its own"),
    @("u090_cook", 640, 80, 600, 290, "Stove, oven and microwave - temperature and timer"),
    @("u060_fluid", 24, 80, 818, 560, "Pouring - how much leaves and how much comes"),
    @("r10_fluid", 40, 90, 520, 340, "Fluid container info"),
    @("r10_alarm", 40, 84, 864, 392, "The alarm - like the clock itself")
)
function DeviceScene($d, $a = 1, $prev = $null, $pa = 0) {
    $bmp, $g = Backdrop 1280 720
    foreach ($e in @(@($prev, $pa), @($d, $a))) {
        if (-not $e[0] -or $e[1] -le 0) { continue }
        $x = $e[0]
        $k2 = [math]::Min(1.25, [math]::Min([double](1200 / $x[3]), [double](660 / $x[4])))
        $w = $x[3] * $k2; $h = $x[4] * $k2
        Crop $g (Join-Path $news ($x[0] + "_en.png")) $x[1] $x[2] $x[3] $x[4] ((1280 - $w) / 2) ((720 - $h) / 2) $w $h $e[1]
    }
    $g.Dispose()
    return $bmp
}
function GifDevices() {
    BeginGif
    $prev = $null
    foreach ($d in $DEVICES) {
        if ($prev) { foreach ($t in 0.33, 0.66) { $s = DeviceScene $d $t $prev (1 - $t); Add $s $d[5]; $s.Dispose() } }
        $s = DeviceScene $d; Add $s $d[5] 20; $s.Dispose()
        $prev = $d
    }
    EndGif "devices"
}

# --- the dashboard: KnoxDashboard's own drawing, frame by frame -------------------------------
$dashFrames = Join-Path $work "dash"
function DashCaption($n) {
    if ($n -le 8) { "The sedan's dashboard at night" }
    elseif ($n -le 30) { "The key goes in: the lamp check, the needles sweep" }
    elseif ($n -le 41) { "Start - the key turns, the engine cranks" }
    elseif ($n -le 59) { "Headlights on - the dials light up" }
    elseif ($n -le 98) { "Speedometer with the gear, tachometer, fuel" }
    elseif ($n -le 120) { "The radio: your own music is a tape" }
    elseif ($n -le 131) { "The lock switch by the door" }
    else { "The pickup: no key - the wires spark" }
}
function DashScene($file) {
    $img = [System.Drawing.Image]::FromFile($file)
    # (snap.ps1 leaves 24 px round the panel and 190 above it for the tips)
    $pw = $img.Width - 48; $ph = $img.Height - 214
    $bmp, $g = Backdrop 1200 300
    $k2 = 1160 / 1117
    $w = $pw * $k2; $h = $ph * $k2
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, (New-Object System.Drawing.RectangleF ([float]((1200 - $w) / 2)), ([float]((300 - $h) / 2)), ([float]$w), ([float]$h)), (New-Object System.Drawing.RectangleF 24, 190, $pw, $ph), [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose(); $g.Dispose()
    return $bmp
}
function GifDash() {
    Write-Host "  (the dashboard's frames: tools\page\dash_frames.ps1)"
    & (Join-Path $PSScriptRoot "page\dash_frames.ps1") $dashFrames 6>$null | Out-Null
    BeginGif
    $files = Get-ChildItem $dashFrames -Filter "f*.png" | Sort-Object Name
    $n = 0
    foreach ($f in $files) {
        $n++
        $s = DashScene $f.FullName
        $times = $(if ($n -eq 131 -or $n -eq $files.Count) { 16 } else { 1 })
        Add $s (DashCaption $n) $times; $s.Dispose()
    }
    EndGif "dash" 12 192 "bayer"
}

# --- music (a still): the radio by the fire and the car's radio with the tape -----------------
function MusicScene() {
    $bmp, $g = Backdrop 1280 720
    Crop $g (Join-Path $news "u0985_radio_en.png") 40 84 528 604 30 40 (528 * 1.06) (604 * 1.06)
    $tape = Join-Path $dashFrames "f0110.png"
    if (-not (Test-Path $tape)) { & (Join-Path $PSScriptRoot "page\dash_frames.ps1") $dashFrames 6>$null | Out-Null }
    $img = [System.Drawing.Image]::FromFile($tape); $pw = $img.Width - 48; $ph = $img.Height - 214; $img.Dispose()
    # the radio and heater stack: the right part of the sedan's panel
    $rx = [int]($pw * 0.635)
    $rw = $pw - $rx
    $k2 = 640 / $rw
    Crop $g $tape (24 + $rx) 190 $rw $ph 610 40 640 ($ph * $k2)
    $ty = 40 + $ph * $k2 + 34
    $ty = CapsBlock $g "BY THE FIRE: THE RADIO WITH THE GAME'S MUSIC OR YOUR OWN." 610 $ty 640 22 $null 32
    $ty = CapsBlock $g "IN THE CAR YOUR MUSIC IS A TAPE. GET OUT - IT PLAYS ON IN THE CAR, QUIETER WITH THE DISTANCE. TWO CARS CAN PLAY AT ONCE." 610 ($ty + 14) 640 22 $K.accent 32
    CapsBlock $g "MULTIPLAYER (TEST): PLAYERS NEAR THE CAR HEAR IT." 610 ($ty + 14) 640 22 $null 32 | Out-Null
    $g.Dispose()
    return $bmp
}

# --- tooltips and sounds (a still) ------------------------------------------------------------
function ExtrasScene() {
    $bmp, $g = Backdrop 1280 500
    $script:C = 64
    Grid $g 40 60 2 2
    Tile $g 40 60 0 0 1 2 "food" "bottle"; Tile $g 40 60 1 0 1 1 "food" "bread" "hit"
    Tile $g 40 60 1 1 1 1 "food" "beans"
    Cursor $g (40 + 64 + 34) (60 + 30) 40
    $th = Tooltip $g 190 60 470 "food" "bread" $s18.bread $s18.foodSub $s18.tipRows
    $wx = 700; $wy = 60; $ww = 540; $wh = 330
    Win $g $wx $wy $ww $wh (Tr $lang "IGUI_Knox_Settings")
    $pages = @((Tr $lang "IGUI_Knox_Page_modules"), (Tr $lang "IGUI_Knox_Page_look"), (Tr $lang "IGUI_Knox_Page_game"),
               (Tr $lang "IGUI_Knox_Page_order"), (Tr $lang "IGUI_Knox_Page_controls"))
    $y = Tabs $g $wx ($wy + 44) $ww $pages 2
    $sx = $wx + 2 * $P; $sw = $ww - 4 * $P
    Slider $g $sx ($y + 34) $sw (Tr $lang "IGUI_Knox_search_time") 0.2 "100%" 200
    Slider $g $sx ($y + 104) $sw (Tr $lang "IGUI_Knox_search_sound") 0.5 "100%" 200
    Slider $g $sx ($y + 174) $sw (Tr $lang "IGUI_Knox_ui_sound") 0.5 "100%" 200
    $ty = CapsBlock $g "TOOLTIPS: THE ITEM'S HEADER, ITS CATEGORY, SIZE AND WEIGHT, THEN WHAT MATTERS FOR IT." 40 (60 + $th + 30) 620 20 $null 30
    CapsBlock $g "SOUNDS: HANDS RUMMAGE THROUGH A BOX, EVERY THING FOUND SOUNDS LIKE WHAT IT IS MADE OF; A BAG OPENS WITH ITS ZIP." 700 ($wy + $wh + 30) 540 20 $K.accent 30 | Out-Null
    $g.Dispose()
    return $bmp
}

# --- the opening GIF: one interface, a part after another -----------------------------------
function GifHero() {
    BeginGif
    $parts = @(
        @("One interface for the whole game: the inventory", { $s, $null, $null = RigScene @{ fold = 0; extra = @(); used = 16; wt = 3.4; gone = @(); ghost = $null }; $s }),
        @("One interface: the right-click menu", { MenuScene 1 2 2 $null }),
        @("One interface: TV, radio, stove and other windows", { DeviceScene $DEVICES[0] }),
        @("One interface: the car's dashboard", { DashScene (Join-Path $dashFrames "f0095.png") }),
        @("One interface: the radio by the fire and your music", { MusicScene }),
        @("One style, ten modules - each one on or off", { $s, $null = ModulesScene @() $null $null; $s })
    )
    if (-not (Test-Path (Join-Path $dashFrames "f0095.png"))) { & (Join-Path $PSScriptRoot "page\dash_frames.ps1") $dashFrames 6>$null | Out-Null }
    # every part fills the same 16:9 frame, centred on the screen colour
    foreach ($pt in $parts) {
        $sc = & $pt[1]
        $bmp, $g = Backdrop 1280 720
        $k2 = [math]::Min([double](1280 / $sc.Width), [double](720 / $sc.Height))
        $w = $sc.Width * $k2; $h = $sc.Height * $k2
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($sc, (New-Object System.Drawing.RectangleF ([float]((1280 - $w) / 2)), ([float]((720 - $h) / 2)), ([float]$w), ([float]$h)))
        $g.Dispose(); $sc.Dispose()
        Add $bmp $pt[0] 20; $bmp.Dispose()
    }
    EndGif "hero" 12 128
}

Write-Host "Workshop page pictures (v2):"
if (Want "dash") { GifDash }
if (Want "hero") { GifHero }
if (Want "modules") { GifModules }
if (Want "rigs") { GifRigs }
if (Want "search") { GifSearch }
if (Want "menu") { GifMenu }
if (Want "devices") { GifDevices }
if (Want "music") { $s = MusicScene; SavePng $s "Music: by the fire and in the car" "music"; $s.Dispose() }
if (Want "extras") { $s = ExtrasScene; SavePng $s "Tooltips and sounds in Knox's style" "extras"; $s.Dispose() }
if (Want "space") {
    Copy-Item (Join-Path $PSScriptRoot "art\page\space_weight_en.gif") (Join-Path $out "inv_space.gif") -Force
    Write-Host ("  inv_space.gif  {0:N0} bytes (make_page_gifs.ps1)" -f (Get-Item (Join-Path $out "inv_space.gif")).Length)
}
