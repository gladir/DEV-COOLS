#!/bin/bash
# test_njs2java.sh - Teste que les fichiers .java generes par NJS2JAVA
#                    compilent et s'executent correctement.
#
# Usage: ./TESTS/test_njs2java.sh [--verbose]
#
# Prerequis: fpc (Free Pascal), javac/java (JDK 10+)

set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPTDIR/.." && pwd)"
TRANSPILER="$ROOTDIR/BINLINUX/NJS2JAVA"
SAMPLES="$ROOTDIR/SAMPLES/NJS2JAVA"
TMPDIR_BUILD="/tmp/njs2java_test_$$"
VERBOSE=0
TIMEOUT=15

if [ "$1" = "--verbose" ]; then
  VERBOSE=1
fi

# Verifier que le transpileur existe (le compiler au besoin)
if [ ! -f "$TRANSPILER" ]; then
  echo "INFO: NJS2JAVA non trouve, compilation avec fpc -Mtp NJS2JAVA.PAS..."
  ( cd "$ROOTDIR" && fpc -Mtp NJS2JAVA.PAS >/dev/null 2>&1 && \
    mkdir -p BINLINUX && mv NJS2JAVA BINLINUX/ && rm -f NJS2JAVA.o ) || {
    echo "ERREUR: echec compilation NJS2JAVA.PAS"
    exit 1
  }
fi

# Verifier que javac est disponible
if ! command -v javac &>/dev/null; then
  echo "ERREUR: javac non trouve. Installez le JDK (>= 10)."
  exit 1
fi

# Verifier que des fichiers JS de test existent
if [ ! -d "$SAMPLES" ] || [ -z "$(ls "$SAMPLES"/test*.js 2>/dev/null)" ]; then
  echo "ERREUR: Aucun fichier test*.js dans $SAMPLES"
  exit 1
fi

mkdir -p "$TMPDIR_BUILD"

PASS=0
FAIL=0
TOTAL=0

for SRC in "$SAMPLES"/test*.js; do
  BASE=$(basename "$SRC" .js)
  JAVA_OUT="$TMPDIR_BUILD/Program.java"
  TOTAL=$((TOTAL + 1))

  # Etape 1 : Transpilation JS -> Java
  RC=0
  TRANS_OUT=$(timeout "$TIMEOUT" "$TRANSPILER" "$SRC" "$JAVA_OUT" 2>&1) || RC=$?

  if [ "$RC" -eq 124 ]; then
    echo "ECHEC TRANSPILATION: $BASE - TIMEOUT (>${TIMEOUT}s)"
    FAIL=$((FAIL + 1))
    continue
  fi

  if [ ! -f "$JAVA_OUT" ]; then
    echo "ECHEC TRANSPILATION: $BASE - fichier .java non genere"
    if [ $VERBOSE -eq 1 ]; then echo "  $TRANS_OUT"; fi
    FAIL=$((FAIL + 1))
    continue
  fi

  # Etape 2 : Compilation Java
  rm -f "$TMPDIR_BUILD"/*.class
  BUILD_OUT=$(cd "$TMPDIR_BUILD" && javac Program.java 2>&1)
  if [ -n "$BUILD_OUT" ]; then
    echo "ECHEC COMPILATION: $BASE"
    if [ $VERBOSE -eq 1 ]; then
      echo "$BUILD_OUT" | head -10 | sed "s/^/  /"
    fi
    FAIL=$((FAIL + 1))
    continue
  fi

  echo "OK: $BASE"
  PASS=$((PASS + 1))
done

# Nettoyage
rm -rf "$TMPDIR_BUILD"

echo
echo "Resultats : $PASS/$TOTAL reussis, $FAIL echecs"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
