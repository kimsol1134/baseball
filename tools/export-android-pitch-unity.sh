#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNITY_PROJECT="$REPO_ROOT/apps/android-pitch-unity"
OUTPUT_DIR="${PITCH_UNITY_EXPORT_PATH:-$REPO_ROOT/artifacts/android-compose/unity-export/current}"
UNITY_BIN="${BASEBALL_UNITY_BIN:-/Applications/Unity/Hub/Editor/6000.3.19f1/Unity.app/Contents/MacOS/Unity}"
LOG_FILE="${PITCH_UNITY_EXPORT_LOG:-$REPO_ROOT/artifacts/android-compose/unity-export/export.log}"

if [[ ! -x "$UNITY_BIN" ]]; then
  echo "Unity 6000.3.19f1 editor not found: $UNITY_BIN" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUTPUT_DIR")" "$(dirname "$LOG_FILE")"
if [[ -e "$OUTPUT_DIR" ]]; then
  rm -rf "$OUTPUT_DIR"
fi

echo "Exporting pitch-only Unity library to $OUTPUT_DIR"
PITCH_UNITY_EXPORT_PATH="$OUTPUT_DIR" "$UNITY_BIN" \
  -batchmode \
  -nographics \
  -quit \
  -projectPath "$UNITY_PROJECT" \
  -executeMethod BaseballPitch.Editor.ExportPitchLibrary.ExportAndroidLibrary \
  -logFile "$LOG_FILE"

if [[ ! -d "$OUTPUT_DIR/unityLibrary" ]]; then
  echo "Unity completed without unityLibrary; see $LOG_FILE" >&2
  exit 1
fi

node "$REPO_ROOT/tools/normalize-android-pitch-unity-export.mjs" "$OUTPUT_DIR"

echo "Unity export ready: $OUTPUT_DIR/unityLibrary"
