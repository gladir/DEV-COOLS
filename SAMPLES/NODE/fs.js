const fs = require('fs');
const path = require('path');
const d = 'fs1_tmp_dir';
if (fs.existsSync(d)) fs.rmSync(d, { recursive: true, force: true });
console.log(fs.existsSync(d));
console.log(fs.mkdirSync(d + '/a/b', { recursive: true }));
fs.writeFileSync(d + '/x.txt', 'hello\nworld\n');
fs.appendFileSync(d + '/x.txt', 'moreé\n');
console.log(JSON.stringify(fs.readFileSync(d + '/x.txt', 'utf8')));
console.log(fs.readFileSync(d + '/x.txt').length, fs.statSync(d + '/x.txt').size, fs.statSync(d).isDirectory(), fs.statSync(d + '/x.txt').isFile());
fs.writeFileSync(d + '/a/y.bin', Buffer.from([1, 2, 3, 255]));
console.log(fs.readFileSync(d + '/a/y.bin'));
console.log(fs.readdirSync(d), fs.readdirSync(d, { withFileTypes: true }).map(e => e.name + ':' + e.isDirectory()));
console.log(fs.readdirSync(d, { recursive: true }).sort());
fs.renameSync(d + '/x.txt', d + '/z.txt');
fs.copyFileSync(d + '/z.txt', d + '/c.txt');
console.log(fs.readdirSync(d));
try { fs.readFileSync(d + '/nope.txt'); } catch (e) { console.log(e.code, e.syscall, e.errno, e.message); }
try { fs.mkdirSync(d); } catch (e) { console.log(e.code, e.message); }
try { fs.rmdirSync(d); } catch (e) { console.log(e.code); }
fs.unlinkSync(d + '/c.txt');
var fd = fs.openSync(d + '/w.txt', 'w');
fs.writeSync(fd, 'abc');
fs.writeSync(fd, Buffer.from('def'));
fs.closeSync(fd);
fd = fs.openSync(d + '/w.txt', 'r');
var b = Buffer.alloc(4);
console.log(fs.readSync(fd, b, 0, 4, 1), b.toString('utf8', 0, 4));
fs.closeSync(fd);
fs.truncateSync(d + '/w.txt', 2);
console.log(fs.readFileSync(d + '/w.txt', 'utf8'));
fs.readFile(d + '/w.txt', 'utf8', (err, data) => {
  console.log('cb', err, data);
  fs.promises.readFile(d + '/z.txt', 'utf8').then(t => {
    console.log('promise', t.length);
    return fs.promises.readdir(d);
  }).then(l => {
    console.log(l);
    var ws = fs.createWriteStream(d + '/s.txt');
    ws.write('line1\n'); ws.end('line2\n');
    ws.on('close', () => {
      var rs = fs.createReadStream(d + '/s.txt', 'utf8');
      rs.on('data', c => console.log('stream', JSON.stringify(c)));
      rs.on('close', () => { fs.rmSync(d, { recursive: true }); console.log(fs.existsSync(d)); });
    });
  });
});
console.log(typeof process.cwd(), process.cwd() === path.resolve('.'), typeof process.env.PATH);
