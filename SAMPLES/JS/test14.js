// test14.js - Test TODO 14 : boucles while / do-while / for / break / continue

// Test 1: while simple - somme 1..5 = 15
var sum = 0;
var i = 1;
while (i <= 5) {
  sum = sum + i;
  i = i + 1;
}
console.log(sum);

// Test 2: do-while - somme 1..3 = 6
var s2 = 0;
var j = 1;
do {
  s2 = s2 + j;
  j = j + 1;
} while (j <= 3);
console.log(s2);

// Test 3: for classique - somme 0..4 = 10
var s3 = 0;
for (let k = 0; k < 5; k = k + 1) {
  s3 = s3 + k;
}
console.log(s3);

// Test 4: break dans while
var s4 = 0;
var m = 0;
while (1) {
  if (m == 3) {
    break;
  }
  s4 = s4 + m;
  m = m + 1;
}
console.log(s4);

// Test 5: continue dans for
var s5 = 0;
for (let n = 0; n < 5; n = n + 1) {
  if (n == 2) {
    continue;
  }
  s5 = s5 + n;
}
console.log(s5);

process.exit(0);
