// test11.js - TODO 11 : Expressions binaires (Pratt)

// Arithmetique entre variables
let a = 10;
let b = 3;
let sum = a + b;
let diff = a - b;
let prod = a * b;
let quot = a / b;
let rem = a % b;

// Pliage de constantes
let c1 = 2 + 3;
let c2 = 10 - 4;
let c3 = 3 * 7;
let c4 = 20 / 5;
let c5 = 17 % 5;

// Comparaisons entre variables
let eq = a == b;
let ne = a != b;
let lt = a < b;
let le = b <= b;
let gt = a > b;
let ge = a >= a;

// Egalite stricte
let seq = a === 10;
let sne = a !== 5;

// Operateurs bit-a-bit entre variables
let band = a & b;
let bor  = a | b;
let bxor = a ^ b;
let shl  = a << 1;
let shr  = a >> 1;

// Court-circuit && et ||
let x = 5;
let y = 0;
let and1 = x && 42;
let or1  = y || 99;
let and2 = y && 42;
let or2  = x || 99;

// Nullish ??
let n = 0;
let nul = n ?? 7;

// Ternaire non-constant
let t1 = x ? 100 : 200;
let t2 = y ? 100 : 200;

// Ternaire constant
let t3 = 1 ? 11 : 22;
let t4 = 0 ? 11 : 22;

// Operateur virgule
let v = (1, 2, 3);

// Expressions mixtes imm + var
let m1 = 5 + a;
let m2 = a - 1;
let m3 = 2 * b;

// Chaine concatenation
let s1 = "hello";
let s2 = "world";
let s3 = s1 + s2;
