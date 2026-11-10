# The game on JetBrains Runtime 25, for the DEV reloader (the author's plan 2026-11-10, stage 4:
# "no restart even for Java"). The game's own Java (Zulu) swaps only method bodies; JetBrains
# Runtime with -XX:+AllowEnhancedClassRedefinition also takes new fields, methods and lambdas,
# so java\hot.ps1's build goes in without "restart needed".
#
# Nothing of the game's is changed: the game is started from its folder the way its launcher
# does it (ProjectZomboid64.json is read each time - a game update's flags come along), only
# with JBR's java.exe, G1 instead of Shenandoah (enhanced redefinition takes Serial or G1 only:
# "Must use the Serial or G1 GC with enhanced class redefinition") and the flag above.
# ZombieBuddy: -agentlib:zbNative stays; zbNative loads instrument.dll from the running Java's
# folder (JBR has its own) and ZombieBuddy.jar from the game's folder.
# Steam must be running (steam_appid.txt in the game's folder lets the game find it).
#
#   tools\hot\run_jbr.ps1            the game, as from Steam
#   tools\hot\run_jbr.ps1 -debug     any of the game's own arguments go through
#   tools\hot\run_jbr.ps1 -show      only print the command
#
# JBR lives in C:\Users\pielo\Zomboid\tools\jbr-25 (jbr-25.0.4.1-windows-x64-b635.79, from
# github.com/JetBrains/JetBrainsRuntime releases, checksum checked 2026-11-10).
param([switch]$show, [Parameter(ValueFromRemainingArguments = $true)][string[]]$gameArgs = @())
$ErrorActionPreference = 'Stop'
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$jbr = 'C:\Users\pielo\Zomboid\tools\jbr-25\bin\java.exe'
if (-not (Test-Path $jbr)) { throw "No JetBrains Runtime at $jbr" }

$cfg = Get-Content (Join-Path $game 'ProjectZomboid64.json') -Raw | ConvertFrom-Json
$vm = @()
foreach ($a in $cfg.vmArgs) {
    if ($a -match '^-XX:\+Use\w+GC$') { continue }   # (the collector is ours: G1)
    if ($vm -contains $a) { continue }                 # (the game's list repeats some)
    $vm += $a
}
$vm += '-XX:+UseG1GC'
$vm += '-XX:+AllowEnhancedClassRedefinition'
$cp = ($cfg.classpath -join ';')
$main = $cfg.mainClass -replace '/', '.'
$all = $vm + @('-cp', $cp, $main) + $gameArgs

if ($show) { "cd `"$game`""; "`"$jbr`" " + ($all -join ' '); return }
"Starting the game on JetBrains Runtime (enhanced class redefinition on)..."
Start-Process -FilePath $jbr -ArgumentList $all -WorkingDirectory $game
