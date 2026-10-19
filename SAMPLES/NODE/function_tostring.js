function add(a, b) { return a + b; }
var f2 = function named(x) { return x * 2; };
var arrow = (a, b) => a * b;
var arrow2 = async x => { await x; };
class Animal { constructor(n) { this.n = n; } speak() { return 'hi'; } static make() { return new Animal('x'); } get g() { return 1; } *gen() { yield 1; } async am() { } }
class Empty {}
class Sub extends Animal {}
var o = { m() { return 1; }, get p() { return 2; }, ['c' + 1]() { }, f: function () { }, a: () => 1 };
console.log(add.toString());
console.log(String(f2), '' + arrow, `${arrow2}`);
console.log(Animal.toString());
console.log(Empty.toString(), Sub.toString());
console.log(Animal.prototype.speak.toString(), Animal.make.toString(), Animal.prototype.gen.toString(), Animal.prototype.am.toString());
console.log(o.m.toString(), o.c1.toString(), o.f.toString(), o.a.toString());
console.log(Object.getOwnPropertyDescriptor(Animal.prototype, 'g').get.toString());
console.log(Math.max.toString(), (function () {}).bind(null).toString().length > 0, Function.prototype.toString.call(Symbol));
console.log(parseInt.toString(), Array.prototype.map.toString());
