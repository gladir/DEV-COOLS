#!/bin/sh
# =============================================================================
# test_asm68_run.sh - Tests d'execution du code genere par ASM68
# =============================================================================
#
# Usage:
#   ./TESTS/test_asm68_run.sh [--verbose]
#
# Ce script compile ASM68.PAS et M68K_EMU.PAS si necessaire, assemble les
# fichiers de test dans SAMPLES/ASM68/, puis execute les S-Records generes
# dans l'emulateur M68K_EMU (Pascal) pour verifier le code machine.
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
SKIP=0
TOTAL=0

echo "=== Tests ASM68 - Execution dans l'emulateur 68000 ==="
echo ""

# Fichiers executables (ont une terminaison TRAP #15 D0=9)
EXEC_FILES="hello.asm arith.asm bcd.asm branch.asm cond.asm expr.asm \
listing.asm logic.asm move.asm sections.asm shift.asm special.asm \
test_listing.asm test_logic.asm \
test_shift.asm test_special.asm test_srecord.asm \
test_transfer.asm test_twopass.asm"

# Fichiers assemblage seul (testent des fonctionnalites de l'assembleur,
# pas concus pour l'execution : registres non initialises, macros, etc.)
ASM_ONLY="test_advanced.asm test_branch.asm test_conditional.asm \
test_directives.asm test_parser.asm test_run.asm \
include.asm test_include.asm \
labels.asm macro.asm test_arith.asm test_encode.asm test_macro.asm"

echo "--- Fichiers executables (assemblage + execution) ---"
for f in $EXEC_FILES; do
  TOTAL=$((TOTAL + 1))
  FULL_PATH="$SAMPLES_DIR/$f"
  S68_PATH="${FULL_PATH%.asm}.S68"

  if [ ! -f "$FULL_PATH" ]; then
    echo "  ABSENT : $f"
    FAIL=$((FAIL + 1))
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
    ERR_MSG=$(echo "$EMU_OUT" | grep -E "^Erreur" | head -1)
    echo "  FAIL : $f (execution: $ERR_MSG)"
    if [ "$VERBOSE" -eq 1 ]; then
      echo "$EMU_OUT" | head -3 | sed 's/^/         /'
    fi
  fi
done

echo ""
echo "--- Fichiers assemblage seul (pas d'execution) ---"
for f in $ASM_ONLY; do
  TOTAL=$((TOTAL + 1))
  FULL_PATH="$SAMPLES_DIR/$f"

  if [ ! -f "$FULL_PATH" ]; then
    echo "  ABSENT : $f"
    FAIL=$((FAIL + 1))
    continue
  fi

  ASM_OUT=$("$ASM68_BIN" "$FULL_PATH" 2>&1)
  ASM_EXIT=$?
  ASM_ERRORS=$(echo "$ASM_OUT" | grep "^Erreurs" | awk -F: '{print $2}' | tr -d ' ')

  if [ "$ASM_EXIT" -eq 0 ] && [ "$ASM_ERRORS" = "0" ]; then
    SKIP=$((SKIP + 1))
    echo "  SKIP : $f (assemblage OK, execution non applicable)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL : $f (assemblage: exit=$ASM_EXIT, erreurs=$ASM_ERRORS)"
  fi
done

echo ""
echo "=== Resultats: $PASS/$TOTAL executes OK, $SKIP assembles seul, $FAIL echec(s) ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
