import sys, os, random; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
def setup(p,mode=0,col=1,mask=0xFFFF,clip=0):
    p.mw(24,col); p.mw(36,mode); p.mw(34,mask); p.mw(54,clip)
random.seed(3)
masks=[0xFFFF,0x7FFE,0x3FFC,0x1FF8,0x0FF0,0x07E0,0x03C0,0x0180]+[random.randrange(65536) for _ in range(8)]
datas=[random.randrange(65536) for _ in range(16)]
def form(hx,hy,bg,fg):
    return struct.pack(">hhhhh",hx,hy,1,bg,fg)+b''.join(struct.pack('>HH',masks[j],datas[j]) for j in range(16))
# fond a motif : rect 200x40 plein 1 / trame
pat=[0xAAAA,0x5555]*8
patb=b''.join(struct.pack('>H',w) for w in pat)
def bg_pat(x,y): return (pat[y&15]>>(15-(x&15)))&1
for (hx,hy,bg,fg) in [(2,3,0,1),(0,0,1,0),(15,15,0,0),(8,8,1,1)]:
    p=P(); setup(p); po=p.d(patb); p.mlp(46,po); p.mw(50,15)
    p.mw(38,80);p.mw(40,40);p.mw(42,200);p.mw(44,100);p.op(5)       # fond en damier
    fm=p.d(form(hx,hy,bg,fg)); sv=p.d(bytes(100))
    p.d0d1(100,60); p.a0(fm); p.a2(sv); p.op(13)
    s1=run(p,'sp1')
    # reference
    x0,y0=100-hx,60-hy; ok=True
    for j in range(16):
        for i in range(16):
            m=(masks[j]>>(15-i))&1; d=(datas[j]>>(15-i))&1
            e=(fg if d else bg) if m else bg_pat(x0+i,y0+j)
            if s1.px(x0+i,y0+j)!=e: ok=False
    check('A00D lutin hot=(%d,%d) bg=%d fg=%d'%(hx,hy,bg,fg),ok,s1.art(x0-1,y0-1,18,18) if not ok else '')
    # effacement : on retrouve le fond
    p.op(12); s2=run(p,'sp2')
    ok=all(s2.px(x0+i,y0+j)==bg_pat(x0+i,y0+j) for i in range(16) for j in range(16))
    check('A00C effacement du lutin restaure le fond',ok)
# deux lutins superposes puis efface dans l'ordre inverse
p=P(); setup(p); po=p.d(patb); p.mlp(46,po); p.mw(50,15)
p.mw(38,0);p.mw(40,0);p.mw(42,300);p.mw(44,200);p.op(5)
fm=p.d(form(0,0,0,1)); s1=p.d(bytes(100)); s2=p.d(bytes(100))
p.d0d1(50,50); p.a0(fm); p.a2(s1); p.op(13)
p.d0d1(58,54); p.a0(fm); p.a2(s2); p.op(13)
p.a2(s2); p.op(12); p.a2(s1); p.op(12)
s=run(p,'sp3'); ok=all(s.px(x,y)==bg_pat(x,y) for x in range(0,301) for y in range(0,201))
check('A00D/A00C deux lutins superposes effaces en ordre inverse',ok)
# lutin clippe sur le bord de l'ecran
p=P(); setup(p); fm=p.d(form(0,0,0,1)); sv=p.d(bytes(100)); p.d0d1(-4,395); p.a0(fm); p.a2(sv); p.op(13)
s=run(p,'sp4'); check('A00D lutin partiellement hors ecran',s.count()>0 and s.count(0,395,12,5)==s.count(),s.count())

# ---- A00E : copie de formulaire raster (CONTRL 0:?, 14 = MFDB source, 18 = dest) ----------------
# source = image 32x8 en memoire, destination = ecran
img=bytes(random.randrange(256) for _ in range(4*8))
def mfdb(addr_off_or_scr,wpx,h,wdwidth,fd=0,pl=1):
    return None
p=P(); setup(p)
im=p.d(img)
# MFDB source (20 octets : addr.l, wpix.w, h.w, wdwidth.w, stand.w, planes.w, 3 reserved)
mf=p.d(bytes(40))
p.data[mf:mf+20]=bytes(4)+struct.pack('>hhhhh',32,8,2,0,1)+bytes(6)
p.dfix.append((mf,im))
p.data[mf+20:mf+40]=struct.pack('>I',SCR)+struct.pack('>hhhhh',640,400,40,0,1)+bytes(6)
ctl=p.d(bytes(40)); p.data[ctl+14:ctl+18]=b'\0'*4; p.data[ctl+18:ctl+22]=b'\0'*4
# CONTRL+14 = adresse du MFDB source (long), +18 = destination
p.data[ctl:ctl+40]=bytes(14)+bytes(4)+bytes(4)+bytes(18)
p.dfix.append((ctl+14,mf)); p.dfix.append((ctl+18,mf+20))
intin=p.d(struct.pack('>H',3))            # mode copie
ptsin=p.d(struct.pack('>hhhhhhhh',0,0,31,7,200,100,231,107))
p.mlp(4,ctl); p.mlp(8,intin); p.mlp(12,ptsin); p.op(14)
s=run(p,'cp')
ok=all(s.px(200+i,100+j)==(img[j*4+(i>>3)]>>(7-(i&7)))&1 for i in range(32) for j in range(8))
check('A00E copie de formulaire raster memoire -> ecran',ok,s.art(198,98,36,12))
# ---- A00F : remplissage par germe -----------------------------------------------------------
p=P(); setup(p)
for (a,b,c,d) in [(100,100,200,100),(200,100,200,180),(200,180,100,180),(100,180,100,100),(100,140,200,140)]:
    p.mw(38,a);p.mw(40,b);p.mw(42,c);p.mw(44,d);p.op(3)
pts=p.d(struct.pack('>hh',150,120)); p.mlp(12,pts); p.mw(24,1)
p.op(15)
s=run(p,'sf')
inside=s.count(101,101,99,39); inside2=s.count(101,141,99,39)
check('A00F remplissage par germe : zone du germe remplie, autre zone intacte',inside==99*39 and inside2==0 and s.count(0,0,100,400)==0 and s.count(201,0,200,400)==0,(inside,inside2))
print('FAILS',FAIL)
