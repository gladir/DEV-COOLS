#!/bin/bash
# =============================================================================
# test_al60cw32.sh - Test du compilateur Algol 60 AL60CW32 (SAMPLES/ALGOL60)
# =============================================================================
#
# Usage:
#   ./TESTS/test_al60cw32.sh [--verbose]
#
# Compile AL60CW32.PAS (Free Pascal) puis, pour chacun des 33 exemples de
# SAMPLES/ALGOL60 :
#   1. compile en .EXE (mode par defaut), verifie qu'aucun .asm ni .obj n'est
#      cree, execute le programme et compare sa sortie a TESTS/AL60CW32/exp
#   2. compile avec -asm (.EXE + .ASM) et avec -obj (.OBJ seul), puis
#      -obj -asm (.OBJ + .ASM)
#   3. controle l'encodage binaire avec objdump (TESTS/AL60CW32/chkenc.py)
#      et, si lld-link est present, lie chaque .OBJ pour comparer sa sortie
#   4. verifie les messages et le code de retour sur des programmes fautifs,
#      les avertissements (-w), les erreurs d'execution et les options
#
# Execution des .EXE : Wine si disponible, sinon le chargeur PE minimal
# TESTS/AL60CW32/runpe.c (Linux x86-64, necessite gcc). Sans l'un des deux,
# les comparaisons de sortie sont ignorees (SKIP).
#
# test_switch.a60 ne se termine pas par construction : il est execute sous
# un delai et seul le debut de sa sortie est compare.
#
# Prerequis: fpc (Free Pascal) ; facultatifs : wine ou gcc, objdump, python3,
# lld-link + llvm-dlltool + llvm-mc
# =============================================================================

VERBOSE=0
[ "$1" = "--verbose" ] && VERBOSE=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$SCRIPT_DIR/AL60CW32"
SAMPLES_DIR="$REPO_DIR/SAMPLES/ALGOL60"
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
AL60="$WORK/AL60CW32"
echo "Compilation de AL60CW32.PAS..."
if ! fpc -Mtp -FE"$WORK" -FU"$WORK" "$REPO_DIR/AL60CW32.PAS" >"$WORK/fpc.log" 2>&1; then
  tail -5 "$WORK/fpc.log"
  echo "ERREUR: echec de la compilation de AL60CW32.PAS"
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

# run_head prog.exe sortie N : N premiers octets de la sortie d'un programme
# qui ne se termine pas (arrete par un delai)
run_head() {
  if [ "$RUNNER" = "wine" ]; then
    WINEDEBUG=-all timeout 2 wine "$1" </dev/null 2>/dev/null | head -c "$(($3 * 4))" >"$2.raw"
  else
    timeout 2 "$WORK/runpe" "$1" </dev/null 2>/dev/null | head -c "$(($3 * 4))" >"$2.raw"
  fi
  tr -d '\r' <"$2.raw" | head -c "$3" >"$2"
}

# check_run nom exe : execute et compare a l'exp (rc 0, sortie identique)
check_run() {
  local name="$1" exe="$2" exp="$DATA_DIR/exp/$1.exp" rc
  if [ "$name" = "test_switch" ]; then
    run_head "$exe" "$name.out" "$(wc -c <"$exp")"
    rc=0
  else
    run_exe "$exe" "$name.out"
    rc=$?
  fi
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
echo "  Test AL60CW32 - Compilateur Algol 60 vers Win32 PE / COFF"
echo "============================================================"
echo "  Executeur : ${RUNNER:-aucun (comparaisons de sortie ignorees)}"
if [ -n "$HAVE_OBJDUMP" ]; then echo "  objdump   : oui"; else echo "  objdump   : non (controles .obj et encodage ignores)"; fi
if [ -n "$HAVE_PYTHON" ]; then echo "  python3   : oui"; else echo "  python3   : non (controle de l encodage ignore)"; fi
if [ -n "$HAVE_LLD" ]; then echo "  lld-link  : oui"; else echo "  lld-link  : non (edition de liens des .obj ignoree)"; fi
echo "  Exemples  : $SAMPLES_DIR"
echo "============================================================"

# --- 1 a 3 : exemples ----------------------------------------------------------
for SRC in "$SAMPLES_DIR"/*.a60; do
  NAME="$(basename "$SRC" .a60)"
  D="$WORK/$NAME"
  mkdir -p "$D"
  cp "$SRC" "$D/$NAME.a60"
  cd "$D" || exit 1
  OPT=""
  # test_lex.a60 reference des etiquettes non definies : -w les signale
  [ "$NAME" = "test_lex" ] && OPT="-w"

  # mode par defaut : .EXE seul
  "$AL60" $OPT "$NAME.a60" >"$NAME.log" 2>&1
  if [ $? -ne 0 ] || [ ! -f "$NAME.exe" ]; then
    bad "$NAME (compilation .exe)"
    continue
  fi
  if [ -e "$NAME.asm" ] || [ -e "$NAME.obj" ]; then
    bad "$NAME (fichier .asm ou .obj cree sans option)"
  else
    ok "$NAME defaut: .exe seul"
  fi
  if [ "$NAME" = "test_lex" ]; then
    if grep -q "etiquette non definie" "$NAME.log"; then
      ok "$NAME avertissement signale"
    else
      bad "$NAME (avertissement attendu)"
    fi
  fi

  # execution et comparaison
  if [ -n "$RUNNER" ]; then
    if check_run "$NAME" "$NAME.exe"; then ok "$NAME sortie"; else bad "$NAME (sortie differente)"; fi
  else
    skip "$NAME sortie"
  fi

  # -asm : .exe + .asm
  rm -f "$NAME.exe"
  "$AL60" $OPT -asm "$NAME.a60" >/dev/null 2>&1
  if [ -f "$NAME.exe" ] && [ -f "$NAME.asm" ] && [ ! -e "$NAME.obj" ]; then
    ok "$NAME -asm"
  else
    bad "$NAME (-asm)"
  fi

  # -obj : .obj seul
  rm -f "$NAME.exe" "$NAME.asm"
  "$AL60" $OPT -obj "$NAME.a60" >/dev/null 2>&1
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
    if lld-link /entry:A60P_Main /subsystem:console /machine:x86 /nodefaultlib \
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
  "$AL60" $OPT -obj -asm "$NAME.a60" >/dev/null 2>&1
  if [ -f "$NAME.obj" ] && [ -f "$NAME.asm" ] && [ ! -e "$NAME.exe" ]; then
    ok "$NAME -obj -asm"
  else
    bad "$NAME (-obj -asm)"
  fi
  # le listing doit contenir le runtime utilise (autonome)
  if grep -q '_A60RT_' "$NAME.asm" && ! grep -q 'EXTERN _A60RT_' "$NAME.asm"; then
    ok "$NAME listing autonome"
  elif ! grep -q '_A60RT_' "$NAME.asm"; then
    ok "$NAME listing sans runtime"
  else
    bad "$NAME (listing non autonome)"
  fi

  # encodage binaire verifie par objdump
  if [ -n "$HAVE_OBJDUMP" ] && [ -n "$HAVE_PYTHON" ]; then
    "$AL60" $OPT -d "$NAME.a60" -o "$D/enc.exe" >/dev/null 2>&1
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
  printf '%s\n' "$2" >"$1.a60"
  "$AL60" "$1.a60" >"$1.log" 2>&1
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
check_error chaine     'begin outstring(1, "abc); end'                    'chaine non fermee'
check_error commentaire 'begin comment jamais termine'                    'commentaire non termine'
check_error entier     'begin integer x; x := 99999999999 end'            'entier hors limites'
check_error exposant   'begin real r; r := 1.5e999 end'                   'exposant hors limites'
check_error syntaxe    'begin integer x; x := (3 + 4; x := 2 end'         "')' attendu"
check_error virgule    'begin integer x x := 2 end'                       "';' ou 'end' attendu"
check_error fin        'begin integer x; x := 1;'                         "'end' attendu"
check_error apresend   'begin integer x; x := 1 end end'                 'texte apres la fin'
check_error crochet    'begin integer array a[1:3]; a[2 := 1 end'         "']' attendu"
check_error doublon    'begin integer x; integer x; x := 1 end'           'declaration en double'
check_error etiquette2 'begin integer x; l: x := 1; l: x := 2 end'        'etiquette dupliquee'
check_error arguments  'begin integer procedure f(a); value a; integer a; f := a; integer x; x := f(1, 2) end' 'trop d.arguments'
check_error sansarg    'begin integer procedure f(a); value a; integer a; f := a; integer x; x := f end' 'au lieu de 1'
check_error inconnue   'begin integer x; x := f(1) end'                   'procedure ou fonction inconnue'
check_error divzero    'begin integer x; x := 1 div 0 end'                'division par zero'
check_error divzeror   'begin real r; r := 1 / 0 end'                     'division par zero'
check_error chainevers 'begin integer x; x := "abc" end'                  'affectation incompatible'
check_error realbool   'begin boolean b; b := 3.5 end'                    'affectation incompatible'
check_error indices    'begin integer array a[1:3]; a[1,2] := 1 end'      'indice(s) au lieu de'
check_error pastab     'begin integer x; x[1] := 2 end'                   "n'est pas un tableau"
check_error sansindice 'begin integer array a[1:3]; integer x; x := a end' 'indice attendu'
check_error bornes     'begin integer array a[3:1]; a[2] := 1 end'        'bornes inversees'
check_error gotovar    'begin integer x; goto x end'                      'etiquette attendue'
check_error procvide   'begin integer x; procedure p; x := 1; x := p end' 'sans valeur'

# plusieurs erreurs signalees en une compilation (recuperation)
printf 'begin integer x; if x > 1 then then x := 1; x := ; x := 2 end\n' >multi.a60
"$AL60" multi.a60 >multi.log 2>&1
if [ "$(grep -c ': erreur :' multi.log)" -ge 2 ]; then ok "erreurs multiples"; else bad "erreurs multiples"; fi

# format fichier(ligne,col) : erreur : message et compteurs finaux
printf 'begin\n  integer x;\n  x := 3 @ 4\nend\n' >fmt.a60
"$AL60" fmt.a60 >fmt.log 2>&1
if grep -q '^fmt\.a60(3,10) : erreur : caractere invalide' fmt.log &&
   grep -q 'Compilation echouee : [1-9][0-9]* erreur(s), 0 avertissement(s)' fmt.log; then
  ok "format des messages"
else
  bad "format des messages"
fi

# avertissements : actifs avec -w, absents sans option ou avec -w-
check_warn() {   # nom source motif
  printf '%s\n' "$2" >"$1.a60"
  rm -f "$1.exe"
  "$AL60" -w "$1.a60" >"$1.log" 2>&1
  local rc=$?
  if [ $rc -eq 0 ] && [ -f "$1.exe" ] && grep -q "$3" "$1.log" &&
     grep -q 'Compilation terminee' "$1.log"; then
    ok "avertissement $1"
  else
    bad "avertissement $1 (rc=$rc)"
    [ $VERBOSE -eq 1 ] && cat "$1.log"
  fi
}
check_warn w_decl    'begin integer x; x := y + 1 end'                    'variable non declaree'
check_warn w_real    'begin integer x; real r; r := 2.5; x := r end'      'real converti en integer'
check_warn w_intbool 'begin integer x; if x then x := 1 end'              'integer converti en Boolean'
check_warn w_boolint 'begin integer x; boolean b; x := b end'             'Boolean converti en integer'
check_warn w_boolnum 'begin integer x; boolean b; x := 1 + b end'         'Boolean converti en integer'
check_warn w_unused  'begin integer x; goto la; x := 1; la: x := 2; inutile: x := 3 end' 'etiquette non utilisee'
check_warn w_undef   'begin integer x; goto nulle; x := 1 end'            'etiquette non definie'
check_warn w_switch  'begin integer x; switch s := l1, l2; l1: x := 1; l2: x := 2; goto s[5] end' 'indice de switch hors bornes'
check_warn w_step    'begin integer i; for i := 1 step 0 until 5 do i := i end' 'pas nul'

for OPT in "" "-w-" "-w -w-"; do
  rm -f w_decl.exe
  "$AL60" $OPT w_decl.a60 >warn.log 2>&1
  rc=$?
  if [ $rc -eq 0 ] && [ -f w_decl.exe ] && ! grep -q 'avertissement' warn.log; then
    ok "avertissements absents (options: ${OPT:-aucune})"
  else
    bad "avertissements absents (options: ${OPT:-aucune})"
  fi
done

# --- 5 : erreurs d'execution et canal d'erreur ---------------------------------
if [ -n "$RUNNER" ]; then
  printf 'begin integer array a[1:3]; integer i;\n  i := 5; outstring(1, "avant"); newline(1);\n  a[i] := 1; outstring(1, "apres")\nend\n' >rt_idx.a60
  "$AL60" rt_idx.a60 >/dev/null 2>&1
  run_exe rt_idx.exe rt_idx.out
  rc=$?
  if [ $rc -eq 1 ] && grep -q '^avant' rt_idx.out && grep -q 'indice hors bornes' rt_idx.out &&
     ! grep -q apres rt_idx.out; then
    ok "execution: indice hors bornes"
  else
    bad "execution: indice hors bornes (rc=$rc)"
  fi
  printf 'begin integer a, b; a := 0; b := 7;\n  outinteger(1, b div a)\nend\n' >rt_div.a60
  "$AL60" rt_div.a60 >/dev/null 2>&1
  run_exe rt_div.exe rt_div.out
  rc=$?
  if [ $rc -eq 1 ] && grep -q 'division par zero' rt_div.out; then
    ok "execution: division par zero"
  else
    bad "execution: division par zero (rc=$rc)"
  fi
  printf 'begin outstring(1, "sortie"); newline(1); outstring(2, "erreur"); newline(2) end\n' >rt_chan.a60
  "$AL60" rt_chan.a60 >/dev/null 2>&1
  run_exe rt_chan.exe rt_chan.out
  if [ "$RUNNER" = "wine" ]; then
    WINEDEBUG=-all wine rt_chan.exe 2>&1 >/dev/null </dev/null | tr -d '\r' >rt_chan.err
  else
    "$WORK/runpe" rt_chan.exe 2>&1 >/dev/null </dev/null | tr -d '\r' >rt_chan.err
  fi
  if [ "$(cat rt_chan.out)" = "sortie" ] && [ "$(cat rt_chan.err)" = "erreur" ]; then
    ok "execution: canal 2 = erreur standard"
  else
    bad "execution: canal 2 = erreur standard"
  fi
else
  skip "erreurs d'execution (aucun executeur)"
fi

# --- 6 : options et fichiers produits ------------------------------------------
M="$WORK/opt"
mkdir -p "$M"
cd "$M" || exit 1
cp "$SAMPLES_DIR/hello.a60" h.a60

check_files() {   # attendu options...
  local want="$1"; shift
  rm -f h.exe h.obj h.asm h.lst n.exe n.obj n.asm
  "$AL60" "$@" h.a60 >/dev/null 2>&1
  local got
  got="$(ls h.exe h.obj h.asm h.lst n.exe n.obj n.asm 2>/dev/null | tr '\n' ' ')"
  if [ "$got" = "$want " ] || { [ -z "$want" ] && [ -z "$got" ]; }; then
    ok "fichiers [$*] -> $want"
  else
    bad "fichiers [$*] -> '$got' (attendu '$want')"
  fi
}
check_files "h.exe"
check_files "h.asm h.exe" -asm
check_files "h.obj" -obj
check_files "h.asm h.obj" -obj -asm
check_files "h.exe h.lst" -d
check_files "h.lst h.obj" -obj -d
check_files "h.exe" -v
check_files "h.exe" -w
check_files "h.exe" -w-
check_files "n.exe" -o n
check_files "n.asm n.exe" -o n -asm
check_files "n.obj" -obj -o n
check_files "n.asm n.obj" -obj -asm -o n

"$AL60" -v h.a60 >v.log 2>&1
if grep -q 'token' v.log && grep -q '\.text :' v.log && grep -q 'Compilation terminee' v.log; then
  ok "-v statistiques"
else
  bad "-v statistiques"
fi
"$AL60" -d h.a60 >d.log 2>&1
if grep -q 'KEYWORD begin' d.log && grep -q 'Code interne' d.log && grep -q 'Portee' d.log; then
  ok "-d tokens, symboles et code interne"
else
  bad "-d tokens, symboles et code interne"
fi
cp h.a60 h.alg
rm -f h.exe
"$AL60" h.alg >/dev/null 2>&1
if [ -f h.exe ]; then ok "source .alg"; else bad "source .alg"; fi
rm -f h.exe
"$AL60" h >/dev/null 2>&1
if [ -f h.exe ]; then ok "source sans extension"; else bad "source sans extension"; fi

# options
"$AL60" -h >help.log 2>&1
rc=$?
if [ $rc -eq 0 ] && grep -q 'Syntaxe: AL60CW32' help.log; then ok "-h"; else bad "-h"; fi
"$AL60" >noarg.log 2>&1
rc=$?
if [ $rc -eq 2 ] && grep -q 'Syntaxe: AL60CW32' noarg.log; then ok "sans argument: usage"; else bad "sans argument"; fi
"$AL60" introuvable.a60 >missing.log 2>&1
rc=$?
if [ $rc -eq 1 ] && grep -q 'introuvable' missing.log; then ok "source introuvable"; else bad "source introuvable"; fi
"$AL60" -z h.a60 >badopt.log 2>&1
rc=$?
if [ $rc -eq 2 ] && grep -q 'option inconnue' badopt.log; then ok "option inconnue"; else bad "option inconnue"; fi
printf 'x\n' >h.txt
"$AL60" h.txt >badext.log 2>&1
rc=$?
if [ $rc -eq 1 ] && grep -q 'extension non supportee' badext.log; then ok "extension inconnue"; else bad "extension inconnue"; fi
"$AL60" -o h.asm h.a60 >badasm.log 2>&1
rc=$?
if [ $rc -eq 1 ] && grep -q 'utiliser -asm' badasm.log; then ok "-o vers .asm refuse"; else bad "-o vers .asm refuse"; fi
"$AL60" -o h.a60 h.a60 >badsrc.log 2>&1
rc=$?
if [ $rc -eq 1 ] && grep -q 'ecraserait le source' badsrc.log; then ok "-o vers le source refuse"; else bad "-o vers le source refuse"; fi

# erreur fatale apres creation du .asm : aucun fichier ne subsiste
rm -f h.asm h.exe
mkdir h.exe
"$AL60" -asm h.a60 >fatal.log 2>&1
rc=$?
if [ $rc -eq 1 ] && [ ! -e h.asm ]; then ok "erreur fatale: .asm supprime"; else bad "erreur fatale: .asm supprime"; fi
rmdir h.exe

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
