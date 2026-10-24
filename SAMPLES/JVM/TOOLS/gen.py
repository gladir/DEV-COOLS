import sys, os, base64
root = sys.argv[1]; out = sys.argv[2]
items = []
for dp, dn, fn in os.walk(root):
    for f in sorted(fn):
        if f.endswith('.class'):
            full = os.path.join(dp, f)
            name = os.path.relpath(full, root)[:-6].replace(os.sep, '/')
            items.append((name, open(full, 'rb').read()))
items.sort()
o = open(out, 'w')
o.write("{ ============================================================================\n  DONNEES : classes compilees de la bibliotheque (base 64)\n  Source Java : SAMPLES/JVM/RT (compilees par JAVAC.PAS)\n  ============================================================================ }\n\n")
per = 40
procs = []
for i in range(0, len(items), per):
    grp = items[i:i+per]
    pn = 'LoadEmb%03d' % (i // per)
    procs.append(pn)
    o.write("Procedure %s;\nBegin\n" % pn)
    for name, data in grp:
        b = base64.b64encode(data).decode().rstrip('=')
        chunks = [b[k:k+240] for k in range(0, len(b), 240)]
        o.write("  EmbAdd('%s',\n" % name)
        o.write(" +\n".join("    '%s'" % c for c in chunks))
        o.write(");\n")
    o.write("End;\n\n")
o.write("Procedure LoadEmbedded;\nBegin\n")
for p in procs: o.write("  %s;\n" % p)
o.write("End;\n")
o.close()
print(len(items), 'classes')
