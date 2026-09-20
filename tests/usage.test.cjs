const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeUsage, UsageReader } = require('../src/core/usage.cjs');
const { dailySeries } = require('../src/core/presentation.js');
const { identity } = require('../src/core/model.cjs');
const account = {type:'chatgpt',email:'fixture@example.invalid'};
const response = {summary:{lifetimeTokens:300},dailyUsageBuckets:[{startDate:'2026-09-18',tokens:100},{startDate:'2026-09-19',tokens:0}],threadUsage:[{private:'discard'}]};
test('daily usage retains reported zero, sorts dates, and drops unrelated thread details', () => {
  const data = normalizeUsage(response,123);
  assert.deepEqual(data.days,[{date:'2026-09-18',tokens:100},{date:'2026-09-19',tokens:0}]);
  assert.equal(data.lifetimeTokens,300);
  assert.equal(data.observedAt,123);
  assert.equal('threadUsage' in data,false);
});
test('missing daily data is distinct from zero usage', () => {
  assert.equal(normalizeUsage({dailyUsageBuckets:null}).days,null);
  assert.deepEqual(normalizeUsage({dailyUsageBuckets:[]}).days,[]);
  assert.equal(normalizeUsage({summary:{lifetimeTokens:'300'}}).lifetimeTokens,null);
});
test('invalid counts and conflicting duplicates cannot inflate daily totals', () => {
  const data=normalizeUsage({dailyUsageBuckets:[
    {startDate:'2026-02-30',tokens:10},{startDate:'2026-09-18',tokens:-1},
    {startDate:'2026-09-19',tokens:100},{startDate:'2026-09-19',tokens:100},
    {startDate:'2026-09-20',tokens:2},{startDate:'2026-09-20',tokens:3},
  ]});
  assert.deepEqual(data.days,[{date:'2026-09-19',tokens:100}]);
  assert.equal(data.incomplete,true);
});
test('calendar series preserves missing days and crosses month boundaries without shifting buckets', () => {
  const rows=dailySeries([{date:'2026-03-01',tokens:0},{date:'2026-02-28',tokens:15}],7,'2026-03-02');
  assert.equal(rows.length,7);
  assert.deepEqual(rows.slice(0,3),[{date:'2026-03-02',tokens:null},{date:'2026-03-01',tokens:0},{date:'2026-02-28',tokens:15}]);
  assert.equal(dailySeries([],30,'2026-01-02').at(-1).date,'2025-12-04');
});
function readerFixture() {
  let calls=0, now=100000;
  let context={id:'account-a',fingerprint:identity(account)};
  const rpc={call:async method=>{ if(method==='account/read')return {account}; calls++; return response; }};
  const reader=new UsageReader(rpc,()=>context,()=>now);
  return {reader,rpc,calls:()=>calls,setContext:value=>context=value,advance:()=>now+=61000};
}
test('daily requests coalesce, cache briefly, and refresh after expiry', async () => {
  const f=readerFixture();
  const [a,b]=await Promise.all([f.reader.read(),f.reader.read()]);
  assert.equal(a,b); assert.equal(f.calls(),1);
  await f.reader.read(); assert.equal(f.calls(),1);
  f.advance(); await f.reader.read(); assert.equal(f.calls(),2);
});
test('a changed account cannot receive the cached token history', async () => {
  const f=readerFixture(); await f.reader.read();
  f.rpc.call=async()=>({account:{type:'chatgpt',email:'other@example.invalid'}});
  await assert.rejects(f.reader.read(),error=>error.code==='accountChanged');
});
test('account invalidation during a request discards the result', async () => {
  const f=readerFixture(); let release;
  f.rpc.call=async method=> method==='account/read' ? {account} : new Promise(resolve=>{release=resolve;});
  const pending=f.reader.read();
  await new Promise(resolve=>setImmediate(resolve));
  f.reader.invalidate(); release(response);
  await assert.rejects(pending,error=>error.code==='accountChanged');
  assert.equal(f.reader.cache,null);
});
