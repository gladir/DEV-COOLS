import json,re,collections
from geo2 import *
from capstone import *
rows=json.load(open('api_rows.json'))
libs={'geos':0,'ui':1,'ansic':2}
names={}
for lib,o,n,c,s,r in rows:
    names[(lib,o)]=(n,sum(4 if ch=='d' else 2 for ch in s) if s!='?' else None)
md=Cs(CS_ARCH_X86,CS_MODE_16); md.detail=False
def run(path):
    g=Geode(path); res=collections.defaultdict(collections.Counter)
    for ri,s in enumerate(g.segs):
        if s['flags']&8 or ri==0 or not s['data']: continue
        d=s['data']
        fixes={o:t for t,o in s['fix'] if t&0xFF==0x14}
        pend=0
        for i in md.disasm(d,0):
            m=i.mnemonic
            if m=='push': pend+=1
            elif m=='pusha': pend+=8
            elif m=='pop' : pend=max(0,pend-1)
            elif m=='lcall':
                off=i.address+1
                if off in fixes:
                    t=fixes[off]; lib=g.libs[t>>8][0] if (t>>8)<len(g.libs) else '?'
                    o=u16(d,off)
                    nm=names.get((lib,o))
                    if nm: res[(lib,o,nm[0],nm[1])][pend*2]+=1
                pend=0
            elif m in('call','ret','retf','jmp','leave','enter'): 
                if m=='call': pend=0
                if m in ('ret','retf','leave','enter'): pend=0
    return res
for p in ('/tmp/claude-0/-home-user-DEV-COOLS/d14758fa-c84e-5d0d-97e6-451c5c1b82fe/scratchpad/graphs/GRAPH.GEO','/tmp/gz/INSTFE.GEO'):
    print(p.split('/')[-1])
    for k,v in sorted(run(p).items(),key=lambda x:x[0][1]): print('  ',k,dict(v))
