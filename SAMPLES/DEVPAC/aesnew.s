* AESNEW.S - appl_bvset/yield/search, objc_sysvar, appl_getinfo, form_keybd,
* form_button, rsrc_rcfix, vq_cellarray, vsin_mode/vqin_mode, vsc_form, code VDI inconnu
*
* Execution :  DEVPAC /B /X AESNEW.S   (necessite RSCTEST.RSC ; resultats dans AESNEW.RES)
        text
AES     MACRO
        move.w  #\1,ctrl
        move.w  #\2,ctrl+2
        move.w  #\3,ctrl+4
        move.w  #\4,ctrl+6
        clr.w   ctrl+8
        bsr     aes
        ENDM
VDI     MACRO
        move.w  #\1,vctrl
        clr.w   vctrl+2
        clr.w   vctrl+6
        clr.w   vctrl+10
        move.w  handle,vctrl+12
        ENDM
OUT     MACRO
        move.w  intout+\1*2,(a5)+
        ENDM
start:
        lea     results,a5
        AES     10,0,1,0
        move.w  intout,d0
        move.w  d0,(a5)+                * 0 : ap_id
        AES     77,0,5,0
        move.w  intout,handle
* appl_bvset
        move.w  #$1F,intin
        clr.w   intin+2
        move.w  #$C,intin+4
        clr.w   intin+6
        AES     16,4,1,0
        OUT     0                       * 1
* appl_yield
        AES     17,0,1,0
        OUT     0                       * 2
* appl_search
        clr.w   intin
        move.l  #namebuf,addrin
        AES     18,1,3,1
        OUT     0                       * 3 rc
        OUT     1                       * 4 type
        OUT     2                       * 5 id
        move.l  namebuf,(a5)+           * 6,7 : nom
        move.l  namebuf+4,(a5)+         * 8,9
        move.w  #1,intin
        move.l  #namebuf,addrin
        AES     18,1,3,1
        OUT     0                       * 10 : plus d'application
* objc_sysvar : ecrit puis relit AD3DVALUE
        move.w  #1,intin
        move.w  #6,intin+2
        move.w  #3,intin+4
        move.w  #4,intin+6
        AES     48,4,3,0
        OUT     0                       * 11
        clr.w   intin
        move.w  #6,intin+2
        AES     48,4,3,0
        OUT     0                       * 12 rc
        OUT     1                       * 13 = 3
        OUT     2                       * 14 = 4
        clr.w   intin
        move.w  #9,intin+2
        AES     48,4,3,0
        OUT     0                       * 15 = 0 (quoi invalide)
* appl_getinfo
        clr.w   intin
        AES     130,1,5,0
        OUT     0                       * 16
        OUT     1                       * 17 = 10
        OUT     2                       * 18 = 1
        move.w  #3,intin
        AES     130,1,5,0
        OUT     1                       * 19 langue
        move.w  #99,intin
        AES     130,1,5,0
        OUT     0                       * 20 = 0
* form_keybd : arbre tree1, edition en 1
        move.w  #1,intin
        move.w  #$0F09,intin+2          * Tab
        move.w  #0,intin+4
        move.l  #tree1,addrin
        AES     55,3,3,1
        OUT     0                       * 21 = 1
        OUT     1                       * 22 = 2
        OUT     2                       * 23 = 0
        move.w  #2,intin
        move.w  #$4800,intin+2          * fleche haut
        AES     55,3,3,1
        OUT     1                       * 24 = 1
        move.w  #1,intin
        move.w  #$5000,intin+2          * fleche bas
        AES     55,3,3,1
        OUT     1                       * 25 = 2
        move.w  #1,intin
        move.w  #$1E61,intin+2          * 'a'
        AES     55,3,3,1
        OUT     0                       * 26 = 1
        OUT     1                       * 27 = 1
        OUT     2                       * 28 = $1E61
        move.w  #1,intin
        move.w  #$1C0D,intin+2          * Return
        AES     55,3,3,1
        OUT     0                       * 29 = 0
        OUT     1                       * 30 = 3 (objet par defaut)
        move.w  tree1+3*24+10,(a5)+     * 31 = etat du bouton par defaut (selectionne)
* form_button : boutons radio 4 et 5 (4 selectionne au depart)
        move.w  #5,intin
        move.w  #1,intin+2
        move.l  #tree1,addrin
        AES     56,2,2,1
        OUT     0                       * 32 = 1 (continuer)
        OUT     1                       * 33 = 5
        move.w  tree1+4*24+10,(a5)+     * 34 = etat de 4 (deselectionne : 0)
        move.w  tree1+5*24+10,(a5)+     * 35 = etat de 5 (selectionne : 1)
* form_button : bouton de sortie 6, double-clic
        move.w  #6,intin
        move.w  #2,intin+2
        AES     56,2,2,1
        OUT     0                       * 36 = 0 (sortie)
        OUT     1                       * 37 = 6 | $8000
* rsrc_rcfix : lit RSCTEST.RSC dans un tampon
        clr.w   -(sp)
        pea     rscname(pc)
        move.w  #$3D,-(sp)
        trap    #1
        addq.l  #8,sp
        move.w  d0,d6
        pea     rscbuf
        move.l  #4000,-(sp)
        move.w  d6,-(sp)
        move.w  #$3F,-(sp)
        trap    #1
        lea     12(sp),sp
        move.w  d6,-(sp)
        move.w  #$3E,-(sp)
        trap    #1
        addq.l  #4,sp
        move.l  #rscbuf,addrin
        AES     115,0,1,1
        OUT     0                       * 38 = 1
        clr.w   intin
        clr.w   intin+2
        AES     112,2,1,0
        OUT     0                       * 39 = 1
        move.l  addrout,a0
        move.w  20(a0),(a5)+            * 40 = largeur de la racine en pixels (320)
* VDI : station, rectangle noir, vq_cellarray
        lea     vintin,a0
        moveq   #9,d0
oi:     move.w  #1,(a0)+
        dbra    d0,oi
        move.w  #2,(a0)
        move.w  #100,vctrl
        clr.w   vctrl+2
        move.w  #11,vctrl+6
        clr.w   vctrl+10
        move.w  handle,vctrl+12
        bsr     vdi
        move.w  vctrl+12,handle
        VDI     23                      * vsf_interior solide
        move.w  #1,vctrl+6
        move.w  #1,vintin
        bsr     vdi
        VDI     25                      * vsf_color noir
        move.w  #1,vctrl+6
        move.w  #1,vintin
        bsr     vdi
        VDI     11                      * v_bar
        move.w  #2,vctrl+2
        move.w  #1,vctrl+10
        clr.w   ptsin
        clr.w   ptsin+2
        move.w  #15,ptsin+4
        move.w  #15,ptsin+6
        bsr     vdi
        VDI     27                      * vq_cellarray : 4 cases sur 32x16
        move.w  #2,vctrl+2
        move.w  #2,vctrl+6
        clr.w   ptsin
        clr.w   ptsin+2
        move.w  #31,ptsin+4
        move.w  #15,ptsin+6
        move.w  #4,vintin
        move.w  #1,vintin+2
        bsr     vdi
        move.w  vctrl+8,(a5)+           * 41 = 7 (3 + 4)
        move.w  vintout,(a5)+           * 42 = 4
        move.w  vintout+2,(a5)+         * 43 = 1
        move.w  vintout+6,(a5)+         * 44 = 1 (noir)
        move.w  vintout+12,(a5)+        * 45 = 0 (blanc)
* vsin_mode / vqin_mode
        VDI     33
        move.w  #2,vctrl+6
        move.w  #1,vintin
        move.w  #2,vintin+2
        bsr     vdi
        VDI     115
        move.w  #1,vctrl+6
        move.w  #1,vintin
        bsr     vdi
        move.w  vintout,(a5)+           * 46 = 2
        VDI     115
        move.w  #1,vctrl+6
        move.w  #2,vintin
        bsr     vdi
        move.w  vintout,(a5)+           * 47 = 1
* code VDI 34 : aucune sortie
        VDI     34
        move.w  #5,vctrl+8
        bsr     vdi
        move.w  vctrl+8,(a5)+           * 48 = 0
* ecrit les resultats
        clr.w   -(sp)
        pea     fname(pc)
        move.w  #$3C,-(sp)
        trap    #1
        addq.l  #8,sp
        move.w  d0,d6
        move.l  a5,d0
        sub.l   #results,d0
        pea     results
        move.l  d0,-(sp)
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
vdi:    move.l  #vdipb,d1
        moveq   #115,d0
        trap    #2
        rts
        data
fname:  dc.b    'AESNEW.RES',0
rscname: dc.b   'rsctest.rsc',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
vdipb:  dc.l    vctrl,vintin,ptsin,vintout,ptsout
* arbre de formulaire : 0 racine, 1 et 2 champs editables, 3 defaut, 4 et 5 radio, 6 sortie
tree1:  dc.w    -1,1,6,20,0,0
        dc.l    $00011100
        dc.w    0,0,200,100
        dc.w    2,-1,-1,20,8,0
        dc.l    $00011100
        dc.w    4,4,60,16
        dc.w    3,-1,-1,20,8,0
        dc.l    $00011100
        dc.w    4,24,60,16
        dc.w    4,-1,-1,20,3,0
        dc.l    $00011100
        dc.w    4,44,40,16
        dc.w    5,-1,-1,20,17,1
        dc.l    $00011100
        dc.w    80,4,40,16
        dc.w    6,-1,-1,20,17,0
        dc.l    $00011100
        dc.w    80,24,40,16
        dc.w    0,-1,-1,20,37,0
        dc.l    $00011100
        dc.w    80,44,40,16
        bss
results: ds.w   64
handle: ds.w    1
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l   4
namebuf: ds.b   16
vctrl:  ds.w    12
vintin: ds.w    40
vintout: ds.w   60
ptsin:  ds.w    30
ptsout: ds.w    30
rscbuf: ds.b    4000
