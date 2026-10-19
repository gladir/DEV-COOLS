try { undefinedFn(); } catch (e) { console.log(e.name, e.message); }
try { console.log(nope + 1); } catch (e) { console.log(e.name, e.message); }
console.log(typeof nope2, typeof undefinedThing === 'undefined');
globalThis.fromGlobal = 42;
console.log(fromGlobal, typeof fromGlobal);
globalThis.gfn = function () { return 'called'; };
console.log(gfn());
function f() { return later; }
try { f(); } catch (e) { console.log(e.message); }
globalThis.later = 'L';
console.log(f());
