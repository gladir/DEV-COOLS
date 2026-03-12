// test20.js - Test des methodes natives String / Number / Math / JSON (TODO 20)

// --- String methods ---
var s = "Hello World";

// 1. length
var len = s.length;
console.log(len);

// 2. indexOf
var idx = s.indexOf("World");
console.log(idx);

// 3. lastIndexOf
var s2 = "abcabc";
var li = s2.lastIndexOf("abc");
console.log(li);

// 4. includes
var inc = s.includes("llo");
console.log(inc);

// 5. startsWith / endsWith
var sw = s.startsWith("Hel");
console.log(sw);
var ew = s.endsWith("rld");
console.log(ew);

// 6. charAt / charCodeAt
var ch = s.charAt(0);
console.log(ch);
var code = s.charCodeAt(0);
console.log(code);

// 7. toUpperCase / toLowerCase
var up = s.toUpperCase();
console.log(up);
var lo = s.toLowerCase();
console.log(lo);

// 8. trim
var s3 = "  hi  ";
var tr = s3.trim();
console.log(tr);

// 9. slice / substring
var sl = s.slice(0, 5);
console.log(sl);
var sub = s.substring(6, 11);
console.log(sub);

// 10. repeat
var rp = "ab".repeat(3);
console.log(rp);

// 11. padStart
var ps = "42".padStart(5, "0");
console.log(ps);

// 12. String.fromCharCode
var fc = String.fromCharCode(65);
console.log(fc);

// 13. split
var parts = "a,b,c".split(",");
console.log(parts.length);

// --- Number methods ---

// 14. parseInt
var n1 = parseInt("42");
console.log(n1);

// 15. parseInt with radix
var n2 = parseInt("FF", 16);
console.log(n2);

// 16. Number()
var n3 = Number("123");
console.log(n3);

// 17. isNaN / isFinite
var nan = isNaN(42);
console.log(nan);
var fin = isFinite(42);
console.log(fin);

// 18. Number.isInteger
var ni = Number.isInteger(42);
console.log(ni);

// --- Math methods ---

// 19. Math.abs
var ab = Math.abs(-5);
console.log(ab);

// 20. Math.max / Math.min
var mx = Math.max(3, 7);
console.log(mx);
var mn = Math.min(3, 7);
console.log(mn);

// 21. Math.pow
var pw = Math.pow(2, 10);
console.log(pw);

// 22. Math.sqrt
var sq = Math.sqrt(144);
console.log(sq);

// 23. Math.floor / ceil / round (pass-through)
var fl = Math.floor(42);
console.log(fl);

// 24. Math.sign
var sg = Math.sign(-10);
console.log(sg);

// 25. Math.PI
var pi = Math.PI;
console.log(pi);

// 26. Math.random (just check it compiles)
var rnd = Math.random();

// --- JSON ---
// 27. JSON.stringify (simple)
var js = JSON.stringify(42);
console.log(js);

// 28. JSON.parse (stub)
var jp = JSON.parse("42");

process.exit(0);
