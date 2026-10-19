export default class Logger {
  constructor(n) { this.n = n; }
  log(m) { console.log('[' + this.n + ']', m); }
}
