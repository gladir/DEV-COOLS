const sleep = (ms, v) => new Promise(r => setTimeout(() => r(v), ms));
async function* gen() {
  try {
    yield 1;
    const x = await sleep(5, 10);
    yield x;
    const y = yield 'q';
    console.log('got', y);
    yield* [7, 8];
    yield* inner();
    return 'end';
  } finally { console.log('fin'); }
}
async function* inner() { yield 'i1'; await sleep(1); yield 'i2'; }
(async () => {
  for await (const v of gen()) console.log('v', v);
  const g = gen();
  console.log(await g.next(), await g.next(), await g.next(), await g.next('Y'));
  console.log(await g.return('R'));
  console.log(await g.next());
  for await (const v of [Promise.resolve(1), 2, sleep(3, 3)]) console.log('s', v);
  for await (const v of gen()) { if (v === 10) break; }
  const o = { async *m() { yield 'm1'; throw new Error('boom'); } };
  try { for await (const v of o.m()) console.log(v); } catch (e) { console.log('caught', e.message); }
  class C { static async *s() { yield 's1'; } }
  for await (const v of C.s()) console.log(v);
  const g2 = gen(); const ps = [g2.next(), g2.next(), g2.next()];
  console.log(await Promise.all(ps));
  console.log(Object.prototype.toString.call(g2), typeof g2[Symbol.asyncIterator]);
})();
