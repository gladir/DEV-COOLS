import os,sys,re
import os
S=os.environ['WORK']
MODE=sys.argv[1]; R=f'{S}/runs_{MODE}'
def read(p):
    try: return open(p,'rb').read()
    except: return None
def norm_screen(b):
    if b is None: return None
    return b'\n'.join(l.rstrip(b'\r ') for l in b.split(b'\n')).strip(b'\n')
RE_ERR=re.compile(rb"(Runtime error|Erreur d'execution) (\d+) (at|a) [0-9A-F]{4}:[0-9A-F]{4}\.")
def norm_out(b):
    if b is None: return None
    # "Runtime error 002 at 0000:0191." et "Erreur d'execution 002 a 0000:172A." sont equivalents
    # (meme numero; l'adresse depend du compilateur)
    return RE_ERR.sub(lambda m: b'RUNERR %03d' % int(m.group(2)), b)
names=sorted(set(d.split('_',1)[1] for d in os.listdir(R) if d.startswith('ref_')))
rows=[]
for n in names:
    rd=f'{R}/ref_{n}'; od=f'{R}/our_{n}'
    ro=read(rd+'/OUT.TXT'); rs=read(rd+'/SCREEN.TXT'); rt=os.path.exists(rd+'/TIMEOUT.TXT')
    oo=read(od+'/OUT.TXT'); os_=read(od+'/SCREEN.TXT'); ot=os.path.exists(od+'/TIMEOUT.TXT')
    note=''
    if rt and ot: cls='TIMEOUT_2'
    elif rt: cls='TIMEOUT_REF'
    elif ot: cls='TIMEOUT_OUR'
    elif oo is not None and b"Erreur d'execution" in oo and not (ro is not None and b"Runtime error" in ro): cls='ERREUR_EXEC'
    else:
        so=(norm_out(ro)==norm_out(oo)); ss=(norm_screen(rs)==norm_screen(os_))
        # fichiers produits
        rf={f for f in os.listdir(rd) if f not in ('OUT.TXT','SCREEN.TXT','TIMEOUT.TXT')}
        of={f for f in os.listdir(od) if f not in ('OUT.TXT','SCREEN.TXT','TIMEOUT.TXT')}
        sf=(rf==of) and all(read(f'{rd}/{f}')==read(f'{od}/{f}') for f in rf)
        if not sf: note='fichiers:'+','.join(sorted((rf^of)|{f for f in rf&of if read(f'{rd}/{f}')!=read(f'{od}/{f}')}))
        if so and ss and sf: cls='IDENTIQUE'
        elif so and ss: cls='FICHIER_DIFF'
        elif so: cls='ECRAN_DIFF'
        elif ss: cls='STDOUT_DIFF'
        else: cls='DIFF'
    rows.append((n,cls,len(ro or b''),len(oo or b''),note))
from collections import Counter
c=Counter(r[1] for r in rows)
print('MODE',MODE,'TOTAL',len(rows))
for k,v in sorted(c.items(),key=lambda x:-x[1]): print(f'{k:14s} {v}')
with open(f'{S}/compare_{MODE}.txt','w') as f:
    for r in rows: f.write(f'{r[1]:14s} {r[0]:14s} ref={r[2]} our={r[3]} {r[4]}\n')
