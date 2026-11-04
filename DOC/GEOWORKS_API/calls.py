from geo2 import *
import sys,collections
def calls(g):
    """liste (res, ofs_of_call_instr, lib, ordinal) triee"""
    out=[]
    for ri,s in enumerate(g.segs):
        if s['flags']&8: continue   # lmem -> objets
        for t,o in s['fix']:
            if t&0xFF in (0x14,) :
                lib=t>>8; ordn=u16(s['data'],o)
                inst=s['data'][o-1] if o>0 else 0
                out.append((ri,o-1,lib,ordn,inst))
    return sorted(out)
if __name__=='__main__':
    g=Geode(sys.argv[1]); c=calls(g)
    cnt=collections.Counter((l,o) for _,_,l,o,_ in c)
    for lib in range(3):
        ks=sorted(k for k in cnt if k[0]==lib); print(g.libs[lib][0] if lib<len(g.libs) else lib,len(ks),[k[1] for k in ks])
    print(collections.Counter(i for *_,i in c))
