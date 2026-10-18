var __Promise, __mq, __mqh, __ticks, __timers, __timer_seq, __imm, __unhandled, __Timeout;
function __job(fn) {
  __mq = __mq || [];
  __mq.push(fn);
}
function __drain() {
  __mq = __mq || [];
  __ticks = __ticks || [];
  var again = true;
  while (again) {
    again = false;
    while (__ticks.length > 0) {
      var t = __ticks.shift();
      t.fn.apply(undefined, t.args);
      again = true;
    }
    if (__mq.length > 0) {
      var jobs = __mq;
      __mq = [];
      for (var i = 0; i < jobs.length; i++) {
        jobs[i]();
        if (__ticks.length > 0) {
          for (var j = jobs.length - 1; j > i; j--) __mq.unshift(jobs[j]);
          break;
        }
      }
      again = true;
    }
  }
  __check_unhandled();
}
function __check_unhandled() {
  if (!__unhandled || __unhandled.length === 0) return;
  var list = __unhandled;
  __unhandled = [];
  for (var i = 0; i < list.length; i++) {
    var p = list[i];
    if (!p['\x01h']) {
      var e = p['\x01v'];
      var msg = e instanceof Error ? (typeof e.stack === 'string' ? e.stack : String(e)) : __i_insp(e, 2);
      __write(2, 'Uncaught ' + msg + '\n');
      process.exit(1);
    }
  }
}
function __settle(p, state, v) {
  if (p['\x01s'] !== 0) return;
  p['\x01s'] = state;
  p['\x01v'] = v;
  var q = p['\x01q'];
  p['\x01q'] = null;
  if (state === 2 && q.length === 0 && !p['\x01h']) {
    __unhandled = __unhandled || [];
    __unhandled.push(p);
  }
  for (var i = 0; i < q.length; i++) __react(p, q[i]);
}
function __react(p, r) {
  __job(function () {
    var h = p['\x01s'] === 1 ? r.f : r.r;
    if (typeof h !== 'function') {
      if (p['\x01s'] === 1) __resolveP(r.p, p['\x01v']);
      else __settle(r.p, 2, p['\x01v']);
      return;
    }
    var out;
    try { out = h(p['\x01v']); } catch (e) { __settle(r.p, 2, e); return; }
    __resolveP(r.p, out);
  });
}
function __resolveP(p, v) {
  if (v === p) { __settle(p, 2, new TypeError('Chaining cycle detected for promise #<Promise>')); return; }
  if (v !== null && (typeof v === 'object' || typeof v === 'function')) {
    var then;
    try { then = v.then; } catch (e) { __settle(p, 2, e); return; }
    if (typeof then === 'function') {
      __job(function () {
        var done = false;
        try {
          then.call(v, function (x) { if (!done) { done = true; __resolveP(p, x); } },
                        function (e) { if (!done) { done = true; __settle(p, 2, e); } });
        } catch (e) { if (!done) { done = true; __settle(p, 2, e); } }
      });
      return;
    }
  }
  __settle(p, 1, v);
}
function __newP() {
  var p = Object.create(__Promise.prototype);
  p['\x01s'] = 0;
  p['\x01v'] = undefined;
  p['\x01q'] = [];
  p['\x01h'] = false;
  return p;
}
function __i_async(g) {
  var p = __newP();
  function step(mode, v) {
    var r;
    try { r = __gen_resume(g, mode, v); } catch (e) { __settle(p, 2, e); return; }
    if (__gen_done(g)) { __resolveP(p, r); return; }
    var w = r instanceof __Promise ? r : __Promise.resolve(r);
    w.then(function (x) { step(0, x); }, function (e) { step(1, e); });
  }
  step(0, undefined);
  return p;
}
function __timer_add(fn, ms, args, interval) {
  __timers = __timers || [];
  __timer_seq = (__timer_seq || 0) + 1;
  ms = Number(ms);
  if (!(ms >= 1)) ms = 1;
  if (ms > 2147483647) ms = 1;
  var t = Object.create(__Timeout.prototype);
  t['\x01id'] = __timer_seq;
  t['\x01t'] = Date.now() + ms;
  t['\x01ms'] = ms;
  t['\x01iv'] = interval;
  t['\x01fn'] = fn;
  t['\x01args'] = args;
  __timers.push(t);
  return t;
}
function __setTimeout(fn, ms, ...args) {
  if (typeof fn !== 'function') throw new TypeError('The "callback" argument must be of type function. Received ' + __i_insp(fn, 0));
  return __timer_add(fn, ms, args, false);
}
function __setInterval(fn, ms, ...args) {
  if (typeof fn !== 'function') throw new TypeError('The "callback" argument must be of type function. Received ' + __i_insp(fn, 0));
  return __timer_add(fn, ms, args, true);
}
function __setImmediate(fn, ...args) {
  __imm = __imm || [];
  var t = { fn: fn, args: args, cleared: false };
  __imm.push(t);
  return t;
}
function __clearTimeout(t) {
  if (!__timers) return;
  for (var i = 0; i < __timers.length; i++) {
    if (__timers[i] === t || (typeof t === 'number' && __timers[i]['\x01id'] === t)) {
      __timers.splice(i, 1);
      return;
    }
  }
}
function __clearInterval(t) {
  __clearTimeout(t);
}
function __clearImmediate(t) {
  if (t) t.cleared = true;
}
function __queueMicrotask(fn) {
  __job(fn);
}
function __i_run() {
  __drain();
  while (true) {
    var ran = false;
    if (__timers && __timers.length > 0) {
      var now = Date.now();
      var due = [];
      for (var i = 0; i < __timers.length; i++) {
        if (__timers[i]['\x01t'] <= now + 1) due.push(__timers[i]);
      }
      due.sort(function (a, b) { return a['\x01t'] - b['\x01t'] || a['\x01id'] - b['\x01id']; });
      for (var j = 0; j < due.length; j++) {
        var t = due[j];
        var idx = __timers.indexOf(t);
        if (idx < 0) continue;
        if (t['\x01iv']) t['\x01t'] = Date.now() + t['\x01ms'];
        else __timers.splice(idx, 1);
        t['\x01fn'].apply(undefined, t['\x01args']);
        __drain();
        ran = true;
      }
    }
    if (__imm && __imm.length > 0) {
      var im = __imm;
      __imm = [];
      for (var k = 0; k < im.length; k++) {
        if (!im[k].cleared) im[k].fn.apply(undefined, im[k].args);
        __drain();
      }
      ran = true;
    }
    if (ran) continue;
    if (!__timers || __timers.length === 0) break;
    var next = __timers[0]['\x01t'];
    for (var m = 1; m < __timers.length; m++) if (__timers[m]['\x01t'] < next) next = __timers[m]['\x01t'];
    var wait = next - Date.now();
    if (wait > 0) __sleep(wait);
  }
}
function __init_async() {
  __Promise = class Promise {
    constructor(executor) {
      if (typeof executor !== 'function') throw new TypeError('Promise resolver ' + __i_insp(executor, 0) + ' is not a function');
      this['\x01s'] = 0;
      this['\x01v'] = undefined;
      this['\x01q'] = [];
      this['\x01h'] = false;
      var self = this;
      var done = false;
      try {
        executor(function (v) { if (!done) { done = true; __resolveP(self, v); } },
                 function (e) { if (!done) { done = true; __settle(self, 2, e); } });
      } catch (e) {
        if (!done) { done = true; __settle(self, 2, e); }
      }
    }
    then(f, r) {
      var p2 = __newP();
      this['\x01h'] = true;
      var rec = { f: f, r: r, p: p2 };
      if (this['\x01s'] === 0) this['\x01q'].push(rec);
      else __react(this, rec);
      return p2;
    }
    catch(r) { return this.then(undefined, r); }
    finally(f) {
      if (typeof f !== 'function') return this.then(f, f);
      return this.then(
        function (v) { return __Promise.resolve(f()).then(function () { return v; }); },
        function (e) { return __Promise.resolve(f()).then(function () { throw e; }); });
    }
    static resolve(v) {
      if (v instanceof __Promise) return v;
      var p = __newP();
      __resolveP(p, v);
      return p;
    }
    static reject(e) {
      var p = __newP();
      __settle(p, 2, e);
      return p;
    }
    static withResolvers() {
      var res, rej;
      var promise = new __Promise(function (a, b) { res = a; rej = b; });
      return { promise: promise, resolve: res, reject: rej };
    }
    static all(it) {
      return new __Promise(function (resolve, reject) {
        var items = Array.from(it);
        var out = [];
        var left = items.length;
        if (left === 0) { resolve(out); return; }
        items.forEach(function (x, i) {
          out[i] = undefined;
          __Promise.resolve(x).then(function (v) {
            out[i] = v;
            if (--left === 0) resolve(out);
          }, reject);
        });
      });
    }
    static allSettled(it) {
      return new __Promise(function (resolve) {
        var items = Array.from(it);
        var out = [];
        var left = items.length;
        if (left === 0) { resolve(out); return; }
        items.forEach(function (x, i) {
          out[i] = undefined;
          __Promise.resolve(x).then(function (v) {
            out[i] = { status: 'fulfilled', value: v };
            if (--left === 0) resolve(out);
          }, function (e) {
            out[i] = { status: 'rejected', reason: e };
            if (--left === 0) resolve(out);
          });
        });
      });
    }
    static race(it) {
      return new __Promise(function (resolve, reject) {
        Array.from(it).forEach(function (x) { __Promise.resolve(x).then(resolve, reject); });
      });
    }
    static any(it) {
      return new __Promise(function (resolve, reject) {
        var items = Array.from(it);
        var errs = [];
        var left = items.length;
        if (left === 0) { reject(new __AggregateError([], 'All promises were rejected')); return; }
        items.forEach(function (x, i) {
          errs[i] = undefined;
          __Promise.resolve(x).then(resolve, function (e) {
            errs[i] = e;
            if (--left === 0) reject(new __AggregateError(errs, 'All promises were rejected'));
          });
        });
      });
    }
  };
  __Promise.prototype['\x01Symbol.toStringTag\x02'] = 'Promise';
  __Timeout = class Timeout {
    ref() { return this; }
    unref() { return this; }
    hasRef() { return true; }
    refresh() { return this; }
    close() { __clearTimeout(this); return this; }
  };
  process.nextTick = function (fn, ...args) {
    __ticks = __ticks || [];
    __ticks.push({ fn: fn, args: args });
  };
}
