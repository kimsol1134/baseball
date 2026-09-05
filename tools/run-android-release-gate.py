#!/usr/bin/env python3
"""Reproducible release gate. Never uploads, changes user saves, or equates debug with release."""
from pathlib import Path
import argparse
import fcntl
import hashlib
import json
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "artifacts/android-compose/release-gate"
OUT.mkdir(parents=True, exist_ok=True)
lock = (OUT / '.runner.lock').open('w')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit('Another release gate is already running')
parser = argparse.ArgumentParser()
parser.add_argument('--compare-only', action='store_true')
args = parser.parse_args()

def digest_sources(label):
    paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '--',
        'apps/android', 'packages/simulation-core', 'tools', 'docs/android-compose/RELEASE_PRODUCT_CONTRACT.md'], cwd=ROOT, text=True).splitlines()
    manifest = {}
    digest = hashlib.sha256()
    for relative in sorted(set(paths)):
        path = ROOT / relative
        if path.is_file() and not any(part in {"build", ".build", ".gradle", ".kotlin", "__pycache__"} for part in path.parts):
            content = path.read_bytes()
            manifest[relative] = hashlib.sha256(content).hexdigest()
            digest.update(relative.encode() + b'\0')
            digest.update(content)
    (OUT / f"sources-{label}.json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
    return digest.hexdigest(), manifest

before, before_files = digest_sources("before")
commands = [
    ('swift-career-training', ['swift', 'run', '--package-path', 'packages/simulation-core', 'release-parity-exporter']),
    ('swift-high-school', ['swift', 'run', '--package-path', 'packages/simulation-core', 'high-school-phase4-fixture-exporter']),
    ('source-boundary', ['node', 'tools/check-android-compose.mjs']),
    ('localization', ['node', 'tools/import-android-localization.mjs', '--check']),
    ('visible-copy', ['python3', 'tools/inventory-android-localization.py', '--check']),
]
gradle = ['./apps/android/gradlew', '-p', 'apps/android', ':game-core:test']
if args.compare_only:
    gradle += ['--tests', '*Release*ParityTest', '--tests', '*HighSchoolPhase4FixtureTest']
else:
    gradle += [':game-application:test', ':game-persistence:test', ':app:testDebugUnitTest', ':app:lintDebug', ':app:compileReleaseKotlin', ':app:lintRelease', ':app:assembleDebug', ':app:assembleDebugAndroidTest',
               '-PbaseballLaunchQa=true', '-PbaseballQaNativeStore=true', '-Pphase11Distribution=production']
commands += [('verification', gradle + ['--offline', '--console=plain'])]
checks = []
for name, command in commands:
    print('Running:', name, flush=True)
    with (OUT / f'{name}.log').open('w') as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    checks.append({'name': name, 'passed': result.returncode == 0, 'log': f'{name}.log'})
    if result.returncode:
        print(f'Failed: {name}; see {OUT / (name + ".log")}', flush=True)
        break
after, after_files = digest_sources("after")
tests = []
for module in ['game-core', 'game-application', 'game-persistence', 'app']:
    for path in (ROOT / 'apps/android' / module / 'build/test-results').glob('*/TEST-*.xml'):
        suite = ET.parse(path).getroot()
        tests.append({'module': module, 'suite': suite.attrib['name'], **{key: int(suite.attrib.get(key, 0)) for key in ['tests', 'failures', 'errors', 'skipped']}})
signing_keys = ['BASEBALL_UPLOAD_KEYSTORE_PATH', 'BASEBALL_UPLOAD_KEYSTORE_PASSWORD', 'BASEBALL_UPLOAD_KEY_ALIAS', 'BASEBALL_UPLOAD_KEY_PASSWORD']
fixture_path = OUT / 'swift-release-parity.json'
fixture = json.loads(fixture_path.read_text()) if fixture_path.exists() else {}
passed = len(checks) == len(commands) and all(c['passed'] for c in checks)
report = {
    'schema': 'baseball-release-gate-v1', 'sourceBefore': before, 'sourceAfter': after, 'sourceStable': before == after,
    'changedSources': [path for path in sorted(before_files.keys() | after_files.keys()) if before_files.get(path) != after_files.get(path)],
    'scope': 'comparison-only' if args.compare_only else 'QA debug with native persistence',
    'automatedChecksPassed': passed and before == after,
    'releaseReady': False,
    'checks': checks, 'tests': tests,
    'coverage': {'swiftProTransitions': sum(len(fixture.get(key, [])) for key in ['pro', 'proFa', 'proLinked']), 'highSchoolTransitions': len(fixture.get('highSchool', [])), 'proPolicies': ['renewal', 'free-agency', 'earned-high-school-draft-to-pro'], 'trainingCombinations': len(fixture.get('training', [])),
                 'terminalNormalization': 'retired = iOS completed or Android post-retirement legacy-selection/completed with HOF score; Android raw phase retained',
                 'fixedGameReport': '24 pitches / 4 strikeouts / 0 walks / 0 runs / 3 outs / entry differential +2 / entry outs 1; no absolute team score'},
    'signingConfigurationPresent': all(os.environ.get(key) for key in signing_keys),
    'unverified': ['signed production candidate', 'same signed candidate on devices', 'user-owned playtest'],
}
apk = ROOT / 'apps/android/app/build/outputs/apk/debug/app-debug.apk'
if passed and not args.compare_only and apk.exists():
    report['qaApkSha256'] = hashlib.sha256(apk.read_bytes()).hexdigest()
(OUT / 'gate.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print('Gate:', OUT / 'gate.json')
print('Automated checks:', 'PASS' if report['automatedChecksPassed'] else 'BLOCKED')
print('Production release: UNVERIFIED (this tool does not sign or publish)')
sys.exit(0 if report['automatedChecksPassed'] else 1)
