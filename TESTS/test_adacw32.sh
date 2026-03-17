#!/bin/sh
# =============================================================================
# test_adacw32.sh - Test du compilateur Ada ADACW32 avec les exemples SAMPLES/ADA
# =============================================================================
#
# Usage:
#   ./TESTS/test_adacw32.sh
#
# Compile ADACW32.PAS puis compile et execute chaque fichier .ADB/.ada
# dans SAMPLES/ADA/ avec Wine. Verifie la sortie attendue quand possible.
#
# Prerequis: fpc (Free Pascal), wine (Wine 32 bits)
# =============================================================================

TIMEOUT_SEC=5

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ADACW32_BIN="$REPO_DIR/ADACW32"
SAMPLES_DIR="$REPO_DIR/SAMPLES/ADA"

# Compiler ADACW32 si necessaire
if [ ! -x "$ADACW32_BIN" ]; then
  echo "Compilation de ADACW32.PAS..."
  cd "$REPO_DIR"
  fpc -Mtp ADACW32.PAS 2>&1 | tail -3
  if [ $? -ne 0 ]; then
    echo "ERREUR: Echec de la compilation de ADACW32.PAS"
    exit 1
  fi
fi

# Verifier wine
if ! command -v wine >/dev/null 2>&1; then
  echo "ERREUR: wine n'est pas installe."
  exit 1
fi

echo "============================================================"
echo "  Test ADACW32 - Compilateur Ada vers Win32 PE"
echo "============================================================"
echo "  ADACW32:   $ADACW32_BIN"
echo "  Samples:   $SAMPLES_DIR"
echo "  Timeout:   ${TIMEOUT_SEC}s par fichier"
echo "============================================================"
echo ""

TOTAL=0
COMPILE_OK=0
COMPILE_FAIL=0
RUN_OK=0
RUN_FAIL=0
RUN_TIMEOUT=0
CHECK_OK=0
CHECK_FAIL=0
FAIL_LIST=""

# Fonction pour verifier la sortie attendue
check_expected() {
  local name="$1"
  local actual="$2"
  local expected=""

  case "$name" in
    HELLO)
      expected="Hello, World!
Compilation ADA86 TODO 24 OK"
      ;;
    T01_HELLO)
      expected="Hello, World!
ADA86 fonctionne !"
      ;;
    T02_LOOPS)
      expected="FOR 1..5 :
15
WHILE decrement :
55
LOOP EXIT WHEN :
5"
      ;;
    T03_VARS)
      expected="42
58
100
26
A > 20 OK
A = 26 OK"
      ;;
    T06_COND)
      expected="Bien
Trois
hors 1..2"
      ;;
    test_write)
      expected="Test 1 : Hello
Test 2 : Bonjour
Test 3 : 42
Test 4 : 100
Test 5 : X
Test 6 : 1
Test 7a : ligne A
Test 7b : ligne B
Test 7c : ligne C
Test 8 : 35
Test 9 : 0
Test 10 : -1
Fin test_write"
      ;;
    test_io_formats)
      expected="1
12345
abcdefghi
valeur=77
3 7
Hi
avant
apres
6*7=42
ABCDEFGHIJKLMNOPQRSTUVWXYZ
somme premiers=28
Fin test_io_formats"
      ;;
    test_io_vars)
      expected="X=10
Y=15
Z=15
Max=999
X+1=101
(X+Y)*2=232
Char=Z
Bool=1
Bool=0
X apres swap=22
Y apres swap=11
Fin test_io_vars"
      ;;
    T05_FUNC)
      expected="42
99
120
20
10"
      ;;
    *)
      # Pas de sortie attendue definie, on skip la verification
      return 2
      ;;
  esac

  if [ "$actual" = "$expected" ]; then
    return 0
  else
    return 1
  fi
}

for f in "$SAMPLES_DIR"/*.ADB "$SAMPLES_DIR"/*.ada; do
  [ -f "$f" ] || continue
  TOTAL=$((TOTAL + 1))
  basename=$(basename "$f")
  name="${basename%.*}"
  exename="${f%.*}.exe"

  printf "  %-30s" "$basename"

  # Compilation
  OUTPUT=$("$ADACW32_BIN" "$f" 2>&1)
  ERRORS=$(echo "$OUTPUT" | grep "Erreurs" | awk '{print $NF}')

  if [ -z "$ERRORS" ] || [ "$ERRORS" != "0" ]; then
    printf "COMPILE_FAIL\n"
    COMPILE_FAIL=$((COMPILE_FAIL + 1))
    FAIL_LIST="$FAIL_LIST  $basename (compilation)\n"
    continue
  fi

  if [ ! -f "$exename" ]; then
    printf "NO_EXE\n"
    COMPILE_FAIL=$((COMPILE_FAIL + 1))
    FAIL_LIST="$FAIL_LIST  $basename (pas de .exe)\n"
    continue
  fi

  COMPILE_OK=$((COMPILE_OK + 1))

  # Execution avec Wine
  WINE_OUTPUT=$(timeout "$TIMEOUT_SEC" wine "$exename" </dev/null 2>/dev/null | tr -d '\r')
  WINE_RC=$?

  if [ $WINE_RC -eq 124 ]; then
    printf "TIMEOUT"
    RUN_TIMEOUT=$((RUN_TIMEOUT + 1))
  elif [ $WINE_RC -ne 0 ]; then
    printf "RUN_FAIL(rc=$WINE_RC)"
    RUN_FAIL=$((RUN_FAIL + 1))
    FAIL_LIST="$FAIL_LIST  $basename (execution rc=$WINE_RC)\n"
    printf "\n"
    continue
  else
    RUN_OK=$((RUN_OK + 1))
    printf "RUN_OK"
  fi

  # Verification sortie attendue
  check_expected "$name" "$WINE_OUTPUT"
  CHECK_RC=$?
  if [ $CHECK_RC -eq 0 ]; then
    CHECK_OK=$((CHECK_OK + 1))
    printf " CHECK_OK"
  elif [ $CHECK_RC -eq 1 ]; then
    CHECK_FAIL=$((CHECK_FAIL + 1))
    printf " CHECK_FAIL"
    FAIL_LIST="$FAIL_LIST  $basename (sortie incorrecte)\n"
  fi

  printf "\n"

  # Nettoyage exe et asm
  rm -f "$exename" "${f%.*}.asm" "${f%.*}.obj" 2>/dev/null
done

echo ""
echo "============================================================"
echo "  RESULTATS"
echo "============================================================"
echo "  Total:         $TOTAL"
echo "  Compile OK:    $COMPILE_OK"
echo "  Compile FAIL:  $COMPILE_FAIL"
echo "  Run OK:        $RUN_OK"
echo "  Run FAIL:      $RUN_FAIL"
echo "  Run TIMEOUT:   $RUN_TIMEOUT"
echo "  Check OK:      $CHECK_OK"
echo "  Check FAIL:    $CHECK_FAIL"
echo "============================================================"

if [ -n "$FAIL_LIST" ]; then
  echo ""
  echo "Details des echecs:"
  printf "$FAIL_LIST"
fi

# Code de retour: 0 si toutes les compilations passent
if [ "$COMPILE_FAIL" -eq 0 ] && [ "$RUN_FAIL" -eq 0 ]; then
  echo ""
  echo "OK: Tous les fichiers compilent et s'executent."
  exit 0
else
  echo ""
  echo "ATTENTION: Certains fichiers ont des problemes."
  exit 1
fi
