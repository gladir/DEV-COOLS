function f() { return this; }
console.log(f() === globalThis, typeof f());
function g() { 'use strict'; return this; }
console.log(g());
var o = { m() { return this; }, a: function () { return this === o; } };
var m = o.m; console.log(m() === globalThis, o.a(), (0, o.m)() === globalThis);
class C { m() { return this; } static s() { return this; } }
var cm = new C().m; console.log(cm(), (0, C.s)());
function h() { var self = this; return function () { return self === globalThis; }(); }
console.log(h());
function k() { return (() => this === globalThis)(); }
console.log(k());
var arrow = () => typeof this; console.log(arrow());
function Ctor() { this.x = 1; } var inst = new Ctor(); console.log(inst.x);
Ctor.call(null); console.log(globalThis.x);
(function () { 'use strict'; console.log((function () { return this; })()); })();
console.log([1, 2].map(function () { return this === globalThis; }));
