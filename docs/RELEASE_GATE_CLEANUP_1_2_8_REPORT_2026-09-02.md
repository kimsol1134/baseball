# 1.2.8 릴리스 게이트 정리 보고

구현: grok-4.6. 스펙: `docs/RELEASE_GATE_CLEANUP_1_2_8_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음. 픽스처 재생성 없음. 시뮬레이터는 부팅된 iPhone 17만 재사용.

## 0. 규칙 준수

- 워킹트리의 1.2.7 + 프로 주간 결정 훅 변경을 되돌리지 않았다.
- 단언을 약화하거나 테스트를 삭제하지 않았다. 테스트 수정은 아래 1.2·1.3에만 있고, 각각 폐기된 경로/헬퍼를 가리키거나 엔진 커밋먼트 미러가 어긋난 경우다.
- `swift-pro-career-oracle-v1/v2.json`, `simulate_pitch_golden.json`, `swift-simulation-engine-golden-v1.json`은 건드리지 않았다. 프로 주간 루프에 RNG를 넣지 않았다.
- 주간 결정 훅의 생성·만료·후속 카드 동작(`ProCareer.swift` 로직, v9 게이트, planWeek 스트림)은 바꾸지 않았다. 주석 한 줄만 정식 용어로 고쳤다.
- ko/en/ja 카탈로그를 줄이지 않았다. 실존 구단·선수명을 넣지 않았다.

## 1. 실패 항목별 원인·조치·근거

### 1.1 iOS `LayerBoundaryTests.testFeatureViewsDoNotCallJourneyRuleEngines`

원인: Features 소스가 `ProCareerEngine.`을 직접 호출했다.

- `ProWeeklyPlanView.swift` — `liveClimate`
- `ProImportantGameIntro.swift` — `usesFinalSeriesRules`
- `PitchScenario.swift` — `usesFinalSeriesRules`, `liveBatterOffset`

조치: `CareerDisplayRules`에 프로젝션 3개를 두고 `MobileCareerStore`가 그것을 위임한다. 뷰와 `PitchScenario`는 `CareerDisplayRules`만 쓴다. 엔진 계산은 그대로다.

### 1.2 iOS `LocalizationBoundaryTests.testBoundedCardsHaveExplicitSemanticSourceBoundaries`

원인: `ReminderNudgeCard`는 `CareerTelemetry.logOnce(...)`를 쓰는데, 테스트는 폐기된 `GameAnalytics.logOnce(...)`를 요구했다. `LayerBoundaryTests`가 Features에서 `GameAnalytics.`를 금지한다.

조치: 테스트를 현재 계약인 `CareerTelemetry.logOnce(.reminderOfferShown, ["source": "after_first_game"])`로 맞췄다. 알림 노출 이벤트와 `source` 값은 그대로다.

근거: 뷰/문구가 사라진 것이 아니라 플랫폼 분석 직접 호출이 `CareerTelemetry` 경계로 옮겨진 폐기 계약이다.

### 1.3 iOS 여정·투자 소스 스캔 테스트 4건

대상:

- `ProCareerJourneyStoreTests.testOfferUIHasStableAccessibilityAndRetainsCurrentGoalByDefault`
- `ProCareerJourneyStoreTests.testJourneySurfacesHaveStableAccessibilityRoots`
- `ProContractInvestmentSurfaceTests.testInvestmentAccessibilityAndMediaContentContracts`
- `ProContractInvestmentSurfaceTests.testInvestmentPresentationExposesBenefitsAndKeepsMoney`

원인: 접근성 ID와 저장된 프로젝션은 뷰에 남아 있는데, 인자 있는 `resolve` 호출은 `ProFeatureCopy`로 빠져 있었다. 소스 스캔이 옛 인라인 키 문자열만 보았다.

조치:

- 결산 화면이 `settlement.teamLegacyBefore` / `teamLegacyAfter`를 헬퍼에 넘기도록 바꿨다. 저장된 프로젝션을 화면이 직접 읽는다.
- 스캔 목록에 `ProFeatureCopy.swift`를 넣었다 (`contractOfferOutlookLine`, `contractOfferDuration, arguments:`, `journeySettlementMerchandiseTier`, `.offseasonInvestmentPitchLabBenefit`, `decisionTiming(for: choice, ...)`).
- 카드 순서 단언의 레거시 마커를 `.journeySettlementLegacy`에서 `ProSeasonSettlementCopy.legacy`로 바꿨다. 화면 순서는 팀 기록 → 레거시 → 목표 → 연봉 → 응원상품 그대로다.

근거: 테스트가 리팩터링으로 프레젠테이션 헬퍼로 옮긴 문구 조립을 옛 뷰 파일에서 찾고 있었다. 접근성 ID와 카드 순서 단언은 유지했다.

### 1.4 `npm run check:copy`

원인: 주석의 비공식 용어.

- `ProCareer.swift` — `감독 신뢰` → `감독의 믿음`
- `ProContractMarketRules.swift:980` — `무브먼트` → `변화구`

조치: 주석만 정식 용어로 고쳤다. 런타임 문자열은 그대로다.

### 1.5 `npm run check:ios-localization`

원인: `RecordView.swift` 포스트시즌 박스스코어 `Text(line)`이 dynamic_text_path로 잡혔다.

조치: 다른 기록 줄과 같이 `Text(verbatim: line)`으로 바꿨다. 문구는 이미 `ProCareerPresentation.postseasonDirectLine`이 만든 resolved copy다.

### 1.6 `CareerSignatureLegacyTests` 4건 (`invalidPitcherLab("career state or phase is invalid")`)

원인: `rewritingState`의 `testCommitment`이 엔진 `commitment(_:)`와 어긋났다. 엔진은 투수연구소 진행 유지 이후 `mastery`·`repertoire`·`rebirth_echo`·`lineage_loadout`을 조건부로 넣는데, 테스트 헬퍼는 빠뜨렸다. v3로 다시 서명한 스냅샷이 엔진 검증에서 거절됐다.

해당 테스트:

- `testV3CoreListeningKeepsTheExactLegacyArchetypeEffects`
- `testV4StaminaTrainingNeverWorsensZeroCostPitchWhileV3RemainsExact`
- `testV3LoadNormalizationPreservesDraftForecastAndExactResolution`
- `testV3ImportantGameDoesNotApplyV4GrowthOrSequenceTrust`

조치: `testCommitment`에 엔진과 같은 순서의 조건부 토큰을 넣었다. v3 결과 바이트 동일 단언은 그대로다. 엔진 커밋먼트 공식은 바꾸지 않았다.

### 1.7 `DraftConclusionPresentationTests.testPresentationLookupCannotChangeDraftPhaseSeedHashCommitmentOrJSON`

원인: 같은 스냅샷을 `JSONEncoder()`로 두 번 인코드하면 키 순서가 비결정적이라 길이만 같고 바이트가 달랐다 (`"14683 bytes" != "14683 bytes"`).

조치: 스펙대로 `encoder.outputFormatting = [.sortedKeys]`를 테스트 인코더에 적용했다. 드래프트 조회가 seed/hash/commitment를 바꾸면 안 된다는 단언은 그대로다.

### 1.8 `RPCServerTests.testPitcherLabStartAndTrainingRoundTrip` 직후 시그널 10

원인: `~/Library/Logs/DiagnosticReports/xctest-2026-09-02-110745.ips`. `EXC_BAD_ACCESS` / `SIGBUS` (code 10). 프레임은 `outlined destroy of [PitcherLabEvent]` → `_swift_release_dealloc`. 발생 지점은 `RPCServerTests.swift:201`의 `XCTAssertEqual`. 기존 `PitcherLabSnapshot` / `HighSchoolCareerSnapshot`과 같은 Swift 6.3 거대 값 타입 destroy 결함이다.

조치: `PitcherLabEvent`를 `final class`로 박싱했다. 프로퍼티는 전부 `let`, Codable JSON 모양은 동일, `==`는 필드 비교. 테스트 `--skip` 없음.

## 2. 게이트 원문 결과

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`. 새로 만들지 않았다.

### 2.1 `swift test --package-path packages/simulation-core`

종료 코드 0.

```
Test Suite 'BaseballSimulationPackageTests.xctest' passed at 2026-09-02 12:04:37.829.
	 Executed 534 tests, with 1 test skipped and 0 failures (0 unexpected) in 465.934 (465.972) seconds
Test Suite 'All tests' passed at 2026-09-02 12:04:37.830.
	 Executed 534 tests, with 1 test skipped and 0 failures (0 unexpected) in 465.934 (465.974) seconds
WAVE5_DISTRIBUTION seeds=1000 seasons=20 negative_funds=0 duplicate_finance=0 duplicate_settlement=0 contractless_active_seasons=0 season3_before_fan100=0
```

`RPCServerTests.testPitcherLabStartAndTrainingRoundTrip` 포함 스위트 완주. 시그널 10 없음.

### 2.2 `swift test --package-path packages/ios-layers`

종료 코드 0.

```
Test Suite 'BaseballIOSLayersPackageTests.xctest' passed at 2026-09-02 11:56:22.768.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.007 (0.008) seconds
Test Suite 'All tests' passed at 2026-09-02 11:56:22.768.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.007 (0.009) seconds
```

### 2.3 `npm run check`

종료 코드 0. 하위 단계 마지막 줄:

디자인 시스템:

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

copy:

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

balance:

```
밸런스 불변식 검사 통과: 분포·적응·능력축·체력·시작 청사진·등판 단위 확인
```

test:swift:

```
Test Suite 'All tests' passed at 2026-09-02 12:17:24.159.
	 Executed 534 tests, with 1 test skipped and 0 failures (0 unexpected) in 470.795 (470.841) seconds
```

test:web:

```
 Test Files  30 passed (30)
      Tests  103 passed (103)
   Start at  12:17:24
   Duration  668ms (transform 1.43s, setup 0ms, import 2.19s, tests 170ms, environment 904ms)
```

build:web:

```
✓ built in 132ms
```

test:tauri:

```
test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.02s
```

check:tauri:

```
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 12.39s
```

### 2.4 개별 정적·스모크 게이트

`npm run check:ios-localization` 종료 코드 0.

```
iOS localization release check passed: 3695 catalog entries and zero pending surfaces
```

`npm run check:copy` 종료 코드 0.

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

`npm run check:balance` 종료 코드 0.

```
밸런스 불변식 검사 통과: 분포·적응·능력축·체력·시작 청사진·등판 단위 확인
```

`npm run run:pro-career:distribution:smoke` 종료 코드 0.

```
PRO_CAREER_DISTRIBUTION output=artifacts/analysis/pro-career-wave6/swift-distribution-smoke.json valid=true failures=
```

### 2.5 iOS BaseballIOSTests

`cd apps/ios && xcodegen generate && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO`

종료 코드 0. `project.yml`은 이 작업에서 바꾸지 않았다. 게이트 명령에 따라 `xcodegen generate`는 실행했다.

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 12:07:21.394.
	 Executed 520 tests, with 0 failures (0 unexpected) in 108.975 (109.102) seconds
Test Suite 'All tests' passed at 2026-09-02 12:07:21.395.
	 Executed 520 tests, with 0 failures (0 unexpected) in 108.975 (109.103) seconds
** TEST SUCCEEDED **
```

스펙의 519+ 전부 통과. 한 번에 xcodebuild 하나만 돌렸다.

## 3. 남은 실패

없음. 섹션 2 게이트는 모두 종료 코드 0.
