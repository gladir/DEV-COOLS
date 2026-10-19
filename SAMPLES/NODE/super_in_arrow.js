class A { constructor(x) { this.x = x; this.log = ['A']; } hi() { return 'A.hi'; } }
class B extends A {
  fld = 7;
  constructor(x) {
    const init = () => { super(x * 2); this.log.push('after'); };
    init();
    this.y = 1;
  }
}
var b = new B(5);
console.log(b.x, b.y, b.fld, b.log, b instanceof B, b.hi());
class C extends A {
  constructor() {
    const f = (v) => { const g = () => super(v + 1); g(); };
    f(10);
    console.log(this.x, new.target === C);
  }
}
new C();
class D extends A {
  constructor() {
    setTimeout(() => console.log('timer', this.x), 0);
    [1].forEach(() => super(99));
  }
}
new D();
class E2 extends B { constructor() { (() => super(3))(); this.z = 'z'; } }
var e = new E2(); console.log(e.x, e.y, e.z, e.log);
