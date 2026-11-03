#!/usr/bin/env python3
"""Construit DEVENV.PAS sous Linux (pour les tests) : DEVENV.PAS cible Windows ; ce script produit une copie
ou les appels 'External' de DLL Windows sont remplaces par des corps vides, ajoute cthreads et un repli de
ConRawWriteLn, puis compile avec  fpc -Mtp -dWINDOWS.   Ne modifie pas DEVENV.PAS.

  python3 OSSPAS_TESTS/devenv_linux_build.py DEVENV.PAS /tmp/devenv_build        # produit /tmp/devenv_build/devenv
"""
import re,sys,os,subprocess
src,out=sys.argv[1],sys.argv[2]
os.makedirs(out,exist_ok=True)
s=open(src,encoding='latin-1').read()
pat=re.compile(r'(?is)\b(Function|Procedure)\s+(\w+)\s*(\((?:[^()]|\([^()]*\))*\))?\s*(?::\s*(\w+))?\s*;\s*(?:(?:StdCall|CDecl)\s*;\s*)?External\b[^;]*;')
def rep(m):
    kind,name,args,ret=m.group(1),m.group(2),m.group(3) or '',m.group(4)
    if kind.lower()=='procedure': return f'Procedure {name}{args}; Begin End;'
    r=(ret or '').lower()
    if r in ('boolean','longbool','bool','wordbool'): v='False'
    elif r in ('pointer','pchar','thandle','hwnd') or (ret and ret[0]=='P' and len(ret)>2 and ret[1].isupper()): v='Nil'
    else: v='0'
    return f'Function {name}{args}: {ret}; Begin {name}:={v}; End;'
t=pat.sub(rep,s)
t=t.replace('Uses DOS,\n     {$IFDEF FPC}\n      PtcGraph','Uses {$IFDEF UNIX}cthreads,{$ENDIF}DOS,\n     {$IFDEF FPC}\n      PtcGraph',1)
assert 'cthreads' in t
# ConRawWriteLn : version Windows uniquement dans le source
i=t.index('{$IFDEF WINDOWS}\nFunction GetAsyncKeyState')
d=0;lines=t[i:].split('\n');pos=i
for k,l in enumerate(lines):
    u=l.strip().upper()
    if u.startswith('{$IF'): d+=1
    elif u.startswith('{$ENDIF'):
        d-=1
        if d==0:
            end=i+sum(len(x)+1 for x in lines[:k]); break
stub='''{$ELSE}
Var ConRawOut: Text;
    ConRawOpen: Boolean;
Procedure ConRawWriteLn(Const S: String);
Begin
 If Not ConRawOpen Then Begin Assign(ConRawOut,'');Rewrite(ConRawOut);ConRawOpen:=True;End;
 WriteLn(ConRawOut,S);Flush(ConRawOut);
End;
'''
t=t[:end]+stub+t[end:]
p=os.path.join(out,'DEVENV_linux.PAS')
open(p,'w',encoding='latin-1').write(t)
r=subprocess.run(['fpc','-Mtp','-dWINDOWS','-Se2000','-FE'+out,'-o'+os.path.join(out,'devenv'),p],capture_output=True,text=True)
errs=[l for l in r.stdout.split('\n') if ' Error: ' in l or ' Fatal: ' in l or l.startswith(('Error','Fatal'))]
print('\n'.join(errs[:20]) or 'compilation reussie : '+os.path.join(out,'devenv'))
