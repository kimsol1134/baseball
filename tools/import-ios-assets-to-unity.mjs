#!/usr/bin/env node

import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { copyFile, mkdir, mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { promisify } from "node:util";

export const MANIFEST_SCHEMA = "baseball-unity-asset-manifest-v1";

const SCRIPT_PATH = fileURLToPath(import.meta.url);
export const REPOSITORY_ROOT = path.resolve(path.dirname(SCRIPT_PATH), "..");
const IOS_CATALOG_ROOT = "apps/ios/Sources/Assets.xcassets";
const IOS_AUDIO_ROOT = "apps/ios/Audio";
const UNITY_ART_ROOT = "apps/android-unity/Assets/Game/Art";
const UNITY_AUDIO_ROOT = "apps/android-unity/Assets/Game/Audio";
const ANDROID_GENERATED_ICON_ROOT = `${UNITY_ART_ROOT}/PlatformIcons`;
const ANDROID_NOTIFICATION_ICON_ROOT =
  "apps/android-unity/Assets/Plugins/Android/BaseballManifest.androidlib/res/drawable";
const LEGACY_ANDROID_NOTIFICATION_ICON_ROOT = "apps/android-unity/Assets/Plugins/Android/res/drawable";
export const MANIFEST_PATH = "apps/android-unity/Assets/Game/Content/Manifests/asset-manifest.json";

const AUDIO_EXTENSIONS = new Set([".wav", ".m4a", ".caf", ".aiff", ".mp3", ".ogg"]);
const execFileAsync = promisify(execFile);

function toPosix(value) {
  return value.split(path.sep).join("/");
}

function compareOrdinal(left, right) {
  return left < right ? -1 : left > right ? 1 : 0;
}

function repositoryPath(absolutePath) {
  return toPosix(path.relative(REPOSITORY_ROOT, absolutePath));
}

async function sha256File(filePath) {
  const contents = await readFile(filePath);
  return createHash("sha256").update(contents).digest("hex");
}

function sha256Bytes(contents) {
  return createHash("sha256").update(contents).digest("hex");
}

async function androidCrowdLoopWav(source) {
  const temporaryRoot = await mkdtemp(path.join(os.tmpdir(), "baseball-crowd-loop-"));
  const target = path.join(temporaryRoot, "crowd-loop.wav");
  try {
    await execFileAsync("ffmpeg", [
      "-nostdin", "-v", "error", "-y", "-i", source,
      "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
      "-ac", "2", "-ar", "44100", "-c:a", "pcm_s16le", target,
    ]);
    return await readFile(target);
  } catch (error) {
    throw new Error(`ffmpeg is required to create the Android crowd loop WAV: ${error.message}`);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
}

function sha256Text(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

async function walkFiles(root) {
  const found = [];
  async function visit(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
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

function classifyImage(logicalName, catalogKind) {
  if (catalogKind === "appiconset") {
    return { category: "PlatformIcons", purpose: "android-icon-source", importPreset: "platform-icon", addressableLabel: null };
  }
  if (logicalName === "LaunchLogo") {
    return { category: "Bootstrap", purpose: "launch-logo", importPreset: "ui-sprite", addressableLabel: "bootstrap" };
  }
  if (logicalName.startsWith("KeyArt")) {
    const proArt = new Set(["KeyArtProStadiumTunnel", "KeyArtMajorDebut", "KeyArtRetirement"]);
    return { category: "KeyArt", purpose: "key-art", importPreset: "key-art-sprite", addressableLabel: proArt.has(logicalName) ? "pro" : "highschool" };
  }
  if (logicalName.startsWith("Portrait")) {
    return {
      category: "Portraits",
      purpose: "character-portrait",
      importPreset: "portrait-sprite",
      addressableLabel: logicalName.startsWith("PortraitPlayerPro") ? "pro" : "highschool",
    };
  }
  if (logicalName.startsWith("PresetArt")) {
    return { category: "Presets", purpose: "pitcher-preset-art", importPreset: "portrait-sprite", addressableLabel: "setup" };
  }
  if (logicalName.startsWith("SceneArt")) {
    return { category: "Scenes", purpose: "scene-art", importPreset: "ui-sprite", addressableLabel: "meta" };
  }
  if (logicalName.startsWith("MemoryArt")) {
    return { category: "Memories", purpose: "memory-art", importPreset: "ui-sprite", addressableLabel: "meta" };
  }
  if (logicalName.startsWith("TournamentBanner")) {
    return { category: "Tournaments", purpose: "tournament-banner", importPreset: "ui-sprite", addressableLabel: "highschool" };
  }
  if (logicalName === "BatterStance" || logicalName === "CatcherStance") {
    return { category: "Pitch", purpose: "pitch-stage-billboard", importPreset: "billboard-sprite", addressableLabel: "pitch" };
  }
  if (logicalName === "BloomArt" || logicalName === "LifeCardBackdrop") {
    return { category: "Meta", purpose: "meta-art", importPreset: "ui-sprite", addressableLabel: "meta" };
  }
  return { category: "Misc", purpose: "ui-art", importPreset: "ui-sprite", addressableLabel: "meta" };
}

function numericScale(image) {
  const match = /^(\d+)x$/i.exec(image.scale ?? "");
  return match ? Number(match[1]) : 1;
}

function isStandardAppearance(image) {
  return !Array.isArray(image.appearances) || image.appearances.length === 0;
}

function selectImagesetSource(images, catalogPath) {
  const candidates = images.filter((image) => typeof image.filename === "string" && image.filename.length > 0);
  if (candidates.length === 0) return null;
  const standard = candidates.filter(isStandardAppearance);
  const selectionPool = standard.length > 0 ? standard : candidates;
  selectionPool.sort((left, right) => {
    const scaleDifference = numericScale(right) - numericScale(left);
    if (scaleDifference !== 0) return scaleDifference;
    return compareOrdinal(left.filename, right.filename);
  });
  const selected = selectionPool[0];
  if (!selected) throw new Error(`No importable image in ${catalogPath}`);
  return selected;
}

function safeCatalogFilename(catalogDirectory, filename) {
  const source = path.resolve(catalogDirectory, filename);
  const prefix = `${path.resolve(catalogDirectory)}${path.sep}`;
  if (!source.startsWith(prefix)) throw new Error(`Catalog filename escapes its directory: ${filename}`);
  return source;
}

function registerUnique(map, key, description) {
  const normalized = key.toLocaleLowerCase("en-US");
  const existing = map.get(normalized);
  if (existing) throw new Error(`Case-insensitive ${description} collision: ${existing} <> ${key}`);
  map.set(normalized, key);
}

async function imageEntries() {
  const catalogRoot = path.join(REPOSITORY_ROOT, IOS_CATALOG_ROOT);
  const allFiles = await walkFiles(catalogRoot);
  const contentsFiles = allFiles.filter((file) => path.basename(file) === "Contents.json");
  const logicalNames = new Map();
  const targetPaths = new Map();
  const entries = [];
  const catalogs = [];

  for (const contentsPath of contentsFiles) {
    const catalogDirectory = path.dirname(contentsPath);
    const suffix = path.extname(catalogDirectory).slice(1).toLowerCase();
    const logicalName = path.basename(catalogDirectory, path.extname(catalogDirectory));
    const catalogPath = repositoryPath(contentsPath);
    let payload;
    try {
      payload = JSON.parse(await readFile(contentsPath, "utf8"));
    } catch (error) {
      throw new Error(`Invalid xcassets JSON at ${catalogPath}: ${error.message}`);
    }

    if (path.resolve(catalogDirectory) === path.resolve(catalogRoot)) {
      catalogs.push({ logicalName: "Assets", catalogPath, catalogKind: "root", status: "metadata-only" });
      continue;
    }

    registerUnique(logicalNames, logicalName, "xcassets logical name");

    if (suffix === "colorset") {
      catalogs.push({
        logicalName,
        catalogPath,
        catalogKind: suffix,
        status: "theme-token-only",
        note: "No bitmap is copied; the launch color is owned by BaseballTheme/theme.uss.",
      });
      continue;
    }
    if (suffix !== "imageset" && suffix !== "appiconset") {
      catalogs.push({ logicalName, catalogPath, catalogKind: suffix, status: "unsupported-no-files" });
      continue;
    }

    const images = Array.isArray(payload.images) ? payload.images : [];
    const filenames = images.filter((image) => image?.filename).map((image) => image.filename);
    const localFilenames = new Map();
    for (const filename of filenames) registerUnique(localFilenames, filename, `filename in ${catalogPath}`);
    for (const filename of filenames) {
      const source = safeCatalogFilename(catalogDirectory, filename);
      try {
        const sourceStats = await stat(source);
        if (!sourceStats.isFile()) throw new Error("not a regular file");
      } catch (error) {
        throw new Error(`Missing xcassets file ${repositoryPath(source)} referenced by ${catalogPath}: ${error.message}`);
      }
    }

    if (suffix === "imageset") {
      const selected = selectImagesetSource(images, catalogPath);
      if (!selected) throw new Error(`No filename in imageset ${catalogPath}`);
      const source = safeCatalogFilename(catalogDirectory, selected.filename);
      const extension = path.extname(selected.filename).toLowerCase();
      const classification = classifyImage(logicalName, suffix);
      const target = path.join(REPOSITORY_ROOT, UNITY_ART_ROOT, classification.category, `${logicalName}${extension}`);
      const sourceSha256 = await sha256File(source);
      const targetPath = repositoryPath(target);
      registerUnique(targetPaths, targetPath, "Unity asset target");
      entries.push({
        logicalName,
        kind: "image",
        category: classification.category,
        sourcePath: repositoryPath(source),
        sourceCatalogPath: catalogPath,
        sourceCandidates: filenames.map((filename) => repositoryPath(safeCatalogFilename(catalogDirectory, filename))).sort(),
        selectedScale: selected.scale ?? null,
        targetPath,
        sourceSha256,
        targetSha256: sourceSha256,
        purpose: classification.purpose,
        importPreset: classification.importPreset,
        addressableLabel: classification.addressableLabel,
      });
    } else {
      for (const image of images.filter((candidate) => candidate?.filename).sort((left, right) => compareOrdinal(left.filename, right.filename))) {
        const source = safeCatalogFilename(catalogDirectory, image.filename);
        const extension = path.extname(image.filename).toLowerCase();
        const variantName = path.basename(image.filename, path.extname(image.filename));
        const classification = classifyImage(logicalName, suffix);
        const target = path.join(REPOSITORY_ROOT, UNITY_ART_ROOT, classification.category, `${variantName}${extension}`);
        const sourceSha256 = await sha256File(source);
        const targetPath = repositoryPath(target);
        registerUnique(targetPaths, targetPath, "Unity asset target");
        entries.push({
          logicalName: variantName,
          sourceLogicalName: logicalName,
          kind: "platform-icon-source",
          category: classification.category,
          sourcePath: repositoryPath(source),
          sourceCatalogPath: catalogPath,
          sourceCandidates: [repositoryPath(source)],
          selectedScale: image.scale ?? null,
          targetPath,
          sourceSha256,
          targetSha256: sourceSha256,
          purpose: classification.purpose,
          importPreset: classification.importPreset,
          addressableLabel: classification.addressableLabel,
        });
      }
    }

    catalogs.push({
      logicalName,
      catalogPath,
      catalogKind: suffix,
      status: "imported",
      referencedFileCount: filenames.length,
    });
  }

  return { entries, catalogs, targetPaths };
}

async function audioEntries(targetPaths) {
  const sourceRoot = path.join(REPOSITORY_ROOT, IOS_AUDIO_ROOT);
  const files = (await walkFiles(sourceRoot)).filter((file) => AUDIO_EXTENSIONS.has(path.extname(file).toLowerCase()));
  const logicalNames = new Map();
  const entries = [];

  for (const source of files) {
    const filename = path.basename(source);
    const logicalName = path.basename(filename, path.extname(filename));
    registerUnique(logicalNames, logicalName, "audio logical name");
    const isLoop = logicalName === "crowd-loop";
    const category = isLoop ? "Ambience" : "Effects";
    const generatedWav = isLoop ? await androidCrowdLoopWav(source) : null;
    const targetFilename = isLoop ? `${logicalName}.wav` : filename;
    const target = path.join(REPOSITORY_ROOT, UNITY_AUDIO_ROOT, category, targetFilename);
    const targetPath = repositoryPath(target);
    registerUnique(targetPaths, targetPath, "Unity asset target");
    const sourceSha256 = await sha256File(source);
    const entry = {
      logicalName,
      kind: "audio",
      category,
      sourcePath: repositoryPath(source),
      sourceCatalogPath: null,
      sourceCandidates: [repositoryPath(source)],
      selectedScale: null,
      targetPath,
      sourceSha256,
      targetSha256: generatedWav == null ? sourceSha256 : sha256Bytes(generatedWav),
      transformation: isLoop ? "ffmpeg-pcm-s16le-44100-stereo-bitexact-v1" : null,
      purpose: isLoop ? "crowd-ambience-loop" : "gameplay-audio-cue",
      importPreset: isLoop ? "audio-stream-loop" : "audio-effect",
      addressableLabel: "audio",
    };
    if (generatedWav != null)
      Object.defineProperty(entry, "generatedBytes", { value: generatedWav, enumerable: false });
    entries.push(entry);
  }

  const creditsSource = path.join(sourceRoot, "CREDITS.md");
  const creditsTarget = path.join(REPOSITORY_ROOT, UNITY_AUDIO_ROOT, "CREDITS.md");
  const creditsSha256 = await sha256File(creditsSource);
  return {
    entries,
    credits: {
      sourcePath: repositoryPath(creditsSource),
      targetPath: repositoryPath(creditsTarget),
      sha256: creditsSha256,
    },
  };
}

async function generatedAndroidIconEntries(targetPaths) {
  const definitions = [
    ["AndroidAdaptiveBackground", "android-adaptive-background"],
    ["AndroidAdaptiveForeground", "android-adaptive-foreground"],
    ["AndroidMonochrome", "android-themed-monochrome"],
  ];
  const entries = [];
  for (const [logicalName, purpose] of definitions) {
    const targetPath = `${ANDROID_GENERATED_ICON_ROOT}/${logicalName}.png`;
    const absolutePath = path.join(REPOSITORY_ROOT, targetPath);
    try {
      const assetStats = await stat(absolutePath);
      if (!assetStats.isFile()) throw new Error("not a regular file");
    } catch (error) {
      throw new Error(`Missing generated Android icon ${targetPath}: ${error.message}`);
    }
    registerUnique(targetPaths, targetPath, "Unity asset target");
    const checksum = await sha256File(absolutePath);
    entries.push({
      logicalName,
      sourceLogicalName: "AppIcon",
      kind: "platform-icon-source",
      category: "PlatformIcons",
      sourcePath: targetPath,
      sourceCatalogPath: null,
      sourceCandidates: [
        "apps/ios/Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
      ],
      selectedScale: null,
      targetPath,
      sourceSha256: checksum,
      targetSha256: checksum,
      purpose,
      importPreset: "platform-icon",
      addressableLabel: null,
    });
  }

  const notificationSourcePath = `${ANDROID_GENERATED_ICON_ROOT}/AndroidMonochrome.png`;
  const notificationTargetPath = `${ANDROID_NOTIFICATION_ICON_ROOT}/baseball_notification_small.png`;
  registerUnique(targetPaths, notificationTargetPath, "Unity asset target");
  const notificationChecksum = await sha256File(path.join(REPOSITORY_ROOT, notificationSourcePath));
  entries.push({
    logicalName: "AndroidNotificationSmall",
    sourceLogicalName: "AndroidMonochrome",
    kind: "platform-icon-source",
    category: "PlatformIcons",
    sourcePath: notificationSourcePath,
    sourceCatalogPath: null,
    sourceCandidates: [notificationSourcePath],
    selectedScale: null,
    targetPath: notificationTargetPath,
    sourceSha256: notificationChecksum,
    targetSha256: notificationChecksum,
    purpose: "android-notification-small-icon",
    importPreset: "platform-icon",
    addressableLabel: null,
  });
  return entries;
}

export async function buildImportPlan() {
  const images = await imageEntries();
  const generatedAndroidIcons = await generatedAndroidIconEntries(images.targetPaths);
  const audio = await audioEntries(images.targetPaths);
  const entries = [...images.entries, ...generatedAndroidIcons, ...audio.entries]
    .sort((left, right) => compareOrdinal(left.targetPath, right.targetPath));
  const catalogs = images.catalogs.sort((left, right) => compareOrdinal(left.catalogPath, right.catalogPath));
  return {
    schema: MANIFEST_SCHEMA,
    sources: {
      imageCatalogRoot: IOS_CATALOG_ROOT,
      audioRoot: IOS_AUDIO_ROOT,
      androidGeneratedIconRoot: ANDROID_GENERATED_ICON_ROOT,
    },
    destinations: {
      artRoot: UNITY_ART_ROOT,
      audioRoot: UNITY_AUDIO_ROOT,
      androidNotificationIconRoot: ANDROID_NOTIFICATION_ICON_ROOT,
    },
    policy: {
      addressables: "local-only",
      checksum: "sha256",
      imagesetSelection: "highest-scale-standard-appearance",
      appIconHandling: "separate-android-icon-source",
    },
    summary: {
      catalogCount: catalogs.length,
      entryCount: entries.length,
      imageCount: entries.filter((entry) => entry.kind === "image").length,
      platformIconSourceCount: entries.filter((entry) => entry.kind === "platform-icon-source").length,
      audioCount: entries.filter((entry) => entry.kind === "audio").length,
    },
    catalogs,
    credits: audio.credits,
    entries,
  };
}

export function serializeManifest(manifest) {
  return `${JSON.stringify(manifest, null, 2)}\n`;
}

async function copyIfChanged(source, target, expectedSha256) {
  try {
    if ((await sha256File(target)) === expectedSha256) return false;
  } catch {
    // A missing destination is the normal first-import path.
  }
  await mkdir(path.dirname(target), { recursive: true });
  await copyFile(source, target);
  return true;
}

async function writeBytesIfChanged(contents, target, expectedSha256) {
  try {
    if ((await sha256File(target)) === expectedSha256) return false;
  } catch {
    // A missing destination is the normal first-import path.
  }
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, contents);
  return true;
}

async function prunePreviousTargets(previousManifest, expectedTargets) {
  if (!previousManifest || !Array.isArray(previousManifest.entries)) return [];
  const removed = [];
  for (const entry of previousManifest.entries) {
    if (typeof entry?.targetPath !== "string" || expectedTargets.has(entry.targetPath)) continue;
    if (!entry.targetPath.startsWith(`${UNITY_ART_ROOT}/`)
        && !entry.targetPath.startsWith(`${UNITY_AUDIO_ROOT}/`)
        && !entry.targetPath.startsWith(`${ANDROID_NOTIFICATION_ICON_ROOT}/`)
        && !entry.targetPath.startsWith(`${LEGACY_ANDROID_NOTIFICATION_ICON_ROOT}/`)) {
      throw new Error(`Refusing to prune target outside managed roots: ${entry.targetPath}`);
    }
    const absoluteTarget = path.join(REPOSITORY_ROOT, entry.targetPath);
    await rm(absoluteTarget, { force: true });
    await rm(`${absoluteTarget}.meta`, { force: true });
    removed.push(entry.targetPath);
  }
  return removed;
}

async function readPreviousManifest() {
  try {
    return JSON.parse(await readFile(path.join(REPOSITORY_ROOT, MANIFEST_PATH), "utf8"));
  } catch {
    return null;
  }
}

export async function importAssets({ checkOnly = false, prune = false } = {}) {
  const manifest = await buildImportPlan();
  const serialized = serializeManifest(manifest);
  const expectedTargets = new Set(manifest.entries.map((entry) => entry.targetPath));
  expectedTargets.add(manifest.credits.targetPath);

  if (checkOnly) {
    const current = await readFile(path.join(REPOSITORY_ROOT, MANIFEST_PATH), "utf8");
    if (current !== serialized) throw new Error(`Asset manifest is stale. Run node ${repositoryPath(SCRIPT_PATH)}.`);
    return { manifest, copied: [], removed: [], manifestSha256: sha256Text(serialized) };
  }

  const previousManifest = await readPreviousManifest();
  const copied = [];
  for (const entry of manifest.entries) {
    const changed = entry.generatedBytes == null
      ? await copyIfChanged(
        path.join(REPOSITORY_ROOT, entry.sourcePath),
        path.join(REPOSITORY_ROOT, entry.targetPath),
        entry.sourceSha256,
      )
      : await writeBytesIfChanged(
        entry.generatedBytes,
        path.join(REPOSITORY_ROOT, entry.targetPath),
        entry.targetSha256,
      );
    if (changed) copied.push(entry.targetPath);
  }
  if (await copyIfChanged(
    path.join(REPOSITORY_ROOT, manifest.credits.sourcePath),
    path.join(REPOSITORY_ROOT, manifest.credits.targetPath),
    manifest.credits.sha256,
  )) copied.push(manifest.credits.targetPath);

  const removed = prune ? await prunePreviousTargets(previousManifest, expectedTargets) : [];
  const manifestTarget = path.join(REPOSITORY_ROOT, MANIFEST_PATH);
  await mkdir(path.dirname(manifestTarget), { recursive: true });
  let manifestChanged = true;
  try {
    manifestChanged = (await readFile(manifestTarget, "utf8")) !== serialized;
  } catch {
    // Missing manifest is expected on the first import.
  }
  if (manifestChanged) await writeFile(manifestTarget, serialized, "utf8");

  return { manifest, copied, removed, manifestChanged, manifestSha256: sha256Text(serialized) };
}

function parseArguments(argv) {
  const allowed = new Set(["--check", "--json", "--prune"]);
  for (const argument of argv) {
    if (!allowed.has(argument)) throw new Error(`Unknown argument: ${argument}`);
  }
  return {
    checkOnly: argv.includes("--check"),
    json: argv.includes("--json"),
    prune: argv.includes("--prune"),
  };
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const result = await importAssets(options);
  const summary = {
    schema: result.manifest.schema,
    catalogs: result.manifest.summary.catalogCount,
    images: result.manifest.summary.imageCount,
    platformIconSources: result.manifest.summary.platformIconSourceCount,
    audio: result.manifest.summary.audioCount,
    copied: result.copied.length,
    removed: result.removed.length,
    manifestChanged: result.manifestChanged ?? false,
    manifestSha256: result.manifestSha256,
    mode: options.checkOnly ? "check" : "import",
  };
  if (options.json) process.stdout.write(`${JSON.stringify(summary)}\n`);
  else process.stdout.write(`Unity assets ${summary.mode} complete: ${summary.images} images, ${summary.platformIconSources} icon sources, ${summary.audio} audio files; ${summary.copied} copied, ${summary.removed} pruned.\n`);
}

const isMain = process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  main().catch((error) => {
    process.stderr.write(`Asset import failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
