// arrays.js - Exemple JS86 : tableaux, push/pop, forEach, sort, indexOf
// Compile : JS86.EXE arrays.js arrays.asm

// Creation de tableau
var nums = [10, 30, 20, 50, 40];
console.log(nums.length);
// attendu : 5

// push / pop
nums.push(60);
console.log(nums.length);
// attendu : 6

var last = nums.pop();
console.log(last);
// attendu : 60

// indexOf
var idx = nums.indexOf(30);
console.log(idx);
// attendu : 1

// sort (tri numerique ascendant)
nums.sort();
console.log(nums[0]);
// attendu : 10
console.log(nums[1]);
// attendu : 20
console.log(nums[2]);
// attendu : 30

// reverse
nums.reverse();
console.log(nums[0]);
// attendu : 50

// shift / unshift
var first = nums.shift();
console.log(first);
// attendu : 50

nums.unshift(5);
console.log(nums[0]);
// attendu : 5

// forEach avec fonction nommee
var sum = 0;
function addToSum(v) {
  sum = sum + v;
}
var arr = [1, 2, 3];
arr.forEach(addToSum);
console.log(sum);
// attendu : 6

// Acces par index
var letters = ["a", "b", "c"];
console.log(letters[1]);
// attendu : b
