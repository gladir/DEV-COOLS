* VSCFORM.S - vsc_form : curseur de souris personnalise (carre plein 16x16)
*
* Execution (interface graphique) : DEVPAC /X VSCFORM.S ; le curseur devient un carre noir
        text
start:
        move.w  #10,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
        move.w  #77,ctrl
        clr.w   ctrl+2
        move.w  #5,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
        move.w  intout,handle
* vsc_form(handle, forme)
        lea     form(pc),a0
        lea     vintin,a1
        moveq   #36,d0
cp:     move.w  (a0)+,(a1)+
        dbra    d0,cp
        move.w  #111,vctrl
        clr.w   vctrl+2
        move.w  #37,vctrl+6
        move.w  handle,vctrl+12
        bsr     vdi
* attend 8 secondes (evnt_timer)
        move.w  #8000,intin
        clr.w   intin+2
        move.w  #24,ctrl
        move.w  #2,ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
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
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
vdipb:  dc.l    vctrl,vintin,ptsin,vintout,ptsout
form:   dc.w    0,0,1,0,1
        dcb.w   16,$FFFF
        dcb.w   16,$FFFF
        bss
handle: ds.w    1
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    10
intout: ds.w    10
addrin: ds.l    4
addrout: ds.l   4
vctrl:  ds.w    12
vintin: ds.w    40
vintout: ds.w   10
ptsin:  ds.w    10
ptsout: ds.w    10
