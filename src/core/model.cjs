const { createHash } = require("node:crypto");

const numeric = (value) =>
  typeof value === "number" && Number.isFinite(value) ? value : null;
function identity(account, limits) {
  const raw =
    limits?.accountId || account?.accountId || account?.id || account?.email;
  return raw ? createHash("sha256").update(String(raw)).digest("hex") : null;
}
function normalize(account, result, now = Date.now()) {
  const groups =
    result.rateLimitsByLimitId ??
    (result.rateLimits ? { codex: result.rateLimits } : {});
  const windows = [];
  let plan = typeof account?.planType === "string" ? account.planType : null;
  for (const [id, group] of Object.entries(groups).sort(([a], [b]) =>
    a === "codex" ? -1 : b === "codex" ? 1 : a.localeCompare(b),
  )) {
    if (!group || typeof group !== "object") continue;
    plan ||= typeof group.planType === "string" ? group.planType : null;
    for (const slot of ["primary", "secondary"]) {
      const raw = group[slot];
      if (!raw || numeric(raw.usedPercent) === null) continue;
      const minutes = numeric(raw.windowDurationMins);
      windows.push({
        id: `${id}:${slot}`,
        group: id,
        scope: group.limitName || (id === "codex" ? null : id),
        model: typeof group.normalModelSlug === "string" ? group.normalModelSlug : null,
        minutes,
        used: raw.usedPercent,
        remaining: Math.max(0, Math.min(100, 100 - raw.usedPercent)),
        resetsAt: numeric(raw.resetsAt) === null ? null : raw.resetsAt * 1000,
        // Group-level refusal is not evidence that a particular window is exhausted.
        groupBlocked: Boolean(
          group.spendControlReached || group.rateLimitReachedType,
        ),
      });
    }
  }
  const reset = result.rateLimitResetCredits;
  const count = numeric(reset?.availableCount);
  const expirations = Array.isArray(reset?.credits)
    ? reset.credits
        .filter(
          (c) => c.status === "available" && numeric(c.expiresAt) !== null,
        )
        .map((c) => c.expiresAt * 1000)
        .filter((t) => t > now)
    : [];
  return {
    identity: identity(account, result),
    plan,
    windows,
    resets: {
      count: count === null ? null : Math.max(0, Math.trunc(count)),
      expiresAt: expirations.length ? Math.min(...expirations) : null,
    },
    allowed:
      typeof result.ordinaryUsageAllowed === "boolean"
        ? result.ordinaryUsageAllowed
        : null,
    observedAt: now,
  };
}
function validCache(snapshot, accountIdentity, now = Date.now()) {
  if (
    !snapshot ||
    !accountIdentity ||
    snapshot.identity !== accountIdentity ||
    !Array.isArray(snapshot.windows) ||
    !Number.isFinite(snapshot.observedAt) ||
    now - snapshot.observedAt > 86400000 ||
    snapshot.observedAt > now + 60000
  )
    return null;
  const windows = snapshot.windows.filter(
    (w) =>
      w &&
      Number.isFinite(w.remaining) &&
      (!w.resetsAt || (Number.isFinite(w.resetsAt) && w.resetsAt > now)),
  );
  if (!windows.length) return null;
  // Never claim that a consumable reset credit count from an old request is current.
  return { ...snapshot, windows, resets: { count: null, expiresAt: null } };
}
function planLabel(raw) {
  // Display alias observed in Codex; entitlements still come only from quota windows.
  return (
    {
      free: "Free",
      go: "Go",
      plus: "Plus",
      pro: "Pro",
      prolite: "Pro",
      team: "Team",
      business: "Business",
      enterprise: "Enterprise",
      edu: "Edu",
    }[raw?.toLowerCase()] ||
    raw ||
    "—"
  );
}
function validDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value || "")) return false;
  const date = new Date(value + "T12:00:00Z");
  return Number.isFinite(+date) && date.toISOString().slice(0, 10) === value;
}
function daysUntil(value, now = new Date()) {
  if (!validDate(value)) return null;
  const [y, m, d] = value.split("-").map(Number);
  return Math.round(
    (Date.UTC(y, m - 1, d) -
      Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())) /
      86400000,
  );
}
function collectAlerts(
  snapshot,
  membership,
  memory,
  now = Date.now(),
  threshold = 20,
) {
  const alerts = [];
  if (!snapshot?.identity || now - snapshot.observedAt > 300000) return alerts;
  for (const w of snapshot.windows) {
    if (!w.resetsAt || w.resetsAt <= now || w.remaining > threshold) continue;
    const level = w.remaining <= 5 ? 5 : w.remaining <= 10 ? 10 : threshold;
    const key = `quota:${snapshot.identity}:${w.id}:${w.resetsAt}`;
    if (memory[key] === undefined || memory[key] > level) {
      memory[key] = level;
      alerts.push({
        type: "quota",
        remaining: Math.floor(w.remaining),
        minutes: w.minutes,
      });
    }
  }
  const days = daysUntil(membership?.date, new Date(now));
  if (days !== null && days >= 0 && days <= 3) {
    const key = `member:${snapshot.identity}:${membership.date}:${days}`;
    if (!memory[key]) {
      memory[key] = 1;
      alerts.push({ type: "member", days, kind: membership.kind });
    }
  }
  const expiry = snapshot.resets?.expiresAt;
  if (
    snapshot.resets?.count > 0 &&
    expiry &&
    expiry > now &&
    expiry - now <= 3 * 86400000
  ) {
    const key = `credit:${snapshot.identity}:${expiry}:${new Date(now).toISOString().slice(0, 10)}`;
    if (!memory[key]) {
      memory[key] = 1;
      alerts.push({ type: "credit" });
    }
  }
  return alerts;
}
module.exports = {
  normalize,
  identity,
  validCache,
  planLabel,
  validDate,
  daysUntil,
  collectAlerts,
};
