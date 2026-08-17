#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${1:-verification}"
VERSION_NAME="${BASEBALL_VERSION_NAME:-1.0.0}"
VERSION_CODE="${BASEBALL_VERSION_CODE:-37}"
ARTIFACT_DIRECTORY="${BASEBALL_COMPOSE_ARTIFACT_DIRECTORY:-$REPO_ROOT/artifacts/android-compose/rc/${VERSION_NAME}-${VERSION_CODE}}"
INJECTED_GOOGLE_SERVICES="$REPO_ROOT/apps/android/app/google-services.json"
CLEANED_INJECTION=0

cleanup_injection() {
  if [[ "$CLEANED_INJECTION" -eq 1 && -f "$INJECTED_GOOGLE_SERVICES" ]]; then
    rm -f -- "$INJECTED_GOOGLE_SERVICES"
  fi
}
trap cleanup_injection EXIT

fail() {
  echo "$1" >&2
  exit 2
}

if [[ ! "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "BASEBALL_VERSION_NAME must be a three-part numeric version: $VERSION_NAME"
fi
if [[ ! "$VERSION_CODE" =~ ^[1-9][0-9]*$ ]] || [[ "$VERSION_CODE" -le 5 ]]; then
  fail "BASEBALL_VERSION_CODE must be an integer higher than the current Play Unity baseline (5)"
fi

case "$BUILD_MODE" in
  verification)
    if [[ "${ANDROID_COMPOSE_SKIP_UNITY_EXPORT:-0}" != "1" ]]; then
      "$REPO_ROOT/tools/export-android-pitch-unity.sh"
    fi
    cd "$REPO_ROOT/apps/android"
    ./gradlew :app:assembleDebug --no-daemon --stacktrace \
      -Pphase10VersionName="$VERSION_NAME" \
      -Pphase10VersionCode="$VERSION_CODE"
    APK="$REPO_ROOT/apps/android/app/build/outputs/apk/debug/app-debug.apk"
    if [[ ! -f "$APK" ]]; then
      fail "Compose debug APK was not produced: $APK"
    fi
    APKSIGNER_BIN="$(command -v apksigner || true)"
    if [[ -z "$APKSIGNER_BIN" ]]; then
      SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
      APKSIGNER_BIN="$(find "$SDK_ROOT/build-tools" -type f -name apksigner -perm -111 2>/dev/null | sort | tail -n 1 || true)"
    fi
    if [[ -n "$APKSIGNER_BIN" ]]; then
      "$APKSIGNER_BIN" verify --verbose "$APK"
    else
      echo "apksigner not found; APK verification was not run" >&2
    fi
    shasum -a 256 "$APK"
    echo "Compose verification APK ready: $APK"
    ;;
  rc)
    for required_command in git jarsigner keytool java unzip shasum node; do
      command -v "$required_command" >/dev/null 2>&1 || fail "$required_command is required for a Compose release candidate"
    done
    for required_env in \
      BASEBALL_UPLOAD_KEYSTORE_PATH \
      BASEBALL_UPLOAD_KEYSTORE_PASSWORD \
      BASEBALL_UPLOAD_KEY_ALIAS \
      BASEBALL_UPLOAD_KEY_PASSWORD \
      BASEBALL_UPLOAD_CERT_SHA256 \
      BASEBALL_GOOGLE_SERVICES_PATH \
      BASEBALL_AMPLITUDE_API_KEY
    do
      if [[ -z "${!required_env:-}" ]]; then
        fail "$required_env is required for a Compose production RC"
      fi
    done
    if [[ ! -f "$BASEBALL_UPLOAD_KEYSTORE_PATH" ]]; then
      fail "upload keystore is missing"
    fi
    if [[ ! -f "$BASEBALL_GOOGLE_SERVICES_PATH" ]]; then
      fail "Firebase configuration file is missing"
    fi
    expected_certificate="$(printf '%s' "$BASEBALL_UPLOAD_CERT_SHA256" | tr -d ':[:space:]' | tr '[:upper:]' '[:lower:]')"
    if [[ ! "$expected_certificate" =~ ^[0-9a-f]{64}$ ]]; then
      fail "BASEBALL_UPLOAD_CERT_SHA256 must contain a SHA-256 certificate fingerprint"
    fi
    git_commit="$(git -C "$REPO_ROOT" rev-parse HEAD)"
    git_dirty=false
    if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
      git_dirty=true
    fi
    if [[ "$git_dirty" == "true" && "${BASEBALL_ALLOW_DIRTY_RC:-0}" != "1" ]]; then
      fail "production RC requires a clean worktree; set BASEBALL_ALLOW_DIRTY_RC=1 only for a local non-Play candidate"
    fi
    if [[ "${ANDROID_COMPOSE_SKIP_UNITY_EXPORT:-0}" == "1" ]]; then
      fail "Compose production RC cannot skip the pitch Unity export"
    fi
    "$REPO_ROOT/tools/export-android-pitch-unity.sh"
    if [[ ! -d "$REPO_ROOT/artifacts/android-compose/unity-export/current/unityLibrary" ]]; then
      fail "pitch Unity export is missing; a Play AAB without the trajectory runtime is not a candidate"
    fi

    mkdir -p "$ARTIFACT_DIRECTORY"
    cp "$BASEBALL_GOOGLE_SERVICES_PATH" "$INJECTED_GOOGLE_SERVICES"
    chmod 600 "$INJECTED_GOOGLE_SERVICES"
    CLEANED_INJECTION=1

    cd "$REPO_ROOT/apps/android"
    ./gradlew :app:bundleRelease --no-daemon --stacktrace \
      -Pphase10VersionName="$VERSION_NAME" \
      -Pphase10VersionCode="$VERSION_CODE" \
      -Pphase9ExternalSdks=true \
      -Pphase9AmplitudeApiKey="$BASEBALL_AMPLITUDE_API_KEY" \
      -Pphase11Distribution=production

    AAB_SOURCE="$REPO_ROOT/apps/android/app/build/outputs/bundle/release/app-release.aab"
    if [[ ! -f "$AAB_SOURCE" ]]; then
      fail "Compose release AAB was not produced: $AAB_SOURCE"
    fi
    AAB_NAME="baseball-android-compose-${VERSION_NAME}-${VERSION_CODE}.aab"
    AAB_PATH="$ARTIFACT_DIRECTORY/$AAB_NAME"
    cp "$AAB_SOURCE" "$AAB_PATH"

    if ! unzip -tqq "$AAB_PATH" >"$ARTIFACT_DIRECTORY/aab-zip-test.txt" 2>&1; then
      fail "Release-candidate AAB ZIP integrity verification failed"
    fi
    if ! jarsigner -verify -certs "$AAB_PATH" >"$ARTIFACT_DIRECTORY/aab-signature.txt" 2>&1; then
      fail "Release-candidate AAB signature verification failed"
    fi
    if ! grep -Fq 'jar verified.' "$ARTIFACT_DIRECTORY/aab-signature.txt"; then
      fail "Release-candidate AAB did not report a verified JAR signature"
    fi
    actual_certificate="$(keytool -J-Duser.language=en -printcert -jarfile "$AAB_PATH" |
      sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -n 1 | tr -d ':[:space:]' | tr '[:upper:]' '[:lower:]')"
    if [[ "$actual_certificate" != "$expected_certificate" ]]; then
      fail "Release-candidate AAB certificate does not match BASEBALL_UPLOAD_CERT_SHA256"
    fi
    printf '%s\n' "$actual_certificate" >"$ARTIFACT_DIRECTORY/aab-signing-cert.sha256"

    bundle_sha="$(shasum -a 256 "$AAB_PATH" | awk '{print $1}')"
    bundle_bytes="$(wc -c <"$AAB_PATH" | tr -d ' ')"
    printf '%s  %s\n' "$bundle_sha" "$AAB_NAME" >"$ARTIFACT_DIRECTORY/checksums.sha256"

    UNITY_EXPORT="$REPO_ROOT/artifacts/android-compose/unity-export/current/unityLibrary"
    unity_hash="$(find "$UNITY_EXPORT" -type f ! -path '*/build/*' -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}')"
    content_hash="$(shasum -a 256 "$REPO_ROOT/apps/android-unity/StoreAssets/manifest.json" | awk '{print $1}')"

    SCHEMA="baseball-android-compose-build-manifest-v1"
    DISTRIBUTION="production"
    if [[ "$git_dirty" == "true" ]]; then
      DISTRIBUTION="local-dirty-candidate"
    fi

    VERSION_NAME="$VERSION_NAME" VERSION_CODE="$VERSION_CODE" \
    GIT_COMMIT="$git_commit" GIT_DIRTY="$git_dirty" \
    ARTIFACT_DIRECTORY="$ARTIFACT_DIRECTORY" AAB_NAME="$AAB_NAME" \
    BUNDLE_SHA="$bundle_sha" BUNDLE_BYTES="$bundle_bytes" \
    CERT_SHA="$actual_certificate" UNITY_HASH="$unity_hash" \
    CONTENT_HASH="$content_hash" DISTRIBUTION="$DISTRIBUTION" \
    SCHEMA="$SCHEMA" REPO_ROOT="$REPO_ROOT" node <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const catalog = fs.readFileSync(path.join(process.env.REPO_ROOT, "apps/android/gradle/libs.versions.toml"), "utf8");
const wrapper = fs.readFileSync(path.join(process.env.REPO_ROOT, "apps/android/gradle/wrapper/gradle-wrapper.properties"), "utf8");
const gradleMatch = wrapper.match(/gradle-([0-9.]+)-bin\.zip/);
const pick = (text, key) => {
  const match = text.match(new RegExp(`^${key}\\s*=\\s*"([^"]+)"`, "m"));
  return match ? match[1] : null;
};
const manifest = {
  schema: process.env.SCHEMA,
  gitCommit: process.env.GIT_COMMIT,
  gitDirty: process.env.GIT_DIRTY === "true",
  versionName: process.env.VERSION_NAME,
  versionCode: Number(process.env.VERSION_CODE),
  package: "com.solkim.baseball.android",
  applicationLabel: "야구 못하면 또 환생함",
  distribution: process.env.DISTRIBUTION,
  environment: process.env.DISTRIBUTION === "production" ? "production" : process.env.DISTRIBUTION,
  agp: pick(catalog, "agp"),
  gradle: gradleMatch ? gradleMatch[1] : null,
  kotlin: pick(catalog, "kotlin"),
  composeBom: pick(catalog, "composeBom"),
  unityVersion: "6000.3.19f1",
  unityExportHash: process.env.UNITY_HASH,
  unityProtocol: "baseball-pitch-ipc-v1",
  il2cppCompilerConfiguration: "Release",
  minSdk: 26,
  targetSdk: 36,
  compileSdk: 36,
  abi: ["arm64-v8a"],
  bundleFile: process.env.AAB_NAME,
  bundleSha256: process.env.BUNDLE_SHA,
  bundleBytes: Number(process.env.BUNDLE_BYTES),
  uploadCertSha256: process.env.CERT_SHA,
  saveSchema: "android-unity-save-v1",
  contentManifestSha256: process.env.CONTENT_HASH,
  pageAlignment: "PAGE_ALIGNMENT_16K-required",
  playUpload: "not-performed",
};
if (!manifest.agp || !manifest.gradle || !manifest.kotlin || !manifest.composeBom) {
  console.error("Compose RC manifest is missing locked toolchain versions");
  process.exit(1);
}
if (manifest.distribution === "production" && manifest.gitDirty) {
  console.error("production distribution cannot record a dirty worktree");
  process.exit(1);
}
fs.writeFileSync(
  path.join(process.env.ARTIFACT_DIRECTORY, "build-manifest.json"),
  JSON.stringify(manifest, null, 2) + "\n",
);
console.log(`Compose RC evidence written: ${process.env.ARTIFACT_DIRECTORY}`);
NODE
    node "$REPO_ROOT/tools/check-android-compose-release.mjs" --require-aab --artifact-dir "$ARTIFACT_DIRECTORY"
    echo "Compose RC AAB ready (Play upload was not performed): $AAB_PATH"
    ;;
  *)
    fail "usage: tools/android-compose-build.sh verification|rc"
    ;;
esac
