import re,sys
import glob
files=['prelude.js','prelude_core.js','prelude_async.js','prelude_lib.js','prelude_big.js','prelude_mod.js','prelude_eval.js']
src=''.join(open('./'+f).read().rstrip('\n')+'\n' for f in files).rstrip('\n').split('\n')
lines=["{ PRELUDE-BEGIN : genere depuis le formateur JS (inspect, console, formats %) }","Const","  PRELUDE_LINES = %d;"%len(src),"  PreludeText: Array[1..PRELUDE_LINES] Of String[250] = ("]
for i,l in enumerate(src):
    q="'"+l.replace("'","''")+"'"
    lines.append("    "+q+(","if i<len(src)-1 else ""))
lines.append("  );")
lines.append("{ PRELUDE-END }")
blk="\n".join(lines)+"\n"
s=open('../../JSCW32.PAS').read()
if "{ PRELUDE-BEGIN" in s:
    i=s.index("{ PRELUDE-BEGIN"); j=s.index("{ PRELUDE-END }")+len("{ PRELUDE-END }\n")
    s=s[:i]+blk+s[j:]
else:
    k=s.index("Function LoadSource(Var ctx: TCompilerContext): Boolean;")
    s=s[:k]+blk+"\n"+s[k:]
open('../../JSCW32.PAS','w').write(s)
