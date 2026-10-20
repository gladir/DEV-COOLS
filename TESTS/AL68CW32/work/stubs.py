# stubs.py fichier.asm : ajoute au listing genere le runtime d'essai (TODO 22
# en miniature) : routines ALLOC (tampon de 16 Ko), CHKIDX, DIVZERO, NILREF,
# BOUNDS, STRCMP (codes de sortie) et, depuis rt_code.inc / rt_data.inc,
# WRITE*, NEWLINE, SPACE, WHOLE, READ*, STRCAT. Le dossier de stubs.py doit
# contenir rt_code.inc et rt_data.inc. Utilise avec chk.sh ou runp.sh.
import sys,os
f=sys.argv[1]
d=os.path.dirname(os.path.abspath(__file__))
s=open(f).read()
if '_A68RT_ALLOC:' in s: sys.exit(0)
if 'hbuf' not in s:
    s=s.replace('.DATA\n','.DATA\nhbuf DB 16384 DUP(0)\nhpp DD hbuf\n'+open(d+'/rt_data.inc').read(),1)
stubs=[('DIVZERO',99),('NILREF',98),('BOUNDS',96),('STRCMP',94)]
t=''
for n,c in stubs:
    if '_A68RT_%s:'%n not in s:
        t+='_A68RT_%s:\n        PUSH    %d\n        CALL    ExitProcess\n'%(n,c)
if '_A68RT_CHKIDX:' not in s:
    t+='_A68RT_CHKIDX:\n        CMP EAX, ECX\n        JL chkbad\n        CMP EAX, EDX\n        JG chkbad\n        RET\nchkbad:\n        PUSH 97\n        CALL ExitProcess\n'
t+='_A68RT_ALLOC:\n        MOV ECX, DWORD PTR [hpp]\n        ADD DWORD PTR [hpp], EAX\n        MOV EAX, ECX\n        RET\n'
t+=open(d+'/rt_code.inc').read()
s=s.replace('\nEND ','\n'+t+'\nEND ',1)
open(f,'w').write(s)
