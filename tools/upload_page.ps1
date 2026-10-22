# Updates the Workshop item's page without starting the game, through Valve's SteamCMD:
# the preview picture (tools\art\preview_workshop.jpg, 1024x1024 - make_poster.ps1) and, with -Description, the title and the
# description from WORKSHOP_DESCRIPTION.txt. The mod's files on Steam are NOT touched
# (no content folder is given): a new version of the mod still goes up from the game.
#
# Run it yourself in a PowerShell window: SteamCMD asks for the account's password and
# the Steam Guard code there. Neither is stored by this script.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\upload_page.ps1 -Login <steam login> [-Description]
#
# SteamCMD is looked for in Zomboid\tools\steamcmd\steamcmd.exe (Valve's installer:
# https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip, unpack it there).

param([Parameter(Mandatory = $true)][string]$Login, [switch]$Description,
      [string]$Preview = "")   # another picture to send (the animated tools\art\preview_workshop.gif)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$steamcmd = Join-Path $env:USERPROFILE "Zomboid\tools\steamcmd\steamcmd.exe"
if (-not (Test-Path $steamcmd)) { throw "SteamCMD is not installed: unpack steamcmd.zip into $(Split-Path $steamcmd)" }

$utf8 = New-Object Text.UTF8Encoding $false
$work = Join-Path $env:TEMP "knox_page"
New-Item -ItemType Directory -Force $work | Out-Null
# 1024x1024: the Workshop pads a picture smaller than its 322x322 tiles with black
# (the page's preview is the animated GIF since 2026-10-14; the still JPG went up
# by default once and replaced it - the author, 2026-10-18)
$src = $(if ($Preview) { $Preview } else { Join-Path $PSScriptRoot "art\preview_workshop.gif" })
# (Steam refused 1 016 336 bytes with "Limit exceeded": its megabyte is 1 000 000)
if ((Get-Item -LiteralPath $src).Length -ge 1000000) { throw "the preview is over Steam's 1 000 000 bytes: $src" }
# (not "$preview": PowerShell names don't care about case - it is $Preview)
$sent = Join-Path $work ("preview" + [IO.Path]::GetExtension($src))
Copy-Item -LiteralPath $src -Destination $sent -Force

function Vdf([string]$s) { $s.Replace('\', '\\').Replace('"', '\"') }

$lines = @('"workshopitem"', '{', '  "appid" "108600"', '  "publishedfileid" "3816775774"',
    ('  "previewfile" "' + (Vdf $sent) + '"'))
if ($Description) {
    $src = [IO.File]::ReadAllLines((Join-Path $root "WORKSHOP_DESCRIPTION.txt"), $utf8)
    if ($src[0] -notmatch '^Title:\s*(.+)$') { throw "WORKSHOP_DESCRIPTION.txt: the first line must be 'Title: <workshop title>'" }
    $title = $Matches[1].Trim()
    $desc = $src | Select-Object -Skip 2
    while ($desc.Count -and $desc[-1].Trim() -eq '') { $desc = $desc[0..($desc.Count - 2)] }
    if ($desc | Where-Object { $_ -match '\[img\]\{' }) { throw "WORKSHOP_DESCRIPTION.txt: [img]{...} placeholders are left" }
    # The game's own uploader ends a mod's page with its Workshop ID and Mod ID;
    # SteamCMD sends the text as it is, and they were gone from the page (the
    # author, 2026-10-18: "they must always be there"). So they are added here,
    # always last, the Mod ID from 42\mod.info.
    $desc = @($desc | Where-Object { $_ -notmatch '^\s*(Workshop ID|Mod ID):' })
    while ($desc.Count -and $desc[-1].Trim() -eq '') { $desc = $desc[0..($desc.Count - 2)] }
    $modId = (Select-String -Path (Join-Path $root "42\mod.info") -Pattern '^id=(.+)$').Matches[0].Groups[1].Value.Trim()
    # (the item carries two mods while the 1.0 beta is out: both ids, as the game's
    # uploader lists every mod of an item - see prepare_workshop.ps1)
    $desc += @('', 'Workshop ID: 3816775774', "Mod ID: $modId", "Mod ID: KnoxInventoryBeta")
    $text = $desc -join "`n"
    if ($utf8.GetByteCount($text) -gt 7950) { throw "the description is over Steam's 8000-byte limit" }
    # SteamCMD reads this file without escape sequences: a \" ends the value
    # ("key name too long", 2026-10-13). So no straight double quotes go in: pairs
    # become typographic ones, and backslashes stay single.
    $lq = [string][char]0x201C; $rq = [string][char]0x201D
    $plain = { param($s) ([regex]::Replace($s, '"([^"\n]*)"', ($lq + '$1' + $rq))).Replace('"', $rq) }
    $lines += ('  "title" "' + (& $plain $title) + '"')
    $lines += ('  "description" "' + (& $plain $text) + '"')
}
$lines += '}'
$vdf = Join-Path $work "item.vdf"
[IO.File]::WriteAllText($vdf, ($lines -join "`n"), $utf8)

Write-Host "Updating the page of item 3816775774: preview$(if ($Description) { ', title and description' })."
Write-Host "SteamCMD will now ask for the password and the Steam Guard code."
& $steamcmd +login $Login +workshop_build_item $vdf +quit
Write-Host "SteamCMD finished with code $LASTEXITCODE (0 = done)."
