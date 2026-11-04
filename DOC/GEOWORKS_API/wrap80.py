#!/usr/bin/env python3
"""Coupe les lignes Pascal de plus de LIM colonnes (sans changer le code)."""
import sys,re
LIM=80
KW_BREAK_BEFORE={'then','do','else','of','and','or','xor','shl','shr','to',
                 'downto','begin','end','until','mod','div','in'}
KW_BREAK_AFTER={'begin','then','do','else','of','repeat'}
OPS2=(':=','<=','>=','<>','..','(*','*)','(.','.)')

def tokenize(line,in_cmt):
    """retourne (tokens, in_cmt_final). token=(text,kind,space_before)"""
    toks=[];i=0;n=len(line)
    sp=''
    # indentation
    while i<n and line[i] in ' \t':
        i+=1
    ind=line[:i]
    sp=''
    def add(t,k):
        nonlocal sp
        toks.append((t,k,sp));sp=''
    while i<n:
        c=line[i]
        if in_cmt:
            # mots de commentaire jusqu'a }
            j=i
            while j<n and line[j]!='}' and line[j]!=' ':
                j+=1
            if j>i:
                add(line[i:j],'cw')
                i=j
                continue
            if line[i]==' ':
                sp=' ';i+=1;continue
            # '}'
            add('}','cclose');in_cmt=False;i+=1;continue
        if c in ' \t':
            sp=' ';i+=1;continue
        if c=='{':
            if line.startswith('{$',i):
                j=line.find('}',i)
                if j<0: j=n-1
                add(line[i:j+1],'dir');i=j+1;continue
            add('{','copen');in_cmt=True;i+=1;continue
        if c=="'":
            j=i+1
            while j<n:
                if line[j]=="'":
                    if j+1<n and line[j+1]=="'":
                        j+=2;continue
                    break
                j+=1
            add(line[i:j+1],'str');i=j+1;continue
        if c=='#':
            j=i+1
            while j<n and line[j].isdigit(): j+=1
            add(line[i:j],'chr');i=j;continue
        if c.isalpha() or c=='_':
            j=i
            while j<n and (line[j].isalnum() or line[j]=='_'): j+=1
            add(line[i:j],'id');i=j;continue
        if c.isdigit() or (c=='$' and i+1<n and line[i+1] in '0123456789abcdefABCDEF'):
            j=i+1
            while j<n and (line[j].isalnum()):
                j+=1
            # partie decimale / exposant
            if j+1<n and line[j]=='.' and line[j+1].isdigit() and c!='$':
                j+=1
                while j<n and line[j].isalnum(): j+=1
                if line[j-1] in 'eE' and j<n and line[j] in '+-':
                    j+=1
                    while j<n and line[j].isdigit(): j+=1
            add(line[i:j],'num');i=j;continue
        if line[i:i+2] in OPS2:
            add(line[i:i+2],'op');i+=2;continue
        add(c,'op');i+=1
    return ind,toks,in_cmt

def split_str(tok):
    """decoupe une chaine longue en morceaux (apres un espace), None sinon"""
    body=tok
    if len(body)<=60: return None
    parts=[];cur=''
    i=0
    while i<len(body):
        ch=body[i]
        cur+=ch
        if ch=="'" and i+1<len(body) and body[i+1]=="'" and i>0:
            # quote double : garder ensemble
            cur+="'";i+=2
            continue
        i+=1
        if ((ch==" " and len(cur)>=30) or len(cur)>=58) and i<len(body)-1 and body[i]!="'":
            parts.append(cur);cur=''
    if cur: parts.append(cur)
    if len(parts)<2: return None
    # chaque morceau doit etre une chaine entre quotes
    res=[]
    for k,p in enumerate(parts):
        if k==0: res.append(p+"'")
        elif k==len(parts)-1: res.append("'"+p)
        else: res.append("'"+p+"'")
    return res

def prep(toks):
    """pre-decoupage des chaines longues et marquage des soudures de chaines"""
    out=[]
    for t,k,sp in toks:
        if k=='str':
            parts=split_str(t)
            if parts:
                for q,p in enumerate(parts):
                    out.append((p,'strp' if q else 'str',sp if q==0 else ''))
                    # marque : le morceau suivant est une soudure
                continue
        out.append((t,k,sp))
    return out

def tier(prev,nxt,depth):
    pt,pk,_=prev;nt,nk,nsp=nxt
    if nk=='strp': return 6
    # soudure de chaines (pas d'espace d'origine) : seulement avec '+'
    if nsp=='' and nk in('str','strp','chr') and pk in('str','strp','chr'):
        return 6
    if nsp=='' and nk in('str','chr') and pk in('str','strp','chr'):
        return 6
    if pk in('cw','copen') or nk in('cw','cclose'):
        return 2 if nk=='cw' else 99
    if pk=='dir' or nk=='dir': return 3
    if pt==';' and depth==0: return 1
    if pt==',': return 2
    if nk=='id' and nt.lower() in KW_BREAK_BEFORE: return 3
    if pk=='id' and pt.lower() in KW_BREAK_AFTER: return 3
    if nt in('+','-','*','/','=','<>','<','>','<=','>=') and nsp: return 4
    if pt==':=' : return 5
    if nt in('.','^','(','[','@',')',']',':',';',',','..') or pt in('.','^','(','[','@','..'):
        return 9
    return 5

def wrap_line(line,in_cmt):
    ind,toks,end_cmt=tokenize(line,in_cmt)
    toks=prep(toks)
    if len(line)<=LIM:
        return [line],end_cmt
    if not toks:
        return [line],end_cmt
    # le debut de ligne peut etre un morceau de commentaire deja ouvert
    out=[];i=0;cur_ind=ind;first=True
    depth_at=[0]*(len(toks)+1)
    d=0
    for j,(t,k,sp) in enumerate(toks):
        depth_at[j]=d
        if k in('op',):
            if t in('(','['): d+=1
            elif t in(')',']'): d=max(0,d-1)
    depth_at[len(toks)]=d
    inc=in_cmt
    n=len(toks)
    while True:
        # texte potentiel de la ligne depuis le token i
        text=cur_ind;cum=[]
        for j in range(i,n):
            t,k,sp=toks[j]
            if j>i:
                text+=sp
                if k=='strp': text+='+'
            text+=t
            cum.append(len(text))
        if cum[-1]<=LIM:
            out.append(text);break
        # candidats : frontieres b (premier token de la ligne suivante)
        best=None
        cand=[]
        for b in range(i+1,n):
            width=cum[b-i-1]
            t6=tier(toks[b-1],toks[b],depth_at[b])
            if t6==6: width+=1   # le '+' ajoute
            if width>LIM: break
            if t6==99: continue
            cand.append((b,width,t6))
        if not cand:
            # token trop long : on le laisse tel quel (rapporte plus tard)
            b=i+1
            if b>=n:
                out.append(text);break
            t6=tier(toks[b-1],toks[b],depth_at[b]);cand=[(b,cum[0],t6)]
        # choix : meilleur palier avec largeur >= 45% (sinon plus a droite)
        minw=len(cur_ind)+max(20,(LIM-len(cur_ind))*45//100)
        pick=None
        for want in (1,2,3,4,5,6,9):
            ok=[c for c in cand if c[2]==want and c[1]>=minw]
            if ok:
                pick=ok[-1];break
        if pick is None:
            pick=cand[-1]
        b,width,t6=pick
        # texte de la ligne
        seg=cur_ind
        for j in range(i,b):
            t,k,sp=toks[j]
            if j>i:
                seg+=sp
                if toks[j][1]=='strp': seg+='+'
            seg+=t
        if t6==6: seg+='+'
        out.append(seg)
        # indentation de la suite
        if toks[b-1][0]==';' and depth_at[b]==0 and toks[b-1][1]=='op':
            cur_ind=ind
        else:
            cur_ind=ind+'    '
        # un morceau de commentaire reste a l'interieur du commentaire
        i=b
        # si la frontiere est dans un commentaire, l'indentation est celle de base
        if toks[b][1] in('cw',) and toks[b-1][1] in('cw','copen'):
            cur_ind=ind+'  '
        # le premier token d'une ligne n'a pas d'espace
    # fin : retourne le nouvel etat de commentaire
    return out,end_cmt

def process(src):
    lines=src.split('\n')
    res=[];in_cmt=False
    for ln in lines:
        if len(ln)>LIM:
            o,in_cmt2=wrap_line(ln,in_cmt)
            res.extend(o)
            in_cmt=in_cmt2
        else:
            # suivre l'etat de commentaire
            _,_,in_cmt=tokenize(ln,in_cmt)
            res.append(ln)
    return '\n'.join(res)

if __name__=='__main__':
    s=open(sys.argv[1],encoding='latin-1').read()
    o=process(s)
    open(sys.argv[2],'w',encoding='latin-1',newline='\n').write(o)
    bad=[(i+1,len(l)) for i,l in enumerate(o.split('\n')) if len(l)>LIM]
    print('lignes >%d restantes: %d'%(LIM,len(bad)),bad[:10])
