# Builds the Java part of Knox Inventory (Knox Inventory\42\media\java\client\
# KnoxInventoryJava.jar, loaded by ZombieBuddy) from src/ with the JDK 25
# in C:\Users\pielo\Zomboid\tools\jdk-25 (the game runs on Java 25 and its
# classes can't be read by older compilers).
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$jdk = "C:\Users\pielo\Zomboid\tools\jdk-25\bin"
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$cp = "$game\projectzomboid.jar;$game\ZombieBuddy.jar"
$out = Join-Path $root "build\classes"
# (since 2026-10-22 this folder is java\ inside the mod's folder - the repository;
# "Knox Inventory Java" next to the mod is a junction to it, so both ways work)
$modRoot = Split-Path $root
if (-not (Test-Path (Join-Path $modRoot "42"))) { $modRoot = Join-Path $modRoot "Knox Inventory" }
$jar = Join-Path $modRoot "42\media\java\client\KnoxInventoryJava.jar"

if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null
New-Item -ItemType Directory -Force (Split-Path $jar) | Out-Null

# javac options and source list in an argument file (paths with spaces)
$argFile = Join-Path $root "build\javac.args"
$lines = @("--release", "17", "-encoding", "UTF-8", "-cp", "`"$($cp -replace '\\', '/')`"", "-d", "`"$($out -replace '\\', '/')`"")
Get-ChildItem (Join-Path $root "src") -Recurse -Filter *.java | ForEach-Object { $lines += "`"$($_.FullName -replace '\\', '/')`"" }
[IO.File]::WriteAllLines($argFile, $lines)
& "$jdk\javac.exe" "@$argFile"
if ($LASTEXITCODE -ne 0) { throw "javac failed" }
& "$jdk\jar.exe" --create --file $jar -C $out .
if ($LASTEXITCODE -ne 0) { throw "jar failed" }
Write-Output "built $jar"

# The signature for ZombieBuddy (tools\zbs\KnoxSign.java): KnoxInventoryJava.jar.zbs next
# to the jar, made with the author's private key - kept outside the mod, never uploaded.
# No key: no signature (and an old one goes - it would not match this jar, and a jar with
# a signature that doesn't match is refused by ZombieBuddy).
$key = "C:\Users\pielo\Zomboid\tools\keys\knox_zbs.key"
$steamId = "76561198124465594"   # the Workshop item's uploader
$zbs = "$jar.zbs"
if (Test-Path $key) {
    $signOut = Join-Path $root "build\zbs"
    New-Item -ItemType Directory -Force $signOut | Out-Null
    & "$jdk\javac.exe" --release 17 -cp "$game\ZombieBuddy.jar" -d $signOut (Join-Path $root "tools\zbs\KnoxSign.java")
    if ($LASTEXITCODE -ne 0) { throw "javac KnoxSign failed" }
    & "$jdk\java.exe" -cp "$game\ZombieBuddy.jar;$signOut" KnoxSign sign $key $jar $steamId
    if ($LASTEXITCODE -ne 0) { throw "signing failed" }
} elseif (Test-Path $zbs) {
    Remove-Item $zbs
    Write-Output "no signing key: old signature removed"
}
