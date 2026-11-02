* SCROLLPOP.S - menu_popup avec defilement (mn_scroll)
*
* Ouvre un menu de 12 elements limite a 5 lignes visibles (menu_settings) :
* survoler la fleche du bas pour faire defiler, choisir un element.
* Execution (interface graphique) : DEVPAC /X SCROLLPOP.S
* Resultat (element choisi, premier element visible) dans SCROLL.RES.
        text
start:
        move.w  #10,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
* menu_settings : hauteur = 5 elements
        move.l  #setbuf,addrin
        clr.w   intin
        bsr     mset
        move.w  #5,setbuf+16
        move.w  #1,intin
        bsr     mset
* menu_popup
        move.l  #tree1,me
        clr.w   me+4
        clr.w   me+6
        move.w  #1,me+8                 * mn_scroll <> 0
        move.w  #100,intin
        move.w  #100,intin+2
        move.l  #me,addrin
        move.l  #md,addrin+4
        move.w  #36,ctrl
        move.w  #2,ctrl+2
        move.w  #1,ctrl+4
        move.w  #2,ctrl+6
        clr.w   ctrl+8
        bsr     aes
        move.w  intout,r_rc
        move.w  md+6,r_item
        move.w  md+8,r_first
        clr.w   -(sp)
        pea     fname(pc)
        move.w  #$3C,-(sp)
        trap    #1
        addq.l  #8,sp
        move.w  d0,d6
        pea     results
        move.l  #6,-(sp)
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
mset:   move.w  #39,ctrl
        move.w  #1,ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        bra     aes
aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts
        data
fname:  dc.b    'SCROLL.RES',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
results:
r_rc:   dc.w    0
r_item: dc.w    0
r_first: dc.w   0
s0: dc.b 'Item 01',0
s1: dc.b 'Item 02',0
s2: dc.b 'Item 03',0
s3: dc.b 'Item 04',0
s4: dc.b 'Item 05',0
s5: dc.b 'Item 06',0
s6: dc.b 'Item 07',0
s7: dc.b 'Item 08',0
s8: dc.b 'Item 09',0
s9: dc.b 'Item 10',0
s10: dc.b 'Item 11',0
s11: dc.b 'Item 12',0
        even
tree1:  dc.w -1,1,12,20,0,0
        dc.l $00011100
        dc.w 0,0,120,192
        dc.w 2,-1,-1,28,1,0
        dc.l s0
        dc.w 0,0,120,16
        dc.w 3,-1,-1,28,1,0
        dc.l s1
        dc.w 0,16,120,16
        dc.w 4,-1,-1,28,1,0
        dc.l s2
        dc.w 0,32,120,16
        dc.w 5,-1,-1,28,1,0
        dc.l s3
        dc.w 0,48,120,16
        dc.w 6,-1,-1,28,1,0
        dc.l s4
        dc.w 0,64,120,16
        dc.w 7,-1,-1,28,1,0
        dc.l s5
        dc.w 0,80,120,16
        dc.w 8,-1,-1,28,1,0
        dc.l s6
        dc.w 0,96,120,16
        dc.w 9,-1,-1,28,1,0
        dc.l s7
        dc.w 0,112,120,16
        dc.w 10,-1,-1,28,1,0
        dc.l s8
        dc.w 0,128,120,16
        dc.w 11,-1,-1,28,1,0
        dc.l s9
        dc.w 0,144,120,16
        dc.w 12,-1,-1,28,1,0
        dc.l s10
        dc.w 0,160,120,16
        dc.w 0,-1,-1,28,33,0
        dc.l s11
        dc.w 0,176,120,16
        bss
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l    4
me:     ds.w    8
md:     ds.w    8
setbuf: ds.b    32
