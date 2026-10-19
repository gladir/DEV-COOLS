var u = new URL('https://user:pw@Example.com:8080/a/b/../c?x=1&y=2#frag');
console.log(u.href, u.origin, u.protocol, u.username, u.password, u.host, u.hostname, u.port, u.pathname, u.search, u.hash);
console.log(new URL('../x?q=1', 'http://h.com/a/b/c').href, new URL('/abs', 'http://h.com/a/b').href, new URL('http://h.com:80/').href, new URL('file:///C:/a/b.txt').pathname);
console.log(u.searchParams.get('x'), [...u.searchParams.keys()].join(), String(u.searchParams));
u.searchParams.append('z', 'a b&c'); console.log(u.search, u.href);
var sp = new URLSearchParams({ a: '1', b: 'é ü' }); sp.append('a', '2'); console.log(sp.toString(), sp.getAll('a'), sp.has('b'), sp.size);
sp.sort(); sp.delete('b'); console.log(String(sp), JSON.stringify(new URL('http://x.y/')), URL.canParse('nope'), URL.canParse('a:b'));
try { new URL('bad'); } catch (e) { console.log(e.name, e.message, e.code); }
console.log(btoa('Hello, World!'), atob('SGVsbG8sIFdvcmxkIQ=='), btoa(''), atob('YQ'));
var ac = new AbortController(); var log = [];
ac.signal.addEventListener('abort', function (e) { log.push(e.type + ':' + ac.signal.aborted + ':' + e.target.reason.name); });
ac.abort(); ac.abort(); console.log(log, ac.signal.aborted, ac.signal.reason.message, ac.signal.reason instanceof DOMException);
var et = new EventTarget(); var n = 0; et.addEventListener('t', function f(e) { n += e.detail; }, { once: true });
et.dispatchEvent(new CustomEvent('t', { detail: 5 })); et.dispatchEvent(new CustomEvent('t', { detail: 5 })); console.log(n);
try { AbortSignal.abort().throwIfAborted(); } catch (e) { console.log(e.name, e.code); }
fetch('http://x').catch(function (e) { console.log('fetch', e.name, e.message); });
