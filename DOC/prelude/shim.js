global.__fname = function (f) { return f.name || ''; };
global.__fflags = function (f) { var s = Function.prototype.toString.call(f); var r = 0; if (/^class\b/.test(s)) r |= 16; if (/^async\b/.test(s)) r |= 2; if (/^(async\s+)?function\s*\*/.test(s)) r |= 4; return r; };
global.__fparent = function (f) { var p = Object.getPrototypeOf(f); return p === Function.prototype ? undefined : p; };
global.__extras = function (a) { var ks = Object.keys(a).filter(function (k) { return !(String(k >>> 0) === k && (k >>> 0) < a.length); }); if (!ks.length) return undefined; var o = {}; ks.forEach(function (k) { o[k] = a[k]; }); return o; };
global.__acc = function (o, k) { var d = Object.getOwnPropertyDescriptor(o, k); if (!d || !('get' in d || 'set' in d)) return 0; return (d.get ? 1 : 0) | (d.set ? 2 : 0); };
global.__write = function (fd, s) { (fd === 2 ? process.stderr : process.stdout).write(s); };
global.__setgrp = function () {};
