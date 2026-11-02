* Assembler avec :  devpac /B /OUT:clock.acc clock.acc.s  puis placer CLOCK.ACC a cote du programme GEM execute (par exemple gemdemo.s).
* Accessoire de bureau de demonstration
        text
start:
        move.w  #10,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        clr.w   ctrl+6
        clr.w   ctrl+8
        bsr     aes
        move.w  intout,apid
* menu_register(apid, "  Mon accessoire")
        move.w  #35,ctrl
        move.w  #1,ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.w  apid,intin
        move.l  #name,addrin
        bsr     aes
        move.w  intout,menuid
loop:
        move.w  #23,ctrl
        clr.w   ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.l  #msgbuf,addrin
        bsr     aes
        cmp.w   #40,msgbuf
        bne.s   loop
        move.w  msgbuf+8,d0
        cmp.w   menuid,d0
        bne.s   loop
* form_alert
        move.w  #52,ctrl
        move.w  #1,ctrl+2
        move.w  #1,ctrl+4
        move.w  #1,ctrl+6
        clr.w   ctrl+8
        move.w  #1,intin
        move.l  #alert,addrin
        bsr     aes
        bra     loop

aes:    move.l  #aespb,d1
        move.w  #200,d0
        trap    #2
        rts

        data
name:   dc.b    '  Demo accessory',0
alert:  dc.b    '[1][Accessoire de bureau|execute en multitache|cooperatif !][ Super ]',0
        even
aespb:  dc.l    ctrl,global,intin,intout,addrin,addrout
        bss
ctrl:   ds.w    10
global: ds.w    16
intin:  ds.w    16
intout: ds.w    16
addrin: ds.l    4
addrout: ds.l    4
msgbuf: ds.w    8
apid:   ds.w    1
menuid: ds.w    1
