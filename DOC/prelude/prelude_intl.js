var __Intl, __ilData, __ilCache, __ilDef;
function __ilreg(tag, text) {
  if (__ilData === undefined) { __ilData = {}; __ilCache = {}; }
  __ilData[tag] = text;
}
function __ilGet(tag) {
  var d;
  if (__ilCache === undefined) { __ilData = {}; __ilCache = {}; }
  d = __ilCache[tag];
  if (d === undefined) {
    d = JSON.parse(__ilData[tag]);
    __ilCache[tag] = d;
  }
  return d;
}
function __ilCanon(tag) {
  var m, parts, out, i, p, lang, script = '', region = '', rest = [], ext = '', inExt = false, singleton = null;
  if (typeof tag !== 'string') {
    if (tag !== null && typeof tag === 'object' && typeof tag.baseName === 'string') tag = tag.toString();
    else throw new TypeError('Incorrect locale information provided');
  }
  if (!/^[A-Za-z]{2,3}(-[A-Za-z0-9]{1,8})*$|^[A-Za-z]{5,8}(-[A-Za-z0-9]{1,8})*$/.test(tag)) throw new RangeError('Incorrect locale information provided');
  parts = tag.split('-');
  lang = parts[0].toLowerCase();
  for (i = 1; i < parts.length; i++) {
    p = parts[i];
    if (inExt) { ext += '-' + p.toLowerCase(); continue; }
    if (p.length === 1) { inExt = true; ext += '-' + p.toLowerCase(); continue; }
    if (p.length === 4 && /^[A-Za-z]+$/.test(p) && script === '' && region === '') script = p.charAt(0).toUpperCase() + p.slice(1).toLowerCase();
    else if ((p.length === 2 && /^[A-Za-z]+$/.test(p)) || (p.length === 3 && /^[0-9]+$/.test(p))) region = p.toUpperCase();
    else rest.push(p.toLowerCase());
  }
  out = lang + (script ? '-' + script : '') + (region ? '-' + region : '') + (rest.length ? '-' + rest.join('-') : '') + ext;
  return out;
}
function __ilList(loc) {
  var r = [], i, c;
  if (loc === undefined) return r;
  if (typeof loc === 'string') return [__ilCanon(loc)];
  if (loc !== null && typeof loc === 'object' && typeof loc.baseName === 'string') return [loc.toString()];
  for (i = 0; i < loc.length; i++) { c = __ilCanon(loc[i]); if (r.indexOf(c) < 0) r.push(c); }
  return r;
}
function __ilDataFor(tag) {
  var base = tag.split('-u-')[0].split('-x-')[0], lang = base.split('-')[0], k, best = null, region;
  if (__ilData === undefined) __ilData = {};
  if (__ilData[base] !== undefined) return base;
  region = base.split('-').pop();
  if (region.length === 2 && __ilData[lang + '-' + region.toUpperCase()] !== undefined) return lang + '-' + region.toUpperCase();
  for (k in __ilData) if (k.split('-')[0] === lang) { best = k; break; }
  return best;
}
function __ilSupported(tag) {
  var d = __ilDataFor(tag), lang = tag.split('-')[0];
  return d !== null && (lang === d.split('-')[0]);
}
function __ilResolve(loc) {
  var list = __ilList(loc), i, d, tag = null, ext = {}, m, parts, key;
  for (i = 0; i < list.length; i++) {
    if (__ilSupported(list[i])) { tag = list[i]; break; }
  }
  if (tag === null) tag = 'en-US';
  d = __ilDataFor(tag);
  if (d === null) d = 'en-US';
  m = tag.indexOf('-u-');
  if (m >= 0) {
    parts = tag.slice(m + 3).split('-');
    for (i = 0; i < parts.length; i++) {
      if (parts[i].length === 2 && parts[i + 1] !== undefined) { ext[parts[i]] = parts[i + 1]; i++; }
    }
  }
  return { tag: tag.split('-u-')[0], data: d, ext: ext, full: tag };
}
// ---------- fuseaux horaires ----------
var __ilZones, __ilZoneLC;
function __ilZoneTable() {
  if (__ilZones !== undefined) return __ilZones;
  var z = {}, add = function (rule, std, names) { var i; for (i = 0; i < names.length; i++) z[names[i]] = [std, rule]; };
  add('us', -300, ['America/New_York', 'America/Detroit', 'America/Toronto', 'America/Montreal', 'US/Eastern', 'EST5EDT', 'America/Nassau']);
  add('us', -360, ['America/Chicago', 'America/Winnipeg', 'US/Central', 'CST6CDT']);
  add('us', -420, ['America/Denver', 'America/Edmonton', 'US/Mountain', 'MST7MDT']);
  add('us', -480, ['America/Los_Angeles', 'America/Vancouver', 'America/Tijuana', 'US/Pacific', 'PST8PDT']);
  add('us', -540, ['America/Anchorage', 'US/Alaska']);
  add('us', -240, ['America/Halifax', 'Atlantic/Bermuda']);
  add('us', -210, ['America/St_Johns']);
  add('', -420, ['America/Phoenix', 'US/Arizona', 'MST']);
  add('', -600, ['Pacific/Honolulu', 'US/Hawaii', 'HST']);
  add('', -300, ['America/Bogota', 'America/Lima', 'America/Panama', 'America/Jamaica', 'EST']);
  add('', -360, ['America/Mexico_City', 'America/Regina', 'America/Guatemala', 'America/Costa_Rica', 'America/El_Salvador']);
  add('', -240, ['America/Puerto_Rico', 'America/Caracas', 'America/La_Paz', 'America/Santo_Domingo', 'America/Manaus']);
  add('', -180, ['America/Sao_Paulo', 'America/Argentina/Buenos_Aires', 'America/Buenos_Aires', 'America/Montevideo', 'America/Bahia', 'America/Recife']);
  add('', -240, ['America/Santiago']);
  add('', 0, ['UTC', 'GMT', 'Etc/UTC', 'Etc/GMT', 'Atlantic/Reykjavik', 'Africa/Abidjan', 'Africa/Accra', 'Africa/Dakar', 'Zulu', 'UCT', 'Etc/UCT']);
  add('eu', 0, ['Europe/London', 'Europe/Dublin', 'Europe/Lisbon', 'Atlantic/Canary', 'Atlantic/Madeira', 'Atlantic/Faroe', 'GB', 'Europe/Belfast', 'WET']);
  add('eu', 60, ['Europe/Paris', 'Europe/Berlin', 'Europe/Madrid', 'Europe/Rome', 'Europe/Amsterdam', 'Europe/Brussels', 'Europe/Vienna', 'Europe/Zurich', 'Europe/Stockholm',
    'Europe/Oslo', 'Europe/Copenhagen', 'Europe/Prague', 'Europe/Warsaw', 'Europe/Budapest', 'Europe/Belgrade', 'Europe/Zagreb', 'Europe/Luxembourg', 'Europe/Monaco', 'Europe/Malta',
    'Europe/Bratislava', 'Europe/Ljubljana', 'Europe/Sarajevo', 'Europe/Skopje', 'Europe/Tirane', 'Europe/Vaduz', 'Europe/Andorra', 'Europe/Gibraltar', 'Africa/Ceuta', 'CET', 'MET']);
  add('eu', 120, ['Europe/Athens', 'Europe/Helsinki', 'Europe/Kiev', 'Europe/Kyiv', 'Europe/Bucharest', 'Europe/Sofia', 'Europe/Riga', 'Europe/Tallinn', 'Europe/Vilnius', 'Asia/Nicosia', 'EET']);
  add('', 120, ['Africa/Cairo', 'Africa/Johannesburg', 'Africa/Harare', 'Africa/Maputo', 'Africa/Tripoli', 'Asia/Beirut', 'Africa/Khartoum', 'Africa/Windhoek']);
  add('', 60, ['Africa/Lagos', 'Africa/Algiers', 'Africa/Tunis', 'Africa/Kinshasa', 'Africa/Casablanca']);
  add('', 180, ['Europe/Moscow', 'Europe/Istanbul', 'Asia/Istanbul', 'Turkey', 'Europe/Minsk', 'Asia/Riyadh', 'Asia/Baghdad', 'Asia/Kuwait', 'Asia/Qatar', 'Africa/Nairobi', 'Africa/Addis_Ababa', 'Africa/Dar_es_Salaam', 'Europe/Kirov',
    'Europe/Simferopol']);
  add('', 210, ['Asia/Tehran']);
  add('', 240, ['Asia/Dubai', 'Asia/Muscat', 'Asia/Baku', 'Asia/Tbilisi', 'Asia/Yerevan', 'Europe/Samara', 'Indian/Mauritius']);
  add('', 270, ['Asia/Kabul']);
  add('', 300, ['Asia/Karachi', 'Asia/Tashkent', 'Asia/Yekaterinburg', 'Indian/Maldives']);
  add('', 330, ['Asia/Kolkata', 'Asia/Calcutta', 'Asia/Colombo']);
  add('', 345, ['Asia/Kathmandu', 'Asia/Katmandu']);
  add('', 360, ['Asia/Dhaka', 'Asia/Almaty', 'Asia/Omsk', 'Asia/Thimphu']);
  add('', 390, ['Asia/Yangon', 'Asia/Rangoon']);
  add('', 420, ['Asia/Bangkok', 'Asia/Jakarta', 'Asia/Ho_Chi_Minh', 'Asia/Saigon', 'Asia/Novosibirsk', 'Asia/Krasnoyarsk', 'Asia/Phnom_Penh', 'Asia/Vientiane']);
  add('', 480, ['Asia/Shanghai', 'Asia/Hong_Kong', 'Asia/Singapore', 'Asia/Taipei', 'Asia/Manila', 'Asia/Kuala_Lumpur', 'Australia/Perth', 'Asia/Macau', 'Asia/Irkutsk', 'Asia/Ulaanbaatar', 'PRC', 'Singapore', 'Hongkong']);
  add('', 540, ['Asia/Tokyo', 'Asia/Seoul', 'Asia/Pyongyang', 'Asia/Yakutsk', 'Japan', 'Asia/Dili']);
  add('', 570, ['Australia/Darwin']);
  add('au', 570, ['Australia/Adelaide', 'Australia/Broken_Hill']);
  add('', 600, ['Australia/Brisbane', 'Pacific/Port_Moresby', 'Pacific/Guam', 'Asia/Vladivostok']);
  add('au', 600, ['Australia/Sydney', 'Australia/Melbourne', 'Australia/Canberra', 'Australia/Hobart', 'Australia/ACT', 'Australia/NSW', 'Australia/Victoria', 'Australia/Tasmania']);
  add('', 660, ['Pacific/Noumea', 'Pacific/Guadalcanal', 'Asia/Magadan', 'Asia/Sakhalin']);
  add('nz', 720, ['Pacific/Auckland', 'NZ', 'Antarctica/McMurdo']);
  add('', 720, ['Pacific/Fiji', 'Asia/Kamchatka', 'Pacific/Tarawa']);
  add('', 780, ['Pacific/Tongatapu', 'Pacific/Apia']);
  add('', -660, ['Pacific/Pago_Pago', 'Pacific/Midway']);
  add('', -120, ['Atlantic/South_Georgia', 'America/Noronha']);
  add('', -60, ['Atlantic/Azores']);
  __ilZones = z;
  return z;
}
function __ilNthDow(y, mon, dow, n, h, mi) {
  var first = __mktime(y, mon, 1, 0, 0, 0, 0), w0 = __dparts(first).wd, day, dim;
  if (n > 0) day = 1 + ((dow - w0 + 7) % 7) + 7 * (n - 1);
  else {
    dim = __civil(__days_from_civil(mon === 11 ? y + 1 : y, mon === 11 ? 1 : mon + 2, 1) - 1)[2];
    day = dim - ((__dparts(__mktime(y, mon, dim, 0, 0, 0, 0)).wd - dow + 7) % 7);
  }
  return __mktime(y, mon, day, h, mi || 0, 0, 0);
}
function __ilZoneOff(zi, t) {
  var so = zi[0], rule = zi[1], y, a, b, in1;
  if (rule === '') return [so, false];
  y = __dparts(t + so * 60000).y;
  if (rule === 'us') {
    if (y >= 2007) { a = __ilNthDow(y, 2, 0, 2, 2) - so * 60000; b = __ilNthDow(y, 10, 0, 1, 2) - (so + 60) * 60000; }
    else if (y >= 1987) { a = __ilNthDow(y, 3, 0, 1, 2) - so * 60000; b = __ilNthDow(y, 9, 0, -1, 2) - (so + 60) * 60000; }
    else if (y >= 1976) { a = __ilNthDow(y, 3, 0, -1, 2) - so * 60000; b = __ilNthDow(y, 9, 0, -1, 2) - (so + 60) * 60000; }
    else return [so, false];
    return a < b ? (t >= a && t < b ? [so + 60, true] : [so, false]) : [so, false];
  }
  if (rule === 'eu') {
    a = __ilNthDow(y, 2, 0, -1, 1) ; b = __ilNthDow(y, y >= 1996 ? 9 : 8, 0, -1, 1);
    return (t >= a && t < b) ? [so + 60, true] : [so, false];
  }
  if ((rule === 'au' || rule === 'nz') && y < 1990) return [so, false];
  if (rule === 'eu' && y < 1980) return [so, false];
  if (rule === 'au') {
    a = __ilNthDow(y, 9, 0, 1, 2) - so * 60000; b = __ilNthDow(y, 3, 0, 1, 3) - (so + 60) * 60000;
    return (t >= a || t < b) ? [so + 60, true] : [so, false];
  }
  if (rule === 'nz') {
    a = __ilNthDow(y, 8, 0, -1, 2) - so * 60000; b = __ilNthDow(y, 3, 0, 1, 3) - (so + 60) * 60000;
    return (t >= a || t < b) ? [so + 60, true] : [so, false];
  }
  return [so, false];
}
// retourne { off (minutes), dst, id, fixed }
function __ilZoneOf(tz) {
  var t, m, zt, k, lower;
  if (tz === undefined) return { local: true };
  tz = String(tz);
  lower = tz.toLowerCase();
  m = /^([+-])(\d\d)(?::?(\d\d))?$/.exec(tz);
  if (m) return { fixed: (m[1] === '-' ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3] || 0)), id: tz.length === 3 ? tz + ':00' : (tz.length === 5 ? tz.slice(0, 3) + ':' + tz.slice(3) : tz) };
  if (lower === 'utc' || lower === 'etc/utc' || lower === 'gmt' || lower === 'etc/gmt' || lower === 'z' || lower === 'etc/uct' || lower === 'uct' || lower === 'zulu') return { fixed: 0, id: 'UTC', utc: true };
  zt = __ilZoneTable();
  if (zt[tz] !== undefined) return { zi: zt[tz], id: tz };
  if (__ilZoneLC === undefined) { __ilZoneLC = {}; var ks = Object.keys(zt), q; for (q = 0; q < ks.length; q++) __ilZoneLC[ks[q].toLowerCase()] = ks[q]; }
  k = __ilZoneLC[lower];
  if (k !== undefined) return { zi: zt[k], id: k };
  throw new RangeError('Invalid time zone specified: ' + tz);
}
function __ilOffsetOf(z, t) {
  if (z.local) return [__tzoff(t), false];
  if (z.fixed !== undefined) return [z.fixed, false];
  return __ilZoneOff(z.zi, t);
}
// ---------- formatage de dates ----------
function __ilPad(n, w) { var s = String(n); while (s.length < w) s = '0' + s; return s; }
function __ilGmt(L, off, long) {
  var Z = L.Z, s = Z.a, m = /^(.*?)([+\-−])(\d+)(?::(\d\d))?$/.exec(Z.a), pre = m ? m[1] : 'GMT', minus = '-', mm = /([−\-])/.exec(Z.c), a, h, mi, hs;
  if (mm) minus = mm[1];
  if (off === 0) return pre === 'GMT' && !m ? 'GMT' : pre;
  a = off < 0 ? -off : off;
  h = Math.floor(a / 60); mi = a % 60;
  hs = long || (m && m[3].length === 2) ? __ilPad(h, 2) : String(h);
  if (long) return pre + (off < 0 ? minus : '+') + hs + ':' + __ilPad(mi, 2);
  return pre + (off < 0 ? minus : '+') + hs + (mi ? ':' + __ilPad(mi, 2) : '');
}

var __ilReps;
function __ilRepOf(L, id, zi) {
  var k, ks, best = null;
  if (L.ZN[id] !== undefined) return id;
  ks = Object.keys(L.ZN);
  for (k = 0; k < ks.length; k++) {
    var rz = __ilZoneTable()[ks[k]];
    if (rz !== undefined && rz[0] === zi[0] && rz[1] === zi[1]) { best = ks[k]; break; }
  }
  return best;
}
function __ilTzName(L, z, t, kind, off) {
  var Z = L.Z, rep, nm, id, zi;
  if (kind === 'longOffset') return __ilGmt(L, off[0], true);
  if (kind === 'shortOffset') return __ilGmt(L, off[0], false);
  if (kind === 'shortGeneric' || kind === 'longGeneric') kind = kind === 'shortGeneric' ? 'short' : 'long';
  if (z.utc || (z.fixed === 0 && z.id === 'UTC')) return kind === 'long' ? Z.U : Z.u;
  if (z.fixed !== undefined) return __ilGmt(L, z.fixed, false);
  id = z.local ? __ilLocalZoneId() : z.id;
  zi = z.local ? __ilZoneTable()[id] : z.zi;
  if (id === 'UTC') return kind === 'long' ? Z.U : Z.u;
  if (zi !== undefined) {
    rep = __ilRepOf(L, id, zi);
    if (rep !== null) {
      nm = L.ZN[rep][(kind === 'long' ? 2 : 0) + (off[1] ? 1 : 0)];
      if (nm !== undefined && !(zi[0] === 0 && zi[1] === '' && false)) return nm;
    }
  }
  return __ilGmt(L, off[0], kind === 'long');
}
function __ilDateFields(t, z) {
  var off = __ilOffsetOf(z, t), p = __dparts(t + off[0] * 60000);
  p.off = off;
  return p;
}
function __ilNormDate(o, required, defaults) {
  var r = {}, k, need = true, i;
  var fields = ['weekday', 'era', 'year', 'month', 'day', 'dayPeriod', 'hour', 'minute', 'second', 'fractionalSecondDigits', 'timeZoneName', 'hour12', 'hourCycle', 'timeZone', 'dateStyle', 'timeStyle', 'calendar', 'numberingSystem'];
  if (o === undefined || o === null) o = {};
  else if (typeof o !== 'object') o = Object(o);
  for (i = 0; i < fields.length; i++) { k = fields[i]; if (o[k] !== undefined) r[k] = o[k]; }
  var chk = function (name, list) { if (r[name] !== undefined && list.indexOf(String(r[name])) < 0) throw new RangeError('Value ' + r[name] + ' out of range for Intl.DateTimeFormat options property ' + name); };
  chk('weekday', ['narrow', 'short', 'long']); chk('year', ['2-digit', 'numeric']); chk('month', ['2-digit', 'numeric', 'narrow', 'short', 'long']);
  chk('day', ['2-digit', 'numeric']); chk('hour', ['2-digit', 'numeric']); chk('minute', ['2-digit', 'numeric']); chk('second', ['2-digit', 'numeric']);
  chk('dateStyle', ['full', 'long', 'medium', 'short']); chk('timeStyle', ['full', 'long', 'medium', 'short']);
  chk('timeZoneName', ['short', 'long', 'shortOffset', 'longOffset', 'shortGeneric', 'longGeneric']); chk('hourCycle', ['h11', 'h12', 'h23', 'h24']);
  if (r.fractionalSecondDigits !== undefined) {
    r.fractionalSecondDigits = Math.floor(Number(r.fractionalSecondDigits));
    if (!(r.fractionalSecondDigits >= 1 && r.fractionalSecondDigits <= 3)) throw new RangeError('fractionalSecondDigits value is out of range.');
  }
  if (r.dateStyle !== undefined || r.timeStyle !== undefined) {
    for (i = 0; i < fields.length - 5; i++) if (r[fields[i]] !== undefined && fields[i] !== 'hour12' && fields[i] !== 'hourCycle') throw new TypeError("Can't set option " + fields[i] + ' when ' + (r.dateStyle !== undefined ? 'dateStyle'
      : 'timeStyle') + ' is used');
    if (required === 'date' && r.timeStyle !== undefined) throw new TypeError('Invalid option : timeStyle');
    if (required === 'time' && r.dateStyle !== undefined) throw new TypeError('Invalid option : dateStyle');
    return r;
  }
  if (required === 'date' || required === 'any') {
    if (r.weekday !== undefined || r.year !== undefined || r.month !== undefined || r.day !== undefined) need = false;
  }
  if (required === 'time' || required === 'any') {
    if (r.dayPeriod !== undefined || r.hour !== undefined || r.minute !== undefined || r.second !== undefined || r.fractionalSecondDigits !== undefined) need = false;
  }
  if (need && (defaults === 'date' || defaults === 'all')) { r.year = 'numeric'; r.month = 'numeric'; r.day = 'numeric'; }
  if (need && (defaults === 'time' || defaults === 'all')) { r.hour = 'numeric'; r.minute = 'numeric'; r.second = 'numeric'; }
  return r;
}
function __ilHC(L, r, ext) {
  var hc = r.hourCycle;
  if (r.hour12 !== undefined) return r.hour12 ? L.h12 : 'h23';
  if (hc === undefined && ext && ext.hc) hc = ext.hc;
  if (hc === undefined) hc = L.hcn;
  return hc;
}
function __ilTokens(pat, f, st) {
  var out = [], re = /\{([A-Za-z]+)(?:#(\d+))?\}/g, m, last = 0, L = st.L, tok, v, o = st.o;
  var push = function (type, val) { out.push({ type: type, value: val }); };
  var lit = function (s) { if (s !== '') { if (out.length && out[out.length - 1].type === 'literal') out[out.length - 1].value += s; else push('literal', s); } };
  while ((m = re.exec(pat)) !== null) {
    lit(pat.slice(last, m.index));
    last = m.index + m[0].length;
    tok = m[1];
    switch (tok) {
      case 'E': push('weekday', L.P[Number(m[2])][f.wd]); break;
      case 'M': if (m[2] !== undefined) push('month', L.P[Number(m[2])][f.m]); else push('month', o.month === '2-digit' ? __ilPad(f.m + 1, 2) : String(f.m + 1)); break;
      case 'MM': push('month', __ilPad(f.m + 1, 2)); break;
      case 'd': push('day', o.day === '2-digit' ? __ilPad(f.d, 2) : String(f.d)); break;
      case 'dd': push('day', __ilPad(f.d, 2)); break;
      case 'y': push('year', o.year === '2-digit' ? __ilPad(((f.y % 100) + 100) % 100, 2) : String(f.y)); break;
      case 'yy': push('year', __ilPad(((f.y % 100) + 100) % 100, 2)); break;
      case 'h': case 'hh': case 'H': case 'HH': {
        v = f.h;
        if (st.hc === 'h12') v = v % 12 === 0 ? 12 : v % 12;
        else if (st.hc === 'h11') v = v % 12;
        else if (st.hc === 'h24') v = v === 0 ? 24 : v;
        push('hour', (tok.length === 2 || o.hour === '2-digit') ? __ilPad(v, 2) : String(v));
        break;
      }
      case 'm': case 'mm': push('minute', (tok === 'mm' || o.minute === '2-digit') ? __ilPad(f.mi, 2) : String(f.mi)); break;
      case 's': case 'ss': push('second', (tok === 'ss' || o.second === '2-digit') ? __ilPad(f.s, 2) : String(f.s)); break;
      case 'a': v = L.P[Number(m[2])]; push('dayPeriod', v.length === 24 ? v[f.h] : v[f.h < 12 ? 0 : 1]); break;
      case 'z': push('timeZoneName', st.tzname()); break;
      case 'zz': push('timeZoneName', st.tzname()); break;
      case 'G': push('era', f.y > 0 ? 'AD' : 'BC'); break;
      case 'f': push('fractionalSecond', __ilPad(f.ms, 3).slice(0, o.fractionalSecondDigits || 3)); break;
      default: lit(m[0]);
    }
  }
  lit(pat.slice(last));
  return out;
}
function __ilDateParts(dtf, t) {
  var L = dtf['\x01L'], r = dtf['\x01o'], z = dtf['\x01z'], f, st, pat, dpat, tpat, key, hc, g, parts, gi, dm, tm, i, kind, tzkind;
  if (t !== t || Math.abs(t) > 8.64e15) throw new RangeError('Invalid time value');
  f = __ilDateFields(t, z);
  hc = dtf['\x01h'];
  st = { L: L, o: r, hc: hc, tzk: r.timeZoneName, tzname: function () { return __ilTzName(L, z, t, st.tzk || 'short', f.off); } };
  if (r.dateStyle !== undefined || r.timeStyle !== undefined) {
    var gl = ['full', 'long', 'medium', 'short'].indexOf(r.dateStyle);
    var tfam = (hc === 'h12' || hc === 'h11') ? 'h' : 'H', fam0 = L.hc;
    dpat = r.dateStyle !== undefined ? L.S['d' + r.dateStyle[0]] : null;
    tpat = r.timeStyle !== undefined ? L.S[(tfam === fam0 ? 't' : 'u') + r.timeStyle[0]] : null;
    if (r.timeStyle === 'full' || r.timeStyle === 'long') st.tzk = r.timeStyle === 'full' ? 'long' : 'short';
    dm = dpat !== null ? __ilTokens(dpat, f, { L: L, o: {}, hc: hc, tzname: st.tzname }) : [];
    tm = tpat !== null ? __ilTokens(tpat, f, { L: L, o: {}, hc: hc, tzname: st.tzname }) : [];
    if (dm.length && tm.length) {
      g = L.G[gl];
      parts = g[0] === 0 ? dm.concat([{ type: 'literal', value: g[1] }], tm) : tm.concat([{ type: 'literal', value: g[1] }], dm);
      parts = __ilGlueWrap(g, parts);
    } else parts = dm.length ? dm : tm;
    return parts;
  }
  var w = r.weekday === undefined ? null : r.weekday, mo = r.month === undefined ? null : r.month, yy = r.year !== undefined, dd = r.day !== undefined;
  var hasDate = w !== null || mo !== null || yy || dd;
  if (hasDate) {
    key = (w === null ? '-' : w === 'narrow' ? 'r' : w.charAt(0)) + (mo === null ? '-' : (mo === 'numeric' || mo === '2-digit') ? '#' : mo === 'narrow' ? 'r' : mo.charAt(0)) + (yy ? 'y' : '-') + (dd ? 'd' : '-');
    dpat = L.D[key];
  }
  var h1 = r.hour !== undefined, m1 = r.minute !== undefined, s1 = r.second !== undefined, f1 = r.fractionalSecondDigits !== undefined, tz = r.timeZoneName;
  tpat = null;
  if (h1 || m1 || s1 || f1) {
    var fam = (hc === 'h12' || hc === 'h11') ? 'h' : 'H', tzk = tz === undefined ? '-' : (tz === 'long' || tz === 'longOffset' || tz === 'longGeneric') ? 'Z' : 'z';
    if (!h1 && !m1 && !s1) tpat = '{f}';
    else {
      key = (h1 ? fam : '-') + (h1 ? 'h' : '-') + (m1 ? 'm' : '-') + (s1 ? 's' : '-') + (h1 ? tzk : '-');
      tpat = L.T[key];
      if (h1 && r.hour !== '2-digit' && (r.minute === '2-digit' || r.second === '2-digit') && L.T2[key] !== undefined) tpat = L.T2[key];
    }
    if (f1 && tpat !== '{f}') {
      if (/\{ss?\}/.test(tpat)) tpat = tpat.replace(/\{ss?\}/, function (x) { return x + L.N.d + '{f}'; });
    }
  }
  dm = dpat !== undefined && dpat !== null && hasDate ? __ilTokens(dpat, f, st) : [];
  tm = tpat !== undefined && tpat !== null ? __ilTokens(tpat, f, st) : [];
  if (r.timeZoneName !== undefined && !tm.length && dm.length) {
    tm = [{ type: 'timeZoneName', value: st.tzname() }];
    return dm.concat([{ type: 'literal', value: ', ' }], tm);
  }
  if (dm.length && tm.length) {
    gi = (w !== null && mo === 'long') ? 0 : mo === 'long' ? 1 : mo === 'short' ? 2 : 3;
    g = L.G[gi];
    parts = g[0] === 0 ? dm.concat([{ type: 'literal', value: g[1] }], tm) : tm.concat([{ type: 'literal', value: g[1] }], dm);
    return __ilGlueWrap(g, parts);
  }
  return dm.length ? dm : tm;
}
function __ilGlueWrap(g, parts) {
  if (g[2]) parts = [{ type: 'literal', value: g[2] }].concat(parts);
  if (g[3]) parts = parts.concat([{ type: 'literal', value: g[3] }]);
  return parts;
}
function __ilJoin(parts) {
  var s = '', i;
  for (i = 0; i < parts.length; i++) s += parts[i].value;
  return s;
}
function __ilMkDTF(loc, opts, required, defaults) {
  var res = __ilResolve(loc), L = __ilGet(res.data), r = __ilNormDate(opts, required, defaults), o = {}, k;
  L.lang = res.data;
  if (opts !== undefined && opts !== null && opts.timeZone !== undefined) o.z = __ilZoneOf(opts.timeZone); else o.z = __ilZoneOf(undefined);
  this['\x01L'] = L; this['\x01o'] = r; this['\x01z'] = o.z; this['\x01res'] = res;
  this['\x01h'] = __ilHC(L, r, res.ext);
  this['\x01req'] = required;
  for (k in this) if (k.charAt(0) === '\x01') Object.defineProperty(this, k, { enumerable: false });
}
function __ilDTFInit() {
  var DTF = function DateTimeFormat(loc, opts) {
    if (!(this instanceof DTF)) return new DTF(loc, opts);
    __ilMkDTF.call(this, loc, opts, 'any', 'date');
    var self = this;
    Object.defineProperty(this, 'format', { value: function (d) { return self.formatToParts(d).map(function (p) { return p.value; }).join('').replace(/\u202f/g, ' '); }, writable: true, configurable: true, enumerable: false });
  };
  var P = DTF.prototype;
  P.formatToParts = function (d) {
    var t = d === undefined ? __now() : (d instanceof __Date ? d.getTime() : Number(d));
    return __ilDateParts(this, t);
  };
  P.formatRange = function (a, b) {
    var x = this.format(a), y = this.format(b);
    return x === y ? x : x + ' – ' + y;
  };
  P.formatRangeToParts = function (a, b) { return this.formatToParts(a).concat([{ type: 'literal', value: ' – ', source: 'shared' }], this.formatToParts(b)); };
  P.resolvedOptions = function () {
    var r = this['\x01o'], res = this['\x01res'], z = this['\x01z'], o = { locale: res.full, calendar: 'gregory', numberingSystem: 'latn' }, k, tzid = z.local ? 'UTC' : z.id;
    o.timeZone = tzid;
    if (z.local) { o.timeZone = __ilLocalZoneId(); }
    if (r.hour !== undefined || r.timeStyle !== undefined) { o.hourCycle = this['\x01h']; o.hour12 = this['\x01h'] === 'h12' || this['\x01h'] === 'h11'; }
    for (k in r) if (k !== 'hour12' && k !== 'hourCycle' && k !== 'timeZone') o[k] = r[k];
    return o;
  };
  DTF.supportedLocalesOf = function (l) { return __ilList(l).filter(__ilSupported); };
  Object.defineProperty(P, '\x01Symbol.toStringTag\x02', { value: 'Intl.DateTimeFormat', configurable: true, enumerable: false });
  return DTF;
}
function __ilLocalZoneId() {
  var c = __tzinfo(), zt = __ilZoneTable(), k, so = -(c.bias + c.sb);
  if (so === 0 && !c.dst) return c.sn === '' || /UTC|Coordinated|GMT/i.test(c.sn) ? 'UTC' : 'Europe/London';
  var map = { 'Pacific Standard Time': 'America/Los_Angeles', 'Mountain Standard Time': 'America/Denver', 'Central Standard Time': 'America/Chicago', 'Eastern Standard Time': 'America/New_York',
    'W. Europe Standard Time': 'Europe/Berlin', 'Romance Standard Time': 'Europe/Paris', 'Central Europe Standard Time': 'Europe/Budapest', 'Central European Standard Time': 'Europe/Warsaw',
    'GMT Standard Time': 'Europe/London', 'GTB Standard Time': 'Europe/Bucharest', 'E. Europe Standard Time': 'Europe/Chisinau', 'FLE Standard Time': 'Europe/Kiev', 'Russian Standard Time': 'Europe/Moscow',
    'India Standard Time': 'Asia/Calcutta', 'China Standard Time': 'Asia/Shanghai', 'Tokyo Standard Time': 'Asia/Tokyo', 'Korea Standard Time': 'Asia/Seoul', 'AUS Eastern Standard Time': 'Australia/Sydney',
    'E. South America Standard Time': 'America/Sao_Paulo', 'SE Asia Standard Time': 'Asia/Bangkok', 'Singapore Standard Time': 'Asia/Singapore', 'Arabian Standard Time': 'Asia/Dubai',
    'Alaskan Standard Time': 'America/Anchorage', 'Hawaiian Standard Time': 'Pacific/Honolulu', 'US Mountain Standard Time': 'America/Phoenix', 'Atlantic Standard Time': 'America/Halifax',
    'Turkey Standard Time': 'Europe/Istanbul', 'Israel Standard Time': 'Asia/Jerusalem', 'South Africa Standard Time': 'Africa/Johannesburg', 'Egypt Standard Time': 'Africa/Cairo',
    'New Zealand Standard Time': 'Pacific/Auckland', 'Canada Central Standard Time': 'America/Regina', 'Mexico Standard Time': 'America/Mexico_City', 'Argentina Standard Time': 'America/Buenos_Aires' };
  if (map[c.sn]) return map[c.sn];
  for (k in zt) if (zt[k][0] === so && (c.dst ? zt[k][1] !== '' : zt[k][1] === '')) return k;
  return 'UTC';
}
// ---------- nombres ----------
function __ilDigits(x) {
  // x : nombre fini positif -> [chaine de chiffres, exposant decimal du premier chiffre]
  var s, e, m, ds, p;
  if (x === 0) return ['0', 0];
  s = x.toExponential();
  m = /^(\d)(?:\.(\d+))?e([+-]\d+)$/.exec(s);
  ds = m[1] + (m[2] || '');
  e = Number(m[3]);
  return [ds, e];
}
function __ilRoundDigits(dg, e, pos) {
  // arrondit les chiffres dg (premier chiffre a l'exposant e) a la position pos (indice dans la chaine dg ; pos<0 : zero)
  var a, i, carry;
  if (pos >= dg.length) return [dg, e];
  if (pos < 0) return ['0', 0];
  if (dg.charCodeAt(pos) >= 53) {
    a = dg.slice(0, pos).split('');
    carry = true;
    for (i = pos - 1; i >= 0 && carry; i--) {
      if (a[i] === '9') a[i] = '0'; else { a[i] = String.fromCharCode(a[i].charCodeAt(0) + 1); carry = false; }
    }
    if (carry) { a.unshift('1'); e++; }
    return [a.join(''), e];
  }
  return [dg.slice(0, pos) === '' ? '0' : dg.slice(0, pos), pos === 0 ? 0 : e];
}
// retourne { int: chaine de chiffres, frac: chaine de chiffres } apres arrondi
function __ilNumDigits(x, minF, maxF, minI, minS, maxS) {
  var d, dg, e, ip, fp, pos, r, i, nd;
  if (typeof x === 'string') { d = __ilDigitsStr(x); } else d = __ilDigits(x);
  dg = d[0]; e = d[1];
  if (maxS !== undefined) {
    if (dg.length > maxS) { r = __ilRoundDigits(dg, e, maxS); dg = r[0]; e = r[1]; }
    dg = dg.replace(/0+$/, ''); if (dg === '') dg = '0';
  } else {
    pos = e + 1 + maxF;
    if (pos < dg.length) { r = __ilRoundDigits(dg, e, pos); dg = r[0]; e = r[1]; if (pos < 0 || (pos === 0 && dg === '0')) { dg = '0'; e = 0; } }
    dg = dg.replace(/0+$/, ''); if (dg === '') { dg = '0'; e = 0; }
  }
  if (dg === '0') { ip = '0'; fp = ''; }
  else if (e >= 0) {
    ip = dg.slice(0, e + 1); while (ip.length < e + 1) ip += '0';
    fp = dg.slice(e + 1);
  } else { ip = '0'; fp = ''; for (i = 0; i < -e - 1; i++) fp += '0'; fp += dg; }
  if (minS !== undefined) {
    nd = (ip === '0' ? 0 : ip.length) + fp.length;
    if (ip === '0') { var lz = /^0*/.exec(fp)[0].length; nd = fp.length - lz; if (dg === '0') nd = 1; }
    while (nd < minS) { fp += '0'; nd++; }
  }
  while (fp.length < minF) fp += '0';
  while (ip.length < minI) ip = '0' + ip;
  return { i: ip, f: fp };
}
function __ilDigitsStr(s) {
  var m = /^(\d+)(?:\.(\d+))?$/.exec(s), ip, fp, all, e, lead;
  ip = m[1].replace(/^0+(?=\d)/, ''); fp = m[2] || '';
  all = ip + fp;
  lead = /^0*/.exec(all)[0].length;
  if (lead === all.length) return ['0', 0];
  e = ip.length - 1 - lead;
  return [all.slice(lead).replace(/0+$/, '') || '0', e];
}
function __ilGroup(L, ip, useGrouping) {
  var g = L.N.g, out = '', n = ip.length, mg = L.N.mg, i, first;
  if (useGrouping === false || useGrouping === 'false') return ip;
  if (n < 4 || (n < 3 + mg && useGrouping !== 'always')) return ip;
  if (L.N.ind) {
    var last3 = ip.slice(n - 3), rest = ip.slice(0, n - 3), parts = [];
    while (rest.length > 2) { parts.unshift(rest.slice(rest.length - 2)); rest = rest.slice(0, rest.length - 2); }
    if (rest) parts.unshift(rest);
    return parts.join(g) + g + last3;
  }
  first = n % 3;
  if (first) out = ip.slice(0, first);
  for (i = first; i < n; i += 3) out += (out === '' ? '' : g) + ip.slice(i, i + 3);
  return out;
}
function __ilNumInit() {
  var NF = function NumberFormat(loc, opts) {
    if (!(this instanceof NF)) return new NF(loc, opts);
    var res = __ilResolve(loc), L = __ilGet(res.data), o = {}, k, nm = ['style', 'currency', 'currencyDisplay', 'currencySign', 'unit', 'unitDisplay', 'notation', 'compactDisplay', 'signDisplay', 'useGrouping', 'minimumIntegerDigits',
      'minimumFractionDigits', 'maximumFractionDigits', 'minimumSignificantDigits', 'maximumSignificantDigits', 'roundingMode', 'numberingSystem'];
    if (opts !== undefined && opts !== null) for (k = 0; k < nm.length; k++) if (opts[nm[k]] !== undefined) o[nm[k]] = opts[nm[k]];
    if (o.style === undefined) o.style = 'decimal';
    if (['decimal', 'percent', 'currency', 'unit'].indexOf(o.style) < 0) throw new RangeError('Value ' + o.style + ' out of range for Intl.NumberFormat options property style');
    if (o.style === 'currency') {
      if (o.currency === undefined) throw new TypeError('Currency code is required with currency style.');
      if (!/^[A-Za-z]{3}$/.test(String(o.currency))) throw new RangeError('Invalid currency code : ' + o.currency);
      o.currency = String(o.currency).toUpperCase();
      if (o.currencyDisplay === undefined) o.currencyDisplay = 'symbol';
      if (o.currencySign === undefined) o.currencySign = 'standard';
    }
    if (o.style === 'unit') {
      if (o.unit === undefined) throw new TypeError('Unit is required with unit style.');
      if (o.unitDisplay === undefined) o.unitDisplay = 'short';
    }
    if (o.notation === undefined) o.notation = 'standard';
    if (['standard', 'scientific', 'engineering', 'compact'].indexOf(o.notation) < 0) throw new RangeError('Value ' + o.notation + ' out of range for Intl.NumberFormat options property notation');
    if (o.notation === 'compact' && o.compactDisplay === undefined) o.compactDisplay = 'short';
    if (o.signDisplay === undefined) o.signDisplay = 'auto';
    var dfd = 3, cd;
    if (o.style === 'currency') { cd = L.N.cd[o.currency]; dfd = cd === undefined ? 2 : cd; }
    if (o.style === 'percent') dfd = 0;
    var mnId = o.minimumIntegerDigits === undefined ? 1 : Number(o.minimumIntegerDigits);
    if (!(mnId >= 1 && mnId <= 21)) throw new RangeError('minimumIntegerDigits value is out of range.');
    o.minimumIntegerDigits = mnId;
    if (o.minimumSignificantDigits !== undefined || o.maximumSignificantDigits !== undefined) {
      o.minimumSignificantDigits = o.minimumSignificantDigits === undefined ? 1 : Number(o.minimumSignificantDigits);
      o.maximumSignificantDigits = o.maximumSignificantDigits === undefined ? 21 : Number(o.maximumSignificantDigits);
      if (!(o.minimumSignificantDigits >= 1 && o.minimumSignificantDigits <= 21) || !(o.maximumSignificantDigits >= o.minimumSignificantDigits
        && o.maximumSignificantDigits <= 21)) throw new RangeError('maximumSignificantDigits value is out of range.');
    } else {
      var mnF = o.minimumFractionDigits, mxF = o.maximumFractionDigits;
      if (mnF !== undefined) { mnF = Number(mnF); if (!(mnF >= 0 && mnF <= 100)) throw new RangeError('minimumFractionDigits value is out of range.'); }
      if (mxF !== undefined) { mxF = Number(mxF); if (!(mxF >= 0 && mxF <= 100)) throw new RangeError('maximumFractionDigits value is out of range.'); }
      if (mnF === undefined && mxF === undefined) {
        if (o.notation === 'compact') { mnF = 0; mxF = 0; o.cmpAuto = true; } else { mnF = o.style === 'currency' ? dfd : 0; mxF = dfd; }
      }
      else if (mnF === undefined) mnF = Math.min(o.style === 'currency' ? dfd : 0, mxF);
      else if (mxF === undefined) mxF = Math.max(dfd, mnF);
      else if (mnF > mxF) throw new RangeError('maximumFractionDigits value is out of range.');
      o.minimumFractionDigits = mnF; o.maximumFractionDigits = mxF;
    }
    this['\x01L'] = L; this['\x01o'] = o; this['\x01res'] = res;
    Object.defineProperty(this, '\x01L', { enumerable: false }); Object.defineProperty(this, '\x01o', { enumerable: false }); Object.defineProperty(this, '\x01res', { enumerable: false });
    var self = this;
    Object.defineProperty(this, 'format', { value: function (x) { return self.formatToParts(x).map(function (p) { return p.value; }).join(''); }, enumerable: false, configurable: true, writable: true });
  };
  var P = NF.prototype;
  P.formatToParts = function (x) { return __ilNumParts(this['\x01L'], this['\x01o'], x); };
  P.formatRange = function (a, b) { return this.format(a) + '–' + this.format(b); };
  P.resolvedOptions = function () {
    var o = this['\x01o'], r = { locale: this['\x01res'].full, numberingSystem: 'latn', style: o.style }, order, k, i;
    if (o.style === 'currency') { r.currency = o.currency; r.currencyDisplay = o.currencyDisplay; r.currencySign = o.currencySign; }
    if (o.style === 'unit') { r.unit = o.unit; r.unitDisplay = o.unitDisplay; }
    r.minimumIntegerDigits = o.minimumIntegerDigits;
    if (o.minimumSignificantDigits !== undefined) { r.minimumSignificantDigits = o.minimumSignificantDigits; r.maximumSignificantDigits = o.maximumSignificantDigits; }
    else if (o.cmpAuto === undefined) { r.minimumFractionDigits = o.minimumFractionDigits; r.maximumFractionDigits = o.maximumFractionDigits; }
    r.useGrouping = o.useGrouping === undefined ? (o.notation === 'compact' ? 'min2' : 'auto') : (o.useGrouping === true ? 'always' : o.useGrouping);
    r.notation = o.notation;
    if (o.notation === 'compact') r.compactDisplay = o.compactDisplay;
    r.signDisplay = o.signDisplay;
    r.roundingIncrement = 1; r.roundingMode = 'halfExpand'; r.roundingPriority = 'auto'; r.trailingZeroDisplay = 'auto';
    return r;
  };
  NF.supportedLocalesOf = function (l) { return __ilList(l).filter(__ilSupported); };
  Object.defineProperty(P, '\x01Symbol.toStringTag\x02', { value: 'Intl.NumberFormat', configurable: true, enumerable: false });
  return NF;
}

function __ilCompact(L, o, v, isBig) {
  var tab = L.N.cmp[o.compactDisplay === 'long' ? 'l' : 's'], mag, e = 0, suffix = '', scaled = v, tries, sm, dg, digitsLen, i, r, num, thr;
  for (tries = 0; tries < 2; tries++) {
    mag = isBig ? String(v).length - 1 : (v === 0 ? 0 : __ilDigits(v)[1]);
    e = 0; suffix = '';
    if (mag >= 3) {
      sm = tab[Math.min(mag, 14) - 3];
      dg = /^[0-9]+/.exec(sm);
      if (dg !== null && !/[0-9]/.test(sm.slice(dg[0].length))) {
        digitsLen = dg[0].length; e = Math.min(mag, 14) - (digitsLen - 1); suffix = sm.slice(digitsLen);
        if (o.compactDisplay === 'long') {
          var s2 = L.N.cmp['l2'][Math.min(mag, 14) - 3], d2 = /^[0-9]+/.exec(s2);
          if (d2 !== null) { suffix = [suffix, s2.slice(d2[0].length)]; }
        }
      }
    }
    scaled = e === 0 ? v : (isBig ? Number(v) / Math.pow(10, e) : v / Math.pow(10, e));
    if (!o.cmpAuto) return { scaled: scaled, suffix: suffix, e: e };
    r = typeof scaled === 'string' ? Number(scaled) : scaled;
    // arrondi : entier si >= 2 chiffres entiers, sinon 2 chiffres significatifs
    var d;
    if (r >= 10) d = __ilNumDigits(r, 0, 0, 1); else d = __ilNumDigits(r, 0, 30, 1, undefined, 2);
    num = Number(d.i + (d.f ? '.' + d.f : ''));
    if (e > 0 || mag >= 3) {
      thr = Math.pow(10, 3 + (e === 0 ? 0 : 0));
      if (num * Math.pow(10, e) >= Math.pow(10, mag + 1) && tries === 0 && mag >= 2) { v = num * Math.pow(10, e); isBig = false; continue; }
    } else if (num >= 1000 && tries === 0) { v = num; isBig = false; continue; }
    return { scaled: num, suffix: suffix, done: true, e: e };
  }
  return { scaled: scaled, suffix: suffix };
}
function __ilNumParts(L, o, x) {
  var N = L.N, neg = false, isBig = typeof x === 'bigint', v, s, nd, ip = '', fp = '', i, sign, special = null, expo = 0, suffix = '', cmp, zero, core = [], out = [], gi, pats, pt, sym, unitName, pre, suf, one, ud, sp;
  if (isBig) { s = String(x); if (s.charAt(0) === '-') { neg = true; s = s.slice(1); } v = s; }
  else {
    v = Number(x);
    if (v !== v) special = 'nan';
    else { neg = v < 0 || (v === 0 && 1 / v < 0); if (neg) v = -v; if (v === Infinity) special = 'inf'; }
  }
  if (o.style === 'percent' && special === null) {
    if (isBig) v = v + '00';
    else if (v !== 0) { var pd = __ilDigits(v); v = Number(pd[0].charAt(0) + (pd[0].length > 1 ? '.' + pd[0].slice(1) : '') + 'e' + (pd[1] + 2)); }
  }
  if (special === null) {
    var vv = v, mnF = o.minimumFractionDigits, mxF = o.maximumFractionDigits;
    if (o.notation === 'compact') {
      cmp = __ilCompact(L, o, isBig && o.style !== 'percent' ? v : (isBig ? v : v), isBig);
      vv = cmp.scaled; suffix = cmp.suffix;
      if (o.cmpAuto) { mnF = 0; mxF = 30; }
      if (typeof suffix === 'object') suffix = (Number(vv) === 1) ? suffix[0] : suffix[1];
    } else if (o.notation === 'scientific' || o.notation === 'engineering') {
      var dd = isBig ? __ilDigitsStr(v) : __ilDigits(v), ex = (v === 0 || dd[0] === '0') ? 0 : dd[1];
      if (o.notation === 'engineering') ex = Math.floor(ex / 3) * 3;
      vv = isBig ? Number(v) / Math.pow(10, ex) : v / Math.pow(10, ex);
      expo = ex;
    }
    nd = __ilNumDigits(vv, mnF === undefined ? 0 : mnF, mxF === undefined ? 0 : mxF, o.minimumIntegerDigits, o.minimumSignificantDigits, o.maximumSignificantDigits);
    if ((o.notation === 'scientific' || o.notation === 'engineering') && nd.i.length > (o.notation === 'engineering' ? 3 : 1) && nd.i.length > o.minimumIntegerDigits) {
      expo += o.notation === 'engineering' ? 3 : 1;
      vv = isBig ? Number(v) / Math.pow(10, expo) : v / Math.pow(10, expo);
      nd = __ilNumDigits(vv, mnF === undefined ? 0 : mnF, mxF === undefined ? 0 : mxF, o.minimumIntegerDigits, o.minimumSignificantDigits, o.maximumSignificantDigits);
    }
    if (o.notation === 'compact' && cmp !== undefined && cmp.e > 0 && !o.cmpAuto && nd.i.length > 3 && cmp.pass !== 1) {
      var v2 = Number(nd.i + '.' + (nd.f || '0')) * Math.pow(10, cmp.e);
      cmp = __ilCompact(L, o, v2, false); cmp.pass = 1; vv = cmp.scaled; suffix = cmp.suffix;
      if (typeof suffix === 'object') suffix = (Number(vv) === 1) ? suffix[0] : suffix[1];
      nd = __ilNumDigits(vv, mnF === undefined ? 0 : mnF, mxF === undefined ? 0 : mxF, o.minimumIntegerDigits, o.minimumSignificantDigits, o.maximumSignificantDigits);
    }
    ip = nd.i; fp = nd.f;
    zero = /^0*$/.test(ip) && /^0*$/.test(fp);
    if (o.signDisplay === 'never') sign = '';
    else if (o.signDisplay === 'always') sign = neg ? '-' : '+';
    else if (o.signDisplay === 'exceptZero') sign = zero ? '' : (neg ? '-' : '+');
    else if (o.signDisplay === 'negative') sign = neg && !zero ? '-' : '';
    else sign = neg ? '-' : '';
  } else {
    sign = neg ? '-' : '';
    if (o.signDisplay === 'always' || (o.signDisplay === 'exceptZero' && special === 'inf')) sign = neg ? '-' : '+';
    if (o.signDisplay === 'never') sign = '';
  }
  if (special === 'nan') core.push({ type: 'nan', value: N.nan });
  else if (special === 'inf') core.push({ type: 'infinity', value: N.inf });
  else {
    var ug = o.useGrouping === undefined ? (o.notation === 'compact' ? 'min2' : true) : o.useGrouping, gp, gs;
    if (ug === 'min2') gp = ip.length < 5 ? ip : __ilGroup(L, ip, true);
    else gp = __ilGroup(L, ip, ug === 'auto' ? true : ug);
    gs = N.g.length ? gp.split(N.g) : [gp];
    for (i = 0; i < gs.length; i++) { if (i) core.push({ type: 'group', value: N.g }); core.push({ type: 'integer', value: gs[i] }); }
    if (fp !== '') { core.push({ type: 'decimal', value: N.d }); core.push({ type: 'fraction', value: fp }); }
    if (o.notation === 'scientific' || o.notation === 'engineering') {
      core.push({ type: 'exponentSeparator', value: N.sci || 'E' });
      if (expo < 0) core.push({ type: 'exponentMinusSign', value: N.m });
      core.push({ type: 'exponentInteger', value: String(Math.abs(expo)) });
    }
    if (suffix !== '') {
      if (/^\s/.test(suffix)) { core.push({ type: 'literal', value: suffix.match(/^\s+/)[0] }); suffix = suffix.replace(/^\s+/, ''); }
      core.push({ type: 'compact', value: suffix });
    }
  }
  pre = ''; suf = '';
  if (o.style === 'percent') { pt = special === 'nan' || special === 'inf' ? N.ps : (sign === '-' ? N.pn : N.pp); pre = pt[0]; suf = pt[1]; }
  else if (o.style === 'currency') {
    gi = N.cp[o.currency];
    if (o.currencyDisplay === 'code') pats = N.cc; else if (o.currencySign === 'accounting') pats = N.ca;
    else if (o.currencyDisplay === 'narrowSymbol' && N.cn[o.currency] !== undefined) pats = N.cpats[N.cn[o.currency][1]];
    else pats = gi === undefined ? N.cpats[0] : N.cpats[gi];
    pt = special !== null && pats[2] !== undefined ? pats[2] : (sign === '-' ? pats[1] : pats[0]);
    pre = pt[0]; suf = pt[1];
    if (special !== null && sign === '-') pre = '{-}' + pre;
    if (o.currencyDisplay === 'name') { pre = sign === '-' ? '{-}' : ''; suf = '{n}'; }
  } else if (o.style === 'unit') {
    unitName = __ilUnits[o.unit];
    if (unitName === undefined && o.unit.indexOf('-per-') > 0) unitName = [o.unit.replace('-per-', '/'), o.unit.replace('-per-', ' per '), o.unit.replace('-per-', ' per ')];
    if (unitName === undefined) throw new RangeError("Invalid unit argument for Intl.NumberFormat() '" + o.unit + "'");
    pre = sign === '-' ? '{-}' : ''; suf = '{u}';
  } else { pre = sign === '-' ? N.dn[0] : ''; suf = sign === '-' ? N.dn[1] : ''; }
  var emit = function (str) {
    var re = /\{(-|c|n|u)\}|%/g, m, last = 0;
    while ((m = re.exec(str)) !== null) {
      if (m.index > last) out.push({ type: 'literal', value: str.slice(last, m.index) });
      last = m.index + m[0].length;
      if (m[0] === '%') out.push({ type: 'percentSign', value: '%' });
      else if (m[1] === '-') out.push({ type: 'minusSign', value: N.m });
      else if (m[1] === 'c') {
        sym = N.cs[o.currency] === undefined ? o.currency : N.cs[o.currency];
        if (o.currencyDisplay === 'code') sym = o.currency;
        else if (o.currencyDisplay === 'narrowSymbol') sym = N.cn[o.currency] !== undefined ? N.cn[o.currency][0] : sym;
        out.push({ type: 'currency', value: sym });
      } else if (m[1] === 'n') {
        out.push({ type: 'literal', value: ' ' });
        out.push({ type: 'currency', value: __ilCurName(o.currency, ip === '1' && fp === '') });
      } else if (m[1] === 'u') {
        one = ip === '1' && fp === ''; ud = o.unitDisplay;
        if (ud === 'long') { out.push({ type: 'literal', value: ' ' }); out.push({ type: 'unit', value: one ? unitName[1] : unitName[2] }); }
        else if (ud === 'narrow') out.push({ type: 'unit', value: unitName[0] });
        else { sp = /^(%|°)/.test(unitName[0]) ? '' : ' '; if (sp) out.push({ type: 'literal', value: sp }); out.push({ type: 'unit', value: unitName[0] }); }
      }
    }
    if (last < str.length) out.push({ type: 'literal', value: str.slice(last) });
  };
  if (sign === '+') out.push({ type: 'plusSign', value: N.p });
  emit(pre);
  for (i = 0; i < core.length; i++) out.push(core[i]);
  emit(suf);
  return out;
}
function __ilCurName(c, one) {
  var n = { USD: ['US dollar', 'US dollars'], EUR: ['euro', 'euros'], GBP: ['British pound', 'British pounds'], JPY: ['Japanese yen', 'Japanese yen'], CAD: ['Canadian dollar', 'Canadian dollars'],
    AUD: ['Australian dollar', 'Australian dollars'], CHF: ['Swiss franc', 'Swiss francs'], CNY: ['Chinese yuan', 'Chinese yuan'], INR: ['Indian rupee', 'Indian rupees'], MXN: ['Mexican peso', 'Mexican pesos'],
    BRL: ['Brazilian real', 'Brazilian reals'], RUB: ['Russian ruble', 'Russian rubles'], KRW: ['South Korean won', 'South Korean won'] }[c];
  return n === undefined ? c : (one ? n[0] : n[1]);
}
// ---------- pluriels ----------
function __ilFracDigits(n) {
  var s = String(Math.abs(n)), m;
  if (n === Math.floor(n)) return 0;
  m = /\.(\d+)/.exec(s);
  return m ? m[1].length : 0;
}
function __ilPlural(tag, n, ordinal, fd) {
  var lang = tag.split('-')[0], a = Math.abs(n), i = Math.floor(a), v = fd === undefined || fd === 0 ? __ilFracDigits(n) : fd, m10 = i % 10, m100 = i % 100, isInt = v === 0;
  if (ordinal) {
    if (lang === 'en') { if (isInt) { if (m10 === 1 && m100 !== 11) return 'one'; if (m10 === 2 && m100 !== 12) return 'two'; if (m10 === 3 && m100 !== 13) return 'few'; } return 'other'; }
    if (lang === 'fr') return a === 1 ? 'one' : 'other';
    if (lang === 'it') return (a === 11 || a === 8 || a === 80 || a === 800) ? 'many' : 'other';
    if (lang === 'sv') return (isInt && (m10 === 1 || m10 === 2) && m100 !== 11 && m100 !== 12) ? 'one' : 'other';
    return 'other';
  }
  switch (lang) {
    case 'ja': case 'zh': case 'ko': case 'id': return 'other';
    case 'fr': if (i === 0 || i === 1) return 'one'; if (isInt && i !== 0 && i % 1000000 === 0) return 'many'; return 'other';
    case 'pt': if (tag === 'pt-PT') return (i === 1 && isInt) ? 'one' : (isInt && i !== 0 && i % 1000000 === 0 ? 'many' : 'other'); if (i === 0 || i === 1) return 'one'; if (isInt && i % 1000000 === 0) return 'many'; return 'other';
    case 'hi': return (i === 0 || a === 1) ? 'one' : 'other';
    case 'es': if (a === 1 && isInt) return 'one'; if (isInt && i !== 0 && i % 1000000 === 0) return 'many'; return 'other';
    case 'it': if (i === 1 && isInt) return 'one'; if (isInt && i !== 0 && i % 1000000 === 0) return 'many'; return 'other';
    case 'ru': case 'uk':
      if (!isInt) return 'other';
      if (m10 === 1 && m100 !== 11) return 'one';
      if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'few';
      return 'many';
    case 'pl':
      if (!isInt) return 'other';
      if (i === 1) return 'one';
      if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'few';
      return 'many';
    case 'cs': if (!isInt) return 'many'; if (i === 1) return 'one'; if (i >= 2 && i <= 4) return 'few'; return 'other';
    case 'he': if (i === 1 && isInt) return 'one'; if (i === 2 && isInt) return 'two'; return 'other';
    case 'da': return (a === 1 || (!isInt && (i === 0 || i === 1))) ? 'one' : 'other';
    case 'tr': case 'hu': case 'el': case 'nb': return a === 1 ? 'one' : 'other';
  }
  return (i === 1 && isInt) ? 'one' : 'other';
}
function __ilPluralInit() {
  var PR = function PluralRules(loc, opts) {
    if (!(this instanceof PR)) throw new TypeError("Constructor Intl.PluralRules requires 'new'");
    var res = __ilResolve(loc);
    this['\x01lang'] = res.data; this['\x01type'] = opts && opts.type === 'ordinal' ? 'ordinal' : 'cardinal'; this['\x01res'] = res;
    this['\x01o'] = opts || {};
    Object.defineProperty(this, '\x01lang', { enumerable: false }); Object.defineProperty(this, '\x01type', { enumerable: false });
    Object.defineProperty(this, '\x01res', { enumerable: false }); Object.defineProperty(this, '\x01o', { enumerable: false });
  };
  PR.prototype.select = function (n) {
    n = Number(n);
    var o = this['\x01o'], fd = 0;
    if (o.minimumFractionDigits !== undefined) fd = Number(o.minimumFractionDigits);
    if (n !== n || Math.abs(n) === Infinity) return 'other';
    return __ilPlural(this['\x01lang'], n, this['\x01type'] === 'ordinal', fd);
  };
  PR.prototype.resolvedOptions = function () {
    var l = this['\x01lang'].split('-')[0], cats = ['other'];
    if (this['\x01type'] === 'ordinal') cats = l === 'en' ? ['few', 'one', 'two', 'other'] : ['other'];
    else if (l === 'ru' || l === 'uk' || l === 'pl') cats = ['few', 'many', 'one', 'other'];
    else if (l === 'cs') cats = ['few', 'many', 'one', 'other'];
    else if (l === 'ja' || l === 'zh' || l === 'ko' || l === 'id') cats = ['other'];
    else if (l === 'fr' || l === 'es' || l === 'it' || l === 'pt') cats = ['many', 'one', 'other'];
    else cats = ['one', 'other'];
    return { locale: this['\x01res'].full, type: this['\x01type'], minimumIntegerDigits: 1, minimumFractionDigits: 0, maximumFractionDigits: 3, pluralCategories: cats, roundingIncrement: 1, roundingMode: 'halfExpand',
      roundingPriority: 'auto', trailingZeroDisplay: 'auto' };
  };
  PR.supportedLocalesOf = function (l) { return __ilList(l).filter(__ilSupported); };
  Object.defineProperty(PR.prototype, '\x01Symbol.toStringTag\x02', { value: 'Intl.PluralRules', configurable: true, enumerable: false });
  return PR;
}
// ---------- temps relatif / listes ----------
function __ilRelInit() {
  var RT = function RelativeTimeFormat(loc, opts) {
    if (!(this instanceof RT)) throw new TypeError("Constructor Intl.RelativeTimeFormat requires 'new'");
    var res = __ilResolve(loc);
    this['\x01L'] = __ilGet(res.data); this['\x01res'] = res; this['\x01lang'] = res.data.split('-')[0];
    this['\x01style'] = opts && opts.style ? String(opts.style) : 'long'; this['\x01num'] = opts && opts.numeric ? String(opts.numeric) : 'always';
    if (['long', 'short', 'narrow'].indexOf(this['\x01style']) < 0) throw new RangeError('Value ' + this['\x01style'] + ' out of range for Intl.RelativeTimeFormat options property style');
    if (['always', 'auto'].indexOf(this['\x01num']) < 0) throw new RangeError('Value ' + this['\x01num'] + ' out of range for Intl.RelativeTimeFormat options property numeric');
    var k;
    for (k in this) if (k.charAt(0) === '\x01') Object.defineProperty(this, k, { enumerable: false });
  };
  RT.prototype.formatToParts = function (v, unit) {
    var u = String(unit).replace(/s$/, ''), n = Number(v), L = this['\x01L'], R, e, pl, key, tpl, neg, nf, ps, out = [], i, a;
    if (n !== n || Math.abs(n) === Infinity) throw new RangeError('Value need to be finite number for Intl.RelativeTimeFormat.prototype.format()');
    if (['second', 'minute', 'hour', 'day', 'week', 'month', 'quarter', 'year'].indexOf(u) < 0) throw new RangeError('Invalid unit argument for format() \'' + unit + '\'');
    R = L.R[this['\x01style'] === 'long' ? 'l' : 's'][u];
    if (this['\x01num'] === 'auto' && R.a[n === 0 ? '0' : String(n)] !== undefined && (n === 0 || n === 1 || n === -1 || n === 2 || n === -2)) {
      return [{ type: 'literal', value: R.a[n === 0 ? '0' : String(n)] }];
    }
    neg = n < 0 || (n === 0 && 1 / n < 0);
    a = Math.abs(n);
    pl = __ilPlural(this['\x01res'].data, a, false, 0);
    key = (neg ? 'p' : 'f') + pl;
    if (neg && a === 0) tpl = R.c.pz; else tpl = R.c[key];
    if (tpl === undefined) tpl = R.c[(neg ? 'p' : 'f') + 'other'];
    nf = new __Intl.NumberFormat(this['\x01res'].full);
    ps = nf.formatToParts(a);
    var idx = tpl.indexOf('{0}');
    if (idx > 0) out.push({ type: 'literal', value: tpl.slice(0, idx) });
    for (i = 0; i < ps.length; i++) out.push({ type: ps[i].type, value: ps[i].value, unit: u });
    if (idx + 3 < tpl.length) out.push({ type: 'literal', value: tpl.slice(idx + 3) });
    return out;
  };
  RT.prototype.format = function (v, unit) { return this.formatToParts(v, unit).map(function (p) { return p.value; }).join(''); };
  RT.prototype.resolvedOptions = function () { return { locale: this['\x01res'].full, style: this['\x01style'], numeric: this['\x01num'], numberingSystem: 'latn' }; };
  RT.supportedLocalesOf = function (l) { return __ilList(l).filter(__ilSupported); };
  Object.defineProperty(RT.prototype, '\x01Symbol.toStringTag\x02', { value: 'Intl.RelativeTimeFormat', configurable: true, enumerable: false });
  var LF = function ListFormat(loc, opts) {
    if (!(this instanceof LF)) throw new TypeError("Constructor Intl.ListFormat requires 'new'");
    var res = __ilResolve(loc);
    this['\x01L'] = __ilGet(res.data); this['\x01res'] = res;
    this['\x01type'] = opts && opts.type ? String(opts.type) : 'conjunction'; this['\x01style'] = opts && opts.style ? String(opts.style) : 'long';
    if (['conjunction', 'disjunction', 'unit'].indexOf(this['\x01type']) < 0) throw new RangeError('Value ' + this['\x01type'] + ' out of range for Intl.ListFormat options property type');
    var k;
    for (k in this) if (k.charAt(0) === '\x01') Object.defineProperty(this, k, { enumerable: false });
  };
  LF.prototype.formatToParts = function (list) {
    var items = Array.from(list), d = this['\x01L'].L[this['\x01type'].charAt(0) + this['\x01style'].charAt(0)], out = [], i, n = items.length;
    for (i = 0; i < n; i++) {
      if (typeof items[i] !== 'string') throw new TypeError('Iterable yielded ' + String(items[i]) + ' which is not a string');
    }
    if (n === 0) return [];
    for (i = 0; i < n; i++) {
      if (i > 0) out.push({ type: 'literal', value: n === 2 ? d[0] : i === 1 ? d[1] : i === n - 1 ? d[3] : d[2] });
      out.push({ type: 'element', value: items[i] });
    }
    return out;
  };
  LF.prototype.format = function (list) { return this.formatToParts(list).map(function (p) { return p.value; }).join(''); };
  LF.prototype.resolvedOptions = function () { return { locale: this['\x01res'].full, type: this['\x01type'], style: this['\x01style'] }; };
  LF.supportedLocalesOf = function (l) { return __ilList(l).filter(__ilSupported); };
  Object.defineProperty(LF.prototype, '\x01Symbol.toStringTag\x02', { value: 'Intl.ListFormat', configurable: true, enumerable: false });
  return [RT, LF];
}
// ---------- collation ----------

function __ilKey(lang, s, level, num) {
  var t = __ilTail[lang], out = '', i, c, lc, k, pos;
  if (!t && !num) return null;
  return null;
}
function __ilCollInit() {
  var CO = function Collator(loc, opts) {
    if (!(this instanceof CO)) return new CO(loc, opts);
    var res = __ilResolve(loc), o = opts || {}, self = this;
    this['\x01res'] = res; this['\x01lang'] = res.data.split('-')[0];
    this['\x01sens'] = o.sensitivity || 'variant'; this['\x01num'] = o.numeric === true || res.ext.kn === 'true' || res.ext.kn === '' ; this['\x01cf'] = o.caseFirst || res.ext.kf || 'false';
    this['\x01ip'] = o.ignorePunctuation === true; this['\x01usage'] = o.usage || 'sort';
    if (['base', 'accent', 'case', 'variant'].indexOf(this['\x01sens']) < 0) throw new RangeError('Value ' + this['\x01sens'] + ' out of range for Intl.Collator options property sensitivity');
    var k;
    for (k in this) if (k.charAt(0) === '\x01') Object.defineProperty(this, k, { enumerable: false });
    Object.defineProperty(this, 'compare', { value: function (a, b) { return __ilCompare(self, String(a), String(b)); }, enumerable: false, configurable: true, writable: true });
  };
  CO.prototype.resolvedOptions = function () {
    return { locale: this['\x01res'].full, usage: this['\x01usage'], sensitivity: this['\x01sens'], ignorePunctuation: this['\x01ip'], collation: 'default', numeric: this['\x01num'], caseFirst: this['\x01cf'] };
  };
  CO.supportedLocalesOf = function (l) { return __ilList(l).filter(__ilSupported); };
  Object.defineProperty(CO.prototype, '\x01Symbol.toStringTag\x02', { value: 'Intl.Collator', configurable: true, enumerable: false });
  return CO;
}
function __ilKey0(lang, s) {
  var tl = __ilTail[lang], out = '', i, ch, j, row, found;
  if (!tl) return __coll(s, 0);
  for (i = 0; i < s.length; i++) {
    ch = s.charAt(i).toLowerCase();
    found = false;
    for (j = 0; j < tl.length; j++) {
      row = tl[j];
      if (row[1].indexOf(ch) >= 0) { out += '5' + row[0] + '￿' + String.fromCharCode(48 + row[1].indexOf(ch)); found = true; break; }
    }
    if (!found) out += __coll(s.charAt(i), 0);
  }
  return out;
}
function __ilCompare(c, a, b) {
  var lang = c['\x01lang'], sens = c['\x01sens'], i, x, y, r, ta, tb;
  if (c['\x01ip']) { a = a.replace(/[\s!-/:-@[-`{-~]/g, ''); b = b.replace(/[\s!-/:-@[-`{-~]/g, ''); }
  if (c['\x01num']) {
    ta = a.match(/\d+|\D+/g) || []; tb = b.match(/\d+|\D+/g) || [];
    for (i = 0; i < ta.length && i < tb.length; i++) {
      x = ta[i]; y = tb[i];
      if (/^\d/.test(x) && /^\d/.test(y)) {
        x = x.replace(/^0+(?=\d)/, ''); y = y.replace(/^0+(?=\d)/, '');
        if (x.length !== y.length) return x.length < y.length ? -1 : 1;
        if (x !== y) return x < y ? -1 : 1;
      } else {
        r = __ilCompareText(c, x, y, lang, sens);
        if (r !== 0) return r;
      }
    }
    if (ta.length !== tb.length) return ta.length < tb.length ? -1 : 1;
    return 0;
  }
  return __ilCompareText(c, a, b, lang, sens);
}
function __ilCompareText(c, a, b, lang, sens) {
  var x = __ilKey0(lang, a), y = __ilKey0(lang, b), cf = c['\x01cf'];
  if (x !== y) return x < y ? -1 : 1;
  if (sens === 'accent' || sens === 'variant') {
    x = __coll(a, 1); y = __coll(b, 1);
    if (x !== y) return x < y ? -1 : 1;
  }
  if (sens === 'case' || sens === 'variant') {
    x = __coll(a, 2); y = __coll(b, 2);
    if (x !== y) return cf === 'upper' ? (x < y ? 1 : -1) : (x < y ? -1 : 1);
  }
  return 0;
}
// ---------- Intl.Locale, Segmenter, DisplayNames ----------
function __ilMiscInit() {
  var LC = function Locale(tag, opts) {
    if (!(this instanceof LC)) throw new TypeError("Constructor Intl.Locale requires 'new'");
    var c = __ilCanon(typeof tag === 'string' ? tag : String(tag)), p = c.split('-u-')[0].split('-'), i, ext = c.indexOf('-u-') >= 0 ? c.slice(c.indexOf('-u-')) : '';
    this['\x01c'] = c; this.language = p[0]; this.script = undefined; this.region = undefined;
    for (i = 1; i < p.length; i++) { if (p[i].length === 4) this.script = p[i]; else if (p[i].length === 2 || /^\d{3}$/.test(p[i])) this.region = p[i]; }
    if (opts) { if (opts.region) this.region = opts.region; if (opts.language) this.language = opts.language; if (opts.script) this.script = opts.script; }
    this.baseName = this.language + (this.script ? '-' + this.script : '') + (this.region ? '-' + this.region : '');
    this['\x01ext'] = ext;
    var ex = /-u-(.*)$/.exec(c), kv, j;
    if (ex) { kv = ex[1].split('-'); for (j = 0; j + 1 < kv.length; j += 2) { if (kv[j] === 'ca') this.calendar = kv[j + 1]; if (kv[j] === 'nu') this.numberingSystem = kv[j + 1]; if (kv[j] === 'hc') this.hourCycle = kv[j + 1];
      if (kv[j] === 'co') this.collation = kv[j + 1]; if (kv[j] === 'kn') this.numeric = kv[j + 1] !== 'false'; if (kv[j] === 'kf') this.caseFirst = kv[j + 1]; }}
    Object.defineProperty(this, '\x01c', { enumerable: false }); Object.defineProperty(this, '\x01ext', { enumerable: false });
  };
  LC.prototype.toString = function () { return this.baseName + this['\x01ext']; };
  LC.prototype.maximize = function () {
    var def = { en: 'en-Latn-US', fr: 'fr-Latn-FR', de: 'de-Latn-DE', es: 'es-Latn-ES', it: 'it-Latn-IT', pt: 'pt-Latn-BR', ja: 'ja-Jpan-JP', zh: 'zh-Hans-CN', ko: 'ko-Kore-KR', ru: 'ru-Cyrl-RU', nl: 'nl-Latn-NL', sv: 'sv-Latn-SE',
      pl: 'pl-Latn-PL', tr: 'tr-Latn-TR' };
    return new LC(this.region || this.script ? (def[this.language] && !this.region ? def[this.language] : this.baseName) : (def[this.language] || this.baseName));
  };
  LC.prototype.minimize = function () { return new LC(this.language); };
  var SG = function Segmenter(loc, opts) {
    if (!(this instanceof SG)) throw new TypeError("Constructor Intl.Segmenter requires 'new'");
    this['\x01g'] = opts && opts.granularity ? opts.granularity : 'grapheme'; this['\x01res'] = __ilResolve(loc);
    Object.defineProperty(this, '\x01g', { enumerable: false }); Object.defineProperty(this, '\x01res', { enumerable: false });
  };
  SG.prototype.segment = function (str) {
    str = String(str);
    var g = this['\x01g'], segs = [], re, m, idx = 0, isW;
    if (g === 'grapheme') re = /(?:\r\n|[\ud800-\udbff][\udc00-\udfff]|[^\ud800-\udfff])(?:[̀-ͯ‍️]|\ud83c[\udffb-\udfff])*(?:‍(?:[\ud800-\udbff][\udc00-\udfff]|[^\ud800-\udfff])(?:[̀-ͯ️])*)*/g;
    else if (g === 'word') re = /[A-Za-z0-9_À-ɏЀ-ӿ']+(?:[.,][0-9]+)*|\s+|[^\sA-Za-z0-9_À-ɏЀ-ӿ]/g;
    else re = /[^.!?]*[.!?]+\s*|[^.!?]+$/g;
    while ((m = re.exec(str)) !== null) {
      if (m[0] === '') { re.lastIndex++; continue; }
      isW = g === 'word' ? /[A-Za-z0-9À-ɏЀ-ӿ]/.test(m[0]) : undefined;
      segs.push(g === 'word' ? { segment: m[0], index: m.index, input: str, isWordLike: isW } : { segment: m[0], index: m.index, input: str });
    }
    var res = {
      containing: function (i) { var j; i = i === undefined ? 0 : i; for (j = 0; j < segs.length; j++) if (i >= segs[j].index && i < segs[j].index + segs[j].segment.length) return segs[j]; return undefined; }
    };
    res[Symbol.iterator] = function () { var k = 0; return { next: function () { return k < segs.length ? { value: segs[k++], done: false } : { value: undefined, done: true }; }, [Symbol.iterator]: function () { return this; } }; };
    return res;
  };
  SG.prototype.resolvedOptions = function () { return { locale: this['\x01res'].full, granularity: this['\x01g'] }; };
  SG.supportedLocalesOf = function (l) { return __ilList(l).filter(__ilSupported); };
  var DN = function DisplayNames(loc, opts) {
    if (!(this instanceof DN)) throw new TypeError("Constructor Intl.DisplayNames requires 'new'");
    if (!opts || opts.type === undefined) throw new TypeError('Required option "type" is missing');
    this['\x01t'] = opts.type; this['\x01res'] = __ilResolve(loc); this['\x01fb'] = opts.fallback || 'code';
    Object.defineProperty(this, '\x01t', { enumerable: false }); Object.defineProperty(this, '\x01res', { enumerable: false }); Object.defineProperty(this, '\x01fb', { enumerable: false });
  };
  DN.prototype.of = function (code) {
    var en = { region: { US: 'United States', GB: 'United Kingdom', FR: 'France', DE: 'Germany', ES: 'Spain', IT: 'Italy', JP: 'Japan', CN: 'China', CA: 'Canada', BR: 'Brazil', IN: 'India', RU: 'Russia', MX: 'Mexico', AU: 'Australia',
      KR: 'South Korea', CH: 'Switzerland', NL: 'Netherlands', SE: 'Sweden', PT: 'Portugal' },
      language: { en: 'English', fr: 'French', de: 'German', es: 'Spanish', it: 'Italian', ja: 'Japanese', zh: 'Chinese', ko: 'Korean', ru: 'Russian', pt: 'Portuguese', nl: 'Dutch', sv: 'Swedish', 'en-US': 'American English',
        'en-GB': 'British English', 'fr-CA': 'Canadian French' },
      currency: { USD: 'US Dollar', EUR: 'Euro', GBP: 'British Pound', JPY: 'Japanese Yen', CNY: 'Chinese Yuan', CAD: 'Canadian Dollar', AUD: 'Australian Dollar', CHF: 'Swiss Franc', INR: 'Indian Rupee', BRL: 'Brazilian Real' } }[this['\x01t']];
    code = String(code);
    if (en && en[code]) return en[code];
    return this['\x01fb'] === 'none' ? undefined : code;
  };
  DN.prototype.resolvedOptions = function () { return { locale: this['\x01res'].full, style: 'long', type: this['\x01t'], fallback: this['\x01fb'] }; };
  return [LC, SG, DN];
}
var __ilUsNames, __ilUnits, __ilTail;
function __ilTables() {
  __ilUsNames = { 'America/New_York': ['EST', 'EDT', 'Eastern Standard Time', 'Eastern Daylight Time'], 'America/Chicago': ['CST', 'CDT', 'Central Standard Time', 'Central Daylight Time'],
  'America/Denver': ['MST', 'MDT', 'Mountain Standard Time', 'Mountain Daylight Time'], 'America/Los_Angeles': ['PST', 'PDT', 'Pacific Standard Time', 'Pacific Daylight Time'],
  'America/Anchorage': ['AKST', 'AKDT', 'Alaska Standard Time', 'Alaska Daylight Time'], 'Pacific/Honolulu': ['HST', 'HST', 'Hawaii-Aleutian Standard Time', 'Hawaii-Aleutian Standard Time'],
  'America/Phoenix': ['MST', 'MST', 'Mountain Standard Time', 'Mountain Standard Time'], 'America/Toronto': ['EST', 'EDT', 'Eastern Standard Time', 'Eastern Daylight Time'] };
  __ilUnits = {
  kilometer: ['km', 'kilometer', 'kilometers'], meter: ['m', 'meter', 'meters'], centimeter: ['cm', 'centimeter', 'centimeters'], millimeter: ['mm', 'millimeter', 'millimeters'], mile: ['mi', 'mile', 'miles'],
  foot: ['ft', 'foot', 'feet'], inch: ['in', 'inch', 'inches'], yard: ['yd', 'yard', 'yards'], kilogram: ['kg', 'kilogram', 'kilograms'], gram: ['g', 'gram', 'grams'], pound: ['lb', 'pound', 'pounds'], ounce: ['oz', 'ounce', 'ounces'],
  liter: ['L', 'liter', 'liters'], milliliter: ['mL', 'milliliter', 'milliliters'], gallon: ['gal', 'gallon', 'gallons'], celsius: ['°C', 'degree Celsius', 'degrees Celsius'], fahrenheit: ['°F', 'degree Fahrenheit', 'degrees Fahrenheit'],
  percent: ['%', 'percent', 'percent'], second: ['sec', 'second', 'seconds'], minute: ['min', 'minute', 'minutes'], hour: ['hr', 'hour', 'hours'], day: ['day', 'day', 'days'], week: ['wk', 'week', 'weeks'],
  month: ['mth', 'month', 'months'], year: ['yr', 'year', 'years'], millisecond: ['ms', 'millisecond', 'milliseconds'], byte: ['byte', 'byte', 'bytes'], kilobyte: ['kB', 'kilobyte', 'kilobytes'],
  megabyte: ['MB', 'megabyte', 'megabytes'], gigabyte: ['GB', 'gigabyte', 'gigabytes'], terabyte: ['TB', 'terabyte', 'terabytes'], bit: ['bit', 'bit', 'bits'], degree: ['deg', 'degree', 'degrees'],
  'kilometer-per-hour': ['km/h', 'kilometer per hour', 'kilometers per hour'], 'mile-per-hour': ['mph', 'mile per hour', 'miles per hour'], 'meter-per-second': ['m/s', 'meter per second', 'meters per second'],
  acre: ['ac', 'acre', 'acres'], hectare: ['ha', 'hectare', 'hectares']
};
  __ilTail = {
    es: [['n', '\u00f1']], sv: [['z', '\u00e5\u00e4\u00f6']], fi: [['z', '\u00e5\u00e4\u00f6']], da: [['z', '\u00e6\u00f8\u00e5']], nb: [['z', '\u00e6\u00f8\u00e5']],
    tr: [['c', '\u00e7'], ['g', '\u011f'], ['h', '\u0131'], ['o', '\u00f6'], ['s', '\u015f'], ['u', '\u00fc']],
    pl: [['a', '\u0105'], ['c', '\u0107'], ['e', '\u0119'], ['l', '\u0142'], ['n', '\u0144'], ['o', '\u00f3'], ['s', '\u015b'], ['z', '\u017a\u017c']],
    cs: [['c', '\u010d'], ['r', '\u0159'], ['s', '\u0161'], ['z', '\u017e']], hu: [['o', '\u00f6\u0151'], ['u', '\u00fc\u0171']]
  };
}
function __ilBuild() {
  var I = {}, DTF = __ilDTFInit(), NF = __ilNumInit(), PR = __ilPluralInit(), rl = __ilRelInit(), CO = __ilCollInit(), ms = __ilMiscInit();
  I.DateTimeFormat = DTF; I.NumberFormat = NF; I.PluralRules = PR; I.RelativeTimeFormat = rl[0]; I.ListFormat = rl[1]; I.Collator = CO;
  I.Locale = ms[0]; I.Segmenter = ms[1]; I.DisplayNames = ms[2];
  I.getCanonicalLocales = function (l) { return __ilList(l); };
  I.supportedValuesOf = function (k) {
    var z = __ilZoneTable(), r = [], q;
    if (k === 'timeZone') { for (q in z) r.push(q); return r.sort(); }
    if (k === 'calendar') return ['gregory'];
    if (k === 'numberingSystem') return ['latn'];
    if (k === 'currency') return ['AUD', 'BRL', 'CAD', 'CHF', 'CNY', 'EUR', 'GBP', 'INR', 'JPY', 'KRW', 'MXN', 'RUB', 'USD'];
    if (k === 'unit') return Object.keys(__ilUnits).sort();
    throw new RangeError('Invalid key : ' + k);
  };
  Object.defineProperty(I, '\x01Symbol.toStringTag\x02', { value: 'Intl', configurable: true, enumerable: false });
  return I;
}
function __intlDate(t, loc, o, kind) {
  var req = kind === 1 ? 'date' : kind === 2 ? 'time' : 'any', def = kind === 1 ? 'date' : kind === 2 ? 'time' : 'all', f;
  if (__Intl === undefined) return null;
  f = {};
  __ilMkDTF.call(f, loc, o, req, def);
  return __ilJoin(__ilDateParts(f, t)).replace(/\u202f/g, ' ');
}
function __ilNumLocale(x, loc, o) {
  var nf = new __Intl.NumberFormat(loc, o);
  return nf.format(x);
}
function __init_intl() {
  __ilTables();
  __ilreg('en-US', __ilEnUS());
  __init_il_cs();
  __init_il_da();
  __init_il_de();
  __init_il_el();
  __init_il_en();
  __init_il_es();
  __init_il_fi();
  __init_il_fr();
  __init_il_he();
  __init_il_hi();
  __init_il_hu();
  __init_il_id();
  __init_il_it();
  __init_il_ja();
  __init_il_ko();
  __init_il_nb();
  __init_il_nl();
  __init_il_pl();
  __init_il_pt();
  __init_il_ru();
  __init_il_sv();
  __init_il_tr();
  __init_il_uk();
  __init_il_zh();
  __Intl = __ilBuild();
  var NP = Number.prototype, SP = String.prototype, AP = Array.prototype, ol = SP.localeCompare, oup = SP.toUpperCase, olo = SP.toLowerCase;
  __ilDef = __Intl;
  NP.toLocaleString = function (loc, o) { return __ilNumLocale(Number(this), loc, o); };
  if (typeof BigInt !== 'undefined') BigInt.prototype.toLocaleString = function (loc, o) { return __ilNumLocale(this, loc, o); };
  SP.localeCompare = function (that, loc, o) {
    if (loc === undefined && o === undefined) return ol.call(this, that);
    return new __Intl.Collator(loc, o).compare(String(this), String(that));
  };
  SP.toLocaleUpperCase = function (loc) {
    var l = loc === undefined ? '' : String(Array.isArray(loc) ? loc[0] : loc).toLowerCase().split('-')[0], s = String(this);
    if (l === 'tr' || l === 'az') s = s.replace(/i/g, 'İ').replace(/ı/g, 'I');
    return oup.call(s);
  };
  SP.toLocaleLowerCase = function (loc) {
    var l = loc === undefined ? '' : String(Array.isArray(loc) ? loc[0] : loc).toLowerCase().split('-')[0], s = String(this);
    if (l === 'tr' || l === 'az') s = s.replace(/I/g, 'ı').replace(/İ/g, 'i');
    return olo.call(s);
  };
  AP.toLocaleString = function (loc, o) {
    var r = [], i, v;
    for (i = 0; i < this.length; i++) { v = this[i]; r.push(v === undefined || v === null ? '' : v.toLocaleString(loc, o)); }
    return r.join(',');
  };
  __global.Intl = __Intl;
  Object.defineProperty(__global, 'Intl', { enumerable: false });
}
function __ilEnUS() {
  return [
    "{\"D\":{\"---d\":\"{d}\",\"--y-\":\"{y}\",\"--yd\":\"{y} (day: {d})\",\"-#--\":\"{M}\",\"-#-d\":\"{M}/{d}\",\"-#y-\":\"{M}/{y}\",\"-#yd\":\"{M}/{d}/{y}\",\"-s--\":\"{M#0}\",\"-s-d\":\"{M#0} {d}\",\"-sy-\":\"{M#0} {y}\",\"-s",
    "yd\":\"{M#0} {d}, {y}\",\"-l--\":\"{M#1}\",\"-l-d\":\"{M#1} {d}\",\"-ly-\":\"{M#1} {y}\",\"-lyd\":\"{M#1} {d}, {y}\",\"-r--\":\"{M#2}\",\"-r-d\":\"{M#2} {d}\",\"-ry-\":\"{M#2} {y}\",\"-ryd\":\"{M#2} {d}, {y}\",\"s---\":\"{E",
    "#3}\",\"s--d\":\"{d} {E#3}\",\"s-y-\":\"{y} {E#3}\",\"s-yd\":\"{d} {E#3} {y}\",\"s#--\":\"{M} {E#3}\",\"s#-d\":\"{E#3}, {M}/{d}\",\"s#y-\":\"{M}/{y} {E#3}\",\"s#yd\":\"{E#3}, {M}/{d}/{y}\",\"ss--\":\"{M#0} {E#3}\",\"ss-d\":",
    "\"{E#3}, {M#0} {d}\",\"ssy-\":\"{M#0} {y} {E#3}\",\"ssyd\":\"{E#3}, {M#0} {d}, {y}\",\"sl--\":\"{E#3} (month: {M#1})\",\"sl-d\":\"{E#3}, {M#1} {d}\",\"sly-\":\"{M#1} {y} {E#3}\",\"slyd\":\"{E#3}, {M#1} {d}, {y}\",\"sr--\":",
    "\"{E#3} (month: {M#2})\",\"sr-d\":\"{E#3}, {M#2} {d}\",\"sry-\":\"{M#2} {y} {E#3}\",\"sryd\":\"{E#3}, {M#2} {d}, {y}\",\"l---\":\"{E#4}\",\"l--d\":\"{d} {E#4}\",\"l-y-\":\"{y} {E#4}\",\"l-yd\":\"{d} {E#4} {y}\",\"l#--\":\"{",
    "M} {E#4}\",\"l#-d\":\"{E#4}, {M}/{d}\",\"l#y-\":\"{M}/{y} {E#4}\",\"l#yd\":\"{E#4}, {M}/{d}/{y}\",\"ls--\":\"{M#0} {E#4}\",\"ls-d\":\"{E#4}, {M#0} {d}\",\"lsy-\":\"{M#0} {y} {E#4}\",\"lsyd\":\"{E#4}, {M#0} {d}, {y}\",\"ll--",
    "\":\"{M#1} {E#4}\",\"ll-d\":\"{E#4}, {M#1} {d}\",\"lly-\":\"{M#1} {y} {E#4}\",\"llyd\":\"{E#4}, {M#1} {d}, {y}\",\"lr--\":\"{E#4} (month: {M#2})\",\"lr-d\":\"{E#4}, {M#2} {d}\",\"lry-\":\"{M#2} {y} {E#4}\",\"lryd\":\"{E#4},",
    " {M#2} {d}, {y}\",\"r---\":\"{E#5}\",\"r--d\":\"{d} {E#5}\",\"r-y-\":\"{y} {E#5}\",\"r-yd\":\"{d} {E#5} {y}\",\"r#--\":\"{M} {E#5}\",\"r#-d\":\"{E#5}, {M}/{d}\",\"r#y-\":\"{M}/{y} {E#5}\",\"r#yd\":\"{E#5}, {M}/{d}/{y}\",\"r",
    "s--\":\"{M#0} {E#5}\",\"rs-d\":\"{E#5}, {M#0} {d}\",\"rsy-\":\"{M#0} {y} {E#5}\",\"rsyd\":\"{E#5}, {M#0} {d}, {y}\",\"rl--\":\"{M#1} {E#5}\",\"rl-d\":\"{E#5}, {M#1} {d}\",\"rly-\":\"{M#1} {y} {E#5}\",\"rlyd\":\"{E#5}, {M#1}",
    " {d}, {y}\",\"rr--\":\"{M#2} {E#5}\",\"rr-d\":\"{E#5}, {M#2} {d}\",\"rry-\":\"{M#2} {y} {E#5}\",\"rryd\":\"{E#5}, {M#2} {d}, {y}\"},\"T\":{\"hh---\":\"{h}\\u202f{a#6}\",\"hh--z\":\"{h}\\u202f{a#6} {z}\",\"hh--Z\":\"{h}",
    "\\u202f{a#6} {zz}\",\"hh-s-\":\"{h}\\u202f{a#6} (second: {s})\",\"hh-sz\":\"{h}\\u202f{a#6} (second: {s})\",\"hh-sZ\":\"{h}\\u202f{a#6} (second: {s})\",\"hhm--\":\"{h}:{mm}\\u202f{a#6}\",\"hhm-z\":\"{h}:{mm}\\u202f{a#6} {z}",
    "\",\"hhm-Z\":\"{h}:{mm}\\u202f{a#6} {zz}\",\"hhms-\":\"{h}:{mm}:{ss}\\u202f{a#6}\",\"hhmsz\":\"{h}:{mm}:{ss}\\u202f{a#6} {z}\",\"hhmsZ\":\"{h}:{mm}:{ss}\\u202f{a#6} {zz}\",\"---s-\":\"{s}\",\"--m--\":\"{m}\",\"--ms-\":\"{mm",
    "}:{ss}\",\"Hh---\":\"{HH}\",\"Hh--z\":\"{HH} {z}\",\"Hh--Z\":\"{HH} {zz}\",\"Hh-s-\":\"{HH} (second: {s})\",\"Hh-sz\":\"{HH} (second: {s})\",\"Hh-sZ\":\"{HH} (second: {s})\",\"Hhm--\":\"{HH}:{mm}\",\"Hhm-z\":\"{HH}:{mm} {z}",
    "\",\"Hhm-Z\":\"{HH}:{mm} {zz}\",\"Hhms-\":\"{HH}:{mm}:{ss}\",\"Hhmsz\":\"{HH}:{mm}:{ss} {z}\",\"HhmsZ\":\"{HH}:{mm}:{ss} {zz}\"},\"S\":{\"df\":\"{E#4}, {M#1} {d}, {y}\",\"tf\":\"{h}:{mm}:{ss}\\u202f{a#6} {z}\",\"uf\":\"{HH}",
    ":{mm}:{ss} {z}\",\"dl\":\"{M#1} {d}, {y}\",\"tl\":\"{h}:{mm}:{ss}\\u202f{a#6} {z}\",\"ul\":\"{HH}:{mm}:{ss} {z}\",\"dm\":\"{M#0} {d}, {y}\",\"tm\":\"{h}:{mm}:{ss}\\u202f{a#6}\",\"um\":\"{HH}:{mm}:{ss}\",\"ds\":\"{M}/{d}/{yy",
    "}\",\"ts\":\"{h}:{mm}\\u202f{a#6}\",\"us\":\"{HH}:{mm}\"},\"G\":[[0,\" at \",\"\",\"\"],[0,\" at \",\"\",\"\"],[0,\", \",\"\",\"\"],[0,\", \",\"\",\"\"]],\"N\":{\"d\":\".\",\"g\":\",\",\"mg\":1,\"ind\":false,\"m\":\"-\",\"p",
    "\":\"+\",\"nan\":\"NaN\",\"inf\":\"\\u221e\",\"dn\":[\"{-}\",\"\"],\"pp\":[\"\",\"%\"],\"pn\":[\"{-}\",\"%\"],\"ps\":[\"\",\"%\"],\"cp\":{\"USD\":0,\"EUR\":0,\"GBP\":0,\"JPY\":0,\"CNY\":0,\"KRW\":0,\"INR\":0,\"BRL\":0,\"CAD",
    "\":0,\"AUD\":0,\"CHF\":1,\"MXN\":0,\"RUB\":1,\"SEK\":1,\"NOK\":1,\"DKK\":1,\"PLN\":1,\"TRY\":1,\"ZAR\":1,\"HKD\":0,\"SGD\":1,\"NZD\":0,\"ILS\":0,\"CZK\":1,\"HUF\":1,\"UAH\":1,\"THB\":1,\"IDR\":1,\"TWD\":0,\"PHP\":0,\"EGP\":",
    "1,\"SAR\":1,\"AED\":1,\"ARS\":1,\"CLP\":1,\"COP\":1,\"VND\":0,\"BTC\":1},\"cs\":{\"USD\":\"$\",\"EUR\":\"\\u20ac\",\"GBP\":\"\\u00a3\",\"JPY\":\"\\u00a5\",\"CNY\":\"CN\\u00a5\",\"KRW\":\"\\u20a9\",\"INR\":\"\\u20b9\",\"BRL",
    "\":\"R$\",\"CAD\":\"CA$\",\"AUD\":\"A$\",\"CHF\":\"CHF\",\"MXN\":\"MX$\",\"RUB\":\"RUB\",\"SEK\":\"SEK\",\"NOK\":\"NOK\",\"DKK\":\"DKK\",\"PLN\":\"PLN\",\"TRY\":\"TRY\",\"ZAR\":\"ZAR\",\"HKD\":\"HK$\",\"SGD\":\"SGD\",\"NZD",
    "\":\"NZ$\",\"ILS\":\"\\u20aa\",\"CZK\":\"CZK\",\"HUF\":\"HUF\",\"UAH\":\"UAH\",\"THB\":\"THB\",\"IDR\":\"IDR\",\"TWD\":\"NT$\",\"PHP\":\"\\u20b1\",\"EGP\":\"EGP\",\"SAR\":\"SAR\",\"AED\":\"AED\",\"ARS\":\"ARS\",\"CLP\":\"CL",
    "P\",\"COP\":\"COP\",\"VND\":\"\\u20ab\",\"BTC\":\"BTC\"},\"cd\":{\"USD\":2,\"EUR\":2,\"GBP\":2,\"JPY\":0,\"CNY\":2,\"KRW\":0,\"INR\":2,\"BRL\":2,\"CAD\":2,\"AUD\":2,\"CHF\":2,\"MXN\":2,\"RUB\":2,\"SEK\":2,\"NOK\":2,\"DKK\":",
    "2,\"PLN\":2,\"TRY\":2,\"ZAR\":2,\"HKD\":2,\"SGD\":2,\"NZD\":2,\"ILS\":2,\"CZK\":2,\"HUF\":2,\"UAH\":2,\"THB\":2,\"IDR\":2,\"TWD\":2,\"PHP\":2,\"EGP\":2,\"SAR\":2,\"AED\":2,\"ARS\":2,\"CLP\":0,\"COP\":2,\"VND\":0,\"BTC\":2},",
    "\"cn\":{\"CNY\":[\"\\u00a5\",0],\"CAD\":[\"$\",0],\"AUD\":[\"$\",0],\"MXN\":[\"$\",0],\"RUB\":[\"\\u20bd\",0],\"SEK\":[\"kr\",1],\"NOK\":[\"kr\",1],\"DKK\":[\"kr\",1],\"PLN\":[\"z\\u0142\",1],\"TRY\":[\"\\u20ba\",0],\"ZAR\"",
    ":[\"R\",1],\"HKD\":[\"$\",0],\"SGD\":[\"$\",0],\"NZD\":[\"$\",0],\"CZK\":[\"K\\u010d\",1],\"HUF\":[\"Ft\",1],\"UAH\":[\"\\u20b4\",0],\"THB\":[\"\\u0e3f\",0],\"IDR\":[\"Rp\",1],\"TWD\":[\"$\",0],\"EGP\":[\"E\\u00a3\",0],\"AR",
    "S\":[\"$\",0],\"CLP\":[\"$\",0],\"COP\":[\"$\",0]},\"cpats\":[[[\"{c}\",\"\"],[\"{-}{c}\",\"\"],[\"{c}\",\"\"]],[[\"{c}\\u00a0\",\"\"],[\"{-}{c}\\u00a0\",\"\"],[\"{c}\",\"\"]]],\"cc\":[[\"{c}\\u00a0\",\"\"],[\"{-}{c}\\u00a0",
    "\",\"\"],[\"{c}\",\"\"]],\"ca\":[[\"{c}\",\"\"],[\"({c}\",\")\"],[\"{c}\",\"\"]],\"sci\":\"E\",\"cmp\":{\"s\":[\"1K\",\"10K\",\"100K\",\"1M\",\"10M\",\"100M\",\"1B\",\"10B\",\"100B\",\"1T\",\"10T\",\"100T\",\"1000T\"],\"s2",
    "\":[\"2K\",\"20K\",\"200K\",\"2M\",\"20M\",\"200M\",\"2B\",\"20B\",\"200B\",\"2T\",\"20T\",\"200T\",\"2000T\"],\"l\":[\"1 thousand\",\"10 thousand\",\"100 thousand\",\"1 million\",\"10 million\",\"100 million\",\"1 billion",
    "\",\"10 billion\",\"100 billion\",\"1 trillion\",\"10 trillion\",\"100 trillion\",\"1000 trillion\"],\"l2\":[\"2 thousand\",\"20 thousand\",\"200 thousand\",\"2 million\",\"20 million\",\"200 million\",\"2 billion\",\"20 bi",
    "llion\",\"200 billion\",\"2 trillion\",\"20 trillion\",\"200 trillion\",\"2000 trillion\"]}},\"R\":{\"l\":{\"second\":{\"c\":{\"fother\":\"in {0} seconds\",\"fone\":\"in {0} second\",\"pz\":\"{0} seconds ago\",\"pone\":\"{0",
    "} second ago\",\"pother\":\"{0} seconds ago\"},\"a\":{\"0\":\"now\"}},\"minute\":{\"c\":{\"fother\":\"in {0} minutes\",\"fone\":\"in {0} minute\",\"pz\":\"{0} minutes ago\",\"pone\":\"{0} minute ago\",\"pother\":\"{0} minut",
    "es ago\"},\"a\":{\"0\":\"this minute\"}},\"hour\":{\"c\":{\"fother\":\"in {0} hours\",\"fone\":\"in {0} hour\",\"pz\":\"{0} hours ago\",\"pone\":\"{0} hour ago\",\"pother\":\"{0} hours ago\"},\"a\":{\"0\":\"this hour\"}},\"",
    "day\":{\"c\":{\"fother\":\"in {0} days\",\"fone\":\"in {0} day\",\"pz\":\"{0} days ago\",\"pone\":\"{0} day ago\",\"pother\":\"{0} days ago\"},\"a\":{\"0\":\"today\",\"1\":\"tomorrow\",\"-1\":\"yesterday\"}},\"week\":{\"c\"",
    ":{\"fother\":\"in {0} weeks\",\"fone\":\"in {0} week\",\"pz\":\"{0} weeks ago\",\"pone\":\"{0} week ago\",\"pother\":\"{0} weeks ago\"},\"a\":{\"0\":\"this week\",\"1\":\"next week\",\"-1\":\"last week\"}},\"month\":{\"c\":",
    "{\"fother\":\"in {0} months\",\"fone\":\"in {0} month\",\"pz\":\"{0} months ago\",\"pone\":\"{0} month ago\",\"pother\":\"{0} months ago\"},\"a\":{\"0\":\"this month\",\"1\":\"next month\",\"-1\":\"last month\"}},\"quarter",
    "\":{\"c\":{\"fother\":\"in {0} quarters\",\"fone\":\"in {0} quarter\",\"pz\":\"{0} quarters ago\",\"pone\":\"{0} quarter ago\",\"pother\":\"{0} quarters ago\"},\"a\":{\"0\":\"this quarter\",\"1\":\"next quarter\",\"-1\":\"l",
    "ast quarter\"}},\"year\":{\"c\":{\"fother\":\"in {0} years\",\"fone\":\"in {0} year\",\"pz\":\"{0} years ago\",\"pone\":\"{0} year ago\",\"pother\":\"{0} years ago\"},\"a\":{\"0\":\"this year\",\"1\":\"next year\",\"-1\":\"",
    "last year\"}}},\"s\":{\"second\":{\"c\":{\"fother\":\"in {0} sec.\",\"fone\":\"in {0} sec.\",\"pz\":\"{0} sec. ago\",\"pone\":\"{0} sec. ago\",\"pother\":\"{0} sec. ago\"},\"a\":{\"0\":\"now\"}},\"minute\":{\"c\":{\"fother",
    "\":\"in {0} min.\",\"fone\":\"in {0} min.\",\"pz\":\"{0} min. ago\",\"pone\":\"{0} min. ago\",\"pother\":\"{0} min. ago\"},\"a\":{\"0\":\"this minute\"}},\"hour\":{\"c\":{\"fother\":\"in {0} hr.\",\"fone\":\"in {0} hr.\",\"",
    "pz\":\"{0} hr. ago\",\"pone\":\"{0} hr. ago\",\"pother\":\"{0} hr. ago\"},\"a\":{\"0\":\"this hour\"}},\"day\":{\"c\":{\"fother\":\"in {0} days\",\"fone\":\"in {0} day\",\"pz\":\"{0} days ago\",\"pone\":\"{0} day ago\",\"po",
    "ther\":\"{0} days ago\"},\"a\":{\"0\":\"today\",\"1\":\"tomorrow\",\"-1\":\"yesterday\"}},\"week\":{\"c\":{\"fother\":\"in {0} wk.\",\"fone\":\"in {0} wk.\",\"pz\":\"{0} wk. ago\",\"pone\":\"{0} wk. ago\",\"pother\":\"{0} w",
    "k. ago\"},\"a\":{\"0\":\"this wk.\",\"1\":\"next wk.\",\"-1\":\"last wk.\"}},\"month\":{\"c\":{\"fother\":\"in {0} mo.\",\"fone\":\"in {0} mo.\",\"pz\":\"{0} mo. ago\",\"pone\":\"{0} mo. ago\",\"pother\":\"{0} mo. ago\"},\"",
    "a\":{\"0\":\"this mo.\",\"1\":\"next mo.\",\"-1\":\"last mo.\"}},\"quarter\":{\"c\":{\"fother\":\"in {0} qtrs.\",\"fone\":\"in {0} qtr.\",\"pz\":\"{0} qtrs. ago\",\"pone\":\"{0} qtr. ago\",\"pother\":\"{0} qtrs. ago\"},\"a",
    "\":{\"0\":\"this qtr.\",\"1\":\"next qtr.\",\"-1\":\"last qtr.\"}},\"year\":{\"c\":{\"fother\":\"in {0} yr.\",\"fone\":\"in {0} yr.\",\"pz\":\"{0} yr. ago\",\"pone\":\"{0} yr. ago\",\"pother\":\"{0} yr. ago\"},\"a\":{\"0\":",
    "\"this yr.\",\"1\":\"next yr.\",\"-1\":\"last yr.\"}}}},\"L\":{\"cl\":[\" and \",\", \",\", \",\", and \"],\"cs\":[\" & \",\", \",\", \",\", & \"],\"cn\":[\", \",\", \",\", \",\", \"],\"dl\":[\" or \",\", \",\", \",\", or ",
    "\"],\"ds\":[\" or \",\", \",\", \",\", or \"],\"dn\":[\" or \",\", \",\", \",\", or \"],\"ul\":[\", \",\", \",\", \",\", \"],\"us\":[\", \",\", \",\", \",\", \"],\"un\":[\" \",\" \",\" \",\" \"]},\"Z\":{\"u\":\"UTC\",\"U\":",
    "\"Coordinated Universal Time\",\"a\":\"GMT+5:30\",\"b\":\"GMT+1\",\"c\":\"GMT-3\",\"d\":\"India Standard Time\",\"e\":\"GMT+05:30\",\"f\":\"EST\",\"g\":\"Eastern Standard Time\"},\"T2\":{},\"hc\":\"h\",\"hcn\":\"h12\",\"h12",
    "\":\"h12\",\"ZN\":{\"America/New_York\":[\"EST\",\"EDT\",\"Eastern Standard Time\",\"Eastern Daylight Time\"],\"America/Chicago\":[\"CST\",\"CDT\",\"Central Standard Time\",\"Central Daylight Time\"],\"America/Denver\":[\"M",
    "ST\",\"MDT\",\"Mountain Standard Time\",\"Mountain Daylight Time\"],\"America/Los_Angeles\":[\"PST\",\"PDT\",\"Pacific Standard Time\",\"Pacific Daylight Time\"],\"America/Anchorage\":[\"AKST\",\"AKDT\",\"Alaska Standard Ti",
    "me\",\"Alaska Daylight Time\"],\"America/Halifax\":[\"AST\",\"ADT\",\"Atlantic Standard Time\",\"Atlantic Daylight Time\"],\"America/St_Johns\":[\"GMT-3:30\",\"GMT-2:30\",\"Newfoundland Standard Time\",\"Newfoundland Daylig",
    "ht Time\"],\"America/Phoenix\":[\"MST\",\"MST\",\"Mountain Standard Time\",\"Mountain Standard Time\"],\"Pacific/Honolulu\":[\"HST\",\"HST\",\"Hawaii-Aleutian Standard Time\",\"Hawaii-Aleutian Standard Time\"],\"America/Mex",
    "ico_City\":[\"CST\",\"CST\",\"Central Standard Time\",\"Central Standard Time\"],\"America/Bogota\":[\"GMT-5\",\"GMT-5\",\"Colombia Standard Time\",\"Colombia Standard Time\"],\"America/Sao_Paulo\":[\"GMT-3\",\"GMT-3\",\"Br",
    "asilia Standard Time\",\"Brasilia Standard Time\"],\"America/Argentina/Buenos_Aires\":[\"GMT-3\",\"GMT-3\",\"Argentina Standard Time\",\"Argentina Standard Time\"],\"America/Santiago\":[\"GMT-4\",\"GMT-3\",\"Chile Standard ",
    "Time\",\"Chile Summer Time\"],\"America/Caracas\":[\"GMT-4\",\"GMT-4\",\"Venezuela Time\",\"Venezuela Time\"],\"America/Lima\":[\"GMT-5\",\"GMT-5\",\"Peru Standard Time\",\"Peru Standard Time\"],\"Europe/London\":[\"GMT\",",
    "\"GMT+1\",\"Greenwich Mean Time\",\"British Summer Time\"],\"Europe/Dublin\":[\"GMT\",\"GMT+1\",\"Greenwich Mean Time\",\"Irish Standard Time\"],\"Europe/Lisbon\":[\"GMT\",\"GMT+1\",\"Western European Standard Time\",\"West",
    "ern European Summer Time\"],\"Europe/Paris\":[\"GMT+1\",\"GMT+2\",\"Central European Standard Time\",\"Central European Summer Time\"],\"Africa/Lagos\":[\"GMT+1\",\"GMT+1\",\"West Africa Standard Time\",\"West Africa Standa",
    "rd Time\"],\"Europe/Athens\":[\"GMT+2\",\"GMT+3\",\"Eastern European Standard Time\",\"Eastern European Summer Time\"],\"Africa/Cairo\":[\"GMT+2\",\"GMT+3\",\"Eastern European Standard Time\",\"Eastern European Summer Time",
    "\"],\"Africa/Johannesburg\":[\"GMT+2\",\"GMT+2\",\"South Africa Standard Time\",\"South Africa Standard Time\"],\"Europe/Moscow\":[\"GMT+3\",\"GMT+3\",\"Moscow Standard Time\",\"Moscow Standard Time\"],\"Europe/Istanbul\":[",
    "\"GMT+3\",\"GMT+3\",\"GMT+03:00\",\"GMT+03:00\"],\"Africa/Nairobi\":[\"GMT+3\",\"GMT+3\",\"East Africa Time\",\"East Africa Time\"],\"Asia/Riyadh\":[\"GMT+3\",\"GMT+3\",\"Arabian Standard Time\",\"Arabian Standard Time\"],",
    "\"Asia/Tehran\":[\"GMT+3:30\",\"GMT+3:30\",\"Iran Standard Time\",\"Iran Standard Time\"],\"Asia/Dubai\":[\"GMT+4\",\"GMT+4\",\"Gulf Standard Time\",\"Gulf Standard Time\"],\"Asia/Karachi\":[\"GMT+5\",\"GMT+5\",\"Pakistan S",
    "tandard Time\",\"Pakistan Standard Time\"],\"Asia/Kolkata\":[\"GMT+5:30\",\"GMT+5:30\",\"India Standard Time\",\"India Standard Time\"],\"Asia/Kathmandu\":[\"GMT+5:45\",\"GMT+5:45\",\"Nepal Time\",\"Nepal Time\"],\"Asia/Dha",
    "ka\":[\"GMT+6\",\"GMT+6\",\"Bangladesh Standard Time\",\"Bangladesh Standard Time\"],\"Asia/Bangkok\":[\"GMT+7\",\"GMT+7\",\"Indochina Time\",\"Indochina Time\"],\"Asia/Jakarta\":[\"GMT+7\",\"GMT+7\",\"Western Indonesia Tim",
    "e\",\"Western Indonesia Time\"],\"Asia/Shanghai\":[\"GMT+8\",\"GMT+8\",\"China Standard Time\",\"China Standard Time\"],\"Asia/Hong_Kong\":[\"GMT+8\",\"GMT+8\",\"Hong Kong Standard Time\",\"Hong Kong Standard Time\"],\"Asia",
    "/Singapore\":[\"GMT+8\",\"GMT+8\",\"Singapore Standard Time\",\"Singapore Standard Time\"],\"Asia/Manila\":[\"GMT+8\",\"GMT+8\",\"Philippine Standard Time\",\"Philippine Standard Time\"],\"Asia/Taipei\":[\"GMT+8\",\"GMT+8\"",
    ",\"Taiwan Standard Time\",\"Taiwan Standard Time\"],\"Australia/Perth\":[\"GMT+8\",\"GMT+8\",\"Australian Western Standard Time\",\"Australian Western Standard Time\"],\"Asia/Tokyo\":[\"GMT+9\",\"GMT+9\",\"Japan Standard Ti",
    "me\",\"Japan Standard Time\"],\"Asia/Seoul\":[\"GMT+9\",\"GMT+9\",\"Korean Standard Time\",\"Korean Standard Time\"],\"Australia/Darwin\":[\"GMT+9:30\",\"GMT+9:30\",\"Australian Central Standard Time\",\"Australian Central ",
    "Standard Time\"],\"Australia/Adelaide\":[\"GMT+9:30\",\"GMT+10:30\",\"Australian Central Standard Time\",\"Australian Central Daylight Time\"],\"Australia/Brisbane\":[\"GMT+10\",\"GMT+10\",\"Australian Eastern Standard Time",
    "\",\"Australian Eastern Standard Time\"],\"Australia/Sydney\":[\"GMT+10\",\"GMT+11\",\"Australian Eastern Standard Time\",\"Australian Eastern Daylight Time\"],\"Pacific/Auckland\":[\"GMT+12\",\"GMT+13\",\"New Zealand Stand",
    "ard Time\",\"New Zealand Daylight Time\"],\"Pacific/Fiji\":[\"GMT+12\",\"GMT+12\",\"Fiji Standard Time\",\"Fiji Standard Time\"],\"Pacific/Guam\":[\"GMT+10\",\"GMT+10\",\"Chamorro Standard Time\",\"Chamorro Standard Time\"]",
    "},\"P\":[[\"Jan\",\"Feb\",\"Mar\",\"Apr\",\"May\",\"Jun\",\"Jul\",\"Aug\",\"Sep\",\"Oct\",\"Nov\",\"Dec\"],[\"January\",\"February\",\"March\",\"April\",\"May\",\"June\",\"July\",\"August\",\"September\",\"October\",\"Novem",
    "ber\",\"December\"],[\"J\",\"F\",\"M\",\"A\",\"M\",\"J\",\"J\",\"A\",\"S\",\"O\",\"N\",\"D\"],[\"Sun\",\"Mon\",\"Tue\",\"Wed\",\"Thu\",\"Fri\",\"Sat\"],[\"Sunday\",\"Monday\",\"Tuesday\",\"Wednesday\",\"Thursday\",\"Friday",
    "\",\"Saturday\"],[\"S\",\"M\",\"T\",\"W\",\"T\",\"F\",\"S\"],[\"AM\",\"PM\"]]}"
  ].join('');
}
