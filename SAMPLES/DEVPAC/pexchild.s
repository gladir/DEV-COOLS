* PEXCHILD.S - fils GEM lance par PEXGEM.S : appl_init, ouvre une fenetre,
* ecrit son ap_id et le handle de sa fenetre dans CHILD.RES, puis termine
* (code 7) sans fermer sa fenetre.  Assembler avant PEXGEM.S.
        text
AES     MACRO
        move.w  #\1,ctrl
        move.w  #\2,ctrl+2
        move.w  #\3,ctrl+4
        move.w  #\4,ctrl+6
        clr.w   ctrl+8
        bsr     aes
        ENDM
start:
        AES     10,0,1,0
        move.w  intout,r_ap
        move.w  #$0B,intin
        move.w  #100,intin+2
        move.w  #100,intin+4
        move.w  #200,intin+6
        move.w  #150,intin+8
        AES     100,5,1,0
        move.w  intout,r_win
        move.w  intout,intin
        move.w  #100,intin+2
        move.w  #100,intin+4
        move.w  #200,intin+6
        move.w  #150,intin+8
        AES     101,5,1,0
* ecrit CHILD.RES
        clr.w   -(sp)
        pea     fname(pc)
        move.w  #$3C,-(sp)
        trap    #1
        addq.l  #8,sp
        move.w  d0,d6
        pea     results
        move.l  #4,-(sp)
        move.w  d6,-(sp)
        move.w  #$40,-(sp)
        trap    #1
        lea     12(sp),sp
        move.w  d6,-(sp)
        move.w  #$3E,-(sp)
        trap    #1
        addq.l  #4,sp
        move.w  #7,-(sp)
        move.w  #$4C,-(sp)
        trap    #1
aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts
        data
fname:  dc.b    'CHILD.RES',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
results:
r_ap:   dc.w    0
r_win:  dc.w    0
        bss
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l    4
