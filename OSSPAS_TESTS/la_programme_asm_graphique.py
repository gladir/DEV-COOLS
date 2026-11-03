# Programme assembleur reel (assemble par DEVPAC.PAS) : demonstration graphique combinant
# lignes a masque, rectangles a motifs et modes, polygones par lignes de balayage, lignes
# horizontales, BITBLT ecran->ecran avec recouvrement, lutins et remplissage par germe.
import sys, os, random; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
random.seed(7)
# ----- donnees -----
LINES=[(0xFFFF,4,4,635,4),(0xF0F0,635,4,635,395),(0xAAAA,635,395,4,395),(0x8888,4,395,4,4),(0xFFFF,30,30,130,90),(0x0F0F,130,30,30,90),(0xFFFF,300,20,380,20)]
PATS=[[0xAAAA,0x5555]*8,[0xF0F0]*8+[0x0F0F]*8,[random.randrange(65536) for _ in range(16)],[(0x8000>>(i%16)) for i in range(16)]]
RECTS=[(k,k,[1,0,1,0][k],20+110*k,110,20+110*k+89,160) for k in range(4)]
POLY1=[(100,190),(200,250),(60,270)]
POLY2=[(300,300),(380,300),(380,360),(340,330),(300,360)]
HL=(20,220,300,16,2)         # x1,x2,y0,n,pattern
BLK=[random.randrange(256) for _ in range(2*16*2)]   # 32x16 : 2 mots/ligne
SPR=[(masks:=random.randrange(65536),random.randrange(65536)) for _ in range(16)]
SPRH=(3,2,0,1)             # hotx,hoty,bg,fg
SPRPOS=[(300+40*k,260+5*k) for k in range(8)]
BOX=[(0xFFFF,440,100,540,100),(0xFFFF,540,100,540,160),(0xFFFF,540,160,440,160),(0xFFFF,440,160,440,100),
     (0xFFFF,470,120,500,120),(0xFFFF,500,120,500,140),(0xFFFF,500,140,470,140),(0xFFFF,470,140,470,120)]
SEED=(450,110)
def dcw(vs): return '\tdc.w\t'+','.join(str(v) if v<32768 and v>=0 else '$%X'%(v&0xFFFF) for v in vs)+'\n'
def table(rows): return ''.join(dcw(r) for r in rows)
src='''	opt	o+
start:	dc.w	$A000
	movea.l	a0,a5
	clr.w	36(a5)
	clr.w	54(a5)
	move.w	#1,24(a5)
; --- lignes
	lea	lines(pc),a3
	moveq	#%d,d7
	bsr	dolines
; --- rectangles a motif
	lea	rects(pc),a3
	moveq	#%d,d7
r1:	clr.l	46(a5)
	clr.w	36(a5)
	move.w	#1,24(a5)
	move.w	6(a3),38(a5)
	move.w	8(a3),40(a5)
	move.w	10(a3),42(a5)
	move.w	12(a3),44(a5)
	dc.w	$A005
	move.w	(a3),d0
	asl.w	#5,d0
	lea	pats(pc),a0
	adda.w	d0,a0
	move.l	a0,46(a5)
	move.w	#15,50(a5)
	move.w	2(a3),36(a5)
	move.w	4(a3),24(a5)
	dc.w	$A005
	lea	14(a3),a3
	dbra	d7,r1
	clr.l	46(a5)
	clr.w	36(a5)
	move.w	#1,24(a5)
; --- polygones
	lea	poly1(pc),a3
	bsr	dopoly
	lea	poly2(pc),a3
	bsr	dopoly
; --- lignes horizontales avec motif 2
	lea	pats+64(pc),a0
	move.l	a0,46(a5)
	move.w	#15,50(a5)
	moveq	#%d,d7
	move.w	#%d,d6
hl:	move.w	#%d,38(a5)
	move.w	#%d,42(a5)
	move.w	d6,40(a5)
	move.w	d7,d0
	and.w	#1,d0
	move.w	d0,d1
	add.w	d0,d0
	add.w	d1,d0
	move.w	d0,36(a5)
	dc.w	$A004
	addq.w	#1,d6
	dbra	d7,hl
	clr.l	46(a5)
	clr.w	36(a5)
; --- BITBLT
	lea	-80(sp),sp
	movea.l	sp,a6
	move.w	#32,(a6)
	move.w	#16,2(a6)
	move.w	#1,4(a6)
	move.w	#1,6(a6)
	clr.w	8(a6)
	move.l	#$03030303,10(a6)
	clr.w	14(a6)
	clr.w	16(a6)
	lea	blksrc(pc),a0
	move.l	a0,18(a6)
	move.w	#2,22(a6)
	move.w	#4,24(a6)
	clr.w	26(a6)
	move.w	#300,28(a6)
	move.w	#180,30(a6)
	move.l	-34(a5),32(a6)
	move.w	#2,36(a6)
	move.w	#80,38(a6)
	clr.w	40(a6)
	clr.l	42(a6)
	dc.w	$A007
	move.l	-34(a5),18(a6)
	move.w	#2,22(a6)
	move.w	#80,24(a6)
	move.w	#40,(a6)
	moveq	#11,d7
	move.w	#300,d4
	move.w	#180,d5
bl:	move.w	d4,14(a6)
	move.w	d5,16(a6)
	addq.w	#7,d4
	addq.w	#1,d5
	move.w	d4,28(a6)
	move.w	d5,30(a6)
	dc.w	$A007
	dbra	d7,bl
	lea	80(sp),sp
; --- lutins
	lea	-80(sp),sp
	moveq	#7,d7
	move.w	#300,d4
	move.w	#260,d5
sp1:	move.w	d4,d0
	move.w	d5,d1
	lea	sprite(pc),a0
	movea.l	sp,a2
	dc.w	$A00D
	tst.w	d7
	beq.s	sp9
	movea.l	sp,a2
	dc.w	$A00C
sp9:	add.w	#40,d4
	addq.w	#5,d5
	dbra	d7,sp1
	lea	80(sp),sp
; --- boite + remplissage par germe
	lea	box(pc),a3
	moveq	#%d,d7
	bsr	dolines
	lea	seed(pc),a0
	move.l	a0,12(a5)
	move.w	#1,24(a5)
	dc.w	$A00F
	clr.w	-(sp)
	trap	#1
dolines:
dl1:	move.w	(a3)+,34(a5)
	move.w	(a3)+,38(a5)
	move.w	(a3)+,40(a5)
	move.w	(a3)+,42(a5)
	move.w	(a3)+,44(a5)
	dc.w	$A003
	dbra	d7,dl1
	rts
dopoly:	move.l	a3,4(a5)
	lea	8(a3),a0
	move.l	a0,12(a5)
	move.w	4(a3),d6
	move.w	6(a3),d7
	clr.w	38(a5)
	move.w	#639,42(a5)
pl:	move.w	d6,40(a5)
	dc.w	$A006
	addq.w	#1,d6
	cmp.w	d7,d6
	ble.s	pl
	rts
lines:
'''%(len(LINES)-1,len(RECTS)-1,HL[3]-1,HL[2],HL[0],HL[1],len(BOX)-1)
src+=table(LINES)+'rects:\n'+table(RECTS)+'pats:\n'+table(PATS)
for nm,P_ in (('poly1',POLY1),('poly2',POLY2)):
    ys=[y for _,y in P_]
    src+=nm+':\n'+dcw([0,len(P_),min(ys),max(ys)])+''.join(dcw(list(v)) for v in P_)
src+='blksrc:\n'+dcw([(BLK[i]<<8)|BLK[i+1] for i in range(0,len(BLK),2)])
src+='sprite:\n'+dcw([SPRH[0],SPRH[1],1,SPRH[2],SPRH[3]])+''.join(dcw(list(m)) for m in SPR)
src+='box:\n'+table(BOX)+'seed:\n'+dcw(list(SEED))
pp=asm(src,'LAGFX')
s=runprg(pp,'LAGFX')
# ----- reference -----
G=[[0]*640 for _ in range(400)]
def put(x,y,v):
    if 0<=x<640 and 0<=y<400: G[y][x]=v
def bres(x1,y1,x2,y2):
    pts=[];dx=abs(x2-x1);dy=abs(y2-y1);sx=1 if x1<x2 else -1;sy=1 if y1<y2 else -1;err=dx-dy
    while True:
        pts.append((x1,y1))
        if (x1,y1)==(x2,y2): break
        e2=2*err
        if e2>-dy: err-=dy;x1+=sx
        if e2<dx: err+=dx;y1+=sy
    return pts
def dolines_replace(L):
    for (m,a,b,c,d) in L:
        for n,(x,y) in enumerate(bres(a,b,c,d)):
            put(x,y,(m>>(15-(n&15)))&1)
dolines_replace(LINES)
def pbit(pat,x,y): return (pat[y&15]>>(15-(x&15)))&1
def pix(x,y,mode,col,pb):
    if not(0<=x<640 and 0<=y<400): return
    d=G[y][x]
    if mode==0: G[y][x]=col if pb else 0
    elif mode==1: G[y][x]=col if pb else d
    elif mode==2: G[y][x]=d^1 if (pb and col) else d
    else: G[y][x]=col if not pb else d
for (k,mode,col,x1,y1,x2,y2) in RECTS:
    for y in range(y1,y2+1):
        for x in range(x1,x2+1): G[y][x]=1
    for y in range(y1,y2+1):
        for x in range(x1,x2+1): pix(x,y,mode,col,pbit(PATS[k],x,y))
def poly_ref(verts,y):
    xs=[];n=len(verts)
    for i in range(n):
        x1,y1=verts[i];x2,y2=verts[(i+1)%n]
        if (y1<=y<y2) or (y2<=y<y1): xs.append(round(x1+(y-y1)*(x2-x1)/(y2-y1)))
    xs.sort(); out=[]
    for i in range(0,len(xs)-1,2): out+=range(xs[i],xs[i+1]+1)
    return out
for V in (POLY1,POLY2):
    for y in range(min(v[1] for v in V),max(v[1] for v in V)+1):
        for x in poly_ref(V,y): put(x,y,1)
for i in range(HL[3]):
    n=HL[3]-1-i                      # d7 compte a rebours
    y=HL[2]+i; mode=3 if n&1 else 0
    for x in range(HL[0],HL[1]+1): pix(x,y,mode,1,pbit(PATS[2],x,y))
for j in range(16):
    for i in range(32): put(300+i,180+j,(BLK[j*4+(i>>3)]>>(7-(i&7)))&1)
sx,sy=300,180
for k in range(12):
    src_=[[G[sy+j][sx+i] if 0<=sx+i<640 and 0<=sy+j<400 else 0 for i in range(40)] for j in range(16)]
    for j in range(16):
        for i in range(40): put(sx+7+i,sy+1+j,src_[j][i])
    sx+=7;sy+=1
hx,hy,bg,fg=SPRH; x,y=SPRPOS[-1]
for j in range(16):
    for i in range(16):
        m=(SPR[j][0]>>(15-i))&1;d=(SPR[j][1]>>(15-i))&1
        if m: put(x-hx+i,y-hy+j,fg if d else bg)
dolines_replace(BOX)
# remplissage 4-connexe depuis le germe, frontiere = pixels noirs
st=[SEED];seen=set()
if G[SEED[1]][SEED[0]]==0:
    while st:
        x,y=st.pop()
        if (x,y) in seen or not(0<=x<640 and 0<=y<400) or G[y][x]!=0: continue
        seen.add((x,y));st+=[(x+1,y),(x-1,y),(x,y+1),(x,y-1)]
    for x,y in seen: G[y][x]=1
bad=[(x,y) for y in range(400) for x in range(640) if s.px(x,y)!=G[y][x]]
def region(name,x1,y1,x2,y2):
    b=[(x,y) for (x,y) in bad if x1<=x<=x2 and y1<=y<=y2]
    check('programme ASM : '+name,not b,(len(b),b[:4]))
region('lignes a masque',0,0,639,100)
region('rectangles : 4 motifs x 4 modes',0,105,500,165)
region('polygones (triangle, etoile concave)',0,185,400,365)
region('lignes horizontales a motif',15,295,225,320)
region('BITBLT recouvrant (12 iterations)',290,170,440,215)
region('lutins dessines/effaces',290,255,620,300)
region('boite et remplissage par germe',430,90,550,170)
check('programme ASM : ecran entier identique (%d pixels, %d ecarts)'%(sum(map(sum,G)),len(bad)),not bad)
print('FAILS',FAIL)
