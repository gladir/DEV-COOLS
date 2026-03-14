// test16.js - Test TODO 16 : Objets litteraux et acces proprietes

// Test 1: objet litteral simple + acces propriete
let obj = {x: 10, y: 20};
console.log(obj.x);
console.log(obj.y);

// Test 2: affectation de propriete existante
obj.x = 42;
console.log(obj.x);

// Test 3: ajout de propriete a l execution
obj.z = 99;
console.log(obj.z);

// Test 4: objet avec valeurs calculees
let a = 5;
let b = {val: a + 3};
console.log(b.val);

// Test 5: Object.keys()
let keys = Object.keys(obj);
console.log(keys.length);

// Test 6: Object.assign()
let src = {m: 77};
let dst = {n: 88, m: 0};
Object.assign(dst, src);
console.log(dst.m);

// Test 7: plusieurs proprietes
let p = {a: 1, b: 2, c: 3};
console.log(p.a);
console.log(p.b);
console.log(p.c);
