# The fast Java build for the DEV reloader (2026-11-10): Knox's classes compiled into
# java\build\hot\classes - not into the jar (the game holds it open) - and then
# java\build\hot\stamp.txt written; the game that is going (with Zomboid\Lua\knox_dev.txt)
# sees the stamp and swaps the changed classes in (KnoxHotJava): bodies of methods on plain
# Java, whole classes on JetBrains Runtime (tools\hot\run_jbr.ps1), ZombieBuddy's patches
# written into the game's classes again. A note in the game's corner says what it did.
#   java\hot.ps1          (once)
#   java\hot.ps1 -watch   (on every saved .java, until Ctrl+C)
# The jar is still built by build.ps1 - before a release, and for a normal start.
param([switch]$watch)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$jdk = "C:\Users\pielo\Zomboid\tools\jdk-25\bin"
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$cp = "$game\projectzomboid.jar;$game\ZombieBuddy.jar"
$hot = Join-Path $root "build\hot"
$out = Join-Path $hot "classes"
$tmp = Join-Path $hot "next"

function Build {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $argFile = Join-Path $hot "javac.args"
    $lines = @("--release", "17", "-encoding", "UTF-8", "-nowarn", "-cp", "`"$($cp -replace '\\', '/')`"", "-d", "`"$($tmp -replace '\\', '/')`"")
    Get-ChildItem (Join-Path $root "src") -Recurse -Filter *.java | ForEach-Object { $lines += "`"$($_.FullName -replace '\\', '/')`"" }
    [IO.File]::WriteAllLines($argFile, $lines)
    $ErrorActionPreference = "Continue"   # (javac's notes on stderr are not errors)
    $msg = & "$jdk\javac.exe" "@$argFile" 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch '^Note:' }
    $code = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($code -ne 0) {
        $msg | Write-Output
        Write-Output "hot: javac failed - nothing handed to the game"
        return
    }
    # (the classes whole into place, then the stamp: the game never reads a half-written folder)
    if (Test-Path $out) { Remove-Item -Recurse -Force $out }
    Move-Item $tmp $out
    Set-Content -Path (Join-Path $hot "stamp.txt") -Value (Get-Date -Format o) -Encoding ascii
    Write-Output ("hot: built " + (Get-Date -Format HH:mm:ss) + " - the game swaps it in within a second")
}

New-Item -ItemType Directory -Force $hot | Out-Null
Build
if ($watch) {
    $src = Join-Path $root "src"
    $last = @{}
    Get-ChildItem $src -Recurse -Filter *.java | ForEach-Object { $last[$_.FullName] = $_.LastWriteTimeUtc }
    Write-Output "hot: watching $src (Ctrl+C to stop)"
    while ($true) {
        Start-Sleep -Milliseconds 400
        $changed = $false
        Get-ChildItem $src -Recurse -Filter *.java | ForEach-Object {
            if (-not $last.ContainsKey($_.FullName) -or $last[$_.FullName] -ne $_.LastWriteTimeUtc) {
                $last[$_.FullName] = $_.LastWriteTimeUtc
                $changed = $true
            }
        }
        if ($changed) {
            Start-Sleep -Milliseconds 300   # (an editor saving several files)
            Get-ChildItem $src -Recurse -Filter *.java | ForEach-Object { $last[$_.FullName] = $_.LastWriteTimeUtc }
            Build
        }
    }
}
