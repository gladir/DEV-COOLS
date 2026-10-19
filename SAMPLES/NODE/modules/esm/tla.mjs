import { setTimeout as sleep } from 'timers/promises';
const v = await Promise.resolve(41);
console.log('v', v + 1);
await sleep(5);
export const late = 'late';
const f = async () => { await null; return 1; };
console.log(await f(), typeof late);
for (const x of [1, 2]) { console.log('x', await Promise.resolve(x)); }
