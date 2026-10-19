var out = [];
function p() { out.push(Array.prototype.slice.call(arguments).map(function (x) { return typeof x === 'string' ? x : JSON.stringify(x); }).join(' ')); }
['en-US', 'fr-FR', 'de-DE', 'es-ES', 'ru-RU', 'pl-PL', 'ja-JP', 'pt-BR', 'it-IT', 'cs-CZ'].forEach(function (l) {
  var pr = new Intl.PluralRules(l), po = new Intl.PluralRules(l, { type: 'ordinal' });
  p(l, 'plural', [0, 1, 2, 3, 5, 11, 21, 22, 100, 101, 1.5, 0.5, 1000000].map(function (n) { return pr.select(n); }).join(','));
  p(l, 'ordinal', [1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 101].map(function (n) { return po.select(n); }).join(','));
  ['long', 'short'].forEach(function (st) {
    ['always', 'auto'].forEach(function (nu) {
      var rf = new Intl.RelativeTimeFormat(l, { style: st, numeric: nu });
      p(l, st, nu, [[1, 'day'], [-1, 'day'], [0, 'day'], [3, 'hour'], [-5, 'month'], [2, 'year'], [-1, 'week'], [10, 'second'], [1.5, 'minute'], [-2, 'quarter']].map(function (a) { return rf.format(a[0], a[1]); }).join(' | '));
    });
  });
  ['conjunction', 'disjunction', 'unit'].forEach(function (t) {
    ['long', 'short', 'narrow'].forEach(function (s) {
      var lf = new Intl.ListFormat(l, { type: t, style: s });
      p(l, t, s, lf.format([]), lf.format(['a']), lf.format(['a', 'b']), lf.format(['a', 'b', 'c']), lf.format(['a', 'b', 'c', 'd']));
    });
  });
  var words = ['zebra', 'apple', 'Äpfel', 'éclair', 'Eclair', 'eclair', 'ñandú', 'nube', 'z', 'a10', 'a2', 'a1', 'Zoo', 'zoo', 'ångström', 'ärger', 'öl', 'ol', 'ça', 'cb'];
  p(l, 'sort', words.slice().sort(new Intl.Collator(l).compare).join(' '));
  p(l, 'sortnum', words.slice().sort(new Intl.Collator(l, { numeric: true }).compare).join(' '));
  p(l, 'lc', 'a'.localeCompare('b', l), 'a'.localeCompare('B', l), 'a'.localeCompare('A', l), 'ä'.localeCompare('a', l, { sensitivity: 'base' }), 'a'.localeCompare('á', l, { sensitivity: 'accent' }));
});
p(new Intl.NumberFormat().resolvedOptions());
p(new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York' }).resolvedOptions());
p(new Intl.DateTimeFormat('de-DE', { hour: 'numeric', hour12: false }).resolvedOptions());
p(new Intl.PluralRules('en').resolvedOptions());
p(Intl.getCanonicalLocales(['EN-us', 'fr-fr', 'zh-hans-cn']), new Intl.Locale('en-Latn-US').language, new Intl.Locale('fr-CA').region, String(new Intl.Locale('de-DE-u-nu-latn')));
p([...new Intl.Segmenter('en', { granularity: 'grapheme' }).segment('áb😀')].map(function (s) { return s.segment; }));
p([...new Intl.Segmenter('en', { granularity: 'word' }).segment('Hello, world! 42')].filter(function (s) { return s.isWordLike; }).map(function (s) { return s.segment; }));
p(Intl.DateTimeFormat.supportedLocalesOf(['en-US', 'xx-XX', 'fr']), Intl.NumberFormat.supportedLocalesOf('de'));
p((1234.5).toLocaleString('de-DE'), (1234.5).toLocaleString('fr-FR', { style: 'currency', currency: 'EUR' }), (0.256).toLocaleString('en-US', { style: 'percent' }), (123456789n).toLocaleString('en-US'));
p([1234.5, 6789].toLocaleString('de-DE'), new Date(Date.UTC(2020, 11, 25, 15, 30)).toLocaleDateString('de-DE', { timeZone: 'UTC' }), new Date(Date.UTC(2020, 11, 25, 15, 30)).toLocaleTimeString('en-GB', { timeZone: 'UTC' }));
p('I'.toLocaleLowerCase('tr'), 'i'.toLocaleUpperCase('tr'), 'i'.toLocaleUpperCase('en'));
p(new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).formatToParts(-1234.5));
p(new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'UTC' }).formatToParts(new Date(0)));
p(typeof Intl, Object.prototype.toString.call(Intl), Object.prototype.toString.call(new Intl.NumberFormat()));
p(new Intl.DisplayNames('en', { type: 'region' }).of('US'), new Intl.DisplayNames('en', { type: 'language' }).of('fr'), new Intl.DisplayNames('en', { type: 'currency' }).of('EUR'));
console.log(out.join('\n'));
