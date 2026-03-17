#!/bin/sh
# =============================================================================
# test_asm68.sh - Tests de validation de l'assembleur ASM68
# =============================================================================
#
# Usage:
#   ./TESTS/test_asm68.sh [--verbose]
#
# Ce script compile ASM68.PAS si necessaire, puis assemble tous les fichiers
# de test dans SAMPLES/ASM68/ et verifie qu'ils s'assemblent sans erreur.
#
# =============================================================================

VERBOSE=0
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
  VERBOSE=1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ASM68_BIN="$REPO_DIR/ASM68"

# Compiler ASM68 si le binaire n'existe pas
if [ ! -f "$ASM68_BIN" ]; then
  echo "Compilation de ASM68.PAS..."
  fpc -Mtp "$REPO_DIR/ASM68.PAS" -o"$ASM68_BIN" 2>&1 | tail -3
  if [ $? -ne 0 ]; then
    echo "ERREUR: Echec de la compilation de ASM68.PAS"
    exit 1
  fi
fi

SAMPLES_DIR="$REPO_DIR/SAMPLES/ASM68"
PASS=0
FAIL=0
TOTAL=0

echo "=== Tests ASM68 - Validation des fichiers assembleur 68000 ==="
echo ""

# Liste des fichiers de test (TODO 25 samples)
SAMPLE_FILES="hello.asm move.asm arith.asm logic.asm shift.asm branch.asm \
special.asm macro.asm cond.asm include.asm labels.asm expr.asm \
sections.asm listing.asm bcd.asm"

# Liste des fichiers test_*.asm supplementaires
TEST_FILES=$(cd "$SAMPLES_DIR" && ls test_*.asm 2>/dev/null || true)

echo "--- Fichiers sample (TODO 25) ---"
for f in $SAMPLE_FILES; do
  TOTAL=$((TOTAL + 1))
  FULL_PATH="$SAMPLES_DIR/$f"
  if [ ! -f "$FULL_PATH" ]; then
    echo "  ABSENT : $f"
    FAIL=$((FAIL + 1))
    continue
  fi

  OUTPUT=$("$ASM68_BIN" "$FULL_PATH" 2>&1)
  EXIT_CODE=$?
  ERRORS=$(echo "$OUTPUT" | grep "^Erreurs" | awk -F: '{print $2}' | tr -d ' ')
  INSTR=$(echo "$OUTPUT" | grep "^Instructions" | awk -F: '{print $2}' | tr -d ' ')
  CODE_SIZE=$(echo "$OUTPUT" | grep "^Taille code" | awk -F: '{print $2}' | tr -d ' ')
  SRECS=$(echo "$OUTPUT" | grep "^S-Records" | awk -F: '{print $2}' | awk '{print $1}')

  if [ "$EXIT_CODE" -eq 0 ] && [ "$ERRORS" = "0" ]; then
    PASS=$((PASS + 1))
    if [ "$VERBOSE" -eq 1 ]; then
      echo "  OK   : $f ($INSTR instr, $CODE_SIZE, $SRECS S1)"
    else
      echo "  OK   : $f"
    fi
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL : $f (exit=$EXIT_CODE, erreurs=$ERRORS)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "$OUTPUT" | grep -i "erreur" | head -5
    fi
  fi
done

echo ""
echo "--- Fichiers test supplementaires ---"
for f in $TEST_FILES; do
  TOTAL=$((TOTAL + 1))
  FULL_PATH="$SAMPLES_DIR/$f"

  OUTPUT=$("$ASM68_BIN" "$FULL_PATH" 2>&1)
  EXIT_CODE=$?
  ERRORS=$(echo "$OUTPUT" | grep "^Erreurs" | awk -F: '{print $2}' | tr -d ' ')
  INSTR=$(echo "$OUTPUT" | grep "^Instructions" | awk -F: '{print $2}' | tr -d ' ')
  CODE_SIZE=$(echo "$OUTPUT" | grep "^Taille code" | awk -F: '{print $2}' | tr -d ' ')

  if [ "$EXIT_CODE" -eq 0 ] && [ "$ERRORS" = "0" ]; then
    PASS=$((PASS + 1))
    if [ "$VERBOSE" -eq 1 ]; then
      echo "  OK   : $f ($INSTR instr, $CODE_SIZE)"
    else
      echo "  OK   : $f"
    fi
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL : $f (exit=$EXIT_CODE, erreurs=$ERRORS)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "$OUTPUT" | grep -i "erreur" | head -5
    fi
  fi
done

echo ""
echo "--- Verification des fichiers S-Record ---"
S68_COUNT=$(ls "$SAMPLES_DIR"/*.S68 2>/dev/null | wc -l)
echo "  Fichiers S68 generes : $S68_COUNT"

# Verifier le format S-Record de hello.asm
HELLO_S68="$SAMPLES_DIR/hello.S68"
if [ -f "$HELLO_S68" ]; then
  S0_OK=$(grep -c "^S0" "$HELLO_S68")
  S1_OK=$(grep -c "^S1" "$HELLO_S68")
  S5_OK=$(grep -c "^S5" "$HELLO_S68")
  S9_OK=$(grep -c "^S9" "$HELLO_S68")
  if [ "$S0_OK" -ge 1 ] && [ "$S1_OK" -ge 1 ] && [ "$S5_OK" -ge 1 ] && [ "$S9_OK" -ge 1 ]; then
    echo "  hello.S68 : format S-Record valide (S0=$S0_OK S1=$S1_OK S5=$S5_OK S9=$S9_OK)"
  else
    echo "  hello.S68 : format S-Record INVALIDE (S0=$S0_OK S1=$S1_OK S5=$S5_OK S9=$S9_OK)"
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
  fi
else
  echo "  hello.S68 : ABSENT"
fi

echo ""
echo "=== Resultats: $PASS/$TOTAL OK, $FAIL echec(s) ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
