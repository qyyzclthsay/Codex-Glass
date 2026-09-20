const fs = require("node:fs");
const path = require("node:path");
const { validDate } = require("./model.cjs");
const { mainSize } = require('./window-size.cjs');
const defaults = {
  language: "zh",
  theme: "light",
  accentColor: null,
  pinned: true,
  compact: false,
  ringWindow: "auto",
  elapsedArc: false,
  startup: false,
  notifications: false,
  refreshSeconds: 120,
  membership: {},
  position: null,
  mainSize: null,
};
function sanitize(raw = {}) {
  if (!raw || typeof raw !== "object") raw = {};
  const value = { ...defaults };
  value.mainSize = mainSize(raw.mainSize);
  for (const k of ["pinned", "compact", "startup", "notifications", "elapsedArc"])
    if (typeof raw[k] === "boolean") value[k] = raw[k];
  if (["zh", "en"].includes(raw.language)) value.language = raw.language;
  if (["light", "dark", "system"].includes(raw.theme)) value.theme = raw.theme;
  if (typeof raw.accentColor === 'string' && /^#[0-9a-f]{6}$/i.test(raw.accentColor)) value.accentColor = raw.accentColor.toLowerCase();
  if (["auto", "five", "week"].includes(raw.ringWindow)) value.ringWindow = raw.ringWindow;
  if ([60, 120, 300, 600].includes(raw.refreshSeconds))
    value.refreshSeconds = raw.refreshSeconds;
  if (
    raw.position &&
    Number.isFinite(raw.position.x) &&
    Number.isFinite(raw.position.y)
  )
    value.position = {
      x: Math.round(raw.position.x),
      y: Math.round(raw.position.y),
    };
  value.membership = {};
  if (raw.membership && typeof raw.membership === "object")
    for (const [id, m] of Object.entries(raw.membership)) {
      if (
        /^[a-f0-9]{64}$/.test(id) &&
        validDate(m?.date) &&
        ["renewal", "expiry"].includes(m.kind)
      )
        value.membership[id] = { date: m.date, kind: m.kind };
    }
  return value;
}
class Storage {
  constructor(directory) {
    this.directory = directory;
    fs.mkdirSync(directory, { recursive: true });
  }
  read(name, fallback) {
    try {
      return JSON.parse(
        fs.readFileSync(path.join(this.directory, name + ".json"), "utf8"),
      );
    } catch {
      return fallback;
    }
  }
  write(name, value) {
    const target = path.join(this.directory, name + ".json");
    fs.writeFileSync(target + ".tmp", JSON.stringify(value, null, 2), {
      mode: 0o600,
    });
    fs.renameSync(target + ".tmp", target);
  }
}
module.exports = { Storage, sanitize, defaults };
