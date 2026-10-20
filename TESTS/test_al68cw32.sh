#!/bin/bash
# =============================================================================
# test_al68cw32.sh - Test du compilateur Algol 68 AL68CW32 (SAMPLES/ALGOL68)
# =============================================================================
#
# Usage:
#   ./TESTS/test_al68cw32.sh [--verbose]
#
# Compile AL68CW32.PAS (Free Pascal) puis, pour chacun des 27 exemples de
# SAMPLES/ALGOL68 :
#   1. compile en .EXE (mode par defaut), verifie qu'aucun .asm ni .obj n'est
#      cree, execute le programme et compare sa sortie a TESTS/AL68CW32/exp
#      (sorties calculees a la main, puis confrontees au compilateur)
#   2. compile avec -asm (.EXE + .ASM) et avec -obj (.OBJ seul), puis
#      -obj -asm (.OBJ + .ASM)
#   3. controle l'encodage binaire avec objdump (TESTS/AL68CW32/chkenc.py)
#      et, si lld-link est present, lie chaque .OBJ pour comparer sa sortie
#   4. pour les exemples sans sortie (declarations et expressions isolees),
#      ajoute un print de leurs variables (TESTS/AL68CW32/vars.py) et
#      compare aux valeurs calculees a la main (TESTS/AL68CW32/vars/*.vars)
#   5. lance les scripts de TESTS/AL68CW32 : chkerr.sh (programmes fautifs,
#      messages, code de retour, mutations), chkopt.sh (options et fichiers
#      produits), chkrt.sh (runtime : formats, lecture, erreurs
#      d'execution) et chkpe.sh (ecrivains PE et COFF)
#
# Execution des .EXE : Wine si disponible, sinon le chargeur PE minimal
# TESTS/AL60CW32/runpe.c (Linux x86-64, necessite gcc). Sans l'un des deux,
# les comparaisons de sortie sont ignorees (SKIP).
#
# test_closed.a68 ne se termine pas par construction (GOTO done apres
# l'etiquette done) : il est execute sous un delai, sans sortie attendue.
#
# Prerequis: fpc (Free Pascal) ; facultatifs : wine ou gcc, objdump, python3,
# lld-link + llvm-dlltool + llvm-mc
# =============================================================================

VERBOSE=0
[ "$1" = "--verbose" ] && VERBOSE=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/AL68CW32"
RUNPE_DIR="$SCRIPT_DIR/AL60CW32"
SAMPLES_DIR="$REPO_DIR/SAMPLES/ALGOL68"
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
AL68="$WORK/AL68CW32"
echo "Compilation de AL68CW32.PAS..."
if ! fpc -Mtp -FE"$WORK" -FU"$WORK" "$REPO_DIR/AL68CW32.PAS" >"$WORK/fpc.log" 2>&1; then
  tail -5 "$WORK/fpc.log"
  echo "ERREUR: echec de la compilation de AL68CW32.PAS"
  exit 1
fi

# --- Executeur des .EXE ------------------------------------------------------
RUNNER=""
RUNNER_CMD=""
if command -v wine >/dev/null 2>&1; then
  RUNNER="wine"
  RUNNER_CMD="wine"
elif [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ] &&
     command -v gcc >/dev/null 2>&1; then
  if gcc -O1 -o "$WORK/runpe" "$RUNPE_DIR/runpe.c" 2>/dev/null; then
    cp "$RUNPE_DIR/stubs.bin" "$WORK/stubs.bin"
    RUNNER="runpe"
    RUNNER_CMD="$WORK/runpe"
  fi
fi

# run_exe prog.exe sortie : stdout (sans CR) dans "sortie" ; code de retour
run_exe() {
  if [ "$RUNNER" = "wine" ]; then
    WINEDEBUG=-all timeout 15 wine "$1" </dev/null 2>/dev/null >"$2.raw"
  else
    timeout 10 "$WORK/runpe" "$1" </dev/null 2>/dev/null >"$2.raw"
  fi
  local rc=$?
  tr -d '\r' <"$2.raw" >"$2"
  return $rc
}

# check_run nom exe : execute et compare a l'exp (rc 0, sortie identique) ;
# test_closed ne se termine pas : delai (code 124) accepte
check_run() {
  local name="$1" exe="$2" exp="$DATA_DIR/exp/$1.exp" rc
  run_exe "$exe" "$name.out"
  rc=$?
  if [ "$name" = "test_closed" ] && [ $rc -eq 124 ]; then rc=0; fi
  if [ $rc -eq 0 ] && diff -q "$name.out" "$exp" >/dev/null 2>&1; then
    return 0
  fi
  [ $VERBOSE -eq 1 ] && { echo "  rc=$rc"; diff "$name.out" "$exp" | head -5; }
  return 1
}

HAVE_OBJDUMP=""
HAVE_PYTHON=""
HAVE_LLD=""
command -v objdump >/dev/null 2>&1 && HAVE_OBJDUMP=1
command -v python3 >/dev/null 2>&1 && HAVE_PYTHON=1
if command -v lld-link >/dev/null 2>&1 && command -v llvm-dlltool >/dev/null 2>&1 &&
   command -v llvm-mc >/dev/null 2>&1; then
  HAVE_LLD=1
fi

# Bibliotheque d'import et alias kernel32 pour lld-link (stdcall decore)
LK="$WORK/lk"
if [ -n "$HAVE_LLD" ] && [ -n "$RUNNER" ]; then
  mkdir -p "$LK"
  {
    echo "LIBRARY kernel32.dll"
    echo "EXPORTS"
    echo "GetStdHandle@4"; echo "WriteFile@20"; echo "ReadFile@20"
    echo "ExitProcess@4"; echo "GetProcessHeap@0"; echo "HeapAlloc@12"
    echo "HeapFree@12"
  } >"$LK/k32.def"
  {
    echo ".intel_syntax noprefix"; echo ".text"
    for F in GetStdHandle:4 WriteFile:20 ReadFile:20 ExitProcess:4 \
             GetProcessHeap:0 HeapAlloc:12 HeapFree:12; do
      echo ".globl ${F%%:*}"; echo "${F%%:*}: jmp _${F%%:*}@${F##*:}"
    done
  } >"$LK/alias.s"
  if ! (llvm-dlltool -m i386 -d "$LK/k32.def" -l "$LK/k32.lib" &&
        llvm-mc -triple=i686-pc-windows-msvc -filetype=obj "$LK/alias.s" \
                -o "$LK/alias.obj") >/dev/null 2>&1; then
    HAVE_LLD=""
  fi
else
  HAVE_LLD=""
fi

echo "============================================================"
echo "  Test AL68CW32 - Compilateur Algol 68 vers Win32 PE / COFF"
echo "============================================================"
echo "  Executeur : ${RUNNER:-aucun (comparaisons de sortie ignorees)}"
if [ -n "$HAVE_OBJDUMP" ]; then echo "  objdump   : oui"; else echo "  objdump   : non (controles .obj et encodage ignores)"; fi
if [ -n "$HAVE_PYTHON" ]; then echo "  python3   : oui"; else echo "  python3   : non (encodage, valeurs et mutations ignores)"; fi
if [ -n "$HAVE_LLD" ]; then echo "  lld-link  : oui"; else echo "  lld-link  : non (edition de liens des .obj ignoree)"; fi
echo "  Exemples  : $SAMPLES_DIR"
echo "============================================================"

# --- 1 a 3 : exemples ----------------------------------------------------------
for SRC in "$SAMPLES_DIR"/*.a68; do
  NAME="$(basename "$SRC" .a68)"
  D="$WORK/$NAME"
  mkdir -p "$D"
  cp "$SRC" "$D/$NAME.a68"
  cd "$D" || exit 1

  # mode par defaut : .EXE seul
  "$AL68" "$NAME.a68" >"$NAME.log" 2>&1
  if [ $? -ne 0 ] || [ ! -f "$NAME.exe" ]; then
    bad "$NAME (compilation .exe)"
    continue
  fi
  if [ -e "$NAME.asm" ] || [ -e "$NAME.obj" ]; then
    bad "$NAME (fichier .asm ou .obj cree sans option)"
  else
    ok "$NAME defaut: .exe seul"
  fi

  # execution et comparaison
  if [ -n "$RUNNER" ]; then
    if check_run "$NAME" "$NAME.exe"; then ok "$NAME sortie"; else bad "$NAME (sortie differente)"; fi
  else
    skip "$NAME sortie"
  fi

  # -asm : .exe + .asm
  rm -f "$NAME.exe"
  "$AL68" -asm "$NAME.a68" >/dev/null 2>&1
  if [ -f "$NAME.exe" ] && [ -f "$NAME.asm" ] && [ ! -e "$NAME.obj" ]; then
    ok "$NAME -asm"
  else
    bad "$NAME (-asm)"
  fi

  # -obj : .obj seul
  rm -f "$NAME.exe" "$NAME.asm"
  "$AL68" -obj "$NAME.a68" >/dev/null 2>&1
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

  # .obj lie avec lld-link : meme comportement que le .exe direct
  if [ -n "$HAVE_LLD" ]; then
    if lld-link /entry:A68P_Main /subsystem:console /machine:x86 /nodefaultlib \
         /safeseh:no /base:0x400000 /fixed /out:"$NAME.lk.exe" "$NAME.obj" \
         "$LK/alias.obj" "$LK/k32.lib" >"$NAME.lk.log" 2>&1 &&
       check_run "$NAME" "$NAME.lk.exe"; then
      ok "$NAME .obj lie (lld-link)"
    else
      bad "$NAME (.obj lie)"
    fi
  else
    skip "$NAME .obj lie (lld-link absent)"
  fi

  # -obj -asm : .obj + .asm
  rm -f "$NAME.obj"
  "$AL68" -obj -asm "$NAME.a68" >/dev/null 2>&1
  if [ -f "$NAME.obj" ] && [ -f "$NAME.asm" ] && [ ! -e "$NAME.exe" ]; then
    ok "$NAME -obj -asm"
  else
    bad "$NAME (-obj -asm)"
  fi
  # le listing doit contenir le runtime utilise (autonome)
  if grep -q '_A68RT_' "$NAME.asm" && ! grep -q 'EXTERN _A68RT_' "$NAME.asm"; then
    ok "$NAME listing autonome"
  elif ! grep -q '_A68RT_' "$NAME.asm"; then
    ok "$NAME listing sans runtime"
  else
    bad "$NAME (listing non autonome)"
  fi

  # encodage binaire verifie par objdump
  if [ -n "$HAVE_OBJDUMP" ] && [ -n "$HAVE_PYTHON" ]; then
    "$AL68" -d "$NAME.a68" -o "$D/enc.exe" >/dev/null 2>&1
    if python3 "$DATA_DIR/chkenc.py" "$D/enc.lst" 2>&1 | tail -1 | grep -q " 0 ecart"; then
      ok "$NAME encodage"
    else
      bad "$NAME (encodage)"
    fi
  else
    skip "$NAME encodage (objdump ou python3 absent)"
  fi
done

# --- 4 : valeurs calculees a la main des exemples sans sortie -----------------
echo ""
echo "Valeurs des exemples sans sortie..."
V="$WORK/vars"
mkdir -p "$V"
cd "$V" || exit 1
for VF in "$DATA_DIR"/vars/*.vars; do
  NAME="$(basename "$VF" .vars)"
  if [ -z "$RUNNER" ] || [ -z "$HAVE_PYTHON" ]; then
    skip "$NAME valeurs (executeur ou python3 absent)"
    continue
  fi
  python3 "$DATA_DIR/vars.py" "$SAMPLES_DIR/$NAME.a68" "$VF" "$NAME.a68"
  "$AL68" "$NAME.a68" >"$NAME.log" 2>&1
  if [ $? -ne 0 ] || [ ! -f "$NAME.exe" ]; then
    bad "$NAME valeurs (compilation)"
    continue
  fi
  run_exe "$NAME.exe" "$NAME.out"
  rc=$?
  grep -v '^#' "$VF" >"$NAME.want"
  if [ $rc -eq 0 ] && diff -q "$NAME.out" "$NAME.want" >/dev/null 2>&1; then
    ok "$NAME valeurs"
  else
    bad "$NAME valeurs (rc=$rc)"
    [ $VERBOSE -eq 1 ] && diff "$NAME.out" "$NAME.want" | head -5
  fi
done

# --- 5 : scripts de TESTS/AL68CW32 ---------------------------------------------
echo ""
echo "Erreurs, options, runtime et ecrivains PE / COFF..."
cd "$WORK" || exit 1
run_sub() {   # description script [variables]
  local desc="$1" script="$2"
  if bash "$script" "$AL68" >"$WORK/sub.log" 2>&1; then
    ok "$desc"
  else
    bad "$desc"
    [ $VERBOSE -eq 1 ] && cat "$WORK/sub.log"
  fi
}
if [ -n "$HAVE_PYTHON" ]; then
  run_sub "programmes fautifs et mutations (chkerr.sh)" "$DATA_DIR/chkerr.sh"
else
  skip "programmes fautifs (python3 absent)"
fi
run_sub "options et fichiers produits (chkopt.sh)" "$DATA_DIR/chkopt.sh"
if [ -n "$RUNNER" ]; then
  export RUNNER="$RUNNER_CMD"
  run_sub "runtime embarque (chkrt.sh)" "$DATA_DIR/chkrt.sh"
  run_sub "ecrivains PE et COFF (chkpe.sh)" "$DATA_DIR/chkpe.sh"
  unset RUNNER
else
  skip "runtime embarque (aucun executeur)"
  skip "ecrivains PE et COFF (aucun executeur)"
fi
if [ -n "$HAVE_OBJDUMP" ] && [ -n "$HAVE_PYTHON" ]; then
  run_sub "encodage de tous les exemples (chkall.sh)" "$DATA_DIR/chkall.sh"
else
  skip "encodage (objdump ou python3 absent)"
fi

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
