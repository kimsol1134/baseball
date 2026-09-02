# 프로 주간 결정 훅 구현 보고 (2026-09-02)

구현: grok-4.6. 스펙: `docs/PRO_WEEKLY_DECISION_HOOK_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음.

## 변경 파일

이 작업에서 직접 손댄 파일만 적는다. 워킹트리의 1.2.7 미커밋 변경은 그대로 두었다.

### simulation-core
- `packages/simulation-core/Sources/SimulationCore/ProCareerModels.swift` — 타입 4종, modifier/follow-up 모델, 스냅샷 Optional 필드, `StartProCareerParams.proRulesVersion`
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` — rules v9 게이트, 주간 결정 생성, 임시 효과, 3주 후속, commitment
- `packages/simulation-core/Sources/SimulationCore/ProCareer+Journey.swift` — 시즌 롤오버 시 modifier/follow-up 비움
- `packages/simulation-core/Sources/ProCareerFixtureExporterV2/main.swift` — 새 커리어를 `proRulesVersion: 8`로 명시 지정
- `packages/simulation-core/Tests/SimulationCoreTests/ProWeeklyDecisionHookTests.swift` — 신규 수용 테스트
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerEngineTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerLegacyRulesTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerRetiredNumberBalanceTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerArcTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/PresentationCopyTokenTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/ProOffseasonInvestmentRulesTests.swift`

### iOS
- `apps/ios/Sources/Application/MobileCareerStore+Season.swift` — `cadence`, `decision_type`
- `apps/ios/Sources/Platform/GameAnalytics.swift` — `pro_weekly_decision_followup_shown`
- `apps/ios/Sources/Features/Pro/ProSeasonDecisionView.swift` — 3주 결정 eyebrow, 즉시/3주 뒤 분리
- `apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift` — 결정 결과 카드
- `apps/ios/Sources/Presentation/ProCareerPresentation.swift`
- `apps/ios/Sources/Presentation/ProFeatureCopy.swift`
- `apps/ios/Sources/Presentation/Localization/ProCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/GameContent.xcstrings`
- `apps/ios/Sources/Presentation/Localization/Localizable.xcstrings`
- `apps/ios/Tests/LocalizationCoverageTests.swift`
- `apps/ios/Tests/ProSeasonDecisionTests.swift`
- `docs/localization/ios-copy-schema.json` — `inventory:ios-localization --write`로 카탈로그 재생성

`apps/ios/project.yml`은 이 작업에서 바꾸지 않았다. `xcodegen generate` 불필요.

## 동작 요약

- `currentRulesVersion = 9`. `usesWeeklyDecisionRules`는 `proRulesVersion >= 9`.
- v9 결정 주: 3·6·9·12·15·18·21, 시즌 최대 7회. 부상·중요경기 주는 건너뛰고 이월하지 않음.
- v8 이하: `seasonDecisionWeeks = [6, 13, 20]`, 최대 3회. `planWeek` RNG 스트림에 `next*()` 추가 없음.
- 신규 타입 `rotationPush` / `newPitchTrial` / `farmReset` / `veteranMentor`는 선택지 2개. formCrisis·agingCrossroads·mediaOpportunity 우선순위는 유지. media 슬롯은 규칙 버전의 결정 주 집합에서 해시.
- 선택 A는 `followUpResolvedWeek = week + 3`과 `activeDecisionModifiers`를 남긴다. `planWeek`가 `week >= expiresWeek`이면 임시 효과를 해제하고 `resolvedFollowUps`에 붙인다. 시즌 롤오버에서 둘 다 비운다.
- 스키마 버전은 5 유지. `schemaVersion(for:)` 미변경.

## 밸런스 수치

스펙 초안 수치 그대로 넣었다. 조정 없음.

| 타입 | A | B | 임시 |
|---|---|---|---|
| rotationPush | 피로 +12, 감독의 믿음 +4, 등판 +1 | 감독의 믿음 −2 | injuryPressureFloor 80 |
| newPitchTrial | 제구 −3, 대상 구종 프로필 +2 | 대상 구종 프로필 +1 | 3주 후 제구 복구 |
| farmReset | 피로 −25, 구위/제구 낮은 쪽 +2, 감독의 믿음 −6, 등판 0 | 감독의 믿음 −3 | 만료 시 믿음 +4 |
| veteranMentor | 변화구 +1, 포수와의 호흡 +5 | 포수와의 호흡 −2 | 훈련 효율 800‰ |

`npm run check:balance`와 `npm run run:pro-career:distribution:smoke`는 이번 필수 게이트에 없어 실행하지 않았다.

## 픽스처

- `swift-pro-career-oracle-v1.json`: 재생성하지 않음. `testWave0CurrentSwiftNextSeedsMatchTheV1GoldenFixture` 통과. `seasonDecisionWeeks`/`maximumSeasonDecisions` 공개 상수는 v8 값 유지.
- `swift-pro-career-oracle-v2.json`: 재생성하지 않음. v2 exporter는 `start(..., proRulesVersion: 8)`로 스탬프한다.
- `simulate_pitch_golden.json`: 미변경.

## 실행한 테스트·게이트

시뮬레이터: 스펙의 `iPhone 17 Pro`는 없고 부팅된 `iPhone 17`만 있어 그것을 썼다. 새 시뮬레이터는 만들지 않았다.

### 통과

- `swift test --package-path packages/ios-layers` — 13 tests, 0 failures.
- `ProWeeklyDecisionHookTests` 7/7.
- `ProCareerEngineTests` 39/39.
- `ProCareerLegacyRulesTests`, `ProCareerArcTests`, `ProCareerRetiredNumberBalanceTests`, `ProCareerBootstrapCharacterizationTests`(v1 golden 포함).
- iOS `LocalizationCoverageTests` 전부, `ProSeasonDecisionTests` 전부, `JapaneseLocalizationTests` 전부.

### 실패 (이번 변경과 무관한 것으로 판단, 고치지 않음)

`npm run check:copy`:

```
문구 품질 검사 실패 (2)
- packages/simulation-core/Sources/SimulationCore/ProCareer.swift:1850 — 감독 신뢰
- packages/simulation-core/Sources/SimulationCore/ProContractMarketRules.swift:980 — 무브먼트
```

둘 다 기존 주석이다. `ProContractMarketRules.swift`는 이 작업에서 편집하지 않았다.

`npm run check:ios-localization`:

```
iOS localization release check FAILED
- pending inventory: 0
- direct legacy display paths: 1
  - apps/ios/Sources/Features/Shell/RecordView.swift:459 (dynamic_text_path)
- catalog entries checked: 3689
```

`RecordView.swift:459`은 이 작업에서 만지지 않은 포스트시즌 `Text(line)` 경로다.

`swift test --package-path packages/simulation-core` (전체 스위트, 종료 코드 1):

```
/Users/solkim/Dev/baseball/packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift:2591: error: -[SimulationCoreTests.CareerSignatureLegacyTests testV3CoreListeningKeepsTheExactLegacyArchetypeEffects] : failed: caught error: "invalidPitcherLab("career state or phase is invalid")"
/Users/solkim/Dev/baseball/packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift:2591: error: -[SimulationCoreTests.CareerSignatureLegacyTests testV3ImportantGameDoesNotApplyV4GrowthOrSequenceTrust] : failed: caught error: "invalidPitcherLab("career state or phase is invalid")"
/Users/solkim/Dev/baseball/packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift:2591: error: -[SimulationCoreTests.CareerSignatureLegacyTests testV3LoadNormalizationPreservesDraftForecastAndExactResolution] : failed: caught error: "invalidPitcherLab("career state or phase is invalid")"
/Users/solkim/Dev/baseball/packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift:2591: error: -[SimulationCoreTests.CareerSignatureLegacyTests testV4StaminaTrainingNeverWorsensZeroCostPitchWhileV3RemainsExact] : failed: caught error: "invalidPitcherLab("career state or phase is invalid")"
/Users/solkim/Dev/baseball/packages/simulation-core/Tests/SimulationCoreTests/DraftConclusionPresentationTests.swift:84: error: -[SimulationCoreTests.DraftConclusionPresentationTests testPresentationLookupCannotChangeDraftPhaseSeedHashCommitmentOrJSON] : XCTAssertEqual failed: ("14683 bytes") is not equal to ("14683 bytes")
error: Process '/Applications/Xcode.app/Contents/Developer/usr/bin/xctest ...' exited with unexpected signal code 10
```

시그널 10은 `RPCServerTests.testPitcherLabStartAndTrainingRoundTrip` 시작 직후 xctest가 죽은 것이다. 고교/RPC 경로이며 프로 주간 결정과 무관하다.

iOS `xcodebuild test -scheme BaseballIOS -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BaseballIOSTests CODE_SIGNING_ALLOWED=NO`:

```
Executed 519 tests, with 9 failures (0 unexpected)

Failing tests:
	LayerBoundaryTests.testFeatureViewsDoNotCallJourneyRuleEngines()
	LocalizationBoundaryTests.testBoundedCardsHaveExplicitSemanticSourceBoundaries()
	ProCareerJourneyStoreTests.testJourneySurfacesHaveStableAccessibilityRoots()
	ProCareerJourneyStoreTests.testOfferUIHasStableAccessibilityAndRetainsCurrentGoalByDefault()
	ProContractInvestmentSurfaceTests.testInvestmentAccessibilityAndMediaContentContracts()
	ProContractInvestmentSurfaceTests.testInvestmentPresentationExposesBenefitsAndKeepsMoney()
```

원문:

```
apps/ios/Tests/LayerBoundaryTests.swift:32: error: ... XCTAssertFalse failed
apps/ios/Tests/LocalizationBoundaryTests.swift:103: error: ... XCTAssertTrue failed
apps/ios/Tests/ProCareerJourneyStoreTests.swift:549: error: ... XCTAssertTrue failed
apps/ios/Tests/ProCareerJourneyStoreTests.swift:209: error: ... XCTAssertTrue failed
apps/ios/Tests/ProCareerJourneyStoreTests.swift:211: error: ... XCTAssertTrue failed
apps/ios/Tests/ProContractInvestmentSurfaceTests.swift:142: error: ... XCTAssertTrue failed
apps/ios/Tests/ProContractInvestmentSurfaceTests.swift:204: error: ... XCTAssertTrue failed
apps/ios/Tests/ProContractInvestmentSurfaceTests.swift:210: error: ... XCTAssertTrue failed
apps/ios/Tests/ProContractInvestmentSurfaceTests.swift:215: error: ... XCTUnwrap failed: expected non-nil value of type "Range<Index>"
```

소스 스캔 계약이다. `ProCareerEngine.` 금지는 기존 `ProWeeklyPlanView`/`ProImportantGameIntro`에도 있고, 정산·오퍼·투자 문자열은 이 작업이 만지지 않은 화면이다. 1.2.7 미커밋 워킹트리와 테스트가 이미 어긋난 상태로 본다.

## 미해결

- 밸런스/분포 스모크 미실행. 밴드가 깨지면 수치만 조정하면 된다.
- v9 미디어 슬롯은 주간 결정 주 집합에서 고른다. v8은 기존 6·13·20.
- Android Kotlin 포팅은 스펙 범위 밖.
- 위 실패들은 고치지 않았다.

## 수정 라운드 2 (PM 검수 반영)

커밋·stash·reset·checkout 없음. `planWeek`에 RNG `next*()` 추가 없음. v8 골든 픽스처 재생성 없음.

### 1. rotationPush 등판 +1 총량

원인: `extraOutingChance: 1`을 활성 주마다 `outings`에 더해서, 선발이 3주 동안 매주 2선발(총 6등판)을 던졌다. 4일 로테이션은 3주 창에서 선발 +1이어야 한다.

조치: `ProDecisionModifier.extraOutingsGranted`를 추가했다(Optional, `decodeIfPresent ?? nil` → 0). 부상·회복 주가 아닌 첫 등판 주에 남은 할당만 소모하고, 창 전체에서 추가 등판은 1로 멈춘다. `injuryPressureFloor`와 `extraOutingChance` 할당 값은 만료까지 유지한다. 커밋먼트 문자열에 granted 값을 넣었다.

`ProWeeklyDecisionHookTests.testRotationPushFollowUpExpiresAfterThreeWeeksAndClearsModifier`가 창 동안 부상 바닥 80을 유지하고, 주간 자동 등판의 extra outing 합이 1이며, 선발의 `starts == games`를 단언한다.

rotation_push A 선택 문구(ko/en/ja)를 "+1 start over three weeks"에 맞게 고쳤다.

- ko: `앞으로 3주 동안 선발 등판이 1경기 늘고 피로와 감독의 믿음이 함께 움직입니다.`
- en: `You get one extra start over the next three weeks, with more fatigue and manager faith.`
- ja: `これから3週間で先発が1試合増え、疲労と監督の信頼が一緒に動きます。`

### 2. `check:copy` — `감독 신뢰`

`ProCareer.swift`의 `careerChallengeRulesVersion = 8` 주석이다. v8 도전 규칙(1.2.7 미커밋) 설명이며, 이번 주간 결정 훅에서 작성한 문구가 아니다. HEAD에도 `currentRulesVersion = 7`만 있고 이 주석은 없다. 주간 결정 작업은 `currentRulesVersion` 8→9와 `weeklyDecisionRulesVersion = 9`만 추가했다. 지시대로 주석은 그대로 두었다. 줄 번호는 planWeek 수정으로 1850→1857로 밀렸다.

`ProContractMarketRules.swift:980 — 무브먼트`도 이 라운드에서 편집하지 않았다.

### 3. 후속 뉴스·결정 요약 현지화

기존 결정 뉴스는 두 갈래다.

- 미디어: 스냅샷에 `content.pro-media-opportunity.resolved.*` 키를 넣고 `ProCareerPresentation.news`가 키로 해석한다.
- 그 외 주간/기후/부상 뉴스: 스냅샷은 한국어, `news()`가 알려진 접두·정규식으로 en/ja 카탈로그에 매핑한다. 레거시 6종 결정 뉴스(`제목 · 선택 — 효과`)는 `news()`에 매핑이 없고, `storeSummary`만 `" — "`로 처리한다.

이번 훅의 `"시즌 결정 · N주차"`와 `"결정 결과 · …"`는 미디어 키가 아니라 한국어 스냅샷이므로, 기후·주차 뉴스와 같이 presentation 매핑을 추가했다. 관련 없는 뉴스 줄은 건드리지 않았다.

추가 키(ko/en/ja): `content.pro-news.weekly-decision`, `content.pro-news.decision-followup.{generic,rotation-push,new-pitch-trial,farm-reset,veteran-mentor}`.

`ProSeasonDecisionTests.testWeeklyDecisionSnapshotNewsLocalizesForEnglishAndJapanese`로 en/ja 해석을 고정했다.

### 실행 결과 (원문)

`swift test --package-path packages/simulation-core --filter "ProWeeklyDecisionHookTests|ProCareerBootstrapCharacterizationTests|ProCareerLegacyRulesTests|ProCareerEngineTests"` — 종료 코드 0.

```
Test Suite 'ProCareerBootstrapCharacterizationTests' passed at 2026-09-02 11:34:00.165.
	 Executed 6 tests, with 1 test skipped and 0 failures (0 unexpected) in 3.987 (3.988) seconds
Test Suite 'ProCareerEngineTests' passed at 2026-09-02 11:37:19.121.
	 Executed 39 tests, with 0 failures (0 unexpected) in 198.953 (198.956) seconds
Test Suite 'ProCareerLegacyRulesTests' passed at 2026-09-02 11:37:19.140.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.018 (0.018) seconds
Test Suite 'ProWeeklyDecisionHookTests' passed at 2026-09-02 11:37:21.764.
	 Executed 7 tests, with 0 failures (0 unexpected) in 2.624 (2.625) seconds
Test Suite 'Selected tests' passed at 2026-09-02 11:37:21.764.
	 Executed 66 tests, with 1 test skipped and 0 failures (0 unexpected) in 205.581 (205.588) seconds
```

`npm run check:copy` — 종료 코드 1. 이번 라운드에서 고치지 않음.

```
문구 품질 검사 실패 (2)
- packages/simulation-core/Sources/SimulationCore/ProCareer.swift:1857 — 감독 신뢰
- packages/simulation-core/Sources/SimulationCore/ProContractMarketRules.swift:980 — 무브먼트
```

`npm run check:ios-localization` — 종료 코드 1. `RecordView.swift:459`은 이 작업에서 만지지 않음. 카탈로그는 3695항목(신규 뉴스 키 포함).

```
iOS localization release check FAILED
- pending inventory: 0
- direct legacy display paths: 1
  - apps/ios/Sources/Features/Shell/RecordView.swift:459 (dynamic_text_path)
- catalog entries checked: 3695
```

iOS (한 번의 xcodebuild, 부팅된 iPhone 17, `CODE_SIGNING_ALLOWED=NO`):

```
xcodebuild test -project Baseball.xcodeproj -scheme BaseballIOS -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BaseballIOSTests/ProSeasonDecisionTests -only-testing:BaseballIOSTests/LocalizationCoverageTests CODE_SIGNING_ALLOWED=NO
```

```
Test Suite 'LocalizationCoverageTests' passed at 2026-09-02 11:38:18.738.
	 Executed 37 tests, with 0 failures (0 unexpected) in 0.513 (0.521) seconds
Test Suite 'ProSeasonDecisionTests' passed at 2026-09-02 11:38:36.732.
	 Executed 25 tests, with 0 failures (0 unexpected) in 17.989 (17.994) seconds
** TEST SUCCEEDED **
```
