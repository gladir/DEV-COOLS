#!/bin/bash
# chkopt.sh [AL68CW32] : verifie les options de la ligne de commande et
# les fichiers produits (SAMPLES/ALGOL68/ops.a68 copie dans un dossier
# temporaire) : sans option seul le .EXE ; -asm ajoute le .ASM ; -obj ne
# produit jamais de .EXE ; -o ; -d (.lst) ; -w / -w+ / -w- ; erreurs
# d'usage.
here=$(cd "$(dirname "$0")" && pwd)
comp=${1:-$here/../../BINLINUX/AL68CW32}
tmp=$(mktemp -d)
cd "$tmp" || exit 1
bad=0
n=0
# t "description" "fichiers attendus" arguments...
t() {
  local desc="$1" want="$2"; shift 2
  rm -f ./*.exe ./*.obj ./*.asm ./*.lst out* x*
  "$comp" "$@" >log 2>&1
  local got
  got=$(ls | grep -v -e '^log$' -e '^ops.a68$' -e '^ops.alg$' -e '^ops$' | tr '\n' ' ' | sed 's/ $//')
  n=$((n+1))
  [ "$got" = "$want" ] || { echo "ECHEC $desc: obtenu '$got', attendu '$want'"; bad=1; }
}
cp "$here/../../SAMPLES/ALGOL68/ops.a68" ops.a68
t "defaut"              "ops.exe"           ops.a68
t "-asm"                "ops.asm ops.exe"   ops.a68 -asm
t "-obj"                "ops.obj"           ops.a68 -obj
t "-obj -asm"           "ops.asm ops.obj"   ops.a68 -obj -asm
t "-o out"              "out.exe"           ops.a68 -o out
t "-o out.exe -asm"     "out.asm out.exe"   ops.a68 -o out.exe -asm
t "-obj -o x"           "x.obj"             ops.a68 -obj -o x
t "-obj -o x -asm"      "x.asm x.obj"       ops.a68 -obj -o x -asm
t "-d"                  "ops.exe ops.lst"   ops.a68 -d
t "-d -obj"             "ops.lst ops.obj"   ops.a68 -d -obj
t "sans extension"      "ops.exe"           ops
cp ops.a68 ops.alg
t "extension .alg"      "ops.exe"           ops.alg
rm -f ops.alg
t "-v"                  "ops.exe"           ops.a68 -v
t "-o ecrase le source" ""                  ops.a68 -o ops.a68
[ $? -eq 0 ] && { "$comp" ops.a68 -o ops.a68 >log 2>&1; [ $? -eq 1 ] || { echo "ECHEC code -o source"; bad=1; }; }
t "-o x.asm"            ""                  ops.a68 -o x.asm
t "option inconnue"     ""                  ops.a68 -zz
"$comp" ops.a68 -zz >log 2>&1; [ $? -eq 2 ] || { echo "ECHEC code option inconnue"; bad=1; }
t "source introuvable"  ""                  absent.a68
"$comp" absent.a68 >log 2>&1; [ $? -eq 1 ] || { echo "ECHEC code source introuvable"; bad=1; }
"$comp" >log 2>&1; [ $? -eq 2 ] || { echo "ECHEC code sans argument"; bad=1; }
"$comp" -h >log 2>&1; [ $? -eq 0 ] || { echo "ECHEC code -h"; bad=1; }
# avertissements
"$comp" ops.a68 >log 2>&1;        grep -q avertissement log && { echo "ECHEC avertissement sans -w"; bad=1; }
"$comp" ops.a68 -w >log 2>&1;     grep -q avertissement log || { echo "ECHEC -w"; bad=1; }
"$comp" ops.a68 -w+ >log 2>&1;    grep -q avertissement log || { echo "ECHEC -w+"; bad=1; }
"$comp" ops.a68 -w -w- >log 2>&1; grep -q avertissement log && { echo "ECHEC -w -w-"; bad=1; }
# apres une erreur : aucun fichier
echo 'BEGIN INT x := TRUE END' >bad.a68
rm -f ./*.exe ./*.obj ./*.asm
"$comp" bad.a68 -asm >log 2>&1; rc=$?
[ $rc -eq 1 ] && [ ! -e bad.exe ] && [ ! -e bad.asm ] || { echo "ECHEC fichiers apres erreur"; bad=1; }
echo "$n combinaisons verifiees"
cd / && rm -rf "$tmp"
[ $bad -eq 0 ] && echo "chkopt: ok"
exit $bad
