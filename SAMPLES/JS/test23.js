// test23.js - TODO 23 : Exceptions (try/catch/finally/throw)

// Test 1 : try/catch basique
try {
  console.log(1);
} catch (e) {
  console.log(0);
}
// attendu : 1

// Test 2 : throw et catch
try {
  throw "erreur simple";
} catch (e) {
  console.log(e);
}
// attendu : erreur simple

// Test 3 : try/catch/finally
var x = 0;
try {
  x = 10;
} catch (e) {
  x = 99;
} finally {
  x = x + 1;
}
console.log(x);
// attendu : 11 (try ok -> x=10, finally x=10+1=11)

// Test 4 : throw avec catch qui utilise la variable
try {
  throw "boom";
} catch (err) {
  console.log(err);
}
// attendu : boom

// Test 5 : new Error(msg) et throw
try {
  throw new Error("test error");
} catch (e) {
  console.log(e);
}
// attendu : test error

// Test 6 : code apres catch continue normalement
var y = 5;
try {
  throw "stop";
} catch (e) {
  y = 42;
}
console.log(y);
// attendu : 42

// Test 7 : try sans exception - catch ignore
var z = 100;
try {
  z = 200;
} catch (e) {
  z = 0;
}
console.log(z);
// attendu : 200

// Test 8 : try/finally sans catch
var w = 0;
try {
  w = 7;
} finally {
  w = w + 3;
}
console.log(w);
// attendu : 10
