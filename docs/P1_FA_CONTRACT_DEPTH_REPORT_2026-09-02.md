# P1-3 FA 다년 계약·계약금·잔류 협상·연봉 사용처 구현 보고

구현: grok-4.6. 스펙: `docs/P1_FA_CONTRACT_DEPTH_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음. 픽스처 재생성 없음. 시뮬레이터는 부팅된 iPhone 17만 재사용.

HEAD: 822b1c85 chore(core): reserve rules version 10 gates for contract depth and national team.

## 0. 규칙 준수

- 새 동작은 전부 `ProCareerEngine.usesContractDepthRules(state)` (`proRulesVersion ≥ 10`) 뒤에 두었다.
- `makeFreeAgencyMarket` / `makeRenewalMarket` / `isValid` 기본 인자는 레거시(3오퍼·연수 ≤ 4·계약금 nil). 익스포터는 `usesContractDepth: false`를 명시한다.
- `swift-pro-career-contract-wave3-oracle-v1.json`과 `wave3OfferCanonical`은 바이트 동일. Kotlin 테스트·픽스처는 건드리지 않았다.
- 골든 픽스처 재생성 없음. `planWeek` RNG에 `next*()`를 넣지 않았다. 시장 생성은 `StableHash`만 사용한다.
- 저니 신규 필드(`interest`, `counterOffer`)는 Optional + `decodeIfPresent`. `canonicalToken`은 두 필드가 nil이면 기존 문자열과 같다.
- ko/en/ja 카탈로그. 실존 구단명 없음. 뷰는 `CareerDisplayRules` / 스토어 프로젝션만 쓴다. 투구 슬라이더 코드는 접근하지 않았다.
- 예약 파일(`ProPostseason.swift`, `PitchScenario.swift`, `ProImportantGameIntro.swift`, `MobileCareerStore+ImportantGame.swift`, `CareerFlowView.swift` importantGame 분기, `militaryCompleted`)은 건드리지 않았다. `ProCareerPhase` 케이스를 추가하지 않았다.
- 테스트 삭제·단언 약화 없음. 현재 버전 엔진 FA 테스트 1건은 v10 4오퍼를 반영하도록 기대값을 맞췄고, 레거시 3오퍼는 팩토리·v9 핀 테스트로 유지한다.

## 1. 변경 파일

이 작업에서 직접 손댄 파일만 적는다. 워킹트리의 다른 미커밋·미추적 산출물은 그대로 두었다.

### simulation-core
- `packages/simulation-core/Sources/SimulationCore/ProCareerJourney.swift` — `longTerm`, `ProClubInterest*`, `ProContractCounter*`, 오퍼/시장 Optional 필드, 투자 2케이스, benefit 2케이스, `canonicalToken` nil 생략
- `packages/simulation-core/Sources/SimulationCore/ProCareerModels.swift` — `RequestProContractCounterParams`
- `packages/simulation-core/Sources/SimulationCore/ProContractMarketRules.swift` — v10 FA 4오퍼·계약금·관심·5년, 재계약 5년, 잔류 협상 적용, `isValid` 분기
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` — `acceptContract` 연수/계약금 가드, FA 계약금 입금, `requestContractCounter`, 장비 부상 압력 −6, 트레이너 효율 +100‰
- `packages/simulation-core/Sources/SimulationCore/ProCareer+Journey.swift` — 시장 재생성 시 규칙 버전·협상 적용, 연수 상한, 투자 2케이스, 계약금 원장 검증
- `packages/simulation-core/Sources/SimulationCore/ProRoleRequestRules.swift` — `longTerm` 계약은 보직 지원 카드 숨김
- `packages/simulation-core/Sources/ProCareerFixtureExporter/main.swift` — wave3 레거시 경로 명시 고정
- `packages/simulation-core/Sources/ProCareerDistributionRunner/main.swift` — v10 FA 4오퍼·투자 후보
- `packages/simulation-core/Tests/SimulationCoreTests/ProContractDepthRulesTests.swift` — 수용 기준 1–5
- `packages/simulation-core/Tests/SimulationCoreTests/ProContractMarketRulesTests.swift` — 현재 버전 엔진 FA는 4오퍼

### iOS
- `apps/ios/Sources/Application/CareerDisplayRules.swift` — 깊이 규칙·보증 연봉·협상 가능·투자 목록
- `apps/ios/Sources/Application/MobileCareerStore+Queries.swift` — 보증 연봉 프로젝션
- `apps/ios/Sources/Application/MobileCareerStore+Season.swift` — `requestContractCounter`, `proContractSigned` 속성
- `apps/ios/Sources/Platform/GameAnalytics.swift` — `pro_contract_counter_requested`
- `apps/ios/Sources/Features/Pro/ProContractOfferView.swift` — 관심 배지, 요구하기 시트, 계약금 줄, 4번째 카드
- `apps/ios/Sources/Features/Pro/ProOffseasonInvestmentView.swift` — 장비·트레이너
- `apps/ios/Sources/Presentation/ProFeatureCopy.swift` — 관심·협상 헬퍼
- `apps/ios/Sources/Presentation/Localization/ProCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/Localizable.xcstrings`
- `apps/ios/Sources/Presentation/Localization/GameContent.xcstrings`
- `packages/ios-layers/Sources/BaseballIOSDomain/GlossaryCatalog.swift` — 계약금, 구단 관심
- `apps/ios/Tests/ProContractDepthSurfaceTests.swift`
- `apps/ios/Tests/LayerBoundaryTests.swift`
- `apps/ios/Tests/LocalizationCoverageTests.swift`
- `apps/ios/Tests/ProRoleRequestAndGlossaryTests.swift`
- `docs/localization/ios-copy-schema.json` — `inventory:ios-localization --write`
- `tools/inject-contract-depth-copy.mjs`
- `apps/ios/Baseball.xcodeproj/project.pbxproj` — `xcodegen generate`

`apps/ios/project.yml`은 이 작업에서 바꾸지 않았다.

## 2. 오퍼 표 (v10 FA)

시장 생성은 해시만 쓴다. 연수는 `cappedYears`로 남은 시즌에 맞춘다.

| 슬롯 | kind | 연수 | 연봉 배수 | 계약금 % (연봉 대비, 1천만 반올림) | 관심 | 기타 |
|---|---|---|---|---|---|---|
| 잔류 | `free_agent` | 3–4, 마지막 팀 레거시 ≥ 65이면 5까지 | ×0.90/0.95/1.00 | 80–120 | 해시 + demand + 잔류 가산 | `preservesTeamLegacy`, outlook balanced, 기대치 standard |
| 도전 | `free_agent` | 2–3 | ×1.05/1.10/1.15 | 60–90 (낮음) | 해시 + demand + contender 가산 | 외부 최고 outlook, 보직 한 단계 아래, 기대치 stretch |
| 기회 | `free_agent` | 1–2 | ×0.80/0.85/0.90/0.95 | 70–110 | 해시 + demand + opportunity 감산 | 외부 최저 outlook, 보직 한 단계 위, 기대치 accessible |
| 장기 안정 | `long_term` | 4–5 | ×0.85/0.90/0.95 | 110–140 (높음) | 해시 + demand | 외부 중간 outlook, contender 아님, `preservesTeamLegacy = false`, 기대치 accessible |

관심 레벨: 점수 ≥ 150 `hot`, < 90 `cool`, 그 외 `warm`. 사유 키 `content.contract.interest.<level>.<reason>` (demand / contention / loyalty / opportunity / depth).

재계약 `renewal_long`은 마지막 팀 레거시 ≥ 65일 때 최대 5년. 재계약 계약금은 없음.

`totalGuaranteedSalary` = `annualSalary * years + (signingBonus ?? 0)`.

### 잔류 협상 판정

시장당 1회. 잔류 오퍼만. 선택지: 연수 +1(최대 5·남은 시즌) 또는 연봉 +10%(1천만 반올림).

| 조건 | 결과 |
|---|---|
| `marketScore ≥ 70` | 수락, 오퍼에 적용 |
| `fanSupport ≥ 55 && marketScore ≥ 60` | 수락, 오퍼에 적용 |
| 그 외 | 거절, 오퍼 유지, 팬 지지 −1 |

결과는 `pendingContractMarket.counterOffer`에 kind / accepted / applied로 남긴다. `validateStoredJourneyMarket`은 거절 시 팬 지지를 복원해 재생성한 뒤 같은 협상을 적용해 저장과 맞춘다.

### 연봉 사용처

| 투자 | 비용 | 효과 | 만료 |
|---|---|---|---|
| `equipment` | 3천만 | `ProSeasonBenefit.kind == .equipmentEdge`, 다음 시즌 부상 압력 −6 | 시즌 결산 롤오버 |
| `personalTrainer` | 4천만 | `.trainingEfficiency`, 주간 `trainingEfficiencyPermille` 경로에 ×1.100 | 시즌 결산 롤오버 |

v10에서 계약 수락 후 `.offseasonInvestment`로 들어간다(기존 non-rookie 경로와 동일). 오프시즌당 1회. 잔액 부족 시 카드 비활성.

## 3. 게이트 원문 결과

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`. 새로 만들지 않았다. xcodebuild는 한 번에 하나만 돌렸다. 첫 iOS 실행은 `LocalizationCoverageTests.testGlossaryCatalogHasKoreanEnglishJapaneseParity`가 용어 키 수를 40으로 고정해 종료 65. 44로 고친 뒤 같은 부팅 기기에서 한 번 더 돌렸다.

### 3.1 `swift test --package-path packages/simulation-core`

종료 코드 0.

```
Test Suite 'BaseballSimulationPackageTests.xctest' passed at 2026-09-02 20:36:45.384.
	 Executed 579 tests, with 1 test skipped and 0 failures (0 unexpected) in 464.250 (464.290) seconds
Test Suite 'All tests' passed at 2026-09-02 20:36:45.384.
	 Executed 579 tests, with 1 test skipped and 0 failures (0 unexpected) in 464.250 (464.291) seconds
WAVE5_DISTRIBUTION seeds=1000 seasons=20 negative_funds=0 duplicate_finance=0 duplicate_settlement=0 contractless_active_seasons=0 season3_before_fan100=0
```

`ProContractDepthRulesTests` 10/10 포함.

### 3.2 `swift test --package-path packages/ios-layers`

종료 코드 0.

```
Test Suite 'BaseballIOSLayersPackageTests.xctest' passed at 2026-09-02 20:29:09.438.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.006 (0.007) seconds
Test Suite 'All tests' passed at 2026-09-02 20:29:09.438.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.006 (0.008) seconds
```

### 3.3 `npm run check`

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
Test Suite 'All tests' passed at 2026-09-02 20:47:54.740.
	 Executed 579 tests, with 1 test skipped and 0 failures (0 unexpected) in 521.166 (521.223) seconds
```

test:web:

```
 Test Files  30 passed (30)
      Tests  103 passed (103)
   Start at  20:47:55
   Duration  1.51s (transform 5.55s, setup 0ms, import 7.19s, tests 221ms, environment 1.37s)
```

build:web:

```
✓ built in 179ms
```

test:tauri:

```
test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.05s
```

check:tauri:

```
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.23s
```

정적 게이트:

`npm run check:ios-localization` 종료 코드 0.

```
iOS localization release check passed: 3832 catalog entries and zero pending surfaces
```

### 3.4 `npm run run:pro-career:distribution:smoke`

종료 코드 0.

```
PRO_CAREER_DISTRIBUTION output=artifacts/analysis/pro-career-wave6/swift-distribution-smoke.json valid=true failures=
```

### 3.5 iOS `BaseballIOSTests`

`cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO`

종료 코드 0.

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 20:42:27.844.
	 Executed 547 tests, with 0 failures (0 unexpected) in 120.599 (120.788) seconds
Test Suite 'All tests' passed at 2026-09-02 20:42:27.845.
	 Executed 547 tests, with 0 failures (0 unexpected) in 120.599 (120.789) seconds
** TEST SUCCEEDED **
```

### 3.6 익스포터 cmp

```
BASEBALL_PRO_CONTRACT_WAVE3_OUTPUT=/tmp/swift-pro-career-contract-wave3-oracle-v1.json \
BASEBALL_PRO_ORACLE_OUTPUT=/tmp/swift-pro-career-oracle-v1-unused.json \
swift run --package-path packages/simulation-core pro-career-fixture-exporter
cmp /tmp/swift-pro-career-contract-wave3-oracle-v1.json \
  apps/android/game-core/src/test/resources/fixtures/swift-pro-career-contract-wave3-oracle-v1.json
```

종료 코드 0. 파일 sha256 동일:

```
49a942ba4db832809f117c546586c3378a507a3729aa8e95b0921256ad75abaf
```

## 4. 미해결

- 잔류 5년은 마지막 팀 레거시 ≥ 65일 때만 열린다. 3년 신인 계약이 막 끝난 직후는 대개 3–4년이다.
- 연수 +1이 한도에 걸리거나, 수락 시 시장 비지배/연봉 밴드를 깨면 해당 선택지는 비활성 + 한 줄 사유다. 둘 다 불가면 「요구하기」를 숨긴다. 적용 경로의 `invalid_offer`는 안전망으로 남긴다.
- 오프시즌 투자 단계는 예전부터 진행 중 저장의 `proRulesVersion`을 `currentRulesVersion`(지금 10)으로 올린다. 투자 전이면 v9 pending 시장은 3오퍼로 재생성되고, 투자를 마친 저장은 다음 시장부터 v10 규칙을 쓴다. 이번 작업에서 그 승격 시점을 바꾸지는 않았다.
- 국가대표 대회는 다른 엔지니어 워크트리. 이 작업은 손대지 않았다.

## 수정 라운드 J (잔류 협상 사전 검증)

라운드 I에서 지적한 FA 잔류 협상 UX: 수락된 연수 +1 / 연봉 +10%가 다른 슬롯을 지배하거나 연봉 밴드를 벗어나면 엔진이 `invalid_offer`를 던지고, 앱은 오퍼 화면에 아무 피드백 없이 남았다.

`ProContractMarketRules.counterAvailability(market:state:kind:) -> ProCounterAvailability`를 추가했다. 적용 경로와 같은 연수 한도·수락 판정·적용 시장 `isValid`·비지배 검사를 순수하게 돌린다. 거절될 협상은 오퍼를 바꾸지 않으므로 가능으로 둔다. 사유: `years` / `dominance` / `salary-band`. `CareerDisplayRules`와 `MobileCareerStore` 프로젝션으로 노출한다. `ProContractOfferView`는 불가 선택지를 비활성 + 한 줄 사유(`content.contract.counter.unavailable.*`, ko/en/ja)로 보여 주고, 둘 다 불가이면 「요구하기」를 숨긴다. `requestContractCounter`의 throw는 안전망으로 남긴다.

커밋·stash·reset·checkout 없음. 픽스처 재생성 없음. v9 이하 시장 생성·검증은 그대로다. xcodebuild는 부팅된 iPhone 17만, 한 번에 하나.

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`.

### 게이트 원문

```
swift test --package-path packages/simulation-core --filter "ProContract"
```

종료 코드 0.

```
Test Suite 'Selected tests' passed at 2026-09-02 22:03:05.394.
	 Executed 43 tests, with 0 failures (0 unexpected) in 29.377 (29.381) seconds
```

```
npm run check:ios-localization
```

종료 코드 0.

```
iOS localization release check passed: 3881 catalog entries and zero pending surfaces
```

```
npm run check:copy
```

종료 코드 0.

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

```
cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' \
  -only-testing:BaseballIOSTests/ProContractInvestmentSurfaceTests \
  -only-testing:BaseballIOSTests/LocalizationCoverageTests \
  -only-testing:BaseballIOSTests/ProCareerJourneyStoreTests \
  test CODE_SIGNING_ALLOWED=NO
```

종료 코드 0.

```
Test Suite 'Selected tests' passed at 2026-09-02 22:04:09.875.
	 Executed 69 tests, with 0 failures (0 unexpected) in 6.254 (6.270) seconds
** TEST SUCCEEDED **
```

```
cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' \
  -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO
```

종료 코드 0.

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 22:06:25.471.
	 Executed 553 tests, with 0 failures (0 unexpected) in 116.905 (117.080) seconds
Test Suite 'All tests' passed at 2026-09-02 22:06:25.471.
	 Executed 553 tests, with 0 failures (0 unexpected) in 116.905 (117.080) seconds
** TEST SUCCEEDED **
```

