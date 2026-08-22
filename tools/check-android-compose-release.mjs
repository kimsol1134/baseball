#!/usr/bin/env node

import { createHash } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const requireAab = args.includes("--require-aab");
const artifactFlag = args.indexOf("--artifact-dir");
const artifactDir = artifactFlag >= 0
  ? resolve(args[artifactFlag + 1] ?? "")
  : process.env.BASEBALL_COMPOSE_ARTIFACT_DIRECTORY
    ? resolve(process.env.BASEBALL_COMPOSE_ARTIFACT_DIRECTORY)
    : "";

const errors = [];
const notes = [];
const read = (relative) => {
  const path = resolve(root, relative);
  if (!existsSync(path)) {
    errors.push(`missing: ${relative}`);
    return "";
  }
  return readFileSync(path, "utf8");
};
const sha256File = (relative) => createHash("sha256").update(readFileSync(resolve(root, relative))).digest("hex");
const requireFile = (relative) => {
  if (!existsSync(resolve(root, relative))) errors.push(`missing: ${relative}`);
};

const strings = read("apps/android/app/src/main/res/values/strings.xml");
const manifest = read("apps/android/app/src/main/AndroidManifest.xml");
const appGradle = read("apps/android/app/build.gradle.kts");
const applicationRoot = read("apps/android/app/src/main/java/com/solkim/baseball/android/BaseballApplication.kt");
const storeManifest = JSON.parse(read("apps/android-unity/StoreAssets/manifest.json") || "{}");
const gitignore = read(".gitignore");

if (!strings.includes(">야구 못하면 또 환생함<")) {
  errors.push("release application label is not the product name");
}
if (strings.includes("가상 야구 연출 실험")) {
  errors.push("experiment application label is still present");
}
for (const marker of [
  'android:icon="@mipmap/ic_launcher"',
  'android:roundIcon="@mipmap/ic_launcher_round"',
  'android:resizeableActivity="false"',
  "<supports-screens",
  'android:anyDensity="true"',
  'android:smallScreens="true"',
  'android:normalScreens="true"',
  'android:largeScreens="false"',
  'android:xlargeScreens="false"',
  "google_analytics_adid_collection_enabled",
  "firebase_analytics_collection_enabled",
]) {
  if (!manifest.includes(marker)) errors.push(`Play form-factor/privacy marker missing: ${marker}`);
}
if (manifest.includes("<compatible-screens")) {
  errors.push("compatible-screens must not exclude intermediate handset densities");
}
if (manifest.includes("LEANBACK_LAUNCHER")) errors.push("TV launcher category is present");
if (!appGradle.includes('applicationId = "com.solkim.baseball.android"')) {
  errors.push("production application ID is not explicit");
}
if (!appGradle.includes("BASEBALL_UPLOAD_KEYSTORE_PATH") || !appGradle.includes("phase11Distribution")) {
  errors.push("Play upload-key and production distribution inputs are not wired");
}
if (!appGradle.includes('alias(libs.plugins.firebase.crashlytics) apply false') ||
    !appGradle.includes('apply(plugin = "com.google.firebase.crashlytics")')) {
  errors.push("production Firebase configuration must generate the Crashlytics build ID");
}
const platformGradle = read("apps/android/platform/build.gradle.kts");
if (!platformGradle.includes("implementation(libs.okhttp)")) {
  errors.push("Amplitude legacy SDK requires the OkHttp runtime in the packaged app");
}
if (appGradle.includes("google-services.json") || appGradle.includes('phase9AmplitudeApiKey = "')) {
  errors.push("production credentials are checked into the app build");
}
if (!applicationRoot.includes("BuildConfig.RELEASE_DISTRIBUTION")) {
  errors.push("application root does not publish the release distribution");
}
if (!gitignore.includes("apps/android/app/google-services.json")) {
  errors.push("Compose Firebase configuration is not gitignored");
}
if (existsSync(resolve(root, "apps/android/app/google-services.json"))) {
  errors.push("apps/android/app/google-services.json must be injected at RC time and omitted from the tree");
}

for (const relative of [
  "apps/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml",
  "apps/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml",
  "apps/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png",
  "apps/android/app/src/main/res/drawable-nodpi/ic_launcher_background.png",
  "apps/android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png",
  "apps/android/app/src/main/res/drawable-nodpi/ic_launcher_monochrome.png",
  "apps/android/platform/src/main/res/drawable/baseball_notification_small.png",
  "tools/android-compose-build.sh",
  "tools/android-compose-instrumentation.sh",
  "docs/android-compose/PLAY_SUBMISSION_CHECKLIST.md",
]) {
  requireFile(relative);
}

const adaptive = read("apps/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml");
if (!adaptive.includes("ic_launcher_monochrome")) {
  errors.push("Android 13 monochrome launcher layer is missing");
}

if (storeManifest.schema !== "baseball-android-store-assets-v1") {
  errors.push("Play store-asset manifest schema is unexpected");
}
for (const entry of storeManifest.entries ?? []) {
  if (!existsSync(resolve(root, entry.path))) {
    errors.push(`store asset missing: ${entry.path}`);
    continue;
  }
  if (sha256File(entry.path) !== entry.sha256) {
    errors.push(`store asset checksum drifted: ${entry.path}`);
  }
}

const sourceAppIcon = "apps/android-unity/Assets/Game/Art/PlatformIcons/AppIcon.png";
if (existsSync(resolve(root, sourceAppIcon))) {
  const expected = storeManifest.entries
    ?.find((entry) => entry.kind === "store-icon")
    ?.sourceReferences
    ?.find((ref) => ref.path === sourceAppIcon)
    ?.sha256;
  if (expected && sha256File(sourceAppIcon) !== expected) {
    errors.push("approved RGB app icon source drifted from the store-asset manifest");
  }
}

if (requireAab || artifactDir) {
  if (!artifactDir) {
    errors.push("--require-aab needs --artifact-dir or BASEBALL_COMPOSE_ARTIFACT_DIRECTORY");
  } else if (!existsSync(artifactDir)) {
    errors.push(`RC artifact directory is missing: ${artifactDir}`);
  } else {
    const manifestPath = resolve(artifactDir, "build-manifest.json");
    const checksumsPath = resolve(artifactDir, "checksums.sha256");
    if (!existsSync(manifestPath) || !existsSync(checksumsPath)) {
      errors.push("RC build-manifest.json or checksums.sha256 is missing");
    } else {
      const rc = JSON.parse(readFileSync(manifestPath, "utf8"));
      if (rc.schema !== "baseball-android-compose-build-manifest-v1") {
        errors.push("unexpected Compose RC manifest schema");
      }
      if (rc.package !== "com.solkim.baseball.android") errors.push("RC package is not production");
      if (rc.applicationLabel !== "야구 못하면 또 환생함") errors.push("RC application label is not the product name");
      if (rc.playUpload !== "not-performed") errors.push("RC manifest must not claim a Play upload");
      const bundle = resolve(artifactDir, rc.bundleFile || "");
      if (!rc.bundleFile || !existsSync(bundle)) {
        errors.push("RC AAB is missing");
      } else {
        const actualSha = createHash("sha256").update(readFileSync(bundle)).digest("hex");
        if (actualSha !== rc.bundleSha256) errors.push("RC AAB SHA-256 does not match the manifest");
        if (statSync(bundle).size !== rc.bundleBytes) errors.push("RC AAB byte count does not match the manifest");
        const checksumLine = `${rc.bundleSha256}  ${rc.bundleFile}`;
        if (readFileSync(checksumsPath, "utf8").trim() !== checksumLine) {
          errors.push("checksums.sha256 does not exactly match the RC AAB");
        }
      }
      const pin = (process.env.BASEBALL_UPLOAD_CERT_SHA256 || "").replace(/[:\s]/g, "").toLowerCase();
      if (pin && rc.uploadCertSha256 !== pin) {
        errors.push("RC upload certificate does not match BASEBALL_UPLOAD_CERT_SHA256");
      }
      if (requireAab && rc.distribution !== "production") {
        errors.push(`--require-aab received a non-production distribution: ${rc.distribution}`);
      }
      if (rc.distribution === "production" && rc.gitDirty !== false) {
        errors.push("production RC cannot be dirty");
      }
    }
  }
} else {
  notes.push("source/product-surface ready; signed production AAB was not required in this invocation");
}

if (errors.length > 0) {
  console.error(`android-compose release check failed (${errors.length})`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log("android-compose release check passed");
for (const note of notes) console.log(note);
