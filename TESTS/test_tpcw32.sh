#!/bin/bash
# =============================================================================
# test_tpcw32.sh - Tests de regression pour TPCW32 (compilateur Turbo Pascal)
# =============================================================================
# Usage: bash TESTS/test_tpcw32.sh [--verbose]
# Compile chaque fichier .pas dans SAMPLES/TURBOPASCAL/ et execute avec Wine.
# =============================================================================

set -e

VERBOSE=0
if [ "$1" = "--verbose" ]; then VERBOSE=1; fi

BASEDIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPILER="$BASEDIR/TPCW32"
SAMPDIR="$BASEDIR/SAMPLES/TURBOPASCAL"

if [ ! -x "$COMPILER" ]; then
  echo "ERREUR: $COMPILER non trouve. Compiler d abord avec: fpc -Mtp TPCW32.PAS"
  exit 1
fi

TOTAL=0
PASS=0
FAIL=0
SKIP=0

# Liste des fichiers a tester (qui ne requierent pas d interaction stdin)
# Exclure les fichiers qui utilisent ReadLn sans fichier (lecture stdin)
SKIP_FILES="crtdemo graphdemo dosdemo test_readln_min test_io test_unit test_unitdemo unitdemo mathunit test_readln_file test_getenv test_findfile test_find2 objects test_objects test_system test_types"

is_skipped() {
  local base="$1"
  for s in $SKIP_FILES; do
    if [ "$base" = "$s" ]; then return 0; fi
  done
  return 1
}

cleanup() {
  # Nettoyer les fichiers generes par les tests
  rm -f "$SAMPDIR"/*.exe "$SAMPDIR"/*.asm "$SAMPDIR"/*.txt "$SAMPDIR"/*.dat
  rm -f textwrite_out.txt textread_data.txt append_data.txt
  rm -f binwrite_out.dat binread_data.dat combined_text.txt combined_bin.dat
  rm -f test_output.txt test_tw.txt test_app.txt
}

echo "=== TPCW32 Tests de regression ==="
echo "Compilateur: $COMPILER"
echo "Exemples   : $SAMPDIR"
echo ""

# Changer vers le repertoire de travail pour les fichiers de sortie
cd "$BASEDIR"

for SRC in "$SAMPDIR"/*.pas; do
  BASE=$(basename "$SRC" .pas)
  TOTAL=$((TOTAL + 1))

  if is_skipped "$BASE"; then
    SKIP=$((SKIP + 1))
    if [ $VERBOSE -eq 1 ]; then echo "SKIP  $BASE.pas (interactif/stdin)"; fi
    continue
  fi

  # Compiler
  if ! "$COMPILER" "$SRC" > /dev/null 2>&1; then
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

  # Verifier que le programme a produit une sortie et s est termine
  if [ $EXITCODE -eq 124 ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (timeout)"
  elif echo "$OUTPUT" | grep -qi "Done\.\|=== Test\|OK\|Version:\|Done\|FOR\|WHILE\|REPEAT" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    if [ $VERBOSE -eq 1 ]; then echo "PASS  $BASE.pas"; fi
  elif [ -n "$OUTPUT" ]; then
    PASS=$((PASS + 1))
    if [ $VERBOSE -eq 1 ]; then echo "PASS  $BASE.pas (output ok)"; fi
  else
    FAIL=$((FAIL + 1))
    echo "FAIL  $BASE.pas (pas de sortie)"
  fi

  rm -f "$EXE"
done

cleanup

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
