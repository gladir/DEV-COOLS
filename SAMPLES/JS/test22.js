// test22.js - TODO 22 : Closures et references

// Test 1 : Closure simple - variable capturee par fonction imbriquee
function makeCounter() {
  var count = 0;
  function increment() {
    count = count + 1;
    return count;
  }
  return increment;
}
var inc = makeCounter();
console.log(inc()); // 1
console.log(inc()); // 2

// Test 2 : Closure avec parametre capture
function makeAdder(x) {
  function add(y) {
    return x + y;
  }
  return add;
}
var add5 = makeAdder(5);
console.log(add5(3)); // 8

// Test 3 : Arrow function et this (contexte global = 0)
var arrow = () => {
  return this;
};
console.log(arrow()); // 0

// Test 4 : Closure avec arrow function
function makeMultiplier(factor) {
  var mul = y => factor * y;
  return mul;
}
var dbl = makeMultiplier(2);
console.log(dbl(7)); // 14

// Test 5 : Operateur de reference &
function square(n) {
  return n * n;
}
var fptr = &square;
console.log(fptr(4)); // 16

// Test 6 : Fermeture partagee (deux fonctions capturent la meme variable)
function makeGetSet() {
  var val = 0;
  function getter() { return val; }
  function setter(v) { val = v; }
  getter();
  setter(42);
  return getter();
}
console.log(makeGetSet()); // 42

// Test 7 : Fonction retournee comme valeur (ptr code dans AX)
function identity(x) { return x; }
var f = identity;
console.log(f(99)); // 99

// Test 8 : Variable modifiee apres creation de closure
function modAfter() {
  var x = 10;
  function readX() { return x; }
  x = 20;
  return readX();
}
console.log(modAfter()); // 20
