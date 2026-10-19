import def, { a, b as bb, counter, inc } from './lib/mod.mjs';
import * as ns from './lib/mod.mjs';
import fs, { existsSync } from 'fs';
import path from 'node:path';
import Logger from './lib/logger.mjs';
import cjs from './lib/cjs.cjs'; const { plain } = cjs;
import './lib/side.mjs';
export { a as exported };
export const Z = 5;
export default function main() { return 'main'; }
console.log(def, a, bb, counter);
inc(); inc();
console.log(ns.counter, Object.keys(ns).sort().join(','), ns.default);
console.log(typeof fs.readFileSync, existsSync('.'), path.basename('/x/y.txt'));
const l = new Logger('L'); l.log('hi');
console.log(cjs.plain, plain, typeof cjs);
console.log(typeof import.meta.url);
import('./lib/mod.mjs').then(m => console.log('dyn', m.a, m.default));
