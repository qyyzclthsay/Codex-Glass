const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("glass", {
  getState: () => ipcRenderer.invoke("get-state"),
  refresh: () => ipcRenderer.invoke("refresh"),
  hide: () => ipcRenderer.invoke("hide"),
  quit: () => ipcRenderer.invoke("quit"),
  login: () => ipcRenderer.invoke("login"),
  cancelLogin: () => ipcRenderer.invoke("cancel-login"),
  openUsage: () => ipcRenderer.invoke("open-usage"),
  dailyUsage: () => ipcRenderer.invoke('daily-usage'),
  openResets: () => ipcRenderer.invoke('open-resets'),
  installHelp: () => ipcRenderer.invoke("install-help"),
  resize: (size) => ipcRenderer.invoke("resize", size),
  resizeCorner: (value) => ipcRenderer.invoke('resize-corner', value),
  drag: (value) => ipcRenderer.invoke("drag", value),
  menu: () => ipcRenderer.invoke("menu"),
  settings: (patch) => ipcRenderer.invoke("settings", patch),
  membership: (value) => ipcRenderer.invoke("membership", value),
  subscribe: (callback) => {
    const handler = (_event, value) => callback(value);
    ipcRenderer.on("state", handler);
    return () => ipcRenderer.removeListener("state", handler);
  },
});
