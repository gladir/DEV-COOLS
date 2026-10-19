import re,sys
base=['prelude.js','prelude_core.js','prelude_async.js','prelude_lib.js','prelude_big.js','prelude_case.js','prelude_str.js']
chunks=[('prelude_mod.js','require|module|exports|import|export|__esm|__umods|__filename|__dirname|eval|Function|globalThis'),('prelude_fmt.js','Event|Abort|URL|fetch|DOMException|Intl|toLocale|localeCompare|toFixed|toPrecision|toExponential|encodeURI|decodeURI|btoa|atob|eval|Function|globalThis|Reflect|Int8Array|Uint8|nt16Array|nt32Array|Float32A|Float64A|BigInt64|BigUint64|ArrayBuffer|DataView|Buffer|TextEncoder|TextDecoder|Atomics|fs\'|fs"|fs/|readline|child_process|stdin|process.cwd|process.env|chdir'),('prelude_path.js','path'),('prelude_eval.js','eval|Function|with (|with('),('prelude_web.js','Event|Abort|URL|fetch|DOMException'),('prelude_bin.js','Int8Array|Uint8|nt16Array|nt32Array|Float32A|Float64A|BigInt64|BigUint64|ArrayBuffer|DataView|Buffer|TextEncoder|TextDecoder|Atomics|fs\'|fs"|fs/|readline|child_process|stdin|process.cwd|process.env|chdir'),('prelude_proxy.js','Proxy'),('prelude_uni.js','\\p{|\\P{'),('prelude_norm.js','normalize'),('prelude_fs.js','fs\'|fs"|fs/|readline|child_process|stdin|process.cwd|process.env|chdir'),('prelude_intl.js','Intl|toLocale|localeCompare'),('prelude_il_cs.js','\'cs-|"cs-|\'cs\'|"cs"|`cs-'),('prelude_il_da.js','\'da-|"da-|\'da\'|"da"|`da-'),('prelude_il_de.js','\'de-|"de-|\'de\'|"de"|`de-'),('prelude_il_el.js','\'el-|"el-|\'el\'|"el"|`el-'),('prelude_il_en.js','en-GB|en-AU|en-CA|en-IN'),('prelude_il_es.js','\'es-|"es-|\'es\'|"es"|`es-'),('prelude_il_fi.js','\'fi-|"fi-|\'fi\'|"fi"|`fi-'),('prelude_il_fr.js','\'fr-|"fr-|\'fr\'|"fr"|`fr-'),('prelude_il_he.js','\'he-|"he-|\'he\'|"he"|`he-'),('prelude_il_hi.js','\'hi-|"hi-|\'hi\'|"hi"|`hi-'),('prelude_il_hu.js','\'hu-|"hu-|\'hu\'|"hu"|`hu-'),('prelude_il_id.js','\'id-|"id-|\'id\'|"id"|`id-'),('prelude_il_it.js','\'it-|"it-|\'it\'|"it"|`it-'),('prelude_il_ja.js','\'ja-|"ja-|\'ja\'|"ja"|`ja-'),('prelude_il_ko.js','\'ko-|"ko-|\'ko\'|"ko"|`ko-'),('prelude_il_nb.js','\'nb-|"nb-|\'nb\'|"nb"|`nb-'),('prelude_il_nl.js','\'nl-|"nl-|\'nl\'|"nl"|`nl-'),('prelude_il_pl.js','\'pl-|"pl-|\'pl\'|"pl"|`pl-'),('prelude_il_pt.js','\'pt-|"pt-|\'pt\'|"pt"|`pt-'),('prelude_il_ru.js','\'ru-|"ru-|\'ru\'|"ru"|`ru-'),('prelude_il_sv.js','\'sv-|"sv-|\'sv\'|"sv"|`sv-'),('prelude_il_tr.js','\'tr-|"tr-|\'tr\'|"tr"|`tr-'),('prelude_il_uk.js','\'uk-|"uk-|\'uk\'|"uk"|`uk-'),('prelude_il_zh.js','\'zh-|"zh-|\'zh\'|"zh"|`zh-')]
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
 "  PreludeChunkKeys: Array[1..%d] Of String[255] = (%s);"%(len(chunks),', '.join("'%s'"%k.replace("'","''") for f,k in chunks)),
 "  PreludeText: Array[1..PRELUDE_LINES] Of String[250] = ("]
for i,l in enumerate(src):
    assert len(l.encode('utf8'))<=250,(i,len(l))
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
