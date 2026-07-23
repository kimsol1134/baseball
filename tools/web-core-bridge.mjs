import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const executable = process.env.SIMULATION_SIDECAR_PATH
  ?? join(root, "packages/simulation-core/.build/release/simulation-sidecar");
const host = "127.0.0.1";
const port = Number(process.env.BASEBALL_CORE_PORT ?? "8787");
const MAX_REQUEST_BYTES = 2 * 1024 * 1024;

if (!existsSync(executable)) {
  console.error(`Web core bridge: sidecar not found at ${executable}. Run npm run prepare:sidecar first.`);
  process.exit(1);
}

function execute(request) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, [], { stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    const timeout = setTimeout(() => {
      child.kill();
      reject(new Error("simulation sidecar timed out"));
    }, 15_000);
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", (error) => { clearTimeout(timeout); reject(error); });
    child.on("close", (code) => {
      clearTimeout(timeout);
      const line = stdout.trim().split("\n").find(Boolean);
      if (code === 0 && line) resolve(line);
      else reject(new Error(stderr.trim() || `simulation sidecar exited with ${code}`));
    });
    child.stdin.end(`${request}\n`);
  });
}

const server = createServer((request, response) => {
  if (request.method === "GET" && request.url === "/health") {
    response.writeHead(200, { "content-type": "text/plain" });
    response.end("ready");
    return;
  }
  if (request.method !== "POST" || request.url !== "/api/core") {
    response.writeHead(404).end();
    return;
  }
  let body = "";
  request.setEncoding("utf8");
  request.on("data", (chunk) => {
    body += chunk;
    if (Buffer.byteLength(body) > MAX_REQUEST_BYTES) request.destroy();
  });
  request.on("end", async () => {
    try {
      const result = await execute(body);
      response.writeHead(200, { "content-type": "application/json; charset=utf-8" });
      response.end(result);
    } catch (error) {
      response.writeHead(502, { "content-type": "application/json; charset=utf-8" });
      response.end(JSON.stringify({ message: error instanceof Error ? error.message : "simulation bridge failed" }));
    }
  });
});

server.listen(port, host, () => console.log(`Web core bridge ready at http://${host}:${port}`));

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
