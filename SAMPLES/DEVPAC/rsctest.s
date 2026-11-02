* Test du chargement d'un fichier ressource .RSC (rsrc_load / rsrc_gaddr)
        text
start:
        move.w  #10,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
* rsrc_load
        move.w  #110,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.l  #rscname,addrin
        bsr     aes
        tst.w   intout
        beq     fail
* rsrc_gaddr(R_TREE,0)
        move.w  #112,ctrl
        move.w  #2,ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        move.w  #1,ctrl+8
        clr.w   intin
        clr.w   intin+2
        bsr     aes
        move.l  addrout,tree
* form_center
        move.w  #54,ctrl
        clr.w   ctrl+2
        move.w  #5,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.l  tree,addrin
        bsr     aes
        move.w  intout+2,fx
        move.w  intout+4,fy
        move.w  intout+6,fw
        move.w  intout+8,fh
* form_dial(START)
        clr.w   intin
        move.w  fx,intin+2
        move.w  fy,intin+4
        move.w  fw,intin+6
        move.w  fh,intin+8
        move.w  fx,intin+10
        move.w  fy,intin+12
        move.w  fw,intin+14
        move.w  fh,intin+16
        move.w  #51,ctrl
        move.w  #9,ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
* objc_draw
        clr.w   intin
        move.w  #8,intin+2
        move.w  fx,intin+4
        move.w  fy,intin+6
        move.w  fw,intin+8
        move.w  fh,intin+10
        move.w  #42,ctrl
        move.w  #6,ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.l  tree,addrin
        bsr     aes
* form_do
        move.w  #2,intin
        move.w  #50,ctrl
        move.w  #1,ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.l  tree,addrin
        bsr     aes
fail:
        clr.w   -(sp)
        trap    #1

aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts

        data
rscname: dc.b   'rsctest.rsc',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
        bss
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    20
intout: ds.w    20
addrin: ds.l    4
addrout: ds.l    4
tree:   ds.l    1
fx:     ds.w    1
fy:     ds.w    1
fw:     ds.w    1
fh:     ds.w    1
