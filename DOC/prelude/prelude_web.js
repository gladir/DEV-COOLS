var __Event, __EventTarget, __CustomEvent, __AbortController, __AbortSignal, __URL, __URLSearchParams;
function __fetch(url) {
  return new Promise(function (resolve, reject) {
    var e = new TypeError('fetch failed');
    e.cause = new Error('le reseau n\'est pas disponible dans JSCW32');
    reject(e);
  });
}
function __init_web() {
  __DOMException = class DOMException extends Error {
    constructor(message, name) {
      super(message === undefined ? '' : message);
      Object.defineProperty(this, 'name', { value: name === undefined ? 'Error' : name, writable: true, configurable: true, enumerable: false });
    }
    get code() {
      var m = { IndexSizeError: 1, NotFoundError: 8, NotSupportedError: 9, InvalidStateError: 11, SyntaxError: 12, InvalidCharacterError: 5, AbortError: 20, TimeoutError: 23, DataCloneError: 25 };
      return m[this.name] || 0;
    }
  };
  __Event = class Event {
    constructor(type, init) {
      if (arguments.length === 0) throw new TypeError('The "type" argument must be specified');
      this.type = String(type);
      this.bubbles = !!(init && init.bubbles);
      this.cancelable = !!(init && init.cancelable);
      this.composed = !!(init && init.composed);
      this.defaultPrevented = false;
      this.target = null;
      this.currentTarget = null;
      this.timeStamp = performance.now();
      Object.defineProperty(this, '\x01stop', { value: false, writable: true, enumerable: false });
    }
    preventDefault() { if (this.cancelable) this.defaultPrevented = true; }
    stopPropagation() { }
    stopImmediatePropagation() { this['\x01stop'] = true; }
  };
  __CustomEvent = class CustomEvent extends __Event {
    constructor(type, init) {
      super(type, init);
      this.detail = init && init.detail !== undefined ? init.detail : null;
    }
  };
  __EventTarget = class EventTarget {
    constructor() { Object.defineProperty(this, '\x01l', { value: {}, enumerable: false }); }
    addEventListener(type, fn, opts) {
      if (typeof fn !== 'function' && !(fn && typeof fn.handleEvent === 'function')) return;
      var l = this['\x01l'], once = typeof opts === 'object' && opts !== null && !!opts.once, i;
      if (!l[type]) l[type] = [];
      for (i = 0; i < l[type].length; i++) if (l[type][i].fn === fn) return;
      l[type].push({ fn: fn, once: once });
      if (typeof opts === 'object' && opts !== null && opts.signal) {
        var self = this;
        opts.signal.addEventListener('abort', function () { self.removeEventListener(type, fn); });
      }
    }
    removeEventListener(type, fn) {
      var a = this['\x01l'][type], i;
      if (!a) return;
      for (i = 0; i < a.length; i++) if (a[i].fn === fn) { a.splice(i, 1); return; }
    }
    dispatchEvent(ev) {
      var a = this['\x01l'][ev.type], i, h, copy, f;
      ev.target = this; ev.currentTarget = this;
      f = this['on' + ev.type];
      if (typeof f === 'function') f.call(this, ev);
      if (a) {
        copy = a.slice();
        for (i = 0; i < copy.length; i++) {
          h = copy[i];
          if (h.once) this.removeEventListener(ev.type, h.fn);
          if (typeof h.fn === 'function') h.fn.call(this, ev); else h.fn.handleEvent(ev);
          if (ev['\x01stop']) break;
        }
      }
      ev.currentTarget = null;
      return !ev.defaultPrevented;
    }
  };
  __AbortSignal = class AbortSignal extends __EventTarget {
    constructor() { super(); this.aborted = false; this.reason = undefined; this.onabort = null; }
    throwIfAborted() { if (this.aborted) throw this.reason; }
    static abort(reason) {
      var s = new __AbortSignal();
      s.aborted = true;
      s.reason = reason === undefined ? new __DOMException('This operation was aborted', 'AbortError') : reason;
      return s;
    }
    static timeout(ms) {
      var s = new __AbortSignal();
      setTimeout(function () { __abortSignal(s, new __DOMException('The operation was aborted due to timeout', 'TimeoutError')); }, ms);
      return s;
    }
    static any(list) {
      var s = new __AbortSignal(), i;
      for (i = 0; i < list.length; i++) {
        if (list[i].aborted) { s.aborted = true; s.reason = list[i].reason; return s; }
        list[i].addEventListener('abort', function (e) { __abortSignal(s, e.target.reason); });
      }
      return s;
    }
  };
  __AbortController = class AbortController {
    constructor() { this.signal = new __AbortSignal(); }
    abort(reason) { __abortSignal(this.signal, reason); }
  };
  __URLSearchParams = class URLSearchParams {
    constructor(init) {
      var i, k, e;
      Object.defineProperty(this, '\x01l', { value: [], enumerable: false });
      Object.defineProperty(this, '\x01u', { value: null, writable: true, enumerable: false });
      if (init === undefined || init === null) return;
      if (typeof init === 'string') this['\x01parse'](init);
      else if (init instanceof __URLSearchParams) { for (i = 0; i < init['\x01l'].length; i++) this['\x01l'].push(init['\x01l'][i].slice()); }
      else if (typeof init === 'object' && typeof init[Symbol.iterator] === 'function') {
        for (e of init) {
          if (e.length !== 2) throw new TypeError('Each query pair must be an iterable [name, value] tuple');
          this['\x01l'].push([String(e[0]), String(e[1])]);
        }
      } else if (typeof init === 'object') {
        for (k of Object.keys(init)) this['\x01l'].push([k, String(init[k])]);
      } else this['\x01parse'](String(init));
    }
    '\x01parse'(s) {
      var parts, i, p, k, v, q;
      this['\x01l'].length = 0;
      if (s.charAt(0) === '?') s = s.slice(1);
      if (s === '') return;
      parts = s.split('&');
      for (i = 0; i < parts.length; i++) {
        if (parts[i] === '') continue;
        p = parts[i].indexOf('=');
        k = p < 0 ? parts[i] : parts[i].slice(0, p);
        v = p < 0 ? '' : parts[i].slice(p + 1);
        this['\x01l'].push([__uqDec(k), __uqDec(v)]);
      }
    }
    '\x01upd'() { if (this['\x01u']) this['\x01u']['\x01setq'](this.toString()); }
    get size() { return this['\x01l'].length; }
    append(k, v) { this['\x01l'].push([String(k), String(v)]); this['\x01upd'](); }
    delete(k) { var l = this['\x01l'], i; for (i = l.length - 1; i >= 0; i--) if (l[i][0] === k) l.splice(i, 1); this['\x01upd'](); }
    get(k) { var l = this['\x01l'], i; for (i = 0; i < l.length; i++) if (l[i][0] === k) return l[i][1]; return null; }
    getAll(k) { var l = this['\x01l'], i, r = []; for (i = 0; i < l.length; i++) if (l[i][0] === k) r.push(l[i][1]); return r; }
    has(k) { return this.get(k) !== null; }
    set(k, v) {
      var l = this['\x01l'], i, f = -1;
      k = String(k); v = String(v);
      for (i = 0; i < l.length; i++) if (l[i][0] === k) { if (f < 0) { f = i; l[i][1] = v; } else { l.splice(i, 1); i--; } }
      if (f < 0) l.push([k, v]);
      this['\x01upd']();
    }
    sort() { this['\x01l'].sort(function (a, b) { return a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0; }); this['\x01upd'](); }
    forEach(f, t) { var l = this['\x01l'], i; for (i = 0; i < l.length; i++) f.call(t, l[i][1], l[i][0], this); }
    keys() { return this['\x01l'].map(function (e) { return e[0]; }).values(); }
    values() { return this['\x01l'].map(function (e) { return e[1]; }).values(); }
    entries() { return this['\x01l'].map(function (e) { return [e[0], e[1]]; }).values(); }
    toString() { return this['\x01l'].map(function (e) { return __uqEnc(e[0]) + '=' + __uqEnc(e[1]); }).join('&'); }
  };
  __URLSearchParams.prototype[Symbol.iterator] = __URLSearchParams.prototype.entries;
  __URL = class URL {
    constructor(url, base) {
      var r = __urlParse(String(url), base === undefined ? undefined : (base instanceof __URL ? base.href : String(base)));
      if (r === null) { var e = new TypeError('Invalid URL'); e.code = 'ERR_INVALID_URL'; e.input = String(url); throw e; }
      Object.defineProperty(this, '\x01r', { value: r, writable: true, enumerable: false });
      Object.defineProperty(this, '\x01sp', { value: null, writable: true, enumerable: false });
    }
    static canParse(u, b) { try { new __URL(u, b); return true; } catch (e) { return false; } }
    '\x01setq'(q) { this['\x01r'].query = q === '' ? null : q; }
    get href() { return __urlHref(this['\x01r']); }
    set href(v) { var r = __urlParse(String(v)); if (r === null) throw new TypeError('Invalid URL'); this['\x01r'] = r; }
    get origin() { var r = this['\x01r']; return (r.scheme === 'http' || r.scheme === 'https' || r.scheme === 'ws' || r.scheme === 'wss' || r.scheme === 'ftp') ? r.scheme + '://' + __urlHost(r) : 'null'; }
    get protocol() { return this['\x01r'].scheme + ':'; }
    set protocol(v) { this['\x01r'].scheme = String(v).replace(/:.*$/, '').toLowerCase(); }
    get username() { return this['\x01r'].user; }
    set username(v) { this['\x01r'].user = __urlEnc(String(v), '/:;=@[\\]^|?#'); }
    get password() { return this['\x01r'].pass; }
    set password(v) { this['\x01r'].pass = __urlEnc(String(v), '/:;=@[\\]^|?#'); }
    get host() { return __urlHost(this['\x01r']); }
    set host(v) { var m = /^([^:]*)(?::(\d*))?$/.exec(String(v)); if (m) { this['\x01r'].host = m[1].toLowerCase(); if (m[2] !== undefined) this.port = m[2]; } }
    get hostname() { return this['\x01r'].host; }
    set hostname(v) { this['\x01r'].host = String(v).toLowerCase(); }
    get port() { return this['\x01r'].port; }
    set port(v) {
      v = String(v);
      this['\x01r'].port = (v === '' || __urlDefPort(this['\x01r'].scheme) === Number(v)) ? '' : String(parseInt(v, 10));
    }
    get pathname() { return this['\x01r'].path; }
    set pathname(v) { v = String(v); this['\x01r'].path = __urlNormPath(this['\x01r'].special && v.charAt(0) !== '/' ? '/' + v : v, this['\x01r'].special); }
    get search() { var q = this['\x01r'].query; return q === null || q === '' ? '' : '?' + q; }
    set search(v) {
      v = String(v);
      if (v.charAt(0) === '?') v = v.slice(1);
      this['\x01r'].query = v === '' ? null : __urlEnc(v, ' "#<>');
      if (this['\x01sp']) this['\x01sp']['\x01parse'](v);
    }
    get hash() { var f = this['\x01r'].frag; return f === null || f === '' ? '' : '#' + f; }
    set hash(v) { v = String(v); if (v.charAt(0) === '#') v = v.slice(1); this['\x01r'].frag = v === '' ? null : __urlEnc(v, ' "<>`'); }
    get searchParams() {
      if (!this['\x01sp']) {
        this['\x01sp'] = new __URLSearchParams(this['\x01r'].query === null ? '' : this['\x01r'].query);
        this['\x01sp']['\x01u'] = this;
      }
      return this['\x01sp'];
    }
    toString() { return this.href; }
    toJSON() { return this.href; }
  };
  var gt = globalThis;
  gt.Event = __Event; gt.EventTarget = __EventTarget; gt.CustomEvent = __CustomEvent; gt.AbortController = __AbortController; gt.AbortSignal = __AbortSignal;
  gt.DOMException = __DOMException; gt.URL = __URL; gt.URLSearchParams = __URLSearchParams; gt.fetch = __fetch;
}
function __abortSignal(s, reason) {
  if (s.aborted) return;
  s.aborted = true;
  s.reason = reason === undefined ? new __DOMException('This operation was aborted', 'AbortError') : reason;
  var ev = new __Event('abort');
  s.dispatchEvent(ev);
}
function __uqEnc(s) {
  var e = __encodeURIComponent(s).replace(/%20/g, '+');
  return e.replace(/[!'()~]/g, function (c) { return '%' + c.charCodeAt(0).toString(16).toUpperCase(); });
}
function __uqDec(s) {
  s = s.replace(/\+/g, ' ');
  try { return __decodeURIComponent(s); } catch (e) { return s; }
}
function __urlEnc(s, set) {
  var out = '', i, c, b;
  for (i = 0; i < s.length; i++) {
    c = s.charAt(i);
    if (s.charCodeAt(i) < 33 || s.charCodeAt(i) > 126 || set.indexOf(c) >= 0) {
      if (c === '%' && /^%[0-9A-Fa-f]{2}/.test(s.slice(i))) { out += c; continue; }
      if (c === ' ' && set.indexOf(' ') < 0 && false) { out += c; continue; }
      out += __encodeURIComponent(s.charCodeAt(i) >= 55296 && s.charCodeAt(i) <= 56319 ? s.charAt(i) + s.charAt(++i) : c);
    } else out += c;
  }
  return out;
}
function __urlDefPort(sc) { return { http: 80, https: 443, ftp: 21, ws: 80, wss: 443 }[sc]; }
function __urlSpecial(sc) { return sc === 'http' || sc === 'https' || sc === 'ftp' || sc === 'ws' || sc === 'wss' || sc === 'file'; }
function __urlHost(r) { return r.host + (r.port === '' ? '' : ':' + r.port); }
function __urlNormPath(p, special) {
  var segs = p.split(special ? /[\/\\]/ : '/'), out = [], i, s, last;
  if (segs[0] === '') segs.shift();
  for (i = 0; i < segs.length; i++) {
    s = segs[i];
    last = i === segs.length - 1;
    if (s === '..' || s.toLowerCase() === '%2e%2e' || s.toLowerCase() === '.%2e' || s.toLowerCase() === '%2e.') { if (out.length > 0) out.pop(); if (last) out.push(''); }
    else if (s === '.' || s.toLowerCase() === '%2e') { if (last) out.push(''); }
    else out.push(__urlEnc(s, ' "#<>?`{}'));
  }
  return '/' + out.join('/');
}
function __urlParse(input, base) {
  var s = input.replace(/^[\u0000- ]+|[\u0000- ]+$/g, '').replace(/[\t\n\r]/g, ''), m, r, b, rest, auth, hp, q, f, pi, hm, special, path;
  m = /^([A-Za-z][A-Za-z0-9+.\-]*):/.exec(s);
  r = { scheme: '', user: '', pass: '', host: '', port: '', path: '', query: null, frag: null, special: false, opaque: false };
  if (m === null) {
    if (base === undefined) return null;
    b = __urlParse(base);
    if (b === null || b.opaque) return null;
    r.scheme = b.scheme; r.special = b.special;
    rest = s;
    f = rest.indexOf('#'); if (f >= 0) { r.frag = __urlEnc(rest.slice(f + 1), ' "<>`'); rest = rest.slice(0, f); }
    q = rest.indexOf('?'); if (q >= 0) { r.query = __urlEnc(rest.slice(q + 1), r.special ? ' "#<>\'' : ' "#<>'); rest = rest.slice(0, q); }
    if (rest.slice(0, 2) === '//' || (r.special && /^[\/\\]{2}/.test(rest))) return __urlParse(b.scheme + ':' + s, undefined);
    r.user = b.user; r.pass = b.pass; r.host = b.host; r.port = b.port;
    if (rest === '') { r.path = b.path; if (q < 0) r.query = b.query; }
    else if (rest.charAt(0) === '/' || (r.special && rest.charAt(0) === '\\')) r.path = __urlNormPath(rest, r.special);
    else {
      path = b.path.slice(0, b.path.lastIndexOf('/') + 1) + rest;
      r.path = __urlNormPath(path, r.special);
    }
    return r;
  }
  r.scheme = m[1].toLowerCase();
  r.special = __urlSpecial(r.scheme);
  rest = s.slice(m[0].length);
  f = rest.indexOf('#'); if (f >= 0) { r.frag = __urlEnc(rest.slice(f + 1), ' "<>`'); rest = rest.slice(0, f); }
  q = rest.indexOf('?'); if (q >= 0) { r.query = __urlEnc(rest.slice(q + 1), r.special ? ' "#<>\'' : ' "#<>'); rest = rest.slice(0, q); }
  if (r.special) {
    if (r.scheme === 'file') {
      rest = rest.replace(/\\/g, '/');
      if (rest.slice(0, 2) === '//') { rest = rest.slice(2); pi = rest.indexOf('/'); r.host = (pi < 0 ? rest : rest.slice(0, pi)).toLowerCase(); rest = pi < 0 ? '/' : rest.slice(pi); }
      else if (rest.charAt(0) !== '/') {
        if (base !== undefined) { b = __urlParse(base); if (b && b.scheme === 'file') { r.host = b.host; rest = b.path.slice(0, b.path.lastIndexOf('/') + 1) + rest; } }
        if (rest.charAt(0) !== '/') rest = '/' + rest;
      }
      r.path = __urlNormPath(rest, true);
      return r;
    }
    rest = rest.replace(/^[\/\\]*/, '');
    pi = rest.search(/[\/\\]/);
    auth = pi < 0 ? rest : rest.slice(0, pi);
    path = pi < 0 ? '/' : rest.slice(pi);
  } else if (rest.slice(0, 2) === '//') {
    rest = rest.slice(2);
    pi = rest.indexOf('/');
    auth = pi < 0 ? rest : rest.slice(0, pi);
    path = pi < 0 ? '' : rest.slice(pi);
  } else {
    r.opaque = true;
    r.path = __urlEnc(rest, '');
    return r;
  }
  hp = auth.lastIndexOf('@');
  if (hp >= 0) {
    var ui = auth.slice(0, hp), c = ui.indexOf(':');
    r.user = __urlEnc(c < 0 ? ui : ui.slice(0, c), '/:;=@[\\]^|?#');
    r.pass = c < 0 ? '' : __urlEnc(ui.slice(c + 1), '/:;=@[\\]^|?#');
    auth = auth.slice(hp + 1);
  }
  hm = /^(\[[^\]]*\]|[^:]*)(?::(.*))?$/.exec(auth);
  if (hm === null) return null;
  r.host = hm[1];
  if (r.special) {
    if (r.host === '') return null;
    try { r.host = __decodeURIComponent(r.host); } catch (e) { return null; }
    r.host = r.host.toLowerCase();
    if (/[\u0000\t\n\r #\/:<>?@\[\\\]^|%]/.test(r.host.replace(/^\[.*\]$/, ''))) return null;
  } else r.host = r.host.toLowerCase();
  if (hm[2] !== undefined && hm[2] !== '') {
    if (!/^\d+$/.test(hm[2]) || Number(hm[2]) > 65535) return null;
    r.port = __urlDefPort(r.scheme) === Number(hm[2]) ? '' : String(Number(hm[2]));
  }
  r.path = r.special || path !== '' ? __urlNormPath(path === '' ? '/' : path, r.special) : '';
  return r;
}
function __urlHref(r) {
  var s = r.scheme + ':';
  if (r.opaque) return s + r.path + (r.query === null ? '' : '?' + r.query) + (r.frag === null ? '' : '#' + r.frag);
  if (r.host !== '' || r.scheme === 'file' || r.special) {
    s += '//';
    if (r.user !== '' || r.pass !== '') s += r.user + (r.pass === '' ? '' : ':' + r.pass) + '@';
    s += __urlHost(r);
  }
  return s + r.path + (r.query === null ? '' : '?' + r.query) + (r.frag === null ? '' : '#' + r.frag);
}
