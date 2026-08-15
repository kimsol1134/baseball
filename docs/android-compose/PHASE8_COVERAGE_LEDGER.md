# Phase 8 Compose coverage ledger

Evidence captured 2026-08-14 KST for
`ANDROID_COMPOSE_SHELL_UNITY_PITCH_MIGRATION_PLAN_2026-08-13.md`. This ledger is an
implementation and evidence index, not product copy. The P identifiers remain in this
developer artifact only; they are not rendered by the Compose shell.

## Contract and evidence vocabulary

- `JVM-PROJECTION`: a valid aggregate fixture reaches the route, the authoritative Kotlin
  projection is validated, and every enabled action carries an exact typed command payload whose
  codec round-trips.
- `JVM-COMMAND`: the test captures the rendered payload and dispatches that exact envelope; it does
  not reconstruct the command after the callback.
- `COMPOSE-SEMANTICS`: the actual `Phase8Shell` renderer is checked for product text, content
  descriptions, roles/actions, disabled states, safe-area padding, and 100/130/150/200% wrapping.
- `EMULATOR`: actual API 35, 16 KiB AVD evidence. The device captures are representative of the
  shared product renderer and meaningful saved routes; they are not falsely presented as 29
  separate device sessions.
- `PHASE9-NATIVE`: platform SDK actions and semantic guards implemented in Phase 9 are described by
  their authoritative source, durable receipt, and explicit external boundary; no fake success is
  claimed.

The product route is derived from `GameAggregateState` by
`Phase8ScreenProjection.preferredScreen` on cold start, process restart, and after successful
dispatch. `MainActivity` owns one application-scoped `KotlinGameStore`; it drops any manual route
after a successful command and recomputes from the committed state. `P-023` has no enum, no product
entry, and legacy Daily routes normalize to the preferred current route.

## Screen ledger

| Screen | Valid-state projection fixture | Exact command-payload coverage | Semantics/layout and screenshot evidence | Phase 9 boundary |
|---|---|---|---|---|
| P-001 Opening | `Phase8ScreenProjectionTest.productCoverageExcludesRetiredDailyAndFailsClosedForOffStateScreens`; real initial aggregate and restart fixture | `enterSetup` and typed `view` payload codec round-trip in `realHighSchoolJourneyProjectsEveryHighSchoolAndMetaScreenWithCapturedCommands` | `Phase8ProductSemanticsTest.openingUsesProductCopyAndExcludesDiagnosticMatrixContent`; final APK opening `20-final-installed.png`/XML; product-surface scan | None; opening/return is native Compose |
| P-002 Setup | Valid `OPENING → SETUP` aggregate, then real HS journey | Captured custom setup action and `HighSchool.Start` payload; invalid name disables CTA | `setupFieldsAndActionsRemainReadableAtEveryRequiredFontScale`; final APK `27-setup-final-{100,130,150,200}` plus 200% scrolled captures | Notification/reset controls are not on setup; no Phase 9 dependency |
| P-003 Prologue | Valid HS `PROLOGUE` before and after tutorial | `beginTutorial` and `completeTutorial`; exact payloads are dispatched from the projection | Final APK `17-prologue-final-{100,130,150,200}` and XML; 200% scroll evidence; TalkBack content descriptions | None |
| P-004 Pitch Tutorial | Valid active HS `PROLOGUE` with tutorial started and nonterminal tutorial pitch | `ReservePitch → StartPitch → CommitPitch → ConsumePitch → MarkTerminal → CompletePitch`; Phase 7 controller/restart/terminal tests | Final APK `25-tutorial-final-{100,130,150,200}` and `26-tutorial-final-200-scrolled`; final Korean trajectory copy; Unity remains full-screen trajectory-only | Phase 9 platform feedback is not exposed; pitch renderer boundary remains Unity-only |
| P-005 School Selection | Valid HS after non-counting tutorial completion and `CompleteTutorial` | `ChooseSchool` candidate payloads are captured and codec-checked | HS journey projection/accessibility contract; common shell font/device evidence; selected route is unreachable before the committed phase | None |
| P-006 Training | Valid selected-school HS `TRAINING` fixture | Six focus/target actions carry exact `Training` commands; block auto-advance is exercised by the vertical journey | Projection accessibility contract plus representative 200% shell captures; state changes only after commit | None |
| P-007 Relationship | Valid HS `RELATIONSHIP` fixture | Relationship response payloads are captured and round-tripped | Projection/accessibility contract; common Compose card semantics and device wrapping evidence | None |
| P-008 Important Game | Valid HS important-game boundary, with and without active pitch | `openImportantGame`, `nextImportantPitch`, and saved pitch payloads; suspend/abandon and count-once remain in Phase 7 tests | Phase 7 emulator in-flight/Postgame evidence plus Phase 8 projection; Compose route is the authoritative pre/postgame surface | Unity is trajectory-only; no score/result authority or SDK action |
| P-009 Awakening | Valid HS `AWAKENING` after an official important game | `ChooseAwakening` exact payloads | HS journey projection/accessibility contract; Phase 7 Awakening capture and 200% shell evidence | None |
| P-010 Chapter | Valid HS `CHAPTER_REVIEW` | `AdvanceChapter` exact payload and committed-state route recomputation | HS journey projection/accessibility contract; Phase 7 chapter capture and 200% scroll evidence | None |
| P-011 High School Career | Valid selected/active HS read model | Typed read/view payload plus enabled acknowledgement actions, if present | HS journey captures a reachable model; common shell semantics/layout contract | None |
| P-012 Tournament / League | Valid HS tournament/ranking read model | Typed read/view payload and any enabled record action | Valid HS journey projection and accessibility contract; no fabricated off-state screen | None |
| P-013 Draft | Valid HS `DRAFT` before and after resolution | Exact `ResolveDraft` payload | HS journey reaches and captures Draft projection; common shell layout contract | None |
| P-014 Run Recap | Valid HS legacy candidates and frozen current-life recap | `PrepareLegacy`, candidate selection, and `FinalizeArchive` payloads | HS journey captures recap before/after selection; common renderer semantics | Share/export SDK remains outside this screen's Phase 8 scope |
| P-015 Rebirth | Valid completed/archived HS aggregate with retained archive | Typed rebirth/read payload; no arbitrary initial-state projection | HS journey reaches resulting rebirth model and validates retained archive semantics | New-life reset remains the Phase 6 journal boundary; no native SDK cutover |
| P-016 Pro Contract | Valid initial aggregate for direct Pro and linked Pro fixture | Exact direct-start and linked-start `ProCommand` payloads; preferred route changes only after commit | `realProFixturesCoverContractWeekImportantSeasonOffseasonRetirementLegacyAndRecords`; common shell semantics | None |
| P-017 Pro Week | Valid signed Pro `WEEKLY_PLAN` fixture | Exactly six weekly plan payloads plus segment-advance payload; codec round-trip | Valid Pro projection/accessibility contract; common shell 100/130/150/200 evidence | None |
| P-018 Pro Important Game | Valid signed Pro `IMPORTANT_GAME` fixture | Pro pitch reserve/start/commit/consume/terminal payload boundary; Phase 7 shared pitch tests | Valid Pro projection plus shared Compose/Unity pitch boundary evidence | Unity trajectory-only; platform SDK stays Phase 9 |
| P-019 Pro Season | Valid signed Pro `SEASON_REVIEW` fixture | Season review/decision typed payloads | Valid Pro projection/accessibility contract; no fabricated active-season state | None |
| P-020 Offseason | Valid signed Pro `OFFSEASON_DECISION` fixture | Each offseason decision payload, including retire boundary | Valid Pro projection/accessibility contract | None |
| P-021 Pro Retirement | Valid signed Pro `RETIREMENT_DECISION` fixture | Retirement payload and max-career terminal validation | Valid Pro projection/accessibility contract | None |
| P-022 Pro Legacy | Linked Pro fixture with three frozen candidates and HS settlement | Candidate selection payloads; direct Pro no-fake-archive shape is rejected/covered | Valid linked legacy projection and archive-read contract | Share/export remains disabled until Phase 9 native surface |
| P-023 retired Daily | No product state; `normalizeLegacyRoute("daily"/"P-023")` returns preferred route | Zero product action/payload; legacy normalization is tested | Static scan and Android hierarchy contain no retired Daily entry or old copy | No Phase 9 work; caller is removed, not stubbed |
| P-024 Weekly | Valid HS/Pro meta fixture with weekly board | Weekly claim/ack payloads are typed and idempotent where enabled | Valid HS and Pro projections/accessibility contract; common shell evidence | None |
| P-025 Records / League | Valid HS and completed Pro record books | Typed view payload and any enabled record action round-trip | HS/Pro valid-state projection and common renderer semantics | None |
| P-026 Achievements | Valid HS achievements/unacknowledged achievement fixture | Achievement acknowledgement payloads are exact and stale-safe | Valid HS projection/accessibility contract; Korean achievement titles only | None |
| P-027 Settings | Any valid aggregate, including initial setup | Exact settings payloads; OS notification truth is read before actionable controls | Final emulator settings capture plus Phase 9 API35 semantics; settings guidance is readable at required scales | Requestable first-game reminder offer is separate from denied/blocked settings guidance; durable truth changes are source-tagged/deduped |
| P-028 LifeCard | Valid archive with an explicitly selected frozen record | Typed archive/view payload and exact selected-record share payload/receipt scope | Valid archive projection/accessibility contract; Phase 9 viewport and chooser-race/restart tests | `player_legacy_seen` uses `archive`; share receipts remain scoped to the selected non-latest frozen record |
| P-029 Return Plan | Valid HS/Pro return-plan fixture | Prepare/dismiss return-plan payloads are exact | Valid meta projection/accessibility contract; Phase 9 reminder policy and notification truth tests | Offers require first completed game + OS `REQUESTABLE` + unasked/undeclined state; denied/blocked states only guide settings |
| P-030 Review | Valid review-reason fixture after the required career milestone | Only durable third-life, good-recap-confirm, and drafted-reveal-confirm moments can dispatch Play Review | Valid projection/accessibility contract; no generic/manual review button or route-visit caller | Native review request remains external OS/Play behavior; failure does not alter game state |

## Exact artifact hashes

Phase 8 capture APK (historical): `apps/android/app/build/outputs/apk/debug/app-debug.apk`,
SHA-256 `8c20e75582c5edd75e79c7ee1455c7aabaab034f0b171475a3053006ddfc26a3`. The current Phase 9
APK/test APK/bundle and refreshed screenshot hashes are in
[PHASE9_NATIVE_PLATFORM_EVIDENCE.md](PHASE9_NATIVE_PLATFORM_EVIDENCE.md).

Device: AVD `baseball_16k_api35`, API 35, 16,384-byte pages, 1080×2400, density 420, final
`font_scale=1.0`; launcher resolution and scan are in
[`36-product-surface-scan.txt`](../../artifacts/android-compose/phase8-emulator-2026-08-14/36-product-surface-scan.txt)
(SHA-256 `ce3e1289eb21d2f9934576f4978a92e3db26208e0144346e859bf98803199671`). The launcher is
`com.solkim.baseball.android.MainActivity`; generated Unity's launcher declaration is removed by
the app manifest.

Final setup screenshots/XML:

- 100%: PNG `5bafe72643ccd54f5700f86c0fada0dbb955bbfb0f1a51e1c0acbdf61149dd36`, XML
  `3af7eb483565d026bb6423ccae973bb49ec5cb718937271d240b7d9d73f9e4e3`.
- 130%: PNG `2b74c0d9aac71be8146c4c8136d31c9ba2825c5c808e1f089750935e4e649527`, XML
  `09a7c6270874e0c63f3d2e925572cb95e309d039b8da1daf20648e4aa5b00f11`.
- 150%: PNG `829c8bd383f86fecc063aa3fa1fe505a0e095085c40117a91cb427982d926e73`, XML
  `a457be8e127c27ae678b664b67e94b2196bb11dfae9afc2fbb986e8241d76f18`.
- 200%: PNG `ca2bb3bb71eaa92558694b4209de5d82582d65a810e0d4bdb2dcfcab402b466d`, XML
  `f07ed730ff69a4008479d7bd5e282b7c2675d67edf4b48c15acc24225fa9039f`.
- 200% scrolled: PNG `71a88bc1c1a26e04d5dbb292a43632479cb5116ea834feb7a30a00d74aca9373`, XML
  `403896207e3d95a001ab7cf92ed75c065773638c82ce2b938ec981415e863b92`.

Final tutorial screenshots/XML:

- 100%: PNG `d49a458223abcf387fe01b987235f1245c7c719d8150eaf9b344f5bb91225817`, XML
  `7a453c98d78113b6ef80047872c132600bc219d20bbfd70ad14852b7f5da47f1`.
- 130%: PNG `47725167a3a9dcf1d2294bf4505cba0b9472f8123973917b2d85667b10a95068`, XML
  `2676f65bee40be0a7ff66c3203d78a9cca18144fd8ae08887538f991ed3acd95`.
- 150%: PNG `4e97d95df0677d8f680657894d74f313bfaef3b0d2f32ee2d4371198694f3b3f`, XML
  `fe4b88a598f2f087c9502909323d1a59767a6dd2095713acf47ec387affd0d87`.
- 200%: PNG `a4b63000cd0cfd774bb4bad57db58d38736b87a7476971c7e5286bc7afe35aaf`, XML
  `2ee52dd50325e5d0f52ddb9d219ed83119a10cb7fb70da7a0071dbc10c5c057a`.
- 200% scrolled: PNG `b6501aa8c7077989127613ca30bd1d0b519b46cfdb3858b53ffb371e79ddfd73`, XML
  `55fa1436821b51a1cb899daa869d94c22a9867f8f63ff030815ff6baeb5b903c`.

Saved-route evidence includes the final cold route `28-cold-route-tutorial-final-100.png` (SHA-256
`4f46a56bf6d5ea0c0a54de3bb32e5be0714069f2b0893419a7127b29186a0c86`) and the process-restart
preferred route `35-restart-tutorial-final-100.png` (SHA-256
`82fa54ae01ed90bc3fb37e0644c05aacbd6bcd75ba16b0fc01d0fdb140562258`). The restart hierarchy
`34-restart-tutorial-manual.xml` is SHA-256
`7a453c98d78113b6ef80047872c132600bc219d20bbfd70ad14852b7f5da47f1`; the saved shadow file was
revision 3 with `highSchool.beginTutorial` before force-stop and remained revision 3 after reopen.

## Gate result and boundaries

- `Phase8ScreenProjectionTest` focused suite: green, including valid HS/Pro fixtures, 29-screen
  coverage excluding P-023, preferred-route restart, duplicate/stale boundaries, exact action and
  view payload codec round-trips, and non-challenge tutorial count behavior.
- `Phase8ProductSemanticsTest`: green on the API35 AVD (2/2); full
  `:app:connectedDebugAndroidTest`: green (2/2).
- `./gradlew test lint :app:assembleDebug :app:assembleDebugAndroidTest`: green (243 actionable
  tasks); final debug APK above. `npm run check:android:compose`: green.
- `npm run report:android:fixtures`: green. Current Swift pitch output SHA
  `37d86e69406862d434a4304f929dd8725502e4d7dc53cb9f73dddd6dd36fbcc6`, HighSchool Phase 4
  output SHA `ebcf365278b10cdcd5d56ee20a73252c8a2623ad54dd1202414225d6359c2095`, Pro output SHA
  `850ce637c48fa28b689effe52e2233961743fc1327728bdf3e12eada7f224d39`, and report SHA
  `61660ee3d2048128f75f5dad30ab636a27bb4c7d24ea7153412b13b9479259dc`.
- `swift test --package-path packages/simulation-core`: green, 377/377.
- Copy/IP/assets gates: `check:copy`, `check:copy:android:unity`, `check:korean-copy`,
  `test:korean-copy`, `check:dialogue-parity`, and `check:unity-assets` green; Unity static 447/447
  and reference compiles 0 errors/0 warnings.
- Full `npm run test:unity` remains nonzero only for the two pre-existing dirty presentation
  assertions (`MissingArtworkShowsExplicitFallbackWithoutDisablingChoice` and
  `ProductScreensCallImportedChoiceAndNarrativeArtworkLoaders`); the same run passed the core,
  application, platform, high-school, Pro, Internal-QA, all Phase 6 persistence cases, and
  PlayMode 14/14. `npm run check:android:unity` remains blocked by the pre-existing injected/
  omitted `apps/android-unity/Assets/google-services.json` release contract. Neither unrelated
  failure was masked or changed.
- Production package/save writes remain disabled. The app uses the `.compose.dev` package and a
  bounded debug shadow repository while advertising `nativeShadowReadOnly`; the legacy production
  save path is untouched. Unity remains trajectory-only.
- Phase 9 native semantic remediation is complete for the documented local scope; the detailed
  implementation, 24/24 platform tests, 7/7 connected tests, artifact hashes, and external SDK
  boundaries are in [PHASE9_NATIVE_PLATFORM_EVIDENCE.md](PHASE9_NATIVE_PLATFORM_EVIDENCE.md).
