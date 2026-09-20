const readline = require("node:readline");
readline.createInterface({ input: process.stdin }).on("line", (line) => {
  const m = JSON.parse(line);
  if (m.method === "initialize")
    process.stdout.write(JSON.stringify({ id: m.id, result: {} }) + "\n");
  if (m.method === "echo")
    process.stdout.write(JSON.stringify({ id: m.id, result: m.params }) + "\n");
  if (m.method === "exit") process.exit(0);
  if (m.method === "refused")
    process.stdout.write(
      JSON.stringify({
        id: m.id,
        error: { message: "401 unauthorized secret example token" },
      }) + "\n",
    );
  if (m.method === "push") {
    process.stdout.write(
      JSON.stringify({ method: "account/rateLimits/updated", params: {} }) +
        "\n",
    );
    process.stdout.write(JSON.stringify({ id: m.id, result: {} }) + "\n");
  }
});
