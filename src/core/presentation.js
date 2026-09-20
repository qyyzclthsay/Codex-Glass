// Shared by the sandboxed renderer and Node tests. No account or OS access.
(function (root) {
  function primaryWindows(windows, now = Date.now()) {
    return (windows || []).filter(w => w.group === 'codex' && Number.isFinite(w.remaining) && (!w.resetsAt || w.resetsAt > now));
  }
  function selectWindow(windows, preference = 'auto', now = Date.now()) {
    const candidates = primaryWindows(windows, now);
    const minutes = preference === 'five' ? 300 : preference === 'week' ? 10080 : null;
    const pinned = candidates.find(w => w.minutes === minutes);
    return pinned || candidates.slice().sort((a, b) => a.remaining - b.remaining || (a.minutes || Infinity) - (b.minutes || Infinity))[0] || null;
  }
  function elapsed(w, now = Date.now()) {
    if (!w?.minutes || !w.resetsAt || w.resetsAt <= now) return null;
    return Math.max(0, Math.min(1, 1 - (w.resetsAt - now) / (w.minutes * 60000)));
  }
  function dailySeries(days, range = 7, today) {
    const now = new Date();
    const key = today || `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
    const end = Date.parse(key + 'T12:00:00Z');
    const byDate = new Map((days || []).map(d => [d.date,d.tokens]));
    const length = range === 30 ? 30 : 7;
    return Array.from({length},(_,i) => {
      const date = new Date(end-i*86400000).toISOString().slice(0,10);
      return {date,tokens:byDate.has(date)?byDate.get(date):null};
    });
  }
  const value = { primaryWindows, selectWindow, elapsed, dailySeries };
  if (typeof module === 'object' && module.exports) module.exports = value;
  else root.quotaPresentation = value;
})(typeof globalThis === 'object' ? globalThis : this);
