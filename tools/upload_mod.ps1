# Uploads a new version of the mod's FILES to its Workshop item without starting the
# game, through Valve's SteamCMD: the folder built by prepare_workshop.ps1
# (Zomboid\Workshop\KnoxInventory\Contents - the same one the game's own uploader sends).
# The page (title, description, preview, tags, visibility) is NOT touched: that is
# upload_page.ps1.
#
# Run prepare_workshop.ps1 first; afterwards run it again with -Clean.
# SteamCMD logs in with the session it remembers; if it asks for a password or a Steam
# Guard code, that is typed by the account's owner in a window of their own.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\upload_mod.ps1 -Login <steam login> [-Note "what changed"]

param([Parameter(Mandatory = $true)][string]$Login, [string]$Note = "",
      [string]$NoteFile = "")   # the change notes from a file (BBCode, e.g. CHANGE_NOTES_1.0_BETA.txt)
if ($NoteFile) {
    $Note = [IO.File]::ReadAllText((Resolve-Path $NoteFile), (New-Object Text.UTF8Encoding $false))
    if ($Note.Length -gt 7900) { throw "the change notes are $($Note.Length) characters: over Steam's 8000" }
}

$ErrorActionPreference = "Stop"
$steamcmd = Join-Path $env:USERPROFILE "Zomboid\tools\steamcmd\steamcmd.exe"
if (-not (Test-Path $steamcmd)) { throw "SteamCMD is not installed: unpack steamcmd.zip into $(Split-Path $steamcmd)" }
if (Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue) { throw "Project Zomboid is running: close the game first." }

$contents = Join-Path $env:USERPROFILE "Zomboid\Workshop\KnoxInventory\Contents"
# (the release and, since 2026-10-20, the 1.0 beta next to it: see prepare_workshop.ps1)
$version = @()
foreach ($m in "KnoxInventory", "KnoxInventoryBeta") {
    $mod = Join-Path $contents "mods\$m"
    foreach ($need in "42\mod.info", "42\media\java\client\KnoxInventoryJava.jar", "42\media\lua\client\Knox\KnoxMain.lua") {
        if (-not (Test-Path (Join-Path $mod $need))) { throw "The built folder is not complete ($m\$need is missing): run prepare_workshop.ps1 first." }
    }
    $version += "$m " + (Select-String -Path (Join-Path $mod "42\mod.info") -Pattern '^modversion=(.+)$').Matches[0].Groups[1].Value
}
$version = $version -join " + "
$files = (Get-ChildItem $contents -Recurse -File).Count

# SteamCMD reads this file without escape sequences: no double quotes may go into a
# value - pairs become typographic ones (as upload_page.ps1 does), line ends stay
$lq = [string][char]0x201C; $rq = [string][char]0x201D
$plain = ([regex]::Replace($Note.Replace("`r`n", "`n"), '"([^"\n]*)"', ($lq + '$1' + $rq))).Replace('"', $rq)
$utf8 = New-Object Text.UTF8Encoding $false
$work = Join-Path $env:TEMP "knox_upload"
New-Item -ItemType Directory -Force $work | Out-Null
$vdf = Join-Path $work "item.vdf"
$lines = @('"workshopitem"', '{', '  "appid" "108600"', '  "publishedfileid" "3816775774"',
    ('  "contentfolder" "' + $contents.Replace('\', '\\') + '"'),
    ('  "changenote" "' + $plain + '"'), '}')
[IO.File]::WriteAllText($vdf, ($lines -join "`n"), $utf8)

Write-Host "Uploading Knox Inventory $version ($files files) from $contents"
& $steamcmd +login $Login +workshop_build_item $vdf +quit
$code = $LASTEXITCODE
Write-Host "SteamCMD finished with code $code (0 = done)."
# The built folder away at once (prepare_workshop.ps1 -Clean): the game loads mods
# from Zomboid\Workshop too and prefers that copy - left there after a news-only
# upload, the author's game ran the released 0.9.8.7 instead of the work (2026-10-18).
$built = Join-Path $env:USERPROFILE "Zomboid\Workshop\KnoxInventory\Contents"
if (Test-Path $built) { Remove-Item -LiteralPath $built -Recurse -Force; Write-Host "Removed $built (the game loads Zomboid\mods\Knox Inventory again)." }
exit $code
