# The mouse cursor in each skin's main colour (KnoxTheme.SKINS, beta): from
# 42\media\ui\knox_cursor.png and knox_cursor_down.png (the sand arrow) to
# knox_cursor_<skin>.png and knox_cursor_down_<skin>.png. Every pixel becomes the
# skin's colour at its brightness against the sand (the fill the colour, the
# outline a dark shade of it, the shadow black) - as KnoxCursor.java repaints the
# system cursor; these are the drawn cursor the game uses while that one is hidden.
# The custom skin has no file: the drawn cursor stays sand there.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_cursors.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$ui = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui"
# (the skins' main colours, as in KnoxTheme.lua)
$skins = [ordered]@{ blood = "#d8705f"; pine = "#b5c278"; ice = "#8ec5e0"; night = "#86f07e"; coal = "#cfcfcf"; mansion = "#d0a24c" }
foreach ($file in "knox_cursor", "knox_cursor_down") {
    foreach ($id in $skins.Keys) {
        $hexC = $skins[$id]
        $cr = [Convert]::ToInt32($hexC.Substring(1, 2), 16); $cg = [Convert]::ToInt32($hexC.Substring(3, 2), 16); $cb = [Convert]::ToInt32($hexC.Substring(5, 2), 16)
        $src = [System.Drawing.Bitmap]::FromFile((Join-Path $ui "$file.png"))
        $dst = New-Object System.Drawing.Bitmap $src.Width, $src.Height
        for ($y = 0; $y -lt $src.Height; $y++) {
            for ($x = 0; $x -lt $src.Width; $x++) {
                $p = $src.GetPixel($x, $y)
                $kk = ($p.R + $p.G + $p.B) / 545.0
                $dst.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A, [math]::Min(255, [int]($cr * $kk)), [math]::Min(255, [int]($cg * $kk)), [math]::Min(255, [int]($cb * $kk))))
            }
        }
        $src.Dispose()
        $out = Join-Path $ui ($file + "_" + $id + ".png")
        $dst.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $dst.Dispose()
        Write-Host "  $file`_$id.png"
    }
}
