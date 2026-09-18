#!/usr/bin/env bash
# Runs the Compose instrumentation suite the way the tests are written:
#   * the QA application id (`-PbaseballResetQa`) — every class requires a QA package,
#     and the classes that pin an exact id pin the reset one
#   * the release save mode (`-PbaseballQaNativeStore`) — erasing progress and reopening the
#     store are writes that a shadow read-only store refuses
#   * a clean install per group — the tests assert "use a fresh disposable QA install"
# Groups run in order inside one install where a test needs the career the previous one left.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB_BIN="${ANDROID_ADB_BIN:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb}"
PACKAGE="com.solkim.baseball.android.reset.compose.qa"
RUNNER="$PACKAGE.test/androidx.test.runner.AndroidJUnitRunner"

if [[ ! -x "$ADB_BIN" ]]; then
  echo "adb not found: $ADB_BIN" >&2
  exit 2
fi

SERIAL="${ANDROID_SERIAL:-$("$ADB_BIN" devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
if [[ -z "$SERIAL" ]]; then
  echo "Compose instrumentation was not run: no Android device or emulator is connected." >&2
  exit 2
fi
adb_run() { "$ADB_BIN" -s "$SERIAL" "$@"; }

cd "$REPO_ROOT/apps/android"
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest \
  -PbaseballResetQa=true -PbaseballQaNativeStore=true --console=plain
adb_run install -r -t app/build/outputs/apk/debug/app-debug.apk >/dev/null
adb_run install -r -t app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk >/dev/null

# One entry per clean install. A space-separated entry runs its classes in order without erasing
# between them, because the later class needs the career the earlier one created.
# GROUPS is a read-only bash builtin (the caller's group ids); use our own name.
TEST_GROUPS=(
  "AchievementShareUiTest"
  "CareerParityUiTest"
  "ContinuousPitchUiTest"
  "FirstPitchLocalizedSmokeTest ResumePlayerTutorialTest"  # resume needs the career the smoke test leaves
  "PitchSustainedRenderTest"
  "Phase8ProductSemanticsTest"
  "Phase9PlatformSemanticsTest"
  "Phase10NativeAuthoritativeCommandTest"
  "PitchFlightUiTest"
  "PitchGestureUiTest"
  "PitchOutputDeviceTest"
  "PitchPerformanceUiTest"
  "ProgressResetUiTest"
  "ReleaseBackupDeviceTest"
  "SeedChallengeUiTest"
  "SettingsFlowUiTest"
  "SettingsLayoutUiTest"
  "TrainingUiTest"
)

failures=0
for group in "${TEST_GROUPS[@]}"; do
  # adb restarts its daemon now and then; a hiccup here must not abandon the whole suite.
  adb_run shell pm clear "$PACKAGE" >/dev/null 2>&1 || adb_run shell pm clear "$PACKAGE" >/dev/null 2>&1 || true
  for class in $group; do
    output="$(adb_run shell am instrument -w -r -e class "com.solkim.baseball.android.$class" "$RUNNER" 2>&1 || true)"
    verdict="$(printf '%s\n' "$output" | grep -Eo '^(OK \([0-9]+ tests?\)|FAILURES!!!)' | head -1)"
    printf '%-40s %s\n' "$class" "${verdict:-no result}"
    if [[ "$verdict" != OK* ]]; then
      failures=$((failures + 1))
      printf '%s\n' "$output" | grep -A6 '^INSTRUMENTATION_STATUS: stack=' | head -12 | sed 's/^/      /'
    fi
  done
done

if (( failures > 0 )); then
  echo "instrumentation classes failed: $failures" >&2
  exit 1
fi
echo "instrumentation suite passed"
