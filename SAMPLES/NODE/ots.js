var f = Object.prototype.toString;
console.log([undefined, null, [], function () {}, 'a', 1, true, {}, new Date(0), /x/, new Error('e'), new Map(), new Set(), Promise.resolve(), new WeakRef({}), Symbol('q'), 5n, Math, JSON].map(function (x) { return f.call(x); }).join(' '));
console.log(String({}), '' + [], `${{}}`, String(new Map()));
