#!/bin/bash
# =============================================================================
# test_al58cw32.sh - Test du compilateur Algol 58 AL58CW32 (SAMPLES/ALGOL58)
# =============================================================================
#
# Usage:
#   ./TESTS/test_al58cw32.sh [--verbose]
#
# Compile AL58CW32.PAS (Free Pascal) puis, pour chacun des 31 exemples de
# SAMPLES/ALGOL58 :
#   1. compile en .EXE (mode par defaut), verifie qu'aucun .asm ni .obj n'est
#      cree, execute le programme et compare sa sortie a TESTS/AL58CW32/exp
#   2. compile avec -asm (.EXE + .ASM) et avec -obj (.OBJ seul), puis
#      -obj -asm (.OBJ + .ASM)
#   3. controle l'encodage binaire avec objdump (TESTS/AL58CW32/chkenc.py)
#   4. verifie les messages et le code de retour sur des programmes fautifs
#
# Execution des .EXE : Wine si disponible, sinon le chargeur PE minimal
# TESTS/AL58CW32/runpe.c (Linux x86-64, necessite gcc). Sans l'un des deux,
# les comparaisons de sortie sont ignorees (SKIP).
#
# Prerequis: fpc (Free Pascal) ; facultatifs : wine ou gcc, objdump, python3
# =============================================================================

VERBOSE=0
[ "$1" = "--verbose" ] && VERBOSE=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/AL58CW32"
SAMPLES_DIR="$REPO_DIR/SAMPLES/ALGOL58"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
SKIP=0
FAIL_LIST=""

ok()   { PASS=$((PASS+1)); if [ $VERBOSE -eq 1 ]; then echo "  OK    $1"; fi; return 0; }
bad()  { FAIL=$((FAIL+1)); FAIL_LIST="$FAIL_LIST $1"; echo "  ECHEC $1"; }
skip() { SKIP=$((SKIP+1)); if [ $VERBOSE -eq 1 ]; then echo "  SKIP  $1"; fi; return 0; }

# --- Compilateur -------------------------------------------------------------
AL58="$WORK/AL58CW32"
echo "Compilation de AL58CW32.PAS..."
if ! fpc -Mtp -FE"$WORK" -FU"$WORK" "$REPO_DIR/AL58CW32.PAS" >"$WORK/fpc.log" 2>&1; then
  tail -5 "$WORK/fpc.log"
  echo "ERREUR: echec de la compilation de AL58CW32.PAS"
  exit 1
fi

# --- Executeur des .EXE ------------------------------------------------------
RUNNER=""
if command -v wine >/dev/null 2>&1; then
  RUNNER="wine"
elif [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ] &&
     command -v gcc >/dev/null 2>&1; then
  if gcc -O1 -o "$WORK/runpe" "$DATA_DIR/runpe.c" 2>/dev/null; then
    cp "$DATA_DIR/stubs.bin" "$WORK/stubs.bin"
    RUNNER="runpe"
  fi
fi

run_exe() {
  if [ "$RUNNER" = "wine" ]; then
    WINEDEBUG=-all timeout 15 wine "$1" </dev/null 2>/dev/null | tr -d '\r'
  else
    timeout 10 "$WORK/runpe" "$1" </dev/null 2>/dev/null | tr -d '\r'
  fi
}

HAVE_OBJDUMP=""
HAVE_PYTHON=""
command -v objdump >/dev/null 2>&1 && HAVE_OBJDUMP=1
command -v python3 >/dev/null 2>&1 && HAVE_PYTHON=1

echo "============================================================"
echo "  Test AL58CW32 - Compilateur Algol 58 vers Win32 PE / COFF"
echo "============================================================"
echo "  Executeur : ${RUNNER:-aucun (comparaisons de sortie ignorees)}"
if [ -n "$HAVE_OBJDUMP" ]; then echo "  objdump   : oui"; else echo "  objdump   : non (controles .obj et encodage ignores)"; fi
if [ -n "$HAVE_PYTHON" ]; then echo "  python3   : oui"; else echo "  python3   : non (controle de l encodage ignore)"; fi
echo "  Exemples  : $SAMPLES_DIR"
echo "============================================================"

# --- 1 a 3 : exemples ----------------------------------------------------------
for SRC in "$SAMPLES_DIR"/*.a58; do
  NAME="$(basename "$SRC" .a58)"
  D="$WORK/$NAME"
  mkdir -p "$D"
  cp "$SRC" "$D/$NAME.a58"
  cd "$D" || exit 1
  OPT=""
  # test_errors.a58 contient une variable non declaree : -w la signale
  [ "$NAME" = "test_errors" ] && OPT="-w"

  # mode par defaut : .EXE seul
  "$AL58" $OPT "$NAME.a58" >"$NAME.log" 2>&1
  if [ $? -ne 0 ] || [ ! -f "$NAME.exe" ]; then
    bad "$NAME (compilation .exe)"
    continue
  fi
  if [ -e "$NAME.asm" ] || [ -e "$NAME.obj" ]; then
    bad "$NAME (fichier .asm ou .obj cree sans option)"
  else
    ok "$NAME defaut: .exe seul"
  fi
  if [ "$NAME" = "test_errors" ]; then
    if grep -q "variable non declaree" "$NAME.log"; then
      ok "$NAME avertissement signale"
    else
      bad "$NAME (avertissement attendu)"
    fi
  fi

  # execution et comparaison
  if [ -n "$RUNNER" ]; then
    run_exe "$NAME.exe" >"$NAME.out"
    if diff -q "$NAME.out" "$DATA_DIR/exp/$NAME.exp" >/dev/null 2>&1; then
      ok "$NAME sortie"
    else
      bad "$NAME (sortie differente)"
      [ $VERBOSE -eq 1 ] && diff "$NAME.out" "$DATA_DIR/exp/$NAME.exp" | head -5
    fi
  else
    skip "$NAME sortie"
  fi

  # -asm : .exe + .asm
  rm -f "$NAME.exe"
  "$AL58" $OPT -asm "$NAME.a58" >/dev/null 2>&1
  if [ -f "$NAME.exe" ] && [ -f "$NAME.asm" ] && [ ! -e "$NAME.obj" ]; then
    ok "$NAME -asm"
  else
    bad "$NAME (-asm)"
  fi

  # -obj : .obj seul
  rm -f "$NAME.exe" "$NAME.asm"
  "$AL58" $OPT -obj "$NAME.a58" >/dev/null 2>&1
  if [ -f "$NAME.obj" ] && [ ! -e "$NAME.exe" ] && [ ! -e "$NAME.asm" ]; then
    ok "$NAME -obj"
  else
    bad "$NAME (-obj)"
  fi
  if [ -n "$HAVE_OBJDUMP" ]; then
    if objdump -h -t -r "$NAME.obj" >/dev/null 2>&1; then
      ok "$NAME .obj lisible (objdump)"
    else
      bad "$NAME (.obj illisible)"
    fi
  else
    skip "$NAME .obj lisible (objdump absent)"
  fi

  # -obj -asm : .obj + .asm
  rm -f "$NAME.obj"
  "$AL58" $OPT -obj -asm "$NAME.a58" >/dev/null 2>&1
  if [ -f "$NAME.obj" ] && [ -f "$NAME.asm" ] && [ ! -e "$NAME.exe" ]; then
    ok "$NAME -obj -asm"
  else
    bad "$NAME (-obj -asm)"
  fi

  # encodage binaire verifie par objdump
  if [ -n "$HAVE_OBJDUMP" ] && [ -n "$HAVE_PYTHON" ]; then
    "$AL58" $OPT -d "$NAME.a58" -o "$D/enc.exe" >/dev/null 2>&1
    if python3 "$DATA_DIR/chkenc.py" "$D/enc.lst" 2>&1 | tail -1 | grep -q " 0 ecart"; then
      ok "$NAME encodage"
    else
      bad "$NAME (encodage)"
    fi
  else
    skip "$NAME encodage (objdump ou python3 absent)"
  fi
done

# --- 4 : programmes fautifs --------------------------------------------------
echo ""
echo "Programmes fautifs..."
E="$WORK/err"
mkdir -p "$E"
cd "$E" || exit 1

check_error() {   # nom source motif
  printf '%s\n' "$2" >"$1.a58"
  "$AL58" "$1.a58" >"$1.log" 2>&1
  local rc=$?
  if [ $rc -eq 1 ] && grep -q "$3" "$1.log" && grep -q "Compilation echouee" "$1.log" &&
     [ ! -e "$1.exe" ] && [ ! -e "$1.obj" ] && [ ! -e "$1.asm" ]; then
    ok "erreur $1"
  else
    bad "erreur $1 (rc=$rc)"
    [ $VERBOSE -eq 1 ] && cat "$1.log"
  fi
}

check_error lexicale   'begin integer x; x := 3 @ 4 end'                  'caractere invalide'
check_error syntaxe    'begin integer x; x := (3 + 4; x := 2 end'         "')' attendu"
check_error virgule    'begin integer x x := 2 end'                       "';' ou 'end' attendu"
check_error fin        'begin integer x; x := 1;'                         "'end' attendu"
check_error doublon    'begin integer x; integer x; x := 1 end'           'declaration en double'
check_error etiquette  'begin integer x; goto nulle; x := 1 end'          'etiquette non definie'
check_error arguments  'begin integer procedure f(a); value a; integer a; f := a; integer x; x := f(1, 2) end' 'trop d.arguments'
check_error divzero    'begin integer x; x := 1 div 0 end'                'division par zero'

# plusieurs erreurs signalees en une compilation (recuperation)
printf 'begin integer x; if x > 1 then then x := 1; x := ; x := 2 end\n' >multi.a58
"$AL58" multi.a58 >multi.log 2>&1
if [ "$(grep -c ': erreur :' multi.log)" -ge 2 ]; then ok "erreurs multiples"; else bad "erreurs multiples"; fi

# avertissements : actifs avec -w, absents sans option
printf 'begin integer x; goto la; x := 1; la: x := 2; inutile: x := 3 end\n' >warn.a58
"$AL58" -w warn.a58 >warn.log 2>&1
rc=$?
if [ $rc -eq 0 ] && [ -f warn.exe ] && grep -q 'etiquette non utilisee' warn.log; then ok "avertissement -w"; else bad "avertissement -w"; fi
rm -f warn.exe
"$AL58" warn.a58 >warn.log 2>&1
rc=$?
if [ $rc -eq 0 ] && [ -f warn.exe ] && ! grep -q 'avertissement' warn.log; then ok "sans -w: aucun avertissement"; else bad "avertissement sans -w"; fi

# options
"$AL58" -h >help.log 2>&1
rc=$?
if [ $rc -eq 0 ] && grep -q 'Syntaxe: AL58CW32' help.log; then ok "-h"; else bad "-h"; fi
"$AL58" >noarg.log 2>&1
rc=$?
if [ $rc -eq 2 ] && grep -q 'Syntaxe: AL58CW32' noarg.log; then ok "sans argument: usage"; else bad "sans argument"; fi
"$AL58" introuvable.a58 >missing.log 2>&1
rc=$?
if [ $rc -eq 1 ] && grep -q 'introuvable' missing.log; then ok "source introuvable"; else bad "source introuvable"; fi

# --- Resultat ----------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Reussis: $PASS   Echecs: $FAIL   Ignores: $SKIP"
if [ $FAIL -gt 0 ]; then
  echo "  A revoir:$FAIL_LIST"
  echo "============================================================"
  exit 1
fi
echo "============================================================"
exit 0
