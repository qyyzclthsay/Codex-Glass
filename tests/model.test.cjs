const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalize,
  validCache,
  identity,
  planLabel,
  validDate,
  daysUntil,
  collectAlerts,
} = require("../src/core/model.cjs");
const { sanitize } = require("../src/core/storage.cjs");
const account = { email: "fixture@example.invalid", planType: "plus" };
const now = Date.UTC(2026, 8, 19, 5);
const week = {
  usedPercent: 18,
  windowDurationMins: 10080,
  resetsAt: (now + 86400000) / 1000,
};
const snapshot = () =>
  normalize(
    account,
    {
      rateLimits: { primary: week },
      rateLimitResetCredits: { availableCount: 1 },
    },
    now,
  );

test("weekly primary is not incorrectly labeled as five hours", () => {
  const s = snapshot();
  assert.equal(s.windows.length, 1);
  assert.equal(s.windows[0].minutes, 10080);
  assert.equal(s.windows[0].remaining, 82);
});
test("multiple quota groups retain their own identities and blocked flags", () => {
  const s = normalize(
    account,
    {
      ordinaryUsageAllowed: false,
      rateLimitsByLimitId: {
        codex: { primary: week },
        model: {
          primary: { ...week, windowDurationMins: 300 },
          rateLimitReachedType: "usage",
        },
      },
    },
    now,
  );
  assert.equal(s.allowed, false);
  assert.equal(s.windows[0].groupBlocked, false);
  assert.equal(s.windows[1].groupBlocked, true);
  assert.notEqual(s.windows[0].id, s.windows[1].id);
});
test("unknown percentages stay absent; missing reset credits stay unknown", () => {
  const s = normalize(
    account,
    {
      rateLimits: {
        primary: { usedPercent: null },
        secondary: { usedPercent: "10" },
      },
    },
    now,
  );
  assert.deepEqual(s.windows, []);
  assert.equal(s.resets.count, null);
});
test("reported zero credits is different from unavailable credits", () => {
  assert.equal(
    normalize(account, { rateLimitResetCredits: { availableCount: 0 } }, now)
      .resets.count,
    0,
  );
  assert.equal(
    normalize(account, { rateLimitResetCredits: { credits: [] } }, now).resets
      .count,
    null,
  );
});
test("only available future credits participate in expiry date", () => {
  const s = normalize(
    account,
    {
      rateLimitResetCredits: {
        availableCount: 5,
        credits: [
          { status: "available", expiresAt: now / 1000 - 1 },
          { status: "used", expiresAt: now / 1000 + 1 },
          { status: "available", expiresAt: now / 1000 + 1000 },
        ],
      },
    },
    now,
  );
  assert.equal(s.resets.count, 5);
  assert.equal(s.resets.expiresAt, now + 1000000);
});
test("cached readings cannot cross account identity", () => {
  const s = snapshot();
  assert.equal(
    validCache(s, identity({ email: "another@example.invalid" }), now),
    null,
  );
  assert.equal(validCache(s, null, now), null);
  assert.equal(validCache(s, s.identity, now).resets.count, null);
});
test("cache drops reset windows and snapshots older than 24 hours", () => {
  const s = snapshot();
  assert.equal(validCache(s, s.identity, now + 86400001), null);
  s.windows.push({ ...s.windows[0], id: "future", resetsAt: now + 200000000 });
  assert.equal(validCache(s, s.identity, now + 86400000 - 1).windows.length, 2);
  s.windows[0].resetsAt = now - 1;
  assert.equal(validCache(s, s.identity, now).windows.length, 1);
});
test("percentages are clamped for display, not used to invent allowed status", () => {
  const s = normalize(
    account,
    {
      rateLimits: {
        primary: { ...week, usedPercent: 150 },
        secondary: { ...week, usedPercent: -5 },
      },
    },
    now,
  );
  assert.equal(s.windows[0].remaining, 0);
  assert.equal(s.windows[1].remaining, 100);
  assert.equal(s.allowed, null);
});
test("known aliases display membership; unknown plans remain visible", () => {
  assert.equal(planLabel("plus"), "Plus");
  assert.equal(planLabel("prolite"), "Pro");
  assert.equal(planLabel("future-tier"), "future-tier");
});
test("damaged local settings and cache records do not crash the application", () => {
  assert.equal(sanitize(null).language, "zh");
  const s = snapshot();
  s.windows = [null, { remaining: 10, resetsAt: "bad" }];
  assert.equal(validCache(s, s.identity, now), null);
  assert.equal(
    normalize({ planType: {} }, { rateLimits: { planType: 42 } }, now).plan,
    null,
  );
});
test("calendar validation rejects impossible dates", () => {
  assert.equal(validDate("2026-02-30"), false);
  assert.equal(validDate("2028-02-29"), true);
  assert.equal(validDate("tomorrow"), false);
});
test("membership uses calendar days instead of rounding remaining hours", () => {
  assert.equal(daysUntil("2026-09-20", new Date(2026, 8, 19, 23, 59)), 1);
});
test("settings keep account dates isolated and discard unsupported inputs", () => {
  const id = identity(account);
  const s = sanitize({
    language: "de",
    theme: "script",
    refreshSeconds: 1,
    membership: {
      [id]: { date: "2026-10-01", kind: "renewal" },
      wrong: { date: "2026-10-01", kind: "expiry" },
    },
    startup: "true",
  });
  assert.equal(s.language, "zh");
  assert.equal(s.theme, "light");
  assert.equal(s.refreshSeconds, 120);
  assert.equal(s.startup, false);
  assert.equal(Object.keys(s.membership).length, 1);
});
test("alerts deduplicate within a window and escalate only when lower", () => {
  const s = snapshot(),
    memory = {};
  s.windows[0].remaining = 18;
  assert.equal(collectAlerts(s, null, memory, now).length, 1);
  assert.equal(collectAlerts(s, null, memory, now).length, 0);
  s.windows[0].remaining = 9;
  assert.equal(collectAlerts(s, null, memory, now).length, 1);
  s.windows[0].remaining = 12;
  assert.equal(collectAlerts(s, null, memory, now).length, 0);
  s.windows[0].resetsAt += 86400000;
  assert.equal(collectAlerts(s, null, memory, now).length, 1);
});
test("expired and stale snapshots never trigger quota alerts", () => {
  const s = snapshot();
  s.windows[0].remaining = 1;
  assert.equal(collectAlerts(s, null, {}, now + 600000).length, 0);
  s.windows[0].resetsAt = now - 1;
  assert.equal(collectAlerts(s, null, {}, now).length, 0);
});
