; MAIN.S - Utilise des symboles externes : genam -L main.s
	SECTION	main,CODE
	XREF	_AddTwo
	XREF	_Counter

start:
	moveq	#3,d0
	moveq	#4,d1
	bsr	_AddTwo
	move.l	_Counter,d2
	rts
