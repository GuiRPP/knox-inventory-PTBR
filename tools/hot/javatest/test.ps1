# The DEV reloader's Java part, offline (2026-11-10): the game's own Java (jre64, Zulu 25)
# and ZombieBuddy's own patch engine, no game. Version 1 of a few test classes is "Knox's jar"
# (ZombieBuddy writes its patch into knoxhottarget.Target), version 2 is swapped in by
# KnoxHotJava exactly as in the game: a body, a patch written into a game's class again, a
# new class, and a class whose make-up changed (a restart on plain Java; swapped under JBR).
#   tools\hot\javatest\test.ps1 [-java <path to java.exe>]   (e.g. JetBrains Runtime's, with
#   -jvmFlag -XX:+AllowEnhancedClassRedefinition)
param([string]$java = '', [string[]]$jvmFlag = @())
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$mod = (Resolve-Path (Join-Path $here '..\..\..')).Path
$game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$jdk = 'C:\Users\pielo\Zomboid\tools\jdk-25\bin'
if ($java -eq '') { $java = Join-Path $game 'jre64\bin\java.exe' }
$cp = "$game\projectzomboid.jar;$game\ZombieBuddy.jar"
$tmp = Join-Path $env:TEMP 'knox_hot_javatest'
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force "$tmp\agent", "$tmp\v1", "$tmp\hot\classes" | Out-Null

function Compile($out, $classpath, $sources) {
    $ErrorActionPreference = 'Continue'   # (javac's notes on stderr are not errors)
    & "$jdk\javac.exe" --release 17 -encoding UTF-8 -nowarn -cp $classpath -d $out @sources 2>&1 | Where-Object { $_ -notmatch '^Note:' }
    if ($LASTEXITCODE -ne 0) { "javatest: FAIL (javac)"; exit 1 }   # (not a throw: checkall goes on)
}

Compile "$tmp\agent" $cp @(Join-Path $here 'agent\KnoxTestAgent.java')
& "$jdk\jar.exe" --create --file "$tmp\agent.jar" --manifest (Join-Path $here 'agent\MANIFEST.MF') -C "$tmp\agent" .
$knox = Join-Path $mod 'java\src\knox\java'
$v1 = @(Get-ChildItem -Recurse -Filter *.java (Join-Path $here 'v1'), (Join-Path $here 'common')).FullName +
      @('KnoxHot.java', 'KnoxHotJava.java', 'KnoxHotEngine.java' | ForEach-Object { Join-Path $knox $_ })
Compile "$tmp\v1" $cp $v1
& "$jdk\jar.exe" --create --file "$tmp\test.jar" -C "$tmp\v1" .
Compile "$tmp\hot\classes" "$tmp\v1;$cp" @(Get-ChildItem -Recurse -Filter *.java (Join-Path $here 'v2')).FullName
Set-Content -Path "$tmp\hot\stamp.txt" -Value (Get-Date -Format o) -Encoding ascii

$flags = @("-javaagent:$tmp\agent.jar")
if ($jvmFlag.Count -gt 0) { $flags += $jvmFlag }
$ErrorActionPreference = 'Continue'
$out = & $java @flags -cp "$tmp\test.jar;$cp" knox.java.HotJavaTestMain "$tmp\hot" "$tmp\test.jar" "$tmp\v1" 2>&1
$out | ForEach-Object { "$_" } | Where-Object { $_ -match '^(pass|FAIL|apply|ok|restart|error|none|off|javatest)|Exception' }
