import re,os,json
ROOT='/home/user/bluewaysw/pcgeos/CInclude'
txt=''
for dp,dn,fn in os.walk(ROOT):
    for f in fn:
        if f.lower().endswith(('.h','.goh')):
            try: txt+='\n'+open(os.path.join(dp,f),encoding='latin-1').read()
            except: pass
txt=re.sub(r'/\*.*?\*/','',txt,flags=re.S); txt=re.sub(r'//[^\n]*','',txt)
# typedefs simples
TD={}
for m in re.finditer(r'typedef\s+([A-Za-z_][\w\s\*]*?)\s+(\w+)\s*;',txt):
    TD.setdefault(m.group(2),m.group(1).strip())
SZ2={'byte','char','sbyte','word','sword','int','short','Boolean','BooleanWord','unsigned','void'}
SZ4={'dword','sdword','long','optr','fptr','float'}
def tsize(t,depth=0):
    t=t.strip()
    t=re.sub(r'\b(const|volatile|struct|union|enum|_near|_far|register)\b','',t).strip()
    if '*' in t or '[' in t: return 4
    t=re.sub(r'\bunsigned\b|\bsigned\b','',t).strip() or 'int'
    if t in SZ2: return 2
    if t in SZ4: return 4
    if t=='double': return None
    if depth<6 and t in TD: return tsize(TD[t],depth+1)
    return 2 if t.endswith(('Handle','Flags','Type','Mode','Enum','Error')) else None
PROT={}
pat=re.compile(r'((?:extern\s+)?[A-Za-z_][\w\s\*]*?)\s*\b_(pascal|cdecl)\s+(\*?)\s*(\w+)\s*\(([^;{}]*?)\)\s*;',re.S)
for m in pat.finditer(txt):
    ret,conv,star,name,args=m.groups()
    ret=re.sub(r'\bextern\b','',ret).strip()+(' *' if star else '')
    args=' '.join(args.split())
    if args in ('void',''): al=[]
    else:
        al=[a.strip() for a in re.split(r',(?![^()]*\))',args)]
    sg='';ok=True
    for a in al:
        if a=='...': sg+='.'; continue
        a2=re.sub(r'\[.*?\]','*',a)
        parts=a2.replace('*',' * ').split()
        ty=' '.join(parts[:-1]) if len(parts)>=2 and parts[-1] not in ('*',) and not parts[-1] in SZ2|SZ4 else a2
        s=tsize(ty)
        if s is None: ok=False;break
        sg+='d' if s==4 else 'w'
    rs=tsize(ret) if ret.strip() not in('void','') else 0
    rc='v' if rs==0 else ('w' if rs==2 else 'd' if rs==4 else '?')
    if rs is None: rc='?'
    if not ok: sg='?'
    if name.upper() not in PROT: PROT[name.upper()]=dict(name=name,conv=conv[0],sig=sg,ret=rc)
json.dump(PROT,open('cinc.json','w'))
print(len(PROT)); 
for k in ('FILEREAD','MEMALLOC','_MALLOC','SPRINTF','STRCPY','COBJMESSAGE','FILEPOS','GRDRAWLINE','VMLOCK'):
    print(k,PROT.get(k))
