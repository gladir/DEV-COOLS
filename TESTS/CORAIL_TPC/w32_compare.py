#!/usr/bin/env python3
# w32_compare.py MODE : classe les executions de $WORK/runs_MODE (ref_NOM = Free Pascal Win32,
# our_NOM = TPCW32 -CW32) et ecrit $WORK/compare_MODE.txt.
# Normalisations : "Runtime error N at $ADR" (et la trace FPC) -> RUNERR N ; octets non ASCII
# (page de code de la console Wine) -> '?' ; noms de repertoires our_/ref_ du harnais.
import os,sys,re
from collections import Counter
S=os.environ['WORK']; MODE=sys.argv[1]; R=f'{S}/runs_{MODE}'
def read(p):
    try: return open(p,'rb').read()
    except: return None
RE_ERR_FPC=re.compile(rb'Runtime error (\d+) at \$[0-9A-F]{8}\n(?:  \$[0-9A-F]{8}\n)*')
RE_ERR_OUR=re.compile(rb"(Erreur d'execution|Runtime error) (\d+) (a|at) [\$0-9A-F:]+\.?\n?")
def norm(b):
    if b is None: return None
    b=RE_ERR_FPC.sub(lambda m: b'RUNERR %d\n' % int(m.group(1)), b)
    b=RE_ERR_OUR.sub(lambda m: b'RUNERR %d\n' % int(m.group(2)), b)
    b=re.sub(rb'[\x80-\xff]+', b'?', b)
    b=re.sub(rb'([\\/])our_', rb'\1ref_', b)
    return b'\n'.join(l.rstrip() for l in b.split(b'\n')).strip(b'\n')
names=sorted(set(d.split('_',1)[1] for d in os.listdir(R) if d.startswith('ref_')))
rows=[]
for n in names:
    rd=f'{R}/ref_{n}'; od=f'{R}/our_{n}'
    if not os.path.isdir(od): rows.append((n,'NON_COMPILE',0,0,'')); continue
    ro=read(rd+'/OUT.TXT'); oo=read(od+'/OUT.TXT')
    rt=os.path.exists(rd+'/TIMEOUT.TXT'); ot=os.path.exists(od+'/TIMEOUT.TXT')
    note=''
    if rt and ot: cls='TIMEOUT_2'
    elif rt: cls='TIMEOUT_REF'
    elif ot: cls='TIMEOUT_OUR'
    else:
        so=(norm(ro)==norm(oo))
        skip={'OUT.TXT','OUT.RAW','OUT_SCREEN.TXT','ERR.TXT','RC.TXT','TIMEOUT.TXT'}
        rf={f for f in os.listdir(rd) if f not in skip}; of={f for f in os.listdir(od) if f not in skip}
        sf=(rf==of) and all(read(f'{rd}/{f}')==read(f'{od}/{f}') for f in rf)
        if not sf: note='fichiers:'+','.join(sorted((rf^of)|{f for f in rf&of if read(f'{rd}/{f}')!=read(f'{od}/{f}')}))
        if so and sf: cls='IDENTIQUE'
        elif so: cls='FICHIER_DIFF'
        elif oo is not None and b'RUNERR' in norm(oo) and (ro is None or b'RUNERR' not in norm(ro)): cls='ERREUR_EXEC'
        else: cls='SORTIE_DIFF'
    rows.append((n,cls,len(ro or b''),len(oo or b''),note))
c=Counter(r[1] for r in rows)
print('MODE',MODE,'TOTAL',len(rows))
for k,v in sorted(c.items(),key=lambda x:-x[1]): print(f'{k:14s} {v}')
with open(f'{S}/compare_{MODE}.txt','w') as f:
    for r in rows: f.write(f'{r[1]:14s} {r[0]:14s} ref={r[2]} our={r[3]} {r[4]}\n')
