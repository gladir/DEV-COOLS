# GEMDOS : un programme assembleur (assemble par DEVPAC.PAS) appelle Dgetdrv/Dsetdrv/Dsetpath/Dgetpath, Fcreate/Fwrite/
# Fclose/Fopen/Fread/Fseek, Frename, Fsfirst/Fsnext/Fgetdta, Fattrib, Fdelete, Dcreate/Ddelete, Malloc/Mfree/Mshrink,
# range les resultats en memoire, relus a la fin (OSSPAS_EMU=osspas|devpac|devenv).
import sys, os, struct; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from la import *
FAIL=[]
def check(n,c,info=''):
    print(('ok   ' if c else 'FAIL ')+n+(' '+str(info) if (info and not c) else ''))
    if not c: FAIL.append(n)
L=['\topt\to+','start:','\tlea\tres,a6']
def push(a):
    k,v=a
    if k=='w': L.append('\tmove.w\t#%d,-(sp)'%v)
    elif k=='l': L.append('\tmove.l\t#%d,-(sp)'%v)
    elif k=='a': L.append('\tpea\t%s'%v)
    elif k=='hw': L.append('\tmove.w\td6,-(sp)')       # handle courant (d6)
def gd(fn,args=(),keep=True,h=None):
    n=2
    for a in reversed(args):
        push(a); n+=4 if a[0] in('l','a') else 2
    L.append('\tmove.w\t#%d,-(sp)'%fn); L.append('\ttrap\t#1')
    L.append('\tlea\t%d(sp),sp'%n if n>8 else '\taddq.l\t#%d,sp'%n)
    if h: L.append('\tmove.l\td0,d6')
    if keep: L.append('\tmove.l\td0,(a6)+')
def copy4(lbl):             # range les 4 premiers octets du tampon dans les resultats
    L.append('\tmove.l\t%s,(a6)+'%lbl)
gd(0x19)                                   # 0  Dgetdrv
gd(0x0E,[('w',2)])                         # 1  Dsetdrv(2)
gd(0x19)                                   # 2  Dgetdrv
gd(0x3B,[('a','root')])                    # 3  Dsetpath("\")
gd(0x47,[('a','pbuf'),('w',0)]); copy4('pbuf')   # 4,5 Dgetpath
gd(0x3C,[('a','fn1'),('w',0)],h=True)      # 6  Fcreate
gd(0x40,[('hw',0),('l',5),('a','hello')])  # 7  Fwrite 5
gd(0x40,[('hw',0),('l',2),('a','bang')])   # 8  Fwrite 2
gd(0x3E,[('hw',0)])                        # 9  Fclose
gd(0x3D,[('a','fn1'),('w',0)],h=True)      # 10 Fopen
gd(0x3F,[('hw',0),('l',10),('a','buf')]); copy4('buf'); L.append('\tmove.l\tbuf+4,(a6)+')   # 11 Fread, 12,13 contenu
gd(0x42,[('l',2),('hw',0),('w',0)])        # 14 Fseek(2,h,0)
gd(0x3F,[('hw',0),('l',3),('a','buf2')]); copy4('buf2')     # 15 Fread 3, 16 "LLO"
gd(0x42,[('l',0),('hw',0),('w',2)])        # 17 Fseek(0,h,2)
gd(0x3E,[('hw',0)])                        # 18 Fclose
gd(0x56,[('w',0),('a','fn1'),('a','fn2')]) # 19 Frename
gd(0x4E,[('a','fn2'),('w',0)])             # 20 Fsfirst
gd(0x2F,keep=False); L.append('\tmove.l\td0,a0'); L.append('\tmove.l\t26(a0),(a6)+')   # 21 taille dans la DTA
L.append('\tmove.l\t30(a0),(a6)+')         # 22 nom dans la DTA ("GDRE")
gd(0x4F)                                   # 23 Fsnext -> -33
gd(0x43,[('a','fn2'),('w',0),('w',0)])             # 24 Fattrib(get)
gd(0x41,[('a','fn2')])                     # 25 Fdelete
gd(0x41,[('a','fn2')])                     # 26 Fdelete (absent) -> -33
gd(0x3D,[('a','fnx'),('w',0)])             # 27 Fopen absent -> -33
gd(0x39,[('a','dn')])                      # 28 Dcreate
gd(0x3A,[('a','dn')])                      # 29 Ddelete
gd(0x48,[('l',1000)],h=True)               # 30 Malloc(1000) (d6 = adresse)
L.append('\tmove.l\td6,-(sp)'); L.append('\tmove.w\t#$49,-(sp)'); L.append('\ttrap\t#1'); L.append('\taddq.l\t#6,sp'); L.append('\tmove.l\td0,(a6)+')  # 31 Mfree
gd(0x48,[('l',-1)])                        # 32 Malloc(-1) : plus grand bloc
gd(0x4E,[('a','pat'),('w',0)])             # 33 Fsfirst("*.PRG")
L.append('\tmoveq\t#0,d5')
L.append('cnt:\ttst.l\td0')
L.append('\tbne.s\tcnte')
L.append('\taddq.l\t#1,d5')
L.append('\tmove.w\t#$4F,-(sp)'); L.append('\ttrap\t#1'); L.append('\taddq.l\t#2,sp')
L.append('\tcmp.l\t#50,d5'); L.append('\tbcs.s\tcnt')
L.append('cnte:\tmove.l\td5,(a6)+')        # 34 nombre de .PRG trouves
L+=['\tclr.w\t-(sp)','\ttrap\t#1',
 "root:\tdc.b\t'\\\\',0","fn1:\tdc.b\t'GDTEST.TMP',0","fn2:\tdc.b\t'GDREN.TMP',0","fnx:\tdc.b\t'NOFILE.XXX',0","dn:\tdc.b\t'GDDIR',0","pat:\tdc.b\t'*.PRG',0",
 "hello:\tdc.b\t'HELLO',0","bang:\tdc.b\t'!!',0",'\teven','pbuf:\tdc.b\t"XXXX"','\tdc.b\t0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
 'buf:\tds.b\t16','buf2:\tds.b\t8','res:\tds.b\t400']
src='\n'.join(L)+'\n'
pp=asm(src,'GDTEST')
h=open(pp,'rb').read(28); tl,dl=struct.unpack('>II',h[2:10]); off=tl+dl-400
NR=36
sc=runprg(pp,'GDTEST',dump='%X:%d'%(off+TEXTBASE,NR*4))
r=struct.unpack('>%dl'%NR,sc.dump)
def s32(v): return v
print([hex(x&0xFFFFFFFF) for x in r[:35]])
check('Dgetdrv : lecteur courant valide',0<=r[0]<=15)
check('Dsetdrv(2) : table des lecteurs avec C:',(r[1]&4)!=0,hex(r[1]))
check('Dgetdrv apres Dsetdrv(2) = 2',r[2]==2,r[2])
check('Dsetpath(\\) = 0',r[3]==0,r[3])
check('Dgetpath : \\ ou vide',r[4]==0 and (r[5]>>24) in (0x5C,0),hex(r[5]&0xFFFFFFFF))
check('Fcreate : handle valide',r[6]>=0,r[6])
check('Fwrite 5 octets',r[7]==5,r[7]); check('Fwrite 2 octets',r[8]==2,r[8]); check('Fclose = 0',r[9]==0,r[9])
check('Fopen : handle valide',r[10]>=0,r[10])
check('Fread : 7 octets',r[11]==7,r[11])
check('contenu relu = HELLO!!',(r[12]&0xFFFFFFFF)==0x48454C4C and (r[13]>>8)&0xFFFFFF==0x4F2121,(hex(r[12]&0xFFFFFFFF),hex(r[13]&0xFFFFFFFF)))
check('Fseek(2,debut) = 2',r[14]==2,r[14]); check('Fread apres Fseek : 3 octets',r[15]==3,r[15])
check('contenu apres Fseek = LLO',(r[16]>>8)&0xFFFFFF==0x4C4C4F,hex(r[16]&0xFFFFFFFF))
check('Fseek(0,fin) = taille 7',r[17]==7,r[17]); check('Fclose = 0',r[18]==0,r[18])
check('Frename = 0',r[19]==0,r[19])
check('Fsfirst : trouve',r[20]==0,r[20])
check('DTA : taille 7',r[21]==7,r[21]); check('DTA : nom GDRE...',(r[22]&0xFFFFFFFF)==0x47445245,hex(r[22]&0xFFFFFFFF))
check('Fsnext : plus de fichier (ENMFIL = -49)',r[23]==-49,r[23])
check('Fattrib(lecture) : attribut 0 ou archive',r[24] in (0,32),r[24])
check('Fdelete = 0',r[25]==0,r[25]); check('Fdelete d\'un fichier absent = -33',r[26]==-33,r[26])
check('Fopen d\'un fichier absent = -33',r[27]==-33,r[27])
check('Dcreate = 0',r[28]==0,r[28]); check('Ddelete = 0',r[29]==0,r[29])
check('Malloc(1000) : adresse non nulle',r[30]!=0,r[30]); check('Mfree = 0',r[31]==0,r[31])
check('Malloc(-1) : plus grand bloc > 1000',r[32]>1000,r[32])
check('Fsfirst("*.PRG") trouve des fichiers',r[33]==0 and r[34]>=1,(r[33],r[34]))
print('FAILS',FAIL)
