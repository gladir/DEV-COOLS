; CPUTEST.S - Test du coeur 68000 de l emulateur de STBASIC (affiche ALL PASS)
; Assembler : AS68 -U -L CPUTEST.S
; Lier      : LINK68 [U,ABSOLUTE,TEXTBASE[20100],DATABASE[20348]] CPUTEST.PRG=CPUTEST
; Executer  : STBASIC /X CPUTEST.PRG
        text
start:
        moveq   #1,d6
        move.l  #$12345678,d0
        swap    d0
        cmpi.l  #$56781234,d0
        bne     bad
        moveq   #2,d6
        move.w  #$7FFF,d0
        addq.w  #1,d0
        bvc     bad
        bpl     bad
        cmpi.w  #$8000,d0
        bne     bad
        moveq   #3,d6
        move.l  #100,d0
        mulu    #300,d0
        cmpi.l  #30000,d0
        bne     bad
        moveq   #4,d6
        move.l  #$FFFFFFF9,d0
        divs    #2,d0
        cmpi.l  #$FFFFFFFD,d0
        bne     bad
        moveq   #5,d6
        move.l  #$80000001,d0
        lsr.l   #1,d0
        bcc     bad
        cmpi.l  #$40000000,d0
        bne     bad
        moveq   #6,d6
        move.b  #$81,d0
        ror.b   #1,d0
        cmpi.b  #$C0,d0
        bne     bad
        moveq   #7,d6
        move.l  #$F0,d0
        bchg    #0,d0
        bclr    #7,d0
        bset    #8,d0
        cmpi.l  #$171,d0
        bne     bad
        moveq   #8,d6
        moveq   #1,d1
        moveq   #2,d2
        moveq   #3,d3
        move.l  sp,d5
        movem.l d1-d3,-(sp)
        moveq   #0,d1
        moveq   #0,d2
        moveq   #0,d3
        movem.l (sp)+,d1-d3
        cmpi.l  #2,d2
        bne     bad
        cmpi.l  #3,d3
        bne     bad
        cmp.l   sp,d5
        bne     bad
        moveq   #9,d6
        lea     buf,a0
        move.l  #$01020304,(a0)
        move.b  2(a0),d0
        cmpi.b  #3,d0
        bne     bad
        moveq   #1,d1
        dc.w    $1030,$1000
        cmpi.b  #2,d0
        bne     bad
        move.b  (a0)+,d0
        cmpi.b  #1,d0
        bne     bad
        move.b  (a0)+,d0
        move.b  -(a0),d0
        cmpi.b  #2,d0
        bne     bad
        moveq   #10,d6
        lea     src,a0
        lea     dst,a1
cp:     move.b  (a0)+,(a1)+
        bne     cp
        lea     src,a0
        lea     dst,a1
cm:     cmpm.b  (a0)+,(a1)+
        bne     bad
        tst.b   -1(a0)
        bne     cm
        moveq   #11,d6
        bsr     sub1
        cmpi.l  #77,d0
        bne     bad
        moveq   #12,d6
        moveq   #0,d0
        moveq   #9,d1
lp:     addq.l  #2,d0
        dbra    d1,lp
        cmpi.l  #20,d0
        bne     bad
        moveq   #13,d6
        move.l  #$00000199,d0
        move.l  #$00000001,d1
        andi    #$EF,ccr
        abcd    d1,d0
        cmpi.b  #$00,d0
        bne     bad
        moveq   #14,d6
        moveq   #5,d0
        neg.l   d0
        not.l   d0
        cmpi.l  #4,d0
        bne     bad
        moveq   #15,d6
        link    a6,#$FFF8
        move.l  #99,-4(a6)
        move.l  -4(a6),d0
        unlk    a6
        cmpi.l  #99,d0
        bne     bad
        moveq   #16,d6
        move.l  #$FFFFFFFF,d0
        ext.w   d0
        ext.l   d0
        scs     d1
        cmpi.l  #$FFFFFFFF,d0
        bne     bad
        moveq   #17,d6
        move.w  #$FFFF,d0
        move.w  #1,d1
        add.w   d1,d0
        bcc     bad
        bne     bad
        moveq   #18,d6
        move.l  #5,d0
        move.l  #7,d1
        exg     d0,d1
        cmpi.l  #7,d0
        bne     bad
        moveq   #19,d6
        move.l  #$1FF,d0
        lsl.w   #8,d0
        cmpi.w  #$FF00,d0
        bne     bad
        moveq   #20,d6
        move.w  #$8000,d0
        asr.w   #3,d0
        cmpi.w  #$F000,d0
        bne     bad
        pea     okmsg
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        clr.w   -(sp)
        trap    #1
bad:
        add.b   #'0',d6
        pea     badmsg
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        move.w  d6,-(sp)
        move.w  #2,-(sp)
        trap    #1
        addq.l  #4,sp
        clr.w   -(sp)
        trap    #1
sub1:   moveq   #77,d0
        rts
        data
okmsg:  dc.b   'ALL PASS',13,10,0
badmsg: dc.b  'FAIL TEST ',0
src:    dc.b   'copy me',0
        even
buf:    dc.l   0,0,0,0
dst:    dc.b   0,0,0,0,0,0,0,0,0,0
        end
