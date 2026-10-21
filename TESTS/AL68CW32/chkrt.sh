#!/bin/bash
# chkrt.sh [AL68CW32] : verifie le runtime embarque (TODO 22) avec le
# chargeur PE de test (RUNNER, TESTS/AL60CW32/runpe.c compile) :
#   - work/rt1.a68, pr2.a68 (avec pr2.in sur l'entree standard), slice.a68
#     (tranches a plusieurs dimensions), copy.a68 (chaines recopiees,
#     tableaux passes par valeur), display.a68 (affichages a plusieurs
#     dimensions), gc.a68 et gc2.a68 (plus de 6 millions d'allocations :
#     le ramasse-miettes doit rendre la memoire), print2 (print de
#     tableaux, structures, unions ; concatenation), ouse (conformite),
#     procs (formes de PROC et OP, recursion mutuelle, GOTO hors
#     procedure), closure (fermetures), long (LONG INT, BITS, avec
#     long.in), compl (COMPL, BYTES), file (fichiers), fmt (formats),
#     real2 (reels en notation scientifique), par1 et par2 (PAR et
#     SEMA), events (gestionnaires d'evenements), numfmt (whole, fixed,
#     float), fmt2 (formats e c k q s replicateurs calcules) et getf
#     (lecture formatee) donnent la sortie des fichiers .exp (fins de ligne CR LF
#     converties) ;
#   - indice hors bornes, division par zero, reference NIL, tableaux de
#     dimensions differentes et interblocage de PAR ecrivent un message
#     sur l'erreur standard et terminent par le code 1 ;
#   - si ML (RUNNER_ML, clone de ML.EXE) est present, le listing .ASM
#     autonome assemble donne la meme sortie que l'.EXE direct.
here=$(cd "$(dirname "$0")" && pwd)
comp=${1:-$here/../../BINLINUX/AL68CW32}
[ -n "$RUNNER" ] || { echo "RUNNER non defini: verification ignoree"; exit 0; }
tmp=$(mktemp -d)
cd "$tmp" || exit 1
bad=0
ko() { echo "ECHEC: $1"; bad=1; }
for n in rt1 pr2 slice copy display gc gc2 print2 ouse procs closure long \
         compl file fmt real2 par1 par2 events numfmt fmt2 getf; do
  cp "$here/work/$n.a68" .
  "$comp" $n.a68 >log 2>&1 || { ko "compilation $n"; continue; }
  in=/dev/null; [ -f "$here/work/$n.in" ] && in="$here/work/$n.in"
  timeout 5 "$RUNNER" $n.exe <"$in" 2>/dev/null | tr -d '\r' >$n.out
  cmp -s $n.out "$here/work/$n.exp" && echo "  $n: ok" || ko "$n: sortie differente"
done
i=0
while IFS='|' read -r code msg; do
  i=$((i+1))
  printf 'BEGIN print(("avant", newline)); %s; print(("apres", newline)) END\n' "$code" >e$i.a68
  "$comp" e$i.a68 >log 2>&1 || { ko "compilation e$i"; continue; }
  timeout 5 "$RUNNER" e$i.exe >e$i.out 2>e$i.err
  rc=$?
  tr -d '\r' <e$i.out | grep -q '^avant$' && ! grep -q apres e$i.out \
    && grep -q "$msg" e$i.err && [ $rc -eq 1 ] \
    && echo "  erreur $i: ok" || ko "erreur d'execution $i ($code)"
done <<'LST'
[1:3] INT a; INT i := 5; a[i] := 1|indice hors bornes
INT z := 0; INT r := 10 OVER z|division par zero
REF INT p := NIL; INT v := p|reference NIL
[1:3] INT a; [1:4] INT b; a := b|dimensions differentes
SEMA d = LEVEL 0; DOWN d|interblocage
LST
if [ -n "$RUNNER_ML" ]; then
  cp "$here/work/rt1.a68" m.a68
  "$comp" -asm m.a68 >log 2>&1 && cp m.exe direct.exe && "$RUNNER_ML" m.asm >/dev/null 2>&1
  timeout 5 "$RUNNER" direct.exe | tr -d '\r' >d.out
  timeout 5 "$RUNNER" m.exe | tr -d '\r' >m.out
  cmp -s d.out m.out && echo "  listing .ASM assemble par ML: meme sortie" || ko "listing .ASM (ML)"
fi
cd / && rm -rf "$tmp"
[ $bad -eq 0 ] && echo "chkrt: ok"
exit $bad
