import sys, os, random; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
LA=0x1F000
def setup(p,mode=0,col=1,mask=0xFFFF,clip=0):
    p.mw(24,col); p.mw(36,mode); p.mw(34,mask); p.mw(54,clip)

# ---- 1. pixel : A001 / A002 ------------------------------------------------
p=P(); setup(p)
pts=p.d(b''.join(struct.pack('>hh',x,5) for x in range(10,20)))
col=p.d(struct.pack('>H',1)); col0=p.d(struct.pack('>H',0))
for i in range(10):
    p.mlp(12,pts+4*i); p.mlp(8,col if i<8 else col0); p.op(1)
# lire (x=10..14,y=5)
for i in range(10):
    p.mlp(12,pts+4*i); p.op(2); p.w(0x3B40); p.w(0x100+2*i)
s=run(p,'px',dump='%X:20'%(LAVARS+0x100))
check('A001 pixels poses',all(s.px(10+i,5)==1 for i in range(8)) and s.px(18,5)==0 and s.px(19,5)==0,s.art(8,3,14,5))
got=struct.unpack('>10H',s.dump)
check('A002 lit les pixels',list(got)==[1]*8+[0,0],got)
# pixel en xor deux fois + mode transparent
p=P(); setup(p,mode=2)
pts=p.d(struct.pack('>hhhh',30,30,31,30)); col=p.d(struct.pack('>H',1))
p.mlp(8,col)
p.mlp(12,pts); p.op(1); p.op(1)         # xor x2 -> efface
p.mlp(12,pts+4); p.op(1)                # xor x1
s=run(p,'pxx')
check('A001 mode XOR',s.px(30,30)==0 and s.px(31,30)==1)

# ---- 2. ligne : A003 -------------------------------------------------------
def bres(x1,y1,x2,y2):
    pts=[];dx=abs(x2-x1);dy=abs(y2-y1);sx=1 if x1<x2 else -1;sy=1 if y1<y2 else -1;err=dx-dy
    while True:
        pts.append((x1,y1))
        if (x1,y1)==(x2,y2): break
        e2=2*err
        if e2>-dy: err-=dy;x1+=sx
        if e2<dx: err+=dx;y1+=sy
    return pts
lines=[(10,10,200,10),(10,20,10,120),(20,20,120,120),(300,50,250,200),(100,300,500,310),(400,20,380,300),(50,380,50,380),(600,390,20,200)]
p=P(); setup(p)
for (a,b,c,d) in lines:
    p.mw(38,a);p.mw(40,b);p.mw(42,c);p.mw(44,d);p.op(3)
s=run(p,'ln')
ok=True
tot=0
for (a,b,c,d) in lines:
    n=max(abs(c-a),abs(d-b))+1
    pts=bres(a,b,c,d)
    miss=[q for q in pts if s.px(*q)==0]
    if miss: ok=False;print('  manque',(a,b,c,d),miss[:5])
    tot+=n
check('A003 lignes pleines (extremites, nombre de points, pas de trou)',ok and s.count()<=tot and s.count()>=tot-6,(s.count(),tot))
# masque de ligne, depart au premier point, repetition tous les 16 pixels
for mask in (0xF0F0,0x8001,0xAAAA,0x00FF):
    p=P(); setup(p,mask=mask); p.mw(38,20);p.mw(40,30);p.mw(42,200);p.mw(44,30);p.op(3)
    s=run(p,'lm')
    exp=[(mask>>(15-(i&15)))&1 for i in range(181)]
    got=[s.px(20+i,30) for i in range(181)]
    check('A003 masque %04X'%mask,exp==got)
# sens inverse : le masque part de la 1re extremite
p=P(); setup(p,mask=0xF000); p.mw(38,200);p.mw(40,30);p.mw(42,20);p.mw(44,30);p.op(3)
s=run(p,'lm2'); check('A003 masque part de (X1,Y1) meme vers la gauche',[s.px(200-i,30) for i in range(8)]==[1,1,1,1,0,0,0,0])
# xor deux fois
p=P(); setup(p,mode=2)
for _ in range(2): p.mw(38,20);p.mw(40,40);p.mw(42,120);p.mw(44,90);p.op(3)
s=run(p,'lx'); check('A003 XOR deux fois efface tout',s.count()==0,s.count())
# xor sur zone noire : inverse. ligne remplie dessous
p=P(); setup(p); p.mw(38,20);p.mw(40,40);p.mw(42,120);p.mw(44,40);p.op(3); p.mw(36,2); p.mw(38,50);p.mw(42,150);p.op(3)
s=run(p,'lx2'); check('A003 XOR inverse les pixels existants',s.count(50,40,71,1)==0 and s.count(121,40,30,1)==30 and s.count(20,40,30,1)==30)
# couleur 0 en mode remplace : efface
p=P(); setup(p); p.mw(38,20);p.mw(40,40);p.mw(42,120);p.mw(44,40);p.op(3); p.mw(24,0); p.mw(38,40);p.mw(42,60);p.op(3)
s=run(p,'lc0'); check('A003 couleur 0 efface',s.count(40,40,21,1)==0 and s.count(20,40,20,1)==20)
# masque + mode transparent : trous non effaces
p=P(); setup(p); p.mw(38,20);p.mw(40,40);p.mw(42,120);p.mw(44,40);p.op(3)
p.mw(24,0); p.mw(34,0xFF00); p.mw(36,1); p.mw(38,20);p.mw(42,120);p.op(3)
s=run(p,'ltr'); exp=101-sum(1 for i in range(101) if (0xFF00>>(15-(i&15)))&1)
check('A003 transparent couleur 0 : efface seulement sous les bits du masque',s.count(20,40,101,1)==exp,(s.count(20,40,101,1),exp))
p=P(); setup(p); p.mw(38,20);p.mw(40,40);p.mw(42,120);p.mw(44,40);p.op(3)
p.mw(24,1); p.mw(34,0xFF00); p.mw(36,0); p.mw(38,20);p.mw(42,120);p.op(3)
s=run(p,'lrp'); check('A003 remplacement : trous du masque effaces (fond 0)',s.count(20,40,16,1)==8,s.count(20,40,16,1))
# transparent inverse
p=P(); setup(p,mode=3,mask=0xFF00); p.mw(38,20);p.mw(40,40);p.mw(42,35);p.mw(44,40);p.op(3)
s=run(p,'lrv'); check('A003 transparent inverse trace les trous du masque',[s.px(20+i,40) for i in range(16)]==[0]*8+[1]*8)
# clipping
p=P(); setup(p,clip=1); p.mw(56,100);p.mw(58,100);p.mw(60,200);p.mw(62,150)
for (a,b,c,d) in [(50,50,300,200),(50,125,300,125),(150,20,150,300),(0,0,639,399),(300,300,10,10)]:
    p.mw(38,a);p.mw(40,b);p.mw(42,c);p.mw(44,d);p.op(3)
s=run(p,'lcl')
outside=s.count()-s.count(100,100,101,51)
check('A003 clipping : rien hors fenetre',outside==0,outside)
check('A003 clipping : traits visibles a l\'interieur',s.count(100,100,101,51)>250 and s.px(100,125)==1 and s.px(200,125)==1 and s.px(150,100)==1 and s.px(150,150)==1)
# hors ecran
p=P(); setup(p); p.mw(38,-50);p.mw(40,-20);p.mw(42,700);p.mw(44,500);p.op(3); p.mw(38,-30000);p.mw(42,30000);p.mw(40,10);p.mw(44,10);p.op(3)
s=run(p,'lof'); check('A003 hors ecran ne plante pas, trait visible',s.count()>300,s.count())
print('FAILS',FAIL)
