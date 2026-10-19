const cp = require('child_process');
const win = process.platform === 'win32';
const r = cp.spawnSync(win ? 'cmd' : 'sh', win ? ['/c', 'echo spawn out'] : ['-c', 'echo spawn out'], { encoding: 'utf8' });
console.log(r.status, JSON.stringify(r.stdout.trim()), r.stderr);
try { cp.execSync('exit 3', { stdio: 'pipe' }); } catch (e) { console.log('failed', e.status); }
var c = cp.spawn(win ? 'cmd' : 'sh', win ? ['/c', 'echo child'] : ['-c', 'echo child']);
c.stdout.on('data', d => console.log('data', JSON.stringify(d.toString().trim())));
c.on('close', code => {
  console.log('close', code);
  cp.exec('echo async', (err, out, errout) => { console.log(err, JSON.stringify(out.trim()), JSON.stringify(errout)); });
});
