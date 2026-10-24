import sys, os
src, outdir = sys.argv[1], sys.argv[2]
cur = None; buf = []
def flush():
    global cur, buf
    if cur:
        p = os.path.join(outdir, cur)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, 'w').write(''.join(buf))
    buf = []
for line in open(src):
    if line.startswith('//== '):
        flush(); cur = line[5:].strip()
    else:
        buf.append(line)
flush()
