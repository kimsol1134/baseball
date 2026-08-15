# Phase 9 native platform evidence

Date started: 2026-08-14 (Asia/Seoul); implementation and local gates verified 2026-08-14 KST  
Contract: `docs/ANDROID_COMPOSE_SHELL_UNITY_PITCH_MIGRATION_PLAN_2026-08-13.md`, Phase 9  
Scope: native Android platform services only. Phase 10 is not started.

## Boundary and authority

The Compose product shell remains the only Android launcher and Kotlin `GameStore` remains the
aggregate authority. Production package/save writes remain disabled. The installed development
application continues to use the bounded `.compose.dev` shadow fixture with
`NATIVE_SHADOW_READ_ONLY`; Unity is still loaded only for trajectory presentation. The historical
`apps/android-unity` project is an oracle and is not modified by this phase.

The native platform state has its own install-scoped durable identity and state under Android's
`noBackupFilesDir/phase9` path. The aggregate fixture keeps its existing Phase 8 compatibility
identity so that this phase does not silently change the shadow save. These are intentionally
separate scopes and are not presented as a production cutover.

## Implemented source contract

| Area | Native implementation | Contract evidence |
|---|---|---|
| Anonymous identity | `FileInstallIdentity`, `InstallIdentityContract` | 32 lowercase hex, atomic/read-back durable file, no process-only fallback, scoped hashes never expose the raw ID |
| Analytics | `NativeAnalyticsService`, `FirebaseAnalyticsDestination`, `AmplitudeAnalyticsDestination` | Matrix event/property allowlist, retired Daily rejection, reserved/PII/free-text rejection, Firebase bool `1/0`, FIFO 128 outbox, destination delivery receipts, restart retry |
| Crash reporting | `FirebaseCrashReporter` | Consent-gated native Crashlytics adapter with only distribution/schema/phase/life/quality/Unity-stage keys; raw save, URL, user input, and identity are not recorded |
| Notifications | `NativeNotificationPermission`, `NativeReminderScheduler`, `ReminderAlarmReceiver`, `NotificationOpenCoordinator` | API 33 permission truth, external revoke re-read, allowlisted HighSchool/Pro/Records destinations, Daily legacy normalization, stable token hash, separate analytics/navigation receipts, durable scheduled-token allowlist |
| Review | `ReviewGate`, `NativePlayReviewService` | Exact third-life/good-recap/drafted-reveal-confirmed reasons, reason lifetime, 24-hour interval, native Play request, failure does not affect game state |
| Share | `NativeLifeCardShareService` | non-exported `FileProvider`, full-content Korean text plus PNG in `ACTION_SEND`, chooser-open-only analytics, text fallback, cache cleanup |
| Audio/haptics | `NativeAudioHapticsService`, `HapticPolicy` | SoundPool effects separate from MediaPlayer music, audio-focus pause/resume, presentation-seed variation, reduced-motion/system-haptics gates |
| Compose callers | `Phase9ComposePlatform`, `MainActivity` | settings/notification/share/review actions capture a canonical typed payload before dispatch; MainActivity verifies revision and commitment before executing; no fake success |

The requested semantic remediation is implemented in the current dirty worktree: the application
analytics boundary is event/key typed with exact text domains; training uses signed, versioned,
backward-compatible per-session evidence; rebirth and recap/custom entry paths use committed
payloads and inherited state; legacy visibility and LifeCard share receipts bind to exact frozen
records; reminder offers require first-game/requestable/unasked/undeclined OS truth; generic P-030
review requests and challenge `first_pitch` callers are absent; optional analytics fields are
omitted unless authoritative evidence exists; and the executable matrix covers all active events,
typed values, guards, restart, and unknown-caller rejection.

## Durable and privacy rules

`Phase9PlatformStateCodec` is a strict canonical JSON codec. It rejects unknown fields, malformed
types, noncanonical bytes, duplicate receipts, unsupported schema versions, and invalid token or
review shapes. `FilePlatformStateStore` writes a canonical temporary file, forces the file before
atomic replacement (with a best-effort directory force), then decodes the replaced bytes for
read-back verification.

Analytics is enqueued only after the aggregate durable receipt projection. Each event is validated
against the current matrix before entering the platform outbox. SDK failure leaves the event in the
outbox and never fails or rolls back the committed game state. Once all configured destinations
acknowledge a receipt, the install-scoped receipt is retained and later publishes are ignored.
When no external destination is configured, the local outbox remains durable and retryable; this is
the fail-closed development behavior.

No production Firebase configuration, Crashlytics mapping, Amplitude API key, or backend secret is
checked into this worktree. `PHASE9_EXTERNAL_SDKS_ENABLED` defaults to false and the development
build uses `compose-dev`; therefore this evidence does not claim a real Firebase/Amplitude or
Crashlytics production receipt. A separately supplied, explicit test configuration is required for
that external-receipt gate. No raw player name, career ID, school/team free text, seed, URL, save,
file path, email, phone, location, advertising ID, or image is sent by the native schema.

## Executable tests and gates

The focused native contract suite passes (24/24 tests):

```text
cd apps/android
./gradlew :platform:test --no-daemon --console=plain
```

It covers canonical/tamper/unknown-field state decoding, file restart and reset domains,
install identity persistence and scoping, every non-zero analytics event plus typed/domain
rejection, analytics destination failure/success/retry/dedup, notification legacy normalization and
process-death receipt separation, review lifetime/24-hour gates, typed platform action future-wire
rejection, and haptic policy. The application suite adds the exhaustive event/property matrix,
training 1/2/3/stop/single/save-failure/restart cases, exact rebirth/legacy/share/reminder/review
guards, and challenge/optional-field audits.

The source/dependency boundary checker currently passes:

```text
npm run check:android:phase9
```

The full Android, connected AVD, dependency-report, Swift, fixture, copy/IP/assets, Unity, and
reference results are recorded below after execution. A passing static check is not treated as an
external SDK receipt or a device notification/share/review delivery receipt.

## Evidence ledger

The following entries are intentionally filled only with command output from this worktree:

| Artifact or gate | Command/path | SHA-256 / result |
|---|---|---|
| Native platform focused tests | `:platform:test` | PASS, 24/24 |
| Android JVM/static/lint + debug packaging | `test lint :app:assembleDebug :app:assembleDebugAndroidTest :app:bundleDebug` | PASS, 300 actionable tasks |
| Debug APK | `apps/android/app/build/outputs/apk/debug/app-debug.apk` | `951c72a8538faf075612a3b1b9ebfb1ca4ed94c4c23f39b785ea53a09d670128` |
| Debug APK test package | `apps/android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk` | `9c292d4aea7be36aadd9b4b34bcdbea45f2433f6e1e58fbf64c0b38f957691d6` |
| Debug bundle | `apps/android/app/build/outputs/bundle/debug/app-debug.aab` | `f94ca0ccbecd5e77d9bd255f57af5002e9767d41908f85d9805daa9f8629d3b7` |
| Runtime dependency graph | `artifacts/android-compose/phase9-evidence-2026-08-14/dependencies-debugRuntimeClasspath.txt` | `cd07c647a052065cf5d6f698778a62fc67973c04b9cd8686a6eae4e932732d20` |
| Phase 9 static dependency/source scan | `tools/check-android-phase9.mjs` | PASS; SHA-256 `64adadac0df540f1685a93d52bb1cda87897f711557ea43a6e65011cc3877efe` |
| Connected API 35 / 16 KiB AVD | `baseball_16k_api35` / `:app:connectedDebugAndroidTest` | PASS, 7/7; API 35, page size 16384, arm64-v8a |
| Final emulator screenshot/XML | `artifacts/android-compose/phase9-evidence-2026-08-14/10-final-native-platform-2026-08-14.{png,xml}` | PNG `9d3e92d41564d7ead009d146bcfb592e640a29b1b4a96a5a8967d192b6da6663`; XML `fdda9de708177fe763bc8e586eec651fb2993afb8244b5f4361617ae428a168c` |
| Cross-runtime fixture report | `npm run report:android:fixtures` / `artifacts/android-compose/fixtures/cross-runtime-report.json` | PASS; SHA-256 `61660ee3d2048128f75f5dad30ab636a27bb4c7d24ea7153412b13b9479259dc` |
| Swift | `swift test --package-path packages/simulation-core` | PASS, 377/377 |
| Unity static/reference/copy/IP/assets | repository scripts | PASS: static 447/447, reference 0 warnings/0 errors, copy/dialogue/assets green |
| Wrapper | `apps/android/gradlew --version` | Gradle 9.1.0; wrapper properties SHA-256 `6009cea91ce8dbcc62cb2ea6dec6ddd4c87b65fc326872f5abfc7e77fd24aa36` |

## Explicit external and deferred boundaries

The following are not fabricated by this phase:

1. Production Firebase Analytics/Crashlytics receipt, Amplitude receipt, and Crashlytics native plus
   IL2CPP symbolication require credentials, an explicit test distribution, and upload/service
   access not present in this worktree.
2. Notification delivery and Play review completion are OS/Play outcomes. The emulator evidence
   can prove permission truth, durable scheduling/open normalization, and fail-closed behavior; it
   cannot prove a Play backend review submission without Play services/account availability.
3. Phase 10 update-install, rollback, and production package/save cutover are intentionally not
   run.

The repository release-contract checker `npm run check:android:unity` remains externally blocked by
the pre-existing omitted/injected `apps/android-unity/Assets/google-services.json` requirement;
that credential/configuration file was not added. The full Unity presentation batch also retains
the two already-dirty oracle assertions documented in the migration status; the requested static
447/447 and reference 0-warning/0-error checks are green.

No Phase 10 work is included in this document.
