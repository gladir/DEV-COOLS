// gc.js - ramasse-miettes : beaucoup plus de memoire allouee que le tas n'en
// garde ; le programme ne finit que si la memoire est recuperee.

// Collecte frequente (tous les 100 Ko alloues) pour que le test reste court
if (typeof __gcstress === 'function') __gcstress(100000);

// Test 1 : 12000 objets ephemeres, quelques-uns conserves
var keep = [];
var total = 0;
for (var i = 0; i < 12000; i++) {
  var o = { a: i, b: "s" + (i % 100), c: [i, i + 1] };
  total += o.c[1] - o.a;
  if (i % 2000 === 0) keep.push(o);
}
console.log(total);
// attendu : 12000
console.log(keep.length);
// attendu : 6
console.log(keep[5].c[0]);
// attendu : 10000

// Test 2 : chaines qui grandissent, tableaux de chaines
var s = "";
for (var i = 0; i < 1000; i++) s += "abcdefghij";
console.log(s.length);
// attendu : 10000
var parts = [];
for (var i = 0; i < 3000; i++) parts.push("item" + i);
console.log(parts.join(",").split(",").length);
// attendu : 3000

// Test 3 : liste chainee de 4000 maillons, vivante pendant les collectes
var lst = null;
for (var i = 0; i < 4000; i++) lst = { next: lst, v: i };
var junk = 0;
for (var i = 0; i < 6000; i++) junk += [i, i].length;
var c = 0;
for (var p = lst; p; p = p.next) c++;
console.log(c);
// attendu : 4000

// Test 4 : generateurs et Map sous pression memoire
function* gen(n) { for (var i = 0; i < n; i++) yield { i: i }; }
var gs = 0;
for (var r = 0; r < 300; r++) for (var x of gen(20)) gs += x.i;
console.log(gs);
// attendu : 57000
var m = new Map();
for (var i = 0; i < 6000; i++) m.set(i % 977, { v: i });
console.log(m.size);
// attendu : 977

// Test 5 : le compte de collectes augmente
console.log(typeof __gcstats !== 'function' || __gcstats()[1] > 0);
// attendu : true
