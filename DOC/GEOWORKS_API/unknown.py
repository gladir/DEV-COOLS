import json,collections,sys
from geo2 import *
from capstone import *
rows=json.load(open('api_rows.json'))
known={(l,o) for l,o,*_ in rows}
md=Cs(CS_ARCH_X86,CS_MODE_16)
def scan(path):
    g=Geode(path); res=collections.defaultdict(lambda:collections.Counter()); ret=collections.defaultdict(collections.Counter)
    for ri,s in enumerate(g.segs):
        if s['flags']&8 or ri==0 or not s['data']: continue
        d=s['data']; fixes={o:t for t,o in s['fix'] if t&0xFF==0x14}
        ins=list(md.disasm(d,0)); pend=0
        for k,i in enumerate(ins):
            m=i.mnemonic
            if m=='push': pend+=1
            elif m=='pop': pend=max(0,pend-1)
            elif m=='lcall':
                off=i.address+1
                if off in fixes:
                    t=fixes[off]; lib=g.libs[t>>8][0] if (t>>8)<len(g.libs) else '?'
                    o=u16(d,off)
                    res[(lib,o)][pend*2]+=1
                    # usage du retour : instruction suivante
                    nx=ins[k+1] if k+1<len(ins) else None
                    use='?'
                    if nx:
                        txt=nx.mnemonic+' '+nx.op_str
                        if 'dx' in txt and 'ax' in txt: use='dxax'
                        elif 'ax' in txt or 'al' in txt: use='ax'
                        else: use='none'
                    ret[(lib,o)][use]+=1
                pend=0
            elif m in('call','ret','retf','leave','enter'): pend=0
    return res,ret
P=json.load(open('protos.json'))
if __name__=='__main__':
    allres={}
    for p in sys.argv[1:]:
        r,rt=scan(p)
        for k,v in r.items():
            if k in known: continue
            print(k,'args(mode)=',v.most_common(2),'ret=',rt[k].most_common(2),'n=',sum(v.values()))
