// control.js - Exemple JS86 : if/else if, switch/case, while, for, for-of
// Compile : JS86.EXE control.js control.asm

// if / else if / else
var x = 15;
if (x > 20) {
  console.log("grand");
} else if (x > 10) {
  console.log("moyen");
} else {
  console.log("petit");
}
// attendu : moyen

// switch / case
var day = 3;
switch (day) {
  case 1:
    console.log("lundi");
    break;
  case 2:
    console.log("mardi");
    break;
  case 3:
    console.log("mercredi");
    break;
  default:
    console.log("autre");
    break;
}
// attendu : mercredi

// while
var i = 0;
var total = 0;
while (i < 5) {
  total = total + i;
  i = i + 1;
}
console.log(total);
// attendu : 10

// for classique
var sum = 0;
for (var j = 1; j <= 10; j = j + 1) {
  sum = sum + j;
}
console.log(sum);
// attendu : 55

// for-of sur tableau
var fruits = ["pomme", "banane", "cerise"];
for (var f of fruits) {
  console.log(f);
}
// attendu : pomme, banane, cerise

// do-while
var k = 1;
var product = 1;
do {
  product = product * k;
  k = k + 1;
} while (k <= 5);
console.log(product);
// attendu : 120

// Ternaire
var age = 18;
var status = (age >= 18) ? "majeur" : "mineur";
console.log(status);
// attendu : majeur
