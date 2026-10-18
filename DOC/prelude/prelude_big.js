var __bigproto, __bigop, __BigInt;
function __bmk(sign, m) {
  var o = Object.create(__bigproto);
  o['\x01m'] = m;
  o['\x01g'] = m.length === 0 ? 1 : sign;
  return o;
}
function __bm(x) { return x['\x01m']; }
function __bsg(x) { return x['\x01g']; }
function __mtrim(a) {
  while (a.length > 0 && a[a.length - 1] === 0) a.pop();
  return a;
}
function __mcmp(a, b) {
  if (a.length !== b.length) return a.length < b.length ? -1 : 1;
  for (var i = a.length - 1; i >= 0; i--) {
    if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return 0;
}
function __madd(a, b) {
  var r = [], c = 0, n = a.length > b.length ? a.length : b.length, v;
  for (var i = 0; i < n; i++) {
    v = (i < a.length ? a[i] : 0) + (i < b.length ? b[i] : 0) + c;
    if (v >= 10000000) { r.push(v - 10000000); c = 1; } else { r.push(v); c = 0; }
  }
  if (c > 0) r.push(c);
  return r;
}
function __msub(a, b) {
  var r = [], br = 0, v;
  for (var i = 0; i < a.length; i++) {
    v = a[i] - (i < b.length ? b[i] : 0) - br;
    if (v < 0) { v += 10000000; br = 1; } else br = 0;
    r.push(v);
  }
  return __mtrim(r);
}
function __mmuls(a, s) {
  var r = [], c = 0, v;
  if (s === 0) return r;
  for (var i = 0; i < a.length; i++) {
    v = a[i] * s + c;
    c = Math.floor(v / 10000000);
    r.push(v - c * 10000000);
  }
  if (c > 0) r.push(c);
  return r;
}
function __maddsmall(a, s) {
  var r = a.slice(), i = 0, v;
  while (s > 0) {
    if (i >= r.length) r.push(0);
    v = r[i] + s;
    if (v >= 10000000) { r[i] = v - 10000000; s = 1; } else { r[i] = v; s = 0; }
    i++;
  }
  return r;
}
function __mmul(a, b) {
  if (a.length === 0 || b.length === 0) return [];
  var r = [], i, j, k, c, v, ai;
  for (i = 0; i < a.length + b.length; i++) r.push(0);
  for (i = 0; i < a.length; i++) {
    ai = a[i];
    if (ai === 0) continue;
    c = 0;
    for (j = 0; j < b.length; j++) {
      v = r[i + j] + ai * b[j] + c;
      c = Math.floor(v / 10000000);
      r[i + j] = v - c * 10000000;
    }
    k = i + b.length;
    while (c > 0) {
      v = r[k] + c;
      c = Math.floor(v / 10000000);
      r[k] = v - c * 10000000;
      k++;
    }
  }
  return __mtrim(r);
}
function __mdivs(a, d) {
  var r = [], rem = 0, v, q, i;
  for (i = 0; i < a.length; i++) r.push(0);
  for (i = a.length - 1; i >= 0; i--) {
    v = rem * 10000000 + a[i];
    q = Math.floor(v / d);
    rem = v - q * d;
    r[i] = q;
  }
  return [__mtrim(r), rem];
}
function __mdivmod(a, b) {
  if (__mcmp(a, b) < 0) return [[], a.slice()];
  if (b.length === 1) {
    var t = __mdivs(a, b[0]);
    return [t[0], t[1] > 0 ? [t[1]] : []];
  }
  var d = Math.floor(10000000 / (b[b.length - 1] + 1));
  var u = __mmuls(a, d), v = __mmuls(b, d), n = v.length, j, i, m, qhat, rhat, num, p, carry, borrow, sub, q = [];
  while (u.length < a.length + 1) u.push(0);
  m = u.length - n - 1;
  for (i = 0; i <= m; i++) q.push(0);
  for (j = m; j >= 0; j--) {
    num = u[j + n] * 10000000 + u[j + n - 1];
    qhat = Math.floor(num / v[n - 1]);
    rhat = num - qhat * v[n - 1];
    while (qhat >= 10000000 || qhat * v[n - 2] > rhat * 10000000 + u[j + n - 2]) {
      qhat--;
      rhat += v[n - 1];
      if (rhat >= 10000000) break;
    }
    borrow = 0;
    carry = 0;
    for (i = 0; i < n; i++) {
      p = qhat * v[i] + carry;
      carry = Math.floor(p / 10000000);
      sub = u[i + j] - (p - carry * 10000000) - borrow;
      if (sub < 0) { sub += 10000000; borrow = 1; } else borrow = 0;
      u[i + j] = sub;
    }
    sub = u[j + n] - carry - borrow;
    if (sub < 0) { sub += 10000000; borrow = 1; } else borrow = 0;
    u[j + n] = sub;
    if (borrow > 0) {
      qhat--;
      carry = 0;
      for (i = 0; i < n; i++) {
        sub = u[i + j] + v[i] + carry;
        if (sub >= 10000000) { sub -= 10000000; carry = 1; } else carry = 0;
        u[i + j] = sub;
      }
      u[j + n] = (u[j + n] + carry) % 10000000;
    }
    q[j] = qhat;
  }
  u.length = n;
  return [__mtrim(q), __mdivs(__mtrim(u), d)[0]];
}
function __bfromstr10(s) {
  var m = [], i = s.length, st;
  while (i > 0) {
    st = i - 7 < 0 ? 0 : i - 7;
    m.push(Number(s.slice(st, i)));
    i = st;
  }
  return __mtrim(m);
}
function __bparse(str) {
  var s = String(str).trim(), neg = false, radix = 10, c0, m, i, d, ch;
  if (s === '') return __bmk(1, []);
  if (s.length > 2 && s.charAt(0) === '0') {
    c0 = s.charAt(1).toLowerCase();
    radix = c0 === 'x' ? 16 : c0 === 'o' ? 8 : c0 === 'b' ? 2 : 10;
    if (radix !== 10) s = s.slice(2);
  }
  if (radix === 10) {
    if (s.charAt(0) === '-') { neg = true; s = s.slice(1); }
    else if (s.charAt(0) === '+') s = s.slice(1);
    if (s === '') return null;
    for (i = 0; i < s.length; i++) {
      ch = s.charCodeAt(i);
      if (ch < 48 || ch > 57) return null;
    }
    return __bmk(neg ? -1 : 1, __bfromstr10(s));
  }
  m = [];
  for (i = 0; i < s.length; i++) {
    ch = s.charCodeAt(i);
    d = ch >= 48 && ch <= 57 ? ch - 48 : ch >= 97 && ch <= 102 ? ch - 87 : ch >= 65 && ch <= 70 ? ch - 55 : 99;
    if (d >= radix) return null;
    m = __maddsmall(__mmuls(m, radix), d);
  }
  return __bmk(1, __mtrim(m));
}
function __btos(x, radix) {
  var m = __bm(x), s = '', i, t, ds, r;
  if (m.length === 0) return '0';
  if (radix === undefined || radix === 10) {
    s = String(m[m.length - 1]);
    for (i = m.length - 2; i >= 0; i--) s += ('000000' + m[i]).slice(-7);
  } else {
    ds = '0123456789abcdefghijklmnopqrstuvwxyz';
    t = m;
    while (t.length > 0) {
      r = __mdivs(t, radix);
      s = ds.charAt(r[1]) + s;
      t = r[0];
    }
  }
  return __bsg(x) < 0 ? '-' + s : s;
}
function __bfromnum(n) {
  if (n !== n || n === Infinity || n === -Infinity || n !== Math.floor(n)) {
    throw new RangeError('The number ' + n + ' cannot be converted to a BigInt because it is not an integer');
  }
  var neg = n < 0, a = neg ? -n : n;
  if (a === 0) return __bmk(1, []);
  return __bmk(neg ? -1 : 1, __bfromstr10(__exact(a)[0]));
}
function __bto(v) {
  var t = typeof v, r;
  if (t === 'bigint') return v;
  if (t === 'number') return __bfromnum(v);
  if (t === 'boolean') return __bmk(1, v ? [1] : []);
  if (t === 'string') {
    r = __bparse(v);
    if (r === null) throw new SyntaxError('Cannot convert ' + v + ' to a BigInt');
    return r;
  }
  throw new TypeError('Cannot convert ' + String(v) + ' to a BigInt');
}
function __badd(a, b) {
  var sa = __bsg(a), sb = __bsg(b), ma = __bm(a), mb = __bm(b), c;
  if (sa === sb) return __bmk(sa, __madd(ma, mb));
  c = __mcmp(ma, mb);
  if (c === 0) return __bmk(1, []);
  return c > 0 ? __bmk(sa, __msub(ma, mb)) : __bmk(sb, __msub(mb, ma));
}
function __bneg(a) { return __bmk(-__bsg(a), __bm(a)); }
function __bcmp(a, b) {
  var sa = __bsg(a), sb = __bsg(b), c;
  if (sa !== sb) return sa < sb ? -1 : 1;
  c = __mcmp(__bm(a), __bm(b));
  return sa < 0 ? -c : c;
}
function __bcmpnum(b, n) {
  if (n !== n) return 2;
  if (n === Infinity) return -1;
  if (n === -Infinity) return 1;
  var f = Math.floor(n), c = __bcmp(b, __bfromnum(f));
  if (c === 0 && n > f) return -1;
  return c;
}
function __bcmpany(x, y) {
  var tx = typeof x, ty = typeof y, r;
  if (tx === 'bigint' && ty === 'bigint') return __bcmp(x, y);
  if (tx === 'bigint') {
    if (ty === 'string') { r = __bparse(y); return r === null ? 2 : __bcmp(x, r); }
    return __bcmpnum(x, Number(y));
  }
  r = __bcmpany(y, x);
  return r === 2 ? 2 : -r;
}
function __bdivmod(a, b) {
  if (__bm(b).length === 0) throw new RangeError('Division by zero');
  var r = __mdivmod(__bm(a), __bm(b));
  return [__bmk(__bsg(a) * __bsg(b), r[0]), __bmk(__bsg(a), r[1])];
}
function __bpow(a, b) {
  if (__bsg(b) < 0) throw new RangeError('Exponent must be non-negative');
  var e = Number(__btos(b)), r = [1], base = __bm(a).slice(), neg = __bsg(a) < 0 && e % 2 === 1;
  if (e > 1000000000) throw new RangeError('Maximum BigInt size exceeded');
  while (e > 0) {
    if (e % 2 === 1) r = __mmul(r, base);
    e = Math.floor(e / 2);
    if (e > 0) base = __mmul(base, base);
  }
  return __bmk(neg ? -1 : 1, r);
}
function __bshl(a, n) {
  var p;
  if (n >= 0) return __bmk(__bsg(a), __mmul(__bm(a), __bm(__bpow(__bmk(1, [2]), __bfromnum(n)))));
  p = __bm(__bpow(__bmk(1, [2]), __bfromnum(-n)));
  var r = __mdivmod(__bm(a), p), q = __bmk(__bsg(a), r[0]);
  if (__bsg(a) < 0 && r[1].length > 0) q = __badd(q, __bmk(-1, [1]));
  return q;
}
function __bbits(x, n) {
  var m = __bm(x), neg = __bsg(x) < 0, out = [], r, i;
  if (neg) m = __msub(m, [1]);
  while (m.length > 0) {
    r = __mdivs(m, 65536);
    out.push(r[1]);
    m = r[0];
  }
  while (out.length < n) out.push(0);
  if (neg) for (i = 0; i < out.length; i++) out[i] = 65535 - out[i];
  return out;
}
function __bfrombits(r, neg) {
  var m = [], i;
  if (neg) for (i = 0; i < r.length; i++) r[i] = 65535 - r[i];
  for (i = r.length - 1; i >= 0; i--) m = __maddsmall(__mmuls(m, 65536), r[i]);
  m = __mtrim(m);
  if (neg) return __bmk(-1, __madd(m, [1]));
  return __bmk(1, m);
}
function __bbit(op, a, b) {
  var n = Math.max(__btos(a, 16).length, __btos(b, 16).length) + 1, x, y, r = [], i, sa = __bsg(a) < 0 ? 1 : 0, sb = __bsg(b) < 0 ? 1 : 0, sr;
  n = Math.floor(n / 4) + 2;
  x = __bbits(a, n);
  y = __bbits(b, n);
  for (i = 0; i < n; i++) r.push(op === 6 ? (x[i] & y[i]) : op === 7 ? (x[i] | y[i]) : (x[i] ^ y[i]));
  sr = op === 6 ? (sa & sb) : op === 7 ? (sa | sb) : (sa ^ sb);
  return __bfrombits(r, sr === 1);
}
function __bmix() {
  throw new TypeError('Cannot mix BigInt and other types, use explicit conversions');
}
function __bnorm(x, y) {
  if (typeof x !== 'bigint' || typeof y !== 'bigint') __bmix();
}
function __bigop_impl(op, a, b) {
  var r;
  if (op === 0) {
    if (typeof a === 'string' || typeof b === 'string') return `${a}${b}`;
    if (typeof a === 'object' && a !== null && typeof b === 'bigint') return `${a}${b}`;
    if (typeof b === 'object' && b !== null && typeof a === 'bigint') return `${a}${b}`;
    __bnorm(a, b);
    return __badd(a, b);
  }
  if (op === 16) {
    if (a === null || b === null || a === undefined || b === undefined) return false;
    r = __bcmpany(a, b);
    return r === 0;
  }
  if (op === 17) {
    return typeof a === 'bigint' && typeof b === 'bigint' && __bcmp(a, b) === 0;
  }
  if (op >= 12 && op <= 15) {
    r = __bcmpany(a, b);
    if (r === 2) return false;
    return op === 12 ? r < 0 : op === 13 ? r <= 0 : op === 14 ? r > 0 : r >= 0;
  }
  if (op === 18) return __bneg(a);
  if (op === 19) return __badd(a, __bmk(1, [1]));
  if (op === 20) return __badd(a, __bmk(-1, [1]));
  if (op === 21) return __badd(__bneg(a), __bmk(-1, [1]));
  __bnorm(a, b);
  if (op === 1) return __badd(a, __bneg(b));
  if (op === 2) return __bmk(__bsg(a) * __bsg(b), __mmul(__bm(a), __bm(b)));
  if (op === 3) return __bdivmod(a, b)[0];
  if (op === 4) return __bdivmod(a, b)[1];
  if (op === 5) return __bpow(a, b);
  if (op >= 6 && op <= 8) return __bbit(op, a, b);
  if (op === 9) return __bshl(a, Number(__btos(b)));
  if (op === 10) return __bshl(a, -Number(__btos(b)));
  throw new TypeError('BigInts have no unsigned right shift, use >> instead');
}
function __init_big() {
  var P = {};
  __bigproto = P;
  __bigop = __bigop_impl;
  __BigInt = function BigInt(v) {
    if (this !== undefined && this !== null && Object.getPrototypeOf(this) === P) throw new TypeError('BigInt is not a constructor');
    return __bto(v);
  };
  __BigInt.prototype = P;
  P.constructor = __BigInt;
  P.toString = function (radix) { return __btos(this, radix === undefined ? 10 : radix); };
  P.valueOf = function () { return Number(__btos(this)); };
  P.toJSON = function () { throw new TypeError('Do not know how to serialize a BigInt'); };
  P.toLocaleString = function () {
    var s = __btos(this), neg = s.charAt(0) === '-', o = '', i;
    if (neg) s = s.slice(1);
    for (i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 === 0) o += ',';
      o += s.charAt(i);
    }
    return neg ? '-' + o : o;
  };
  __BigInt.asUintN = function (bits, x) {
    var m = __bpow(__bmk(1, [2]), __bfromnum(bits)), r = __bdivmod(__bto(x), m)[1];
    if (__bsg(r) < 0) r = __badd(r, m);
    return r;
  };
  __BigInt.asIntN = function (bits, x) {
    var u = __BigInt.asUintN(bits, x), h = __bpow(__bmk(1, [2]), __bfromnum(bits - 1));
    if (bits > 0 && __bcmp(u, h) >= 0) u = __badd(u, __bneg(__bpow(__bmk(1, [2]), __bfromnum(bits))));
    return u;
  };
}
