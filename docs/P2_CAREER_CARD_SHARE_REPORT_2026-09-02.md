# P2-1 커리어 카드 공유 구현 보고

구현: grok-4.6. 스펙: `docs/P2_CAREER_CARD_SHARE_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음. 픽스처 재생성 없음. 시뮬레이터는 부팅된 iPhone 17만 재사용. xcodebuild는 한 번에 하나만.

HEAD: 187a3b51a7f97dfebe15d5231c4ecfab2fdde2ad.

## 0. 규칙 준수

- 커밋·푸시·stash·reset·checkout 없음. `git add -A` 없음.
- 코어 규칙·시뮬레이션·골든 픽스처 무변경. `BaseballApp.swift`, `HighSchoolSetupView*.swift`, `project.yml` URL/entitlement, `apps/landing` 미수정.
- 도전 코드는 기존 각인 `"<seed>-<life>"`만 사용. URL 스킴·유니버설 링크는 넣지 않았다.
- ko/en/ja 카탈로그. 실존 구단·선수명 없음. 투구 슬라이더 코드는 접근하지 않았다.
- 뷰는 스토어/디스플레이 프로젝션과 Presentation 헬퍼만 쓴다. Features/Pro에 `arguments:` 없음.
- 테스트 삭제·단언 약화 없음. `project.yml`은 바꾸지 않았고, 신규 Swift 파일 반영을 위해 `xcodegen generate`만 실행했다.

## 1. 변경 파일

이 작업에서 직접 손댄 파일만 적는다.

### Presentation
- `apps/ios/Sources/Presentation/CareerShareCard.swift` — 1080×1350 카드, ImageRenderer, 미리보기 시트, 공유 버튼
- `apps/ios/Sources/Presentation/CareerSharePresentation.swift` — 4종 모델 조립
- `apps/ios/Sources/Presentation/Localization/ShareCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/GameCopyKey.swift` — `shareKeys`를 `allCases`에 연결
- `apps/ios/Sources/Presentation/Localization/Localizable.xcstrings`

### Application / Platform
- `apps/ios/Sources/Application/CareerDisplayRules.swift` — `ChallengeStamp` (`career-<seed>-life-<n>` / fallback seed)
- `apps/ios/Sources/Application/MobileCareerStore+Queries.swift` — `challengeStamp()`
- `apps/ios/Sources/Application/MobileCareerStore+Lifecycle.swift` — DEBUG 은퇴 공유 픽스처
- `apps/ios/Sources/Platform/GameAnalytics.swift` — `career_card_shared`

### 진입 화면
- `apps/ios/Sources/Features/Pro/ProRetirementViews.swift` — 은퇴 화면 공유
- `apps/ios/Sources/Features/Pro/CareerFlowView.swift` — 스탬프 전달
- `apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift` — 마일스톤·QS 후속 공유 아이콘
- `apps/ios/Sources/Features/Pro/ProNationalTeamViews.swift` — 국가대표 결과 공유
- `apps/ios/Sources/Features/HighSchool/ClimaxViews.swift` — 드래프트 호명 화면
- `apps/ios/Sources/Features/HighSchool/HighSchoolDraftLegacyViews.swift` — 드래프트 결론 화면
- `apps/ios/Sources/Features/Shell/AppShell.swift` — 은퇴 페이즈는 이번 주 탭, DEBUG 픽스처 설치

### 테스트·도구
- `apps/ios/Tests/CareerShareCardTests.swift`
- `apps/ios/Tests/LocalizationCoverageTests.swift`
- `apps/ios/UITests/Release128JourneyUITests.swift` — `testRetirementSharePreviewOpens`
- `tools/inject-career-share-copy.mjs`
- `docs/localization/ios-copy-schema.json` — `inventory:ios-localization --write`
- `apps/ios/Baseball.xcodeproj/project.pbxproj` — `xcodegen generate` (`project.yml` 무변경)

## 2. 카드 4종 레이아웃과 진입점

공용 캔버스: 360×450 pt @3x = **1080×1350** (4:5). 배경은 `BaseballTheme.fieldNight` 고정. 상단 앱 이름 + App Store 배지, `PortraitView`(기존 AvatarFace 경로), 이름·투구 손, 중앙 본문 통계/훈장, 하단 `시드 <seed>-<life> · 같은 시드로 도전` + 앱 이름. URL은 카드에 없고 공유 텍스트에만.

공유 텍스트: 한 줄 요약 + `도전 코드 <seed>-<life>` + `https://apps.apple.com/app/id6794754217`. 렌더는 메인 액터. 실패 시 토스트(`share.card.render-failed`) 후 텍스트만 공유. 미리보기 시트에서 「공유」. VoiceOver 라벨 「카드 공유」, 접근성 ID `share.card.<kind>`.

분석: `CareerTelemetry.log(.careerCardShared)` — `kind`, `season`, `has_medal` (`0`/`1`).

| kind | 본문 | 진입 |
|---|---|---|
| retirement | 승-패-세이브, RA9(게임의 실점률), 탈삼진, WHIP, 시즌 수. 훈장: 영구결번·명예의 전당·국가대표 금. 팀 레거시 티어 | 은퇴 화면 `RetiredView` 「카드 공유」 |
| draft | 라운드·순번·가상 구단, 고교 경기·RA9·K, 평가 점수/투영 범위 | 드래프트 호명(`DraftRevealView`)과 결론(`CompletionCard`) |
| record | 통산 경기/탈삼진 마일스톤, 또는 후속 QS·실점 | 주간 마일스톤 카드, QS 후속 카드 공유 아이콘 |
| national | 메달, 면제, 결승 상대 점수 라인 | 국가대표 결과 카드 |

실점 지표는 제품이 ERA가 아니라 RA9(`pro.totals.ra9`, 한국어 「9이닝당 실점」)를 쓰므로 카드도 RA9를 찍는다.

## 3. 스크린샷

경로 `apps/ios/releases/qa-1.2.9/share/` (합계 880K, 200MB 이하).

| 파일 | 출처 |
|---|---|
| `retirement.png` | `CareerShareCardTests` ImageRenderer |
| `draft.png` | 동일 |
| `record.png` | 동일 |
| `national.png` | 동일 |
| `retirement-preview.png` | `Release128JourneyUITests.testRetirementSharePreviewOpens` |

## 4. 게이트 원문

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`. 새로 만들지 않았다.

첫 `BaseballIOSTests`는 `JapaneseLocalizationTests.testEveryStringCatalogEntryHasReleaseReadyJapaneseCopy`가 `share.card.store-badge` 영·일 동일 문자열을 잡아 종료 65. 배지를 `App Store에서 받기` / `On the App Store` / `App Storeで入手`로 나눈 뒤 같은 기기에서 다시 돌렸다.

### 4.1 `swift test --package-path packages/simulation-core --filter ProCareerBootstrapCharacterization`

종료 코드 0.

```
Test Suite 'ProCareerBootstrapCharacterizationTests' passed at 2026-09-02 22:36:55.433.
	 Executed 6 tests, with 1 test skipped and 0 failures (0 unexpected) in 3.670 (3.670) seconds
```

### 4.2 `npm run check:ios-localization`

종료 코드 0.

```
iOS localization release check passed: 3905 catalog entries and zero pending surfaces
```

### 4.3 `npm run check:copy`

종료 코드 0.

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

### 4.4 `npm run check:design-system`

종료 코드 0.

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

### 4.5 iOS `BaseballIOSTests`

`cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO`

종료 코드 0.

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 22:43:02.865.
	 Executed 558 tests, with 0 failures (0 unexpected) in 111.674 (111.841) seconds
Test Suite 'All tests' passed at 2026-09-02 22:43:02.865.
	 Executed 558 tests, with 0 failures (0 unexpected) in 111.674 (111.842) seconds
```

`CareerShareCardTests` 4/4 포함. 네 카드 PNG 크기 1080×1350.

### 4.6 UI `testRetirementSharePreviewOpens` (수용 기준 3)

같은 부팅 기기. 종료 코드 0.

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testRetirementSharePreviewOpens]' passed (12.603 seconds).
Test Suite 'Release128JourneyUITests' passed at 2026-09-02 22:45:40.350.
	 Executed 1 test, with 0 failures (0 unexpected) in 12.603 (12.604) seconds
```

DEBUG 환경 `BASEBALL_UI_RETIRED_SHARE=1`로 은퇴 픽스처를 심고, 「이번 주」에서 미리보기를 연다. `BaseballApp.swift`는 건드리지 않았다.

## 5. 미해결

- 시드 도전 **링크**는 공유 텍스트에 연결됨(라운드 K). `CHALLENGE_LINK_HOST`가 비면 스킴 URL. 유니버설 링크 entitlement는 여전히 빈 배열.
- 카드의 실점 지표는 스펙 문구 ERA가 아니라 제품 RA9.
- 고교 `LifeRecord`에는 투구 손이 없어 드래프트 카드(호명 화면) 손은 우완 기본. 결론 화면은 스냅샷 손을 쓴다.
- 커밋하지 않음.

## 수정 라운드 K

진단·수정. 커밋·stash·reset·checkout 없음. 코어 시뮬레이션 무변경. 시뮬레이터는 부팅된 iPhone 17 (`641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF`)만. xcodebuild는 한 번에 하나.

### 진단

1. 큰 제목 슬롯의 「은퇴 카드」는 시트 제목/kind 라벨이 `playerName`으로 들어간 것이 아니다. `CareerSharePresentation.retirement`은 이미 `state.identity.name`을 넣고, 헤드라인은 `share.card.headline.retirement`(「은퇴」). DEBUG UI 픽스처 `installRetiredShareFixtureForUITesting()`가 `playerName: "은퇴 카드"`로 커리어를 만들어 미리보기에 그대로 찍혔다. 샘플 PNG의 「민서준」은 유닛 테스트 샘플 이름.
2. 5칸 2열 그리드 + 훈장 `Label`이 450pt를 넘어 하단 테두리에서 「전력의 한 축」이 잘렸다.

### 수정

- 픽스처 이름을 `민서준`으로 바꿈. `testRetirementCardTitleIsPlayerNameNotKindLabel`이 identity.name / 「은퇴」 헤드라인 / 미리보기 제목 분리를 단언. UI 테스트는 `share.card.preview.playerName` 라벨이 `민서준`이고 「은퇴 카드」가 아님을 단언.
- 레이아웃: 통계 최대 5개(2×2 + 5번째 시즌 전폭), 훈장 고정 높이 1줄(최대 3개 + `+N`). 최대 콘텐츠로 4종 재렌더. unconstrained ImageRenderer 높이가 1350px를 넘지 않음(실측 1324).
- `CareerSharePresentation.shareText`가 `ChallengeLink.shareURL(seed:life:host:)`를 넣음. 호스트는 `CHALLENGE_LINK_HOST`(Info.plist, 빈 값이면 스킴). 공유 문구는 요약 + `도전 코드 <seed>-<life>` + 도전 링크 + App Store URL. 키 `share.card.body.link` ko/en/ja.

`apps/landing`의 `node_modules`에는 `typescript`만 있고 `next`가 없어 `npm --prefix apps/landing run build`는 건너뜀.

### 게이트 원문

`swift test --package-path packages/ios-layers` 종료 코드 0.

```
Test Suite 'All tests' passed at 2026-09-02 22:58:42.288.
	 Executed 24 tests, with 0 failures (0 unexpected) in 0.012 (0.016) seconds
```

`ChallengeLinkSessionTests` + `LocalizationCoverageTests` 종료 코드 0.

```
Test Suite 'ChallengeLinkSessionTests' passed at 2026-09-02 22:59:36.279.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.003 (0.005) seconds
Test Suite 'LocalizationCoverageTests' passed at 2026-09-02 22:59:37.036.
	 Executed 43 tests, with 0 failures (0 unexpected) in 0.745 (0.756) seconds
Test Suite 'Selected tests' passed at 2026-09-02 22:59:37.036.
	 Executed 49 tests, with 0 failures (0 unexpected) in 0.749 (0.762) seconds
```

`BaseballIOSTests` 전체 종료 코드 0.

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 23:04:59.002.
	 Executed 569 tests, with 0 failures (0 unexpected) in 111.165 (111.350) seconds
Test Suite 'All tests' passed at 2026-09-02 23:04:59.002.
	 Executed 569 tests, with 0 failures (0 unexpected) in 111.165 (111.350) seconds
```

`npm run check:ios-localization` 종료 코드 0.

```
iOS localization release check passed: 3911 catalog entries and zero pending surfaces
```

`npm run check:copy` 종료 코드 0.

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

`npm run check:design-system` 종료 코드 0.

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

UI `testRetirementSharePreviewOpens` 종료 코드 0. `retirement-preview.png` 재캡처.

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testRetirementSharePreviewOpens]' passed (13.394 seconds).
Test Suite 'Release128JourneyUITests' passed at 2026-09-02 23:05:48.686.
	 Executed 1 test, with 0 failures (0 unexpected) in 13.394 (13.395) seconds
```

## 수정 라운드 L (실데이터 캡처)

진단·캡처. 커밋·stash·reset·checkout 없음. 코어 시뮬레이션 무변경. 시뮬레이터는 부팅된 iPhone 17 (`641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF`)만. xcodebuild는 한 번에 하나.

라운드 K의 `draft.png` / `record.png` / `national.png`는 `CareerShareCardTests` 스트레스 픽스처였다. 헤드라인이 kind rawValue(`draft`/`record`)이고 본문은 은퇴 통계였다. 실데이터 미리보기는 `retirement-preview.png`뿐이었다.

### 픽스처

DEBUG 설치. 패턴은 `installRetiredShareFixtureForUITesting`과 같고, AppShell `BASEBALL_UI_*_SHARE=1`로만 넣는다. `BaseballApp.swift` 미수정.

| env | 설치 | 선수 | 화면 |
|---|---|---|---|
| `BASEBALL_UI_DRAFT_SHARE` | `HighSchoolCareerStore.installDraftShareFixtureForUITesting` | 박하준 | 고교 드래프트 결론 |
| `BASEBALL_UI_RECORD_SHARE` | `MobileCareerStore.installRecordShareFixtureForUITesting` | 김도윤 | 주간 마일스톤 + QS 후속 |
| `BASEBALL_UI_NATIONAL_SHARE` | `MobileCareerStore.installNationalShareFixtureForUITesting` | 이시우 | 국가대표 금·면제 결과 |

구단은 가상(`busan_marines` 부산 블루웨일스). 실존 구단·선수명 없음.

`WeeklyPlanView` 본문(칩·게이지·접기)은 이 스냅숏에서 주 스레드를 막아 XCUI가 탭 바를 못 읽었다. DEBUG이고 `BASEBALL_UI_RECORD_SHARE=1`일 때만 `CareerFlowView`가 같은 `CareerSharePresentation` 모델로 마일스톤·QS 공유 버튼을 직접 그린다. 제품 주간 화면 기본 경로는 그대로다.

### 카드에 찍힌 내용 (실데이터)

헤드라인은 종류 라벨(ko). 선수 이름이 아니다.

- **드래프트** (`draft-preview.png`, `draft.png`): 박하준 · 우완 · 「드래프트 지명」 · 부산 블루웨일스 · 라운드 1 · 순번 4 · 경기 18 · 9이닝당 실점 3.15 · 탈삼진 187 · 배지 부산 블루웨일스 / 1라운드 / 등급 84. 프로 승-패 없음.
- **신기록 마일스톤** (`record-milestone-preview.png`, `record.png`): 김도윤 · 「신기록」 · 프로 통산 200탈삼진 · 경기 72 · 탈삼진 240.
- **신기록 QS** (`record-qs-preview.png`): 김도윤 · 「신기록」 · 등판 간격 단축의 3주가 끝났습니다. · QS 3 · 실점 7 · 배지 등판 간격 단축.
- **국가대표** (`national-preview.png`, `national.png`): 이시우 · 「국가대표」 · 결승 동해 연안 연합 4-2 · 금메달 · 병역 면제.

스트레스 PNG는 `sample-*.png` / `maximal-*.png`로 옮겼다. kind 파일은 실모델 렌더만 덮어쓴다.

### 프레젠테이션 수정

- 드래프트 통계가 6칸이라 등급이 잘렸다. 등급은 배지(`등급 84`)로 옮기고 본문은 라운드·순번·경기·RA9·K 5칸.
- 국가대표 면제 칸 라벨이 문장(`병역 면제 처리됐습니다.`)이라 타일에 안 맞았다. 짧은 `share.card.national.exempted`(「병역 면제」)로 바꿨다.

### 게이트 원문

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`.

`npm run check:ios-localization` 종료 코드 0.

```
iOS localization release check passed: 3911 catalog entries and zero pending surfaces
```

`npm run check:copy` 종료 코드 0.

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

UI 세 테스트 종료 코드 0.

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testDraftSharePreviewOpens]' passed (13.796 seconds).
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testNationalSharePreviewOpens]' passed (12.989 seconds).
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testRecordSharePreviewsOpen]' passed (20.991 seconds).
Test Suite 'Release128JourneyUITests' passed at 2026-09-02 23:44:52.617.
	 Executed 3 tests, with 0 failures (0 unexpected) in 47.776 (47.778) seconds
```

`BaseballIOSTests` 전체: `CareerShareCardTests` 9/9 포함. 스위트는 570 실행·2 실패. 실패는 공유 카드가 아니다.

- `LocalizationBoundaryTests.testAwakeningSkillTreeSurfaceUsesTypedResolvedCopyBoundary` — 소스에 주석 「건너뛰기」(고교 각성 화면, 병렬 1.2.9 문구 작업).
- `ProContractInvestmentSurfaceTests.testInvestmentPresentationExposesBenefitsAndKeepsMoney` — 결산 `BaseballCard(title: ProCareerPresentation.teamName` 문자열 스캔. 공유 렌더러와 무관.

같은 스위트에서 주간 칩 키 `pro.weekly.injury-chip` 등이 카탈로그에 없어 `WeeklyPlanView` 렌더 테스트가 치명 종료했다. `ProCopyKeys`에만 있던 4키(injury-chip, gain-chip, delta.caption, option.detail-title)를 ko/en/ja로 넣었다. 그 뒤 목표판·보직 테스트는 통과.

```
Test Suite 'BaseballIOSTests.xctest' failed at 2026-09-02 23:51:53.678.
	 Executed 570 tests, with 2 failures (0 unexpected) in 121.012 (121.165) seconds
Test Suite 'All tests' failed at 2026-09-02 23:51:53.678.
	 Executed 570 tests, with 2 failures (0 unexpected) in 121.012 (121.166) seconds
```

`apps/ios/releases/qa-1.2.9/share/` 합계 1.8M.

커밋하지 않음.

## 수정 라운드 M (UX 개편 후 회귀)

UX 3차(`ff7f9c1d`)·4차(`96c17116`) 이후 공유 UI 두 건. 커밋·stash·reset·checkout 없음. 코어 시뮬레이션 무변경. `project.yml`·entitlements 유니버설 링크 변경은 유지. 시뮬레이터는 부팅된 iPhone 17 (`641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF`)만. xcodebuild는 한 번에 하나. 테스트 삭제·단언 약화 없음.

### 원인

1. `testDraftSharePreviewOpens` — 드래프트 결론이 `DraftPeakResultView`(`hs.draft.result.continue`)와 유산/완료 2화면으로 갈렸다. 공유 버튼은 호명(`DraftRevealView`)과 2화면 `CompletionCard`에만 있어, 픽스처가 멈추는 1화면에 `share.card.draft`가 없었다.
2. `testRecordSharePreviewsOpen` — 미리보기 시트의 「닫기」(`action.close`)와 알림 큐 후속 「닫기」(`notice.dismiss`)가 같은 라벨이라 `app.buttons["닫기"]`가 다중 매칭됐다.

### 수정

- `DraftPeakResultView`에 `CareerShareButton`(`share.card.draft`) 복구. 호명 화면 공유는 감정 최고점이라 유지. 2화면 `CompletionCard` 공유도 유지.
- 미리보기 시트 닫기에 `share.card.preview.close`. 네 공유 UI 테스트가 이 식별자로 열고 닫는다.
- 알림 큐 후속 닫기에 `pro.notice.followUp.dismiss`. 픽스처에서 배너·후속 알림이 있으면 미리보기 전에 먼저 닫는다.

### 캡처 (다시 찍음)

경로 `apps/ios/releases/qa-1.2.9/share/` (합계 3.1M). 시트에 「닫기」는 미리보기 하나. 알림 배너 겹침 없음.

- **드래프트** (`draft-preview.png`): 박하준 · 우완 · 「드래프트 지명」 · 부산 블루웨일스 · 라운드 1 · 순번 4 · 경기 18 · 9이닝당 실점 3.15 · 탈삼진 187 · 배지 부산 블루웨일스 / 1라운드 / 등급 84.
- **신기록 마일스톤** (`record-milestone-preview.png`): 김도윤 · 「신기록」 · 프로 통산 200탈삼진 · 경기 72 · 탈삼진 240.
- **신기록 QS** (`record-qs-preview.png`): 김도윤 · 「신기록」 · 등판 간격 단축의 3주가 끝났습니다. · QS 3 · 실점 7 · 배지 등판 간격 단축.

### 게이트 원문

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`.

공유 UI 네 테스트 종료 코드 0.

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testDraftSharePreviewOpens]' passed (15.851 seconds).
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testNationalSharePreviewOpens]' passed (27.045 seconds).
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testRecordSharePreviewsOpen]' passed (38.644 seconds).
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testRetirementSharePreviewOpens]' passed (27.790 seconds).
Test Suite 'Release128JourneyUITests' passed at 2026-09-03 15:59:18.937.
	 Executed 4 tests, with 0 failures (0 unexpected) in 109.331 (109.334) seconds
```

`BaseballIOSTests` 전체 종료 코드 0. `CareerShareCardTests` 9/9.

```
Test Suite 'CareerShareCardTests' passed at 2026-09-03 15:59:46.810.
	 Executed 9 tests, with 0 failures (0 unexpected) in 0.756 (0.758) seconds
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-03 16:01:40.033.
	 Executed 576 tests, with 0 failures (0 unexpected) in 115.106 (115.252) seconds
Test Suite 'All tests' passed at 2026-09-03 16:01:40.033.
	 Executed 576 tests, with 0 failures (0 unexpected) in 115.106 (115.252) seconds
```

`npm run check:ios-localization` 종료 코드 0.

```
iOS localization release check passed: 3911 catalog entries and zero pending surfaces
```

`npm run check:design-system` 종료 코드 0.

```
디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인
```

커밋하지 않음.
