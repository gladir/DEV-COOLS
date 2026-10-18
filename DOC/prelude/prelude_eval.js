function __evtok(src) {
  var t = [], i = 0, n = src.length, c, j, q, s, ch, m;
  var ops3 = ['===', '!==', '>>>', '**=', '...'];
  var ops2 = ['==', '!=', '<=', '>=', '&&', '||', '??', '<<', '>>', '**', '=>', '?.'];
  while (i < n) {
    c = src.charAt(i);
    if (c === ' ' || c === '\t' || c === '\n' || c === '\r') { i++; continue; }
    if ((c >= '0' && c <= '9') || (c === '.' && src.charAt(i + 1) >= '0' && src.charAt(i + 1) <= '9')) {
      m = /^(0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)/.exec(src.slice(i));
      t.push({ k: 'n', v: Number(m[0]) });
      i += m[0].length;
      continue;
    }
    if (c === '"' || c === "'") {
      q = c; s = ''; i++;
      while (i < n && src.charAt(i) !== q) {
        ch = src.charAt(i);
        if (ch === '\\') {
          i++; ch = src.charAt(i);
          if (ch === 'n') s += '\n'; else if (ch === 't') s += '\t'; else if (ch === 'r') s += '\r';
          else if (ch === 'x') { s += String.fromCharCode(parseInt(src.slice(i + 1, i + 3), 16)); i += 2; }
          else if (ch === 'u') { s += String.fromCharCode(parseInt(src.slice(i + 1, i + 5), 16)); i += 4; }
          else s += ch;
        } else s += ch;
        i++;
      }
      if (i >= n) throw new SyntaxError('Invalid or unexpected token');
      i++;
      t.push({ k: 's', v: s });
      continue;
    }
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c === '_' || c === '$') {
      j = i;
      while (j < n && /[A-Za-z0-9_$]/.test(src.charAt(j))) j++;
      t.push({ k: 'i', v: src.slice(i, j) });
      i = j;
      continue;
    }
    if (ops3.indexOf(src.substr(i, 3)) >= 0) { t.push({ k: 'p', v: src.substr(i, 3) }); i += 3; continue; }
    if (ops2.indexOf(src.substr(i, 2)) >= 0) { t.push({ k: 'p', v: src.substr(i, 2) }); i += 2; continue; }
    t.push({ k: 'p', v: c });
    i++;
  }
  t.push({ k: 'e', v: '' });
  return t;
}
function __evparse(toks) {
  var p = 0;
  var prec = { '??': 1, '||': 2, '&&': 3, '|': 4, '^': 5, '&': 6, '==': 7, '!=': 7, '===': 7, '!==': 7, '<': 8, '>': 8, '<=': 8, '>=': 8, 'in': 8, 'instanceof': 8,
    '<<': 9, '>>': 9, '>>>': 9, '+': 10, '-': 10, '*': 11, '/': 11, '%': 11, '**': 12 };
  function peek() { return toks[p]; }
  function isP(v) { return toks[p].k === 'p' && toks[p].v === v; }
  function expect(v) {
    if (!isP(v)) throw new SyntaxError("Unexpected token '" + toks[p].v + "'");
    p++;
  }
  function primary() {
    var t = toks[p], r, a, k;
    if (t.k === 'n' || t.k === 's') { p++; return ['v', t.v]; }
    if (t.k === 'i') {
      p++;
      if (t.v === 'true') return ['v', true];
      if (t.v === 'false') return ['v', false];
      if (t.v === 'null') return ['v', null];
      if (t.v === 'var' || t.v === 'let' || t.v === 'const' || t.v === 'function' || t.v === 'if' || t.v === 'for' || t.v === 'while' || t.v === 'return' || t.v === 'class') {
        throw new EvalError('eval: statements are not supported by JSCW32 (only expressions)');
      }
      return ['id', t.v];
    }
    if (isP('(')) { p++; r = expr(); expect(')'); return r; }
    if (isP('[')) {
      p++; a = [];
      while (!isP(']')) { a.push(assign()); if (isP(',')) p++; else break; }
      expect(']');
      return ['arr', a];
    }
    if (isP('{')) {
      p++; a = [];
      while (!isP('}')) {
        k = toks[p]; p++;
        if (isP(':')) { p++; a.push([k.v, assign()]); } else a.push([k.v, ['id', k.v]]);
        if (isP(',')) p++; else break;
      }
      expect('}');
      return ['obj', a];
    }
    throw new SyntaxError("Unexpected token '" + t.v + "'");
  }
  function postfix() {
    var e = primary(), a;
    for (;;) {
      if (isP('.') || isP('?.')) {
        var opt = isP('?.');
        p++;
        if (opt && isP('(')) { e = ['call', e, args(), true]; continue; }
        if (opt && isP('[')) { p++; var ix = expr(); expect(']'); e = ['mem', e, ix, true]; continue; }
        e = ['mem', e, ['v', toks[p].v], opt]; p++;
      } else if (isP('[')) { p++; var ix2 = expr(); expect(']'); e = ['mem', e, ix2, false]; }
      else if (isP('(')) e = ['call', e, args(), false];
      else break;
    }
    return e;
  }
  function args() {
    expect('(');
    var a = [];
    while (!isP(')')) { a.push(assign()); if (isP(',')) p++; else break; }
    expect(')');
    return a;
  }
  function unary() {
    var t = toks[p];
    if (t.k === 'p' && (t.v === '-' || t.v === '+' || t.v === '!' || t.v === '~')) { p++; return ['un', t.v, unary()]; }
    if (t.k === 'i' && (t.v === 'typeof' || t.v === 'void')) { p++; return ['un', t.v, unary()]; }
    return postfix();
  }
  function binary(minp) {
    var l = unary(), t, pr, r;
    for (;;) {
      t = toks[p];
      if (!((t.k === 'p' || (t.k === 'i' && (t.v === 'in' || t.v === 'instanceof'))) && prec[t.v] !== undefined)) break;
      pr = prec[t.v];
      if (pr < minp) break;
      p++;
      r = t.v === '**' ? binary(pr) : binary(pr + 1);
      l = [(t.v === '&&' || t.v === '||' || t.v === '??') ? 'lg' : 'bin', t.v, l, r];
    }
    return l;
  }
  function assign() {
    var c = binary(1), a, b;
    if (isP('?')) { p++; a = assign(); expect(':'); b = assign(); return ['cond', c, a, b]; }
    return c;
  }
  function expr() {
    var e = assign();
    while (isP(',')) { p++; e = ['seq', e, assign()]; }
    return e;
  }
  var list = [];
  while (peek().k !== 'e') {
    if (isP(';')) { p++; continue; }
    list.push(expr());
    if (peek().k !== 'e' && !isP(';')) throw new SyntaxError("Unexpected token '" + peek().v + "'");
  }
  return list;
}
function __evrun(n, env) {
  var t = n[0], a, b, i, o, f, args, c;
  if (t === 'v') return n[1];
  if (t === 'id') {
    if (n[1] === 'undefined') return undefined;
    if (n[1] === 'NaN') return NaN;
    if (n[1] === 'Infinity') return Infinity;
    if (env[n[1]] !== undefined) return env[n[1]]();
    throw new ReferenceError(n[1] + ' is not defined');
  }
  if (t === 'arr') { a = []; for (i = 0; i < n[1].length; i++) a.push(__evrun(n[1][i], env)); return a; }
  if (t === 'obj') { o = {}; for (i = 0; i < n[1].length; i++) o[n[1][i][0]] = __evrun(n[1][i][1], env); return o; }
  if (t === 'cond') return __evrun(n[1], env) ? __evrun(n[2], env) : __evrun(n[3], env);
  if (t === 'seq') { __evrun(n[1], env); return __evrun(n[2], env); }
  if (t === 'un') {
    if (n[1] === 'typeof' && n[2][0] === 'id' && env[n[2][1]] === undefined && n[2][1] !== 'undefined') return 'undefined';
    a = __evrun(n[2], env);
    switch (n[1]) {
      case '-': return -a;
      case '+': return +a;
      case '!': return !a;
      case '~': return ~a;
      case 'typeof': return typeof a;
      default: return undefined;
    }
  }
  if (t === 'lg') {
    a = __evrun(n[2], env);
    if (n[1] === '&&') return a ? __evrun(n[3], env) : a;
    if (n[1] === '||') return a ? a : __evrun(n[3], env);
    return (a === null || a === undefined) ? __evrun(n[3], env) : a;
  }
  if (t === 'bin') {
    a = __evrun(n[2], env);
    b = __evrun(n[3], env);
    switch (n[1]) {
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
      case 'in': return a in b;
      default: return a instanceof b;
    }
  }
  if (t === 'mem') {
    o = __evrun(n[1], env);
    if (n[3] && (o === null || o === undefined)) return undefined;
    return o[__evrun(n[2], env)];
  }
  if (t === 'call') {
    args = [];
    for (i = 0; i < n[2].length; i++) args.push(__evrun(n[2][i], env));
    if (n[1][0] === 'mem') {
      o = __evrun(n[1][1], env);
      if (n[1][3] && (o === null || o === undefined)) return undefined;
      f = o[__evrun(n[1][2], env)];
      if (n[3] && (f === null || f === undefined)) return undefined;
      return f.apply(o, args);
    }
    f = __evrun(n[1], env);
    if (n[3] && (f === null || f === undefined)) return undefined;
    return f.apply(undefined, args);
  }
  throw new SyntaxError('eval: unsupported expression');
}
function __eval(x) {
  if (typeof x !== 'string') return x;
  var env = {
    Math: function () { return Math; }, JSON: function () { return JSON; }, Number: function () { return Number; },
    String: function () { return String; }, Array: function () { return Array; }, Object: function () { return Object; },
    Boolean: function () { return Boolean; }, parseInt: function () { return parseInt; }, parseFloat: function () { return parseFloat; },
    isNaN: function () { return isNaN; }, isFinite: function () { return isFinite; }, Date: function () { return __Date; },
    Map: function () { return __Map; }, Set: function () { return __Set; }, BigInt: function () { return __BigInt; }
  };
  var list = __evparse(__evtok(x)), r, i;
  for (i = 0; i < list.length; i++) r = __evrun(list[i], env);
  return r;
}
