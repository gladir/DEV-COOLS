// eval.js - eval complet (instructions, variables du programme), new Function,
// new.target par fonction, gabarits etiquetes en cache, BigInt, path.

var gx = 5;
let gy = 6;
function gdouble(n) { return n * 2; }

// Test 1 : expressions et variables du programme
console.log(eval('gx + gy'));
// attendu : 11
console.log(eval('gdouble(21)'));
// attendu : 42

// Test 2 : instructions, boucles, fonctions, classes
console.log(eval('var s = 0; for (var i = 1; i <= 10; i++) { s += i; } s'));
// attendu : 55
console.log(eval('function fact(n) { return n <= 1 ? 1 : n * fact(n - 1); } fact(6)'));
// attendu : 720
console.log(eval('class A { constructor(x) { this.x = x; } get d() { return this.x * 2; } } new A(4).d'));
// attendu : 8

// Test 3 : affectation d'une variable du programme depuis eval
eval('gx = 50');
console.log(gx);
// attendu : 50

// Test 4 : new Function
var add = new Function('a', 'b', 'return a + b + gx');
console.log(add(1, 2));
// attendu : 53

// Test 5 : new.target ne fuit pas vers un appel ordinaire
function helper() { return new.target === undefined; }
function Ctor() { this.h = helper(); this.t = new.target === Ctor; }
var c = new Ctor();
console.log(c.h);
// attendu : true
console.log(c.t);
// attendu : true

// Test 6 : gabarits etiquetes, meme tableau a chaque passage
function tag(s) { return s; }
function site() { return tag`a${1}b`; }
console.log(site() === site());
// attendu : true

// Test 7 : BigInt nul faux, egalite par valeur
console.log(0n ? 1 : 2);
// attendu : 2
console.log([1n, 2n].indexOf(2n));
// attendu : 1

// Test 8 : path comme Node sous Windows
var path = require('path');
console.log(path.join('a', 'b', '..', 'c.txt'));
// attendu : a\c.txt
console.log(path.posix.join('a', 'b'));
// attendu : a/b
