var __GenProto, __TOMB, __Symbol, __Map, __Set, __WeakMap, __WeakSet, __IterProto, __sym_n, __sym_reg;
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
function __i_init() {
  __init_async();
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
  FP.toString = function () { return 'function ' + this.name + '() { [native code] }'; };
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
  var SI = '\x01Symbol.iterator\x02';
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
      this['\x01i'] = {};
      if (iterable !== undefined && iterable !== null) {
        for (const e of iterable) this.set(e[0], e[1]);
      }
    }
    get(k) { var e = this['\x01i'][__mk(k)]; return e === undefined ? undefined : e[0]; }
    has(k) { return this['\x01i'][__mk(k)] !== undefined; }
    set(k, v) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) throw new TypeError('Invalid value used as weak map key');
      this['\x01i'][__mk(k)] = [v];
      return this;
    }
    delete(k) {
      var m = __mk(k);
      if (this['\x01i'][m] === undefined) return false;
      delete this['\x01i'][m];
      return true;
    }
  };
  __WeakSet = class WeakSet {
    constructor(iterable) {
      this['\x01i'] = {};
      if (iterable !== undefined && iterable !== null) {
        for (const e of iterable) this.add(e);
      }
    }
    has(k) { return this['\x01i'][__mk(k)] !== undefined; }
    add(k) {
      if (typeof k !== 'object' && typeof k !== 'function' || k === null) throw new TypeError('Invalid value used in weak set');
      this['\x01i'][__mk(k)] = true;
      return this;
    }
    delete(k) {
      var m = __mk(k);
      if (this['\x01i'][m] === undefined) return false;
      delete this['\x01i'][m];
      return true;
    }
  };
}
