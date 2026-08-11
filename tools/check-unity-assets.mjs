#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import {
  MANIFEST_PATH,
  MANIFEST_SCHEMA,
  REPOSITORY_ROOT,
  buildImportPlan,
  serializeManifest,
} from "./import-ios-assets-to-unity.mjs";

const MANAGED_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".wav", ".m4a", ".caf", ".aiff", ".mp3", ".ogg", ".md"]);
const ALLOWED_PRESETS = new Set([
  "platform-icon",
  "ui-sprite",
  "key-art-sprite",
  "portrait-sprite",
  "billboard-sprite",
  "audio-effect",
  "audio-stream-loop",
]);
const ALLOWED_LABELS = new Set(["bootstrap", "setup", "highschool", "pro", "pitch", "meta", "audio", null]);

function toPosix(value) {
  return value.split(path.sep).join("/");
}

function compareOrdinal(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

async function sha256File(filePath) {
  const contents = await readFile(filePath);
  return createHash("sha256").update(contents).digest("hex");
}

async function walkFiles(root) {
  const found = [];
  async function visit(directory) {
    let entries;
    try {
      entries = await readdir(directory, { withFileTypes: true });
    } catch (error) {
      if (error.code === "ENOENT") return;
      throw error;
    }
    entries.sort((left, right) => compareOrdinal(left.name, right.name));
    for (const entry of entries) {
      const item = path.join(directory, entry.name);
      if (entry.isDirectory()) await visit(item);
      else if (entry.isFile()) found.push(item);
    }
  }
  await visit(root);
  return found;
}

function creditRoot(logicalName) {
  return logicalName.replace(/-\d+$/u, "");
}

function fail(errors, message) {
  errors.push(message);
}

async function validate() {
  const errors = [];
  const manifestAbsolutePath = path.join(REPOSITORY_ROOT, MANIFEST_PATH);
  let currentText;
  let currentManifest;
  try {
    currentText = await readFile(manifestAbsolutePath, "utf8");
    currentManifest = JSON.parse(currentText);
  } catch (error) {
    throw new Error(`Cannot read ${MANIFEST_PATH}: ${error.message}`);
  }

  if (currentManifest.schema !== MANIFEST_SCHEMA) {
    fail(errors, `Unexpected manifest schema ${currentManifest.schema ?? "<missing>"}; expected ${MANIFEST_SCHEMA}.`);
  }

  const expectedManifest = await buildImportPlan();
  const expectedText = serializeManifest(expectedManifest);
  if (currentText !== expectedText) {
    fail(errors, `Manifest differs from iOS source inventory. Run node tools/import-ios-assets-to-unity.mjs.`);
  }

  const targetKeys = new Map();
  const logicalKeys = new Map();
  const expectedManagedFiles = new Set();
  const credits = await readFile(path.join(REPOSITORY_ROOT, currentManifest.credits.targetPath), "utf8");

  for (const entry of currentManifest.entries ?? []) {
    if (!entry.logicalName || !entry.sourcePath || !entry.targetPath || !entry.sourceSha256 || !entry.targetSha256) {
      fail(errors, `Incomplete manifest entry: ${JSON.stringify(entry)}`);
      continue;
    }
    const targetKey = entry.targetPath.toLocaleLowerCase("en-US");
    if (targetKeys.has(targetKey)) fail(errors, `Case-insensitive target collision: ${targetKeys.get(targetKey)} <> ${entry.targetPath}`);
    targetKeys.set(targetKey, entry.targetPath);
    const logicalScope = `${entry.kind}:${entry.logicalName}`.toLocaleLowerCase("en-US");
    if (logicalKeys.has(logicalScope)) fail(errors, `Duplicate logical key: ${logicalKeys.get(logicalScope)} <> ${entry.logicalName}`);
    logicalKeys.set(logicalScope, entry.logicalName);

    if (!ALLOWED_PRESETS.has(entry.importPreset)) fail(errors, `Unknown import preset ${entry.importPreset} for ${entry.logicalName}.`);
    if (!ALLOWED_LABELS.has(entry.addressableLabel)) fail(errors, `Unknown Addressables label ${entry.addressableLabel} for ${entry.logicalName}.`);
    if (entry.kind !== "platform-icon-source" && entry.addressableLabel === null) {
      fail(errors, `Runtime asset ${entry.logicalName} has no local Addressables label.`);
    }

    const sourceAbsolute = path.join(REPOSITORY_ROOT, entry.sourcePath);
    const targetAbsolute = path.join(REPOSITORY_ROOT, entry.targetPath);
    try {
      const [sourceChecksum, targetChecksum] = await Promise.all([sha256File(sourceAbsolute), sha256File(targetAbsolute)]);
      if (sourceChecksum !== entry.sourceSha256) fail(errors, `Source checksum drift for ${entry.sourcePath}.`);
      if (targetChecksum !== entry.targetSha256) fail(errors, `Target checksum mismatch for ${entry.targetPath}.`);
      if (sourceChecksum !== targetChecksum && !entry.transformation) {
        fail(errors, `Copied asset is not byte-identical: ${entry.targetPath}.`);
      }
      if (entry.transformation && entry.transformation !== "ffmpeg-pcm-s16le-44100-stereo-bitexact-v1") {
        fail(errors, `Unknown deterministic transformation ${entry.transformation} for ${entry.logicalName}.`);
      }
    } catch (error) {
      fail(errors, `Missing or unreadable asset ${entry.targetPath}: ${error.message}`);
    }

    expectedManagedFiles.add(entry.targetPath);
    if (entry.kind === "audio") {
      const rootName = creditRoot(entry.logicalName);
      if (!credits.includes(`\`${rootName}.`)) {
        fail(errors, `Audio ${entry.logicalName} has no matching credit root in ${currentManifest.credits.targetPath}.`);
      }
    }
  }

  try {
    const copiedCreditsChecksum = await sha256File(path.join(REPOSITORY_ROOT, currentManifest.credits.targetPath));
    const sourceCreditsChecksum = await sha256File(path.join(REPOSITORY_ROOT, currentManifest.credits.sourcePath));
    if (copiedCreditsChecksum !== currentManifest.credits.sha256 || sourceCreditsChecksum !== currentManifest.credits.sha256) {
      fail(errors, `Audio credits checksum mismatch; preserve apps/ios/Audio/CREDITS.md verbatim.`);
    }
  } catch (error) {
    fail(errors, `Missing audio credits: ${error.message}`);
  }
  expectedManagedFiles.add(currentManifest.credits.targetPath);

  for (const root of [
    currentManifest.destinations.artRoot,
    currentManifest.destinations.audioRoot,
    currentManifest.destinations.androidNotificationIconRoot,
  ]) {
    if (!root) continue;
    const files = await walkFiles(path.join(REPOSITORY_ROOT, root));
    for (const file of files) {
      if (file.endsWith(".meta") || !MANAGED_EXTENSIONS.has(path.extname(file).toLowerCase())) continue;
      const relative = toPosix(path.relative(REPOSITORY_ROOT, file));
      if (!expectedManagedFiles.has(relative)) fail(errors, `Unmanifested managed asset: ${relative}.`);
    }
  }

  if (currentManifest.summary.entryCount !== currentManifest.entries.length) fail(errors, `Manifest entryCount does not match entries.`);
  const calculatedImages = currentManifest.entries.filter((entry) => entry.kind === "image").length;
  const calculatedIcons = currentManifest.entries.filter((entry) => entry.kind === "platform-icon-source").length;
  const calculatedAudio = currentManifest.entries.filter((entry) => entry.kind === "audio").length;
  if (currentManifest.summary.imageCount !== calculatedImages) fail(errors, `Manifest imageCount does not match entries.`);
  if (currentManifest.summary.platformIconSourceCount !== calculatedIcons) fail(errors, `Manifest platformIconSourceCount does not match entries.`);
  if (currentManifest.summary.audioCount !== calculatedAudio) fail(errors, `Manifest audioCount does not match entries.`);

  return {
    errors,
    summary: {
      catalogs: currentManifest.summary.catalogCount,
      images: calculatedImages,
      platformIconSources: calculatedIcons,
      audio: calculatedAudio,
      checkedFiles: expectedManagedFiles.size,
    },
  };
}

async function main() {
  const unexpectedArguments = process.argv.slice(2).filter((argument) => argument !== "--json");
  if (unexpectedArguments.length > 0) throw new Error(`Unknown argument: ${unexpectedArguments.join(", ")}`);
  const result = await validate();
  if (result.errors.length > 0) {
    for (const error of result.errors) process.stderr.write(`- ${error}\n`);
    throw new Error(`${result.errors.length} Unity asset validation error(s).`);
  }
  if (process.argv.includes("--json")) process.stdout.write(`${JSON.stringify({ ok: true, ...result.summary })}\n`);
  else process.stdout.write(`Unity asset check passed: ${result.summary.checkedFiles} files (${result.summary.images} images, ${result.summary.platformIconSources} icon sources, ${result.summary.audio} audio).\n`);
}

main().catch((error) => {
  process.stderr.write(`Unity asset check failed: ${error.message}\n`);
  process.exitCode = 1;
});
