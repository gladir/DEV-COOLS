import re,itertools,json
def syms(path):
    s=set()
    for l in open(path,encoding='latin-1'):
        m=re.match(r'^\s*(ifdef|ifndef|if|elif|ifdef)\s+(.*)',l.split('#')[0])
        if m: s.update(re.findall(r'[A-Za-z_][A-Za-z0-9_]*',m.group(2)))
    return s
def gp_exports(path,defs):
    n=0; out={}; stack=[]  # (active_parent, cond_true_taken, current_active)
    active=True; st=[]
    for l in open(path,encoding='latin-1'):
        l=l.split('#')[0].strip()
        if not l: continue
        m=re.match(r'^(ifdef|ifndef)\s+(\S+)',l)
        if m:
            c=(m.group(2) in defs); c=c if m.group(1)=='ifdef' else (not c)
            st.append((active,c)); active=active and c; continue
        m=re.match(r'^if\s+(.*)',l)
        if m:
            expr=m.group(1); c=eval_expr(expr,defs); st.append((active,c)); active=active and c; continue
        if l.startswith('else'):
            pa,c=st[-1]; active=pa and (not c); st[-1]=(pa,not c) ; 
            # remember : after else, 'c' now denotes the else branch truth
            continue
        if l.startswith('endif'):
            pa,c=st.pop(); active=pa; continue
        if not active: continue
        m=re.match(r'^(?:export|publish)\s+(\S+)(?:\s+as\s+(\S+))?',l)
        if m:
            out[n]=m.group(2) or m.group(1); n+=1; continue
        m=re.match(r'^skip\s+(\d+)',l)
        if m: n+=int(m.group(1))
    return out
def eval_expr(e,defs):
    e=re.sub(r'defined\(\s*(\w+)\s*\)',lambda m:str(m.group(1) in defs),e)
    e=e.replace('||',' or ').replace('&&',' and ').replace('!',' not ')
    e=re.sub(r'[A-Za-z_]\w*',lambda m:m.group(0) if m.group(0) in('True','False','and','or','not') else str(m.group(0) in defs),e)
    try: return bool(eval(e))
    except Exception: return False
if __name__=='__main__':
    R='/home/user/bluewaysw/pcgeos/Library/'
    S=sorted(syms(R+'Kernel/geos.gp')); print(len(S),S)
