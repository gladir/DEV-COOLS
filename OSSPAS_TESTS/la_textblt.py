import sys, os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
# police systeme 8x16 telle que la voit un programme (lignes de 256 octets)
p=P(); s=run(p,'fnt',dump='%X:4096'%FONTADDR); FONT=s.dump
assert sum(FONT[65:66])>0 and any(FONT[r*256+65] for r in range(16)), 'police vide : le test serait sans valeur'
def glyph(c): return [[(FONT[r*256+c]>>(7-i))&1 for i in range(8)] for r in range(16)]
def tb(p,c,x,y,style=0,wmode=0,fg=1,bg=0,**kw):
    p.mw(36,wmode); p.mw(54,kw.get('clip',0))
    if 'clipbox' in kw:
        a,b,c2,d=kw['clipbox']; p.mw(56,a);p.mw(58,b);p.mw(60,c2);p.mw(62,d)
    p.fontform()
    p.mw(72,c*8); p.mw(74,0); p.mw(76,x); p.mw(78,y); p.mw(80,8); p.mw(82,16)
    p.mw(90,style); p.mw(92,kw.get('lite',0x5555)); p.mw(94,kw.get('skew',0x5555)); p.mw(96,kw.get('wt',1))
    p.mw(98,kw.get('roff',0)); p.mw(100,kw.get('loff',0)); p.mw(102,kw.get('scale',0)); p.mw(104,kw.get('chup',0))
    p.mw(106,fg); p.mw(114,bg); p.mw(64,kw.get('xdda',0x8000)); p.mw(66,kw.get('inc',0x10000)&0xFFFF); p.mw(68,kw.get('dir',0))
    p.op(8)
def grid(w,h): return [[0]*w for _ in range(h)]
W=40
def eff(g,style,wt=1,lite=0x5555,skew=0x5555,roff=0,loff=0):
    if not style&1: wt=0
    H=len(g); out=[[0]*(W) for _ in range(H)]
    OFS=8
    cur=[[0]*(W+OFS) for _ in range(H)]
    for j in range(H):
        for i in range(8): cur[j][i+OFS]=g[j][i]
    if style&1:
        n=[[0]*(W+OFS) for _ in range(H)]
        for j in range(H):
            for i in range(W+OFS):
                if cur[j][i]:
                    for k in range(0,wt+1):
                        if i+k<W+OFS: n[j][i+k]=1
        cur=n
    if style&2:
        mk=lite
        for j in range(H):
            for i in range(W+OFS):
                if not (mk>>(15-((i-OFS)&15)))&1: cur[j][i]=0
            mk=((mk<<1)|(mk>>15))&0xFFFF
    if style&4:
        mk=skew; sh=roff; n=[[0]*(W+OFS) for _ in range(H)]
        for j in range(H):
            for i in range(W+OFS):
                if cur[j][i] and 0<=i+sh<W+OFS: n[j][i+sh]=1
            if mk&0x8000: sh-=1
            mk=((mk<<1)|(mk>>15))&0xFFFF
        cur=n
    if style&16:
        n=[[0]*(W+OFS) for _ in range(H)]
        for j in range(H):
            for i in range(1,W+OFS-1):
                if not cur[j][i]:
                    n[j][i]=1 if any(0<=j+r<H and cur[j+r][i+c] for r in (-1,0,1) for c in (-1,0,1)) else 0
        cur=n
    if style&32:
        n=[row[:] for row in cur]
        for j in range(1,H):
            for i in range(1,W+OFS):
                if cur[j-1][i-1] and not cur[j][i] and ((i-OFS+j)&1)==0: n[j][i]=1
        cur=n
    if style&8:
        for i in range(W+OFS):
            if i>=OFS-loff and i<OFS+8+wt+roff: cur[H-1][i]=1
    exl=-loff-(1 if style&16 else 0); exr=8+wt+roff+(1 if style&16 else 0)+(1 if style&32 else 0)
    for j in range(H):
        for i in range(W+OFS):
            if not (exl<=i-OFS<exr): cur[j][i]=0
    return cur,OFS
def place(cur,OFS,dx,dy,rot=0,bg=None):
    H=len(cur); pts={}
    for j in range(H):
        for i in range(-OFS,len(cur[0])-OFS):
            if i<0 and False: continue
            v=cur[j][i+OFS]
            if rot==0: q=(dx+i,dy+j)
            elif rot==900: q=(dx+j,dy-i)
            elif rot==1800: q=(dx-i,dy-j)
            else: q=(dx-j,dy+i)
            pts[q]=v
    return pts
def compare(name,s,pts,box,expect_bg_zero=True):
    bad=[]
    for (x,y),v in pts.items():
        if 0<=x<640 and 0<=y<400 and (x,y)!=None:
            if s.px(x,y)!=v: bad.append((x,y,v))
    check(name,not bad,bad[:5])
    return bad
# --- sans effet : le glyphe est exactement celui de la police ------------------
for c in (65,103,0x7e,0xe9):
    p=P(); tb(p,c,100,50); s=run(p,'tb0')
    g=glyph(c)
    check('TEXTBLT sans effet, caractere %d'%c,s.box(100,50,8,16)==g and s.count()==sum(map(sum,g)),s.art(100,50,8,16))
# --- chaque effet seul + combinaisons -------------------------------------------------
cases=[(1,{}),(1,{'wt':3}),(2,{}),(2,{'lite':0x8888}),(4,{'roff':7}),(4,{'roff':8,'loff':0,'skew':0xFFFF}),(8,{}),(8,{'loff':2,'roff':2}),(16,{}),(32,{}),
       (1|8,{}),(1|2,{}),(4|8,{'roff':8}),(16|1,{}),(1|4|8|16|32,{'roff':8}),(2|32,{}),(63,{'roff':8,'wt':2})]
for style,kw in cases:
    p=P(); tb(p,65,100,50,style,**kw); s=run(p,'tbe')
    cur,ofs=eff(glyph(65),style,kw.get('wt',1),kw.get('lite',0x5555),kw.get('skew',0x5555),kw.get('roff',0),kw.get('loff',0))
    pts=place(cur,ofs,100,50)
    bad=compare('TEXTBLT style %2d %s'%(style,kw),s,pts,None)
    if bad: print(s.art(90,48,40,20))
# --- modes d'ecriture et couleurs -----------------------------------------------------
for mode in (0,1,2,3):
  for fg in (1,0):
    p=P()
    # fond noir 24x20
    p.mw(24,1);p.mw(36,0);p.mw(34,0xFFFF);p.mw(54,0);p.mw(38,96);p.mw(40,46);p.mw(42,127);p.mw(44,69);p.op(5)
    tb(p,65,100,50,0,wmode=mode,fg=fg,bg=0); s=run(p,'tbm')
    g=glyph(65); bad=0
    for j in range(16):
        for i in range(8):
            d=1; v=g[j][i]
            if mode==0: e=fg if v else 0
            elif mode==1: e=fg if v else d
            elif mode==2: e=(d^1) if (v and fg) else d
            else: e=fg if not v else d
            if s.px(100+i,50+j)!=e: bad+=1
    check('TEXTBLT mode %d premier plan %d'%(mode,fg),bad==0,bad)
# fond (TEXTBG) en mode remplacement
p=P(); p.mw(24,1);p.mw(36,0);p.mw(34,0xFFFF);p.mw(54,0);p.mw(38,96);p.mw(40,46);p.mw(42,127);p.mw(44,69);p.op(5)
tb(p,65,100,50,0,wmode=0,fg=0,bg=1); s=run(p,'tbbg'); g=glyph(65)
check('TEXTBLT couleur de fond TEXTBG=1, texte 0 (inverse)',all(s.px(100+i,50+j)==(0 if g[j][i] else 1) for j in range(16) for i in range(8)))
# --- clipping ---------------------------------------------------------------------------------
p=P(); tb(p,65,100,50,1|8,clip=1,clipbox=(103,53,106,60)); s=run(p,'tbc')
cur,ofs=eff(glyph(65),9,1); pts=place(cur,ofs,100,50)
exp={q for q,v in pts.items() if v and 103<=q[0]<=106 and 53<=q[1]<=60}
got={(x,y) for x in range(640) for y in range(400) if s.px(x,y)}
check('TEXTBLT clipping',got==exp,(len(got),len(exp)))
# --- rotation ----------------------------------------------------------------------------------------
for rot in (900,1800,2700):
    for style in (0,1|8,4):
        p=P(); tb(p,65,200,200,style,chup=rot,roff=8 if style&4 else 0); s=run(p,'tbr')
        cur,ofs=eff(glyph(65),style,1,roff=8 if style&4 else 0)
        pts=place(cur,ofs,200,200,rot)
        bad=compare('TEXTBLT rotation %d style %d'%(rot,style),s,pts,None)
        if bad and style==0: print(s.art(180,180,40,40))
# la rotation de 90 deg : le glyphe pivote bien (le haut du A pointe a gauche)
p=P(); tb(p,65,200,200,0,chup=900); s=run(p,'tbr9')
print(s.art(196,196,24,20))
# --- echelle (agrandissement x2 : 0=agrandir) -----------------------------------------------------------
p=P(); tb(p,65,100,50,0,scale=1,xdda=0x8000,inc=0x8000,dir=0); s=run(p,'tbs')
print(s.art(98,48,24,40))
print('FAILS',FAIL)
