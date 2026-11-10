#!/usr/bin/env bash
# The winter bar's frame on the real video card, without the game (see Harness.java):
#   run.sh <classes dir> out.png width height [time] [high|low] [frames]
# Builds only the frame's classes and the harness into <classes dir>.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
MOD="$(cd "$HERE/../.." && pwd)"
JDK="/c/Users/pielo/Zomboid/tools/jdk-25/bin"
GAME="C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid/projectzomboid.jar"
OUT="$(cygpath -m "$1")"; shift
mkdir -p "$OUT"
"$JDK/javac.exe" --release 17 -encoding UTF-8 -nowarn -cp "$GAME" -d "$OUT" \
  "$(cygpath -m "$MOD/java/src/knox/java/KnoxBarMesh.java")" \
  "$(cygpath -m "$MOD/java/src/knox/java/KnoxBarLife.java")" \
  "$(cygpath -m "$MOD/java/src/knox/java/KnoxBarFrame.java")" \
  "$(cygpath -m "$MOD/java/src/knox/java/KnoxMenuSwipe.java")" \
  "$(cygpath -m "$HERE/Harness.java")"
"$JDK/java.exe" -Dknox.mod="$(cygpath -m "$MOD")" $BARJAVA -cp "$OUT;$GAME" Harness "$@"
