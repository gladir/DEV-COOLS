#!/usr/bin/env python3
# fuzz.py graine nombre [AL68CW32] : mutations aleatoires (jeton supprime,
# double, echange ou precede d'un jeton parasite) des exemples de
# SAMPLES/ALGOL68 ; le compilateur ne doit jamais s'arreter autrement que
# par le code 0 ou 1, ni boucler (timeout 15 s).
import random,subprocess,glob,re,sys
random.seed(int(sys.argv[1]))
import os,tempfile
here=os.path.dirname(os.path.abspath(__file__))
comp=sys.argv[3] if len(sys.argv)>3 else os.path.join(here,'..','..','BINLINUX','AL68CW32')
files=glob.glob(os.path.join(here,'..','..','SAMPLES','ALGOL68','*.a68'))+glob.glob(os.path.join(here,'work','*.a68'))
os.chdir(tempfile.mkdtemp())
os.mkdir('fz')
bad=0
for n in range(int(sys.argv[2])):
    f=random.choice(files)
    src=open(f,encoding='latin-1').read()
    toks=re.findall(r'\s+|\w+|"[^"\n]*"|.',src)
    k=random.randrange(1,4)
    for _ in range(k):
        i=random.randrange(len(toks))
        m=random.choice(['del','dup','swap','ins'])
        if m=='del': toks[i]=''
        elif m=='dup': toks[i]=toks[i]*2
        elif m=='swap' and i+2<len(toks): toks[i],toks[i+2]=toks[i+2],toks[i]
        else: toks[i]=random.choice([';',')','(','END','FI','OD',',',':=','+','IF','PROC','[',']','"','CO','THEN','1'])+' '+toks[i]
    name='fz/f%d.a68'%n
    open(name,'w',encoding='latin-1').write(''.join(toks))
    try:
        r=subprocess.run([comp,'-w','-obj',name],capture_output=True,text=True,timeout=15)
        if r.returncode not in (0,1):
            print('CRASH rc',r.returncode,f,name,(r.stdout+r.stderr)[-200:]); bad+=1
    except subprocess.TimeoutExpired:
        print('TIMEOUT',f,name); bad+=1
print('fini, problemes:',bad)
