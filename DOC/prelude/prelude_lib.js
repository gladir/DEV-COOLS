var __Date, __AggregateError, __module, __exports, __performance, __t0, __cnt, __tmr;
var __DN, __MN;


function __days_from_civil(y, m, d) {
  y -= m <= 2 ? 1 : 0;
  var era = Math.floor(y / 400);
  var yoe = y - era * 400;
  var doy = Math.floor((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1;
  var doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe - 719468;
}
function __civil(z) {
  z += 719468;
  var era = Math.floor(z / 146097);
  var doe = z - era * 146097;
  var yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
  var y = yoe + era * 400;
  var doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  var mp = Math.floor((5 * doy + 2) / 153);
  var d = doy - Math.floor((153 * mp + 2) / 5) + 1;
  var m = mp + (mp < 10 ? 3 : -9);
  return [y + (m <= 2 ? 1 : 0), m, d];
}
function __mktime(y, mo, d, h, mi, s, ms) {
  var ym = y + Math.floor(mo / 12);
  var mn = mo - Math.floor(mo / 12) * 12;
  var days = __days_from_civil(ym, mn + 1, 1) + (d - 1);
  return days * 86400000 + h * 3600000 + mi * 60000 + s * 1000 + ms;
}
function __p2(n) { return n < 10 ? '0' + n : String(n); }
function __p3(n) { return n < 10 ? '00' + n : n < 100 ? '0' + n : String(n); }
function __dparts(t) {
  var days = Math.floor(t / 86400000);
  var rem = t - days * 86400000;
  var c = __civil(days);
  return {
    y: c[0], m: c[1] - 1, d: c[2],
    h: Math.floor(rem / 3600000), mi: Math.floor(rem / 60000) % 60,
    s: Math.floor(rem / 1000) % 60, ms: rem % 1000,
    wd: ((days % 7) + 11) % 7
  };
}
var __tzc;
function __tzinfo() {
  var ab, c, i, ch;
  if (__tzc !== undefined) return __tzc;
  ab = __abnew({}, 176);
  __k32(23, ab);
  c = { bias: __abget(ab, 0, 5, true), sb: __abget(ab, 84, 5, true), db: __abget(ab, 168, 5, true), dst: false, sn: '', dn: '', se: null, ds: null };
  for (i = 0; i < 32; i++) { ch = __abget(ab, 4 + 2 * i, 4, true); if (ch === 0) break; c.sn += String.fromCharCode(ch); }
  for (i = 0; i < 32; i++) { ch = __abget(ab, 88 + 2 * i, 4, true); if (ch === 0) break; c.dn += String.fromCharCode(ch); }
  if (__abget(ab, 70, 4, true) !== 0 && __abget(ab, 154, 4, true) !== 0) {
    c.dst = true;
    c.se = [__abget(ab, 70, 4, true), __abget(ab, 72, 4, true), __abget(ab, 74, 4, true), __abget(ab, 76, 4, true)];
    c.ds = [__abget(ab, 154, 4, true), __abget(ab, 156, 4, true), __abget(ab, 158, 4, true), __abget(ab, 160, 4, true)];
  }
  __tzc = c;
  return c;
}
function __tzTrans(y, d) {
  var first = __mktime(y, d[0] - 1, 1, 0, 0, 0, 0), dow0 = __dparts(first).wd, day = 1 + ((d[1] - dow0 + 7) % 7) + 7 * (d[2] - 1);
  var dim = __civil(__days_from_civil(d[0] === 12 ? y + 1 : y, d[0] === 12 ? 1 : d[0] + 1, 1) - 1)[2];
  if (day > dim) day -= 7;
  return __mktime(y, d[0] - 1, day, d[3], 0, 0, 0);
}
function __tzoff(t) {
  var c = __tzinfo(), so = -(c.bias + c.sb), dof, y, a, b;
  if (!c.dst) return so;
  dof = -(c.bias + c.db);
  y = __dparts(t + so * 60000).y;
  a = __tzTrans(y, c.ds) - so * 60000;
  b = __tzTrans(y, c.se) - dof * 60000;
  return (a < b ? (t >= a && t < b) : (t >= a || t < b)) ? dof : so;
}
function __loc2utc(l) {
  var c = __tzinfo(), o1 = __tzoff(l - (-(c.bias + c.sb)) * 60000), t = l - o1 * 60000, o2 = __tzoff(t);
  if (o2 !== o1) t = l - o2 * 60000;
  return t;
}
function __tzname(t) {
  var c = __tzinfo();
  return c.dst && __tzoff(t) === -(c.bias + c.db) ? c.dn : c.sn;
}
function __tzgmt(t) {
  var o = __tzoff(t), a = o < 0 ? -o : o;
  return 'GMT' + (o < 0 ? '-' : '+') + __p2(Math.floor(a / 60)) + __p2(a % 60);
}
function __dparse(str) {
  str = String(str).trim();
  var m = /^([+-]\d{6}|\d{4})(?:-(\d\d)(?:-(\d\d))?)?(?:[T ](\d\d):(\d\d)(?::(\d\d)(?:[.,](\d{1,9}))?)?)?\s*(Z|[+-]\d\d(?::?\d\d)?)?$/.exec(str);
  if (m) {
    var ms = m[7] ? Number((m[7] + '00').slice(0, 3)) : 0;
    var t = __mktime(Number(m[1]), m[2] ? m[2] - 1 : 0, m[3] ? Number(m[3]) : 1,
                     m[4] ? Number(m[4]) : 0, m[5] ? Number(m[5]) : 0, m[6] ? Number(m[6]) : 0, ms);
    var z = m[8];
    if (!z && m[4]) return __loc2utc(t);
    if (z && z !== 'Z') {
      var sign = z.charAt(0) === '-' ? -1 : 1;
      var hh = Number(z.slice(1, 3));
      var mm = z.length > 3 ? Number(z.slice(z.length - 2)) : 0;
      t -= sign * (hh * 60 + mm) * 60000;
    }
    return t;
  }
  var mon = -1;
  var low = str.toLowerCase();
  for (var i = 0; i < 12; i++) {
    if (low.indexOf(__MN[i].slice(0, 3).toLowerCase()) >= 0) { mon = i; break; }
  }
  var dm = /(\d{1,2})[ ,]+/.exec(str.replace(/^[A-Za-z]+,?\s+/, ''));
  var ym = /(\d{4})/.exec(str);
  if (mon >= 0 && ym) {
    var rest = str.replace(/^[A-Za-z]+,?\s*/, '');
    var dd = /\b(\d{1,2})\b/.exec(rest.replace(ym[1], ''));
    var tm = /(\d\d):(\d\d)(?::(\d\d))?/.exec(str);
    var off = /GMT([+-])(\d\d)(\d\d)/.exec(str);
    var tt = __mktime(Number(ym[1]), mon, dd ? Number(dd[1]) : 1,
                      tm ? Number(tm[1]) : 0, tm ? Number(tm[2]) : 0, tm && tm[3] ? Number(tm[3]) : 0, 0);
    if (/PM/i.test(str) && tm && Number(tm[1]) < 12) tt += 12 * 3600000;
    if (off) tt -= (off[1] === '-' ? -1 : 1) * (Number(off[2]) * 60 + Number(off[3])) * 60000;
    else if (!/\b(GMT|UTC|Z)\b/.test(str)) tt = __loc2utc(tt);
    return tt;
  }
  var sl = /^(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(str) || /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(str);
  if (sl) {
    if (sl[1].length === 4) return __loc2utc(__mktime(Number(sl[1]), sl[2] - 1, Number(sl[3]), 0, 0, 0, 0));
    return __loc2utc(__mktime(Number(sl[3]), sl[1] - 1, Number(sl[2]), 0, 0, 0, 0));
  }
  return NaN;
}
function __now() {
  var lo = __ftime(0);
  var hi = __ftime(1);
  if (lo < 0) lo += 4294967296;
  if (hi < 0) hi += 4294967296;
  return Math.floor((hi * 4294967296 + lo) / 10000 - 11644473600000);
}
function __jsonwalk(reviver, holder, key) {
  var val = holder[key], i, k, nv, ks;
  if (val !== null && typeof val === 'object') {
    if (Array.isArray(val)) {
      for (i = 0; i < val.length; i++) {
        nv = __jsonwalk(reviver, val, i);
        if (nv === undefined) delete val[i]; else val[i] = nv;
      }
    } else {
      ks = Object.keys(val);
      for (i = 0; i < ks.length; i++) {
        k = ks[i];
        nv = __jsonwalk(reviver, val, k);
        if (nv === undefined) delete val[k]; else val[k] = nv;
      }
    }
  }
  return reviver.call(holder, typeof key === 'number' ? String(key) : key, val);
}
var __jsonSlow;
function __jsonser(st, holder, key, indent) {
  var value = holder[key], parts = [], i, k, ks, s, inner, t;
  if (value !== null && (typeof value === 'object' || typeof value === 'bigint') && typeof value.toJSON === 'function') {
    value = value.toJSON(typeof key === 'number' ? String(key) : key);
  }
  if (st.rep !== null) value = st.rep.call(holder, typeof key === 'number' ? String(key) : key, value);
  t = typeof value;
  if (value === null) return 'null';
  if (t === 'boolean') return value ? 'true' : 'false';
  if (t === 'string') return st.native(value);
  if (t === 'number') return isFinite(value) ? String(value) : 'null';
  if (t === 'bigint') throw new TypeError('Do not know how to serialize a BigInt');
  if (t !== 'object') return undefined;
  if (st.stack.indexOf(value) >= 0) throw new TypeError('Converting circular structure to JSON');
  st.stack.push(value);
  inner = indent + st.gap;
  if (Array.isArray(value)) {
    for (i = 0; i < value.length; i++) {
      s = __jsonser(st, value, i, inner);
      parts.push(s === undefined ? 'null' : s);
    }
    st.stack.pop();
    if (parts.length === 0) return '[]';
    return st.gap === '' ? '[' + parts.join(',') + ']' : '[\n' + inner + parts.join(',\n' + inner) + '\n' + indent + ']';
  }
  ks = st.plist !== null ? st.plist : Object.keys(value);
  for (i = 0; i < ks.length; i++) {
    k = ks[i];
    if (st.plist !== null && !(k in value)) continue;
    s = __jsonser(st, value, k, inner);
    if (s !== undefined) parts.push(st.native(k) + (st.gap === '' ? ':' : ': ') + s);
  }
  st.stack.pop();
  if (parts.length === 0) return '{}';
  return st.gap === '' ? '{' + parts.join(',') + '}' : '{\n' + inner + parts.join(',\n' + inner) + '\n' + indent + '}';
}
function __toFixed(f) {
  var x = Number(this), neg = '', r, d, E, keep, t, a, i, n, ip, fp;
  f = f === undefined ? 0 : Math.floor(Number(f));
  if (f !== f) f = 0;
  if (f < 0 || f > 100) throw new RangeError('toFixed() digits argument must be between 0 and 100');
  if (x !== x) return 'NaN';
  if (x >= 1e21 || x <= -1e21) return String(x);
  if (x < 0) { neg = '-'; x = -x; }
  if (x === 0) {
    n = '0';
  } else {
    r = __exact(x);
    d = r[0];
    E = r[1];
    keep = E + 1 + f;
    if (keep < 0) n = '0';
    else if (keep >= d.length) { n = d; while (n.length < keep) n += '0'; }
    else {
      t = d.slice(0, keep);
      if (d.charCodeAt(keep) >= 53) {
        a = t.split('');
        i = keep - 1;
        while (i >= 0) {
          if (a[i] === '9') { a[i] = '0'; i--; }
          else { a[i] = String.fromCharCode(a[i].charCodeAt(0) + 1); break; }
        }
        t = a.join('');
        if (i < 0) t = '1' + t;
      }
      n = t === '' ? '0' : t;
    }
  }
  while (n.length < f + 1) n = '0' + n;
  ip = n.slice(0, n.length - f);
  fp = n.slice(n.length - f);
  ip = ip.replace(/^0+(?=\d)/, '');
  if (neg !== '' && /^0*$/.test(ip + fp)) neg = Number(this) < 0 ? '-' : '';
  return neg + ip + (f > 0 ? '.' + fp : '');
}

function __defm(o, name, fn) {
  Object.defineProperty(o, name, { value: fn, writable: true, configurable: true, enumerable: false });
}
function __flat(a, depth, out) {
  var i, v;
  for (i = 0; i < a.length; i++) {
    v = a[i];
    if (Array.isArray(v) && depth > 0) __flat(v, depth - 1, out);
    else out.push(v);
  }
  return out;
}
function __init_arr() {
  var AP = Array.prototype;
  __defm(AP, 'at', function (i) { i = Math.trunc(Number(i)) || 0; if (i < 0) i += this.length; return this[i]; });
  __defm(AP, 'reduceRight', function (f, init) {
    var i = this.length - 1, acc;
    if (arguments.length > 1) acc = init;
    else {
      if (i < 0) throw new TypeError('Reduce of empty array with no initial value');
      acc = this[i--];
    }
    for (; i >= 0; i--) acc = f(acc, this[i], i, this);
    return acc;
  });
  __defm(AP, 'findLast', function (f, t) { for (var i = this.length - 1; i >= 0; i--) if (f.call(t, this[i], i, this)) return this[i]; return undefined; });
  __defm(AP, 'findLastIndex', function (f, t) { for (var i = this.length - 1; i >= 0; i--) if (f.call(t, this[i], i, this)) return i; return -1; });
  __defm(AP, 'flat', function (d) { return __flat(this, d === undefined ? 1 : Number(d), []); });
  __defm(AP, 'flatMap', function (f, t) { return __flat(this.map(f, t), 1, []); });
  __defm(AP, 'keys', function () { var i = 0, a = this; return __mkiter(function () { return i < a.length ? { value: i++, done: false } : { value: undefined, done: true }; }); });
  __defm(AP, 'values', function () { var i = 0, a = this; return __mkiter(function () { return i < a.length ? { value: a[i++], done: false } : { value: undefined, done: true }; }); });
  __defm(AP, 'entries', function () { var i = 0, a = this; return __mkiter(function () { return i < a.length ? { value: [i, a[i++]], done: false } : { value: undefined, done: true }; }); });
  __defm(AP, 'copyWithin', function (target, start, end) {
    var n = this.length, to = target < 0 ? Math.max(n + target, 0) : Math.min(target, n), from = start < 0 ? Math.max(n + start, 0) : Math.min(start || 0, n);
    var fin = end === undefined ? n : (end < 0 ? Math.max(n + end, 0) : Math.min(end, n)), tmp = this.slice(from, fin), i;
    for (i = 0; i < tmp.length && to + i < n; i++) this[to + i] = tmp[i];
    return this;
  });
  __defm(AP, 'toReversed', function () { return this.slice().reverse(); });
  __defm(AP, 'toSorted', function (f) { return this.slice().sort(f); });
  __defm(AP, 'toSpliced', function () { var c = this.slice(); c.splice.apply(c, arguments); return c; });
  __defm(AP, 'with', function (i, v) {
    var c = this.slice();
    i = Math.trunc(Number(i)) || 0;
    if (i < 0) i += c.length;
    if (i < 0 || i >= c.length) throw new RangeError('Invalid index : ' + i);
    c[i] = v;
    return c;
  });
  Math.cbrt = function (x) { return x < 0 ? -Math.pow(-x, 1 / 3) : Math.pow(x, 1 / 3); };
  Math.sinh = function (x) { return (Math.exp(x) - Math.exp(-x)) / 2; };
  Math.cosh = function (x) { return (Math.exp(x) + Math.exp(-x)) / 2; };
  Math.tanh = function (x) { if (x === Infinity) return 1; if (x === -Infinity) return -1; var a = Math.exp(x), b = Math.exp(-x); return (a - b) / (a + b); };
  Math.asinh = function (x) { return x === -Infinity ? x : Math.log(x + Math.sqrt(x * x + 1)); };
  Math.acosh = function (x) { return Math.log(x + Math.sqrt(x * x - 1)); };
  Math.atanh = function (x) { return Math.log((1 + x) / (1 - x)) / 2; };
  Math.expm1 = function (x) { return Math.abs(x) < 1e-5 ? x + x * x / 2 + x * x * x / 6 : Math.exp(x) - 1; };
  Math.log1p = function (x) { return Math.abs(x) < 1e-5 ? x - x * x / 2 + x * x * x / 3 : Math.log(1 + x); };
  Math.clz32 = function (x) { x = x >>> 0; if (x === 0) return 32; var n = 0; while ((x & 2147483648) === 0) { x = x << 1; n++; } return n; };
  Math.fround = function (x) { return x; };
  Object.defineProperties = function (o, props) {
    var k;
    for (k in props) Object.defineProperty(o, k, props[k]);
    return o;
  };
}
var __Reflect, __WeakRef, __FinalizationRegistry, __frs;
function __isIdx(k) { return typeof k === 'string' && k !== '' && String(k >>> 0) === k && (k >>> 0) !== 4294967295; }
function __ownDesc(o, k) {
  var pi, fl, d, fr, n;
  if (o === null || o === undefined) throw new TypeError('Cannot convert undefined or null to object');
  k = String(k);
  fr = typeof o === 'object' || typeof o === 'function' ? (__oflags(o) & 2) !== 0 : true;
  if (typeof o === 'string') {
    if (k === 'length') return { value: o.length, writable: false, enumerable: false, configurable: false };
    if (__isIdx(k) && Number(k) < o.length) return { value: o.charAt(Number(k)), writable: false, enumerable: true, configurable: false };
    return undefined;
  }
  if (typeof o !== 'object' && typeof o !== 'function') return undefined;
  if (Array.isArray(o)) {
    if (k === 'length') return { value: o.length, writable: !fr, enumerable: false, configurable: false };
    if (__isIdx(k)) {
      n = Number(k);
      if (n < o.length) return { value: o[n], writable: !fr, enumerable: true, configurable: !fr };
      return undefined;
    }
  }
  pi = __propinfo(o, k);
  if (pi === undefined) {
    if (typeof o === 'function') {
      if (k === 'name') return { value: o.name, writable: false, enumerable: false, configurable: true };
      if (k === 'length') return { value: o.length, writable: false, enumerable: false, configurable: true };
    }
    return undefined;
  }
  fl = pi[0];
  d = {};
  if ((fl & 2) !== 0) { d.get = pi[1]; d.set = pi[2]; }
  else { d.value = pi[1]; d.writable = (fl & 4) === 0 && !fr; }
  d.enumerable = (fl & 1) === 0;
  d.configurable = !fr && (fl & 8) === 0 && (__oflags(o) & 16) === 0;
  return d;
}
function __objToString() {
  var t = this, tag;
  if (t === undefined) return '[object Undefined]';
  if (t === null) return '[object Null]';
  tag = t['\x01Symbol.toStringTag\x02'];
  if (typeof tag === 'string' && (typeof t === 'object' || typeof t === 'function')) return '[object ' + tag + ']';
  if (Array.isArray(t)) return '[object Array]';
  switch (typeof t) {
    case 'function': return '[object Function]';
    case 'symbol': return '[object Symbol]';
    case 'string': return t.charCodeAt(0) === 1 ? '[object Symbol]' : '[object String]';
    case 'number': return '[object Number]';
    case 'boolean': return '[object Boolean]';
    case 'bigint': return '[object BigInt]';
  }
  if (t instanceof Error) return '[object Error]';
  if (t instanceof RegExp) return '[object RegExp]';
  if (t instanceof Date) return '[object Date]';
  return '[object Object]';
}
function __init_obj() {
  Object.defineProperty(Object.prototype, 'toString', { value: __objToString, writable: true, configurable: true, enumerable: false });
  Object.getOwnPropertyDescriptor = __ownDesc;
  Object.getOwnPropertyDescriptors = function (o) {
    var r = {}, ks = Object.getOwnPropertyNames(o), i;
    for (i = 0; i < ks.length; i++) r[ks[i]] = __ownDesc(o, ks[i]);
    return r;
  };
  Object.preventExtensions = function (o) { if (o !== null && (typeof o === 'object' || typeof o === 'function')) __oflags(o, 8); return o; };
  Object.seal = function (o) { if (o !== null && (typeof o === 'object' || typeof o === 'function')) __oflags(o, 24); return o; };
  Object.isExtensible = function (o) { return (typeof o === 'object' && o !== null || typeof o === 'function') && (__oflags(o) & 26) === 0; };
  Object.isSealed = function (o) { return !(typeof o === 'object' && o !== null || typeof o === 'function') || (__oflags(o) & 18) !== 0; };
}
function __init_globals() {
  var gt = globalThis;
  gt.Map = Map; gt.Set = Set; gt.WeakMap = WeakMap; gt.WeakSet = WeakSet; gt.Symbol = Symbol; gt.Date = Date; gt.Promise = Promise; gt.BigInt = BigInt;
  gt.setTimeout = setTimeout; gt.setInterval = setInterval; gt.setImmediate = setImmediate; gt.clearTimeout = clearTimeout; gt.clearInterval = clearInterval;
  gt.clearImmediate = clearImmediate; gt.queueMicrotask = queueMicrotask; gt.structuredClone = structuredClone; gt.AggregateError = AggregateError;
  gt.btoa = __btoa; gt.atob = __atob;
  gt.performance = performance; gt.encodeURIComponent = encodeURIComponent; gt.decodeURIComponent = decodeURIComponent; gt.encodeURI = encodeURI; gt.decodeURI = decodeURI;
  __WeakRef = class WeakRef {
    constructor(t) {
      if (t === null || (typeof t !== 'object' && typeof t !== 'function')) throw new TypeError('WeakRef: invalid target');
      var c = __wcell(t);
      if (c === undefined) c = { v: t };
      Object.defineProperty(this, '\x01c', { value: c, writable: true, enumerable: false });
    }
    deref() {
      var c = this['\x01c'];
      return typeof c === 'number' ? __wget(c) : c.v;
    }
  };
  __FinalizationRegistry = class FinalizationRegistry {
    constructor(cb) {
      if (typeof cb !== 'function') throw new TypeError('FinalizationRegistry: cleanup must be callable');
      Object.defineProperty(this, '\x01cb', { value: cb, enumerable: false });
      Object.defineProperty(this, '\x01e', { value: [], enumerable: false });
      __frs = __frs || [];
      __frs.push(this);
    }
    register(target, held, token) {
      if (target === null || (typeof target !== 'object' && typeof target !== 'function')) throw new TypeError('FinalizationRegistry.prototype.register: invalid target');
      if (target === held) throw new TypeError('FinalizationRegistry.prototype.register: target and holdings must not be same');
      var c = __wcell(target);
      if (c !== undefined) this['\x01e'].push({ c: c, h: held, t: token });
    }
    unregister(token) {
      var l = this['\x01e'], n = 0;
      for (var i = l.length - 1; i >= 0; i--) {
        if (token !== undefined && l[i].t === token) { l.splice(i, 1); n++; }
      }
      return n > 0;
    }
  };
  __global = gt;
  gt.global = gt;
  __Reflect = __mkReflect();
  gt.Reflect = __Reflect;
  gt.WeakRef = __WeakRef;
  gt.FinalizationRegistry = __FinalizationRegistry;
  __tagOf(Set.prototype, 'Set'); __tagOf(WeakMap.prototype, 'WeakMap'); __tagOf(WeakSet.prototype, 'WeakSet'); __tagOf(__WeakRef.prototype, 'WeakRef');
  __tagOf(__GenProto, 'Generator'); __tagOf(__AsyncGenProto, 'AsyncGenerator');
  __tagOf(Math, 'Math'); __tagOf(JSON, 'JSON'); __tagOf(__Reflect, 'Reflect'); __tagOf(BigInt.prototype, 'BigInt');
}
function __tagOf(o, n) { Object.defineProperty(o, '\x01Symbol.toStringTag\x02', { value: n, enumerable: false, configurable: true }); }
function __mkReflect() {
  var R = {};
  R.apply = function (f, t, a) { return f.apply(t, a); };
  R.construct = function (F, a, nt) {
    if (typeof F !== 'function') throw new TypeError(String(F) + ' is not a constructor');
    var o = new F(...a);
    if (nt !== undefined && nt !== F && o !== null && typeof o === 'object') Object.setPrototypeOf(o, nt.prototype);
    return o;
  };
  R.defineProperty = function (o, k, d) { try { Object.defineProperty(o, k, d); return true; } catch (e) { return false; } };
  R.deleteProperty = function (o, k) { return delete o[k]; };
  R.get = function (o, k, r) {
    var pi = o !== null && typeof o === 'object' ? __propinfo(o, String(k)) : undefined;
    if (pi !== undefined && (pi[0] & 2) !== 0) return pi[1] === undefined ? undefined : pi[1].call(r === undefined ? o : r);
    return o[k];
  };
  R.getOwnPropertyDescriptor = __ownDesc;
  R.getPrototypeOf = function (o) { return Object.getPrototypeOf(o); };
  R.has = function (o, k) { return k in o; };
  R.isExtensible = function (o) { return Object.isExtensible(o); };
  R.ownKeys = function (o) { return Object.getOwnPropertyNames(o).concat(Object.getOwnPropertySymbols(o)); };
  R.preventExtensions = function (o) { Object.preventExtensions(o); return true; };
  R.set = function (o, k, v, r) {
    var pi = typeof o === 'object' && o !== null ? __propinfo(o, String(k)) : undefined;
    if (pi !== undefined && (pi[0] & 2) !== 0) { if (pi[2] === undefined) return false; pi[2].call(r === undefined ? o : r, v); return true; }
    if (pi !== undefined && ((pi[0] & 4) !== 0)) return false;
    if (Object.isFrozen(o)) return false;
    o[k] = v;
    return true;
  };
  R.setPrototypeOf = function (o, p) { Object.setPrototypeOf(o, p); return true; };
  return R;
}
var __DOMException;
function __domEx(m, n) {
  if (__DOMException) return new __DOMException(m, n);
  var e = new Error(m);
  e.name = n;
  return e;
}
function __btoa(s) {
  var tbl = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', out = '', i, a, b, c, n;
  s = String(s);
  for (i = 0; i < s.length; i++) if (s.charCodeAt(i) > 255) throw __domEx('Invalid character', 'InvalidCharacterError');
  for (i = 0; i < s.length; i += 3) {
    a = s.charCodeAt(i); b = i + 1 < s.length ? s.charCodeAt(i + 1) : -1; c = i + 2 < s.length ? s.charCodeAt(i + 2) : -1;
    n = (a << 16) | ((b < 0 ? 0 : b) << 8) | (c < 0 ? 0 : c);
    out += tbl.charAt((n >> 18) & 63) + tbl.charAt((n >> 12) & 63) + (b < 0 ? '=' : tbl.charAt((n >> 6) & 63)) + (c < 0 ? '=' : tbl.charAt(n & 63));
  }
  return out;
}
function __atob(s) {
  var tbl = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', out = '', i, v, bits = 0, acc = 0, ch;
  s = String(s).replace(/[\t\n\f\r ]/g, '');
  if (s.length % 4 === 0) s = s.replace(/==?$/, '');
  if (s.length % 4 === 1 || /[^A-Za-z0-9+\/]/.test(s)) throw __domEx('The string to be decoded is not correctly encoded.', 'InvalidCharacterError');
  for (i = 0; i < s.length; i++) {
    v = tbl.indexOf(s.charAt(i));
    acc = (acc << 6) | v; bits += 6;
    if (bits >= 8) { bits -= 8; ch = (acc >> bits) & 255; out += String.fromCharCode(ch); }
  }
  return out;
}
function __init_lib() {
  __init_arr();
  __init_obj();
  var rma = String.prototype.matchAll;
  String.prototype.matchAll = function (re) {
    if (re instanceof RegExp && re.flags.indexOf('g') < 0) throw new TypeError('String.prototype.matchAll called with a non-global RegExp argument');
    var arr = rma.call(this, re), i = 0;
    return __mkiter(function () {
      if (i >= arr.length) return { value: undefined, done: true };
      return { value: arr[i++], done: false };
    });
  };
  Number.prototype.toFixed = __toFixed;
  var jparse = JSON.parse, jstr = JSON.stringify;
  JSON.parse = function (text, reviver) {
    var v = jparse(text);
    if (typeof reviver !== 'function') return v;
    return __jsonwalk(reviver, { '': v }, '');
  };
  JSON.stringify = function (value, replacer, space) {
    var plist = null, rep = null, gap = '', i, k, seen, st;
    if (typeof replacer === 'function') rep = replacer;
    else if (Array.isArray(replacer)) {
      plist = [];
      seen = {};
      for (i = 0; i < replacer.length; i++) {
        k = replacer[i];
        if (typeof k === 'number') k = String(k);
        if (typeof k === 'string' && !seen[k]) { seen[k] = true; plist.push(k); }
      }
    }
    if (rep === null && plist === null && !__jsonSlow) return jstr(value, undefined, space);
    if (typeof space === 'number') { for (i = 0; i < Math.min(10, space); i++) gap += ' '; }
    else if (typeof space === 'string') gap = space.slice(0, 10);
    st = { rep: rep, plist: plist, gap: gap, stack: [], native: function (x) { return jstr(x); } };
    return __jsonser(st, { '': value }, '', '');
  };
  __require.cache = {};
  __require.resolve = function (n) { return String(n); };
  if (!String.prototype.substr) {
    String.prototype.substr = function (st, len) {
      var n = this.length;
      st = Number(st) || 0;
      if (st < 0) st = Math.max(n + st, 0);
      if (len === undefined) len = n - st;
      return this.slice(st, st + Math.max(0, Number(len)));
    };
  }
  Object.is = __is;
  if (!Object.getOwnPropertyNames) Object.getOwnPropertyNames = Object.keys;
  Object.getOwnPropertySymbols = function (o) { return __ownall(o).filter(function (k) { return typeof k === 'symbol' && k.indexOf('\x02') > 0; }); };
  String.raw = function (s, ...v) {
    var r = s.raw, out = '';
    for (var i = 0; i < r.length; i++) {
      out += r[i];
      if (i + 1 < r.length && i < v.length) out += v[i];
    }
    return out;
  };
  Number.prototype.toPrecision = __toPrecision;
  Number.prototype.toExponential = __toExponential;
  __DN = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  __MN = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  var TT = '\x01t';
  __Date = function Date(a, b, c, d, e, f, g) {
    if (!(this instanceof __Date)) return new __Date().toString();
    var n = arguments.length;
    var t;
    if (n === 0) t = __now();
    else if (n === 1) {
      if (a instanceof __Date) t = a[TT];
      else if (typeof a === 'string') t = __dparse(a);
      else t = Number(a);
    } else {
      var yy = Number(a);
      if (yy >= 0 && yy <= 99) yy += 1900;
      t = __mktime(yy, Number(b), c === undefined ? 1 : Number(c), d === undefined ? 0 : Number(d),
                   e === undefined ? 0 : Number(e), f === undefined ? 0 : Number(f), g === undefined ? 0 : Number(g));
      t = __loc2utc(t);
    }
    if (!(Math.abs(t) <= 8.64e15)) t = NaN;
    else t = Math.trunc(t);
    this[TT] = t;
  };
  var P = __Date.prototype;
  __Date.now = __now;
  __Date.parse = function (s) { return __dparse(s); };
  __Date.UTC = function (y, mo, d, h, mi, s, ms) {
    return __mktime(Number(y), mo === undefined ? 0 : Number(mo), d === undefined ? 1 : Number(d),
                    h === undefined ? 0 : Number(h), mi === undefined ? 0 : Number(mi),
                    s === undefined ? 0 : Number(s), ms === undefined ? 0 : Number(ms));
  };
  var comps = ['y', 'm', 'd', 'h', 'mi', 's', 'ms'];
  var getters = { FullYear: 'y', Month: 'm', Date: 'd', Hours: 'h', Minutes: 'mi', Seconds: 's', Milliseconds: 'ms', Day: 'wd' };
  Object.keys(getters).forEach(function (k) {
    var comp = getters[k];
    P['getUTC' + k] = function () {
      var t = this[TT];
      return t !== t ? NaN : __dparts(t)[comp];
    };
    P['get' + k] = function () {
      var t = this[TT];
      return t !== t ? NaN : __dparts(t + __tzoff(t) * 60000)[comp];
    };
  });
  var setters = { FullYear: [0, 'y'], Month: [1, 'm'], Date: [2, 'd'], Hours: [3, 'h'], Minutes: [4, 'mi'], Seconds: [5, 's'], Milliseconds: [6, 'ms'] };
  Object.keys(setters).forEach(function (k) {
    var idx = setters[k][0];
    var mk = function (loc) {
      return function (...args) {
        var t = this[TT];
        if (t !== t) {
          if (idx !== 0) return NaN;
          t = 0;
        }
        var p = __dparts(loc ? t + __tzoff(t) * 60000 : t);
        var v = [p.y, p.m, p.d, p.h, p.mi, p.s, p.ms];
        for (var i = 0; i < args.length && idx + i < 7; i++) v[idx + i] = Number(args[i]);
        t = __mktime(v[0], v[1], v[2], v[3], v[4], v[5], v[6]);
        this[TT] = loc ? __loc2utc(t) : t;
        return this[TT];
      };
    };
    P['set' + k] = mk(true);
    P['setUTC' + k] = mk(false);
  });
  P.getTime = P.valueOf = function () { return this[TT]; };
  P.setTime = function (t) { this[TT] = Number(t); return this[TT]; };
  P.getYear = function () { return this.getFullYear() - 1900; };
  P.getTimezoneOffset = function () { return this[TT] !== this[TT] ? NaN : -__tzoff(this[TT]) + 0; };
  P.toISOString = function () {
    var t = this[TT];
    if (t !== t) throw new RangeError('Invalid time value');
    var p = __dparts(t);
    var ys = p.y >= 0 && p.y <= 9999 ? (p.y < 1000 ? ('000' + p.y).slice(-4) : String(p.y)) : (p.y < 0 ? '-' : '+') + ('000000' + Math.abs(p.y)).slice(-6);
    return ys + '-' + __p2(p.m + 1) + '-' + __p2(p.d) + 'T' + __p2(p.h) + ':' + __p2(p.mi) + ':' + __p2(p.s) + '.' + __p3(p.ms) + 'Z';
  };
  P.toJSON = function () { return this[TT] !== this[TT] ? null : this.toISOString(); };
  P.toDateString = function () {
    var t = this[TT];
    if (t !== t) return 'Invalid Date';
    var p = __dparts(t + __tzoff(t) * 60000);
    return __DN[p.wd].slice(0, 3) + ' ' + __MN[p.m].slice(0, 3) + ' ' + __p2(p.d) + ' ' + (p.y < 1000 ? ('000' + p.y).slice(-4) : p.y);
  };
  P.toTimeString = function () {
    var t = this[TT];
    if (t !== t) return 'Invalid Date';
    var p = __dparts(t + __tzoff(t) * 60000);
    return __p2(p.h) + ':' + __p2(p.mi) + ':' + __p2(p.s) + ' ' + __tzgmt(t) + ' (' + (__tzoff(t) === 0 && __tzinfo().sn === '' ? 'Coordinated Universal Time' : __tzname(t)) + ')';
  };
  P.toString = function () {
    return this[TT] !== this[TT] ? 'Invalid Date' : this.toDateString() + ' ' + this.toTimeString();
  };
  P.toUTCString = P.toGMTString = function () {
    var t = this[TT];
    if (t !== t) return 'Invalid Date';
    var p = __dparts(t);
    return __DN[p.wd].slice(0, 3) + ', ' + __p2(p.d) + ' ' + __MN[p.m].slice(0, 3) + ' ' + p.y + ' ' + __p2(p.h) + ':' + __p2(p.mi) + ':' + __p2(p.s) + ' GMT';
  };
  P.toLocaleDateString = function (loc, o) {
    var t = this[TT], r;
    if (t !== t) return 'Invalid Date';
    r = __intlDate(t, loc, o, 1);
    if (r !== null) return r;
    var p = __dparts(t + __tzoff(t) * 60000);
    if (o && (o.month === 'long' || o.month === 'short')) {
      var mn = o.month === 'long' ? __MN[p.m] : __MN[p.m].slice(0, 3);
      var s = mn + ' ' + p.d + ', ' + p.y;
      if (o.weekday) s = (o.weekday === 'long' ? __DN[p.wd] : __DN[p.wd].slice(0, 3)) + ', ' + s;
      return s;
    }
    return (p.m + 1) + '/' + p.d + '/' + p.y;
  };
  P.toLocaleTimeString = function (loc, o) {
    var t = this[TT], r;
    if (t !== t) return 'Invalid Date';
    r = __intlDate(t, loc, o, 2);
    if (r !== null) return r;
    var p = __dparts(t + __tzoff(t) * 60000);
    return (p.h % 12 === 0 ? 12 : p.h % 12) + ':' + __p2(p.mi) + ':' + __p2(p.s) + ' ' + (p.h < 12 ? 'AM' : 'PM');
  };
  P.toLocaleString = function (loc, o) {
    var t = this[TT], r;
    if (t !== t) return 'Invalid Date';
    r = __intlDate(t, loc, o, 3);
    if (r !== null) return r;
    return this.toLocaleDateString(loc, o) + ', ' + this.toLocaleTimeString();
  };
  P['\x01Symbol.toPrimitive\x02'] = function (hint) { return hint === 'number' ? this[TT] : this.toString(); };
  __AggregateError = class AggregateError extends Error {
    constructor(errors, message) {
      super(message);
      this.name = 'AggregateError';
      this.errors = Array.from(errors);
    }
  };
  __t0 = __now();
  __performance = { now: function () { return __now() - __t0; }, timeOrigin: __t0 };
  __module = { id: '.', exports: {}, loaded: false, children: [], paths: [] };
  __exports = __module.exports;
  __require.main = __module;
  process.hrtime = function (prev) {
    var ms = __now() - __t0;
    var s = Math.floor(ms / 1000);
    var ns = Math.floor((ms % 1000) * 1000000);
    if (prev) { s -= prev[0]; ns -= prev[1]; if (ns < 0) { s--; ns += 1000000000; } }
    return [s, ns];
  };
  process.uptime = function () { return (__now() - __t0) / 1000; };
  process.cwd = function () { return 'C:\\'; };
  process.version = 'v20.0.0-jscw32';
  process.versions = { node: '20.0.0', jscw32: '1.0' };
  process.pid = 1;
  process.arch = 'ia32';
  process.exitCode = undefined;
  process.memoryUsage = function () { return { rss: 0, heapTotal: 0, heapUsed: 0, external: 0 }; };
  process.on = function () { return process; };
  process.emitWarning = function () {};
  Array.from = function (src, fn, thisArg) {
    if (src === undefined || src === null) throw new TypeError(src + ' is not iterable');
    var out = [];
    var i = 0;
    if (typeof src === 'string' || Array.isArray(src) || typeof src[__Symbol.iterator] === 'function') {
      for (const x of src) {
        out.push(fn ? fn.call(thisArg, x, i) : x);
        i++;
      }
    } else {
      var n = src.length >>> 0;
      for (; i < n; i++) out.push(fn ? fn.call(thisArg, src[i], i) : src[i]);
    }
    return out;
  };
  Array.of = function (...a) { return a; };
  Object.fromEntries = function (it) {
    var o = {};
    for (const e of it) o[e[0]] = e[1];
    return o;
  };
}
function __structuredClone(v) {
  var seen = new __Map();
  function cl(x) {
    if (x === null || (typeof x !== 'object' && typeof x !== 'function')) return x;
    if (typeof x === 'function') throw new Error('function could not be cloned');
    if (seen.has(x)) return seen.get(x);
    var r;
    if (Array.isArray(x)) { r = []; seen.set(x, r); for (var i = 0; i < x.length; i++) r.push(cl(x[i])); return r; }
    if (x instanceof __Date) return new __Date(x.getTime());
    if (x instanceof __Map) { r = new __Map(); seen.set(x, r); x.forEach(function (val, k) { r.set(cl(k), cl(val)); }); return r; }
    if (x instanceof __Set) { r = new __Set(); seen.set(x, r); x.forEach(function (val) { r.add(cl(val)); }); return r; }
    r = {};
    seen.set(x, r);
    Object.keys(x).forEach(function (k) { r[k] = cl(x[k]); });
    return r;
  }
  return cl(v);
}
function __exact(x) {
  var e = 0, dg = [], d, i, c, v, k, m, step, mul, cnt;
  while (x >= 9007199254740992) { x = x / 2; e++; }
  while (x !== Math.floor(x)) { x = x * 2; e--; }
  while (x > 0) { d = x % 10; dg.push(d); x = (x - d) / 10; }
  mul = e > 0 ? 2 : 5;
  cnt = e > 0 ? e : -e;
  while (cnt > 0) {
    step = cnt > 9 ? 9 : cnt;
    m = 1;
    for (k = 0; k < step; k++) m = m * mul;
    c = 0;
    for (i = 0; i < dg.length; i++) { v = dg[i] * m + c; dg[i] = v % 10; c = (v - v % 10) / 10; }
    while (c > 0) { dg.push(c % 10); c = (c - c % 10) / 10; }
    cnt -= step;
  }
  var s = '';
  for (i = dg.length - 1; i >= 0; i--) s += dg[i];
  return [s, s.length - 1 - (e < 0 ? -e : 0)];
}
function __sig(x, p) {
  var r = __exact(x), s = r[0], E = r[1], t, a, i;
  if (s.length <= p) {
    while (s.length < p) s += '0';
    return [s, E];
  }
  t = s.slice(0, p);
  if (s.charCodeAt(p) >= 53) {
    a = t.split('');
    i = p - 1;
    while (i >= 0) {
      if (a[i] === '9') { a[i] = '0'; i--; }
      else { a[i] = String.fromCharCode(a[i].charCodeAt(0) + 1); break; }
    }
    t = a.join('');
    if (i < 0) { t = '1' + t.slice(0, p - 1); E++; }
  }
  return [t, E];
}
function __expo(d, E) {
  return d.charAt(0) + (d.length > 1 ? '.' + d.slice(1) : '') + 'e' + (E < 0 ? '-' : '+') + (E < 0 ? -E : E);
}
function __zeros(n) {
  var z = '';
  while (n-- > 0) z += '0';
  return z;
}
function __toPrecision(p) {
  var x = Number(this), neg = '', r;
  if (p === undefined) return String(x);
  p = Math.floor(Number(p));
  if (x !== x || x === Infinity || x === -Infinity) return String(x);
  if (p < 1 || p > 100) throw new RangeError('toPrecision() argument must be between 1 and 100');
  if (x < 0) { neg = '-'; x = -x; }
  if (x === 0) return p > 1 ? '0.' + __zeros(p - 1) : '0';
  r = __sig(x, p);
  var d = r[0], E = r[1];
  if (E < -6 || E >= p) return neg + __expo(d, E);
  if (E >= 0) return neg + d.slice(0, E + 1) + (p > E + 1 ? '.' + d.slice(E + 1) : '');
  return neg + '0.' + __zeros(-(E + 1)) + d;
}
function __toExponential(f) {
  var x = Number(this), neg = '', r, p;
  if (x !== x || x === Infinity || x === -Infinity) return String(x);
  if (f !== undefined) {
    f = Math.floor(Number(f));
    if (f < 0 || f > 100) throw new RangeError('toExponential() argument must be between 0 and 100');
  }
  if (x < 0) { neg = '-'; x = -x; }
  if (x === 0) return neg + (f > 0 ? '0.' + __zeros(f) : '0') + 'e+0';
  if (f === undefined) {
    for (p = 1; p <= 17; p++) {
      r = __sig(x, p);
      if (Number(__expo(r[0], r[1])) === x) break;
    }
  } else r = __sig(x, f + 1);
  return neg + __expo(r[0], r[1]);
}
var __tplc;
function __tpl(site) {
  if (!__tplc) __tplc = {};
  if (__tplc[site]) return __tplc[site];
  var n = (arguments.length - 1) / 2, a = [], r = [];
  for (var i = 0; i < n; i++) { a.push(arguments[i + 1]); r.push(arguments[n + i + 1]); }
  a.raw = r;
  __tplc[site] = a;
  return a;
}
function __uriEnc(s, keep) {
  var out = '', i, c, cp, lo, b, k, hx = '0123456789ABCDEF';
  s = String(s);
  for (i = 0; i < s.length; i++) {
    c = s.charAt(i);
    if (keep.indexOf(c) >= 0) { out += c; continue; }
    cp = s.charCodeAt(i);
    if (cp >= 56320 && cp <= 57343) throw new URIError('URI malformed');
    if (cp >= 55296 && cp <= 56319) {
      if (i + 1 >= s.length) throw new URIError('URI malformed');
      lo = s.charCodeAt(i + 1);
      if (lo < 56320 || lo > 57343) throw new URIError('URI malformed');
      cp = 65536 + ((cp - 55296) << 10) + (lo - 56320);
      i++;
    }
    if (cp < 128) b = [cp];
    else if (cp < 2048) b = [192 | (cp >> 6), 128 | (cp & 63)];
    else if (cp < 65536) b = [224 | (cp >> 12), 128 | ((cp >> 6) & 63), 128 | (cp & 63)];
    else b = [240 | (cp >> 18), 128 | ((cp >> 12) & 63), 128 | ((cp >> 6) & 63), 128 | (cp & 63)];
    for (k = 0; k < b.length; k++) out += '%' + hx.charAt(b[k] >> 4) + hx.charAt(b[k] & 15);
  }
  return out;
}
function __uriDec(s, reserved) {
  var out = '', i = 0, n, c, b, need, cp, k, h, j, raw;
  s = String(s);
  n = s.length;
  while (i < n) {
    c = s.charAt(i);
    if (c !== '%') { out += c; i++; continue; }
    raw = i;
    if (i + 2 > n - 1) throw new URIError('URI malformed');
    h = parseInt(s.substr(i + 1, 2), 16);
    if (!/^[0-9a-fA-F]{2}$/.test(s.substr(i + 1, 2))) throw new URIError('URI malformed');
    b = h;
    i += 3;
    if (b < 128) {
      if (reserved.indexOf(String.fromCharCode(b)) >= 0) out += s.slice(raw, i);
      else out += String.fromCharCode(b);
      continue;
    }
    if (b >= 192 && b < 224) { need = 1; cp = b & 31; }
    else if (b >= 224 && b < 240) { need = 2; cp = b & 15; }
    else if (b >= 240 && b < 248) { need = 3; cp = b & 7; }
    else throw new URIError('URI malformed');
    for (k = 0; k < need; k++) {
      if (s.charAt(i) !== '%' || !/^[0-9a-fA-F]{2}$/.test(s.substr(i + 1, 2))) throw new URIError('URI malformed');
      j = parseInt(s.substr(i + 1, 2), 16);
      if ((j & 192) !== 128) throw new URIError('URI malformed');
      cp = (cp << 6) | (j & 63);
      i += 3;
    }
    if ((need === 1 && cp < 128) || (need === 2 && cp < 2048) || (need === 3 && cp < 65536) || cp > 1114111 || (cp >= 55296 && cp <= 57343)) throw new URIError('URI malformed');
    if (cp >= 65536) { cp -= 65536; out += String.fromCharCode(55296 + (cp >> 10), 56320 + (cp & 1023)); }
    else out += String.fromCharCode(cp);
  }
  return out;
}
function __encodeURIComponent(s) { return __uriEnc(s, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"); }
function __encodeURI(s) { return __uriEnc(s, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'();/?:@&=+$,#"); }
function __decodeURIComponent(s) { return __uriDec(s, ''); }
function __decodeURI(s) { return __uriDec(s, ';/?:@&=+$,#'); }

function __fr_check() {
  if (!__frs) return;
  for (var r = 0; r < __frs.length; r++) {
    let reg = __frs[r], l = reg['\x01e'];
    for (let i = l.length - 1; i >= 0; i--) {
      if (__wget(l[i].c) === undefined) {
        let held = l[i].h;
        l.splice(i, 1);
        __job(function () { reg['\x01cb'](held); });
      }
    }
  }
}
