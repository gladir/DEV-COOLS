* VEXTEST.S - appl_tplay (relecture d'evenements) et routines vex_*
*
* Rejoue un enregistrement (souris, bouton, minuterie, clavier) avec appl_tplay
* et verifie que vex_motv, vex_butv, vex_curv et vex_timv sont bien appelees.
* Les compteurs sont ecrits dans VEX.RES (mots 16 bits, voir la fin du source).
* Execution (interface graphique) :  DEVPAC /X VEXTEST.S
        text
AES     MACRO
        move.w  #\1,ctrl
        move.w  #\2,ctrl+2
        move.w  #\3,ctrl+4
        move.w  #\4,ctrl+6
        clr.w   ctrl+8
        bsr     aes
        ENDM
VDIC    MACRO
        move.w  #\1,vctrl
        clr.w   vctrl+2
        clr.w   vctrl+6
        move.w  handle,vctrl+12
        ENDM

start:
        AES     10,0,1,0
        AES     77,0,5,0                * graf_handle
        move.w  intout,handle
* vex_motv (126)
        VDIC    126
        move.l  #motv,vctrl+14
        bsr     vdi
* vex_butv (125)
        VDIC    125
        move.l  #butv,vctrl+14
        bsr     vdi
* vex_curv (127)
        VDIC    127
        move.l  #curv,vctrl+14
        bsr     vdi
* vex_timv (118)
        VDIC    118
        move.l  #timv,vctrl+14
        bsr     vdi
        move.w  vintout,tconv
* appl_tplay
        move.w  #7,intin
        move.w  #100,intin+2
        move.l  #recbuf,addrin
        AES     14,2,1,1
        move.w  intout,tplayrc
* clavier
        AES     20,0,1,0
        move.w  intout,keyv
* ecrit les resultats
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

* routines vex
motv:   addq.w  #1,motcnt
        cmp.w   maxx,d0
        bls.s   .n
        move.w  d0,maxx
        move.w  d1,maxy
.n:
        move.w  d0,lastx
        move.w  d1,lasty
        rts
butv:   addq.w  #1,butcnt
        move.w  d0,lastb
        rts
curv:   addq.w  #1,curcnt
        move.w  d0,curx
        move.w  d1,cury
        rts
timv:   addq.w  #1,timcnt
        rts

aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts
vdi:    move.l  #vdipb,d1
        moveq   #115,d0
        trap    #2
        rts

        data
fname:  dc.b    'VEX.RES',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
vdipb:  dc.l    vctrl,vintin,ptsin,vintout,ptsout
* enregistrement : (type,valeur) 
recbuf: dc.l    0,100                   * minuterie 100 ms
        dc.l    2,(200<<16)|150         * souris en (200,150)
        dc.l    1,1                     * bouton gauche enfonce
        dc.l    0,50
        dc.l    1,0                     * relache
        dc.l    3,$1E61                 * touche 'a'
        dc.l    2,(300<<16)|100
results:
motcnt: dc.w    0
lastx:  dc.w    0
lasty:  dc.w    0
butcnt: dc.w    0
lastb:  dc.w    0
curcnt: dc.w    0
curx:   dc.w    0
cury:   dc.w    0
timcnt: dc.w    0
tconv:  dc.w    0
tplayrc: dc.w   0
keyv:   dc.w    0
maxx:   dc.w    0
maxy:   dc.w    0
resend:
        bss
handle: ds.w    1
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l    4
vctrl:  ds.w    12
vintin: ds.w    30
vintout: ds.w    30
ptsin:  ds.w    30
ptsout: ds.w    30
