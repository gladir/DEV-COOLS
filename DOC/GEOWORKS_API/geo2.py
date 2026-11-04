import struct
def u16(d,o): return struct.unpack_from('<H',d,o)[0]
def u32(d,o): return struct.unpack_from('<I',d,o)[0]
class Geode:
    def __init__(self,path):
        d=self.d=open(path,'rb').read()
        assert u32(d,0)==0x53C145C7
        P=248
        self.attr=u16(d,P+34); self.type=u16(d,P+36)
        self.nexp=u16(d,P+82); self.nlib=u16(d,P+84); self.nseg=u16(d,P+88)
        for D in (0,):
            lib=P+96
        self.libs=[]
        for i in range(self.nlib):
            o=lib+i*14
            self.libs.append((d[o:o+8].decode('latin-1').strip('\0 '),u16(d,o+8),u16(d,o+10),u16(d,o+12)))
        exp=lib+self.nlib*14
        self.exports=[(u16(d,exp+i*4+2),u16(d,exp+i*4)) for i in range(self.nexp)]  # (res,ofs)
        st=exp+self.nexp*4; n=self.nseg
        self.segs=[]
        for i in range(n):
            ln=u16(d,st+i*2); pos=u32(d,st+n*2+i*4); fx=u16(d,st+n*6+i*2); fl=u16(d,st+n*8+i*2)
            base=256+pos
            data=d[base:base+ln]
            rl=(ln+15)&~15
            fixes=[(u16(d,base+rl+k*4),u16(d,base+rl+k*4+2)) for k in range(fx//4)]
            self.segs.append(dict(len=ln,pos=base,flags=fl,data=data,fix=fixes))
        self.procclass=(u16(d,P+26),u16(d,P+24)); self.appobj=(u16(d,P+30),u16(d,P+28))
if __name__=='__main__':
    import sys
    g=Geode(sys.argv[1]); print(g.libs, g.exports, g.nseg)
    for i,s in enumerate(g.segs): print(i,hex(s['len']),hex(s['flags']),len(s['fix']))
    seen={}
    for i,s in enumerate(g.segs):
        for t,o in s['fix']:
            seen.setdefault(hex(t),0); seen[hex(t)]+=1
    print(seen)
