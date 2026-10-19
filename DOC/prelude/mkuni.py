import json,re
D='/tmp/claude-0/b/p/'
props=json.load(open(D+'uni_props.json'))
norm=json.load(open(D+'uni_norm.json'))
def lit(p): return json.dumps(p)
def pieces(text,n=200):
    out=[];i=0
    while i<len(text):
        out.append(text[i:i+n]); i+=n
    return out
def arr(var,text):
    ps=pieces(text) if text else ['']
    return "  %s = [\n%s\n  ].join('');\n"%(var,",\n".join('    '+lit(p) for p in ps))
# ---- proprietes
src=r'''var __upC;
function __upDec(s) {
  var t, r = [], i, prev = 0, a, b;
  if (s === '') return r;
  t = s.split(',');
  for (i = 0; i < t.length; i += 2) { a = prev + parseInt(t[i], 36); b = a + parseInt(t[i + 1], 36); r.push(a, b); prev = b; }
  return r;
}
function __upMerge(lists) {
  var all = [], i, j, r = [], cur = null, k;
  for (i = 0; i < lists.length; i++) for (j = 0; j < lists[i].length; j += 2) all.push([lists[i][j], lists[i][j + 1]]);
  all.sort(function (x, y) { return x[0] - y[0]; });
  for (k = 0; k < all.length; k++) {
    if (cur !== null && all[k][0] <= cur[1] + 1) { if (all[k][1] > cur[1]) cur[1] = all[k][1]; }
    else { cur = [all[k][0], all[k][1]]; r.push(cur); }
  }
  return r.reduce(function (acc, p) { acc.push(p[0], p[1]); return acc; }, []);
}
function __upComp(r) {
  var out = [], prev = 0, i;
  for (i = 0; i < r.length; i += 2) { if (r[i] > prev) out.push(prev, r[i] - 1); prev = r[i + 1] + 1; }
  if (prev <= 1114111) out.push(prev, 1114111);
  return out;
}
function __upTab() {
  var T = { gc: {}, sc: {}, scx: {}, bin: {} };
'''
for sect in ('gc','sc','scx','bin'):
    for k,v in props[sect].items():
        src+=arr("T.%s['%s']"%(sect,k),v)
src+='''  return T;
}
var __upGroups, __upAlias;
function __upInit() {
  __upC = __upTab();
  __upGroups = { L: ['Lu', 'Ll', 'Lt', 'Lm', 'Lo'], LC: ['Lu', 'Ll', 'Lt'], M: ['Mn', 'Mc', 'Me'], N: ['Nd', 'Nl', 'No'], P: ['Pc', 'Pd', 'Ps', 'Pe', 'Pi', 'Pf', 'Po'], S: ['Sm', 'Sc', 'Sk', 'So'], Z: ['Zs', 'Zl', 'Zp'], C: ['Cc', 'Cf', 'Cs', 'Co', 'Cn'] };
  __upAlias = {
    Letter: 'L', Cased_Letter: 'LC', Uppercase_Letter: 'Lu', Lowercase_Letter: 'Ll', Titlecase_Letter: 'Lt', Modifier_Letter: 'Lm', Other_Letter: 'Lo', Mark: 'M', Combining_Mark: 'M',
    Nonspacing_Mark: 'Mn', Spacing_Mark: 'Mc', Enclosing_Mark: 'Me', Number: 'N', Decimal_Number: 'Nd', digit: 'Nd', Letter_Number: 'Nl', Other_Number: 'No', Punctuation: 'P', punct: 'P',
    Connector_Punctuation: 'Pc', Dash_Punctuation: 'Pd', Open_Punctuation: 'Ps', Close_Punctuation: 'Pe', Initial_Punctuation: 'Pi', Final_Punctuation: 'Pf', Other_Punctuation: 'Po',
    Symbol: 'S', Math_Symbol: 'Sm', Currency_Symbol: 'Sc', Modifier_Symbol: 'Sk', Other_Symbol: 'So', Separator: 'Z', Space_Separator: 'Zs', Line_Separator: 'Zl', Paragraph_Separator: 'Zp',
    Other: 'C', Control: 'Cc', cntrl: 'Cc', Format: 'Cf', Surrogate: 'Cs', Private_Use: 'Co', Unassigned: 'Cn',
    Alpha: 'Alphabetic', AHex: 'ASCII_Hex_Digit', Bidi_C: 'Bidi_Control', Bidi_M: 'Bidi_Mirrored', CI: 'Case_Ignorable', CWCF: 'Changes_When_Casefolded', CWCM: 'Changes_When_Casemapped',
    CWL: 'Changes_When_Lowercased', CWKCF: 'Changes_When_NFKC_Casefolded', CWT: 'Changes_When_Titlecased', CWU: 'Changes_When_Uppercased', DI: 'Default_Ignorable_Code_Point', Dep: 'Deprecated',
    Dia: 'Diacritic', EBase: 'Emoji_Modifier_Base', EComp: 'Emoji_Component', EMod: 'Emoji_Modifier', EPres: 'Emoji_Presentation', ExtPict: 'Extended_Pictographic', Ext: 'Extender',
    Gr_Base: 'Grapheme_Base', Gr_Ext: 'Grapheme_Extend', Hex: 'Hex_Digit', IDC: 'ID_Continue', Ideo: 'Ideographic', IDS: 'ID_Start', IDSB: 'IDS_Binary_Operator', IDST: 'IDS_Trinary_Operator',
    Join_C: 'Join_Control', LOE: 'Logical_Order_Exception', Lower: 'Lowercase', NChar: 'Noncharacter_Code_Point', Pat_Syn: 'Pattern_Syntax', Pat_WS: 'Pattern_White_Space', QMark: 'Quotation_Mark',
    RI: 'Regional_Indicator', SD: 'Soft_Dotted', STerm: 'Sentence_Terminal', Term: 'Terminal_Punctuation', UIdeo: 'Unified_Ideograph', Upper: 'Uppercase', VS: 'Variation_Selector',
    space: 'White_Space', WSpace: 'White_Space', XIDC: 'XID_Continue', XIDS: 'XID_Start'
  };
  __upScr = { Latn: 'Latin', Grek: 'Greek', Cyrl: 'Cyrillic', Arab: 'Arabic', Hebr: 'Hebrew', Hani: 'Han', Hira: 'Hiragana', Kana: 'Katakana', Hang: 'Hangul', Thai: 'Thai', Deva: 'Devanagari',
    Zyyy: 'Common', Zinh: 'Inherited', Qaai: 'Inherited', Armn: 'Armenian', Geor: 'Georgian', Beng: 'Bengali', Taml: 'Tamil', Telu: 'Telugu', Knda: 'Kannada', Mlym: 'Malayalam', Gujr: 'Gujarati',
    Guru: 'Gurmukhi', Orya: 'Oriya', Sinh: 'Sinhala', Tibt: 'Tibetan', Mong: 'Mongolian', Khmr: 'Khmer', Laoo: 'Lao', Mymr: 'Myanmar', Ethi: 'Ethiopic', Cher: 'Cherokee', Bopo: 'Bopomofo',
    Copt: 'Coptic', Runr: 'Runic', Ogam: 'Ogham', Goth: 'Gothic', Syrc: 'Syriac', Thaa: 'Thaana', Brai: 'Braille', Yiii: 'Yi', Tfng: 'Tifinagh', Nkoo: 'Nko', Cans: 'Canadian_Aboriginal' };
}
var __upScr;
function __upRanges(name) {
  var eq = name.indexOf('='), k, v, parts, i, lists, r;
  if (__upC === undefined) __upInit();
  if (eq >= 0) { k = name.slice(0, eq); v = name.slice(eq + 1); }
  else { k = ''; v = name; }
  if (k === 'General_Category' || k === 'gc' || k === '') {
    v = __upAlias[v] !== undefined && __upAlias[v].length <= 2 ? __upAlias[v] : v;
    parts = __upGroups[v] !== undefined ? __upGroups[v] : (__upC.gc[v] !== undefined || v === 'Cs' ? [v] : null);
    if (parts !== null) {
      lists = [];
      for (i = 0; i < parts.length; i++) {
        if (parts[i] === 'Cs') lists.push([55296, 57343]);
        else if (parts[i] === 'Cn') lists.push(__upComp(__upMerge(Object.keys(__upC.gc).filter(function (q) { return q !== 'Cn'; }).map(function (q) { return __upDec(__upC.gc[q]); }).concat([[55296, 57343]]))));
        else lists.push(__upDec(__upC.gc[parts[i]]));
      }
      return __upMerge(lists);
    }
    if (k !== '') return null;
  }
  if (k === 'Script' || k === 'sc' || k === 'Script_Extensions' || k === 'scx') {
    v = __upScr[v] !== undefined ? __upScr[v] : v;
    if (__upC.sc[v] === undefined) return null;
    if ((k === 'Script_Extensions' || k === 'scx') && __upC.scx[v] !== undefined) return __upDec(__upC.scx[v]);
    return __upDec(__upC.sc[v]);
  }
  if (k === '') {
    v = __upAlias[v] !== undefined ? __upAlias[v] : v;
    if (v === 'Any') return [0, 1114111];
    if (v === 'ASCII') return [0, 127];
    if (v === 'Assigned') return __upComp(__upRanges('Cn'));
    if (__upC.bin[v] !== undefined) return __upDec(__upC.bin[v]);
  }
  return null;
}
function __init_uni() {
  __uprop = function (name) {
    var neg = name.charAt(0) === '!', r;
    if (neg) name = name.slice(1);
    r = __upRanges(name);
    if (r === null) return undefined;
    return neg ? __upComp(r) : r;
  };
}
'''
open(D+'prelude_uni.js','w').write(src)
# ---- normalisation
n='''var __nrmC;
function __nrmTab() {
  var T = {};
'''
for k in ('canon','compat','pairs','ccc'):
    n+=arr("T.%s"%k,norm[k])
n+=r'''  return T;
}
function __nrmDecode(s) {
  var t = s === '' ? [] : s.split(','), i = 0, m = {}, c, len, j, seq;
  while (i < t.length) {
    c = parseInt(t[i++], 36); len = parseInt(t[i++], 36); seq = [];
    for (j = 0; j < len; j++) seq.push(parseInt(t[i++], 36));
    m[c] = seq;
  }
  return m;
}
function __nrmInit() {
  var T = __nrmTab(), t, i, ccc = {}, a, b, v, prev = 0, comp = {}, k;
  t = T.ccc.split(',');
  for (i = 0; i < t.length; i += 3) {
    a = prev + parseInt(t[i], 36); b = a + parseInt(t[i + 1], 36); v = parseInt(t[i + 2], 36); prev = b;
    for (k = a; k <= b; k++) ccc[k] = v;
  }
  t = T.pairs.split(',');
  for (i = 0; i + 2 < t.length; i += 3) comp[parseInt(t[i], 36) + ',' + parseInt(t[i + 1], 36)] = parseInt(t[i + 2], 36);
  __nrmC = { canon: __nrmDecode(T.canon), compat: __nrmDecode(T.compat), ccc: ccc, comp: comp };
}
function __nrmApply(s, compat, compose) {
  var C, cps = [], i, c, n = s.length, out, d, j, k, last, starter, cc, lastCcc, key, res, ch, SBase = 44032, LBase = 4352, VBase = 4449, TBase = 4519, si;
  if (__nrmC === undefined) __nrmInit();
  C = __nrmC;
  for (i = 0; i < n; i++) {
    c = s.charCodeAt(i);
    if (c >= 55296 && c <= 56319 && i + 1 < n) { d = s.charCodeAt(i + 1); if (d >= 56320 && d <= 57343) { c = 65536 + ((c - 55296) << 10) + (d - 56320); i++; } }
    if (c >= 44032 && c <= 55203) {
      si = c - SBase;
      cps.push(LBase + Math.floor(si / 588), VBase + Math.floor((si % 588) / 28));
      if (si % 28 !== 0) cps.push(TBase + si % 28);
    } else {
      d = compat ? C.compat[c] : undefined;
      if (d === undefined) d = C.canon[c];
      if (d === undefined) cps.push(c);
      else for (j = 0; j < d.length; j++) cps.push(d[j]);
    }
  }
  // ordre canonique
  for (i = 1; i < cps.length; i++) {
    cc = C.ccc[cps[i]] || 0;
    if (cc === 0) continue;
    j = i;
    while (j > 0 && (C.ccc[cps[j - 1]] || 0) > cc) { c = cps[j]; cps[j] = cps[j - 1]; cps[j - 1] = c; j--; }
  }
  if (compose) {
    out = []; starter = -1; lastCcc = 0;
    for (i = 0; i < cps.length; i++) {
      c = cps[i]; cc = C.ccc[c] || 0;
      if (starter >= 0 && (out.length - 1 === starter || lastCcc < cc)) {
        last = out[starter];
        res = undefined;
        if (last >= LBase && last < LBase + 19 && c >= VBase && c < VBase + 21) res = SBase + ((last - LBase) * 21 + (c - VBase)) * 28;
        else if (last >= SBase && last < SBase + 11172 && (last - SBase) % 28 === 0 && c > TBase && c < TBase + 28) res = last + (c - TBase);
        else res = C.comp[last + ',' + c];
        if (res !== undefined) { out[starter] = res; continue; }
      }
      if (cc === 0) starter = out.length;
      lastCcc = cc;
      out.push(c);
    }
    cps = out;
  }
  res = [];
  for (i = 0; i < cps.length; i += 1024) res.push(String.fromCodePoint.apply(null, cps.slice(i, i + 1024)));
  return res.join('');
}
function __init_norm() {
  String.prototype.normalize = function (form) {
    var s = String(this), f = form === undefined ? 'NFC' : String(form);
    if (f !== 'NFC' && f !== 'NFD' && f !== 'NFKC' && f !== 'NFKD') throw new RangeError('The normalization form should be one of NFC, NFD, NFKC, NFKD.');
    if (/^[\x00-\x7f]*$/.test(s)) return s;
    return __nrmApply(s, f === 'NFKC' || f === 'NFKD', f === 'NFC' || f === 'NFKC');
  };
}
'''
open(D+'prelude_norm.js','w').write(n)
