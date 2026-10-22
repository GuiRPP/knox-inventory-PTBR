# Checks a Workshop description before tools\upload_page.ps1 sends it, and draws a
# preview of the page:
#   - its size as upload_page.ps1 counts it (the text after the Title line, the
#     Workshop ID / Mod ID footer added), each [img]{name}[/img] placeholder counted
#     as the longest Steam picture link it will become (113 bytes);
#   - the placeholders left, each with its file in tools\art\page_v2 and the file's size;
#   - every link in it: pictures must answer 200 with an image, pages 200;
#   - the preview picture under Steam's 1 000 000 bytes;
#   - tools\art\page_v2\preview.html: the BBCode as HTML, the pictures of the
#     placeholders put in from their files (data: links), the others from Steam.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\page\check_page.ps1 [-File WORKSHOP_DESCRIPTION_V2.txt] [-NoLinks]

param([string]$File = "WORKSHOP_DESCRIPTION_V2.txt", [switch]$NoLinks)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$art = Join-Path $root "tools\art\page_v2"
$utf8 = New-Object Text.UTF8Encoding $false
# the placeholders' files (make_page_v2.ps1)
$MAP = [ordered]@{
    hero = "hero.gif"; modules = "modules.gif"; rigs = "rigs.gif"; search = "search.gif"; space = "inv_space.gif"
    menu = "menu.gif"; devices = "devices.gif"; dash = "dash.gif"; music = "music.png"; extras = "extras.png"
}
$LINK = 113   # [img]https://images.steamusercontent.com/ugc/<20 digits>/<40 hex>/[/img]

$lines = [IO.File]::ReadAllLines((Join-Path $root $File), $utf8)
if ($lines[0] -notmatch '^Title:\s*(.+)$') { throw "$File`: the first line must be 'Title: ...'" }
$title = $Matches[1].Trim()
$desc = $lines | Select-Object -Skip 2
while ($desc.Count -and $desc[-1].Trim() -eq '') { $desc = $desc[0..($desc.Count - 2)] }
$desc = @($desc | Where-Object { $_ -notmatch '^\s*(Workshop ID|Mod ID):' })
$modId = (Select-String -Path (Join-Path $root "42\mod.info") -Pattern '^id=(.+)$').Matches[0].Groups[1].Value.Trim()
$full = @($desc) + @('', 'Workshop ID: 3816775774', "Mod ID: $modId", "Mod ID: KnoxInventoryBeta")
$text = $full -join "`n"
$holders = [regex]::Matches($text, '\[img\]\{(\w+)\}\[/img\]') | ForEach-Object { $_.Groups[1].Value }
$bytes = $utf8.GetByteCount($text)
$counted = $bytes
foreach ($h in $holders) { $counted += $LINK - $utf8.GetByteCount("[img]{$h}[/img]") }
Write-Host ("Title: {0}" -f $title)
Write-Host ("Bytes: {0} now, {1} with the pictures' links (upload_page.ps1 stops over 7950)" -f $bytes, $counted)
$ok = $counted -le 7950
if (-not $ok) { Write-Host "  OVER THE LIMIT" -ForegroundColor Red }

Write-Host "Placeholders ($($holders.Count)):"
foreach ($h in $holders) {
    $f = $MAP[$h]
    if (-not $f -or -not (Test-Path (Join-Path $art $f))) { Write-Host "  {$h}: NO FILE" -ForegroundColor Red; $ok = $false; continue }
    Write-Host ("  {{{0}}} <- {1}  {2:N0} bytes" -f $h, $f, (Get-Item (Join-Path $art $f)).Length)
}
if ($holders.Count) { Write-Host "  (upload_page.ps1 refuses a description with placeholders left)" }

if (-not $NoLinks) {
    Write-Host "Links:"
    foreach ($u in ([regex]::Matches($text, 'https?://[^\[\]\s"]+') | ForEach-Object { $_.Value } | Select-Object -Unique)) {
        try {
            $r = Invoke-WebRequest $u -UseBasicParsing -Method Get -TimeoutSec 30
            $img = $u -match 'steamusercontent'
            $good = $r.StatusCode -eq 200 -and (-not $img -or $r.Headers["Content-Type"] -like "image/*")
            Write-Host ("  {0} {1} {2}" -f $r.StatusCode, $r.Headers["Content-Type"], $u) -ForegroundColor $(if ($good) { "Gray" } else { "Red" })
            if (-not $good) { $ok = $false }
        } catch { Write-Host "  FAILED $u : $($_.Exception.Message)" -ForegroundColor Red; $ok = $false }
    }
}
$pv = Join-Path $root "tools\art\preview_workshop.gif"
$pvLen = (Get-Item $pv).Length
Write-Host ("Preview: {0:N0} bytes ({1})" -f $pvLen, $(if ($pvLen -lt 1000000) { "under 1 000 000" } else { "TOO BIG" }))
if ($pvLen -ge 1000000) { $ok = $false }

# --- the preview page: Steam's BBCode as HTML, roughly in the Workshop's look --------
function Enc($s) { [Net.WebUtility]::HtmlEncode($s) }
$html = Enc ($desc -join "`n")
$html = [regex]::Replace($html, '\[img\]\{(\w+)\}\[/img\]', {
    param($m)
    $f = Join-Path $art $MAP[$m.Groups[1].Value]
    $mime = $(if ($f -like "*.gif") { "image/gif" } else { "image/png" })
    '<img src="data:' + $mime + ';base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($f)) + '" title="{' + $m.Groups[1].Value + '}">'
})
$html = [regex]::Replace($html, '\[img\](.+?)\[/img\]', '<img src="$1">')
$html = [regex]::Replace($html, '\[url=(.+?)\](.+?)\[/url\]', '<a href="$1">$2</a>')
foreach ($p in @(@('\[h1\]', '<h1>'), @('\[/h1\]\n?', '</h1>'), @('\[h2\]', '<h2>'), @('\[/h2\]\n?', '</h2>'), @('\[b\]', '<b>'), @('\[/b\]', '</b>'),
        @('\[i\]', '<i>'), @('\[/i\]', '</i>'), @('\[list\]\n?', '<ul>'), @('\[/list\]\n?', '</ul>'), @('\[olist\]\n?', '<ol>'), @('\[/olist\]\n?', '</ol>'),
        @('\[\*\]', '<li>'))) { $html = [regex]::Replace($html, $p[0], $p[1]) }
$html = $html.Replace("`n", "<br>`n")
$page = @"
<!doctype html><html><head><meta charset="utf-8"><title>Knox page preview</title>
<style>body{background:#1b2838;color:#acb2b8;font:14px Arial,Helvetica,sans-serif;margin:0}
.col{max-width:636px;margin:24px auto;padding:0 16px}h1{color:#fff;font-size:20px;font-weight:normal;margin:14px 0 4px}
h2{color:#fff;font-size:16px}b{color:#ddd}a{color:#ebebeb}img{max-width:100%;display:block;margin:6px 0}ul,ol{margin:2px 0;padding-left:22px}
li br{display:none}.t{color:#fff;font-size:26px;margin:0 0 8px}.n{color:#8f98a0;font-size:12px}</style></head>
<body><div class="col"><div class="t">$(Enc $title)</div><div class="n">$counted bytes with the links · Steam's limit 8000 · the column is 636 px as on the Workshop page</div>
$html</div></body></html>
"@
[IO.File]::WriteAllText((Join-Path $art "preview.html"), $page, $utf8)
Write-Host "Preview page: tools\art\page_v2\preview.html"
if ($ok) { Write-Host "OK" -ForegroundColor Green } else { Write-Host "NOT READY" -ForegroundColor Red; exit 1 }
