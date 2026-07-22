import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const requestedEdition = process.argv[2];
if (!new Set(["full", "demo"]).has(requestedEdition)) {
  throw new Error("Usage: node tools/build-steam-depot.mjs <full|demo>");
}
if (!new Set(["win32", "darwin"]).has(process.platform)) {
  throw new Error("Steam desktop depots must be built on Windows or macOS");
}

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
const releaseEdition = requestedEdition === "full" ? "steam_full" : "steam_demo";
const buildEnvironment = { ...process.env, VITE_RELEASE_EDITION: releaseEdition };
if (process.platform === "darwin") {
  for (const variable of [
    "APPLE_ID",
    "APPLE_PASSWORD",
    "APPLE_TEAM_ID",
    "APPLE_API_ISSUER",
    "APPLE_API_KEY",
    "APPLE_API_KEY_PATH",
  ]) {
    if (!buildEnvironment[variable]?.trim()) delete buildEnvironment[variable];
  }
}
const platformName = process.platform === "win32" ? "windows" : "macos";
const architecture = targetTriple.startsWith("aarch64") ? "arm64" : "x64";
const artifactRoot = path.join(repositoryRoot, "artifacts", "steam");
const depotDirectory = path.join(artifactRoot, requestedEdition, `${platformName}-${architecture}`);

if (!path.resolve(depotDirectory).startsWith(`${path.resolve(artifactRoot)}${path.sep}`)) {
  throw new Error(`Refusing to replace unexpected artifact path: ${depotDirectory}`);
}
rmSync(depotDirectory, { recursive: true, force: true });
mkdirSync(depotDirectory, { recursive: true });

execFileSync(process.execPath, [path.join(repositoryRoot, "tools", "build-sidecar.mjs")], {
  cwd: repositoryRoot,
  env: buildEnvironment,
  stdio: "inherit",
});

const tauriArguments = [path.join(repositoryRoot, "tools", "run-tauri.mjs"), "build"];
if (process.platform === "win32") tauriArguments.push("--no-bundle");
else {
  tauriArguments.push("--bundles", "app");
  if (process.env.APPLE_SIGNING_IDENTITY) {
    tauriArguments.push("--config", JSON.stringify({
      bundle: { macOS: { signingIdentity: process.env.APPLE_SIGNING_IDENTITY } },
    }));
  }
}
execFileSync(process.execPath, tauriArguments, {
  cwd: repositoryRoot,
  env: buildEnvironment,
  stdio: "inherit",
});

const tauriRoot = path.join(repositoryRoot, "apps", "windows", "src-tauri");
if (process.platform === "win32") {
  const releaseDirectory = path.join(tauriRoot, "target", "release");
  const binaryDirectory = path.join(tauriRoot, "binaries");
  const appExecutable = path.join(releaseDirectory, "baseball.exe");
  const sidecar = path.join(releaseDirectory, "simulation-sidecar.exe");
  const runtime = path.join(binaryDirectory, "swift-runtime");
  for (const required of [appExecutable, sidecar, path.join(runtime, "swiftCore.dll")]) {
    if (!existsSync(required)) throw new Error(`Steam depot input is missing: ${required}`);
  }
  cpSync(appExecutable, path.join(depotDirectory, "baseball.exe"));
  cpSync(sidecar, path.join(depotDirectory, "simulation-sidecar.exe"));
  cpSync(runtime, path.join(depotDirectory, "swift-runtime"), { recursive: true });
  cpSync(path.join(tauriRoot, "THIRD_PARTY_NOTICES.md"), path.join(depotDirectory, "THIRD_PARTY_NOTICES.md"));
} else {
  const appBundle = path.join(tauriRoot, "target", "release", "bundle", "macos", "야구 못하면 또 환생함.app");
  if (!existsSync(appBundle)) throw new Error(`Steam app bundle is missing: ${appBundle}`);
  cpSync(appBundle, path.join(depotDirectory, path.basename(appBundle)), { recursive: true, preserveTimestamps: true });
  const executable = path.join(depotDirectory, "야구 못하면 또 환생함.app", "Contents", "MacOS", "baseball");
  const sidecar = path.join(depotDirectory, "야구 못하면 또 환생함.app", "Contents", "MacOS", "simulation-sidecar");
  chmodSync(executable, 0o755);
  chmodSync(sidecar, 0o755);
}

function listFiles(directory, prefix = "") {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const relative = path.join(prefix, entry.name);
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...listFiles(absolute, relative));
    else if (entry.isFile()) files.push({ relative, absolute });
  }
  return files;
}

const packageVersion = JSON.parse(readFileSync(path.join(repositoryRoot, "package.json"), "utf8")).version;
const files = listFiles(depotDirectory).map(({ relative, absolute }) => ({
  path: relative.split(path.sep).join("/"),
  bytes: statSync(absolute).size,
  sha256: createHash("sha256").update(readFileSync(absolute)).digest("hex"),
}));
const manifest = {
  format: "BaseballSteamDepot",
  schemaVersion: 1,
  version: packageVersion,
  edition: releaseEdition,
  platform: platformName,
  architecture,
  targetTriple,
  files,
};
writeFileSync(path.join(depotDirectory, "BUILD_MANIFEST.json"), `${JSON.stringify(manifest, null, 2)}\n`);
process.stdout.write(`Steam ${requestedEdition} depot ready: ${path.relative(repositoryRoot, depotDirectory)}\n`);
