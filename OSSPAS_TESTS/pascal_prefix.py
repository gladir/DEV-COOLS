"""Prefixe tous les identifiants declares au niveau global d'un morceau de programme Pascal (constantes, types,
variables, procedures, fonctions, valeurs d'enumeration). Outil de developpement : sert a porter dans DEVENV.PAS
des routines d'un autre programme sans collision de noms."""
import re,sys
KW=set('and array as asm begin case class const constructor destructor div do downto else end except exports file finalization finally for function goto if implementation in inherited initialization inline interface is label library mod nil not object of on or packed procedure program property raise record repeat resourcestring set shl shr string then threadvar to try type unit until uses var while with xor'.split())
TOK=re.compile(r"""(?P<dir>\{\$[^}]*\})|(?P<com>\{[^}]*\}|\(\*.*?\*\)|//[^\n]*)|(?P<str>'(?:[^']|'')*')|(?P<chr>\#(?:\d+|\$[0-9A-Fa-f]+))|(?P<hex>\$[0-9A-Fa-f]+)|(?P<num>\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?P<id>[A-Za-z_][A-Za-z0-9_]*)|(?P<ws>\s+)|(?P<op>.)""",re.S)
def tokenize(s):
    return [(m.lastgroup,m.group(0)) for m in TOK.finditer(s)]
def declared_globals(toks):
    sig=[i for i,(k,v) in enumerate(toks) if k in ('id','op','str','num','hex','chr')]
    T=[(toks[i][0],toks[i][1].lower() if toks[i][0]=='id' else toks[i][1],toks[i][1]) for i in sig]
    n=len(T); G=set()
    def isk(i,*w): return i<n and T[i][0]=='id' and T[i][1] in w
    def skip_to_semi(i):
        d=0
        while i<n:
            k,l,o=T[i]
            if o in '([': d+=1
            elif o in ')]': d-=1
            elif k=='id' and l=='record': d+=1
            elif k=='id' and l=='end' : d-=1
            elif o==';' and d<=0: return i+1
            i+=1
        return i
    def skip_decl_sections_body(i):
        while i<n:
            if isk(i,'const','type','var','label'):
                i+=1
                d=0
                while i<n:
                    if T[i][0]=='id':
                        l=T[i][1]
                        if l=='record' or l=='object': d+=1
                        elif l=='end' and d>0: d-=1
                        elif d==0 and l in ('const','type','var','label','procedure','function','begin'): break
                    i+=1
            elif isk(i,'procedure','function'):
                i=skip_routine(i)
            elif isk(i,'begin','asm'):
                st=[]
                while i<n:
                    if T[i][0]=='id':
                        l=T[i][1]
                        if l in ('begin','try','asm'): st.append(l)
                        elif l=='record': st.append('record')
                        elif l=='case':
                            if not (st and st[-1]=='record'): st.append('case')
                        elif l=='end':
                            st.pop()
                            if not st: return i+1
                    i+=1
                return i
            else: i+=1
        return i
    def skip_routine(i):
        i+=1
        d=0
        while i<n:
            o=T[i][2]
            if o=='(': d+=1
            elif o==')': d-=1
            elif o==';' and d==0: i+=1;break
            i+=1
        while i<n and T[i][0]=='op' and T[i][2]==';': i+=1
        while isk(i,'stdcall','cdecl','pascal','register','overload','export','far','near','interrupt','alias'):
            i=skip_to_semi(i)
        if isk(i,'forward','external','inline'):
            return skip_to_semi(i)
        i=skip_decl_sections_body(i)
        if i<n and T[i][2]==';': i+=1
        return i
    i=0; sec=None
    while i<n:
        if isk(i,'begin'): break
        if isk(i,'uses','program'):
            i=skip_to_semi(i);continue
        if isk(i,'const','type','var','label'):
            sec=T[i][1];i+=1;continue
        if isk(i,'procedure','function'):
            j=i+1
            if j<n and T[j][0]=='id': G.add(T[j][2])
            i=skip_routine(i);sec=None;continue
        if sec=='var':
            names=[]
            while i<n and T[i][0]=='id' and T[i][1] not in KW:
                names.append(T[i][2]);i+=1
                if T[i][2]==',': i+=1
                else: break
            if i<n and T[i][2]==':':
                for x in names: G.add(x)
                i=skip_to_semi(i)
            else: i+=1
            continue
        if sec=='const':
            if T[i][0]=='id' and T[i][1] not in KW:
                G.add(T[i][2]); i=skip_to_semi(i); continue
            i+=1;continue
        if sec=='type':
            if T[i][0]=='id' and T[i][1] not in KW and i+1<n and T[i+1][2]=='=':
                G.add(T[i][2]); j=i+2
                if j<n and T[j][2]=='(':
                    j+=1
                    while j<n and T[j][2]!=')':
                        if T[j][0]=='id': G.add(T[j][2])
                        j+=1
                i=skip_to_semi(i+2); continue
            i+=1;continue
        i+=1
    return G
def rename(src,prefix,extra_skip=(),G=None,fields=True):
    """Prefixe les identifiants globaux. G : ensemble des globaux (par defaut ceux de src). fields=False : un identifiant
    derriere un point simple (champ d'enregistrement d'un autre programme) n'est pas renomme."""
    toks=tokenize(src)
    if G is None: G=declared_globals(toks)
    Gl={g.lower():g for g in G}
    skip={x.lower() for x in extra_skip}
    out=[]; prev=''; prev2=''
    for k,v in toks:
        field = (not fields) and prev=='.' and prev2!='.'
        if k=='id' and v.lower() in Gl and v.lower() not in skip and v.lower() not in KW and not field:
            out.append(prefix+v)
        else: out.append(v)
        if k in('id','op','str','num','hex','chr'): prev2=prev; prev=v
    return ''.join(out),G


def units(src):
    """Decoupe un source Pascal en declarations de premier niveau : liste de (noms, texte, indice) dans l'ordre du source.
    Une declaration = une routine complete (en-tete et corps, ou Forward), une entree de Const/Type/Var."""
    toks=tokenize(src)
    sig=[i for i,(k,v) in enumerate(toks) if k in ('id','op','str','num','hex','chr')]
    T=[(toks[i][0],toks[i][1].lower() if toks[i][0]=='id' else toks[i][1],toks[i][1]) for i in sig]
    n=len(T)
    def isk(i,*w): return i<n and T[i][0]=='id' and T[i][1] in w
    def skip_to_semi(i):
        d=0
        while i<n:
            k,l,o=T[i]
            if o in '([': d+=1
            elif o in ')]': d-=1
            elif k=='id' and l=='record': d+=1
            elif k=='id' and l=='end': d-=1
            elif o==';' and d<=0: return i+1
            i+=1
        return i
    def skip_body(i):
        while i<n:
            if isk(i,'const','type','var','label'):
                i+=1; d=0
                while i<n:
                    if T[i][0]=='id':
                        l=T[i][1]
                        if l in('record','object'): d+=1
                        elif l=='end' and d>0: d-=1
                        elif d==0 and l in ('const','type','var','label','procedure','function','begin'): break
                    i+=1
            elif isk(i,'procedure','function'): i=skip_routine(i)
            elif isk(i,'begin','asm'):
                st=[]
                while i<n:
                    if T[i][0]=='id':
                        l=T[i][1]
                        if l in('begin','try','asm'): st.append(l)
                        elif l=='record': st.append('record')
                        elif l=='case':
                            if not(st and st[-1]=='record'): st.append('case')
                        elif l=='end':
                            st.pop()
                            if not st: return i+1
                    i+=1
                return i
            else: i+=1
        return i
    def skip_routine(i):
        i+=1; d=0
        while i<n:
            o=T[i][2]
            if o=='(': d+=1
            elif o==')': d-=1
            elif o==';' and d==0: i+=1; break
            i+=1
        while i<n and T[i][2]==';': i+=1
        while isk(i,'stdcall','cdecl','pascal','register','overload','export','far','near','interrupt','alias'): i=skip_to_semi(i)
        if isk(i,'forward','external','inline'): return skip_to_semi(i)
        i=skip_body(i)
        if i<n and T[i][2]==';': i+=1
        return i
    out=[]   # (names, kind, t0, t1) en indices de tokens significatifs
    i=0; sec=None
    while i<n:
        if isk(i,'begin'): break
        if isk(i,'uses','program'): i=skip_to_semi(i); continue
        if isk(i,'const','type','var','label'): sec=T[i][1]; i+=1; continue
        if isk(i,'procedure','function'):
            j=i+1; nm=T[j][2] if j<n and T[j][0]=='id' else None
            e=skip_routine(i); out.append(([nm],'routine',i,e)); i=e; sec=None; continue
        if sec=='var':
            st=i; names=[]
            while i<n and T[i][0]=='id' and T[i][1] not in KW:
                names.append(T[i][2]); i+=1
                if T[i][2]==',': i+=1
                else: break
            if i<n and T[i][2]==':':
                e=skip_to_semi(i); out.append((names,'var',st,e)); i=e
            else: i=st+1
            continue
        if sec=='const':
            if T[i][0]=='id' and T[i][1] not in KW:
                e=skip_to_semi(i); out.append(([T[i][2]],'const',i,e)); i=e; continue
            i+=1; continue
        if sec=='type':
            if T[i][0]=='id' and T[i][1] not in KW and i+1<n and T[i+1][2]=='=':
                names=[T[i][2]]; j=i+2
                if j<n and T[j][2]=='(':
                    j+=1
                    while j<n and T[j][2]!=')':
                        if T[j][0]=='id': names.append(T[j][2])
                        j+=1
                e=skip_to_semi(i+2); out.append((names,'type',i,e)); i=e; continue
            i+=1; continue
        i+=1
    # texte exact de chaque unite : de la position du premier jeton a la fin du dernier
    res=[]
    for names,kind,a,b in out:
        ta=sig[a]; tb=sig[b-1]
        txt=''.join(v for k,v in toks[ta:tb+1])
        ids=[v for k,v in toks[ta:tb+1] if k=='id']
        res.append((names,kind,txt,ids,ta))
    return res
