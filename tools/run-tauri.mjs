import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const repositoryRoot = fileURLToPath(new URL("..", import.meta.url));
const tauri = path.join(
  repositoryRoot,
  "node_modules",
  "@tauri-apps",
  "cli",
  "tauri.js",
);
const cargoBin = path.join(repositoryRoot, ".toolchains", "cargo", "bin");
const localToolchain = existsSync(cargoBin);
const environment = localToolchain
  ? {
      ...process.env,
      PATH: `${cargoBin}${path.delimiter}${process.env.PATH ?? ""}`,
      RUSTUP_HOME: path.join(repositoryRoot, ".toolchains", "rustup"),
      CARGO_HOME: path.join(repositoryRoot, ".toolchains", "cargo"),
    }
  : process.env;

const result = spawnSync(process.execPath, [tauri, ...process.argv.slice(2)], {
  cwd: path.join(repositoryRoot, "apps", "windows"),
  env: environment,
  stdio: "inherit",
});

if (result.error) {
  throw result.error;
}

process.exitCode = result.status ?? 1;
