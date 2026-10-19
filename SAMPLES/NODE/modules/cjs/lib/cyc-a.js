exports.a = 'A';
const b = require('./cyc-b');
exports.a2 = 'A+' + b.b;
