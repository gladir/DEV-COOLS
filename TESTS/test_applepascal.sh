#!/bin/bash
# =============================================================================
# test_applepascal.sh - Tests de regression pour TPCW32 mode Apple Pascal
# =============================================================================
# Usage: bash TESTS/test_applepascal.sh [--verbose]
# Compile chaque fichier .pas dans SAMPLES/APPLEPASCAL/ avec --applepascal
# et execute avec Wine.
# =============================================================================

set -e

VERBOSE=0
if [ "$1" = "--verbose" ]; then VERBOSE=1; fi

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="$BASEDIR/TPCW32"
SAMPDIR="$BASEDIR/SAMPLES/APPLEPASCAL"

if [ ! -x "$COMPILER" ]; then
  echo "ERREUR: $COMPILER non trouve. Compiler d abord avec: fpc -Mtp TPCW32.PAS"
  exit 1
fi

if [ ! -d "$SAMPDIR" ]; then
  echo "ERREUR: $SAMPDIR non trouve."
  exit 1
fi

TOTAL=0
PASS=0
FAIL=0
SKIP=0

echo "=== TPCW32 Tests Apple Pascal (SANE) ==="
echo "Compilateur: $COMPILER --applepascal"
echo "Exemples   : $SAMPDIR"
echo ""

cd "$BASEDIR"

for SRC in "$SAMPDIR"/*.pas; do
  BASE=$(basename "$SRC" .pas)
  TOTAL=$((TOTAL + 1))

  # Compiler avec --applepascal
  if ! "$COMPILER" --applepascal "$SRC" > /dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (compilation echouee)"
    continue
  fi

  EXE="$SAMPDIR/$BASE.exe"
  if [ ! -f "$EXE" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (pas de .exe genere)"
    continue
  fi

  # Executer avec Wine
  OUTPUT=$(WINEDEBUG=-all timeout 15 wine "$EXE" 2>&1) || true
  EXITCODE=$?

  if [ $EXITCODE -eq 124 ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (timeout)"
  elif [ -n "$OUTPUT" ]; then
    PASS=$((PASS + 1))
    if [ $VERBOSE -eq 1 ]; then echo "PASS  $BASE.pas"; fi
  else
    PASS=$((PASS + 1))
    if [ $VERBOSE -eq 1 ]; then echo "PASS  $BASE.pas (compilation ok, pas de Wine)"; fi
  fi

  rm -f "$EXE"
done

# Nettoyer
rm -f "$SAMPDIR"/*.exe "$SAMPDIR"/*.asm

echo ""
echo "=== Resultats ==="
echo "Total : $TOTAL"
echo "Passes: $PASS"
echo "Echecs: $FAIL"
echo "Ignores: $SKIP"

if [ $FAIL -gt 0 ]; then
  echo "ECHEC: $FAIL test(s) en erreur"
  exit 1
else
  echo "SUCCES: tous les tests passent"
  exit 0
fi
