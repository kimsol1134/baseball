# UX 2차 개선 스펙 — 잔여 결함 5건 + 구조 개선 6건 (2026-09-03)

이 문서는 grok CLI가 읽고 구현하는 작업 지시서다. 근거는 `docs/PERSONA_JOURNEY_REPORT_2026-09-03.md`(페르소나 3인 플레이테스트), `docs/UX_AUDIT` 아티팩트, 그리고 아래 스크린샷이다. 1차 라운드(커밋 0c0667a7·47728318)로 가독성·탭바·고정 바는 끝났다. 이번 라운드는 **남은 눈에 보이는 결함(A)** 과 **구조(B)** 를 다룬다.

## 0. 절대 규칙

1. **커밋·푸시·stash 금지.** 워킹트리에만 작업한다. 다른 세션이 수정 중인 파일은 손대지 않는다: `Application/HighSchoolCareerStore+Lifecycle.swift`, `Application/MobileCareerStore+Lifecycle.swift`, `Presentation/CareerSharePresentation.swift`, `Tests/CareerShareCardTests.swift`, `UITests/Release128JourneyUITests.swift`. 이 파일들에 꼭 필요한 변경이 있으면 보고서에 "요청"으로 적고 구현하지 않는다.
2. **시뮬레이션 결정론을 깨지 않는다.** `packages/simulation-core`에 RNG 호출·랜덤 소스를 추가하지 않는다. 기존 골든 픽스처(`artifacts/android-compose/fixtures/*`, `RealPlayDraftRateTests`, `HighSchoolCareerPersistenceTests`)가 바뀌면 안 된다. 코어에 추가하는 것은 **표시 전용 순수 함수**(입력 스냅샷 → 값)만 허용한다. 저장 스키마(`Codable` 구조체 필드)를 바꾸지 않는다.
3. **투구 슬라이더 불변 규칙**(`AGENTS.md`): 슬라이더 조작을 숨기거나 격하하지 않는다. 자동 릴리스는 설정·접근성 보조 경로로만.
4. **문구 규칙.** Swift에 한국어 리터럴을 Text/Button/Label에 직접 넣지 않는다. 새 키는 담당 `*CopyKeys.swift`(또는 `GameCopyKey.swift`의 `AppCopyKey`)에 case를 추가하고, ko/en/ja를 JSON으로 적어 `node tools/inject-copy-batch.mjs <json>`으로 주입한다(형식: `{"Localizable":{"key":{"ko":"…","en":"…","ja":"…"}}}`). `tools/check-copy.mjs`의 금지어("감독 신뢰" 등)를 쓰지 않는다. 문장은 `.proseStyle()/.detailStyle()`, 라벨은 `BaseballType.annotation`. `.font(.footnote` 는 린트가 막는다.
5. **테스트가 잠근 것.** `LocalizationCoverageTests`가 코어 한국어와 정확히 같아야 하는 키 군을 검사한다(`content.awakening.*`, `content.career-wind.*`, `content.karma.*`, `content.event.*` summary, `content.training-focus.*`, 프롤로그 정적 카탈로그). 이 값들은 바꾸지 않는다. `IOSSourceScan`·`LayerBoundaryTests`·`ProContractInvestmentSurfaceTests`는 특정 파일의 특정 문자열(식별자·호출 순서)을 검사한다 — 담당 파일을 `apps/ios/Tests`에서 grep해 유지한다. 기존 `accessibilityIdentifier`는 바꾸지 않는다.
6. **게이트(전부 통과해야 완료).** `node tools/check-design-system.mjs`, `node tools/check-ios-localization.mjs`, `node tools/check-copy.mjs`, `node tools/check-korean-game-copy.mjs`, 그리고 유닛 테스트:
   ```
   xcrun simctl spawn booted defaults write com.solkim.baseball.ios baseball.audio.sound -bool NO   # 호스트 CoreAudio 데드락 우회
   xcodebuild test -project apps/ios/Baseball.xcodeproj -scheme BaseballIOS -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' -only-testing:BaseballIOSTests
   ```
   테스트는 **한 번에 하나만** 돌린다. 끝나면 `defaults delete`로 되돌린다. 부팅된 iPhone 17(위 UDID) 외 기기를 만들지 않는다.
7. **증거.** 각 항목의 전후 스크린샷을 `apps/ios/releases/qa-1.2.9/round2/<항목>/`에 남긴다(gitignore 경로). 보고서는 `docs/UX_ROUND2_REPORT_2026-09-03.md` 한 파일.

## 1. 이미 있는 부품 (새로 만들지 말 것)

- 타이포·칩·접기: `Presentation/DesignSystem.swift` — `proseStyle/proseLeadStyle/detailStyle`, `EffectChip(tone: .gain/.cost/.risk/.neutral)`, `EffectChipFlow`, `StatTile(label:value:previousValue:caption:)`, `PrimaryPill`, `KeyArtHeader`, `BaseballMetrics.floatingTabBarClearance`.
- 접기: `Features/Shell/ProgressiveDisclosure.swift`(`ProgressiveDisclosure`, `SeenContentStore`, `CopyDensity`, `ReadingSize`).
- 고정 하단 바 패턴: `HighSchoolTrainingViews.swift`의 `TrainingCommitBar` + `HighSchoolCareerView.swift`의 `.safeAreaInset(edge: .bottom)`; `ProContractOfferView.swift`의 `rookieSignBar`.
- 성장 연출: `Features/Shell/GrowthCelebrationView.swift`(프로 능력 상승 카드, Reduce Motion 대응).
- 드래프트 전망: `HighSchoolCareerStore.draftForecast` → `DraftForecastSnapshot(score, threshold, band, interestedTeam)`; 평가 내부 항목은 `HighSchoolCareer.swift:1364 draftEvaluationCore(state:) -> DraftEvaluationComponents`(ratingScore·performanceScore·awakeningScore·relationshipScore·karmaPenalty·overusePenalty·seasonTerm·fanTerm…).
- 팔 위험 임계: `HighSchoolCareerEngine.armCautionThreshold 35 / armWarningThreshold 55 / armInjuryThreshold 72`.
- 오늘의 기회: `TrainingOpportunitySnapshot(focus, reason)`; 성장 전망: `TrainingGrowthOutlook`.
- 연습 투구(첫 불펜): `HighSchoolCareerStore.tutorialSession: PitchSession?` — 프롤로그에서만 열리고 기록에 남지 않는다(`+Lifecycle.swift:656` 근처). 이 파일은 수정 금지이므로 **호출 순서만** 바꾼다.

---

## A. 잔여 결함 5건 (먼저, 각 반나절 이하)

### A1. 드래프트 데이 화면의 빈 공간 400pt
근거: `apps/ios/releases/qa-1.2.9/personas/light-fan/11-first-game-result.png` — 스킬트리 카드와 "그라운드 밖의 목소리" 사이가 비어 있다.
- 위치: `HighSchoolCareerView.phaseBody` `.draft` → `DraftCard`(`ClimaxViews.swift`/`HighSchoolDraftLegacyViews.swift`). 연출 대기 상태(`waiting`)에서 고정 높이 프레임이나 `Spacer`, 혹은 `fullScreenCover`로 넘어간 뒤 남은 자리로 추정된다. 원인을 보고서에 적는다.
- 완료 조건: 드래프트 국면의 어느 상태에서도 인접 카드 사이 빈 간격이 `BaseballMetrics.stackSpacing`(14pt)을 넘지 않는다. Reduce Motion on/off 둘 다.

### A2. 첫 회차 "최고 평가 갱신 … 이전 최고(0점)를 넘었습니다"
근거: `personas/light-fan/19-records.png`. 위치: `HighSchoolDraftLegacyViews.swift` ~540, `hs.bestEvaluation`.
- `bestPast == 0`(비교 대상 없음)이면 "갱신" 카드를 그리지 않고, 평가 점수를 A3 카드의 첫 줄로 넘긴다. 2회차부터만 갱신/다음 목표 카드를 그린다.
- 식별자 `hs.bestEvaluation`은 A3 카드로 옮겨 유지한다(UI 테스트 참조 여부를 grep으로 확인).

### A3. 미지명·지명 이유 카드 ("왜 불리지 않았나")
근거: 페르소나 P1·P2가 여기서 종료. 지금은 "마지막 라운드까지 이름이 불리지 않았습니다" 다음이 바로 재시작이다.
- 코어: `draftEvaluationCore(state:)`의 구성 요소를 표시용으로 노출하는 **순수 함수**를 `HighSchoolCareerEngine`에 추가한다. 예: `public static func draftEvaluationBreakdown(state:) -> DraftEvaluationBreakdown` — 항목별 `(id, points, maxPoints)`와 `threshold`. 저장하지 않는다. 기존 `draftEvaluationCore` 계산을 바꾸지 않는다(같은 값을 재사용).
- iOS: 유산·완료 국면(`LegacyCard`/`CompletionCard`) 최상단에 카드 하나:
  - 제목: 미지명이면 `당락선까지 %lld점 모자랐습니다` / 지명이면 `당락선을 %lld점 넘었습니다`.
  - 본문: 기여가 가장 작은 항목 2개(미지명) 또는 가장 큰 항목 2개(지명)를 칩으로. 예: `능력 평균 41 · +5 필요` `팔 과부하 −4` `직접 등판 성적 +2`. 항목 이름은 카탈로그 키로(`draft.reason.rating`, `.performance`, `.awakening`, `.relationship`, `.overuse`, `.season`, `.fan`, `.karma`).
  - 마지막 줄(미지명만): 다음 회차 한 줄 조언 — 항목 id에 따른 고정 문구 8개(예: overuse → "몰아붙이기 뒤에는 회복을 넣으세요").
- 완료 조건: 미지명·지명 각각 실주행 스크린샷. 숫자 합이 `evaluationScore`와 일치(테스트 1개 추가: `DraftEvaluationBreakdownTests`, 픽스처 상태 2개).

### A4. 설정 화면 푸터 정리
근거: `personas/light-fan/20-settings.png`. "…펼쳐집니다." 아래 "…작아지지는 않아요."가 붙어 있고 말투가 다르다.
- `SettingsView.swift`: 설명 밀도와 글자 크기를 **각각의 Section**으로 나누고 푸터를 하나씩만 둔다. 말투는 전부 "~합니다".
- 값 교체(JSON): `settings.reading-size.footer` → "기기의 글자 크기 설정보다 작아지지 않습니다. 둘 중 큰 쪽을 따릅니다." `settings.copy-density.footer` → "중요한 결과와 새로 열린 항목은 항상 펼쳐 보여 줍니다."
- 소리·진동 푸터도 한 문장씩 두 줄로 나눈다(내용 유지).

### A5. 피로에 상태 단어와 결과를 붙인다
근거: P1이 피로 100에서 계속 구위를 눌렀다. 숫자만 주황이다.
- 고교 헤더(`HighSchoolChapterHeaderViews.swift` `Metric`)와 프로 대시보드(`TodayView`·`ProWeeklyPlanView`의 피로 `StatTile`)에 캡션 한 줄: 피로 < 50 `정상`, 50~69 `지침 · 성장 확률 감소`, 70~89 `과로 · 부상 위험`, ≥ 90 `탈진 · 훈련 성장 없음`. 임계는 코어 규칙과 맞춘다(고교: 훈련 성장 컷오프와 `armWarningThreshold`; 프로: `ProWeekHealthForecast`의 임계). 값이 코드에 상수로 없으면 코어에 표시용 상수를 추가하고 보고서에 근거 줄을 적는다.
- 탈진(≥ 90)에서는 훈련 화면 상단에 콜아웃 카드: `회복 없이는 능력이 오르지 않습니다` + `회복 고르기` 버튼(회복 카드 선택으로 스크롤·선택).

---

## B. 구조 개선 6건 (A 완료 뒤, 아래 순서대로)

### B1. 탭 재편 — 고교/프로를 하나의 "커리어" 탭으로
근거: 페르소나 마찰 TOP 1의 근본 원인. 고교 3년 동안 프로 탭은 잠김 화면이고, 프로 이후 고교 탭은 사라진다.
- `AppShell.swift` `TabView`: 탭을 `커리어 / 기록 / 설정` 셋으로. 커리어 탭은 `pro.loadState == .ready`면 프로 흐름, 아니면 고교 흐름을 그린다(기존 `showsHighSchool` 로직 재사용). 탭 라벨 키 신설 `tab.career`("커리어"/"Career"/"キャリア").
- 프로 잠김 화면(`ProLockedView`)은 삭제하지 않고 **커리어 탭 안의 드래프트 전망 카드**로 축소한다: 고교 챕터 헤더의 드래프트 전망 칩을 탭하면 시트로 연다(`이 문까지의 거리` 내용 그대로).
- "고교를 건너뛰고 프로 시작"(`hasFinishedALife` 조건)은 유산·완료 화면(`CompletionCard`)의 보조 버튼으로 옮긴다. 첫 회차에는 어디에도 노출하지 않는다(기존 규칙 유지).
- 은퇴 후 `retiredDailyInningFallbackTab` 로직은 커리어 탭 기준으로 다시 맞춘다.
- 탭바 숨김 규칙(`shouldHideHighSchoolTabBar`, `isChoicePhase`)은 유지.
- 영향 받는 테스트: `AnalyticsContextTests`(탭 관련), `UITests/QACaptureUITests.swift`·`CareerSmokeUITests.swift`가 `"고교"`/`"프로"` 탭을 탭한다 → `"커리어"`로 바꾼다(`Release128JourneyUITests.swift`는 수정 금지 파일이므로 필요한 변경을 보고서에 "요청"으로 적는다).
- 완료 조건: 새 커리어·드래프트 픽스처(`-uiTestResetCareer -uiTestDraftedCareerFixture`)·프로 픽스처(`-uiTestReviewImprovementFixture`)·은퇴 상태 4가지에서 탭 3개와 올바른 화면. 스크린샷.

### B2. 첫 공 먼저 — 온보딩 순서 변경
근거: 오프닝→이름→지역→유형→구종→챕터 시작→첫 공. 손맛까지 6화면.
- 새 순서: 오프닝 `시작하기` → **연습 투구 1타석**(현재 프롤로그의 `tutorialSession`과 같은 세션, 이름은 시스템 기본명) → 결과 화면 하단 `이 투수의 이름을 정하세요` → 이름 → 지역(권역) → **유형+구종 한 화면**(유형 카드 3장 + 구종 기본값, "바꾸기" 접기) → `고교 1학년 시작`(챕터 시작 화면은 유지하되 첫 공 버튼은 `첫 등교`로 바뀐다).
- 구현 원칙: 커리어 RNG를 설정 전에 소비하면 안 된다. 연습 투구는 이미 기록에 남지 않는 세션이므로 **커리어 생성 전에 임시 세션**으로 연다. `HighSchoolCareerStore+Lifecycle.swift`는 수정 금지이므로, `HighSchoolCareerStore`(본체 파일)나 새 확장 파일 `HighSchoolCareerStore+Onboarding.swift`에 `beginOnboardingBullpen()`을 추가하고 기존 `tutorialSession` 경로를 재사용한다. 커리어 생성 시점(`startCareer`)과 시드는 바꾸지 않는다(`CareerBootstrapTests`, `HighSchoolCareerPersistenceTests` 통과가 조건).
- 이미 커리어가 있는 재실행·환생(퀵 환생 카드)은 지금 순서를 유지한다.
- 완료 조건: 오프닝에서 첫 공까지 탭 2회(시작하기 → 길게 눌러 와인드업). `-uiTestAutoRelease`에서는 탭 2회. UI 스모크(`CareerSmokeUITests`)가 새 순서를 통과.

### B3. 추천 훈련 원탭
근거: P1·P3 "같은 훈련 반복", 매주 6장 중 선택이 결정 피로.
- 표시 전용 추천 규칙(코어 순수 함수 `HighSchoolCareerEngine.recommendedTraining(state:) -> TrainingFocus`): 피로 ≥ 70 → `.recovery`; 팔 위험 ≥ `armWarningThreshold` → `.recovery`; 그 외 오늘의 기회(`TrainingOpportunitySnapshot.focus`)가 있으면 그것; 없으면 현재 능력 중 재능 여유(상한 − 현재)가 가장 큰 항목. 강도는 피로 < 40이면 `.intensive`, 40~69 `.standard`, 그 외 `.light`.
- iOS: `TrainingSelection.initial(state:)`가 이 추천으로 시작하고, 카드에 `추천` 칩(기존 `기회` 칩 옆). 고정 바의 `같은 훈련 3번 연속` 아래 문장은 "추천대로 3주 진행 · 대화·경기가 오면 멈춥니다"로(추천 선택 시에만).
- 완료 조건: 훈련 화면 진입 즉시 추천 카드가 선택돼 있고, `훈련하기` 한 번으로 진행된다. 설명 밀도 `compact`에서도 동일.

### B4. 성장 연출
근거: 훈련 결과 "+1"이 문장 한 줄.
- `HighSchoolTrainingResultViews.swift`: 결과 카드 상단에 오른 능력을 `StatTile(previousValue → value)`로, 0.4초 카운트업(Reduce Motion이면 즉시), `+1` 순간에 `.sensoryFeedback(.impact(weight: .medium))`, 타일 배경이 `positiveSoft`로 0.3초 점등. 성장 없음이면 회색 타일 + "이번엔 없음" 캡션(문장 아님).
- 프로 `GrowthCelebrationView`와 같은 리듬. 새 컴포넌트를 만들지 말고 `StatTile`에 `animatesChange: Bool` 옵션을 추가해 재사용.
- 완료 조건: 스크린샷 3장(카운트업 시작·중간·끝)과 Reduce Motion 캡처.

### B5. 투구 화면 간결 모드
근거: 사인 중복은 없앴지만 타석·읽기 게이지·포수 카드가 슬라이더 위에 쌓인다.
- `PitchView.swift`: 세션에서 3구를 던진 뒤부터(또는 설정 밀도 `compact`) 타석 블록·읽기 게이지를 **한 줄 헤더**로 접는다: `연습 타자 · 우타 · 읽힘 12%` + `상세 ▾`. 펼치면 지금 구조. 포수 제안 카드는 유지(사인·칩·접기).
- 슬라이더·와인드업 버튼·자동 릴리스 토글은 위치·크기·동작 불변(0절 3항).
- 완료 조건: iPhone 17에서 3구 뒤 슬라이더 상단 y가 500pt 이하. SE(4.7")에서도 슬라이더가 첫 화면에 보인다.

### B6. 키아트 다양화 (아트 생성 없이)
근거: 같은 야간 구장이 여러 화면에 반복.
- `ChapterHeader.art(for:)`를 장(chapter) 기준으로 확장: 1장 `careerIntro`, 2·3장 `stadiumNight`, 4장(3학년 여름) `draftDay` 예고 없이 `stadiumNight` 유지, 각성 `awakening`, 학교 선택 `schoolCrossroads`, 드래프트 `draftDay`, 유산 `reincarnation`. 프로는 계약 `majorDebut`, 은퇴 `retirement`, 나머지 `proStadiumTunnel`. 같은 국면이 연속으로 같은 그림을 쓰지 않도록 헤더 높이를 국면별로 두 단계(190 / 140)로.
- 완료 조건: 한 회차 실주행에서 연속 두 화면이 같은 키아트+같은 높이인 경우가 훈련 루프 외에는 없다.

---

## 2. 순서와 규모

| 순서 | 항목 | 예상 | 위험 |
|---|---|---|---|
| 1 | A1 빈 공간 | 2h | 낮음 |
| 2 | A2+A3 미지명 이유 | 1일 | 코어 표시 함수 추가, 테스트 1개 |
| 3 | A4 설정 | 1h | 낮음 |
| 4 | A5 피로 상태어 | 3h | 임계값 출처 확인 |
| 5 | B1 탭 재편 | 1일 | UI 테스트·분석 컨텍스트 수정 |
| 6 | B2 첫 공 먼저 | 1~2일 | RNG·저장 순서, 수정 금지 파일 우회 |
| 7 | B3 추천 훈련 | 3h | 낮음 |
| 8 | B4 성장 연출 | 3h | Reduce Motion |
| 9 | B5 간결 모드 | 3h | 슬라이더 불변 |
| 10 | B6 키아트 | 1h | 낮음 |

A는 전부 끝내고 유닛 테스트를 한 번 돌린 뒤 B로 간다. B는 항목마다 게이트를 돌린다. 시간이 모자라면 B6 → B5 → B4 순으로 뺀다. B1·B2는 빼지 않는다.

## 3. 보고서 (`docs/UX_ROUND2_REPORT_2026-09-03.md`)

- 항목별: 바꾼 파일, 원인(A1·A2), 코어 추가 함수 서명(A3·B3), 전후 스크린샷 경로, 게이트 결과(각 명령의 마지막 줄).
- 새 카피 키 목록(ko/en/ja).
- 수정 금지 파일에 필요한 변경 "요청" 목록.
- 건너뛴 항목과 이유.
- 마지막에 `git status --short` 출력.
