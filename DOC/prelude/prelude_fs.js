var __fsMod, __cpMod, __rlMod, __stdinObj;
function __wb(s) {
  var n = s.length, u = new Uint16Array(n + 1), i;
  for (i = 0; i < n; i++) u[i] = s.charCodeAt(i);
  return u;
}
function __wstr(u, n) {
  var out = [], i, j;
  for (i = 0; i < n; i += 2048) {
    j = i + 2048 > n ? n : i + 2048;
    out.push(String.fromCharCode.apply(null, __taArr(u.subarray(i, j))));
  }
  return out.join('');
}
var __fsErrs;
function __fsErr(sys, path, dest) {
  var gle = __k32(28), m, msg, e;
  if (__fsErrs === undefined) {
    __fsErrs = {
      2: ['ENOENT', -2, 'no such file or directory'], 3: ['ENOENT', -2, 'no such file or directory'], 5: ['EACCES', -13, 'permission denied'],
      80: ['EEXIST', -17, 'file already exists'], 183: ['EEXIST', -17, 'file already exists'], 145: ['ENOTEMPTY', -39, 'directory not empty'],
      267: ['ENOTDIR', -20, 'not a directory'], 32: ['EBUSY', -16, 'resource busy or locked'], 4: ['EMFILE', -24, 'too many open files'],
      6: ['EBADF', -9, 'bad file descriptor'], 87: ['EINVAL', -22, 'invalid argument'], 123: ['ENOENT', -2, 'no such file or directory'],
      19: ['EPERM', -1, 'operation not permitted'], 1: ['EPERM', -1, 'operation not permitted']
    };
  }
  m = __fsErrs[gle] || ['EIO', -5, 'i/o error'];
  if (m[0] === 'ENOENT' && sys === 'scandir' && dest === 'notdir') { m = ['ENOTDIR', -20, 'not a directory']; dest = undefined; }
  msg = m[0] + ': ' + m[2] + ', ' + sys + (path !== undefined ? " '" + path + "'" : '') + (dest ? " -> '" + dest + "'" : '');
  e = new Error(msg);
  e.errno = m[1]; e.code = m[0]; e.syscall = sys;
  if (path !== undefined) e.path = path;
  if (dest) e.dest = dest;
  return e;
}
function __fsPath(p, what) {
  if (typeof p === 'string') return p;
  if (p !== null && typeof p === 'object' && p.protocol === 'file:' && typeof p.pathname === 'string') return decodeURIComponent(p.pathname).replace(/^\/([A-Za-z]:)/, '$1');
  if (p instanceof Uint8Array) return p.toString();
  var e = new TypeError('The "' + (what || 'path') + '" argument must be of type string or an instance of Buffer or URL. Received ' +
    (p === null ? 'null' : typeof p === 'object' ? 'an instance of ' + (p.constructor && p.constructor.name) : 'type ' + typeof p + ' (' + String(p) + ')'));
  e.code = 'ERR_INVALID_ARG_TYPE';
  throw e;
}
function __fsH(fd) { return fd >= 0 && fd <= 2 ? __k32(25, -10 - fd) : fd; }
function __fsFlags(f) {
  if (f === undefined || f === null) f = 'r';
  if (typeof f === 'number') {
    var acc = f & 3, cr = (f & 256) !== 0, ex = (f & 1024) !== 0, tr = (f & 512) !== 0, ap = (f & 8) !== 0;
    f = acc === 0 ? 'r' : acc === 1 ? (ex ? 'wx' : tr ? 'w' : cr ? 'a' : 'r+') : (tr ? 'w+' : cr && ap ? 'a+' : 'r+');
    if (ap && acc === 1) f = 'a';
  }
  switch (f) {
    case 'r': case 'rs': case 'sr': return [-2147483648, 3];
    case 'r+': case 'rs+': case 'sr+': return [-1073741824, 3];
    case 'w': return [1073741824, 2];
    case 'wx': case 'xw': return [1073741824, 1];
    case 'w+': return [-1073741824, 2];
    case 'wx+': case 'xw+': return [-1073741824, 1];
    case 'a': case 'as': case 'sa': return [4, 4];
    case 'ax': case 'xa': return [4, 1];
    case 'a+': case 'as+': case 'sa+': return [-2147483644, 4];
    case 'ax+': case 'xa+': return [-2147483644, 1];
  }
  var e = new TypeError("The argument 'flags' is invalid. Received '" + f + "'");
  e.code = 'ERR_INVALID_ARG_VALUE';
  throw e;
}
function __fsAttr(p) { return __k32(36, __wb(p)); }
function __fsOpen(p, flags) {
  var fl = __fsFlags(flags), h;
  if (p === '/dev/stdin') return 0;
  h = __k32(1, __wb(p), fl[0], 7, null, fl[1], 128, null);
  if (h === -1) {
    var a = __fsAttr(p);
    if (a !== -1 && (a & 16) !== 0 && __k32(28) === 5) {
      var e = new Error("EISDIR: illegal operation on a directory, read");
      e.errno = -21; e.code = 'EISDIR'; e.syscall = 'read';
      throw e;
    }
    throw __fsErr('open', p);
  }
  return h;
}
function __fsReadAll(h, size) {
  var chunks = [], total = 0, got = new Uint32Array(1), n, buf, ok;
  for (;;) {
    n = size > 0 ? size - total : 65536;
    if (n <= 0) break;
    if (n > 1048576) n = 1048576;
    buf = new Uint8Array(n);
    got[0] = 0;
    ok = __k32(3, h, buf, n, got, null);
    if (!ok || got[0] === 0) break;
    chunks.push(got[0] === n ? buf : buf.subarray(0, got[0]));
    total += got[0];
  }
  var r = Buffer.alloc(total), off = 0, i;
  for (i = 0; i < chunks.length; i++) { r.set(chunks[i], off); off += chunks[i].length; }
  return r;
}
function __fsWriteAll(h, b, what) {
  var got = new Uint32Array(1), off = 0, n, ok;
  while (off < b.length) {
    n = b.length - off;
    if (n > 1048576) n = 1048576;
    got[0] = 0;
    ok = __k32(4, h, b.subarray(off, off + n), n, got, null);
    if (!ok) throw __fsErr('write', what);
    off += got[0];
    if (got[0] === 0) break;
  }
  return off;
}
function __fsEnc(o) { return typeof o === 'string' ? o : (o && o.encoding) || null; }
function __fsData(d, enc) {
  if (typeof d === 'string') return Buffer.from(d, enc || 'utf8');
  if (d instanceof Uint8Array) return d;
  if (ArrayBuffer.isView(d)) return new Uint8Array(d.buffer, d.byteOffset, d.byteLength);
  var e = new TypeError('The "data" argument must be of type string or an instance of Buffer, TypedArray, or DataView. Received ' +
    (d === null ? 'null' : typeof d === 'object' ? 'an instance of ' + (d.constructor && d.constructor.name) : 'type ' + typeof d + ' (' + String(d) + ')'));
  e.code = 'ERR_INVALID_ARG_TYPE';
  throw e;
}
function __ftMs(lo, hi) { return (hi * 4294967296 + lo) / 10000 - 11644473600000; }
function __fsStats(a, u32, base, dir) {
  var attr = a[0], hasSize = !dir, s = {}, isDir = (attr & 16) !== 0, ro = (attr & 1) !== 0, mt = __ftMs(a[base + 5], a[base + 6]), at = __ftMs(a[base + 3], a[base + 4]), bt = __ftMs(a[base + 1], a[base + 2]);
  var sz = a[base + 8] * 4294967296 + a[base + 9];
  s.dev = 0; s.mode = isDir ? 16895 : (ro ? 33060 : 33206); s.nlink = 1; s.uid = 0; s.gid = 0; s.rdev = 0; s.blksize = 4096; s.ino = 0;
  s.size = isDir ? 0 : sz; s.blocks = isDir ? 0 : Math.ceil(sz / 512);
  s.atimeMs = at; s.mtimeMs = mt; s.ctimeMs = mt; s.birthtimeMs = bt;
  s.atime = new Date(at); s.mtime = new Date(mt); s.ctime = new Date(mt); s.birthtime = new Date(bt);
  Object.setPrototypeOf(s, __StatsP);
  return s;
}
var __StatsP;
function __fsStat(p) {
  var buf = new Uint32Array(9);
  if (!__k32(12, __wb(p), 0, buf)) throw __fsErr('stat', p);
  return __fsStats([buf[0], buf[1], buf[2], buf[3], buf[4], buf[5], buf[6], 0, buf[7], buf[8]], null, 0, false);
}
function __fsList(p) {
  var pat = __wb(p.replace(/[\\\/]+$/, '') + '/*'), data = new Uint16Array(296), d32 = new Uint32Array(data.buffer), h, names = [], name, a;
  h = __k32(13, pat, data);
  if (h === -1) {
    a = __fsAttr(p);
    if (a !== -1 && (a & 16) === 0) throw __fsErr('scandir', p, 'notdir');
    throw __fsErr('scandir', p);
  }
  do {
    name = __wstr(data.subarray(22), 260);
    name = name.slice(0, name.indexOf('\0') < 0 ? name.length : name.indexOf('\0'));
    if (name !== '.' && name !== '..') names.push({ name: name, attr: d32[0] });
    data.fill(0, 22, 282);
  } while (__k32(14, h, data));
  __k32(15, h);
  names.sort(function (x, y) { return x.name < y.name ? -1 : x.name > y.name ? 1 : 0; });
  return names;
}
function __mkFs() {
  var fs = {}, EE = __reqbi('events'), i, names;
  var join = function (a, b) { return a.replace(/[\\\/]+$/, '') + '/' + b; };
  var Stats = function Stats() { };
  Stats.prototype.isFile = function () { return (this.mode & 61440) === 32768; };
  Stats.prototype.isDirectory = function () { return (this.mode & 61440) === 16384; };
  Stats.prototype.isSymbolicLink = function () { return false; };
  Stats.prototype.isFIFO = Stats.prototype.isSocket = Stats.prototype.isBlockDevice = Stats.prototype.isCharacterDevice = function () { return false; };
  __StatsP = Stats.prototype;
  fs.Stats = Stats;
  var Dirent = function Dirent(name, dir, parent) { this.name = name; this.parentPath = parent; this.path = parent; this['\x01d'] = dir; Object.defineProperty(this, '\x01d', { enumerable: false }); };
  Dirent.prototype.isFile = function () { return !this['\x01d']; };
  Dirent.prototype.isDirectory = function () { return this['\x01d']; };
  Dirent.prototype.isSymbolicLink = Dirent.prototype.isFIFO = Dirent.prototype.isSocket = Dirent.prototype.isBlockDevice = Dirent.prototype.isCharacterDevice = function () { return false; };
  fs.Dirent = Dirent;
  fs.constants = { F_OK: 0, R_OK: 4, W_OK: 2, X_OK: 1, O_RDONLY: 0, O_WRONLY: 1, O_RDWR: 2, O_CREAT: 256, O_EXCL: 1024, O_TRUNC: 512, O_APPEND: 8, COPYFILE_EXCL: 1, COPYFILE_FICLONE: 2, S_IFMT: 61440, S_IFREG: 32768, S_IFDIR: 16384 };
  fs.F_OK = 0; fs.R_OK = 4; fs.W_OK = 2; fs.X_OK = 1;
  fs.existsSync = function (p) { try { return __fsAttr(__fsPath(p)) !== -1; } catch (e) { return false; } };
  fs.accessSync = function (p, m) { p = __fsPath(p); if (__fsAttr(p) === -1) throw __fsErr('access', p); };
  fs.openSync = function (p, flags) { return __fsOpen(__fsPath(p), flags); };
  fs.closeSync = function (fd) { if (fd > 2 && !__k32(2, fd)) throw __fsErr('close'); };
  fs.readFileSync = function (p, o) {
    if (p === '/dev/stdin') p = 0;
    var enc = __fsEnc(o), h, own = typeof p !== 'number', b, flag = o && typeof o === 'object' ? o.flag : undefined, size = 0;
    if (own) p = __fsPath(p);
    h = own ? __fsOpen(p, flag) : __fsH(p);
    try {
      if (own && p !== '/dev/stdin') size = __k32(6, h, null);
      if (size < 0) size = 0;
      b = __fsReadAll(h, size);
    } finally { if (own && h > 2) __k32(2, h); }
    return enc ? b.toString(enc) : b;
  };
  fs.writeFileSync = function (p, d, o) {
    var enc = __fsEnc(o), flag = o && typeof o === 'object' && o.flag ? o.flag : 'w', own = typeof p !== 'number', h, b = __fsData(d, enc);
    if (own) p = __fsPath(p);
    h = own ? __fsOpen(p, flag) : __fsH(p);
    try { __fsWriteAll(h, b, own ? p : undefined); } finally { if (own && h > 2) __k32(2, h); }
  };
  fs.appendFileSync = function (p, d, o) {
    var enc = __fsEnc(o);
    fs.writeFileSync(p, d, { encoding: enc, flag: 'a' });
  };
  fs.readSync = function (fd, buf, off, len, pos) {
    var got = new Uint32Array(1), h = __fsH(fd), o = off;
    if (off !== null && typeof off === 'object') { len = off.length; pos = off.position; o = off.offset; }
    if (o === undefined || o === null) o = 0;
    if (len === undefined) len = buf.length - o;
    if (typeof pos === 'number' && pos >= 0) __k32(5, h, pos, null, 0);
    if (!__k32(3, h, buf.subarray(o, o + len), len, got, null) && __k32(28) !== 109) throw __fsErr('read');
    return got[0];
  };
  fs.writeSync = function (fd, d, a, b, c) {
    var h = __fsH(fd), buf, pos = null;
    if (typeof d === 'string') { buf = Buffer.from(d, typeof b === 'string' ? b : 'utf8'); pos = typeof a === 'number' ? a : null; }
    else {
      buf = __fsData(d);
      var off = a === undefined || a === null ? 0 : a, len = b === undefined || b === null ? buf.length - off : b;
      buf = buf.subarray(off, off + len);
      pos = typeof c === 'number' ? c : null;
    }
    if (pos !== null) __k32(5, h, pos, null, 0);
    return __fsWriteAll(h, buf);
  };
  fs.fstatSync = function (fd) {
    var h = __fsH(fd), sz = __k32(6, h, null), s = {};
    s.size = sz < 0 ? 0 : sz; s.mode = fd <= 2 ? 8592 : 33206; s.mtimeMs = s.atimeMs = s.ctimeMs = s.birthtimeMs = Date.now();
    s.mtime = s.atime = s.ctime = s.birthtime = new Date(s.mtimeMs);
    Object.setPrototypeOf(s, Stats.prototype);
    return s;
  };
  fs.statSync = function (p, o) {
    try { return __fsStat(__fsPath(p)); } catch (e) { if (o && o.throwIfNoEntry === false && e.code === 'ENOENT') return undefined; throw e; }
  };
  fs.lstatSync = fs.statSync;
  fs.readdirSync = function (p, o) {
    p = __fsPath(p);
    var wt = o && typeof o === 'object' && o.withFileTypes, rec = o && typeof o === 'object' && o.recursive, out = [], l = __fsList(p), k;
    var walk = function (dir, rel, list) {
      var j, e, r;
      for (j = 0; j < list.length; j++) {
        e = list[j];
        r = rel === '' ? e.name : rel + '/' + e.name;
        out.push(wt ? new Dirent(e.name, (e.attr & 16) !== 0, dir) : r);
        if (rec && (e.attr & 16) !== 0) walk(join(dir, e.name), r, __fsList(join(dir, e.name)));
      }
    };
    walk(p, '', l);
    return out;
  };
  fs.mkdirSync = function (p, o) {
    p = __fsPath(p);
    var rec = o && typeof o === 'object' && o.recursive, parts, cur, first, i, norm = p.replace(/\\/g, '/');
    if (!rec) { if (!__k32(8, __wb(p), null)) throw __fsErr('mkdir', p); return undefined; }
    parts = norm.split('/'); cur = '';
    for (i = 0; i < parts.length; i++) {
      cur = i === 0 ? parts[0] : cur + '/' + parts[i];
      if (parts[i] === '' || (i === 0 && /^[A-Za-z]:$/.test(parts[0]))) continue;
      if (__fsAttr(cur) !== -1) continue;
      if (!__k32(8, __wb(cur), null)) throw __fsErr('mkdir', p);
      if (first === undefined) first = cur;
    }
    return first;
  };
  fs.rmdirSync = function (p, o) {
    p = __fsPath(p);
    if (o && o.recursive) return fs.rmSync(p, { recursive: true, force: false });
    if (!__k32(9, __wb(p))) throw __fsErr('rmdir', p);
  };
  fs.unlinkSync = function (p) {
    p = __fsPath(p);
    var a = __fsAttr(p);
    if (a !== -1 && (a & 16) !== 0) { var e = new Error("EPERM: operation not permitted, unlink '" + p + "'"); e.errno = -1; e.code = 'EPERM'; e.syscall = 'unlink'; e.path = p; throw e; }
    if (!__k32(7, __wb(p))) throw __fsErr('unlink', p);
  };
  fs.rmSync = function (p, o) {
    p = __fsPath(p);
    var a = __fsAttr(p), l, j;
    if (a === -1) { if (o && o.force) return; throw __fsErr('rm', p); }
    if ((a & 16) !== 0) {
      if (!(o && o.recursive)) { var e = new Error('Path is a directory: rm returned EISDIR (is a directory) ' + p); e.code = 'ERR_FS_EISDIR'; e.errno = 21; e.syscall = 'rm'; e.path = p; throw e; }
      l = __fsList(p);
      for (j = 0; j < l.length; j++) fs.rmSync(join(p, l[j].name), o);
      if (!__k32(9, __wb(p))) throw __fsErr('rm', p);
    } else if (!__k32(7, __wb(p))) throw __fsErr('rm', p);
  };
  fs.renameSync = function (a, b) {
    a = __fsPath(a, 'oldPath'); b = __fsPath(b, 'newPath');
    if (__fsAttr(b) !== -1 && (__fsAttr(b) & 16) === 0) __k32(7, __wb(b));
    if (!__k32(10, __wb(a), __wb(b))) throw __fsErr('rename', a, b);
  };
  fs.copyFileSync = function (a, b, mode) {
    a = __fsPath(a, 'src'); b = __fsPath(b, 'dest');
    if (!__k32(11, __wb(a), __wb(b), (mode & 1) !== 0 ? 1 : 0)) throw __fsErr('copyfile', a, b);
  };
  fs.cpSync = function (a, b, o) {
    a = __fsPath(a, 'src'); b = __fsPath(b, 'dest');
    var st = fs.statSync(a), l, j;
    if (st.isDirectory()) {
      if (!(o && o.recursive)) { var e = new Error('Recursive option is required to copy a directory: ' + a); e.code = 'ERR_FS_EISDIR'; throw e; }
      if (__fsAttr(b) === -1) fs.mkdirSync(b, { recursive: true });
      l = __fsList(a);
      for (j = 0; j < l.length; j++) fs.cpSync(join(a, l[j].name), join(b, l[j].name), o);
    } else fs.copyFileSync(a, b);
  };
  fs.truncateSync = function (p, len) {
    var h = __fsOpen(__fsPath(p), 'r+');
    try { __k32(5, h, len || 0, null, 0); if (!__k32(29, h)) throw __fsErr('ftruncate', p); } finally { __k32(2, h); }
  };
  fs.ftruncateSync = function (fd, len) { __k32(5, fd, len || 0, null, 0); if (!__k32(29, fd)) throw __fsErr('ftruncate'); };
  fs.fsyncSync = function (fd) { __k32(30, __fsH(fd)); };
  fs.fdatasyncSync = fs.fsyncSync;
  fs.chmodSync = fs.chownSync = fs.fchmodSync = fs.lchownSync = function () { };
  fs.utimesSync = fs.futimesSync = fs.lutimesSync = function () { };
  fs.realpathSync = function (p) {
    p = __fsPath(p);
    if (__fsAttr(p) === -1) throw __fsErr('lstat', p);
    var u = new Uint16Array(1040), n = __k32(33, __wb(p), 1040, u, null);
    return __wstr(u, n);
  };
  fs.realpathSync.native = fs.realpathSync;
  fs.mkdtempSync = function (prefix) {
    var cs = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', k, s = '', t;
    for (k = 0; k < 20; k++) {
      s = '';
      for (t = 0; t < 6; t++) s += cs[Math.floor(Math.random() * cs.length)];
      if (__k32(8, __wb(prefix + s), null)) return prefix + s;
    }
    throw __fsErr('mkdtemp', prefix + 'XXXXXX');
  };
  fs.symlinkSync = function (t, p) { var e = new Error("EPERM: operation not permitted, symlink '" + t + "' -> '" + p + "'"); e.code = 'EPERM'; e.errno = -1; e.syscall = 'symlink'; throw e; };
  fs.readlinkSync = function (p) { var e = new Error("EINVAL: invalid argument, readlink '" + p + "'"); e.code = 'EINVAL'; e.errno = -22; e.syscall = 'readlink'; throw e; };
  fs.linkSync = fs.symlinkSync;
  fs.watch = fs.watchFile = function () { throw new Error('fs.watch is not supported by JSCW32'); };
  var syncNames = ['access', 'appendFile', 'chmod', 'chown', 'close', 'copyFile', 'cp', 'fstat', 'ftruncate', 'fsync', 'lstat', 'mkdir',
    'mkdtemp', 'open', 'readFile', 'readdir', 'readlink', 'realpath', 'rename', 'rm', 'rmdir', 'stat', 'symlink', 'truncate', 'unlink', 'utimes', 'writeFile'];
  var cbWrap = function (f) {
    return function () {
      var a = Array.prototype.slice.call(arguments), cb = a.pop(), self = this;
      if (typeof cb !== 'function') { var e = new TypeError('The "cb" argument must be of type function. Received ' + (cb === undefined ? 'undefined' : typeof cb)); e.code = 'ERR_INVALID_ARG_TYPE'; throw e; }
      setImmediate(function () {
        var r;
        try { r = f.apply(self, a); } catch (er) { cb(er); return; }
        cb(null, r);
      });
    };
  };
  var promWrap = function (f) {
    return function () {
      var a = arguments, self = this;
      return new Promise(function (res, rej) {
        setImmediate(function () { var r; try { r = f.apply(self, a); } catch (er) { rej(er); return; } res(r); });
      });
    };
  };
  var prom = {};
  for (i = 0; i < syncNames.length; i++) {
    fs[syncNames[i]] = cbWrap(fs[syncNames[i] + 'Sync']);
    prom[syncNames[i]] = promWrap(fs[syncNames[i] + 'Sync']);
  }
  fs.exists = function (p, cb) { setImmediate(function () { cb(fs.existsSync(p)); }); };
  fs.read = function (fd, buf, off, len, pos, cb) {
    setImmediate(function () { var n; try { n = fs.readSync(fd, buf, off, len, pos); } catch (er) { cb(er); return; } cb(null, n, buf); });
  };
  fs.write = function (fd, d) {
    var a = Array.prototype.slice.call(arguments, 1), cb = a.pop();
    setImmediate(function () { var n; try { n = fs.writeSync.apply(fs, [fd].concat(a)); } catch (er) { cb(er); return; } cb(null, n, d); });
  };
  prom.FileHandle = null;
  prom.open = function (p, fl) {
    return new Promise(function (res, rej) {
      var fd;
      try { fd = fs.openSync(p, fl); } catch (er) { rej(er); return; }
      res({
        fd: fd, close: function () { fs.closeSync(fd); return Promise.resolve(); },
        readFile: function (o) { return Promise.resolve(fs.readFileSync(fd, o)); }, writeFile: function (d, o) { fs.writeFileSync(fd, d, o); return Promise.resolve(); },
        stat: function () { return Promise.resolve(fs.fstatSync(fd)); }
      });
    });
  };
  prom.constants = fs.constants;
  fs.promises = prom;
  fs.createReadStream = function (p, o) {
    var s = new EE(), enc = __fsEnc(o), hw = o && o.highWaterMark ? o.highWaterMark : 65536, h, started = false, start = o && o.start !== undefined ? o.start : 0, end = o && o.end !== undefined ? o.end : Infinity;
    s.path = p; s.bytesRead = 0; s.readable = true; s.destroyed = false;
    s.setEncoding = function (e) { enc = e; return s; };
    s.destroy = function () { s.destroyed = true; if (h !== undefined) { __k32(2, h); h = undefined; } return s; };
    s.close = function (cb) { s.destroy(); if (cb) setImmediate(cb); };
    var pump = function () {
      var got, buf, n, chunk;
      if (s.destroyed) return;
      if (h === undefined) {
        try { h = __fsOpen(__fsPath(p), 'r'); } catch (er) { s.emit('error', er); return; }
        if (start > 0) __k32(5, h, start, null, 0);
        s.emit('open', h); s.emit('ready');
      }
      n = Math.min(hw, end - start - s.bytesRead + 1);
      got = new Uint32Array(1); buf = Buffer.alloc(n > 0 ? n : 0);
      if (n > 0) __k32(3, h, buf, n, got, null);
      if (n <= 0 || got[0] === 0) { s.readable = false; s.emit('end'); s.destroy(); s.emit('close'); return; }
      s.bytesRead += got[0];
      chunk = got[0] === n ? buf : buf.subarray(0, got[0]);
      s.emit('data', enc ? chunk.toString(enc) : chunk);
      setImmediate(pump);
    };
    var begin = function () { if (!started) { started = true; setImmediate(pump); } };
    var on = s.on;
    s.on = s.addListener = function (n, f) { on.call(s, n, f); if (n === 'data' || n === 'readable') begin(); return s; };
    s.resume = function () { begin(); return s; };
    s.pause = function () { return s; };
    s.pipe = function (dest) {
      s.on('data', function (c) { dest.write(c); });
      s.on('end', function () { if (dest !== process.stdout && dest !== process.stderr) dest.end(); });
      return dest;
    };
    s[Symbol.asyncIterator] = function () {
      var q = [], done = false, waiting = null;
      s.on('data', function (c) { if (waiting) { var w = waiting; waiting = null; w({ value: c, done: false }); } else q.push(c); });
      s.on('end', function () { done = true; if (waiting) { var w = waiting; waiting = null; w({ value: undefined, done: true }); } });
      return {
        next: function () {
          if (q.length) return Promise.resolve({ value: q.shift(), done: false });
          if (done) return Promise.resolve({ value: undefined, done: true });
          return new Promise(function (r) { waiting = r; });
        },
        [Symbol.asyncIterator]: function () { return this; }
      };
    };
    return s;
  };
  fs.createWriteStream = function (p, o) {
    var s = new EE(), h, flag = o && o.flags ? o.flags : 'w', enc = __fsEnc(o) || 'utf8', failed = false;
    s.path = p; s.bytesWritten = 0; s.writable = true; s.destroyed = false;
    var open = function () {
      if (h !== undefined || failed) return;
      try { h = __fsOpen(__fsPath(p), flag); } catch (er) { failed = true; setImmediate(function () { s.emit('error', er); }); return; }
      setImmediate(function () { s.emit('open', h); s.emit('ready'); });
    };
    open();
    s.write = function (d, e, cb) {
      if (typeof e === 'function') { cb = e; e = undefined; }
      if (failed) return false;
      var b = __fsData(d, e || enc);
      __fsWriteAll(h, b, p);
      s.bytesWritten += b.length;
      if (cb) setImmediate(cb);
      return true;
    };
    s.end = function (d, e, cb) {
      if (typeof d === 'function') { cb = d; d = undefined; }
      if (d !== undefined && d !== null) s.write(d, e);
      s.writable = false;
      if (h !== undefined) { __k32(2, h); h = undefined; }
      setImmediate(function () { s.emit('finish'); s.emit('close'); if (cb) cb(); });
      return s;
    };
    s.close = s.destroy = function () { s.end(); return s; };
    s.cork = s.uncork = function () { };
    return s;
  };
  return fs;
}
function __mkFsPromises() { return __reqbi('fs').promises; }
function __runProc(file, args, o, input) {
  o = o || {};
  var cmd, shell = o.shell, wcmd, pipes = new Uint32Array(2), sa = new Uint32Array(3), si = new Uint32Array(17), pi = new Uint32Array(4), stdio = o.stdio, mode = ['pipe', 'pipe', 'pipe'], i;
  var hIn, hOut, hErr, rOut, rErr, wIn, ok, outs = [], errs = [], outDone = false, errDone = false, avail = new Uint32Array(1), got = new Uint32Array(1), code = new Uint32Array(1), cwd = null, envp = null, flags = 134217728;
  if (typeof stdio === 'string') mode = [stdio, stdio, stdio];
  else if (Array.isArray(stdio)) for (i = 0; i < 3; i++) if (stdio[i] !== undefined && stdio[i] !== null) mode[i] = typeof stdio[i] === 'number' ? 'inherit' : stdio[i];
  if (shell === undefined && args === null) shell = true;
  if (shell) {
    cmd = args === null ? file : file + ' ' + args.map(__cpQuote).join(' ');
    wcmd = 'cmd.exe /d /s /c "' + cmd + '"';
  } else wcmd = [file].concat(args || []).map(__cpQuote).join(' ');
  sa[0] = 12; sa[1] = 0; sa[2] = 1;
  if (mode[0] === 'inherit') hIn = __k32(25, -10);
  else { __k32(19, pipes, pipes.subarray(1), sa, 1048576); hIn = pipes[0]; wIn = pipes[1]; __k32(26, wIn, 1, 0); }
  if (mode[1] === 'inherit') hOut = __k32(25, -11);
  else { __k32(19, pipes, pipes.subarray(1), sa, 1048576); rOut = pipes[0]; hOut = pipes[1]; __k32(26, rOut, 1, 0); }
  if (mode[2] === 'inherit') hErr = __k32(25, -12);
  else { __k32(19, pipes, pipes.subarray(1), sa, 1048576); rErr = pipes[0]; hErr = pipes[1]; __k32(26, rErr, 1, 0); }
  si[0] = 68; si[11] = 256; si[14] = hIn; si[15] = hOut; si[16] = hErr;
  if (o.cwd) cwd = __wb(String(o.cwd));
  var env = o.env || process.env, es = [], k, ks = Object.keys(env);
  for (k = 0; k < ks.length; k++) if (env[ks[k]] !== undefined) es.push(ks[k] + '=' + env[ks[k]]);
  es = es.join('\0') + '\0\0';
  envp = __wb(es); flags |= 1024;
  ok = __k32(20, null, __wb(wcmd), null, null, 1, flags, envp, cwd, si, pi);
  if (!ok) {
    var gle = __k32(28);
    if (mode[0] !== 'inherit') { __k32(2, hIn); __k32(2, wIn); }
    if (mode[1] !== 'inherit') { __k32(2, hOut); __k32(2, rOut); }
    if (mode[2] !== 'inherit') { __k32(2, hErr); __k32(2, rErr); }
    var er = new Error('spawnSync ' + file + ' ENOENT'); er.errno = -2; er.code = 'ENOENT'; er.syscall = 'spawnSync ' + file; er.path = file; er.spawnargs = args || [];
    return { error: er, status: null, signal: null, pid: 0, output: null, stdout: null, stderr: null };
  }
  if (mode[0] !== 'inherit') {
    __k32(2, hIn);
    if (input !== undefined && input !== null) { var ib = __fsData(input); if (ib.length > 0) { got[0] = 0; __k32(4, wIn, ib, ib.length, got, null); } }
    __k32(2, wIn);
  }
  if (mode[1] !== 'inherit') __k32(2, hOut);
  if (mode[2] !== 'inherit') __k32(2, hErr);
  var drain = function (h, list) {
    var a, buf, any = false;
    if (!__k32(27, h, null, 0, null, avail, null)) return -1;
    a = avail[0];
    while (a > 0) {
      buf = Buffer.alloc(a > 65536 ? 65536 : a);
      got[0] = 0;
      if (!__k32(3, h, buf, buf.length, got, null) || got[0] === 0) break;
      list.push(got[0] === buf.length ? buf : buf.subarray(0, got[0]));
      a -= got[0]; any = true;
    }
    return any ? 1 : 0;
  };
  var exited = false, r1, r2, idle;
  for (;;) {
    r1 = rOut !== undefined && !outDone ? drain(rOut, outs) : -1;
    r2 = rErr !== undefined && !errDone ? drain(rErr, errs) : -1;
    if (r1 < 0) outDone = true;
    if (r2 < 0) errDone = true;
    if (r1 > 0 || r2 > 0) continue;
    if ((rOut === undefined || outDone) && (rErr === undefined || errDone)) break;
    if (__k32(21, pi[0], 0) === 0) { if (exited) break; exited = true; continue; }
    __sleep(1);
  }
  __k32(21, pi[0], -1);
  __k32(22, pi[0], code);
  __k32(2, pi[0]); __k32(2, pi[1]);
  if (rOut !== undefined) __k32(2, rOut);
  if (rErr !== undefined) __k32(2, rErr);
  var so = Buffer.concat(outs), se = Buffer.concat(errs);
  return { pid: pi[2], status: code[0] | 0, signal: null, output: [null, so, se], stdout: so, stderr: se };
}
function __cpQuote(a) {
  a = String(a);
  if (a !== '' && !/[\s"]/.test(a)) return a;
  return '"' + a.replace(/(\\*)"/g, '$1$1\\"').replace(/(\\+)$/, '$1$1') + '"';
}
function __cpEnc(r, o) {
  var enc = __fsEnc(o);
  if (enc && enc !== 'buffer') { if (r.stdout) r.stdout = r.stdout.toString(enc); if (r.stderr) r.stderr = r.stderr.toString(enc); r.output = [null, r.stdout, r.stderr]; }
  return r;
}
function __mkCp() {
  var cp = {}, EE = __reqbi('events');
  cp.spawnSync = function (file, args, o) {
    if (args !== undefined && args !== null && !Array.isArray(args)) { o = args; args = []; }
    var r = __runProc(file, args || [], o, o && o.input);
    return __cpEnc(r, o);
  };
  cp.execSync = function (cmd, o) {
    var r = __runProc(cmd, null, o, o && o.input), e;
    if (r.error) throw r.error;
    __cpEnc(r, o);
    if (r.stderr && (!o || !o.stdio || o.stdio === 'pipe') && r.stderr.length > 0) process.stderr.write(r.stderr);
    if (r.status !== 0) {
      e = new Error('Command failed: ' + cmd + (r.stderr && r.stderr.length ? '\n' + r.stderr.toString() : ''));
      e.status = r.status; e.signal = null; e.output = r.output; e.pid = r.pid; e.stdout = r.stdout; e.stderr = r.stderr;
      throw e;
    }
    return r.stdout;
  };
  cp.execFileSync = function (file, args, o) {
    if (args !== undefined && !Array.isArray(args)) { o = args; args = []; }
    var r = __runProc(file, args || [], o, o && o.input), e;
    if (r.error) throw r.error;
    __cpEnc(r, o);
    if (r.status !== 0) {
      e = new Error('Command failed: ' + file + ' ' + (args || []).join(' '));
      e.status = r.status; e.signal = null; e.output = r.output; e.pid = r.pid; e.stdout = r.stdout; e.stderr = r.stderr;
      throw e;
    }
    return r.stdout;
  };
  var mkChild = function (run) {
    var c = new EE(), inChunks = [], ended = false;
    c.stdout = new EE(); c.stderr = new EE(); c.pid = 0; c.exitCode = null; c.killed = false; c.signalCode = null; c.connected = false;
    c.stdout.setEncoding = c.stderr.setEncoding = function (e) { this['\x01e'] = e; return this; };
    c.stdin = {
      write: function (d, e, cb) { inChunks.push(__fsData(d, typeof e === 'string' ? e : undefined)); if (typeof e === 'function') e(); else if (cb) cb(); return true; },
      end: function (d) { if (d !== undefined) this.write(d); ended = true; },
      on: function () { return this; }, once: function () { return this; }
    };
    c.kill = function () { c.killed = true; return false; };
    c.ref = c.unref = function () { return c; };
    setImmediate(function () {
      var r = run(inChunks.length ? Buffer.concat(inChunks) : undefined);
      if (r.error) { c.emit('error', r.error); c.emit('close', -2, null); return; }
      c.pid = r.pid; c.exitCode = r.status;
      var emitOut = function (s, b) {
        if (b.length === 0) return;
        var e = s['\x01e'];
        s.emit('data', e ? b.toString(e) : b);
      };
      emitOut(c.stdout, r.stdout); emitOut(c.stderr, r.stderr);
      c.stdout.emit('end'); c.stderr.emit('end'); c.stdout.emit('close'); c.stderr.emit('close');
      c.emit('exit', r.status, null);
      c.emit('close', r.status, null);
    });
    return c;
  };
  cp.spawn = function (file, args, o) {
    if (args !== undefined && !Array.isArray(args)) { o = args; args = []; }
    return mkChild(function (input) { return __runProc(file, args || [], o, input); });
  };
  cp.exec = function (cmd, o, cb) {
    if (typeof o === 'function') { cb = o; o = {}; }
    var c = mkChild(function (input) { return __runProc(cmd, null, o, input); });
    if (cb) {
      var so = [], se = [];
      c.stdout.on('data', function (d) { so.push(d); });
      c.stderr.on('data', function (d) { se.push(d); });
      c.on('close', function (code) {
        var enc = __fsEnc(o) || 'utf8', out = Buffer.concat(so.map(function (x) { return typeof x === 'string' ? Buffer.from(x) : x; })), err = Buffer.concat(se.map(function (x) { return typeof x === 'string' ? Buffer.from(x) : x; }));
        var os = enc === 'buffer' ? out : out.toString(enc), es = enc === 'buffer' ? err : err.toString(enc), e = null;
        if (code !== 0) { e = new Error('Command failed: ' + cmd + (es.length ? '\n' + es : '')); e.code = code; e.killed = false; e.signal = null; e.cmd = cmd; }
        cb(e, os, es);
      });
    }
    return c;
  };
  cp.execFile = function (file, args, o, cb) {
    if (typeof args === 'function') { cb = args; args = []; o = {}; }
    else if (!Array.isArray(args)) { cb = o; o = args; args = []; }
    if (typeof o === 'function') { cb = o; o = {}; }
    var c = mkChild(function (input) { return __runProc(file, args, o, input); });
    if (cb) {
      var so = [], se = [];
      c.stdout.on('data', function (d) { so.push(d); });
      c.stderr.on('data', function (d) { se.push(d); });
      c.on('error', function (er) { cb(er, '', ''); });
      c.on('close', function (code) {
        var out = Buffer.concat(so.map(function (x) { return typeof x === 'string' ? Buffer.from(x) : x; })), err = Buffer.concat(se.map(function (x) { return typeof x === 'string' ? Buffer.from(x) : x; })), e = null;
        if (code !== 0 && code !== -2) { e = new Error('Command failed: ' + file + ' ' + args.join(' ')); e.code = code; }
        if (code !== -2) cb(e, out.toString(), err.toString());
      });
    }
    return c;
  };
  cp.fork = function () { throw new Error('child_process.fork is not supported by JSCW32'); };
  return cp;
}
function __stdinMake() {
  var EE = __reqbi('events'), s = new EE(), enc = null, started = false, ended = false, paused = false, h = __k32(25, -10);
  s.fd = 0; s.isTTY = false; s.readable = true;
  s.setEncoding = function (e) { enc = e || 'utf8'; return s; };
  var got = new Uint32Array(1);
  var pump = function () {
    var buf, chunk;
    if (ended || paused) return;
    buf = Buffer.alloc(65536); got[0] = 0;
    if (!__k32(3, h, buf, 65536, got, null) || got[0] === 0) {
      ended = true; s.readable = false;
      s.emit('end'); s.emit('close');
      return;
    }
    chunk = buf.subarray(0, got[0]);
    s.emit('data', enc ? chunk.toString(enc) : chunk);
    setImmediate(pump);
  };
  var begin = function () { paused = false; if (!started) { started = true; setImmediate(pump); } else if (!ended) setImmediate(pump); };
  var on = s.on;
  s.on = s.addListener = function (n, f) { on.call(s, n, f); if (n === 'data' || n === 'readable' || n === 'end') { if (!started) begin(); } return s; };
  s.resume = function () { begin(); return s; };
  s.pause = function () { paused = true; return s; };
  s.unref = s.ref = function () { return s; };
  s.setRawMode = function () { return s; };
  s.read = function () {
    var buf = Buffer.alloc(65536);
    got[0] = 0;
    if (ended || !__k32(3, h, buf, 65536, got, null) || got[0] === 0) { ended = true; return null; }
    return enc ? buf.subarray(0, got[0]).toString(enc) : buf.subarray(0, got[0]);
  };
  s.pipe = function (dest) {
    s.on('data', function (c) { dest.write(c); });
    s.on('end', function () { if (dest !== process.stdout && dest !== process.stderr && dest.end) dest.end(); });
    return dest;
  };
  s[Symbol.asyncIterator] = function () {
    var q = [], done = false, waiting = null;
    s.on('data', function (c) { if (waiting) { var w = waiting; waiting = null; w({ value: c, done: false }); } else q.push(c); });
    s.on('end', function () { done = true; if (waiting) { var w = waiting; waiting = null; w({ value: undefined, done: true }); } });
    return {
      next: function () {
        if (q.length) return Promise.resolve({ value: q.shift(), done: false });
        if (done) return Promise.resolve({ value: undefined, done: true });
        return new Promise(function (r) { waiting = r; });
      },
      [Symbol.asyncIterator]: function () { return this; }
    };
  };
  return s;
}
function __mkReadline() {
  var rl = {}, EE = __reqbi('events');
  rl.createInterface = function (opts, out) {
    var input = opts && opts.input !== undefined ? opts.input : opts, output = opts && opts.output !== undefined ? opts.output : out, i = new EE(), buf = '', closed = false, qcb = null, prompt = '> ', lines = [], waiters = [];
    if (opts && opts.prompt !== undefined) prompt = opts.prompt;
    i.terminal = false; i.line = ''; i.input = input; i.output = output;
    var deliver = function (l) {
      if (qcb) { var c = qcb; qcb = null; c(l); } else i.emit('line', l);
      if (waiters.length) { waiters.shift()({ value: l, done: false }); } else lines.push(l);
    };
    var close = function () {
      if (closed) return;
      closed = true;
      if (buf.length > 0) { var l = buf; buf = ''; deliver(l); }
      while (waiters.length) waiters.shift()({ value: undefined, done: true });
      i.emit('close');
    };
    i.close = function () { closed = false; close(); };
    i.setPrompt = function (p) { prompt = p; };
    i.getPrompt = function () { return prompt; };
    i.prompt = function () { if (output && output.write) output.write(prompt); };
    i.write = function () { };
    i.pause = function () { return i; };
    i.resume = function () { return i; };
    i.question = function (q, o, cb) {
      if (typeof o === 'function') cb = o;
      if (output && output.write) output.write(q);
      qcb = cb;
    };
    if (input && input.on) {
      if (input.setEncoding) input.setEncoding('utf8');
      input.on('data', function (d) {
        var parts, j;
        buf += typeof d === 'string' ? d : d.toString();
        parts = buf.split(/\r\n|\n|\r/);
        buf = parts.pop();
        for (j = 0; j < parts.length; j++) deliver(parts[j]);
      });
      input.on('end', close);
    }
    i[Symbol.asyncIterator] = function () {
      lines.length = 0;
      return {
        next: function () {
          if (lines.length) return Promise.resolve({ value: lines.shift(), done: false });
          if (closed) return Promise.resolve({ value: undefined, done: true });
          return new Promise(function (r) { waiters.push(r); });
        },
        [Symbol.asyncIterator]: function () { return this; }
      };
    };
    var pending = [];
    i.on('line', function (l) { });
    return i;
  };
  rl.promises = {
    createInterface: function (o) {
      var i = rl.createInterface(o), q = i.question;
      i.question = function (s) { return new Promise(function (res) { q.call(i, s, res); }); };
      return i;
    }
  };
  rl.clearLine = rl.cursorTo = rl.moveCursor = rl.clearScreenDown = function () { return true; };
  rl.emitKeypressEvents = function () { };
  return rl;
}
function __init_fs() {
  var env = process.env, blk = __k32(18), n, p, buf, s, eq, k, tmp;
  process.cwd = function () {
    var u = new Uint16Array(1040), n = __k32(16, 1040, u);
    return __wstr(u, n);
  };
  process.chdir = function (d) {
    if (!__k32(24, __wb(String(d)))) {
      var e = new Error("ENOENT: no such file or directory, chdir '" + process.cwd() + "' -> '" + d + "'");
      e.code = 'ENOENT'; e.errno = -2; e.syscall = 'chdir';
      throw e;
    }
  };
  process.pid = __k32(38);
  process.ppid = 0;
  process.execPath = 'C:\\Program Files\\nodejs\\node.exe';
  process.stdout.fd = 1; process.stderr.fd = 2;
  process.stdout.isTTY = false; process.stderr.isTTY = false;
  if (blk !== 0) {
    p = blk;
    for (;;) {
      n = __k32(42, p);
      if (n === 0) break;
      buf = new Uint16Array(n);
      __k32(41, buf, p, n * 2);
      s = __wstr(buf, n);
      eq = s.indexOf('=', 1);
      if (eq > 0) env[s.slice(0, eq)] = s.slice(eq + 1);
      p += (n + 1) * 2;
    }
    __k32(34, blk);
  }
  Object.defineProperty(process, 'stdin', { get: function () { if (__stdinObj === undefined) __stdinObj = __stdinMake(); return __stdinObj; }, configurable: true, enumerable: true });
  __fsMod = undefined;
}
function __mkFsModule(name) {
  if (name === 'fs') return __mkFs();
  if (name === 'fs/promises') return __reqbi('fs').promises;
  if (name === 'child_process') return __mkCp();
  if (name === 'readline') return __mkReadline();
  if (name === 'readline/promises') return __reqbi('readline').promises;
  return null;
}
