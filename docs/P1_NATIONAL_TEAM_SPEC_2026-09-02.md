# P1-4 국가대표 대회 스펙

작성: PM, 2026-09-02. 구현: grok (워크트리 `/Users/solkim/Dev/baseball-wt-national`, 브랜치 `p1/national-team`). 리뷰 근거: "국가대표 대회를 통한 군복무 면제"(5★), "한국시리즈·WBC 등 대회가 많은데 일반 경기만"(3★), "WBC·메이저리그 업데이트"(5★). 목적: 커리어 중반에 굴곡과 새 목표를 만든다.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. **이 워크트리에서만** 작업. main 트리 접근 금지.
2. **xcodebuild·npm 실행 금지**(다른 엔지니어가 시뮬레이터·iOS 테스트 점유). 검증은 `swift test`(simulation-core, ios-layers)와 `swift build`까지. iOS 뷰·테스트는 작성만 하고 PM이 병합 후 직렬 실행한다.
3. 모든 새 동작은 `ProCareerEngine.usesNationalTeamRules(state)`(proRulesVersion ≥ 10, 이미 존재) 뒤에. v9 이하 저장 바이트 동일. 프로 주간 루프(`planWeek`) RNG 무삽입. 대회 시뮬은 오프시즌 경로의 시드(`nextSeed`)에서 파생한 **별도 SplitMix64**로 돌리고, 오프시즌의 기존 draw 순서는 보존한다.
4. 골든 픽스처 재생성 금지. 실존 국가명·리그·구단·선수명 금지(AGENTS.md) — 대회 이름과 상대 팀은 가상 명칭(예: "환태평양 초청 대회", 상대는 지역 이름 기반 가상 대표팀).
5. **`ProCareerPhase`에 새 케이스를 추가하면 구버전 앱이 저장을 못 읽는다.** 따라서 `ProCareerPersistence`에 `nationalTeamSchemaVersion = 6`을 추가하고 `schemaVersion(for:)`가 대회 상태가 있는 저장에만 6을 찍게 한다. `currentSchemaVersion = 6`. `canWrite` 로직(빌드 상수 비교)은 유지.
6. **다른 엔지니어가 main에서 FA 계약을 만들고 있다.** 이 작업은 `ProContractMarketRules.swift`, `ProContractOfferView.swift`, `ProOffseasonInvestmentView.swift`, 재정(`ProFinance*`)을 건드리지 않는다. `chooseJourneyOffseason`은 대회 분기 삽입 최소한으로만 수정한다.
7. ko/en/ja 문구 작성(카탈로그 파일 편집은 하되 npm 게이트는 PM이 실행). 테스트 삭제·약화 금지. 작업 끝에 워크트리 `.build` 삭제.

## 1. 기존 구조 (조사 결과)
- 포스트시즌이 대회의 모범: `ProPostseason.swift`의 `ProPostseasonState/SeriesState/GameLine`, `ProPostseasonRules`(trigger·winsRequired·shouldDirectlyPlayNextGame·stakes). 직접 플레이 파이프라인: 엔진이 `phase = .importantGame` + `seasonTrigger` → `CareerFlowView`가 `ImportantGameIntro`/`PitchView` → `MobileCareerStore+ImportantGame.beginImportantGame/finishImportantGame` → `PitchScenario.pro(state:)`의 `ProMoment`(seasonTrigger 1:1 매핑).
- 병역: `militaryCompleted: Bool`, `OffseasonDecision.military_service`(2년 나이 진행, 팬 −3). 면제 개념 없음.
- 평판·수상: `ProReputationState.fanSupport`, `ProCareerRecognition(kind: award|milestone, contentID)`, `ProFanReasonKind`.
- 규칙 게이트 관례: `usesXxxRules(_:)`. 페이즈 검증 `validateState`/저니 스위치(ProCareer+Journey.swift:1430~), `activePhases`.

## 2. 기능 (v10에서만)

### 2.1 선발
- 시점: 시즌 정산 후 오프시즌 진입 시(`chooseJourneyOffseason` 이전), **2년마다**(season % 2 == 0), season ≥ 2, age ≤ 31, 은퇴 결정 아님.
- 조건: 그 시즌 `marketScore ≥ 55` 또는 시즌 수상 1개 이상 또는 팬 지지 ≥ 60. 결정적.
- 흐름: 새 페이즈 `.nationalTeamCall`(소집 통보: 수락/사양). 사양 → 팬 −2, 뉴스, 오프시즌 계속. 수락 → `.nationalTournament`.

### 2.2 대회 구조 (`ProNationalTournament.swift`, 새 파일)
- 가상 대회 이름 1개(문구 키), 상대 가상 대표팀 4개(지역 기반 이름, 강도 등급 A~D).
- 조별 3경기(자동 시뮬, 기존 `AutoOutingSimulator`를 대회 강도 offset으로 호출) → 2승 이상이면 결승 진출. **결승은 직접 플레이 1경기**(승부처 이닝; 기존 중요경기 파이프라인 재사용: `seasonTrigger = .nationalFinal`, `ProMoment.nationalFinal`, 타자 강도 offset은 포스트시즌 결승과 동일하게 시작해 보고서에 값 기록). 진출 실패 시 3위 결정전은 자동.
- 상태: `ProNationalTournamentState { seed, groupGames: [line], stage, finalLine?, result: gold/silver/bronze/groupExit, fatigueCarry }`를 스냅샷 Optional 필드 `nationalTournament`에 저장. 대회 종료 시 `nationalTeamHistory: [ProNationalTeamRecord]?`(season, result, directGameLine)에 append하고 `nationalTournament = nil`.
- 대회 등판은 시즌 기록(`currentStats`/`careerStats`)에 **합산하지 않고** 별도 기록으로 둔다(리그 기록 정합성). 기록 화면에 "국가대표" 섹션.

### 2.3 보상·대가
- 금: `militaryCompleted == false`이면 **true로 전환(면제)** + 뉴스·마일스톤 `pro.milestone.national.gold`, 팬 +8, 수상 recognition `pro.award.national-gold`(contentID), 명예의 전당 점수 보너스 +4(hofScore 경로에 v10 가산).
- 은: 팬 +4, recognition `pro.award.national-silver`. 동: 팬 +2. 조별 탈락: 팬 ±0, 뉴스.
- 대가: 다음 시즌 스프링캠프 시작 피로 +15(`fatigueCarry`), 결승 직접 등판에서 투구 수 80 이상이면 +25. 대회 중 부상 판정 1회(대회 시드로, 압력 = 시작 피로 기반; 부상 시 다음 시즌 회복 주 2~4).
- 해외 관심 훅: 금·은이면 `journeyState.reputation`에 `overseasInterest: Bool?` 필드(Optional, 기본 nil)를 true로 두고 뉴스 1줄. 실제 진출은 이번 범위 밖.

### 2.4 iOS (작성만, 실행은 PM)
- `ProNationalTeamViews.swift`: 소집 통보 화면(수락/사양, 조건 요약, 대가 안내), 대회 진행 화면(조별 3경기 결과 리스트·결승 진출 여부·"결승 직접 등판" 버튼), 결과 카드(메달·면제 여부·팬 변화). 접근성 ID `pro.nationalTeam.call.accept/decline`, `pro.nationalTeam.final.start`, `pro.nationalTeam.result`.
- `CareerFlowView`에 `.nationalTeamCall`, `.nationalTournament` 분기. `ProMoment.nationalFinal` 매핑, `ProImportantGameIntro`에 대회 문구 분기.
- `RecordView` "국가대표" 섹션(이력 표). 은퇴 훈장에 `national_gold` 추가(`ProRetirementHonorKind`).
- 문구 ko/en/ja: `content.national-team.*`, `pro.nationalTeam.*` 키. 용어 사전 "국가대표 소집", "병역 면제" 2항목.
- 텔레메트리 `pro_national_team_called`(accepted), `pro_national_team_result`(result, exempted).

## 3. 수용 기준
1. v10 커리어에서 조건 충족 시즌의 오프시즌에 소집 페이즈가 열리고, 수락 → 조별 3경기 → 결승(직접 플레이 트리거) → 결과 → 오프시즌 결정으로 이어진다(코어 통합 테스트: 결승은 `resolveImportantGame` 경로로 결과 주입).
2. 금 획득 시 `militaryCompleted == true`, 팬 +8, recognition 생성. 이미 병역 완료면 면제 대신 팬 +10.
3. 사양 시 팬 −2, 페이즈 복귀. 2년 뒤 다시 소집 가능.
4. v9 저장 로드 → 오프시즌 진행 결과 바이트 동일(회귀). 대회 상태 없는 v10 저장의 schemaVersion은 5 유지, 대회 상태 있으면 6(테스트).
5. `swift test --package-path packages/simulation-core` 전체, `swift test --package-path packages/ios-layers` 종료 코드 0. iOS 테스트 파일(스토어·뷰 계약·LocalizationCoverage) 작성.

## 4. 산출물
`docs/P1_NATIONAL_TEAM_REPORT_2026-09-02.md`(워크트리 안): 변경 파일, 선발 조건·강도 offset·보상 표, 시드 파생 방식, 게이트 원문, **PM이 병합 후 실행할 명령 목록**(iOS 테스트·npm 게이트), 미해결.
