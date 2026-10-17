#!/bin/bash
# w32_run_all.sh - Compile les .PAS du projet CORAIL avec TPCW32 -CW32 puis compare chaque
# executable produit a l'executable Free Pascal Win32 correspondant (WIN32/) sous Wine.
#
# Usage: CORAIL=/chemin/corail WORK=/chemin/travail ./TESTS/CORAIL_TPC/w32_run_all.sh [TPCW32] [modes]
#   TPCW32  binaire du compilateur (par defaut: compile ../../TPCW32.PAS avec fpc -Mtp)
#   modes   liste parmi help noarg nofile sample (defaut: les quatre)
# Prerequis: fpc (Free Pascal 3.2), wine (32 bits), python3 avec le module pyte,
#            git clone de https://github.com/gladir/corail (sources .PAS et WIN32/*.exe)
# Resultats: $WORK/results.txt (compilation), $WORK/compare_<mode>.txt, et un repertoire
#            $WORK/runs_<mode>/{ref,our}_NOM par execution (OUT.TXT, fichiers produits).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../.." && pwd)
: "${CORAIL:?definir CORAIL=chemin du depot corail}"; : "${WORK:?definir WORK=repertoire de travail}"
TPC=${1:-}; MODES=${2:-"help noarg nofile sample"}
JOBS=${JOBS:-4}
export CORAIL WORK WINEDEBUG=-all
[ -n "${HOME:-}" ] && [ "$HOME" != "/" ] || export HOME=/root   # prefixe Wine stable
mkdir -p "$WORK/exe" "$WORK/src"
if [ -z "$TPC" ]; then fpc -Mtp -O1 -v0 "$REPO/TPCW32.PAS" -o"$WORK/TPCW32" >/dev/null || exit 1; TPC=$WORK/TPCW32; fi
# 1. compilation des 525 sources (copies dans $WORK/src, EXE dans $WORK/exe)
cp "$CORAIL"/*.PAS "$WORK/src/"; rm -f "$WORK/exe"/*.EXE
( cd "$WORK/src" && for f in *.PAS; do
    n=${f%.PAS}; rm -f "$n.exe"
    out=$(timeout 120 "$TPC" -CW32 -Q "$f" 2>&1 | grep -v '^$' | tail -1)
    if [ -f "$n.exe" ]; then echo "$f | OK $(stat -c %s "$n.exe") | $out"; mv "$n.exe" "$WORK/exe/$n.EXE"
    else echo "$f | KO | $out"; fi
  done ) > "$WORK/results.txt"
echo "compilation: $(grep -c '| OK' "$WORK/results.txt") / $(wc -l < "$WORK/results.txt") sources"
# 2. references : executables PE32 de WIN32/ ayant un source (quelques fichiers sont des EXE DOS)
for e in "$CORAIL"/WIN32/*.exe; do n=$(basename "$e" .exe | tr a-z A-Z)
  [ -f "$CORAIL/$n.PAS" ] && file "$e" | grep -q PE32 && echo "$n"; done | sort -u > "$WORK/refnames.txt"
for n in $(cat "$WORK/refnames.txt"); do [ -f "$WORK/exe/$n.EXE" ] && echo "$n"; done > "$WORK/names.txt"
awk 'NF>=2{print $1}' "$HERE/sample_args.txt" | sort -u | grep -x -f "$WORK/names.txt" > "$WORK/sample_names.txt"
cp "$CORAIL/WIN32/isbn.exe" "$WORK/SAMPLE.EXE" 2>/dev/null
echo "references: $(wc -l < "$WORK/refnames.txt")  programmes testables: $(wc -l < "$WORK/names.txt")"
# 3. execution des deux versions et comparaison
for m in $MODES; do
  echo "== mode $m"; rm -rf "$WORK/runs_$m"/our_*
  if [ "$m" = sample ]; then L=$WORK/sample_names.txt
    RL=$(awk 'NF>=2{print $1}' "$HERE/sample_args.txt" | sort -u | grep -x -f "$WORK/refnames.txt")
  else L=$WORK/names.txt; RL=$(cat "$WORK/refnames.txt"); fi
  for n in $RL; do [ -d "$WORK/runs_$m/ref_$n" ] || echo "$n ref $m"; done | xargs -r -P "$JOBS" -n 3 "$HERE/w32_run_one.sh"
  awk -v m=$m '{print $1,"our",m}' "$L" | xargs -r -P "$JOBS" -n 3 "$HERE/w32_run_one.sh"
  python3 "$HERE/w32_compare.py" "$m" | tail -12
done
