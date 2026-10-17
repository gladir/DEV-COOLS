#!/bin/bash
# w32_run_one.sh NOM KIND MODE : execute NOM.EXE sous Wine (pseudo-terminal 80x25) avec les
# arguments du mode et conserve OUT.TXT (sortie rendue), OUT.RAW et les fichiers produits
# dans $WORK/runs_MODE/KIND_NOM.
#   KIND = ref (executable Free Pascal de $CORAIL/WIN32) ou our (executable TPCW32 de $WORK/exe)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
: "${CORAIL:?}"; : "${WORK:?}"
TIMEOUT_SEC=${TIMEOUT_SEC:-20}
NAME=$1; KIND=$2; MODE=$3
W=$WORK/runs_$MODE/${KIND}_$NAME
rm -rf "$W"; mkdir -p "$W"
if [ "$KIND" = ref ]; then cp "$CORAIL/WIN32/$(echo "$NAME" | tr A-Z a-z).exe" "$W/$NAME.EXE"; else cp "$WORK/exe/$NAME.EXE" "$W/$NAME.EXE"; fi
case $MODE in
 help) ARGS="/?";;
 noarg) ARGS="";;
 nofile) ARGS="NOFILE.TXT";;
 sample) ARGS=$(grep "^$NAME " "$HERE/sample_args.txt" | cut -d' ' -f2-); cp "$HERE/samples"/* "$W/" 2>/dev/null; cp "$WORK/SAMPLE.EXE" "$W/" 2>/dev/null;;
esac
cd "$W"
WINEDEBUG=-all python3 "$HERE/w32_ptyrun.py" "$TIMEOUT_SEC" OUT wine "./$NAME.EXE" $ARGS 2> ERR.TXT
rc=$?
echo "$rc" > RC.TXT
[ $rc -eq 124 ] && echo "TIMEOUT rc=$rc" > TIMEOUT.TXT
rm -f "$W/$NAME.EXE"
