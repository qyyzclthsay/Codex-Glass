const {
  app,
  BrowserWindow,
  ipcMain,
  Tray,
  Menu,
  nativeImage,
  nativeTheme,
  screen,
  shell,
  Notification,
  powerMonitor,
  dialog,
} = require("electron");
const path = require("node:path");
const fs = require("node:fs");
const os = require("node:os");
const { pathToFileURL } = require("node:url");
const { CodexRPC } = require("./core/rpc.cjs");
const {
  normalize,
  validCache,
  collectAlerts,
  identity,
  planLabel,
  validDate,
} = require("./core/model.cjs");
const { Storage, sanitize } = require("./core/storage.cjs");
const { selectWindow } = require('./core/presentation.js');
const { UsageReader, normalizeUsage } = require('./core/usage.cjs');
let dragOrigin = null;
const { cornerBounds } = require('./core/window-size.cjs');
let resizeOrigin = null, windowMode = 'main';

const smoke = process.argv.includes("--smoke-test");
// The widget draws small static cards; software rendering also supports remote desktops.
app.disableHardwareAcceleration();
const demo = smoke || process.argv.includes("--demo");
const qaDirectory =
  process.env.CODEX_GLASS_QA_DIR ||
  (app.isPackaged
    ? path.join(app.getPath("temp"), "codex-glass-qa")
    : path.join(__dirname, "..", ".qa"));
const dataOverride = process.env.CODEX_GLASS_DATA_DIR;
if (dataOverride || demo) {
  const directory = dataOverride || path.join(qaDirectory, "profile");
  fs.mkdirSync(directory, { recursive: true });
  app.setPath("userData", directory);
}
const locked = app.requestSingleInstanceLock();
let win, tray, storage, settings, timer, movingTimer, pendingLogin, loginTimer;
let quitting = false,
  busy = false,
  suspended = false,
  failures = 0,
  currentIdentity = null;
let lastAccountFingerprint = null;
let state = {
  status: "loading",
  snapshot: null,
  error: null,
  refreshing: false,
  login: null,
};
const rpc = new CodexRPC();
const usageReader = new UsageReader(rpc, () => ({id:currentIdentity, fingerprint:lastAccountFingerprint}));
let usageIdentity = null;
let alertMemory = {};
const entry = path.join(__dirname, "renderer", "index.html");
const entryURL = pathToFileURL(entry).href;
const zh = () => settings.language === "zh";
const word = (a, b) => (zh() ? a : b);
function save() {
  storage.write("settings", settings);
}
function emit() {
  if (usageIdentity !== currentIdentity) { usageReader.invalidate(); usageIdentity = currentIdentity; }
  if (win && !win.isDestroyed()) win.webContents.send("state", publicState());
  if (tray) {
    const snapshot = state.snapshot;
    const selected = selectWindow(snapshot?.windows, settings.ringWindow);
    tray.setToolTip(
      `Codex Glass${selected ? " · " + Math.floor(selected.remaining) + "%" : ""}${state.status === "stale" ? word(" · 旧数据", " · Cached") : ""}`,
    );
  }
}
function publicState() {
  return {
    ...state,
    settings: {
      ...settings,
      membership: settings.membership[currentIdentity] || null,
    },
    demo,
    version: app.getVersion(),
    dark:
      settings.theme === "dark" ||
      (settings.theme === "system" && nativeTheme.shouldUseDarkColors),
    canSetMembership: Boolean(currentIdentity),
    plan: planLabel(state.snapshot?.plan),
  };
}
function demoSnapshot() {
  return normalize(
    { email: "demo@example.invalid", planType: "plus" },
    {
      ordinaryUsageAllowed: true,
      rateLimitsByLimitId: {
        codex: {
          primary: {
            usedPercent: 32,
            windowDurationMins: 300,
            resetsAt: Date.now() / 1000 + 7980,
          },
          secondary: {
            usedPercent: 18,
            windowDurationMins: 10080,
            resetsAt: Date.now() / 1000 + 343800,
          },
        },
        base_model_inference: {
          limitName: 'gpt-reserve',
          normalModelSlug: 'example-model',
          primary: { usedPercent: 0, windowDurationMins: 10080, resetsAt: Date.now() / 1000 + 600000 },
        },
      },
      rateLimitResetCredits: {
        availableCount: 1,
        credits: [
          { status: "available", expiresAt: Date.now() / 1000 + 14 * 86400 },
        ],
      },
    },
  );
}
function nextRefresh() {
  clearTimeout(timer);
  if (suspended || quitting) return;
  const base = settings.refreshSeconds * 1000;
  const delay = Math.min(
    1800000,
    Math.max(base, win?.isVisible() ? base : 600000) *
      2 ** Math.min(failures, 3),
  );
  timer = setTimeout(refresh, delay);
}
async function refresh() {
  if (busy || quitting || suspended) return;
  busy = true;
  state.refreshing = true;
  emit();
  try {
    let snapshot;
    if (demo) snapshot = demoSnapshot();
    else {
      const before = await rpc.call("account/read", { refreshToken: false });
      if (before.account?.type !== "chatgpt") {
        currentIdentity = null;
        state.snapshot = null;
        throw Object.assign(new Error("signInRequired"), {
          code: "signInRequired",
        });
      }
      const accountKeyBefore = identity(before.account);
      if (lastAccountFingerprint !== accountKeyBefore) {
        currentIdentity = null;
        state.snapshot = null;
        lastAccountFingerprint = accountKeyBefore;
        emit();
      }
      const response = await rpc.call("account/rateLimits/read");
      const after = await rpc.call("account/read", { refreshToken: false });
      if (
        after.account?.type !== "chatgpt" ||
        identity(after.account) !== accountKeyBefore
      ) {
        currentIdentity = null;
        state.snapshot = null;
        throw Object.assign(new Error("accountChanged"), {
          code: "accountChanged",
        });
      }
      snapshot = normalize(after.account, response);
      // No identity means no cache or manually-entered billing data may be shared.
    }
    currentIdentity = snapshot.identity;
    state.snapshot = snapshot;
    state.status = "live";
    state.error = null;
    failures = 0;
    if (!demo && currentIdentity) storage.write("cache", snapshot);
    if (settings.notifications && !demo) {
      for (const alert of collectAlerts(
        snapshot,
        settings.membership[currentIdentity],
        alertMemory,
      )) {
        const windowName =
          alert.minutes === 300
            ? word("5 小时", "5-hour")
            : alert.minutes === 10080
              ? word("本周", "Weekly")
              : "Codex";
        const body =
          alert.type === "quota"
            ? word(
                `${windowName}额度剩余 ${alert.remaining}%，可以打开卡片查看。`,
                `${windowName}: ${alert.remaining}% remaining. Open the widget for details.`,
              )
            : alert.type === "credit"
              ? word(
                  "你的可用重置机会将在 3 天内到期。",
                  "An available reset credit expires within 3 days.",
                )
              : word(
                  `你设置的会员${alert.kind === "renewal" ? "续费" : "到期"}日期还有 ${alert.days} 天。`,
                  `Your manually set membership date is in ${alert.days} days.`,
                );
        notify(body);
      }
      // Bound state growth without logging any account identifiers.
      alertMemory = Object.fromEntries(Object.entries(alertMemory).slice(-200));
      storage.write("alerts", alertMemory);
    }
  } catch (error) {
    failures++;
    state.error = error.code || "serverError";
    if (
      ["signInRequired", "accountChanged", "codexMissing"].includes(state.error)
    ) {
      currentIdentity = null;
      lastAccountFingerprint = null;
      state.snapshot = null;
      state.status = "error";
    } else {
      // Never restore persisted data before the current account is verified by a successful read.
      const cached = validCache(
        state.snapshot || storage.read("cache", null),
        currentIdentity,
      );
      state.snapshot = cached;
      state.status = cached ? "stale" : "error";
    }
  } finally {
    busy = false;
    state.refreshing = false;
    emit();
    nextRefresh();
  }
}
function notify(body) {
  if (!Notification.isSupported()) return;
  const n = new Notification({
    title: "Codex Glass",
    body,
    icon: path.join(__dirname, "..", "assets", "icon.png"),
  });
  n.on("click", () => show());
  n.show();
}
function show() {
  if (!win) return;
  keepOnScreen();
  win.show();
  win.focus();
  if (
    !state.snapshot ||
    Date.now() - state.snapshot.observedAt > settings.refreshSeconds * 1000
  )
    refresh();
}
function keepOnScreen() {
  if (!win) return;
  const b = win.getBounds();
  const a = screen.getDisplayMatching(b).workArea;
  const x = Math.round(Math.max(a.x, Math.min(b.x, a.x + a.width - b.width)));
  const y = Math.round(Math.max(a.y, Math.min(b.y, a.y + a.height - b.height)));
  if (x !== b.x || y !== b.y) win.setPosition(x, y);
}
function snapAndSave() {
  if (!win || win.isDestroyed()) return;
  const b = win.getBounds();
  const a = screen.getDisplayMatching(b).workArea;
  let x = b.x,
    y = b.y;
  if (Math.abs(x - a.x) < 20) x = a.x;
  if (Math.abs(x + b.width - a.x - a.width) < 20) x = a.x + a.width - b.width;
  if (Math.abs(y - a.y) < 20) y = a.y;
  if (Math.abs(y + b.height - a.y - a.height) < 20)
    y = a.y + a.height - b.height;
  if (x !== b.x || y !== b.y) win.setPosition(x, y);
  settings.position = { x, y };
  save();
}
function updateTray() {
  if (!tray) return;
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: word("显示小组件", "Show widget"), click: show },
      {
        label: word("迷你模式", "Compact mode"),
        type: "checkbox",
        checked: settings.compact,
        click: () => {
          settings.compact = !settings.compact;
          save();
          emit();
          updateTray();
          show();
        },
      },
      {
        label: word("始终置顶", "Always on top"),
        type: "checkbox",
        checked: settings.pinned,
        click: () => {
          settings.pinned = !settings.pinned;
          save();
          win.setAlwaysOnTop(settings.pinned);
          emit();
          updateTray();
        },
      },
      { label: word("立即刷新", "Refresh now"), click: refresh },
      { type: "separator" },
      {
        label: "中文 / English",
        click: () => {
          settings.language = zh() ? "en" : "zh";
          save();
          emit();
          updateTray();
        },
      },
      { type: "separator" },
      { label: word("退出", "Quit"), click: () => app.quit() },
    ]),
  );
}
function createWindow() {
  const area = screen.getPrimaryDisplay().workArea;
  win = new BrowserWindow({
    width: 382,
    height: 560,
    x: settings.position?.x ?? area.x + area.width - 414,
    y: settings.position?.y ?? area.y + 64,
    frame: false,
    transparent: true,
    backgroundColor: "#00000000",
    hasShadow: true,
    resizable: false,
    maximizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    alwaysOnTop: settings.pinned,
    show: false,
    title: "Codex Glass",
    icon: path.join(__dirname, "..", "assets", "icon.png"),
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      backgroundThrottling: true,
    },
  });
  win.webContents.session.setPermissionRequestHandler(
    (_wc, _permission, callback) => callback(false),
  );
  win.webContents.session.setPermissionCheckHandler(() => false);
  win.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  win.webContents.on("will-navigate", (event) => event.preventDefault());
  win.on("close", (event) => {
    if (!quitting) {
      event.preventDefault();
      win.hide();
    }
  });
  win.on("moved", () => {
    clearTimeout(movingTimer);
    if (resizeOrigin) return;
    movingTimer = setTimeout(snapAndSave, 350);
  });
  win.once("ready-to-show", () => {
    keepOnScreen();
    if (!smoke && !process.argv.includes("--hidden")) win.show();
  });
  win.loadFile(entry);
}
function allowedURL(raw) {
  try {
    const u = new URL(raw);
    return (
      u.protocol === "https:" &&
      ["auth.openai.com", "auth0.openai.com", "chatgpt.com"].includes(
        u.hostname,
      ) &&
      !u.username &&
      !u.password
    );
  } catch {
    return false;
  }
}
async function cancelLogin() {
  const loginId = pendingLogin;
  pendingLogin = null;
  clearTimeout(loginTimer);
  state.login = null;
  if (loginId) {
    try {
      await rpc.call("account/login/cancel", { loginId });
    } catch {}
  }
  emit();
}
async function login() {
  if (demo || state.login) return;
  state.login = { waiting: true };
  emit();
  try {
    const result = await rpc.call("account/login/start", { type: "chatgpt" });
    if (!allowedURL(result.authUrl)) throw new Error("invalidLoginURL");
    pendingLogin = result.loginId;
    await shell.openExternal(result.authUrl);
    loginTimer = setTimeout(async () => {
      await cancelLogin();
      state.error = "loginExpired";
      emit();
    }, 5 * 60000);
  } catch {
    pendingLogin = null;
    state.login = null;
    state.error = "loginFailed";
    emit();
  }
}
function registerIPC() {
  function handle(channel, fn) {
    ipcMain.handle(channel, async (event, arg) => {
      if (
        event.sender !== win.webContents ||
        event.senderFrame !== win.webContents.mainFrame ||
        event.senderFrame.url !== entryURL
      )
        throw new Error("Invalid sender");
      return fn(arg);
    });
  }
  handle("get-state", () => publicState());
  handle("refresh", refresh);
  handle("hide", () => win.hide());
  handle("quit", () => app.quit());
  handle("login", login);
  handle("cancel-login", cancelLogin);
  handle("open-usage", () =>
    shell.openExternal("https://chatgpt.com/codex/settings/usage"),
  );
  handle('open-resets', () => shell.openExternal('https://chatgpt.com/codex/settings/usage'));
  handle('daily-usage', async () => {
    try {
      if (demo) return { data: normalizeUsage({dailyUsageBuckets:Array.from({length:30},(_,i) => {
        const date = new Date(); date.setDate(date.getDate()-i);
        return {startDate:`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`,tokens:i===2?0:Math.round(1400000+(Math.sin(i*1.7)+1)*1600000)};
      })}) };
      return {data:await usageReader.read()};
    } catch (error) { return {error:error.code || 'serverError'}; }
  });
  handle("install-help", () =>
    shell.openExternal("https://developers.openai.com/codex/cli"),
  );
  handle("resize", (size) => {
    if (resizeOrigin) return;
    if (Number.isFinite(size?.height) && ['main','mini','settings'].includes(size?.mode)) {
      windowMode = size.mode;
      size = windowMode === 'mini' ? {width:92,height:126} : windowMode === 'settings' ? {width:382,height:740} : settings.mainSize || {width:382,height:size.height};
      const before = win.getBounds();
      const area = screen.getDisplayMatching(before).workArea;
      size = {width: Math.min(size.width,area.width), height: Math.min(size.height,area.height)};
      // Win10 can retain the previous fixed-size constraints until resizing is enabled.
      win.setResizable(true);
      win.setSize(
        size.width,
        Math.round(
          Math.max(
            84,
            Math.min(
              size.height,
              screen.getDisplayMatching(win.getBounds()).workArea.height,
            ),
          ),
        ),
      );
      win.setResizable(false);
      if (before.x + before.width / 2 > area.x + area.width / 2)
        win.setPosition(before.x + before.width - size.width, before.y);
      keepOnScreen();
    }
  });
  handle('resize-corner', value => {
    if (value?.phase === 'start' && windowMode === 'main' && ['nw','ne','sw','se'].includes(value.corner)) {
      clearTimeout(movingTimer);
      resizeOrigin = {bounds:win.getBounds(), corner:value.corner, area:screen.getDisplayMatching(win.getBounds()).workArea};
    } else if (value?.phase === 'move' && resizeOrigin && Number.isFinite(value.x) && Number.isFinite(value.y)) {
      win.setResizable(true);
      win.setBounds(cornerBounds(resizeOrigin.bounds,resizeOrigin.corner,value.x,value.y,resizeOrigin.area));
      win.setResizable(false);
    } else if (value?.phase === 'end' && resizeOrigin) {
      resizeOrigin = null;
      const {width,height,x,y} = win.getBounds();
      settings.mainSize = {width,height};
      settings.position = {x,y};
      save(); emit();
    }
    return publicState();
  });
  handle('drag', value => {
    if (value?.phase === 'start' && settings.compact) dragOrigin = win.getBounds();
    else if (value?.phase === 'move' && dragOrigin && Number.isFinite(value.x) && Number.isFinite(value.y)) {
      if (Math.abs(value.x) < 30000 && Math.abs(value.y) < 30000)
        win.setPosition(Math.round(dragOrigin.x + value.x), Math.round(dragOrigin.y + value.y));
    } else if (value?.phase === 'end') { dragOrigin = null; keepOnScreen(); snapAndSave(); }
  });
  handle('menu', () => Menu.buildFromTemplate([
    { label: word('展开主界面','Open overview'), click: () => { settings.compact = false; save(); emit(); updateTray(); show(); } },
    { label: word('偏好设置','Settings'), click: () => { win.webContents.send('state', { ...publicState(), navigate: 'settings' }); show(); } },
    { label: word('立即刷新','Refresh now'), click: refresh },
    { label: word('恢复默认窗口大小','Restore default window size'), click: () => { settings.mainSize = null; save(); emit(); } },
    { type: 'separator' },
    { label: word('退出组件','Quit'), click: () => app.quit() },
  ]).popup({ window: win }));
  handle("settings", (patch) => {
    if (!patch || typeof patch !== "object") return publicState();
    const safe = {};
    for (const key of [
      "language",
      "theme",
      "pinned",
      "compact",
      "startup",
      "notifications",
      "refreshSeconds",
      "ringWindow",
      "elapsedArc",
      "accentColor",

    ])
      if (key in patch) safe[key] = patch[key];
    const beforeStartup = settings.startup;
    settings = sanitize({ ...settings, ...safe });
    nativeTheme.themeSource = settings.theme;
    if (beforeStartup !== settings.startup && !demo) {
      if (!app.isPackaged) settings.startup = false;
      else
        app.setLoginItemSettings({
          openAtLogin: settings.startup,
          path: process.env.PORTABLE_EXECUTABLE_FILE || app.getPath("exe"),
          args: ["--hidden"],
        });
    }
    save();
    win.setAlwaysOnTop(settings.pinned);
    emit();
    updateTray();
    nextRefresh();
    return publicState();
  });
  handle("membership", (value) => {
    if (!currentIdentity || value?.identity !== currentIdentity) return false;
    if (!value?.date) delete settings.membership[currentIdentity];
    else if (
      validDate(value.date) &&
      ["renewal", "expiry"].includes(value.kind)
    )
      settings.membership[currentIdentity] = {
        date: value.date,
        kind: value.kind,
      };
    else return false;
    save();
    emit();
    return true;
  });
}
rpc.on("notification", (method, params) => {
  if (method === "account/login/completed") {
    if (!pendingLogin || params.loginId !== pendingLogin) return;
    clearTimeout(loginTimer);
    pendingLogin = null;
    state.login = null;
    if (params.success) {
      rpc.stop();
      refresh();
    } else {
      state.error = "loginFailed";
      emit();
    }
  }
  if (method === "account/updated") {
    currentIdentity = null;
    state.snapshot = null;
    emit();
    if (!busy && !pendingLogin) refresh();
  }
  if (
    method === "account/rateLimits/updated" &&
    !busy &&
    Date.now() - (state.snapshot?.observedAt || 0) > 10000
  )
    refresh();
});
async function runQA() {
  const directory = qaDirectory;
  fs.mkdirSync(directory, { recursive: true });
  const errors = [];
  win.webContents.on("console-message", (_event, details) => {
    if (details.level === "error") errors.push(details.message);
  });
  await new Promise((resolve) => setTimeout(resolve, 900));
  const js = (code) => win.webContents.executeJavaScript(code);
  const geometry = {};
  const capture = async (name) => {
    await new Promise((resolve) => setTimeout(resolve, 250));
    geometry[name] = { bounds: win.getBounds(), page: await js("({height:innerHeight,desired:lastHeight,content:root.getBoundingClientRect().height})") };
    fs.writeFileSync(
      path.join(directory, name + ".png"),
      (await win.webContents.capturePage()).toPNG(),
    );
  };
  await capture("zh-light");
  const topActions = await js("Array.from(document.querySelectorAll('.toolbar [data-action]')).map(el=>el.dataset.action)");
  if (topActions.indexOf('settings') >= topActions.indexOf('compact')) throw new Error('Toolbar order incorrect');
  await js("document.querySelector('[data-action=toggleDaily]').click()");
  await capture('zh-daily');
  if (!await js("document.querySelectorAll('.daily-bar').length === 7 && dailyData.days.length === 30")) throw new Error('Daily usage did not expand');
  await js("document.querySelector('[data-range=\"30\"]').click()");
  await capture('zh-daily-month');
  if (await js("document.querySelectorAll('.daily-bar').length") !== 30) throw new Error('Daily range did not change');
  if (!await js("Array.from(document.querySelectorAll('.daily-bar')).every((el,i,all)=>i===0 || all[i-1].dataset.tip<el.dataset.tip)")) throw new Error('Daily chart order incorrect');
  const hoverBar = await js("(()=>{const r=document.querySelector('.daily-bar').getBoundingClientRect();return {x:Math.round(r.x+r.width/2),y:Math.round(r.y+r.height/2)}})()");
  win.webContents.sendInputEvent({type:'mouseMove',...hoverBar});
  await new Promise(r=>setTimeout(r,60));
  if (!await js("document.querySelector('.daily-tooltip').classList.contains('visible')")) throw new Error('Daily tooltip missing');
  // Trusted mouse events exercise pointer capture and the complete resize IPC path.
  for (const corner of ['se','sw','ne','nw']) {
    const before = win.getBounds();
    const point = await js(`(()=>{const r=document.querySelector('[data-corner=${corner}]').getBoundingClientRect();return {x:Math.round(r.x+r.width/2),y:Math.round(r.y+r.height/2)}})()`);
    const dx = corner.includes('w') ? 10 : -10, dy = corner.includes('n') ? 10 : -10;
    win.webContents.sendInputEvent({type:'mouseDown',button:'left',clickCount:1,x:point.x,y:point.y,globalX:before.x+point.x,globalY:before.y+point.y});
    await new Promise(r=>setTimeout(r,70));
    win.webContents.sendInputEvent({type:'mouseMove',x:point.x+dx,y:point.y+dy,globalX:before.x+point.x+dx,globalY:before.y+point.y+dy});
    await new Promise(r=>setTimeout(r,80));
    const afterMove = win.getBounds();
    win.webContents.sendInputEvent({type:'mouseUp',button:'left',clickCount:1,x:before.x+point.x+dx-afterMove.x,y:before.y+point.y+dy-afterMove.y,globalX:before.x+point.x+dx,globalY:before.y+point.y+dy});
    await new Promise(r=>setTimeout(r,150));
    const after = win.getBounds();
    if (after.width !== before.width-10 || after.height !== before.height-10) throw new Error('Corner resize failed: '+corner+JSON.stringify({before,after}));
    if (storage.read('settings',{}).mainSize?.width !== after.width) throw new Error('Resized dimensions not saved');
  }
  const savedSize = {...settings.mainSize};
  await js("document.querySelector('[data-action=settings]').click()");
  await new Promise(r=>setTimeout(r,100));
  await js("document.querySelector('[data-action=back]').click()");
  await new Promise(r=>setTimeout(r,100));
  if (win.getBounds().width !== savedSize.width || win.getBounds().height !== savedSize.height) throw new Error('Settings lost overview size');
  await js("document.querySelector('[data-action=compact]').click()");
  await new Promise(r=>setTimeout(r,100));
  if (win.getBounds().width !== 92) throw new Error('Main resize changed mini size');
  await js("document.querySelector('[data-action=expand]').click()");
  await new Promise(r=>setTimeout(r,100));
  if (win.getBounds().width !== savedSize.width) throw new Error('Mini lost overview size');
  settings.mainSize = {width:320,height:420}; save(); emit();
  await capture('small-daily');
  if (!await js("document.querySelector('.content').scrollHeight > document.querySelector('.content').clientHeight && document.documentElement.scrollWidth === innerWidth && document.querySelector('.content').scrollWidth <= document.querySelector('.content').clientWidth")) throw new Error('Small layout overflow');
  await js("document.querySelector('.daily-chart').scrollIntoView({block:'center'})");
  await capture('small-chart');
  settings.language = 'en'; emit();
  await new Promise(r=>setTimeout(r,100));
  await js("document.querySelector('.content').scrollTop=9999");
  await capture('small-english');
  if (!await js("document.querySelector('.content').scrollWidth <= document.querySelector('.content').clientWidth")) throw new Error('Small English layout overflow');
  settings.language = 'zh';
  settings.mainSize = null; save(); emit();
  await new Promise(r=>setTimeout(r,100));
  await js("document.querySelector('[data-action=toggleDaily]').click()");
  const originalOpen = shell.openExternal;
  let resetURL;
  try {
    shell.openExternal = async url => { resetURL = url; };
    await js("document.querySelector('[data-action=openResets]').click()");
    await new Promise(resolve=>setTimeout(resolve,50));
    if (resetURL !== 'https://chatgpt.com/codex/settings/usage') throw new Error('Reset link destination incorrect');
  } finally { shell.openExternal = originalOpen; }
  if (!await js("!!document.querySelector('.toolbar [data-action=compact]') && !document.querySelector('.footer [data-action=compact]') && !document.querySelector('[data-action=hide]')")) throw new Error('Toolbar actions incorrect');
  const mainQuotas = await js("document.querySelectorAll('.quotas > .quota').length");
  const hiddenPools = await js("document.querySelector('.other-pools').open === false");
  if (mainQuotas !== 2 || !hiddenPools) throw new Error('Independent pools were not grouped correctly');
  await js("document.querySelector('.other-pools').open = true");
  await capture('zh-pools');
  await js("document.querySelector('.other-pools').open = false");
  await js("document.querySelector('[data-action=language]').click()");
  await capture("en-light");
  await js("document.querySelector('[data-action=settings]').click()");
  await capture("en-settings");
  const rowInsets = await js("Array.from(document.querySelectorAll('.setting-row')).filter(el=>el.querySelector('small')).map(el=>{const row=el.getBoundingClientRect();const text=el.querySelector('span').getBoundingClientRect();return {top:text.top-row.top,bottom:row.bottom-text.bottom};})");
  if (rowInsets.some(row=>row.top<10 || row.bottom<10)) throw new Error('Setting help text lacks vertical spacing');
  await js("document.querySelector('#accentColor').value='#8b5cf6';document.querySelector('#accentColor').dispatchEvent(new Event('change',{bubbles:true}))");
  await capture('custom-settings');
  if (settings.accentColor !== '#8b5cf6' || storage.read('settings', {}).accentColor !== '#8b5cf6') throw new Error('Accent color was not saved');
  await js("document.querySelector('[data-action=back]').click()");
  await capture('custom-light');
  await js("document.querySelector('[data-action=settings]').click()");
  await js(
    "document.querySelector('#memberDate').value='2027-03-14';document.querySelector('#dateKind').value='expiry';document.querySelector('[data-action=saveMembership]').click()",
  );
  await new Promise((resolve) => setTimeout(resolve, 150));
  if (settings.membership[currentIdentity]?.date !== "2027-03-14")
    throw new Error("Membership save failed");
  await js(
    "document.querySelector('#theme').value='dark';document.querySelector('#theme').dispatchEvent(new Event('change',{bubbles:true}))",
  );
  await js("document.querySelector('[data-action=back]').click()");
  await capture("en-dark");
  await js("document.querySelector('[data-action=compact]').click()");
  await capture("compact");
  const result = await js(
    "({language:document.documentElement.lang,compact:!!document.querySelector('.mini'),overflow:document.documentElement.scrollWidth>innerWidth,body:document.body.innerText})",
  );
  result.compactHeight = win.getBounds().height;
  result.compactWidth = win.getBounds().width;
  result.automaticRemaining = await js("document.querySelector('.ring-value').textContent");
  await js("window.glass.settings({ringWindow:'week',elapsedArc:true})");
  await capture('compact-week');
  result.pinnedRemaining = await js("document.querySelector('.ring-value').textContent");
  result.periodLabel = await js("document.querySelector('.ring-period').textContent");
  if (result.periodLabel !== 'Weekly') throw new Error('Ring period missing');
  if (result.automaticRemaining !== '68%' || result.pinnedRemaining !== '82%') throw new Error('Ring selected the wrong window');
  const beforeDrag = win.getBounds();
  await js("window.qaImageDrags=0;window.qaPointerEvents=[];document.addEventListener('dragstart',()=>window.qaImageDrags++);['pointerdown','pointermove','pointerup','click'].forEach(type=>document.addEventListener(type,event=>window.qaPointerEvents.push({type,x:event.screenX,y:event.screenY,clientX:event.clientX,clientY:event.clientY})));void 0");
  win.webContents.sendInputEvent({type:'mouseDown',x:46,y:44,globalX:beforeDrag.x+46,globalY:beforeDrag.y+44,button:'left',clickCount:1});
  await new Promise(resolve => setTimeout(resolve,60));
  win.webContents.sendInputEvent({type:'mouseMove',x:22,y:64,globalX:beforeDrag.x+22,globalY:beforeDrag.y+64,button:'left'});
  await new Promise(resolve => setTimeout(resolve,80));
  win.webContents.sendInputEvent({type:'mouseUp',x:46,y:44,globalX:beforeDrag.x+22,globalY:beforeDrag.y+64,button:'left',clickCount:1});
  await new Promise(resolve => setTimeout(resolve,100));
  result.dragMoved = win.getBounds().x !== beforeDrag.x || win.getBounds().y !== beforeDrag.y;
  result.imageDragStarts = await js('window.qaImageDrags');
  fs.writeFileSync(path.join(directory,'drag.json'), JSON.stringify({before:beforeDrag,after:win.getBounds(),events:await js('window.qaPointerEvents'),imageDrags:result.imageDragStarts,body:await js('document.body.innerText')},null,2));
  if (result.imageDragStarts !== 0 || !await js("!!document.querySelector('.ring-button') && document.querySelector('.ring-mark img').draggable === false")) throw new Error('Logo drag started a native image drag or expanded the widget');
  const fixtureSnapshot = state.snapshot;
  state.snapshot = { ...fixtureSnapshot, windows: fixtureSnapshot.windows.map(w => w.group === 'codex' ? { ...w, remaining: 9 } : w) };
  emit();
  await capture('compact-low');
  if (!await js("document.querySelector('.ring-widget').classList.contains('critical')")) throw new Error('Low allowance ring missing');
  state.status = 'stale'; emit();
  await capture('compact-stale');
  if (!await js("document.querySelector('.ring-button').title.includes('Cached') && document.querySelector('.ring-widget').classList.contains('is-stale')")) throw new Error('Stale state hidden');
  state.snapshot = { ...fixtureSnapshot, windows: fixtureSnapshot.windows.filter(w => w.group !== 'codex') };
  emit();
  await capture('compact-unknown');
  if (await js("document.querySelector('.ring-value').textContent") !== '—') throw new Error('Reserve pool leaked into main ring');
  state.snapshot = fixtureSnapshot; state.status = 'live'; emit();
  fs.writeFileSync(path.join(directory, 'geometry.json'), JSON.stringify(geometry, null, 2));
  win.webContents.sendInputEvent({type:'mouseDown',x:46,y:44,button:'left',clickCount:1});
  win.webContents.sendInputEvent({type:'mouseUp',x:46,y:44,button:'left',clickCount:1});
  await capture('expanded-again');
  result.expandedWidth = win.getBounds().width;
  settings.theme = "light";
  state = {
    status: "error",
    snapshot: null,
    error: "signInRequired",
    refreshing: false,
    login: null,
  };
  currentIdentity = null;
  emit();
  await capture("en-connect");
  const connect = await js("!!document.querySelector('[data-action=login]')");
  result.connect = connect;
  fs.writeFileSync(path.join(directory, 'geometry.json'), JSON.stringify(geometry, null, 2));
  fs.writeFileSync(
    path.join(directory, "result.json"),
    JSON.stringify({ ...result, errors }, null, 2),
  );
  app.exit(
    errors.length || result.overflow || !result.compact || result.compactHeight !== 126 || result.compactWidth !== 92 || result.expandedWidth !== 382 || !result.dragMoved || !connect ? 1 : 0,
  );
}
if (!locked) app.quit();
else {
  app.on("second-instance", show);
  app.on("before-quit", () => {
    quitting = true;
    clearTimeout(timer);
    clearTimeout(loginTimer);
    rpc.stop();
  });
  app.on("window-all-closed", () => {});
  app
    .whenReady()
    .then(async () => {
      app.setAppUserModelId("io.github.codexglass.widget");
      storage = new Storage(app.getPath("userData"));
      settings = sanitize(smoke ? {} : storage.read("settings", {}));
      nativeTheme.themeSource = settings.theme;
      alertMemory = storage.read("alerts", {});
      if (
        !alertMemory ||
        typeof alertMemory !== "object" ||
        Array.isArray(alertMemory)
      )
        alertMemory = {};
      if (demo) {
        state.snapshot = demoSnapshot();
        currentIdentity = state.snapshot.identity;
        const date = new Date(Date.now() + 19 * 86400000);
        settings.membership[currentIdentity] = {
          date: date.toISOString().slice(0, 10),
          kind: "renewal",
        };
      }
      createWindow();
      registerIPC();
      tray = new Tray(
        nativeImage.createFromPath(
          path.join(__dirname, "..", "assets", "icon.png"),
        ),
      );
      tray.on("click", () => (win.isVisible() ? win.hide() : show()));
      updateTray();
      nativeTheme.on("updated", emit);
      screen.on("display-removed", keepOnScreen);
      screen.on("display-metrics-changed", keepOnScreen);
      powerMonitor.on("suspend", () => {
        suspended = true;
        clearTimeout(timer);
        rpc.stop();
      });
      powerMonitor.on("resume", () => {
        suspended = false;
        refresh();
      });
      await refresh();
      if (smoke) await runQA();
    })
    .catch((error) => {
      if (smoke) console.error(error.stack);
      else
        dialog.showErrorBox(
          "Codex Glass",
          "Unable to start. Please check the application data directory.",
        );
      app.exit(1);
    });
}
