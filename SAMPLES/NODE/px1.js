var log = [];
var target = { a: 1, b: 2 };
var p = new Proxy(target, {
  get(t, k, r) { log.push('get ' + String(k)); return k in t ? t[k] : 'def_' + String(k); },
  set(t, k, v) { log.push('set ' + k + '=' + v); t[k] = v * 2; return true; },
  has(t, k) { log.push('has ' + k); return k === 'zz' || k in t; },
  deleteProperty(t, k) { log.push('del ' + k); delete t[k]; return true; },
  ownKeys(t) { log.push('ownKeys'); return Reflect.ownKeys(t); }
});
console.log(p.a, p.nope);
p.c = 5;
console.log(target.c, 'zz' in p, 'a' in p, 'q' in p);
delete p.a;
console.log(Object.keys(p), JSON.stringify(p));
for (var k in p) console.log('key', k);
console.log(log.join('|'));
console.log(p);
var fp = new Proxy(function (a, b) { return a + b; }, { apply(t, th, args) { return t(...args) * 10; } });
console.log(fp(1, 2), typeof fp);
class A { constructor(x) { this.x = x; } }
var CP = new Proxy(A, { construct(t, args, nt) { return new t(args[0] + 1); } });
console.log(new CP(1).x, new CP(1) instanceof A);
var r = Proxy.revocable({}, {});
r.proxy.q = 1; console.log(r.proxy.q); r.revoke();
try { r.proxy.q; } catch (e) { console.log(e.constructor.name, e.message); }
var neg = new Proxy([1, 2, 3], { get(t, k, r) { var i = Number(k); return i < 0 ? t[t.length + i] : Reflect.get(t, k, r); } });
console.log(neg[-1], neg[0], neg.length);
var v = new Proxy({}, { set(t, k, v) { if (typeof v !== 'number') throw new TypeError('num only'); t[k] = v; return true; } });
try { v.x = 'a'; } catch (e) { console.log(e.message); }
v.y = 3; console.log(v.y);
var dflt = new Proxy({}, { get: (t, k) => k in t ? t[k] : 42 });
console.log(dflt.foo, dflt.bar + 1);
console.log(Object.getPrototypeOf(p) === Object.prototype, p instanceof Object);
console.log(Object.entries(new Proxy({ q: 1 }, {})), Object.getOwnPropertyNames(new Proxy({ w: 1 }, {})));
console.log(Reflect.has(p, 'zz'), p.hasOwnProperty('c'));
