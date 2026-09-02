# 1.2.8 시뮬레이터 E2E 검증 보고 (2026-09-02)

구현·QA: grok-4.6. 스펙: `docs/SIMULATOR_E2E_1_2_8_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음.

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)` 재사용.
작은 화면: `iPhone SE (3rd generation)` `7DFA08C0-5509-4210-A8F8-087B12AA233F`를 iOS 26.5 런타임으로 하나 만들고, 작업 끝에 종료·삭제했다.

xcodebuild는 한 번에 하나만 돌렸다. `QACaptureUITests`는 게이트로 쓰지 않았다.
스크린샷은 `apps/ios/releases/qa-1.2.8/`에만 두었고 약 20MB(200MB 미만). `.xcresult`는 요약만 남기고 삭제했다.

## 1. 시나리오 통과/실패

| # | 시나리오 | 결과 | 근거 스크린샷 |
|---|---|---|---|
| 1 | 새 커리어 → 프로 진입. 좌완/우완이 선수 만들기 스타일 단계에 있다. 고교는 drafted fixture로 스킵해 신인 계약까지. | 통과 | `apps/ios/releases/qa-1.2.8/01-pro-entry/01-setup-name.png`, `02-setup-throwing-hand.png` (우완/좌완 세그먼트), `01-contract-offer.png` |
| 2 | 보직 지원. 스프링캠프 3선택지·수락 전망. 용어 탭이 선택을 먹지 않음. 선발 선택. | 통과 | `02-role-request/03-glossary-sheet.png`, `04-starter-result.png`, 복원 화면의 보직 카드 `07-save-restore/19-restored.png` |
| 3 | 주간 결정 3주차. eyebrow에 3주차. 선택지에서 용어 시트만 열리고 확인창은 안 열림. 선택 A. | 통과 | `03-week3-decision/06-decision.png` (`1시즌 · 3주차 결정`), `07-glossary-without-select.png` (감독의 믿음 시트, 확인 다이얼로그 없음), `08-choice-a-confirm.png` |
| 4 | 후속 결과 카드. 접힘/펼침. | 통과 | `04-follow-up/09-expanded.png` (`등판 간격 단축의 3주가 끝났습니다`), `10-toggled.png` |
| 5 | 직접 등판 1구. 기본 투구 슬라이더로 한 구. | 통과 | `05-pitch-slider/01-windup.png` (`길게 눌러 와인드업`, 자동 릴리스 꺼짐), `02-result.png` (`헛스윙`) |
| 6 | 시즌 완주 → 정산 → 오프시즌 → 다음 시즌. | 통과 | `06-season-complete/11-settlement.png`, `13-offseason.png`, `15-next-spring.png` |
| 7 | 저장·복귀. | 통과 | `07-save-restore/19-restored.png` (재실행 후 이번 주·보직 지원 카드) |
| 8 | 언어 en/ja. 1·3·4 단계. 한국어 누수 없음(en/ja hangul assert). | 통과 | `08-language-en/01-01-pro-entry.png` … `04-04-follow-up.png`; `08-language-ja/` 동일 |

추가 필수: 선택지·훈련 카드 안의 용어 탭.

- 훈련: `testTrainingGlossaryTermDoesNotSelectFocus` 통과. 제구가 선택된 채로 구위 시트가 열림 (`02-role-request/02-training-glossary-sheet.png`).
- 시즌 결정: `07-glossary-without-select.png`에서 `glossary.sheet`만 보이고 `pro.seasonDecision.confirm`은 없음.

## 2. 발견 결함

### 2.1 용어 탭이 부모 Button에 먹힘 (고침)

- 원인: `GlossaryText`가 시즌 결정 선택지·보직 지원·훈련 포커스·주간 계획 카드의 `Button` label 안에 있어, AttributedString 링크와 접근성 자식이 선택 제스처에 가려졌다.
- 수정: 용어 문단을 선택 Button 밖으로 옮겼다. 밑줄 링크는 유지하고, 카드 안에서 `info.circle` 버튼(`glossary.term.<id>`)을 별도 히트 영역으로 뒀다. 소스 회귀: `ProRoleRequestAndGlossaryTests.testGlossaryTextIsOutsideParentChoiceButtons`.
- 전: 용어 리포트 미해결 항목. 시뮬레이터에서 카드 탭 = 선택.
- 후: `02-role-request/02-training-glossary-sheet.png`, `03-week3-decision/07-glossary-without-select.png`.

### 2.2 시즌 결정 경고가 떠 있는 탭 바에 가림 (고침)

- 원인: 결정 화면 마지막 `decisionWarning`이 스크롤 끝에서 플로팅 탭 바와 겹쳤다.
- 수정: `ProSeasonDecisionView` VStack에 `.padding(.bottom, 28)` 추가. `CareerFlowView`의 `floatingTabBarClearance` 120은 유지.
- 전: `03-week3-decision/06-decision.png`에서 경고 문구가 탭 바에 잘림.
- 후: 같은 패딩을 넣은 뒤 시즌 완주 경로를 다시 통과.

### 2.3 국면 전환 때 이전 화면이 비쳐 보임 (일부 고침)

- 원인: `CareerFlowView`가 정산·오프시즌·결정을 같은 스크롤 VStack에서 갈아끼울 때 반투명 카드 뒤로 이전 국면 글이 남았다.
- 수정: 정산·오프시즌·결정 루트에 `BaseballTheme.canvas` 배경.
- 전: `06-season-complete/13-offseason.png`에 정산 숫자(`6,000만 원`)가 오프시즌 선택지와 겹침. en/ja 결정 캡처에도 주간 계획 문구가 비침.
- 후: 배경을 깐 뒤 한국어 시즌 완주를 재통과. 전환 한 프레임의 잔상은 남을 수 있다.

### 2.4 계약·기록 하단이 탭 바에 가림 (남은 항목)

- 원인: 신인 계약 연봉/계약금과 기록 탭 마지막 줄이 플로팅 탭 바 뒤에 있다. 스크롤하면 서명·확인은 닿는다.
- 수정하지 않음. 서명 경로는 스크롤 후 동작 확인. SE에서 잘림이 더 크다 (`glyphs-se/01-contract-offer.png`).
- 전/후: `01-pro-entry/01-contract-offer.png`, `glyphs-iphone17/18-records.png`.

### 2.5 CareerSmoke 구종 학습 영수증 (남은 항목)

- `CareerSmokeUITests.testRepertoireLearningUnlocksPersistsAndUsesManualDelivery`가 `hs.training.result.pitchLearning` 없음으로 두 번 실패. 집중+변화구 탭과 `hs.training.pitchLearning` 카드는 있었다.
- 훈련 포커스 ID는 다른 스모크(훈련 결과·관계)에서 통과. 이 E2E에서 단언을 약화하지 않았다.

## 3. 글자 깨짐 판정

PNG를 직접 열어 봤다. 후보 (a) 잘림 (b) 한국어 단어 중간 줄바꿈 (c) 사각 글리프 (d) 숫자·단위 겹침.

| 화면 | iPhone 17 기본 | iPhone 17 Accessibility L | iPhone SE 3세대 |
|---|---|---|---|
| 시즌 결정 | 경고 잘림 후 패딩 수정. 사각 글리프 없음. | `glyphs-iphone17-a11y/04-season-decision.png` 큰 글, 줄바꿈은 어절 단위. | 미캡처(SE는 계약·주간·설정·기록) |
| 주간 계획 | 본문 정상. 탭 바가 맨 아래 카드와 겹침. | `02-weekly-plan.png` 동일. | `glyphs-se/02-weekly-plan.png` |
| 훈련 결과 | `glyphs-iphone17/03-training-result.png` 정상. | (고교 경로를 a11y 조합에 넣지 않음) | — |
| 시즌 정산 | 숫자 타일 정상. | 오프시즌 조합에서 정산 경로 포함 | — |
| 계약 제안 | 하단 연봉이 탭 바에 가림. 글리프 깨짐 없음. | `a11y/01-contract-offer.png` 더 짧아진 뷰포트. | `glyphs-se/01-contract-offer.png` `6`만 보임 |
| 은퇴 미리보기 | `glyphs-iphone17/14-retirement-preview.png` | `a11y/08-retirement-preview.png` | — |
| 기록 | 결정 이력 가독. 마지막 줄 탭 바 겹침. | `a11y/10-records.png` | `glyphs-se/05-records.png` |
| 설정 | 본문 정상. 푸터 일부 탭 바. | `a11y/09-settings.png` | `glyphs-se/04-settings.png` |

판정:

- (c) 사각 글리프: 재현되지 않음.
- (b) 한국어 중간 줄바꿈: 재현되지 않음. 줄은 어절·조사 앞에서 갈라짐.
- (a)(d) 잘림·겹침: 재현됨. 주로 플로팅 탭 바 vs 긴 카드(계약·기록·결정 경고), 국면 전환 잔상. 2.2·2.3에서 일부를 고쳤고 2.4는 남김.
- 투구 슬라이더 기본값: 시나리오 5에서 자동 릴리스 없이 와인드업 패드로 1구.

8주차 리뷰의 “각종 글자 깨짐” 중 글리프 미적용·단어 중간 개행은 이 빌드에서 재현되지 않았다. 잘림/겹침은 탭 바·전환에서 재현된다.

## 4. 게이트 원문

### 4.1 `Release128JourneyUITests` (iPhone 17)

`testKoreanProJourneyRoleDecisionFollowUpSeasonRestore` 최종:

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testKoreanProJourneyRoleDecisionFollowUpSeasonRestore]' passed (219.241 seconds).
Test Suite 'Release128JourneyUITests' passed at 2026-09-02 14:09:34.247.
	 Executed 1 test, with 0 failures (0 unexpected) in 219.241 (219.242) seconds
** TEST SUCCEEDED **
```

같은 클래스의 나머지(iPhone 17): 새 커리어 손 선택, 훈련 용어, 수동 슬라이더, en/ja 표면, Accessibility L 밀집 화면 통과. SE 전용 테스트는 iPhone 17에서 skip, SE 기기에서 통과.

### 4.2 `CareerSmokeUITests` (iPhone 17)

20시즌 일본어 완주 `testJapaneseDraftedRunCompletesProCareerJourneyAtMaximumHorizon`은 이 세션에서 skip(약 37분). 나머지 14개 중 13 통과, 1 실패.

```
Test Suite 'CareerSmokeUITests' failed at 2026-09-02 14:25:21.307.
	 Executed 14 tests, with 1 failure (0 unexpected) in 782.000 (782.013) seconds
Failing tests:
	CareerSmokeUITests.testRepertoireLearningUnlocksPersistsAndUsesManualDelivery()
```

통과 예: `testKoreanProCareerReachesFirstSettlement` 141.110초, `testHighSchoolCareerRunsThroughDraftAndRebirth` 216.456초, `testManualDeliveryGestureThrowsAPitch` 37.099초.

실패 원문:

```
CareerSmokeUITests.swift:1089: error: ... XCTAssertTrue failed - 구종 연구 진전 영수증이 없습니다.
```

같은 테스트를 한 번 더 돌려도 동일. 단언은 약화하지 않음.

### 4.3 `BaseballIOSTests` 전체 (수정 후 재실행)

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 14:29:32.746.
	 Executed 529 tests, with 0 failures (0 unexpected) in 108.607 (108.756) seconds
Test Suite 'All tests' passed at 2026-09-02 14:29:32.746.
	 Executed 529 tests, with 0 failures (0 unexpected) in 108.607 (108.757) seconds
** TEST SUCCEEDED **
```

`LayerBoundaryTests` 6, `LocalizationBoundaryTests` 7 포함.

### 4.4 `npm run check:design-system`

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

### 4.5 `npm run check:ios-localization`

```
iOS localization release check passed: 3753 catalog entries and zero pending surfaces
```

## 5. 생성 기기 삭제

`iPhone SE (3rd generation)` `7DFA08C0-5509-4210-A8F8-087B12AA233F`를 shutdown 후 `simctl delete` 했다. `xcrun simctl list devices`에 SE 3세대가 남아 있지 않다. 부팅된 iPhone 17은 그대로 두었다.

## 수정 라운드 (PM 검수 6건)

커밋하지 않음. stash/reset/checkout 없음. 골든 픽스처 재생성 없음. 테스트 삭제·약화 없음. `planWeek` RNG 스트림에 `next*()` 없음. 규칙 버전 9 유지. 시뮬레이터는 부팅된 `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF)`만 재사용. xcodebuild는 한 번에 하나만.

재캡처: `apps/ios/releases/qa-1.2.8/fix-round/04-starter-result.png`, `apps/ios/releases/qa-1.2.8/fix-round/09-expanded.png`.

### 1. 신인 보직 지원이 맡은 선발을 거절

- 원인: 신인은 `role == starter`, `managerTrust` 42. 선발 수락이 `stamina ≥ 55 && managerTrust ≥ 45`라 시즌 1 선발 지원이 항상 거절되고 믿음 −1이 붙었다.
- 수정: `ProRoleRequestRules`에서 (a) `state.role` 또는 그 시즌 `trustAssignedRole`(셋업은 중간으로 정규화)과 같은 보직은 항상 수락, 신뢰 변화 없음. (b) 시즌 1만 선발/마무리 수락에서 믿음·호흡 문턱을 제거(체력·구위는 유지). (c) 시즌 2+와 조건부/거절 문턱은 그대로. 카드 전망은 `evaluate` 결과를 따라 유력으로 바뀌고, 이미 맡은 보직은 `pro.role-request.condition.assigned`를 쓴다. 문턱 표는 `docs/PRO_ROLE_REQUEST_AND_GLOSSARY_REPORT_2026-09-02.md`에 반영.
- 후: `fix-round/04-starter-result.png` — 역할 선발, 감독의 믿음 42, 「이미 맡은 보직입니다」. 거절·믿음 −1 없음.

### 2. 주간 요약 주차 범위

- 원인: `MobileCareerStore.progressSummary`가 `"\(before.week + 1)~\(after.week)주차"`를 써서, 보직 지원 후 week 0은 `1~0주차`, 한 주는 `3~3주차`.
- 수정: `ProCareerPresentation.weekSpanLabel` — 단일 주 `N주차`, week 0/스프링캠프는 ko `스프링캠프` / en `Spring camp` / ja `スプリングキャンプ`, start > end를 그리지 않음. `progressSummary`가 이 포맷터를 쓴다. 단위 테스트 `testWeekSpanLabelCoversSpringCampSingleWeekAndRange`, `testProgressSummaryAfterRoleRequestUsesSpringCampLabel`.

### 3. 프로 성장 카드의 고교 다음 단계 문구

- 원인: `GrowthCelebrationView`가 `MetaPresentation.ratingMeaning` → `prologue.ability.meaning.starter`(고교 주전 경쟁)를 프로 주간 화면에서도 썼다.
- 수정: `GrowthStageContext.pro`를 `CareerFlowView`에서 넘긴다. 프로 다음 단계는 `meta.growth.meaning.*`(1군 로테이션 경쟁 / 1군 승격 / 보직 경쟁 / 2군 정착 / 2군 적응, 상위 밴드는 프로 평균 이상). `testProWeeklyGrowthDoesNotResolvePrologueAbilityMeaningKeys`.
- 후: `fix-round/09-expanded.png` — 「다음 단계 1군 로테이션 경쟁까지 3」, 「다음 단계 보직 경쟁까지 3」. 「고교 주전 경쟁」 없음.

### 4. 후속 카드 실점

- 원인: `ProCareerPresentation.followUpSummary`가 `"R \(runs)"` 리터럴.
- 수정: `pro.decision.followup.runs` — ko `실점 %lld`, en `R %lld`, ja `失点 %lld`.
- 후: `fix-round/09-expanded.png` — 「QS 4 · 실점 7」.

### 5. 계약·기록 하단이 탭 바에 가림 (2.4)

- 원인: 결정 경고(2.2)와 달리 계약 제안 VStack에 추가 하단 패딩이 없었고, 기록 탭 스크롤은 `floatingTabBarClearance`가 없었다.
- 수정: `ProContractOfferView`에 결정 화면과 같은 `.padding(.bottom, 28)`. `RecordView` 스크롤 콘텐츠에 `.padding(.bottom, 28)` + `.safeAreaPadding(.bottom, BaseballMetrics.floatingTabBarClearance)`. 디자인 시스템 검사 통과.

### 6. 구종 학습 영수증 (2.5)

- 원인: 1.2.7 훈련 결과 뷰 분리의 `compact` 분기가 `hs.training.result.pitchLearning`을 `if !compact` 안에 넣었다. 챕터 마지막 훈련이 관계 국면으로 바뀌면 영수증이 접혀 스모크가 못 찾았다. 식별자가 사라진 것이 아니라 compact에 가려졌다.
- 수정: 구종 학습 줄을 compact와 무관하게 항상 그린다. `testPitchLearningReceiptStaysVisibleWhenResultIsCompact`. `CareerSmokeUITests.testRepertoireLearningUnlocksPersistsAndUsesManualDelivery` passed (55.105 seconds).

### 게이트 원문

`swift test --package-path packages/simulation-core --filter "ProRoleRequest|ProWeeklyDecisionHook|ProCareerBootstrapCharacterization|ProCareerLegacyRules"`:

```
Test Suite 'Selected tests' passed at 2026-09-02 14:53:01.213.
	 Executed 41 tests, with 1 test skipped and 0 failures (0 unexpected) in 10.118 (10.124) seconds
```

`npm run check:copy`:

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

`npm run check:ios-localization`:

```
iOS localization release check passed: 3767 catalog entries and zero pending surfaces
```

`npm run check:design-system`:

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

`BaseballIOSTests` 전체 (iPhone 17):

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 14:56:08.044.
	 Executed 534 tests, with 0 failures (0 unexpected) in 110.832 (111.009) seconds
Test Suite 'All tests' passed at 2026-09-02 14:56:08.045.
	 Executed 534 tests, with 0 failures (0 unexpected) in 110.832 (111.010) seconds
** TEST SUCCEEDED **
```

`CareerSmokeUITests` 전체 클래스 (iPhone 17):

```
Test Suite 'CareerSmokeUITests' failed at 2026-09-02 15:12:09.070.
	 Executed 15 tests, with 1 failure (0 unexpected) in 928.823 (928.839) seconds
Failing tests:
	CareerSmokeUITests.testJapaneseDraftedRunCompletesProCareerJourneyAtMaximumHorizon()
```

구종 학습 스모크:

```
Test Case '-[BaseballIOSUITests.CareerSmokeUITests testRepertoireLearningUnlocksPersistsAndUsesManualDelivery]' passed (55.105 seconds).
```

일본어 20시즌 실패는 이번 6건 밖이다. 워커가 `pro.postseason.finale`에서 진행 가능한 액션을 못 찾았다. 이전 세션에서는 이 테스트를 skip했다.

`Release128JourneyUITests` 전체 클래스 (iPhone 17):

```
Test Suite 'Release128JourneyUITests' failed at 2026-09-02 15:30:21.725.
	 Executed 8 tests, with 1 test skipped and 1 failure (0 unexpected) in 1056.035 (1056.042) seconds
Failing tests:
	Release128JourneyUITests.testEnglishSurfacesHideKorean()
```

한국어 종주:

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testKoreanProJourneyRoleDecisionFollowUpSeasonRestore]' passed (235.702 seconds).
```

영어 후속 미도달은 재시도에서 통과:

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testEnglishSurfacesHideKorean]' passed (153.834 seconds).
Test Suite 'Release128JourneyUITests' passed at 2026-09-02 15:36:00.185.
	 Executed 1 test, with 0 failures (0 unexpected) in 153.834 (153.835) seconds
** TEST SUCCEEDED **
```

`.xcresult`는 요약만 남기고 삭제했다. 부팅된 iPhone 17은 그대로 두었다.

## 수정 라운드 F

커밋하지 않음. stash/reset/checkout 없음. 골든 픽스처 재생성 없음. 테스트 삭제·약화 없음. `planWeek` RNG 스트림에 `next*()` 없음. 시뮬레이터는 부팅된 `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF)`만 재사용. xcodebuild는 한 번에 하나만.

### 1. 일본어 20시즌이 `pro.postseason.finale`에서 멈춤 — 워커 결함 (플레이어는 안 막힘)

**1.2.7 as shipped에서 일본어 플레이어가 피날레에 막히는가: 아니오.**

근거:

- `ProPostseasonFinaleView`는 언어 조건 없이 `PrimaryPill(identifier: "pro.seasonReview.confirm")`을 항상 그린다. ja 카탈로그 `pro.flow.season-review.action`은 비어 있지 않다(`レビューシーズン`). `Text(verbatim:)`로 버튼을 숨기는 분기도 없다.
- `-AppleLanguages (ja)`로 포스트시즌 픽스처를 피날레까지 진행한 화면 `apps/ios/releases/qa-1.2.8/fix-round/ja-finale.png`: 라임색 「レビューシーズン」 알약이 탭 바 위에 보이고 활성이다. 한국어 같은 픽스처 경로에서도 `pro.seasonReview.confirm`이 버튼으로 존재한다.
- 레이아웃이 일본어 길이 때문에 버튼을 탭 바 밑으로 밀어 넣지 않았다. 식별자는 로케일마다 다르지 않다.

스모크가 멈춘 이유: 워커가 `app.buttons["pro.seasonReview.confirm"]`만 찾았다. 피날레 루트 `pro.postseason.finale`에 `.accessibilityElement(children: .contain)`이 없어, 자식 확인 버튼이 XCUI 버튼 트리에서 빠졌다. 보이는 알약은 그대로라 손가락으로는 진행된다.

수정:

- 피날레 루트에 `.accessibilityElement(children: .contain)`을 넣어 확인 버튼을 접근성/XCUI 트리에 남긴다 (시즌 결정·은퇴 명예와 같은 계약).
- 워커가 피날레 확인을 누르고, 포스트시즌 연투 선택·부상 영수증(`pro.injury.result.acknowledge`)도 처리한다. 은퇴 직후 부상 카드가 명예를 가리던 경로까지 닫아야 20시즌이 끝난다.
- Debug 포스트시즌 픽스처 라이벌 ID를 카탈로그에 있는 `pro-rival-seoul`로 바꿨다. 가짜 `ui-postseason-rival`은 ja/en Debug `.strict`에서 `content.pro-rival.ui-postseason-rival.name` 결번으로 프로세스가 죽었다. 제품 저장 경로의 실존 라이벌 ID는 해당 없음.
- `LocalizationCoverageTests.testPostseasonFinaleContinueControlExistsInEveryLanguage`: ko/en/ja 확인 문구가 비어 있지 않고, 피날레 PrimaryPill이 언어 `if`에 가려지지 않는지 소스 계약.

### 2. 보직 지원 카드가 통계 뒤에 겹침 — 촬영 중간 프레임

`fix-round/04-starter-result.png`의 유령 카드는 선택 직후 snappy 제거 애니메이션 한 프레임이다. 선발 탭 뒤 2초를 기다리면 겹침이 없다: `fix-round/04-starter-result-settled.png` (보직 카드·「이미 맡은 보직입니다」·「긴 이닝 구원」 없음).

그래도 그 한 프레임이 더러워 보여 `ProRoleRequestCard`는 완료 시 계층에서 즉시 빠지게 했다(`.transition(.identity)` + `.animation(nil, value: state.roleRequest != nil)`). UI 테스트는 `pro.roleRequest`가 사라진 뒤에만 캡처한다.

### 게이트 원문

`BaseballIOSTests` 전체 (iPhone 17):

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 15:52:30.365.
	 Executed 535 tests, with 0 failures (0 unexpected) in 109.605 (109.766) seconds
Test Suite 'All tests' passed at 2026-09-02 15:52:30.366.
	 Executed 535 tests, with 0 failures (0 unexpected) in 109.605 (109.767) seconds
** TEST SUCCEEDED **
```

`npm run check:design-system`:

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

`npm run check:ios-localization`:

```
iOS localization release check passed: 3767 catalog entries and zero pending surfaces
```

일본어 피날레 계속 컨트롤:

```
Test Case '-[BaseballIOSUITests.CareerSmokeUITests testJapanesePostseasonFixtureShowsFinaleContinueControl]' passed (19.348 seconds).
```

보직 정착 캡처:

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testRoleRequestResultSettlesWithoutOverlappingOptionCards]' passed (45.344 seconds).
```

일본어 20시즌:

```
Test Case '-[BaseballIOSUITests.CareerSmokeUITests testJapaneseDraftedRunCompletesProCareerJourneyAtMaximumHorizon]' passed (3339.265 seconds).
Test Suite 'CareerSmokeUITests' passed at 2026-09-02 17:58:15.250.
	 Executed 1 test, with 0 failures (0 unexpected) in 3339.265 (3339.267) seconds
** TEST SUCCEEDED **
```

`.xcresult`는 요약만 남기고 삭제했다. 부팅된 iPhone 17은 그대로 두었다.

