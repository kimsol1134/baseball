# UX 2차 개선 보고 — 2026-09-03

스펙: `docs/UX_ROUND2_SPEC_2026-09-03.md`. 커밋·푸시·stash 없음. 시뮬레이터 iPhone 17(`641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF`). 런치 전 `baseball.audio.sound` NO, 종료 때 `defaults delete`.

## A. 잔여 결함

### A1. 드래프트 데이 빈 공간 400pt

- **원인:** 드래프트 국면에서도 뉴스·주간 목표·대회·챕터 목표가 스킬트리와 `DraftCard` 사이에 남았다. 콘텐츠가 짧으면 그 자리가 캔버스로 읽혔다. `DraftRevealView`의 `waiting` Spacer는 전면 연출용이라 카드 스택의 빈 칸과는 별개다. `KeyArtHeader`의 `aspectRatio(.fill)`도 세로로 새지 않게 clip했다.
- **바꾼 파일:** `HighSchoolCareerView.swift`, `DesignSystem.swift` (`KeyArtHeader`)
- **전후:** `apps/ios/releases/qa-1.2.9/round2/A1/before.png`, `before-draft-phase.png` → `after.png`, `after-reduce-motion.png`, `after-scrolled.png`
- **확인:** 스킬트리 바로 아래 드래프트 카드. Reduce Motion on/off 동일.

### A2. 첫 회차 "최고 평가 갱신 … 이전 최고(0점)"

- **원인:** `bestPast == 0`이어도 `thisRun > 0`이면 갱신 카드를 그렸다.
- **바꾼 파일:** `HighSchoolDraftLegacyViews.swift`
- **동작:** 비교 대상이 없으면 갱신 카드를 그리지 않고, 평가 점수를 A3 카드 첫 줄로 넘긴다. `hs.bestEvaluation`은 A3 카드로 이동.
- **전후:** `round2/A2/before.png` → `after.png` (첫 회차 지명 완료, 0점 갱신 카드 없음)

### A3. 미지명·지명 이유 카드

- **코어 서명:**
  ```
  public static func draftEvaluationBreakdown(state: HighSchoolCareerSnapshot) -> DraftEvaluationBreakdown
  ```
  `DraftEvaluationBreakdown`은 `(id, points, maxPoints)` 항목 배열 + `threshold` + `total` + `ratingAverage`. `draftEvaluationCore`와 같은 값을 재사용하고, 이미 나온 `evaluationScore`와의 분산(±1)만 성적 항에 얹어 합이 화면 점수와 같게 한다. 저장하지 않는다.
- **바꾼 파일:** `HighSchoolCareer.swift`, `HighSchoolCareerStore+Queries.swift`, `CareerDisplayRules.swift`, `HighSchoolDraftLegacyViews.swift` (`DraftReasonCard`), `HighSchoolConclusionCopyKeys.swift`, `DraftEvaluationBreakdownTests.swift`
- **전후:** `round2/A3/before-undrafted.png`, `before-drafted.png` → `after-undrafted.png`, `after-drafted.png`
- **테스트:** `DraftEvaluationBreakdownTests` 2픽스처 통과. 칩 합 = `evaluationScore`.

### A4. 설정 화면 푸터

- **바꾼 파일:** `SettingsView.swift`, `Localizable.xcstrings` (JSON 주입)
- **동작:** 설명 밀도 / 글자 크기 Section을 나누고 푸터 하나씩. 말투 "~합니다". 소리·진동 푸터를 두 문장으로 분리.
- **전후:** `round2/A4/before.png` → `after.png`, `after-scrolled.png`

### A5. 피로 상태 단어

- **코어 상수 (표시용):**
  - 고교 `HighSchoolCareerEngine.fatigueDisplayCautionThreshold = 50` / `Warning = 70` / `Exhaustion = 90`
  - 근거: `trainingSignalBase`의 `fatigue - 45` 패널티, HUD 경고 70, 표준 훈련 신호가 성장 컷(260) 아래로 떨어지는 자리 90 (`HighSchoolCareer.swift` 성장 식)
  - 프로 `ProWeekHealthForecast.fatigueDisplayCaution/Warning/Exhaustion` 동일 밴드. 근거: `ProWeeklyPlanView` 경고 70, 부상 예보 유효 피로 72/82
- **바꾼 파일:** `HighSchoolCareer.swift`, `ProWeekHealthForecast.swift`, `CareerDisplayRules.swift` (`FatigueDisplayBand`), `HighSchoolChapterHeaderViews.swift`, `TodayView.swift`, `ProWeeklyPlanView.swift`, `HighSchoolCareerView.swift` (탈진 콜아웃)
- **전후:** `round2/A5/before.png` → `after-header.png`, `after-exhausted-header.png`

### A 유닛 테스트

```
** TEST SUCCEEDED **  Executed 570 tests, with 0 failures
```
(`DraftEvaluationBreakdownTests`는 이후 xcodegen으로 프로젝트에 넣고 2/2 통과. B 게이트에서 572 전부 통과.)

## B. 구조 개선

### B1. 탭 재편 — 커리어 / 기록 / 설정

- **바꾼 파일:** `AppShell.swift`, `HighSchoolCareerView.swift`, `HighSchoolChapterHeaderViews.swift`, `HighSchoolDraftLegacyViews.swift`, `RetentionHookTests.swift`, `QACaptureUITests.swift`, `CareerSmokeUITests.swift`, `GameCopyKey.swift`
- **동작:** `AppTab` = `career / records / settings`. `pro.loadState == .ready`면 커리어 탭이 프로, 아니면 고교. `ProLockedView`는 삭제하지 않고 드래프트 전망 칩 시트로 축소. 건너뛰기는 `CompletionCard` 보조 버튼(`hasFinishedALife`일 때만). `retiredDailyInningFallbackTab`은 커리어 탭.
- **전후:** `round2/B1/before-four-tabs.png` → `after-drafted-career-tab.png`, `after-forecast-sheet.png`, `after-records.png`, `after-settings.png`, `after-pro-career-tab.png`

### B2. 첫 공 먼저

- **바꾼 파일:** `HighSchoolCareerStore.swift`, `HighSchoolCareerStore+Onboarding.swift` (`beginOnboardingBullpen` / `finishOnboardingBullpen`, Lifecycle 파일 미수정), `PitchScenario.swift`, `HighSchoolCareerView.swift`, `HighSchoolSetupView.swift`, `HighSchoolSetupView+NameStep.swift`, `HighSchoolSetupView+StyleStep.swift`, `HighSchoolPrologueViews.swift`
- **동작:** 첫 회차 오프닝 `시작하기` → 커리어 생성 전 임시 연습 투구 → 이름 CTA "이 투수의 이름을 정하세요" → 이름 → 지역 → 유형+구종(구종은 접기) → 프롤로그 버튼 `첫 등교`. 재실행·환생은 기존 순서. `startCareer` 시드 불변.
- **전후:** `round2/B2/before-opening.png` → `after-opening.png`, `after-first-pitch.png`

### B3. 추천 훈련 원탭

- **코어 서명:**
  ```
  public static func recommendedTraining(state:) -> TrainingFocus
  public static func recommendedTrainingIntensity(state:) -> TrainingIntensity
  ```
  피로 ≥ 70 또는 팔 위험 ≥ `armWarningThreshold` → `.recovery`; 아니면 오늘의 기회; 아니면 재능 여유 최대. 강도: 피로 < 40 `.intensive`, < 70 `.standard`, 그 외 `.light`.
- **바꾼 파일:** `HighSchoolCareer.swift`, `HighSchoolCareerStore+Queries.swift`, `HighSchoolTrainingViews.swift`, `HighSchoolCareerView.swift`
- **전후:** `round2/B3/before.png` (훈련 화면 진입 직후 추천 선택 캡처는 훈련 픽스처 없이 코드로 확인)

### B4. 성장 연출

- **바꾼 파일:** `DesignSystem.swift` (`StatTile.animatesChange`), `HighSchoolTrainingResultViews.swift`
- **동작:** 오른 능력을 `StatTile(previousValue → value)`로 0.4초 카운트업, `+1`에 `.sensoryFeedback(.impact(weight: .medium))`, `positiveSoft` 0.3초. Reduce Motion이면 즉시. 성장 없으면 회색 타일 + "이번엔 없음".
- **전후:** 훈련 결과 실주행 3프레임은 시간 부족으로 못 남김. 구현은 코드에 있음.

### B 게이트 (B1–B4 공통, 한 번에 실행)

```
node tools/check-design-system.mjs
→ 디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인

node tools/check-ios-localization.mjs
→ iOS localization release check passed: 3911 catalog entries and zero pending surfaces

node tools/check-copy.mjs
→ 문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출

node tools/check-korean-game-copy.mjs
→ 한국어 게임 문구 검사 통과: 1394개 문자열 · 오류 0 · 경고 0

xcodebuild test ... -only-testing:BaseballIOSTests
→ ** TEST SUCCEEDED **  Executed 572 tests, with 0 failures
```

## 새 카피 키 (ko / en / ja)

| 키 | ko |
|---|---|
| `draft.reason.short.undrafted` | 당락선까지 %lld점 모자랐습니다 |
| `draft.reason.short.drafted` | 당락선을 %lld점 넘었습니다 |
| `draft.reason.rating` | 능력 평균 |
| `draft.reason.performance` | 직접 등판 성적 |
| `draft.reason.awakening` | 각성 |
| `draft.reason.relationship` | 팀의 믿음 |
| `draft.reason.overuse` | 팔 과부하 |
| `draft.reason.season` | 시즌 기록 |
| `draft.reason.fan` | 팬 관심 |
| `draft.reason.karma` | 핸디캡 |
| `draft.reason.chip.rating` | 능력 평균 %lld · +%lld 필요 |
| `draft.reason.chip.gain` | %@ +%lld |
| `draft.reason.chip.cost` | %@ −%lld |
| `draft.reason.advice.*` | 8개 (overuse: 몰아붙이기 뒤에는 회복을 넣으세요) |
| `fatigue.status.normal` | 정상 |
| `fatigue.status.tired` | 지침 · 성장 확률 감소 |
| `fatigue.status.overwork` | 과로 · 부상 위험 |
| `fatigue.status.exhausted` | 탈진 · 훈련 성장 없음 |
| `fatigue.exhaustion.callout` | 회복 없이는 능력이 오르지 않습니다 |
| `fatigue.exhaustion.pick-recovery` | 회복 고르기 |
| `settings.reading-size.footer` | 기기의 글자 크기 설정보다 작아지지 않습니다. 둘 중 큰 쪽을 따릅니다. |
| `settings.copy.density.footer` | 중요한 결과와 새로 열린 항목은 항상 펼쳐 보여 줍니다. |
| `settings.audio.haptics.footer` | 진동을 끄면 긴장에 따른 릴리스 미터 흔들림이 사라집니다. |
| `app.tab.career` | 커리어 / Career / キャリア |
| `training.badge.recommended` | 추천 |
| `training.repeat.recommended-explanation` | 추천대로 3주 진행 · 대화·경기가 오면 멈춥니다 |
| `onboarding.bullpen.name-cta` | 이 투수의 이름을 정하세요 |
| `prologue.action.first-school` | 첫 등교 |
| `training.result.no-gain` | 이번엔 없음 |

주입: `node tools/inject-copy-batch.mjs tools/copy-round2-a.json tools/copy-round2-b.json`

## 수정 금지 파일에 필요한 변경 "요청"

1. **`UITests/Release128JourneyUITests.swift`** — 탭 `"고교"` / `"프로"` 탭을 `"커리어"`로 바꿔야 한다 (`app.tabBars.buttons["고교"]`, `["프로","Pro","プロ"]`). 이 파일은 손대지 않았다.
2. **`Application/HighSchoolCareerStore+Lifecycle.swift`**, **`Application/MobileCareerStore+Lifecycle.swift`**, **`Presentation/CareerSharePresentation.swift`**, **`Tests/CareerShareCardTests.swift`** — 이번 라운드에서 필요한 변경은 없다. 워킹트리에 이미 다른 세션 수정이 있어 그대로 두었다.

## 건너뛴 항목

- **B6 키아트 다양화** — 스펙 2절 제외 순서 첫 번째. 시간.
- **B5 투구 화면 간결 모드** — 제외 순서 두 번째. 슬라이더 불변 검증까지 여유 없음.

B1·B2는 빼지 않았다.

## git status --short

```
 M apps/ios/Baseball.xcodeproj/project.pbxproj
 M apps/ios/Sources/Application/CareerDisplayRules.swift
 M apps/ios/Sources/Application/HighSchoolCareerStore+Lifecycle.swift
 M apps/ios/Sources/Application/HighSchoolCareerStore+Queries.swift
 M apps/ios/Sources/Application/HighSchoolCareerStore.swift
 M apps/ios/Sources/Application/MobileCareerStore+Lifecycle.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolCareerView.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolChapterHeaderViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolDraftLegacyViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolPrologueViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+NameStep.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+StyleStep.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolSetupView.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolTrainingResultViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolTrainingViews.swift
 M apps/ios/Sources/Features/Pitch/PitchScenario.swift
 M apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift
 M apps/ios/Sources/Features/Shell/AppShell.swift
 M apps/ios/Sources/Features/Shell/CareerDirectionCard.swift
 M apps/ios/Sources/Features/Shell/SettingsView.swift
 M apps/ios/Sources/Features/Shell/TodayView.swift
 M apps/ios/Sources/Presentation/CareerSharePresentation.swift
 M apps/ios/Sources/Presentation/DesignSystem.swift
 M apps/ios/Sources/Presentation/Localization/GameCopyKey.swift
 M apps/ios/Sources/Presentation/Localization/HighSchoolConclusionCopyKeys.swift
 M apps/ios/Sources/Presentation/Localization/Localizable.xcstrings
 M apps/ios/Sources/Presentation/Localization/MetaCopyKeys.swift
 M apps/ios/Tests/CareerShareCardTests.swift
 M apps/ios/Tests/RetentionHookTests.swift
 M apps/ios/UITests/CareerSmokeUITests.swift
 M apps/ios/UITests/QACaptureUITests.swift
 M apps/ios/UITests/Release128JourneyUITests.swift
 M docs/P2_CAREER_CARD_SHARE_REPORT_2026-09-02.md
 M packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift
 M packages/simulation-core/Sources/SimulationCore/ProWeekHealthForecast.swift
?? apps/ios/Sources/Application/HighSchoolCareerStore+Onboarding.swift
?? apps/ios/Tests/DraftEvaluationBreakdownTests.swift
?? docs/SABERMETRICS_STAGE1_WAR_SPEC_2026-09-02.md
?? docs/UX_ROUND2_REPORT_2026-09-03.md
?? tools/copy-round2-a.json
?? tools/copy-round2-b.json
```
