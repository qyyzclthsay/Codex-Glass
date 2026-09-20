const { spawn } = require("node:child_process");
const { EventEmitter } = require("node:events");
const fs = require("node:fs");
const path = require("node:path");

function locateCodex(env = process.env) {
  const candidates = [];
  if (env.CODEX_GLASS_CODEX_PATH) candidates.push(env.CODEX_GLASS_CODEX_PATH);
  for (const dir of (env.PATH || "").split(path.delimiter).filter(Boolean))
    candidates.push(
      path.join(dir, process.platform === "win32" ? "codex.exe" : "codex"),
    );
  const base = path.join(env.LOCALAPPDATA || "", "OpenAI", "Codex", "bin");
  try {
    for (const d of fs.readdirSync(base).reverse())
      candidates.push(path.join(base, d, "codex.exe"));
  } catch {}
  const npmRoot = path.join(
    env.APPDATA || "",
    "npm",
    "node_modules",
    "@openai",
  );
  for (const root of [
    path.join(npmRoot, "codex"),
    path.join(npmRoot, "codex", "node_modules", "@openai", "codex-win32-x64"),
  ]) {
    candidates.push(
      path.join(root, "vendor", "x86_64-pc-windows-msvc", "codex", "codex.exe"),
    );
  }
  for (const candidate of candidates) {
    try {
      if (path.isAbsolute(candidate) && fs.statSync(candidate).isFile())
        return { executable: candidate, args: ["app-server"] };
    } catch {}
  }
  throw Object.assign(new Error("codexMissing"), { code: "codexMissing" });
}

class CodexRPC extends EventEmitter {
  constructor({ command, timeout = 25000, env } = {}) {
    super();
    this.command = command;
    this.timeout = timeout;
    this.env = env;
    this.pending = new Map();
    this.id = 0;
  }
  async start() {
    if (this.starting) return this.starting;
    if (this.ready) return;
    this.starting = this.boot();
    try {
      await this.starting;
    } finally {
      this.starting = null;
    }
  }
  async boot() {
    const cmd = this.command || locateCodex();
    const child = spawn(cmd.executable, cmd.args, {
      stdio: ["pipe", "pipe", "pipe"],
      windowsHide: true,
      env: this.env || process.env,
    });
    this.child = child;
    let buffer = "";
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      buffer += chunk;
      if (buffer.length > 4 * 1024 * 1024) {
        this.stop("invalidReply");
        return;
      }
      let end;
      while ((end = buffer.indexOf("\n")) !== -1) {
        const line = buffer.slice(0, end);
        buffer = buffer.slice(end + 1);
        try {
          this.receive(JSON.parse(line), child);
        } catch {}
      }
    });
    // Drain without persisting backend logs, which can contain account details.
    child.stderr.resume();
    child.stdin.on("error", () => this.closed(child, "connectionLost"));
    child.on("error", () => this.closed(child, "startFailed"));
    child.on("exit", () => this.closed(child, "connectionLost"));
    child.stdout.on("end", () => this.closed(child, "connectionLost"));
    try {
      await this.request("initialize", {
        clientInfo: {
          name: "codex_glass",
          title: "Codex Glass",
          version: "0.1.0",
        },
      });
      this.write({ method: "initialized", params: {} });
      this.ready = true;
    } catch (error) {
      this.stop();
      throw error;
    }
  }
  receive(message, child) {
    if (child !== this.child) return;
    if (message.id !== undefined && message.method) {
      // This read-only companion cannot service tool calls or approvals.
      this.write({
        id: message.id,
        error: { code: -32601, message: "Unsupported client request" },
      });
      return;
    }
    if (message.id !== undefined) {
      const pending = this.pending.get(message.id);
      if (!pending) return;
      clearTimeout(pending.timer);
      this.pending.delete(message.id);
      if (message.error) {
        const raw = String(message.error.message || "");
        const code = /auth|login|sign.in|credential|401|403/i.test(raw)
          ? "signInRequired"
          : /429|rate.limit/i.test(raw)
            ? "rateLimited"
            : "serverError";
        pending.reject(Object.assign(new Error(code), { code }));
      } else pending.resolve(message.result);
    } else if (message.method)
      this.emit("notification", message.method, message.params);
  }
  write(message) {
    if (!this.child?.stdin.writable)
      throw Object.assign(new Error("connectionLost"), {
        code: "connectionLost",
      });
    this.child.stdin.write(JSON.stringify(message) + "\n");
  }
  request(method, params = {}) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(Object.assign(new Error("timeout"), { code: "timeout" }));
        this.stop();
      }, this.timeout);
      this.pending.set(id, { resolve, reject, timer });
      try {
        this.write({ id, method, params });
      } catch (error) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(error);
      }
    });
  }
  async call(method, params = {}) {
    await this.start();
    return this.request(method, params);
  }
  closed(child, code) {
    if (child !== this.child) return;
    this.child = null;
    this.ready = false;
    child.stdout.removeAllListeners("data");
    if (!child.killed) child.kill();
    for (const { reject, timer } of this.pending.values()) {
      clearTimeout(timer);
      reject(Object.assign(new Error(code), { code }));
    }
    this.pending.clear();
    this.emit("disconnected");
  }
  stop(code = "connectionLost") {
    if (this.child) this.closed(this.child, code);
  }
}
module.exports = { CodexRPC, locateCodex };
