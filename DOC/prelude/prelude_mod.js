var __modcache;
function __is(a, b) {
  if (a === b) return a !== 0 || 1 / a === 1 / b;
  return a !== a && b !== b;
}
function __deq(a, b, strict) {
  if (strict ? __is(a, b) : (a == b || (a !== a && b !== b))) return true;
  if (typeof a !== 'object' || typeof b !== 'object' || a === null || b === null) return false;
  if (strict && Object.getPrototypeOf(a) !== Object.getPrototypeOf(b)) return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  var i, k, ka, kb, found;
  if (a instanceof __Date || b instanceof __Date) return a instanceof __Date && b instanceof __Date && a.getTime() === b.getTime();
  if (a instanceof RegExp || b instanceof RegExp) return String(a) === String(b);
  if (a instanceof __Map || b instanceof __Map) {
    if (!(a instanceof __Map && b instanceof __Map) || a.size !== b.size) return false;
    found = true;
    a.forEach(function (v, key) { if (!b.has(key) || !__deq(v, b.get(key), strict)) found = false; });
    return found;
  }
  if (a instanceof __Set || b instanceof __Set) {
    if (!(a instanceof __Set && b instanceof __Set) || a.size !== b.size) return false;
    found = true;
    a.forEach(function (v) {
      if (b.has(v)) return;
      var any = false;
      b.forEach(function (w) { if (!any && __deq(v, w, strict)) any = true; });
      if (!any) found = false;
    });
    return found;
  }
  ka = Object.keys(a);
  kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  for (i = 0; i < ka.length; i++) {
    k = ka[i];
    if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
    if (!__deq(a[k], b[k], strict)) return false;
  }
  return true;
}
function __mkEvents() {
  function EventEmitter() { this._events = {}; this._maxListeners = 10; }
  var P = EventEmitter.prototype;
  function lst(self, n) {
    if (self._events === undefined) self._events = {};
    return self._events[n];
  }
  P.addListener = P.on = function (n, f) {
    var l = lst(this, n);
    if (l === undefined) this._events[n] = [f]; else l.push(f);
    return this;
  };
  P.prependListener = function (n, f) {
    var l = lst(this, n);
    if (l === undefined) this._events[n] = [f]; else l.unshift(f);
    return this;
  };
  P.once = function (n, f) {
    var self = this;
    function w(...a) { self.removeListener(n, w); return f.apply(self, a); }
    w.listener = f;
    return this.on(n, w);
  };
  P.removeListener = P.off = function (n, f) {
    var l = lst(this, n), i;
    if (l === undefined) return this;
    for (i = l.length - 1; i >= 0; i--) {
      if (l[i] === f || l[i].listener === f) { l.splice(i, 1); break; }
    }
    if (l.length === 0) delete this._events[n];
    return this;
  };
  P.removeAllListeners = function (n) {
    if (n === undefined) this._events = {}; else if (this._events) delete this._events[n];
    return this;
  };
  P.emit = function (n, ...a) {
    var l = lst(this, n), i;
    if (l === undefined || l.length === 0) {
      if (n === 'error') {
        var er = a[0];
        if (er instanceof Error) throw er;
        var e2 = new Error('Unhandled error. (' + __i_insp(er, 2) + ')');
        e2.context = er;
        throw e2;
      }
      return false;
    }
    l = l.slice();
    for (i = 0; i < l.length; i++) l[i].apply(this, a);
    return true;
  };
  P.listenerCount = function (n) { var l = lst(this, n); return l === undefined ? 0 : l.length; };
  P.listeners = function (n) {
    var l = lst(this, n);
    return l === undefined ? [] : l.map(function (f) { return f.listener || f; });
  };
  P.rawListeners = function (n) { var l = lst(this, n); return l === undefined ? [] : l.slice(); };
  P.eventNames = function () { lst(this, ''); return Object.keys(this._events); };
  P.setMaxListeners = function (m) { this._maxListeners = m; return this; };
  P.getMaxListeners = function () { return this._maxListeners; };
  EventEmitter.EventEmitter = EventEmitter;
  EventEmitter.defaultMaxListeners = 10;
  EventEmitter.once = function (em, n) {
    return new __Promise(function (res) { em.once(n, function (...a) { res(a); }); });
  };
  return EventEmitter;
}
function __mkAssert() {
  class AssertionError extends Error {
    constructor(o) {
      super(o.message);
      this.name = 'AssertionError';
      this.code = 'ERR_ASSERTION';
      this.actual = o.actual;
      this.expected = o.expected;
      this.operator = o.operator;
      this.generatedMessage = !o.user;
    }
  }
  function fail(msg, def, a, e, op) {
    if (msg instanceof Error) throw msg;
    throw new AssertionError({ message: msg === undefined ? def : msg, user: msg !== undefined, actual: a, expected: e, operator: op });
  }
  function ins(v) { return __i_insp(v, 2); }
  var assert = function (v, m) { if (!v) fail(m, 'The expression evaluated to a falsy value:\n\n  assert(' + ins(v) + ')\n', v, true, '=='); };
  assert.ok = function (v, m) { if (!v) fail(m, 'The expression evaluated to a falsy value:\n\n  assert.ok(' + ins(v) + ')\n', v, true, '=='); };
  assert.equal = function (a, b, m) { if (!(a == b || (a !== a && b !== b))) fail(m, ins(a) + ' == ' + ins(b), a, b, '=='); };
  assert.notEqual = function (a, b, m) { if (a == b) fail(m, ins(a) + ' != ' + ins(b), a, b, '!='); };
  assert.strictEqual = function (a, b, m) {
    if (!__is(a, b)) fail(m, 'Expected values to be strictly equal:\n\n' + ins(a) + ' !== ' + ins(b) + '\n', a, b, 'strictEqual');
  };
  assert.notStrictEqual = function (a, b, m) {
    if (__is(a, b)) fail(m, 'Expected "actual" to be strictly unequal to: ' + ins(b), a, b, 'notStrictEqual');
  };
  assert.deepEqual = function (a, b, m) { if (!__deq(a, b, false)) fail(m, 'Expected values to be loosely deep-equal:\n\n' + ins(a) + '\n\nshould loosely deep-equal\n\n' + ins(b), a, b, 'deepEqual'); };
  assert.deepStrictEqual = function (a, b, m) { if (!__deq(a, b, true)) fail(m, 'Expected values to be strictly deep-equal:\n' + ins(a) + '\n\nshould equal\n\n' + ins(b), a, b, 'deepStrictEqual'); };
  assert.notDeepEqual = function (a, b, m) { if (__deq(a, b, false)) fail(m, 'Expected "actual" not to be loosely deep-equal to: ' + ins(b), a, b, 'notDeepEqual'); };
  assert.notDeepStrictEqual = function (a, b, m) { if (__deq(a, b, true)) fail(m, 'Expected "actual" not to be strictly deep-equal to: ' + ins(b), a, b, 'notDeepStrictEqual'); };
  assert.fail = function (m) { fail(m, 'Failed', undefined, undefined, 'fail'); };
  function matches(e, exp) {
    if (exp === undefined) return true;
    if (typeof exp === 'function') {
      if (exp.prototype !== undefined && e instanceof exp) return true;
      if (Error.isPrototypeOf && Error.isPrototypeOf(exp)) return false;
      return exp.prototype === undefined || exp.call({}, e) === true;
    }
    if (exp instanceof RegExp) return exp.test(String(e));
    if (typeof exp === 'object') {
      var ks = Object.keys(exp), i;
      for (i = 0; i < ks.length; i++) {
        var want = exp[ks[i]], got = e[ks[i]];
        if (want instanceof RegExp && typeof got === 'string' ? !want.test(got) : !__deq(got, want, true)) return false;
      }
      return true;
    }
    return true;
  }
  assert.throws = function (fn, exp, m) {
    var threw = false, err;
    try { fn(); } catch (e) { threw = true; err = e; }
    if (!threw) fail(typeof exp === 'string' ? exp : m, 'Missing expected exception.', undefined, exp, 'throws');
    if (typeof exp !== 'string' && !matches(err, exp)) throw err;
  };
  assert.doesNotThrow = function (fn, m) {
    try { fn(); } catch (e) { fail(typeof m === 'string' ? m : undefined, 'Got unwanted exception.\nActual message: "' + (e && e.message) + '"', e, undefined, 'doesNotThrow'); }
  };
  assert.rejects = function (p, exp, m) {
    return (typeof p === 'function' ? p() : p).then(function () {
      fail(m, 'Missing expected rejection.', undefined, exp, 'rejects');
    }, function (e) { if (!matches(e, exp)) throw e; });
  };
  assert.match = function (s, re, m) { if (!re.test(s)) fail(m, 'The input did not match the regular expression ' + String(re) + '. Input:\n\n' + ins(s) + '\n', s, re, 'match'); };
  assert.ifError = function (v) { if (v !== null && v !== undefined) throw v; };
  assert.AssertionError = AssertionError;
  assert.strict = assert;
  return assert;
}
function __mkUtil() {
  var util = {};
  util.inspect = function (v, o) {
    var d = 2;
    if (o !== null && typeof o === 'object' && 'depth' in o) d = o.depth === null ? Infinity : o.depth;
    else if (typeof o === 'number') d = o;
    return __i_insp(v, d);
  };
  util.format = function (...a) { return __i_args(a); };
  util.promisify = function (fn) {
    return function (...a) {
      var self = this;
      return new __Promise(function (res, rej) {
        a.push(function (err, v) { if (err) rej(err); else res(v); });
        fn.apply(self, a);
      });
    };
  };
  util.inherits = function (c, s) {
    Object.setPrototypeOf(c.prototype, s.prototype);
    c.super_ = s;
  };
  util.deprecate = function (fn) { return fn; };
  util.isDeepStrictEqual = function (a, b) { return __deq(a, b, true); };
  util.isArray = Array.isArray;
  util.types = {
    isDate: function (v) { return v instanceof __Date; },
    isRegExp: function (v) { return v instanceof RegExp; },
    isMap: function (v) { return v instanceof __Map; },
    isSet: function (v) { return v instanceof __Set; },
    isPromise: function (v) { return v instanceof __Promise; }
  };
  return util;
}
function __mkPath() {
  var path = {};
  function norm(p) {
    var abs = p.charAt(0) === '/', parts = p.split('/'), out = [], i;
    for (i = 0; i < parts.length; i++) {
      if (parts[i] === '' || parts[i] === '.') continue;
      if (parts[i] === '..') {
        if (out.length > 0 && out[out.length - 1] !== '..') out.pop();
        else if (!abs) out.push('..');
      } else out.push(parts[i]);
    }
    var r = out.join('/');
    if (abs) return '/' + r;
    return r === '' ? '.' : r;
  }
  path.sep = '/';
  path.delimiter = ':';
  path.normalize = function (p) {
    var r = norm(String(p));
    return (String(p).slice(-1) === '/' && r !== '/' && r !== '.') ? r + '/' : r;
  };
  path.join = function (...a) {
    var s = a.filter(function (x) { return x !== ''; }).join('/');
    return s === '' ? '.' : path.normalize(s);
  };
  path.isAbsolute = function (p) { return String(p).charAt(0) === '/'; };
  path.resolve = function (...a) {
    var r = '', i;
    for (i = a.length - 1; i >= 0 && r.charAt(0) !== '/'; i--) {
      if (a[i] !== '') r = a[i] + (r === '' ? '' : '/' + r);
    }
    if (r.charAt(0) !== '/') r = process.cwd().replace(/\\/g, '/') + (r === '' ? '' : '/' + r);
    r = norm(r);
    return r;
  };
  path.dirname = function (p) {
    p = String(p);
    while (p.length > 1 && p.slice(-1) === '/') p = p.slice(0, -1);
    var i = p.lastIndexOf('/');
    if (i < 0) return '.';
    if (i === 0) return '/';
    return p.slice(0, i);
  };
  path.basename = function (p, ext) {
    p = String(p);
    while (p.length > 1 && p.slice(-1) === '/') p = p.slice(0, -1);
    var b = p.slice(p.lastIndexOf('/') + 1);
    if (ext !== undefined && b.length > ext.length && b.slice(-ext.length) === ext) b = b.slice(0, -ext.length);
    return b;
  };
  path.extname = function (p) {
    var b = path.basename(p), i = b.lastIndexOf('.');
    return (i <= 0) ? '' : b.slice(i);
  };
  path.relative = function (from, to) {
    var f = path.resolve(from).split('/').filter(Boolean), t = path.resolve(to).split('/').filter(Boolean), i = 0;
    while (i < f.length && i < t.length && f[i] === t[i]) i++;
    var out = [], j;
    for (j = i; j < f.length; j++) out.push('..');
    return out.concat(t.slice(i)).join('/');
  };
  path.parse = function (p) {
    p = String(p);
    var base = path.basename(p), ext = path.extname(p), dir = path.dirname(p);
    if (dir === '.' && p.charAt(0) !== '.') dir = '';
    return { root: p.charAt(0) === '/' ? '/' : '', dir: dir, base: base, ext: ext, name: ext ? base.slice(0, -ext.length) : base };
  };
  path.format = function (o) {
    var dir = o.dir || o.root || '', base = o.base || ((o.name || '') + (o.ext || ''));
    return dir ? (dir === o.root ? dir + base : dir + '/' + base) : base;
  };
  path.posix = path;
  path.win32 = path;
  return path;
}
function __mkmod(name) {
  var e;
  if (name === 'events') return __mkEvents();
  if (name === 'assert' || name === 'assert/strict') return __mkAssert();
  if (name === 'util') return __mkUtil();
  if (name === 'path' || name === 'path/posix') return __mkPath();
  if (name === 'os') {
    return {
      EOL: '\r\n', platform: function () { return 'win32'; }, type: function () { return 'Windows_NT'; },
      arch: function () { return 'ia32'; }, release: function () { return '10.0'; }, hostname: function () { return 'localhost'; },
      homedir: function () { return 'C:\\'; }, tmpdir: function () { return 'C:\\Temp'; }, endianness: function () { return 'LE'; },
      cpus: function () { return []; }, totalmem: function () { return 0; }, freemem: function () { return 0; },
      uptime: function () { return 0; }, userInfo: function () { return { username: 'user', homedir: 'C:\\' }; }
    };
  }
  if (name === 'timers') {
    return { setTimeout: setTimeout, setInterval: setInterval, setImmediate: setImmediate, clearTimeout: clearTimeout, clearInterval: clearInterval, clearImmediate: clearImmediate };
  }
  if (name === 'timers/promises') {
    return {
      setTimeout: function (ms, v) { return new __Promise(function (res) { setTimeout(function () { res(v); }, ms); }); },
      setImmediate: function (v) { return new __Promise(function (res) { setImmediate(function () { res(v); }); }); }
    };
  }
  if (name === 'perf_hooks') return { performance: performance };
  if (name === 'process') return process;
  if (name === 'fs' || name === 'child_process' || name === 'http' || name === 'https' || name === 'net' || name === 'crypto' ||
      name === 'readline' || name === 'stream' || name === 'zlib' || name === 'worker_threads' || name === 'buffer' || name === 'url' ||
      name === 'string_decoder' || name === 'vm' || name === 'cluster' || name === 'dns' || name === 'tty' || name === 'fs/promises') {
    e = new Error("Module '" + name + "' is not supported by JSCW32");
    e.code = 'ERR_MODULE_NOT_SUPPORTED';
    throw e;
  }
  e = new Error("Cannot find module '" + name + "'");
  e.code = 'MODULE_NOT_FOUND';
  throw e;
}
function __require(name) {
  name = String(name);
  if (name.slice(0, 5) === 'node:') name = name.slice(5);
  if (__modcache === undefined) __modcache = {};
  if (__modcache[name] !== undefined) return __modcache[name];
  var m = __mkmod(name);
  __modcache[name] = m;
  return m;
}
