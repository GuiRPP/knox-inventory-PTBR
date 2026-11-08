# Builds the Steam Workshop upload folder:
#   Zomboid\Workshop\KnoxInventory\
#     preview.png                          (256x256: 42\poster.png)
#     Contents\mods\KnoxInventoryBeta\     the work as "Knox Inventory" (42\ and common\ only:
#                                           no tools, no notes; the Java part is
#                                           42\media\java\client\KnoxInventoryJava.jar,
#                                           built by java\build.ps1)
# (the released 0.9.8.7 was a second mod here until 2026-11-08: see below)
# The in-game uploader (main menu > Workshop) creates workshop.txt on first upload.
# Re-run before every update; the Contents folder is replaced, workshop.txt is kept
# (its title and description are rebuilt from WORKSHOP_DESCRIPTION.txt).
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\prepare_workshop.ps1

#        powershell -ExecutionPolicy Bypass -File tools\prepare_workshop.ps1 -Clean
# -Clean removes the built Contents again (workshop.txt and preview.png stay).
# Do it after every upload: the game also loads mods from Zomboid\Workshop and
# prefers that copy, so while it exists in-game tests run the old build.

param([switch]$Clean)

$ErrorActionPreference = "Stop"
# the game also loads mods from Zomboid\Workshop and keeps the Java jar open:
# rebuilding while it runs would leave a half-deleted folder
if (Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue) {
    throw "Project Zomboid is running: close the game first (it keeps files of the Workshop folder open)."
}
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ws = Join-Path $env:USERPROFILE "Zomboid\Workshop\KnoxInventory"
$contents = Join-Path $ws "Contents\mods"

if ($Clean) {
    if (Test-Path (Join-Path $ws "Contents")) { Remove-Item -LiteralPath (Join-Path $ws "Contents") -Recurse -Force }
    Write-Host "Removed the built Contents from ${ws}: the game now loads Zomboid\mods\Knox Inventory."
    return
}

New-Item -ItemType Directory -Force $ws | Out-Null
if (Test-Path $contents) { Remove-Item -LiteralPath $contents -Recurse -Force }
New-Item -ItemType Directory -Force $contents | Out-Null

if (-not (Test-Path (Join-Path $root "42\media\java\client\KnoxInventoryJava.jar"))) {
    throw "The Java part is missing: run java\build.ps1 first."
}
$utf8 = New-Object Text.UTF8Encoding $false

# ---------------------------------------------------------------------------------
# One mod in the Workshop item again since 2026-11-08 (the author: "удали legacy
# версию мода. Теперь 1.0 beta единственная и основная версия knox"): the frozen
# 0.9.8.7 (KnoxInventory, 2026-10-20 .. 2026-11-08) is gone from the item.
#   Contents\mods\KnoxInventoryBeta\   the work, named "Knox Inventory"
# The id stays KnoxInventoryBeta (the author's choice): the saves of the beta's
# players keep their mod. The work folder (Zomboid\mods\Knox Inventory) keeps the
# id KnoxInventory - the author's own saves are on it; it becomes KnoxInventoryBeta
# only here. The release's last copy stays in Zomboid\backups\knox_0.9.8.7_release.
# ---------------------------------------------------------------------------------

# The beta: the work as it is now.
$dst = Join-Path $contents "KnoxInventoryBeta"
New-Item -ItemType Directory -Force $dst | Out-Null
foreach ($part in "42", "common") {
    $src = Join-Path $root $part
    if (Test-Path $src) {
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    } else {
        New-Item -ItemType Directory -Force (Join-Path $dst $part) | Out-Null
    }
}

# the author's own tools stay home (2026-10-16: "убрать dev режим для дропа в
# стим"): the test bench (Insert) and the filming mode (Home) with its scenes.
# Nothing else needs them - every other file asks whether they are there.
foreach ($devOnly in "42\media\lua\client\Knox\KnoxTestBench.lua", "42\media\lua\client\Knox\KnoxStudio.lua", "42\media\knox\studio_ru.txt") {
    $f = Join-Path $dst $devOnly
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}

# its own id, name and version, and the file that tells its Lua which mod it is
$mi = Join-Path $dst "42\mod.info"
$lines = [IO.File]::ReadAllLines($mi, $utf8) | Where-Object { $_ -notmatch '^incompatible=' } | ForEach-Object {
    if ($_ -match '^name=') { "name=Knox Inventory" }
    elseif ($_ -match '^id=') { "id=KnoxInventoryBeta" }
    elseif ($_ -match '^modversion=') { "modversion=1.0-beta" }
    elseif ($_ -match '^description=') { "description=Knox Inventory 1.0 BETA: the whole Project Zomboid UI in the style of Escape From Tarkov - a grid inventory around your live 3D character, rigs and bags in bags, its own right-click menu, a car dashboard and a main menu that is a camp by the fire or a bar in a blizzard. Requires ZombieBuddy." }
    else { $_ }
}
$lines = @($lines) + "incompatible=\KnoxInventory"
[IO.File]::WriteAllLines($mi, [string[]]$lines, $utf8)
$idFile = Join-Path $dst "42\media\lua\shared\Knox\KnoxModId.lua"
[IO.File]::WriteAllLines($idFile, [string[]]@(
    "-- Written by tools\prepare_workshop.ps1 into the Workshop copy only: which of Knox's mods this is (KnoxTheme.MOD_ID).",
    'KnoxModId = "KnoxInventoryBeta"'), $utf8)

Copy-Item -LiteralPath (Join-Path $root "42\poster.png") -Destination (Join-Path $ws "preview.png") -Force

# workshop.txt: title and description from WORKSHOP_DESCRIPTION.txt (first line
# "Title: ...", the description from the line after it); id, tags and visibility
# are kept. Steam's limit is 8000 bytes of UTF-8 (Cyrillic takes 2 per letter).
$utf8 = New-Object Text.UTF8Encoding $false
$src = [IO.File]::ReadAllLines((Join-Path $root "WORKSHOP_DESCRIPTION.txt"), $utf8)
if ($src[0] -notmatch '^Title:\s*(.+)$') { throw "WORKSHOP_DESCRIPTION.txt: the first line must be 'Title: <workshop title>'" }
$title = $Matches[1].Trim()
$desc = $src | Select-Object -Skip 2
while ($desc.Count -and $desc[-1].Trim() -eq '') { $desc = $desc[0..($desc.Count - 2)] }
if ($desc | Where-Object { $_ -match '^=' }) { throw "WORKSHOP_DESCRIPTION.txt: lines starting with '=' break workshop.txt" }
if ($desc | Where-Object { $_ -match '\[img\]\{' }) { throw "WORKSHOP_DESCRIPTION.txt: [img]{...} placeholders are left - put the uploaded pictures' links in first" }
$bytes = $utf8.GetByteCount(($desc -join "`n"))
if ($bytes -gt 7950) { throw "WORKSHOP_DESCRIPTION.txt is $bytes bytes: over Steam's 8000-byte limit (keep it under 7950, as upload_page.ps1 does)" }

$wt = Join-Path $ws "workshop.txt"
if (Test-Path $wt) {
    $old = [IO.File]::ReadAllLines($wt, $utf8)
} else {
    # first upload: the uploader fills in the id; tags and visibility to check there
    $old = @("version=1", "title=", "tags=Build 42;Interface;QoL", "visibility=public")
}
$keep = $old | Where-Object { $_ -notmatch '^description=' } | ForEach-Object { if ($_ -match '^title=') { "title=$title" } else { $_ } }
$out = @()
foreach ($l in $keep) {
    $out += $l
    if ($l -match '^title=') { $out += ($desc | ForEach-Object { "description=$_" }) }
}
[IO.File]::WriteAllLines($wt, $out, $utf8)

$files = (Get-ChildItem $contents -Recurse -File).Count
Write-Host "Workshop folder: $ws ($files files)"
Write-Host "workshop.txt: title '$title', description $bytes bytes (Steam limit 8000)"
