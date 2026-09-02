# 1.2.8 릴리스 게이트 정리 스펙

작성: PM, 2026-09-02. 구현: grok. 목표: 1.2.7 미커밋 워킹트리에서 이미 깨져 있는 게이트를 전부 녹색으로 만들어 1.2.8을 제출 가능하게 한다.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. 워킹트리 변경(1.2.7 + 프로 주간 결정 훅)을 되돌리지 않는다.
2. **테스트를 삭제하거나 단언을 약화시켜 통과시키지 않는다.** 원칙은 "코드를 계약에 맞춘다". 테스트 자체가 잘못된 경우(예: 옛 파일 경로를 가리킴, 이미 폐기된 계약)에만 테스트를 고치고, 보고서에 왜 테스트가 잘못됐는지 한 줄씩 근거를 쓴다.
3. 골든 픽스처(`swift-pro-career-oracle-v1/v2.json`, `simulate_pitch_golden.json`, `swift-simulation-engine-golden-v1.json`) 재생성 금지. 프로 주간 루프에 RNG 삽입 금지.
4. ko/en/ja 모두 필수. 실존 구단·선수명 금지(AGENTS.md).
5. iOS 테스트는 xcodebuild를 한 번에 하나만 실행. 시뮬레이터는 부팅된 iPhone 17을 재사용하고 새로 만들지 않는다.
6. `docs/PRO_WEEKLY_DECISION_HOOK_REPORT_2026-09-02.md`에 기록된 주간 결정 훅 동작을 바꾸지 않는다.

## 1. 알려진 실패 목록 (전부 해결 대상)

### iOS BaseballIOSTests (519 중 9 실패)
- `LayerBoundaryTests.testFeatureViewsDoNotCallJourneyRuleEngines` — Features 뷰에서 `ProCareerEngine.` 직접 호출 (`ProWeeklyPlanView.swift` liveClimate, `ProImportantGameIntro.swift` usesFinalSeriesRules). 해결 방향: MobileCareerStore 또는 CareerDisplayRules에 프로젝션을 두고 뷰는 그것을 쓴다.
- `LocalizationBoundaryTests.testBoundedCardsHaveExplicitSemanticSourceBoundaries`
- `ProCareerJourneyStoreTests.testJourneySurfacesHaveStableAccessibilityRoots`, `testOfferUIHasStableAccessibilityAndRetainsCurrentGoalByDefault`
- `ProContractInvestmentSurfaceTests.testInvestmentAccessibilityAndMediaContentContracts`, `testInvestmentPresentationExposesBenefitsAndKeepsMoney`
  위 테스트 파일들은 1.2.7에서 새로 추가된 미추적 파일이다. 테스트가 요구하는 접근성 ID·문구 계약을 뷰가 실제로 만족하게 한다. 테스트가 이미 리팩터링으로 사라진 뷰/문구를 가리키면 그때만 테스트를 현재 계약에 맞게 고친다.

### 정적 게이트
- `npm run check:copy` 2건: `ProCareer.swift` 주석 "감독 신뢰"(정식 용어 "감독의 믿음"), `ProContractMarketRules.swift:980` 주석 "무브먼트"(정식 용어 "변화구"). 주석을 정식 용어로 고친다.
- `npm run check:ios-localization` 1건: `apps/ios/Sources/Features/Shell/RecordView.swift:459` `Text(line)` 직접 표시 경로(포스트시즌 박스스코어). 다른 기록 줄과 같은 semantic 경계 방식으로 바꾼다.

### simulation-core 전체 스위트 (종료 코드 1)
- `CareerSignatureLegacyTests` 4건: `invalidPitcherLab("career state or phase is invalid")`. 원인을 진단해서 고친다. 1.2.5의 투수연구소 진행 유지 수정과 v3 레거시 경로가 어긋났을 가능성이 높다. 레거시 회차(rulesVersion 3)의 결과가 바이트 동일해야 한다는 테스트 의도를 존중한다.
- `DraftConclusionPresentationTests.testPresentationLookupCannotChangeDraftPhaseSeedHashCommitmentOrJSON`: "14683 bytes" != "14683 bytes" — 같은 길이인데 내용이 다르다. JSONEncoder 키 순서 비결정성일 가능성이 높다(`.sortedKeys` 사용). 테스트나 인코더에 `outputFormatting = [.sortedKeys]`를 적용해 결정적으로 만든다.
- `RPCServerTests.testPitcherLabStartAndTrainingRoundTrip` 직후 xctest 시그널 10. 이 프로젝트에서 거대한 값 타입의 outlined destroy가 Swift 6.3에서 세그폴트를 낸 전례가 있다(해결책: 큰 값 타입을 `final class` 박스로 감싸기). 크래시 로그(`~/Library/Logs/DiagnosticReports`)를 확인하고 재현 → 수정한다. 테스트 자체의 `--skip`으로 회피하지 않는다.

## 2. 실행해야 하는 게이트 (전부 종료 코드 0이 목표)
1. `swift test --package-path packages/simulation-core` (전체)
2. `swift test --package-path packages/ios-layers`
3. `npm run check` (집계 — 실패 항목은 개별 실행해 원인 확인)
4. `npm run check:ios-localization`, `npm run check:copy`, `npm run check:balance`, `npm run run:pro-career:distribution:smoke`
5. iOS: `cd apps/ios && xcodegen generate && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO` — 519+ 전부 통과
6. project.yml을 바꿨다면 pbxproj를 재생성한 상태로 둔다.

## 3. 산출물
`docs/RELEASE_GATE_CLEANUP_1_2_8_REPORT_2026-09-02.md`: 실패 항목별 원인·조치·근거, 실행한 게이트별 원문 결과(마지막 요약 줄 포함), 남은 실패(있다면 원문과 진단).
