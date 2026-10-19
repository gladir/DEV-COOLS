var seed = 12345;
function rnd() { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed; }
var pool = [];
var i;
for (i = 0; i < 600; i++) pool.push(rnd() % 0x300);
for (i = 0; i < 800; i++) pool.push(0x300 + rnd() % 0x70);
for (i = 0; i < 600; i++) pool.push(0x1e00 + rnd() % 0x300);
for (i = 0; i < 400; i++) pool.push(0x2000 + rnd() % 0x1000);
for (i = 0; i < 400; i++) pool.push(0x3040 + rnd() % 0x100);
for (i = 0; i < 300; i++) pool.push(0xac00 + rnd() % 11172);
for (i = 0; i < 300; i++) pool.push(0x1100 + rnd() % 0x100);
for (i = 0; i < 300; i++) pool.push(0xfb00 + rnd() % 0x500);
for (i = 0; i < 200; i++) pool.push(0x1d400 + rnd() % 0x400);
for (i = 0; i < 200; i++) pool.push(0x0900 + rnd() % 0x400);
for (i = 0; i < 100; i++) pool.push(0x1f100 + rnd() % 0x300);
var sum = 0, n = 0, bad = 0;
for (i = 0; i < 1500; i++) {
  var len = 1 + rnd() % 6, s = '', j;
  for (j = 0; j < len; j++) s += String.fromCodePoint(pool[rnd() % pool.length]);
  ['NFC', 'NFD', 'NFKC', 'NFKD'].forEach(function (f) {
    var r = s.normalize(f);
    for (var k = 0; k < r.length; k++) sum = (sum * 31 + r.charCodeAt(k)) % 1000000007;
    n++;
  });
}
console.log(n, sum);
