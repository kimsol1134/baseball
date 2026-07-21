import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const executableExtension = process.platform === "win32" ? ".exe" : "";
const localCargo = path.join(
  repositoryRoot,
  ".toolchains",
  "cargo",
  "bin",
  `cargo${executableExtension}`,
);
const cargo = existsSync(localCargo) ? localCargo : "cargo";
const environment = existsSync(localCargo)
  ? {
      ...process.env,
      RUSTUP_HOME: path.join(repositoryRoot, ".toolchains", "rustup"),
      CARGO_HOME: path.join(repositoryRoot, ".toolchains", "cargo"),
    }
  : process.env;

const result = spawnSync(cargo, process.argv.slice(2), {
  cwd: repositoryRoot,
  env: environment,
  stdio: "inherit",
});

if (result.error) {
  throw result.error;
}

process.exitCode = result.status ?? 1;
