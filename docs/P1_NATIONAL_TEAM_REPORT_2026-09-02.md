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
- 분포 러너는 소집 페이즈를 자동 진행하지 않는다. 시즌 루프가 `acknowledgeSettlement` 직후 `chooseOffseason`을 호출하면 v10 자격 시즌에서 실패할 수 있다. 제품 경로(화면)는 소집→대회→오프시즌 순서다.
- Android Kotlin 포팅은 스펙 범위 밖.
- iOS xcodebuild·npm은 실행하지 않음.
- 커밋하지 않음.
