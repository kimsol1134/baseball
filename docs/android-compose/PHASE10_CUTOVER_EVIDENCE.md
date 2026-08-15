# Phase 10 package cutover rehearsal evidence

Execution scope: 2026-08-14 Phase 10 only. The complete evidence bundle is
[artifacts/android-compose/phase10-evidence-2026-08-14](../../artifacts/android-compose/phase10-evidence-2026-08-14).

## Verdict and boundary

VERIFIED for the local internal package rehearsal on the dedicated API 35/16 KiB emulator:

- Unity v32 → Compose native-authoritative v33 → Unity rollback v34 → Compose v35 → final
  Compose v36 all used package com.solkim.baseball.android and the same certificate SHA-256
  52f8d209468e18a160ffbb550f7160929a7117fe58e6e3f1292cf22ec21e7135.
- Every update used adb -s emulator-5554 install -r; no uninstall and no pm clear were used
  for the production package. firstInstallTime stayed 2026-08-13 19:57:32 through v36.
- The v36 final state is Compose MainActivity with the production save directory present and
  the emulator left running it. The final capture is
  [compose-v36/final-after-connected](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/final-after-connected).

This is not a Play, physical-device, or production-RC claim. The available v5 upload artifact is
signed by certificate SHA-256
D0A8EC4FDCEC6F7F74BBEBCE747CB3D2FA308DB72CCA106D30AA2A782DAA445F, but its private signing
key was not available to this run. The release build therefore used the existing authorized local
debug signing identity for the internal rehearsal; the upload-key boundary is recorded in
[signing-v5-upload-cert.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/signing-v5-upload-cert.txt).
No Play upload or Phase 11 work was started.

The native-authoritative adapter deliberately permits only the exercised legacy UpdateSettings
write and fails closed for unported legacy commands. This evidence proves the package/save
contract and rollback boundary; it must not be read as a claim that the complete product command
reducer has already replaced the Unity shell.

## Device, package, and save contract

| Item | Verified value | Evidence |
|---|---|---|
| Device | emulator-5554, API 35, 16384, arm64-v8a | [compose-v36/final-after-connected](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/final-after-connected) |
| Production package | com.solkim.baseball.android | [compose-v36/manifest.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/manifest.txt) |
| Production version | versionCode=36, versionName=1.0.0 | [compose-v36/post/package.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/post/package.txt) |
| Production save path | getExternalFilesDir(null)/save, observed as /sdcard/Android/data/com.solkim.baseball.android/files/save | [compose-v36/post/save-directory.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/post/save-directory.txt) |
| Backup policy | allowBackup=false; canonical plus three backups | [compose-v36/manifest.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/manifest.txt), [compose-v36/post/save-hashes.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/post/save-hashes.txt) |
| Unity boundary | pitch runtime only; no shell/store/save codec/analytics SDK symbols in the pitch export source | [gates/pitch-only-boundary.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/pitch-only-boundary.txt) |

The implementation points are [BaseballApplication.kt](../../apps/android/app/src/main/java/com/solkim/baseball/android/BaseballApplication.kt),
[CSharpLegacyGameStoreRepository.kt](../../apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/CSharpLegacyGameStoreRepository.kt),
[AtomicJsonRepository.kt](../../apps/android/game-persistence/src/main/kotlin/com/solkim/baseball/persistence/AtomicJsonRepository.kt),
[GameStore.kt](../../apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/GameStore.kt), and
[app/build.gradle.kts](../../apps/android/app/build.gradle.kts). Debug remains
nativeShadowReadOnly in the separate .compose.dev package; its write rejection is covered by
the Phase 6 JVM contract suite.

## Unity baseline

The signed/internal Unity baseline was built as production package com.solkim.baseball.android,
code 32, with deterministic QA seed 20260814. Its AAB SHA-256 is recorded in
[baseline-unity-v32/aab-sha256.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/baseline-unity-v32/aab-sha256.txt),
its certificate in [baseline-unity-v32/cert.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/baseline-unity-v32/cert.txt),
and its Unity build manifest in
[artifacts/android/1.0.0-32/build-manifest.json](../../artifacts/android/1.0.0-32/build-manifest.json).

Representative deterministic saves were captured without changing the opening state:

| Phase | Result | Canonical save SHA-256 |
|---|---|---|
| opening | NO_CANONICAL_SAVE | none |
| setup | revision 1 | c64128f8a09834b9a290ca3d8ca716ff28a7f89ae4cc62b2a3f01728292fb8dc |
| prologue | revision 2 | 7871a6260dae45a509ca7bfa4b1f3f7bea505bc845794db1c4a54d225fa0ee99 |
| school selection | revision 3 | d51c5c664ef694bdbc206706f0512d0c6478b00f021045f81956404825310658 |
| training | revision 5 | b6f39f0e19cd825cf3bad3aa176e84802d57232604277623254734b05aab8d73 |
| relationship | revision 6 | 090aef91fcbbdded5b9a621e2225e2153b7d89cf3a8077b0674c509b5c95c908 |

The relationship baseline marker proves aggregate version 4, high-school state present, pro,
pitchResume, and pendingPitchCompletion null, default settings, six command receipts, zero
analytics receipts, and core commitment SHA-256
8e8ba7ca17b856807b34879c434debf3af59d5b14a1530c0b4b4721c8f3ec48f:
[baseline-unity-v32/save-inspect.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/baseline-unity-v32/save-inspect.log).
The anonymous install identity baseline is stored only as a SHA-256 in
[baseline-unity-v32/install-id-sha256.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/baseline-unity-v32/install-id-sha256.txt).

## Compose update and atomic Kotlin command

Compose v33 was update-installed over Unity v32. The five representative fixture opens all
returned unchanged=true fatal=false with exact expected/observed hashes:
[compose-v33/opens/summary.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v33/opens/summary.txt).
The fixture copy into the canonical path was QA setup for each isolated open; it was not reported
as an app write.

The real Kotlin UI settings command changed only the legacy-compatible settings payload:

- revision and envelope revision: 6 → 7;
- command receipts: 6 → 7;
- autoReleaseEnabled: false → true; all other settings stayed unchanged;
- install identity hash, stage, nullable paths, analytics receipt count, and core commitment stayed
  unchanged;
- canonical post-write SHA-256:
  9412dcba5b1c31ea8e2b78b5859c8204ee972b49b425751acb9ad5e10fd64f6d;
- save.bak.1 equals the pre-command canonical SHA-256, and no temporary candidate remained.

The complete semantic diff, raw pre/post JSON, backup hashes, UI XML, and screenshot are in
[compose-v33/native-command](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v33/native-command).
This passed through AtomicJsonRepository and its read-back path; the focused Kotlin test is
[Phase10CSharpLegacyGameStoreRepositoryTest.kt](../../apps/android/game-application/src/test/kotlin/com/solkim/baseball/application/Phase10CSharpLegacyGameStoreRepositoryTest.kt).

## Rollback verification and failure matrix

Unity v34 was update-installed over Compose v33 with the same package and certificate. Its C#
save-inspect marker semantically read the Kotlin-written save as revision 7, aggregate version 4,
high-school present, pro/pitch-resume/pending-completion null, autoReleaseEnabled=1, seven
command receipts, zero analytics receipts, and the unchanged core commitment:
[rollback-unity-v34/save-inspect.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/rollback-unity-v34/save-inspect.log).

The rollback Unity QA hooks also ran on emulator-5554:

- corrupt canonical → backup recovery and quarantine:
  [save-corruption.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/rollback-unity-v34/save-corruption.log);
- canonical-swap fault → rollback/no-publish:
  [save-fault.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/rollback-unity-v34/save-fault.log);
- simulated ENOSPC → io_failed and no published candidate:
  [save-failure.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/rollback-unity-v34/save-failure.log).

The JVM contract run additionally covered every save fault point, reset retry, reset process-death
journal boundary, corrupt-canonical quarantine, backup recovery, install-ID mismatch fail-closed,
unknown/future fields, and no-publish behavior:
[persistence-contract-tests.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/persistence-contract-tests.log).

Compose v35 and then v36 were update-installed back over the rollback build. v36 preserved the
rollback canonical and all three backups byte-for-byte; the v36 before/after package and save
evidence is in [compose-v36](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36).

## Identity, receipts, and notification truth

Because the signed release is non-debuggable, direct run-as access to no_backup is correctly
blocked. The release-gated read-only probe in [MainActivity.kt](../../apps/android/app/src/main/java/com/solkim/baseball/android/MainActivity.kt)
logs only hashes and counts. Its v36 result was:

> installIdSha256=ab2578f46094fa27b92e7a34893fc21cb528d3c82387a3f4da504546257c6173
>
> analyticsOnce=0 analyticsOutbox=0 knownAggregate=1
>
> reviewAttempts=0 scheduledReminders=0 notificationAnalytics=0 notificationNavigation=0
>
> notificationPermissionAsked=false reminderOfferDeclined=false notificationTruth=REQUESTABLE
>
> scopedEpoch=0 shareCacheEpoch=0

The exact log is [compose-v36/platform-inspect.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/platform-inspect.log).
knownAggregate=1 is the native aggregate-baseline marker, not an external SDK delivery receipt.
The raw legacy aggregate retained zero analytics receipts and seven command receipts after the
settings command. OS permission truth is separately recorded as not granted with no production
package notification record in [compose-v35/permission-truth.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v35/permission-truth.txt)
and [compose-v35/notification-package-matches.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v35/notification-package-matches.txt).
No external Firebase/Amplitude receipt is claimed.

## Gates

| Gate | Result | Evidence |
|---|---|---|
| Android JVM/lint/debug APK/debug test APK/debug bundle | pass | [gates/android-full-after-probe.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/android-full-after-probe.log) |
| Connected API 35/16 KiB emulator | 8/8 completed, 1 skipped, 0 failed; release-only Phase 10 instrumentation test skipped in debug | [gates/android-connected-after-probe.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/android-connected-after-probe.log) |
| Swift simulation suite | 383 executed, 1 skipped, 0 failures | [gates/swift-test-phase10.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/swift-test-phase10.log) |
| Cross-runtime fixtures | pass | [gates/android-fixtures-report.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/android-fixtures-report.log) |
| Android Compose/Phase 9 source checks | pass | [gates/android-source-after-probe.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/android-source-after-probe.log) |
| Unity static/reference gates | 447/447; reference compile 0 warnings/0 errors | [gates/unity-static.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/unity-static.log), [gates/unity-references.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/unity-references.log) |
| Full Unity batch | all migration persistence/core/application/platform/high-school/Pro/internal-QA/PlayMode scopes pass; two pre-existing dirty presentation assertions remain 239/241 | [gates/unity-full.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/unity-full.log) |
| Copy/IP, Korean copy, dialogue, assets | pass; 150 Unity assets | [gates/copy-check.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/copy-check.log), [gates/copy-android-unity-check.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/copy-android-unity-check.log), [gates/korean-copy-test.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/korean-copy-test.log), [gates/dialogue-parity-check.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/dialogue-parity-check.log), [gates/unity-assets-check.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/unity-assets-check.log) |
| Unity source-clean gate | pass only with both ignored generated configs isolated; original presence and hashes restored | [gates/android-unity-source-clean.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/android-unity-source-clean.log), [gates/android-unity-source-clean-config-state.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/gates/android-unity-source-clean-config-state.txt) |

The normal Unity release checker still reports its existing injected/omitted google-services.json
contract failure; no generated config was committed. The v36 build refreshed the existing Gradle
dependency lock state with --write-locks after the build reported the missing
kotlin-stdlib-common:2.2.10 lock entry; the successful build log is
[compose-v36-build.log](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36-build.log).

## Final state

The final emulator state is Compose v36, package com.solkim.baseball.android, foreground
MainActivity, API 35/16 KiB/arm64-v8a, with canonical save SHA-256
663d8fe3404f701bef34a8060d121e873cf1807f0e0252e7adf81dd5c520e26c and the rollback-preserved
backup hashes in [compose-v36/post/save-hashes.txt](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/post/save-hashes.txt).
The final foreground screenshot/XML is in
[compose-v36/final-after-connected](../../artifacts/android-compose/phase10-evidence-2026-08-14/compose-v36/final-after-connected).

Phase 10 stops here. Phase 11 CI/RC/Play and Phase 12 legacy removal were not started.
