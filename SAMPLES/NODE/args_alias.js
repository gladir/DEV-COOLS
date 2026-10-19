function f(a, b) { arguments[0] = 'X'; b = 'Y'; return [a, b, arguments[0], arguments[1], arguments.length]; }
console.log(f(1, 2), f(1));
function g(a) { a = 5; return arguments[0]; }
console.log(g(1), g());
function h(a) { 'use strict'; a = 5; return arguments[0]; }
console.log(h(1));
function k(a, b) { a++; b += 2; return [a, b, [].slice.call(arguments)]; }
console.log(k(1, 2));
function d(a = 1) { a = 5; return arguments[0]; }
console.log(d(9));


function sw(a, b) { var t = arguments; t[1] = 99; return b; }
console.log(sw(1, 2));
