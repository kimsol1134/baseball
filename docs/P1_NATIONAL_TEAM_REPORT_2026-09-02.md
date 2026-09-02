# P1-4 국가대표 대회 구현 보고 (2026-09-02)

구현: grok-4.6. 스펙: `docs/P1_NATIONAL_TEAM_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음. 픽스처 재생성 없음. xcodebuild·npm 미실행.

## 0. 규칙 준수

- 워크트리 `/Users/solkim/Dev/baseball-wt-national`만 수정. main 트리(`/Users/solkim/Dev/baseball`) 미접근.
- `planWeek`에 RNG `next*()`를 넣지 않았다. 대회 시뮬은 `nextSeed`를 FNV-1a로 해시한 **별도 SplitMix64**만 쓴다. 수락·사양·결승 주입 뒤 `nextSeed`는 오프시즌 진입 시 원래 값으로 복구된다.
- 모든 새 동작은 `ProCareerEngine.usesNationalTeamRules` (`proRulesVersion >= 10`) 뒤에 있다. v9 이하는 소집 페이즈에 들어가지 않는다.
- `ProCareerPersistence.nationalTeamSchemaVersion = 6`, `currentSchemaVersion = 6`. 대회 상태(진행 중 토너먼트·이력·캐리·소집/대회 페이즈·결승 트리거)가 있는 저장만 6을 찍는다. 대회 없는 v10은 기존처럼 5(또는 더 낮은 세대)를 유지한다. `canWrite`의 빌드 상수 비교는 그대로다.
- `ProContractMarketRules.swift`, `ProContractOfferView.swift`, `ProOffseasonInvestmentView.swift`, `ProFinance*` 미수정. `chooseJourneyOffseason`은 다음 시즌 시작 피로/부상 캐리 적용만 넣었다.
- 대회명·상대 팀은 가상 명칭만 쓴다. 실존 구단·리그·선수명 없음. 골든 픽스처 재생성 없음. 테스트 삭제·약화 없음.

## 1. 변경 파일

### simulation-core
- `packages/simulation-core/Sources/SimulationCore/ProNationalTournament.swift` — 상태·상대·선발·보상 규칙 (신규)
- `packages/simulation-core/Sources/SimulationCore/ProCareerModels.swift` — 페이즈 2개, `nationalFinal` 트리거, 스냅샷 Optional 3필드, 커맨드 파라미터
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` — 소집 분기, 수락/사양/결승/결과, `resolveImportantGame` 결승 경로, HOF +4, `replacing`
- `packages/simulation-core/Sources/SimulationCore/ProCareer+Journey.swift` — 정산 확인 후 소집, 페이즈 검증, 다음 시즌 캐리
- `packages/simulation-core/Sources/SimulationCore/ProCareerJourney.swift` — `overseasInterest`, 은퇴 훈장 `national_gold`
- `packages/simulation-core/Sources/SimulationCore/Presentation/CopyToken.swift` — 닫힌 enum 목록
- `packages/simulation-core/Tests/SimulationCoreTests/ProNationalTeamTests.swift` — 신규
- `packages/simulation-core/Tests/SimulationCoreTests/PresentationCopyTokenTests.swift`

### ios-layers
- `packages/ios-layers/Sources/BaseballIOSPersistence/ProCareerPersistence.swift`
- `packages/ios-layers/Sources/BaseballIOSDomain/GlossaryCatalog.swift`
- `packages/ios-layers/Tests/BaseballIOSPersistenceTests/ProCareerCodecTests.swift`

### iOS (작성만, 실행은 PM)
- `apps/ios/Sources/Features/Pro/ProNationalTeamViews.swift` — 신규
- `apps/ios/Sources/Features/Pro/CareerFlowView.swift`
- `apps/ios/Sources/Features/Pro/ProImportantGameIntro.swift`
- `apps/ios/Sources/Features/Pro/ProRetirementViews.swift`
- `apps/ios/Sources/Features/Pitch/PitchScenario.swift`
- `apps/ios/Sources/Features/Shell/RecordView.swift`
- `apps/ios/Sources/Application/CareerDisplayRules.swift`
- `apps/ios/Sources/Application/MobileCareerStore+Season.swift`
- `apps/ios/Sources/Application/MobileCareerStore+ImportantGame.swift`
- `apps/ios/Sources/Platform/GameAnalytics.swift`
- `apps/ios/Sources/Presentation/ProFeatureCopy.swift`
- `apps/ios/Sources/Presentation/ProCareerPresentation.swift`
- `apps/ios/Sources/Presentation/PitchPresentation.swift`
- `apps/ios/Sources/Presentation/Localization/ProCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/GameContent.xcstrings`
- `apps/ios/Sources/Presentation/Localization/Localizable.xcstrings`
- `apps/ios/Tests/ProNationalTeamTests.swift` — 신규
- `apps/ios/Tests/LocalizationCoverageTests.swift` — 용어 22개 패리티

## 2. 선발·강도·보상

시점: 시즌 정산 확인(`acknowledgeSettlement`) 직후, `chooseJourneyOffseason` 이전. 은퇴 강제 루트는 건너뛴다.

| 조건 | 값 |
|---|---|
| 규칙 | `proRulesVersion >= 10` |
| 시즌 | `season >= 2` 이고 `season % 2 == 0` |
| 나이 | `age <= 31` |
| 자격 (하나면 됨) | `marketScore >= 55` 또는 그 시즌 수상 ≥ 1 또는 팬 지지 ≥ 60 |

사양: 팬 −2, 뉴스 키, 오프시즌 복귀. 2년 뒤 다시 소집 가능.

대회 이름 키: `content.national-team.tournament.name` → "환태평양 초청 대회".

| 상대 ID | 등급 | batterOffset |
|---|---|---|
| south-harbor (남해 항구 연합) | D | 2 |
| northern-plains (북방 평원 대표) | C | 4 |
| southwest-isles (서남 열도 대표) | B | 5 |
| east-coast (동해 연안 연합) | A, 결승 | **6** (`ProPostseasonRules.extraOffset(.final)`과 동일) |

조별 3경기(D/C/B)는 `AutoOutingSimulator`(18아웃, 투구 상한 96). 2승 이상이면 결승 직접 등판. 미달은 3위 결정전 자동. 대회 성적은 `currentStats`/`careerStats`에 합산하지 않고 `nationalTeamHistory`에만 남긴다.

| 결과 | 팬 | 그 외 |
|---|---|---|
| 금 | +8 (이미 병역 완료면 +10) | `militaryCompleted = true`(면제), 마일스톤 `pro.milestone.national.gold`, 수상 `pro.award.national-gold`, HOF +4, `overseasInterest = true` |
| 은 | +4 | `pro.award.national-silver`, `overseasInterest = true` |
| 동 | +2 | 뉴스 |
| 조별 탈락 | 0 | 뉴스 |

대가: 다음 스프링캠프 시작 피로 +15. 결승 직접 등판 투구 수 ≥ 80이면 +25. 대회 시드로 부상 판정 1회(압력 = 소집 시점 피로, 성공 시 회복 주 2~4).

## 3. 시드 파생

```
StableHash.fnv1a64Value("national-tournament:\(nextSeed)")
```

이 UInt64로 SplitMix64를 연다. 조별·동메달 자동 경기와 부상 판정만 이 스트림을 소비한다. 커리어 `nextSeed`는 수락 시 `resumeSeed`로 저장했다가 결과 확인 후 그대로 반환한다. 오프시즌 계약 시장 draw 순서는 대회를 거치지 않은 것과 같다.

결승 승패는 플레이어 `ImportantInningReport`(테스트는 `teamRuns` 주입)로 결정하며 오프시즌 시드를 굴리지 않는다.

게이트 원문:

```
usesNationalTeamRules(_ state: ProCareerSnapshot) -> Bool {
    (state.proRulesVersion ?? 1) >= nationalTeamRulesVersion  // 10
}
```

스키마:

```
hasNationalTeamState → nationalTeamSchemaVersion (6)
그 외 기존 mastery(5) / repertoire(4) / journey(3) / legacy(2)
```

## 4. 실행한 테스트

### `swift test --package-path packages/simulation-core`

종료 코드 0.

```
Test Suite 'BaseballSimulationPackageTests.xctest' passed at 2026-09-02 20:37:08.961.
	 Executed 576 tests, with 1 test skipped and 0 failures (0 unexpected) in 459.389 (459.429) seconds
Test Suite 'All tests' passed at 2026-09-02 20:37:08.961.
	 Executed 576 tests, with 1 test skipped and 0 failures (0 unexpected) in 459.389 (459.430) seconds
WAVE5_DISTRIBUTION seeds=1000 seasons=20 negative_funds=0 duplicate_finance=0 duplicate_settlement=0 contractless_active_seasons=0 season3_before_fan100=0
```

`ProNationalTeamTests` 7/7 포함.

### `swift test --package-path packages/ios-layers`

종료 코드 0.

```
Test Suite 'BaseballIOSLayersPackageTests.xctest' passed at 2026-09-02 20:29:45.835.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.006 (0.007) seconds
Test Suite 'All tests' passed at 2026-09-02 20:29:45.835.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.006 (0.008) seconds
```

스키마 테스트: 대회 없는 v10은 6 미만, 대회 상태 있으면 6.

## 5. PM이 병합 후 실행할 명령

iOS 시뮬레이터는 부팅된 기기 하나만 재사용한다. xcodebuild는 한 번에 하나만.

```
# 1) 코어 재확인 (이미 이 워크트리에서 통과)
swift test --package-path packages/simulation-core
swift test --package-path packages/ios-layers

# 2) iOS 테스트 (이 작업에서 작성만 함)
cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' \
  -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO

# 관련 클래스만 먼저 돌리려면
cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' \
  -only-testing:BaseballIOSTests/ProNationalTeamSurfaceTests \
  -only-testing:BaseballIOSTests/LocalizationCoverageTests \
  -only-testing:BaseballIOSTests/LayerBoundaryTests \
  CODE_SIGNING_ALLOWED=NO

# 3) 문구·카탈로그 게이트 (npm은 이 작업에서 금지)
npm run check:ios-localization
npm run check:copy
npm run inventory:ios-localization -- --write
npm run check
```

카탈로그는 ko/en/ja 키를 넣었지만 `ios-copy-schema.json`은 npm 인벤토리로 재생성하는 편이 안전하다. xcstrings는 JSON 재직렬화로 키가 파일 끝에 추가됐다.

## 6. 미해결

- 해외 진출(`overseasInterest`)은 뉴스·플래그만. 실제 이적 시장은 범위 밖.
- 분포 러너는 소집·대회·헤드리스 결승을 정책별로 걷는다. 아래 라운드 I 참고.
- Android Kotlin 포팅은 스펙 범위 밖.
- 커밋하지 않음.

## 수정 라운드 I (병합 후)

병합 트리(`/Users/solkim/Dev/baseball`, main)에서 분포 스모크와 iOS 로컬라이제이션 게이트를 고쳤다. 커밋·stash·reset·checkout 없음. `planWeek` RNG 무삽입. 골든 픽스처 미재생성. v9 이하는 소집 페이즈에 들어가지 않는다.

### 진단

`npm run run:pro-career:distribution:smoke`가 다섯 정책 모두 `failedRuns`로 중단했다. 원인은 두 겹이다.

1. 헤드리스 러너가 `acknowledgeSettlement` 직후 `chooseOffseason`을 호출한다. v10 자격 시즌(짝수, season ≥ 2, age ≤ 31)은 `.nationalTeamCall`에 멈추므로 `chooseOffseason`이 거부된다. 수락 뒤 `.nationalTournament`와 결승 직접 등판(`.importantGame` + `.nationalFinal`)도 워커가 모른다.
2. 결승은 플레이어 `ImportantInningReport`를 기대한다. 헤드리스에는 투구 UI가 없다.

부가로 v10 FA 잔류 협상(`requestContractCounter` + 연봉 +10%)은 적용 후 잔류 오퍼가 다른 슬롯을 지배하거나 연봉 밴드 검증을 벗어나면 `invalid_offer`를 던진다. 앱은 버튼을 눌러 실패해도 오퍼 화면에 남는다. 러너는 그 경우 협상을 건너뛰고 기존 오퍼를 고른다.

제품 경로: `CareerFlowView`는 `.nationalTeamCall` / `.nationalTournament`를 이미 라우트한다. `advanceSegment` / `advanceBlock`은 `.weeklyPlan`에서만 주를 넘긴다. 소집 페이즈에서 호출하면 리비전을 올리지 않는다. 스토어 테스트로 확인했다.

### 엔진

`ProCareerEngine.resolveNationalFinalAutomatically` — 조별에서 자격한 뒤 직접 등판이 없을 때 대회 시드에서 결승을 돌린다.

```
derivedFinalSeed = FNV-1a64("national-final:\(resumeSeed)")
```

조별 스트림(`national-tournament:`)과 분리한다. 커리어 `nextSeed`는 소비하지 않는다. `directlyPlayed = false`. 승패는 금/은. 포스트시즌 자동 경기와 같은 패턴이다. 앱 경로는 그대로 `startNationalFinal` → 중요 경기.

### 러너 정책

소집:

| 정책 | 소집 |
|---|---|
| `role_first` | 수락 (국제 무대) |
| `legacy_first` | 수락 (금메달 HOF +4) |
| `stable_random` | 수락 (밸런스 코호트가 경로를 샘플) |
| `security_first` | 사양 (피로·부상 캐리) |
| `salary_first` | 사양 (즉시 연봉 없음) |

FA 잔류 협상 (v10 자유계약, 잔류 오퍼가 있을 때만):

| 정책 | 협상 |
|---|---|
| `salary_first` | 연봉 +10% |
| `security_first` | 연수 +1, 불가하면 연봉 +10% |
| `legacy_first` | 연수 +1, 불가하면 생략 |
| `role_first` | 생략 (보직 축) |
| `stable_random` | 해시 레인 none / extra year / raise |

관심(`interest`)은 v10 오퍼 속성이다. 러너는 관심으로 오퍼를 다시 정렬하지 않아 급여·유산·보직·안정 축이 섞이지 않는다. 계약 수락 뒤 `.offseasonInvestment`는 기존처럼 걷는다.

수락된 협상이 시장 비지배/연봉 밴드를 깨면 엔진이 `invalid_offer`를 낸다. 러너는 적용 시장을 `isValid`로 먼저 보고, 그래도 거부되면 협상을 건너뛴다.

### 로컬라이제이션

`ProNationalTeamCopy.resultTitle`을 `Text(verbatim:)`로 넘겼다(기록 화면 포스트시즌 줄과 동일). 뷰의 `arguments:` 조립은 `ProNationalTeamCopy` 헬퍼로 옮겼다. `pro.nationalTeam.*` 키는 `GameCopyKey.isSemanticID`가 카멜케이스를 거부하므로 `pro.national-team.*`로 바꿨다. 닫힌 enum 한국어 목록에 소집/대회/결승을 넣었고, 용어 사전 기대값을 24항·48키에 맞췄다.

### 게이트 원문

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`. xcodebuild는 한 번에 하나만.

```
swift test --package-path packages/simulation-core --filter "ProNationalTeam|ProContractDepth|ProContractMarket|ProCareerBootstrapCharacterization|ProCareerLegacyRules"
```

종료 코드 0.

```
Test Suite 'Selected tests' passed at 2026-09-02 21:23:58.280.
	 Executed 57 tests, with 1 test skipped and 0 failures (0 unexpected) in 18.091 (18.097) seconds
```

`ProNationalTeamTests` 8/8 (헤드리스 결승 1건 포함).

```
npm run run:pro-career:distribution:smoke
```

종료 코드 0.

```
PRO_CAREER_DISTRIBUTION output=artifacts/analysis/pro-career-wave6/swift-distribution-smoke.json valid=true failures=
```

```
npm run check:ios-localization
```

종료 코드 0.

```
iOS localization release check passed: 3832 catalog entries and zero pending surfaces
```

```
npm run check:copy
```

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

```
npm run check:design-system
```

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

iOS `BaseballIOSTests` (iPhone 17):

```
cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' \
  -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO
```

종료 코드 0.

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 21:41:44.877.
	 Executed 551 tests, with 0 failures (0 unexpected) in 111.795 (111.973) seconds
Test Suite 'All tests' passed at 2026-09-02 21:41:44.878.
	 Executed 551 tests, with 0 failures (0 unexpected) in 111.795 (111.974) seconds
** TEST SUCCEEDED **
```

UI 테스트:

```
cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' \
  -only-testing:BaseballIOSUITests/Release128JourneyUITests/testKoreanProJourneyRoleDecisionFollowUpSeasonRestore \
  test CODE_SIGNING_ALLOWED=NO
```

종료 코드 0.

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testKoreanProJourneyRoleDecisionFollowUpSeasonRestore]' passed (238.134 seconds).
** TEST SUCCEEDED **
```

시즌 정산 → 오프시즌 → 투자(없음) → 다음 스프링캠프 → 저장 복귀까지 통과. 시즌 1은 홀수라 소집 페이즈는 열리지 않는다.
