// test15.js - Test TODO 15 : Tableaux (Array)

// Test 1: declaration litteral + acces par index
let arr = [10, 20, 30];
console.log(arr[0]);
console.log(arr[1]);
console.log(arr[2]);

// Test 2: arr.length
console.log(arr.length);

// Test 3: arr[i] = expr (affectation par index)
arr[1] = 99;
console.log(arr[1]);

// Test 4: arr.push(v) + length apres push
arr.push(40);
console.log(arr.length);
console.log(arr[3]);

// Test 5: arr.pop()
let v = arr.pop();
console.log(v);
console.log(arr.length);

// Test 6: arr.indexOf(val)
let idx = arr.indexOf(99);
console.log(idx);

// Test 7: arr.reverse()
let r = [1, 2, 3];
r.reverse();
console.log(r[0]);
console.log(r[2]);

// Test 8: arr.sort()
let s = [30, 10, 20];
s.sort();
console.log(s[0]);
console.log(s[1]);
console.log(s[2]);

// Test 9: new Array(n)
let a2 = new Array(3);
console.log(a2.length);

process.exit(0);
