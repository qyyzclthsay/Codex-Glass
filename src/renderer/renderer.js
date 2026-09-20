const root = document.getElementById("app");
let state,
  view = "widget",
  lastHeight = 0,
  lastWidth = 0,
  lastMode = null,
  dragState = null,
  resizeState = null,
  suppressClick = false,
  formAccount = null;
const api = window.glass;
let dailyOpen = false, dailyRange = 7, dailyData = null, dailyError = null, dailyLoading = false, dailyGeneration = 0;
const escapeHTML = (value) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (char) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        char
      ],
  );
const t = (key) =>
  window.messages[state?.settings.language || "zh"][key] ?? key;
const icons = {
  grid: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  pin: '<path d="m9 3 6 0-1 6 4 4v2h-5v6l-2-2v-4H6v-2l4-4z"/>',
  settings:
    '<path d="M10 2h4l.5 3 1.4.6 2.5-1.7 2.8 2.8-1.7 2.5.6 1.4 2.9.4v4l-2.9.4-.6 1.4 1.7 2.5-2.8 2.8-2.5-1.7-1.4.6-.5 3h-4l-.5-3-1.4-.6-2.5 1.7-2.8-2.8 1.7-2.5-.6-1.4L1 15v-4l2.9-.4.6-1.4L2.8 6.7l2.8-2.8 2.5 1.7L9.5 5z" transform="translate(1 0) scale(.92)"/><circle cx="12" cy="12" r="3.2"/>',
  minus: '<path d="M5 12h14"/>',
  refresh:
    '<path d="M20 7v5h-5M4 17v-5h5M6 7a7 7 0 0 1 12-1l2 3M4 15l2 3a7 7 0 0 0 12-1"/>',
  arrow: '<path d="M7 17 17 7M7 7h10v10"/>',
  clock: '<circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/>',
  bolt: '<path d="m13 2-8 12h6l-1 8 9-13h-7z"/>',
  back: '<path d="m14 6-6 6 6 6"/>',
  calendar:
    '<rect x="4" y="5" width="16" height="16" rx="3"/><path d="M8 3v4M16 3v4M4 11h16M8 15h3"/>',
  shield:
    '<path d="m12 3 8 3v6c0 4-4 7-8 9-4-2-8-5-8-9V6z"/><path d="m8 12 3 3 5-6"/>',
  compact:
    '<path d="M10 20H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5M2 8h20M8 11l4 4m-4 0h4v-4"/><rect x="15" y="14" width="7" height="7" rx="1.8"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1 1M18 18l1 1M5 19l1-1M18 6l1-1"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  chart: '<path d="M4 3v17h17M8 15V9M13 15V5M18 15v-4"/>',
  chevron: '<path d="m9 5 7 7-7 7"/>',
};
const icon = (name) =>
  `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] || icons.grid}</svg>`;
const button = (action, image, label, extra = "") =>
  `<button class="icon-button ${extra}" data-action="${action}" title="${escapeHTML(label)}" aria-label="${escapeHTML(label)}">${icon(image)}</button>`;
function formatDate(date) {
  return new Intl.DateTimeFormat(
    state.settings.language === "zh" ? "zh-CN" : "en-US",
    { month: "short", day: "numeric", year: "numeric" },
  ).format(new Date(date));
}
function label(w) {
  return w.minutes === 300
    ? t("five")
    : w.minutes === 10080
      ? t("week")
      : w.minutes
        ? `${w.minutes} ${t("minutes")}`
        : "Codex";
}
function countdown(date) {
  if (!date) return t("noReset");
  const minutes = Math.ceil((date - Date.now()) / 60000);
  if (minutes <= 0) return t("resetting");
  const days = Math.floor(minutes / 1440),
    hours = Math.floor((minutes % 1440) / 60),
    mins = minutes % 60;
  const duration = days
    ? `${days} ${t("days")} ${hours} ${t("hours")}`
    : hours
      ? `${hours} ${t("hours")} ${mins} ${t("minutes")}`
      : `${mins} ${t("minutes")}`;
  return `${duration} ${t("resetsIn")}`;
}
function age(date) {
  if (!date) return "—";
  const seconds = Math.max(0, Math.floor((Date.now() - date) / 1000));
  return seconds < 15
    ? t("justNow")
    : seconds < 60
      ? `${seconds} ${t("secondsAgo")}`
      : `${Math.floor(seconds / 60)} ${t("minutesAgo")}`;
}
function memberDays(date) {
  const [y, m, d] = date.split("-").map(Number),
    now = new Date();
  return Math.round(
    (Date.UTC(y, m - 1, d) -
      Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())) /
      86400000,
  );
}
function statusHTML() {
  const key = state.refreshing
    ? "syncing"
    : state.status === "live"
      ? "live"
      : state.status === "stale"
        ? "stale"
        : "offline";
  return `<span class="status ${state.status}"><i class="${state.refreshing ? "pulse" : ""}"></i>${t(key)}</span>`;
}
function toolbar() {
  return `<header class="toolbar drag"><div class="brand"><span class="brand-icon">${icon("grid")}</span><span>Codex <b>Glass</b></span></div><nav class="no-drag">
    <button class="language-button" data-action="language" title="中文 / English" aria-label="中文 / English">${state.settings.language === "zh" ? "EN" : "中"}</button>
    ${button("pin", "pin", t(state.settings.pinned ? "unpin" : "pin"), state.settings.pinned ? "active" : "")}
    ${button('settings', 'settings', t('settings'))}${button('compact', 'compact', t('compact'))}</nav></header>`;
}
function quota(w, index) {
  const expired = w.resetsAt && w.resetsAt <= Date.now();
  const low = w.remaining <= 10;
  return `<article class="quota ${low ? "low" : ""} ${index === 0 ? "primary" : ""}">
    <div class="quota-top"><span class="quota-name">${icon(w.minutes === 10080 ? "calendar" : "clock")}${escapeHTML(label(w))}</span>${w.scope ? `<span class="scope">${escapeHTML(w.scope)}</span>` : ""}<span class="remaining-label">${t("remaining")}</span></div>
    <div class="quota-number">${expired ? "—" : Math.floor(w.remaining)}${expired ? "" : "<span>%</span>"}<span class="quota-caption">${t("remaining")}</span></div>
    <div class="track" role="progressbar" aria-label="${escapeHTML(label(w))}" aria-valuenow="${expired ? 0 : w.remaining}" aria-valuemin="0" aria-valuemax="100"><span style="width:${expired ? 0 : w.remaining}%"></span></div>
    <div class="quota-bottom"><span title="${w.resetsAt ? escapeHTML(formatDate(w.resetsAt) + " " + new Date(w.resetsAt).toLocaleTimeString()) : ""}" data-countdown="${w.resetsAt || ""}">${countdown(w.resetsAt)}</span>${w.group === 'codex' && [300,10080].includes(w.minutes) ? `<button class="window-pin ${state.settings.ringWindow === (w.minutes === 300 ? 'five' : 'week') ? 'selected' : ''}" data-action="selectWindow" data-window="${w.minutes === 300 ? 'five' : 'week'}" title="${t('pinWindow')}">${icon('pin')}</button>` : ''}</div>
  </article>`;
}
function quotaGroups() {
  const windows = state.snapshot.windows;
  const main = windows.filter(w => w.group === 'codex');
  const other = windows.filter(w => w.group !== 'codex');
  return `<div class="quotas">${main.length ? main.map(quota).join('') : `<p class="empty">${t('noWindows')}</p>`}</div>${other.length ? `<details class="other-pools"><summary>${t('otherPools')}<span>${other.length}</span></summary><p>${t('poolHelp')}</p>${other.map(w => `<div class="pool-detail"><span>${escapeHTML(w.model || w.scope || w.group)}</span>${quota(w, 1)}</div>`).join('')}</details>` : ''}`;
}
function ringHTML() {
  const w = window.quotaPresentation.selectWindow(state.snapshot?.windows, state.settings.ringWindow);
  const remaining = w ? Math.floor(w.remaining) : null;
  const color = remaining === null ? 'unknown' : remaining <= 10 ? 'critical' : remaining <= 25 ? 'warning' : 'healthy';
  const elapsed = state.settings.elapsedArc ? window.quotaPresentation.elapsed(w) : null;
  const details = (state.snapshot?.windows || []).map(item => `${item.group === 'codex' ? 'Codex' : item.scope || item.group} · ${label(item)}: ${item.resetsAt && item.resetsAt <= Date.now() ? '—' : Math.floor(item.remaining) + '%'} ${t('remaining')} · ${countdown(item.resetsAt)}`).join('\n');
  const title = `${w ? `${label(w)} · ${t('remaining')}\n` : ''}${state.status === 'stale' ? t('stale') + '\n' : ''}${details || t('compactEmpty')}\n${t('ringHelp')}`;
  return `<section class="mini ring-widget ${color} ${state.status === 'stale' ? 'is-stale' : ''}"><button class="ring-button" data-action="expand" title="${escapeHTML(title)}" aria-label="${escapeHTML(title)}"><svg class="quota-ring" viewBox="0 0 88 88" aria-hidden="true"><circle class="ring-track" cx="44" cy="44" r="33"/><circle class="ring-fill" cx="44" cy="44" r="33" pathLength="100" stroke-dasharray="${w ? w.remaining : 0} 100" transform="rotate(-90 44 44)"/>${elapsed === null ? '' : `<circle class="elapsed-ring" cx="44" cy="44" r="40" pathLength="100" stroke-dasharray="${elapsed * 100} 100" transform="rotate(-90 44 44)"/>`}</svg><span class="ring-mark"><img src="../../assets/openai.svg" alt="OpenAI / Codex" draggable="false" width="34" height="34"></span><strong class="ring-value">${remaining === null ? '—' : remaining + '<small>%</small>'}</strong><span class="ring-period">${w ? escapeHTML(label(w)) : ''}</span>${state.demo ? '<span class="demo-ring">DEMO</span>' : ''}${state.status === 'stale' ? `<span class="ring-notice" aria-label="${t('stale')}">${icon('clock')}</span>` : ''}</button></section>`;
}
function memberHTML() {
  const member = state.settings.membership;
  if (!member)
    return `<section class="membership"><span class="member-icon">${icon("calendar")}</span><div><span class="muted small">${t("membership")}</span><p>${t("unknown")}</p></div><button class="text-button" data-action="membership">${t("setDate")} ${icon("arrow")}</button></section>`;
  const days = memberDays(member.date);
  return `<section class="membership"><span class="member-icon">${icon("calendar")}</span><div><span class="muted small">${t(member.kind)} <em>${t("manualShort")}</em></span><p>${formatDate(member.date + "T12:00:00")}</p><span class="member-count ${days <= 3 ? "warning-text" : ""}">${days < 0 ? t("datePassed") : days === 0 ? t("today") : `${days} ${t("daysLeft")}`}</span></div><button class="text-button" data-action="membership">${t("edit")}</button></section>`;
}
function dailyHTML() {
  let body = '';
  if (dailyOpen) {
    const rows = window.quotaPresentation.dailySeries(dailyData?.days, dailyRange).reverse();
    const known = rows.filter(d => d.tokens !== null);
    const total = known.length ? known.reduce((n,d) => n+d.tokens,0).toLocaleString(state.settings.language === 'zh' ? 'zh-CN' : 'en-US') : '—';
    const max = Math.max(1,...known.map(d => d.tokens));
    body = `<div class="daily-body"><div class="daily-controls"><div class="range-switch">${[7,30].map(n => `<button data-action="dailyRange" data-range="${n}" aria-pressed="${dailyRange === n}">${n}${t('dayRange')}</button>`).join('')}</div><button class="text-button" data-action="refreshDaily" ${dailyLoading ? 'disabled' : ''}>${t('dailyRefresh')}</button></div>
      ${dailyLoading ? `<p class="daily-message" role="status">${t('syncing')}</p>` : dailyError ? `<p class="daily-message" role="status">${escapeHTML(t(dailyError))}</p>` : !dailyData?.days?.length ? `<p class="daily-message">${t('noDaily')}</p>` : `<div class="daily-total"><span>${t('periodTokens')}</span><strong>${total}</strong></div><div class="daily-chart" aria-label="${t('dailyTokens')}"><div class="daily-bars">${rows.map(d => {
        const value = d.tokens === null ? '—' : d.tokens.toLocaleString(state.settings.language === 'zh' ? 'zh-CN' : 'en-US');
        const description = `${d.date} · ${value}${d.tokens === null ? '' : ' tokens'}`;
        return `<button class="daily-bar ${d.tokens === null ? 'missing' : d.tokens === 0 ? 'zero' : ''}" aria-label="${description}" data-tip="${description}" style="--bar-height:${d.tokens === null ? 0 : d.tokens/max*100}%"><span></span></button>`;
      }).join('')}</div><div class="daily-axis"><time datetime="${rows[0].date}">${rows[0].date.slice(5).replace('-','/')}</time><time datetime="${rows.at(-1).date}">${rows.at(-1).date.slice(5).replace('-','/')}</time></div><div class="daily-tooltip" role="status"></div></div>`}
      <p class="daily-note">${t('dailySource')}${dailyData?.incomplete ? ' '+t('partialDaily') : ''}${dailyData ? `<br>${t('refreshed')} <span data-age="${dailyData.observedAt}">${age(dailyData.observedAt)}</span>` : ''}</p></div>`;
  }
  return `<section class="daily-usage"><button class="daily-toggle" data-action="toggleDaily" aria-expanded="${dailyOpen}">${icon('chart')}<span>${t('dailyTokens')}</span><span class="daily-chevron ${dailyOpen ? 'open' : ''}">${icon('chevron')}</span></button>${body}</section>`;
}
async function loadDaily() {
  if (dailyLoading) return;
  const generation = ++dailyGeneration, account = state.snapshot?.identity;
  dailyLoading = true; dailyError = null;
  render();
  let result;
  try { result = await api.dailyUsage(); } catch { result = {error:'serverError'}; }
  if (generation !== dailyGeneration || account !== state.snapshot?.identity) return;
  dailyLoading = false;
  dailyData = result.data || null;
  dailyError = result.error || null;
  if (view === 'widget') render();
}
function connectionHTML() {
  return `<section class="connection"><div class="connection-icon">${icon("shield")}</div><h2>${state.status === "loading" ? t("syncing") : t("connectTitle")}</h2><p>${t("connectBody")}</p>
    ${state.error ? `<div class="notice">${escapeHTML(t(state.error))}</div>` : ""}
    ${state.login ? `<div class="waiting"><i></i>${t("browserWaiting")}</div><button class="secondary-button" data-action="cancelLogin">${t("cancel")}</button>` : `<button class="primary-button" data-action="${state.error === "codexMissing" ? "installHelp" : "login"}">${t(state.error === "codexMissing" ? "install" : "connect")}${icon("arrow")}</button>`}
    <button class="text-button retry" data-action="refresh">${icon("refresh")}${t("retry")}</button><small>${t("sharedLogin")}</small></section>`;
}
function widgetHTML() {
  if (state.settings.compact && view === "widget") {
    return ringHTML();
  }
  return `<section class="glass">${toolbar()}<div class="content"><div class="heading"><div><h1>${t("title")}</h1></div>${state.snapshot ? `<span class="plan">${escapeHTML(state.plan)}</span>` : ""}</div>
    ${state.demo ? `<div class="demo-banner">${t("demo")}</div>` : ""}
    ${
      state.snapshot
        ? `${state.status === "stale" ? `<div class="notice">${escapeHTML(t(state.error))} · ${t("stale")}</div>` : ""}${state.snapshot.allowed === false || state.snapshot.windows.some((w) => w.groupBlocked) ? `<div class="notice">${t("blocked")}</div>` : ""}${quotaGroups()}${dailyHTML()}
    <section class="reset-row"><span class="reset-icon">${icon("bolt")}</span><div><span class="small">${t("resetCredits")}</span><p class="muted tiny">${state.snapshot.resets.expiresAt ? `${formatDate(state.snapshot.resets.expiresAt)} ${t("expires")}` : t("unknown")}</p></div><strong>${state.snapshot.resets.count === null ? "—" : state.snapshot.resets.count}<small>${t("times")}</small></strong><button class="reset-link" data-action="openResets" title="${t('resetHelp')}">${t('resetAction')}${icon('arrow')}</button></section>
    ${memberHTML()}`
        : connectionHTML()
    }
    <div class="footer"><div>${statusHTML()}<span class="updated" data-age="${state.snapshot?.observedAt || ""}">${state.snapshot ? age(state.snapshot.observedAt) : t("local")}</span></div><div>${button("refresh", "refresh", t("refresh"), state.refreshing ? "spinning" : "")}${button("openUsage", "arrow", t("usage"))}</div></div></div></section>`;
}
const option = (value, key, selected) =>
  `<option value="${value}" ${value === selected ? "selected" : ""}>${t(key)}</option>`;
const toggle = (key, help) =>
  `<label class="setting-row"><span>${t(key)}<small>${t(help)}</small></span><input type="checkbox" id="${key}" ${state.settings[key] ? "checked" : ""}><span class="switch"></span></label>`;
function applyAccent(color) {
  const el = document.documentElement;
  const valid = typeof color === 'string' && /^#[0-9a-f]{6}$/i.test(color);
  el.dataset.customAccent = String(valid);
  for (const key of ['--accent', '--blue', '--on-accent']) el.style.removeProperty(key);
  if (!valid) return;
  el.style.setProperty('--accent', color);
  el.style.setProperty('--blue', `color-mix(in srgb, ${color}, ${state.dark ? 'white 28%' : 'black 20%'})`);
  const rgb = [1,3,5].map(i => parseInt(color.slice(i,i+2),16) / 255).map(v => v <= .04045 ? v / 12.92 : ((v+.055)/1.055) ** 2.4);
  const luminance = .2126*rgb[0] + .7152*rgb[1] + .0722*rgb[2];
  el.style.setProperty('--on-accent', luminance > .179 ? '#172033' : '#ffffff');
}
function colorSettingsHTML() {
  const color = state.settings.accentColor || '#4c8df3';
  return `<div class="setting-group color-settings"><label class="setting-row" for="accentColor"><span>${t('accentColor')}<small>${t('accentHelp')}</small></span><input id="accentColor" type="color" value="${escapeHTML(color)}"></label><div class="color-presets">${['#4c8df3','#8b5cf6','#16a085','#ed7896','#f59e0b','#64748b'].map(c => `<button class="color-swatch" data-action="accent" data-color="${c}" style="--swatch:${c}" title="${t('accentColor')} ${c}" aria-label="${t('accentColor')} ${c}" aria-pressed="${color === c}"></button>`).join('')}<button class="text-button" data-action="resetAccent">${t('resetAccent')}</button></div></div>`;
}
function settingsHTML() {
  formAccount = state.snapshot?.identity;
  const m = state.settings.membership;
  return `<section class="glass settings"><header class="settings-header drag">${button("back", "back", t("back"), "no-drag")}<h1>${t("settingsTitle")}</h1><span class="version">v${escapeHTML(state.version)}</span></header><div class="settings-body">
    <h3>${t("appearance")}</h3><div class="setting-group"><label class="setting-row"><span>${t("language")}</span><select id="language"><option value="zh" ${state.settings.language === "zh" ? "selected" : ""}>简体中文</option><option value="en" ${state.settings.language === "en" ? "selected" : ""}>English</option></select></label><label class="setting-row"><span>${t("theme")}</span><select id="theme">${["light", "dark", "system"].map((v) => option(v, v, state.settings.theme)).join("")}</select></label></div>
    ${colorSettingsHTML()}
    <h3>${t('ringSettings')}</h3><div class="setting-group"><label class="setting-row"><span>${t('ringWindow')}<small>${t('ringWindowHelp')}</small></span><select id="ringWindow">${['auto','five','week'].map(v => option(v,v,state.settings.ringWindow)).join('')}</select></label>${toggle('elapsedArc','elapsedArcHelp')}</div>
    <h3>${t("behavior")}</h3><div class="setting-group">${toggle("startup", "startupHelp")}${toggle("notifications", "notificationsHelp")}<label class="setting-row"><span>${t("interval")}</span><select id="refreshSeconds">${[
      [60, "everyMinute"],
      [120, "every2"],
      [300, "every5"],
      [600, "every10"],
    ]
      .map(([v, k]) => option(v, k, state.settings.refreshSeconds))
      .join("")}</select></label></div>
    <h3>${t("membership")} <span class="manual-badge">${t("manual")}</span></h3><div class="setting-group membership-form">${state.canSetMembership ? `<p class="help">${t("memberHelp")}</p><label class="setting-row"><span>${t("dateKind")}</span><select id="dateKind">${option("renewal", "renewal", m?.kind || "renewal")}${option("expiry", "expiry", m?.kind)}</select></label><label class="setting-row"><span>${t("date")}</span><input id="memberDate" type="date" value="${escapeHTML(m?.date || "")}" min="2020-01-01" max="2100-12-31"></label><div class="form-actions"><span id="save-status" role="status"></span><button class="text-button" data-action="clearMembership">${t("clear")}</button><button class="small-primary" data-action="saveMembership">${t("save")}</button></div>` : `<p class="help">${t("connectFirst")}</p>`}</div>
    <h3>${t("account")}</h3><div class="privacy-box">${icon("shield")}<p>${t("privacy")}</p></div><div class="settings-links"><button class="text-button" data-action="openUsage">${t("usage")}${icon("arrow")}</button><button class="text-button" data-action="quit">${t("quit")}</button></div><p class="disclaimer">${t("developer")}</p>
    </div></section>`;
}
function fit() {
  if (!state || resizeState) return;
  const compact = view === 'widget' && state.settings.compact;
  const mode = compact ? 'mini' : view === 'settings' ? 'settings' : 'main';
  const saved = view === 'widget' && !compact ? state.settings.mainSize : null;
  const width = compact ? 92 : saved?.width || 382;
  const height =
    compact ? 126 : view === "settings"
      ? 740
      : saved?.height || Math.ceil(root.getBoundingClientRect().height + 20);
  if (height !== lastHeight || width !== lastWidth || mode !== lastMode) {
    lastHeight = height;
    lastWidth = width;
    lastMode = mode;
    api.resize({ width, height, mode });
  }
}
function render() {
  if (resizeState) return;
  document.documentElement.lang =
    state.settings.language === "zh" ? "zh-CN" : "en";
  document.documentElement.dataset.theme = state.dark ? "dark" : "light";
  applyAccent(state.settings.accentColor);
  document.body.classList.toggle('is-mini', view === 'widget' && state.settings.compact);
  const main = view === 'widget' && !state.settings.compact;
  document.body.classList.toggle('sized-main', main && !!state.settings.mainSize);
  root.innerHTML = (view === "settings" ? settingsHTML() : widgetHTML()) + (main ? ['nw','ne','sw','se'].map(c => `<div class="resize-corner ${c}" data-corner="${c}" aria-hidden="true"></div>`).join('') : '');
  fit();
}
root.addEventListener("click", async (event) => {
  const action = event.target.closest("[data-action]")?.dataset.action;
  if (!action) return;
  if (suppressClick) { suppressClick = false; return; }
  if (action === 'toggleDaily') {
    dailyOpen = !dailyOpen;
    if (dailyOpen) await loadDaily(); else render();
    return;
  }
  if (action === 'refreshDaily') { await loadDaily(); return; }
  if (action === 'dailyRange') {
    dailyRange = Number(event.target.closest('[data-range]').dataset.range) === 30 ? 30 : 7;
    render(); return;
  }
  if (action === 'accent' || action === 'resetAccent') {
    state = await api.settings({ accentColor: action === 'resetAccent' ? null : event.target.closest('[data-color]').dataset.color });
    render();
    return;
  }
  if (action === 'selectWindow') {
    const selected = event.target.closest('[data-window]').dataset.window;
    state = await api.settings({ ringWindow: state.settings.ringWindow === selected ? 'auto' : selected });
    render();
    return;
  }
  if (action === "settings" || action === "membership") {
    view = "settings";
    render();
    return;
  }
  if (action === "back") {
    view = "widget";
    render();
    return;
  }
  if (action === "language") {
    state = await api.settings({
      language: state.settings.language === "zh" ? "en" : "zh",
    });
    render();
    return;
  }
  if (action === "pin") {
    state = await api.settings({ pinned: !state.settings.pinned });
    render();
    return;
  }
  if (action === "compact" || action === "expand") {
    state = await api.settings({ compact: action === "compact" });
    view = "widget";
    render();
    return;
  }
  if (action === "saveMembership") {
    const input = document.getElementById("memberDate");
    if (!input.value || !input.checkValidity()) {
      document.getElementById("save-status").textContent = t("invalidDate");
      return;
    }
    const saved = await api.membership({
      identity: formAccount,
      date: input.value,
      kind: document.getElementById("dateKind").value,
    });
    const status = document.getElementById("save-status");
    if (status) status.textContent = t(saved ? "saved" : "accountChanged");
    return;
  }
  if (action === "clearMembership") {
    const saved = await api.membership({ identity: formAccount, date: "" });
    if (document.getElementById("memberDate")) {
      if (saved) document.getElementById("memberDate").value = "";
      document.getElementById("save-status").textContent = t(
        saved ? "saved" : "accountChanged",
      );
    }
    return;
  }
  if (typeof api[action] === "function") await api[action]();
});
root.addEventListener("change", async (event) => {
  const input = event.target;
  if (
    [
      "language",
      "theme",
      "startup",
      "notifications",
      "refreshSeconds",
      "ringWindow",
      "elapsedArc",
      "accentColor",

    ].includes(input.id)
  ) {
    const draft = {
      date: document.getElementById("memberDate")?.value,
      kind: document.getElementById("dateKind")?.value,
    };
    state = await api.settings({
      [input.id]:
        input.type === "checkbox"
          ? input.checked
          : input.id === "refreshSeconds"
            ? Number(input.value)
            : input.value,
    });
    render();
    if (draft.date !== undefined && document.getElementById("memberDate")) {
      document.getElementById("memberDate").value = draft.date;
      document.getElementById("dateKind").value = draft.kind;
    }
  }
});
root.addEventListener('input', event => {
  if (event.target.id === 'accentColor') applyAccent(event.target.value);
});
api.subscribe((value) => {
  if (state && state.snapshot?.identity !== value.snapshot?.identity) {
    dailyGeneration++; dailyOpen = false; dailyData = null; dailyError = null; dailyLoading = false;
  }
  if (value.navigate === 'settings') { state = value; view = 'settings'; render(); return; }
  const wasSettings = view === "settings";
  const structuralChange =
    state &&
    (state.settings.language !== value.settings.language ||
      state.canSetMembership !== value.canSetMembership ||
      state.snapshot?.identity !== value.snapshot?.identity);
  state = value;
  if (dragState || resizeState) return;
  if (!wasSettings || structuralChange) render();
  else { document.documentElement.dataset.theme = state.dark ? "dark" : "light"; applyAccent(state.settings.accentColor); }
});
api.getState().then((value) => {
  state = value;
  render();
});
setInterval(() => {
  if (!state) return;
  let expired = !!state.snapshot?.windows.some(w => w.resetsAt && w.resetsAt <= Date.now());
  if (state.settings.compact && view === 'widget' && !dragState) render();
  document.querySelectorAll("[data-countdown]").forEach((el) => {
    const date = Number(el.dataset.countdown);
    el.textContent = countdown(date);
    if (date && date <= Date.now()) expired = true;
  });
  document.querySelectorAll("[data-age]").forEach((el) => {
    if (el.dataset.age) el.textContent = age(Number(el.dataset.age));
  });
  if (expired && !state.refreshing) {
    render();
    if (state.status === "live") api.refresh();
  }
}, 15000);
new ResizeObserver(fit).observe(root);
root.addEventListener('toggle', fit, true);
// A manual drag lets the entire ring remain clickable and keyboard accessible.
root.addEventListener('pointerdown', event => {
  if (event.button !== 0 || !event.target.closest('.ring-button')) return;
  suppressClick = false;
  dragState = { x: event.screenX, y: event.screenY, moved: false, pointerId: event.pointerId, target: event.target.closest('.ring-button') };
  dragState.target.setPointerCapture(event.pointerId);
  api.drag({ phase: 'start' });
});
root.addEventListener('pointermove', event => {
  if (!dragState) return;
  const x = event.screenX - dragState.x, y = event.screenY - dragState.y;
  if (Math.abs(x) + Math.abs(y) > 5) dragState.moved = true;
  if (dragState.moved) api.drag({ phase: 'move', x, y });
});
function endDrag(event) {
  if (!dragState) return;
  suppressClick = dragState.moved || event?.type === 'pointercancel';
  const { target, pointerId } = dragState;
  dragState = null;
  if (target.hasPointerCapture(pointerId)) target.releasePointerCapture(pointerId);
  api.drag({ phase: 'end' });
}
root.addEventListener('pointerup', endDrag);
root.addEventListener('pointercancel', endDrag);
root.addEventListener('lostpointercapture', endDrag);
root.addEventListener('dragstart', event => event.preventDefault());
root.addEventListener('contextmenu', event => {
  event.preventDefault();
  api.menu();
});

// Resize transparent frameless windows explicitly so all four corners work on Windows 10.
root.addEventListener('pointerdown', event => {
  const target = event.target.closest('[data-corner]');
  if (!target || event.button !== 0) return;
  event.preventDefault();
  resizeState = {target, pointerId:event.pointerId, x:event.screenX, y:event.screenY};
  target.setPointerCapture(event.pointerId);
  document.body.classList.add('sized-main');
  api.resizeCorner({phase:'start',corner:target.dataset.corner});
});
root.addEventListener('pointermove', event => {
  if (resizeState) api.resizeCorner({phase:'move',x:event.screenX-resizeState.x,y:event.screenY-resizeState.y});
});
async function endResize() {
  if (!resizeState) return;
  const current = resizeState;
  const updated = await api.resizeCorner({phase:'end'});
  if (resizeState !== current) return;
  resizeState = null;
  if (current.target.hasPointerCapture(current.pointerId)) current.target.releasePointerCapture(current.pointerId);
  state = updated;
  lastWidth = 0; lastHeight = 0;
  render();
}
root.addEventListener('pointerup', endResize);
root.addEventListener('pointercancel', endResize);
root.addEventListener('lostpointercapture', endResize);
window.addEventListener('blur', endResize);
function showDailyTip(event) {
  const bar = event.target.closest('.daily-bar');
  if (!bar) return;
  const tooltip = bar.closest('.daily-chart').querySelector('.daily-tooltip');
  tooltip.textContent = bar.dataset.tip;
  tooltip.classList.add('visible');
}
function hideDailyTip(event) {
  if (event.target.closest('.daily-bar')) document.querySelector('.daily-tooltip')?.classList.remove('visible');
}
root.addEventListener('pointerover', showDailyTip);
root.addEventListener('focusin', showDailyTip);
root.addEventListener('pointerout', hideDailyTip);
root.addEventListener('focusout', hideDailyTip);
