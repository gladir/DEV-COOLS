#!/bin/bash
# run_one.sh NOM KIND MODE : execute NOM.EXE sous DOSBox (sans fenetre) avec les
# arguments du mode et conserve OUT.TXT (stdout), SCREEN.TXT (ecran texte) et
# les fichiers produits dans $WORK/runs_MODE/KIND_NOM.
#   KIND = ref (executable Borland de $CORAIL/BIN16) ou our (executable TPC de $WORK/exe)
#   MODE = help (/?), noarg (aucun argument), nofile (fichier inexistant),
#          sample (arguments de sample_args.txt + fichiers samples/)
# Variables: CORAIL (depot corail), WORK (repertoire de travail), TIMEOUT_SEC (25).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
: "${CORAIL:?definir CORAIL=chemin du depot corail}"; : "${WORK:?definir WORK=repertoire de travail}"
TIMEOUT_SEC=${TIMEOUT_SEC:-25}
NAME=$1; KIND=$2; MODE=$3
W=$WORK/runs_$MODE/${KIND}_$NAME
rm -rf "$W"; mkdir -p "$W"
if [ "$KIND" = ref ]; then cp "$CORAIL/BIN16/$NAME.EXE" "$W/$NAME.EXE"; else cp "$WORK/exe/$NAME.EXE" "$W/$NAME.EXE"; fi
cp "$WORK/SCRDUMP.EXE" "$W/"
case $MODE in
 help) ARGS="/?";;
 noarg) ARGS="";;
 nofile) ARGS="NOFILE.TXT";;
 sample) ARGS=$(grep "^$NAME " "$HERE/sample_args.txt" | cut -d' ' -f2-); cp "$HERE"/samples/* "$W/" 2>/dev/null; cp "$WORK/SAMPLE.EXE" "$W/" 2>/dev/null;;
esac
cat > "$W/run.conf" <<CONF
[sdl]
output=surface
[cpu]
cycles=max
[autoexec]
mount c $W
c:
cls
$NAME.EXE $ARGS > OUT.TXT
SCRDUMP.EXE SCREEN.TXT
exit
CONF
cd "$W"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 $TIMEOUT_SEC dosbox -conf run.conf -noconsole > dosbox.log 2>&1
rc=$?
[ -f SCREEN.TXT ] || echo "TIMEOUT rc=$rc" > TIMEOUT.TXT
rm -f "$W/$NAME.EXE" "$W/SCRDUMP.EXE" "$W/run.conf" "$W/dosbox.log"
