var __wk_n, __fpts, __symproto, __newfn, __GenProto, __TOMB, __Symbol, __Map, __Set, __WeakMap, __WeakSet, __IterProto, __sym_n, __sym_reg;
function __mk(k) {
  var t = typeof k;
  if (t === 'string') return 's' + k;
  if (t === 'number') return 'n' + String(k);
  if (t === 'object' || t === 'function') return k === null ? 'l' : 'o' + __ptr(k);
  if (t === 'symbol') return 'y' + k;
  return t.charAt(0) + String(k);
}
function __mkiter(next) {
  var it = Object.create(__IterProto);
  it['\x01n'] = next;
  return it;
}
function __sym_desc(s) {
  var e = s.indexOf('\x02');
  return s.slice(1, e < 0 ? s.length : e);
}
function __sym_str(s) {
  return 'Symbol(' + __sym_desc(s) + ')';
}
function __init_eval() {}
function __init_web() {}
function __init_bin() {}
function __withrun() { return undefined; }
function __evlocal(x) { return x; }
function __toFixed() { throw new Error("__toFixed: module non charge"); }
function __toPrecision() { throw new Error("__toPrecision: module non charge"); }
function __toExponential() { throw new Error("__toExponential: module non charge"); }
function __uriEnc() { throw new Error("__uriEnc: module non charge"); }
function __uriDec() { throw new Error("__uriDec: module non charge"); }
function __btoa() { throw new Error("__btoa: module non charge"); }
function __atob() { throw new Error("__atob: module non charge"); }
function __init_proxy() {}
function __init_uni() {}
function __init_norm() {}
var __uprop;
function __init_fs() {}
function __init_intl() {}
function __init_il_cs() {}
function __init_il_da() {}
function __init_il_de() {}
function __init_il_el() {}
function __init_il_en() {}
function __init_il_es() {}
function __init_il_fi() {}
function __init_il_fr() {}
function __init_il_he() {}
function __init_il_hi() {}
function __init_il_hu() {}
function __init_il_id() {}
function __init_il_it() {}
function __init_il_ja() {}
function __init_il_ko() {}
function __init_il_nb() {}
function __init_il_nl() {}
function __init_il_pl() {}
function __init_il_pt() {}
function __init_il_ru() {}
function __init_il_sv() {}
function __init_il_tr() {}
function __init_il_uk() {}
function __init_il_zh() {}
function __ilreg() {}
function __intlDate() { return null; }
function __intlNum() { return null; }
var __proxyOp, __Proxy;
var __global;
function __i_init() {
  __init_async();
  __init_eval();
  __init_lib();
  __init_big();
  __init_str();
  var FP = __fproto();
  FP.call = function (t, ...a) { return __invoke(this, t, a); };
  FP.apply = function (t, a) { return __invoke(this, t, a === undefined || a === null ? [] : a); };
  FP.bind = function (t, ...a) {
    var f = this;
    return function (...b) { return __invoke(f, t, a.concat(b)); };
  };
  FP.toString = function () { var src = __fsrc(this); return src !== undefined ? src : 'function ' + this.name + '() { [native code] }'; };
  __fpts = FP.toString;
  var __cl = [[Object, 0], [Array, 0], [String, 0], [Number, 0], [Boolean, 0], [RegExp, 0], [Function, 0], [Error, 0], [EvalError, 0], [RangeError, 0],
    [ReferenceError, 0], [SyntaxError, 0], [TypeError, 0], [URIError, 0]];
  for (var __ci = 0; __ci < __cl.length; __ci++) {
    var __cp = __cl[__ci][0].prototype;
    if (__cp) Object.defineProperty(__cp, 'constructor', { value: __cl[__ci][0], writable: true, configurable: true, enumerable: false });
  }
  __IterProto = {
    next: function () { return this['\x01n'](); },
    toString: function () { return '[object Iterator]'; }
  };
  __IterProto['\x01Symbol.iterator\x02'] = function () { return this; };
  __Symbol = function Symbol(desc) {
    __sym_n = (__sym_n || 0) + 1;
    return '\x01' + (desc === undefined ? '' : String(desc)) + '\x02' + __sym_n;
  };
  __Symbol.iterator = '\x01Symbol.iterator\x02';
  __Symbol.asyncIterator = '\x01Symbol.asyncIterator\x02';
  __Symbol.hasInstance = '\x01Symbol.hasInstance\x02';
  __Symbol.toPrimitive = '\x01Symbol.toPrimitive\x02';
  __Symbol.toStringTag = '\x01Symbol.toStringTag\x02';
  __Symbol['for'] = function (key) {
    __sym_reg = __sym_reg || {};
    var k = String(key);
    if (__sym_reg[k] === undefined) __sym_reg[k] = '\x01' + k + '\x02';
    return __sym_reg[k];
  };
  __Symbol.keyFor = function (s) {
    var d = __sym_desc(s);
    return __sym_reg && __sym_reg[d] === s ? d : undefined;
  };
  __symproto = Object.create(String.prototype);
  Object.defineProperty(__symproto, 'constructor', { value: __Symbol, writable: true, configurable: true, enumerable: false });
  Object.defineProperty(__symproto, 'toString', { value: function () { return __sym_str(this); }, writable: true, configurable: true, enumerable: false });
  Object.defineProperty(__symproto, 'valueOf', { value: function () { return this; }, writable: true, configurable: true, enumerable: false });
  Object.defineProperty(__symproto, 'description', { get: function () { return __sym_desc(this); }, configurable: true, enumerable: false });
  __Symbol.prototype = __symproto;
  var SI = '\x01Symbol.iterator\x02';
  Object.defineProperty(Array.prototype, SI, { value: Array.prototype.values, writable: true, configurable: true, enumerable: false });
  Object.defineProperty(String.prototype, SI, { value: function () { return [...String(this)].values(); }, writable: true, configurable: true, enumerable: false });
  __GenProto = {
    next: function (v) { var x = __gen_resume(this, 0, v); return { value: x, done: __gen_done(this) }; },
    'return': function (v) { var x = __gen_resume(this, 2, v); return { value: x, done: true }; },
    'throw': function (e) { var x = __gen_resume(this, 1, e); return { value: x, done: __gen_done(this) }; },
    toString: function () { return '[object Generator]'; }
  };
  __GenProto[SI] = function () { return this; };
  var TOMB = {};
  __TOMB = TOMB;
  __Map = class Map {
    constructor(iterable) {
      this['\x01k'] = [];
      this['\x01v'] = [];
      this['\x01i'] = {};
      this['\x01n'] = 0;
      if (iterable !== undefined && iterable !== null) {
        for (const e of iterable) this.set(e[0], e[1]);
      }
    }
    get size() { return this['\x01n']; }
    get(k) {
      var p = this['\x01i'][__mk(k)];
      return p === undefined ? undefined : this['\x01v'][p];
    }
    has(k) { return this['\x01i'][__mk(k)] !== undefined; }
    set(k, v) {
      var m = __mk(k);
      var p = this['\x01i'][m];
      if (p === undefined) {
        this['\x01i'][m] = this['\x01k'].length;
        this['\x01k'].push(k === 0 ? 0 : k);
        this['\x01v'].push(v);
        this['\x01n']++;
      } else this['\x01v'][p] = v;
      return this;
    }
    delete(k) {
      var m = __mk(k);
      var p = this['\x01i'][m];
      if (p === undefined) return false;
      delete this['\x01i'][m];
      this['\x01k'][p] = TOMB;
      this['\x01v'][p] = undefined;
      this['\x01n']--;
      return true;
    }
    clear() {
      this['\x01k'] = [];
      this['\x01v'] = [];
      this['\x01i'] = {};
      this['\x01n'] = 0;
    }
    forEach(cb, thisArg) {
      for (var i = 0; i < this['\x01k'].length; i++) {
        if (this['\x01k'][i] !== TOMB) cb.call(thisArg, this['\x01v'][i], this['\x01k'][i], this);
      }
    }
    entries() { return this['\x01it'](2); }
    keys() { return this['\x01it'](0); }
    values() { return this['\x01it'](1); }
    ['\x01it'](kind) {
      var self = this;
      var i = 0;
      return __mkiter(function () {
        while (i < self['\x01k'].length && self['\x01k'][i] === TOMB) i++;
        if (i >= self['\x01k'].length) return { value: undefined, done: true };
        var r = kind === 0 ? self['\x01k'][i] : kind === 1 ? self['\x01v'][i] : [self['\x01k'][i], self['\x01v'][i]];
        i++;
        return { value: r, done: false };
      });
    }
  };
  __Map.prototype[SI] = __Map.prototype.entries;
  __Map.prototype['\x01Symbol.toStringTag\x02'] = 'Map';
  __Set = class Set {
    constructor(iterable) {
      this['\x01k'] = [];
      this['\x01i'] = {};
      this['\x01n'] = 0;
      if (iterable !== undefined && iterable !== null) {
        for (const e of iterable) this.add(e);
      }
    }
    get size() { return this['\x01n']; }
    has(k) { return this['\x01i'][__mk(k)] !== undefined; }
    add(k) {
      var m = __mk(k);
      if (this['\x01i'][m] === undefined) {
        this['\x01i'][m] = this['\x01k'].length;
        this['\x01k'].push(k === 0 ? 0 : k);
        this['\x01n']++;
      }
      return this;
    }
    delete(k) {
      var m = __mk(k);
      var p = this['\x01i'][m];
      if (p === undefined) return false;
      delete this['\x01i'][m];
      this['\x01k'][p] = TOMB;
      this['\x01n']--;
      return true;
    }
    clear() {
      this['\x01k'] = [];
      this['\x01i'] = {};
      this['\x01n'] = 0;
    }
    forEach(cb, thisArg) {
      for (var i = 0; i < this['\x01k'].length; i++) {
        if (this['\x01k'][i] !== TOMB) cb.call(thisArg, this['\x01k'][i], this['\x01k'][i], this);
      }
    }
    values() { return this['\x01it'](false); }
    keys() { return this['\x01it'](false); }
    entries() { return this['\x01it'](true); }
    ['\x01it'](pairs) {
      var self = this;
      var i = 0;
      return __mkiter(function () {
        while (i < self['\x01k'].length && self['\x01k'][i] === TOMB) i++;
        if (i >= self['\x01k'].length) return { value: undefined, done: true };
        var r = pairs ? [self['\x01k'][i], self['\x01k'][i]] : self['\x01k'][i];
        i++;
        return { value: r, done: false };
      });
    }
  };
  __Set.prototype[SI] = __Set.prototype.values;
  __WeakMap = class WeakMap {
    constructor(iterable) {
      __wk_n = (__wk_n || 0) + 1;
      Object.defineProperty(this, '\x01id', { value: '\x01w' + __wk_n, enumerable: false });
      if (iterable !== undefined && iterable !== null) {
        for (const e of iterable) this.set(e[0], e[1]);
      }
    }
    get(k) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) return undefined;
      var v = __hget(k, this['\x01id'], __TOMB);
      if (v !== __TOMB) return v;
      var f = this['\x01f'];
      return f === undefined ? undefined : f.get(k);
    }
    has(k) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) return false;
      if (__hget(k, this['\x01id'], __TOMB) !== __TOMB) return true;
      var f = this['\x01f'];
      return f !== undefined && f.has(k);
    }
    set(k, v) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) throw new TypeError('Invalid value used as weak map key');
      if (!__hset(k, this['\x01id'], v)) {
        if (this['\x01f'] === undefined) Object.defineProperty(this, '\x01f', { value: new __Map(), enumerable: false });
        this['\x01f'].set(k, v);
      }
      return this;
    }
    delete(k) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) return false;
      if (__hget(k, this['\x01id'], __TOMB) !== __TOMB) { __hset(k, this['\x01id'], __TOMB); return true; }
      var f = this['\x01f'];
      return f !== undefined && f.delete(k);
    }
  };
  __WeakSet = class WeakSet {
    constructor(iterable) {
      __wk_n = (__wk_n || 0) + 1;
      Object.defineProperty(this, '\x01id', { value: '\x01w' + __wk_n, enumerable: false });
      if (iterable !== undefined && iterable !== null) {
        for (const e of iterable) this.add(e);
      }
    }
    has(k) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) return false;
      if (__hget(k, this['\x01id'], __TOMB) !== __TOMB) return true;
      var f = this['\x01f'];
      return f !== undefined && f.has(k);
    }
    add(k) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) throw new TypeError('Invalid value used in weak set');
      if (!__hset(k, this['\x01id'], true)) {
        if (this['\x01f'] === undefined) Object.defineProperty(this, '\x01f', { value: new __Set(), enumerable: false });
        this['\x01f'].add(k);
      }
      return this;
    }
    delete(k) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) return false;
      if (__hget(k, this['\x01id'], __TOMB) !== __TOMB) { __hset(k, this['\x01id'], __TOMB); return true; }
      var f = this['\x01f'];
      return f !== undefined && f.delete(k);
    }
  };
  __init_web();
  __init_bin();
  __init_proxy();
  __init_uni();
  __init_norm();
  __init_fs();
  __init_globals();
  __init_intl();
}
