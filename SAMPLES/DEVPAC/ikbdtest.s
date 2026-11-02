* IKBDTEST.S - Initmous / Ikbdws : modes souris relatif, absolu, desactive, touches du curseur
*
* Rejoue des mouvements avec appl_tplay ; le vecteur souris compte les paquets.
* Execution (interface graphique) : DEVPAC /X IKBDTEST.S    -> IKBD.RES
        text
TPLAY   MACRO
        move.w  #\2,intin
        move.w  #100,intin+2
        move.l  #\1,addrin
        move.w  #14,ctrl
        move.w  #2,ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        bsr     aes
        ENDM
IKB     MACRO
        pea     \1
        move.w  #\2-1,-(sp)
        move.w  #25,-(sp)
        trap    #14
        addq.l  #8,sp
        ENDM
SNAP    MACRO
        move.w  mcnt,\1
        move.l  last6,\1+2
        move.w  last6+4,\1+6
        ENDM
start:
        move.w  #10,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
* Initmous(1,param,vec) : relatif, seuil 3
        pea     mvec(pc)
        pea     parm(pc)
        move.w  #1,-(sp)
        clr.w   -(sp)
        trap    #14
        lea     12(sp),sp
        TPLAY   rec1,6
        SNAP    snap1
* absolu avec rapport sur appui et relachement
        IKB     cmdabs,5
        IKB     cmdbtn,2
        TPLAY   rec2,5
        SNAP    snap2
* souris desactivee
        IKB     cmdoff,1
        move.w  mcnt,before
        TPLAY   rec3,2
        move.w  mcnt,after
* reactivee en mode touches du curseur (pas de 40)
        IKB     cmdon,1
        IKB     cmdkey,3
        TPLAY   rec4,3
* compte les fleches droites dans la file de touches
        clr.w   d4
rk:     move.w  #2,-(sp)
        move.w  #1,-(sp)
        trap    #13                     ; Bconstat(2)
        addq.l  #4,sp
        tst.l   d0
        beq.s   rkend
        move.w  #2,-(sp)
        move.w  #2,-(sp)
        trap    #13                     ; Bconin(2)
        addq.l  #4,sp
        swap    d0
        cmp.b   #77,d0
        bne.s   rk
        addq.w  #1,d4
        bra.s   rk
rkend:  move.w  d4,rights
        clr.w   -(sp)
        pea     fname(pc)
        move.w  #$3C,-(sp)
        trap    #1
        addq.l  #8,sp
        move.w  d0,d6
        pea     results
        move.l  #resend-results,-(sp)
        move.w  d6,-(sp)
        move.w  #$40,-(sp)
        trap    #1
        lea     12(sp),sp
        move.w  d6,-(sp)
        move.w  #$3E,-(sp)
        trap    #1
        addq.l  #4,sp
        clr.w   -(sp)
        trap    #1
mvec:   addq.w  #1,mcnt
        lea     last6,a1
        moveq   #5,d0
mv1:    move.b  (a0)+,(a1)+
        dbra    d0,mv1
        rts
aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts
        data
fname:  dc.b    'IKBD.RES',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
parm:   dc.b    0,0,3,3
cmdabs: dc.b    $09,$02,$7F,$01,$8F
cmdbtn: dc.b    $07,$03
cmdoff: dc.b    $12
cmdon:  dc.b    $11
cmdkey: dc.b    $0A,40,40
        even
rec1:   dc.l    2,(100<<16)|100,0,50,2,(112<<16)|100,1,1,0,50,1,0
rec2:   dc.l    2,(200<<16)|200,0,40,1,1,0,40,1,0
rec3:   dc.l    0,30,2,(500<<16)|300
rec4:   dc.l    2,(300<<16)|200,0,30,2,(400<<16)|200
results:
snap1:  ds.b    8
snap2:  ds.b    8
before: dc.w    0
after:  dc.w    0
rights: dc.w    0
mcnt:   dc.w    0
last6:  ds.b    8
resend:
        bss
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l    4
