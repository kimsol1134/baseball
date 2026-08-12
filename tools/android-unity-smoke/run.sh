#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly prerequisite_exit=2
readonly package_id="${BASEBALL_ANDROID_PACKAGE_ID:-com.solkim.baseball.android}"
readonly launch_timeout_seconds="${BASEBALL_SMOKE_LAUNCH_TIMEOUT_SECONDS:-20}"
readonly pitch_timeout_seconds="${BASEBALL_SMOKE_PITCH_TIMEOUT_SECONDS:-300}"
readonly settle_seconds="${BASEBALL_SMOKE_SETTLE_SECONDS:-1}"
readonly smoke_mode="${BASEBALL_SMOKE_MODE:-production}"
readonly qa_seed="${BASEBALL_SMOKE_QA_SEED:-20260811}"
readonly qa_crash_probe="${BASEBALL_SMOKE_QA_CRASH_PROBE:-0}"
readonly unity_android_player="${BASEBALL_UNITY_ANDROID_PLAYER:-/Applications/Unity/Hub/Editor/6000.3.19f1/PlaybackEngines/AndroidPlayer}"
readonly unity_android_sdk="${BASEBALL_UNITY_ANDROID_SDK:-$unity_android_player/SDK}"

fail() {
  printf 'Android Unity smoke 실패: %s\n' "$*" >&2
  exit 1
}

missing() {
  printf 'Android Unity smoke 사전 조건 누락: %s\n' "$*" >&2
  exit "$prerequisite_exit"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || missing "명령을 찾을 수 없습니다: $1"
}

require_file() {
  [[ -f "$1" ]] || missing "파일을 찾을 수 없습니다: $1"
}

require_secret_file() {
  require_file "$1"
  [[ -s "$1" ]] || missing "비밀번호 파일이 비어 있습니다: $1"
}

resolve_adb() {
  if [[ -n "${BASEBALL_ADB:-}" ]]; then
    [[ -x "$BASEBALL_ADB" ]] || missing "BASEBALL_ADB가 실행 파일이 아닙니다: $BASEBALL_ADB"
    printf '%s\n' "$BASEBALL_ADB"
    return
  fi

  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return
  fi

  local bundled_adb="$unity_android_sdk/platform-tools/adb"
  [[ -x "$bundled_adb" ]] || missing \
    "adb를 PATH 또는 Unity Android SDK에서 찾지 못했습니다. BASEBALL_ADB로 지정하세요."
  printf '%s\n' "$bundled_adb"
}

resolve_bundletool() {
  if [[ -n "${BASEBALL_BUNDLETOOL_JAR:-}" ]]; then
    require_file "$BASEBALL_BUNDLETOOL_JAR"
    printf '%s\n' "$BASEBALL_BUNDLETOOL_JAR"
    return
  fi

  local bundled_bundletool="$unity_android_player/Tools/bundletool-all-1.17.2.jar"
  [[ -f "$bundled_bundletool" ]] || missing \
    "bundletool을 Unity Android Build Support에서 찾지 못했습니다. BASEBALL_BUNDLETOOL_JAR로 지정하세요."
  printf '%s\n' "$bundled_bundletool"
}

resolve_zipalign() {
  if [[ -n "${BASEBALL_ZIPALIGN:-}" ]]; then
    [[ -x "$BASEBALL_ZIPALIGN" ]] || missing "BASEBALL_ZIPALIGN이 실행 파일이 아닙니다: $BASEBALL_ZIPALIGN"
    printf '%s\n' "$BASEBALL_ZIPALIGN"
    return
  fi
  if command -v zipalign >/dev/null 2>&1; then
    command -v zipalign
    return
  fi
  local bundled_zipalign="$unity_android_sdk/build-tools/36.0.0/zipalign"
  [[ -x "$bundled_zipalign" ]] || missing \
    "zipalign을 PATH 또는 Unity Android SDK에서 찾지 못했습니다. BASEBALL_ZIPALIGN로 지정하세요."
  printf '%s\n' "$bundled_zipalign"
}

resolve_apkanalyzer() {
  if [[ -n "${BASEBALL_APKANALYZER:-}" ]]; then
    [[ -x "$BASEBALL_APKANALYZER" ]] || missing \
      "BASEBALL_APKANALYZER가 실행 파일이 아닙니다: $BASEBALL_APKANALYZER"
    printf '%s\n' "$BASEBALL_APKANALYZER"
    return
  fi
  if command -v apkanalyzer >/dev/null 2>&1; then
    command -v apkanalyzer
    return
  fi
  local bundled_apkanalyzer="$unity_android_sdk/cmdline-tools/16.0/bin/apkanalyzer"
  [[ -x "$bundled_apkanalyzer" ]] || missing \
    "apkanalyzer를 PATH 또는 Unity Android SDK에서 찾지 못했습니다. BASEBALL_APKANALYZER로 지정하세요."
  printf '%s\n' "$bundled_apkanalyzer"
}

resolve_llvm_readelf() {
  if [[ -n "${BASEBALL_LLVM_READELF:-}" ]]; then
    [[ -x "$BASEBALL_LLVM_READELF" ]] || missing \
      "BASEBALL_LLVM_READELF가 실행 파일이 아닙니다: $BASEBALL_LLVM_READELF"
    printf '%s\n' "$BASEBALL_LLVM_READELF"
    return
  fi
  local bundled_readelf="$unity_android_player/NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf"
  [[ -x "$bundled_readelf" ]] || missing \
    "llvm-readelf를 Unity Android NDK에서 찾지 못했습니다. BASEBALL_LLVM_READELF로 지정하세요."
  printf '%s\n' "$bundled_readelf"
}

for command_name in java jarsigner keytool git grep sed date od unzip node; do
  require_command "$command_name"
done
readonly adb_bin="$(resolve_adb)"
readonly bundletool_jar="$(resolve_bundletool)"
readonly zipalign_bin="$(resolve_zipalign)"
readonly apkanalyzer_bin="$(resolve_apkanalyzer)"
readonly llvm_readelf="$(resolve_llvm_readelf)"

[[ -n "${BASEBALL_AAB:-}" ]] || missing 'BASEBALL_AAB를 설정하세요.'
[[ -n "${BASEBALL_ANDROID_KEYSTORE:-}" ]] || missing 'BASEBALL_ANDROID_KEYSTORE를 설정하세요.'
[[ -n "${BASEBALL_ANDROID_KEY_ALIAS:-}" ]] || missing 'BASEBALL_ANDROID_KEY_ALIAS를 설정하세요.'
[[ -n "${BASEBALL_ANDROID_STORE_PASSWORD_FILE:-}" ]] || missing 'BASEBALL_ANDROID_STORE_PASSWORD_FILE을 설정하세요.'
[[ -n "${BASEBALL_ANDROID_KEY_PASSWORD_FILE:-}" ]] || missing 'BASEBALL_ANDROID_KEY_PASSWORD_FILE을 설정하세요.'
require_file "$BASEBALL_AAB"
require_file "$BASEBALL_ANDROID_KEYSTORE"
require_secret_file "$BASEBALL_ANDROID_STORE_PASSWORD_FILE"
require_secret_file "$BASEBALL_ANDROID_KEY_PASSWORD_FILE"
[[ "$launch_timeout_seconds" =~ ^[1-9][0-9]*$ ]] || missing 'BASEBALL_SMOKE_LAUNCH_TIMEOUT_SECONDS는 양의 정수여야 합니다.'
[[ "$pitch_timeout_seconds" =~ ^[1-9][0-9]*$ ]] || missing 'BASEBALL_SMOKE_PITCH_TIMEOUT_SECONDS는 양의 정수여야 합니다.'
[[ "$settle_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]] || missing 'BASEBALL_SMOKE_SETTLE_SECONDS는 0 이상의 숫자여야 합니다.'
[[ "$smoke_mode" == "production" || "$smoke_mode" == "internal" ]] ||
  missing 'BASEBALL_SMOKE_MODE는 production 또는 internal이어야 합니다.'
[[ "$qa_seed" =~ ^[0-9]+$ ]] || missing 'BASEBALL_SMOKE_QA_SEED는 부호 없는 10진수여야 합니다.'
[[ "$qa_crash_probe" == "0" || "$qa_crash_probe" == "1" ]] ||
  missing 'BASEBALL_SMOKE_QA_CRASH_PROBE는 0 또는 1이어야 합니다.'
if [[ "$smoke_mode" == "production" && "$qa_crash_probe" == "1" ]]; then
  missing 'crash probe는 internal smoke에서만 실행할 수 있습니다.'
fi

build_manifest="${BASEBALL_BUILD_MANIFEST:-$(dirname "$BASEBALL_AAB")/build-manifest.json}"
build_checksums="${BASEBALL_BUILD_CHECKSUMS:-$(dirname "$BASEBALL_AAB")/checksums.sha256}"
if [[ "$smoke_mode" == "production" ]]; then
  require_file "$build_manifest"
  require_file "$build_checksums"
  [[ -n "${BASEBALL_UPLOAD_CERT_SHA256:-}" ]] ||
    missing 'production smoke에는 BASEBALL_UPLOAD_CERT_SHA256이 필요합니다.'
fi

device_serial="${BASEBALL_ADB_SERIAL:-}"
if [[ -z "$device_serial" ]]; then
  device_serials=()
  while IFS=$'\t' read -r serial state; do
    [[ "$state" == "device" ]] && device_serials+=("$serial")
  done < <("$adb_bin" devices | sed '1d')
  [[ ${#device_serials[@]} -gt 0 ]] || missing 'adb 상태가 device인 Android 기기가 없습니다.'
  [[ ${#device_serials[@]} -eq 1 ]] || missing '기기가 여러 대입니다. BASEBALL_ADB_SERIAL로 한 대를 지정하세요.'
  device_serial="${device_serials[0]}"
fi

adb_command=("$adb_bin" -s "$device_serial")
[[ "$("${adb_command[@]}" get-state 2>/dev/null)" == "device" ]] || missing '선택한 adb 기기가 device 상태가 아닙니다.'

sdk_level="$("${adb_command[@]}" shell getprop ro.build.version.sdk | tr -d '\r')"
[[ "$sdk_level" =~ ^[0-9]+$ ]] || missing 'Android API level을 확인할 수 없습니다.'
[[ "$sdk_level" -ge 26 ]] || missing '지원 범위는 Android 8(API 26) 이상입니다.'
device_page_size="$("${adb_command[@]}" shell getconf PAGE_SIZE 2>/dev/null | tr -d '\r')"
[[ "$device_page_size" =~ ^[1-9][0-9]*$ ]] || missing '기기의 native page size를 확인할 수 없습니다.'
native_16k_execution="not_tested"
rc_build_evidence_result="not_applicable_internal_build"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
evidence_parent="${BASEBALL_SMOKE_EVIDENCE_ROOT:-$repo_root/artifacts/android-unity-smoke}"
evidence_dir="$evidence_parent/$timestamp"
[[ ! -e "$evidence_dir" ]] || missing "evidence 경로가 이미 존재합니다: $evidence_dir"
mkdir -p "$evidence_dir"

original_airplane=""
original_accelerometer_rotation=""
original_user_rotation=""
original_font_scale=""
original_notification_permission=""
state_captured=0

set_airplane() {
  local desired="$1"
  if [[ "$desired" == "1" ]]; then
    "${adb_command[@]}" shell cmd connectivity airplane-mode enable >/dev/null
  else
    "${adb_command[@]}" shell cmd connectivity airplane-mode disable >/dev/null
  fi
}

notification_permission_state() {
  local permission_line
  permission_line="$(
    "${adb_command[@]}" shell dumpsys package "$package_id" 2>/dev/null |
      tr -d '\r' |
      sed -n '/android[.]permission[.]POST_NOTIFICATIONS: granted=/p' |
      tail -n 1
  )"
  case "$permission_line" in
    *"granted=true"*) printf 'granted\n' ;;
    *"granted=false"*) printf 'denied\n' ;;
    *) return 1 ;;
  esac
}

restore_device() {
  local status=$?
  set +e
  if [[ "$state_captured" == "1" ]] && "${adb_command[@]}" get-state >/dev/null 2>&1; then
    [[ "$original_accelerometer_rotation" =~ ^[0-9]+$ ]] &&
      "${adb_command[@]}" shell settings put system accelerometer_rotation "$original_accelerometer_rotation" >/dev/null
    [[ "$original_user_rotation" =~ ^[0-9]+$ ]] &&
      "${adb_command[@]}" shell settings put system user_rotation "$original_user_rotation" >/dev/null
    [[ "$original_font_scale" =~ ^[0-9]+([.][0-9]+)?$ ]] &&
      "${adb_command[@]}" shell settings put system font_scale "$original_font_scale" >/dev/null
    [[ "$original_airplane" == "0" || "$original_airplane" == "1" ]] && set_airplane "$original_airplane"
    if [[ "$original_notification_permission" == "granted" ]]; then
      "${adb_command[@]}" shell pm grant "$package_id" android.permission.POST_NOTIFICATIONS >/dev/null
    elif [[ "$original_notification_permission" == "denied" ]]; then
      "${adb_command[@]}" shell pm revoke "$package_id" android.permission.POST_NOTIFICATIONS >/dev/null
    fi
  fi
  if [[ "$status" -ne 0 ]]; then
    printf '기기 설정 복원을 시도했습니다. 증거 경로: %s\n' "$evidence_dir" >&2
  fi
  exit "$status"
}
trap restore_device EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$smoke_mode" == "production" ]]; then
  current_git_commit="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null)" ||
    missing 'production smoke의 현재 Git commit을 확인할 수 없습니다.'
  [[ -z "$(git -C "$repo_root" status --porcelain --untracked-files=all)" ]] ||
    fail 'production smoke는 build manifest와 같은 clean worktree에서만 실행할 수 있습니다.'
  AAB_PATH="$BASEBALL_AAB" \
    BUILD_MANIFEST="$build_manifest" \
    BUILD_CHECKSUMS="$build_checksums" \
    EVIDENCE_DIR="$evidence_dir" \
    EXPECTED_PACKAGE_ID="$package_id" \
    EXPECTED_GIT_COMMIT="$current_git_commit" node <<'NODE' ||
    fail 'production AAB와 RC build evidence가 일치하지 않습니다.'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

function fail(message) {
  console.error(`production build evidence invalid: ${message}`);
  process.exit(1);
}
function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}
function safeFileName(value, label) {
  const name = path.basename(value ?? "");
  if (!name || name !== value) fail(`${label} is missing or unsafe`);
  return name;
}

const aabPath = path.resolve(process.env.AAB_PATH);
const manifestPath = path.resolve(process.env.BUILD_MANIFEST);
const checksumsPath = path.resolve(process.env.BUILD_CHECKSUMS);
const manifestDirectory = path.dirname(manifestPath);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
if (manifest.schema !== "baseball-android-build-manifest-v1") fail("manifest schema mismatch");
if (manifest.gitCommit !== process.env.EXPECTED_GIT_COMMIT || manifest.gitDirty !== false) {
  fail("Git commit/dirty state mismatch");
}
if (manifest.applicationId !== process.env.EXPECTED_PACKAGE_ID) fail("application ID mismatch");
if (manifest.distribution !== "production" || manifest.environment !== "production") {
  fail("distribution/environment mismatch");
}
if (manifest.developmentBuild !== false || manifest.internalQaCompiled !== false) {
  fail("production build flags mismatch");
}
if (manifest.il2cppCompilerConfiguration !== "Release" || manifest.architecture !== "ARM64" ||
    manifest.graphicsApi !== "OpenGLES3" || manifest.minimumApi !== 26 || manifest.targetApi !== 36) {
  fail("Android player configuration mismatch");
}
if (!manifest.versionName || !Number.isInteger(manifest.versionCode) || manifest.versionCode <= 0) {
  fail("version is missing or invalid");
}

const bundleName = safeFileName(manifest.bundleFile, "bundleFile");
if (path.basename(aabPath) !== bundleName) fail("BASEBALL_AAB filename does not match manifest");
const actualBundleSha = sha256(aabPath);
if (actualBundleSha !== manifest.bundleSha256) fail("AAB SHA-256 mismatch");

const symbolName = safeFileName(manifest.symbolFile, "symbolFile");
const symbolPath = path.join(manifestDirectory, symbolName);
if (!fs.existsSync(symbolPath)) fail("IL2CPP symbol archive is missing beside build manifest");
if (sha256(symbolPath) !== manifest.symbolSha256) fail("IL2CPP symbol SHA-256 mismatch");
const expectedChecksums = [
  `${manifest.bundleSha256}  ${bundleName}`,
  `${manifest.symbolSha256}  ${symbolName}`,
];
const actualChecksums = fs.readFileSync(checksumsPath, "utf8").trim().split(/\r?\n/);
if (JSON.stringify(actualChecksums) !== JSON.stringify(expectedChecksums)) {
  fail("checksums.sha256 does not exactly match the manifest");
}

fs.copyFileSync(manifestPath, path.join(process.env.EVIDENCE_DIR, "build-manifest.json"));
fs.copyFileSync(checksumsPath, path.join(process.env.EVIDENCE_DIR, "checksums.sha256"));
fs.writeFileSync(
  path.join(process.env.EVIDENCE_DIR, "build-evidence-link.txt"),
  [
    "result=passed",
    `git_commit=${manifest.gitCommit}`,
    `version_name=${manifest.versionName}`,
    `version_code=${manifest.versionCode}`,
    `distribution=${manifest.distribution}`,
    `aab_sha256=${actualBundleSha}`,
    `symbol_sha256=${manifest.symbolSha256}`,
    "",
  ].join("\n"),
);
NODE

  expected_certificate="$(printf '%s' "$BASEBALL_UPLOAD_CERT_SHA256" |
    tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
  [[ "$expected_certificate" =~ ^[0-9A-F]{64}$ ]] ||
    missing 'BASEBALL_UPLOAD_CERT_SHA256는 SHA-256 인증서 지문이어야 합니다.'
  actual_certificate="$(keytool -J-Duser.language=en -printcert -jarfile "$BASEBALL_AAB" |
    sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' | head -n 1 |
    tr -d ':[:space:]' | tr '[:lower:]' '[:upper:]')"
  [[ "$actual_certificate" == "$expected_certificate" ]] ||
    fail 'AAB 서명 인증서가 BASEBALL_UPLOAD_CERT_SHA256 pin과 다릅니다.'
  printf '%s\n' "$actual_certificate" >"$evidence_dir/aab-signing-cert.sha256"
  rc_build_evidence_result="passed"
fi

if [[ "$smoke_mode" == "production" ]]; then
  jarsigner -verify -strict -certs "$BASEBALL_AAB" >"$evidence_dir/aab-signature.txt" 2>&1 ||
    fail '프로덕션 AAB strict 서명 검증에 실패했습니다.'
else
  # Unity Local Verification uses the standard self-signed Android debug
  # certificate. Verify every signed entry, but reserve PKIX/strict trust and
  # the upload-certificate pin for production candidates.
  jarsigner -verify -certs "$BASEBALL_AAB" >"$evidence_dir/aab-signature.txt" 2>&1 ||
    fail '내부 검증 AAB 서명 무결성 검사에 실패했습니다.'
fi
java -jar "$bundletool_jar" dump config --bundle="$BASEBALL_AAB" \
  >"$evidence_dir/bundle-config.txt" 2>"$evidence_dir/bundle-config.stderr.txt" ||
  fail 'AAB BundleConfig를 읽지 못했습니다.'
grep -Fq 'PAGE_ALIGNMENT_16K' "$evidence_dir/bundle-config.txt" ||
  fail 'AAB에 PAGE_ALIGNMENT_16K 설정이 없습니다.'

apks_path="$evidence_dir/baseball-device.apks"
java -jar "$bundletool_jar" build-apks \
  --bundle="$BASEBALL_AAB" \
  --output="$apks_path" \
  --adb="$adb_bin" \
  --connected-device \
  --device-id="$device_serial" \
  --ks="$BASEBALL_ANDROID_KEYSTORE" \
  --ks-key-alias="$BASEBALL_ANDROID_KEY_ALIAS" \
  --ks-pass="file:$BASEBALL_ANDROID_STORE_PASSWORD_FILE" \
  --key-pass="file:$BASEBALL_ANDROID_KEY_PASSWORD_FILE" \
  --overwrite >"$evidence_dir/bundletool-build.txt" 2>&1 || fail 'AAB에서 APKS를 만들지 못했습니다.'

unzip -tqq "$apks_path" >"$evidence_dir/apks-zip-test.txt" 2>&1 ||
  fail '생성된 APKS ZIP 무결성 검증에 실패했습니다.'
apk_extract_dir="$evidence_dir/apks-extracted"
mkdir -p "$apk_extract_dir"
apk_count=0
native_count=0
base_manifest_apk_count=0
apk_debuggable=""
: >"$evidence_dir/apk-zipalign.txt"
: >"$evidence_dir/elf-alignment.txt"
: >"$evidence_dir/apk-permissions.txt"
: >"$evidence_dir/apk-build-mode.txt"
while IFS= read -r apk_entry; do
  [[ -z "$apk_entry" ]] && continue
  if [[ ! "$apk_entry" =~ ^([A-Za-z0-9._+-]+/)*[A-Za-z0-9._+-]+[.]apk$ ]]; then
    fail "APKS에 안전하지 않은 APK entry가 있습니다: $apk_entry"
  fi
  apk_count=$((apk_count + 1))
  apk_file="$apk_extract_dir/apk-${apk_count}.apk"
  unzip -p "$apks_path" "$apk_entry" >"$apk_file" ||
    fail "APKS에서 APK를 추출하지 못했습니다: $apk_entry"
  {
    printf 'apk=%s\n' "$apk_entry"
    "$zipalign_bin" -c -P 16 -v 4 "$apk_file"
  } >>"$evidence_dir/apk-zipalign.txt" 2>&1 ||
    fail "생성 APK가 16KB ZIP alignment를 충족하지 않습니다: $apk_entry"
  if [[ "$apk_entry" == "base-master.apk" || "$apk_entry" == */base-master.apk ]]; then
    base_manifest_apk_count=$((base_manifest_apk_count + 1))
    apk_application_id="$("$apkanalyzer_bin" manifest application-id "$apk_file" | tr -d '\r')" ||
      fail 'base-master APK application ID를 읽지 못했습니다.'
    apk_debuggable="$("$apkanalyzer_bin" manifest debuggable "$apk_file" | tr -d '\r')" ||
      fail 'base-master APK debuggable 값을 읽지 못했습니다.'
    expected_debuggable="false"
    [[ "$smoke_mode" == "internal" ]] && expected_debuggable="true"
    {
      printf 'apk=%s\n' "$apk_entry"
      printf 'application_id=%s\n' "$apk_application_id"
      printf 'debuggable=%s\n' "$apk_debuggable"
      printf 'expected_debuggable=%s\n' "$expected_debuggable"
    } >>"$evidence_dir/apk-build-mode.txt"
    [[ "$apk_application_id" == "$package_id" ]] ||
      fail "base-master APK application ID가 기대값과 다릅니다: $apk_application_id"
    [[ "$apk_debuggable" == "$expected_debuggable" ]] ||
      fail "$smoke_mode smoke와 AAB debuggable 모드가 일치하지 않습니다."

    base_manifest_xml="$evidence_dir/base-master-manifest.xml"
    "$apkanalyzer_bin" manifest print "$apk_file" >"$base_manifest_xml" 2>&1 ||
      fail 'base-master APK merged manifest를 읽지 못했습니다.'
    {
      printf 'apk=%s\n' "$apk_entry"
      "$apkanalyzer_bin" manifest permissions "$apk_file"
    } >>"$evidence_dir/apk-permissions.txt" 2>&1 ||
      fail 'base-master APK merged permission을 읽지 못했습니다.'
    if ! BASE_MANIFEST_XML="$base_manifest_xml" \
      BASE_SCREEN_EVIDENCE="$evidence_dir/apk-compatible-screens.txt" node <<'NODE'
const fs = require("node:fs");
const xml = fs.readFileSync(process.env.BASE_MANIFEST_XML, "utf8");
const expected = ["small", "normal"].flatMap((size) =>
  ["ldpi", "mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]
    .map((density) => `${size}:${density}`)
).sort();
function normalizedScreenSize(value) {
  // apkanalyzer may print either the enum ordinal (1/2) or Android's
  // Configuration.SCREENLAYOUT_SIZE_* constants (200/300).
  return ({ "1": "small", "2": "normal", "200": "small", "300": "normal" })[value]
    ?? value ?? "missing";
}
function normalizedScreenDensity(value) {
  return ({
    "120": "ldpi", "160": "mdpi", "240": "hdpi", "320": "xhdpi",
    "480": "xxhdpi", "640": "xxxhdpi",
    "0x78": "ldpi", "0xa0": "mdpi", "0xf0": "hdpi", "0x140": "xhdpi",
    "0x1e0": "xxhdpi", "0x280": "xxxhdpi",
  })[(value ?? "").toLowerCase()] ?? value ?? "missing";
}
const pairs = [...xml.matchAll(/<screen\b[^>]*>/g)].map((match) => {
  const size = match[0].match(/(?:android:)?screenSize\s*=\s*["']([^"']+)["']/)?.[1];
  const density = match[0].match(/(?:android:)?screenDensity\s*=\s*["']([^"']+)["']/)?.[1];
  return `${normalizedScreenSize(size)}:${normalizedScreenDensity(density)}`;
}).sort();
if (JSON.stringify(pairs) !== JSON.stringify(expected)) {
  console.error(`compatible_screens=${pairs.join(",")}`);
  process.exit(1);
}
fs.writeFileSync(
  process.env.BASE_SCREEN_EVIDENCE,
  `result=passed compatible_screens=${pairs.join(",")}\n`,
);
NODE
    then
      fail 'base-master APK compatible-screens가 스마트폰 허용 목록과 다릅니다.'
    fi
  fi

  while IFS= read -r native_entry; do
    [[ -z "$native_entry" ]] && continue
    if [[ ! "$native_entry" =~ ^lib/arm64-v8a/[A-Za-z0-9._+-]+[.]so$ ]]; then
      fail "APK에 안전하지 않은 ARM64 library entry가 있습니다: $native_entry"
    fi
    native_count=$((native_count + 1))
    native_file="$apk_extract_dir/library-${native_count}.so"
    unzip -p "$apk_file" "$native_entry" >"$native_file" ||
      fail "APK에서 ARM64 library를 추출하지 못했습니다: $native_entry"
    load_lines="$("$llvm_readelf" -lW "$native_file" |
      sed -n '/^[[:space:]]*LOAD[[:space:]]/p')" ||
      fail "ARM64 library의 ELF header를 읽지 못했습니다: $native_entry"
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
      fail "ARM64 library의 ELF LOAD alignment가 16KB 미만입니다: $native_entry"
    fi
    {
      printf 'apk=%s library=%s\n' "$apk_entry" "$native_entry"
      printf '%s\n' "$load_lines"
    } >>"$evidence_dir/elf-alignment.txt"
  done < <(unzip -Z1 "$apk_file" | sed -n '/^lib\/arm64-v8a\/[^/]*[.]so$/p')
done < <(unzip -Z1 "$apks_path" | sed -n '/[.]apk$/p')
[[ "$apk_count" -gt 0 ]] || fail 'APKS에 검증할 APK가 없습니다.'
[[ "$native_count" -gt 0 ]] || fail 'APKS에 검증할 ARM64 native library가 없습니다.'
[[ "$base_manifest_apk_count" -eq 1 ]] ||
  fail "APKS에서 단일 base-master APK를 찾지 못했습니다: $base_manifest_apk_count"
printf 'result=passed apks=%s alignment=16384\n' "$apk_count" >>"$evidence_dir/apk-zipalign.txt"
printf 'result=passed mode=%s\n' "$smoke_mode" >>"$evidence_dir/apk-build-mode.txt"
printf 'result=passed libraries=%s minimum_load_alignment=16384\n' "$native_count" \
  >>"$evidence_dir/elf-alignment.txt"
if ! APK_PERMISSIONS="$evidence_dir/apk-permissions.txt" node <<'NODE'
const fs = require("node:fs");
const path = process.env.APK_PERMISSIONS;
const raw = fs.readFileSync(path, "utf8");
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
  console.error(`permissions=${permissions.join(",")}`);
  process.exit(1);
}
fs.appendFileSync(path, `result=passed permissions=${permissions.join(",")}\n`);
NODE
then
  fail '생성 APK의 merged permission이 허용 목록과 다릅니다.'
fi

prior_package_paths="$(
  "${adb_command[@]}" shell pm path "$package_id" 2>/dev/null | tr -d '\r' || true
)"
if [[ -n "$prior_package_paths" ]]; then
  {
    printf 'prior_installation=present\n'
    printf '%s\n' "$prior_package_paths"
  } >"$evidence_dir/clean-install.txt"
  "$adb_bin" -s "$device_serial" uninstall "$package_id" \
    >>"$evidence_dir/clean-install.txt" 2>&1 ||
    fail "기존 $package_id 설치와 앱 데이터를 제거하지 못했습니다."
  if [[ -n "$("${adb_command[@]}" shell pm path "$package_id" 2>/dev/null | tr -d '\r')" ]]; then
    fail "기존 $package_id 패키지가 uninstall 뒤에도 남아 있습니다."
  fi
  printf 'uninstall=passed\n' >>"$evidence_dir/clean-install.txt"
else
  printf '%s\n' \
    'prior_installation=absent' \
    'uninstall=not_required' >"$evidence_dir/clean-install.txt"
fi

java -jar "$bundletool_jar" install-apks \
  --apks="$apks_path" \
  --adb="$adb_bin" \
  --device-id="$device_serial" >"$evidence_dir/bundletool-install.txt" 2>&1 || fail 'APKS 설치에 실패했습니다.'
[[ -n "$("${adb_command[@]}" shell pm path "$package_id" 2>/dev/null | tr -d '\r')" ]] ||
  fail "bundletool 설치 뒤 $package_id 패키지를 찾지 못했습니다."
printf '%s\n' \
  'install=passed' \
  'data_state=fresh_install' >>"$evidence_dir/clean-install.txt"

resolved_activity="$("${adb_command[@]}" shell cmd package resolve-activity --brief "$package_id" | tr -d '\r' | sed -n '$p')"
[[ "$resolved_activity" == */* ]] || fail "launch activity를 찾지 못했습니다: $package_id"

original_airplane="$("${adb_command[@]}" shell settings get global airplane_mode_on | tr -d '\r')"
original_accelerometer_rotation="$("${adb_command[@]}" shell settings get system accelerometer_rotation | tr -d '\r')"
original_user_rotation="$("${adb_command[@]}" shell settings get system user_rotation | tr -d '\r')"
original_font_scale="$("${adb_command[@]}" shell settings get system font_scale | tr -d '\r')"
if [[ "$sdk_level" -ge 33 ]]; then
  original_notification_permission="$(notification_permission_state)"
else
  original_notification_permission="not_applicable"
fi
[[ "$original_airplane" == "0" || "$original_airplane" == "1" ]] || fail '기존 airplane mode 상태를 읽지 못했습니다.'
[[ "$original_accelerometer_rotation" =~ ^[0-9]+$ ]] || fail '기존 자동 회전 상태를 읽지 못했습니다.'
[[ "$original_user_rotation" =~ ^[0-9]+$ ]] || fail '기존 화면 회전 값을 읽지 못했습니다.'
[[ "$original_font_scale" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail '기존 글자 크기 값을 읽지 못했습니다.'
[[ "$original_notification_permission" == "granted" || "$original_notification_permission" == "denied" || "$original_notification_permission" == "not_applicable" ]] ||
  fail '기존 알림 권한 상태를 읽지 못했습니다.'
state_captured=1

"${adb_command[@]}" shell settings put system accelerometer_rotation 0 >/dev/null
"${adb_command[@]}" shell settings put system user_rotation 0 >/dev/null
set_airplane 0
[[ "$("${adb_command[@]}" shell settings get global airplane_mode_on | tr -d '\r')" == "0" ]] ||
  fail 'cold start 전에 airplane mode를 해제하지 못했습니다.'
"${adb_command[@]}" logcat -c

wait_for_process() {
  local deadline=$((SECONDS + launch_timeout_seconds))
  local pid=""
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    pid="$("${adb_command[@]}" shell pidof "$package_id" 2>/dev/null | tr -d '\r')"
    [[ -n "$pid" ]] && return 0
    sleep 0.25
  done
  return 1
}

wait_for_foreground() {
  local evidence_file="$1"
  local deadline=$((SECONDS + launch_timeout_seconds))
  local activity_state=""
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    activity_state="$("${adb_command[@]}" shell dumpsys activity activities 2>/dev/null | tr -d '\r')"
    if printf '%s\n' "$activity_state" |
      grep -E '(mResumedActivity|topResumedActivity|ResumedActivity)' |
      grep -F "$package_id" >/dev/null; then
      printf '%s\n' "$activity_state" >"$evidence_file"
      return 0
    fi
    sleep 0.25
  done
  printf '%s\n' "$activity_state" >"$evidence_file"
  return 1
}

wait_for_app_marker() {
  local evidence_file="$1"
  local marker="$2"
  local timeout_seconds="${3:-$launch_timeout_seconds}"
  local deadline=$((SECONDS + timeout_seconds))
  local pid=""
  : >"$evidence_file"
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    pid="$("${adb_command[@]}" shell pidof "$package_id" 2>/dev/null | tr -d '\r')"
    if [[ -n "$pid" ]]; then
      "${adb_command[@]}" logcat -d -v threadtime --pid="$pid" >"$evidence_file" 2>&1 || true
      if grep -Fq "$marker" "$evidence_file"; then
        printf 'matched_marker=%s\n' "$marker" >>"$evidence_file"
        return 0
      fi
    fi
    sleep 0.25
  done
  printf 'timeout_seconds=%s expected_marker=%s\n' "$timeout_seconds" "$marker" \
    >>"$evidence_file"
  return 1
}

wait_for_global_marker() {
  local evidence_file="$1"
  local marker="$2"
  local timeout_seconds="${3:-$launch_timeout_seconds}"
  local deadline=$((SECONDS + timeout_seconds))
  : >"$evidence_file"
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    "${adb_command[@]}" logcat -d -v threadtime >"$evidence_file" 2>&1 || true
    if grep -Fq "$marker" "$evidence_file"; then
      printf 'matched_marker=%s\n' "$marker" >>"$evidence_file"
      return 0
    fi
    sleep 0.25
  done
  printf 'timeout_seconds=%s expected_marker=%s\n' "$timeout_seconds" "$marker" \
    >>"$evidence_file"
  return 1
}

verify_portrait_screenshot() {
  local screenshot="$1"
  local label="$2"
  local byte0 byte1 byte2 byte3 byte4 byte5 byte6 byte7
  local IFS=' '
  read -r byte0 byte1 byte2 byte3 byte4 byte5 byte6 byte7 < <(od -An -tu1 -N8 -j16 "$screenshot")
  [[ -n "${byte7:-}" ]] || fail "$label PNG의 IHDR 크기를 읽지 못했습니다."
  local width=$((byte0 * 16777216 + byte1 * 65536 + byte2 * 256 + byte3))
  local height=$((byte4 * 16777216 + byte5 * 65536 + byte6 * 256 + byte7))
  printf '%s width=%s height=%s\n' "$label" "$width" "$height" >>"$evidence_dir/screenshot-dimensions.txt"
  [[ "$height" -gt "$width" ]] || fail "$label screenshot이 portrait가 아닙니다: ${width}x${height}"
}

launch_and_capture() {
  local label="$1"
  shift
  "${adb_command[@]}" shell am force-stop "$package_id"
  "${adb_command[@]}" shell timeout "$launch_timeout_seconds" am start -W -n "$resolved_activity" \
    "$@" \
    >"$evidence_dir/$label-start.txt" 2>&1 || fail "$label 시작 명령이 실패하거나 시간 제한을 넘었습니다."
  grep -Eq '^Status:[[:space:]]+ok' "$evidence_dir/$label-start.txt" ||
    fail "$label am start가 성공 상태를 반환하지 않았습니다."
  wait_for_process || fail "$label 뒤 앱 process가 ${launch_timeout_seconds}초 안에 나타나지 않았습니다."
  wait_for_foreground "$evidence_dir/$label-activity.txt" ||
    fail "$label 뒤 앱이 ${launch_timeout_seconds}초 안에 foreground/resumed 상태가 되지 않았습니다."
  wait_for_app_marker \
    "$evidence_dir/$label-first-interactive.txt" \
    'BASEBALL_FIRST_INTERACTIVE schema=1 status=passed' ||
    fail "$label 뒤 실제 shell의 first-interactive 마커가 ${launch_timeout_seconds}초 안에 나타나지 않았습니다."
  capture_foreground "$label"
}

launch_internal_command() {
  local label="$1"
  local command="$2"
  local expected_marker="$3"
  local phase="${4:-prologue}"
  local quality="${5:-high}"
  [[ "$smoke_mode" == "internal" ]] || fail 'internal QA command가 production smoke에서 요청되었습니다.'
  launch_and_capture "$label" \
    --es baseball.qa.command "$command" \
    --es baseball.qa.seed "$qa_seed" \
    --es baseball.qa.phase "$phase" \
    --es baseball.qa.quality "$quality"
  wait_for_app_marker \
    "$evidence_dir/$label-qa-marker.txt" \
    "BASEBALL_QA_MARKER schema=1 name=$expected_marker status=passed" ||
    fail "$label 내부 QA 완료 마커가 ${launch_timeout_seconds}초 안에 나타나지 않았습니다."
  capture_foreground "$label-completed"
}

capture_foreground() {
  local label="$1"
  sleep "$settle_seconds"
  "${adb_command[@]}" exec-out screencap -p >"$evidence_dir/$label.png" || fail "$label screenshot 저장에 실패했습니다."
  verify_portrait_screenshot "$evidence_dir/$label.png" "$label"
  local active_pid
  active_pid="$("${adb_command[@]}" shell pidof "$package_id" | tr -d '\r')"
  "${adb_command[@]}" logcat -d -v threadtime --pid="$active_pid" >"$evidence_dir/$label-app-logcat.txt"
}

launch_and_capture '01-cold-start'
cold_pid="$("${adb_command[@]}" shell pidof "$package_id" | tr -d '\r')"
"${adb_command[@]}" shell input keyevent KEYCODE_HOME >/dev/null
sleep "$settle_seconds"
"${adb_command[@]}" shell dumpsys activity activities >"$evidence_dir/02-background-activity.txt"
if grep -E '(mResumedActivity|topResumedActivity|ResumedActivity)' \
  "$evidence_dir/02-background-activity.txt" | grep -F "$package_id" >/dev/null; then
  fail 'HOME 이동 뒤 앱이 계속 resumed 상태입니다.'
fi
"${adb_command[@]}" shell timeout "$launch_timeout_seconds" am start -W -n "$resolved_activity" \
  >"$evidence_dir/02-background-resume-start.txt" 2>&1 ||
  fail 'background resume 시작 명령이 실패하거나 시간 제한을 넘었습니다.'
wait_for_foreground "$evidence_dir/02-background-resume-activity.txt" ||
  fail 'background resume 뒤 앱이 foreground/resumed 상태가 되지 않았습니다.'
warm_pid="$("${adb_command[@]}" shell pidof "$package_id" | tr -d '\r')"
[[ -n "$warm_pid" && "$warm_pid" == "$cold_pid" ]] ||
  fail 'background resume가 기존 process를 유지하지 못했습니다.'
capture_foreground '02-background-resume'

"${adb_command[@]}" shell settings put system user_rotation 1 >/dev/null
launch_and_capture '03-landscape-request'
"${adb_command[@]}" shell settings put system user_rotation 0 >/dev/null

set_airplane 1
[[ "$("${adb_command[@]}" shell settings get global airplane_mode_on | tr -d '\r')" == "1" ]] ||
  fail 'airplane mode가 활성화되지 않았습니다.'
[[ "$("${adb_command[@]}" get-state 2>/dev/null)" == "device" ]] ||
  fail 'airplane mode 이후 adb 연결이 끊겼습니다. USB 연결 기기를 사용하세요.'
launch_and_capture '04-offline-relaunch'

set_airplane "$original_airplane"
notification_denial_result="not_applicable_api_lt_33"
if [[ "$sdk_level" -ge 33 ]]; then
  "${adb_command[@]}" shell pm revoke "$package_id" android.permission.POST_NOTIFICATIONS >/dev/null ||
    fail '알림 권한 거부 상태를 만들지 못했습니다.'
  [[ "$(notification_permission_state)" == "denied" ]] ||
    fail '알림 권한이 denied로 확인되지 않았습니다.'
  notification_denial_result="passed"
fi
launch_and_capture '05-notification-denied'

"${adb_command[@]}" shell settings put system font_scale 2.0 >/dev/null
launch_and_capture '06-font-200-percent'
"${adb_command[@]}" shell settings put system font_scale "$original_font_scale" >/dev/null

before_trim_pid="$("${adb_command[@]}" shell pidof "$package_id" | tr -d '\r')"
"${adb_command[@]}" shell am send-trim-memory "$package_id" RUNNING_LOW \
  >"$evidence_dir/07-low-memory-command.txt" 2>&1 || fail 'low-memory callback 전달에 실패했습니다.'
sleep "$settle_seconds"
after_trim_pid="$("${adb_command[@]}" shell pidof "$package_id" | tr -d '\r')"
[[ -n "$after_trim_pid" && "$after_trim_pid" == "$before_trim_pid" ]] ||
  fail 'low-memory callback 뒤 앱 process가 종료되었습니다.'
wait_for_foreground "$evidence_dir/07-low-memory-activity.txt" ||
  fail 'low-memory callback 뒤 앱이 foreground 상태를 유지하지 못했습니다.'
capture_foreground '07-low-memory'

production_pitch_16k_result="not_applicable_page_size_${device_page_size}"
if [[ "$smoke_mode" == "internal" ]]; then
  production_pitch_16k_result="not_applicable_internal_build"
elif [[ "$device_page_size" == "16384" ]]; then
  printf '%s\n' \
    "16KB production 증거: 기기에서 실제 커리어 투구 한 공을 완료하세요. 제한 ${pitch_timeout_seconds}초." >&2
  wait_for_app_marker \
    "$evidence_dir/08-production-pitch-16k.txt" \
    'BASEBALL_PITCH_PRESENTATION_COMPLETED schema=1 status=passed' \
    "$pitch_timeout_seconds" ||
    fail '16KB production AAB에서 실제 투구 presentation 완료 marker를 확인하지 못했습니다.'
  capture_foreground '08-production-pitch-16k-completed'
  production_pitch_16k_result="passed"
  native_16k_execution="passed"
fi

qa_fixture_result="not_requested"
qa_pitch_high_result="not_requested"
qa_pitch_low_result="not_requested"
qa_nonfatal_result="not_requested"
qa_save_corruption_result="not_requested"
qa_save_fault_result="not_requested"
qa_save_failure_proxy_result="not_requested"
qa_analytics_result="not_requested"
qa_tutorial_relaunch_result="not_requested"
qa_crash_result="not_requested"
if [[ "$smoke_mode" == "internal" ]]; then
  launch_internal_command \
    '08-qa-fixture-prologue' 'fixture' 'fixture_ready' 'prologue' 'high'
  qa_fixture_result="passed"
  launch_internal_command \
    '09-qa-pitch-high' 'pitch-sample' 'pitch_presentation_completed' 'prologue' 'high'
  qa_pitch_high_result="passed"
  launch_internal_command \
    '10-qa-pitch-low' 'pitch-sample' 'pitch_presentation_completed' 'prologue' 'low'
  qa_pitch_low_result="passed"
  launch_internal_command \
    '11-qa-nonfatal' 'nonfatal' 'nonfatal_invoked' 'prologue' 'high'
  qa_nonfatal_result="passed"
  launch_internal_command \
    '12-qa-save-corruption' 'save-corruption' 'save_corruption_recovered' 'prologue' 'high'
  qa_save_corruption_result="passed"
  launch_internal_command \
    '13-qa-save-fault' 'save-fault' 'save_fault_rollback' 'prologue' 'high'
  qa_save_fault_result="passed"
  launch_internal_command \
    '14-qa-save-failure' 'save-failure' 'save_failure_proxy' 'prologue' 'high'
  qa_save_failure_proxy_result="passed"
  launch_internal_command \
    '15-qa-analytics' 'analytics-fake' 'analytics_fake_logged' 'prologue' 'high'
  qa_analytics_result="passed"
  launch_internal_command \
    '16-qa-tutorial-checkpoint' 'tutorial-checkpoint' 'tutorial_checkpoint_saved' \
    'tutorial_checkpoint' 'high'
  launch_and_capture '17-qa-tutorial-relaunch'
  wait_for_app_marker \
    "$evidence_dir/17-qa-tutorial-relaunch-qa-marker.txt" \
    'BASEBALL_QA_MARKER schema=1 name=tutorial_checkpoint_restored status=passed' ||
    fail '내부 QA tutorial checkpoint가 force-stop/relaunch 뒤 복원되지 않았습니다.'
  capture_foreground '17-qa-tutorial-relaunch-restored'
  qa_tutorial_relaunch_result="passed"

  if [[ "$qa_crash_probe" == "1" ]]; then
    "${adb_command[@]}" logcat -d -v threadtime >"$evidence_dir/18-pre-crash-logcat-all.txt"
    "${adb_command[@]}" logcat -b crash -d -v threadtime >"$evidence_dir/18-pre-crash-buffer.txt"
    if grep -Fqi "$package_id" "$evidence_dir/18-pre-crash-buffer.txt" ||
      grep -Eiq "ANR in ${package_id}|am_crash.*${package_id}|am_anr.*${package_id}" \
        "$evidence_dir/18-pre-crash-logcat-all.txt"; then
      fail '의도적 crash probe 전에 예상 밖 crash 또는 ANR 표식을 발견했습니다.'
    fi
    "${adb_command[@]}" logcat -c
    "${adb_command[@]}" shell am force-stop "$package_id"
    "${adb_command[@]}" shell timeout "$launch_timeout_seconds" am start -W -n "$resolved_activity" \
      --es baseball.qa.command crash \
      --es baseball.qa.seed "$qa_seed" \
      --es baseball.qa.phase prologue \
      --es baseball.qa.quality high \
      >"$evidence_dir/18-qa-crash-start.txt" 2>&1 ||
      fail '내부 QA crash probe 시작 명령이 실패했습니다.'
    wait_for_global_marker \
      "$evidence_dir/18-qa-crash-first-interactive.txt" \
      'BASEBALL_FIRST_INTERACTIVE schema=1 status=passed' ||
      fail 'crash probe 전에 first-interactive 마커가 나타나지 않았습니다.'
    wait_for_global_marker \
      "$evidence_dir/18-qa-crash-marker-logcat.txt" \
      'BASEBALL_QA_MARKER schema=1 name=crash_requested status=passed' ||
      fail '내부 QA crash 요청 마커가 나타나지 않았습니다.'
    crash_deadline=$((SECONDS + launch_timeout_seconds))
    while [[ "$SECONDS" -lt "$crash_deadline" ]] &&
      [[ -n "$("${adb_command[@]}" shell pidof "$package_id" 2>/dev/null | tr -d '\r')" ]]; do
      sleep 0.25
    done
    [[ -z "$("${adb_command[@]}" shell pidof "$package_id" 2>/dev/null | tr -d '\r')" ]] ||
      fail '내부 QA crash probe가 process를 종료하지 않았습니다.'
    "${adb_command[@]}" logcat -b crash -d -v threadtime >"$evidence_dir/18-qa-crash-buffer.txt"
    grep -Fqi "$package_id" "$evidence_dir/18-qa-crash-buffer.txt" ||
      fail '내부 QA crash buffer에서 package 증거를 찾지 못했습니다.'
    qa_crash_result="passed"
    "${adb_command[@]}" logcat -c
    launch_and_capture '19-qa-post-crash-relaunch'
  fi
fi

final_pid="$("${adb_command[@]}" shell pidof "$package_id" | tr -d '\r')"
[[ -n "$final_pid" ]] || fail '최종 재실행 뒤 앱 process가 유지되지 않았습니다.'
"${adb_command[@]}" logcat -d -v threadtime >"$evidence_dir/logcat-all.txt"
"${adb_command[@]}" logcat -b crash -d -v threadtime >"$evidence_dir/logcat-crash.txt"
"${adb_command[@]}" logcat -d -v threadtime --pid="$final_pid" >"$evidence_dir/logcat-app-final.txt"
"${adb_command[@]}" shell dumpsys activity exit-info "$package_id" >"$evidence_dir/app-exit-info.txt" 2>&1 || true
"${adb_command[@]}" shell df -k /data >"$evidence_dir/storage-data-df.txt" 2>&1 ||
  fail '기기 /data 저장공간 증거를 읽지 못했습니다.'
"${adb_command[@]}" shell dumpsys diskstats >"$evidence_dir/storage-diskstats.txt" 2>&1 ||
  fail '기기 diskstats 증거를 읽지 못했습니다.'
{
  printf 'android_api=%s\n' "$sdk_level"
  printf 'native_page_size=%s\n' "$device_page_size"
  printf 'manufacturer=%s\n' "$("${adb_command[@]}" shell getprop ro.product.manufacturer | tr -d '\r')"
  printf 'model=%s\n' "$("${adb_command[@]}" shell getprop ro.product.model | tr -d '\r')"
  printf 'abi=%s\n' "$("${adb_command[@]}" shell getprop ro.product.cpu.abi | tr -d '\r')"
  "${adb_command[@]}" shell wm size | tr -d '\r'
  "${adb_command[@]}" shell wm density | tr -d '\r'
  "${adb_command[@]}" shell dumpsys package "$package_id" | sed -n -E '/version(Name|Code)=/p' | tr -d '\r'
} >"$evidence_dir/device-metadata.txt"

if grep -Fqi "$package_id" "$evidence_dir/logcat-crash.txt" ||
  grep -Eiq "ANR in ${package_id}|am_crash.*${package_id}|am_anr.*${package_id}" "$evidence_dir/logcat-all.txt"; then
  fail 'logcat에서 crash 또는 ANR 표식을 발견했습니다.'
fi

if grep -Eiq '([[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,})|Bearer[[:space:]]+[[:alnum:]_.-]{12,}|(access|refresh)[_-]?token[[:space:]]*[:=]|advertis(ing|ement)[ _-]?id[[:space:]]*[:=]|phone(number)?[[:space:]_-]*[:=]' \
  "$evidence_dir"/*-app-logcat.txt; then
  fail '앱 logcat에서 이메일·인증 토큰·광고 식별자·전화번호로 보이는 PII 표식을 발견했습니다.'
fi

# Package-scoped runtime bridge failures can leave an interactive shell with broken product
# visuals or telemetry. Expected offline transport retries are deliberately not matched here.
if grep -Eiq 'pitch.stage_shader_unavailable|Shader.*(not found|unsupported|is not supported)|Hidden/InternalErrorShader|pink[[:space:]_-]*material|StrictMode|Default FirebaseApp failed to initialize|FirebaseApp initialization unsuccessful|Failed to read Firebase options|Firebase.*(initialization failed|dependency[^[:cntrl:]]*failed|not initialized|No Firebase App|bridge[^[:cntrl:]]*failed)|Amplitude.*(initialization failed|not initialized|bridge[^[:cntrl:]]*failed|API key[^[:cntrl:]]*missing)' \
  "$evidence_dir"/*-app-logcat.txt "$evidence_dir/logcat-app-final.txt"; then
  fail '앱 logcat에서 셰이더·StrictMode·Firebase/Amplitude 초기화 또는 브릿지 오류를 발견했습니다.'
fi

printf '%s\n' \
  "schema=baseball.android-unity-smoke.v1" \
  "package=$package_id" \
  "smoke_mode=$smoke_mode" \
  "aab_debuggable=$apk_debuggable" \
  "android_api=$sdk_level" \
  "native_page_size=$device_page_size" \
  "native_16k_execution=$native_16k_execution" \
  "production_pitch_on_16k=$production_pitch_16k_result" \
  "rc_build_evidence=$rc_build_evidence_result" \
  "aab_16k_alignment=passed" \
  "apk_16k_zipalign=passed" \
  "arm64_elf_alignment=passed" \
  "clean_install=passed" \
  "cold_start=passed" \
  "first_interactive=passed" \
  "background_resume_same_process=passed" \
  "portrait=passed" \
  "landscape_request_blocked=passed" \
  "offline_relaunch=passed" \
  "notification_denial=$notification_denial_result" \
  "font_200_percent_launch=passed" \
  "low_memory_callback=passed" \
  "low_storage_real=not_tested" \
  "qa_fixture=$qa_fixture_result" \
  "qa_pitch_high=$qa_pitch_high_result" \
  "qa_pitch_low=$qa_pitch_low_result" \
  "qa_nonfatal=$qa_nonfatal_result" \
  "qa_save_corruption=$qa_save_corruption_result" \
  "qa_save_fault=$qa_save_fault_result" \
  "qa_save_failure_proxy=$qa_save_failure_proxy_result" \
  "qa_analytics_fake=$qa_analytics_result" \
  "qa_tutorial_checkpoint_relaunch=$qa_tutorial_relaunch_result" \
  "qa_crash_probe=$qa_crash_result" \
  "foreground_resumed=passed" \
  "crash_anr_scan=passed" \
  "pii_scan=passed" \
  "runtime_bridge_scan=passed" >"$evidence_dir/result.txt"

printf 'Android Unity smoke 통과. 증거 경로: %s\n' "$evidence_dir"
