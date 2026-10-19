function __init_eval() {
  __newfn = __evnewfn;
  __evg = {};
  __evSHORT = { short: 1 };
  __evTDZ = { tdz: 1 };
  __evKW = { 'break': 1, 'case': 1, 'catch': 1, 'class': 1, 'const': 1, 'continue': 1, 'debugger': 1, 'default': 1, 'delete': 1, 'do': 1, 'else': 1, 'export': 1,
  'extends': 1, 'finally': 1, 'for': 1, 'function': 1, 'if': 1, 'import': 1, 'in': 1, 'instanceof': 1, 'new': 1, 'return': 1, 'super': 1, 'switch': 1, 'this': 1,
  'throw': 1, 'try': 1, 'typeof': 1, 'var': 1, 'void': 1, 'while': 1, 'with': 1, 'null': 1, 'true': 1, 'false': 1 };
  __evREKW = { 'return': 1, 'typeof': 1, 'instanceof': 1, 'in': 1, 'of': 1, 'new': 1, 'delete': 1, 'void': 1, 'throw': 1, 'case': 1, 'do': 1, 'else': 1 };
  __evBinPrec = { '??': 1, '||': 2, '&&': 3, '|': 4, '^': 5, '&': 6, '==': 7, '!=': 7, '===': 7, '!==': 7, '<': 8, '>': 8, '<=': 8, '>=': 8,
  'instanceof': 8, 'in': 8, '<<': 9, '>>': 9, '>>>': 9, '+': 10, '-': 10, '*': 11, '/': 11, '%': 11, '**': 12 };
  __evAsgOps = { '=': 1, '+=': 1, '-=': 1, '*=': 1, '/=': 1, '%=': 1, '**=': 1, '<<=': 1, '>>=': 1, '>>>=': 1, '&=': 1, '|=': 1, '^=': 1, '&&=': 1, '||=': 1, '??=': 1 };
  __evNone = { none: 1 };
}
var __evg, __evSHORT, __evTDZ, __evcv, __evKW, __evREKW, __evBinPrec, __evAsgOps, __evNone;
function __evSyn(msg) { return new SyntaxError(msg); }
function __evIsIdStart(c) {
  return (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c === 95 || c === 36 || c > 127;
}
function __evIsIdPart(c) { return __evIsIdStart(c) || (c >= 48 && c <= 57); }
function __evHex(s, i, n) {
  var v = 0, k, c;
  for (k = 0; k < n; k++) {
    c = s.charCodeAt(i + k);
    if (c >= 48 && c <= 57) v = v * 16 + (c - 48);
    else if (c >= 97 && c <= 102) v = v * 16 + (c - 87);
    else if (c >= 65 && c <= 70) v = v * 16 + (c - 55);
    else return -1;
  }
  return v;
}
function __evFromCp(cp) {
  if (cp < 65536) return String.fromCharCode(cp);
  cp -= 65536;
  return String.fromCharCode(55296 + (cp >> 10), 56320 + (cp & 1023));
}
// lit un echappement apres le antislash a la position i ; rend [texte, nouvelle position]
function __evEsc(s, i) {
  var c = s.charAt(i), v, j;
  switch (c) {
    case 'n': return ['\n', i + 1];
    case 't': return ['\t', i + 1];
    case 'r': return ['\r', i + 1];
    case 'b': return ['\b', i + 1];
    case 'f': return ['\f', i + 1];
    case 'v': return ['\v', i + 1];
    case '0': if (!(s.charCodeAt(i + 1) >= 48 && s.charCodeAt(i + 1) <= 57)) return ['\0', i + 1]; return ['\0', i + 1];
    case 'x':
      v = __evHex(s, i + 1, 2);
      if (v < 0) throw __evSyn('Invalid hexadecimal escape sequence');
      return [String.fromCharCode(v), i + 3];
    case 'u':
      if (s.charAt(i + 1) === '{') {
        j = s.indexOf('}', i);
        if (j < 0) throw __evSyn('Invalid Unicode escape sequence');
        v = parseInt(s.slice(i + 2, j), 16);
        if (isNaN(v) || v > 1114111) throw __evSyn('Undefined Unicode code-point');
        return [__evFromCp(v), j + 1];
      }
      v = __evHex(s, i + 1, 4);
      if (v < 0) throw __evSyn('Invalid Unicode escape sequence');
      return [String.fromCharCode(v), i + 5];
    case '\r':
      if (s.charAt(i + 1) === '\n') return ['', i + 2];
      return ['', i + 1];
    case '\n': return ['', i + 1];
    default: return [c, i + 1];
  }
}
function __evSkipStr(src, j) {
  var q = src.charCodeAt(j);
  j++;
  while (j < src.length && src.charCodeAt(j) !== q) { if (src.charCodeAt(j) === 92) j++; j++; }
  return j + 1;
}
function __evSkipTpl(src, j) {
  var c;
  while (j < src.length) {
    c = src.charCodeAt(j);
    if (c === 96) return j + 1;
    if (c === 92) { j += 2; continue; }
    if (c === 36 && src.charCodeAt(j + 1) === 123) { j = __evSkipExpr(src, j + 2); continue; }
    j++;
  }
  throw __evSyn('Unterminated template literal');
}
function __evSkipExpr(src, j) {
  var depth = 1, c;
  while (j < src.length) {
    c = src.charCodeAt(j);
    if (c === 123) depth++;
    else if (c === 125) { depth--; if (depth === 0) return j + 1; }
    else if (c === 34 || c === 39) { j = __evSkipStr(src, j); continue; }
    else if (c === 96) { j = __evSkipTpl(src, j + 1); continue; }
    j++;
  }
  throw __evSyn('Unterminated template literal');
}
function __evTok(src) {
  var t = [], i = 0, n = src.length, c, j, q, s, nl = false, prev = null, m, e, k, st, tq;
  function push(kind, v, extra) {
    var o = { k: kind, v: v, nl: nl, p: i };
    if (extra) { o.f = extra.f; o.x = extra.x; o.r = extra.r; }
    t.push(o);
    prev = o;
    nl = false;
    return o;
  }
  function regexOk() {
    if (prev === null) return true;
    if (prev.k === 'n' || prev.k === 's' || prev.k === 'T' || prev.k === 'r' || prev.k === 'b') return false;
    if (prev.k === 'i') return __evREKW[prev.v] === 1;
    return !(prev.v === ')' || prev.v === ']' || prev.v === '}');
  }
  var puncts = ['>>>=', '...', '===', '!==', '**=', '<<=', '>>=', '>>>', '&&=', '||=', '??=', '=>', '==', '!=', '<=', '>=', '&&', '||', '??', '?.', '++', '--', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<', '>>', '**'];
  while (i < n) {
    c = src.charCodeAt(i);
    if (c === 10 || c === 13 || c === 8232 || c === 8233) { nl = true; i++; continue; }
    if (c === 32 || c === 9 || c === 11 || c === 12 || c === 160 || c === 65279) { i++; continue; }
    if (c === 47 && src.charCodeAt(i + 1) === 47) {
      while (i < n && src.charCodeAt(i) !== 10 && src.charCodeAt(i) !== 13) i++;
      continue;
    }
    if (c === 47 && src.charCodeAt(i + 1) === 42) {
      j = src.indexOf('*/', i + 2);
      if (j < 0) throw __evSyn('Invalid or unexpected token');
      if (/[\n\r]/.test(src.slice(i, j))) nl = true;
      i = j + 2;
      continue;
    }
    if ((c >= 48 && c <= 57) || (c === 46 && src.charCodeAt(i + 1) >= 48 && src.charCodeAt(i + 1) <= 57)) {
      m = /^(0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|(\d[\d_]*\.?[\d_]*|\.\d[\d_]*)([eE][+-]?\d+)?)/.exec(src.slice(i, i + 80));
      s = m[0].replace(/_/g, '');
      if (src.charAt(i + m[0].length) === 'n') {
        i += m[0].length + 1;
        push('b', s);
        continue;
      }
      i += m[0].length;
      if (__evIsIdStart(src.charCodeAt(i))) throw __evSyn('Invalid or unexpected token');
      push('n', Number(s));
      continue;
    }
    if (c === 34 || c === 39) {
      q = c; s = ''; i++;
      while (i < n && src.charCodeAt(i) !== q) {
        c = src.charCodeAt(i);
        if (c === 10 || c === 13) throw __evSyn('Invalid or unexpected token');
        if (c === 92) { e = __evEsc(src, i + 1); s += e[0]; i = e[1]; }
        else { s += src.charAt(i); i++; }
      }
      if (i >= n) throw __evSyn('Invalid or unexpected token');
      i++;
      push('s', s);
      continue;
    }
    if (c === 96) {
      st = []; tq = []; e = []; s = ''; k = ''; i++;
      for (;;) {
        if (i >= n) throw __evSyn('Unterminated template literal');
        c = src.charCodeAt(i);
        if (c === 96) { i++; break; }
        if (c === 92) {
          j = __evEsc(src, i + 1);
          k += src.slice(i, j[1]);
          s += j[0];
          i = j[1];
        } else if (c === 36 && src.charCodeAt(i + 1) === 123) {
          st.push(s); tq.push(k.replace(/\r\n?/g, '\n')); s = ''; k = '';
          j = __evSkipExpr(src, i + 2);
          e.push(src.slice(i + 2, j - 1));
          i = j;
        } else {
          if (c === 13) { if (src.charCodeAt(i + 1) === 10) i++; s += '\n'; k += '\n'; }
          else { s += src.charAt(i); k += src.charAt(i); }
          i++;
        }
      }
      st.push(s); tq.push(k.replace(/\r\n?/g, '\n'));
      push('T', st, { r: tq, x: e });
      continue;
    }
    if (__evIsIdStart(c) || (c === 35 && __evIsIdStart(src.charCodeAt(i + 1))) || c === 92) {
      j = i + 1;
      while (j < n && __evIsIdPart(src.charCodeAt(j))) j++;
      push('i', src.slice(i, j));
      i = j;
      continue;
    }
    if (c === 47 && regexOk()) {
      j = i + 1; k = false;
      while (j < n) {
        c = src.charCodeAt(j);
        if (c === 10 || c === 13) throw __evSyn('Invalid regular expression: missing /');
        if (c === 92) j++;
        else if (c === 91) k = true;
        else if (c === 93) k = false;
        else if (c === 47 && !k) break;
        j++;
      }
      if (j >= n) throw __evSyn('Invalid regular expression: missing /');
      s = src.slice(i + 1, j);
      j++;
      q = j;
      while (j < n && __evIsIdPart(src.charCodeAt(j))) j++;
      push('r', s, { f: src.slice(q, j) });
      i = j;
      continue;
    }
    s = null;
    for (k = 0; k < puncts.length; k++) {
      if (src.substr(i, puncts[k].length) === puncts[k]) { s = puncts[k]; break; }
    }
    if (s === '?.' && src.charCodeAt(i + 2) >= 48 && src.charCodeAt(i + 2) <= 57) s = null;
    if (s === null) {
      s = src.charAt(i);
      if ('{}()[];,<>+-*/%&|^!~?:=.@'.indexOf(s) < 0) throw __evSyn('Invalid or unexpected token');
    }
    push('p', s);
    i += s.length;
  }
  nl = true;
  push('e', '');
  return t;
}
function __evPatNames(pat, out) {
  var i, pr;
  if (pat === null) return out;
  switch (pat.t) {
    case 'Id': out.push(pat.n); break;
    case 'DefPat': __evPatNames(pat.a, out); break;
    case 'ArrPat':
      for (i = 0; i < pat.el.length; i++) __evPatNames(pat.el[i], out);
      if (pat.rest) __evPatNames(pat.rest, out);
      break;
    case 'ObjPat':
      for (i = 0; i < pat.props.length; i++) { pr = pat.props[i]; __evPatNames(pr.v, out); }
      if (pat.rest) __evPatNames(pat.rest, out);
      break;
  }
  return out;
}
function __evLex(stmts) {
  var lex = [], funs = [], i, s, j, nm;
  for (i = 0; i < stmts.length; i++) {
    s = stmts[i];
    if (s.t === 'Var' && s.kind !== 'var') {
      for (j = 0; j < s.decls.length; j++) {
        nm = __evPatNames(s.decls[j].a, []);
        for (var q = 0; q < nm.length; q++) lex.push({ n: nm[q], c: s.kind === 'const' });
      }
    } else if (s.t === 'ClassDecl') {
      lex.push({ n: s.cls.name, c: false });
    } else if (s.t === 'FnDecl') {
      funs.push(s);
    }
  }
  return { lex: lex, funs: funs };
}
function __evToTarget(n) {
  var i, pr, el, r;
  switch (n.t) {
    case 'Id': case 'Mem': return n;
    case 'Arr':
      el = []; r = null;
      for (i = 0; i < n.el.length; i++) {
        if (n.el[i] === null) el.push(null);
        else if (n.el[i].t === 'Spread') r = __evToTarget(n.el[i].a);
        else el.push(__evToElem(n.el[i]));
      }
      return { t: 'ArrPat', el: el, rest: r };
    case 'Obj':
      el = []; r = null;
      for (i = 0; i < n.props.length; i++) {
        pr = n.props[i];
        if (pr.kind === 'spread') r = __evToTarget(pr.v);
        else if (pr.kind !== 'init' || pr.method) throw __evSyn('Invalid destructuring assignment target');
        else el.push({ k: pr.k, c: pr.c, v: __evToElem(pr.v) });
      }
      return { t: 'ObjPat', props: el, rest: r };
  }
  throw __evSyn('Invalid left-hand side in assignment');
}
function __evToElem(n) {
  if (n.t === 'Asg' && n.op === '=') return { t: 'DefPat', a: __evToTarget(n.a), d: n.v };
  return __evToTarget(n);
}
function __evParse(src) {
  var T = __evTok(src), p = 0, fctx = { vars: [] }, noIn = false;
  function isP(v) { var t = T[p]; return t.k === 'p' && t.v === v; }
  function isK(v) { var t = T[p]; return t.k === 'i' && t.v === v; }
  function fail(t) {
    t = t || T[p];
    if (t.k === 'e') throw __evSyn('Unexpected end of input');
    if (t.k === 'i') throw __evSyn(__evKW[t.v] === 1 ? "Unexpected token '" + t.v + "'" : "Unexpected identifier '" + t.v + "'");
    if (t.k === 's') throw __evSyn('Unexpected string');
    if (t.k === 'n') throw __evSyn('Unexpected number');
    if (t.k === 'T') throw __evSyn('Unexpected template string');
    throw __evSyn("Unexpected token '" + t.v + "'");
  }
  function unsup(what) { throw __evSyn('eval: ' + what + ' are not supported by JSCW32'); }
  function eatP(v) { if (isP(v)) { p++; return true; } return false; }
  function expectP(v) { if (!isP(v)) fail(); p++; }
  function semi() {
    if (isP(';')) { p++; return; }
    if (isP('}') || T[p].k === 'e' || T[p].nl) return;
    fail();
  }
  function ident() {
    var t = T[p];
    if (t.k !== 'i' || __evKW[t.v] === 1) fail();
    p++;
    return t.v;
  }
  function propName() {
    var t = T[p];
    if (t.k === 'i' || t.k === 's') { p++; return t.v; }
    if (t.k === 'n' || t.k === 'b') { p++; return String(t.v); }
    fail();
  }
  function bindingTarget() {
    var el, rest, props, pr, key, c;
    if (isP('[')) {
      p++; el = []; rest = null;
      while (!isP(']')) {
        if (isP(',')) { p++; el.push(null); continue; }
        if (isP('...')) { p++; rest = bindingTarget(); break; }
        el.push(bindingElem());
        if (!isP(']')) expectP(',');
      }
      expectP(']');
      return { t: 'ArrPat', el: el, rest: rest };
    }
    if (isP('{')) {
      p++; props = []; rest = null;
      while (!isP('}')) {
        if (isP('...')) { p++; rest = bindingTarget(); break; }
        c = false;
        if (isP('[')) { p++; key = assign(); expectP(']'); c = true; }
        else key = propName();
        if (isP(':')) { p++; props.push({ k: key, c: c, v: bindingElem() }); }
        else {
          pr = { t: 'Id', n: key };
          if (isP('=')) { p++; pr = { t: 'DefPat', a: pr, d: assign() }; }
          props.push({ k: key, c: false, v: pr });
        }
        if (!isP('}')) expectP(',');
      }
      expectP('}');
      return { t: 'ObjPat', props: props, rest: rest };
    }
    return { t: 'Id', n: ident() };
  }
  function bindingElem() {
    var tg = bindingTarget();
    if (isP('=')) { p++; return { t: 'DefPat', a: tg, d: assign() }; }
    return tg;
  }
  function params() {
    var list = [], rest = null;
    expectP('(');
    while (!isP(')')) {
      if (isP('...')) { p++; rest = bindingTarget(); break; }
      list.push(bindingElem());
      if (!isP(')')) expectP(',');
    }
    expectP(')');
    return { list: list, rest: rest };
  }
  function fnBody(name, ps, arrow, kind, gen, asy) {
    var saved = fctx, savedIn = noIn, body, lx;
    fctx = { vars: [], fn: true, gen: !!gen, asy: !!asy };
    noIn = false;
    expectP('{');
    body = [];
    while (!isP('}')) {
      if (T[p].k === 'e') fail();
      body.push(stmt());
    }
    p++;
    lx = __evLex(body);
    var node = { t: 'Fn', name: name, params: ps.list, rest: ps.rest, body: body, vars: fctx.vars, lex: lx.lex, funs: lx.funs, arrow: arrow, kind: kind, gen: !!gen, asy: !!asy };
    fctx = saved;
    noIn = savedIn;
    return node;
  }
  function fnExpr(isDecl, asy) {
    var name = null, gen = false;
    p++;
    if (isP('*')) { p++; gen = true; }
    if (T[p].k === 'i' && !isP('(')) name = ident();
    else if (isDecl) fail();
    return fnBody(name, params(), false, 'fn', gen, asy);
  }
  function arrowAhead() {
    var d = 0, q = p, t;
    for (;;) {
      t = T[q];
      if (t.k === 'e') return false;
      if (t.k === 'p') {
        if (t.v === '(') d++;
        else if (t.v === ')') { d--; if (d === 0) break; }
      }
      q++;
    }
    return T[q + 1].k === 'p' && T[q + 1].v === '=>' && !T[q + 1].nl;
  }
  function arrowRest(ps, asy) {
    var saved = fctx, savedIn = noIn, node, body, lx;
    expectP('=>');
    if (isP('{')) return fnBody(null, ps, true, 'arrow', false, asy);
    fctx = { vars: [], fn: true, gen: false, asy: !!asy };
    noIn = savedIn;
    body = assign();
    node = { t: 'Fn', name: null, params: ps.list, rest: ps.rest, body: body, vars: [], lex: [], funs: [], arrow: true, kind: 'arrow', exprBody: true, gen: false, asy: !!asy };
    fctx = saved;
    return node;
  }
  function memberKey() {
    // cle d'une propriete de classe ou d'objet : [nom, calculee]
    var k;
    if (isP('[')) { p++; k = assign(); expectP(']'); return [k, true]; }
    if (T[p].k === 'i' && T[p].v.charAt(0) === '#') { k = T[p].v; p++; return [k, false]; }
    return [propName(), false];
  }
  function classBody(isDecl) {
    var name = null, sup = null, members = [], st, kind, key, kc, fn, v, nxt, masy, mgen;
    p++;
    if (T[p].k === 'i' && T[p].v !== 'extends' && !isP('{')) name = ident();
    else if (isDecl) fail();
    if (isK('extends')) { p++; sup = lhs(); }
    expectP('{');
    while (!isP('}')) {
      if (eatP(';')) continue;
      st = false; kind = 'method';
      if (isK('static') && !(T[p + 1].k === 'p' && (T[p + 1].v === '(' || T[p + 1].v === '=' || T[p + 1].v === ';' || T[p + 1].v === '}'))) {
        p++; st = true;
        if (isP('{')) {
          fn = fnBody(null, { list: [], rest: null }, false, 'method');
          members.push({ kind: 'block', st: true, v: fn });
          continue;
        }
      }
      masy = false; mgen = false;
      if (isK('async') && !(T[p + 1].k === 'p' && (T[p + 1].v === '(' || T[p + 1].v === '=' || T[p + 1].v === ';' || T[p + 1].v === '}')) && !T[p + 1].nl) { p++; masy = true; }
      if (isP('*')) { p++; mgen = true; }
      nxt = T[p + 1];
      if ((isK('get') || isK('set')) && !(nxt.k === 'p' && (nxt.v === '(' || nxt.v === '=' || nxt.v === ';' || nxt.v === '}'))) { kind = T[p].v; p++; }
      key = memberKey(); kc = key[1]; key = key[0];
      if (isP('(')) {
        fn = fnBody(null, params(), false, 'method', mgen, masy);
        members.push({ kind: kind, st: st, k: key, c: kc, v: fn, ctor: !st && !kc && key === 'constructor' && kind === 'method' });
      } else {
        v = null;
        if (eatP('=')) v = assign();
        semi();
        members.push({ kind: 'field', st: st, k: key, c: kc, v: v });
      }
    }
    p++;
    return { name: name, sup: sup, members: members };
  }
  function args() {
    var a = [];
    expectP('(');
    while (!isP(')')) {
      if (isP('...')) { p++; a.push({ t: 'Spread', a: assign() }); }
      else a.push(assign());
      if (!isP(')')) expectP(',');
    }
    expectP(')');
    return a;
  }
  function objLit() {
    var props = [], k, kc, nm, fn, nxt, v, pr, masy, mgen;
    p++;
    while (!isP('}')) {
      if (isP('...')) { p++; props.push({ kind: 'spread', v: assign() }); }
      else {
        masy = false; mgen = false;
        if (isK('async')) {
          nxt = T[p + 1];
          if (!(nxt.k === 'p' && (nxt.v === ',' || nxt.v === ':' || nxt.v === '(' || nxt.v === '}' || nxt.v === '='))) { p++; masy = true; }
        }
        if (isP('*')) { p++; mgen = true; }
        nm = null; nxt = T[p + 1];
        if ((isK('get') || isK('set')) && !(nxt.k === 'p' && (nxt.v === ',' || nxt.v === ':' || nxt.v === '(' || nxt.v === '}' || nxt.v === '='))) { nm = T[p].v; p++; }
        k = memberKey(); kc = k[1]; k = k[0];
        if (nm !== null) {
          fn = fnBody(null, params(), false, 'method');
          props.push({ kind: nm, k: k, c: kc, v: fn });
        } else if (isP('(')) {
          fn = fnBody(null, params(), false, 'method', mgen, masy);
          props.push({ kind: 'init', method: true, k: k, c: kc, v: fn });
        } else if (isP(':')) {
          p++;
          props.push({ kind: 'init', k: k, c: kc, v: assign() });
        } else {
          if (kc || typeof k !== 'string') fail();
          v = { t: 'Id', n: k };
          if (isP('=')) { p++; v = { t: 'Asg', op: '=', a: v, v: assign(), cover: true }; }
          props.push({ kind: 'init', k: k, c: false, v: v, short: true });
        }
      }
      if (!isP('}')) expectP(',');
    }
    p++;
    return { t: 'Obj', props: props };
  }
  function tplNode(t) {
    var es = [], i;
    for (i = 0; i < t.x.length; i++) es.push(__evParseExprSrc(t.x[i]));
    return { q: t.v, r: t.r, e: es };
  }
  function primary() {
    var t = T[p], e, el;
    switch (t.k) {
      case 'n': p++; return { t: 'Num', v: t.v };
      case 's': p++; return { t: 'Str', v: t.v };
      case 'b': p++; return { t: 'Big', v: t.v };
      case 'r': p++; return { t: 'Reg', v: t.v, f: t.f };
      case 'T': p++; e = tplNode(t); return { t: 'Tpl', q: e.q, e: e.e };
      case 'i':
        switch (t.v) {
          case 'this': p++; return { t: 'This' };
          case 'null': p++; return { t: 'Null' };
          case 'true': p++; return { t: 'Bool', v: true };
          case 'false': p++; return { t: 'Bool', v: false };
          case 'function': return fnExpr(false);
          case 'class': return { t: 'Cls', cls: classBody(false) };
          case 'super':
            p++;
            if (!isP('.') && !isP('[') && !isP('(')) fail();
            return { t: 'Super' };
          case 'async':
            if (T[p + 1].k === 'i' && T[p + 1].v === 'function' && !T[p + 1].nl) { p++; return fnExpr(false, true); }
            if (T[p + 1].k === 'p' && T[p + 1].v === '(' && !T[p + 1].nl && arrowAhead2()) { p++; return arrowRest(params(), true); }
            break;
          case 'import':
            if (!(T[p + 1].k === 'p' && T[p + 1].v === '(')) unsup('import declarations');
            p += 2;
            e = assign();
            if (isP(',')) { p++; if (!isP(')')) assign(); if (isP(',')) p++; }
            expectP(')');
            return { t: 'ImportCall', a: e };
        }
        if (__evKW[t.v] === 1) fail();
        p++;
        return { t: 'Id', n: t.v };
      case 'p':
        if (t.v === '(') {
          p++;
          var sv = noIn; noIn = false;
          e = expr();
          noIn = sv;
          expectP(')');
          return { t: 'Paren', e: e };
        }
        if (t.v === '[') {
          p++; el = [];
          while (!isP(']')) {
            if (isP(',')) { p++; el.push(null); continue; }
            if (isP('...')) { p++; el.push({ t: 'Spread', a: assign() }); }
            else el.push(assign());
            if (!isP(']')) expectP(',');
          }
          p++;
          return { t: 'Arr', el: el };
        }
        if (t.v === '{') return objLit();
    }
    fail();
  }
  function arrowAhead2() {
    var save = p;
    p++;
    var r = arrowAhead();
    p = save;
    return r;
  }
  function newExpr() {
    var f, a = [], t;
    p++;
    if (isP('.')) {
      p++;
      if (!isK('target')) fail();
      p++;
      return { t: 'NewTarget' };
    }
    if (isK('new')) f = newExpr();
    else f = primary();
    for (;;) {
      if (isP('.')) { p++; f = { t: 'Mem', o: f, n: memberName(), c: false }; }
      else if (isP('[')) { p++; t = expr(); expectP(']'); f = { t: 'Mem', o: f, i: t, c: true }; }
      else break;
    }
    if (isP('(')) a = args();
    return { t: 'New', f: f, a: a };
  }
  function memberName() {
    var t = T[p];
    if (t.k !== 'i') fail();
    p++;
    return t.v;
  }
  function lhs() {
    var e;
    if (isK('new')) e = newExpr();
    else e = primary();
    return tail(e);
  }
  function tail(e) {
    var chain = false, t, ix, tp;
    for (;;) {
      t = T[p];
      if (t.k === 'p') {
        if (t.v === '.') { p++; e = { t: 'Mem', o: e, n: memberName(), c: false }; continue; }
        if (t.v === '?.') {
          p++; chain = true;
          if (isP('(')) e = { t: 'Call', f: e, a: args(), opt: true };
          else if (isP('[')) { p++; ix = expr(); expectP(']'); e = { t: 'Mem', o: e, i: ix, c: true, opt: true }; }
          else e = { t: 'Mem', o: e, n: memberName(), c: false, opt: true };
          continue;
        }
        if (t.v === '[') { p++; ix = expr(); expectP(']'); e = { t: 'Mem', o: e, i: ix, c: true }; continue; }
        if (t.v === '(') { e = { t: 'Call', f: e, a: args() }; continue; }
      } else if (t.k === 'T') {
        p++; tp = tplNode(t);
        e = { t: 'TTpl', tag: e, q: tp.q, r: tp.r, e: tp.e };
        continue;
      }
      break;
    }
    return chain ? { t: 'Chain', e: e } : e;
  }
  function unary() {
    var t = T[p], a, e;
    if (t.k === 'p') {
      if (t.v === '!' || t.v === '-' || t.v === '+' || t.v === '~') { p++; return { t: 'Un', op: t.v, a: unary() }; }
      if (t.v === '++' || t.v === '--') { p++; a = unary(); __evToTarget(a); return { t: 'Upd', op: t.v, pre: true, a: a }; }
    } else if (t.k === 'i') {
      if (t.v === 'typeof' || t.v === 'void' || t.v === 'delete') { p++; return { t: 'Un', op: t.v, a: unary() }; }
      if (t.v === 'await' && fctx.asy) { p++; return { t: 'Await', a: unary() }; }
    }
    e = lhs();
    t = T[p];
    if (t.k === 'p' && (t.v === '++' || t.v === '--') && !t.nl) {
      __evToTarget(e);
      p++;
      return { t: 'Upd', op: t.v, pre: false, a: e };
    }
    return e;
  }
  function binary(minp) {
    var l = unary(), t, pr, r;
    for (;;) {
      t = T[p];
      if (!((t.k === 'p') || (t.k === 'i' && (t.v === 'in' || t.v === 'instanceof')))) break;
      pr = __evBinPrec[t.v];
      if (pr === undefined || pr < minp) break;
      if (t.v === 'in' && noIn) break;
      p++;
      r = t.v === '**' ? binary(pr) : binary(pr + 1);
      l = { t: (t.v === '&&' || t.v === '||' || t.v === '??') ? 'Log' : 'Bin', op: t.v, l: l, r: r };
    }
    return l;
  }
  function cond() {
    var c = binary(1), a, b;
    if (isP('?')) {
      p++;
      var sv = noIn; noIn = false;
      a = assign();
      noIn = sv;
      expectP(':');
      b = assign();
      return { t: 'Cnd', c: c, a: a, b: b };
    }
    return c;
  }
  function assign() {
    var t = T[p], left, o, ps, n2;
    if (t.k === 'i' && __evKW[t.v] !== 1 && T[p + 1].k === 'p' && T[p + 1].v === '=>' && !T[p + 1].nl) {
      p++;
      return arrowRest({ list: [{ t: 'Id', n: t.v }], rest: null }, false);
    }
    if (t.k === 'i' && t.v === 'async' && !T[p + 1].nl && T[p + 1].k === 'i' && __evKW[T[p + 1].v] !== 1 && T[p + 2].k === 'p' && T[p + 2].v === '=>' && !T[p + 2].nl) {
      p++;
      n2 = T[p].v;
      p++;
      return arrowRest({ list: [{ t: 'Id', n: n2 }], rest: null }, true);
    }
    if (t.k === 'i' && t.v === 'yield' && fctx.gen) {
      p++;
      n2 = false; left = null;
      if (isP('*') && !T[p].nl) { p++; n2 = true; left = assign(); }
      else if (!T[p].nl && T[p].k !== 'e' && !(T[p].k === 'p' && (T[p].v === ')' || T[p].v === ']' || T[p].v === '}' || T[p].v === ',' || T[p].v === ';' || T[p].v === ':'))) left = assign();
      return { t: 'Yield', a: left, dlg: n2, ag: fctx.asy };
    }
    if (t.k === 'p' && t.v === '(' && arrowAhead()) return arrowRest(params(), false);
    left = cond();
    o = T[p];
    if (o.k === 'p' && __evAsgOps[o.v] === 1) {
      p++;
      if (o.v === '=') {
        if (left.t === 'Paren') left = left.e;
        left = (left.t === 'Arr' || left.t === 'Obj') ? __evToTarget(left) : __evToTarget(left);
      } else {
        if (left.t === 'Paren') left = left.e;
        if (left.t !== 'Id' && left.t !== 'Mem') throw __evSyn('Invalid left-hand side in assignment');
      }
      return { t: 'Asg', op: o.v, a: left, v: assign() };
    }
    return left;
  }
  function expr() {
    var e = assign(), l;
    if (isP(',')) {
      l = [e];
      while (eatP(',')) l.push(assign());
      return { t: 'Seq', l: l };
    }
    return e;
  }
  function varDecl() {
    var kind = T[p].v, decls = [], tg, init, nm, i;
    p++;
    for (;;) {
      tg = bindingTarget();
      init = null;
      if (isP('=')) { p++; init = assign(); }
      else if (!(isK('of') || isK('in')) && (kind === 'const' || tg.t !== 'Id')) {
        if (!noIn) throw __evSyn(kind === 'const' ? 'Missing initializer in const declaration' : 'Missing initializer in destructuring declaration');
      }
      decls.push({ a: tg, init: init });
      if (kind === 'var') {
        nm = __evPatNames(tg, []);
        for (i = 0; i < nm.length; i++) fctx.vars.push(nm[i]);
      }
      if (!isP(',')) break;
      p++;
    }
    return { t: 'Var', kind: kind, decls: decls };
  }
  function block() {
    var body = [], lx;
    expectP('{');
    while (!isP('}')) {
      if (T[p].k === 'e') fail();
      body.push(stmt());
    }
    p++;
    lx = __evLex(body);
    return { t: 'Block', body: body, lex: lx.lex, funs: lx.funs };
  }
  function forStmt() {
    var init = null, test = null, upd = null, body, kind, tg, it, sv, aw;
    p++;
    aw = false;
    if (isK('await')) { p++; aw = true; }
    expectP('(');
    if (isP(';')) {
      // pas d'initialisation
    } else if (isK('var') || isK('const') || (isK('let') && (T[p + 1].k === 'i' || (T[p + 1].k === 'p' && (T[p + 1].v === '[' || T[p + 1].v === '{'))))) {
      sv = noIn; noIn = true;
      init = varDecl();
      noIn = sv;
      if (isK('of') || isK('in')) {
        kind = T[p].v; p++;
        it = kind === 'of' ? assign() : expr();
        expectP(')');
        body = stmt();
        return { t: kind === 'of' ? 'ForOf' : 'ForIn', decl: init, a: null, it: it, body: body, aw: aw };
      }
    } else {
      sv = noIn; noIn = true;
      init = expr();
      noIn = sv;
      if (isK('of') || isK('in')) {
        kind = T[p].v; p++;
        tg = __evToTarget(init.t === 'Paren' ? init.e : init);
        it = kind === 'of' ? assign() : expr();
        expectP(')');
        body = stmt();
        return { t: kind === 'of' ? 'ForOf' : 'ForIn', decl: null, a: tg, it: it, body: body, aw: aw };
      }
      init = { t: 'Expr', e: init };
    }
    expectP(';');
    if (!isP(';')) test = expr();
    expectP(';');
    if (!isP(')')) upd = expr();
    expectP(')');
    body = stmt();
    return { t: 'For', init: init, test: test, upd: upd, body: body };
  }
  function stmt() {
    var t = T[p], n, a, b, c, cases, lx, bd, nm;
    if (t.k === 'p') {
      if (t.v === '{') return block();
      if (t.v === ';') { p++; return { t: 'Empty' }; }
    } else if (t.k === 'i') {
      switch (t.v) {
        case 'var': case 'const': n = varDecl(); semi(); return n;
        case 'let':
          if (T[p + 1].k === 'i' || (T[p + 1].k === 'p' && (T[p + 1].v === '[' || T[p + 1].v === '{'))) { n = varDecl(); semi(); return n; }
          break;
        case 'function': n = fnExpr(true); return { t: 'FnDecl', fn: n };
        case 'class': n = classBody(true); return { t: 'ClassDecl', cls: n };
        case 'async':
          if (T[p + 1].k === 'i' && T[p + 1].v === 'function' && !T[p + 1].nl) { p++; n = fnExpr(true, true); return { t: 'FnDecl', fn: n }; }
          break;
        case 'if':
          p++; expectP('('); a = expr(); expectP(')');
          b = stmt(); c = null;
          if (isK('else')) { p++; c = stmt(); }
          return { t: 'If', c: a, a: b, b: c };
        case 'for': return forStmt();
        case 'while':
          p++; expectP('('); a = expr(); expectP(')');
          return { t: 'While', c: a, body: stmt() };
        case 'do':
          p++; b = stmt();
          if (!isK('while')) fail();
          p++; expectP('('); a = expr(); expectP(')');
          if (isP(';')) p++;
          return { t: 'DoWhile', c: a, body: b };
        case 'return':
          if (!fctx.fn) throw __evSyn('Illegal return statement');
          p++; a = null;
          if (!isP(';') && !isP('}') && T[p].k !== 'e' && !T[p].nl) a = expr();
          semi();
          return { t: 'Return', a: a };
        case 'break': case 'continue':
          p++; nm = null;
          if (T[p].k === 'i' && !T[p].nl && __evKW[T[p].v] !== 1) { nm = T[p].v; p++; }
          semi();
          return { t: t.v === 'break' ? 'Break' : 'Continue', label: nm };
        case 'throw':
          p++;
          if (T[p].nl) throw __evSyn('Illegal newline after throw');
          a = expr(); semi();
          return { t: 'Throw', a: a };
        case 'try':
          p++; a = block(); b = null; c = null; nm = null;
          if (isK('catch')) {
            p++;
            if (isP('(')) { p++; nm = bindingTarget(); expectP(')'); }
            b = { param: nm, body: block() };
          }
          if (isK('finally')) { p++; c = block(); }
          if (!b && !c) throw __evSyn('Missing catch or finally after try');
          return { t: 'Try', block: a, h: b, f: c };
        case 'switch':
          p++; expectP('('); a = expr(); expectP(')'); expectP('{');
          cases = [];
          while (!isP('}')) {
            if (isK('case')) { p++; b = expr(); }
            else if (isK('default')) { p++; b = null; }
            else fail();
            expectP(':');
            bd = [];
            while (!isP('}') && !isK('case') && !isK('default')) {
              if (T[p].k === 'e') fail();
              bd.push(stmt());
            }
            cases.push({ test: b, body: bd });
          }
          p++;
          bd = [];
          for (b = 0; b < cases.length; b++) for (c = 0; c < cases[b].body.length; c++) bd.push(cases[b].body[c]);
          lx = __evLex(bd);
          return { t: 'Switch', d: a, cases: cases, lex: lx.lex, funs: lx.funs };
        case 'debugger': p++; semi(); return { t: 'Empty' };
        case 'with': unsup('with statements');
        case 'import': case 'export': unsup('modules');
      }
      if (__evKW[t.v] !== 1 && T[p + 1].k === 'p' && T[p + 1].v === ':') {
        p += 2;
        return { t: 'Labeled', label: t.v, body: stmt() };
      }
    }
    a = expr();
    semi();
    return { t: 'Expr', e: a };
  }
  var body = [], lx;
  while (T[p].k !== 'e') body.push(stmt());
  lx = __evLex(body);
  return { t: 'Program', body: body, vars: fctx.vars, lex: lx.lex, funs: lx.funs };
}
function __evParseExprSrc(s) {
  var prog = __evParse('(' + s + '\n)');
  return prog.body[0].e.e;
}
function __evBuiltin(name) {
  switch (name) {
    case 'undefined': return undefined;
    case 'NaN': return NaN;
    case 'Infinity': return Infinity;
    case 'globalThis': return globalThis;
    case 'Object': return Object;
    case 'Array': return Array;
    case 'String': return String;
    case 'Number': return Number;
    case 'Boolean': return Boolean;
    case 'Function': return Function;
    case 'RegExp': return RegExp;
    case 'Math': return Math;
    case 'JSON': return JSON;
    case 'Date': return Date;
    case 'Map': return Map;
    case 'Set': return Set;
    case 'WeakMap': return WeakMap;
    case 'WeakSet': return WeakSet;
    case 'Symbol': return Symbol;
    case 'Promise': return Promise;
    case 'BigInt': return BigInt;
    case 'Error': return Error;
    case 'EvalError': return EvalError;
    case 'RangeError': return RangeError;
    case 'ReferenceError': return ReferenceError;
    case 'SyntaxError': return SyntaxError;
    case 'TypeError': return TypeError;
    case 'URIError': return URIError;
    case 'AggregateError': return AggregateError;
    case 'parseInt': return parseInt;
    case 'parseFloat': return parseFloat;
    case 'isNaN': return isNaN;
    case 'isFinite': return isFinite;
    case 'encodeURIComponent': return encodeURIComponent;
    case 'decodeURIComponent': return decodeURIComponent;
    case 'encodeURI': return encodeURI;
    case 'decodeURI': return decodeURI;
    case 'console': return console;
    case 'process': return process;
    case 'setTimeout': return setTimeout;
    case 'setInterval': return setInterval;
    case 'setImmediate': return setImmediate;
    case 'clearTimeout': return clearTimeout;
    case 'clearInterval': return clearInterval;
    case 'clearImmediate': return clearImmediate;
    case 'queueMicrotask': return queueMicrotask;
    case 'structuredClone': return structuredClone;
    case 'performance': return performance;
    case 'require': return require;
    case 'module': return module;
    case 'exports': return exports;
    case 'eval': return eval;
  }
  return __evNone;
}
function __evScope(p) { return { v: {}, p: p, c: null, fn: null }; }
function __evRefErr(name) { return new ReferenceError(name + ' is not defined'); }
function __evTdzErr(name) { return new ReferenceError("Cannot access '" + name + "' before initialization"); }
function __evGlobalGet(name) {
  var k = '$' + name, b;
  if (k in __evg) return __evg[k];
  if (__ginfo(name) >= 0) return __gget(name);
  b = __evBuiltin(name);
  if (b !== __evNone) return b;
  throw __evRefErr(name);
}
function __evHasVar(s, name) {
  var k = '$' + name;
  while (s !== null) {
    if (k in s.v) return true;
    s = s.p;
  }
  return (k in __evg) || __ginfo(name) >= 0 || __evBuiltin(name) !== __evNone;
}
function __evGetVar(s, name) {
  var k = '$' + name, x;
  while (s !== null) {
    if (k in s.v) {
      x = s.v[k];
      if (x === __evTDZ) throw __evTdzErr(name);
      return x;
    }
    s = s.p;
  }
  return __evGlobalGet(name);
}
function __evSetVar(s, name, val) {
  var k = '$' + name, inf;
  while (s !== null) {
    if (k in s.v) {
      if (s.v[k] === __evTDZ) throw __evTdzErr(name);
      if (s.c !== null && s.c[k] === true) throw new TypeError('Assignment to constant variable.');
      s.v[k] = val;
      return;
    }
    s = s.p;
  }
  if (k in __evg) { __evg[k] = val; return; }
  inf = __ginfo(name);
  if (inf >= 0) {
    if (inf === 2) throw new TypeError('Assignment to constant variable.');
    __gset(name, val);
    return;
  }
  __evg[k] = val;
}
function __evDeclare(s, name, val, isConst) {
  var k = '$' + name;
  s.v[k] = val;
  if (isConst) {
    if (s.c === null) s.c = {};
    s.c[k] = true;
  }
}
function __evFnScope(s) {
  while (s !== null && s.fn === null) s = s.p;
  return s === null ? null : s.fn;
}
function __evText(n) {
  switch (n.t) {
    case 'Id': return n.n;
    case 'This': return 'this';
    case 'Paren': return __evText(n.e);
    case 'Chain': return __evText(n.e);
    case 'Mem': return n.c ? __evText(n.o) + '[...]' : __evText(n.o) + '.' + n.n;
    case 'Call': return __evText(n.f) + '(...)';
    case 'Super': return 'super';
    case 'Str': return '"' + n.v + '"';
    case 'Num': return String(n.v);
  }
  return '(intermediate value)';
}
function __evNamed(v, name) {
  if (typeof v === 'function') {
    try { Object.defineProperty(v, 'name', { value: name, configurable: true }); } catch (e) { }
  }
  return v;
}
function __evIsAnon(n) { return (n.t === 'Fn' && n.name === null) || (n.t === 'Cls' && n.cls.name === null); }
function __evToArr(v) {
  if (v === null || v === undefined) throw new TypeError(String(v) + ' is not iterable');
  if (Array.isArray(v)) return v;
  return [...v];
}
function __evBind(pat, val, s, mode) {
  var i, arr, pr, key, used, k, rest, el;
  switch (pat.t) {
    case 'Id':
      if (mode === 'asg' || mode === 'var') __evSetVar(s, pat.n, val);
      else __evDeclare(s, pat.n, val, mode === 'const');
      return;
    case 'Mem':
      __evPut(pat, val, s);
      return;
    case 'DefPat':
      if (val === undefined) {
        val = __evEval(pat.d, s);
        if (pat.a.t === 'Id' && __evIsAnon(pat.d)) __evNamed(val, pat.a.n);
      }
      __evBind(pat.a, val, s, mode);
      return;
    case 'ArrPat':
      arr = __evToArr(val);
      for (i = 0; i < pat.el.length; i++) {
        if (pat.el[i] !== null) __evBind(pat.el[i], arr[i], s, mode);
      }
      if (pat.rest) __evBind(pat.rest, arr.slice(pat.el.length), s, mode);
      return;
    case 'ObjPat':
      if (val === null || val === undefined) throw new TypeError("Cannot destructure '" + String(val) + "' as it is " + String(val) + '.');
      used = [];
      for (i = 0; i < pat.props.length; i++) {
        pr = pat.props[i];
        key = pr.c ? __evEval(pr.k, s) : pr.k;
        used.push(String(key));
        __evBind(pr.v, val[key], s, mode);
      }
      if (pat.rest) {
        rest = {};
        for (k in val) if (Object.prototype.hasOwnProperty.call(val, k) && used.indexOf(k) < 0) rest[k] = val[k];
        __evBind(pat.rest, rest, s, mode);
      }
      return;
  }
  throw new SyntaxError('Invalid destructuring target');
}
function __evObjOf(n, s) {
  // objet et cle d'une reference membre : [objet, cle]
  var o, key;
  if (n.o.t === 'Super') {
    var fi = __evFnScope(s);
    o = fi && fi.home !== undefined ? Object.getPrototypeOf(fi.home) : undefined;
    key = n.c ? __evEval(n.i, s) : n.n;
    return [o, key, fi ? fi.th : undefined];
  }
  o = __evEval(n.o, s);
  if (o === __evSHORT) return [__evSHORT, null, null];
  if (n.opt && (o === null || o === undefined)) return [__evSHORT, null, null];
  key = n.c ? __evEval(n.i, s) : n.n;
  return [o, key, o];
}
function __evPut(n, val, s) {
  var r = __evObjOf(n, s), o = r[0];
  if (o === null || o === undefined) throw new TypeError("Cannot set properties of " + String(o) + " (setting '" + String(r[1]) + "')");
  o[r[1]] = val;
}
function __evArgs(list, s) {
  var out = [], i, v, j, sp;
  for (i = 0; i < list.length; i++) {
    if (list[i].t === 'Spread') {
      sp = __evToArr(__evEval(list[i].a, s));
      for (j = 0; j < sp.length; j++) out.push(sp[j]);
    } else {
      out.push(__evEval(list[i], s));
    }
  }
  return out;
}
function __evKey(k) { return k; }
function __evBinop(op, a, b) {
  switch (op) {
    case '+': return a + b;
    case '-': return a - b;
    case '*': return a * b;
    case '/': return a / b;
    case '%': return a % b;
    case '**': return a ** b;
    case '==': return a == b;
    case '!=': return a != b;
    case '===': return a === b;
    case '!==': return a !== b;
    case '<': return a < b;
    case '>': return a > b;
    case '<=': return a <= b;
    case '>=': return a >= b;
    case '&': return a & b;
    case '|': return a | b;
    case '^': return a ^ b;
    case '<<': return a << b;
    case '>>': return a >> b;
    case '>>>': return a >>> b;
    case 'in':
      if (b === null || (typeof b !== 'object' && typeof b !== 'function')) throw new TypeError("Cannot use 'in' operator to search for '" + String(a) + "' in " + String(b));
      return a in b;
    case 'instanceof':
      if (typeof b !== 'function') throw new TypeError("Right-hand side of 'instanceof' is not callable");
      return a instanceof b;
  }
  throw new SyntaxError('Unknown operator ' + op);
}
async function __evAsyncRun(node, scope, home, thisv, args, nt, f) { return __evInvoke(node, scope, home, thisv, args, nt, f); }
function* __evGenRun(node, scope, home, thisv, args, nt, f) { return __evInvoke(node, scope, home, thisv, args, nt, f); }
async function* __evAGenRun(node, scope, home, thisv, args, nt, f) { return __evInvoke(node, scope, home, thisv, args, nt, f); }
function __evYieldStar(x) {
  var it = x[Symbol.iterator](), sent, r;
  for (;;) {
    r = it.next(sent);
    if (r.done) return r.value;
    sent = __co_yield(r.value);
  }
}
function __evMkFn(node, scope, home) {
  var f;
  if (node.gen || node.asy) {
    var run = node.gen ? (node.asy ? __evAGenRun : __evGenRun) : __evAsyncRun;
    if (node.arrow) f = function () { return run(node, scope, home, undefined, arguments, undefined, f); };
    else f = function () { return run(node, scope, home, this, arguments, undefined, f); };
  } else if (node.arrow) {
    f = function () { return __evInvoke(node, scope, home, undefined, arguments, undefined, f); };
  } else {
    f = function () { return __evInvoke(node, scope, home, this, arguments, new.target, f); };
  }
  if (node.name !== null && node.kind === 'fn') __evNamed(f, node.name);
  __evLen(f, node);
  return f;
}
function __evLen(f, node) {
  var n = 0, i;
  for (i = 0; i < node.params.length; i++) {
    if (node.params[i].t === 'DefPat') break;
    n++;
  }
  try { Object.defineProperty(f, 'length', { value: n, configurable: true }); } catch (e) { }
}
function __evInvoke(node, closure, home, thisv, args, nt, fobj) {
  var s = __evScope(closure), i, sig, ps = node.params, k;
  if (!node.arrow) {
    s.fn = { th: thisv, nt: nt, home: home, args: args, fo: fobj };
    s.v.$arguments = args;
  }
  for (i = 0; i < node.vars.length; i++) {
    k = '$' + node.vars[i];
    if (!(k in s.v)) s.v[k] = undefined;
  }
  for (i = 0; i < ps.length; i++) __evBind(ps[i], args[i], s, 'let');
  if (node.rest) {
    var r = [];
    for (i = ps.length; i < args.length; i++) r.push(args[i]);
    __evBind(node.rest, r, s, 'let');
  }
  if (node.exprBody) return __evEval(node.body, s);
  __evHoist(node.lex, node.funs, s);
  sig = __evExecList(node.body, s);
  if (sig !== null && sig.t === 3) return sig.v;
  return undefined;
}
function __evHoist(lex, funs, s) {
  var i;
  for (i = 0; i < lex.length; i++) __evDeclare(s, lex[i].n, __evTDZ, lex[i].c);
  for (i = 0; i < funs.length; i++) __evDeclare(s, funs[i].fn.name, __evMkFn(funs[i].fn, s, undefined), false);
}
function __evExecList(list, s) {
  var i, sig;
  for (i = 0; i < list.length; i++) {
    sig = __evExec(list[i], s, null);
    if (sig !== null) return sig;
  }
  return null;
}
function __evInitFields(info, obj) {
  var i, fl = info.fields, f, s, v;
  for (i = 0; i < fl.length; i++) {
    f = fl[i];
    s = __evScope(info.scope);
    s.fn = { th: obj, nt: undefined, home: info.proto, args: [], fo: info.C };
    v = f.v === null ? undefined : __evEval(f.v, s);
    if (f.v !== null && __evIsAnon(f.v)) __evNamed(v, String(f.k));
    Object.defineProperty(obj, f.k, { value: v, writable: true, enumerable: String(f.k).charAt(0) !== '#', configurable: true });
  }
}
function __evSuperCall(fi, args) {
  var info = fi.info, parent = info.parent, r;
  if (fi.th !== undefined) throw new ReferenceError('Super constructor may only be called once');
  if (typeof parent !== 'function') throw new TypeError('Super constructor ' + String(parent) + ' of anonymous class is not a constructor');
  r = new parent(...args);
  if (fi.nt !== undefined && fi.nt !== null && r !== null && typeof r === 'object') Object.setPrototypeOf(r, fi.nt.prototype);
  fi.th = r;
  __evInitFields(info, r);
  return r;
}
function __evRunCtor(info, thisv, args, nt) {
  var s = __evScope(info.scope), fi, node = info.node, res, sig, i, k, ps, r;
  fi = { th: info.derived ? undefined : thisv, nt: nt, home: info.proto, args: args, fo: info.C, info: info };
  s.fn = fi;
  s.v.$arguments = args;
  if (!info.derived) __evInitFields(info, thisv);
  if (node === null) {
    if (info.derived) __evSuperCall(fi, args);
    return fi.th;
  }
  for (i = 0; i < node.vars.length; i++) {
    k = '$' + node.vars[i];
    if (!(k in s.v)) s.v[k] = undefined;
  }
  ps = node.params;
  for (i = 0; i < ps.length; i++) __evBind(ps[i], args[i], s, 'let');
  if (node.rest) {
    r = [];
    for (i = ps.length; i < args.length; i++) r.push(args[i]);
    __evBind(node.rest, r, s, 'let');
  }
  __evHoist(node.lex, node.funs, s);
  sig = __evExecList(node.body, s);
  if (sig !== null && sig.t === 3 && sig.v !== null && (typeof sig.v === 'object' || typeof sig.v === 'function')) return sig.v;
  if (fi.th === undefined) throw new ReferenceError("Must call super constructor in derived class before accessing 'this' or returning from derived constructor");
  return fi.th;
}
function __evDefine(target, key, kind, fn, enumerable) {
  if (kind === 'get') Object.defineProperty(target, key, { get: fn, enumerable: enumerable, configurable: true });
  else if (kind === 'set') Object.defineProperty(target, key, { set: fn, enumerable: enumerable, configurable: true });
  else Object.defineProperty(target, key, { value: fn, writable: true, enumerable: enumerable, configurable: true });
}
function __evClass(c, s) {
  var cs = __evScope(s), parent, protoParent, proto, info, C, i, m, key, ctorNode = null, fn, target, statics = [], fs, v;
  if (c.sup) {
    parent = __evEval(c.sup, cs);
    if (parent !== null && typeof parent !== 'function') throw new TypeError('Class extends value ' + String(parent) + ' is not a constructor or null');
    protoParent = parent === null ? null : parent.prototype;
  } else {
    protoParent = Object.prototype;
  }
  proto = Object.create(protoParent);
  for (i = 0; i < c.members.length; i++) if (c.members[i].ctor) ctorNode = c.members[i].v;
  info = { node: ctorNode, scope: cs, derived: c.sup !== null, fields: [], proto: proto, parent: parent, C: null, name: c.name };
  C = function () {
    if (new.target === undefined) throw new TypeError("Class constructor " + (info.name || '') + " cannot be invoked without 'new'");
    return __evRunCtor(info, this, arguments, new.target);
  };
  info.C = C;
  if (c.sup && parent !== null) Object.setPrototypeOf(C, parent);
  C.prototype = proto;
  Object.defineProperty(proto, 'constructor', { value: C, writable: true, configurable: true, enumerable: false });
  if (c.name !== null) {
    __evDeclare(cs, c.name, C, true);
    __evNamed(C, c.name);
  }
  for (i = 0; i < c.members.length; i++) {
    m = c.members[i];
    if (m.ctor) continue;
    if (m.kind === 'block') { statics.push(m); continue; }
    target = m.st ? C : proto;
    key = m.c ? __evEval(m.k, cs) : m.k;
    if (m.kind === 'field') {
      if (m.st) statics.push({ kind: 'field', k: key, v: m.v });
      else info.fields.push({ k: key, v: m.v });
    } else {
      fn = __evMkFn(m.v, cs, target);
      __evNamed(fn, String(key));
      __evDefine(target, key, m.kind, fn, false);
    }
  }
  for (i = 0; i < statics.length; i++) {
    m = statics[i];
    fs = __evScope(cs);
    fs.fn = { th: C, nt: undefined, home: C, args: [], fo: C };
    if (m.kind === 'block') {
      __evHoist(m.v.lex, m.v.funs, fs);
      __evExecList(m.v.body, fs);
    } else {
      v = m.v === null ? undefined : __evEval(m.v, fs);
      Object.defineProperty(C, m.k, { value: v, writable: true, enumerable: String(m.k).charAt(0) !== '#', configurable: true });
    }
  }
  return C;
}
function __evEval(n, s) {
  var o, v, f, a, i, r, k, key, pr, t, fi, d, arr, th;
  switch (n.t) {
    case 'Num': case 'Str': return n.v;
    case 'Id': return __evGetVar(s, n.n);
    case 'Paren': return __evEval(n.e, s);
    case 'Null': return null;
    case 'Bool': return n.v;
    case 'Big': return BigInt(n.v);
    case 'This':
      fi = __evFnScope(s);
      if (fi === null) return undefined;
      if (fi.th === undefined && fi.info !== undefined) throw new ReferenceError("Must call super constructor in derived class before accessing 'this' or returning from derived constructor");
      return fi.th;
    case 'Tpl':
      r = n.q[0];
      for (i = 0; i < n.e.length; i++) r += String(__evEval(n.e[i], s)) + n.q[i + 1];
      return r;
    case 'TTpl':
      if (!n.cache) { n.cache = n.q.slice(); n.cache.raw = n.r.slice(); }
      a = [n.cache];
      for (i = 0; i < n.e.length; i++) a.push(__evEval(n.e[i], s));
      if (n.tag.t === 'Mem') {
        t = __evObjOf(n.tag, s);
        f = t[0][t[1]];
        th = t[2];
      } else {
        f = __evEval(n.tag, s);
        th = undefined;
      }
      if (typeof f !== 'function') throw new TypeError(__evText(n.tag) + ' is not a function');
      return f.apply(th, a);
    case 'Reg': return new RegExp(n.v, n.f);
    case 'Arr':
      arr = [];
      for (i = 0; i < n.el.length; i++) {
        v = n.el[i];
        if (v === null) arr.push(undefined);
        else if (v.t === 'Spread') {
          d = __evToArr(__evEval(v.a, s));
          for (k = 0; k < d.length; k++) arr.push(d[k]);
        } else arr.push(__evEval(v, s));
      }
      return arr;
    case 'Obj':
      o = {};
      for (i = 0; i < n.props.length; i++) {
        pr = n.props[i];
        if (pr.kind === 'spread') {
          v = __evEval(pr.v, s);
          if (v !== null && v !== undefined) Object.assign(o, v);
          continue;
        }
        key = pr.c ? __evEval(pr.k, s) : pr.k;
        if (pr.kind === 'get' || pr.kind === 'set') {
          f = __evMkFn(pr.v, s, o);
          __evDefine(o, key, pr.kind, f, true);
        } else if (pr.method) {
          f = __evMkFn(pr.v, s, o);
          __evNamed(f, String(key));
          o[key] = f;
        } else {
          v = __evEval(pr.v, s);
          if (!pr.c && !pr.short && key === '__proto__') {
            if (v === null || typeof v === 'object' || typeof v === 'function') Object.setPrototypeOf(o, v);
          } else {
            if (__evIsAnon(pr.v)) __evNamed(v, String(key));
            o[key] = v;
          }
        }
      }
      return o;
    case 'Fn':
      if (n.name !== null && n.kind === 'fn') {
        r = __evScope(s);
        f = __evMkFn(n, r, undefined);
        __evDeclare(r, n.name, f, false);
        return f;
      }
      return __evMkFn(n, s, undefined);
    case 'Cls': return __evClass(n.cls, s);
    case 'Await': return __co_await(__evEval(n.a, s));
    case 'Yield':
      v = n.a === null ? undefined : __evEval(n.a, s);
      if (n.dlg) return n.ag ? __i_ystarA(v) : __evYieldStar(v);
      return __co_yield(v);
    case 'ImportCall':
      v = __evEval(n.a, s);
      return Promise.resolve().then(function () {
        var m = require(String(v));
        return m !== null && typeof m === 'object' ? Object.assign({ default: m }, m) : { default: m };
      });
    case 'Seq':
      for (i = 0; i < n.l.length; i++) v = __evEval(n.l[i], s);
      return v;
    case 'Cnd': return __evEval(n.c, s) ? __evEval(n.a, s) : __evEval(n.b, s);
    case 'Log':
      v = __evEval(n.l, s);
      if (n.op === '&&') return v ? __evEval(n.r, s) : v;
      if (n.op === '||') return v ? v : __evEval(n.r, s);
      return (v === null || v === undefined) ? __evEval(n.r, s) : v;
    case 'Bin': return __evBinop(n.op, __evEval(n.l, s), __evEval(n.r, s));
    case 'Un':
      if (n.op === 'typeof') {
        if (n.a.t === 'Id' && !__evHasVar(s, n.a.n)) return 'undefined';
        return typeof __evEval(n.a, s);
      }
      if (n.op === 'delete') {
        if (n.a.t === 'Mem') {
          t = __evObjOf(n.a, s);
          if (t[0] === null || t[0] === undefined) throw new TypeError('Cannot convert undefined or null to object');
          return delete t[0][t[1]];
        }
        if (n.a.t === 'Chain') return true;
        return n.a.t !== 'Id';
      }
      v = __evEval(n.a, s);
      switch (n.op) {
        case '!': return !v;
        case '-': return -v;
        case '+': return +v;
        case '~': return ~v;
        case 'void': return undefined;
      }
      return undefined;
    case 'Upd':
      if (n.a.t === 'Id') {
        v = __evGetVar(s, n.a.n);
        t = typeof v === 'bigint' ? v : Number(v);
        r = n.op === '++' ? t + (typeof t === 'bigint' ? 1n : 1) : t - (typeof t === 'bigint' ? 1n : 1);
        __evSetVar(s, n.a.n, r);
      } else {
        a = n.a.t === 'Paren' ? n.a.e : n.a;
        t = __evObjOf(a, s);
        if (t[0] === null || t[0] === undefined) throw new TypeError("Cannot read properties of " + String(t[0]) + " (reading '" + String(t[1]) + "')");
        v = t[0][t[1]];
        t = [t[0], t[1], typeof v === 'bigint' ? v : Number(v)];
        r = n.op === '++' ? t[2] + (typeof t[2] === 'bigint' ? 1n : 1) : t[2] - (typeof t[2] === 'bigint' ? 1n : 1);
        t[0][t[1]] = r;
        t = t[2];
      }
      return n.pre ? r : t;
    case 'Asg': return __evAssign(n, s);
    case 'Mem':
      t = __evObjOf(n, s);
      o = t[0];
      if (o === __evSHORT) return __evSHORT;
      if (o === null || o === undefined) throw new TypeError("Cannot read properties of " + String(o) + " (reading '" + String(t[1]) + "')");
      return o[t[1]];
    case 'Chain':
      v = __evEval(n.e, s);
      return v === __evSHORT ? undefined : v;
    case 'Call':
      if (n.f.t === 'Super') {
        fi = __evFnScope(s);
        if (fi === null || fi.info === undefined) throw new SyntaxError("'super' keyword unexpected here");
        return __evSuperCall(fi, __evArgs(n.a, s));
      }
      th = undefined;
      f = n.f;
      while (f.t === 'Paren') f = f.e;
      if (f.t === 'Mem') {
        t = __evObjOf(f, s);
        o = t[0];
        if (o === __evSHORT) return __evSHORT;
        if (o === null || o === undefined) throw new TypeError("Cannot read properties of " + String(o) + " (reading '" + String(t[1]) + "')");
        v = o[t[1]];
        th = t[2];
      } else {
        v = __evEval(f, s);
        if (v === __evSHORT) return __evSHORT;
      }
      if (n.opt && (v === null || v === undefined)) return __evSHORT;
      if (typeof v !== 'function') throw new TypeError(__evText(n.f) + ' is not a function');
      return v.apply(th, __evArgs(n.a, s));
    case 'New':
      f = __evEval(n.f, s);
      if (typeof f !== 'function') throw new TypeError(__evText(n.f) + ' is not a constructor');
      a = __evArgs(n.a, s);
      return new f(...a);
    case 'NewTarget':
      fi = __evFnScope(s);
      return fi === null ? undefined : fi.nt;
    case 'Spread': throw new SyntaxError('Unexpected token ...');
    case 'Super': throw new SyntaxError("'super' keyword unexpected here");
  }
  throw new SyntaxError('eval: unsupported expression ' + n.t);
}
function __evAssign(n, s) {
  var a = n.a, op = n.op, v, t, cur, r;
  if (op === '=') {
    if (a.t === 'Id') {
      v = __evEval(n.v, s);
      if (__evIsAnon(n.v)) __evNamed(v, a.n);
      __evSetVar(s, a.n, v);
      return v;
    }
    if (a.t === 'Mem') {
      t = __evObjOf(a, s);
      v = __evEval(n.v, s);
      if (t[0] === null || t[0] === undefined) throw new TypeError("Cannot set properties of " + String(t[0]) + " (setting '" + String(t[1]) + "')");
      t[0][t[1]] = v;
      return v;
    }
    v = __evEval(n.v, s);
    __evBind(a, v, s, 'asg');
    return v;
  }
  if (a.t === 'Id') {
    cur = __evGetVar(s, a.n);
    t = null;
  } else {
    t = __evObjOf(a, s);
    if (t[0] === null || t[0] === undefined) throw new TypeError("Cannot read properties of " + String(t[0]) + " (reading '" + String(t[1]) + "')");
    cur = t[0][t[1]];
  }
  if (op === '&&=') { if (!cur) return cur; r = __evEval(n.v, s); }
  else if (op === '||=') { if (cur) return cur; r = __evEval(n.v, s); }
  else if (op === '??=') { if (cur !== null && cur !== undefined) return cur; r = __evEval(n.v, s); }
  else r = __evBinop(op.slice(0, op.length - 1), cur, __evEval(n.v, s));
  if (t === null) __evSetVar(s, a.n, r);
  else t[0][t[1]] = r;
  return r;
}
function __evLoopSig(sig, labels) {
  // 0 = continuer la boucle, 1 = sortir en rendant null, 2 = rendre sig
  if (sig === null) return 0;
  if (sig.t === 1) return (sig.l === null || labels.indexOf(sig.l) >= 0) ? 1 : 2;
  if (sig.t === 2) return (sig.l === null || labels.indexOf(sig.l) >= 0) ? 0 : 2;
  return 2;
}
function __evExec(n, s, labels) {
  var i, v, sig, d, c, ls, k, ns, it, key, act, found, cur, x, q, lets;
  if (labels === null) labels = [];
  switch (n.t) {
    case 'Expr': __evcv = __evEval(n.e, s); return null;
    case 'Var':
      for (i = 0; i < n.decls.length; i++) {
        d = n.decls[i];
        if (d.init === null) {
          if (n.kind !== 'var') __evBind(d.a, undefined, s, n.kind);
          continue;
        }
        v = __evEval(d.init, s);
        if (d.a.t === 'Id' && __evIsAnon(d.init)) __evNamed(v, d.a.n);
        __evBind(d.a, v, s, n.kind);
      }
      return null;
    case 'FnDecl': return null;
    case 'ClassDecl':
      v = __evClass(n.cls, s);
      __evDeclare(s, n.cls.name, v, false);
      return null;
    case 'Empty': return null;
    case 'Block':
      ns = __evScope(s);
      __evHoist(n.lex, n.funs, ns);
      return __evExecList(n.body, ns);
    case 'If':
      if (__evEval(n.c, s)) return __evExec(n.a, s, null);
      if (n.b !== null) return __evExec(n.b, s, null);
      return null;
    case 'Return': return { t: 3, l: null, v: n.a === null ? undefined : __evEval(n.a, s) };
    case 'Break': return { t: 1, l: n.label, v: undefined };
    case 'Continue': return { t: 2, l: n.label, v: undefined };
    case 'Throw': throw __evEval(n.a, s);
    case 'Labeled':
      ls = labels.concat([n.label]);
      sig = __evExec(n.body, s, ls);
      if (sig !== null && sig.t === 1 && sig.l === n.label) return null;
      return sig;
    case 'While':
      while (__evEval(n.c, s)) {
        sig = __evExec(n.body, s, null);
        act = __evLoopSig(sig, labels);
        if (act === 1) return null;
        if (act === 2) return sig;
      }
      return null;
    case 'DoWhile':
      do {
        sig = __evExec(n.body, s, null);
        act = __evLoopSig(sig, labels);
        if (act === 1) return null;
        if (act === 2) return sig;
      } while (__evEval(n.c, s));
      return null;
    case 'For':
      ns = __evScope(s);
      lets = [];
      if (n.init !== null) {
        if (n.init.t === 'Var' && n.init.kind !== 'var') {
          for (i = 0; i < n.init.decls.length; i++) lets = __evPatNames(n.init.decls[i].a, lets);
          for (i = 0; i < lets.length; i++) __evDeclare(ns, lets[i], __evTDZ, n.init.kind === 'const');
        }
        __evExec(n.init, ns, null);
      }
      for (;;) {
        if (n.test !== null && !__evEval(n.test, ns)) break;
        sig = __evExec(n.body, ns, null);
        act = __evLoopSig(sig, labels);
        if (act === 1) return null;
        if (act === 2) return sig;
        if (lets.length > 0) {
          q = __evScope(s);
          for (i = 0; i < lets.length; i++) q.v['$' + lets[i]] = ns.v['$' + lets[i]];
          q.c = ns.c;
          ns = q;
        }
        if (n.upd !== null) __evEval(n.upd, ns);
      }
      return null;
    case 'ForIn':
    case 'ForOf':
      v = __evEval(n.it, s);
      if (n.aw) v = __i_forawait(v);
      if (n.t === 'ForIn') {
        if (v === null || v === undefined) return null;
        it = [];
        for (key in v) it.push(key);
      } else {
        it = v;
        if (it === null || it === undefined) throw new TypeError(String(it) + ' is not iterable');
      }
      for (x of it) {
        ns = __evScope(s);
        if (n.decl !== null) {
          d = n.decl;
          __evBind(d.decls[0].a, x, ns, d.kind);
        } else {
          __evBind(n.a, x, ns, 'asg');
        }
        sig = __evExec(n.body, ns, null);
        act = __evLoopSig(sig, labels);
        if (act === 1) return null;
        if (act === 2) return sig;
      }
      return null;
    case 'Try':
      sig = null;
      found = false;
      cur = undefined;
      try {
        sig = __evExec(n.block, s, null);
      } catch (e) {
        if (n.h !== null) {
          try {
            ns = __evScope(s);
            if (n.h.param !== null) __evBind(n.h.param, e, ns, 'let');
            sig = __evExec(n.h.body, ns, null);
          } catch (e2) {
            found = true;
            cur = e2;
          }
        } else {
          found = true;
          cur = e;
        }
      }
      if (n.f !== null) {
        q = __evcv;
        x = __evExec(n.f, s, null);
        if (x !== null) return x;
        __evcv = q;
      }
      if (found) throw cur;
      return sig;
    case 'Switch':
      v = __evEval(n.d, s);
      ns = __evScope(s);
      __evHoist(n.lex, n.funs, ns);
      found = -1;
      for (i = 0; i < n.cases.length; i++) {
        if (n.cases[i].test !== null && __evEval(n.cases[i].test, ns) === v) { found = i; break; }
      }
      if (found < 0) {
        for (i = 0; i < n.cases.length; i++) if (n.cases[i].test === null) { found = i; break; }
      }
      if (found < 0) return null;
      for (i = found; i < n.cases.length; i++) {
        sig = __evExecList(n.cases[i].body, ns);
        if (sig !== null) {
          if (sig.t === 1 && (sig.l === null || labels.indexOf(sig.l) >= 0)) return null;
          return sig;
        }
      }
      return null;
  }
  throw new SyntaxError('eval: unsupported statement ' + n.t);
}
function __evRun(prog) {
  var s = { v: {}, p: null, c: null, fn: { th: globalThis, nt: undefined, home: undefined, args: [], fo: undefined } }, i, k, f, sig;
  for (i = 0; i < prog.vars.length; i++) {
    k = '$' + prog.vars[i];
    if (!(k in __evg) && __ginfo(prog.vars[i]) < 0) __evg[k] = undefined;
  }
  __evHoist(prog.lex, [], s);
  for (i = 0; i < prog.funs.length; i++) {
    f = prog.funs[i].fn;
    __evSetVar(s, f.name, __evMkFn(f, s, undefined));
  }
  __evcv = undefined;
  sig = __evExecList(prog.body, s);
  return __evcv;
}
function __eval(x) {
  if (typeof x !== 'string') return x;
  return __evRun(__evParse(x));
}
function __evnewfn(a) {
  var ps = [], i, body = '';
  for (i = 0; i < a.length - 1; i++) ps.push(String(a[i]));
  if (a.length > 0) body = String(a[a.length - 1]);
  return __evRun(__evParse('(function anonymous(' + ps.join(',') + '\n) {\n' + body + '\n})'));
}
