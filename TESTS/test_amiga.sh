#!/bin/bash
# =============================================================================
# test_amiga.sh - Tests de regression pour TPCW32 cible Amiga (-CAMIGA)
# =============================================================================
# Usage: bash TESTS/test_amiga.sh [--verbose]
# Compile chaque fichier .pas dans SAMPLES/AMIGA/ avec -CAMIGA
# et verifie que le fichier genere est un executable Amiga Hunk valide.
# Note: pas d execution (pas d emulateur Amiga), seulement validation
# de la compilation et du format binaire.
# =============================================================================

set -e

VERBOSE=0
if [ "$1" = "--verbose" ]; then VERBOSE=1; fi

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="$BASEDIR/TPCW32"
SAMPDIR="$BASEDIR/SAMPLES/AMIGA"

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

echo "=== TPCW32 Tests Amiga (-CAMIGA) ==="
echo "Compilateur: $COMPILER -CAMIGA"
echo "Exemples   : $SAMPDIR"
echo ""

cd "$BASEDIR"

for SRC in "$SAMPDIR"/*.pas; do
  BASE=$(basename "$SRC" .pas)
  TOTAL=$((TOTAL + 1))

  # Compiler avec -CAMIGA
  if ! "$COMPILER" -CAMIGA "$SRC" > /dev/null 2>&1; then
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

  # Verifier le magic number $000003F3 (HUNK_HEADER)
  MAGIC=$(xxd -p -l 4 "$EXE")
  if [ "$MAGIC" != "000003f3" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (magic invalide: $MAGIC, attendu: 000003f3)"
    rm -f "$EXE"
    continue
  fi

  # Verifier la taille minimale (en-tete + au moins du code)
  SIZE=$(stat -c %s "$EXE")
  if [ "$SIZE" -lt 40 ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (fichier trop petit: $SIZE octets)"
    rm -f "$EXE"
    continue
  fi

  # Verifier que HUNK_CODE ($000003E9) est present dans le fichier
  if ! xxd -p "$EXE" | tr -d '\n' | grep -q '000003e9'; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (HUNK_CODE non trouve)"
    rm -f "$EXE"
    continue
  fi

  PASS=$((PASS + 1))
  if [ $VERBOSE -eq 1 ]; then
    echo "PASS  $BASE.pas ($SIZE octets, HUNK_HEADER OK)"
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
