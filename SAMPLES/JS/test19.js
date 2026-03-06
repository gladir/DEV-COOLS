// test19.js - TODO 19 : Expressions regulieres (RegExp basique)

// Test 1 : regexp literal simple
var re = /hello/;
console.log(re);

// Test 2 : re.test(str) - match
var re2 = /world/;
var s = "hello world";
var found = re2.test(s);
console.log(found); // 1

// Test 3 : re.test(str) - no match
var re3 = /xyz/;
var notfound = re3.test(s);
console.log(notfound); // 0

// Test 4 : str.match(re)
var m = s.match(re);
console.log(m); // 1

// Test 5 : str.search(re)
var idx = s.search(re2);
console.log(idx); // 6

// Test 6 : str.search - not found
var idx2 = s.search(re3);
console.log(idx2); // -1

// Test 7 : new RegExp(pat, flags)
var re4 = new RegExp("llo", "g");
var t = re4.test(s);
console.log(t); // 1

// Test 8 : re.exec(str)
var ex = re2.exec(s);
console.log(ex); // ptr (non-zero si match)

// Test 9 : str.replace(pattern, repl)
var orig = "foo bar foo";
var rep = orig.replace("foo", "baz");
console.log(rep); // "baz bar foo"

// Test 10 : empty pattern match
var re5 = /test/;
var r = re5.test("this is a test");
console.log(r); // 1
