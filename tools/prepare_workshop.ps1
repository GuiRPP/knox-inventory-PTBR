# Builds the Steam Workshop upload folder:
#   Zomboid\Workshop\KnoxInventory\
#     preview.png                          (256x256: 42\poster.png)
#     Contents\mods\KnoxInventory\         the released 0.9.8.7 (kept in Zomboid\backups\knox_0.9.8.7_release)
#     Contents\mods\KnoxInventoryBeta\     the work as "Knox Inventory 1.0 BETA" (42\ and common\ only:
#                                           no tools, no notes; the Java part is
#                                           42\media\java\client\KnoxInventoryJava.jar,
#                                           built by java\build.ps1)
# When 1.0 itself is released, this goes back to one mod: the work as KnoxInventory.
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
# Two mods in the one Workshop item since the 1.0 beta (the author, 2026-10-20):
#   Contents\mods\KnoxInventory\       the released 0.9.8.7, as it was
#   Contents\mods\KnoxInventoryBeta\   the work: "Knox Inventory 1.0 BETA"
# The player picks one in the mod list; they can't be on together (incompatible=).
# The work folder (Zomboid\mods\Knox Inventory) keeps the id KnoxInventory - the
# author's own saves are on it; it becomes the beta only here.
# ---------------------------------------------------------------------------------

# The release: a copy of 0.9.8.7 kept apart, taken once from what Steam installed
# (after an upload of this layout Steam's own folder holds both mods - the copy
# keeps the release as it was published).
$stableKeep = Join-Path $env:USERPROFILE "Zomboid\backups\knox_0.9.8.7_release"
if (-not (Test-Path (Join-Path $stableKeep "42\mod.info"))) {
    $steam = "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3816775774\mods\KnoxInventory"
    if (-not (Test-Path (Join-Path $steam "42\mod.info"))) { throw "No copy of the released 0.9.8.7: neither $stableKeep nor $steam" }
    $v = (Select-String -Path (Join-Path $steam "42\mod.info") -Pattern '^modversion=(.+)$').Matches[0].Groups[1].Value.Trim()
    if ($v -ne "0.9.8.7") { throw "Steam's copy is $v, not the released 0.9.8.7: put the release into $stableKeep by hand" }
    New-Item -ItemType Directory -Force $stableKeep | Out-Null
    Copy-Item -Path (Join-Path $steam "*") -Destination $stableKeep -Recurse -Force
    Write-Host "Kept the released 0.9.8.7 in $stableKeep"
}
$stable = Join-Path $contents "KnoxInventory"
New-Item -ItemType Directory -Force $stable | Out-Null
Copy-Item -Path (Join-Path $stableKeep "*") -Destination $stable -Recurse -Force

# What the release gets from the beta's coming: three changes (and the pictures of the
# beta's post, step 3), nothing else.
# 1. it can't be on together with the beta
$mi = Join-Path $stable "42\mod.info"
$lines = [IO.File]::ReadAllLines($mi, $utf8) | Where-Object { $_ -notmatch '^incompatible=' }
$lines = @($lines) + "incompatible=\KnoxInventoryBeta"
[IO.File]::WriteAllLines($mi, [string[]]$lines, $utf8)
# 2. a save played with the beta has Knox: the release's save guard must not add itself to it
$sg = Join-Path $stable "42\media\lua\client\Knox\KnoxSaveGuard.lua"
$t = [IO.File]::ReadAllText($sg, $utf8)
$from = 'if okSnap and snap and not has(info.activeMods, MOD_ID) then'
$to = 'if okSnap and snap and not has(info.activeMods, MOD_ID) and not has(info.activeMods, "KnoxInventoryBeta") then'
if (-not $t.Contains($from)) { throw "The release's KnoxSaveGuard.lua is not as expected: $sg" }
[IO.File]::WriteAllText($sg, $t.Replace($from, $to), $utf8)
# 3. the news of the beta, so that the release's players hear of it (the post between
#    the BETA-POST marks of the work's news, put on top of the release's posts)
foreach ($lang in "ru", "en") {
    $work = [IO.File]::ReadAllText((Join-Path $root "42\media\knox\news_$lang.txt"), $utf8)
    $m = [regex]::Match($work, '(?s); BETA-POST-BEGIN\r?\n(.*?); BETA-POST-END')
    if (-not $m.Success) { throw "news_$lang.txt: the BETA-POST marks are missing" }
    $nf = Join-Path $stable "42\media\knox\news_$lang.txt"
    $rel = [IO.File]::ReadAllLines($nf, $utf8)
    $at = 0
    while ($at -lt $rel.Count -and $rel[$at] -notmatch '^# ') { $at++ }
    $out = @($rel[0..($at - 1)]) + ($m.Groups[1].Value.TrimEnd() -split "\r?\n") + @('') + @($rel[$at..($rel.Count - 1)])
    [IO.File]::WriteAllLines($nf, [string[]]$out, $utf8)
    # ...and the pictures it names (@banner, @art, @), which the frozen release lacks
    # (the gear of a technical update, 2026-10-22: else the release showed its stock forest)
    foreach ($pm in [regex]::Matches($m.Groups[1].Value, '(?m)^@(?:banner|art)?\s*(\S+\.png)\s*$')) {
        $pic = $pm.Groups[1].Value
        $src = Join-Path $root "42\media\knox\news\$pic"
        $dstPic = Join-Path $stable "42\media\knox\news\$pic"
        if (-not (Test-Path $src)) { throw "news_$lang.txt: the beta post's picture $pic is missing" }
        if (-not (Test-Path $dstPic)) { Copy-Item -LiteralPath $src -Destination $dstPic }
    }
}

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
    if ($_ -match '^name=') { "name=Knox Inventory 1.0 BETA" }
    elseif ($_ -match '^id=') { "id=KnoxInventoryBeta" }
    elseif ($_ -match '^modversion=') { "modversion=1.0-beta" }
    elseif ($_ -match '^description=') { "description=TEST VERSION of Knox Inventory 1.0 - for trying the new features and reporting bugs, not for a full playthrough. Back up your saves. Only one of Knox Inventory and Knox Inventory 1.0 BETA can be enabled. Requires ZombieBuddy." }
    else { $_ }
}
$lines = @($lines) + "incompatible=\KnoxInventory"
[IO.File]::WriteAllLines($mi, [string[]]$lines, $utf8)
$idFile = Join-Path $dst "42\media\lua\shared\Knox\KnoxModId.lua"
[IO.File]::WriteAllLines($idFile, [string[]]@(
    "-- Written by tools\prepare_workshop.ps1 into the beta's copy only: which of Knox's mods this is (KnoxTheme.MOD_ID).",
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
if ($bytes -gt 7800) { throw "WORKSHOP_DESCRIPTION.txt is $bytes bytes: over Steam's 8000-byte limit (keep it under 7800)" }

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
