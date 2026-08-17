#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB_BIN="${ANDROID_ADB_BIN:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb}"

if [[ ! -x "$ADB_BIN" ]]; then
  echo "adb not found: $ADB_BIN" >&2
  exit 2
fi

devices="$("$ADB_BIN" devices | awk 'NR>1 && $2=="device" {print $1}')"
if [[ -z "$devices" ]]; then
  echo "Compose instrumentation was not run: no Android device or emulator is connected." >&2
  exit 2
fi

cd "$REPO_ROOT/apps/android"
./gradlew :app:connectedDebugAndroidTest --no-daemon --stacktrace
