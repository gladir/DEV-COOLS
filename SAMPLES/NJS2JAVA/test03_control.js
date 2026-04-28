// test03_control.js - if/else, while, for, for...of, switch
var n = 7;
if (n > 5) {
  console.log("grand");
} else {
  console.log("petit");
}

var sum = 0;
for (var i = 1; i <= 5; i = i + 1) {
  sum = sum + i;
}
console.log(sum);

var fruits = ["pomme", "banane", "cerise"];
for (var f of fruits) {
  console.log(f);
}

switch (n) {
  case 1: console.log("un"); break;
  case 7: console.log("sept"); break;
  default: console.log("autre"); break;
}

var k = 0;
while (k < 3) {
  console.log(k);
  k = k + 1;
}
