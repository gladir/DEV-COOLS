var samples = ['café', 'café', 'Ångström', 'Å', 'Å', 'ẛ̣', 'ﬁ', '①', 'Ａ', '½', '한글', '한', 'क़', 'ậ', 'ậ', '̈́', 'ᾀ', 'Ǆ', 'é̂', '𝅗𝅥', 'Ω', 'ཱི', 'ำ', 'q̣̇', 'é́', '㌄', 'ﷺ', 'ABC abc', 'ǅ', 'ﬃ', '각', 'Ǻ', 'à֮̀̕b'];
var forms = ['NFC', 'NFD', 'NFKC', 'NFKD'];
var out = [];
samples.forEach(function (s) {
  forms.forEach(function (f) {
    var r = s.normalize(f);
    out.push(Array.from(s, function (c) { return c.codePointAt(0).toString(16); }).join(' ') + ' ' + f + ' => ' + Array.from(r, function (c) { return c.codePointAt(0).toString(16); }).join(' '));
  });
});
out.push('café'.normalize('NFD').length, 'café'.normalize().length, 'x'.normalize('NFKC'));
try { 'a'.normalize('X'); } catch (e) { out.push(e.constructor.name + ': ' + e.message); }
console.log(out.join('\n'));
