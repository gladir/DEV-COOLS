// Genere les tables Unicode (proprietes pour \p{...} et normalisation) depuis Node/ICU
const fs = require('fs');
const N = 0x110000;
const chars = new Array(N);
for (let c = 0; c < N; c++) chars[c] = (c >= 0xD800 && c < 0xE000) ? null : String.fromCodePoint(c);
function ranges(re) {
  const out = [];
  let s = -1;
  for (let c = 0; c < N; c++) {
    const ch = chars[c];
    const m = ch !== null && re.test(ch);
    if (m) { if (s < 0) s = c; }
    else if (s >= 0) { out.push([s, c - 1]); s = -1; }
  }
  if (s >= 0) out.push([s, N - 1]);
  return out;
}
function enc(rs) {
  let prev = 0, toks = [];
  for (const [a, b] of rs) { toks.push((a - prev).toString(36)); toks.push((b - a).toString(36)); prev = b; }
  return toks.join(',');
}
const GC = ['Cc', 'Cf', 'Cn', 'Co', 'Cs', 'Ll', 'Lm', 'Lo', 'Lt', 'Lu', 'Mc', 'Me', 'Mn', 'Nd', 'Nl', 'No', 'Pc', 'Pd', 'Pe', 'Pf', 'Pi', 'Po', 'Ps', 'Sc', 'Sk', 'Sm', 'So', 'Zl', 'Zp', 'Zs'];
const SCRIPTS = 'Adlam Ahom Anatolian_Hieroglyphs Arabic Armenian Avestan Balinese Bamum Bassa_Vah Batak Bengali Bhaiksuki Bopomofo Brahmi Braille Buginese Buhid Canadian_Aboriginal Carian Caucasian_Albanian Chakma Cham Cherokee Chorasmian Common Coptic Cuneiform Cypriot Cypro_Minoan Cyrillic Deseret Devanagari Dives_Akuru Dogra Duployan Egyptian_Hieroglyphs Elbasan Elymaic Ethiopic Garay Georgian Glagolitic Gothic Grantha Greek Gujarati Gunjala_Gondi Gurmukhi Gurung_Khema Han Hangul Hanifi_Rohingya Hanunoo Hatran Hebrew Hiragana Imperial_Aramaic Inherited Inscriptional_Pahlavi Inscriptional_Parthian Javanese Kaithi Kannada Katakana Kawi Kayah_Li Kharoshthi Khitan_Small_Script Khmer Khojki Khudawadi Kirat_Rai Lao Latin Lepcha Limbu Linear_A Linear_B Lisu Lycian Lydian Mahajani Makasar Malayalam Mandaic Manichaean Marchen Masaram_Gondi Medefaidrin Meetei_Mayek Mende_Kikakui Meroitic_Cursive Meroitic_Hieroglyphs Miao Modi Mongolian Mro Multani Myanmar Nabataean Nag_Mundari Nandinagari New_Tai_Lue Newa Nko Nushu Nyiakeng_Puachue_Hmong Ogham Ol_Chiki Ol_Onal Old_Hungarian Old_Italic Old_North_Arabian Old_Permic Old_Persian Old_Sogdian Old_South_Arabian Old_Turkic Old_Uyghur Oriya Osage Osmanya Pahawh_Hmong Palmyrene Pau_Cin_Hau Phags_Pa Phoenician Psalter_Pahlavi Rejang Runic Samaritan Saurashtra Sharada Shavian Siddham SignWriting Sinhala Sogdian Sora_Sompeng Soyombo Sundanese Sunuwar Syloti_Nagri Syriac Tagalog Tagbanwa Tai_Le Tai_Tham Tai_Viet Takri Tamil Tangsa Tangut Telugu Thaana Thai Tibetan Tifinagh Tirhuta Todhri Toto Tulu_Tigalari Ugaritic Vai Vithkuqi Wancho Warang_Citi Yezidi Yi Zanabazar_Square'.split(' ');
const BIN = 'ASCII_Hex_Digit Alphabetic Bidi_Control Bidi_Mirrored Case_Ignorable Cased Changes_When_Casefolded Changes_When_Casemapped Changes_When_Lowercased Changes_When_NFKC_Casefolded Changes_When_Titlecased Changes_When_Uppercased Dash Default_Ignorable_Code_Point Deprecated Diacritic Emoji Emoji_Component Emoji_Modifier Emoji_Modifier_Base Emoji_Presentation Extended_Pictographic Extender Grapheme_Base Grapheme_Extend Hex_Digit IDS_Binary_Operator IDS_Trinary_Operator ID_Continue ID_Start Ideographic Join_Control Logical_Order_Exception Lowercase Math Noncharacter_Code_Point Pattern_Syntax Pattern_White_Space Quotation_Mark Radical Regional_Indicator Sentence_Terminal Soft_Dotted Terminal_Punctuation Unified_Ideograph Uppercase Variation_Selector White_Space XID_Continue XID_Start'.split(' ');
const out = { gc: {}, sc: {}, scx: {}, bin: {} };
for (const g of GC) out.gc[g] = enc(ranges(new RegExp('\\p{' + g + '}', 'u')));
for (const s of SCRIPTS) {
  let re; try { re = new RegExp('\\p{Script=' + s + '}', 'u'); } catch (e) { console.error('script inconnu', s); continue; }
  const a = ranges(re), b = ranges(new RegExp('\\p{Script_Extensions=' + s + '}', 'u'));
  out.sc[s] = enc(a);
  const ea = enc(a), eb = enc(b);
  if (ea !== eb) out.scx[s] = eb;
}
for (const b of BIN) { try { out.bin[b] = enc(ranges(new RegExp('\\p{' + b + '}', 'u'))); } catch (e) { console.error('prop inconnue', b); } }
fs.writeFileSync('/tmp/claude-0/b/p/uni_props.json', JSON.stringify(out));
// normalisation
const canon = [], compat = [], pairs = [];
const hex = c => c.toString(36);
for (let c = 0; c < N; c++) {
  const ch = chars[c];
  if (ch === null || (c >= 0xAC00 && c <= 0xD7A3)) continue;
  const d = ch.normalize('NFD'), kd = ch.normalize('NFKD');
  const cps = s => Array.from(s, x => x.codePointAt(0));
  if (d !== ch) canon.push([c, cps(d)]);
  if (kd !== d) compat.push([c, cps(kd)]);
  if (d !== ch) {
    const dc = cps(d);
    if (dc.length >= 2) {
      const b = dc[dc.length - 1], a = String.fromCodePoint(...dc.slice(0, -1)).normalize('NFC');
      if (Array.from(a).length === 1 && (a + String.fromCodePoint(b)).normalize('NFC') === ch) pairs.push([a.codePointAt(0), b, c]);
    }
  }
}
function encSeq(list) { return list.map(([c, s]) => [hex(c), s.length.toString(36), ...s.map(hex)].join(',')).join(','); }
// classes de combinaison (Unicode 15.1 via Python) calculees ici par ordre canonique : on les lit depuis un fichier
let ccc = {};
try { ccc = JSON.parse(fs.readFileSync('/tmp/claude-0/b/p/ccc.json', 'utf8')); } catch (e) { }
const cccRanges = [];
const keys = Object.keys(ccc).map(Number).sort((x, y) => x - y);
let prevEnd = 0;
for (let i = 0; i < keys.length;) {
  let j = i;
  while (j + 1 < keys.length && keys[j + 1] === keys[j] + 1 && ccc[keys[j + 1]] === ccc[keys[i]]) j++;
  cccRanges.push([keys[i], keys[j], ccc[keys[i]]]);
  i = j + 1;
}
const cccEnc = cccRanges.map(([a, b, v], idx) => { const t = [(a - prevEnd).toString(36), (b - a).toString(36), v.toString(36)].join(','); prevEnd = b; return t; }).join(',');
fs.writeFileSync('/tmp/claude-0/b/p/uni_norm.json', JSON.stringify({ canon: encSeq(canon), compat: encSeq(compat), pairs: pairs.map(p => p.map(hex).join(',')).join(','), ccc: cccEnc }));
console.log('ok', canon.length, compat.length, pairs.length, cccRanges.length);
