#!/bin/bash
# test_cscw32.sh - Script de test automatise pour le compilateur CSCW32
# Compile tous les exemples SAMPLES/CSHARP/test*.cs et verifie leur execution sous Wine
#
# Usage: ./TESTS/test_cscw32.sh [--verbose]
#
# Prerequis: fpc (Free Pascal), wine (Wine), CSCW32.PAS compile

set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
ROOTDIR="$(cd "$SCRIPTDIR/.." && pwd)"
COMPILER="$ROOTDIR/CSCW32"
SAMPLES="$ROOTDIR/SAMPLES/CSHARP"
VERBOSE=0
TIMEOUT=10

if [ "$1" = "--verbose" ]; then
  VERBOSE=1
fi

# Verifier que le compilateur existe
if [ ! -f "$COMPILER" ]; then
  echo "ERREUR: Compilateur CSCW32 non trouve. Compilez avec: fpc -Mtp CSCW32.PAS"
  exit 1
fi

# Verifier que Wine est disponible
if ! command -v wine &>/dev/null; then
  echo "ERREUR: Wine non trouve. Installez wine pour tester les executables Win32."
  exit 1
fi

PASS=0
FAIL=0
TOTAL=0

for SRC in "$SAMPLES"/test*.cs; do
  BASE=$(basename "$SRC" .cs)
  EXE="$SAMPLES/${BASE}.exe"
  TOTAL=$((TOTAL + 1))

  # Compiler
  COMPILE_OUT=$("$COMPILER" "$SRC" 2>&1)
  if echo "$COMPILE_OUT" | grep -qi "erreur\|fatal\|Error" | grep -v "0 erreur"; then
    echo "ECHEC COMPILATION: $BASE"
    if [ $VERBOSE -eq 1 ]; then
      echo "  $COMPILE_OUT"
    fi
    FAIL=$((FAIL + 1))
    continue
  fi

  # Verifier que l'EXE a ete genere
  if [ ! -f "$EXE" ]; then
    echo "ECHEC: $BASE - EXE non genere"
    FAIL=$((FAIL + 1))
    continue
  fi

  # Executer sous Wine
  OUTPUT=$(timeout "$TIMEOUT" wine "$EXE" </dev/null 2>/dev/null) || RC=$?
  RC=${RC:-0}

  if [ "$RC" -eq 124 ]; then
    echo "ECHEC: $BASE - TIMEOUT (>${TIMEOUT}s)"
    FAIL=$((FAIL + 1))
  elif [ "$RC" -ne 0 ]; then
    echo "ECHEC: $BASE - CRASH (exit=$RC)"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
    if [ $VERBOSE -eq 1 ]; then
      LINES=$(echo "$OUTPUT" | wc -l)
      echo "OK: $BASE ($LINES lignes)"
    fi
  fi
done

echo ""
echo "========================================="
echo "  RESULTATS CSCW32: $PASS/$TOTAL passes"
if [ $FAIL -gt 0 ]; then
  echo "  $FAIL echec(s)"
fi
echo "========================================="

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
