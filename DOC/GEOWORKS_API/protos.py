import re,json
T4={'dword','sdword','long','unsigned long','optr','fptr','WWFixedAsDWord','dword','XYValueAsDWord','PointDWord','LongInt','ULong','fixed32','WWFixed','FileLongName'}
def tsize(t):
    t=t.strip()
    t=re.sub(r'\bconst\b|\bstruct\b|\b_near\b|\b_far\b|\bunsigned\b|\bsigned\b','',t).strip()
    if '*' in t: return 4
    if t in ('void',''): return 0
    if t in T4: return 4
    if t in ('word','byte','char','int','short','sword','sbyte','Boolean','Message','ChunkHandle','MemHandle','VMBlockHandle','GeodeHandle','ThreadHandle','FileHandle','VMFileHandle','GStateHandle','WindowHandle','EventHandle','QueueHandle','TimerHandle','word'): return 2
    if t.endswith('Handle') or t.endswith('Flags') or t.endswith('Type') or t.endswith('Mode'): return 2
    if t in ('long','dword'): return 4
    return 2
def parse(path):
    L=open(path,encoding='utf-8',errors='replace').read().split('\n')
    out={}
    i=0
    while i<len(L):
        m=re.match(r'^\s*■\s+([A-Za-z_][A-Za-z0-9_]*)\(\)\s*$',L[i])
        if m:
            name=m.group(1)
            # prototype : lignes suivantes jusqu'a ');'
            txt=''
            j=i+1
            while j<len(L) and j<i+30:
                s=re.sub(r'/\*.*?\*/','',L[j]).strip()
                txt+=' '+s
                if ');' in s or re.search(r'\)\s*;',s): break
                if s=='' and txt.strip()=='' : j+=1; continue
                j+=1
            mm=re.match(r'\s*(.*?)\b'+re.escape(name)+r'\s*\((.*)\)\s*;',txt)
            if mm and name not in out:
                ret=mm.group(1).strip(); params=mm.group(2).strip()
                if params in ('void',''): ps=[]
                else:
                    ps=[p.strip() for p in params.split(',')]
                sizes=[]
                for p in ps:
                    if p=='...': sizes.append(-1); continue
                    p2=re.sub(r'\[.*?\]','*',p)
                    # enlever le nom de la variable (dernier mot)
                    mt=re.match(r'^(.*?)([A-Za-z_][A-Za-z0-9_]*)?\s*$',p2.replace('*',' * '))
                    ty=p2
                    parts=p2.replace('*',' * ').split()
                    if len(parts)>=2 and parts[-1]!='*': ty=' '.join(parts[:-1])
                    sizes.append(tsize(ty))
                out[name]=dict(ret=ret,args=ps,argbytes=(None if -1 in sizes else sum(sizes)),retbytes=tsize(ret) if ret!='void' else 0)
        i+=1
    return out
if __name__=='__main__':
    d=parse('/tmp/pdf/cref.txt'); print(len(d))
    for n in ('MemAlloc','MemLock','MemFree','MemUnlock','FileRead','FileWrite','FilePos','FileTruncate','GrDrawLine','ObjMessage','UserStandardDialog','UserDoDialog','GrDrawText','GrSetLineColor','malloc','free','strlen','FileOpen'):
        print(n,d.get(n))
    json.dump(d,open('/tmp/gx/protos.json','w'))
