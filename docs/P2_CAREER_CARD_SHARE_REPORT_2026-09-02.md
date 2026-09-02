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

- 시드 도전 **링크**(URL 스킴·유니버설 링크)는 다른 엔지니어 예약. 공유 텍스트는 각인 문자열과 스토어 URL만.
- 카드의 실점 지표는 스펙 문구 ERA가 아니라 제품 RA9.
- 고교 `LifeRecord`에는 투구 손이 없어 드래프트 카드(호명 화면) 손은 우완 기본. 결론 화면은 스냅샷 손을 쓴다.
- 커밋하지 않음.
