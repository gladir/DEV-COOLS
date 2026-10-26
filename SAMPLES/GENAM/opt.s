; OPT.S - Options OPT : essayez  genam opt.s  et  genam -O -A opt.s
	OPT	O+,A+,W+
	SECTION	code,CODE
start:
	bra	near		; branche courte (OPT O1)
	moveq	#0,d0
	move.l	#10,d1		; devient MOVEQ
	addq.l	#1,d1
	add.l	#4,d2		; devient ADDQ
	lea	table,a0	; devient lea table(pc),a0 (OPT A+)
	move.l	0(a0),d3	; devient (a0) (OPT O2)
	jsr	near		; devient BSR (OPT O1)
near:
	rts
table:	dc.w	1,2,3,4
