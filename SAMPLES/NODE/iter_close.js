function* g(){ try { yield 1; yield 2; } finally { console.log('fin'); } }
for (const v of g()) { break; }
const it = { [Symbol.iterator]() { return { next(){ return {value:1, done:false}; }, return(){ console.log('ret'); return {}; } }; } };
for (const v of it) break;
console.log(Object.prototype.toString.call(g()));
function* g2(){ try { yield 1; yield 2; } finally { console.log('fin2'); } }
function f(){ for (const v of g2()) { return v; } }
console.log(f());
outer: for (const a of [1,2]) { for (const v of g2()) { continue outer; } }
try { for (const v of g2()) throw new Error('x'); } catch (e) { console.log(e.message); }
for (const v of g2()) { continue; }
const bad = { [Symbol.iterator]() { return { next(){ throw new Error('nx'); }, return(){ console.log('NO'); return {}; } }; } };
try { for (const v of bad) ; } catch (e) { console.log(e.message); }
function* h(){ for (const x of g2()) yield x; }
const hh = h(); hh.next(); hh.return(5);
for (const x of 'ab') console.log(x);
for (const [k,v] of new Map([[1,2]])) console.log(k,v);
