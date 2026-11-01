* test des fonctionnalites de l'assembleur
        include 'macros.i'
DEBUG   equ     1
VER     set     1
VER     set     VER+2
cnt     equ     5
        rsreset
r_a     rs.w    1
r_b     rs.l    2
r_c     rs.b    3
r_size  rs.b    0

PRINT   macro
        pea     \1(pc)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        endm

SHOWNUM macro
        move.l  \1,d0
        bsr     printnum
        endm

        text
start:
        PRINT   m1
        SHOWNUM #r_size
        SHOWNUM #r_c
        SHOWNUM #VER
        SHOWNUM #INCVAL
        PRINT   nl
        ifd     DEBUG
        PRINT   m2
        endc
        ifnd    DEBUG
        PRINT   m3
        endc
        ifeq    cnt-5
        PRINT   m4
        else
        PRINT   m5
        endc
        ifne    cnt-5
        PRINT   m5
        else
        PRINT   m6
        endc
        ifc     'abc','abc'
        PRINT   m7
        endc
        ifnc    'abc','abd'
        PRINT   m8
        endc
        moveq   #0,d4
        rept    cnt
        addq.l  #2,d4
        endr
        SHOWNUM d4
        PRINT   nl
        PRINT   incstr
        lea     tab(pc),a0
        moveq   #0,d0
        moveq   #3,d1
.sum:   add.w   (a0)+,d0
        dbra    d1,.sum
        bsr     printnum
        PRINT   nl
        move.l  #end-start,d0
        move.l  #(2+3)*4-1,d0
        bsr     printnum
        PRINT   nl
        move.l  #$ff&$0f|$30,d0
        bsr     printnum
        PRINT   nl
        move.l  #1<<10,d0
        bsr     printnum
        PRINT   nl
        move.l  #'AB',d0
        bsr     printnum
        PRINT   nl
        clr.w   -(sp)
        trap    #1

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
        pea     sp1(pc)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        movem.l (sp)+,d0-d3/a0
        rts
end:
        data
m1:     dc.b    'RS sizes: ',0
m2:     dc.b    'DEBUG defined',13,10,0
m3:     dc.b    'NOT HERE',13,10,0
m4:     dc.b    'ifeq ok',13,10,0
m5:     dc.b    'WRONG',13,10,0
m6:     dc.b    'ifne else ok',13,10,0
m7:     dc.b    'ifc ok',13,10,0
m8:     dc.b    'ifnc ok',13,10,0
incstr: incmac
sp1:    dc.b    ' ',0
nl:     dc.b    13,10,0
        even
tab:    dc.w    10,20,30,40
        bss
numbuf: ds.b    12
