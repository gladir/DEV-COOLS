import re,sys
base=['prelude.js','prelude_core.js','prelude_async.js','prelude_lib.js','prelude_big.js','prelude_mod.js','prelude_case.js','prelude_str.js']
chunks=[('prelude_path.js','path'),('prelude_eval.js','eval|Function'),('prelude_web.js','Event|Abort|URL|fetch|DOMException'),('prelude_bin.js','Int8Array|Uint8Array|Uint8ClampedArray|Int16Array|Uint16Array|Int32Array|Uint32Array|Float32Array|Float64Array|BigInt64Array|BigUint64Array|ArrayBuffer|DataView|Buffer|TextEncoder|TextDecoder|Atomics')]
D='/tmp/claude-0/b/p/'
def lines(f): return open(D+f).read().rstrip('\n').split('\n')
src=[]
for f in base: src+=lines(f)
nbase=len(src)
ends=[]
for f,k in chunks:
    src+=lines(f); ends.append(len(src))
out=["{ PRELUDE-BEGIN : genere depuis le formateur JS (inspect, console, formats %) }","Const","  PRELUDE_LINES = %d;"%len(src),"  PRELUDE_BASE = %d;"%nbase,"  PRELUDE_CHUNKS = %d;"%len(chunks),
 "  PreludeChunkEnd: Array[1..%d] Of LongInt = (%s);"%(len(chunks),', '.join(map(str,ends))),
 "  PreludeChunkKeys: Array[1..%d] Of String[255] = (%s);"%(len(chunks),', '.join("'%s'"%k for f,k in chunks)),
 "  PreludeText: Array[1..PRELUDE_LINES] Of String[250] = ("]
for i,l in enumerate(src):
    assert len(l)<=250,(i,len(l))
    q="'"+l.replace("'","''")+"'"
    out.append("    "+q+(","if i<len(src)-1 else ""))
out.append("  );")
out.append("{ PRELUDE-END }")
blk="\n".join(out)+"\n"
p='/home/user/DEV-COOLS/JSCW32.PAS'
s=open(p,encoding='utf-8').read()
i=s.index("{ PRELUDE-BEGIN"); j=s.index("{ PRELUDE-END }")+len("{ PRELUDE-END }\n")
s=s[:i]+blk+s[j:]
open(p,'w',encoding='utf-8').write(s)
