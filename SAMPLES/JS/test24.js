// test24.js - TODO 24 : Runtime minimal

// Test 1 : numtostr via console.log
console.log(42);
// attendu : 42

// Test 2 : nombre negatif
console.log(-7);
// attendu : -7

// Test 3 : zero
console.log(0);
// attendu : 0

// Test 4 : concat de chaines
var a = "hello";
var b = " world";
var c = a + b;
console.log(c);
// attendu : hello world

// Test 5 : typeof number
var n = 10;
console.log(typeof n);
// attendu : number

// Test 6 : typeof string
var s = "test";
console.log(typeof s);
// attendu : string

// Test 7 : Math.abs
console.log(Math.abs(-15));
// attendu : 15

// Test 8 : Math.pow
console.log(Math.pow(2, 10));
// attendu : 1024

// Test 9 : grand nombre
console.log(32767);
// attendu : 32767

// Test 10 : concatenation nombre + string via expression
console.log(100);
console.log("ok");
// attendu : 100 puis ok
