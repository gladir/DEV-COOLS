# Programme assembleur reel (assemble par DEVPAC.PAS) : affichage de chaines avec TEXTBLT,
# en lisant l'en-tete de police et la table des decalages comme le font les vrais programmes.
import sys, os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
src_t=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'la_textblt.py')).read().split('# --- sans effet')[0]
exec(src_t.replace("import sys, os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))",""))
TXT='Hello, World! 0123 gjpqy AVWX'
ENT=[ # style, wt, lite, skew, roff, loff, x, y
 (0,1,0x5555,0x5555,0,0,8,8),(1,1,0x5555,0x5555,0,0,8,28),(1,3,0x5555,0x5555,0,0,8,48),(2,1,0x5555,0x5555,0,0,8,68),
 (2,1,0x8888,0x5555,0,0,8,88),(4,1,0x5555,0x5555,8,0,8,108),(8,1,0x5555,0x5555,0,0,8,128),(16,1,0x5555,0x5555,0,0,8,148),
 (32,1,0x5555,0x5555,0,0,8,168),(1|4|8,2,0x5555,0x5555,8,0,8,188),(1|2|16,1,0x5555,0x5555,0,0,8,208),(63,2,0x5555,0x5555,8,0,8,232)]
lines=[]
for e in ENT:
    lines.append('\tdc.w\t'+','.join(('$%X'%v if i in (2,3) else str(v)) for i,v in enumerate(e)))
    lines.append("\tdc.b\t'%s',0\n\teven"%TXT)
src='''	opt	o+
start:	dc.w	$A000
	movea.l	a0,a5
	movea.l	8(a1),a4
	move.l	76(a4),84(a5)
	move.w	80(a4),88(a5)
	move.w	82(a4),82(a5)
	clr.w	74(a5)
	move.w	#1,106(a5)
	clr.w	114(a5)
	clr.w	36(a5)
	clr.w	54(a5)
	clr.w	102(a5)
	lea	table(pc),a3
next:	move.w	(a3)+,d6
	bmi	done
	move.w	d6,90(a5)
	move.w	(a3)+,96(a5)
	move.w	(a3)+,92(a5)
	move.w	(a3)+,94(a5)
	move.w	(a3)+,98(a5)
	move.w	(a3)+,100(a5)
	move.w	(a3)+,d4
	move.w	(a3)+,78(a5)
	moveq	#0,d5
	btst	#0,d6
	beq.s	nb
	add.w	96(a5),d5
nb:	btst	#2,d6
	beq.s	ns
	add.w	98(a5),d5
ns:
chr:	moveq	#0,d0
	move.b	(a3)+,d0
	beq.s	eos
	movea.l	72(a4),a2
	add.w	d0,d0
	move.w	(a2,d0.w),d1
	move.w	2(a2,d0.w),d2
	sub.w	d1,d2
	move.w	d1,72(a5)
	move.w	d2,80(a5)
	move.w	d4,76(a5)
	dc.w	$A008
	add.w	d2,d4
	add.w	d5,d4
	bra.s	chr
eos:	move.l	a3,d0
	addq.l	#1,d0
	bclr	#0,d0
	movea.l	d0,a3
	bra	next
done:	clr.w	-(sp)
	trap	#1
table:
'''+'\n'.join(lines)+'\n\tdc.w\t-1\n'
pp=asm(src,'LATEXT')
s=runprg(pp,'LATEXT')
# reference
ref={}
for (st,wt,lite,skew,roff,loff,x,y) in ENT:
    cx=x
    for ch in TXT:
        c=ord(ch)
        cur,ofs=eff(glyph(c),st,wt,lite,skew,roff,loff)
        wte=wt if st&1 else 0
        exl=-loff-(1 if st&16 else 0); exr=8+wte+roff+(1 if st&16 else 0)+(1 if st&32 else 0)
        for q,v in place(cur,ofs,cx,y).items():
            if exl<=q[0]-cx<exr and y<=q[1]<y+16: ref[q]=v
        cx+=8+(wt if st&1 else 0)+(roff if st&4 else 0)
bad=[(x,y,v) for (x,y),v in ref.items() if 0<=x<640 and 0<=y<400 and s.px(x,y)!=v]
out=s.count()-sum(v for (x,y),v in ref.items() if 0<=x<640 and 0<=y<400 and v)
check('programme ASM : 12 lignes de texte avec effets (%d points compares)'%len(ref),not bad and out==0,(bad[:5],out))
if bad or out: print(s.art(0,0,200,120))
print('FAILS',FAIL)
if bad:
    from collections import Counter
    print(Counter((y-8)//20 for x,y,v in bad))
    print(Counter(x//16 for x,y,v in bad if 8<=y<28).most_common(5))
