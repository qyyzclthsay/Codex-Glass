const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const { CodexRPC, locateCodex } = require("../src/core/rpc.cjs");
const client = (timeout) =>
  new CodexRPC({
    command: {
      executable: process.execPath,
      args: [path.join(__dirname, "fake-server.cjs")],
    },
    timeout: timeout || 2000,
  });
test("RPC correlates concurrent requests and performs a single initialization", async () => {
  const r = client();
  try {
    const results = await Promise.all([
      r.call("echo", { a: 1 }),
      r.call("echo", { b: 2 }),
    ]);
    assert.deepEqual(results, [{ a: 1 }, { b: 2 }]);
    assert.equal(r.pending.size, 0);
  } finally {
    r.stop();
  }
});
test("RPC reports auth failures without exposing backend messages", async () => {
  const r = client();
  try {
    await assert.rejects(r.call("refused"), { message: "signInRequired" });
  } finally {
    r.stop();
  }
});
test("RPC rejects in-flight calls on EOF and can start again", async () => {
  const r = client();
  try {
    await assert.rejects(r.call("exit"));
    assert.deepEqual(await r.call("echo", { restarted: true }), {
      restarted: true,
    });
  } finally {
    r.stop();
  }
});
test("RPC timeout terminates helper and clears pending requests", async () => {
  const r = client(300);
  try {
    await assert.rejects(r.call("hang"), { message: "timeout" });
    assert.equal(r.child, null);
    assert.equal(r.pending.size, 0);
  } finally {
    r.stop();
  }
});
test("RPC forwards account notifications", async () => {
  const r = client();
  let notified = false;
  r.on("notification", (method) => {
    notified = method === "account/rateLimits/updated";
  });
  try {
    await r.call("push");
    assert.equal(notified, true);
  } finally {
    r.stop();
  }
});
test("untrusted executable names are not passed through a shell", () => {
  assert.throws(
    () =>
      locateCodex({
        PATH: "",
        LOCALAPPDATA: "Z:/nonexistent",
        APPDATA: "Z:/nonexistent",
        CODEX_GLASS_CODEX_PATH: "cmd.exe & echo unsafe",
      }),
    { code: "codexMissing" },
  );
});
