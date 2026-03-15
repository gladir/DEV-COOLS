#!/bin/sh
# =============================================================================
# test_jasmin_jvm.sh - Test des fichiers .class generes par JASMIN.PAS
# =============================================================================
#
# Ce script :
#   1. Compile JASMIN.PAS avec Free Pascal
#   2. Assemble chaque fichier .j de SAMPLES/JASMIN/ en .class
#   3. Execute les .class avec la commande java d'Oracle/OpenJDK
#   4. Verifie que la sortie correspond aux valeurs attendues
#
# Usage:
#   ./TESTS/test_jasmin_jvm.sh
#
# Prerequis:
#   - fpc (Free Pascal Compiler)
#   - java (JDK/JRE 8+)
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SAMPLES_DIR="$REPO_DIR/SAMPLES/JASMIN"
WORKDIR="/tmp/jasmin_jvm_test_$$"
TIMEOUT_SEC=10

# Compteurs
TOTAL=0
PASS=0
FAIL=0
SKIP=0
FAIL_LIST=""

# Couleurs (si terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  NC='\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  NC=''
fi

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

mkdir -p "$WORKDIR"

# =====================================================================
#  Etape 1 : Compilation de JASMIN.PAS
# =====================================================================
echo "============================================================"
echo "  Test des fichiers .class generes par JASMIN.PAS"
echo "============================================================"
echo ""

if ! command -v fpc > /dev/null 2>&1; then
  echo "ERREUR: fpc (Free Pascal Compiler) non trouve."
  exit 1
fi

if ! command -v java > /dev/null 2>&1; then
  echo "ERREUR: java non trouve."
  exit 1
fi

echo "Compilation de JASMIN.PAS..."
fpc -Mtp "$REPO_DIR/JASMIN.PAS" -o"$WORKDIR/jasmin" > "$WORKDIR/fpc.log" 2>&1
if [ $? -ne 0 ]; then
  echo "ERREUR: Echec de la compilation de JASMIN.PAS"
  cat "$WORKDIR/fpc.log"
  exit 1
fi
echo "  OK: JASMIN compile"
echo ""

JASMIN_BIN="$WORKDIR/jasmin"

echo "Java: $(java -version 2>&1 | head -1)"
echo ""

# =====================================================================
#  Etape 2 : Test d'assemblage et d'execution
# =====================================================================

# Fonction utilitaire : tester un fichier .j
# Arguments: $1 = fichier .j, $2 = sortie attendue (premiere ligne), $3 = "full" pour verifier toute la sortie
test_jfile() {
  jfile="$1"
  expected_first="$2"
  expected_full="$3"
  base=$(basename "$jfile" .j)
  TOTAL=$((TOTAL + 1))

  # Trouver le nom de la classe
  classname=$(grep '^\.class' "$jfile" | head -1 | awk '{print $NF}')
  if [ -z "$classname" ]; then
    classname="$base"
  fi

  # Assembler
  cd "$WORKDIR"
  rm -f *.class
  "$JASMIN_BIN" "$jfile" > "$WORKDIR/asm_${base}.log" 2>&1
  asm_rc=$?

  if [ $asm_rc -ne 0 ] || [ ! -f "${classname}.class" ]; then
    FAIL=$((FAIL + 1))
    FAIL_LIST="$FAIL_LIST  ${base}.j : echec assemblage\n"
    printf "  ${RED}FAIL${NC} [%-25s] echec assemblage\n" "${base}.j"
    return
  fi

  # Verifier si la classe a une methode main
  has_main=$(grep -c '^\.method public static main' "$jfile" || true)

  if [ "$has_main" -eq 0 ]; then
    # Pas de main, verifier avec javap
    javap -c "$classname" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      PASS=$((PASS + 1))
      printf "  ${GREEN}OK${NC}   [%-25s] class=%s (pas de main, javap ok)\n" "${base}.j" "$classname"
    else
      FAIL=$((FAIL + 1))
      FAIL_LIST="$FAIL_LIST  ${base}.j : javap echoue\n"
      printf "  ${RED}FAIL${NC} [%-25s] javap echoue\n" "${base}.j"
    fi
    return
  fi

  # Executer
  output=$(timeout "$TIMEOUT_SEC" java -cp "$WORKDIR" "$classname" < /dev/null 2>&1)
  run_rc=$?

  if [ $run_rc -eq 124 ]; then
    FAIL=$((FAIL + 1))
    FAIL_LIST="$FAIL_LIST  ${base}.j : timeout (>${TIMEOUT_SEC}s)\n"
    printf "  ${RED}FAIL${NC} [%-25s] timeout\n" "${base}.j"
    return
  fi

  if [ $run_rc -ne 0 ]; then
    error_head=$(echo "$output" | head -1)
    FAIL=$((FAIL + 1))
    FAIL_LIST="$FAIL_LIST  ${base}.j : erreur execution ($error_head)\n"
    printf "  ${RED}FAIL${NC} [%-25s] erreur: %s\n" "${base}.j" "$error_head"
    return
  fi

  # Verifier la sortie attendue
  if [ -n "$expected_first" ]; then
    actual_first=$(echo "$output" | head -1)
    if [ "$actual_first" != "$expected_first" ]; then
      FAIL=$((FAIL + 1))
      FAIL_LIST="$FAIL_LIST  ${base}.j : sortie inattendue (attendu: '$expected_first', obtenu: '$actual_first')\n"
      printf "  ${RED}FAIL${NC} [%-25s] sortie: '%s' != '%s'\n" "${base}.j" "$actual_first" "$expected_first"
      return
    fi
  fi

  # Verifier la sortie complete si fournie
  if [ -n "$expected_full" ]; then
    if [ "$output" != "$expected_full" ]; then
      FAIL=$((FAIL + 1))
      FAIL_LIST="$FAIL_LIST  ${base}.j : sortie complete inattendue\n"
      printf "  ${RED}FAIL${NC} [%-25s] sortie complete differente\n" "${base}.j"
      return
    fi
  fi

  PASS=$((PASS + 1))
  first_out=$(echo "$output" | head -1)
  printf "  ${GREEN}OK${NC}   [%-25s] class=%s output=\"%s\"\n" "${base}.j" "$classname" "$first_out"
}

echo "--- Tests d'assemblage et d'execution JVM ---"
echo ""

# Hello.j
test_jfile "$SAMPLES_DIR/Hello.j" "Hello, World!"

# test01 - Hello basique
test_jfile "$SAMPLES_DIR/test01_hello.j" "Bonjour depuis Jasmin!"

# test02 - Variables
test_jfile "$SAMPLES_DIR/test02_variables.j" "142"

# test03 - Arithmetique
test_jfile "$SAMPLES_DIR/test03_arith.j" "26"

# test04 - Conditions
test_jfile "$SAMPLES_DIR/test04_cond.j" "x >= 5"

# test05 - Boucles
test_jfile "$SAMPLES_DIR/test05_loop.j" "0"

# test06 - Methodes
test_jfile "$SAMPLES_DIR/test06_method.j" "10"

# test07 - Champs
test_jfile "$SAMPLES_DIR/test07_field.j" "42"

# test08 - Tableaux
test_jfile "$SAMPLES_DIR/test08_array.j" "5"

# test09 - Exceptions
test_jfile "$SAMPLES_DIR/test09_except.j" "Exception attrapee : Erreur de test"

# test10 - Pile
test_jfile "$SAMPLES_DIR/test10_stack.j" "42"

# test11 - Declaration de methodes
test_jfile "$SAMPLES_DIR/test11_method_decl.j" "Bonjour"

# test12 - Descripteurs de types
test_jfile "$SAMPLES_DIR/test12_descriptors.j" ""

# test13 - Load/Store
test_jfile "$SAMPLES_DIR/test13_loadstore.j" ""

# test14 - Arithmetique/logique
test_jfile "$SAMPLES_DIR/test14_arithlogic.j" ""

# test15 - Conversions
test_jfile "$SAMPLES_DIR/test15_conversion.j" ""

# test16 - Controle de flux
test_jfile "$SAMPLES_DIR/test16_controlflow.j" ""

# test17 - Invocations
test_jfile "$SAMPLES_DIR/test17_invoke.j" ""

# test18 - Pile et constantes
test_jfile "$SAMPLES_DIR/test18_stackconst.j" ""

# test19 - Objets et tableaux
test_jfile "$SAMPLES_DIR/test19_objarray.j" ""

# test20 - Acces aux champs
test_jfile "$SAMPLES_DIR/test20_fieldaccess.j" ""

# test21 - Return/Compare/Misc
test_jfile "$SAMPLES_DIR/test21_retcmpmisc.j" ""

# test22 - Labels
test_jfile "$SAMPLES_DIR/test22_labels.j" ""

# test23 - Attribut Code
test_jfile "$SAMPLES_DIR/test23_codeattr.j" "Hello from voidWithLines"

# test24 - Exceptions avancees
test_jfile "$SAMPLES_DIR/test24_exceptions.j" "Caught: simple exception"

# test25 - Attributs supplementaires
test_jfile "$SAMPLES_DIR/test25_attributes.j" "This method is deprecated"

# test26 - Generation complete
EXPECTED_26="Bonjour
7
3
0
42
test26_classgen OK"
test_jfile "$SAMPLES_DIR/test26_classgen.j" "Bonjour" "$EXPECTED_26"

# test27 - Validation
test_jfile "$SAMPLES_DIR/test27_validation.j" "test27_validation OK"

# test28 - Exemples complets
test_jfile "$SAMPLES_DIR/test28_examples.j" "OK: add result matches"

# =====================================================================
#  Etape 3 : Bilan
# =====================================================================
echo ""
echo "============================================================"
echo "  RESULTATS"
echo "============================================================"
echo "  Total:       $TOTAL"
echo "  Succes:      $PASS"
echo "  Echecs:      $FAIL"
echo "  Taux:        $(( PASS * 100 / TOTAL ))%"
echo "============================================================"

if [ -n "$FAIL_LIST" ]; then
  echo ""
  echo "Fichiers en echec:"
  printf "$FAIL_LIST"
fi

if [ $FAIL -eq 0 ]; then
  echo ""
  echo "SUCCES: Tous les fichiers .class generes par JASMIN.PAS"
  echo "        fonctionnent correctement avec la commande java."
  exit 0
else
  echo ""
  echo "ECHEC: $FAIL fichier(s) en echec sur $TOTAL."
  exit 1
fi
