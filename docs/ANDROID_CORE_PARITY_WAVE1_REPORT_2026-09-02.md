# Android 코어 패리티 1차 보고 — Kotlin game-core = Swift 규칙 v8

작성: grok, 2026-09-02. 워크트리 `/Users/solkim/Dev/baseball-wt-android`, 브랜치 `android/core-parity-v8`.
권위: Swift `SimulationCore` (읽기 전용). 픽스처 JSON은 재생성·편집하지 않음.

## 완료 기준

- `ProCareerFixtureTest`, `ProCareerWave6FixtureParityTest`의 `@Ignore` 제거 후 통과.
- `./gradlew :game-core:test` — 89 tests, 0 failures, 0 skipped.
- `:game-core:runProCareerDistribution` 정상 종료 (smoke: 8 seeds × 4 seasons).

## 1. 파일 대응표

| Swift (`packages/simulation-core/Sources/SimulationCore`) | Kotlin (`apps/android/game-core/...`) |
|---|---|
| `ProSeasonClimate.swift` | `pro/ProSeasonClimate.kt` (신규) |
| `DifficultyScale.swift` | `pro/DifficultyScale.kt` (신규) |
| `ProSeasonArcRules.swift` | `pro/ProSeasonArcRules.kt` (신규) |
| `ProPostseason.swift` | `pro/ProPostseason.kt` (신규) |
| `AutoOutingSimulator.swift` (`callPolicy`, `diverseScouting=false`, 초말 절대 아웃) | `pro/ProAutomaticOutingSimulator.kt` |
| `BatterScoutingProfileRules.swift` (diverseScouting 분기용) | `pitch/BatterScoutingProfileRules.kt` (신규) |
| `ProCareer.swift` v5–v8 게이트·에이징·부상 압력·신뢰 반감·중요경기 반올림·롤오버 스탬프 | `pro/ProKernel.kt`, `pro/ProCatalog.kt` |
| `ProCareerModels.swift` 옵셔널 필드 | `pro/ProModels.kt` |
| `ProCareerJourney.swift` 수상 문턱 v3 | `pro/ProCareerRecognitionRules.kt`, `pro/ProJourneyKernel.kt` |
| `StableHash.fnv1a64Value` | `StableHash.fnv1a64Value` |
| Codable `decodeIfPresent` | `ProStateCodec.kt` trailing optional 블록 |

## 2. 규칙 버전

| 상수 | 값 | 비고 |
|---|---|---|
| Swift `currentRulesVersion` | 9 | 2차 범위. 이 작업은 따라가지 않음 |
| Kotlin `ProCatalog.RULES_VERSION` | **8** | 신규 커리어 스탬프 |
| `agencyRulesVersion` | 3 | 기존 유지 |
| `careerArcRulesVersion` | 5 | climate, 불완전 콜, 아크 오프셋 |
| `autumnRulesVersion` | 6 | 24주 후 가을 4라운드 |
| `finalSeriesRulesVersion` | 7 | best-of 시리즈 |
| `careerChallengeRulesVersion` | 8 | 31세 에이징, 부상 압력 바닥, 신뢰 85+ 반감 |
| `weeklyDecisionRulesVersion` | 9 | 시그니처만. 신규 커리어는 false |
| `currentJourneyRulesVersion` | **3** | 아웃 유실 수정 후 수상 문턱 재기준 |
| 픽스처 `swift-pro-career-oracle-v2.json` | `proRulesVersion: 8` | 커밋된 값 그대로 |

버전 게이트는 `proRulesVersion >= CURRENT`가 아니라 Swift와 같이 축별 하한이다. v4 저장본은 기존 live outing offset을 유지하고, v5+만 climate/callPolicy를 탄다.

## 3. 디코더 호환

- 바이너리 v1 페이로드는 `proRulesVersion` 뒤에 **optional trailing**을 붙인다. 구세이브는 `available()==0`이면 `postseason`/`activeDecisionModifiers`/`resolvedFollowUps`/`roleRequest`를 null로 읽는다.
- v9 필드 세 개는 시뮬레이션에 쓰지 않지만 **디코드 실패 없이 보존**한다. 커밋먼트에도 값이 있을 때만 넣는다.
- `ProSeasonStats.postseasonGames`는 메모리 모델에만 있고, 기존 14-int stats 레코드 레이아웃은 바꾸지 않았다 (구세이브 중간 필드 호환).
- Journey `rulesVersion` 허용 범위는 `1..3`. 레거시 마이그레이션은 계속 `JOURNEY_RULES_VERSION = 1`.

## 4. 어긋났던 지점과 해결

픽스처 주석이 가리킨 원인은 **시즌 climate + 콜 정책의 RNG 소비**였다. v8 신규 커리어의 자동 등판은 `.perfect`가 아니라 climate에 따른 `.mixed`/`.slump`라서 타석당 `nextInt(100)`이 한 번 더 나간다. 1주차도 hot(15%)이면 `batterOffset = -2`.

포팅 후 `ProCareerFixtureTest`(seeds 100..119, 1주차 성적)는 커밋된 `swift-pro-career-oracle-v1.json`과 **한 시드도 어긋나지 않고** 통과했다. 주차별 출력 diff는 필요 없었다.

그 밖에 Swift를 따라가며 맞춘 항목:

- 중요 경기 잔여 이닝 **반올림** `(value * complement + outs/2) / outs` — 이전 Kotlin은 내림.
- v8 `injuryPressure`: `max(effectiveFatigue, rawFatigue * 800 / 1000)`.
- 감독 신뢰 85+에서 양수 이득만 `/ 2`.
- 오프시즌 에이징 31세부터 네 능력 (도전 규칙). `proRulesVersion`은 `max(saved, 8)`로 스탬프.
- 24주 종료 시 autumn 평가 → `IMPORTANT_GAME` 또는 `SEASON_REVIEW`. 가을 이닝은 정규 성적에 합치지 않음.
- 시즌 결정 로테이션은 `enum.entries`가 아니라 Swift와 같은 **6타입 고정 목록** (formCrisis/agingCrossroads를 넣어도 기존 슬롯이 밀리지 않음).

Swift 버그로 의심되어 고치지 않은 항목은 없음. 권위는 전부 Swift 값.

## 5. Gradle 원문 결과

### `:game-core:test`

```
tests=89 failures=0 errors=0 skipped=0
BUILD SUCCESSFUL
```

포함: `ProCareerFixtureTest` 2, `ProCareerWave6FixtureParityTest` 1, `ProContractMarketWave3FixtureTest` 1, `HighSchoolPhase4FixtureTest` 1, `ProKernelTest` 7 (20시즌 직접 커리어 포함).

### `:game-core:runProCareerDistribution`

```
{"actualCommandSimulation":true,"journeyEnabled":true,"noUniversallyOptimalOfferArchetype":true,"policies":{"legacy_first":{"careers":8,"completedSeasons":32,"negativeFunds":0,"duplicateFinance":0,"duplicateSettlement":0,"activeExpiredOrMissingContract":0,"marketOfferCountMismatch":0,"dominatedMarkets":0,"renewalMarkets":8,"freeAgencyMarkets":0,"teamRecordMismatches":0,"earlyFan100":0,"retiredNumbers":0,"hallOfFame":0,"ambitionCompletions":0,"contractSelections":{"legacy_first:renewal_long":8,"legacy_first:rookie":8}},"role_first":{"careers":8,"completedSeasons":32,"negativeFunds":0,"duplicateFinance":0,"duplicateSettlement":0,"activeExpiredOrMissingContract":0,"marketOfferCountMismatch":0,"dominatedMarkets":0,"renewalMarkets":8,"freeAgencyMarkets":0,"teamRecordMismatches":0,"earlyFan100":0,"retiredNumbers":0,"hallOfFame":0,"ambitionCompletions":0,"contractSelections":{"role_first:prove_it":7,"role_first:renewal_long":1,"role_first:rookie":8}},"salary_first":{"careers":8,"completedSeasons":32,"negativeFunds":0,"duplicateFinance":0,"duplicateSettlement":0,"activeExpiredOrMissingContract":0,"marketOfferCountMismatch":0,"dominatedMarkets":0,"renewalMarkets":8,"freeAgencyMarkets":0,"teamRecordMismatches":0,"earlyFan100":0,"retiredNumbers":0,"hallOfFame":0,"ambitionCompletions":0,"contractSelections":{"salary_first:prove_it":7,"salary_first:renewal_long":1,"salary_first:rookie":8}},"security_first":{"careers":8,"completedSeasons":32,"negativeFunds":0,"duplicateFinance":0,"duplicateSettlement":0,"activeExpiredOrMissingContract":0,"marketOfferCountMismatch":0,"dominatedMarkets":0,"renewalMarkets":8,"freeAgencyMarkets":0,"teamRecordMismatches":0,"earlyFan100":0,"retiredNumbers":0,"hallOfFame":0,"ambitionCompletions":0,"contractSelections":{"security_first:renewal_long":8,"security_first:rookie":8}},"stable_random":{"careers":8,"completedSeasons":32,"negativeFunds":0,"duplicateFinance":0,"duplicateSettlement":0,"activeExpiredOrMissingContract":0,"marketOfferCountMismatch":0,"dominatedMarkets":0,"renewalMarkets":8,"freeAgencyMarkets":0,"teamRecordMismatches":0,"earlyFan100":0,"retiredNumbers":0,"hallOfFame":0,"ambitionCompletions":0,"contractSelections":{"stable_random:prove_it":4,"stable_random:renewal_long":4,"stable_random:rookie":8}}},"policyCount":5,"policyDominantContractKinds":{"legacy_first":"renewal_long","role_first":"rookie","salary_first":"rookie","security_first":"renewal_long","stable_random":"rookie"},"runner":"pro-career-distribution-kotlin-v1","seasons":4,"seedCount":8}
BUILD SUCCESSFUL
```

## 6. 2차(v9) 범위

스펙이 미룬 항목. Kotlin에 시그니처·보존 필드만 있고 켜지지 않는다 (`usesWeeklyDecisionRules` = `proRulesVersion >= 9`).

- 주간 결정 3주 주기 (`weeklySeasonDecisionWeeks`)와 시즌당 결정 상한 변경
- `activeDecisionModifiers` 실제 소비 (extra outing, suppressOutings, trainingEfficiency, injuryPressureFloor, follow-up resolve)
- `resolvedFollowUps` 카드 생성
- `roleRequest` 스프링캠프 보직 지원
- 사인 v2 / 포수 추천 다양화 (`diverseScouting=true`가 기본이 되는 경로)
- 목표판 (`ProCareerGoalBoardRules`)
- `ProCatalog.RULES_VERSION = 9` 및 오프시즌 스탬프 9
- v9 스냅샷을 Swift Codable JSON으로 직접 읽는 디코더 (현재 Android 와이어는 자체 바이너리)

## 7. 정리

워크트리 `apps/android/game-core/build`, `apps/android/game-model/build`는 보고 작성 후 삭제했다. Swift 소스·픽스처 JSON·main 트리(`/Users/solkim/Dev/baseball`)는 수정하지 않았다.
