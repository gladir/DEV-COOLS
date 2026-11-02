; GemDemo : programme GEM de demonstration (menus, fenetre, dialogue, alerte)
	text
start:
	move.w #10,ctrl
	move.w #0,ctrl+2
	move.w #1,ctrl+4
	move.w #0,ctrl+6
	move.w #0,ctrl+8
	bsr aes
	move.w intout,apid
	move.w #77,ctrl
	move.w #0,ctrl+2
	move.w #5,ctrl+4
	move.w #0,ctrl+6
	move.w #0,ctrl+8
	bsr aes
	move.w intout,vhandle
	lea vintin,a0
	moveq #9,d0
.oi:	move.w #1,(a0)+
	dbra d0,.oi
	move.w #2,(a0)
	move.w #100,vctrl
	move.w #0,vctrl+2
	move.w #11,vctrl+6
	move.w #0,vctrl+10
	move.w vhandle,vctrl+12
	bsr vdi
	move.w vctrl+12,vhandle
	move.w #23,vctrl
	move.w #0,vctrl+2
	move.w #1,vctrl+6
	move.w #0,vctrl+10
	move.w vhandle,vctrl+12
	move.w #0,vintin+0
	bsr vdi
	move.w #78,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	move.w #0,ctrl+8
	move.w #0,intin+0
	move.l #0,addrin+0
	bsr aes
	move.w #30,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	move.w #0,ctrl+8
	move.w #1,intin+0
	move.l #menutree,addrin+0
	bsr aes
	move.w #100,ctrl
	move.w #5,ctrl+2
	move.w #1,ctrl+4
	move.w #0,ctrl+6
	move.w #0,ctrl+8
	move.w #4079,intin+0
	move.w #0,intin+2
	move.w #19,intin+4
	move.w #640,intin+6
	move.w #381,intin+8
	bsr aes
	move.w intout,whandle
	move.w whandle,intin
	move.w #2,intin+2
	move.l #wtitle,d0
	move.w d0,intin+6
	swap d0
	move.w d0,intin+4
	move.w #105,ctrl
	move.w #6,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	move.w whandle,intin
	move.w #60,intin+2
	move.w #60,intin+4
	move.w #400,intin+6
	move.w #220,intin+8
	move.w #101,ctrl
	move.w #5,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
mainloop:
	move.l #msgbuf,addrin
	move.w #23,ctrl
	move.w #0,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	move.w #0,ctrl+8
	move.l #msgbuf,addrin+0
	bsr aes
	move.w msgbuf,d0
	cmp.w #10,d0
	beq menusel
	cmp.w #20,d0
	beq redraw
	cmp.w #21,d0
	beq topped
	cmp.w #22,d0
	beq quit
	cmp.w #23,d0
	beq fulled
	cmp.w #27,d0
	beq sized
	cmp.w #28,d0
	beq moved
	bra mainloop
topped:	move.w msgbuf+6,intin
	move.w #10,intin+2
	move.w #105,ctrl
	move.w #6,ctrl+2
	move.w #1,ctrl+4
	move.w #0,ctrl+6
	move.w #0,ctrl+8
	bsr aes
	move.w msgbuf+6,intin
	move.w #10,intin+2
	move.w #105,ctrl
	move.w #6,ctrl+2
	move.w #1,ctrl+4
	bsr aes
	bra mainloop
sized:
moved:
	move.w msgbuf+6,intin
	move.w #5,intin+2
	move.w msgbuf+8,intin+4
	move.w msgbuf+10,intin+6
	move.w msgbuf+12,intin+8
	move.w msgbuf+14,intin+10
	move.w #105,ctrl
	move.w #6,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	bra mainloop
fulled:	move.w msgbuf+6,intin
	move.w #5,intin+2
	move.w #0,intin+4
	move.w #19,intin+6
	move.w #640,intin+8
	move.w #381,intin+10
	move.w #105,ctrl
	move.w #6,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	bra mainloop
menusel:
	move.w msgbuf+8,d3
	move.w msgbuf+6,d2
	cmp.w #18,d3
	beq quit
	cmp.w #17,d3
	beq doalert
	cmp.w #16,d3
	beq dodialog
	cmp.w #8,d3
	beq doabout
menuend:	move.w d2,intin
	move.w #1,intin+2
	move.w #33,ctrl
	move.w #2,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	clr.w ctrl+8
	move.l #menutree,addrin
	bsr aes
	bra mainloop
doabout:	move.w #1,intin
	move.l #aboutstr,addrin
	move.w #52,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	clr.w ctrl+8
	bsr aes
	bra menuend
doalert:	move.w #2,intin
	move.l #alertstr,addrin
	move.w #52,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	clr.w ctrl+8
	bsr aes
	bra menuend
dodialog:
	move.l #dlgtree,addrin
	move.w #54,ctrl
	clr.w ctrl+2
	move.w #5,ctrl+4
	move.w #1,ctrl+6
	clr.w ctrl+8
	bsr aes
	move.w intout+2,fx
	move.w intout+4,fy
	move.w intout+6,fw
	move.w intout+8,fh
	clr.w intin
	move.w fx,intin+2
	move.w fy,intin+4
	move.w fw,intin+6
	move.w fh,intin+8
	move.w fx,intin+10
	move.w fy,intin+12
	move.w fw,intin+14
	move.w fh,intin+16
	move.w #51,ctrl
	move.w #9,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	move.l #dlgtree,addrin
	clr.w intin
	move.w #8,intin+2
	move.w fx,intin+4
	move.w fy,intin+6
	move.w fw,intin+8
	move.w fh,intin+10
	move.w #42,ctrl
	move.w #6,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	clr.w ctrl+8
	bsr aes
	move.l #dlgtree,addrin
	move.w #2,intin
	move.w #50,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	clr.w ctrl+8
	bsr aes
	move.w intout,exitobj
	move.w exitobj,d0
	and.w #$7fff,d0
	mulu #24,d0
	lea dlgtree,a0
	clr.w 10(a0,d0.l)
	move.w #3,intin
	move.w fx,intin+2
	move.w fy,intin+4
	move.w fw,intin+6
	move.w fh,intin+8
	move.w fx,intin+10
	move.w fy,intin+12
	move.w fw,intin+14
	move.w fh,intin+16
	move.w #51,ctrl
	move.w #9,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	bra menuend
redraw:
	move.w msgbuf+6,d6
	move.w #1,intin
	move.w #107,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	move.w d6,intin
	move.w #11,intin+2
	move.w #104,ctrl
	move.w #2,ctrl+2
	move.w #5,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
rdloop:	move.w intout+6,d0
	or.w intout+8,d0
	beq rddone
	move.w intout+2,cx
	move.w intout+4,cy
	move.w intout+6,cw
	move.w intout+8,ch
	bsr drawcontent
	move.w d6,intin
	move.w #12,intin+2
	move.w #104,ctrl
	move.w #2,ctrl+2
	move.w #5,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	bra rdloop
rddone:	clr.w intin
	move.w #107,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	bra mainloop
drawcontent:
	move.w cx,ptsin
	move.w cy,ptsin+2
	move.w cx,d0
	add.w cw,d0
	subq.w #1,d0
	move.w d0,ptsin+4
	move.w cy,d0
	add.w ch,d0
	subq.w #1,d0
	move.w d0,ptsin+6
	move.w cx,ptsin
	move.w cy,ptsin+2
	move.w #1,vctrl+14
	clr.w vctrl+10
	move.w #114,vctrl
	move.w #2,vctrl+2
	clr.w vctrl+6
	move.w vhandle,vctrl+12
	bsr vdi
	move.w #129,vctrl
	move.w #2,vctrl+2
	move.w #1,vctrl+6
	move.w vhandle,vctrl+12
	move.w #1,vintin
	bsr vdi
	move.w #8,vctrl
	move.w #1,vctrl+2
	move.w #14,vctrl+6
	move.w vhandle,vctrl+12
	move.w #80,ptsin
	move.w #110,ptsin+2
	lea hello,a0
	lea vintin,a1
	moveq #13,d0
.ct:	moveq #0,d1
	move.b (a0)+,d1
	move.w d1,(a1)+
	dbra d0,.ct
	bsr vdi
	move.w #11,vctrl
	move.w #3,vctrl+2
	clr.w vctrl+6
	move.w #4,vctrl+10
	move.w vhandle,vctrl+12
	move.w #260,ptsin
	move.w #130,ptsin+2
	clr.w ptsin+4
	clr.w ptsin+6
	move.w #40,ptsin+8
	clr.w ptsin+10
	bsr vdi
	move.w #6,vctrl
	move.w #2,vctrl+2
	clr.w vctrl+6
	clr.w vctrl+10
	move.w vhandle,vctrl+12
	move.w #70,ptsin
	move.w #75,ptsin+2
	move.w #300,ptsin+4
	move.w #200,ptsin+6
	bsr vdi
	clr.w vintin
	move.w #129,vctrl
	move.w #2,vctrl+2
	move.w #1,vctrl+6
	move.w vhandle,vctrl+12
	bsr vdi
	rts
quit:
	move.w whandle,intin
	move.w #102,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	move.w whandle,intin
	move.w #103,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	clr.w intin
	move.w #30,ctrl
	move.w #1,ctrl+2
	move.w #1,ctrl+4
	move.w #1,ctrl+6
	clr.w ctrl+8
	move.l #menutree,addrin
	bsr aes
	move.w #19,ctrl
	clr.w ctrl+2
	move.w #1,ctrl+4
	clr.w ctrl+6
	clr.w ctrl+8
	bsr aes
	clr.w -(sp)
	trap #1
aes:	move.l #aespb,d1
	move.w #200,d0
	trap #2
	rts
vdi:	move.l #vdipb,d1
	moveq #115,d0
	trap #2
	rts
	data
	even
aespb:	dc.l ctrl,global,intin,intout,addrin,addrout
vdipb:	dc.l vctrl,vintin,ptsin,vintout,ptsout
hello:	dc.b "Hello from GEM!"
wtitle:	dc.b " GemDemo window ",0
aboutstr:	dc.b "[1][GemDemo for DEVPAC|AES / VDI emulation][ OK ]",0
alertstr:	dc.b "[2][Do you like GEM ?|It is running on|an emulated Atari ST][ Yes | No | Maybe ]",0
dlgTitle:	dc.b "Enter your name:",0
dlgHint:	dc.b "(Tab, Return and mouse work)",0
btnOK:	dc.b "OK",0
btnCancel:	dc.b "Cancel",0
strDesk:	dc.b "Desk",0
strFile:	dc.b "File",0
mi8:	dc.b "  About GemDemo...",0
mi9:	dc.b "------------------",0
mi10:	dc.b "                  ",0
mi11:	dc.b "                  ",0
mi12:	dc.b "                  ",0
mi13:	dc.b "                  ",0
mi14:	dc.b "                  ",0
mi15:	dc.b "                  ",0
mi16:	dc.b "  Dialog...    ",0
mi17:	dc.b "  Alert        ",0
mi18:	dc.b "  Quit         ",0
tedtext:	dc.b 0
	ds.b 20
tedtmpl:	dc.b "Name: ____________",0
tedvalid:	dc.b "aaaaaaaaaaaa",0
	even
ted0:	dc.l tedtext,tedtmpl,tedvalid
	dc.w 3,0,0,$1180,0,1,21,19
menutree:
	dc.w -1,1,5,25,0,0
	dc.l $00000000
	dc.w 0,0,640,400
	dc.w 5,2,2,20,0,0
	dc.l $00000100
	dc.w 0,0,640,19
	dc.w 1,3,4,25,0,0
	dc.l $00000000
	dc.w 0,0,640,19
	dc.w 4,-1,-1,32,0,0
	dc.l strDesk
	dc.w 8,1,48,17
	dc.w 2,-1,-1,32,0,0
	dc.l strFile
	dc.w 56,1,48,17
	dc.w 0,6,7,25,0,0
	dc.l $00000000
	dc.w 0,19,640,381
	dc.w 7,8,15,20,0,0
	dc.l $00011100
	dc.w 8,0,152,130
	dc.w 5,16,18,20,0,0
	dc.l $00011100
	dc.w 56,0,128,50
	dc.w 9,-1,-1,28,0,0
	dc.l mi8
	dc.w 0,1,152,16
	dc.w 10,-1,-1,28,0,8
	dc.l mi9
	dc.w 0,17,152,16
	dc.w 11,-1,-1,28,0,8
	dc.l mi10
	dc.w 0,33,152,16
	dc.w 12,-1,-1,28,0,8
	dc.l mi11
	dc.w 0,49,152,16
	dc.w 13,-1,-1,28,0,8
	dc.l mi12
	dc.w 0,65,152,16
	dc.w 14,-1,-1,28,0,8
	dc.l mi13
	dc.w 0,81,152,16
	dc.w 15,-1,-1,28,0,8
	dc.l mi14
	dc.w 0,97,152,16
	dc.w 6,-1,-1,28,0,8
	dc.l mi15
	dc.w 0,113,152,16
	dc.w 17,-1,-1,28,0,0
	dc.l mi16
	dc.w 0,1,128,16
	dc.w 18,-1,-1,28,0,0
	dc.l mi17
	dc.w 0,17,128,16
	dc.w 7,-1,-1,28,32,0
	dc.l mi18
	dc.w 0,33,128,16
dlgtree:
	dc.w -1,1,5,20,0,0
	dc.l $00021100
	dc.w 0,0,300,140
	dc.w 2,-1,-1,28,0,0
	dc.l dlgTitle
	dc.w 16,12,264,16
	dc.w 3,-1,-1,29,8,0
	dc.l ted0
	dc.w 16,44,264,16
	dc.w 4,-1,-1,26,7,0
	dc.l btnOK
	dc.w 40,96,80,24
	dc.w 5,-1,-1,26,5,0
	dc.l btnCancel
	dc.w 180,96,80,24
	dc.w 0,-1,-1,28,32,0
	dc.l dlgHint
	dc.w 16,70,264,16
	bss
	even
ctrl:	ds.w 10
global:	ds.w 16
intin:	ds.w 40
intout:	ds.w 50
ptsin:	ds.w 16
ptsout:	ds.w 16
vctrl:	ds.w 12
vintin:	ds.w 40
vintout:	ds.w 50
msgbuf:	ds.w 8
apid:	ds.w 1
vhandle:	ds.w 1
whandle:	ds.w 1
exitobj:	ds.w 1
fx:	ds.w 1
fy:	ds.w 1
fw:	ds.w 1
fh:	ds.w 1
cx:	ds.w 1
cy:	ds.w 1
cw:	ds.w 1
ch:	ds.w 1
addrin:	ds.l 4
addrout:	ds.l 4
