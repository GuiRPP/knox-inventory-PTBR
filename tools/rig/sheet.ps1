# A sheet of every bag family with compartments (KnoxBagShapes), drawn from the mod's
# own geometry (geometry.lua on the game's Lua) with the parts of the Knox screen
# (news_ui.ps1): to look the shapes over. -> tools\art\rig_sheet_<ru|en>.png
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\rig\sheet.ps1
param([string]$Lang = "ru")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "news_ui.ps1")
$out = Join-Path (Split-Path -Parent $PSScriptRoot) "art"
$mod = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$java = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe'
$run = (Join-Path $PSScriptRoot '..\..\java\tools\luacheck\LuaRun.java')
$shared = Join-Path $mod '42\media\lua\shared\Knox'
$geo = Join-Path $env:TEMP 'knox_rig_geometry.txt'
$CELL = 30
Push-Location $game
try {
    & $java -cp "$game\projectzomboid.jar" $run (Join-Path $PSScriptRoot '..\footprint\stubs.lua') `
        (Join-Path $shared 'KnoxBagShapes.lua') (Join-Path $PSScriptRoot 'geometry.lua') "cell=$CELL" "target=$geo" | Out-Null
} finally { Pop-Location }

$fams = @(); $cur = $null
foreach ($l in [IO.File]::ReadAllLines($geo)) {
    $f = $l -split "`t"
    if ($f[0] -eq "F") { $cur = @{name = $f[1]; type = $f[2]; w = [int]$f[3]; h = [int]$f[4]; cells = $f[5]; size = $f[6]; parts = @()}; $fams += $cur }
    elseif ($f[0] -eq "P") { $cur.parts += , @([int]$f[1], [int]$f[2], [int]$f[3], [int]$f[4]) }
}

$W = 1920; $colW = 300; $pad = 28
$bmp, $g = Canvas $W 3600 $K.screen
Caption $g $(if ($Lang -eq "ru") { "РАЗГРУЗКА: ВСЕ СУМКИ С ОТСЕКАМИ" } else { "RIGS: EVERY BAG WITH COMPARTMENTS" }) 24 26
$x = 24; $y = 84; $rowH = 0
$script:C = $CELL
foreach ($f in $fams) {
    $name = GTr $Lang "ItemName" ("Base." + $f.type)
    # (as wide as its name and size need on the strip)
    $need = (TextW $g (Up $name) "head" 19) + (TextW $g $f.size "body" 20) + 48
    $bw = [math]::Max([math]::Max($f.w, 6 * $CELL), $need)
    $bh = 36 + 10 + $f.h + 34
    if ($x + $bw -gt $W - 24) { $x = 24; $y += $rowH + $pad; $rowH = 0 }
    Strip $g $x $y $bw (Up $name) $f.size
    $gy = $y + 36 + 10
    foreach ($p in $f.parts) {
        $px = $x + [math]::Floor(($bw - $f.w) / 2) + $p[0]; $py = $gy + $p[1]
        Grid $g $px $py $p[2] $p[3]
        Frame $g $K.tileEdge ($px - 1) ($py - 1) ($p[2] * $CELL + 3) ($p[3] * $CELL + 3) 1 0.55
    }
    Txt $g ($f.name + "  " + $f.cells) "body" 15 $K.dim $x ($gy + $f.h + 10)
    $x += $bw + $pad
    $rowH = [math]::Max($rowH, $bh)
}
$script:C = 64
$hTotal = [int][math]::Min(3600, $y + $rowH + 30)
$crop = $bmp.Clone((New-Object System.Drawing.Rectangle 0, 0, $W, $hTotal), $bmp.PixelFormat)
$g.Dispose(); $bmp.Dispose()
$gc = [System.Drawing.Graphics]::FromImage($crop)
Save $crop $gc "rig_sheet_$Lang.png"
