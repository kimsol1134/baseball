#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${ANDROID_COMPOSE_SKIP_UNITY_EXPORT:-0}" != "1" ]]; then
  "$REPO_ROOT/tools/export-android-pitch-unity.sh"
fi

cd "$REPO_ROOT/apps/android"
./gradlew :app:assembleDebug --no-daemon --stacktrace

APK="$REPO_ROOT/apps/android/app/build/outputs/apk/debug/app-debug.apk"
if [[ ! -f "$APK" ]]; then
  echo "Compose APK was not produced: $APK" >&2
  exit 1
fi

APKSIGNER_BIN="$(command -v apksigner || true)"
if [[ -z "$APKSIGNER_BIN" ]]; then
  SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/Users/solkim/Library/Android/sdk}}"
  APKSIGNER_BIN="$(find "$SDK_ROOT/build-tools" -type f -name apksigner -perm -111 2>/dev/null | sort | tail -n 1 || true)"
fi

if [[ -n "$APKSIGNER_BIN" ]]; then
  "$APKSIGNER_BIN" verify --verbose "$APK"
else
  echo "apksigner not found; APK verification was not run" >&2
fi

shasum -a 256 "$APK"
