; Hello Amiga avec dos.library
        section prog,CODE
start:  move.l  4.w,a6
        lea     dosname(pc),a1
        moveq   #0,d0
        jsr     -552(a6)
        move.l  d0,a6
        jsr     -60(a6)
        move.l  d0,d1
        move.l  strptr,d2
        moveq   #msgend-msg,d3
        jsr     -48(a6)
        move.l  a6,a1
        move.l  4.w,a6
        jsr     -414(a6)
        moveq   #0,d0
        rts
dosname dc.b    'dos.library',0
        even
        section dat,DATA
strptr: dc.l    msg
msg:    dc.b    'Hello Amiga (dos.library)',10
msgend:
        section bss1,BSS
buffer: ds.b    100
