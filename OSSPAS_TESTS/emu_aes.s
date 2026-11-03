	opt	o+
AES	macro	op,ni,no,na
	lea	contrl(pc),a0
	move.w	#\1,(a0)
	move.w	#\2,2(a0)
	move.w	#\3,4(a0)
	move.w	#\4,6(a0)
	clr.w	8(a0)
	lea	pb(pc),a0
	move.l	a0,d1
	move.w	#$C8,d0
	trap	#2
	bsr	keep
	endm
start:
	lea	pb(pc),a0
	lea	contrl(pc),a1
	move.l	a1,(a0)
	lea	global(pc),a1
	move.l	a1,4(a0)
	lea	intin(pc),a1
	move.l	a1,8(a0)
	lea	intout(pc),a1
	move.l	a1,12(a0)
	lea	addrin(pc),a1
	move.l	a1,16(a0)
	lea	addrout(pc),a1
	move.l	a1,20(a0)
	lea	res(pc),a6
	; 1 appl_init
	AES	10,0,1,0
	; 2 appl_getinfo(0)
	lea	intin(pc),a0
	clr.w	(a0)
	AES	130,1,5,0
	; 3 objc_sysvar(1,2,7,9) puis (0,2)
	lea	intin(pc),a0
	move.w	#1,(a0)
	move.w	#2,2(a0)
	move.w	#7,4(a0)
	move.w	#9,6(a0)
	AES	48,4,3,0
	lea	intin(pc),a0
	clr.w	(a0)
	move.w	#2,2(a0)
	AES	48,4,3,0
	; 4 appl_search(0,name) / (1)
	lea	intin(pc),a0
	clr.w	(a0)
	lea	nameb(pc),a1
	lea	addrin(pc),a2
	move.l	a1,(a2)
	AES	18,1,3,1
	lea	intin(pc),a0
	move.w	#1,(a0)
	AES	18,1,3,1
	; 5 scrp_write / scrp_read
	lea	addrin(pc),a2
	lea	scrapin(pc),a1
	move.l	a1,(a2)
	AES	81,0,1,1
	lea	addrin(pc),a2
	lea	scrapout(pc),a1
	move.l	a1,(a2)
	AES	80,0,1,1
	lea	scrapout(pc),a1
	moveq	#0,d0
	move.b	(a1),d0
	lea	intout(pc),a0
	move.w	d0,2(a0)
	move.b	3(a1),d0
	move.w	d0,4(a0)
	bsr	keep
	; 6 shel_wdef / shel_rdef
	lea	addrin(pc),a2
	lea	defcmd(pc),a1
	move.l	a1,(a2)
	lea	defdir(pc),a1
	move.l	a1,4(a2)
	AES	127,0,1,2
	lea	addrin(pc),a2
	lea	outcmd(pc),a1
	move.l	a1,(a2)
	lea	outdir(pc),a1
	move.l	a1,4(a2)
	AES	126,0,1,2
	lea	outcmd(pc),a1
	lea	intout(pc),a0
	moveq	#0,d0
	move.b	(a1),d0
	move.w	d0,2(a0)
	lea	outdir(pc),a1
	move.b	(a1),d0
	move.w	d0,4(a0)
	bsr	keep
	; 7 wind_new, appl_bvset
	AES	109,0,1,0
	AES	16,4,1,0
	; fin : ecrit res dans AESRES.BIN
	clr.w	-(sp)
	pea	fname(pc)
	move.w	#$3C,-(sp)
	trap	#1
	addq.l	#8,sp
	move.w	d0,d7
	lea	res(pc),a1
	move.l	a1,-(sp)
	move.l	#256,-(sp)
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
keep:	lea	intout(pc),a0
	moveq	#7,d2
kp1:	move.w	(a0)+,(a6)+
	dbra	d2,kp1
	rts
fname:	dc.b	'AESRES.BIN',0
nameb:	ds.b	16
scrapin:	dc.b	'C:\SCRAP',0
scrapout:	ds.b	32
defcmd:	dc.b	'DESK.PRG',0
defdir:	dc.b	'C:\',0
outcmd:	ds.b	32
outdir:	ds.b	32
	even
pb:	ds.l	6
contrl:	ds.w	5
global:	ds.w	16
intin:	ds.w	16
intout:	ds.w	16
addrin:	ds.l	4
addrout:	ds.l	4
res:	ds.b	320
