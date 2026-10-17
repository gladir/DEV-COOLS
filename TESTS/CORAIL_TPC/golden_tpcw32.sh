#!/bin/bash
# golden_tpcw32.sh BIN OUTDIR : compile SAMPLES/TURBOPASCAL/*.pas avec TPCW32 pour chaque
# cible et enregistre les md5 des fichiers produits dans OUTDIR/<cible>.md5.
# Usage pour verifier qu'une modification de TPCW32.PAS ne change pas les autres cibles:
#   ./golden_tpcw32.sh /tmp/TPCW32.avant /tmp/gold_avant
#   ./golden_tpcw32.sh /tmp/TPCW32.apres /tmp/gold_apres
#   for f in /tmp/gold_avant/*.md5; do cmp -s $f /tmp/gold_apres/$(basename $f) || echo "$f differe"; done
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../.." && pwd)
BIN=$1; OUT=$2; mkdir -p "$OUT"
TARGETS=${TARGETS:-"-CW32 -CD -CP -CW -CZ80 -C6502 -C6809 -C68000 -CATARIST -CAMIGA -CAPPLEII -CC64 -CCOCO3 -CTRS80 -CATARI400 -CATARI800 -CMSX -CNES -CATARI2600 -CADAM -CCRAY1 -CTO7 -obj -asm --quickpascal --applepascal -tp6 -tp55 -tp4"}
TMP=$(mktemp -d)
for T in $TARGETS; do
  rm -rf "$TMP"/*; cp "$REPO"/SAMPLES/TURBOPASCAL/*.pas "$TMP/"
  ( cd "$TMP" && for f in *.pas; do timeout 30 "$BIN" $T -Q "$f" >/dev/null 2>&1; done
    for f in *.pas; do n=${f%.pas}; for e in exe EXE obj asm s19 com bin prg rom nes xex; do [ -f "$n.$e" ] && echo "$n.$e $(md5sum < "$n.$e" | cut -c1-32)"; done; done ) > "$OUT/${T#-}.md5"
  echo "$T: $(wc -l < "$OUT/${T#-}.md5") sorties"
done
rm -rf "$TMP"
