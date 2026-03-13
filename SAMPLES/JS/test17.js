// test17.js - Test TODO 17 : Fonctions (function / arrow / return)

// Test 1: declaration de fonction + appel
function add(a, b) {
  return a + b;
}
console.log(add(3, 4));

// Test 2: return sans valeur -> undefined = 0
function nothing() {
  return;
}
console.log(nothing());

// Test 3: absence de return -> 0
function empty() {
}
console.log(empty());

// Test 4: fonction avec variable locale
function square(x) {
  let result = x * x;
  return result;
}
console.log(square(5));

// Test 5: expression function
let double = function(n) {
  return n * 2;
};
console.log(double(6));

// Test 6: arrow function single-param
let triple = n => n * 3;
console.log(triple(4));

// Test 7: arrow function multi-params
let mul = (a, b) => a * b;
console.log(mul(3, 5));

// Test 8: arrow function avec bloc
let inc = (x) => {
  let y = x + 1;
  return y;
};
console.log(inc(9));

// Test 9: appel de fonction par variable (higher-order)
function apply(f, val) {
  return f(val);
}
console.log(apply(double, 7));

// Test 10: zero-param arrow
let getVal = () => 42;
console.log(getVal());
