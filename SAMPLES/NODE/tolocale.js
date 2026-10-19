var n = 1234567.891;
console.log(n.toLocaleString(), (0.5).toLocaleString(), (1e21).toLocaleString(), (-5).toLocaleString(), (12).toLocaleString('de-DE'), n.toLocaleString('en-US', { maximumFractionDigits: 0 }));
var d = new Date(Date.UTC(2024, 0, 5, 14, 3, 9));
console.log(d.toString(), d.getHours(), d.getTimezoneOffset(), d.toLocaleString(), d.toLocaleDateString(), d.toLocaleTimeString());
console.log(new Date(2024, 5, 15, 10, 30).toISOString(), new Date('2024-06-15T10:30:00').toISOString(), new Date('2024-06-15').toISOString());
console.log(new Date(2024, 0, 31).getMonth(), (function(){var x=new Date(2024,0,31);x.setMonth(1);return x.toISOString()})());
