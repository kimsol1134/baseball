# P1-1 커리어 목표판 스펙

작성: PM, 2026-09-02. 구현: grok. 리뷰 근거: "한 팀 프차·영구결번 미션조차 없음", "목표 지향성이 떨어짐"(2★), "80 찍으면 할 게 없음"(4★ 2건), "환생 메리트 없음"(1★). 목표: 커리어 중반 이후에도 "다음에 채울 칸"이 항상 보이게 한다.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. main 워킹트리에서 작업(HEAD e82f0a51).
2. **새 영속 필드 금지.** 목표판은 전부 파생 값이다. `ProCareerJourneyState`·`ProCareerSnapshot`에 필드를 추가하지 않는다(canonicalToken·골든 픽스처가 깨진다). `ProCareerJourneyRules.canonicalToken` 미변경.
3. 프로 주간 루프 RNG 무삽입. 골든 픽스처(`swift-pro-career-oracle-v1/v2.json`, `simulate_pitch_golden.json`, 고교 v3) 재생성 금지.
4. ko/en/ja 필수, `npm run check:ios-localization`·`check:copy`·`check:design-system` 통과. 실존 구단명 금지. 뷰는 엔진 직접 호출 금지(`LayerBoundaryTests`), 투구 슬라이더 접근 금지.
5. 테스트 삭제·약화 금지. iOS 테스트는 한 번에 하나, 부팅된 iPhone 17 재사용. **다른 엔지니어가 같은 시각에 별도 워크트리에서 코어 작업 중이다. 이 작업은 `CatcherRecommendationEngine.swift`, `ProRivalBatter+Stats.swift`, `AutoOutingSimulator.swift`, `PitchSession.swift`, `ScoutingEstimate.swift`를 건드리지 않는다.**

## 1. 기존 자산 (재사용, 새로 만들지 말 것)
- 장기 목표: `ProCareerAmbition`(franchiseIcon/recordBook/enduringPro), `ProCareerGoalRules.expectedMetrics/progress` (ProCareerJourney.swift:1357~). target 상수: franchiseIcon(anchorTeamSeasons 8, anchorTeamLegacy 80), recordBook(hallOfFameProjection 70, awards 3), enduringPro(proSeasons 12, majorServiceYears 8).
- 은퇴 훈장 조건: `ProRetirementRules.preview(for:)` (ProCareerJourney.swift:839~). 영구결번 = 마지막 팀 시즌 ≥ 8 && 레거시 ≥ 80 && 팬 지지 ≥ 60. 클럽 명예의 전당 = 시즌 ≥ 6 && 점수 ≥ 65. 명예의 전당 = 최종 점수 ≥ 70. `ProRetirementPreview`는 은퇴 전에도 호출 가능하며 lastTeamSeasons/lastTeamLegacy/fanSupport를 가진다.
- 팀 레거시: `ProTeamLegacyRules.nextTierProjection(record:rulesVersion:)`, `ProTeamCareerRecordRules.score`(rulesVersion 필수).
- HOF 예측: `ProCareerEngine.hallOfFameProjection(for:)`.
- 통산 마일스톤 임계값이 `ProCareer.swift:765`(경기 [50,100,300], 탈삼진 [50,100,200,500])와 `ProCareer+Journey.swift:263`에 중복 하드코딩.
- iOS 조회 계층: `MobileCareerStore+Queries.swift`(retirementPreview :150, hallOfFameProjection :154, teamLegacyProjection :182, goalProgress :209). 메트릭 뷰 `ProCareerGoalMetricsView`(ProCareerPresentation.swift:1093). 기록 화면 `RecordView.swift`(awards :481, milestones :497, HOF :516, 팀 기록 :530).

## 2. 기능

### 2.1 코어: `ProCareerGoalBoardRules` (SimulationCore, 새 파일, 순수 함수)
`board(state: ProCareerSnapshot) -> ProCareerGoalBoard`. 정수만 사용(퍼밀 = min(1000, current*1000/target), target 0 방지).

행(`ProGoalBoardRow`): `id`, `kind`(enum: ambitionMetric, retiredNumber, clubHall, hallOfFame, milestoneGames, milestoneStrikeouts, teamLegacyTier), `titleKey`, `current`, `target`, `permille`, `completed`, `hintKey`(다음 행동 한 줄), `subRows`(영구결번의 3조건처럼 복합 조건일 때).
- 장기 목표: `ProCareerGoalRules.progress` 메트릭을 행으로. 완료 잠금 상태면 현재값이 target 아래여도 `completed = true, permille = 1000`(정합성 규칙 `settlementMetricsAreConsistent` 존중).
- 영구결번: 3 subRows(마지막 팀 시즌/레거시/팬 지지)를 `ProRetirementRules.preview`로. 전체 permille = 세 subRow permille의 최소값. 팀 이적 시 마지막 팀 기준으로 리셋되는 점을 hint로 표시.
- 클럽 명예의 전당: 2 subRows. 영구결번 달성 팀은 제외 규칙 그대로.
- 명예의 전당: `hallOfFameProjection` vs 70. 은퇴 후엔 `hallOfFameScore` 확정치.
- 통산 마일스톤: 경기·탈삼진 각각 "다음 임계값" 1행. 임계값 배열을 `ProCareerMilestoneRules`(새 파일)로 올리고 기존 두 사용처가 그 배열을 쓰게 한다. **기존 출력(마일스톤 문자열·recognition contentID)은 바이트 동일** — 테스트로 고정.
- 팀 레거시: 현재 티어 → 다음 티어 점수. rulesVersion을 레코드에서 읽는다.
- 정렬: 미완료 중 permille 높은 순, 완료는 뒤. `nearest: ProGoalBoardRow?` = 미완료 1위.

### 2.2 iOS
- **기록 탭 상단 "커리어 목표판" 카드**(프로 커리어일 때만): 행마다 제목·현재/목표·게이지(정수 퍼밀, 디자인 시스템 토큰), 완료 행은 체크. subRows는 접힘. 접근성 ID `pro.goalBoard.row.<id>`.
- **주간 계획 화면 한 줄**: "다음 목표 · <nearest 제목> <current>/<target>" 카드(기존 카드 스타일). 탭하면 기록 탭 목표판으로 이동. 접힘 규칙은 `CopyDensity` 존중.
- **시즌 정산**: 정산 화면 목표 메트릭 뷰(`ProCareerGoalMetricsView`)에 퍼밀 게이지를 추가(기존 텍스트 유지).
- 조회 계층: `MobileCareerStore+Queries.swift`에 `nonisolated static func goalBoard(state:) -> ProCareerGoalBoard` 패턴으로 추가. 뷰는 스토어 프로젝션만 쓴다.
- 분석: `GameAnalytics.Event.proGoalBoardViewed = "pro_goal_board_viewed"` (nearest_kind, nearest_permille 밴드 속성), `CareerTelemetry.logOnce`.
- 문구: `content.goal-board.<kind>.title|hint` ko/en/ja (GameContent.xcstrings), 정적 UI는 `Localizable.xcstrings` + `ProUICopyKey`/`RecordCopyKeys`.

## 3. 수용 기준
1. 규칙 테스트: 각 kind별 permille 계산, 완료 잠금 시 1000 유지, target 0 방지, 정렬·nearest.
2. 마일스톤 임계값 단일화 후 기존 `ProCareerEngineTests`·`ProCareerJourneyMigrationTests`·골든 픽스처 무변경 통과.
3. iOS: RecordView 목표판 카드와 주간 한 줄이 프로 커리어에서 보이고 고교에서는 보이지 않는다(뷰 계약 테스트 + 접근성 ID). `LayerBoundaryTests`·`LocalizationBoundaryTests` 통과.
4. ko/en/ja 전부 존재, LocalizationCoverageTests 패리티 테스트 추가.
5. 게이트: `swift test --package-path packages/simulation-core`, `swift test --package-path packages/ios-layers`, `npm run check`, `npm run run:pro-career:distribution:smoke`, iOS `BaseballIOSTests` 전체. 모두 종료 코드 0.

## 4. 산출물
`docs/P1_CAREER_GOAL_BOARD_REPORT_2026-09-02.md`: 변경 파일, 행 정의와 hint 문구 목록, 게이트 원문, 미해결.
