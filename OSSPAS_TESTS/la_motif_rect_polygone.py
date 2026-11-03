import sys, os, random; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
def setup(p,mode=0,col=1,mask=0xFFFF,clip=0):
    p.mw(24,col); p.mw(36,mode); p.mw(34,mask); p.mw(54,clip)
random.seed(5)
pat=[random.randrange(65536) for _ in range(16)]
patb=b''.join(struct.pack('>H',w) for w in pat)
def pbit(x,y,pm=15): return (pat[y&pm]>>(15-(x&15)))&1

# ---- A005 rectangle pleine avec motif ---------------------------------------
for pm in (15,7,3,0):
    p=P(); setup(p); po=p.d(patb); p.mlp(46,po); p.mw(50,pm); p.mw(52,0)
    p.mw(38,37);p.mw(40,21);p.mw(42,150);p.mw(44,70);p.op(5)
    s=run(p,'rc')
    ok=all(s.px(x,y)==pbit(x,y,pm) for x in range(37,151) for y in range(21,71))
    out=s.count()-s.count(37,21,114,50)
    check('A005 rectangle + motif PATMSK=%d'%pm,ok and out==0,(out,))
# sans motif (PATPTR=0) : plein
p=P(); setup(p); p.mw(38,10);p.mw(40,10);p.mw(42,29);p.mw(44,19);p.op(5); s=run(p,'rp')
check('A005 sans motif = plein',s.count()==20*10,s.count())
# y1>y2, x1>x2 
p=P(); setup(p); p.mw(38,29);p.mw(40,19);p.mw(42,10);p.mw(44,10);p.op(5); s=run(p,'ri')
check('A005 coins inverses',s.count()==200,s.count())
# modes d'ecriture avec motif
for mode in (0,1,2,3):
  for col in (1,0):
    p=P(); setup(p,col=1)
    p.mw(38,0);p.mw(40,0);p.mw(42,63);p.mw(44,31);p.op(5)       # fond noir 64x32
    p.mw(36,mode); p.mw(24,col); po=p.d(patb); p.mlp(46,po); p.mw(50,15)
    p.mw(38,0);p.mw(40,0);p.mw(42,63);p.mw(44,31);p.op(5)
    s=run(p,'rm')
    def ref(x,y):
        d=1;pb=pbit(x,y)
        if mode==0: return col if pb else 0
        if mode==1: return col if pb else d
        if mode==2: return d^1 if (pb and col) else d
        return col if not pb else d
    bad=[(x,y) for x in range(64) for y in range(32) if s.px(x,y)!=ref(x,y)]
    check('A005 mode %d couleur %d'%(mode,col),not bad,bad[:4])
# clipping rectangle
p=P(); setup(p,clip=1); p.mw(56,100);p.mw(58,50);p.mw(60,119);p.mw(62,59)
p.mw(38,90);p.mw(40,40);p.mw(42,200);p.mw(44,100);p.op(5)
s=run(p,'rcl'); check('A005 clipping',s.count()==20*10 and s.count(100,50,20,10)==200,s.count())
# A004 ligne horizontale + motif
p=P(); setup(p); po=p.d(patb); p.mlp(46,po); p.mw(50,15)
p.mw(38,5);p.mw(42,200);p.mw(40,7);p.op(4)
p.mw(38,300);p.mw(42,100);p.mw(40,9);p.op(4)
s=run(p,'hl')
check('A004 ligne horizontale avec motif',all(s.px(x,7)==pbit(x,7) for x in range(5,201)) and s.count(0,7,640,1)==sum(pbit(x,7) for x in range(5,201)))
check('A004 X1>X2 accepte',all(s.px(x,9)==pbit(x,9) for x in range(100,301)))
# ---- A006 polygone : une ligne de balayage -----------------------------------
def poly_ref(verts,y):
    xs=[]
    n=len(verts)
    for i in range(n):
        x1,y1=verts[i];x2,y2=verts[(i+1)%n]
        if (y1<=y<y2) or (y2<=y<y1):
            xs.append(round(x1+(y-y1)*(x2-x1)/(y2-y1)))
    xs.sort(); out=set()
    for i in range(0,len(xs)-1,2):
        out.update(range(xs[i],xs[i+1]+1))
    return out
shapes={'triangle':[(100,100),(200,160),(60,180)],
        'carre':[(300,50),(400,50),(400,120),(300,120)],
        'etoile':[(500,200),(530,290),(450,230),(550,230),(470,290)],
        'concave':[(50,250),(150,250),(150,350),(100,300),(50,350)]}
for nm,v in shapes.items():
    p=P(); setup(p)
    pts=p.d(b''.join(struct.pack('>hh',x,y) for x,y in v))
    ctl=p.d(struct.pack('>hhhhh',0,len(v),0,0,0))
    p.mlp(12,pts); p.mlp(4,ctl)
    ys=[y for _,y in v]
    for y in range(min(ys),max(ys)+1):
        p.mw(40,y); p.mw(38,0); p.mw(42,639); p.op(6)
    s=run(p,'pg_'+nm)
    bad=0
    for y in range(min(ys),max(ys)+1):
        ref=poly_ref(v,y)
        got={x for x in range(640) if s.px(x,y)}
        if ref!=got: bad+=1
    area=0.5*abs(sum(v[i][0]*v[(i+1)%len(v)][1]-v[(i+1)%len(v)][0]*v[i][1] for i in range(len(v))))
    check('A006 polygone %s (lignes fausses: %d, pixels %d, aire geo %.0f)'%(nm,bad,s.count(),area),bad==0)
print('FAILS',FAIL)
