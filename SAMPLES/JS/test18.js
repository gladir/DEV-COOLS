// test18.js - TODO 18 : Portee, pile et cadres
// Test 1 : Sauvegarde registres SI/DI dans fonction
function add(a, b) { return a + b; }
console.log(add(10, 20)); // 30

// Test 2 : Variables locales avec SI/DI offset correct
function square(x) {
  var result = x * x;
  return result;
}
console.log(square(7)); // 49

// Test 3 : Fonction avec plusieurs variables locales
function calc(a, b) {
  var sum = a + b;
  var diff = a - b;
  var prod = sum * diff;
  return prod;
}
console.log(calc(10, 3)); // (10+3)*(10-3) = 13*7 = 91

// Test 4 : Arrow function avec SI/DI sauvegarde
var dbl = x => x * 2;
console.log(dbl(15)); // 30

// Test 5 : Arrow multi-params
var mul = (a, b) => a * b;
console.log(mul(6, 8)); // 48

// Test 6 : Fonctions imbriquees (profondeur)
function outer(x) {
  function inner(y) {
    return x + y;
  }
  return inner(5);
}
console.log(outer(10)); // devrait etre 15 si pas capture, ou warning

// Test 7 : Arrow function avec bloc et locales
var compute = (a, b) => {
  var temp = a + b;
  return temp * 2;
};
console.log(compute(3, 4)); // 14

// Test 8 : this en contexte global
var t = this;
console.log(t); // 0 (XOR AX,AX)

// Test 9 : Fonction avec return au milieu
function early(x) {
  if (x > 5) { return x; }
  return 0;
}
console.log(early(10)); // 10
console.log(early(3));  // 0

// Test 10 : Chaine d'appels
function double(n) { return n * 2; }
function quad(n) { return double(double(n)); }
console.log(quad(5)); // 20
