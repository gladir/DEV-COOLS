; HELLO.S - Programme AmigaOS minimal pour GENAM
;
;   genam hello.s              -> executable "hello" (format Hunk)
;   genam -L hello.s           -> objet linkable "hello.o"
;   genam -P hello.s           -> avec listing a l'ecran
;
_LVOOpenLibrary		EQU	-552
_LVOCloseLibrary	EQU	-414
_LVOOutput		EQU	-60
_LVOWrite		EQU	-48
AbsExecBase		EQU	4

	SECTION	hello,CODE

start:
	move.l	AbsExecBase.w,a6
	lea	dosname(pc),a1
	moveq	#0,d0
	jsr	_LVOOpenLibrary(a6)
	tst.l	d0
	beq.s	.exit
	move.l	d0,a6			; a6 = DOSBase
	jsr	_LVOOutput(a6)
	move.l	d0,d1			; d1 = fichier de sortie
	beq.s	.close
	lea	msg(pc),a0
	move.l	a0,d2			; d2 = tampon
	moveq	#msglen,d3		; d3 = longueur
	jsr	_LVOWrite(a6)
.close:
	move.l	a6,a1
	move.l	4.w,a6
	jsr	_LVOCloseLibrary(a6)
.exit:
	moveq	#0,d0
	rts

dosname:	dc.b	'dos.library',0
msg:		dc.b	'Bonjour depuis GENAM !',10
msglen		EQU	*-msg
	EVEN
