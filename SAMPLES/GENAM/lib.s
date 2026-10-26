; LIB.S - Module a lier : genam -L lib.s  (puis edition de liens avec main.o)
	SECTION	lib,CODE
	XDEF	_AddTwo
	XDEF	_Counter

; D0 = D0 + D1
_AddTwo:
	add.l	d1,d0
	addq.l	#1,_Counter
	rts

	SECTION	libdata,DATA
_Counter:	dc.l	0
