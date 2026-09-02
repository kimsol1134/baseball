# P1-2 포수 사인·상대 약점 다양화 스펙

작성: PM, 2026-09-02. 구현: grok (별도 워크트리 `/Users/solkim/Dev/baseball-wt-catcher`, 브랜치 `p1/catcher-variety`). 리뷰 근거: "포수의 사인이 패턴화되어 어떤 경기든 똑같다"(4★), "상대의 약점도 커브 아니면 체인지업으로 단순함"(3★), "포수가 시키는 대로 던지면 방어율 1점대"(2★). 직접 투구가 이 게임의 핵심 손맛이므로 반복감 제거가 리텐션 직결.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. **이 워크트리에서만 작업**하고 `/Users/solkim/Dev/baseball`(main 워킹트리)는 건드리지 않는다. 워크트리에는 node_modules가 없으므로 npm 게이트는 실행하지 않는다(PM이 병합 후 실행).
2. **xcodebuild 실행 금지.** 다른 엔지니어가 같은 시뮬레이터에서 iOS 테스트를 돌리고 있다. iOS 코드·테스트는 작성하되 검증은 `swift test`(simulation-core, ios-layers)까지만 하고, iOS 테스트는 PM이 병합 후 직렬로 돌린다. 컴파일 확인이 필요하면 `swift build`로 가능한 범위까지만.
3. **결정론 계약**: `CatcherRecommendationEngine`·`SignSituation`은 난수 사용 금지(prepare/submit가 재계산해 `preparationToken`을 대조). 새 다양화는 전부 `(투수·타자·카운트·직전 구·적응 스냅샷·matchupSeed 등 이미 입력에 있는 값)`의 결정적 함수여야 한다.
4. **픽스처 보호**: `simulate_pitch_golden.json`, Kotlin `swift-pitch-kernel-current-v1.json`/`approved-v2.json`, `swift-pro-career-oracle-v1/v2.json`, 고교 v3 전부 재생성 금지. 따라서 (a) 포수 추천 변경은 `CatcherSignRules.version`(새 파라미터, 기본값 1 = 기존 동작) 뒤에 두고 iOS `PitchSession`만 2를 넘긴다. exporter·CLI·테스트 기본 경로는 1을 유지한다. (b) 자동 등판 약점 다양화는 `AutoOutingSimulator.simulate`에 `diverseScouting: Bool = false`를 추가하고 `ProCareerEngine.planWeek`가 `usesWeeklyDecisionRules(state)`(proRulesVersion ≥ 9)일 때만 true를 넘긴다. v8 커리어와 v2 픽스처 exporter(v8 고정)는 바이트 동일.
5. ko/en/ja 필수(새 reasonCode 문구). 실존 선수·구단명 금지. 투구 슬라이더 조작 코드 접근 금지.
6. 테스트 삭제·약화 금지.

## 1. 원인 (조사 결과)
- 약점 생성 4곳이 2종으로 붕괴: `apps/ios/Sources/Platform/ProRivalBatter+Stats.swift:101` (`powerHitter ? .changeup : .curveball`, hot/cold 존도 2가지), `HighSchoolPresentation+Drama.swift:78` 동일, `PitchScenario.swift:328` 튜토리얼 커브 고정(그대로 둠), `AutoOutingSimulator.swift:97` 슬라이더/체인지업 2종.
- 포수 코스는 항상 `situation.shift(scouting.coldZone)`(CatcherRecommendationEngine.swift:44) → 콜드존이 2가지면 코스도 2가지.
- 적응 반영이 `level >= 500` 계단 스위치 하나(:30) → 그 아래에선 사인이 전혀 변하지 않음. 연속값 `pitchReadStrength/zoneReadStrength`(RivalMemory.swift:249~)는 추천에 미사용.

## 2. 기능

### 2.1 상대 스카우팅 다양화 (`BatterScoutingProfileRules`, SimulationCore 새 파일)
`profile(archetype:, seedToken: String) -> (pitchWeakness, pitchStrength, hotZone, coldZone, reliability)`를 결정적 해시(`StableHash.fnv1a64(seedToken)`)로 만든다.
- 아키타입 9종(`ProRivalBatter+Stats.swift:28-38` 표)마다 **약점 후보 2~3종**을 표로 정의하고 해시로 하나를 고른다. 전체적으로 4구종이 모두 나오고, 한 아키타입 안에서도 라이벌마다 달라진다. 예: 파워형 {changeup, curveball, slider(낮은 확률)}, 컨택형 {fourSeam(하이), slider}, 선구안형 {curveball, changeup}, 등. 표는 야구 상식에 맞게 grok이 채우고 보고서에 적는다.
- hot/cold 존은 9존 중 아키타입별 후보 3~4개에서 해시로 선택, hot ≠ cold.
- 강점은 약점과 다른 구종에서 선택.
- 적용: `ProRivalBatter+Stats.swift`(seedToken = 라이벌 id + 시즌), `HighSchoolPresentation+Drama.swift`(라이벌 id), `AutoOutingSimulator`(diverseScouting일 때만; **RNG 소비 순서·횟수 유지** — 기존 `rng.nextInt(upperBound: 2)` 호출은 그대로 두고 그 결과와 해시를 섞어 4종으로 확장하거나, 해시만 쓰되 기존 draw는 반드시 그대로 호출해 스트림을 보존).
- 튜토리얼(`PitchScenario.swift:328`)은 커브 고정 유지(교육용).

### 2.2 포수 사인 다양화 (`CatcherRecommendationEngine`, version 2)
- **코스 선택**: 콜드존 고정 대신 후보 3개 {콜드존, `zoneIntent(protectZone:twoStrikes:)`가 주는 의도 존, 직전 구와 대각 반대 존(시퀀싱)}에 카운트별 가중치를 두고 결정적으로 고른다(예: 2스트라이크는 유인구 존 우선, 3볼은 스트라이크 의도 존 우선, 그 외는 콜드존 우선하되 직전 2구가 같은 존이면 반대 존). 같은 타자 상대 연속 타석에서 같은 존이 3회 연속 나오지 않게 한다.
- **구종 점수**: `repetitionAvoided` 계단(level ≥ 500)을 유지하되, 추가로 `adaptation.pitchReadStrength`(0~1000)를 연속 감점(예: `-(strength * 70 / 1000)`)으로 desired/lean 구종에 적용하고, `zoneReadStrength`는 코스 후보 가중치에 반영한다. 이 감점은 v2에서만.
- **직전 구 시퀀싱**: 같은 구종 2연속 뒤에는 `repeatPenalty` 상향(v2), 구속차 셋업(직구 뒤 체인지업 보너스 소폭)을 점수에 추가.
- reasonCode 추가: `sequence.change_eye_level`, `sequence.setup_offspeed`, `rival.read_pressure`, `situation.chase_zone`. 문구 ko/en/ja (`PitchUICopyKey` 매핑, `PitchPresentation.swift:368 catcherReason`).
- `PitchSession`은 v2를 사용. `preparationToken`은 version을 포함해 v1/v2 혼용 시 거부되게 한다.

### 2.3 난이도 안전장치
리뷰 "사인대로 던지면 방어율 1점대"는 사인이 항상 최적이라는 뜻이다. v2의 코스 다양화가 추천 수락 피안타율 밴드(`check:balance`의 "추천 수락 피안타율 0.17~0.3")를 벗어나면 안 된다. 워크트리에서 npm을 못 돌리므로, 동일 로직을 `PitchKernelEngineTests`에 통계 테스트로 추가한다: 200타석 시뮬레이션에서 v2 추천 수락 피안타율이 v1 대비 ±0.04 이내, 그리고 추천 코스 분포가 9존 중 ≥5존, 구종 ≥3종.

## 3. 수용 기준
1. 아키타입 9종 × 라이벌 30명 생성 시 약점 4구종 모두 등장, 존 ≥ 6종, 같은 아키타입 내 약점이 단일하지 않음(테스트).
2. v1 경로(기본값)에서 `PitchKernelEngineTests`·`SimulationEngineTests` 골든·Kotlin 픽스처 입력에 해당하는 Swift 테스트 전부 바이트 동일 통과.
3. v2 prepare/submit 결정론: 같은 입력 두 번 → 같은 추천·같은 토큰(테스트).
4. 연속 타석 30구 시나리오에서 v2 추천 존 ≥ 4종, 구종 ≥ 3종(v1은 동일 시나리오에서 존 ≤ 2종임을 대조 테스트로 보임).
5. v8 커리어 `planWeek` 결과 바이트 동일(`ProCareerBootstrapCharacterizationTests`·`ProCareerLegacyRulesTests`).
6. `swift test --package-path packages/simulation-core` 전체, `swift test --package-path packages/ios-layers` 종료 코드 0. iOS 테스트 파일(`PitchSessionTests`·`RivalAdaptationSessionTests`·`PitchLocalizationTests`에 v2 케이스)은 작성만 하고 실행은 PM에 넘긴다.

## 4. 산출물
- `docs/P1_CATCHER_SIGN_VARIETY_REPORT_2026-09-02.md`(워크트리 안): 약점 후보 표, 코스 가중치 표, 통계 테스트 수치, 게이트 원문, PM이 병합 후 돌려야 할 명령 목록(iOS 테스트·npm 게이트), 미해결.
- 작업 끝에 워크트리의 `.build`를 삭제한다.
