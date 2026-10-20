#!/usr/bin/env python3
# vars.py exemple.a68 exemple.vars sortie.a68 : copie l'exemple en ajoutant,
# avant son dernier END (ou a la fin s'il n'a pas de BEGIN ... END), un
# print de chaque variable de exemple.vars (lignes nom=valeur attendue).
# Le programme obtenu doit afficher exactement les lignes de exemple.vars
# (sans les commentaires), qui sont calculees a la main.
import re, sys
src = open(sys.argv[1], encoding='latin-1').read()
names = []
for line in open(sys.argv[2], encoding='latin-1'):
    line = line.rstrip('\n')
    if line and not line.startswith('#'):
        names.append(line.split('=', 1)[0])
prints = ';\n'.join('  print(("%s=", %s, newline))' % (n, n) for n in names)
m = None
for m in re.finditer(r'\bEND\b', src):
    pass
body = src.rstrip()
if m is not None and body.endswith('END') and re.match(r'\s*(CO .*? CO\s*)*BEGIN\b', src, re.S):
    i = m.start()
    # ne pas ajouter de point-virgule apres un point-virgule final
    head = src[:i].rstrip()
    sep = '' if head.endswith(';') else ';'
    out = head + sep + '\n' + prints + '\n' + src[i:]
else:
    head = body
    sep = '' if head.endswith(';') else ';'
    out = head + sep + '\n' + prints + '\n'
open(sys.argv[3], 'w', encoding='latin-1').write(out)
