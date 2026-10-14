#!/usr/bin/env python3
"""embed_tpc.py TPC.PAS TPCW32_IN.PAS TPCW32_OUT.PAS [rename1,rename2,...]
Insere (ou remplace) le moteur de compilation de TPC.PAS dans TPCW32.PAS entre les
marqueurs DEBUT/FIN MOTEUR TPC. Les identificateurs globaux de la liste sont
prefixes par 'Tp' pour eviter les collisions avec ceux de TPCW32."""
import re,sys
tpc,src,dst=sys.argv[1],sys.argv[2],sys.argv[3]
renames=[r for r in (sys.argv[4].split(',') if len(sys.argv)>4 and sys.argv[4] else []) if r]
T=open(tpc,encoding='latin-1').read()
# corps: apres "Uses Dos;" jusqu'au BEGIN principal (dernier "BEGIN" en debut de ligne)
i=T.index('\nUses Dos;\n')+len('\nUses Dos;\n')
j=T.rindex('\nBEGIN\n')
body=T[i:j]
main=T[j+len('\nBEGIN\n'):]
main=main[:main.rindex('END.')]
# ParseArguments: arguments fournis par TPCW32 plutot que la ligne de commande
k=body.index('Procedure ParseArguments')
l=body.index('\nEnd;\n',k)+6
pa=body[k:l].replace('ParamCount','EngineArgCount').replace('ParamStr(','EngineArg(')
body=body[:k]+pa+body[l:]
main=main.replace("Define('VER70');","Case EngineTPVersion Of 4:Define('VER40'); 5:Define('VER50'); 55:Define('VER55'); 6:Define('VER60'); Else Define('VER70') End;")
eng=body+"\nProcedure TpcEngineMain;\nBegin\n"+main+"End;\n"
# renommage des identificateurs en collision (hors chaines)
def ren(text):
    if not renames: return text
    pat=re.compile(r"\b("+"|".join(re.escape(r) for r in renames)+r")\b",re.I)
    # scanner: code / chaine '...' / commentaire { } ou (* *) ; renommer dans le code seulement
    out=[];i=0;n=len(text);code=[]
    def flush():
        if code: out.append(pat.sub(lambda m:'Tp'+m.group(1),''.join(code))); code.clear()
    while i<n:
        c=text[i]
        if c=="'":
            j=text.index("'",i+1)
            while j+1<n and text[j+1]=="'": j=text.index("'",j+2)
            flush(); out.append(text[i:j+1]); i=j+1
        elif c=='{':
            j=text.index('}',i); flush(); out.append(text[i:j+1]); i=j+1
        elif c=='(' and text.startswith('(*',i):
            j=text.index('*)',i)+2; flush(); out.append(text[i:j]); i=j
        else:
            code.append(c); i+=1
    flush(); return ''.join(out)
eng=ren(eng)
head="""{ === DEBUT MOTEUR TPC ===
  Moteur de compilation Turbo Pascal 7.0 pour la cible DOS mode reel (-CD):
  copie du compilateur TPC.PAS de ce depot, inseree par
  TESTS/CORAIL_TPC/embed_tpc.py. NE PAS EDITER ICI: modifier TPC.PAS puis
  regenerer. Les identificateurs en collision avec TPCW32 sont prefixes Tp. }
{$A-}{$R-}{$Q-}{$I+}
Var
  EngineArgs: Array[1..64] Of String;
  EngineArgCount, EngineTPVersion: Integer;
Function EngineArg(I: Integer): String;
Begin
  If (I>=1) And (I<=EngineArgCount) Then EngineArg:=EngineArgs[I] Else EngineArg:='';
End;
"""
tail="{$A+}{$I-}\n{ === FIN MOTEUR TPC === }\n"
W=open(src,encoding='latin-1').read()
m1='{ === DEBUT MOTEUR TPC ==='; m2='{ === FIN MOTEUR TPC === }\n'
if m1 in W:
    a=W.index(m1); b=W.index(m2)+len(m2); W=W[:a]+head+eng+tail+W[b:]
else:
    a=W.index('\nProcedure RunTpcEngine')+1
    W=W[:a]+head+eng+tail+'\n'+W[a:]
    W=W.replace('\nProgram TPCW32;\n','\nProgram TPCW32;\n\nUses Dos;\n',1)
open(dst,'w',encoding='latin-1').write(W)
print('engine lines',eng.count('\n'),'renames',len(renames))
