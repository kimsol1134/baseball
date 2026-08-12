#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_path="$repo_root/apps/android-unity"
artifact_root="$repo_root/artifacts/unity"
unity_bin="${BASEBALL_UNITY_BIN:-/Applications/Unity/Hub/Editor/6000.3.19f1/Unity.app/Contents/MacOS/Unity}"
alignment_temp=""

cleanup_alignment_temp() {
  if [[ -n "$alignment_temp" && -d "$alignment_temp" ]]; then
    rm -rf -- "$alignment_temp"
  fi
}
trap cleanup_alignment_temp EXIT

if [[ ! -x "$unity_bin" ]]; then
  echo "Unity executable not found: $unity_bin" >&2
  exit 2
fi

if [[ ! -d "/Applications/Unity/Hub/Editor/6000.3.19f1/PlaybackEngines/AndroidPlayer" ]]; then
  echo "Unity Android Build Support is not installed for 6000.3.19f1" >&2
  exit 2
fi

mkdir -p "$artifact_root"
rm -f "$artifact_root/android-build.log"

build_mode="${BASEBALL_BUILD_MODE:-verification}"
case "$build_mode" in
  verification)
    execute_method="Baseball.Editor.AndroidBuild.BuildLocalVerification"
    ;;
  rc)
    execute_method="Baseball.Editor.AndroidBuild.BuildReleaseCandidate"
    ;;
  *)
    echo "BASEBALL_BUILD_MODE must be 'verification' or 'rc': $build_mode" >&2
    exit 2
    ;;
esac

version_name="${BASEBALL_VERSION_NAME:-1.0.0}"
version_code="${BASEBALL_VERSION_CODE:-1}"
if [[ ! "$version_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "BASEBALL_VERSION_NAME must be a three-part numeric version: $version_name" >&2
  exit 2
fi
if [[ ! "$version_code" =~ ^[1-9][0-9]*$ ]]; then
  echo "BASEBALL_VERSION_CODE must be a positive integer: $version_code" >&2
  exit 2
fi
artifact_directory="$repo_root/artifacts/android/${version_name}-${version_code}"

if [[ "$build_mode" == "rc" ]]; then
  for signing_command in jarsigner keytool java unzip; do
    if ! command -v "$signing_command" >/dev/null 2>&1; then
      echo "$signing_command is required to verify a release-candidate AAB" >&2
      exit 2
    fi
  done
  if [[ -z "${BASEBALL_UPLOAD_CERT_SHA256:-}" ]]; then
    echo "BASEBALL_UPLOAD_CERT_SHA256 is required for release-candidate certificate pinning" >&2
    exit 2
  fi
  expected_certificate="$(printf '%s' "$BASEBALL_UPLOAD_CERT_SHA256" | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
  if [[ ! "$expected_certificate" =~ ^[0-9A-F]{64}$ ]]; then
    echo "BASEBALL_UPLOAD_CERT_SHA256 must contain a SHA-256 certificate fingerprint" >&2
    exit 2
  fi
  bundletool_jar="${BASEBALL_BUNDLETOOL_JAR:-/Applications/Unity/Hub/Editor/6000.3.19f1/PlaybackEngines/AndroidPlayer/Tools/bundletool-all-1.17.2.jar}"
  if [[ ! -f "$bundletool_jar" ]]; then
    echo "bundletool JAR is required for the Android 16KB page-alignment gate: $bundletool_jar" >&2
    exit 2
  fi
  zipalign_bin="${BASEBALL_ZIPALIGN:-/Applications/Unity/Hub/Editor/6000.3.19f1/PlaybackEngines/AndroidPlayer/SDK/build-tools/36.0.0/zipalign}"
  if [[ ! -x "$zipalign_bin" ]]; then
    echo "zipalign is required for the Android 16KB APK-alignment gate: $zipalign_bin" >&2
    exit 2
  fi
  apkanalyzer_bin="${BASEBALL_APKANALYZER:-/Applications/Unity/Hub/Editor/6000.3.19f1/PlaybackEngines/AndroidPlayer/SDK/cmdline-tools/16.0/bin/apkanalyzer}"
  if [[ ! -x "$apkanalyzer_bin" ]]; then
    echo "apkanalyzer is required for the merged APK permission gate: $apkanalyzer_bin" >&2
    exit 2
  fi
  llvm_readelf="${BASEBALL_LLVM_READELF:-/Applications/Unity/Hub/Editor/6000.3.19f1/PlaybackEngines/AndroidPlayer/NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf}"
  if [[ ! -x "$llvm_readelf" ]]; then
    echo "llvm-readelf is required for the Android 16KB ELF-alignment gate: $llvm_readelf" >&2
    exit 2
  fi
fi

set +e
"$unity_bin" \
  -batchmode \
  -nographics \
  -quit \
  -buildTarget Android \
  -projectPath "$project_path" \
  -executeMethod "$execute_method" \
  -logFile "$artifact_root/android-build.log" \
  "$@"
unity_status=$?
set -e

failed=0
if [[ "$unity_status" -ne 0 ]]; then
  echo "Unity Android build process failed with exit code $unity_status" >&2
  failed=1
fi
if [[ ! -s "$artifact_root/android-build.log" ]]; then
  echo "Unity Android build log is missing or empty" >&2
  failed=1
elif grep -Eiq \
  'No valid Unity Editor license|LICENSE SYSTEM.*(fail|error)|error CS[0-9]{4}:|Scripts have compiler errors|Compilation failed|Aborting batchmode due to failure|BuildFailedException|Fatal Error' \
  "$artifact_root/android-build.log"; then
  echo "Unity Android build log contains a license, compile, build, or fatal error" >&2
  grep -Ein \
    'No valid Unity Editor license|LICENSE SYSTEM.*(fail|error)|error CS[0-9]{4}:|Scripts have compiler errors|Compilation failed|Aborting batchmode due to failure|BuildFailedException|Fatal Error' \
    "$artifact_root/android-build.log" | tail -n 20 >&2 || true
  failed=1
fi

if [[ "$failed" -eq 0 ]]; then
  BUILD_MODE="$build_mode" ARTIFACT_DIRECTORY="$artifact_directory" \
    VERSION_NAME="$version_name" VERSION_CODE="$version_code" REPO_ROOT="$repo_root" node <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

function fail(message) {
  console.error(`Android build evidence invalid: ${message}`);
  process.exit(1);
}
function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}
function requireZip(file, label) {
  const bytes = fs.readFileSync(file);
  if (bytes.length < 4 || bytes[0] !== 0x50 || bytes[1] !== 0x4b || bytes[2] !== 0x03 || bytes[3] !== 0x04) {
    fail(`${label} is empty or does not have a ZIP local-file signature: ${file}`);
  }
}

const directory = path.resolve(process.env.ARTIFACT_DIRECTORY);
const artifactRoot = path.resolve(process.env.REPO_ROOT, "artifacts", "android") + path.sep;
if (!directory.startsWith(artifactRoot)) fail("artifact directory escaped the repository artifact root");
const manifestPath = path.join(directory, "build-manifest.json");
const checksumsPath = path.join(directory, "checksums.sha256");
if (!fs.existsSync(manifestPath) || !fs.existsSync(checksumsPath)) fail("manifest or checksums file is missing");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const expectedDistribution = process.env.BUILD_MODE === "rc" ? "production" : "internal-verification";
const expectedDevelopmentBuild = process.env.BUILD_MODE !== "rc";
if (manifest.schema !== "baseball-android-build-manifest-v1") fail("unexpected manifest schema");
if (manifest.versionName !== process.env.VERSION_NAME || String(manifest.versionCode) !== process.env.VERSION_CODE) fail("version mismatch");
if (manifest.distribution !== expectedDistribution || manifest.environment !== expectedDistribution) fail("distribution/environment mismatch");
if (manifest.developmentBuild !== expectedDevelopmentBuild) fail("developmentBuild does not match build mode");
if (manifest.internalQaCompiled !== expectedDevelopmentBuild) fail("internalQaCompiled does not match build mode");
if (manifest.il2cppCompilerConfiguration !== "Release") fail("IL2CPP compiler configuration is not Release");
if (process.env.BUILD_MODE === "rc" && manifest.gitDirty !== false) fail("release candidate records a dirty worktree");

const bundleName = path.basename(manifest.bundleFile || "");
if (!bundleName || bundleName !== manifest.bundleFile || !bundleName.endsWith(".aab")) fail("unsafe or missing bundleFile");
const bundle = path.join(directory, bundleName);
if (!fs.existsSync(bundle)) fail("AAB is missing");
requireZip(bundle, "AAB");
if (sha256(bundle) !== manifest.bundleSha256) fail("AAB SHA-256 mismatch");
if (manifest.bundleBytes !== fs.statSync(bundle).size) fail("AAB byte count mismatch");

const expectedLines = [`${manifest.bundleSha256}  ${bundleName}`];
const symbolName = path.basename(manifest.symbolFile || "");
if (symbolName) {
  if (symbolName !== manifest.symbolFile || !symbolName.toLowerCase().includes("symbol")) fail("unsafe symbolFile");
  const symbol = path.join(directory, symbolName);
  if (!fs.existsSync(symbol)) fail("IL2CPP symbol archive is missing");
  requireZip(symbol, "IL2CPP symbol archive");
  if (sha256(symbol) !== manifest.symbolSha256) fail("IL2CPP symbol SHA-256 mismatch");
  expectedLines.push(`${manifest.symbolSha256}  ${symbolName}`);
} else if (process.env.BUILD_MODE === "rc") {
  fail("release candidate is missing symbolFile");
}
const checksumLines = fs.readFileSync(checksumsPath, "utf8").trim().split(/\r?\n/);
if (JSON.stringify(checksumLines) !== JSON.stringify(expectedLines)) fail("checksums.sha256 does not exactly match the manifest");
console.log(`Android build evidence passed: ${directory}`);
NODE
fi

if [[ "$failed" -eq 0 && "$build_mode" == "rc" ]]; then
  aab_path="$artifact_directory/baseball-android-${version_name}-${version_code}.aab"
  if ! unzip -tqq "$aab_path" >"$artifact_directory/aab-zip-test.txt" 2>&1; then
    echo "Release-candidate AAB ZIP integrity verification failed" >&2
    failed=1
  elif ! jarsigner -verify -strict -certs "$aab_path" >"$artifact_directory/aab-signature.txt" 2>&1; then
    echo "Release-candidate AAB signature verification failed" >&2
    failed=1
  else
    actual_certificate="$(keytool -J-Duser.language=en -printcert -jarfile "$aab_path" |
      sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -n 1 | tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
    if [[ "$actual_certificate" != "$expected_certificate" ]]; then
      echo "Release-candidate AAB certificate does not match BASEBALL_UPLOAD_CERT_SHA256" >&2
      failed=1
    else
      printf '%s\n' "$actual_certificate" >"$artifact_directory/aab-signing-cert.sha256"
    fi
  fi
  if [[ "$failed" -eq 0 ]]; then
    if ! java -jar "$bundletool_jar" dump config --bundle="$aab_path" \
      >"$artifact_directory/bundle-config.txt" 2>"$artifact_directory/bundle-config.stderr.txt"; then
      echo "bundletool could not dump the release-candidate BundleConfig" >&2
      failed=1
    elif ! grep -Fq 'PAGE_ALIGNMENT_16K' "$artifact_directory/bundle-config.txt"; then
      echo "Release-candidate AAB is not configured for PAGE_ALIGNMENT_16K" >&2
      failed=1
    fi
  fi
  if [[ "$failed" -eq 0 ]]; then
    merged_manifest="$artifact_directory/merged-manifest.xml"
    if ! java -jar "$bundletool_jar" dump manifest \
      --bundle="$aab_path" \
      --module=base \
      >"$merged_manifest" 2>"$artifact_directory/merged-manifest.stderr.txt"; then
      echo "bundletool could not dump the release-candidate merged base manifest" >&2
      failed=1
    elif ! MERGED_MANIFEST="$merged_manifest" \
      MERGED_MANIFEST_EVIDENCE="$artifact_directory/merged-manifest-verify.txt" node <<'NODE'
const fs = require("node:fs");

const manifestPath = process.env.MERGED_MANIFEST;
const evidencePath = process.env.MERGED_MANIFEST_EVIDENCE;
const xml = fs.readFileSync(manifestPath, "utf8");
function fail(message) {
  console.error(`Merged Android manifest invalid: ${message}`);
  process.exit(1);
}
function attributes(element) {
  return Object.fromEntries(
    [...element.matchAll(/(?:android:)?([A-Za-z][\w.-]*)\s*=\s*["']([^"']*)["']/g)]
      .map((match) => [match[1], match[2]])
  );
}

const root = xml.match(/<manifest\b[^>]*>/)?.[0];
if (!root) fail("manifest root is missing");
const rootAttributes = attributes(root);
if (rootAttributes.package !== "com.solkim.baseball.android") {
  fail(`package is ${rootAttributes.package ?? "missing"}`);
}

const permissions = [...xml.matchAll(/<uses-permission\b[^>]*>/g)]
  .map((match) => attributes(match[0]).name)
  .filter(Boolean)
  .sort();
const expectedPermissions = [
  "android.permission.ACCESS_NETWORK_STATE",
  "android.permission.INTERNET",
  "android.permission.POST_NOTIFICATIONS",
  "android.permission.VIBRATE",
].sort();
if (JSON.stringify(permissions) !== JSON.stringify(expectedPermissions)) {
  fail(`active permissions differ: ${permissions.join(", ")}`);
}

const application = xml.match(/<application\b[^>]*>/)?.[0];
if (!application) fail("application element is missing");
const applicationAttributes = attributes(application);
if (applicationAttributes.allowBackup !== "false") fail("android:allowBackup is not false");
if (applicationAttributes.usesCleartextTraffic !== "false") {
  fail("android:usesCleartextTraffic is not false");
}
if (xml.includes("android.intent.category.LEANBACK_LAUNCHER")) {
  fail("TV Leanback launcher category is present");
}
if (/<queries\b/.test(xml)) fail("broad package visibility queries are present");

const playerActivity = [...xml.matchAll(/<activity\b[^>]*>/g)]
  .map((match) => attributes(match[0]))
  .find((value) => /UnityPlayer(?:Game)?Activity$/.test(value.name ?? ""));
if (!playerActivity) fail("Unity player activity is missing");
if (playerActivity.screenOrientation !== "portrait") {
  fail(`Unity player orientation is ${playerActivity.screenOrientation ?? "missing"}`);
}
if (playerActivity.resizeableActivity !== "false") {
  fail(`Unity player resizeableActivity is ${playerActivity.resizeableActivity ?? "missing"}`);
}

const provider = [...xml.matchAll(/<provider\b[^>]*>/g)]
  .map((match) => attributes(match[0]))
  .find((value) => value.name === "com.solkim.baseball.platform.ShareFileProvider");
if (!provider || provider.exported !== "false" ||
    provider.authorities !== "com.solkim.baseball.android.baseball.share") {
  fail("share provider is missing, exported, or has a different authority");
}

const touchscreen = [...xml.matchAll(/<uses-feature\b[^>]*>/g)]
  .map((match) => attributes(match[0]))
  .find((value) => value.name === "android.hardware.touchscreen");
if (!touchscreen || touchscreen.required !== "true") {
  fail("required touchscreen feature is missing");
}

const screens = [...xml.matchAll(/<screen\b[^>]*>/g)].map((match) => attributes(match[0]));
function normalizedScreenSize(value) {
  return ({ "1": "small", "2": "normal" })[value] ?? value ?? "missing";
}
function normalizedScreenDensity(value) {
  return ({
    "120": "ldpi", "160": "mdpi", "240": "hdpi", "320": "xhdpi",
    "480": "xxhdpi", "640": "xxxhdpi",
    "0x78": "ldpi", "0xa0": "mdpi", "0xf0": "hdpi", "0x140": "xhdpi",
    "0x1e0": "xxhdpi", "0x280": "xxxhdpi",
  })[(value ?? "").toLowerCase()] ?? value ?? "missing";
}
const expectedScreenPairs = ["small", "normal"].flatMap((size) =>
  ["ldpi", "mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]
    .map((density) => `${size}:${density}`)
).sort();
const screenPairs = screens
  .map((value) => `${normalizedScreenSize(value.screenSize)}:${normalizedScreenDensity(value.screenDensity)}`)
  .sort();
if (JSON.stringify(screenPairs) !== JSON.stringify(expectedScreenPairs)) {
  fail(`compatible screen filter differs: ${screenPairs.join(", ")}`);
}

const evidence = [
  "result=passed",
  `package=${rootAttributes.package}`,
  `permissions=${permissions.join(",")}`,
  `compatible_screens=${screenPairs.join(",")}`,
  "allow_backup=false",
  "cleartext=false",
  "share_provider_exported=false",
  "touchscreen_required=true",
  "player_orientation=portrait",
  "resizeable_activity=false",
  "leanback_launcher=false",
  "package_queries=false",
].join("\n") + "\n";
fs.writeFileSync(evidencePath, evidence);
console.log(`Merged Android manifest evidence passed: ${manifestPath}`);
NODE
    then
      echo "Release-candidate merged manifest contract verification failed" >&2
      failed=1
    fi
  fi
  if [[ "$failed" -eq 0 ]]; then
    alignment_temp="$(mktemp -d "${TMPDIR:-/tmp}/baseball-aab-alignment.XXXXXX")"
    store_password_file="$alignment_temp/store-password.txt"
    key_password_file="$alignment_temp/key-password.txt"
    (umask 077
      printf '%s' "$BASEBALL_UPLOAD_KEYSTORE_PASSWORD" >"$store_password_file"
      printf '%s' "$BASEBALL_UPLOAD_KEY_PASSWORD" >"$key_password_file")
    universal_apks="$artifact_directory/universal.apks"
    universal_apk="$artifact_directory/universal.apk"
    if ! java -jar "$bundletool_jar" build-apks \
      --bundle="$aab_path" \
      --output="$universal_apks" \
      --mode=universal \
      --ks="$BASEBALL_UPLOAD_KEYSTORE_PATH" \
      --ks-key-alias="$BASEBALL_UPLOAD_KEY_ALIAS" \
      --ks-pass="file:$store_password_file" \
      --key-pass="file:$key_password_file" \
      --overwrite >"$artifact_directory/universal-apks-build.txt" 2>&1; then
      echo "bundletool could not build the signed universal APK for the 16KB gate" >&2
      failed=1
    elif ! unzip -tqq "$universal_apks" >"$artifact_directory/universal-apks-zip-test.txt" 2>&1; then
      echo "Universal APKS ZIP integrity verification failed" >&2
      failed=1
    elif ! unzip -p "$universal_apks" universal.apk >"$universal_apk"; then
      echo "bundletool universal APKS did not contain universal.apk" >&2
      failed=1
    elif ! unzip -tqq "$universal_apk" >"$artifact_directory/universal-apk-zip-test.txt" 2>&1; then
      echo "Universal APK ZIP integrity verification failed" >&2
      failed=1
    elif ! "$zipalign_bin" -c -P 16 -v 4 "$universal_apk" \
      >"$artifact_directory/apk-zipalign.txt" 2>&1; then
      echo "Universal APK does not satisfy zipalign -P 16" >&2
      failed=1
    else
      printf 'result=passed alignment=16384\n' >>"$artifact_directory/apk-zipalign.txt"
    fi
  fi
  if [[ "$failed" -eq 0 ]]; then
    apk_permissions="$artifact_directory/apk-permissions.txt"
    if ! "$apkanalyzer_bin" manifest permissions "$universal_apk" >"$apk_permissions" 2>&1; then
      echo "apkanalyzer could not inspect universal APK permissions" >&2
      failed=1
    elif ! APK_PERMISSIONS="$apk_permissions" node <<'NODE'
const fs = require("node:fs");
const raw = fs.readFileSync(process.env.APK_PERMISSIONS, "utf8");
const permissions = [...new Set(
  [...raw.matchAll(/\b(?:android|com)\.[A-Za-z0-9_.]*permission(?:\.[A-Za-z0-9_.]+)?\b/g)]
    .map((match) => match[0])
)].sort();
const expected = [
  "android.permission.ACCESS_NETWORK_STATE",
  "android.permission.INTERNET",
  "android.permission.POST_NOTIFICATIONS",
  "android.permission.VIBRATE",
].sort();
if (JSON.stringify(permissions) !== JSON.stringify(expected)) {
  console.error(`APK permissions differ: ${permissions.join(", ")}`);
  process.exit(1);
}
fs.appendFileSync(process.env.APK_PERMISSIONS, `result=passed permissions=${permissions.join(",")}\n`);
NODE
    then
      echo "Universal APK permission contract verification failed" >&2
      failed=1
    fi
  fi
  if [[ "$failed" -eq 0 ]]; then
    alignment_evidence="$artifact_directory/elf-alignment.txt"
    : >"$alignment_evidence"
    native_count=0
    while IFS= read -r native_entry; do
      [[ -z "$native_entry" ]] && continue
      if [[ ! "$native_entry" =~ ^lib/arm64-v8a/[A-Za-z0-9._+-]+[.]so$ ]]; then
        echo "Unsafe ARM64 library entry in universal APK: $native_entry" >&2
        failed=1
        break
      fi
      native_count=$((native_count + 1))
      native_file="$alignment_temp/library-${native_count}.so"
      if ! unzip -p "$universal_apk" "$native_entry" >"$native_file"; then
        echo "Could not extract ARM64 library from universal APK: $native_entry" >&2
        failed=1
        break
      fi
      if ! load_lines="$("$llvm_readelf" -lW "$native_file" |
        sed -n '/^[[:space:]]*LOAD[[:space:]]/p')"; then
        echo "Could not inspect ARM64 library in universal APK: $native_entry" >&2
        failed=1
        break
      fi
      invalid_alignment=0
      if [[ -z "$load_lines" ]]; then
        invalid_alignment=1
      else
        while IFS= read -r load_line; do
          load_alignment="${load_line##* }"
          if [[ ! "$load_alignment" =~ ^0x[0-9A-Fa-f]+$ ]] ||
            (( load_alignment < 0x4000 )); then
            invalid_alignment=1
            break
          fi
        done <<<"$load_lines"
      fi
      if [[ "$invalid_alignment" -ne 0 ]]; then
        echo "ARM64 library has a missing or sub-16KB ELF LOAD alignment: $native_entry" >&2
        failed=1
        break
      fi
      {
        printf 'library=%s\n' "$native_entry"
        printf '%s\n' "$load_lines"
      } >>"$alignment_evidence"
    done < <(unzip -Z1 "$universal_apk" | sed -n '/^lib\/arm64-v8a\/[^/]*[.]so$/p')
    if [[ "$native_count" -eq 0 ]]; then
      echo "Universal APK contains no ARM64 native libraries to verify" >&2
      failed=1
    elif [[ "$failed" -eq 0 ]]; then
      printf 'result=passed libraries=%s minimum_load_alignment=16384\n' "$native_count" \
        >>"$alignment_evidence"
    fi
    cleanup_alignment_temp
    alignment_temp=""
  fi
  if [[ "$failed" -eq 0 ]]; then
    symbol_path="$(node -e 'const manifest=require(process.argv[1]); process.stdout.write(manifest.symbolFile)' "$artifact_directory/build-manifest.json")"
    if ! unzip -tqq "$artifact_directory/$symbol_path" \
      >"$artifact_directory/symbol-zip-test.txt" 2>&1; then
      echo "IL2CPP symbol archive ZIP integrity verification failed" >&2
      failed=1
    fi
  fi
fi

exit "$failed"
