import re,sys
from geo2 import *
from calls import calls
G='/tmp/claude-0/-home-user-DEV-COOLS/d14758fa-c84e-5d0d-97e6-451c5c1b82fe/scratchpad/graphs/'
names=set(open('/tmp/gx/cnames.txt').read().split())
def bin_funcs(g):
    c=calls(g); out=[]
    for ri,s in enumerate(g.segs):
        if s['flags']&8 or ri==0: continue
        d=s['data']
        starts=[m.start() for m in re.finditer(b'\x55\x8b\xec',d)]
        # c'est approximatif: aussi 'enter' non gere
        for k,st in enumerate(starts):
            en=starts[k+1] if k+1<len(starts) else len(d)
            seq=[(l,o) for (r,off,l,o,_) in c if r==ri and st<=off<en]
            out.append((ri,st,en,seq))
    return out
def src_funcs(f):
    t=open(G+f,encoding='latin-1').read()
    t=re.sub(r'/\*.*?\*/','',t,flags=re.S); t=re.sub(r'//.*','',t)
    res=[]
    # fonctions : ligne commencant par type ... nom( ... ) { au niveau 0
    i=0;depth=0;start=None
    toks=list(re.finditer(r'[{}]',t))
    for m in toks:
        if m.group()=='{':
            if depth==0:
                # retrouver l'en-tete
                hdr=t[max(0,m.start()-300):m.start()]
                hdr=hdr.split(';')[-1].split('}')[-1]
                mm=re.findall(r'([A-Za-z_@][A-Za-z0-9_]*)\s*\(',hdr)
                nm=mm[-1] if mm else '?'
                start=(m.end(),nm)
            depth+=1
        else:
            depth-=1
            if depth==0 and start:
                body=t[start[0]:m.start()]
                seq=[]
                for x in re.finditer(r'(@call|@send|@callsuper|@record|\b[A-Za-z_][A-Za-z0-9_]*)\s*\(?',body):
                    w=x.group(1)
                    if w in ('@call','@send','@callsuper'): seq.append(w)
                    elif w in names and body[x.end()-1:x.end()]=='(' or (w in names and body[x.end():x.end()+1]=='('): seq.append(w)
                res.append((f,start[1],seq))
                start=None
    return res
if __name__=='__main__':
    g=Geode(G+'GRAPH.GEO')
    bf=bin_funcs(g)
    print(len(bf),'binary funcs')
    for ri,st,en,seq in bf: 
        if seq: print(ri,hex(st),[o for l,o in seq])
    print()
    for f in ['EDGE.C','GRAPH.C','QUEUE.C','STACK.C','SUPPORT.C','VERTEX.C','APPUI.GOC','DOCUMENT.GOC','PRIMARY.GOC','PROCESS.GOC','VIEW.GOC']:
        for fn,nm,seq in src_funcs(f):
            if seq: print(fn,nm,seq)
