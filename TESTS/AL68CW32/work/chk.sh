#!/bin/bash
# chk.sh fichier.asm cellule [real|offN] : assemble le listing avec ML, le
# rend avec le code de sortie egal a la valeur de la cellule (entier, reel
# double, ou mot a un decalage), execute avec le chargeur PE de test.
# Les programmes .a68 de ce dossier sont des essais manuels (TODOs 8 a 13) ;
# les corps de boucle y sont remplaces dans le listing (voir DOC).
# chk2.sh fichier.asm cellule [real]  -> code de sortie = valeur de la cellule
f=$1; cell=$2; kind=${3:-int}
python3 - "$f" "$cell" "$kind" <<'PY'
import sys,re
f,cell,kind=sys.argv[1:4]
s=open(f).read()
name=re.search(r'^(_A68V_%s_\d+)'%cell,s,re.M).group(1)
if kind.startswith('off'):
    ins="        PUSH    DWORD PTR [%s+%d]\n"%(name,int(kind[3:]))
elif kind=='int': ins="        PUSH    DWORD PTR [%s]\n"%name
else: ins="        FLD     QWORD PTR [%s]\n        FLD     QWORD PTR [%s]\n        FADDP   ST(1), ST\n        FISTP   DWORD PTR [_CHKTMP]\n        PUSH    DWORD PTR [_CHKTMP]\n"%(name,name)
s=s.replace("        PUSH    0\n        CALL    ExitProcess",ins+"        CALL    ExitProcess",1)
s=s.replace(".DATA\n",".DATA\n_CHKTMP DD 0\n",1)
open('chk.asm','w').write(s)
PY
/tmp/claude-0/ml/ML chk.asm >/dev/null 2>&1; /tmp/claude-0/runpe/runpe chk.exe; echo -n "$cell=$? "
