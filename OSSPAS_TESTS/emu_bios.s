	opt	o+
start:
	lea	res(pc),a6
	; Drvmap
	move.w	#10,-(sp)
	trap	#13
	addq.l	#2,sp
	move.l	d0,(a6)+
	; Setexc(0x101,-1) puis Setexc(0x101,$1234) puis lecture
	move.l	#-1,-(sp)
	move.w	#$101,-(sp)
	move.w	#5,-(sp)
	trap	#13
	addq.l	#8,sp
	move.l	#$1234,-(sp)
	move.w	#$101,-(sp)
	move.w	#5,-(sp)
	trap	#13
	addq.l	#8,sp
	move.l	#-1,-(sp)
	move.w	#$101,-(sp)
	move.w	#5,-(sp)
	trap	#13
	addq.l	#8,sp
	move.l	d0,(a6)+
	; Setcolor(3,$123) puis (3,-1)
	move.w	#$123,-(sp)
	move.w	#3,-(sp)
	move.w	#7,-(sp)
	trap	#14
	addq.l	#6,sp
	move.w	#-1,-(sp)
	move.w	#3,-(sp)
	move.w	#7,-(sp)
	trap	#14
	addq.l	#6,sp
	move.l	d0,(a6)+
	; Gettime : annee
	move.w	#23,-(sp)
	trap	#14
	addq.l	#2,sp
	moveq	#25,d1
	lsr.l	d1,d0
	add.l	#1980,d0
	move.l	d0,(a6)+
	; Iorec(1) : taille du tampon
	move.w	#1,-(sp)
	move.w	#14,-(sp)
	trap	#14
	addq.l	#4,sp
	movea.l	d0,a0
	moveq	#0,d0
	move.w	4(a0),d0
	move.l	d0,(a6)+
	; Kbdvbase : non nul
	move.w	#34,-(sp)
	trap	#14
	addq.l	#2,sp
	tst.l	d0
	sne	d0
	ext.w	d0
	ext.l	d0
	move.l	d0,(a6)+
	; Giaccess ecrit puis lit le registre 3
	move.w	#$83,-(sp)
	move.w	#$55,-(sp)
	move.w	#28,-(sp)
	trap	#14
	addq.l	#6,sp
	move.w	#3,-(sp)
	move.w	#0,-(sp)
	move.w	#28,-(sp)
	trap	#14
	addq.l	#6,sp
	move.l	d0,(a6)+
	; Kbrate
	move.w	#-1,-(sp)
	move.w	#-1,-(sp)
	move.w	#35,-(sp)
	trap	#14
	addq.l	#6,sp
	move.l	d0,(a6)+
	; ecriture
	clr.w	-(sp)
	pea	fname(pc)
	move.w	#$3C,-(sp)
	trap	#1
	addq.l	#8,sp
	move.w	d0,d7
	lea	res(pc),a1
	move.l	a1,-(sp)
	move.l	#64,-(sp)
	move.w	d7,-(sp)
	move.w	#$40,-(sp)
	trap	#1
	lea	12(sp),sp
	move.w	d7,-(sp)
	move.w	#$3E,-(sp)
	trap	#1
	addq.l	#4,sp
	clr.w	-(sp)
	trap	#1
fname:	dc.b	'BXRES.BIN',0
	even
res:	ds.b	128
