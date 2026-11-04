# The broken thing's red cross (42\media\ui\knox_cross_<k>.png, condition_v3, the
# author, 2026-10-31): white on transparent, 2 px lines with square ends, anti-aliased;
# drawn 1:1 in red (T.brokenMark) - one picture per size, a scaled one goes soft.
# k = half the cross's side, as round(min(w, h) * 0.22) of the tile, even.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\make_cross.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "42\media\ui"
# (counted, not drawn with a pen: GDI+ left the two lines unlike by up to 24 of 255 -
# QA, 2026-10-31; so the same for both by the mirror)
$S = 5
$root2 = [math]::Sqrt(2)
for ($k = 8; $k -le 44; $k += 2) {
    $n = $k * 2 + 4
    $c = $n / 2
    $bmp = New-Object System.Drawing.Bitmap $n, $n
    $reach = $k * $root2 + 1
    for ($py = 0; $py -lt $n; $py++) {
        for ($px = 0; $px -lt $n; $px++) {
            $u0 = $px + 0.5 - $c
            $v0 = $py + 0.5 - $c
            # (far from both lines: nothing)
            if ([math]::Abs([math]::Abs($u0) - [math]::Abs($v0)) -gt 3) { continue }
            $hit = 0
            for ($i = 0; $i -lt $S; $i++) {
                for ($j = 0; $j -lt $S; $j++) {
                    $u = $u0 - 0.5 + ($i + 0.5) / $S
                    $v = $v0 - 0.5 + ($j + 0.5) / $S
                    $along = ($u + $v) / $root2
                    $across = ($u - $v) / $root2
                    if (([math]::Abs($across) -le 1 -and [math]::Abs($along) -le $reach) -or
                        ([math]::Abs($along) -le 1 -and [math]::Abs($across) -le $reach)) { $hit++ }
                }
            }
            if ($hit -gt 0) {
                $al = [int][math]::Round(255 * $hit / ($S * $S))
                $bmp.SetPixel($px, $py, [System.Drawing.Color]::FromArgb($al, 255, 255, 255))
            }
        }
    }
    $bmp.Save((Join-Path $dir "knox_cross_$k.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}
Write-Host "saved crosses"