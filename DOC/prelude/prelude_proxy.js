function __pxHandler(holder, name) {
  var h = holder.h;
  if (h === null) throw new TypeError("Cannot perform '" + name + "' on a proxy that has been revoked");
  return h;
}
function __pxOp(op, p, key, value, recv) {
  var holder = __proxyinfo(p, 1), t = __proxyinfo(p, 0), h, trap, ks, i, r, d, k;
  switch (op) {
    case 0:
      h = __pxHandler(holder, 'get'); trap = h.get;
      if (trap === undefined) return Reflect.get(t, key, recv === p ? t : recv);
      return trap.call(h, t, key, recv);
    case 1:
      h = __pxHandler(holder, 'set'); trap = h.set;
      if (trap === undefined) { t[key] = value; return value; }
      trap.call(h, t, key, value, recv);
      return value;
    case 2:
      h = __pxHandler(holder, 'deleteProperty'); trap = h.deleteProperty;
      if (trap === undefined) return delete t[key];
      return !!trap.call(h, t, key);
    case 3:
      h = __pxHandler(holder, 'has'); trap = h.has;
      if (trap === undefined) return key in t;
      return !!trap.call(h, t, key);
    case 4:
      h = __pxHandler(holder, 'getOwnPropertyDescriptor'); trap = h.getOwnPropertyDescriptor;
      if (trap === undefined) return Object.prototype.hasOwnProperty.call(t, key);
      return trap.call(h, t, key) !== undefined;
  }
  h = __pxHandler(holder, 'ownKeys'); trap = h.ownKeys;
  ks = trap === undefined ? Object.getOwnPropertyNames(t) : Array.from(trap.call(h, t));
  r = [];
  for (i = 0; i < ks.length; i++) {
    k = ks[i];
    if (typeof k !== 'string') continue;
    if (key !== 3) {
      trap = h.getOwnPropertyDescriptor;
      d = trap === undefined ? Object.getOwnPropertyDescriptor(t, k) : trap.call(h, t, k);
      if (d === undefined || !d.enumerable) continue;
    }
    r.push(key === 1 ? p[k] : key === 2 ? [k, p[k]] : k);
  }
  return r;
}
function __pxFn(target, holder) {
  var f = function () {
    var h = __pxHandler(holder, 'apply'), trap, args = Array.prototype.slice.call(arguments), res;
    if (new.target !== undefined) {
      trap = h.construct;
      if (trap === undefined) return Reflect.construct(target, args, new.target === f ? target : new.target);
      res = trap.call(h, target, args, new.target === f ? f : new.target);
      if (res === null || (typeof res !== 'object' && typeof res !== 'function')) throw new TypeError('proxy [[Construct]] must return an object');
      return res;
    }
    trap = h.apply;
    if (trap === undefined) return target.apply(this, args);
    return trap.call(h, target, this, args);
  };
  Object.setPrototypeOf(f, target);
  Object.defineProperty(f, 'name', { value: target.name, configurable: true });
  return f;
}
function __pxMake(target, handler) {
  var holder = { h: handler };
  if (typeof target === 'function') return __pxFn(target, holder);
  return __proxynew(Object.getPrototypeOf(target), target, holder);
}
function __pxCheck(target, handler) {
  if (target === null || (typeof target !== 'object' && typeof target !== 'function') || handler === null || (typeof handler !== 'object' && typeof handler !== 'function')) {
    throw new TypeError('Cannot create proxy with a non-object as target or handler');
  }
}
function __pxTrapped(o, name) {
  var holder, h;
  if (o === null || typeof o !== 'object' || !__proxyinfo(o, 2)) return undefined;
  holder = __proxyinfo(o, 1);
  h = __pxHandler(holder, name);
  return h[name] === undefined ? undefined : { t: __proxyinfo(o, 0), h: h, f: h[name] };
}
function __pxCopy(p) {
  var n = p.length >>> 0, r = [], i;
  for (i = 0; i < n; i++) r.push(p[i]);
  return r;
}
function __pxWrite(p, tmp, old) {
  var i;
  for (i = 0; i < tmp.length; i++) p[i] = tmp[i];
  for (i = tmp.length; i < old; i++) delete p[i];
  p.length = tmp.length;
}
function __pxArrays() {
  var AP = Array.prototype, def = function (n, f) { Object.defineProperty(AP, n, { value: f, writable: true, configurable: true, enumerable: false }); };
  var readers = ['every', 'filter', 'find', 'findIndex', 'findLast', 'findLastIndex', 'flat', 'flatMap', 'forEach', 'includes', 'indexOf', 'join', 'lastIndexOf',
    'map', 'reduce', 'reduceRight', 'slice', 'some', 'keys', 'values', 'entries', 'toString', 'at', 'toSorted', 'toReversed', 'with', 'concat'];
  var writers = ['shift', 'unshift', 'splice', 'sort', 'reverse', 'fill', 'copyWithin'];
  var oisa = Array.isArray;
  readers.forEach(function (m) {
    var o = AP[m];
    if (typeof o === 'function') def(m, function () { return o.apply(__proxyinfo(this, 2) ? __pxCopy(this) : this, arguments); });
  });
  writers.forEach(function (m) {
    var o = AP[m];
    if (typeof o === 'function') def(m, function () {
      var tmp, old, r;
      if (!__proxyinfo(this, 2)) return o.apply(this, arguments);
      tmp = __pxCopy(this); old = tmp.length;
      r = o.apply(tmp, arguments);
      __pxWrite(this, tmp, old);
      return r === tmp ? this : r;
    });
  });
  var opush = AP.push, opop = AP.pop;
  def('push', function () {
    var len, i;
    if (!__proxyinfo(this, 2)) return opush.apply(this, arguments);
    len = this.length >>> 0;
    for (i = 0; i < arguments.length; i++) this[len++] = arguments[i];
    this.length = len;
    return len;
  });
  def('pop', function () {
    var len, v;
    if (!__proxyinfo(this, 2)) return opop.apply(this, arguments);
    len = this.length >>> 0;
    if (len === 0) { this.length = 0; return undefined; }
    v = this[len - 1];
    delete this[len - 1];
    this.length = len - 1;
    return v;
  });
  Array.isArray = function (a) { return __proxyinfo(a, 2) ? oisa(__proxyinfo(a, 0)) : oisa(a); };
}
function __init_proxy() {
  var ogpo = Object.getPrototypeOf, ospo = Object.setPrototypeOf, odp = Object.defineProperty, ogod = Object.getOwnPropertyDescriptor, oie = Object.isExtensible, opx = Object.preventExtensions;
  __proxyOp = __pxOp;
  __jsonSlow = true;
  __pxArrays();
  __Proxy = function Proxy(target, handler) {
    if (new.target === undefined) throw new TypeError("Constructor Proxy requires 'new'");
    __pxCheck(target, handler);
    return __pxMake(target, handler);
  };
  __Proxy.revocable = function (target, handler) {
    __pxCheck(target, handler);
    var p = __pxMake(target, handler), holder = typeof target === 'function' ? null : __proxyinfo(p, 1);
    return { proxy: p, revoke: function () { if (holder !== null) holder.h = null; } };
  };
  Object.getPrototypeOf = function (o) {
    var x = __pxTrapped(o, 'getPrototypeOf');
    return x === undefined ? ogpo(o) : x.f.call(x.h, x.t);
  };
  Object.setPrototypeOf = function (o, p) {
    var x = __pxTrapped(o, 'setPrototypeOf');
    if (x === undefined) return ospo(o, p);
    x.f.call(x.h, x.t, p);
    return o;
  };
  Object.defineProperty = function (o, k, d) {
    var x = __pxTrapped(o, 'defineProperty');
    if (x === undefined) return __proxyinfo(o, 2) ? odp(__proxyinfo(o, 0), k, d) && o : odp(o, k, d);
    if (!x.f.call(x.h, x.t, k, d)) throw new TypeError("'defineProperty' on proxy: trap returned falsish for property '" + String(k) + "'");
    return o;
  };
  Object.getOwnPropertyDescriptor = function (o, k) {
    var x = __pxTrapped(o, 'getOwnPropertyDescriptor');
    if (x === undefined) return ogod(__proxyinfo(o, 2) ? __proxyinfo(o, 0) : o, k);
    return x.f.call(x.h, x.t, k);
  };
  Object.isExtensible = function (o) {
    var x = __pxTrapped(o, 'isExtensible');
    return x === undefined ? oie(__proxyinfo(o, 2) ? __proxyinfo(o, 0) : o) : !!x.f.call(x.h, x.t);
  };
  Object.preventExtensions = function (o) {
    var x = __pxTrapped(o, 'preventExtensions');
    if (x === undefined) { opx(__proxyinfo(o, 2) ? __proxyinfo(o, 0) : o); return o; }
    x.f.call(x.h, x.t);
    return o;
  };
}
