* POPUP.S - menu_popup, menu_attach (sous-menu), appl_trecord et graf_slidebox
*
* Programme interactif (DEVPAC /X POPUP.S) :
*   1. un menu deroulant s'ouvre en (100,100) : choisir un element a la souris ;
*   2. il se rouvre avec un sous-menu attache a "Beta" : survoler "Beta", puis
*      choisir un element du sous-menu ;
*   3. appl_trecord enregistre 8 evenements (bougez la souris, cliquez, tapez) ;
*   4. appuyer sur le curseur de l'ascenseur a droite et le faire glisser
*      (graf_slidebox) ; relacher le bouton.
* Les resultats (elements choisis, evenements enregistres, position du
* curseur 0..1000) sont ecrits dans POP.RES.
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
* dessin du curseur (arbre 3)
        clr.w   intin
        move.w  #8,intin+2
        move.w  #290,intin+4
        move.w  #190,intin+6
        move.w  #80,intin+8
        move.w  #230,intin+10
        move.l  #tree3,addrin
        AES     42,6,1,1
* --- 1 : popup simple ---
        move.l  #tree1,me
        clr.w   me+4
        clr.w   me+6
        clr.w   me+8
        move.w  #100,intin
        move.w  #100,intin+2
        move.l  #me,addrin
        move.l  #md,addrin+4
        AES     36,2,1,2
        move.w  intout,r_rc1
        move.l  md,r_t1
        move.w  md+4,r_m1
        move.w  md+6,r_i1
* --- 2 : attache un sous-menu a l'element 2 de tree1 puis popup ---
        move.l  #tree2,me
        clr.w   me+4
        clr.w   me+6
        clr.w   me+8
        move.w  #1,intin                * ME_ATTACH
        move.w  #2,intin+2              * item
        move.l  #tree1,addrin
        move.l  #me,addrin+4
        AES     37,2,1,2
        move.w  intout,r_att
        move.l  #tree1,me
        clr.w   me+4
        clr.w   me+6
        move.w  #100,intin
        move.w  #100,intin+2
        move.l  #me,addrin
        move.l  #md,addrin+4
        AES     36,2,1,2
        move.w  intout,r_rc2
        move.l  md,r_t2
        move.w  md+4,r_m2
        move.w  md+6,r_i2
* --- 3 : enregistrement de 6 evenements ---
        move.w  #8,intin
        move.l  #recbuf,addrin
        AES     15,1,1,1
        move.w  intout,r_rec
* --- 4 : curseur d'ascenseur ---
        move.w  #1,intin
        move.w  #1,intin+2
        move.w  #1,intin+4
        AES     21,3,5,0
        move.w  #0,intin                * parent
        move.w  #1,intin+2              * objet
        move.w  #1,intin+4              * vertical
        move.l  #tree3,addrin
        AES     76,3,1,1
        move.w  intout,r_sl
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

aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts

        data
fname:  dc.b    'POP.RES',0
s1:     dc.b    'Alpha',0
s2:     dc.b    'Beta',0
s3:     dc.b    'Gamma',0
s4:     dc.b    'Delta',0
t1:     dc.b    'One',0
t2:     dc.b    'Two',0
t3:     dc.b    'Three',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
* arbre 1 : 4 elements de 120x16
tree1:  dc.w    -1,1,4,20,0,0
        dc.l    $00011100
        dc.w    0,0,120,64
        dc.w    2,-1,-1,28,1,0
        dc.l    s1
        dc.w    0,0,120,16
        dc.w    3,-1,-1,28,1,0
        dc.l    s2
        dc.w    0,16,120,16
        dc.w    4,-1,-1,28,1,0
        dc.l    s3
        dc.w    0,32,120,16
        dc.w    0,-1,-1,28,33,0
        dc.l    s4
        dc.w    0,48,120,16
* arbre 2 : sous-menu
tree2:  dc.w    -1,1,3,20,0,0
        dc.l    $00011100
        dc.w    0,0,100,48
        dc.w    2,-1,-1,28,1,0
        dc.l    t1
        dc.w    0,0,100,16
        dc.w    3,-1,-1,28,1,0
        dc.l    t2
        dc.w    0,16,100,16
        dc.w    0,-1,-1,28,33,0
        dc.l    t3
        dc.w    0,32,100,16
* arbre 3 : piste + curseur (300,200) 40x200
tree3:  dc.w    -1,1,1,20,0,0
        dc.l    $00011100
        dc.w    300,200,40,200
        dc.w    0,-1,-1,20,1,0
        dc.l    $00011101
        dc.w    0,0,40,20
results:
r_rc1:  dc.w    0
r_t1:   dc.l    0
r_m1:   dc.w    0
r_i1:   dc.w    0
r_att:  dc.w    0
r_rc2:  dc.w    0
r_t2:   dc.l    0
r_m2:   dc.w    0
r_i2:   dc.w    0
r_rec:  dc.w    0
r_sl:   dc.w    0
recbuf: ds.l    16
resend:
tree1a: dc.l    tree1
tree2a: dc.l    tree2
        bss
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l    4
me:     ds.w    8
md:     ds.w    8
