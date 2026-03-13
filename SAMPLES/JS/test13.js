// test13.js - Test TODO 13 : if/else/switch
var x = 10;

// Test 1: if simple
if (x) {
  console.log(1);
}

// Test 2: if-else
if (0) {
  console.log(99);
} else {
  console.log(2);
}

// Test 3: else if chain
var y = 5;
if (y == 10) {
  console.log(99);
} else if (y == 5) {
  console.log(3);
} else {
  console.log(99);
}

// Test 4: switch-case
var z = 2;
switch (z) {
  case 1:
    console.log(99);
    break;
  case 2:
    console.log(4);
    break;
  case 3:
    console.log(99);
    break;
  default:
    console.log(99);
    break;
}

// Test 5: switch default
var w = 99;
switch (w) {
  case 1:
    console.log(99);
    break;
  default:
    console.log(5);
    break;
}

process.exit(0);
