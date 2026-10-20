#!/bin/bash
# runp.sh prog.a68 : compile avec AL68CW32 -asm, ajoute le runtime d'essai
# (stubs.py), assemble avec ML et execute avec le chargeur PE de test ;
# la sortie standard du programme est affichee (fins de ligne CR LF
# converties), puis le code de sortie.
b=${1%.a68}
timeout 10 /tmp/claude-0/b3/AL68CW32 -asm $1 >$b.log 2>&1 || { head -5 $b.log; exit 1; }
python3 stubs.py $b.asm
timeout 10 /tmp/claude-0/ml/ML $b.asm 2>&1 | grep -i "error" | head
timeout 5 /tmp/claude-0/runpe/runpe $b.exe | tr -d '\r'
echo "[rc=${PIPESTATUS[0]}]"
