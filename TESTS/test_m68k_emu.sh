#!/bin/sh
# =============================================================================
# test_m68k_emu.sh - Tests de l'emulateur Motorola 68000 (M68K_EMU.PAS)
# =============================================================================
#
# Usage:
#   ./TESTS/test_m68k_emu.sh [--verbose]
#
# Ce script compile M68K_EMU.PAS et ASM68.PAS si necessaire, assemble les
# fichiers de test dans SAMPLES/ASM68/, puis execute les S-Records generes
# dans l'emulateur Pascal M68K_EMU pour verifier le fonctionnement.
#
# =============================================================================

VERBOSE=0
if [ "$1" = "--verbose" ] || [ "$1" = "-v" ]; then
  VERBOSE=1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ASM68_BIN="$REPO_DIR/ASM68"
EMU_BIN="$REPO_DIR/M68K_EMU"
SAMPLES_DIR="$REPO_DIR/SAMPLES/ASM68"

# Compiler ASM68 si le binaire n'existe pas
if [ ! -f "$ASM68_BIN" ]; then
  echo "Compilation de ASM68.PAS..."
  fpc -Mtp "$REPO_DIR/ASM68.PAS" -o"$ASM68_BIN" 2>&1 | tail -3
  if [ $? -ne 0 ]; then
    echo "ERREUR: Echec de la compilation de ASM68.PAS"
    exit 1
  fi
fi

# Compiler M68K_EMU si le binaire n'existe pas
if [ ! -f "$EMU_BIN" ]; then
  echo "Compilation de M68K_EMU.PAS..."
  fpc -Mtp "$REPO_DIR/M68K_EMU.PAS" -o"$EMU_BIN" 2>&1 | tail -3
  if [ $? -ne 0 ]; then
    echo "ERREUR: Echec de la compilation de M68K_EMU.PAS"
    exit 1
  fi
fi

PASS=0
FAIL=0
TOTAL=0

echo "=== Tests M68K_EMU - Emulateur Motorola 68000 (Pascal) ==="
echo ""

# Test 1 : Compilation
TOTAL=$((TOTAL + 1))
echo "  Test compilation M68K_EMU.PAS..."
if [ -f "$EMU_BIN" ]; then
  PASS=$((PASS + 1))
  echo "  OK   : M68K_EMU compile avec succes"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL : M68K_EMU ne compile pas"
fi

# Test 2 : Hello World
TOTAL=$((TOTAL + 1))
"$ASM68_BIN" "$SAMPLES_DIR/hello.asm" >/dev/null 2>&1
OUT=$("$EMU_BIN" "$SAMPLES_DIR/hello.S68" 2>&1)
EXIT=$?
if [ "$EXIT" -eq 0 ] && echo "$OUT" | grep -q "Hello, World!"; then
  PASS=$((PASS + 1))
  echo "  OK   : hello.asm -> 'Hello, World!'"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL : hello.asm (exit=$EXIT, output='$OUT')"
fi

# Tests executables (ont une terminaison TRAP #15 et sont concus pour
# l'execution dans l'emulateur)
EXEC_FILES="arith.asm bcd.asm branch.asm cond.asm expr.asm \
logic.asm move.asm shift.asm special.asm \
test_logic.asm test_shift.asm test_special.asm test_srecord.asm \
test_transfer.asm test_twopass.asm"

# Tests d'encodage (assemblage seul, pas concus pour l'execution :
# registres non initialises, division par zero intentionnelle, etc.)
ENCODE_ONLY="labels.asm test_arith.asm test_encode.asm \
test_listing.asm test_macro.asm"

for f in $EXEC_FILES; do
  TOTAL=$((TOTAL + 1))
  FULL_PATH="$SAMPLES_DIR/$f"
  S68_PATH="${FULL_PATH%.asm}.S68"

  if [ ! -f "$FULL_PATH" ]; then
    FAIL=$((FAIL + 1))
    echo "  ABSENT: $f"
    continue
  fi

  # Assembler
  ASM_OUT=$("$ASM68_BIN" "$FULL_PATH" 2>&1)
  ASM_EXIT=$?
  ASM_ERRORS=$(echo "$ASM_OUT" | grep "^Erreurs" | awk -F: '{print $2}' | tr -d ' ')

  if [ "$ASM_EXIT" -ne 0 ] || [ "$ASM_ERRORS" != "0" ]; then
    FAIL=$((FAIL + 1))
    echo "  FAIL : $f (assemblage: exit=$ASM_EXIT, erreurs=$ASM_ERRORS)"
    continue
  fi

  if [ ! -f "$S68_PATH" ]; then
    FAIL=$((FAIL + 1))
    echo "  FAIL : $f (pas de fichier S68 genere)"
    continue
  fi

  # Executer dans l'emulateur Pascal
  EMU_OUT=$("$EMU_BIN" "$S68_PATH" --max-cycles 200000 2>&1)
  EMU_EXIT=$?

  if [ "$EMU_EXIT" -eq 0 ]; then
    PASS=$((PASS + 1))
    if [ "$VERBOSE" -eq 1 ]; then
      echo "  OK   : $f (execution OK)"
    else
      echo "  OK   : $f"
    fi
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL : $f (execution: exit=$EMU_EXIT)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "$EMU_OUT" | head -3 | sed 's/^/         /'
    fi
  fi
done

echo ""
echo "--- Tests d'encodage (assemblage seul, pas d'execution) ---"
SKIP=0
for f in $ENCODE_ONLY; do
  TOTAL=$((TOTAL + 1))
  FULL_PATH="$SAMPLES_DIR/$f"

  if [ ! -f "$FULL_PATH" ]; then
    FAIL=$((FAIL + 1))
    echo "  ABSENT: $f"
    continue
  fi

  ASM_OUT=$("$ASM68_BIN" "$FULL_PATH" 2>&1)
  ASM_EXIT=$?
  ASM_ERRORS=$(echo "$ASM_OUT" | grep "^Erreurs" | awk -F: '{print $2}' | tr -d ' ')

  if [ "$ASM_EXIT" -eq 0 ] && [ "$ASM_ERRORS" = "0" ]; then
    SKIP=$((SKIP + 1))
    PASS=$((PASS + 1))
    echo "  SKIP : $f (assemblage OK, execution non applicable)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL : $f (assemblage: exit=$ASM_EXIT, erreurs=$ASM_ERRORS)"
  fi
done

echo ""
echo "=== Resultats: $PASS/$TOTAL OK ($SKIP assemblage seul), $FAIL echec(s) ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
