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
function __dparse(str) {
  str = String(str).trim();
  var m = /^([+-]\d{6}|\d{4})(?:-(\d\d)(?:-(\d\d))?)?(?:[T ](\d\d):(\d\d)(?::(\d\d)(?:[.,](\d{1,9}))?)?)?\s*(Z|[+-]\d\d(?::?\d\d)?)?$/.exec(str);
  if (m) {
    var ms = m[7] ? Number((m[7] + '00').slice(0, 3)) : 0;
    var t = __mktime(Number(m[1]), m[2] ? m[2] - 1 : 0, m[3] ? Number(m[3]) : 1,
                     m[4] ? Number(m[4]) : 0, m[5] ? Number(m[5]) : 0, m[6] ? Number(m[6]) : 0, ms);
    var z = m[8];
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
    return tt;
  }
  var sl = /^(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(str) || /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(str);
  if (sl) {
    if (sl[1].length === 4) return __mktime(Number(sl[1]), sl[2] - 1, Number(sl[3]), 0, 0, 0, 0);
    return __mktime(Number(sl[3]), sl[1] - 1, Number(sl[2]), 0, 0, 0, 0);
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
function __init_lib() {
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
    if (rep === null && plist === null) return jstr(value, undefined, space);
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
      t = __mktime(Number(a), Number(b), c === undefined ? 1 : Number(c), d === undefined ? 0 : Number(d),
                   e === undefined ? 0 : Number(e), f === undefined ? 0 : Number(f), g === undefined ? 0 : Number(g));
      var yy = Number(a);
      if (yy >= 0 && yy <= 99) t += (1900 * 365 + 17 + 0) * 0;
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
    var fn = function () {
      var t = this[TT];
      return t !== t ? NaN : __dparts(t)[comp];
    };
    P['get' + k] = fn;
    P['getUTC' + k] = fn;
  });
  var setters = { FullYear: [0, 'y'], Month: [1, 'm'], Date: [2, 'd'], Hours: [3, 'h'], Minutes: [4, 'mi'], Seconds: [5, 's'], Milliseconds: [6, 'ms'] };
  Object.keys(setters).forEach(function (k) {
    var idx = setters[k][0];
    var fn = function (...args) {
      var t = this[TT];
      if (t !== t) {
        if (idx !== 0) return NaN;
        t = 0;
      }
      var p = __dparts(t);
      var v = [p.y, p.m, p.d, p.h, p.mi, p.s, p.ms];
      for (var i = 0; i < args.length && idx + i < 7; i++) v[idx + i] = Number(args[i]);
      this[TT] = __mktime(v[0], v[1], v[2], v[3], v[4], v[5], v[6]);
      return this[TT];
    };
    P['set' + k] = fn;
    P['setUTC' + k] = fn;
  });
  P.getTime = P.valueOf = function () { return this[TT]; };
  P.setTime = function (t) { this[TT] = Number(t); return this[TT]; };
  P.getYear = function () { return this.getFullYear() - 1900; };
  P.getTimezoneOffset = function () { return this[TT] !== this[TT] ? NaN : 0; };
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
    var p = __dparts(t);
    return __DN[p.wd].slice(0, 3) + ' ' + __MN[p.m].slice(0, 3) + ' ' + __p2(p.d) + ' ' + (p.y < 1000 ? ('000' + p.y).slice(-4) : p.y);
  };
  P.toTimeString = function () {
    var t = this[TT];
    if (t !== t) return 'Invalid Date';
    var p = __dparts(t);
    return __p2(p.h) + ':' + __p2(p.mi) + ':' + __p2(p.s) + ' GMT+0000 (Coordinated Universal Time)';
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
    var t = this[TT];
    if (t !== t) return 'Invalid Date';
    var p = __dparts(t);
    if (o && (o.month === 'long' || o.month === 'short')) {
      var mn = o.month === 'long' ? __MN[p.m] : __MN[p.m].slice(0, 3);
      var s = mn + ' ' + p.d + ', ' + p.y;
      if (o.weekday) s = (o.weekday === 'long' ? __DN[p.wd] : __DN[p.wd].slice(0, 3)) + ', ' + s;
      return s;
    }
    return (p.m + 1) + '/' + p.d + '/' + p.y;
  };
  P.toLocaleTimeString = function () {
    var t = this[TT];
    if (t !== t) return 'Invalid Date';
    var p = __dparts(t);
    return (p.h % 12 === 0 ? 12 : p.h % 12) + ':' + __p2(p.mi) + ':' + __p2(p.s) + ' ' + (p.h < 12 ? 'AM' : 'PM');
  };
  P.toLocaleString = function (loc, o) {
    return this[TT] !== this[TT] ? 'Invalid Date' : this.toLocaleDateString(loc, o) + ', ' + this.toLocaleTimeString();
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
function __tpl() {
  var n = arguments.length / 2, a = [], r = [];
  for (var i = 0; i < n; i++) { a.push(arguments[i]); r.push(arguments[n + i]); }
  a.raw = r;
  return a;
}
