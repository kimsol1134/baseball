#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB_BIN="${ANDROID_ADB_BIN:-${ANDROID_SDK_ROOT:-/Users/solkim/Library/Android/sdk}/platform-tools/adb}"
APK="$REPO_ROOT/apps/android/app/build/outputs/apk/debug/app-debug.apk"
PACKAGE="com.solkim.baseball.android.compose.dev"

if [[ ! -x "$ADB_BIN" ]]; then
  echo "adb not found: $ADB_BIN" >&2
  exit 2
fi
if [[ ! -f "$APK" ]]; then
  echo "APK not found: $APK" >&2
  exit 2
fi

"$ADB_BIN" install -r "$APK"
"$ADB_BIN" shell am force-stop "$PACKAGE"
"$ADB_BIN" shell am start -n "$PACKAGE/com.solkim.baseball.android.MainActivity"
sleep "${ANDROID_COMPOSE_SMOKE_SETTLE_SECONDS:-3}"

echo "Tap the Compose pitch entry point and wait for the terminal status; this helper only captures the real view tree."
"$ADB_BIN" shell uiautomator dump /sdcard/android-compose-window.xml >/dev/null
"$ADB_BIN" shell cat /sdcard/android-compose-window.xml
