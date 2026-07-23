import { execFileSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const packagePath = path.join(repositoryRoot, "packages", "simulation-core");
const binaryDirectory = path.join(
  repositoryRoot,
  "apps",
  "windows",
  "src-tauri",
  "binaries",
);
const executableExtension = process.platform === "win32" ? ".exe" : "";
const localRustc = path.join(
  repositoryRoot,
  ".toolchains",
  "cargo",
  "bin",
  `rustc${executableExtension}`,
);
const rustc = existsSync(localRustc) ? localRustc : "rustc";
const toolchainEnvironment = existsSync(localRustc)
  ? {
      ...process.env,
      RUSTUP_HOME: path.join(repositoryRoot, ".toolchains", "rustup"),
      CARGO_HOME: path.join(repositoryRoot, ".toolchains", "cargo"),
    }
  : process.env;

execFileSync(
  "swift",
  [
    "build",
    "--package-path",
    packagePath,
    "--configuration",
    "release",
    "--product",
    "simulation-sidecar",
  ],
  { cwd: repositoryRoot, stdio: "inherit" },
);

const swiftBuildDirectory = execFileSync(
  "swift",
  [
    "build",
    "--package-path",
    packagePath,
    "--configuration",
    "release",
    "--show-bin-path",
  ],
  { cwd: repositoryRoot, encoding: "utf8" },
).trim();

const targetTriple = execFileSync(rustc, ["--print", "host-tuple"], {
  cwd: repositoryRoot,
  encoding: "utf8",
  env: toolchainEnvironment,
}).trim();
const source = path.join(
  swiftBuildDirectory,
  `simulation-sidecar${executableExtension}`,
);
const destination = path.join(
  binaryDirectory,
  `simulation-sidecar-${targetTriple}${executableExtension}`,
);

if (!existsSync(source)) {
  throw new Error(`Swift sidecar was not produced at ${source}`);
}

mkdirSync(binaryDirectory, { recursive: true });
// Recreate the bundle target instead of overwriting it in place. On macOS an
// overwritten file can retain stale Gatekeeper/provenance xattrs and hang on
// launch even when its bytes are identical to the freshly built executable.
rmSync(destination, { force: true });
copyFileSync(source, destination);
if (process.platform !== "win32") {
  chmodSync(destination, 0o755);
}

function findNamedFile(root, expectedName, depth = 0) {
  if (!root || !existsSync(root) || depth > 9) return undefined;
  let entries;
  try {
    entries = readdirSync(root, { withFileTypes: true });
  } catch {
    return undefined;
  }
  const direct = entries.find(
    (entry) => entry.isFile() && entry.name.toLowerCase() === expectedName.toLowerCase(),
  );
  if (direct) return path.join(root, direct.name);
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const found = findNamedFile(path.join(root, entry.name), expectedName, depth + 1);
    if (found) return found;
  }
  return undefined;
}

function prepareWindowsSwiftRuntime() {
  const targetInfo = JSON.parse(execFileSync("swiftc", ["-print-target-info"], {
    cwd: repositoryRoot,
    encoding: "utf8",
  }));
  const candidateRoots = new Set([
    ...(targetInfo.paths?.runtimeLibraryPaths ?? []),
    targetInfo.paths?.runtimeResourcePath,
    process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, "Programs", "Swift") : undefined,
    process.env.ProgramFiles ? path.join(process.env.ProgramFiles, "Swift") : undefined,
  ].filter(Boolean));

  let swiftCore;
  for (const root of candidateRoots) {
    swiftCore = findNamedFile(root, "swiftCore.dll");
    if (swiftCore) break;
  }
  if (!swiftCore) {
    throw new Error(`Swift runtime directory was not found. Checked: ${[...candidateRoots].join(", ")}`);
  }

  const runtimeSource = path.dirname(swiftCore);
  const runtimeDestination = path.join(binaryDirectory, "swift-runtime");
  rmSync(runtimeDestination, { force: true, recursive: true });
  mkdirSync(runtimeDestination, { recursive: true });

  const runtimeFiles = readdirSync(runtimeSource)
    .filter((name) => name.toLowerCase().endsWith(".dll"))
    .filter((name) => statSync(path.join(runtimeSource, name)).isFile())
    .sort();
  if (!runtimeFiles.some((name) => name.toLowerCase() === "swiftcore.dll")) {
    throw new Error(`swiftCore.dll is missing from ${runtimeSource}`);
  }
  for (const name of runtimeFiles) {
    copyFileSync(path.join(runtimeSource, name), path.join(runtimeDestination, name));
  }
  writeFileSync(
    path.join(runtimeDestination, "windows-runtime-manifest.json"),
    `${JSON.stringify({
      compilerVersion: targetInfo.compilerVersion,
      target: targetInfo.target?.triple,
      runtimeFiles,
    }, null, 2)}\n`,
  );
  process.stdout.write(`Bundled ${runtimeFiles.length} Swift runtime DLLs\n`);
}

if (process.platform === "win32") {
  prepareWindowsSwiftRuntime();
}

process.stdout.write(`Prepared ${path.relative(repositoryRoot, destination)}\n`);
