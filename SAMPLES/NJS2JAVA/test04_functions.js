// test04_functions.js - Fonctions, recursion, fonctions imbriquees
function carre(x) {
  return x * x;
}

function factorielle(n) {
  if (n <= 1) return 1;
  return n * factorielle(n - 1);
}

console.log(carre(5));
console.log(factorielle(6));

function dbl(x) {
  return x + x;
}
console.log(dbl(21));

function additionne(a, b) {
  return a + b;
}
console.log(additionne(100, 200));
