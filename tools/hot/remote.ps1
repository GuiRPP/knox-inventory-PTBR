# The remote (DEV reloader, 2026-11-10): Lua run in the game that is going, its answer back.
# The game must have Zomboid\Lua\knox_dev.txt (the author's computer); it reads the request
# within about half a second - in the main menu and in a game, paused too.
#   tools\hot\remote.ps1 "return KnoxHot.state()"
#   tools\hot\remote.ps1 -file some.lua
# What the code printed comes back line by line, then "return ..." for each value it returned
# (tables two levels deep). Exit code 1: the game said error, 2: no answer in time.
param([string]$code = '', [string]$file = '', [int]$timeout = 15)
$ErrorActionPreference = 'Stop'
if ($file -ne '') { $code = [IO.File]::ReadAllText((Resolve-Path $file), [Text.Encoding]::UTF8) }
if ($code -eq '') { Write-Output 'remote: no code (give it as the first argument or -file)'; exit 2 }
$lua = Join-Path $env:USERPROFILE 'Zomboid\Lua'
$in = Join-Path $lua 'knox_remote_in.lua'
$out = Join-Path $lua 'knox_remote_out.txt'
$id = [DateTime]::UtcNow.Ticks.ToString()
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($in, "-- knox remote $id`n$code`n", $utf8)
$until = (Get-Date).AddSeconds($timeout)
while ((Get-Date) -lt $until) {
    Start-Sleep -Milliseconds 150
    if (-not (Test-Path $out)) { continue }
    try { $text = [IO.File]::ReadAllText($out, [Text.Encoding]::UTF8) } catch { continue }
    $lines = $text -split "`r?`n"
    if ($lines[0] -ne "id $id") { continue }
    $lines[1..($lines.Count - 1)] | Where-Object { $_ -ne '' } | Write-Output
    if ($lines[1] -eq 'ok') { exit 0 } else { exit 1 }
}
Write-Output "remote: no answer in $timeout s (the game not running, no knox_dev.txt, dev.hot=0, or it is loading)"
exit 2
