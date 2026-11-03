# Test d'instructions du 68000 : un programme assembleur (assemble par DEVPAC.PAS) applique des centaines
# d'instructions a des operandes varies et range D0 et le CCR apres chacune dans un fichier. Le fichier est
# compare entre emulateurs (OSSPAS_EMU=osspas|devpac|devenv) a une reference calculee en Python (modele
# independant de chaque instruction : resultat et indicateurs X N Z V C).
import sys, os, struct; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
MASK={'b':0xFF,'w':0xFFFF,'l':0xFFFFFFFF}; BITS={'b':8,'w':16,'l':32}
def sx(v,sz): 
    b=BITS[sz]; v&=MASK[sz]; return v-(1<<b) if v>>(b-1) else v
def flags_logic(r,sz,x):
    r&=MASK[sz]; return (x<<4)|((r>>(BITS[sz]-1))<<3)|((r==0)<<2)
def f_add(a,b,sz,cin=0,xin=0,zkeep=False,zin=1):
    m=MASK[sz]; a&=m;b&=m; full=a+b+cin; r=full&m
    c=full>m; sa,sb,sr=sx(a,sz),sx(b,sz),sx(r,sz); v=(sa>=0)==(sb>=0) and (sr>=0)!=(sa>=0)
    z=(r==0) if not zkeep else (r==0 and zin)
    return r,(c<<4)|((sr<0)<<3)|(z<<2)|(v<<1)|c
def f_sub(a,b,sz,cin=0,zkeep=False,zin=1):   # a - b - cin
    m=MASK[sz]; a&=m;b&=m; full=a-b-cin; r=full&m
    c=full<0; sa,sb,sr=sx(a,sz),sx(b,sz),sx(r,sz); v=(sa>=0)!=(sb>=0) and (sr>=0)!=(sa>=0)
    z=(r==0) if not zkeep else (r==0 and zin)
    return r,(c<<4)|((sr<0)<<3)|(z<<2)|(v<<1)|c
VALS=[0,1,0x7F,0x80,0xFF,0x7FFF,0x8000,0xFFFF,0x12345678,0x7FFFFFFF,0x80000000,0xFFFFFFFF,0xDEADBEEF,0x00010000]
SMALL=[0,1,2,3,7,8,15,16,31,33]
CUR=[0]
cases=[]   # (asm lines, python function -> (d0,ccr))
def add_case(setup,ins,model,d1=None,x=0):
    cases.append((setup,ins,model,d1,x))
for a in VALS:
  for b in (0,1,0x7F,0x80,0xFF,0x1234,0x8000,0xFFFF,0x7FFFFFFF,0x80000000,0xFFFFFFFF,0x12345678):
    for sz in 'bwl':
        for x in (0,1):
            add_case(a,'add.%s d1,d0'%sz,lambda a,b,sz,x:(lambda r:(a&~MASK[sz]|r[0],r[1]))(f_add(a,b,sz)),b,x)
            add_case(a,'sub.%s d1,d0'%sz,lambda a,b,sz,x:(lambda r:(a&~MASK[sz]|r[0],r[1]))(f_sub(a,b,sz)),b,x)
            add_case(a,'cmp.%s d1,d0'%sz,lambda a,b,sz,x:(a,((x<<4)&0)|(f_sub(a,b,sz)[1]&0xF)|(x<<4)),b,x)
        # logique
    for sz in 'bwl':
        add_case(a,'and.%s d1,d0'%sz,lambda a,b,sz,x:((a&~MASK[sz])|((a&b)&MASK[sz]),flags_logic(a&b,sz,x)),b,0)
        add_case(a,'or.%s d1,d0'%sz,lambda a,b,sz,x:((a&~MASK[sz])|((a|b)&MASK[sz]),flags_logic(a|b,sz,x)),b,0)
        add_case(a,'eor.%s d1,d0'%sz,lambda a,b,sz,x:((a&~MASK[sz])|((a^b)&MASK[sz]),flags_logic(a^b,sz,x)),b,0)
        # eor : source Dn -> destination ; ici d1 eor d0
# ADDX / SUBX / NEGX avec X et Z
for a in VALS[:8]:
  for b in (0,1,0xFF,0x8000,0xFFFFFFFF):
    for sz in 'bwl':
      for x in (0,1):
        for zin in (0,1):
            ccr=(x<<4)|(zin<<2)
            add_case(a,'addx.%s d1,d0'%sz,(lambda a,b,sz,x: (lambda r:(a&~MASK[sz]|r[0],r[1]))(f_add(a,b,sz,x,x,True,(CUR[0]>>2)&1))),b,ccr)
            add_case(a,'subx.%s d1,d0'%sz,(lambda a,b,sz,x: (lambda r:(a&~MASK[sz]|r[0],r[1]))(f_sub(a,b,sz,x,True,(CUR[0]>>2)&1))),b,ccr)
# unaires
for a in VALS:
  for sz in 'bwl':
    add_case(a,'neg.%s d0'%sz,lambda a,b,sz,x:(lambda r:(a&~MASK[sz]|r[0],r[1]))(f_sub(0,a,sz)),0,0)
    add_case(a,'not.%s d0'%sz,lambda a,b,sz,x:((a&~MASK[sz])|((~a)&MASK[sz]),flags_logic(~a,sz,x)),0,0)
    add_case(a,'clr.%s d0'%sz,lambda a,b,sz,x:(a&~MASK[sz],0x04|(x<<4)),0,0x1F)
    add_case(a,'tst.%s d0'%sz,lambda a,b,sz,x:(a,flags_logic(a,sz,x)),0,0)
add_case(0x80,'ext.w d0',lambda a,b,sz,x:((a&0xFFFF0000)|(sx(a,'b')&0xFFFF),flags_logic(sx(a,'b'),'w',0)),0,0)
add_case(0x8000,'ext.l d0',lambda a,b,sz,x:(sx(a,'w')&0xFFFFFFFF,flags_logic(sx(a,'w'),'l',0)),0,0)
add_case(0x12345678,'swap d0',lambda a,b,sz,x:(((a>>16)|(a<<16))&0xFFFFFFFF,flags_logic(((a>>16)|(a<<16)),'l',0)),0,0)
# multiplications / divisions
for a in (0,1,0xFFFF,0x8000,0x7FFF,0x12345678,0xFFFFFFFF):
  for b in (0,1,2,0xFFFF,0x8000,0x7FFF,0x1234):
    add_case(a,'mulu.w d1,d0',lambda a,b,sz,x:((a&0xFFFF)*(b&0xFFFF)&0xFFFFFFFF,flags_logic((a&0xFFFF)*(b&0xFFFF),'l',0)&0xE),b,0)
    add_case(a,'muls.w d1,d0',lambda a,b,sz,x:((sx(a,'w')*sx(b,'w'))&0xFFFFFFFF,flags_logic(sx(a,'w')*sx(b,'w'),'l',0)&0xE),b,0)
def divu(a,b,sz,x):
    d=b&0xFFFF
    q=(a&0xFFFFFFFF)//d; r=(a&0xFFFFFFFF)%d
    if q>0xFFFF: return a,0x02
    return ((r<<16)|q),(((q>>15)&1)<<3)|((q==0)<<2)
def divs(a,b,sz,x):
    d=sx(b,'w'); n=sx(a,'l')
    q=abs(n)//abs(d)*(1 if (n<0)==(d<0) else -1); r=n-q*d
    if q>32767 or q<-32768: return a,0x02
    return (((r&0xFFFF)<<16)|(q&0xFFFF)),(((q>>15)&1)<<3)|(((q&0xFFFF)==0)<<2)
for a in (0,1,100,0xFFFF,0x10000,0x7FFFFFFF,0xFFFFFFFF,0x12345678,0x80000000):
  for b in (1,2,3,0xFFFF,0x7FFF,0x8000,0x1234):
    add_case(a,'divu.w d1,d0',divu,b,0)
    add_case(a,'divs.w d1,d0',divs,b,0)
# decalages / rotations par registre et immediat
def shift(kind,a,n,sz,x):
    b=BITS[sz]; m=MASK[sz]; v=a&m; c=None; xx=x
    n&=63
    for _ in range(n):
        if kind in('lsl','asl'): c=(v>>(b-1))&1; v=(v<<1)&m; xx=c
        elif kind=='lsr': c=v&1; v=v>>1; xx=c
        elif kind=='asr': c=v&1; v=(v>>1)|(v&(1<<(b-1))); xx=c
        elif kind=='rol': c=(v>>(b-1))&1; v=((v<<1)|c)&m
        elif kind=='ror': c=v&1; v=(v>>1)|(c<<(b-1))
        elif kind=='roxl': c=(v>>(b-1))&1; v=((v<<1)|xx)&m; xx=c
        elif kind=='roxr': c=v&1; v=(v>>1)|(xx<<(b-1)); xx=c
    r=(a&~m)|v
    if n==0: cflag=(x if kind.startswith('rox') else 0); xout=x
    else: cflag=c; xout=xx if kind not in('rol','ror') else x
    # V pour asl : changement de signe pendant le decalage
    vflag=0
    if kind=='asl' and n>0:
        t=a&m; ch=False
        for _ in range(n):
            nt=(t<<1)&m
            if ((nt^t)>>(b-1))&1: ch=True
            t=nt
        vflag=int(ch)
    return r,(xout<<4)|(((v>>(b-1))&1)<<3)|((v==0)<<2)|(vflag<<1)|(cflag or 0)
for kind in ('lsl','lsr','asl','asr','rol','ror','roxl','roxr'):
  for a in (0,1,0x80,0x8001,0xFF,0x12345678,0x80000000,0xFFFFFFFF):
    for n in (0,1,2,7,8,9,15,16,17,31,33):
      for sz in 'bwl':
        for x in (0,1):
          add_case(a,'%s.%s d1,d0'%(kind,sz),(lambda k:(lambda a,b,sz,x:shift(k,a,b,sz,x)))(kind),n,x<<4)
        if 1<=n<=8: add_case(a,'%s.%s #%d,d0'%(kind,sz,n),(lambda k,n:(lambda a,b,sz,x:shift(k,a,n,sz,0)))(kind,n),0,0)
# operations sur bits (registre) : bset/bclr/bchg/btst
for a in (0,0xFFFFFFFF,0x80000001,0x12345678):
  for n in (0,1,7,8,31,32,33,63):
    def bit(op):
        def f(a,b,sz,x):
            k=b&31; z=((a>>k)&1)==0
            r=a
            if op=='bset': r=a|(1<<k)
            elif op=='bclr': r=a&~(1<<k)
            elif op=='bchg': r=a^(1<<k)
            return r&0xFFFFFFFF,(x<<4)|(z<<2)
        return f
    for op in ('bset','bclr','bchg','btst'):
        add_case(a,'%s d1,d0'%op,bit(op),n,0)
# Scc / DBcc  : Scc selon CCR donne
CC={'t':lambda n,z,v,c:1,'f':lambda n,z,v,c:0,'hi':lambda n,z,v,c:not(c or z),'ls':lambda n,z,v,c:c or z,'cc':lambda n,z,v,c:not c,'cs':lambda n,z,v,c:c,'ne':lambda n,z,v,c:not z,'eq':lambda n,z,v,c:z,
    'vc':lambda n,z,v,c:not v,'vs':lambda n,z,v,c:v,'pl':lambda n,z,v,c:not n,'mi':lambda n,z,v,c:n,'ge':lambda n,z,v,c:n==v,'lt':lambda n,z,v,c:n!=v,'gt':lambda n,z,v,c:(not z) and n==v,'le':lambda n,z,v,c:z or n!=v}
for cc,fn in CC.items():
    for ccr in range(0,32):
        n,z,v,c=(ccr>>3)&1,(ccr>>2)&1,(ccr>>1)&1,ccr&1
        add_case(0x12345600,'s%s d0'%cc,(lambda fn,n,z,v,c,ccr:(lambda a,b,sz,x:((a&~0xFF)|(0xFF if fn(n,z,v,c) else 0),ccr)))(fn,n,z,v,c,ccr),0,ccr)
# EXG / MOVEQ / LEA etc simples
add_case(0x11111111,'exg d0,d1',lambda a,b,sz,x:(b,0),0x22222222,0)
add_case(0,'moveq #-128,d0',lambda a,b,sz,x:(0xFFFFFF80,0x08|(x<<4)),0,0x1F)
add_case(0,'moveq #0,d0',lambda a,b,sz,x:(0,0x04|(x<<4)),0,0x1F)
add_case(0x12345678,'move.b d1,d0',lambda a,b,sz,x:((a&~0xFF)|(b&0xFF),flags_logic(b,'b',0)),0x80,0)
add_case(0x12345678,'move.w d1,d0',lambda a,b,sz,x:((a&~0xFFFF)|(b&0xFFFF),flags_logic(b,'w',0)),0x8000,0)
add_case(0x12345678,'move.l d1,d0',lambda a,b,sz,x:(b,flags_logic(b,'l',0)),0,0)
add_case(0x00FF00FF,'abcd d1,d0',lambda a,b,sz,x:(0x00FF0000|((0xFF+0xFF) if False else 0),0),0,0) if False else None
# au plus 40 cas par mnemonique (regulierement espaces) : le programme tient dans la memoire de l'ST
by={}
for c in cases: by.setdefault(c[1].split()[0],[]).append(c)
cases=[]
for k in sorted(by):
    L=by[k]; step=max(1,len(L)//40)
    cases+=L[::step][:40]
N=len(cases)
lines=['\topt\to+','start:','\tlea\tres,a6']
for i,(a,ins,model,b,ccr) in enumerate(cases):
    lines.append('\tmove.l\t#$%X,d0'%a)
    lines.append('\tmove.l\t#$%X,d1'%(b if b is not None else 0))
    lines.append('\tmove.w\t#$%X,ccr'%ccr)
    lines.append('\t'+ins)
    lines.append('\tmove.w\tsr,d7')
    lines.append('\tand.w\t#$1F,d7')
    lines.append('\tmove.l\td0,(a6)+')
    lines.append('\tmove.w\td7,(a6)+')
if EMU=='devenv':
    # l'emulateur ST d'origine de DEVENV n'a pas de GEMDOS fiable : les resultats sont relus en memoire a la fin
    lines+=['\tclr.w\t-(sp)','\ttrap\t#1',"fname:\tdc.b\t'CPURES.BIN',0",'\teven','res:\tds.b\t%d'%(N*6+16)]
else:
    lines+=['\tclr.w\t-(sp)','\tpea\tfname','\tmove.w\t#$3C,-(sp)','\ttrap\t#1','\taddq.l\t#8,sp','\tmove.w\td0,d7',
        '\tlea\tres,a1','\tmove.l\ta1,-(sp)','\tmove.l\t#%d,-(sp)'%(N*6),'\tmove.w\td7,-(sp)','\tmove.w\t#$40,-(sp)','\ttrap\t#1','\tlea\t12(sp),sp',
        '\tmove.w\td7,-(sp)','\tmove.w\t#$3E,-(sp)','\ttrap\t#1','\taddq.l\t#4,sp','\tclr.w\t-(sp)','\ttrap\t#1',"fname:\tdc.b\t'CPURES.BIN',0",'\teven','res:\tds.b\t%d'%(N*6+16)]
pp=asm('\n'.join(lines)+'\n','CPUTEST')
rp=os.path.join(WORK,'CPURES.BIN')
if os.path.exists(rp): os.remove(rp)
if EMU=='devenv':
    # le chargeur ST de DEVENV place le texte a l'adresse $1100 : la zone de resultats est a la fin du programme
    h=open(pp,'rb').read(28); tl,dl=struct.unpack('>II',h[2:10]); off=tl+dl-(N*6+16)+0x1100
    sc=runprg(pp,'CPUTEST',dump='%X:%d'%(off,N*6)); b=sc.dump
else:
    runprg(pp,'CPUTEST')
    b=open(rp,'rb').read() if os.path.exists(rp) else b''
check('programme termine et fichier ecrit (%d cas, %d octets attendus)'%(N,N*6),len(b)==N*6,len(b))
missing=len(b)<N*6
bad={}
for i,(a,ins,model,bb,ccr) in enumerate(cases):
    if len(b)<(i+1)*6:
        bad.setdefault(ins.split()[0],[]).append(('resultat absent',ins)); continue
    got=struct.unpack('>LH',b[i*6:i*6+6])
    sz=ins.split()[0].split('.')[-1] if '.' in ins.split()[0] else 'l'
    CUR[0]=ccr
    exp=model(a,bb if bb is not None else 0,sz if sz in 'bwl' else 'l',(ccr>>4)&1)
    exp=(exp[0]&0xFFFFFFFF,exp[1]&0x1F)
    if ins.split()[0].startswith(('mulu','muls','divu','divs')): got=(got[0],got[1]&0xE); exp=(exp[0],exp[1]&0xE)
    if ins.split()[0].startswith(('lsl','lsr','asl','asr','rol','ror','roxl','roxr','bset','bclr','bchg','btst','add','sub','cmp','and','or','eor','neg','not','clr','tst','ext','swap','move','exg','s')) is False: pass
    if got!=exp: bad.setdefault(ins.split()[0],[]).append((hex(a),ins,hex(bb or 0),hex(ccr),'attendu',(hex(exp[0]),hex(exp[1])),'obtenu',(hex(got[0]),hex(got[1]))))
groups=sorted(set(c[1].split()[0] for c in cases))
for g in groups:
    check('instruction %s (%d cas)'%(g,sum(1 for c in cases if c[1].split()[0]==g)),g not in bad,(len(bad.get(g,[])),bad.get(g,[None])[0]))
print('FAILS',len(FAIL))
