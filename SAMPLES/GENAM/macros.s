; MACROS.S - Macros, REPT, assemblage conditionnel et structures
	OPT	O+,W+

; --- structure (RS) ---
	RSRESET
node_next	rs.l	1
node_prev	rs.l	1
node_type	rs.b	1
node_pri	rs.b	1
node_name	rs.l	1
node_SIZEOF	rs.b	0

; --- macros ---
PUSHALL	MACRO
	movem.l	d0-d7/a0-a6,-(sp)
	ENDM

POPALL	MACRO
	movem.l	(sp)+,d0-d7/a0-a6
	ENDM

; CLEARMEM adresse,nbre_de_longs
CLEARMEM	MACRO
	lea	\1,a0
	moveq	#\2-1,d0
	moveq	#0,d1
clr\@:	move.l	d1,(a0)+
	dbra	d0,clr\@
	ENDM

DEBUG	EQU	1

	SECTION	code,CODE
main:
	PUSHALL
	CLEARMEM	buffer,16
	IFNE	DEBUG
	move.b	#1,flag
	ELSE
	clr.b	flag
	ENDC
	REPT	4
	nop
	ENDR
	POPALL
	rts

	SECTION	data,DATA
flag:	dc.b	0
	EVEN
	SECTION	bss,BSS
buffer:	ds.l	16
