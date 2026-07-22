import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const depotDirectory = path.resolve(process.argv[2] ?? "");
const artifactRoot = path.resolve(repositoryRoot, "artifacts", "steam");
if (!depotDirectory.startsWith(`${artifactRoot}${path.sep}`)) {
  throw new Error("Provide a depot directory under artifacts/steam");
}
const manifestPath = path.join(depotDirectory, "BUILD_MANIFEST.json");
if (!existsSync(manifestPath)) throw new Error(`Missing depot manifest: ${manifestPath}`);
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
for (const file of manifest.files) {
  const absolute = path.join(depotDirectory, ...file.path.split("/"));
  if (!existsSync(absolute)) throw new Error(`Missing depot file: ${file.path}`);
  const checksum = createHash("sha256").update(readFileSync(absolute)).digest("hex");
  if (checksum !== file.sha256) throw new Error(`Checksum mismatch: ${file.path}`);
}

const isWindows = manifest.platform === "windows";
const sidecar = isWindows
  ? path.join(depotDirectory, `simulation-sidecar-${manifest.targetTriple}.exe`)
  : path.join(depotDirectory, "Project Diamond Soul.app", "Contents", "MacOS", "simulation-sidecar");
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
