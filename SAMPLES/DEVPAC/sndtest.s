* SNDTEST.S - Dosound (sequence YM2149), Ikbdws (horloge, demande d'etat)
* et disquette vierge creee a la premiere ecriture.
*
* Execution :  DEVPAC /B /X SNDTEST.S      (resultats dans SND.RES)
* Pour voir les notes jouees (sans haut-parleur) :
*   DEVPAC_SNDLOG=notes.txt DEVPAC /B /X SNDTEST.S   -> frequences en Hz
        text
start:
        clr.w   d7
* --- Dosound : voie A, periode 0x1AA (~294 Hz), volume 15, 3 ticks, puis changement, puis fin ---
        pea     seq(pc)
        move.w  #32,-(sp)
        trap    #14
        addq.l  #6,sp
        moveq   #20,d5
vs:     move.w  #37,-(sp)               ; Vsync
        trap    #14
        addq.l  #2,sp
        dbra    d5,vs
* --- kbdvbase ---
        move.w  #34,-(sp)
        trap    #14
        addq.l  #2,sp
        move.l  d0,a3
        lea     clockh(pc),a0
        move.l  a0,20(a3)               ; clockvec
        lea     stath(pc),a0
        move.l  a0,12(a3)               ; statvec
* --- Ikbdws : regle l'horloge 99/12/31 23:59:50 ---
        pea     setclk(pc)
        move.w  #6,-(sp)                ; 7 octets - 1
        move.w  #25,-(sp)
        trap    #14
        addq.l  #8,sp
        pea     getclk(pc)
        clr.w   -(sp)
        move.w  #25,-(sp)
        trap    #14
        addq.l  #8,sp
        moveq   #3,d5
vs2:    move.w  #37,-(sp)
        trap    #14
        addq.l  #2,sp
        dbra    d5,vs2
* demande l'etat du mode souris (0x88) puis seuil (0x8B)
        pea     inq(pc)
        move.w  #1,-(sp)
        move.w  #25,-(sp)
        trap    #14
        addq.l  #8,sp
        moveq   #3,d5
vs3:    move.w  #37,-(sp)
        trap    #14
        addq.l  #2,sp
        dbra    d5,vs3
* --- ecriture de disquette vierge : DISKA.ST n'existe pas encore ---
        lea     buf,a0
        move.w  #127,d0
f1:     move.l  #$CAFEBABE,(a0)+
        dbra    d0,f1
        move.w  #1,-(sp)
        clr.w   -(sp)
        clr.w   -(sp)
        move.w  #3,-(sp)
        clr.w   -(sp)
        clr.l   -(sp)
        pea     buf
        move.w  #9,-(sp)
        trap    #14
        lea     20(sp),sp
        move.w  d0,wrrc
* fin : ecrit les resultats
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

clockh: lea     clkpkt,a1
        moveq   #6,d0
cc1:    move.b  (a0)+,(a1)+
        dbra    d0,cc1
        rts
stath:  lea     stapkt,a1
        move.w  stan,d1
        lsl.w   #3,d1
        add.w   d1,a1
        moveq   #7,d0
cc2:    move.b  (a0)+,(a1)+
        dbra    d0,cc2
        addq.w  #1,stan
        rts
        data
fname:  dc.b    'SND.RES',0
        even
* sequence Dosound : reg0=$AA reg1=$01 reg8=15 ; attendre 3 ; reg0=$55 ; attendre 3 ; glissando reg0 ; fin
seq:    dc.b    0,$AA,1,$01,8,15,7,$FE
        dc.b    $82,3
        dc.b    0,$55
        dc.b    $82,3
        dc.b    $80,$40,$81,0,$10,$60
        dc.b    $82,2
        dc.b    8,0
        dc.b    $82,0
setclk: dc.b    $1B,$99,$12,$31,$23,$59,$50
getclk: dc.b    $1C
inq:    dc.b    $88,$8B
        even
results:
clkpkt: ds.b    8
stan:   dc.w    0
wrrc:   dc.w    99
stapkt: ds.b    32
resend:
        bss
buf:    ds.b    512
