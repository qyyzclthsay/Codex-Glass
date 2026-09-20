const test = require('node:test');
const assert = require('node:assert/strict');
const { selectWindow, elapsed } = require('../src/core/presentation.js');
const { normalize } = require('../src/core/model.cjs');
const { sanitize } = require('../src/core/storage.cjs');
const now = 100000000;
const five = { id: 'five', group: 'codex', minutes: 300, remaining: 30, resetsAt: now + 300000 };
const week = { id: 'week', group: 'codex', minutes: 10080, remaining: 77, resetsAt: now + 500000 };
const reserve = { ...week, id: 'reserve', group: 'base_model_inference', remaining: 1 };
test('ring chooses the lowest main allowance, excluding model pools', () => {
  assert.equal(selectWindow([reserve, week, five], 'auto', now).id, 'five');
  assert.equal(selectWindow([reserve], 'auto', now), null);
});
test('pinned weekly window falls back safely when missing or expired', () => {
  assert.equal(selectWindow([five, week], 'week', now).id, 'week');
  assert.equal(selectWindow([five], 'week', now).id, 'five');
  assert.equal(selectWindow([five, { ...week, resetsAt: now }], 'week', now).id, 'five');
  assert.equal(selectWindow([{ ...five, resetsAt: now }], 'auto', now), null);
});
test('valid zero remains zero and unknown values do not become full rings', () => {
  assert.equal(selectWindow([{ ...five, remaining: 0 }], 'auto', now).remaining, 0);
  assert.equal(selectWindow([{ ...five, remaining: null }], 'auto', now), null);
});
test('elapsed arc uses duration and never invents a missing start time', () => {
  assert.equal(elapsed({ minutes: 10, resetsAt: now + 300000 }, now), .5);
  assert.equal(elapsed({ minutes: null, resetsAt: now + 300000 }, now), null);
  assert.equal(elapsed({ minutes: 10, resetsAt: now - 1 }, now), null);
});
test('model metadata remains attached to its independent pool', () => {
  const s = normalize({}, { rateLimitsByLimitId: { base_model_inference: { limitName: 'gpt-reserve', normalModelSlug: 'example-model', primary: { usedPercent: 0 } } } });
  assert.equal(s.windows[0].model, 'example-model');
  assert.equal(s.windows[0].scope, 'gpt-reserve');
});
test('new appearance preferences persist while unknown values are rejected', () => {
  assert.equal(sanitize({accentColor:'#AB12EF'}).accentColor, '#ab12ef');
  assert.equal(sanitize({accentColor:'red; display:none'}).accentColor, null);
  assert.equal(sanitize({accentColor:null}).accentColor, null);
  assert.equal(sanitize({ material: 'clear', ringWindow: 'week', elapsedArc: true }).material, undefined);
  assert.equal(sanitize({ ringWindow: 'week' }).ringWindow, 'week');
  assert.equal(sanitize({ material: 'script', ringWindow: 'reserve', elapsedArc: 'true' }).material, undefined);
  assert.equal(sanitize({ ringWindow: 'reserve' }).ringWindow, 'auto');
  assert.equal(sanitize({ elapsedArc: 'true' }).elapsedArc, false);
});
