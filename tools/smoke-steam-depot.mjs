import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { validateSteamDepot } from "./steam-depot-manifest.mjs";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const depotDirectory = path.resolve(process.argv[2] ?? "");
const artifactRoot = path.resolve(repositoryRoot, "artifacts", "steam");
if (!depotDirectory.startsWith(`${artifactRoot}${path.sep}`)) {
  throw new Error("Provide a depot directory under artifacts/steam");
}
const manifest = validateSteamDepot(depotDirectory);

const isWindows = manifest.platform === "windows";
const sidecar = isWindows
  ? path.join(depotDirectory, "simulation-sidecar.exe")
  : path.join(depotDirectory, "야구 못하면 또 환생함.app", "Contents", "MacOS", "simulation-sidecar");
const runtime = path.join(depotDirectory, "swift-runtime");
const environment = isWindows
  ? { ...process.env, PATH: `${runtime}${path.delimiter}${process.env.PATH ?? ""}` }
  : process.env;
const result = spawnSync(sidecar, [], {
  cwd: depotDirectory,
  encoding: "utf8",
  env: environment,
  input: `${JSON.stringify({ jsonrpc: "2.0", id: "steam-depot-smoke", method: "health" })}\n`,
});
if (result.error) throw result.error;
if (result.status !== 0) throw new Error(result.stderr || `Sidecar exited with ${result.status}`);
const responseLine = result.stdout.split(/\r?\n/).find((line) => line.trim());
const response = responseLine ? JSON.parse(responseLine) : undefined;
if (response?.result?.status !== "ok") throw new Error(`Invalid sidecar response: ${result.stdout}`);
process.stdout.write(`Verified ${manifest.edition} ${manifest.platform}-${manifest.architecture} depot (${manifest.files.length} files)\n`);
