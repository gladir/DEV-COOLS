#!/bin/bash
# chkerr.sh [AL68CW32] : verifie les diagnostics sur les programmes fautifs
# de errors.txt (nom|programme|E ou W|ligne,colonne|message) : le premier
# diagnostic doit avoir cette nature, cette position et ce debut de
# message ; une erreur donne le code 1 et aucun fichier de sortie, un
# avertissement (option -w) le code 0 ; le rapport final compte les
# diagnostics. Ensuite fuzz.py (mutations) ne doit provoquer ni arret
# anormal ni boucle.
here=$(cd "$(dirname "$0")" && pwd)
comp=${1:-$here/../../BINLINUX/AL68CW32}
tmp=$(mktemp -d)
cd "$tmp" || exit 1
bad=0; n=0
while IFS='|' read -r name src kind pos msg; do
  case "$name" in \#*|"") continue;; esac
  n=$((n+1))
  echo "$src" >"$name.a68"
  out=$("$comp" -w -asm "$name.a68" 2>&1); rc=$?
  first=$(echo "$out" | head -1)
  want="$name.a68($pos) : "
  [ "$kind" = E ] && want="${want}erreur : $msg" || want="${want}avertissement : $msg"
  case "$first" in "$want"*) ;; *) echo "ECHEC $name: attendu '$want', obtenu '$first'"; bad=1;; esac
  if [ "$kind" = E ]; then
    [ $rc -eq 1 ] && [ ! -e "$name.exe" ] && [ ! -e "$name.asm" ] || { echo "ECHEC $name: code $rc ou fichier cree"; bad=1; }
    echo "$out" | tail -1 | grep -q "^Compilation echouee : " || { echo "ECHEC $name: pas de rapport final"; bad=1; }
  else
    [ $rc -eq 0 ] || { echo "ECHEC $name: code $rc"; bad=1; }
    echo "$out" | tail -1 | grep -q "^Compilation terminee : 0 erreur, " || { echo "ECHEC $name: pas de rapport final"; bad=1; }
  fi
done <"$here/errors.txt"
echo "$n programmes fautifs verifies"
if command -v python3 >/dev/null 2>&1; then
  r=$(python3 "$here/fuzz.py" 1 300 "$comp" | tail -1)
  echo "  fuzz: $r"
  case "$r" in *"problemes: 0") ;; *) bad=1;; esac
fi
cd / && rm -rf "$tmp"
[ $bad -eq 0 ] && echo "chkerr: ok"
exit $bad
