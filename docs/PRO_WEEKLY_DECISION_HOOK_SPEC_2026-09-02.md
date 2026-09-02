# 프로 주간 결정 훅 구현 스펙 (1.2.8 P0)

작성: PM, 2026-09-02. 구현 담당: grok (grok-4.6, high).
근거: App Store 리뷰 41건 중 10건이 "프로 데뷔 후 휴식·훈련 딸깍만 반복"을 1위 불만으로 꼽음. 옵트인 세션 데이터상 D1 약 50%, D3 약 22%로 3일 안에 대부분 이탈. 프로 반복 구간에 **결과가 되돌아오는 선택**을 3주 단위로 넣어 "다음에 시험할 전략"을 남긴다.

## 0. 절대 규칙 (위반 시 리뷰 반려)

1. **커밋·푸시 금지.** 워킹트리에는 심사 대기 중인 1.2.7 미커밋 변경 91개가 있다. 그 변경을 되돌리거나 stash 하지 말 것. `git stash`, `git checkout -- <file>`, `git reset` 금지.
2. **RNG 스트림 삽입 금지.** `ProCareerEngine.planWeek`(packages/simulation-core/Sources/SimulationCore/ProCareer.swift:429~)은 단일 `SplitMix64` 순차 스트림이라 `rng.next*()` 호출을 하나라도 추가하면 모든 골든 픽스처가 깨진다. 결정 선택·발생 여부는 기존 `seasonDecision`처럼 `StableHash.fnv1a64` / `hashInt("\(proCareerID)|season\(season)|...")` 해시로만 결정한다. `applySeasonDecision`도 RNG를 소비하지 않는 원칙을 유지한다.
3. **규칙 버전 게이트.** `currentRulesVersion`을 8→9로 올리고 `usesWeeklyDecisionRules(_:)` 게이트를 추가한다. 기존 저장(proRulesVersion ≤ 8)은 시즌 롤오버 전까지 기존 동작(6·13·20주, 최대 3회)을 그대로 유지해야 한다. 규칙 스탬프는 시즌 롤오버·커리어 시작에서만 찍힌다(기존 관례).
4. **저장 호환.** 스냅샷 신규 필드는 전부 Optional + `decodeIfPresent ?? default`. 수동 `Equatable`(ProCareerModels.swift:535 부근)과 `replacing(...)` 헬퍼(ProCareer.swift 말미)에도 반영. `ProCareerPersistence.currentSchemaVersion`(5)은 **올리지 않는다** — 새 필드가 없어도 디코드되므로 스키마 승격 불필요. 저장 게이트 교착(8/30 리뷰 원인)이 재발하지 않도록 `schemaVersion(for:)` 로직은 건드리지 않는다.
5. **현지화 ko/en/ja 전부 필수.** 콘텐츠 문구는 `GameContent.xcstrings`의 `content.pro-decision.*` 관례, UI 정적 문구는 `Localizable.xcstrings` + `ProUICopyKey`. `npm run check:ios-localization`, `npm run check:copy` 통과. 일본어 금지어 정규식 준수.
6. **콘텐츠 불변 규칙(AGENTS.md).** 실존 구단·선수·리그명 사용 금지. 투구 슬라이더 관련 코드 접근 금지.
7. **범위 밖 금지.** 보직 선택권, 용어 카드, FA 계약, 국가대표 등 다른 P0/P1 항목은 이 작업에서 손대지 않는다. 안드로이드 Kotlin 포팅도 이번 범위 밖(패리티 테스트가 이미 @Ignore인 것은 그대로 둔다).

## 1. 기능 정의

### 1.1 빈도
- 규칙 v9 커리어: 정규시즌 **3·6·9·12·15·18·21주** 종료 시점(기존 `legacySeasonDecisionWeeks`와 동일 집합)에 결정 창이 열린다. 시즌 최대 7회.
- 기존 조건 유지: 중요경기 트리거·부상 회복 중·신규 부상 주에는 열리지 않는다(`shouldOpenDecision` 조건 재사용). 그 주에 못 열린 결정은 **다음 주로 이월**하지 않는다(단순성 우선).
- 기존 3종 특수 결정(formCrisis, agingCrossroads, mediaOpportunity)의 우선순위 오버라이드는 그대로 두고, 나머지 슬롯을 아래 신규 타입과 기존 6종 로테이션이 채운다. 같은 시즌 안에서 같은 타입이 두 번 나오지 않게 해시 로테이션을 확장한다.

### 1.2 신규 결정 타입 (`ProSeasonDecisionType` 케이스 추가, 4종)
각 결정은 **선택 시 즉시 효과 + 3주 뒤 후속 결과**를 가진다. 트레이드오프가 없는 "정답 선택지"는 만들지 않는다.

| 타입 | 발생 조건 | 선택지 A | 선택지 B | 3주 후 후속 |
|---|---|---|---|---|
| `rotationPush` 등판 간격 단축 | 선발 보직 && 피로 < 60 | 4일 로테이션 수락: 다음 3주 등판 기회 +1, 피로 +12, 감독 신뢰 +4 | 정상 간격 유지: 변화 없음, 감독 신뢰 −2 | A 선택 시 3주간 QS 수·실점 요약을 후속 카드로 표시. 3주 동안 부상 압력 바닥 +상승(기존 challenge 규칙의 injury pressure 경로 재사용) |
| `newPitchTrial` 신구종 실전 투입 | 레퍼토리에 숙련 낮은 구종 존재 | 실전 투입: 대상 구종 숙련/development +, 이번 3주 command −3(임시, 후속 시 복구) | 불펜에서만 연습: 대상 구종 development 소폭 +, 실전 영향 없음 | A 선택 시 3주 후 command 복구 + 구종 성장량 요약 |
| `farmReset` 2군 재정비 | 최근 3주 ERA 악화 또는 감독 신뢰 < 40 (formCrisis와 겹치면 formCrisis 우선) | 2군행 수락: 다음 3주 등판 0, 피로 −25, stuff/command 중 낮은 쪽 +2, 신뢰 −6 | 1군 잔류: 변화 없음, 신뢰 −3 | A 선택 시 3주 후 "복귀" 후속 카드, 신뢰 +4 회복 |
| `veteranMentor` 베테랑 조언 | 시즌 2년차 이상 && 위 조건 미해당 | 멘토 세션: 포수 신뢰 +5, movement +1, 이번 3주 훈련 성장 효율 −20% | 내 방식 고수: 훈련 효율 유지, 포수 신뢰 −2 | A 선택 시 3주 후 효율 복구, 누적 성장 요약 |

수치는 초안이다. 구현 후 `npm run check:balance`와 프로 분포 스모크(`npm run run:pro-career:distribution:smoke`)의 밴드가 깨지면 수치를 밴드 안으로 조정하고 보고서에 조정 내역을 남긴다.

### 1.3 후속(follow-up) 메커니즘
- `ProDecisionRecord.followUpResolvedWeek`가 이미 존재한다. 이를 실제로 사용: 선택 시 `followUpResolvedWeek = week + 3`을 기록하고, `planWeek`가 해당 주에 도달하면 임시 효과를 해제하고 **후속 결과 이벤트**(`events: [String]`)와 스냅샷의 새 필드 `resolvedFollowUps: [ProDecisionFollowUp]?`(decisionID, type, season, week, summaryKey, 수치 요약)에 append 한다.
- 임시 효과는 스냅샷에 `activeDecisionModifiers: [ProDecisionModifier]?`(decisionID, type, expiresWeek, commandDelta, trainingEfficiencyPermille, extraOutingChance, injuryPressureFloor 등)로 저장한다. 시즌 롤오버 시 전부 비운다.
- 시즌 도중 부상·중요경기와 겹쳐도 만료 주에 반드시 해제된다(주가 건너뛰어져도 `week >= expiresWeek`로 판단).

### 1.4 UI
- 결정 화면: 기존 `ProSeasonDecisionView` 재사용. 신규 타입은 eyebrow에 "3주 결정" 표기(ProUICopyKey 추가). 선택지 카드에 즉시 효과와 "3주 뒤" 한 줄 요약을 분리 표시(기존 `immediate-effect`/`follow-up` 키 활용).
- 후속 결과: `WeeklyPlanView` 상단 또는 주간 정산 카드에 "결정 결과" 카드 1장(타입 아이콘, 선택한 제목, 결과 요약 수치). 한 번 본 뒤 접힘은 SeenContentStore로 처리(id `pro.decision.followup.<type>.v1`).
- `advanceSegment()`(MobileCareerStore+Week.swift)는 `.seasonDecision` 페이즈에서 이미 멈춘다. 후속 결과가 생긴 주에도 멈춰서 카드를 보여줄지 결정: **멈추지 않고** 카드만 다음 화면에 누적 표시한다(딸깍 흐름 방해 최소화).
- 문구 밀도(`CopyDensity`) 설정을 존중한다.

### 1.5 분석 이벤트
- `GameAnalytics.Event`에 `proWeeklyDecisionFollowUpShown = "pro_weekly_decision_followup_shown"` 추가. 기존 `proSeasonDecisionSelected`에 property `cadence: "weekly3"|"legacy"`와 `decision_type` 포함. 저장 커밋 성공 후에만 로깅(기존 관례).

## 2. 수용 기준 (Acceptance)

1. 새 커리어(v9)에서 시즌 1을 자동 진행하면 결정 창이 3·6·9·12·15·18·21주 중 부상·중요경기 주를 제외하고 열리고, 시즌 내 같은 타입이 반복되지 않는다. 단위 테스트로 고정.
2. `rotationPush` A 선택 → 3주 뒤 스냅샷에 후속 결과 1건, 임시 modifier 0건. 부상으로 주가 건너뛰어도 만료된다. 테스트로 고정.
3. proRulesVersion 8 저장을 로드해 시즌을 진행하면 결정 주가 6·13·20 그대로이고 스냅샷 해시가 변경 전과 동일하다(회귀 테스트).
4. 같은 seed·같은 선택으로 두 번 시뮬레이션한 결과가 바이트 동일하다(결정성).
5. 기존 골든 픽스처 무변경: `swift-pro-career-oracle-v1.json`, `-v2.json`, `simulate_pitch_golden.json`이 재생성 없이 통과해야 한다. 만약 v2 exporter가 새 커리어를 v9로 스탬프해 픽스처가 바뀐다면 **바꾸지 말고** exporter가 v8을 명시 지정하도록 하거나, 그것이 불가능하면 보고서에 사유를 적고 멈춘다.
6. ko/en/ja 문구 전부 존재, `npm run check:ios-localization`, `npm run check:copy` 통과.
7. `swift test --package-path packages/simulation-core`, `swift test --package-path packages/ios-layers`, iOS 유닛 테스트(`BaseballIOSTests`) 통과. iOS 테스트는 한 번에 하나만 실행(동시 실행 금지).
8. `apps/ios/project.yml` 변경 시 `xcodegen generate` 후 pbxproj 갱신.

## 3. 작업 순서 제안

1. 코드 읽기: ProCareer.swift 429~820, 1757~1800, 1952~2100, ProCareerModels.swift 115~300·480~540, MobileCareerStore+Season.swift, ProSeasonDecisionView.swift, ProCareerPresentation.swift 72~105·548~625, GameContent.xcstrings의 `content.pro-decision.*` 항목, ProCareerBootstrapCharacterizationTests.swift 286~330.
2. 코어: 규칙 v9 + 게이트 → 타입·모델·modifier·follow-up → planWeek 배선 → decisionContent 추가 → 테스트.
3. 앱: 프레젠테이션 리졸버 → xcstrings ko/en/ja → 뷰 → 분석 이벤트 → LocalizationCoverageTests 추가.
4. 게이트 실행 후 보고서 작성.

## 4. 산출물

- 코드 변경(미커밋 상태로 둔다).
- `docs/PRO_WEEKLY_DECISION_HOOK_REPORT_2026-09-02.md`: 변경 파일 목록, 실행한 테스트·게이트와 결과(실패 포함 원문), 밸런스 수치 조정 내역, 미해결 사항, 픽스처 영향 여부.
