function __su_this(t) { return typeof t === 'string' ? t : String(t); }
function __su_int(x) {
  x = Number(x);
  if (x !== x) return 0;
  return x < 0 ? Math.ceil(x) : Math.floor(x);
}
function __rc(m, s, a, b) {
  __raw(1);
  var r = __nsm[m].call(s, a, b);
  __raw(0);
  return r;
}
function __su_charAt(i) {
  var s = __su_this(this), u = __u16(s);
  i = __su_int(i);
  if (i < 0 || i >= u.length) return '';
  return __fromu16([u[i]]);
}
function __su_charCodeAt(i) {
  var s = __su_this(this), u = __u16(s);
  i = __su_int(i);
  if (i < 0 || i >= u.length) return NaN;
  return u[i];
}
function __su_pos(s, p, n) {
  var b;
  if (p < 0) p = 0;
  if (p > n) p = n;
  b = __u2b(s, p);
  if (b < 0) b = __u2b(s, p + 1);
  return b;
}
function __su_indexOf(sub, pos) {
  var s = __su_this(this), n = s.length, r;
  sub = String(sub);
  if (sub === '') return Math.min(Math.max(__su_int(pos), 0), n);
  r = __rc('indexOf', s, sub, __su_pos(s, __su_int(pos), n));
  return r < 0 ? -1 : __b2u(s, r);
}
function __su_lastIndexOf(sub, pos) {
  var s = __su_this(this), n = s.length, r;
  sub = String(sub);
  pos = (pos === undefined || Number(pos) !== Number(pos)) ? n : __su_int(pos);
  if (sub === '') return Math.min(Math.max(pos, 0), n);
  r = __rc('lastIndexOf', s, sub, __su_pos(s, pos, n));
  return r < 0 ? -1 : __b2u(s, r);
}
function __su_includes(sub, pos) {
  return __su_indexOf.call(__su_this(this), sub, pos) !== -1;
}
function __su_startsWith(sub, pos) {
  var s = __su_this(this), n = s.length;
  return __rc('startsWith', s, String(sub), __su_pos(s, __su_int(pos), n));
}
function __su_endsWith(sub, pos) {
  var s = __su_this(this), n = s.length;
  pos = pos === undefined ? n : __su_int(pos);
  return __rc('endsWith', s, String(sub), __su_pos(s, pos, n));
}
function __su_range(s, a, b) {
  var ba, bb, u;
  if (a >= b) return '';
  ba = __u2b(s, a);
  bb = __u2b(s, b);
  if (ba < 0 || bb < 0) {
    u = __u16(s);
    return __fromu16(u.slice(a, b));
  }
  return __rc('slice', s, ba, bb);
}
function __su_slice(a, b) {
  var s = __su_this(this), n = s.length;
  a = __su_int(a);
  b = b === undefined ? n : __su_int(b);
  a = a < 0 ? Math.max(n + a, 0) : Math.min(a, n);
  b = b < 0 ? Math.max(n + b, 0) : Math.min(b, n);
  return __su_range(s, a, b);
}
function __su_substring(a, b) {
  var s = __su_this(this), n = s.length, t;
  a = Math.min(Math.max(__su_int(a), 0), n);
  b = b === undefined ? n : Math.min(Math.max(__su_int(b), 0), n);
  if (a > b) { t = a; a = b; b = t; }
  return __su_range(s, a, b);
}
function __su_fill(s, target, pad, atStart) {
  var n = s.length, need, f, k;
  target = __su_int(target);
  pad = pad === undefined ? ' ' : String(pad);
  if (target <= n || pad === '') return s;
  need = target - n;
  k = Math.ceil(need / pad.length);
  f = pad.repeat(k).slice(0, need);
  return atStart ? f + s : s + f;
}
function __su_padStart(target, pad) { return __su_fill(__su_this(this), target, pad, true); }
function __su_padEnd(target, pad) { return __su_fill(__su_this(this), target, pad, false); }
function __su_isws(c) {
  return c === 32 || (c >= 9 && c <= 13) || c === 160 || c === 5760 || (c >= 8192 && c <= 8202) ||
    c === 8232 || c === 8233 || c === 8239 || c === 8287 || c === 12288 || c === 65279;
}
function __su_trimmed(s, front, back) {
  var u = __u16(s), a = 0, b = u.length;
  if (front) while (a < b && __su_isws(u[a])) a++;
  if (back) while (b > a && __su_isws(u[b - 1])) b--;
  return __su_range(s, a, b);
}
function __su_trim() { return __su_trimmed(__su_this(this), true, true); }
function __su_trimStart() { return __su_trimmed(__su_this(this), true, false); }
function __su_trimEnd() { return __su_trimmed(__su_this(this), false, true); }
function __su_split(sep, limit) {
  var s = __su_this(this), u, out = [], i, lim;
  if (typeof sep === 'string' && sep === '') {
    u = __u16(s);
    lim = limit === undefined ? 4294967295 : limit >>> 0;
    for (i = 0; i < u.length && out.length < lim; i++) out.push(__fromu16([u[i]]));
    return out;
  }
  __raw(1);
  out = __nsm.split.call(s, sep, limit);
  __raw(0);
  return out;
}
function __case_find(t, cp) {
  var lo = 0, hi = t.length / 4 - 1, mid, s, e;
  while (lo <= hi) {
    mid = (lo + hi) >> 1;
    s = t[mid * 4];
    e = t[mid * 4 + 1];
    if (cp < s) hi = mid - 1;
    else if (cp > e) lo = mid + 1;
    else return (t[mid * 4 + 3] === 1 || (cp - s) % 2 === 0) ? t[mid * 4 + 2] : 0;
  }
  return 0;
}
function __case_multi(m, cp) {
  for (var i = 0; i < m.length; i += 2) if (m[i] === cp) return m[i + 1];
  return null;
}
function __cpat(u, i) {
  var c = u[i];
  if (c >= 56320 && c <= 57343 && i > 0 && u[i - 1] >= 55296 && u[i - 1] <= 56319) return 65536 + ((u[i - 1] - 55296) << 10) + (c - 56320);
  if (c >= 55296 && c <= 56319 && i + 1 < u.length && u[i + 1] >= 56320 && u[i + 1] <= 57343) return 65536 + ((c - 55296) << 10) + (u[i + 1] - 56320);
  return c;
}
function __iscased(c) {
  if (c < 128) return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  if (c >= 119808 && c <= 120831) return true;
  return __case_find(__UPR, c) !== 0 || __case_find(__LOR, c) !== 0 || __case_multi(__UPM, c) !== null || __case_multi(__LOM, c) !== null;
}
function __case_conv(s, upper) {
  var t, m, out = [], i, cp, d, r, n, u;
  if (__UPR === undefined) __case_init();
  t = upper ? __UPR : __LOR;
  m = upper ? __UPM : __LOM;
  u = __u16(s);
  n = u.length;
  for (i = 0; i < n; i++) {
    cp = u[i];
    if (cp >= 55296 && cp <= 56319 && i + 1 < n && u[i + 1] >= 56320 && u[i + 1] <= 57343) {
      cp = 65536 + ((cp - 55296) << 10) + (u[i + 1] - 56320);
      d = __case_find(t, cp);
      if (d !== 0) { cp += d; out.push(55296 + ((cp - 65536) >> 10), 56320 + ((cp - 65536) & 1023)); }
      else out.push(u[i], u[i + 1]);
      i++;
      continue;
    }
    if (cp < 128) {
      if (upper) { if (cp >= 97 && cp <= 122) cp -= 32; }
      else if (cp >= 65 && cp <= 90) cp += 32;
      out.push(cp);
      continue;
    }
    r = __case_multi(m, cp);
    if (r !== null) {
      r = __u16(r);
      for (d = 0; d < r.length; d++) out.push(r[d]);
      continue;
    }
    if (!upper && cp === 931) {
      /* sigma final : precede d'une lettre et non suivi d'une lettre */
      if (i > 0 && __iscased(__cpat(u, i - 1)) && !(i + 1 < n && __iscased(__cpat(u, i + 1)))) { out.push(962); continue; }
    }
    d = __case_find(t, cp);
    out.push(d !== 0 ? cp + d : cp);
  }
  return __fromu16(out);
}
function __su_toUpperCase() { return __case_conv(__su_this(this), true); }
function __su_toLowerCase() { return __case_conv(__su_this(this), false); }
function __su_fromCharCode(...a) {
  var u = [], i;
  for (i = 0; i < a.length; i++) u.push(Number(a[i]) & 65535);
  return __fromu16(u);
}
function __coll(s, level) {
  var from = 'a\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5c\u00e7e\u00e8\u00e9\u00ea\u00ebi\u00ec\u00ed\u00ee\u00efn\u00f1o\u00f2\u00f3\u00f4\u00f5\u00f6u\u00f9\u00fa\u00fb\u00fcy\u00fd\u00ff';
  var base = 'aaaaaaaccceeeeeiiiiinnooooooouuuuuyyy', out = '', i, c, k, lo, cp;
  for (i = 0; i < s.length; i++) {
    c = s.charAt(i);
    cp = s.charCodeAt(i);
    if (cp >= 55296 && cp <= 56319 && i + 1 < s.length) { c += s.charAt(i + 1); i++; cp = 65536 + ((cp - 55296) << 10) + (s.charCodeAt(i) - 56320); }
    lo = c.toLowerCase();
    k = from.indexOf(lo);
    if (level === 0) {
      if (cp === 32 || (cp >= 9 && cp <= 13) || cp === 160) out += '1';
      else if (cp < 48 || (cp > 57 && cp < 65) || (cp > 90 && cp < 97) || (cp > 122 && cp < 128)) out += '2' + lo;
      else if (cp >= 48 && cp <= 57) out += '4' + lo;
      else if (cp >= 119808 && cp <= 120831) out += '5' + lo;
      else if (cp >= 65536) out += '3' + lo;
      else if (lo === '\u00df') out += '5ss';
      else if (k >= 0) out += '5' + base.charAt(k);
      else if (cp < 128 || (cp >= 192 && cp < 592)) out += '5' + lo;
      else if (cp >= 880 && cp < 1024) out += '6' + lo;
      else if (cp >= 1024 && cp < 1328) out += '7' + lo;
      else if (cp >= 8192 && cp < 12288) out += '3' + lo;
      else out += '8' + lo;
    }
    else if (level === 1) out += k > 0 && lo !== base.charAt(k) ? '1' : '0';
    else out += c === lo ? '0' : '1';
  }
  return out;
}
var __cfold;
function __init_str() {
  var SP = String.prototype;
  // variantes de casse des points de code lo..lo+n (valeur empaquetee), pour les regex /i
  __cfold = function (packed) {
    var lo = packed & 2097151, n = packed >> 21, out = [], i, cp, s, v, k, c1, c2, vs;
    for (i = 0; i <= n; i++) {
      cp = lo + i;
      if (cp >= 55296 && cp <= 57343) continue;
      s = String.fromCodePoint(cp);
      c1 = s.toUpperCase(); c2 = s.toLowerCase();
      vs = [c1, c2, c1.toLowerCase(), c2.toUpperCase()];
      for (k = 0; k < 4; k++) {
        v = vs[k];
        if (v.length === 0 || v.length > 2) continue;
        if (v.codePointAt(0) !== cp && String.fromCodePoint(v.codePointAt(0)) === v) out.push(v.codePointAt(0));
      }
    }
    return out;
  };
  SP.at = function (i) {
    var s = __su_this(this), n = s.length;
    i = __su_int(i);
    if (i < 0) i += n;
    if (i < 0 || i >= n) return undefined;
    return s.charAt(i);
  };
  SP.codePointAt = function (i) {
    var s = __su_this(this), u = __u16(s), c, d;
    i = __su_int(i);
    if (i < 0 || i >= u.length) return undefined;
    c = u[i];
    if (c >= 55296 && c <= 56319 && i + 1 < u.length) {
      d = u[i + 1];
      if (d >= 56320 && d <= 57343) return 65536 + ((c - 55296) << 10) + (d - 56320);
    }
    return c;
  };
  SP.normalize = function () { return __su_this(this); };
  SP.localeCompare = function (o) {
    var a = __su_this(this), b = String(o), x = __coll(a, 0), y = __coll(b, 0), i;
    if (x !== y) return x < y ? -1 : 1;
    x = __coll(a, 1);
    y = __coll(b, 1);
    if (x !== y) return x < y ? -1 : 1;
    x = __coll(a, 2);
    y = __coll(b, 2);
    return x === y ? 0 : x < y ? -1 : 1;
  };
  SP.concat = function (...a) {
    var s = __su_this(this), i;
    for (i = 0; i < a.length; i++) s += String(a[i]);
    return s;
  };
  String.fromCodePoint = function (...a) {
    var u = [], i, c;
    for (i = 0; i < a.length; i++) {
      c = Number(a[i]);
      if (c !== Math.floor(c) || c < 0 || c > 1114111) throw new RangeError('Invalid code point ' + a[i]);
      if (c >= 65536) { c -= 65536; u.push(55296 + (c >> 10), 56320 + (c & 1023)); }
      else u.push(c);
    }
    return __fromu16(u);
  };
}
