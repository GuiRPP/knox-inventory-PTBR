# The generator window's pictures (42\media\ui\knoxgen\*.png) for KnoxGeneratorWindow.lua,
# cut from the approved mockup itself (tools\gen\generator_v18.html - a copy of
# .claude\mockups\generator_v18.html, approved by the author 2026-10-22): Edge without a
# window opens bake.html (the mockup + gen\bake.js) once per layer and scale and saves
# what it shows, so the body is the mockup's to the pixel. Text and everything that
# moves are left out of the body - the game draws them:
#   under_k<K>       the body without them (700 x 500 units)
#   over_k<K>        what lies over the needles and digits: hubs, glass glints, the
#                    lamps' light, the counter's shade and frames
#   fticks, fticks_red, lticks   the scales' marks, white (tinted: paint or backlight)
#   fneedle, lneedle, knob, knobmark (white), lever (white and greys: the skin's sand),
#   handle, plug, lampdisc (white), icon_fridge / bulb / stove / plug (white)
# K = 80, 100, 133, 160, 200, 250: px per 100 units (as the dashboard's pictures), the game
# takes the nearest not smaller. The pieces' boxes in units are BOX in the Lua too -
# change both together.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_generator.ps1 [-Only under,over] [-Scales 250]
#   -Only: just these layers, -Scales: just these K (a whole bake takes a quarter of an hour)
param([string[]]$Only, [int[]]$Scales)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$gen = Join-Path $PSScriptRoot "gen"
$dir = Join-Path $root "42\media\ui\knoxgen"
New-Item -ItemType Directory -Force $dir | Out-Null
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { throw "Edge not found: $edge" }

# bake.html: the mockup without its web font (no text is drawn), its animation stopped
$html = [IO.File]::ReadAllText((Join-Path $gen "generator_v18.html"), [Text.Encoding]::UTF8)
$html = [Regex]::Replace($html, '<link id="ff"[^>]*>', '<link id="ff">')
$i = $html.IndexOf("<script>")
$html = $html.Substring(0, $i) + "<script>window.requestAnimationFrame=function(){return 0};</script>`n" + $html.Substring($i)
$html = $html.Replace("</body>", "<script src=""bake.js""></script>`n</body>")
$bake = Join-Path $gen "bake.html"
[IO.File]::WriteAllText($bake, $html, (New-Object Text.UTF8Encoding $false))
$url = "file:///" + ($bake -replace "\\", "/")

# name -> box in units (x, y, w, h); a turning piece has its pivot in its middle
# (the handle's pivot: 34, 9 from its top left)
$layers = [ordered]@{
    "under" = @(0, 0, 700, 500); "over" = @(0, 0, 700, 500)
    "fticks" = @(426, 80, 48, 48); "fticks_red" = @(426, 80, 48, 48); "lticks" = @(213, 225, 118, 118)
    "fneedle" = @(445, 81, 10, 46); "lneedle" = @(265, 228, 14, 112)
    "knob" = @(110, 239, 56, 56); "knobmark" = @(110, 239, 56, 56)
    "lever" = @(544, 346, 26, 26); "handle" = @(316, 241, 68, 28); "plug" = @(499, 218, 34, 49)
    "lampdisc" = @(382, 288, 16, 16)
    "icon_fridge" = @(501, 220, 28, 26); "icon_bulb" = @(501, 220, 28, 26)
    "icon_stove" = @(501, 220, 28, 26); "icon_plug" = @(501, 220, 28, 26)
}
$ks = @(80, 100, 133, 160, 200, 250)
if ($Scales) { $ks = $Scales }   # (-Scales 250: just these)
$tmp = Join-Path $env:TEMP "knox_gen_bake"
New-Item -ItemType Directory -Force $tmp | Out-Null
$made = 0
foreach ($k in $ks) {
    foreach ($name in $layers.Keys) {
        if ($Only -and ($Only -notcontains $name)) { continue }
        $b = $layers[$name]
        $w = [int][Math]::Round($b[2] * $k / 100)
        $h = [int][Math]::Round($b[3] * $k / 100)
        $out = Join-Path $tmp "$($name)_k$k.png"
        if (Test-Path $out) { Remove-Item $out }
        $u = "$url#layer=$name&vb=$($b -join ',')&w=$w&h=$h"
        # (only Edge's own process is waited for: -Wait waited for its helpers too,
        # which outlive it, and the script hung)
        # (now and then Edge never writes its picture: tried again, three times)
        for ($try = 0; $try -lt 3 -and -not (Test-Path $out); $try++) {
            $p = Start-Process -FilePath $edge -PassThru -WindowStyle Hidden -ArgumentList @(
                "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
                "--user-data-dir=$tmp\profile", "--default-background-color=00000000",
                "--force-device-scale-factor=1", "--window-size=$w,$h", "--screenshot=$out", "`"$u`"")
            for ($t = 0; $t -lt 200 -and -not (Test-Path $out); $t++) { Start-Sleep -Milliseconds 100 }
            $p.WaitForExit(10000) | Out-Null
            if (-not (Test-Path $out)) {
                Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like "*knox_gen_bake*" } |
                    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            }
        }
        if (-not (Test-Path $out)) { throw "no picture for $name k$k" }
        Start-Sleep -Milliseconds 150   # (the file written whole)
        # (exactly the box's size: a window may come out a pixel bigger)
        $src = [System.Drawing.Image]::FromFile($out)
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), (New-Object System.Drawing.Rectangle 0, 0, $w, $h), [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose(); $src.Dispose()
        $bmp.Save((Join-Path $dir "$($name)_k$k.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $made++
    }
}
Remove-Item $bake
# Edge's helpers of the bake's own profile (the player's Edge is not touched)
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" | Where-Object { $_.CommandLine -like "*knox_gen_bake*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Output "made $made pictures in $dir"
