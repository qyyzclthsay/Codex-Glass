const { CodexRPC } = require("../src/core/rpc.cjs");
const { normalize } = require("../src/core/model.cjs");
(async () => {
  const rpc = new CodexRPC();
  try {
    const { account } = await rpc.call("account/read", { refreshToken: false });
    if (account?.type !== "chatgpt")
      throw new Error("A ChatGPT login is required.");
    const result = await rpc.call("account/rateLimits/read");
    const snapshot = normalize(account, result);
    // Intentionally omit identity, email, tokens, raw replies, and local paths.
    console.log(
      JSON.stringify(
        {
          success: true,
          plan: snapshot.plan,
          windows: snapshot.windows.map((w) => ({
            minutes: w.minutes,
            remaining: w.remaining,
            hasResetTime: !!w.resetsAt,
          })),
          resetCredits: snapshot.resets.count,
        },
        null,
        2,
      ),
    );
  } catch (error) {
    console.error(error.code || error.message);
    process.exitCode = 1;
  } finally {
    rpc.stop();
  }
})();
