const wm = new WeakMap(), ws = new WeakSet();
const k1 = {}, k2 = Object.freeze({}), k3 = [], k4 = function () {}, k5 = new (class A {})();
for (const k of [k1, k2, k3, k4, k5]) { wm.set(k, typeof k); ws.add(k); }
console.log([k1, k2, k3, k4, k5].map(k => [wm.get(k), wm.has(k), ws.has(k)]));
console.log(wm.delete(k1), wm.has(k1), wm.get(k1), wm.delete(k1), ws.delete(k2), ws.has(k2));
console.log(Object.keys(k1), Object.getOwnPropertyNames(k5), JSON.stringify(k5), k5);
const wm2 = new WeakMap([[k1, 'b']]);
console.log(wm.has(k1), wm2.get(k1), wm.has(5), wm2.get('x'));
try { wm.set(1, 2); } catch (e) { console.log(e.constructor.name); }
try { ws.add('s'); } catch (e) { console.log(e.constructor.name); }
console.log(wm, ws);
// address reuse: no false hit
const probe = new WeakSet();
for (let i = 0; i < 2000; i++) { const o = { i }; if (probe.has(o)) console.log('FALSE HIT'); probe.add(o); }
console.log('ok');
