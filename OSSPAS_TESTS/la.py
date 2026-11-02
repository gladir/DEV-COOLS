import struct, subprocess, os, sys
import tempfile
EMU=os.environ.get('OSSPAS_EMU','osspas')      # 'osspas' ou 'devpac'
BIN=os.path.abspath(os.environ.get('OSSPAS_BIN','./OSSPAS'))      # executable compile depuis OSSPAS.PAS
WORK=os.environ.get('OSSPAS_TMP',tempfile.gettempdir()+'/osspas_lineA')
os.makedirs(WORK,exist_ok=True)
SCR=0xF8000
LAVARS=0x500 if EMU=='devpac' else 0x1F000      # adresse des variables de la ligne A (valeur de A0 apres $A000)
FONTADDR=0x9C00 if EMU=='devpac' else 0x19800     # forme de la police 8x16 (lignes de 256 octets)
class P:
    def __init__(s):
        s.code=bytearray(); s.rel=[]; s.data=bytearray(); s.fix=[]   # fix: (codepos, dataoffset)
        s.dfix=[]                                                      # dfix: (dataoff, dataoff2) pointer inside data
        s.w(0xA000); s.w(0x2A48)  # movea.l a0,a5
        s.w(0x2869); s.w(8)       # movea.l 8(a1),a4 : en-tete de la police 8x16
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
    def scr_ptr(s,off):            # move.l -34(a5),off(a6) : adresse de l'ecran (V_BAS_AD)
        s.w(0x2D6D); s.w(0xFFDE); s.w(off)
    def fontform(s):               # FBASE, FWIDTH d'apres l'en-tete de la police (a4)
        s.w(0x2B6C); s.w(76); s.w(84)       # move.l 76(a4),84(a5)
        s.w(0x3B6C); s.w(80); s.w(88)       # move.w 80(a4),88(a5)
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
DEVPAC=os.path.abspath(os.environ.get('DEVPAC_BIN','./DEVPAC'))   # assembleur compile depuis DEVPAC.PAS
def asm(src,name):
    """assemble un source GenST (DEVPAC.PAS en mode batch) et retourne le chemin du .PRG"""
    sp=WORK+'/%s.S'%name; pp=WORK+'/%s.PRG'%name
    open(sp,'w').write(src)
    if os.path.exists(pp): os.remove(pp)
    r=subprocess.run([DEVPAC,'/B','/ATARIST',sp,'/OUT:'+pp],env=dict(os.environ,DISPLAY=os.environ.get('DISPLAY',':99')),
                     stdin=subprocess.DEVNULL,capture_output=True,timeout=60,cwd=WORK)
    if not os.path.exists(pp):
        raise SystemExit('assemblage en echec :\n'+r.stdout.decode('latin1'))
    return pp
def runprg(pp,name,dump=None,gem=False):
    class Q: pass
    q=Q(); q.path=pp; q.gem=gem
    return run(q,name,dump)
def run(p,name='T',dump=None):
    s=_run(p,name,dump)
    if dump:
        try: s.dump=open(''+WORK+'/%s.dmp'%name,'rb').read()
        except: s.dump=b''
    return s
def _run(p,name,dump):
    path=''+WORK+'/%s.PRG'%name
    if hasattr(p,'path'): path=p.path
    else: open(path,'wb').write(p.build())
    scr=WORK+'/%s.scr'%name
    try: os.remove(scr)
    except: pass
    env=dict(os.environ,DISPLAY=os.environ.get('DISPLAY',':99'))
    if EMU=='devpac':
        # emulateur integre a DEVPAC.PAS : /EMUL (sans interface), ecran initial vierge (/NOGEM)
        cmd=[DEVPAC]+([] if getattr(p,'gem',False) else ['/NOGEM'])+['/EMUL:'+path,'/TIME:20','/SCR:'+scr]
        if dump: cmd.append('/DUMP:'+dump+':'+WORK+'/%s.dmp'%name)
        subprocess.run(cmd,env=env,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,cwd=WORK,timeout=60)
        return Scr(open(scr,'rb').read())
    env.update(OSSDUMPSCR=scr,OSSTIMEOUT='15')
    if dump: env['OSSDUMP']=dump+':'+WORK+'/%s.dmp'%name
    import time
    pr=subprocess.Popen([BIN,'/R',path],env=env,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,cwd=WORK)
    t0=time.time()
    while time.time()-t0<30:
        if os.path.exists(scr) and os.path.getsize(scr)==32000:
            time.sleep(0.3); break
        time.sleep(0.1)
    pr.kill(); pr.wait()
    return Scr(open(scr,'rb').read())
class Scr:
    def __init__(s,b): s.b=b
    def px(s,x,y):
        if x<0 or y<0 or x>=640 or y>=400: return 0
        return (s.b[y*80+(x>>3)]>>(7-(x&7)))&1
    def box(s,x,y,w,h): return [[s.px(x+i,y+j) for i in range(w)] for j in range(h)]
    def count(s,x=0,y=0,w=640,h=400): return sum(sum(r) for r in s.box(x,y,w,h))
    def art(s,x,y,w,h): return '\n'.join(''.join('#' if v else '.' for v in r) for r in s.box(x,y,w,h))
