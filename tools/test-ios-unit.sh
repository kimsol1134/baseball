#!/bin/bash
# Run the iOS unit suite only when the shared simulator and memory budget are available.
set -euo pipefail
baseball_repo_root="$(cd "$(dirname "$0")/.." && pwd)"
baseball_destination="platform=iOS Simulator,name=iPhone 17"
if [[ -n "${BASEBALL_SIMULATOR_ID:-}" ]]; then
  baseball_destination="platform=iOS Simulator,id=$BASEBALL_SIMULATOR_ID"
fi
baseball_derived="${BASEBALL_DERIVED_DATA:-}"
baseball_lock="${TMPDIR:-/tmp}/baseball-ios-unit-tests.lock"
if ! mkdir "$baseball_lock" 2>/dev/null; then
  echo "Another iOS unit run holds $baseball_lock. Wait for it to finish." >&2
  exit 2
fi
trap 'rmdir "$baseball_lock"' EXIT
python3 - <<'PY'
import pathlib, subprocess, sys
busy = []
for line in subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines():
    fields = line.strip().split(None, 1)
    if len(fields) != 2:
        continue
    name = pathlib.Path(fields[1]).name
    if name in ('Unity', 'xcodebuild') or name.startswith('qemu-system-'):
        busy.append(f'{fields[0]} {name}')
if busy:
    print('Unit tests were NOT started. Close Unity/Android emulators and wait for the existing Xcode job:', file=sys.stderr)
    print('\n'.join(busy), file=sys.stderr)
    sys.exit(2)
PY
cd "$baseball_repo_root"
# Without an override Xcode reuses this project's existing default DerivedData directory.
if [[ -n "$baseball_derived" ]]; then
  set -- -derivedDataPath "$baseball_derived" "$@"
fi
xcodebuild test -project apps/ios/Baseball.xcodeproj -scheme BaseballIOS \
  -destination "$baseball_destination" \
  -parallel-testing-enabled NO \
  -only-testing:BaseballIOSTests "$@"
