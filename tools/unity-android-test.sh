#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_path="$repo_root/apps/android-unity"
artifact_root="$repo_root/artifacts/unity"
unity_bin="${BASEBALL_UNITY_BIN:-/Applications/Unity/Hub/Editor/6000.3.19f1/Unity.app/Contents/MacOS/Unity}"

if [[ ! -x "$unity_bin" ]]; then
  echo "Unity executable not found: $unity_bin" >&2
  exit 2
fi

mkdir -p "$artifact_root"

validate_results() {
  local platform="$1"
  local result_file="$2"
  local log_file="$3"
  local failed=0

  if [[ ! -s "$result_file" ]]; then
    echo "$platform test result XML is missing or empty: $result_file" >&2
    failed=1
  elif ! PLATFORM="$platform" RESULT_FILE="$result_file" node <<'NODE'
const fs = require("node:fs");
const platform = process.env.PLATFORM;
const path = process.env.RESULT_FILE;
const xml = fs.readFileSync(path, "utf8");
const root = xml.match(/<test-run\b([^>]*)>/);
if (!root || !/<\/test-run>\s*$/.test(xml)) {
  console.error(`${platform} test result is not a complete NUnit test-run document: ${path}`);
  process.exit(1);
}
const attributes = Object.fromEntries(
  [...root[1].matchAll(/([\w-]+)\s*=\s*["']([^"']*)["']/g)].map(match => [match[1], match[2]])
);
const total = Number(attributes.total ?? attributes.testcasecount);
const failures = Number(attributes.failed);
const result = attributes.result;
if (!Number.isInteger(total) || total <= 0) {
  console.error(`${platform} test result did not execute any tests (total=${attributes.total ?? attributes.testcasecount ?? "missing"}).`);
  process.exit(1);
}
if (!Number.isInteger(failures) || failures !== 0 || result !== "Passed") {
  console.error(`${platform} test result is not passing (result=${result ?? "missing"}, failed=${attributes.failed ?? "missing"}, total=${total}).`);
  process.exit(1);
}
console.log(`${platform} NUnit evidence passed: total=${total}, failed=${failures}`);
NODE
  then
    failed=1
  fi

  if [[ ! -s "$log_file" ]]; then
    echo "$platform Unity log is missing or empty: $log_file" >&2
    failed=1
  elif grep -Eiq \
    'No valid Unity Editor license|LICENSE SYSTEM.*(fail|error)|error CS[0-9]{4}:|Scripts have compiler errors|Compilation failed|Aborting batchmode due to failure|Fatal Error|test run failed' \
    "$log_file"; then
    echo "$platform Unity log contains a license, compile, fatal, or test-run failure: $log_file" >&2
    grep -Ein \
      'No valid Unity Editor license|LICENSE SYSTEM.*(fail|error)|error CS[0-9]{4}:|Scripts have compiler errors|Compilation failed|Aborting batchmode due to failure|Fatal Error|test run failed' \
      "$log_file" | tail -n 20 >&2 || true
    failed=1
  fi

  [[ "$failed" -eq 0 ]]
}

run_tests() {
  local platform="$1"
  local label
  local result_file
  local log_file
  local unity_status
  label="$(printf '%s' "$platform" | tr '[:upper:]' '[:lower:]')"
  result_file="$artifact_root/${label}.xml"
  log_file="$artifact_root/${label}.log"
  rm -f "$result_file" "$log_file"

  set +e
  "$unity_bin" \
    -batchmode \
    -nographics \
    -quit \
    -buildTarget Android \
    -projectPath "$project_path" \
    -runTests \
    -testPlatform "$platform" \
    -testResults "$result_file" \
    -logFile "$log_file"
  unity_status=$?
  set -e

  if [[ "$unity_status" -ne 0 ]]; then
    echo "$platform Unity process failed with exit code $unity_status." >&2
  fi

  if ! validate_results "$platform" "$result_file" "$log_file"; then
    return 1
  fi
  [[ "$unity_status" -eq 0 ]]
}

overall_status=0
run_tests EditMode || overall_status=1
run_tests PlayMode || overall_status=1
exit "$overall_status"
