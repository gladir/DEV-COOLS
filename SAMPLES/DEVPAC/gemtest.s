* Petit programme GEM : VDI + AES (sous-ensemble emule)
        text
start:
        * appl_init
        move.w  #10,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
        * ouvre la station virtuelle (v_opnvwk)
        lea     intin,a0
        moveq   #9,d0
.oi:    move.w  #1,(a0)+
        dbra    d0,.oi
        move.w  #2,(a0)
        move.w  #100,vctrl
        clr.w   vctrl+2
        move.w  #11,vctrl+6
        bsr     vdi
        * cadre
        move.w  #11,vctrl
        move.w  #2,vctrl+2
        clr.w   vctrl+6
        move.w  #1,vctrl+10
        move.w  #20,ptsin
        move.w  #20,ptsin+2
        move.w  #619,ptsin+4
        move.w  #379,ptsin+6
        move.w  #23,vctrl         * vsf_interior
        move.w  #1,vctrl+6
        clr.w   intin
        bsr     vdi
        move.w  #11,vctrl
        move.w  #2,vctrl+2
        clr.w   vctrl+6
        move.w  #1,vctrl+10
        bsr     vdi
        * ligne diagonale
        move.w  #6,vctrl
        move.w  #2,vctrl+2
        clr.w   vctrl+6
        move.w  #20,ptsin
        move.w  #20,ptsin+2
        move.w  #619,ptsin+4
        move.w  #379,ptsin+6
        bsr     vdi
        * texte
        move.w  #8,vctrl
        move.w  #1,vctrl+2
        move.w  #17,vctrl+6
        move.w  #200,ptsin
        move.w  #100,ptsin+2
        lea     txt(pc),a0
        lea     intin,a1
        moveq   #16,d0
.ct:    moveq   #0,d1
        move.b  (a0)+,d1
        move.w  d1,(a1)+
        dbra    d0,.ct
        bsr     vdi
        * cercle plein
        move.w  #23,vctrl
        move.w  #1,vctrl+6
        move.w  #1,intin
        bsr     vdi
        move.w  #11,vctrl
        move.w  #3,vctrl+2
        clr.w   vctrl+6
        move.w  #4,vctrl+10
        move.w  #320,ptsin
        move.w  #250,ptsin+2
        clr.w   ptsin+4
        clr.w   ptsin+6
        move.w  #60,ptsin+8
        clr.w   ptsin+10
        bsr     vdi
        * alerte AES
        move.w  #52,ctrl
        move.w  #1,ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.w  #1,intin
        move.l  #alert,addrin
        bsr     aes
        * appl_exit
        move.w  #19,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        bsr     aes
        clr.w   -(sp)
        trap    #1

aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts
vdi:    move.l  #vdipb,d1
        moveq   #115,d0
        trap    #2
        rts

        data
txt:    dc.b    'GenST GEM test OK!'
        even
alert:  dc.b    '[1][Alerte GEM emulee|OK ?][ Bravo ]',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
vdipb:  dc.l    vctrl,intin,ptsin,intout,ptsout
        bss
ctrl:   ds.w    10
vctrl:  ds.w    12
global: ds.w    16
intin:  ds.w    40
intout: ds.w    50
ptsin:  ds.w    16
ptsout: ds.w    16
addrin: ds.l    4
addrout: ds.l    4
