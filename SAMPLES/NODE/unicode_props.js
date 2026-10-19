var tests = ['\\p{L}+', '\\p{Lu}', '\\p{Ll}+', '\\p{N}+', '\\p{Nd}+', '\\p{P}+', '\\p{S}+', '\\p{Script=Greek}+', '\\p{sc=Cyrillic}+', '\\p{Script=Han}+', '\\p{Script_Extensions=Latin}+', '\\p{Emoji}', '\\p{Emoji_Presentation}+', '\\p{Alphabetic}+', '\\p{Uppercase}+',
  '\\p{White_Space}+', '\\p{ASCII}+', '\\p{Any}', '\\p{Letter}+', '\\p{Uppercase_Letter}', '\\P{L}+', '[\\p{L}\\p{N}]+', '[^\\p{L}]+', '\\p{General_Category=Decimal_Number}+', '\\p{Script=Latn}+', '\\p{Extended_Pictographic}+', '\\p{Cn}', '\\p{Hex_Digit}+', '\\P{ASCII}+'];
var text = 'Hello Wörld ÅÄÖ αβγ Привет 漢字ひらがなカタカナ 123 ٣٤٥ !?.,;:$+<=>€ 😀👍🏽 ¼½  \t\n end_ 42';
var out = [];
tests.forEach(function (p) {
  var re = new RegExp(p, 'gu'), m = text.match(re);
  out.push(p + ' => ' + JSON.stringify(m));
});
out.push(/\p{L}/.test('p{L}') + ' ' + /\p{L}/u.test('é') + ' ' + /^\p{Lu}\p{Ll}+$/u.test('Éric') + ' ' + 'abc 123 déf'.replace(/\p{L}+/gu, function (w) { return '<' + w + '>'; }));
try { new RegExp('\\p{Foo}', 'u'); out.push('no error'); } catch (e) { out.push(e.constructor.name); }
console.log(out.join('\n'));
