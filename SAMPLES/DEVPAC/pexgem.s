* PEXGEM.S - pere GEM : lance PEXCHILD.PRG par Pexec et verifie que le fils a
* son propre contexte AES (ap_id different, fenetre du fils supprimee a sa
* fin, fenetre du pere conservee).  Execution :
*   DEVPAC /B pexchild.s   puis   DEVPAC /B /X pexgem.s
* Les resultats sont ecrits dans PARENT.RES (voir la fin du source).
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
* fenetre du pere
        move.w  #$0B,intin
        move.w  #300,intin+2
        move.w  #200,intin+4
        move.w  #200,intin+6
        move.w  #100,intin+8
        AES     100,5,1,0
        move.w  intout,r_pwin
        move.w  intout,intin
        move.w  #300,intin+2
        move.w  #200,intin+4
        move.w  #200,intin+6
        move.w  #100,intin+8
        AES     101,5,1,0
* Pexec(0,"CHILD.PRG","",0)
        clr.l   -(sp)
        pea     cmd(pc)
        pea     name(pc)
        clr.w   -(sp)
        move.w  #$4b,-(sp)
        trap    #1
        lea     16(sp),sp
        move.w  d0,r_code
* appl_find("PARENT  ")
        move.l  #pname,addrin
        AES     13,0,1,1
        move.w  intout,r_findp
        move.l  #cname,addrin
        AES     13,0,1,1
        move.w  intout,r_findc
* la fenetre du pere existe-t-elle encore ?
        move.w  r_pwin,intin
        move.w  #1,intin+2
        AES     104,2,5,0
        move.w  intout,r_pw_ok
* fenetre du fils (handle lu dans CHILD.RES) : doit avoir disparu
        clr.w   -(sp)
        pea     cfile(pc)
        move.w  #$3D,-(sp)
        trap    #1
        addq.l  #8,sp
        move.w  d0,d6
        pea     cbuf
        move.l  #4,-(sp)
        move.w  d6,-(sp)
        move.w  #$3F,-(sp)
        trap    #1
        lea     12(sp),sp
        move.w  d6,-(sp)
        move.w  #$3E,-(sp)
        trap    #1
        addq.l  #4,sp
        move.w  cbuf,r_cap
        move.w  cbuf+2,intin
        move.w  #1,intin+2
        AES     104,2,5,0
        move.w  intout,r_cw_ok
* ecrit PARENT.RES
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
name:   dc.b    'pexchild.PRG',0
cmd:    dc.b    0,0
fname:  dc.b    'PARENT.RES',0
cfile:  dc.b    'CHILD.RES',0
pname:  dc.b    'PEXGEM  ',0
cname:  dc.b    'PEXCHILD',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
results:
r_ap:   dc.w    0
r_pwin: dc.w    0
r_code: dc.w    0
r_findp: dc.w   0
r_findc: dc.w   0
r_pw_ok: dc.w   0
r_cap:  dc.w    0
r_cw_ok: dc.w   0
resend:
        bss
cbuf:   ds.w    4
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    30
intout: ds.w    30
addrin: ds.l    4
addrout: ds.l    4
