#!/usr/bin/env python3
"""Regenere dans TPC.PAS le bloc GraphSource (unite Graph integree) a partir de GRAPH.PAS.
usage : python3 GENGRAPH.PY GRAPH.PAS TPC.PAS
Le bloc est delimite par les marqueurs { === DEBUT UNITE GRAPH === } / { === FIN UNITE GRAPH === }
(cree apres { === FIN UNITES INTEGREES === } s'il n'existe pas encore)."""
import sys, re
src, tpc = sys.argv[1], sys.argv[2]
lines = open(src, encoding='latin-1').read().replace('\r', '').split('\n')
while lines and lines[-1] == '':
    lines.pop()
out = []
for l in lines:
    l = l.rstrip()
    if len(l) > 255:
        sys.exit('ligne trop longue : ' + l[:40])
    out.append(" '" + l.replace("'", "''") + "'")
block = ["{ === DEBUT UNITE GRAPH === }",
         "{ Source Pascal de l'unite Graph (BGI integre), compile a la demande comme CRT/DOS.",
         "  Genere par TESTS/GRAPH/GENGRAPH.PY a partir de TESTS/GRAPH/GRAPH.PAS; apostrophes doublees. }",
         "const GraphSource: array[1..%d] of string[255] = (" % len(out)]
block += [o + ("," if i < len(out) - 1 else ");") for i, o in enumerate(out)]
block += ["{ === FIN UNITE GRAPH === }"]
t = open(tpc, encoding='latin-1').read()
b, e = "{ === DEBUT UNITE GRAPH === }", "{ === FIN UNITE GRAPH === }"
if b in t:
    i = t.index(b); j = t.index(e) + len(e)
    t = t[:i] + "\n".join(block) + t[j:]
else:
    k = "{ === FIN UNITES INTEGREES === }"
    t = t.replace(k, k + "\n" + "\n".join(block), 1)
open(tpc, 'w', encoding='latin-1', newline='\n').write(t)
