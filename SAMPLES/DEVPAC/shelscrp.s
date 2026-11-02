* SHELSCRP.S - presse-papiers (scrp_read/write/clear), shell (shel_get/put,
* shel_envrn, shel_rdef/wdef), menu_settings et menu_istart
*
* Execution :  DEVPAC /B /X SHELSCRP.S   -> affiche  MISC TEST ALL OK
* (le dossier du presse-papiers est cree dans le dossier courant)
        text
AES     MACRO
        move.w  #\1,ctrl
        move.w  #\2,ctrl+2
        move.w  #\3,ctrl+4
        move.w  #\4,ctrl+6
        clr.w   ctrl+8
        bsr     aes
        ENDM
CHK     MACRO
        move.w  intout,d0
        cmp.w   #\1,d0
        beq.s   .ok\@
        lea     \2(pc),a0
        bsr     fail
.ok\@:
        ENDM

start:
        clr.w   d7
        AES     10,0,1,0
* scrp_read
        move.l  #pathbuf,addrin
        AES     80,0,1,1
        CHK     1,m1
        lea     pathbuf,a0
        cmp.b   #'C',(a0)
        beq.s   s1
        lea     m1b(pc),a0
        bsr     fail
s1:
* scrp_write puis relecture
        move.l  #newdir,addrin
        AES     81,0,1,1
        move.l  #pathbuf,addrin
        AES     80,0,1,1
        CHK     1,m2
        lea     pathbuf,a0
        lea     newdir(pc),a1
        moveq   #8,d0
cmpl:   cmpm.b  (a0)+,(a1)+
        bne.s   s2bad
        dbra    d0,cmpl
        bra.s   s2
s2bad:  lea     m2b(pc),a0
        bsr     fail
s2:
* cree SCRAP.TXT puis scrp_clear
        clr.w   -(sp)
        pea     scrapf(pc)
        move.w  #$3C,-(sp)
        trap    #1
        addq.l  #8,sp
        move.w  d0,-(sp)
        move.w  #$3E,-(sp)
        trap    #1
        addq.l  #4,sp
        AES     82,0,1,0
        CHK     1,m3
* shel_put / shel_get
        lea     putdata(pc),a0
        move.l  a0,addrin
        move.w  #16,intin
        AES     123,1,1,1
        CHK     1,m4
        lea     getbuf,a0
        moveq   #3,d0
zl:     clr.l   (a0)+
        dbra    d0,zl
        move.l  #getbuf,addrin
        move.w  #16,intin
        AES     122,1,1,1
        lea     getbuf,a0
        lea     putdata(pc),a1
        moveq   #15,d0
cl2:    cmpm.b  (a0)+,(a1)+
        bne.s   s5bad
        dbra    d0,cl2
        bra.s   s5
s5bad:  lea     m5(pc),a0
        bsr     fail
s5:
* shel_envrn : PATH=
        move.l  #envres,addrin
        move.l  #srch,addrin+4
        AES     125,0,1,2
        move.l  envres,d0
        bne.s   s6
        lea     m6(pc),a0
        bsr     fail
s6:
* shel_wdef / shel_rdef
        move.l  #defcmd,addrin
        move.l  #defdir,addrin+4
        AES     127,0,1,2
        move.l  #getbuf,addrin
        move.l  #getbuf+64,addrin+4
        AES     126,0,1,2
        lea     getbuf,a0
        cmp.l   #'DESK',(a0)
        beq.s   s7
        lea     m7(pc),a0
        bsr     fail
s7:
* menu_settings : lecture puis ecriture
        move.l  #setbuf,addrin
        clr.w   intin
        AES     39,1,1,1
        move.l  #setbuf,addrin
        move.w  #1,intin
        move.l  #777,setbuf+4
        AES     39,1,1,1
        clr.l   setbuf+4
        move.l  #setbuf,addrin
        clr.w   intin
        AES     39,1,1,1
        cmp.l   #777,setbuf+4
        beq.s   s8
        lea     m8(pc),a0
        bsr     fail
s8:
* menu_istart
        move.w  #1,intin
        clr.w   intin+2
        move.w  #3,intin+4
        move.l  #tree1,addrin
        AES     38,3,1,1
        clr.w   intin
        clr.w   intin+2
        AES     38,3,1,1
        CHK     3,m9
        tst.w   d7
        bne.s   done
        lea     mok(pc),a0
        bsr     puts
done:   clr.w   -(sp)
        trap    #1
fail:   addq.w  #1,d7
puts:   move.l  a0,-(sp)
        move.w  #9,-(sp)
        trap    #1
        addq.l  #6,sp
        rts
aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts
        data
mok:    dc.b    'MISC TEST ALL OK',13,10,0
m1:     dc.b    'FAIL scrp_read',13,10,0
m1b:    dc.b    'FAIL scrp_read path',13,10,0
m2:     dc.b    'FAIL scrp_write/read',13,10,0
m2b:    dc.b    'FAIL scrp path value',13,10,0
m3:     dc.b    'FAIL scrp_clear',13,10,0
m4:     dc.b    'FAIL shel_put',13,10,0
m5:     dc.b    'FAIL shel_get data',13,10,0
m6:     dc.b    'FAIL shel_envrn',13,10,0
m7:     dc.b    'FAIL shel_rdef',13,10,0
m8:     dc.b    'FAIL menu_settings',13,10,0
m9:     dc.b    'FAIL menu_istart',13,10,0
newdir: dc.b    'C:\NEWCLIP',0
scrapf: dc.b    'C:\NEWCLIP\SCRAP.TXT',0
srch:   dc.b    'PATH=',0
defcmd: dc.b    'DESKTOP.PRG',0
defdir: dc.b    'C:\',0
putdata: dc.b   'ABCDEFGHIJKLMNOP'
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
tree1:  dc.w    -1,-1,-1,20,0,0
        dc.l    0
        dc.w    0,0,8,8
        bss
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l    4
pathbuf: ds.b   128
getbuf: ds.b    128
envres: ds.l    1
setbuf: ds.b    32
