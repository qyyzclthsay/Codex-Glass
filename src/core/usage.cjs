const { identity, validDate } = require('./model.cjs');
const count = n => Number.isSafeInteger(n) && n >= 0 ? n : null;
function normalizeUsage(raw, now = Date.now()) {
  if (!raw || typeof raw !== 'object') throw Object.assign(new Error('invalidReply'), {code:'invalidReply'});
  const days = new Map(), conflicts = new Set();
  let incomplete = false;
  const available = Array.isArray(raw.dailyUsageBuckets);
  for (const row of available ? raw.dailyUsageBuckets : []) {
    if (!validDate(row?.startDate) || count(row?.tokens) === null) { incomplete = true; continue; }
    if (days.has(row.startDate) && days.get(row.startDate) !== row.tokens) {
      conflicts.add(row.startDate); incomplete = true;
    }
    days.set(row.startDate, row.tokens);
  }
  for (const date of conflicts) days.delete(date);
  return {
    days: available ? [...days].sort(([a],[b]) => a.localeCompare(b)).map(([date,tokens]) => ({date,tokens})) : null,
    lifetimeTokens: count(raw.summary?.lifetimeTokens),
    observedAt: now,
    incomplete,
  };
}
class UsageReader {
  constructor(rpc, context, now = Date.now) { this.rpc = rpc; this.context = context; this.now = now; this.generation = 0; }
  invalidate() { this.generation++; this.cache = null; this.pending = null; }
  read() {
    const context = this.context(), generation = this.generation;
    const current = () => generation === this.generation && this.context().id === context.id && this.context().fingerprint === context.fingerprint;
    if (!context.id || !context.fingerprint) return Promise.reject(Object.assign(new Error('signInRequired'), {code:'signInRequired'}));
    if (this.pending) return this.pending;
    const promise = (async () => {
      const before = await this.rpc.call('account/read', {refreshToken:false});
      if (before.account?.type !== 'chatgpt' || identity(before.account) !== context.fingerprint || !current()) throw Object.assign(new Error('accountChanged'), {code:'accountChanged'});
      if (this.cache?.id === context.id && this.now() - this.cache.data.observedAt < 60000) return this.cache.data;
      const raw = await this.rpc.call('account/usage/read');
      const after = await this.rpc.call('account/read', {refreshToken:false});
      if (after.account?.type !== 'chatgpt' || identity(after.account) !== context.fingerprint || !current()) throw Object.assign(new Error('accountChanged'), {code:'accountChanged'});
      const data = normalizeUsage(raw, this.now());
      this.cache = {id:context.id,data};
      return data;
    })();
    this.pending = promise;
    promise.finally(() => { if(this.pending === promise) this.pending = null; }).catch(() => {});
    return promise;
  }
}
module.exports = { normalizeUsage, UsageReader };
