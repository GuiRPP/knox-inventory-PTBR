# Runs tools\barwalk\WalkTest.java: the walk about the bar (KnoxBarWalk) outside the game.
$ErrorActionPreference = "Continue"   # (the JVM warns on stderr about its Unsafe: not a failure, the exit code is)
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
$java = "C:\Users\pielo\Zomboid\tools\jdk-25\bin\java.exe"
$jar = Join-Path $root "42\media\java\client\KnoxInventoryJava.jar"
& $java -cp "$jar;$game\projectzomboid.jar;$game\ZombieBuddy.jar" (Join-Path $PSScriptRoot "WalkTest.java") $root
exit $LASTEXITCODE
