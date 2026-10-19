import json,re,sys
D='/tmp/claude-0/b/p/'
raw=json.load(open(D+'intl_raw.json'))
def pieces(text,n=225):
    # coupe un texte JSON ASCII en morceaux dont le litteral JS reste court, sans couper un echappement
    out=[];i=0
    while i<len(text):
        j=i
        while j<len(text) and len(json.dumps(text[i:j+1]))<=n: j+=1
        if j<len(text):
            # ne pas couper apres un antislash ni dans \uXXXX
            k=j
            while k>i and (text[k-1]=='\\' or (k>=2 and text[k-2]=='\\' and text[k-1]=='u') or re.search(r'\\u[0-9a-fA-F]{0,3}$',text[i:k])):
                k-=1
            j=k
        out.append(text[i:j]); i=j
    return out
def lit(p):
    return json.dumps(p)  # ASCII uniquement
def datafn(name,tags):
    lines=['function %s() {'%name]
    for t in tags:
        text=json.dumps(raw[t],ensure_ascii=True,separators=(',',':'))
        ps=pieces(text)
        lines.append("  __ilreg('%s', ["%t)
        for k,p in enumerate(ps):
            lines.append('    '+lit(p)+(',' if k<len(ps)-1 else ''))
        lines.append("  ].join(''));")
    lines.append('}')
    return '\n'.join(lines)+'\n'
langs={}
for t in raw:
    langs.setdefault(t.split('-')[0],[]).append(t)
# coeur : en-US dans le moteur
eng=open(D+'intl_engine.js').read()
core_en=("function __ilEnUS() {\n  return [\n"+",\n".join('    '+lit(p) for p in pieces(json.dumps(raw['en-US'],ensure_ascii=True,separators=(',',':'))))+"\n  ].join('');\n}\n")
calls=''.join("  __init_il_%s();\n"%l for l in sorted(langs))
eng=eng.replace('//ILCALLS\n',calls)
open(D+'prelude_intl.js','w').write(eng+core_en)
keys={}
stubs=[]
for l,tags in sorted(langs.items()):
    t2=[t for t in tags if t!='en-US']
    if not t2: continue
    fn='__init_il_'+l
    open(D+'prelude_il_%s.js'%l,'w').write(datafn(fn,t2))
    stubs.append(l)
    if l=='en': k='|'.join(t2)
    else: k="'%s-|\"%s-|'%s'|\"%s\"|`%s-"%(l,l,l,l,l)
    keys[l]=k
# stubs pour le prelude de base
core=open(D+'prelude_core.js').read()
core=re.sub(r"function __init_il_\w+\(\) \{\}\n","",core)
st=''.join("function __init_il_%s() {}\n"%l for l in sorted(langs))
if 'function __ilreg()' not in core: st+="function __ilreg() {}\n"
core=core.replace("function __init_intl() {}\n","function __init_intl() {}\n"+st,1)
open(D+'prelude_core.js','w').write(core)
json.dump(keys,open(D+'intl_keys.json','w'))
# fichier de configuration des chunks pour genprelude
print(sorted(langs), len(stubs))
