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
