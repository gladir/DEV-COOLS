import struct, subprocess, os, sys
import tempfile
BIN=os.path.abspath(os.environ.get('OSSPAS_BIN','./OSSPAS'))      # executable compile depuis OSSPAS.PAS
WORK=os.environ.get('OSSPAS_TMP',tempfile.gettempdir()+'/osspas_lineA')
os.makedirs(WORK,exist_ok=True)
SCR=0xF8000
class P:
    def __init__(s):
        s.code=bytearray(); s.rel=[]; s.data=bytearray(); s.fix=[]   # fix: (codepos, dataoffset)
        s.dfix=[]                                                      # dfix: (dataoff, dataoff2) pointer inside data
        s.w(0xA000); s.w(0x2A48)  # movea.l a0,a5
    def w(s,x): s.code+=struct.pack('>H',x&0xFFFF)
    def l(s,x): s.code+=struct.pack('>I',x&0xFFFFFFFF)
    def mw(s,off,val): s.w(0x3B7C); s.w(val); s.w(off)
    def ml(s,off,val): s.w(0x2B7C); s.l(val); s.w(off)
    def mlp(s,off,doff):           # long = pointer to data offset
        s.w(0x2B7C); s.rel.append(len(s.code)); s.fix.append((len(s.code),doff)); s.l(0); s.w(off)
    def op(s,n): s.w(0xA000|n)
    def d(s,b):                    # add data (bytes), return offset
        if len(s.data)%2: s.data+=b'\0'
        o=len(s.data); s.data+=bytes(b); return o
    def a6(s,doff):                # move.l #data,a6
        s.w(0x2C7C); s.rel.append(len(s.code)); s.fix.append((len(s.code),doff)); s.l(0)
    def a2(s,doff):
        s.w(0x247C); s.rel.append(len(s.code)); s.fix.append((len(s.code),doff)); s.l(0)
    def a0(s,doff):
        s.w(0x207C); s.rel.append(len(s.code)); s.fix.append((len(s.code),doff)); s.l(0)
    def d0d1(s,x,y):
        s.w(0x303C); s.w(x); s.w(0x323C); s.w(y)    # move.w #x,d0 ; move.w #y,d1
    def build(s):
        c=bytearray(s.code)+struct.pack('>HHH',0x3F3C,0,0x4E41)     # Pterm0
        if len(c)%2: c.append(0)
        base=len(c); data=bytearray(s.data)
        for pos,doff in s.fix: c[pos:pos+4]=struct.pack('>I',base+doff)
        for dpos,doff in s.dfix: data[dpos:dpos+4]=struct.pack('>I',base+doff)
        img=c+data
        rels=sorted(s.rel+[base+p for p in [x[0] for x in s.dfix]])
        tab=bytearray(); last=0
        for i,r in enumerate(rels):
            d=r-last
            if i==0: tab+=struct.pack('>I',r)
            else:
                while d>254: tab.append(1); d-=254
                tab.append(d)
            last=r
        tab.append(0) if rels else None
        if not rels: tab=bytearray(struct.pack('>I',0))
        hdr=struct.pack('>HIIIIIIH',0x601A,len(img),0,0,0,0,0,0)
        return hdr+bytes(img)+bytes(tab)
def run(p,name='T',dump=None):
    s=_run(p,name,dump)
    if dump:
        try: s.dump=open(''+WORK+'/%s.dmp'%name,'rb').read()
        except: s.dump=b''
    return s
def _run(p,name,dump):
    path=''+WORK+'/%s.PRG'%name
    open(path,'wb').write(p.build())
    env=dict(os.environ,DISPLAY=os.environ.get('DISPLAY',':99'),OSSDUMPSCR=''+WORK+'/%s.scr'%name,OSSTIMEOUT='15')
    if dump: env['OSSDUMP']=dump+':'+WORK+'/%s.dmp'%name
    try: os.remove(env['OSSDUMPSCR'])
    except: pass
    import time
    pr=subprocess.Popen([BIN,'/R',path],env=env,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,cwd=WORK)
    t0=time.time()
    while time.time()-t0<30:
        if os.path.exists(env['OSSDUMPSCR']) and os.path.getsize(env['OSSDUMPSCR'])==32000:
            time.sleep(0.3); break
        time.sleep(0.1)
    pr.kill(); pr.wait()
    return Scr(open(env['OSSDUMPSCR'],'rb').read())
class Scr:
    def __init__(s,b): s.b=b
    def px(s,x,y):
        if x<0 or y<0 or x>=640 or y>=400: return 0
        return (s.b[y*80+(x>>3)]>>(7-(x&7)))&1
    def box(s,x,y,w,h): return [[s.px(x+i,y+j) for i in range(w)] for j in range(h)]
    def count(s,x=0,y=0,w=640,h=400): return sum(sum(r) for r in s.box(x,y,w,h))
    def art(s,x,y,w,h): return '\n'.join(''.join('#' if v else '.' for v in r) for r in s.box(x,y,w,h))
