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
	AES	10,0,1,0
	lea	intin(pc),a0
	move.w	#100,(a0)
	move.w	#60,2(a0)
	lea	addrin(pc),a2
	lea	menu(pc),a1
	move.l	a1,(a2)
	lea	menuout(pc),a1
	move.l	a1,4(a2)
	AES	36,2,1,2
	lea	menuout(pc),a1
	lea	intout(pc),a0
	move.w	6(a1),2(a0)
	move.w	4(a1),4(a0)
	bsr	keep
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
keep:	lea	intout(pc),a0
	moveq	#7,d2
kp1:	move.w	(a0)+,(a6)+
	dbra	d2,kp1
	rts
fname:	dc.b	'POPRES.BIN',0
s1:	dc.b	'First item',0
s2:	dc.b	'Second',0
s3:	dc.b	'Disabled',0
	even
tree:	dc.w	-1,1,3,20,0,0
	dc.l	$00021100
	dc.w	0,0,100,48
	dc.w	2,-1,-1,28,0,0
	dc.l	s1
	dc.w	0,0,100,16
	dc.w	3,-1,-1,28,0,0
	dc.l	s2
	dc.w	0,16,100,16
	dc.w	0,-1,-1,28,$20,8
	dc.l	s3
	dc.w	0,32,100,16
menu:	dc.l	tree
	dc.w	0,0,0,0
menuout:	ds.w	8
pb:	ds.l	6
contrl:	ds.w	5
global:	ds.w	16
intin:	ds.w	16
intout:	ds.w	16
addrin:	ds.l	4
addrout:	ds.l	4
res:	ds.b	320
