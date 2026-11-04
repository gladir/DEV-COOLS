import collections,re
from align import *
g=Geode(G+'GRAPH.GEO'); bf=[b for b in bin_funcs(g) if b[3]]
MACRO={'MakeWWFixed','IntegerOf','ObjDerefGen','ObjDerefVis'}
sf=[]
for f in ['EDGE.C','GRAPH.C','QUEUE.C','STACK.C','SUPPORT.C','VERTEX.C','APPUI.GOC','DOCUMENT.GOC','PRIMARY.GOC','PROCESS.GOC','VIEW.GOC']:
    for fn,nm,seq in src_funcs(f):
        s=[('MSG' if w.startswith('@') else w) for w in seq if w not in MACRO]
        if s: sf.append((fn,nm,s))
votes=collections.defaultdict(collections.Counter)
for fn,nm,s in sf:
    for ri,st,en,seq in bf:
        b=[(l,o) for l,o in seq]
        if len(b)==len(s):
            for a,c in zip(s,b): votes[a][c]+=1
for k,v in sorted(votes.items()):
    print(k, v.most_common(4))
