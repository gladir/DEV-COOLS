function __i_isId(k) {
  if (k.length === 0) return false;
  for (var i = 0; i < k.length; i++) {
    var c = k.charCodeAt(i);
    if (!((c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c === 95 || (i > 0 && c >= 48 && c <= 57))) return false;
  }
  return true;
}
function __i_hex2(c) {
  var h = '0123456789ABCDEF';
  return '\\x' + h[(c >> 4) & 15] + h[c & 15];
}
function __i_quote(s) {
  var q = "'";
  if (s.indexOf("'") !== -1) {
    if (s.indexOf('"') === -1) q = '"';
    else if (s.indexOf('`') === -1 && s.indexOf('${') === -1) q = '`';
  }
  var out = q;
  for (var i = 0; i < s.length; i++) {
    var ch = s[i];
    var c = s.charCodeAt(i);
    if (ch === q || ch === '\\') out += '\\' + ch;
    else if (c === 10) out += '\\n';
    else if (c === 9) out += '\\t';
    else if (c === 13) out += '\\r';
    else if (c === 8) out += '\\b';
    else if (c === 12) out += '\\f';
    else if (c === 11) out += '\\v';
    else if (c < 32 || c === 127) out += __i_hex2(c);
    else if (c >= 55296 && c <= 57343) {
      var d = i + 1 < s.length ? s.charCodeAt(i + 1) : 0;
      if (c <= 56319 && d >= 56320 && d <= 57343) { out += ch + s[i + 1]; i++; }
      else out += '\\u' + c.toString(16);
    }
    else out += ch;
  }
  return out + q;
}
function __i_qstr(s, ctx) {
  if (s.length > 16 && s.length > 76 - ctx.ind && s.indexOf('\n') !== -1) {
    var parts = [];
    var st = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] === '\n') {
        parts.push(__i_quote(s.slice(st, i + 1)));
        st = i + 1;
      }
    }
    if (st < s.length) parts.push(__i_quote(s.slice(st)));
    return parts.join(' +\n' + ' '.repeat(ctx.ind + 2));
  }
  return __i_quote(s);
}
function __fnm(f) {
  var n = f.name;
  return typeof n === 'string' ? n : __fname(f);
}
function __i_cname(o) {
  var p = Object.getPrototypeOf(o);
  if (p === null) return null;
  while (p !== null) {
    if (p.hasOwnProperty('constructor')) {
      var c = p.constructor;
      if (typeof c === 'function') {
        var n = __fnm(c);
        if (n !== '') return n;
      }
    }
    if (p === Object.prototype) return 'Object';
    p = Object.getPrototypeOf(p);
  }
  return 'Object';
}
function __i_fnbase(f) {
  var fl = __fflags(f);
  var nm = __fnm(f);
  if (fl & 16) {
    var s = '[class ' + (nm === '' ? '(anonymous)' : nm);
    var par = __fparent(f);
    if (typeof par === 'function') s += ' extends ' + __fnm(par);
    return s + ']';
  }
  var kind = 'Function';
  if (fl & 2) kind = (fl & 4) ? 'AsyncGeneratorFunction' : 'AsyncFunction';
  else if (fl & 4) kind = 'GeneratorFunction';
  return '[' + kind + (nm === '' ? ' (anonymous)' : ': ' + nm) + ']';
}
function __i_errbase(e, ctx) {
  var st = e.stack;
  var s = (typeof st === 'string' && st !== '') ? st : String(e);
  if (s.indexOf('\n    at') === -1) s = '[' + s + ']';
  if (ctx.ind > 0) s = s.split('\n').join('\n' + ' '.repeat(ctx.ind));
  return s;
}
function __i_isBelow(out, start, base) {
  var total = out.length + start;
  if (total + out.length > 80) return false;
  for (var i = 0; i < out.length; i++) {
    total += out[i].length;
    if (total > 80) return false;
  }
  return base === '' || base.indexOf('\n') === -1;
}
function __i_group(ctx, out, value) {
  var total = 0;
  var maxLen = 0;
  var i;
  var outLen = out.length;
  if (out.length > 100 && value.length > 100) outLen--;
  var dataLen = [];
  for (i = 0; i < outLen; i++) {
    var len = out[i].length;
    dataLen.push(len);
    total += len + 2;
    if (maxLen < len) maxLen = len;
  }
  var actualMax = maxLen + 2;
  if (actualMax * 3 + ctx.ind < 80 && (total / actualMax > 5 || maxLen <= 6)) {
    var averageBias = Math.sqrt(actualMax - total / out.length);
    var biasedMax = Math.max(actualMax - 3 - averageBias, 1);
    var columns = Math.min(
      Math.round(Math.sqrt(2.5 * biasedMax * outLen) / biasedMax),
      Math.floor((80 - ctx.ind) / actualMax),
      12,
      15);
    if (columns <= 1) return out;
    var tmp = [];
    var maxLine = [];
    for (i = 0; i < columns; i++) {
      var lineLen = 0;
      for (var j = i; j < out.length; j += columns) {
        if (dataLen[j] > lineLen) lineLen = dataLen[j];
      }
      maxLine.push(lineLen + 2);
    }
    var padStart = true;
    for (i = 0; i < out.length; i++) {
      if (typeof value[i] !== 'number') {
        padStart = false;
        break;
      }
    }
    for (i = 0; i < outLen; i += columns) {
      var max = Math.min(i + columns, outLen);
      var str = '';
      var k = i;
      for (; k < max - 1; k++) {
        var cell = out[k] + ', ';
        str += padStart ? cell.padStart(maxLine[k - i], ' ') : cell.padEnd(maxLine[k - i], ' ');
      }
      if (padStart) str += out[k].padStart(maxLine[k - i] - 2, ' ');
      else str += out[k];
      tmp.push(str);
    }
    if (outLen < out.length) tmp.push(out[outLen]);
    out = tmp;
  }
  return out;
}
function __i_reduce(out, base, b0, b1, isArr, rt, ctx, value) {
  var entries = out.length;
  if (isArr && entries > 6) out = __i_group(ctx, out, value);
  if (ctx.cur - rt < 3 && entries === out.length) {
    var start = out.length + ctx.ind + b0.length + base.length + 10;
    if (__i_isBelow(out, start, base)) {
      var joined = out.join(', ');
      if (joined.indexOf('\n') === -1) {
        return (base !== '' ? base + ' ' : '') + b0 + ' ' + joined + ' ' + b1;
      }
    }
  }
  var ind = '\n' + ' '.repeat(ctx.ind);
  return (base !== '' ? base + ' ' : '') + b0 + ind + '  ' + out.join(',' + ind + '  ') + ind + b1;
}
function __i_order(keys) {
  var ints = [];
  var rest = [];
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i];
    var ok = k.length > 0 && k.length < 10 && (k.length === 1 || k.charCodeAt(0) !== 48);
    for (var j = 0; ok && j < k.length; j++) {
      var c = k.charCodeAt(j);
      if (c < 48 || c > 57) ok = false;
    }
    if (ok) ints.push(k);
    else rest.push(k);
  }
  if (ints.length === 0) return keys;
  ints.sort(function (a, b) { return Number(a) - Number(b); });
  return ints.concat(rest);
}
function __i_prop(v, k, ctx, rt) {
  var a = __acc(v, k);
  var s;
  if (a !== 0) s = a === 1 ? '[Getter]' : (a === 2 ? '[Setter]' : '[Getter/Setter]');
  else {
    ctx.ind += 2;
    s = __i_fmt(v[k], ctx, rt);
    ctx.ind -= 2;
  }
  return (__i_isId(k) ? k : __i_quote(k)) + ': ' + s;
}
function __i_bytes(v, off, n, max) {
  var parts = [], i, lim = n > max ? max : n, h;
  for (i = 0; i < lim; i++) {
    h = __abget(v, off + i, 1, false).toString(16);
    parts.push(h.length < 2 ? '0' + h : h);
  }
  h = parts.join(' ');
  if (n > lim) h += ' ... ' + (n - lim) + ' more byte' + (n - lim > 1 ? 's' : '');
  return h;
}
function __i_raw(v, ctx, rt) {
  var isFn = typeof v === 'function';
  var ti = isFn ? 0 : __tainfo(v, 5);
  var cname0, tabuf;
  if (ti === 1) {
    cname0 = __i_cname(v);
    if (cname0 === 'Buffer') {
      tabuf = __tainfo(v, 0);
      return '<Buffer' + (v.length === 0 ? '' : ' ' + __i_bytes(tabuf, __tainfo(v, 1), v.length, 50)) + '>';
    }
  }
  var isArr = Array.isArray(v) || ti === 1;
  var isRx = !isFn && !isArr && v instanceof RegExp;
  var isErr = !isFn && !isArr && !isRx && v instanceof Error;
  var isMap = !isFn && !isArr && !isRx && !isErr && v instanceof __Map;
  var isSet = !isFn && !isArr && !isRx && !isErr && !isMap && v instanceof __Set;
  var isWeak = !isFn && !isArr && (v instanceof __WeakMap || v instanceof __WeakSet);
  var isDate = !isFn && !isArr && v instanceof __Date;
  var isProm = !isFn && !isArr && v instanceof __Promise;
  var cname = ti === 1 ? cname0 : (isArr ? 'Array' : __i_cname(v));
  var ex = isArr && ti !== 1 ? __extras(v) : undefined;
  var keys = isArr ? (ex ? Object.keys(ex) : []) : __i_order(Object.keys(v));
  var base = '';
  var b0 = '{';
  var b1 = '}';
  if (ti === 2) {
    b0 = cname + ' {';
    if (rt > ctx.depth) return '[' + cname + ']';
    return b0 + ' [Uint8Contents]: <' + __i_bytes(v, 0, v.byteLength, 50) + '>, byteLength: ' + v.byteLength + ' }';
  } else if (isArr) {
    b0 = ti === 1 ? cname + '(' + v.length + ') [' : '[';
    b1 = ']';
    if (v.length === 0 && keys.length === 0) return ti === 1 ? b0 + ']' : '[]';
  } else if (isFn) {
    base = __i_fnbase(v);
    if (keys.length === 0) return base;
  } else if (isRx) {
    base = String(v);
    if (keys.length === 0) return base;
  } else if (isErr) {
    base = __i_errbase(v, ctx);
    if (keys.length === 0) return base;
  } else if (isMap || isSet) {
    b0 = cname + '(' + v['\x01n'] + ') {';
    if (keys.length === 0 && v['\x01n'] === 0) return b0 + '}';
  } else if (isWeak) {
    return cname + ' { <items unknown> }';
  } else if (isDate) {
    base = v.getTime() !== v.getTime() ? 'Invalid Date' : v.toISOString();
    if (keys.length === 0) return base;
  } else if (isProm) {
    b0 = 'Promise {';
  } else {
    if (cname === null) b0 = '[Object: null prototype] {';
    else if (cname !== 'Object') b0 = cname + ' {';
    if (keys.length === 0) return b0 + '}';
  }
  if (rt > ctx.depth) return isArr && ti !== 1 ? '[Array]' : '[' + (cname || 'Object') + ']';
  rt += 1;
  ctx.seen.push(v);
  ctx.cur = rt;
  var out = [];
  var i;
  if (isArr) {
    var n = v.length;
    var lim = n > 100 ? 100 : n;
    for (i = 0; i < lim; i++) {
      ctx.ind += 2;
      out.push(__i_fmt(v[i], ctx, rt));
      ctx.ind -= 2;
    }
    if (n > lim) out.push('... ' + (n - lim) + ' more item' + (n - lim > 1 ? 's' : ''));
    for (i = 0; i < keys.length; i++) out.push(__i_prop(ex, keys[i], ctx, rt));
  } else {
    if (isMap || isSet) {
      var ks = v['\x01k'];
      for (i = 0; i < ks.length; i++) {
        if (ks[i] === __TOMB) continue;
        ctx.ind += 2;
        var e = __i_fmt(ks[i], ctx, rt);
        if (isMap) e += ' => ' + __i_fmt(v['\x01v'][i], ctx, rt);
        ctx.ind -= 2;
        out.push(e);
      }
    }
    if (isProm) {
      var ps = v['\x01s'];
      ctx.ind += 2;
      out.push(ps === 0 ? '<pending>' : ps === 1 ? __i_fmt(v['\x01v'], ctx, rt) : '<rejected> ' + __i_fmt(v['\x01v'], ctx, rt));
      ctx.ind -= 2;
    }
    for (i = 0; i < keys.length; i++) out.push(__i_prop(v, keys[i], ctx, rt));
  }
  ctx.seen.pop();
  var ci = ctx.circ.indexOf(v);
  if (ci !== -1) {
    var ref = '<ref *' + (ci + 1) + '>';
    base = base === '' ? ref : ref + ' ' + base;
  }
  return __i_reduce(out, base, b0, b1, isArr, rt, ctx, v);
}
function __i_fmt(v, ctx, rt) {
  var t = typeof v;
  if (t === 'string') return __i_qstr(v, ctx);
  if (t === 'symbol') return __sym_str(v);
  if (t === 'bigint') return String(v) + 'n';
  if (t === 'number') return (v === 0 && 1 / v < 0) ? '-0' : String(v);
  if (t !== 'object' && t !== 'function') return String(v);
  if (v === null) return 'null';
  if (ctx.seen.indexOf(v) !== -1) {
    var ix = ctx.circ.indexOf(v);
    if (ix === -1) {
      ctx.circ.push(v);
      ix = ctx.circ.length - 1;
    }
    return '[Circular *' + (ix + 1) + ']';
  }
  return __i_raw(v, ctx, rt);
}
function __i_insp(v, depth) {
  return __i_fmt(v, { seen: [], circ: [], ind: 0, cur: 0, depth: depth }, 0);
}
function __i_num(n) {
  return (n === 0 && 1 / n < 0) ? '-0' : String(n);
}
function __i_str1(v) {
  if (typeof v === 'number') return __i_num(v);
  if (typeof v === 'bigint') return String(v) + 'n';
  if (typeof v !== 'object' || v === null) return String(v);
  if (v.toString === Object.prototype.toString || Array.isArray(v) || v instanceof Error || v instanceof RegExp) return __i_insp(v, 0);
  return String(v);
}
function __i_args(a) {
  var n = a.length;
  if (n === 0) return '';
  var first = a[0];
  var i;
  if (typeof first !== 'string') {
    var parts = [];
    for (i = 0; i < n; i++) parts.push(typeof a[i] === 'string' ? a[i] : __i_insp(a[i], 2));
    return parts.join(' ');
  }
  if (n === 1) return first;
  var res = '';
  var last = 0;
  var ai = 1;
  for (i = 0; i < first.length - 1; i++) {
    if (first[i] !== '%') continue;
    var c = first[i + 1];
    if (c === '%') {
      res += first.slice(last, i) + '%';
      last = i + 2;
      i++;
      continue;
    }
    if (ai >= n) continue;
    var t = null;
    var x = a[ai];
    if (c === 's') t = __i_str1(x);
    else if (c === 'd') t = (typeof x === 'object' && x !== null) ? 'NaN' : __i_num(Number(x));
    else if (c === 'i') t = (typeof x === 'object' && x !== null) ? 'NaN' : __i_num(parseInt(x));
    else if (c === 'f') t = __i_num(parseFloat(x));
    else if (c === 'j') t = JSON.stringify(x);
    else if (c === 'o') t = __i_insp(x, 4);
    else if (c === 'O') t = __i_insp(x, 2);
    else if (c === 'c') t = '';
    if (t === null) continue;
    res += first.slice(last, i) + t;
    last = i + 2;
    i++;
    ai++;
  }
  res += first.slice(last);
  for (i = ai; i < n; i++) res += ' ' + (typeof a[i] === 'string' ? a[i] : __i_insp(a[i], 2));
  return res;
}
function __i_console(kind, ...a) {
  var g = __i_g;
  var fd = 1;
  var s;
  if (kind === 5) {
    if (g && g.length >= 2) __i_g = g.slice(2);
    __setgrp(__i_g ? 1 : 0);
    return;
  }
  if (kind === 1) fd = 2;
  if (kind === 2) s = __i_insp(a[0], 2);
  else if (kind === 3) {
    if (a[0]) return;
    a.shift();
    fd = 2;
    s = 'Assertion failed' + (a.length > 0 ? ': ' + __i_args(a) : '');
  } else s = __i_args(a);
  if (kind === 4 && a.length === 0) {
    __i_g = (g || '') + '  ';
    __setgrp(1);
    return;
  }
  if (g) s = g + s.split('\n').join('\n' + g);
  __write(fd, s + '\n');
  if (kind === 4) {
    __i_g = (g || '') + '  ';
    __setgrp(1);
  }
}
var __i_g;
