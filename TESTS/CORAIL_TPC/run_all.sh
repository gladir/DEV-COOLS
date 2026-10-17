#!/bin/bash
# run_all.sh - Compile les .PAS du projet CORAIL avec TPC puis compare chaque
# executable produit a l'executable Borland correspondant (BIN16) sous DOSBox.
#
# Usage: CORAIL=/chemin/corail WORK=/chemin/travail ./TESTS/CORAIL_TPC/run_all.sh [TPC] [modes]
#   TPC    binaire du compilateur (par defaut: compile ../../TPC.PAS avec fpc)
#   modes  liste parmi help noarg nofile sample (defaut: les quatre)
# Prerequis: fpc (Free Pascal 3.2), dosbox, python3, git clone de https://github.com/gladir/corail
# Resultats: $WORK/results.txt (resume de compilation), $WORK/compare_<mode>.txt
set -u
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../.." && pwd)
: "${CORAIL:?definir CORAIL=chemin du depot corail}"; : "${WORK:?definir WORK=repertoire de travail}"
TPC=${1:-}; MODES=${2:-"help noarg nofile sample"}
TPC_OPTS=${TPC_OPTS:-}   # ex. TPC_OPTS="-CD -tp7" pour tester TPCW32
JOBS=${JOBS:-4}
mkdir -p "$WORK/exe" "$WORK/src"
if [ -z "$TPC" ]; then fpc -Mtp -O1 -v0 "$REPO/TPC.PAS" -o"$WORK/TPC" >/dev/null || exit 1; TPC=$WORK/TPC; fi
# 1. compilation des 525 sources (copies dans $WORK/src, EXE dans $WORK/exe)
cp "$CORAIL"/*.PAS "$WORK/src/"; rm -f "$WORK/exe"/*.EXE
( cd "$WORK/src" && for f in *.PAS; do
    out=$(timeout 60 "$TPC" $TPC_OPTS -Q -E"$WORK/exe/" "$f" 2>&1 | tail -1); echo "$f | $out"; done ) > "$WORK/results.txt"
echo "Compilation: $(grep -c 'octets de code' "$WORK/results.txt") / $(ls "$WORK/src"/*.PAS | wc -l) sources"
# 2. outil de capture d'ecran et fichier exemple EXE
"$TPC" $TPC_OPTS -Q -E"$WORK/" "$HERE/SCRDUMP.PAS" >/dev/null
cp "$WORK/exe/ISBN.EXE" "$WORK/SAMPLE.EXE" 2>/dev/null
# 3. programmes testables: EXE produit par TPC et EXE Borland present
for e in "$WORK/exe"/*.EXE; do n=$(basename "$e" .EXE); [ -f "$CORAIL/BIN16/$n.EXE" ] && echo "$n"; done > "$WORK/names.txt"
awk 'NF>=2{print $1}' "$HERE/sample_args.txt" | sort -u | grep -x -f "$WORK/names.txt" > "$WORK/sample_names.txt"
export CORAIL WORK
for m in $MODES; do
  echo "== mode $m"; rm -rf "$WORK/runs_$m"
  if [ "$m" = sample ]; then LIST=$WORK/sample_names.txt; else LIST=$WORK/names.txt; fi
  for k in ref our; do awk -v k=$k -v m=$m '{print $1,k,m}' "$LIST"; done | xargs -P $JOBS -n 3 "$HERE/run_one.sh"
  python3 "$HERE/compare.py" $m
done
