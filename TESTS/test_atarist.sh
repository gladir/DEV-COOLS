#!/bin/bash
# =============================================================================
# test_atarist.sh - Tests de regression pour TPCW32 cible Atari ST (-CATARIST)
# =============================================================================
# Usage: bash TESTS/test_atarist.sh [--verbose]
# Compile chaque fichier .pas dans SAMPLES/ATARIST/ avec -CATARIST
# et verifie que le fichier .PRG genere est un executable Atari ST valide.
# Note: pas d execution (pas d emulateur Atari ST), seulement validation
# de la compilation et du format binaire.
# =============================================================================

set -e

VERBOSE=0
if [ "$1" = "--verbose" ]; then VERBOSE=1; fi

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="$BASEDIR/TPCW32"
SAMPDIR="$BASEDIR/SAMPLES/ATARIST"

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

echo "=== TPCW32 Tests Atari ST (-CATARIST) ==="
echo "Compilateur: $COMPILER -CATARIST"
echo "Exemples   : $SAMPDIR"
echo ""

cd "$BASEDIR"

for SRC in "$SAMPDIR"/*.pas; do
  BASE=$(basename "$SRC" .pas)
  TOTAL=$((TOTAL + 1))

  # Compiler avec -CATARIST
  if ! "$COMPILER" -CATARIST "$SRC" > /dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (compilation echouee)"
    continue
  fi

  PRG="$SAMPDIR/$BASE.prg"
  if [ ! -f "$PRG" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (pas de .prg genere)"
    continue
  fi

  # Verifier le magic number $601A (en-tete PRG Atari ST)
  MAGIC=$(xxd -p -l 2 "$PRG")
  if [ "$MAGIC" != "601a" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (magic invalide: $MAGIC, attendu: 601a)"
    rm -f "$PRG"
    continue
  fi

  # Verifier la taille minimale (28 octets d en-tete + au moins du code)
  SIZE=$(stat -c %s "$PRG")
  if [ "$SIZE" -lt 30 ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (fichier trop petit: $SIZE octets)"
    rm -f "$PRG"
    continue
  fi

  PASS=$((PASS + 1))
  if [ $VERBOSE -eq 1 ]; then
    echo "PASS  $BASE.pas ($SIZE octets, magic OK)"
  fi

  rm -f "$PRG"
done

# Nettoyer
rm -f "$SAMPDIR"/*.prg "$SAMPDIR"/*.asm

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
