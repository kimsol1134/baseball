# P1-1 커리어 목표판 구현 보고

구현: grok-4.6. 스펙: `docs/P1_CAREER_GOAL_BOARD_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음. 픽스처 재생성 없음. 시뮬레이터는 부팅된 iPhone 17만 재사용.

HEAD: e82f0a51abab575660be90cdba367119b6a1f0cf.

## 0. 규칙 준수

- 새 영속 필드를 넣지 않았다. `ProCareerJourneyState`·`ProCareerSnapshot`·`canonicalToken` 미변경.
- `planWeek` RNG 스트림에 `next*()`를 넣지 않았다.
- 골든 픽스처(`swift-pro-career-oracle-v1/v2.json`, `simulate_pitch_golden.json`, 고교 v3)를 재생성하지 않았다.
- 다른 엔지니어 예약 파일 5종(`CatcherRecommendationEngine.swift`, `ProRivalBatter+Stats.swift`, `AutoOutingSimulator.swift`, `PitchSession.swift`, `ScoutingEstimate.swift`)은 건드리지 않았다.
- ko/en/ja 카탈로그를 넣었다. 실존 구단·선수명 없음. 투구 슬라이더 코드는 접근하지 않았다.
- 테스트 삭제·단언 약화 없음. 뷰는 `MobileCareerStore`/`CareerDisplayRules` 프로젝션만 쓴다.

## 1. 변경 파일

이 작업에서 직접 손댄 파일만 적는다. `docs/REVIEW_REPLIES_1_2_7.md`와 워킹트리의 다른 미커밋·미추적 산출물은 그대로 두었다.

### simulation-core
- `packages/simulation-core/Sources/SimulationCore/ProCareerGoalBoardRules.swift` — 파생 목표판, 정수 퍼밀, 정렬·nearest
- `packages/simulation-core/Sources/SimulationCore/ProCareerMilestoneRules.swift` — 경기 [50,100,300]·탈삼진 [50,100,200,500] 단일화
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` — 주간 마일스톤 문자열이 공유 규칙을 씀
- `packages/simulation-core/Sources/SimulationCore/ProCareer+Journey.swift` — recognition contentID가 공유 규칙을 씀
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerGoalBoardTests.swift` — kind별 퍼밀, 완료 잠금, target 0 방지, 정렬·nearest, 마일스톤 바이트 동일

### iOS
- `apps/ios/Sources/Application/CareerDisplayRules.swift` — `goalBoard` / `goalPermille` / `goalPermilleBand`
- `apps/ios/Sources/Application/MobileCareerStore+Queries.swift` — 같은 프로젝션을 스토어에 노출
- `apps/ios/Sources/Platform/GameAnalytics.swift` — `pro_goal_board_viewed`
- `apps/ios/Sources/Features/Shell/AppShell.swift` — 기록 탭으로 옮기는 `appTabSelection` 환경
- `apps/ios/Sources/Features/Shell/RecordView.swift` — 프로 기록 탭 상단 목표판 카드
- `apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift` — 주간 한 줄, 탭하면 기록 탭
- `apps/ios/Sources/Presentation/ProCareerPresentation.swift` — `GoalPermilleBar`, 정산 메트릭 게이지
- `apps/ios/Sources/Presentation/ProFeatureCopy.swift` — 주간 한 줄 Presentation 헬퍼
- `apps/ios/Sources/Presentation/Localization/ProCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/RecordCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/Localizable.xcstrings`
- `apps/ios/Sources/Presentation/Localization/GameContent.xcstrings`
- `apps/ios/Tests/LayerBoundaryTests.swift` — 뷰가 보드·마일스톤·은퇴 규칙을 직접 부르지 못하게 강화
- `apps/ios/Tests/LocalizationCoverageTests.swift` — 목표판 ko/en/ja 패리티
- `apps/ios/Tests/ProCareerGoalBoardSurfaceTests.swift`
- `apps/ios/Tests/CopyCallerContractTests.swift` — 주간 한 줄 헬퍼 호출 고정
- `docs/localization/ios-copy-schema.json` — `inventory:ios-localization --write`
- `tools/inject-goal-board-copy.mjs` — 카탈로그 키 주입용 일회 스크립트
- `apps/ios/Baseball.xcodeproj/project.pbxproj` — 신규 테스트 파일을 넣기 위해 `xcodegen generate`

`apps/ios/project.yml`은 이 작업에서 바꾸지 않았다.

## 2. 행 정의와 hint 문구

보드 전부 파생. 정수 퍼밀 = `min(1000, current * 1000 / max(target, 1))`. 완료 잠금이면 current가 target 아래여도 `completed = true`, `permille = 1000`. 미완료는 permille 내림차순, 완료는 뒤. `nearest`는 미완료 1위.

| kind | id | title (ko / en / ja) | hint (ko) |
|---|---|---|---|
| ambition_metric | `ambition.<ambition>.<metric>` | 기준 구단 시즌 / Anchor-team seasons / アンカーチーム在籍年数 | 같은 팀에서 시즌을 이어 한 구단의 상징에 다가갑니다. |
| ambition_metric | | 기준 구단 유산 / Anchor-team legacy / アンカーチームのレガシー | 한 팀의 레거시 점수를 80까지 올립니다. |
| ambition_metric | | 명예의 전당 예상 / Hall of Fame projection / 殿堂入り予想 | 통산 성적과 수상으로 명예의 전당 예측을 올립니다. |
| ambition_metric | | 인정 수상 / Recognized awards / 認定された受賞 | 시즌 수상을 모아 기록으로 남깁니다. |
| ambition_metric | | 프로 시즌 / Pro seasons / プロ在籍シーズン | 시즌을 이어 프로 생활을 길게 가져갑니다. |
| ambition_metric | | 1군 등록 / Major-league service / 一軍在籍 | 1군 시즌을 쌓아 근속을 채웁니다. |
| retired_number | `retiredNumber` | 영구결번 / Retired number / 永久欠番 | 이적하면 마지막 팀 시즌과 레거시가 다시 쌓입니다. |
| club_hall | `clubHall` | 구단 명예의 전당 / Club hall / 球団殿堂 | 영구결번을 받은 팀은 구단 명예의 전당에서 빠집니다. |
| hall_of_fame | `hallOfFame` | 명예의 전당 / Hall of Fame / 殿堂入り | 시즌을 쌓고 수상하면 예측 점수가 오릅니다. |
| milestone_games | `milestoneGames` | 통산 경기 / Career games / 通算登板 | 등판을 이어 다음 경기 기록에 닿습니다. |
| milestone_strikeouts | `milestoneStrikeouts` | 통산 탈삼진 / Career strikeouts / 通算奪三振 | 삼진을 모아 다음 탈삼진 기록에 닿습니다. |
| team_legacy_tier | `teamLegacyTier` | 팀 레거시 / Team legacy / チームレガシー | 한 팀에서 시즌을 이어 레거시 점수를 올립니다. |

영구결번 subRows: 마지막 팀 시즌 8 / 마지막 팀 레거시 80 / 팬 지지 60. 전체 permille = 세 subRow permille의 최소값.

구단 명예의 전당 subRows: 구단 시즌 6 / 구단 레거시 65. 영구결번 달성 팀은 `ProRetirementRules.preview`와 같이 제외.

명예의 전당: 현역은 `hallOfFameProjection`, 은퇴 후는 `hallOfFameScore` vs 70.

통산 마일스톤 문자열·contentID는 기존과 바이트 동일:

- `프로 통산 50경기` / `pro.milestone.career.games.50`
- `프로 통산 100경기` / `pro.milestone.career.games.100`
- `프로 통산 300경기` / `pro.milestone.career.games.300`
- `프로 통산 50탈삼진` / `pro.milestone.career.strikeouts.50`
- `프로 통산 100탈삼진` / `pro.milestone.career.strikeouts.100`
- `프로 통산 200탈삼진` / `pro.milestone.career.strikeouts.200`
- `프로 통산 500탈삼진` / `pro.milestone.career.strikeouts.500`

정적 UI (Localizable):

- `record.goal-board.title` 커리어 목표판 / Career goal board / キャリア目標板
- `pro.weekly.goal-board.title` 다음 목표 / Next goal / 次の目標
- `pro.weekly.goal-board.line` `%@ %lld/%lld`
- `pro.weekly.goal-board.hint` 기록 탭에서 목표판을 엽니다 / Opens the goal board on Records / 記録タブで目標板を開きます

접근성 ID: `pro.goalBoard`, `pro.goalBoard.row.<id>`, `pro.weekly.goalBoard`.

분석: `CareerTelemetry.logOnce(.proGoalBoardViewed, scope: careerID)` — `nearest_kind`, `nearest_permille` 밴드(`0_249` / `250_499` / `500_749` / `750_999` / `1000`).

## 3. 게이트 원문 결과

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`. 새로 만들지 않았다. xcodebuild는 한 번에 하나만 돌렸다. 첫 실행은 `CopyCallerContractTests.testProFeatureViewsDoNotAssembleCopyArguments`가 Features/Pro의 `arguments:`를 잡아 종료 65. 주간 한 줄을 `ProWeeklyCopy.goalBoardLine`으로 옮긴 뒤 같은 부팅 기기에서 한 번 더 돌렸다.

### 3.1 `swift test --package-path packages/simulation-core`

종료 코드 0.

```
Test Suite 'BaseballSimulationPackageTests.xctest' passed at 2026-09-02 18:47:05.624.
	 Executed 558 tests, with 1 test skipped and 0 failures (0 unexpected) in 463.665 (463.702) seconds
Test Suite 'All tests' passed at 2026-09-02 18:47:05.625.
	 Executed 558 tests, with 1 test skipped and 0 failures (0 unexpected) in 463.665 (463.703) seconds
WAVE5_DISTRIBUTION seeds=1000 seasons=20 negative_funds=0 duplicate_finance=0 duplicate_settlement=0 contractless_active_seasons=0 season3_before_fan100=0
```

`ProCareerGoalBoardTests` 10/10 포함. `ProCareerEngineTests`·`ProCareerJourneyMigrationTests` 골든 픽스처 무변경 통과.

### 3.2 `swift test --package-path packages/ios-layers`

종료 코드 0.

```
Test Suite 'BaseballIOSLayersPackageTests.xctest' passed at 2026-09-02 18:39:46.587.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.006 (0.007) seconds
Test Suite 'All tests' passed at 2026-09-02 18:39:46.587.
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
Test Suite 'All tests' passed at 2026-09-02 18:57:30.360.
	 Executed 558 tests, with 1 test skipped and 0 failures (0 unexpected) in 481.132 (481.178) seconds
```

test:web:

```
 Test Files  30 passed (30)
      Tests  103 passed (103)
   Start at  18:57:30
   Duration  524ms (transform 868ms, setup 0ms, import 1.46s, tests 145ms, environment 675ms)
```

build:web:

```
✓ built in 116ms
```

test:tauri:

```
test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.03s
```

check:tauri:

```
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.19s
```

정적 게이트(이미 `npm run check` 전에도 통과):

`npm run check:ios-localization` 종료 코드 0.

```
iOS localization release check passed: 3804 catalog entries and zero pending surfaces
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
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 19:03:33.546.
	 Executed 540 tests, with 0 failures (0 unexpected) in 106.867 (107.051) seconds
Test Suite 'All tests' passed at 2026-09-02 19:03:33.546.
	 Executed 540 tests, with 0 failures (0 unexpected) in 106.867 (107.052) seconds
** TEST SUCCEEDED **
```

`LayerBoundaryTests`·`LocalizationBoundaryTests`·`LocalizationCoverageTests.testGoalBoardCopyHasKoreanEnglishJapaneseParity`·`ProCareerGoalBoardSurfaceTests` 포함.

## 4. 미해결

- Android Kotlin 포팅은 스펙 범위 밖.
- 커밋하지 않음.
- 영구결번만 있는 단일 팀이면 구단 명예의 전당 행은 제외 규칙 때문에 0‰로 남을 수 있다. nearest는 더 가까운 미완료 칸을 고른다.
- compact CopyDensity는 주간 한 줄의 힌트만 접는다. 제목·current/target은 남긴다.
