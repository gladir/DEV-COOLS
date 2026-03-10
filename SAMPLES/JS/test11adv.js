// test11adv.js - TODO 11 tests avances

// Expressions chainees : a + b * c
let a = 2;
let b = 3;
let c = 4;
let r1 = a + b * c;

// Priorite : (a + b) * c via parens
let r2 = (a + b) * c;

// Division par zero protegee
let r3 = a / 0;

// Modulo
let r4 = 17 % 5;
let r5 = a % b;

// Puissance **
let r6 = a ** b;

// Ternaire imbrique
let x = 1;
let r7 = x ? (x > 0 ? 10 : 20) : 30;

// Court-circuit && chaine
let r8 = a && b && c;

// Court-circuit || chaine
let z = 0;
let r9 = z || 0 || 42;

// Comparaisons chainees via &&
let r10 = (a < b) && (b < c);

// instanceof et in (stubs)
let obj = {};
let r11 = a instanceof obj;
let r12 = "x" in obj;

// Assignation composee avec expressions
let v = 10;
v += a * b;
v -= 1;
v *= 2;
