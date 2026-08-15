#!/usr/bin/env node

import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = resolve(
  root,
  process.argv[2] ?? "artifacts/android-compose/baseline-2026-08-13/phase-0-manifest.json",
);

function run(command, args, { includeStderr = false } = {}) {
  try {
    const result = spawnSync(command, args, {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    if (result.status !== 0) return null;
    return [result.stdout, includeStderr ? result.stderr : ""].filter(Boolean).join("").trim();
  } catch {
    return null;
  }
}

function sha256(path) {
  if (!existsSync(path)) return null;
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function fileEvidence(path, evidence, note) {
  return { path: path.replace(`${root}/`, ""), sha256: sha256(path), evidence, note };
}

const statusLines = (run("git", ["status", "--short"]) ?? "").split("\n").filter(Boolean);
const trackedDirty = statusLines.filter((line) => !line.startsWith("??")).map((line) => line.slice(3));
const untracked = statusLines.filter((line) => line.startsWith("??")).map((line) => line.slice(3));
const unityVersionPath = resolve(root, "apps/android-pitch-unity/ProjectSettings/ProjectVersion.txt");
const unityVersion = existsSync(unityVersionPath)
  ? readFileSync(unityVersionPath, "utf8").trim()
  : null;
const knownOracleAab = resolve(root, "artifacts/android/1.0.0-1/baseball-android-1.0.0-1-debug-signed-verification.aab");
const adb = resolve(process.env.ANDROID_SDK_ROOT ?? "/Users/solkim/Library/Android/sdk", "platform-tools/adb");

const baseline = {
  baselineId: "ANDROID-COMPOSE-PHASE-0-2026-08-13",
  capturedAtUtc: new Date().toISOString(),
  evidenceLegend: {
    SOURCE: "checked-in repository or fixture content",
    VERIFIED: "command or local runtime check executed by this pass",
    EXTERNAL: "pre-existing artifact, prior evidence, or a dependency outside this pass",
    NOT_RUN: "not executed or not available in this environment",
  },
  repository: {
    head: { value: run("git", ["rev-parse", "HEAD"]), evidence: "SOURCE" },
    worktree: {
      state: statusLines.length === 0 ? "clean" : "dirty-preserved",
      trackedDirty,
      untracked,
      evidence: "VERIFIED",
      note: "The migration pass is additive and does not reset, checkout, clean, revert, commit, or push.",
    },
  },
  oracle: {
    path: "apps/android-unity",
    unityVersion: { value: "6000.3.19f1", evidence: "SOURCE" },
    role: "current oracle/source; not edited by the migration pass",
    observedProjectSettings: fileEvidence(
      resolve(root, "apps/android-unity/ProjectSettings/ProjectSettings.asset"),
      "EXTERNAL",
      "Pre-existing dirty oracle evidence; preserved in place.",
    ),
  },
  migrationSources: {
    composeApp: fileEvidence(resolve(root, "apps/android/settings.gradle.kts"), "SOURCE", "T-001 skeleton"),
    pitchUnityProject: fileEvidence(resolve(root, "apps/android-pitch-unity/ProjectSettings/ProjectVersion.txt"), "SOURCE", unityVersion),
    legacyCurrentFixture: fileEvidence(resolve(root, "apps/android/game-persistence/src/test/resources/legacy/save-v1-current.json"), "SOURCE", "Pulled from the current oracle emulator save path before compatibility tests."),
    legacyBackupFixture: fileEvidence(resolve(root, "apps/android/game-persistence/src/test/resources/legacy/save-v1-backup-1.json"), "SOURCE", "Pulled from the current oracle emulator save backup before compatibility tests."),
  },
  toolchain: {
    unityEditor: { path: "/Applications/Unity/Hub/Editor/6000.3.19f1/Unity.app/Contents/MacOS/Unity", exists: existsSync("/Applications/Unity/Hub/Editor/6000.3.19f1/Unity.app/Contents/MacOS/Unity"), evidence: "VERIFIED" },
    androidSdk: { path: process.env.ANDROID_SDK_ROOT ?? "/Users/solkim/Library/Android/sdk", exists: existsSync(process.env.ANDROID_SDK_ROOT ?? "/Users/solkim/Library/Android/sdk"), evidence: "VERIFIED" },
    adb: { path: adb, devices: run(adb, ["devices"]), evidence: "VERIFIED" },
    java: { version: run("java", ["-version"], { includeStderr: true }), evidence: "VERIFIED" },
    gradleWrapper: { version: run("apps/android/gradlew", ["--version"]), evidence: "VERIFIED" },
    dependencyPins: { path: "apps/android/gradle/libs.versions.toml", evidence: "SOURCE" },
  },
  preExistingArtifact: fileEvidence(knownOracleAab, "EXTERNAL", "Pre-existing oracle AAB; not rebuilt or overwritten by this pass."),
  implementationEvidence: {
    initialAudit: "The first pass began from the dirty worktree above; existing oracle edits and artifacts remain untouched.",
    unityDeviceAndPlayValidation: "NOT_RUN at Phase 0 capture time; later local emulator evidence is recorded separately in MIGRATION_STATUS.md.",
  },
};

mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(baseline, null, 2)}\n`);
console.log(output);
