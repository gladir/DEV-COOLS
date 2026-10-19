var o = { a: 1, b: 2, f() { return this === o; }, name: 'obj' };
var a = 'outer-a', c = 'outer-c';
with (o) {
  console.log(a, b, c, f());
  a = 10;
  c = 'set-c';
  var d = a + b;
}
console.log(o.a, a, c);
function test(p) {
  var local = 5;
  with ({ p: 'shadow', x: 1 }) {
    local += x;
    console.log(p, local);
    function inner() { return x; }
  }
  for (var i = 0; i < 3; i++) {
    with ({ i2: i }) {
      if (i2 === 1) continue;
      if (i2 === 2) break;
      console.log('i2', i2);
    }
  }
  with (Math) { console.log(max(1, 2), PI > 3, typeof floor); }
  with ({ r: 7 }) { return r * local; }
}
console.log(test(1));
with ([1, 2, 3]) console.log(length, join('-'));
try { with (null) {} } catch (e) { console.log(e.constructor.name); }
with ({ x: 1 }) with ({ y: 2 }) console.log(x + y);
