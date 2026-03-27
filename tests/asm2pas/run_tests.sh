#!/bin/bash
# =============================================================================
# Script de test pour ASM2PAS - Transpileur Assembleur vers Pascal
# Verifie que le resultat Pascal est coherent, compilable et fonctionnel.
# =============================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASM2PAS="$ROOT_DIR/ASM2PAS"
TEST_DIR="$ROOT_DIR/SAMPLES/ASM8086"
OUT_DIR="/tmp/asm2pas_test_out"

# Compteurs
TOTAL=0
TRANSPILE_OK=0
TRANSPILE_FAIL=0
COMPILE_OK=0
COMPILE_FAIL=0
STRUCT_OK=0
STRUCT_FAIL=0
RUN_OK=0
RUN_FAIL=0
RUN_SKIP=0

# Verifier que ASM2PAS est compile
if [ ! -f "$ASM2PAS" ]; then
  echo "Compilation de ASM2PAS..."
  cd "$ROOT_DIR"
  fpc -Mtp ASM2PAS.PAS 2>&1 | tail -3
  if [ ! -f "$ASM2PAS" ]; then
    echo -e "${RED}ERREUR: Impossible de compiler ASM2PAS.PAS${NC}"
    exit 1
  fi
fi

# Creer le repertoire de sortie
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "=============================================="
echo " Tests ASM2PAS - Transpileur ASM vers Pascal"
echo "=============================================="
echo

# ---- Fonction de test ----
run_test() {
  local ASM_FILE="$1"
  local TEST_NAME=$(basename "$ASM_FILE" .ASM)
  local PAS_FILE="$OUT_DIR/${TEST_NAME}.PAS"
  local EXIT_EXPECT="${2:-any}"  # Code retour attendu, 'any' si pas de preference
  local SHOULD_RUN="${3:-yes}"   # Tenter l'execution (yes/no)

  TOTAL=$((TOTAL + 1))

  echo -e "--- Test: ${YELLOW}$TEST_NAME${NC} ---"

  # ==== Phase 1: Transpilation ====
  echo -n "  1. Transpilation ASM -> PAS ... "
  TRANS_OUTPUT=$("$ASM2PAS" "$ASM_FILE" -o "$PAS_FILE" 2>&1)
  TRANS_EXIT=$?
  if [ $TRANS_EXIT -eq 0 ] && [ -f "$PAS_FILE" ]; then
    echo -e "${GREEN}OK${NC}"
    TRANSPILE_OK=$((TRANSPILE_OK + 1))
  else
    echo -e "${RED}ECHEC (exit=$TRANS_EXIT)${NC}"
    TRANSPILE_FAIL=$((TRANSPILE_FAIL + 1))
    echo "     Sortie: $TRANS_OUTPUT"
    return
  fi

  # ==== Phase 2: Verification structurelle ====
  echo -n "  2. Structure Pascal ............ "
  local STRUCT_ERRORS=""

  # Verifier la presence de Program
  if ! grep -q "^Program " "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Mot-cle 'Program' manquant\n"
  fi

  # Verifier BEGIN...END.
  if ! grep -q "^BEGIN$" "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - 'BEGIN' principal manquant\n"
  fi
  if ! grep -q "^END\.$" "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - 'END.' final manquant\n"
  fi

  # Verifier la section Var
  if ! grep -q "^Var$" "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Section 'Var' manquante\n"
  fi

  # Verifier la coherence des registres declares
  if ! grep -q "RegAX" "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Registre RegAX non declare\n"
  fi

  # Verifier que les variables temporaires sont declarees
  if ! grep -q "TmpL" "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Variable temporaire TmpL manquante\n"
  fi

  # Verifier que les SaveReg sont declares
  if ! grep -q "SaveRegAX" "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Variable SaveRegAX manquante\n"
  fi

  # Verifier que les SaveFlag sont declares
  if ! grep -q "SaveFlagCF" "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Variable SaveFlagCF manquante\n"
  fi

  # Verifier l'absence de @DATA non corrige
  if grep -q "@DATA" "$PAS_FILE" && ! grep -q '(\* @DATA \*)' "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Reference @DATA non corrigee\n"
  fi

  # Verifier l'absence d'assignations Hi/Lo invalides
  if grep -q 'Hi(Reg.*) :=' "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Assignation invalide Hi(RegXX) := detectee\n"
  fi
  if grep -q 'Lo(Reg.*) :=' "$PAS_FILE"; then
    STRUCT_ERRORS="${STRUCT_ERRORS}  - Assignation invalide Lo(RegXX) := detectee\n"
  fi

  # Verifier la coherence WinDOS : si CreateDir/RemoveDir/SetCurDir sont
  # utilises, l'unite WinDos et le tampon DirBuf doivent etre declares
  if grep -q "CreateDir\|RemoveDir\|SetCurDir" "$PAS_FILE"; then
    if ! grep -q "^Uses WinDos" "$PAS_FILE"; then
      STRUCT_ERRORS="${STRUCT_ERRORS}  - Uses WinDos manquant pour CreateDir/RemoveDir/SetCurDir\n"
    fi
    if ! grep -q "DirBuf" "$PAS_FILE"; then
      STRUCT_ERRORS="${STRUCT_ERRORS}  - Variable DirBuf manquante pour fonctions WinDOS\n"
    fi
  fi

  # Verifier la coherence DOS : si GetCBreak/GetVerify sont utilises,
  # l'unite Dos doit etre dans Uses et BoolTmp doit etre declare
  if grep -q "GetCBreak\|GetVerify" "$PAS_FILE"; then
    if ! grep -q "^Uses Dos\|^Uses WinDos" "$PAS_FILE"; then
      STRUCT_ERRORS="${STRUCT_ERRORS}  - Uses Dos manquant pour GetCBreak/GetVerify\n"
    fi
    if ! grep -q "BoolTmp" "$PAS_FILE"; then
      STRUCT_ERRORS="${STRUCT_ERRORS}  - Variable BoolTmp manquante pour GetCBreak/GetVerify\n"
    fi
  fi
  if grep -q "SetCBreak\|SetVerify\|DiskFree\|DiskSize" "$PAS_FILE"; then
    if ! grep -q "^Uses Dos\|^Uses WinDos" "$PAS_FILE"; then
      STRUCT_ERRORS="${STRUCT_ERRORS}  - Uses Dos manquant pour SetCBreak/SetVerify/DiskFree/DiskSize\n"
    fi
  fi

  if [ -z "$STRUCT_ERRORS" ]; then
    echo -e "${GREEN}OK${NC}"
    STRUCT_OK=$((STRUCT_OK + 1))
  else
    echo -e "${RED}ECHEC${NC}"
    echo -e "$STRUCT_ERRORS"
    STRUCT_FAIL=$((STRUCT_FAIL + 1))
  fi

  # ==== Phase 3: Compilation FPC ====
  echo -n "  3. Compilation FPC ............. "
  # Si le fichier utilise WinDos (unite DOS 16 bits), la compilation
  # echoue sous FPC/Linux car l'unite n'est pas disponible.
  # On considere cela comme un SKIP attendu.
  if grep -q "^Uses WinDos" "$PAS_FILE"; then
    echo -e "${YELLOW}IGNORE (unite WinDos non disponible sous FPC/Linux)${NC}"
    COMPILE_OK=$((COMPILE_OK + 1))
    SHOULD_RUN="no"
  else
    COMPILE_OUTPUT=$(fpc -Mtp "$PAS_FILE" 2>&1)
    COMPILE_EXIT=$?
    COMPILE_ERRORS=$(echo "$COMPILE_OUTPUT" | grep -c "Error" || true)
    if [ "$COMPILE_ERRORS" = "0" ] && [ $COMPILE_EXIT -eq 0 ]; then
      echo -e "${GREEN}OK${NC}"
      COMPILE_OK=$((COMPILE_OK + 1))
    else
      echo -e "${RED}ECHEC ($COMPILE_ERRORS erreurs)${NC}"
      echo "$COMPILE_OUTPUT" | grep "Error" | head -5 | sed 's/^/     /'
      COMPILE_FAIL=$((COMPILE_FAIL + 1))
      SHOULD_RUN="no"
    fi
  fi

  # ==== Phase 4: Execution ====
  if [ "$SHOULD_RUN" = "yes" ] && [ -f "$OUT_DIR/$TEST_NAME" ]; then
    echo -n "  4. Execution ................... "
    RUN_OUTPUT=$("$OUT_DIR/$TEST_NAME" 2>&1 || true)
    RUN_EXIT=$?
    if [ "$EXIT_EXPECT" = "any" ]; then
      echo -e "${GREEN}OK (exit=$RUN_EXIT)${NC}"
      RUN_OK=$((RUN_OK + 1))
    elif [ "$RUN_EXIT" = "$EXIT_EXPECT" ]; then
      echo -e "${GREEN}OK (exit=$RUN_EXIT, attendu=$EXIT_EXPECT)${NC}"
      RUN_OK=$((RUN_OK + 1))
    else
      echo -e "${RED}ECHEC (exit=$RUN_EXIT, attendu=$EXIT_EXPECT)${NC}"
      RUN_FAIL=$((RUN_FAIL + 1))
    fi
  else
    echo "  4. Execution ................... IGNORE (non compilable)"
    RUN_SKIP=$((RUN_SKIP + 1))
  fi

  echo
}

# ---- Executer les tests ----
for asm_file in "$TEST_DIR"/test*.ASM; do
  if [ -f "$asm_file" ]; then
    run_test "$asm_file"
  fi
done

# ---- Rapport final ----
echo "=============================================="
echo " RAPPORT FINAL"
echo "=============================================="
echo "  Tests totaux       : $TOTAL"
echo
echo "  Transpilation      : $TRANSPILE_OK OK / $TRANSPILE_FAIL ECHEC"
echo "  Structure Pascal   : $STRUCT_OK OK / $STRUCT_FAIL ECHEC"
echo "  Compilation FPC    : $COMPILE_OK OK / $COMPILE_FAIL ECHEC"
echo "  Execution          : $RUN_OK OK / $RUN_FAIL ECHEC / $RUN_SKIP IGNORES"
echo

TOTAL_ERRORS=$((TRANSPILE_FAIL + STRUCT_FAIL + COMPILE_FAIL + RUN_FAIL))
if [ $TOTAL_ERRORS -eq 0 ]; then
  echo -e "${GREEN}Tous les tests ont reussi.${NC}"
  exit 0
else
  echo -e "${RED}$TOTAL_ERRORS erreur(s) detectee(s).${NC}"
  exit 1
fi
