* Hello + arithmetic test
        text
start:  pea     msg(pc)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
* somme 1..100
        moveq   #0,d0
        move.w  #100,d1
.l1:    add.l   d1,d0
        subq.w  #1,d1
        bne.s   .l1
        bsr     printnum
        bsr     crlf
* 12345*67
        move.l  #12345,d0
        mulu    #67,d0
        bsr     printnum
        bsr     crlf
* division 1000000/7 via divu en 2 etapes
        move.l  #99999,d0
        divu    #7,d0
        move.l  d0,d2
        and.l   #$ffff,d0
        bsr     printnum
        bsr     crlf
        move.l  d2,d0
        swap    d0
        and.l   #$ffff,d0
        bsr     printnum
        bsr     crlf
* fibonacci 20 termes
        moveq   #0,d3
        moveq   #1,d4
        moveq   #19,d5
.fib:   move.l  d3,d0
        add.l   d4,d3
        exg     d3,d4
        dbra    d5,.fib
        move.l  d3,d0
        bsr     printnum
        bsr     crlf
* signed: -17 / 5 en divs
        move.l  #-17,d0
        divs    #5,d0
        ext.l   d0
        neg.l   d0
        bsr     printnum
        bsr     crlf
        clr.w   -(sp)
        trap    #1

crlf:   pea     nl(pc)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        rts

* affiche D0 (non signe) en decimal
printnum:
        movem.l d0-d3/a0,-(sp)
        lea     numbuf+11,a0
        clr.b   -(a0)
.dl:    move.l  d0,d1
        clr.w   d1
        swap    d1
        divu    #10,d1
        move.w  d1,d2
        move.w  d0,d1
        divu    #10,d1
        move.w  d1,d3
        swap    d1
        add.b   #'0',d1
        move.b  d1,-(a0)
        swap    d2
        move.w  d3,d2
        swap    d2
        move.l  d2,d0
        swap    d0
        tst.l   d0
        bne.s   .dl
        move.l  a0,-(sp)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        movem.l (sp)+,d0-d3/a0
        rts

        data
msg:    dc.b    'Hello from GenST!',13,10,0
nl:     dc.b    13,10,0
        bss
numbuf: ds.b    12
