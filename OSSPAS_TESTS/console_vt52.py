# Console VT52 sur l'ecran bitmap : Cconws, ESC E (efface), ESC Y (position), ESC p/q (inverse), retour chariot et saut de ligne.
import sys, os, struct; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
if EMU=='devpac':
    print('ignore : en mode /EMUL sans interface (/B), DEVPAC.PAS envoie la console sur la sortie standard, pas sur le bitmap'); sys.exit(0)
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
p0=P(); FONT=run(p0,'fnt',dump='%X:4096'%FONTADDR).dump
def glyph16(c): return [[(FONT[r*256+c]>>(7-i))&1 for i in range(8)] for r in range(16)]
p=P()
msg=b'\x1bEAB\r\nCD\x1bY%c%cZ\x1bpR\x1bq!\x00'%(32+5,32+10)
mo=p.d(msg)
p.w(0x2F3C); p.fix.append((len(p.code),mo)); p.rel.append(len(p.code)); p.l(0)     # move.l #msg,-(sp)
p.w(0x3F3C); p.w(9); p.w(0x4E41); p.w(0x5C8F)                                      # move.w #9,-(sp) ; trap #1 ; addq.l #6,sp
s=run(p,'vt52')
exp={}
for (c,row,col,rev) in [('A',0,0,0),('B',0,1,0),('C',1,0,0),('D',1,1,0),('Z',5,10,0),('R',5,11,1),('!',5,12,0)]:
    exp[(row,col)]=(ord(c),rev)
bad=[]
for row in range(25):
    for col in range(80):
        want=glyph16(exp[(row,col)][0]) if (row,col) in exp else [[0]*8 for _ in range(16)]
        if (row,col) in exp and exp[(row,col)][1]: want=[[1-v for v in r] for r in want]
        if s.box(col*8,row*16,8,16)!=want: bad.append((row,col))
check('terminal VT52 : texte, ESC E, ESC Y, ESC p/q, CR LF',not bad,bad[:6])
print('FAILS',FAIL)
