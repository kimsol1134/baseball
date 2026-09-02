# Android 코어 패리티 1차 스펙 — Kotlin game-core를 Swift 규칙 v8로

작성: PM, 2026-09-02. 구현: grok (워크트리 `/Users/solkim/Dev/baseball-wt-android`, 브랜치 `android/core-parity-v8`).
배경: Swift `SimulationCore`는 `currentRulesVersion = 9`, Kotlin `ProCatalog.RULES_VERSION = 4`. 패리티 픽스처 테스트 2개(`ProCareerFixtureTest`, `ProCareerWave6FixtureParityTest`)가 "Kotlin port lags Swift authority (season climate/call policy)"로 `@Ignore` 상태이며, 커밋된 픽스처 `swift-pro-career-oracle-v2.json`은 Swift exporter가 `proRulesVersion: 8`로 만든 값이다. 이 1차 작업의 완료 기준은 **두 테스트의 @Ignore를 제거하고 통과시키는 것**이다.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. 워크트리 안에서만 작업. `/Users/solkim/Dev/baseball`(main 트리)와 `packages/simulation-core`(Swift)는 **읽기만** 한다 — Swift가 권위(authority)이고 Kotlin이 따라간다. Swift 코드·픽스처 JSON 수정 금지.
2. xcodebuild·npm·swift test 실행 금지(다른 엔지니어가 iOS 작업 중). 검증은 `./gradlew :game-core:test`(필요 시 `:game-application:test`)만. 워크트리에는 node_modules가 없다.
3. 픽스처 JSON은 절대 재생성·편집하지 않는다. Kotlin이 그 값을 재현해야 한다.
4. 테스트 삭제·약화 금지. `@Ignore` 제거는 통과할 때만.
5. 결정론: Swift와 동일한 RNG 소비 순서·횟수(SplitMix64), 동일 해시(`StableHash.fnv1a64`), 정수 산술. 부동소수 금지(Swift도 정수만 쓴다).
6. 실존 구단·선수명 금지(AGENTS.md).

## 1. 포팅 대상 (Swift 파일 → Kotlin), 순서대로
Swift 위치는 `packages/simulation-core/Sources/SimulationCore/`.
1. **ProSeasonClimate.swift**(91줄): `ProSeasonClimate`, `AutoCallPolicy`, `ProSeasonClimateRules.callPolicy(for:)`, `liveClimate`/`liveBatterOffset`(ProCareer.swift 내 static). → `apps/android/game-core/.../pro/ProSeasonClimate.kt`.
2. **AutoOutingSimulator.swift**의 `callPolicy` 소비(:52, :123-129)와 초말 전환 아웃 유실 수정(2026-09-02, 이미 Kotlin `ProAutomaticOutingSimulator.kt`에 일부 반영됨 — diff로 확인). `diverseScouting` 파라미터는 **기본값 false로만** 추가(v9 기능은 1차 범위 밖이지만 시그니처 호환).
3. **ProSeasonArcRules.swift**(65줄) + **DifficultyScale.swift**(challenge 추적 포함).
4. **ProPostseason.swift**(940줄): v6 autumn 4라운드 + v7 finalSeries. 상태 모델(`ProPostseasonState`), 시리즈 시뮬, 박스스코어 필드.
5. **ProCareer.swift** v5~v8 게이트: `usesCareerArcRules/usesAutumnRules/usesFinalSeriesRules/usesChallengeRules`, 에이징(31세~), 부상 압력 바닥(`injuryPressure(rawFatigue:stamina:mastery:challengeRules:)`), 신뢰 85+ 반감, 중요경기 병합 반올림, 시즌 롤오버 시 `proRulesVersion` 스탬프.
6. **ProCareer+Journey.swift / ProCareerJourney.swift**: `currentJourneyRulesVersion = 3` 수상 문턱 재기준(2026-09-02), 통산 피안타·볼넷·WHIP 필드.
7. **ProCareerModels.swift**: 스냅샷 신규 Optional 필드(seasonSegment, seasonTrigger, currentRival, seasonTensions, postseason, gameLines 등 v5~v8에 해당하는 것) + `ProStateCodec.kt` 확장(decodeIfPresent 관례, 구세이브 호환).
8. `ProCatalog.RULES_VERSION = 8`. v9(주간 결정·보직 지원·사인 v2·목표판)는 **2차**로 미룬다. 단, Swift가 v9 스냅샷을 내보낼 수 있으므로 Kotlin 디코더는 v9 필드(`activeDecisionModifiers`, `resolvedFollowUps`, `roleRequest`)를 **무시하지 말고 보존 필드로 통과**시키거나, 최소한 디코드 실패 없이 무시하고 그 사실을 보고서에 적는다.

## 2. 검증
- `ProCareerFixtureTest`, `ProCareerWave6FixtureParityTest`의 `@Ignore` 제거 후 `./gradlew :game-core:test` 통과. 픽스처 v1(`swift-pro-career-oracle-v1.json`)·v2·`swift-pro-career-contract-wave3-oracle-v1.json`·`swift-high-school-phase4-oracle-v3.json` 전부 통과.
- `:game-core:runProCareerDistribution`(ci.yml:71-73) 정상 종료.
- 포팅 중 Swift와 Kotlin 결과가 어긋나면 **Swift 쪽 값이 정답**이다. 어긋난 지점은 주차·시드·필드 단위로 보고서에 기록한다(Swift 버그로 의심되는 경우도 Swift를 고치지 말고 보고만).

## 3. 산출물
`docs/ANDROID_CORE_PARITY_WAVE1_REPORT_2026-09-02.md`(워크트리 안): 포팅한 파일 대응표, 규칙 버전, 디코더 호환 방식, 어긋났던 지점과 해결, gradle 원문 결과, 2차(v9) 범위 목록. 작업 끝에 워크트리의 gradle `build/` 디렉터리를 삭제한다.
