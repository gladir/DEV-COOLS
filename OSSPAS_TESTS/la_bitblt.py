import sys, os, random; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
OPS=[lambda s,d:0,lambda s,d:s&d,lambda s,d:s&(1-d),lambda s,d:s,lambda s,d:(1-s)&d,lambda s,d:d,lambda s,d:s^d,lambda s,d:s|d,
     lambda s,d:1-(s|d),lambda s,d:1-(s^d),lambda s,d:1-d,lambda s,d:s|(1-d),lambda s,d:1-s,lambda s,d:(1-s)|d,lambda s,d:1-(s&d),lambda s,d:1]
def blk(p,w,h,fg,bg,ops,sx,sy,sform,snw,snl,dx,dy,dform,dnw,dnl,paddr=0,pnl=2,pmask=0):
    # sform/dform : ('scr',) ou ('data',off) 
    def fp(f): return 0 if f[0]=='scr' else None
    b=bytearray(struct.pack('>hhhhh',w,h,1,fg,bg)+bytes(ops)+struct.pack('>hh',sx,sy))
    off=p.d(bytes(58))
    sp=[]
    def ptr(pos,f):
        if f[0]=='scr': return struct.pack('>I',SCR)
        p.dfix.append((off+pos,f[1])); return b'\0\0\0\0'
    blkb=bytearray(58)
    blkb[0:14]=struct.pack('>hhhhh',w,h,1,fg,bg)[:10]+bytes(ops)
    blkb[14:18]=struct.pack('>hh',sx,sy)
    blkb[18:22]=ptr(18,sform); blkb[22:28]=struct.pack('>hhh',snw,snl,0)
    blkb[28:32]=struct.pack('>hh',dx,dy)
    blkb[32:36]=ptr(32,dform); blkb[36:42]=struct.pack('>hhh',dnw,dnl,0)
    if paddr: p.dfix.append((off+42,paddr)); 
    blkb[46:50]=struct.pack('>hh',pnl,0); blkb[50:52]=struct.pack('>H',pmask)
    p.data[off:off+58]=blkb
    p.a6(off); p.op(7)
    return off
# --- 16 operations logiques ---------------------------------------------------
p=P()
src=p.d(struct.pack('>HH',0xCCCC,0xCCCC)); dst=p.d(struct.pack('>HH',0xAAAA,0xAAAA))
for op in range(16):
    # fond (copie op=3 depuis dst), puis operation
    blk(p,16,1,1,0,[3,3,3,3],0,0,('data',dst),2,4,0,op*2,('scr',),2,80)
    blk(p,16,1,1,0,[op]*4,0,0,('data',src),2,4,0,op*2,('scr',),2,80)
s=run(p,'bb')
for op in range(16):
    exp=[OPS[op]((0xCCCC>>(15-i))&1,(0xAAAA>>(15-i))&1) for i in range(16)]
    got=[s.px(i,op*2) for i in range(16)]
    check('BITBLT operation %2d'%op,exp==got,(exp,got))
# --- OP_TAB indexe par (fg,bg) -----------------------------------------------
for fg in (0,1):
  for bg in (0,1):
    p=P(); src=p.d(struct.pack('>H',0xCCCC)); dst=p.d(struct.pack('>H',0xAAAA))
    blk(p,16,1,1,0,[3]*4,0,0,('data',dst),2,2,0,0,('scr',),2,80)
    blk(p,16,1,fg,bg,[0,7,6,12],0,0,('data',src),2,2,0,0,('scr',),2,80)
    s=run(p,'bt')
    o=[0,7,6,12][(fg<<1)|bg]
    exp=[OPS[o]((0xCCCC>>(15-i))&1,(0xAAAA>>(15-i))&1) for i in range(16)]
    check('BITBLT OP_TAB fg=%d bg=%d -> op %d'%(fg,bg,o),exp==[s.px(i,0) for i in range(16)])
# --- positions non alignees, largeur quelconque, ecran -> ecran -----------------
random.seed(11)
img=bytes(random.randrange(256) for _ in range(5*4*2))   # 5 mots x 4 lignes
for (w,h,sx,sy,dx,dy) in [(37,4,3,0,100,50),(1,1,0,0,7,7),(80,4,0,0,3,100),(16,3,15,1,17,200),(33,4,0,0,479,300)]:
    p=P(); sa=p.d(img)
    blk(p,80,4,1,0,[3]*4,0,0,('data',sa),2,10,0,0,('scr',),2,80)      # affiche l'image en (0,0)
    blk(p,w,h,1,0,[3]*4,sx,sy,('scr',),2,80,dx,dy,('scr',),2,80)
    s=run(p,'bs')
    ok=all(s.px(dx+i,dy+j)==s.px(sx+i,sy+j) for i in range(w) for j in range(h))
    around=s.count(dx-1,dy-1,w+2,h+2)-sum(s.px(dx+i,dy+j) for i in range(w) for j in range(h))
    edge=all(s.px(dx-1,dy+j)==0 and s.px(dx+w,dy+j)==0 for j in range(h)) if (dx>0 and dx+w<640) else True
    check('BITBLT ecran->ecran %dx%d (%d,%d)->(%d,%d)'%(w,h,sx,sy,dx,dy),ok and edge)
# --- recouvrement (decalage a droite et a gauche, haut et bas) -----------------
for (dx,dy) in [(5,0),(-5,0),(0,2),(0,-2),(7,1),(-9,-1)]:
    p=P(); sa=p.d(img)
    blk(p,80,4,1,0,[3]*4,0,0,('data',sa),2,10,0,100,('scr',),2,80)
    blk(p,70,4,1,0,[3]*4,0,100,('scr',),2,80,10+dx,100+dy,('scr',),2,80)
    s=run(p,'bo')
    # reference : image d'origine
    ref=Scr(b'\0'*32000)
    orig=[[ (img[(j*10)+(i>>3)]>>(7-(i&7)))&1 for i in range(80)] for j in range(4)]
    # le bloc source = orig[0..3][0..69]  -> copie en (10+dx,100+dy)
    ok=all(s.px(10+dx+i,100+dy+j)==orig[j][i] for i in range(70) for j in range(4))
    check('BITBLT recouvrement decalage (%d,%d)'%(dx,dy),ok)
# --- demi-teinte (P_ADDR) : S et P ------------------------------------------------
p=P(); src=p.d(struct.pack('>HH',0xFFFF,0xFFFF)); pt=p.d(struct.pack('>HH',0x8888,0x2222))
blk(p,16,2,1,0,[3]*4,0,0,('data',src),2,2,0,0,('scr',),2,80,paddr=pt,pnl=2,pmask=1)
s=run(p,'bh')
check('BITBLT avec motif de demi-teinte (S ET P)',[s.px(i,0) for i in range(16)]==[ (0x8888>>(15-i))&1 for i in range(16)] and [s.px(i,1) for i in range(16)]==[(0x2222>>(15-i))&1 for i in range(16)],s.art(0,0,16,2))
print('FAILS',FAIL)
