function __pvs(v, name) {
  if (typeof v !== 'string') {
    var d;
    if (v === undefined) d = 'undefined';
    else if (v === null) d = 'null';
    else if (typeof v === 'function') d = 'function ' + v.name;
    else if (typeof v === 'object') d = 'an instance of ' + (v.constructor ? v.constructor.name : 'Object');
    else d = 'type ' + typeof v + ' (' + String(v) + ')';
    var e = new TypeError('The "' + name + '" argument must be of type string. Received ' + d);
    e.code = 'ERR_INVALID_ARG_TYPE';
    throw e;
  }
}
function __pnorm(path, allowAboveRoot, separator, isSep) {
  var res = '', lastSegmentLength = 0, lastSlash = -1, dots = 0, code = 0, i, k;
  for (i = 0; i <= path.length; ++i) {
    if (i < path.length) code = path.charCodeAt(i);
    else if (isSep(code)) break;
    else code = 47;
    if (isSep(code)) {
      if (lastSlash === i - 1 || dots === 1) {
        // rien
      } else if (dots === 2) {
        if (res.length < 2 || lastSegmentLength !== 2 || res.charCodeAt(res.length - 1) !== 46 || res.charCodeAt(res.length - 2) !== 46) {
          if (res.length > 2) {
            k = res.lastIndexOf(separator);
            if (k === -1) { res = ''; lastSegmentLength = 0; }
            else { res = res.slice(0, k); lastSegmentLength = res.length - 1 - res.lastIndexOf(separator); }
            lastSlash = i; dots = 0;
            continue;
          } else if (res.length !== 0) {
            res = ''; lastSegmentLength = 0; lastSlash = i; dots = 0;
            continue;
          }
        }
        if (allowAboveRoot) { res += res.length > 0 ? separator + '..' : '..'; lastSegmentLength = 2; }
      } else {
        if (res.length > 0) res += separator + path.slice(lastSlash + 1, i);
        else res = path.slice(lastSlash + 1, i);
        lastSegmentLength = i - lastSlash - 1;
      }
      lastSlash = i; dots = 0;
    } else if (code === 46 && dots !== -1) {
      ++dots;
    } else {
      dots = -1;
    }
  }
  return res;
}
function __pres(p, ci) {
  var d = p.slice(0, ci).toUpperCase(), c;
  if (d === 'CON' || d === 'PRN' || d === 'AUX' || d === 'NUL') return true;
  if (d.length === 4 && (d.slice(0, 3) === 'COM' || d.slice(0, 3) === 'LPT')) {
    c = d.charCodeAt(3);
    return (c >= 49 && c <= 57) || c === 185 || c === 178 || c === 179;
  }
  return false;
}
function __pformat(sep, o) {
  if (o === null || typeof o !== 'object') {
    var e = new TypeError('The "pathObject" argument must be of type object. Received ' + (o === null ? 'null' : o === undefined ? 'undefined' : 'type ' + typeof o + ' (' + String(o) + ')'));
    e.code = 'ERR_INVALID_ARG_TYPE';
    throw e;
  }
  var dir = o.dir || o.root;
  var base = o.base || ((o.name || '') + (o.ext || ''));
  if (!dir) return base;
  return dir === o.root ? dir + base : dir + sep + base;
}
function __pisPosix(c) { return c === 47; }
function __pisSep(c) { return c === 47 || c === 92; }
function __pisDev(c) { return (c >= 65 && c <= 90) || (c >= 97 && c <= 122); }
function __mkPosix() {
  var posix = {};
  posix.resolve = function () {
    var resolvedPath = '', resolvedAbsolute = false, i, p;
    for (i = arguments.length - 1; i >= -1 && !resolvedAbsolute; i--) {
      p = i >= 0 ? arguments[i] : process.cwd().replace(/\\/g, '/').replace(/^[A-Za-z]:/, '');
      __pvs(p, 'paths[' + i + ']');
      if (p.length === 0) continue;
      resolvedPath = p + '/' + resolvedPath;
      resolvedAbsolute = p.charCodeAt(0) === 47;
    }
    resolvedPath = __pnorm(resolvedPath, !resolvedAbsolute, '/', __pisPosix);
    if (resolvedAbsolute) return '/' + resolvedPath;
    return resolvedPath.length > 0 ? resolvedPath : '.';
  };
  posix.normalize = function (p) {
    __pvs(p, 'path');
    if (p.length === 0) return '.';
    var isAbsolute = p.charCodeAt(0) === 47, trailing = p.charCodeAt(p.length - 1) === 47;
    p = __pnorm(p, !isAbsolute, '/', __pisPosix);
    if (p.length === 0) { if (isAbsolute) return '/'; return trailing ? './' : '.'; }
    if (trailing) p += '/';
    return isAbsolute ? '/' + p : p;
  };
  posix.isAbsolute = function (p) { __pvs(p, 'path'); return p.length > 0 && p.charCodeAt(0) === 47; };
  posix.join = function () {
    if (arguments.length === 0) return '.';
    var joined, i, a;
    for (i = 0; i < arguments.length; ++i) {
      a = arguments[i];
      __pvs(a, 'path');
      if (a.length > 0) { if (joined === undefined) joined = a; else joined += '/' + a; }
    }
    if (joined === undefined) return '.';
    return posix.normalize(joined);
  };
  posix.relative = function (from, to) {
    __pvs(from, 'from'); __pvs(to, 'to');
    if (from === to) return '';
    from = posix.resolve(from); to = posix.resolve(to);
    if (from === to) return '';
    var fromStart = 1, fromEnd = from.length, fromLen = fromEnd - fromStart, toStart = 1, toLen = to.length - toStart;
    var length = fromLen < toLen ? fromLen : toLen, lastCommonSep = -1, i = 0, fc;
    for (; i < length; i++) {
      fc = from.charCodeAt(fromStart + i);
      if (fc !== to.charCodeAt(toStart + i)) break;
      else if (fc === 47) lastCommonSep = i;
    }
    if (i === length) {
      if (toLen > length) {
        if (to.charCodeAt(toStart + i) === 47) return to.slice(toStart + i + 1);
        if (i === 0) return to.slice(toStart + i);
      } else if (fromLen > length) {
        if (from.charCodeAt(fromStart + i) === 47) lastCommonSep = i;
        else if (i === 0) lastCommonSep = 0;
      }
    }
    var out = '';
    for (i = fromStart + lastCommonSep + 1; i <= fromEnd; ++i) {
      if (i === fromEnd || from.charCodeAt(i) === 47) out += out.length === 0 ? '..' : '/..';
    }
    return out + to.slice(toStart + lastCommonSep);
  };
  posix.toNamespacedPath = function (p) { return p; };
  posix.dirname = function (p) {
    __pvs(p, 'path');
    if (p.length === 0) return '.';
    var hasRoot = p.charCodeAt(0) === 47, end = -1, matchedSlash = true, i;
    for (i = p.length - 1; i >= 1; --i) {
      if (p.charCodeAt(i) === 47) { if (!matchedSlash) { end = i; break; } }
      else matchedSlash = false;
    }
    if (end === -1) return hasRoot ? '/' : '.';
    if (hasRoot && end === 1) return '//';
    return p.slice(0, end);
  };
  posix.basename = function (p, suffix) {
    if (suffix !== undefined) __pvs(suffix, 'suffix');
    __pvs(p, 'path');
    var start = 0, end = -1, matchedSlash = true, i, code, extIdx, firstNonSlashEnd;
    if (suffix !== undefined && suffix.length > 0 && suffix.length <= p.length) {
      if (suffix === p) return '';
      extIdx = suffix.length - 1; firstNonSlashEnd = -1;
      for (i = p.length - 1; i >= 0; --i) {
        code = p.charCodeAt(i);
        if (code === 47) { if (!matchedSlash) { start = i + 1; break; } }
        else {
          if (firstNonSlashEnd === -1) { matchedSlash = false; firstNonSlashEnd = i + 1; }
          if (extIdx >= 0) {
            if (code === suffix.charCodeAt(extIdx)) { if (--extIdx === -1) end = i; }
            else { extIdx = -1; end = firstNonSlashEnd; }
          }
        }
      }
      if (start === end) end = firstNonSlashEnd;
      else if (end === -1) end = p.length;
      return p.slice(start, end);
    }
    for (i = p.length - 1; i >= 0; --i) {
      if (p.charCodeAt(i) === 47) { if (!matchedSlash) { start = i + 1; break; } }
      else if (end === -1) { matchedSlash = false; end = i + 1; }
    }
    if (end === -1) return '';
    return p.slice(start, end);
  };
  posix.extname = function (p) {
    __pvs(p, 'path');
    var startDot = -1, startPart = 0, end = -1, matchedSlash = true, preDotState = 0, i, code;
    for (i = p.length - 1; i >= 0; --i) {
      code = p.charCodeAt(i);
      if (code === 47) { if (!matchedSlash) { startPart = i + 1; break; } continue; }
      if (end === -1) { matchedSlash = false; end = i + 1; }
      if (code === 46) { if (startDot === -1) startDot = i; else if (preDotState !== 1) preDotState = 1; }
      else if (startDot !== -1) preDotState = -1;
    }
    if (startDot === -1 || end === -1 || preDotState === 0 || (preDotState === 1 && startDot === end - 1 && startDot === startPart + 1)) return '';
    return p.slice(startDot, end);
  };
  posix.format = function (o) { return __pformat('/', o); };
  posix.parse = function (p) {
    __pvs(p, 'path');
    var ret = { root: '', dir: '', base: '', ext: '', name: '' };
    if (p.length === 0) return ret;
    var isAbsolute = p.charCodeAt(0) === 47, start, startDot = -1, startPart = 0, end = -1, matchedSlash = true, i = p.length - 1, preDotState = 0, code, s2;
    if (isAbsolute) { ret.root = '/'; start = 1; } else start = 0;
    for (; i >= start; --i) {
      code = p.charCodeAt(i);
      if (code === 47) { if (!matchedSlash) { startPart = i + 1; break; } continue; }
      if (end === -1) { matchedSlash = false; end = i + 1; }
      if (code === 46) { if (startDot === -1) startDot = i; else if (preDotState !== 1) preDotState = 1; }
      else if (startDot !== -1) preDotState = -1;
    }
    if (end !== -1) {
      s2 = startPart === 0 && isAbsolute ? 1 : startPart;
      if (startDot === -1 || preDotState === 0 || (preDotState === 1 && startDot === end - 1 && startDot === startPart + 1)) {
        ret.base = ret.name = p.slice(s2, end);
      } else {
        ret.name = p.slice(s2, startDot); ret.base = p.slice(s2, end); ret.ext = p.slice(startDot, end);
      }
    }
    if (startPart > 0) ret.dir = p.slice(0, startPart - 1);
    else if (isAbsolute) ret.dir = '/';
    return ret;
  };
  posix.sep = '/';
  posix.delimiter = ':';
  posix.posix = posix;
  return posix;
}
function __mkWin32() {
  var win32 = {};
  win32.resolve = function () {
    var resolvedDevice = '', resolvedTail = '', resolvedAbsolute = false, i, p, len, rootEnd, device, isAbsolute, code, j, last, firstPart;
    for (i = arguments.length - 1; i >= -1; i--) {
      if (i >= 0) {
        p = arguments[i];
        __pvs(p, 'paths[' + i + ']');
        if (p.length === 0) continue;
      } else if (resolvedDevice.length === 0) {
        p = process.cwd();
        if (arguments.length === 0 || ((arguments.length === 1 && (arguments[0] === '' || arguments[0] === '.')) && __pisSep(p.charCodeAt(0)))) {
          return p;
        }
      } else {
        p = process.env['=' + resolvedDevice] || process.cwd();
        if (p === undefined || (p.slice(0, 2).toLowerCase() !== resolvedDevice.toLowerCase() && p.charCodeAt(2) === 92)) p = resolvedDevice + '\\';
      }
      len = p.length; rootEnd = 0; device = ''; isAbsolute = false;
      code = p.charCodeAt(0);
      if (len === 1) {
        if (__pisSep(code)) { rootEnd = 1; isAbsolute = true; }
      } else if (__pisSep(code)) {
        isAbsolute = true;
        if (__pisSep(p.charCodeAt(1))) {
          j = 2; last = j;
          while (j < len && !__pisSep(p.charCodeAt(j))) j++;
          if (j < len && j !== last) {
            firstPart = p.slice(last, j);
            last = j;
            while (j < len && __pisSep(p.charCodeAt(j))) j++;
            if (j < len && j !== last) {
              last = j;
              while (j < len && !__pisSep(p.charCodeAt(j))) j++;
              if (j === len || j !== last) {
                if (firstPart !== '.' && firstPart !== '?') {
                  device = '\\\\' + firstPart + '\\' + p.slice(last, j);
                  rootEnd = j;
                } else {
                  device = '\\\\' + firstPart;
                  rootEnd = 4;
                }
              }
            }
          }
        } else {
          rootEnd = 1;
        }
      } else if (__pisDev(code) && p.charCodeAt(1) === 58) {
        device = p.slice(0, 2); rootEnd = 2;
        if (len > 2 && __pisSep(p.charCodeAt(2))) { isAbsolute = true; rootEnd = 3; }
      }
      if (device.length > 0) {
        if (resolvedDevice.length > 0) {
          if (device.toLowerCase() !== resolvedDevice.toLowerCase()) continue;
        } else {
          resolvedDevice = device;
        }
      }
      if (resolvedAbsolute) {
        if (resolvedDevice.length > 0) break;
      } else {
        resolvedTail = p.slice(rootEnd) + '\\' + resolvedTail;
        resolvedAbsolute = isAbsolute;
        if (isAbsolute && resolvedDevice.length > 0) break;
      }
    }
    resolvedTail = __pnorm(resolvedTail, !resolvedAbsolute, '\\', __pisSep);
    return resolvedAbsolute ? resolvedDevice + '\\' + resolvedTail : (resolvedDevice + resolvedTail) || '.';
  };
  win32.normalize = function (p) {
    __pvs(p, 'path');
    var len = p.length, rootEnd = 0, device, isAbsolute = false, code, j, last, firstPart, tail, ci, poss;
    if (len === 0) return '.';
    code = p.charCodeAt(0);
    if (len === 1) return __pisPosix(code) ? '\\' : p;
    if (__pisSep(code)) {
      isAbsolute = true;
      if (__pisSep(p.charCodeAt(1))) {
        j = 2; last = j;
        while (j < len && !__pisSep(p.charCodeAt(j))) j++;
        if (j < len && j !== last) {
          firstPart = p.slice(last, j);
          last = j;
          while (j < len && __pisSep(p.charCodeAt(j))) j++;
          if (j < len && j !== last) {
            last = j;
            while (j < len && !__pisSep(p.charCodeAt(j))) j++;
            if (j === len || j !== last) {
              if (firstPart === '.' || firstPart === '?') {
                device = '\\\\' + firstPart;
                rootEnd = 4;
                ci = p.indexOf(':');
                poss = p.slice(4, ci + 1);
                if (__pres(poss, poss.length - 1)) {
                  device = '\\\\?\\' + poss;
                  rootEnd = 4 + poss.length;
                }
              } else if (j === len) {
                return '\\\\' + firstPart + '\\' + p.slice(last) + '\\';
              } else {
                device = '\\\\' + firstPart + '\\' + p.slice(last, j);
                rootEnd = j;
              }
            }
          }
        }
      } else {
        rootEnd = 1;
      }
    } else {
      ci = p.indexOf(':');
      if (ci > 0) {
        if (__pisDev(code) && ci === 1) {
          device = p.slice(0, 2);
          rootEnd = 2;
          if (len > 2 && __pisSep(p.charCodeAt(2))) { isAbsolute = true; rootEnd = 3; }
        } else if (__pres(p, ci)) {
          device = p.slice(0, ci + 1);
          rootEnd = ci + 1;
        }
      }
    }
    tail = rootEnd < len ? __pnorm(p.slice(rootEnd), !isAbsolute, '\\', __pisSep) : '';
    if (tail.length === 0 && !isAbsolute) tail = '.';
    if (tail.length > 0 && __pisSep(p.charCodeAt(len - 1))) tail += '\\';
    if (!isAbsolute && device === undefined && p.indexOf(':') >= 0) {
      // un chemin relatif ne doit pas devenir un chemin de lecteur (CVE-2024-36139)
      if (tail.length >= 2 && __pisDev(tail.charCodeAt(0)) && tail.charCodeAt(1) === 58) return '.\\' + tail;
      j = p.indexOf(':');
      do {
        if (j === len - 1 || __pisSep(p.charCodeAt(j + 1))) return '.\\' + tail;
      } while ((j = p.indexOf(':', j + 1)) !== -1);
    }
    if (__pres(p, p.indexOf(':'))) return '.\\' + (device === undefined || device === null ? '' : device) + tail;
    if (device === undefined) return isAbsolute ? '\\' + tail : tail;
    return isAbsolute ? device + '\\' + tail : device + tail;
  };
  win32.isAbsolute = function (p) {
    __pvs(p, 'path');
    var len = p.length, code;
    if (len === 0) return false;
    code = p.charCodeAt(0);
    return __pisSep(code) || (len > 2 && __pisDev(code) && p.charCodeAt(1) === 58 && __pisSep(p.charCodeAt(2)));
  };
  win32.join = function () {
    if (arguments.length === 0) return '.';
    var path = [], firstPart, joined, i, a, needsReplace = true, slashCount = 0, firstLen, parts = [], part = '', result, pi, ci;
    for (i = 0; i < arguments.length; ++i) {
      a = arguments[i];
      __pvs(a, 'path');
      if (a.length > 0) path.push(a);
    }
    if (path.length === 0) return '.';
    firstPart = path[0];
    joined = path.join('\\');
    if (__pisSep(firstPart.charCodeAt(0))) {
      ++slashCount;
      firstLen = firstPart.length;
      if (firstLen > 1 && __pisSep(firstPart.charCodeAt(1))) {
        ++slashCount;
        if (firstLen > 2) {
          if (__pisSep(firstPart.charCodeAt(2))) ++slashCount;
          else needsReplace = false;
        }
      }
    }
    if (needsReplace) {
      while (slashCount < joined.length && __pisSep(joined.charCodeAt(slashCount))) slashCount++;
      if (slashCount >= 2) joined = '\\' + joined.slice(slashCount);
    }
    for (i = 0; i < joined.length; i++) {
      if (joined.charAt(i) === '\\') {
        if (part) parts.push(part);
        part = '';
        while (i + 1 < joined.length && joined.charAt(i + 1) === '\\') i++;
      } else {
        part += joined.charAt(i);
      }
    }
    if (part) parts.push(part);
    for (pi = 0; pi < parts.length; pi++) {
      ci = parts[pi].indexOf(':');
      if (ci !== -1 && __pres(parts[pi], ci)) {
        result = '';
        for (i = 0; i < joined.length; i++) result += joined.charAt(i) === '/' ? '\\' : joined.charAt(i);
        return result;
      }
    }
    return win32.normalize(joined);
  };
  win32.relative = function (from, to) {
    __pvs(from, 'from'); __pvs(to, 'to');
    if (from === to) return '';
    var fromOrig = win32.resolve(from), toOrig = win32.resolve(to);
    if (fromOrig === toOrig) return '';
    from = fromOrig.toLowerCase(); to = toOrig.toLowerCase();
    if (from === to) return '';
    if (fromOrig.length !== from.length || toOrig.length !== to.length) {
      var fromSplit = fromOrig.split('\\'), toSplit = toOrig.split('\\'), n, k;
      if (fromSplit[fromSplit.length - 1] === '') fromSplit.pop();
      if (toSplit[toSplit.length - 1] === '') toSplit.pop();
      var fl = fromSplit.length, tl = toSplit.length, ln = fl < tl ? fl : tl, ix;
      for (ix = 0; ix < ln; ix++) {
        if (fromSplit[ix].toLowerCase() !== toSplit[ix].toLowerCase()) break;
      }
      if (ix === 0) return toOrig;
      if (ix === ln) {
        if (tl > ln) return toSplit.slice(ix).join('\\');
        if (fl > ln) return '..\\'.repeat(fl - 1 - ix) + '..';
        return '';
      }
      return '..\\'.repeat(fl - ix) + toSplit.slice(ix).join('\\');
    }
    var fromStart = 0, fromEnd, fromLen, toStart = 0, toEnd, toLen, length, lastCommonSep = -1, i = 0, fc, out = '';
    while (fromStart < from.length && from.charCodeAt(fromStart) === 92) fromStart++;
    fromEnd = from.length;
    while (fromEnd - 1 > fromStart && from.charCodeAt(fromEnd - 1) === 92) fromEnd--;
    fromLen = fromEnd - fromStart;
    while (toStart < to.length && to.charCodeAt(toStart) === 92) toStart++;
    toEnd = to.length;
    while (toEnd - 1 > toStart && to.charCodeAt(toEnd - 1) === 92) toEnd--;
    toLen = toEnd - toStart;
    length = fromLen < toLen ? fromLen : toLen;
    for (; i < length; i++) {
      fc = from.charCodeAt(fromStart + i);
      if (fc !== to.charCodeAt(toStart + i)) break;
      else if (fc === 92) lastCommonSep = i;
    }
    if (i !== length) {
      if (lastCommonSep === -1) return toOrig;
    } else {
      if (toLen > length) {
        if (to.charCodeAt(toStart + i) === 92) return toOrig.slice(toStart + i + 1);
        if (i === 2) return toOrig.slice(toStart + i);
      }
      if (fromLen > length) {
        if (from.charCodeAt(fromStart + i) === 92) lastCommonSep = i;
        else if (i === 2) lastCommonSep = 3;
      }
      if (lastCommonSep === -1) lastCommonSep = 0;
    }
    for (i = fromStart + lastCommonSep + 1; i <= fromEnd; ++i) {
      if (i === fromEnd || from.charCodeAt(i) === 92) out += out.length === 0 ? '..' : '\\..';
    }
    toStart += lastCommonSep;
    if (out.length > 0) return out + toOrig.slice(toStart, toEnd);
    if (toOrig.charCodeAt(toStart) === 92) ++toStart;
    return toOrig.slice(toStart, toEnd);
  };
  win32.toNamespacedPath = function (p) {
    if (typeof p !== 'string' || p.length === 0) return p;
    var r = win32.resolve(p), code;
    if (r.length <= 2) return p;
    if (r.charCodeAt(0) === 92) {
      if (r.charCodeAt(1) === 92) {
        code = r.charCodeAt(2);
        if (code !== 63 && code !== 46) return '\\\\?\\UNC\\' + r.slice(2);
      }
    } else if (__pisDev(r.charCodeAt(0)) && r.charCodeAt(1) === 58 && r.charCodeAt(2) === 92) {
      return '\\\\?\\' + r;
    }
    return r;
  };
  win32.dirname = function (p) {
    __pvs(p, 'path');
    var len = p.length, rootEnd = -1, offset = 0, code, j, last, end = -1, matchedSlash = true, i;
    if (len === 0) return '.';
    code = p.charCodeAt(0);
    if (len === 1) return __pisSep(code) ? p : '.';
    if (__pisSep(code)) {
      rootEnd = offset = 1;
      if (__pisSep(p.charCodeAt(1))) {
        j = 2; last = j;
        while (j < len && !__pisSep(p.charCodeAt(j))) j++;
        if (j < len && j !== last) {
          last = j;
          while (j < len && __pisSep(p.charCodeAt(j))) j++;
          if (j < len && j !== last) {
            last = j;
            while (j < len && !__pisSep(p.charCodeAt(j))) j++;
            if (j === len) return p;
            if (j !== last) rootEnd = offset = j + 1;
          }
        }
      }
    } else if (__pisDev(code) && p.charCodeAt(1) === 58) {
      rootEnd = len > 2 && __pisSep(p.charCodeAt(2)) ? 3 : 2;
      offset = rootEnd;
    }
    for (i = len - 1; i >= offset; --i) {
      if (__pisSep(p.charCodeAt(i))) { if (!matchedSlash) { end = i; break; } }
      else matchedSlash = false;
    }
    if (end === -1) {
      if (rootEnd === -1) return '.';
      end = rootEnd;
    }
    return p.slice(0, end);
  };
  win32.basename = function (p, suffix) {
    if (suffix !== undefined) __pvs(suffix, 'suffix');
    __pvs(p, 'path');
    var start = 0, end = -1, matchedSlash = true, i, code, extIdx, firstNonSlashEnd;
    if (p.length >= 2 && __pisDev(p.charCodeAt(0)) && p.charCodeAt(1) === 58) start = 2;
    if (suffix !== undefined && suffix.length > 0 && suffix.length <= p.length) {
      if (suffix === p) return '';
      extIdx = suffix.length - 1; firstNonSlashEnd = -1;
      for (i = p.length - 1; i >= start; --i) {
        code = p.charCodeAt(i);
        if (__pisSep(code)) { if (!matchedSlash) { start = i + 1; break; } }
        else {
          if (firstNonSlashEnd === -1) { matchedSlash = false; firstNonSlashEnd = i + 1; }
          if (extIdx >= 0) {
            if (code === suffix.charCodeAt(extIdx)) { if (--extIdx === -1) end = i; }
            else { extIdx = -1; end = firstNonSlashEnd; }
          }
        }
      }
      if (start === end) end = firstNonSlashEnd;
      else if (end === -1) end = p.length;
      return p.slice(start, end);
    }
    for (i = p.length - 1; i >= start; --i) {
      if (__pisSep(p.charCodeAt(i))) { if (!matchedSlash) { start = i + 1; break; } }
      else if (end === -1) { matchedSlash = false; end = i + 1; }
    }
    if (end === -1) return '';
    return p.slice(start, end);
  };
  win32.extname = function (p) {
    __pvs(p, 'path');
    var start = 0, startDot = -1, startPart = 0, end = -1, matchedSlash = true, preDotState = 0, i, code;
    if (p.length >= 2 && p.charCodeAt(1) === 58 && __pisDev(p.charCodeAt(0))) start = startPart = 2;
    for (i = p.length - 1; i >= start; --i) {
      code = p.charCodeAt(i);
      if (__pisSep(code)) { if (!matchedSlash) { startPart = i + 1; break; } continue; }
      if (end === -1) { matchedSlash = false; end = i + 1; }
      if (code === 46) { if (startDot === -1) startDot = i; else if (preDotState !== 1) preDotState = 1; }
      else if (startDot !== -1) preDotState = -1;
    }
    if (startDot === -1 || end === -1 || preDotState === 0 || (preDotState === 1 && startDot === end - 1 && startDot === startPart + 1)) return '';
    return p.slice(startDot, end);
  };
  win32.format = function (o) { return __pformat('\\', o); };
  win32.parse = function (p) {
    __pvs(p, 'path');
    var ret = { root: '', dir: '', base: '', ext: '', name: '' };
    if (p.length === 0) return ret;
    var len = p.length, rootEnd = 0, code = p.charCodeAt(0), j, last, startDot = -1, startPart, end = -1, matchedSlash = true, i, preDotState = 0;
    if (len === 1) {
      if (__pisSep(code)) { ret.root = ret.dir = p; return ret; }
      ret.base = ret.name = p;
      return ret;
    }
    if (__pisSep(code)) {
      rootEnd = 1;
      if (__pisSep(p.charCodeAt(1))) {
        j = 2; last = j;
        while (j < len && !__pisSep(p.charCodeAt(j))) j++;
        if (j < len && j !== last) {
          last = j;
          while (j < len && __pisSep(p.charCodeAt(j))) j++;
          if (j < len && j !== last) {
            last = j;
            while (j < len && !__pisSep(p.charCodeAt(j))) j++;
            if (j === len) rootEnd = j;
            else if (j !== last) rootEnd = j + 1;
          }
        }
      }
    } else if (__pisDev(code) && p.charCodeAt(1) === 58) {
      if (len <= 2) { ret.root = ret.dir = p; return ret; }
      rootEnd = 2;
      if (__pisSep(p.charCodeAt(2))) {
        if (len === 3) { ret.root = ret.dir = p; return ret; }
        rootEnd = 3;
      }
    }
    if (rootEnd > 0) ret.root = p.slice(0, rootEnd);
    startPart = rootEnd;
    for (i = p.length - 1; i >= rootEnd; --i) {
      code = p.charCodeAt(i);
      if (__pisSep(code)) { if (!matchedSlash) { startPart = i + 1; break; } continue; }
      if (end === -1) { matchedSlash = false; end = i + 1; }
      if (code === 46) { if (startDot === -1) startDot = i; else if (preDotState !== 1) preDotState = 1; }
      else if (startDot !== -1) preDotState = -1;
    }
    if (end !== -1) {
      if (startDot === -1 || preDotState === 0 || (preDotState === 1 && startDot === end - 1 && startDot === startPart + 1)) {
        ret.base = ret.name = p.slice(startPart, end);
      } else {
        ret.name = p.slice(startPart, startDot); ret.base = p.slice(startPart, end); ret.ext = p.slice(startDot, end);
      }
    }
    if (startPart > 0 && startPart !== rootEnd) ret.dir = p.slice(0, startPart - 1);
    else ret.dir = ret.root;
    return ret;
  };
  win32.sep = '\\';
  win32.delimiter = ';';
  win32.win32 = win32;
  return win32;
}
var __pathmod;
function __mkPath() {
  if (__pathmod) return __pathmod;
  var posix = __mkPosix(), win32 = __mkWin32();
  win32.posix = posix;
  posix.win32 = win32;
  __pathmod = win32;
  return win32;
}
