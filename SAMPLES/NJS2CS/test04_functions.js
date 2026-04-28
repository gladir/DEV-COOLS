// test04_functions.js - Fonctions, recursion, fonctions flechees
function carre(x) {
  return x * x;
}

function factorielle(n) {
  if (n <= 1) return 1;
  return n * factorielle(n - 1);
}

console.log(carre(5));
console.log(factorielle(6));

var dbl = (x) => x + x;
console.log(dbl(21));

function additionne(a, b) {
  return a + b;
}
console.log(additionne(100, 200));
