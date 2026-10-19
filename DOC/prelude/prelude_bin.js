var __ArrayBuffer, __SharedArrayBuffer, __TypedArray, __DataView, __Buffer, __TextEncoder, __TextDecoder, __Atomics;
var __Int8Array, __Uint8Array, __Uint8ClampedArray, __Int16Array, __Uint16Array, __Int32Array, __Uint32Array, __Float32Array, __Float64Array;
var __BigInt64Array, __BigUint64Array, __taKinds;
function __taIdx(v, what) {
  var n = Number(v);
  if (isNaN(n)) return 0;
  n = Math.trunc(n);
  if (n < 0 || n > 1073741824) throw new RangeError('Invalid ' + what);
  return n;
}
function __taCheck(o) {
  if (__tainfo(o, 5) !== 1) throw new TypeError('this is not a typed array.');
  return o;
}
function __taLen(o) { return __tainfo(o, 2); }
function __taArr(o) {
  var n = o.length >>> 0, a = [], i;
  for (i = 0; i < n; i++) a.push(o[i]);
  return a;
}
function __mkTA(name, kind, size) {
  var C = function (a, b, c) {
    if (new.target === undefined) throw new TypeError("Constructor " + name + " requires 'new'");
    var proto = new.target.prototype, buf, off = 0, len, vals, i, src;
    if (a === undefined || a === null || typeof a !== 'object') {
      len = a === undefined ? 0 : __taIdx(a, 'typed array length: ' + a);
      buf = __abnew(__ArrayBuffer.prototype, len * size);
      return __tanew(proto, buf, 0, len, kind);
    }
    if (__tainfo(a, 5) === 2) {
      off = b === undefined ? 0 : __taIdx(b, 'offset');
      if (off % size !== 0) throw new RangeError('start offset of ' + name + ' should be a multiple of ' + size);
      var bl = __tainfo(a, 4);
      if (c === undefined) {
        if ((bl - off) % size !== 0) throw new RangeError('byte length of ' + name + ' should be a multiple of ' + size);
        if (off > bl) throw new RangeError('Start offset ' + off + ' is outside the bounds of the buffer');
        len = (bl - off) / size;
      } else {
        len = __taIdx(c, 'typed array length: ' + c);
        if (off + len * size > bl) throw new RangeError('Invalid typed array length: ' + len);
      }
      return __tanew(proto, a, off, len, kind);
    }
    if (__tainfo(a, 5) === 1) {
      len = __taLen(a);
      buf = __abnew(__ArrayBuffer.prototype, len * size);
      var t = __tanew(proto, buf, 0, len, kind);
      for (i = 0; i < len; i++) t[i] = a[i];
      return t;
    }
    if (typeof a[Symbol.iterator] === 'function' || Array.isArray(a)) vals = Array.isArray(a) ? a : [...a];
    else { vals = []; for (i = 0; i < (a.length >>> 0); i++) vals.push(a[i]); }
    len = vals.length;
    buf = __abnew(__ArrayBuffer.prototype, len * size);
    var t2 = __tanew(proto, buf, 0, len, kind);
    for (i = 0; i < len; i++) t2[i] = vals[i];
    return t2;
  };
  Object.defineProperty(C, 'name', { value: name });
  C.prototype = Object.create(__TypedArray.prototype);
  Object.defineProperty(C.prototype, 'constructor', { value: C, writable: true, configurable: true, enumerable: false });
  C.BYTES_PER_ELEMENT = size;
  C.prototype.BYTES_PER_ELEMENT = size;
  Object.setPrototypeOf(C, __TypedArray);
  C.from = function (src, mapFn, thisArg) {
    var vals = Array.isArray(src) ? src : (typeof src === 'string' || (src !== null && typeof src === 'object' && typeof src[Symbol.iterator] === 'function')) ? [...src] : __taArr(src), i, r;
    if (mapFn) { vals = vals.map(function (v, j) { return mapFn.call(thisArg, v, j); }); }
    r = new C(vals.length);
    for (i = 0; i < vals.length; i++) r[i] = vals[i];
    return r;
  };
  C.of = function () { return C.from(__taArr(arguments)); };
  __taKinds[name] = C;
  return C;
}
function __init_bin() {
  var mkProto = function (o, name, fn) { Object.defineProperty(o, name, { value: fn, writable: true, configurable: true, enumerable: false }); };
  var getter = function (o, name, fn) { Object.defineProperty(o, name, { get: fn, configurable: true, enumerable: false }); };
  __taKinds = {};
  __ArrayBuffer = function ArrayBuffer(len) {
    if (new.target === undefined) throw new TypeError("Constructor ArrayBuffer requires 'new'");
    return __abnew(new.target.prototype, __taIdx(len === undefined ? 0 : len, 'array buffer length'));
  };
  __ArrayBuffer.prototype = {};
  mkProto(__ArrayBuffer.prototype, 'constructor', __ArrayBuffer);
  getter(__ArrayBuffer.prototype, 'byteLength', function () { return __tainfo(this, 4); });
  mkProto(__ArrayBuffer.prototype, 'slice', function (s, e) {
    var n = __tainfo(this, 4);
    s = s === undefined ? 0 : Math.trunc(Number(s)) || 0; e = e === undefined ? n : Math.trunc(Number(e)) || 0;
    if (s < 0) s = Math.max(n + s, 0); else s = Math.min(s, n);
    if (e < 0) e = Math.max(n + e, 0); else e = Math.min(e, n);
    var len = Math.max(e - s, 0), r = __abnew(__ArrayBuffer.prototype, len);
    __abcopy(r, 0, this, s, len);
    return r;
  });
  __ArrayBuffer.isView = function (v) { return v !== null && typeof v === 'object' && (__tainfo(v, 5) === 1 || v instanceof __DataView); };
  Object.defineProperty(__ArrayBuffer.prototype, '\x01Symbol.toStringTag\x02', { value: 'ArrayBuffer', enumerable: false });
  __SharedArrayBuffer = __ArrayBuffer;
  __TypedArray = function TypedArray() { throw new TypeError('Abstract class TypedArray not directly constructable'); };
  var TP = {};
  __TypedArray.prototype = TP;
  mkProto(TP, 'constructor', __TypedArray);
  getter(TP, 'buffer', function () { return __tainfo(__taCheck(this), 0); });
  getter(TP, 'byteOffset', function () { return __tainfo(__taCheck(this), 1); });
  getter(TP, 'length', function () { return __tainfo(__taCheck(this), 2); });
  getter(TP, 'byteLength', function () { return __tainfo(__taCheck(this), 2) * this.BYTES_PER_ELEMENT; });
  var spec = function (t) { return t.constructor; };
  var newLike = function (t, n) { return new (spec(t))(n); };
  mkProto(TP, 'at', function (i) { i = Math.trunc(Number(i)) || 0; if (i < 0) i += this.length; return this[i]; });
  mkProto(TP, 'fill', function (v, s, e) {
    var n = this.length, i;
    s = s === undefined ? 0 : (Math.trunc(Number(s)) || 0); e = e === undefined ? n : (Math.trunc(Number(e)) || 0);
    if (s < 0) s = Math.max(n + s, 0); else s = Math.min(s, n);
    if (e < 0) e = Math.max(n + e, 0); else e = Math.min(e, n);
    for (i = s; i < e; i++) this[i] = v;
    return this;
  });
  mkProto(TP, 'set', function (src, off) {
    var o = off === undefined ? 0 : (Math.trunc(Number(off)) || 0), n = src.length >>> 0, i, tmp;
    if (o < 0 || o + n > this.length) throw new RangeError('offset is out of bounds');
    tmp = __taArr(src);
    for (i = 0; i < n; i++) this[o + i] = tmp[i];
  });
  mkProto(TP, 'subarray', function (s, e) {
    var n = this.length, size = this.BYTES_PER_ELEMENT;
    s = s === undefined ? 0 : (Math.trunc(Number(s)) || 0); e = e === undefined ? n : (Math.trunc(Number(e)) || 0);
    if (s < 0) s = Math.max(n + s, 0); else s = Math.min(s, n);
    if (e < 0) e = Math.max(n + e, 0); else e = Math.min(e, n);
    return __tanew(Object.getPrototypeOf(this), this.buffer, this.byteOffset + s * size, Math.max(e - s, 0), __tainfo(this, 3));
  });
  mkProto(TP, 'slice', function (s, e) {
    var sub = this.subarray(s, e), r = newLike(this, sub.length), i;
    for (i = 0; i < sub.length; i++) r[i] = sub[i];
    return r;
  });
  mkProto(TP, 'copyWithin', function (target, start, end) {
    var n = this.length, to = target < 0 ? Math.max(n + target, 0) : Math.min(target, n), from = start < 0 ? Math.max(n + start, 0) : Math.min(start || 0, n);
    var fin = end === undefined ? n : (end < 0 ? Math.max(n + end, 0) : Math.min(end, n)), tmp = __taArr(this).slice(from, fin), i;
    for (i = 0; i < tmp.length && to + i < n; i++) this[to + i] = tmp[i];
    return this;
  });
  mkProto(TP, 'reverse', function () {
    var n = this.length, i, t;
    for (i = 0; i < n >> 1; i++) { t = this[i]; this[i] = this[n - 1 - i]; this[n - 1 - i] = t; }
    return this;
  });
  mkProto(TP, 'sort', function (f) {
    var a = __taArr(this), i;
    if (f === undefined) f = function (x, y) { return x < y ? -1 : x > y ? 1 : 0; };
    a.sort(f);
    for (i = 0; i < a.length; i++) this[i] = a[i];
    return this;
  });
  mkProto(TP, 'toSorted', function (f) { return this.slice().sort(f); });
  mkProto(TP, 'toReversed', function () { return this.slice().reverse(); });
  mkProto(TP, 'with', function (i, v) { var c = this.slice(); i = Math.trunc(Number(i)) || 0; if (i < 0) i += c.length; if (i < 0 || i >= c.length) throw new RangeError('Invalid typed array index'); c[i] = v; return c; });
  var arrM = ['forEach', 'indexOf', 'lastIndexOf', 'includes', 'join', 'find', 'findIndex', 'findLast', 'findLastIndex', 'every', 'some', 'reduce', 'reduceRight'];
  arrM.forEach(function (m) { mkProto(TP, m, function () { return Array.prototype[m].apply(__taArr(this), arguments); }); });
  mkProto(TP, 'map', function (f, t) {
    var r = newLike(this, this.length), i;
    for (i = 0; i < this.length; i++) r[i] = f.call(t, this[i], i, this);
    return r;
  });
  mkProto(TP, 'filter', function (f, t) {
    var out = [], i;
    for (i = 0; i < this.length; i++) if (f.call(t, this[i], i, this)) out.push(this[i]);
    var r = newLike(this, out.length);
    for (i = 0; i < out.length; i++) r[i] = out[i];
    return r;
  });
  mkProto(TP, 'keys', function () { return Array.prototype.keys.call(__taArr(this)); });
  mkProto(TP, 'values', function () { return Array.prototype.values.call(__taArr(this)); });
  mkProto(TP, 'entries', function () { return Array.prototype.entries.call(__taArr(this)); });
  TP[Symbol.iterator] = TP.values;
  mkProto(TP, 'toString', function () { return Array.prototype.join.call(this, ','); });
  mkProto(TP, 'toLocaleString', function () { return Array.prototype.join.call(this, ','); });
  getter(TP, '\x01Symbol.toStringTag\x02', function () { return this.constructor.name; });
  __Int8Array = __mkTA('Int8Array', 0, 1);
  __Uint8Array = __mkTA('Uint8Array', 1, 1);
  __Uint8ClampedArray = __mkTA('Uint8ClampedArray', 2, 1);
  __Int16Array = __mkTA('Int16Array', 3, 2);
  __Uint16Array = __mkTA('Uint16Array', 4, 2);
  __Int32Array = __mkTA('Int32Array', 5, 4);
  __Uint32Array = __mkTA('Uint32Array', 6, 4);
  __Float32Array = __mkTA('Float32Array', 7, 4);
  __Float64Array = __mkTA('Float64Array', 8, 8);
  __BigInt64Array = function BigInt64Array() { throw new TypeError('BigInt64Array n\'est pas pris en charge par JSCW32'); };
  __BigUint64Array = function BigUint64Array() { throw new TypeError('BigUint64Array n\'est pas pris en charge par JSCW32'); };
  // DataView
  __DataView = function DataView(buf, off, len) {
    if (new.target === undefined) throw new TypeError("Constructor DataView requires 'new'");
    if (__tainfo(buf, 5) !== 2) throw new TypeError('First argument to DataView constructor must be an ArrayBuffer');
    off = off === undefined ? 0 : __taIdx(off, 'DataView offset');
    var bl = __tainfo(buf, 4);
    if (off > bl) throw new RangeError('Start offset ' + off + ' is outside the bounds of the buffer');
    len = len === undefined ? bl - off : __taIdx(len, 'DataView length');
    if (off + len > bl) throw new RangeError('Invalid DataView length ' + len);
    this['\x01b'] = buf; this['\x01o'] = off; this['\x01n'] = len;
    Object.defineProperty(this, '\x01b', { enumerable: false }); Object.defineProperty(this, '\x01o', { enumerable: false }); Object.defineProperty(this, '\x01n', { enumerable: false });
  };
  var DP = {};
  __DataView.prototype = DP;
  mkProto(DP, 'constructor', __DataView);
  Object.defineProperty(DP, '\x01Symbol.toStringTag\x02', { value: 'DataView', enumerable: false });
  getter(DP, 'buffer', function () { return this['\x01b']; });
  getter(DP, 'byteOffset', function () { return this['\x01o']; });
  getter(DP, 'byteLength', function () { return this['\x01n']; });
  var dvk = [['Int8', 0, 1], ['Uint8', 1, 1], ['Int16', 3, 2], ['Uint16', 4, 2], ['Int32', 5, 4], ['Uint32', 6, 4], ['Float32', 7, 4], ['Float64', 8, 8]];
  dvk.forEach(function (d) {
    mkProto(DP, 'get' + d[0], function (pos, little) {
      pos = __taIdx(pos, 'offset');
      if (pos + d[2] > this['\x01n']) throw new RangeError('Offset is outside the bounds of the DataView');
      return __abget(this['\x01b'], this['\x01o'] + pos, d[1], !!little);
    });
    mkProto(DP, 'set' + d[0], function (pos, v, little) {
      pos = __taIdx(pos, 'offset');
      if (pos + d[2] > this['\x01n']) throw new RangeError('Offset is outside the bounds of the DataView');
      __abset(this['\x01b'], this['\x01o'] + pos, d[1], v, !!little);
    });
  });
  mkProto(DP, 'getBigInt64', function (pos, little) {
    var lo = this.getUint32(pos + (little ? 0 : 4), little), hi = this.getUint32(pos + (little ? 4 : 0), little);
    return BigInt.asIntN(64, (BigInt(hi) << 32n) | BigInt(lo));
  });
  mkProto(DP, 'getBigUint64', function (pos, little) {
    var lo = this.getUint32(pos + (little ? 0 : 4), little), hi = this.getUint32(pos + (little ? 4 : 0), little);
    return (BigInt(hi) << 32n) | BigInt(lo);
  });
  mkProto(DP, 'setBigInt64', function (pos, v, little) {
    v = BigInt.asUintN(64, BigInt(v));
    this.setUint32(pos + (little ? 0 : 4), Number(v & 0xFFFFFFFFn), little);
    this.setUint32(pos + (little ? 4 : 0), Number(v >> 32n), little);
  });
  DP.setBigUint64 = DP.setBigInt64;
  // Atomics (monothread : operations simples)
  __Atomics = {
    add: function (t, i, v) { var o = t[i]; t[i] = o + v; return o; },
    sub: function (t, i, v) { var o = t[i]; t[i] = o - v; return o; },
    and: function (t, i, v) { var o = t[i]; t[i] = o & v; return o; },
    or: function (t, i, v) { var o = t[i]; t[i] = o | v; return o; },
    xor: function (t, i, v) { var o = t[i]; t[i] = o ^ v; return o; },
    load: function (t, i) { return t[i]; },
    store: function (t, i, v) { t[i] = v; return v; },
    exchange: function (t, i, v) { var o = t[i]; t[i] = v; return o; },
    compareExchange: function (t, i, e, v) { var o = t[i]; if (o === e) t[i] = v; return o; },
    isLockFree: function () { return true; },
    notify: function () { return 0; },
    wait: function () { return 'timed-out'; }
  };
  // TextEncoder / TextDecoder (UTF-8)
  __TextEncoder = function TextEncoder() { };
  getter(__TextEncoder.prototype, 'encoding', function () { return 'utf-8'; });
  mkProto(__TextEncoder.prototype, 'encode', function (s) {
    s = s === undefined ? '' : String(s);
    var bytes = __b2u8(s), r = new __Uint8Array(bytes.length), i;
    for (i = 0; i < bytes.length; i++) r[i] = bytes[i];
    return r;
  });
  mkProto(__TextEncoder.prototype, 'encodeInto', function (s, dest) {
    var b = this.encode(s), n = Math.min(b.length, dest.length), i;
    for (i = 0; i < n; i++) dest[i] = b[i];
    return { read: s.length, written: n };
  });
  __TextDecoder = function TextDecoder(label, opts) {
    this.encoding = (label === undefined ? 'utf-8' : String(label).toLowerCase()).replace('utf8', 'utf-8');
    this.fatal = !!(opts && opts.fatal);
    this.ignoreBOM = !!(opts && opts.ignoreBOM);
  };
  mkProto(__TextDecoder.prototype, 'decode', function (b) {
    if (b === undefined) return '';
    var a;
    if (__tainfo(b, 5) === 2) a = new __Uint8Array(b);
    else if (b instanceof __DataView) a = new __Uint8Array(b.buffer, b.byteOffset, b.byteLength);
    else a = new __Uint8Array(b.buffer, b.byteOffset, b.byteLength);
    var s = __u82s(a, this.fatal);
    if (!this.ignoreBOM && s.charCodeAt(0) === 65279) s = s.slice(1);
    return s;
  });
  var gt = globalThis;
  gt.ArrayBuffer = __ArrayBuffer; gt.SharedArrayBuffer = __SharedArrayBuffer; gt.DataView = __DataView; gt.Atomics = __Atomics;
  gt.Int8Array = __Int8Array; gt.Uint8Array = __Uint8Array; gt.Uint8ClampedArray = __Uint8ClampedArray; gt.Int16Array = __Int16Array;
  gt.Uint16Array = __Uint16Array; gt.Int32Array = __Int32Array; gt.Uint32Array = __Uint32Array; gt.Float32Array = __Float32Array;
  gt.Float64Array = __Float64Array; gt.BigInt64Array = __BigInt64Array; gt.BigUint64Array = __BigUint64Array;
  gt.TextEncoder = __TextEncoder; gt.TextDecoder = __TextDecoder;
  __initBuffer();
  gt.Buffer = __Buffer;
}
// chaine -> octets UTF-8 (tableau de nombres)
function __b2u8(s) {
  var out = [], i, c, d;
  for (i = 0; i < s.length; i++) {
    c = s.charCodeAt(i);
    if (c >= 55296 && c <= 56319 && i + 1 < s.length) {
      d = s.charCodeAt(i + 1);
      if (d >= 56320 && d <= 57343) { c = 65536 + ((c - 55296) << 10) + (d - 56320); i++; }
      else c = 65533;
    } else if (c >= 55296 && c <= 57343) c = 65533;
    if (c < 128) out.push(c);
    else if (c < 2048) out.push(192 | (c >> 6), 128 | (c & 63));
    else if (c < 65536) out.push(224 | (c >> 12), 128 | ((c >> 6) & 63), 128 | (c & 63));
    else out.push(240 | (c >> 18), 128 | ((c >> 12) & 63), 128 | ((c >> 6) & 63), 128 | (c & 63));
  }
  return out;
}
function __u82s(a, fatal) {
  var out = '', i = 0, n = a.length, c, need, cp, k, b;
  while (i < n) {
    c = a[i++];
    if (c < 128) { out += String.fromCharCode(c); continue; }
    if (c >= 194 && c < 224) { need = 1; cp = c & 31; }
    else if (c >= 224 && c < 240) { need = 2; cp = c & 15; }
    else if (c >= 240 && c < 245) { need = 3; cp = c & 7; }
    else { if (fatal) throw new TypeError('The encoded data was not valid for encoding utf-8'); out += '�'; continue; }
    for (k = 0; k < need; k++) {
      b = a[i];
      if (b === undefined || (b & 192) !== 128) break;
      cp = (cp << 6) | (b & 63);
      i++;
    }
    if (k < need || (need === 2 && (cp < 2048 || (cp >= 55296 && cp <= 57343))) || (need === 3 && (cp < 65536 || cp > 1114111))) {
      if (fatal) throw new TypeError('The encoded data was not valid for encoding utf-8');
      out += '�';
      continue;
    }
    if (cp >= 65536) { cp -= 65536; out += String.fromCharCode(55296 + (cp >> 10), 56320 + (cp & 1023)); }
    else out += String.fromCharCode(cp);
  }
  return out;
}
function __bufNew(len) { return __tanew(__Buffer.prototype, __abnew(__ArrayBuffer.prototype, len), 0, len, 1); }
function __bufEnc(e) {
  e = e === undefined ? 'utf8' : String(e).toLowerCase();
  if (e === 'utf-8') return 'utf8';
  if (e === 'binary') return 'latin1';
  if (e === 'ucs2' || e === 'ucs-2' || e === 'utf-16le') return 'utf16le';
  if (e === 'utf8' || e === 'hex' || e === 'base64' || e === 'base64url' || e === 'latin1' || e === 'ascii' || e === 'utf16le') return e;
  var er = new TypeError('Unknown encoding: ' + e);
  er.code = 'ERR_UNKNOWN_ENCODING';
  throw er;
}
function __strBytes(s, enc) {
  var out = [], i, c;
  s = String(s);
  switch (__bufEnc(enc)) {
    case 'utf8': return __b2u8(s);
    case 'hex':
      for (i = 0; i + 1 < s.length; i += 2) {
        c = parseInt(s.substr(i, 2), 16);
        if (isNaN(c) || !/^[0-9a-fA-F]{2}$/.test(s.substr(i, 2))) break;
        out.push(c);
      }
      return out;
    case 'base64': case 'base64url':
      s = s.replace(/-/g, '+').replace(/_/g, '/').replace(/[^A-Za-z0-9+\/]/g, '');
      var bin = __atobLoose(s);
      for (i = 0; i < bin.length; i++) out.push(bin.charCodeAt(i));
      return out;
    case 'latin1': case 'ascii':
      for (i = 0; i < s.length; i++) out.push(s.charCodeAt(i) & 255);
      return out;
    case 'utf16le':
      for (i = 0; i < s.length; i++) { c = s.charCodeAt(i); out.push(c & 255, c >> 8); }
      return out;
  }
  return out;
}
function __atobLoose(s) {
  var tbl = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', out = '', i, v, bits = 0, acc = 0;
  for (i = 0; i < s.length; i++) {
    v = tbl.indexOf(s.charAt(i));
    acc = (acc << 6) | v; bits += 6;
    if (bits >= 8) { bits -= 8; out += String.fromCharCode((acc >> bits) & 255); }
  }
  return out;
}
function __bufFromBytes(arr) {
  var b = __bufNew(arr.length), i;
  for (i = 0; i < arr.length; i++) b[i] = arr[i];
  return b;
}
function __initBuffer() {
  var B = function Buffer(a, b, c) {
    if (typeof a === 'number') return __Buffer.alloc(a);
    return __Buffer.from(a, b, c);
  };
  __Buffer = B;
  var BP = Object.create(__Uint8Array.prototype);
  B.prototype = BP;
  Object.setPrototypeOf(B, __Uint8Array);
  var def = function (o, n, f) { Object.defineProperty(o, n, { value: f, writable: true, configurable: true, enumerable: false }); };
  def(BP, 'constructor', B);
  B.poolSize = 8192;
  B.isBuffer = function (v) { return v !== null && typeof v === 'object' && Object.getPrototypeOf(v) === BP; };
  B.isEncoding = function (e) { try { __bufEnc(e); return typeof e === 'string'; } catch (x) { return false; } };
  B.alloc = function (n, fill, enc) {
    if (typeof n !== 'number' || n < 0 || n !== n) { var e = new TypeError('The "size" argument must be of type number. Received ' + (typeof n === 'number' ? n : typeof n)); e.code = 'ERR_INVALID_ARG_TYPE'; throw e; }
    var b = __bufNew(n);
    if (fill !== undefined && n > 0) b.fill(fill, 0, n, enc);
    return b;
  };
  B.allocUnsafe = function (n) { return B.alloc(n); };
  B.allocUnsafeSlow = B.allocUnsafe;
  B.from = function (v, a, b) {
    var arr, t, i;
    if (typeof v === 'string') return __bufFromBytes(__strBytes(v, a));
    if (v === null || v === undefined || (typeof v !== 'object' && typeof v !== 'function')) {
      var got = v === null ? 'null' : typeof v === 'undefined' ? 'undefined' : 'type ' + typeof v + ' (' + String(v) + ')';
      var er = new TypeError('The first argument must be of type string or an instance of Buffer, ArrayBuffer, or Array or an Array-like Object. Received ' + got);
      er.code = 'ERR_INVALID_ARG_TYPE';
      throw er;
    }
    t = __tainfo(v, 5);
    if (t === 2) {
      var off = a === undefined ? 0 : __taIdx(a, 'offset'), len = b === undefined ? __tainfo(v, 4) - off : __taIdx(b, 'length');
      return __tanew(BP, v, off, len, 1);
    }
    if (t === 1) { arr = []; for (i = 0; i < v.length; i++) arr.push(v[i]); return __bufFromBytes(arr); }
    if (v.type === 'Buffer' && Array.isArray(v.data)) return __bufFromBytes(v.data);
    if (Array.isArray(v)) return __bufFromBytes(v);
    if (typeof v.length === 'number') { arr = []; for (i = 0; i < v.length; i++) arr.push(v[i]); return __bufFromBytes(arr); }
    if (typeof v[Symbol.iterator] === 'function') return __bufFromBytes([...v]);
    return __bufFromBytes([]);
  };
  B.byteLength = function (s, enc) {
    if (typeof s !== 'string') return s.byteLength;
    return __strBytes(s, enc).length;
  };
  B.concat = function (list, total) {
    var n = 0, i, j, pos = 0;
    for (i = 0; i < list.length; i++) n += list[i].length;
    if (total !== undefined) n = total;
    var r = __bufNew(n);
    for (i = 0; i < list.length && pos < n; i++) for (j = 0; j < list[i].length && pos < n; j++) r[pos++] = list[i][j];
    return r;
  };
  B.compare = function (a, b) {
    var n = Math.min(a.length, b.length), i;
    for (i = 0; i < n; i++) if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
    return a.length < b.length ? -1 : a.length > b.length ? 1 : 0;
  };
  def(BP, 'toString', function (enc, s, e) {
    var n = this.length, i, out;
    s = s === undefined ? 0 : Math.max(0, Math.min(n, Math.trunc(Number(s)) || 0)); e = e === undefined ? n : Math.max(s, Math.min(n, Math.trunc(Number(e)) || 0));
    enc = __bufEnc(enc);
    var a = [];
    for (i = s; i < e; i++) a.push(this[i]);
    switch (enc) {
      case 'utf8': return __u82s(a, false);
      case 'hex': out = ''; for (i = 0; i < a.length; i++) out += (a[i] < 16 ? '0' : '') + a[i].toString(16); return out;
      case 'base64': case 'base64url':
        out = '';
        for (i = 0; i < a.length; i++) out += String.fromCharCode(a[i]);
        out = __btoa(out);
        if (enc === 'base64url') out = out.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
        return out;
      case 'latin1': out = ''; for (i = 0; i < a.length; i++) out += String.fromCharCode(a[i]); return out;
      case 'ascii': out = ''; for (i = 0; i < a.length; i++) out += String.fromCharCode(a[i] & 127); return out;
      case 'utf16le': out = ''; for (i = 0; i + 1 < a.length; i += 2) out += String.fromCharCode(a[i] | (a[i + 1] << 8)); return out;
    }
    return '';
  });
  def(BP, 'toJSON', function () { var d = [], i; for (i = 0; i < this.length; i++) d.push(this[i]); return { type: 'Buffer', data: d }; });
  def(BP, 'equals', function (o) { return B.compare(this, o) === 0; });
  def(BP, 'compare', function (o) { return B.compare(this, o); });
  def(BP, 'slice', function (s, e) { return this.subarray(s, e); });
  def(BP, 'fill', function (v, s, e, enc) {
    var n = this.length, i, bytes;
    if (typeof s === 'string') { enc = s; s = 0; e = n; }
    s = s === undefined ? 0 : s; e = e === undefined ? n : e;
    if (typeof v === 'string') {
      bytes = __strBytes(v, enc);
      if (bytes.length === 0) bytes = [0];
      for (i = s; i < e; i++) this[i] = bytes[(i - s) % bytes.length];
    } else if (__tainfo(v, 5) === 1) {
      for (i = s; i < e; i++) this[i] = v[(i - s) % v.length];
    } else for (i = s; i < e; i++) this[i] = v & 255;
    return this;
  });
  def(BP, 'write', function (str, off, len, enc) {
    if (typeof off === 'string') { enc = off; off = 0; len = undefined; }
    else if (typeof len === 'string') { enc = len; len = undefined; }
    off = off === undefined ? 0 : off;
    var bytes = __strBytes(str, enc), n = Math.min(bytes.length, this.length - off, len === undefined ? Infinity : len), i;
    for (i = 0; i < n; i++) this[off + i] = bytes[i];
    return n;
  });
  def(BP, 'copy', function (target, ts, ss, se) {
    ts = ts === undefined ? 0 : ts; ss = ss === undefined ? 0 : ss; se = se === undefined ? this.length : se;
    var n = Math.min(se - ss, target.length - ts), i, tmp = [];
    for (i = 0; i < n; i++) tmp.push(this[ss + i]);
    for (i = 0; i < n; i++) target[ts + i] = tmp[i];
    return n < 0 ? 0 : n;
  });
  def(BP, 'indexOf', function (v, from, enc) {
    var needle, i, j, n = this.length;
    if (typeof v === 'number') needle = [v & 255];
    else if (typeof v === 'string') needle = __strBytes(v, enc);
    else { needle = []; for (i = 0; i < v.length; i++) needle.push(v[i]); }
    from = from === undefined ? 0 : (from < 0 ? Math.max(n + from, 0) : from);
    for (i = from; i + needle.length <= n; i++) {
      for (j = 0; j < needle.length && this[i + j] === needle[j]; j++);
      if (j === needle.length) return i;
    }
    return -1;
  });
  def(BP, 'includes', function (v, from, enc) { return this.indexOf(v, from, enc) !== -1; });
  def(BP, 'lastIndexOf', function (v, from, enc) {
    var needle, i, j, n = this.length;
    if (typeof v === 'number') needle = [v & 255]; else if (typeof v === 'string') needle = __strBytes(v, enc); else { needle = []; for (i = 0; i < v.length; i++) needle.push(v[i]); }
    for (i = (from === undefined ? n - needle.length : Math.min(from, n - needle.length)); i >= 0; i--) {
      for (j = 0; j < needle.length && this[i + j] === needle[j]; j++);
      if (j === needle.length) return i;
    }
    return -1;
  });
  var chk = function (b, off, n) {
    off = off === undefined ? 0 : off;
    if (typeof off !== 'number' || off % 1 !== 0) { var e = new TypeError('The "offset" argument must be of type number. Received ' + String(off)); e.code = 'ERR_INVALID_ARG_TYPE'; throw e; }
    if (off < 0 || off + n > b.length) { var r = new RangeError('The value of "offset" is out of range. It must be >= 0 and <= ' + (b.length - n) + '. Received ' + off); r.code = 'ERR_OUT_OF_RANGE'; throw r; }
    return off;
  };
  var dv = function (b) { return new __DataView(b.buffer, b.byteOffset, b.byteLength); };
  var rw = [['UInt8', 'Uint8', 1], ['Int8', 'Int8', 1], ['UInt16', 'Uint16', 2], ['Int16', 'Int16', 2], ['UInt32', 'Uint32', 4], ['Int32', 'Int32', 4], ['Float', 'Float32', 4], ['Double', 'Float64', 8]];
  rw.forEach(function (d) {
    var ends = d[2] === 1 ? [''] : ['LE', 'BE'];
    ends.forEach(function (en) {
      var little = en === 'LE';
      def(BP, 'read' + d[0] + en, function (off) { off = chk(this, off, d[2]); return dv(this)['get' + d[1]](off, little); });
      def(BP, 'write' + d[0] + en, function (v, off) { off = chk(this, off, d[2]); dv(this)['set' + d[1]](off, v, little); return off + d[2]; });
      if (d[0].slice(0, 4) === 'UInt') {
        def(BP, 'read' + d[0].replace('UInt', 'Uint') + en, BP['read' + d[0] + en]);
        def(BP, 'write' + d[0].replace('UInt', 'Uint') + en, BP['write' + d[0] + en]);
      }
    });
  });
  def(BP, 'readBigUInt64LE', function (off) { return dv(this).getBigUint64(chk(this, off, 8), true); });
  def(BP, 'readBigUInt64BE', function (off) { return dv(this).getBigUint64(chk(this, off, 8), false); });
  def(BP, 'readBigInt64LE', function (off) { return dv(this).getBigInt64(chk(this, off, 8), true); });
  def(BP, 'readBigInt64BE', function (off) { return dv(this).getBigInt64(chk(this, off, 8), false); });
  def(BP, 'writeBigUInt64LE', function (v, off) { dv(this).setBigUint64(chk(this, off, 8), v, true); return off + 8; });
  def(BP, 'writeBigUInt64BE', function (v, off) { dv(this).setBigUint64(chk(this, off, 8), v, false); return off + 8; });
  def(BP, 'writeBigInt64LE', function (v, off) { dv(this).setBigInt64(chk(this, off, 8), v, true); return off + 8; });
  def(BP, 'writeBigInt64BE', function (v, off) { dv(this).setBigInt64(chk(this, off, 8), v, false); return off + 8; });
  def(BP, 'swap16', function () { var i, t; for (i = 0; i + 1 < this.length; i += 2) { t = this[i]; this[i] = this[i + 1]; this[i + 1] = t; } return this; });
  def(BP, 'swap32', function () { var i, t; for (i = 0; i + 3 < this.length; i += 4) { t = this[i]; this[i] = this[i + 3]; this[i + 3] = t; t = this[i + 1]; this[i + 1] = this[i + 2]; this[i + 2] = t; } return this; });
}
