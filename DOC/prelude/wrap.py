import sys,re
def split_line(line,limit=240):
    # coupe aux ", " ou " + " ou " || " hors chaine, en respectant l'indentation
    ind=re.match(r'\s*',line).group(0)
    out=[];cur=line
    while len(cur.encode('utf8'))>limit:
        q=None;best=-1;i=0;esc=False;depth=0
        while i<len(cur):
            c=cur[i]
            if q:
                if esc: esc=False
                elif c=='\\': esc=True
                elif c==q: q=None
            else:
                if c in '\'"`': q=c
                elif c=='/' and i+1<len(cur) and cur[i+1]=='/' : break
                elif i<limit and (cur.startswith(', ',i) or cur.startswith('; ',i) or cur.startswith(' + ',i) or cur.startswith(' || ',i) or cur.startswith(' && ',i) or cur.startswith(' ? ',i) or cur.startswith(' : ',i)):
                    best=i+ (2 if cur.startswith(', ',i) or cur.startswith('; ',i) else 1)
            i+=1
        if best<=len(ind)+10: break
        out.append(cur[:best].rstrip())
        cur=ind+'  '+cur[best:].lstrip()
    out.append(cur)
    return out
f=sys.argv[1]
res=[]
for l in open(f).read().split('\n'):
    if len(l.encode('utf8'))>250: res+=split_line(l)
    else: res.append(l)
open(f,'w').write('\n'.join(res))
