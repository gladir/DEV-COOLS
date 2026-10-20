#!/bin/bash
# chkall.sh [AL68CW32] : compile chaque exemple de SAMPLES/ALGOL68 avec -d
# (listing hexadecimal <nom>.lst) dans un dossier temporaire et verifie
# l'encodage avec objdump (chkenc.py). Code de retour 0 si aucun ecart.
here=$(cd "$(dirname "$0")" && pwd)
comp=${1:-$here/../../BINLINUX/AL68CW32}
tmp=$(mktemp -d)
bad=0; n=0
for f in "$here"/../../SAMPLES/ALGOL68/*.a68; do
  b=$(basename "$f" .a68)
  cp "$f" "$tmp/$b.a68"
  ( cd "$tmp" && "$comp" -d "$b.a68" >/dev/null 2>&1 ) || { echo "ERREUR de compilation: $b"; bad=1; continue; }
  r=$(python3 "$here/chkenc.py" "$tmp/$b.lst" | tail -1)
  n=$((n+1))
  case "$r" in *" 0 ecart(s)") ;; *) echo "$b: $r"; bad=1;; esac
done
rm -rf "$tmp"
echo "$n exemples verifies"
exit $bad
