// math.js - Exemple JS86 : fonctions, recursion, return, Math.*
// Compile : JS86.EXE math.js math.asm

// Fonction factorielle (recursion)
function factorial(n) {
  if (n <= 1) return 1;
  return n * factorial(n - 1);
}

console.log(factorial(5));
// attendu : 120

// Fonction fibonacci
function fib(n) {
  if (n <= 1) return n;
  return fib(n - 1) + fib(n - 2);
}

console.log(fib(10));
// attendu : 55

// Math.abs
console.log(Math.abs(-42));
// attendu : 42

// Math.pow
console.log(Math.pow(2, 8));
// attendu : 256

// Math.sqrt (racine entiere)
console.log(Math.sqrt(144));
// attendu : 12

// Math.max / Math.min
console.log(Math.max(10, 20));
// attendu : 20

console.log(Math.min(10, 20));
// attendu : 10

// Math.sign
console.log(Math.sign(-99));
// attendu : -1

// Fonction avec plusieurs parametres
function add(a, b) {
  return a + b;
}

console.log(add(100, 200));
// attendu : 300
