const sleep = (ms, v) => new Promise(r => setTimeout(() => r(v), ms));
const code = `
function* g(n) { for (let i = 0; i < n; i++) { const r = yield i; if (r) console.log('sent', r); } return 'done'; }
async function af(x) { const y = await sleep(2, x * 2); return y + 1; }
const arrow = async (a) => (await sleep(1, a)) + 100;
const arrow2 = async a => a + 1;
class K { *gen() { yield 1; yield* [2, 3]; } async am() { return await sleep(1, 'am'); } static async *ag() { yield 'a'; await sleep(1); yield 'b'; } }
const o = { *g() { yield 'o1'; }, async m() { return 'om'; }, async *ag() { yield 1; yield 2; } };
async function main() {
  console.log([...g(3)]);
  const it = g(2); console.log(it.next(), it.next('x'), it.next());
  console.log(await af(5), await arrow(1), await arrow2(1));
  console.log([...new K().gen()], await new K().am(), [...o.g()], await o.m());
  for await (const v of K.ag()) console.log('ag', v);
  for await (const v of o.ag()) console.log('oag', v);
  for await (const v of [sleep(1, 'p1'), 'p2']) console.log(v);
  const m = await import('path'); console.log(typeof m.default.join);
  try { await (async () => { throw new Error('rej'); })(); } catch (e) { console.log('caught', e.message); }
  return 'ok';
}
main().then(console.log);
`;
eval(code);
console.log(typeof eval('(async function(){})'), Object.prototype.toString.call(eval('(function*(){})()')));
