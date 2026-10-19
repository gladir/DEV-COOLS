// Genere les donnees Intl (modele : Node/ICU) pour les chunks prelude_intl*.js
const fs = require('fs');
const LOCS = ['en-US', 'en-GB', 'en-AU', 'en-CA', 'en-IN', 'fr-FR', 'fr-CA', 'de-DE', 'es-ES', 'es-MX', 'it-IT', 'pt-BR', 'pt-PT', 'nl-NL', 'sv-SE', 'da-DK', 'nb-NO', 'fi-FI', 'pl-PL', 'cs-CZ', 'ru-RU', 'uk-UA', 'tr-TR', 'ja-JP', 'zh-CN', 'zh-TW', 'ko-KR', 'hi-IN', 'id-ID', 'he-IL', 'el-GR', 'hu-HU'];
const DT = new Date(Date.UTC(2024, 2, 5, 9, 7, 4, 123));
const DTP = new Date(Date.UTC(2024, 2, 5, 15, 7, 4));
const CURS = ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'KRW', 'INR', 'BRL', 'CAD', 'AUD', 'CHF', 'MXN', 'RUB', 'SEK', 'NOK', 'DKK', 'PLN', 'TRY', 'ZAR', 'HKD', 'SGD', 'NZD', 'ILS', 'CZK', 'HUF', 'UAH', 'THB', 'IDR', 'TWD', 'PHP', 'EGP', 'SAR', 'AED', 'ARS', 'CLP', 'COP', 'VND', 'BTC'];
const UNITS = ['second', 'minute', 'hour', 'day', 'week', 'month', 'quarter', 'year'];
function parts(loc, o, d) { return new Intl.DateTimeFormat(loc, Object.assign({ timeZone: 'UTC' }, o)).formatToParts(d || DT); }
function pool(P, arr) { const k = JSON.stringify(arr); let i = P.findIndex(x => JSON.stringify(x) === k); if (i < 0) { P.push(arr); i = P.length - 1; } return i; }
function nameList(loc, o, type, n) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const d = type === 'month' ? new Date(Date.UTC(2024, i, 15)) : new Date(Date.UTC(2024, 2, 3 + i));
    const p = parts(loc, o, d).find(x => x.type === type);
    out.push(p ? p.value : '');
  }
  return out;
}
function tokenize(loc, o, P, hc) {
  const ps = parts(loc, o);
  let s = '';
  for (const p of ps) {
    const v = p.value;
    switch (p.type) {
      case 'literal': s += v; break;
      case 'weekday': s += '{E#' + pool(P, nameList(loc, o, 'weekday', 7)) + '}'; break;
      case 'month':
        if (!/^[0-9]+$/.test(v)) s += '{M#' + pool(P, nameList(loc, o, 'month', 12)) + '}';
        else s += v.length === 2 ? '{MM}' : '{M}';
        break;
      case 'day': s += v.length === 2 ? '{dd}' : '{d}'; break;
      case 'year': s += v.length === 2 ? '{yy}' : '{y}'; break;
      case 'hour': s += hc === 'h' ? (v.length === 2 ? '{hh}' : '{h}') : (v.length === 2 ? '{HH}' : '{H}'); break;
      case 'minute': s += v.length === 2 ? '{mm}' : '{m}'; break;
      case 'second': s += v.length === 2 ? '{ss}' : '{s}'; break;
      case 'dayPeriod': {
        const a = parts(loc, o, DT).find(x => x.type === 'dayPeriod').value, b = parts(loc, o, DTP).find(x => x.type === 'dayPeriod').value;
        const all = [];
        for (let hh = 0; hh < 24; hh++) { const pp = parts(loc, o, new Date(Date.UTC(2024, 2, 5, hh, 7, 4))).find(x => x.type === 'dayPeriod'); all.push(pp ? pp.value : ''); }
        if (new Set(all).size > 2) s += '{a#' + pool(P, all) + '}'; else s += '{a#' + pool(P, [a, b]) + '}';
        break;
      }
      case 'timeZoneName': s += o.timeZoneName === 'long' ? '{zz}' : '{z}'; break;
      case 'era': s += '{G}'; break;
      case 'fractionalSecond': s += '{f}'; break;
      default: s += v;
    }
  }
  return s;
}
function dateKey(w, m, y, d) { return (w ? w[0] === 'n' ? 'r' : w[0] : '-') + (m ? (m === 'numeric' || m === '2-digit') ? '#' : m === 'narrow' ? 'r' : m[0] : '-') + (y ? 'y' : '-') + (d ? 'd' : '-'); }
function gen(loc) {
  const P = [], L = { D: {}, T: {}, S: {}, G: [], N: {}, R: {}, L: {}, Z: {} };
  // champs de date
  for (const w of [null, 'short', 'long', 'narrow']) for (const m of [null, 'numeric', 'short', 'long', 'narrow']) for (const y of [0, 1]) for (const d of [0, 1]) {
    if (!w && !m && !y && !d) continue;
    const o = {};
    if (w) o.weekday = w; if (m) o.month = m; if (y) o.year = 'numeric'; if (d) o.day = 'numeric';
    L.D[dateKey(w, m, y, d)] = tokenize(loc, o, P, 'H');
  }
  // champs d'heure
  for (const hc of ['h', 'H']) for (const h of [0, 1]) for (const mi of [0, 1]) for (const s of [0, 1]) for (const z of [null, 'short', 'long']) {
    if (!h && !mi && !s) continue;
    if (!h && hc === 'h') continue;
    if (z && !h) continue;
    const o = {};
    if (h) { o.hour = 'numeric'; o.hourCycle = hc === 'h' ? 'h12' : 'h23'; }
    if (mi) o.minute = 'numeric'; if (s) o.second = 'numeric'; if (z) o.timeZoneName = z;
    L.T[(h ? hc : '-') + (h ? 'h' : '-') + (mi ? 'm' : '-') + (s ? 's' : '-') + (z ? z[0] === 's' ? 'z' : 'Z' : '-')] = tokenize(loc, o, P, hc);
  }
  L.T2 = {};
  for (const hc of ['h', 'H']) for (const mi of [0, 1]) for (const s of [0, 1]) for (const z of [null, 'short', 'long']) {
    if (!mi && !s) continue;
    const o = { hour: 'numeric', hourCycle: hc === 'h' ? 'h12' : 'h23' };
    if (mi) o.minute = '2-digit'; if (s) o.second = '2-digit'; if (z) o.timeZoneName = z;
    const k = hc + 'h' + (mi ? 'm' : '-') + (s ? 's' : '-') + (z ? z[0] === 's' ? 'z' : 'Z' : '-');
    const p2 = tokenize(loc, o, P, hc);
    if (p2 !== L.T[k]) L.T2[k] = p2;
  }
  // styles
  for (const st of ['full', 'long', 'medium', 'short']) {
    L.S['d' + st[0]] = tokenize(loc, { dateStyle: st }, P, 'H');
    const o = { timeStyle: st };
    const rd = new Intl.DateTimeFormat(loc, { timeStyle: st }).resolvedOptions();
    L.S['t' + st[0]] = tokenize(loc, o, P, rd.hourCycle === 'h12' || rd.hourCycle === 'h11' ? 'h' : 'H');
    o.hour12 = rd.hourCycle !== 'h12' && rd.hourCycle !== 'h11';
    L.S['u' + st[0]] = tokenize(loc, { timeStyle: st, hour12: o.hour12 }, P, o.hour12 ? 'h' : 'H');
  }
  // colle date + heure (litteral entre le bloc date et le bloc heure, sans les litteraux deja dans les gabarits)
  for (const st of ['full', 'long', 'medium', 'short']) {
    const ps = parts(loc, { dateStyle: st, timeStyle: 'short' });
    const dtypes = new Set(['weekday', 'month', 'day', 'year', 'era', 'relatedYear']);
    let lastDate = -1, firstTime = -1, firstDate = 1e9, lastTime = -1;
    ps.forEach((p, i) => {
      if (dtypes.has(p.type)) { lastDate = i; if (i < firstDate) firstDate = i; }
      if (['hour', 'minute', 'second', 'dayPeriod', 'timeZoneName'].includes(p.type)) { if (firstTime < 0) firstTime = i; lastTime = i; }
    });
    const dp = L.S['d' + st[0]], tp = L.S['t' + st[0]];
    const dTail = dp.slice(dp.lastIndexOf('}') + 1), dHead = dp.slice(0, dp.indexOf('{'));
    const tTail = tp.slice(tp.lastIndexOf('}') + 1), tHead = tp.slice(0, tp.indexOf('{'));
    const join = (a, b) => ps.slice(a, b).map(p => p.value).join('');
    if (lastDate < firstTime) {
      let lit = join(lastDate + 1, firstTime);
      if (lit.startsWith(dTail)) lit = lit.slice(dTail.length);
      if (lit.endsWith(tHead)) lit = lit.slice(0, lit.length - tHead.length);
      let suf = join(lastTime + 1, ps.length); if (suf.startsWith(tTail)) suf = suf.slice(tTail.length);
      let pre = join(0, firstDate); if (pre.endsWith(dHead)) pre = pre.slice(0, pre.length - dHead.length);
      L.G.push([0, lit, pre, suf]);
    } else {
      let lit = join(lastTime + 1, firstDate);
      if (lit.startsWith(tTail)) lit = lit.slice(tTail.length);
      if (lit.endsWith(dHead)) lit = lit.slice(0, lit.length - dHead.length);
      let suf = join(lastDate + 1, ps.length); if (suf.startsWith(dTail)) suf = suf.slice(dTail.length);
      let pre = join(0, firstTime); if (pre.endsWith(tHead)) pre = pre.slice(0, pre.length - tHead.length);
      L.G.push([1, lit, pre, suf]);
    }
  }
  const r = new Intl.DateTimeFormat(loc, { hour: 'numeric' }).resolvedOptions();
  L.hc = r.hourCycle === 'h12' || r.hourCycle === 'h11' ? 'h' : 'H';
  L.hcn = r.hourCycle;
  L.h12 = new Intl.DateTimeFormat(loc, { hour: 'numeric', hour12: true }).resolvedOptions().hourCycle;
  // fuseaux
  const zs = (z, st) => new Intl.DateTimeFormat(loc, { timeZone: z, timeZoneName: st }).formatToParts(DT).find(x => x.type === 'timeZoneName').value;
  L.Z = { u: zs('UTC', 'short'), U: zs('UTC', 'long'), a: zs('Asia/Kolkata', 'short'), b: zs('Europe/Paris', 'short'), c: zs('America/Sao_Paulo', 'short'), d: zs('Asia/Kolkata', 'long'), e: zs('Asia/Kolkata', 'longOffset') };
  L.Z.f = zs('America/New_York', 'short'); L.Z.g = zs('America/New_York', 'long');
  // noms de fuseaux (zones representatives)
  L.ZN = {};
  const REPS = ['America/New_York', 'America/Chicago', 'America/Denver', 'America/Los_Angeles', 'America/Anchorage', 'America/Halifax', 'America/St_Johns', 'America/Phoenix', 'Pacific/Honolulu', 'America/Mexico_City', 'America/Bogota', 'America/Sao_Paulo', 'America/Argentina/Buenos_Aires', 'America/Santiago', 'America/Caracas', 'America/Lima', 'Europe/London', 'Europe/Dublin', 'Europe/Lisbon', 'Europe/Paris', 'Africa/Lagos', 'Europe/Athens', 'Africa/Cairo', 'Africa/Johannesburg', 'Europe/Moscow', 'Europe/Istanbul', 'Africa/Nairobi', 'Asia/Riyadh', 'Asia/Tehran', 'Asia/Dubai', 'Asia/Karachi', 'Asia/Kolkata', 'Asia/Kathmandu', 'Asia/Dhaka', 'Asia/Bangkok', 'Asia/Jakarta', 'Asia/Shanghai', 'Asia/Hong_Kong', 'Asia/Singapore', 'Asia/Manila', 'Asia/Taipei', 'Australia/Perth', 'Asia/Tokyo', 'Asia/Seoul', 'Australia/Darwin', 'Australia/Adelaide', 'Australia/Brisbane', 'Australia/Sydney', 'Pacific/Auckland', 'Pacific/Fiji', 'Pacific/Guam'];
  const jan = new Date(Date.UTC(2024, 0, 15, 12)), jul = new Date(Date.UTC(2024, 6, 15, 12));
  const zname = (z, st, d) => new Intl.DateTimeFormat(loc, { timeZone: z, timeZoneName: st }).formatToParts(d).find(x => x.type === 'timeZoneName').value;
  const zoff = (z, d) => { const m = /([+\-−])(\d\d)[:.](\d\d)/.exec(zname(z, 'longOffset', d)); return m ? (m[1] !== '+' ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) : 0; };
  for (const z of REPS) {
    const oj = zoff(z, jan), ol = zoff(z, jul);
    let sd, dd;
    if (oj === ol) { sd = jan; dd = jan; } else if (ol > oj) { sd = jan; dd = jul; } else { sd = jul; dd = jan; }
    L.ZN[z] = [zname(z, 'short', sd), zname(z, 'short', dd), zname(z, 'long', sd), zname(z, 'long', dd)];
  }
  // nombres
  const nf = new Intl.NumberFormat(loc);
  const np = nf.formatToParts(1234567.891);
  const N = L.N;
  N.d = np.find(x => x.type === 'decimal').value; N.g = np.find(x => x.type === 'group').value;
  N.mg = nf.formatToParts(1234).some(x => x.type === 'group') ? 1 : 2;
  N.ind = /^\d{1,2}[^\d]\d\d[^\d]\d\d\d$/.test(nf.format(1234567));
  N.m = nf.formatToParts(-1).find(x => x.type === 'minusSign').value;
  N.p = new Intl.NumberFormat(loc, { signDisplay: 'always' }).formatToParts(1).find(x => x.type === 'plusSign').value;
  N.nan = nf.format(NaN); N.inf = nf.format(Infinity);
  const pat = (f, neg, val) => {
    const ps = f.formatToParts(val === undefined ? (neg ? -1234.5 : 1234.5) : val);
    let pre = '', suf = '', seen = false;
    for (const p of ps) {
      if (['integer', 'group', 'decimal', 'fraction', 'nan', 'infinity'].includes(p.type)) { seen = true; continue; }
      const t = p.type === 'minusSign' ? '{-}' : p.type === 'currency' ? '{c}' : p.type === 'percentSign' ? '%' : p.value;
      if (seen) suf += t; else pre += t;
    }
    return [pre, suf];
  };
  const pf = new Intl.NumberFormat(loc, { style: 'percent' });
  N.dn = pat(nf, true); N.pp = pat(pf, false); N.pn = pat(pf, true); N.ps = pat(pf, false, NaN);
  N.cp = {}; N.cs = {}; N.cd = {}; N.cn = {};
  const grp = [];
  for (const c of CURS) {
    let f;
    try { f = new Intl.NumberFormat(loc, { style: 'currency', currency: c }); } catch (e) { continue; }
    const sym = f.formatToParts(1).find(x => x.type === 'currency').value;
    N.cs[c] = sym;
    const nsym = new Intl.NumberFormat(loc, { style: 'currency', currency: c, currencyDisplay: 'narrowSymbol' }).formatToParts(1).find(x => x.type === 'currency').value;
    if (nsym !== sym) { const fn = new Intl.NumberFormat(loc, { style: 'currency', currency: c, currencyDisplay: 'narrowSymbol' }); const kk = JSON.stringify([pat(fn, false), pat(fn, true), pat(fn, false, NaN)]); let gj = grp.indexOf(kk); if (gj < 0) { grp.push(kk); gj = grp.length - 1; } N.cn[c] = [nsym, gj]; }
    const fd = f.resolvedOptions().maximumFractionDigits;
    N.cd[c] = fd;
    const key = JSON.stringify([pat(f, false), pat(f, true), pat(f, false, NaN)]);
    let gi = grp.indexOf(key);
    if (gi < 0) { grp.push(key); gi = grp.length - 1; }
    N.cp[c] = gi;
  }
  N.cpats = grp.map(x => JSON.parse(x));
  N.cc = (() => { const f = new Intl.NumberFormat(loc, { style: 'currency', currency: 'USD', currencyDisplay: 'code' }); return [pat(f, false), pat(f, true), pat(f, false, NaN)]; })();
  N.ca = (() => { const f = new Intl.NumberFormat(loc, { style: 'currency', currency: 'USD', currencySign: 'accounting' }); return [pat(f, false), pat(f, true), pat(f, false, NaN)]; })();
  N.sci = new Intl.NumberFormat(loc, { notation: 'scientific' }).formatToParts(12345).filter(x => x.type === 'exponentSeparator').map(x => x.value)[0];
  // compact (court/long) : echantillons
  N.cmp = {};
  for (const [disp, nm] of [['short', 's'], ['long', 'l']]) {
    const cf = new Intl.NumberFormat(loc, { notation: 'compact', compactDisplay: disp });
    N.cmp[nm] = [1000, 10000, 100000, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13, 1e14, 1e15].map(x => cf.format(x));
    N.cmp[nm + '2'] = [2000, 20000, 200000, 2e6, 2e7, 2e8, 2e9, 2e10, 2e11, 2e12, 2e13, 2e14, 2e15].map(x => cf.format(x));
  }
  // temps relatif
  const R = L.R;
  for (const sty of ['long', 'short']) {
    R[sty[0]] = {};
    for (const u of UNITS) {
      const pr = new Intl.PluralRules(loc);
      const cats = {};
      const rtf = new Intl.RelativeTimeFormat(loc, { style: sty, numeric: 'always' });
      for (const dir of [1, -1]) {
        for (const n of [0, 1, 2, 3, 5, 11, 21, 100, 1.5]) {
          const cat = pr.select(n);
          const tpl = rtf.formatToParts(dir * (n === 0 && dir < 0 ? 0 : n), u).map(p => p.type === 'integer' || p.type === 'group' || p.type === 'decimal' || p.type === 'fraction' ? (p.type === 'integer' && !p.unit ? '{0}' : (p.type === 'integer' ? '{0}' : '')) : p.value);
          const k = (dir > 0 ? 'f' : 'p') + cat;
          if (n === 0 && dir < 0) { cats['pz'] = tpl.join('').replace(/\{0\}\{0\}/g, '{0}'); continue; }
          if (!(k in cats)) cats[k] = tpl.join('');
        }
      }
      const a = new Intl.RelativeTimeFormat(loc, { style: sty, numeric: 'auto' });
      const auto = {};
      for (const n of [-2, -1, 0, 1, 2]) { const s = a.format(n, u); if (s !== rtf.format(n, u)) auto[n] = s; }
      R[sty[0]][u] = { c: cats, a: auto };
    }
  }
  // listes
  for (const type of ['conjunction', 'disjunction', 'unit']) for (const style of ['long', 'short', 'narrow']) {
    const lf = new Intl.ListFormat(loc, { type, style });
    const two = lf.format(['A', 'B']).replace('A', '\u0001').replace('B', '\u0002'), three = lf.format(['A', 'B', 'C']), four = lf.format(['A', 'B', 'C', 'D']);
    const mid = (s, a, b) => s.slice(s.indexOf(a) + 1, s.indexOf(b));
    L.L[type[0] + style[0]] = [two.slice(1, two.indexOf('\u0002')), three.slice(1, three.indexOf('B')), four.slice(four.indexOf('B') + 1, four.indexOf('C')), three.slice(three.indexOf('B') + 1, three.indexOf('C'))];
  }
  L.P = P;
  return L;
}
const out = {};
for (const l of LOCS) { out[l] = gen(l); }
fs.writeFileSync('/tmp/claude-0/b/p/intl_raw.json', JSON.stringify(out));
console.log(Object.keys(out).length, JSON.stringify(out['de-DE']).length, JSON.stringify(out['en-US']).length);
