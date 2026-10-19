function f(a, b) {
  let x = 10; var y = 20; const z = 5;
  function inner() { return 'inner' + a; }
  console.log(eval('a + b + x + y + z'));
  eval('x = 99; y++; var w = 7;');
  console.log(x, y, eval('w'), eval('inner()'));
  const g = () => eval('x + this.k');
  return [g.call({k: 1}), eval('(function(){ return a * 2; })')()];
}
console.log(f.call({k: 1}, 3, 4));
let top = 'T';
{ let blk = 'B'; console.log(eval('top + blk')); }
class A { constructor() { this.v = 5; } m(p) { let q = 2; return eval('this.v + p + q'); } }
console.log(new A().m(1));
function counter() { let c = 0; return { inc: () => eval('++c'), get: () => c }; }
const cc = counter(); cc.inc(); cc.inc(); console.log(cc.get());
var ev = eval; let notvisible = 1;
function h() { let loc = 1; try { return (0, eval)('typeof loc'); } catch (e) { return 'err'; } }
console.log(h(), eval('1+1'), eval(42));
for (let i = 0; i < 2; i++) console.log(eval('i * 3'));
function sh(x) { { let x = 'inner'; return eval('x'); } }
console.log(sh('outer'));
