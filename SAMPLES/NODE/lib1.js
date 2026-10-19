var o = { a: 1, get g() { return 2; }, set g(v) {} };
Object.defineProperty(o, 'h', { value: 3, enumerable: false });
console.log(JSON.stringify(Object.getOwnPropertyDescriptor(o, 'a')), JSON.stringify(Object.getOwnPropertyDescriptor(o, 'h')));
var dg = Object.getOwnPropertyDescriptor(o, 'g'); console.log(typeof dg.get, typeof dg.set, dg.enumerable, dg.configurable);
console.log(Object.getOwnPropertyDescriptor(o, 'zz'), JSON.stringify(Object.getOwnPropertyDescriptor([5], '0')), JSON.stringify(Object.getOwnPropertyDescriptor([5], 'length')), JSON.stringify(Object.getOwnPropertyDescriptor('ab', '1')));
var s = Object.seal({ x: 1 }); s.x = 2; s.y = 3; delete s.x; console.log(JSON.stringify(s), Object.isSealed(s), Object.isFrozen(s), Object.isExtensible(s));
var p = Object.preventExtensions({ q: 1 }); p.r = 1; p.q = 5; delete p.q; console.log(JSON.stringify(p), Object.isExtensible(p), Object.isExtensible({}));
var f = Object.freeze({ z: 1 }); console.log(JSON.stringify(Object.getOwnPropertyDescriptor(f, 'z')), Object.isSealed(f));
console.log(Reflect.has({ a: 1 }, 'a'), Reflect.ownKeys({ a: 1, b: 2 }), Reflect.getPrototypeOf([]) === Array.prototype, Reflect.apply(Math.max, null, [1, 3]));
class A { constructor(x) { this.x = x; } } class B extends A {}
console.log(Reflect.construct(A, [5]).x, Reflect.construct(A, [5], B) instanceof B, Reflect.get({ get z() { return this.k; }, k: 1 }, 'z', { k: 9 }));
console.log(Reflect.set({}, 'a', 1), Reflect.defineProperty({}, 'x', { value: 1 }), Reflect.deleteProperty({ a: 1 }, 'a'));
var w = new WeakRef(o); console.log(w.deref() === o, typeof FinalizationRegistry, new FinalizationRegistry(function () {}).register({}, 1));
console.log(typeof globalThis.Map, typeof globalThis.Promise, globalThis.Date === Date, typeof global, Object.getOwnPropertyDescriptors({ a: 1 }).a.value);
console.log(Object.prototype.toString.call(new WeakRef({})), WeakRef.name);
