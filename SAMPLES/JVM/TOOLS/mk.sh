#!/bin/bash
# Regenere la section DONNEES (classes de la bibliotheque en base 64) de JVM.PAS.
# usage : mk.sh <repertoire des sources RT> <fichier de sortie .pas> [JAVAC]
#   JAVAC : compilateur Java (par defaut l'executable de JAVAC.PAS nomme javac)
RT=${1:-../RT}; OUT=${2:-donnees.pas}; JC=${3:-javac}
D=$(dirname "$0"); W=$(mktemp -d)
mkdir -p $W/out
$JC -d $W/out $(find $RT -name "*.java")
python3 $D/gen.py $W/out $OUT
rm -rf $W
