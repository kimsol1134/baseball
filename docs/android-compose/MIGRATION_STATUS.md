# Compose + pitch Unity migration status

Status after the Phase 2/3 implementation pass, the Phase 4 core/meta acceptance pass, the
Phase 5 Pro pure-Kotlin shadow acceptance pass, the Phase 6 application/save contract-audit
tutorial-ownership remediation pass, the Phase 7 Compose vertical/UaaL acceptance pass, the
Phase 8 full Compose screen implementation/evidence pass, the Phase 9 semantic/native platform
remediation pass, the Phase 10 internal package cutover rehearsal, and the Phase 11 C# v1
command-authority write-back, against
`ANDROID_COMPOSE_SHELL_UNITY_PITCH_MIGRATION_PLAN_2026-08-13.md` (2026-08-17 KST).

## Evidence vocabulary

- `SOURCE`: checked-in oracle source or committed fixture bytes.
- `VERIFIED`: a command or local runtime check actually executed in this worktree.
- `EXTERNAL`: an existing artifact, environment fact, or evidence outside this pass.
- `NOT RUN`: not executed or unavailable here.

Static checks do not upgrade a flow to emulator/device/Play evidence. The production package ID,
production save location, and `apps/android-unity` oracle remain protected.

## Gate ledger

| Scope | Status | Evidence and boundary |
|---|---|---|
| Phase 0 / T-001 | `SOURCE` + `VERIFIED` | [PHASE_0_BASELINE.md](PHASE_0_BASELINE.md), the generated Phase 0 manifest, shadow Gradle repository, feature boundaries, and disabled production ID. The worktree was already dirty and was preserved. |
| T-002 / T-003 / T-004 | `EMULATOR` | Actual pitch-only Unity export and APK. API 35 16 KiB ARM64 emulator exercised Compose → one full-screen Unity surface → Kotlin presentation commands → terminal → unload → Compose return → re-entry in the same app process. No second Unity runtime was started. |
| Phase 2 fixture gate | `GREEN` against current Swift authority; historical C# divergence `DOCUMENTED` | The committed current Swift fixture has exact 128 rows and the 10,000 distribution, and Kotlin matches it byte-for-byte at source `792d728`. The frozen C# fixture remains complete and hash-validated at source `23acbb8`, but its deterministic rows differ because it predates the current Swift pitch rules. The Node report validates generated-vs-committed Swift bytes, both fixture envelopes, and the .NET C# report. Locale/timezone and invalid/future/unknown-wire tests pass. |
| Phase 3 PitchKernel gate | `GREEN` against current Swift authority; historical C# divergence `DOCUMENTED` | Kotlin owns preparation, submission, context/scouting/rival/game situation, delivery, ability moments, result/fielding, trajectory presentation, and committed replay. Exact 128/10,000 Kotlin output matches the current Swift `PitchKernelEngine` fixture. The four pitch trajectories are distinct in the presentation factory. Unity runtime source contains no result-generation API and accepts presentation data only. The frozen C# source set at `23acbb8` is retained as historical evidence, not silently mixed into the current Swift authority. |
| T-005 | `PORT` / `VERIFIED` for current Swift pitch + Phase 4 vertical | SplitMix64/hash and the current authoritative Swift pitch rows are exact against the committed fixture. The historical C# fixture is retained and report-validated with its source/hash metadata. Kotlin now covers the source-backed HighSchool setup/prologue/school/training/block/bloom/relationship/tournament/ranking/important-game/PitchKernel/awakening/chapter/draft/legacy/archive/rebirth vertical plus the C#-authority Meta ledgers. |
| T-006 | `COMPAT` / `VERIFIED` | Real current/backup save fixtures decode and re-encode with additive/unknown fields retained. Duplicate, corrupt, incompatible, future, older, checksum, and semantic-invalid inputs fail closed. Kotlin production writing remains disabled. |
| Phase 4 | `GREEN` / `VERIFIED` (documented core acceptance met) | Eight seeds complete chapter 8 through draft/completed with restart after every durable phase and active-pitch boundary; archive/legacy/rebirth and challenge backup isolation are exercised. The completed-game counter is monotonic and exactly matches committed game receipts. C#-authority achievements, weekly board/receipts/stamps, return-plan experiment/receipt preparation, and strict v6 state/v1 command codecs are covered by JVM tests, including tamper, stale/duplicate, unknown/future-wire, and malformed-envelope rejection. |
| Phase 5 | `GREEN` / `VERIFIED` (pure-Kotlin shadow acceptance; production writes disabled) | Linked/direct Pro start, deterministic team selection, six weekly plans, targeted development, exact segment weeks/auto-advance, important-game PitchKernel boundaries, minor/major progression, full 20-season careers, season ledgers/standings/leaderboards/awards/milestones/decision history, offseason/retirement/max-career, three frozen linked legacy candidates, linked HS archive settlement, and direct-Pro no-fake-archive/active-HS preservation are covered by strict JVM tests. Strict signed state/command codecs, restart at durable phases and every pitch boundary, idempotent/stale/tamper/unknown/future-wire rejection, and the 20-seed current-Swift Pro fixture/report are green. The historical C# PitchKernel exact/distribution gate is green and retained as documented authority evidence. This is not production authority transfer. |
| Phase 6 | `GREEN` / `VERIFIED` after contract-audit remediation (Kotlin engine and fixture scope; production writes disabled) | The exact §4.1 `GameStore` contract is implemented with `StateFlow` aggregate state/busy, suspend dispatch/reconcile, a Mutex one-at-a-time boundary, and an IO repository adapter. State publishes only after verified save; analytics uses a restart baseline plus before/after durable diff, swallows SDK/observer failure without losing committed state, and keeps failed receipts retryable. Typed `PitchCareerKind` is fail-closed to HighSchool/Pro/Tutorial (retired Daily rejected), validates active career identity/aggregate shape, persists RESERVED→PLAYING, and counts only official non-challenge HighSchool/Pro completions. Tutorial reservation and nonterminal restored pitch shapes (`RESERVED`/`PLAYING`/`COMMITTED`/`CONSUMED`/`TERMINAL`/`SUSPENDED`) require the owning active HighSchool stage/career in `PROLOGUE` with `tutorial.started && !tutorial.completed`; Opening/missing owner, wrong stage/active ID, not-started, completed-nonterminal, and challenge-isolated cases fail closed. Retained `COMPLETED`/`ABANDONED` tutorial shapes require the existing active-career binding and wire-safe non-challenge identity, but do not require the old PROLOGUE/tutorial-incomplete lifecycle, so they do not block `CompleteTutorial`, `SCHOOL_SELECTION`, or subsequent `ChooseSchool` progression. The vertical regression completes a non-challenge tutorial, asserts `completedGameCount == 0`, completes the tutorial, chooses a school, and reaches `TRAINING`, with abandoned retention covered too. Reset has the exact contiguous intent/repository/identity/analytics/review/reminder/scoped-epoch/share-cache/completed receipt sequence with per-step side-effect APIs and restart/fault coverage at every boundary. Existing Phase 4/5 reducer integration, strict canonical command/state codecs, revision/idempotency/stale/tamper handling, C#-compatible v1 envelope fixtures, three-backup atomic recovery/quarantine/future/older refusal, fault injection, and real C# reader compatibility remain green. `nativeShadowReadOnly` remains the default/production mode and rejects writes. |
| Phase 7 | `GREEN` / `VERIFIED` (Compose + Unity vertical; production writes disabled) | The real `Opening → Setup → Prologue/Tutorial → School → Training → Relationship → Important Game → Compose pitch HUD → full-screen trajectory-only Unity → Compose Postgame → Awakening/Chapter` route is implemented by `Phase7VerticalController` and `MainActivity`. `PitchUnityActivity` looks up the saved `sessionId + expectedRevision`, enforces one runtime, keeps normal return as pause/detach, and resets the terminal-return handshake for same-session re-entry via `PitchReentryPolicy`; the second pitch in the preserved emulator important-game session returned to Compose Postgame after the fix. Focused tests cover repository reopen/process death at RESERVED, PLAYING, COMMITTED, CONSUMED, TERMINAL, and COMPLETED, exact replay, stale/mismatched callbacks, duplicate callbacks, Back→SUSPENDED versus explicit ABANDONED, analytics baseline/delta/failure/retry/no-duplicate behavior, and multi-pitch official-game counting once. Compose owns all meaning/UI/input; Unity exposes only the ball/trail/trajectory/impact surface. Production package/save writes remain disabled and the app runs `NATIVE_SHADOW_READ_ONLY` against the `.compose.dev` shadow fixture. |
| Phase 8 | `GREEN` / `VERIFIED` for the Phase 8 implementation and API35 evidence | All 29 non-retired product IDs have valid-state Kotlin projection coverage, accessibility validation, exact typed view/action payload round-trips, and state-authoritative preferred-route/restart/duplicate/stale tests. The actual Compose shell was exercised on the API35 16 KiB AVD at opening, setup, prologue, tutorial, settings, and restart-preferred tutorial states; final screenshots/XML at 100/130/150/200% and the coverage ledger are in [PHASE8_COVERAGE_LEDGER.md](PHASE8_COVERAGE_LEDGER.md). P-023 has no product route; legacy Daily links normalize to the preferred current route. Phase 9 platform behavior is tracked in [PHASE9_NATIVE_PLATFORM_EVIDENCE.md](PHASE9_NATIVE_PLATFORM_EVIDENCE.md). |
| Phase 9 | `GREEN` / `VERIFIED` for the semantic remediation and local Android/API35 gates; external SDK receipts not claimed | Event/key typed analytics parsing and exact domains, committed versioned training evidence, authoritative rebirth/recap paths, exact legacy viewport/share scopes, first-game/requestable reminder offers, product-moment-only review calls, non-challenge `first_pitch`, evidence-only optional fields, and the executable matrix are implemented. Focused platform tests are 24/24; full Android JVM/lint/debug APK/debug test APK/debug bundle is green; connected API 35/16 KiB instrumentation is 7/7; Swift is 377/377; fixture, copy/IP/dialogue/assets, Unity static 447/447, and reference compiles are green. Final hashes and emulator evidence are in [PHASE9_NATIVE_PLATFORM_EVIDENCE.md](PHASE9_NATIVE_PLATFORM_EVIDENCE.md). The release checker remains blocked only by the pre-existing omitted/injected `google-services.json` requirement; production package/save writes remain disabled. |
| Phase 10 | `VERIFIED` for the internal emulator rehearsal / `BLOCKED` for production RC | Unity v32 → Compose native-authoritative v33 → Unity rollback v34 → Compose v35/v36 update-install rehearsal passed on `emulator-5554` without uninstall or `pm clear`: five deterministic phase saves were reopened byte-for-byte, a real Kotlin settings command advanced the atomic legacy save, C# read the Kotlin-written revision/settings/null/default/commitment, and reset/corruption/backup/fault/install-mismatch contracts passed. Final package/save/cert/UI XML/screenshots and exact gate outcomes are in [PHASE10_CUTOVER_EVIDENCE.md](PHASE10_CUTOVER_EVIDENCE.md). The v5 upload private key was not available, and no Play/physical-device evidence is claimed. |
| Phase 11 command authority | `VERIFIED` on JVM against the frozen C# v1 wire / `BLOCKED` for CI/RC/Play/device | The production legacy adapter no longer fail-closes career commands. C# `coreStateJson` decodes to `HighSchoolState`, Kotlin Phase 4 is the command authority, and write-back re-signs with the C# FNV-1a algorithm so Unity `Restore()`/`Validate()` can read the next snapshot. Settings, EnterSetup, HighSchool, pitch resume, analytics, and Pro (Kotlin sidecar + C# Sign fields) all write through `AtomicJsonRepository`. Real relationship fixture `save-v1-current.json` advances and reloads. Play upload key, physical Low/Mid/High, API 29/36 matrix, and Firebase/Amplitude/Crashlytics production receipts remain unavailable here. Phase 12 is not started. |
| Phase 11 Play-prep | `VERIFIED` for source/product-surface / `BLOCKED` for signed RC and Play upload | The Compose app now ships the product name, approved launcher/themed icons, smartphone screen filter, portrait lock, and the upload-key/Firebase/Amplitude injection path. `npm run check:android:compose:release` and `npm run build:android:compose:rc` are the local gates. This machine has no Unity 6000.3.19f1, no pitch export, no signing password in the process environment, and no emulator/device matrix, so no Play AAB was built or uploaded. The human checklist is [PLAY_SUBMISSION_CHECKLIST.md](PLAY_SUBMISSION_CHECKLIST.md). |

The Phase 2/3 green status is deliberately scoped to the current Swift-authority pitch migration
gates. The historical C# source-set divergence is explicit and still needs a product/oracle
reconciliation before the two runtimes can be called mutually exact. This does not mean the whole
repository or migration document is complete.

## Cross-runtime fixture evidence

The frozen historical C# pitch source set is commit
`23acbb8ec233836e802009c8852c430e08075d3c`, source-set SHA-256
`bdf4288abbc6dc81e96f8c725202af4e764bb293640e3fb0e3571abef182c76b`. The committed C# fixture
records input SHA-256 `d61eb1b2b39628f55e9318a062628ee71f941de979ccf0f360ccaa5dc1b1b2ce`, output
SHA-256 `1be138df2264c62481590ca4c1bfe1ad9072ff45a30b14531316906fcc9127fe`, exact-run count
128, and canonical-row FNV-1a64 `56b7c99922f1d66d`.

Its recorded 10,000-run distribution is:

`ball=2552, called_strike=2458, double=59, foul=1060, hit_by_pitch=1, home_run=14, in_play_out=871, single=226, swinging_strike=2755, triple=4`.

The reproducible current-HEAD Swift export is committed at
`apps/android/game-core/src/test/resources/fixtures/swift-pitch-kernel-current-v1.json` and is
also regenerated as ignored evidence under `artifacts/android-compose/fixtures/`. It records
source commit `792d72859dc5dcfdc8cefa8b69ab50bc072c212f`, input SHA-256
`d61eb1b2b39628f55e9318a062628ee71f941de979ccf0f360ccaa5dc1b1b2ce`, output SHA-256
`37d86e69406862d434a4304f929dd8725502e4d7dc53cb9f73dddd6dd36fbcc6`, exact-row FNV
`63c42bbba86d7410`, and distribution
`ball=2517, called_strike=2482, double=53, foul=1120, hit_by_pitch=2, home_run=12, in_play_out=916, single=234, swinging_strike=2661, triple=3`.
The report labels its comparison to the historical C# fixture `SOURCE_DIVERGENCE_DOCUMENTED`;
Kotlin matches this current Swift fixture and no value is invented to bridge the two source
revisions.

The older committed Swift fixture remains an approved summary for the historical C# source set;
complete row bytes remain in the C# export. The current Swift fixture is the authority selected by
plan section 5.1, and its complete rows are now committed for Kotlin differential tests. The older
`SimulationEngine` golden fixture is retained under an explicit non-PitchKernel authority scope.

The current Swift HighSchool Phase 4 fixture is `swift-high-school-phase4-oracle-v3.json` at source
commit `792d72859dc5dcfdc8cefa8b69ab50bc072c212f`. Its 20 seeded rows are exact, with input
SHA-256 `dbd5f721edbf4f560c2edea8ba35c9ef0811192a18fbacd25e2cf3aa55315119` and canonical output
SHA-256 `ebcf365278b10cdcd5d56ee20a73252c8a2623ad54dd1202414225d6359c2095`; the fixture report
and `HighSchoolPhase4FixtureTest` both validate the committed bytes and Kotlin projections.

The current Swift Pro fixture is `swift-pro-career-oracle-v1.json` at the same source commit
`792d72859dc5dcfdc8cefa8b69ab50bc072c212f`. It covers seeds 100...119 through linked start,
contract signing, and the first weekly plan, with input SHA-256
`78f6e4e41f638d6ef09bb961d5a731e412126ebfe0b94756b52763ef9885a982` and canonical output
SHA-256 `850ce637c48fa28b689effe52e2233961743fc1327728bdf3e12eada7f224d39`. The fixture report
records `MATCHES_COMMITTED_SWIFT_AUTHORITY`, and `ProCareerFixtureTest` validates the exact 20
rows plus deterministic direct-team selection across 10,000 seeds. `ProKernelTest` additionally
validates direct and linked maximum-career flows, ledger/standing/leaderboard invariants,
restart/codec boundaries, and linked HS settlement without enabling production writes.

Phase 6 save fixtures use the existing `android-unity-save-v1` wire and strict semantic fields. The
current emulator clone is envelope/payload revision 6, install ID
`718fa1083cc647d0b169ff301fdb9ad7`, stage `highSchool`, payload SHA-256
`4de30c7533a3932ca5b9088c2dc6cde64d300bf246dd41afa0394dc38e123b7`, with the expected nullable
`pro`, `pitchResume`, and `pendingPitchCompletion` paths. The Kotlin-written fixture is revision 7
with payload SHA-256 `32c5261f16c2c76815e46825d1a6102bc1c34ae3e1082149b8fb5aad2ab23f15`; the
real C# writer fixture is envelope revision 8 while retaining aggregate payload revision 7 and the
same semantic identity/payload hash. The fixture report checks envelope/payload field inventories,
timestamp/revision/hash metadata, raw bytes, null/default shape, and both semantic transitions.

## Phase 7 device and lifecycle evidence

The rebuilt debug APK is
`apps/android/app/build/outputs/apk/debug/app-debug.apk`, SHA-256
`695e1634fa3bc55c48386f994ca759fe263edb3b1a4370a693c6cc370712e0aa`. `zipalign -c -p 4` and
`apksigner verify --verbose` passed with Android build-tools 35.0.0; APK Signature Scheme v2 is
valid. The earlier user-verified emulator APK SHA
`2b5c496b96ca64952316cd4ccf970d45c055b83912509d6ac635c5c8468f734d` remains historical evidence;
the SHA above is the final APK from this Phase 7 fix pass.

On AVD `baseball_16k_api35`, package
`com.solkim.baseball.android.compose.dev`, API 35, `getconf PAGESIZE=16384`, the preserved dirty
shadow save was installed with `adb install -r` (no app-data clear). The latest-fix evidence is in
`artifacts/android-compose/phase7-emulator-2026-08-14/final/latest-fix/`:

- `04-inflight-1.2s.png` is an actual in-flight Unity ball/trail frame (SHA-256
  `53ade827a82039306361088652166d85759a3539f1ca7d9bf072f6e0191fbf76`).
- `06-exact-replay.png` and `07-compose-postgame-after-pitch.png` show exact replay followed by
  result-only-after-save Postgame return; their SHA values are
  `53ade827a82039306361088652166d85759a3539f1ca7d9bf072f6e0191fbf76` and
  `c429be0c146f71dbce5b05f0f6468687b7025e998c52b618ec85b369fa8d18d9`.
- `14-relationship-after-training.png` is the captured Awakening screen (the filename is retained
  from the scripted capture), and `15-chapter-after-awakening.png` is the subsequent Chapter
  screen. Their SHA-256 values are `269dc9bc0d59fe34a9595fcabb246af274a3119256d2c2adb942da0bdf00f96d`
  and `da27404932c7c584b77a39873225cf31f1fe40b5685b6ae13e6bc384dc5eaef5`.
- `09-font-200-chapter.png`, `10-font-200-chapter-scrolled.png`, and their XML captures verify
  actual `font_scale=2.0`, readable wrapped Korean content, minimum-height controls, and the
  fully scrolled footer above the navigation bar. Their screenshot SHA values are
  `23ee3f4df1e73864542245879d0be846b8bc730d986ce8ca6da9226d82fb67a4` and
  `084f698f88586cc4c513e742df19e8599d916268e1d2790231a5668d5a4c9caa`.
- `16-talkback-enabled.dumpsys` records the installed TalkBack service bound with
  `touchExplorationEnabled=true` (SHA-256 `08e23c93f4f4de36605cc5093f9e0bc3e19b271d4a6a2bcf713e8420d7d6a3af`); the Compose XML captures expose content descriptions for route
  actions, pitch selection, replay, Postgame, suspend, and destructive abandon. The service and
  `font_scale` were restored to disabled/1.0 after capture.
- `17-device-contract.txt` (SHA-256 `bfcf0ddda258a63736a1cfcff8846721cf7f6b79b5ce895836ce5311698e4a09`),
  `18-activity-final.txt` (SHA-256 `2a491f1b38c9b81577c1d887a8110c71c037011fefad85c1dca00170be457ca2`),
  `18-final-shell.png` (SHA-256 `c811f848f91ca79f00ca8a5e22afc8030d447234306574e0835baf67351e5f36`), and
  `17-logcat-relevant.txt` (SHA-256 `ef22948308998cd499d9333805ef52142344d6b932b4ee70b4d1c7fda51059b0`) record the final
  API/page-size/settings/activity/logcat checks. There are no `relabelfrom` or `avc: denied`
  lines after `NioKotlinSaveFileSystem` stopped copying file attributes to app-private backups;
  the prior warning was an emulator SELinux relabel attempt caused by `COPY_ATTRIBUTES`, not a
  save-byte failure. The final foreground activity is Compose `MainActivity`.

The preserved emulator save already contained a pre-fix historical `completedGameCount=4`; it was
not normalized or cleared. Its latest durable analytics receipts are unique (`79/79`) and show the
same-session second-pitch sequence at revisions 67–75, including `FinishImportantGame` before the
generic pitch completion. The fresh isolated Phase 7 route test asserts `gamesBefore + 1` for a
multi-pitch important game and equality between the completed-game counter and receipt count; the
device's inherited historical counter is not used as new count-once evidence.

## Commands and results

Verified in this pass:

- `cd apps/android && ./gradlew :game-application:test --tests 'com.solkim.baseball.application.Phase8ScreenProjectionTest' --no-daemon --rerun-tasks` — pass; valid HS/Pro fixtures cover all 29 product IDs except retired P-023, exact captured action/view payload codecs, preferred-route restart, duplicate/stale rejection, and committed-state routing.
- `cd apps/android && ./gradlew test lint :app:assembleDebug :app:assembleDebugAndroidTest --no-daemon --console=plain` — pass after the final Korean tutorial-copy patch; 243 actionable tasks, including full Android JVM/static/lint and both APK assemblies.
- `cd apps/android && ./gradlew :app:connectedDebugAndroidTest --no-daemon --console=plain` — pass, 2/2 on `baseball_16k_api35` API 35/16 KiB AVD.
- `npm run check:android:compose`, `npm run check:copy`, `npm run check:copy:android:unity`, `npm run check:korean-copy`, `npm run check:dialogue-parity`, and `npm run check:unity-assets` — pass after the final product-copy patch.
- `npm run test:unity:static` — pass, 447/447; `npm run test:unity:references` — pass, requested reference projects with 0 errors/0 warnings. `swift test --package-path packages/simulation-core` — pass, 377/377. `npm run report:android:fixtures` — pass with exact fixture/report hashes recorded in `PHASE8_COVERAGE_LEDGER.md`.
- Manual API35 AVD route: cold Opening → Setup → valid player → Prologue → Tutorial, saved at revision 3, force-stop/reopen to the preferred Tutorial route, and screenshot/XML captures at 1.0/1.3/1.5/2.0 including a 200% scrolled view. The exact product-surface scan and artifact hashes are recorded in `PHASE8_COVERAGE_LEDGER.md`.
- `npm run report:android:fixtures` — pass; runs all current Swift exporters, validates generated-vs-committed current Swift/Phase 4/Pro rows, validates the historical C#/approved Swift fixtures, validates the Phase 6 save compatibility report, and runs the .NET C# comparison report.
- `npm run check:android:compose` — pass; includes Unity authority-boundary and HighSchool kernel/catalog source checks.
- `cd apps/android && ./gradlew :game-application:test --no-daemon --tests 'com.solkim.baseball.application.Phase6GameStoreTest' --tests 'com.solkim.baseball.application.Phase6ContractAuditTest'` — pass; 16 focused application tests, including the nonterminal tutorial ownership rejection matrix, terminal-retained validation, the real CompleteTutorial→ChooseSchool progression regression, non-challenge tutorial count assertion, exact Flow/Mutex/IO/reconcile behavior, analytics restart/failure/retry, strict typed pitch boundaries, and shadow-write rejection.
- `cd apps/android && ./gradlew :game-persistence:test :game-application:test --no-daemon --tests '*Phase6*' --tests '*LegacySaveCodecTest'` — pass; focused Phase 6 evidence is 9 persistence tests, 7 original store tests, 9 contract-audit store tests, and 3 reset-coordinator tests, including every reset receipt and process-death boundary, every save/reset fault point, restart, and C# fixture compatibility.
- `cd apps/android && ./gradlew :game-core:test --tests 'com.solkim.baseball.core.pro.*' --no-daemon` — pass; focused Pro kernel, codec, restart, legacy, archive-settlement, and fixture tests.
- `npm run test:android:compose` — pass; full Android JVM suite, including exact current-Swift pitch/HighSchool/Pro fixtures, retained historical C# fixture metadata, replay, save compatibility, and semantic validation.
- `cd apps/android && ./gradlew :game-core:test :game-application:test :app:compileDebugKotlin` — pass.
- `cd apps/android && ./gradlew lint --no-daemon --stacktrace` — pass, zero lint errors; existing warnings remain.
- `npm run check:copy` — pass; no internal or real-baseball IP terms exposed by the product check.
- `npm run check:copy:android:unity`, `npm run test:korean-copy`, and `npm run check:dialogue-parity` — pass.
- `npm run check:unity-assets` — pass, 150 assets checked.
- `npm run test:unity:static` — pass, 447/447; `npm run test:unity:references` — pass, requested production/internal-QA/core/platform/presentation/editor reference projects compile with 0 errors/0 warnings.
- `swift test --package-path packages/simulation-core` — pass, 377/377, including 37/37 Pro engine tests and the 20-seed maximum-career groups. No temporary/new Swift debug prints remain; the pitch and HighSchool exporters retain only their intentional fixture-summary prints.
- `npm run test:unity` — the current full batch executed all 27 persistence cases (including both real C# compatibility cases) and PlayMode 14/14, with all Phase 6 persistence cases green. Core 47/47, application 121/121, platform 60/60, high-school 39/39, Pro 25/25, Internal-QA 12/12, and all 14 bootstrap cases passed. The batch remains nonzero only for the two dirty presentation assertions (239/241); no migration/oracle file was edited.
- `npm run check:android:unity` — blocked by the existing injected/omitted `google-services.json` release-contract requirement; no file was added.
- `cd apps/android && ./gradlew lint :app:assembleDebug --no-daemon --stacktrace` — pass; zero lint errors, aligned debug APK, and `apksigner` v2 verification. The final APK is `apps/android/app/build/outputs/apk/debug/app-debug.apk`, SHA-256 `695e1634fa3bc55c48386f994ca759fe263edb3b1a4370a693c6cc370712e0aa`; `zipalign -c -p 4` passed.
- `cd apps/android && ./gradlew :game-application:test --tests '*Phase7VerticalControllerTest' --tests '*Phase6ContractAuditTest' --tests '*Phase6GameStoreTest' :game-persistence:test --tests '*Phase6PersistenceTest' --tests '*LegacySaveCodecTest' :unity-bridge:test --tests '*PitchReentryPolicyTest' --tests '*PitchSessionGateTest' --no-daemon --stacktrace` — pass; the focused Phase 7/Phase 6 suites include independently named repository reopen tests at RESERVED, PLAYING, COMMITTED, CONSUMED, TERMINAL, and COMPLETED plus the same-session terminal-return handshake regression.
- `npm run test:android:compose` — pass after the lifecycle, count-once, accessibility-layout, and repository relabel fixes; full Android JVM suite is green.
- `npm run check:android:compose`, `npm run test:unity:static`, `npm run test:unity:references`, `npm run check:copy`, `npm run check:copy:android:unity`, `npm run test:korean-copy`, `npm run check:dialogue-parity`, `npm run check:unity-assets`, and `npm run report:android:fixtures` — pass. The current Swift exporter and full fixture report remain byte/hash-integrity green.
- `swift test --package-path packages/simulation-core` — pass, 377/377. The proportional Unity batch remains green for the migration scopes listed above; its only nonzero result is the two pre-existing dirty presentation assertions documented below.
- `ANDROID_ADB_BIN=/Users/solkim/Library/Android/sdk/platform-tools/adb npm run smoke:android:compose` plus the manual API 35 path — install/launch and the complete two-pitch same-session path passed on `baseball_16k_api35`: in-flight Unity trajectory, exact replay, saved Compose Postgame, Awakening, and Chapter. The manual capture also verified 200% font scrolling, TalkBack service binding/content descriptions, navigation-bar-safe controls, final activity, and filtered logcat.

The local build still reports Android SDK XML v4/v3 and Unity-recommended NDK 23.1 versus installed
NDK 27.2 warnings; neither prevented the verified export/build. The latest emulator run used AVD
`baseball_16k_api35` and package `com.solkim.baseball.android.compose.dev`. Production package/save
writes remained disabled throughout.

## Known repository and external boundaries

The full Unity oracle presentation batch has two failures in already-dirty oracle content:

1. `MissingArtworkShowsExplicitFallbackWithoutDisablingChoice` has an expected/current fallback-copy mismatch.
2. `ProductScreensCallImportedChoiceAndNarrativeArtworkLoaders` expects a source contract changed in the dirty oracle.

These are not migration files and were not masked. `npm run check:android:unity` also remains blocked
by its pre-existing release requirement for injected/omitted
`apps/android-unity/Assets/google-services.json`. The repository-wide `npm run check` stops at
existing iOS design-system failures before later stages.

The relevant C#/Unity suites are green for the Phase 6 scope: the corrected full batch reports 27/27
persistence cases and PlayMode 14/14, and the direct Internal-QA retry is 12/12. The full batch's
remaining nonzero evidence is the two dirty presentation assertions above plus the transient Mono
crash; the presentation batch is 239/241. `npm run test:unity:static` is 447/447 and
`npm run test:unity:references` compiles the requested reference projects with 0 errors/0 warnings.

No physical device matrix, physical-device Unity validation, Play internal/closed track, Firebase/Amplitude/Crashlytics receipt,
API 29/API 36 matrix, or production update-install rehearsal was run. API 35 emulator TalkBack,
200% font, navigation-bar-safe layout, and Unity trajectory/re-entry evidence are verified; no
physical-device or Play validation is claimed.

## Phase 8 Compose screen and device evidence

The complete Phase 8 screen ledger is [PHASE8_COVERAGE_LEDGER.md](PHASE8_COVERAGE_LEDGER.md). It
maps every P-001…P-030 screen except retired P-023 to a valid Kotlin aggregate fixture, exact
captured command/view payload coverage, semantics/layout validation, representative emulator
evidence, and an honest Phase 9 boundary. The ledger is explicit that the same product renderer is
used across the 29 projections; it does not invent 29 separate device sessions.

The Phase 8 launcher is now the state-authoritative Compose product shell: `MainActivity` is the
only launcher, `preferredScreen` is recomputed from the committed aggregate on cold start/restart
and after successful dispatch, and an unreachable/off-state screen fails closed. The generated
Unity library launcher declaration is removed from the app manifest. The current Phase 9 debug
APK is `apps/android/app/build/outputs/apk/debug/app-debug.apk`, SHA-256
`951c72a8538faf075612a3b1b9ebfb1ca4ed94c4c23f39b785ea53a09d670128`; the earlier Phase 8 APK
hash remains historical evidence in the Phase 8 ledger.

On `baseball_16k_api35` (API 35, `getconf PAGESIZE=16384`, 1080×2400, density 420), the final
installed package `com.solkim.baseball.android.compose.dev` resolved to
`com.solkim.baseball.android.MainActivity`. Final setup and tutorial screenshots/XML were
captured at font scales 1.0, 1.3, 1.5, and 2.0, including 200% scrolled content; the saved tutorial
route was reopened after force-stop at revision 3 with `highSchool.beginTutorial` retained. The
product-surface scan artifact is
`artifacts/android-compose/phase8-emulator-2026-08-14/36-product-surface-scan.txt`, SHA-256
`ce3e1289eb21d2f9934576f4978a92e3db26208e0144346e859bf98803199671`; it reports no P IDs,
`nativeShadowReadOnly`, payload/hash/migration/Phase 7 labels, developer browser, retired Daily
copy, or P-023 in the captured product hierarchy. The app-scoped `pm clear` used for the final
cold-start setup capture affected only the `.compose.dev` emulator fixture, not the worktree or
production save.

Phase 8 final gates: focused `Phase8ScreenProjectionTest` green; full Android `test`, lint,
`assembleDebug`, and `assembleDebugAndroidTest` green; connected `Phase8ProductSemanticsTest`
green 2/2 on the existing AVD; `npm run report:android:fixtures` green; Swift 377/377; copy/IP,
Korean-copy, dialogue, assets, Unity static 447/447, and Unity/reference gates green for their
scopes. The full Unity batch remains nonzero only for the two existing dirty presentation
assertions named below, and `npm run check:android:unity` remains blocked by the existing injected/
omitted `google-services.json` release contract. Production package/save writes remain disabled,
the bounded debug repository remains `nativeShadowReadOnly`, and Unity remains trajectory-only.

## Remaining plan phases

Phase 7, Phase 8, and Phase 9 are green for their documented implementation and API35/16KiB
emulator scopes. Phase 10 is verified only for the internal package rehearsal documented above;
the production RC boundary remains explicit. Phase 11 command authority is now on the C# v1
wire (JVM-verified). Phase 11 CI/device/Play-upload lanes and Phase 12 legacy removal remain open.
The Play-prep source surface and RC scripts are in place; they do not authorize an upload.
`apps/android-unity` stays the oracle; the debug `.compose.dev` package remains
`nativeShadowReadOnly`. The production package can now persist HighSchool/setup/pitch/analytics/Pro
commands onto the frozen C# save, but that is not a Play-ready RC.
