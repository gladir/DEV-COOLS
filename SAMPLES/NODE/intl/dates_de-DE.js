var L = 'de-DE';

var OPTS = [
 {}, {dateStyle:'full'}, {dateStyle:'long'}, {dateStyle:'medium'}, {dateStyle:'short'}, {timeStyle:'short'}, {timeStyle:'medium'}, {timeStyle:'long'}, {timeStyle:'full'},
 {dateStyle:'full',timeStyle:'short'}, {dateStyle:'long',timeStyle:'medium'}, {dateStyle:'medium',timeStyle:'medium'}, {dateStyle:'short',timeStyle:'short'},
 {year:'numeric',month:'long',day:'numeric'}, {year:'numeric',month:'short',day:'numeric'}, {year:'numeric',month:'numeric',day:'numeric'}, {year:'numeric',month:'2-digit',day:'2-digit'},
 {weekday:'long',year:'numeric',month:'long',day:'numeric'}, {weekday:'short',month:'short',day:'numeric'}, {month:'long',year:'numeric'}, {month:'long'}, {weekday:'long'}, {month:'short',day:'numeric'},
 {year:'numeric'}, {year:'2-digit',month:'2-digit',day:'2-digit'}, {month:'numeric',day:'numeric'}, {year:'numeric',month:'numeric'}, {weekday:'narrow',month:'narrow',day:'numeric'},
 {hour:'numeric',minute:'numeric'}, {hour:'2-digit',minute:'2-digit'}, {hour:'numeric',minute:'numeric',second:'numeric'}, {hour:'numeric',minute:'2-digit',hour12:true}, {hour:'numeric',minute:'2-digit',hour12:false},
 {hour:'numeric'}, {minute:'numeric',second:'numeric'}, {hour:'numeric',minute:'numeric',timeZoneName:'short'}, {hour:'numeric',minute:'numeric',timeZoneName:'long'},
 {year:'numeric',month:'long',day:'numeric',hour:'numeric',minute:'numeric'}, {year:'numeric',month:'short',day:'numeric',hour:'numeric',minute:'numeric',second:'numeric'},
 {year:'numeric',month:'numeric',day:'numeric',hour:'numeric',minute:'numeric',hour12:false}, {weekday:'long',year:'numeric',month:'long',day:'numeric',hour:'numeric',minute:'numeric'},
 {hourCycle:'h23',hour:'numeric',minute:'numeric'}, {timeStyle:'short',hour12:true}, {timeStyle:'short',hour12:false}, {fractionalSecondDigits:3,second:'numeric',minute:'numeric'},
 {era:'short',year:'numeric'}, {dayPeriod:'long',hour:'numeric'}
];
var DATES = [0, 1709629624123, 1720000000000, 1718451600000, 946684800000, -1234567890123, 1711929600000, 4102444800000];
var ZONES = [undefined, 'America/New_York', 'Asia/Kolkata', 'Europe/Paris', 'Australia/Sydney', 'America/Los_Angeles', 'Asia/Tokyo'];
var out = [];
var ZS = ZONES;
OPTS.forEach(function (o, oi) {
  DATES.forEach(function (t, di) {
    var z = ZS[(oi + di) % ZS.length];
    var oo = {}; for (var k in o) oo[k] = o[k]; oo.timeZone = z === undefined ? 'UTC' : z;
    try { out.push(JSON.stringify(o) + ' ' + t + ' ' + oo.timeZone + ' => ' + new Intl.DateTimeFormat(L, oo).format(t)); }
    catch (e) { out.push(JSON.stringify(o) + ' ERR ' + e.constructor.name + ': ' + e.message); }
  });
});
console.log(out.join('\n'));
