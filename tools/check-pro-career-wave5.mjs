#!/usr/bin/env node

import { spawnSync } from "node:child_process";

const result = spawnSync(
  "swift",
  [
    "test",
    "--package-path",
    "packages/simulation-core",
    "--build-path",
    ".build/pro-career-depth-swift",
    "--filter",
    "ProCareerWave5Tests",
  ],
  { cwd: process.cwd(), encoding: "utf8" }
);

if (result.error) {
  console.error(`pro-career Wave 5 gate failed to start: ${result.error.message}`);
  process.exit(1);
}

process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");

const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
if (!output.includes("WAVE5_DISTRIBUTION")) {
  console.error("pro-career Wave 5 gate did not emit distribution evidence");
  process.exit(1);
}

process.exit(result.status ?? 1);
