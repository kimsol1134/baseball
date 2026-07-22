import { execFileSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const executableExtension = process.platform === "win32" ? ".exe" : "";
const localRustc = path.join(repositoryRoot, ".toolchains", "cargo", "bin", `rustc${executableExtension}`);
const rustc = existsSync(localRustc) ? localRustc : "rustc";
const rustEnvironment = existsSync(localRustc)
  ? {
      ...process.env,
      RUSTUP_HOME: path.join(repositoryRoot, ".toolchains", "rustup"),
      CARGO_HOME: path.join(repositoryRoot, ".toolchains", "cargo"),
    }
  : process.env;
const targetTriple = execFileSync(rustc, ["--print", "host-tuple"], {
  cwd: repositoryRoot,
  encoding: "utf8",
  env: rustEnvironment,
}).trim();
const binaryDirectory = path.join(repositoryRoot, "apps", "windows", "src-tauri", "binaries");
const sidecar = path.join(binaryDirectory, `simulation-sidecar-${targetTriple}${executableExtension}`);
if (!existsSync(sidecar)) throw new Error(`Missing sidecar: ${sidecar}`);

const runtimeDirectory = path.join(binaryDirectory, "swift-runtime");
const environment = process.platform === "win32"
  ? { ...process.env, PATH: `${runtimeDirectory}${path.delimiter}${process.env.PATH ?? ""}` }
  : process.env;
const request = `${JSON.stringify({ jsonrpc: "2.0", id: "package-smoke", method: "health" })}\n`;
const result = spawnSync(sidecar, [], {
  cwd: repositoryRoot,
  encoding: "utf8",
  env: environment,
  input: request,
});
if (result.error) throw result.error;
if (result.status !== 0) throw new Error(result.stderr || `Sidecar exited with ${result.status}`);
const line = result.stdout.split(/\r?\n/).find((item) => item.trim());
if (!line) throw new Error("Sidecar returned no response");
const response = JSON.parse(line);
if (response.error || response.result?.status !== "ok") {
  throw new Error(`Sidecar health check failed: ${line}`);
}
process.stdout.write(`Sidecar ${response.result.coreVersion} ready for ${targetTriple}\n`);
