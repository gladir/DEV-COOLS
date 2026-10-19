var s = Symbol('abc');
console.log(typeof s, s.toString(), s.description, s.constructor === Symbol, s instanceof Symbol, String(s), Symbol.iterator.toString(), Symbol.for('k').description);
var o = {}; o[s] = 1; console.log(o[s], Object.keys(o).length, Symbol('x') === Symbol('x'), 'abc'.constructor === String, 'abc'.description);
