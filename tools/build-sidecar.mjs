import { execFileSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
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

const targetTriple = execFileSync(rustc, ["--print", "host-tuple"], {
  cwd: repositoryRoot,
  encoding: "utf8",
  env: toolchainEnvironment,
}).trim();
const source = path.join(
  packagePath,
  ".build",
  "release",
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
copyFileSync(source, destination);
if (process.platform !== "win32") {
  chmodSync(destination, 0o755);
}

process.stdout.write(`Prepared ${path.relative(repositoryRoot, destination)}\n`);

