#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_path="$repo_root/apps/android-unity"
artifact_root="$repo_root/artifacts/unity"
unity_bin="${BASEBALL_UNITY_BIN:-/Applications/Unity/Hub/Editor/6000.3.19f1/Unity.app/Contents/MacOS/Unity}"
test_process_timeout_seconds="${BASEBALL_UNITY_TEST_PROCESS_TIMEOUT_SECONDS:-600}"
completed_shutdown_grace_seconds="${BASEBALL_UNITY_COMPLETED_SHUTDOWN_GRACE_SECONDS:-20}"

if [[ ! -x "$unity_bin" ]]; then
  echo "Unity executable not found: $unity_bin" >&2
  exit 2
fi
[[ "$test_process_timeout_seconds" =~ ^[1-9][0-9]*$ ]] || {
  echo "BASEBALL_UNITY_TEST_PROCESS_TIMEOUT_SECONDS must be a positive integer." >&2
  exit 2
}
[[ "$completed_shutdown_grace_seconds" =~ ^[1-9][0-9]*$ ]] || {
  echo "BASEBALL_UNITY_COMPLETED_SHUTDOWN_GRACE_SECONDS must be a positive integer." >&2
  exit 2
}

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
    'No valid Unity Editor license|LICENSE SYSTEM.*(fail|error)|error CS[0-9]{4}:|Scripts have compiler errors|Compilation failed|Aborting batchmode due to failure|Fatal Error|test run failed|Generation of the Firebase Android resource file .* failed' \
    "$log_file"; then
    echo "$platform Unity log contains a license, compile, fatal, or test-run failure: $log_file" >&2
    grep -Ein \
      'No valid Unity Editor license|LICENSE SYSTEM.*(fail|error)|error CS[0-9]{4}:|Scripts have compiler errors|Compilation failed|Aborting batchmode due to failure|Fatal Error|test run failed|Generation of the Firebase Android resource file .* failed' \
      "$log_file" | tail -n 20 >&2 || true
    failed=1
  fi

  [[ "$failed" -eq 0 ]]
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]_.' '[:lower:]--'
}

run_tests() {
  local platform="$1"
  local evidence_name="$2"
  local assembly_names="$3"
  local test_filter="${4:-}"
  local result_file="$artifact_root/${evidence_name}.xml"
  local log_file="$artifact_root/${evidence_name}.log"
  local -a command
  local unity_status
  local unity_pid
  local elapsed=0
  local completed_shutdown_elapsed=0
  local completed_shutdown_forced=0
  local process_timed_out=0
  rm -f "$result_file" "$log_file"

  command=(
    "$unity_bin"
    -batchmode
    -nographics
    -buildTarget Android
    -projectPath "$project_path"
    -runTests
    -testPlatform "$platform"
    -assemblyNames "$assembly_names"
  )
  if [[ -n "$test_filter" ]]; then
    command+=(-testFilter "$test_filter")
  fi
  command+=(-testResults "$result_file" -logFile "$log_file")

  "${command[@]}" &
  unity_pid=$!
  while kill -0 "$unity_pid" 2>/dev/null; do
    if [[ -s "$result_file" && -s "$log_file" ]] &&
      grep -Fq 'Test run completed. Exiting with code 0 (Ok). Run completed.' "$log_file"; then
      completed_shutdown_elapsed=$((completed_shutdown_elapsed + 1))
      if (( completed_shutdown_elapsed >= completed_shutdown_grace_seconds )); then
        echo "$platform/$evidence_name produced complete passing evidence but Unity did not exit; terminating the completed Editor after ${completed_shutdown_grace_seconds}s." >&2
        kill -TERM "$unity_pid" 2>/dev/null || true
        completed_shutdown_forced=1
        break
      fi
    else
      completed_shutdown_elapsed=0
    fi

    if (( elapsed >= test_process_timeout_seconds )); then
      echo "$platform/$evidence_name Unity process exceeded ${test_process_timeout_seconds}s before completing evidence." >&2
      kill -TERM "$unity_pid" 2>/dev/null || true
      process_timed_out=1
      break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  if (( completed_shutdown_forced == 1 || process_timed_out == 1 )); then
    local terminate_elapsed=0
    while kill -0 "$unity_pid" 2>/dev/null && (( terminate_elapsed < 10 )); do
      sleep 1
      terminate_elapsed=$((terminate_elapsed + 1))
    done
    if kill -0 "$unity_pid" 2>/dev/null; then
      kill -KILL "$unity_pid" 2>/dev/null || true
    fi
  fi

  set +e
  wait "$unity_pid"
  unity_status=$?
  set -e
  if (( completed_shutdown_forced == 1 )); then
    unity_status=0
  elif (( process_timed_out == 1 )); then
    unity_status=124
  fi

  if [[ "$unity_status" -ne 0 ]]; then
    echo "$platform/$evidence_name Unity process failed with exit code $unity_status." >&2
  fi

  if ! validate_results "$platform/$evidence_name" "$result_file" "$log_file"; then
    return 1
  fi
  [[ "$unity_status" -eq 0 ]]
}

overall_status=0
editmode_assemblies=(
  Baseball.Core.Tests
  Baseball.Application.Tests
  Baseball.Platform.Tests
  Baseball.Presentation.Tests
  Baseball.HighSchool.Tests
  Baseball.Pro.Tests
  Baseball.InternalQa.Tests
)
for assembly_name in "${editmode_assemblies[@]}"; do
  evidence_name="editmode-$(slugify "$assembly_name")"
  run_tests EditMode "$evidence_name" "$assembly_name" || overall_status=1
done

# Bootstrap owns serialized async lifecycle and reset recovery boundaries. Isolate
# these Task tests for the same Unity 1.6 batch-runner limitation as persistence.
bootstrap_tests=(
  Initialize_OpensOnceAndPublishesReadyOnConfiguredMainThread
  AtomicFactory_ResolvesInstallIdentityInsideEverySerializedRetry
  Lifecycle_DeduplicatesPauseResumeAndLowMemory
  FailedLifecycleHook_DoesNotAdvanceStateAndCanBeRetried
  FailedResumeAndLowMemory_RemainRetryableWithoutLosingReadyStore
  FailedInitialization_NotifiesSafelyAndCanBeRetried
  ReadySubscriberFailure_DoesNotBlockOtherSubscribersOrPublication
  Dispose_IsIdempotentClearsReadyAndRejectsFurtherCallbacks
  DisposeFailure_StillClearsAndAttemptsEveryOwnedResource
  AtomicFactory_OpensAggregateAndPersistsFirstCommandBeforePublish
  DurableHooks_PrepareEligiblePlanOnceAndReserveWarmColdAnalyticsAfterSave
  DurableResume_AdoptsExternalHigherRevisionAndPublishesOnMainThread
  DurablePause_ContendedStaleRetryKeepsCommittedPublicationOnMainThread
  PreparedResetFailureSuppressesPauseRewriteAndCandidateRestartsCleanly
)
for test_name in "${bootstrap_tests[@]}"; do
  evidence_name="editmode-bootstrap-$(slugify "$test_name")"
  test_filter="Baseball.Bootstrap.Tests.RuntimeGameCoordinatorTests.$test_name"
  run_tests EditMode "$evidence_name" Baseball.Bootstrap.Tests "$test_filter" || overall_status=1
done

# Unity Test Framework 1.6 can stop advancing after more than one truly asynchronous
# filesystem test in a batch. Keep every persistence test in a fresh Editor process;
# each XML remains complete and non-empty, and every case still runs fail-closed.
persistence_tests=(
  CurrentEmulatorClone_IsReadByTheRealCSharpAggregateReader
  KotlinWrittenFixture_IsReadAndRewrittenByTheRealCSharpReader
  Save_WritesSpecifiedEnvelopeAndRoundTrips
  Checksum_IsIndependentOfObjectPropertyOrder
  Save_RotatesExactlyThreeBackups
  Save_SameRevisionAndPayload_IsIdempotentWithoutBackupRotation
  Save_RejectsRevisionRegression
  Save_RejectsSameRevisionConflict
  Load_CorruptCanonical_RecoversHighestValidBackupAndQuarantinesOnce
  Load_SameRevision_UsesExplicitSemanticPriority
  Load_ChecksumMismatch_FallsBackToBackup
  Load_AllCandidatesCorrupt_MovesThemToQuarantine
  FutureSchema_IsPreservedAndNeverOverwritten
  OlderSchema_IsPreservedAndNeverOverwritten
  Save_FaultBeforeCandidateValidation_PreservesPreviousCanonical
  Save_FaultAfterCandidateValidation_PreservesPreviousCanonical
  Save_FaultAfterTempWrite_PreservesPreviousCanonical
  Save_FaultAfterTempValidation_PreservesPreviousCanonical
  Save_FaultAfterBackupRotation_PreservesPreviousCanonical
  Save_FaultBeforeCanonicalSwap_PreservesPreviousCanonical
  Save_FaultAfterCanonicalSwap_PreservesPreviousCanonical
  Save_FaultBeforeCanonicalVerification_PreservesPreviousCanonical
  Save_FaultAfterCanonicalVerification_PreservesPreviousCanonical
  FirstSave_FaultAfterSwap_LeavesNoFalseCanonical
  InvalidPayload_IsRejectedBeforeAnyFileMutation
  Reset_DeletesCanonicalTempBackupsAndQuarantineWithoutRecovery
  OneHundredSaveReloadCycles_PreserveStateHashInputs
)
for test_name in "${persistence_tests[@]}"; do
  evidence_name="editmode-persistence-$(slugify "$test_name")"
  if [[ "$test_name" == "CurrentEmulatorClone_IsReadByTheRealCSharpAggregateReader" ||
        "$test_name" == "KotlinWrittenFixture_IsReadAndRewrittenByTheRealCSharpReader" ]]; then
    test_filter="Baseball.Persistence.Tests.Phase6KotlinSaveCompatibilityTests.$test_name"
  else
    test_filter="Baseball.Persistence.Tests.AtomicSaveRepositoryTests.$test_name"
  fi
  run_tests EditMode "$evidence_name" Baseball.Persistence.Tests "$test_filter" || overall_status=1
done

run_tests PlayMode playmode Baseball.PlayMode.Tests || overall_status=1
exit "$overall_status"
