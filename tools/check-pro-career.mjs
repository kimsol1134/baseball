#!/usr/bin/env node

import { spawnSync } from "node:child_process";

const result = spawnSync(
  "swift",
  [
    "test",
    "--package-path",
    "packages/simulation-core",
    "--filter",
    "ProCareerLegacyWave4Tests",
  ],
  { stdio: "inherit" }
);

if (result.error) {
  console.error(`pro-career Wave 4 gate failed to start: ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 1);
