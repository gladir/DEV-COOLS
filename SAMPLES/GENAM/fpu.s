; FPU.S - Coprocesseur 68881/68882 et MMU
;   genam -68020 fpu.s
;
	MC68020
	MC68881

	SECTION	fpu,CODE
start:
	fmove.d	#3.14159265358979,fp0	; pi (double)
	fmove.l	#2,fp1
	fmul.x	fp1,fp0			; fp0 = 2 * pi
	fsqrt.x	fp0			; racine carree
	fmovecr	#0,fp2			; constante ROM (pi)
	fadd.x	fp2,fp0
	fcmp.x	fp1,fp0
	fbgt	.plus
	fneg.x	fp0
.plus:
	fmove.d	fp0,result
	fmovem.x	fp0-fp3,-(sp)
	fmovem.x	(sp)+,fp0-fp3
	fmove.l	fpsr,d0
	rts

; --- MMU 68030 : activer la table de pages ---
	MC68030
setmmu:
	pmove	(a0),crp
	pmove	(a1),tc
	pflusha
	rts

	SECTION	fpudata,DATA
result:	dc.d	0.0
single:	dc.s	1.5,-2.25
ext:	dc.x	1.0
	EVEN
