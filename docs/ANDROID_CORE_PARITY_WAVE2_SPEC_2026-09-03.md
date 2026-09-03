# Android 코어 패리티 2차 스펙 — Kotlin game-core를 Swift 규칙 v10으로

작성: PM, 2026-09-03. 구현: grok (워크트리 `/Users/solkim/Dev/baseball-wt-android2`, 브랜치 `android/core-parity-v10`).
배경: 1차(2026-09-02)로 Kotlin이 v8까지 따라왔고 패리티 테스트 2개가 켜졌다. Swift는 이제 `currentRulesVersion = 10`. 이 2차의 완료 기준은 **Kotlin `RULES_VERSION = 10`이고, v10 커리어를 Swift와 동일하게 재현하는 새 패리티 픽스처(v3)가 켜져 통과하는 것**이다.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. 워크트리 안에서만. Swift 소스와 기존 픽스처 JSON은 **읽기만**. Swift가 권위.
2. xcodebuild·npm 금지. `swift build`/`swift run`은 **픽스처 v3 생성에만** 허용(아래 3항). 검증은 `./gradlew :game-core:test`.
3. 기존 픽스처(v1/v2/wave3/고교 v3) 무변경. 새 v3 프로 픽스처는 Swift exporter가 만든다.
4. 테스트 삭제·약화 금지. 결정론: RNG 소비 순서·횟수, `StableHash`, 정수 산술 동일.
5. 실존 명칭 금지.

## 1. 포팅 대상 (Swift → Kotlin)
Swift는 `packages/simulation-core/Sources/SimulationCore/`.
1. **v9 주간 결정**: `ProCareer.swift`의 `weeklySeasonDecision`, 4종 타입(rotationPush/newPitchTrial/farmReset/veteranMentor), `ProDecisionModifier`/`ProDecisionFollowUp`(ProCareerModels.swift), 후속 해결, 시즌 롤오버 비움, `decisionContent` 콘텐츠 키.
2. **v9 보직 지원**: `ProRoleRequestRules.swift`, 스냅샷 `roleRequest`, 6주차 역할 면담 강제 삽입.
3. **v9 스카우팅 다양화**: `BatterScoutingProfileRules.swift`(Kotlin에 1차 때 파일이 있으면 Swift와 대조), `AutoOutingSimulator.diverseScouting`(v9 게이트, RNG 순서 보존).
4. **포수 사인 v2**: `CatcherSignRules.swift`, `CatcherRecommendationEngine.swift`(version 2 경로), `SignSituation.swift`. Kotlin 투구 커널 오라클(`swift-pitch-kernel-*.json`)은 v1 경로라 무변경이어야 한다.
5. **목표판**: `ProCareerGoalBoardRules.swift`, `ProCareerMilestoneRules.swift`(임계값 단일화) — 파생 전용.
6. **v10 FA 계약 깊이**: `ProContractMarketRules.swift`의 v10 분기(4오퍼, 5년, 계약금, 관심, 잔류 협상 `counterAvailability`/apply), `ProOffseasonInvestment`의 equipment/personalTrainer, 협상 후 투자 페이즈. wave3 오라클은 v9 이하 경로라 무변경.
7. **v10 국가대표**: `ProNationalTournament.swift`, 페이즈 2개, `resolveNationalFinalAutomatically`, 보상(면제·팬·HOF +4·overseasInterest), 다음 시즌 캐리, 스키마 관련 필드.
8. `ProStateCodec.kt`: v9/v10 필드 전부 실제 디코드·인코드(1차의 pass-through를 정식 필드로).
9. `ProCatalog.RULES_VERSION = 10`.

## 2. 패리티 픽스처 v3
- Swift exporter `ProCareerFixtureExporterV2`를 **복사**해 `ProCareerFixtureExporterV3`(새 타깃)를 만든다: v10 커리어를 시작해 시즌 3개 이상 진행하며 주간 결정(선택은 해시로 결정적으로 고름), 보직 지원, 오프시즌(FA·협상·투자), 짝수 시즌 국가대표(수락, 결승은 `resolveNationalFinalAutomatically`)를 모두 거치는 스냅샷 시퀀스와 nextSeed를 기록. 출력: `apps/android/game-core/src/test/resources/fixtures/swift-pro-career-oracle-v3.json`(스키마 `baseball-pro-career-fixture-v3`). package.json 스크립트 `export:android:swift-pro-fixture:v3` 추가(파일 편집만, npm 실행은 금지 — `swift run`으로 직접 실행).
- Kotlin `ProCareerV10FixtureParityTest`가 그 파일을 재현한다. **@Ignore 없이 통과**.
- Swift 쪽 회귀: exporter v3 실행이 v1/v2/wave3 픽스처를 건드리지 않는다.

## 3. 검증
- `./gradlew :game-core:test` 전체 통과(기존 89 + 신규), `:game-core:runProCareerDistribution` 정상.
- v2 픽스처(v8) 테스트 계속 통과 — v9/v10 코드가 v8 경로를 바꾸지 않았음을 증명.

## 4. 산출물
`docs/ANDROID_CORE_PARITY_WAVE2_REPORT_2026-09-03.md`: 대응표, v3 픽스처 범위, 어긋났던 지점, gradle·swift run 원문, **남은 격차 목록(Compose UI 화면별·현지화 키 수)**. gradle `build/`·`.build` 삭제.
