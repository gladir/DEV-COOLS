var L = 'fr-FR';

var OPTS = [ {}, {maximumFractionDigits:0}, {minimumFractionDigits:2}, {style:'percent'}, {style:'percent',minimumFractionDigits:1},
 {style:'currency',currency:'USD'}, {style:'currency',currency:'EUR'}, {style:'currency',currency:'JPY'}, {style:'currency',currency:'GBP'}, {style:'currency',currency:'BRL'}, {style:'currency',currency:'EUR',currencyDisplay:'code'},
 {style:'currency',currency:'USD',currencySign:'accounting'}, {notation:'compact'}, {notation:'compact',compactDisplay:'long'}, {notation:'scientific'}, {notation:'engineering'}, {signDisplay:'always'}, {signDisplay:'exceptZero'},
 {useGrouping:false}, {minimumIntegerDigits:3}, {maximumSignificantDigits:3}, {minimumSignificantDigits:5}, {style:'unit',unit:'kilometer-per-hour'}, {style:'unit',unit:'celsius'},
 {style:'unit',unit:'megabyte',unitDisplay:'long'}, {style:'currency',currency:'EUR',currencyDisplay:'name'}, {style:'currency',currency:'USD',minimumFractionDigits:0}, {style:'currency',currency:'USD',currencyDisplay:'narrowSymbol'},
 {maximumFractionDigits:1, minimumFractionDigits:1}, {notation:'compact',maximumFractionDigits:2}, {style:'percent',maximumFractionDigits:2}, {useGrouping:'always'}, {useGrouping:'min2'} ];
var NUMS = [0, 1, -1, 0.5, 1234.5678, -1234567.891, 1e21, 123456789012345680000, 0.000001234, 99999.995, 1.005, 2.5, 1e-7, 12, 1000, 12345, 123456, 1234567, 15000, 999999, 1500000000, NaN, Infinity, -0, 0.125, 1234.5];
var out = [];
OPTS.forEach(function (o) {
  NUMS.forEach(function (n) {
    try { out.push(JSON.stringify(o) + ' ' + String(n) + ' => ' + new Intl.NumberFormat(L, o).format(n)); }
    catch (e) { out.push(JSON.stringify(o) + ' ERR ' + e.constructor.name + ': ' + e.message); }
  });
});
console.log(out.join('\n'));
