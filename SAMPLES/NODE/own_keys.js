const p = Promise.resolve(1);
console.log(Object.getOwnPropertyNames(p), Object.getOwnPropertySymbols(p));
const s = Symbol('s');
const o = {a:1, [s]: 2, b: 3};
console.log(Object.getOwnPropertyNames(o), Object.getOwnPropertySymbols(o), Reflect.ownKeys(o));
console.log(Object.getOwnPropertyNames([1,2]));
const wm = new WeakMap(); wm.set(o, 1);
const wm2 = new WeakMap(); wm2.set(o, 1); console.log(Object.getOwnPropertyNames(o), Object.getOwnPropertySymbols(o));
