# Backs up everything the public repository leaves out (the author, 2026-10-28: "so it
# isn't lost if my account gets blocked"): the notes (ROADMAP, FEEDBACK, ...), CLAUDE.md,
# .claude (skills, agents, Claude's memory, mockups, perf), the Artlist sounds, tools\art.
# The list is git's own "ignored" list, so a new ignored file is backed up without
# touching this script. Left out: the Steam login (stays on this PC only - the author),
# the jar and java\build (rebuilt by java\build.ps1), the report.txt files (regenerated).
#
# The copy goes to a mirror folder with its own git (default Zomboid\knox-workspace) and
# is pushed to the PRIVATE repository github.com/SVNTHETIK/knox-workspace when the mirror
# has a remote. Restore: clone knox-inventory, clone knox-workspace, copy the second over
# the first.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\backup_workspace.ps1 [-Dest <folder>] [-NoPush]

param([string]$Dest = (Join-Path $env:USERPROFILE "Zomboid\knox-workspace"), [switch]$NoPush)

$ErrorActionPreference = "Stop"
$git = "C:\Program Files\Git\cmd\git.exe"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$remote = "https://github.com/SVNTHETIK/knox-workspace.git"

$skip = @('^\.claude/steam_login\.txt$', '\.jar$', '^java/build/', '/report\.txt$')
$files = & $git -C $root -c core.quotepath=off ls-files --others --ignored --exclude-standard |
    Where-Object { $p = $_; -not ($skip | Where-Object { $p -match $_ }) }
if (-not $files) { throw "git listed no ignored files - wrong folder?" }

if (-not (Test-Path (Join-Path $Dest ".git"))) {
    New-Item -ItemType Directory -Force $Dest | Out-Null
    & $git -C $Dest init -q -b main
    # the same public identity as knox-inventory, never the author's mail
    & $git -C $Dest config user.name "SVNTHETIK"
    & $git -C $Dest config user.email "344725640+SVNTHETIK@users.noreply.github.com"
    & $git -C $Dest config core.autocrlf false   # a backup keeps the bytes as they are
    & $git -C $Dest remote add origin $remote
}

$keep = @{}
foreach ($rel in $files) {
    $keep[$rel.Replace('/', '\')] = $true
    $to = Join-Path $Dest $rel
    New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $rel) -Destination $to -Force
}
# files deleted from the project leave the mirror too (git history still has them)
Get-ChildItem -LiteralPath $Dest -Recurse -File -Force |
    Where-Object { $_.FullName -notlike (Join-Path $Dest ".git\*") } |
    ForEach-Object {
        $rel = $_.FullName.Substring($Dest.Length + 1)
        if (-not $keep[$rel]) { Remove-Item -LiteralPath $_.FullName -Force }
    }

& $git -C $Dest add -A
& $git -C $Dest diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host "Nothing changed since the last backup ($($files.Count) files)." }
else {
    & $git -C $Dest commit -q -m "Backup $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Write-Host "Committed $($files.Count) files to $Dest"
}
# pushed even without a new commit: an earlier -NoPush or failed push may be pending
if (-not $NoPush) { & $git -C $Dest push -q -u origin main; if ($LASTEXITCODE -ne 0) { throw "push failed - does the private repository exist?" } }
