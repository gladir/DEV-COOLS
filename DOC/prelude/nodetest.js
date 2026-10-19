require('./shim.js');
const fs = require('fs'), util = require('util');
eval(fs.readFileSync('prelude.js', 'utf8').replace(/^function (\w+)/gm, 'global.$1 = function $1').replace(/^var __i_g;/m, 'global.__i_g = undefined;'));
let fail = 0, n = 0;
function chk(...args) {
  n++;
  const a = __i_args(args), b = util.format(...args);
  if (a !== b) { fail++; console.log('--- MISMATCH\nours:\n' + a + '\nnode:\n' + b); }
}
class A { constructor() { this.x = 1; } get g() { return 1; } static s() {} }
class B extends A { constructor() { super(); this.y = [1, 2]; } }
function foo(a, b) {}
const circ = { name: 'c' }; circ.self = circ;
const big = []; for (let i = 0; i < 30; i++) big.push(i * 7);
const strs = []; for (let i = 0; i < 12; i++) strs.push('item' + i);
const o3 = { a: { b: { c: { d: 1 } } } };
const m = /(a)(b)?/.exec('xab');
chk(1, 'a', null, undefined, true, -0, 1.5, NaN);
chk('hello'); chk(['a', "it's", 'say "hi"', `both ' "`, 'multi\nline', 'tab\t']);
chk({}); chk([]); chk({ a: 1, b: 'x', c: [1, 2, 3], d: { e: null } });
chk(big); chk(strs); chk([1, 'a', true]);
chk(new A()); chk(new B()); chk(A); chk(B); chk(foo); chk(() => 1); chk(async function af() {});
chk(circ); chk(o3); chk([[1, [2, [3, [4]]]]]);
chk({ 'a-b': 1, 2: 3, $x: 4, _y: 5 });
chk(/re/gi); chk([/a/, /b/g]);
chk({ get a() { return 1; }, set a(v) {}, get b() { return 2; }, set c(v) {} });
chk(Object.create(null)); chk(Object.assign(Object.create(null), { z: 1 }));
chk(m);
chk('%s is %d years', 'Bob', 42, 'extra', { a: 1 });
chk('%s %s', 'only'); chk('100%', 5); chk('%%', 1); chk('a%%b'); chk('%i %f %j %o %O %c.', '42.5x', '3.5y', { a: 1 }, [1], { b: 2 }, 'css');
chk('%s', { a: { b: 1 } }); chk('%s', [1, 2]); chk('%s', null, -0); chk('%d', '0x10'); chk('%s', { toString() { return 'custom'; } });
chk({ f: foo, g: () => 1, h: A, r: /x/, n: null, u: undefined });
chk({ longlonglonglong1: 'aaaaaaaaaaaaaaaaaaaaaaa', longlonglonglong2: 'bbbbbbbbbbbbbbbbbbbbbbbb', longlonglonglong3: 'ccccccccccccccccc' });
chk([{ a: 1, b: 2 }, { a: 3, b: 4 }]);
chk({ users: [{ name: 'Al', tags: ['x', 'y'] }, { name: 'Bo', tags: [] }], total: 2 });
const long = []; for (let i = 0; i < 120; i++) long.push(i);
chk(long);
chk(['a'.repeat(100)]); chk('x', 'a\nb'.repeat(30).split('\n'));
chk({ s: 'line1\nline2\nline3 and a much longer content here to pass the limit of width ok ok ok' });
chk(new Error('boom').message);
chk([1.5, 22.25, 333, -4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27]);
chk(['apple', 'banana', 'cherry', 'dragonfruit', 'elderberry', 'fig', 'grape', 'honeydew']);
console.log(n + ' cases, ' + fail + ' mismatches');
