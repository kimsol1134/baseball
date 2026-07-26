# iOS 유료앱 전환 계획

| 항목 | 값 |
|---|---|
| 문서 ID | DOC-IOS-PAID |
| 버전 | 1.0 |
| 기준일 | 2026-07-25 |
| 범위 | `apps/ios` 전체, 공유 `SimulationCore` 호출 경계, App Store 제출 자산·CI |
| 선행 문서 | ADR-013(프로 커리어·권한 경계), ADR-014(iOS 네이티브 흐름), DOC-19(비주얼 디렉션), DOC-14(수익화·법무·접근성) |

## 0. 결정

**Steam이 아니라 iOS 유료앱(paid up-front)을 1순위 배포 채널로 삼는다.**

이 결정이 바꾸는 것:

- 프로 커리어를 IAP로 해금하던 구조(ADR-013)가 무의미해진다. **앱 구매 = 전체 콘텐츠 이용 권한**이다.
- 데스크톱과 UI를 공유하지 않는다는 ADR-014는 유지한다. 다만 "화면 구조만 다르다"였던 범위를 **"게임 플레이 자체를 모바일에 구현한다"**로 넓힌다.
- 무료 체험이 없으므로 **스토어 스크린샷 5장이 유일한 데모**다. 스크린샷에 담을 화면이 존재하는 것이 최우선 요구사항이 된다.

## 1. 현재 상태 진단

### 1.1 규모

| | 코드량 | 내용 |
|---|---|---|
| `apps/windows/src` | 약 17,900줄 | 고교 커리어, 피처랩, GameCast 궤적, 성장 연출, 아바타, 뉴스피드 |
| `apps/ios/Sources` | **528줄 / 파일 5개** | 탭 3개, 전부 `List`·`Form` 텍스트 |
| `packages/simulation-core` | 9,352줄 | 두 앱이 공유하는 결정론 코어 |

코어에는 `HighSchoolCareer.swift`, `PitcherLab.swift`, `PitchKernelEngine.swift`가 모두 있으나 **iOS는 `ProCareer.swift`만 호출한다.** 게임의 핵심 루프(한 구씩 던지는 승부)가 모바일에 존재하지 않는다.

### 1.2 치명 결함 3건

**(D1) 릴리스 빌드에서 게임이 열리지 않는다**

`MobileCareerStore.restoreOrCreateCareer()`가 커리어 생성을 `#if DEBUG`로 감싸고, `#else`에서는 곧장 실패 상태로 떨어진다.

```swift
#else
loadState = .failed("검증된 프로 커리어 구매 또는 복원 권한을 찾지 못했습니다. ...")
#endif
```

StoreKit 구현은 저장소 전체에 존재하지 않는다(문서 언급만 있음). 지금 아카이브해 제출하면 **심사자가 보는 첫 화면이 에러 문구**다. 즉시 리젝 사유.

**(D2) 중요 경기 결과가 하드코딩이다**

`MobileCareerStore.resolveImportantMoment()`가 선택지 3개 각각에 대해 고정된 `ImportantInningReport` 상수를 반환한다. 시뮬레이션을 돌리지 않는다.

```swift
case .attackZone:
    report = .init(scenarioNumber: ..., pitches: 15, strikeouts: 3, walks: 0, runsAllowed: 1, ...)
```

결과적으로 **선수 능력치도, 상대 타자도, 난수도 결과에 영향을 주지 않는다.** 같은 선택지는 언제나 같은 성적을 낸다. 유료앱에서 두 번째 플레이에 발각되는 종류의 결함이다.

**(D3) 상호작용이 게임이 아니라 설문지다**

훈련 선택이 `Picker`, 시즌 종료·오프시즌이 `ContentUnavailableView` + 버튼 1개. 3,000~9,000원을 지불한 사용자가 보는 화면의 밀도가 아니다.

### 1.3 그래픽·디자인 결함

| ID | 항목 | 현재 | 근거 |
|---|---|---|---|
| G1 | 아트 자산 미연결 | 키아트 6장(`apps/windows/src/assets/*.webp`)이 전부 데스크톱 전용. iOS 에셋 카탈로그에는 AppIcon 하나뿐 | DOC-19 §5 |
| G2 | GameCast 부재 | `TrajectoryReplay.tsx`(1,073줄) 대응물 없음. 야구 게임임을 시각적으로 증명하는 화면이 0개 | DOC-19 §5 말미 |
| G3 | 앱 아이콘 variant 없음 | 1024 라이트 1장. iOS 18 다크/틴티드 미지원 → 홈 화면 다크모드에서 이질적 | HIG App Icons |
| G4 | 런치스크린 빈 화면 | `INFOPLIST_KEY_UILaunchScreen_Generation: YES` 자동 생성 단색 | project.yml |
| G5 | 성장·보상 연출 부재 | `GrowthCelebration.tsx`, `AbilityGauge.tsx` 대응물 없음. 피드백은 햅틱 1종 + 텍스트 한 줄 | DOPAMINE_ENGAGEMENT_REVIEW |
| G6 | 디자인 검사 미적용 | `tools/check-design-system.mjs`의 대상이 `apps/windows/src` 하드코딩. `AppShell.swift`의 hex 리터럴 30여 개를 아무도 검사하지 않음 | check-design-system.mjs:6 |
| G7 | Midnight Dugout 미적용 | DOC-19의 조명·구도·질감 방향이 iOS에 0% 반영. 색 토큰만 포팅됨 | DOC-19 §3 |

### 1.4 플랫폼 규격 결함

| ID | 항목 | 현재 |
|---|---|---|
| P1 | 영어 로컬라이제이션 | 전 문자열 Swift 소스에 한국어 하드코딩. String Catalog 없음 |
| P2 | 방향 전환 | `UISupportedInterfaceOrientations` 미지정 → 전 방향 허용, 가로 레이아웃 미검증 |
| P3 | iPad 대응 | `NavigationSplitView`가 커리어 탭에만. 나머지는 아이폰 레이아웃 확대 |
| P4 | 위젯·라이브 액티비티 | 없음. 주 단위 진행 게임에 적합도가 가장 높은 기능 |
| P5 | App Store 자산 | `marketing/`에 `steam/`만 존재. 스크린샷·프리뷰·프로모션 텍스트 0 |
| P6 | CI | `.github/workflows/`에 iOS 잡 없음. `xcodebuild` 호출 0회, iOS 테스트 0개 |

## 2. 목표 상태

### 2.1 권한 모델

```
앱 구매(App Store) ─→ 앱 실행 = proCareerAccess 보유
```

- `SimulationCore`의 `ProEntitlementSnapshot`은 **그대로 둔다**. 코어는 스토어를 몰라야 한다는 원칙(ADR-013)을 지킨다.
- iOS 셸이 `EntitlementSource.purchase` + `status: .active`인 스냅숏을 항상 공급한다. 근거는 "이 바이너리는 유료 다운로드로만 획득된다"는 채널 사실이다.
- `#if DEBUG` 분기를 제거한다. 디버그와 릴리스가 같은 경로를 타야 시뮬레이터 QA가 의미를 갖는다.
- 구세이브 복원 시 `.development` 소스를 거부하던 조건도 제거한다. 유료앱에서는 개발 빌드 세이브를 막을 이유가 없고, 오히려 TestFlight 사용자의 진행을 날린다.

### 2.2 중요 경기 = 실제 승부

```
importantGame 단계 진입
  → PitchSession 생성 (라이벌 타자·수비·구장·상황 구성)
  → preparePitch  ── 포수 추천 + 스카우팅 리포트 + 라이벌 적응도
  → 플레이어가 구종·존·강도 선택
  → submitPitch   ── 실행 결과·궤적·타구·수비 판정
  → (타석 종료까지 반복, 최대 3타자)
  → 누적 ImportantInningReport 생성
  → ProCareerEngine.resolveImportantGame
```

핵심: `ImportantInningReport`의 7개 필드(pitches/strikeouts/walks/runsAllowed/expectedDamage/actualDamage/recommendationAccepted)를 **실제 투구 결과에서 누적**한다. 데스크톱 `App.tsx`가 이미 하는 것과 동일한 방식이다.

라이벌 타자는 `ProCareerSnapshot.currentRival`(아키타입 문자열만 보유)에서 타격 수치를 결정론적으로 파생한다. 데스크톱의 `apps/windows/src/proRival.ts`를 Swift로 포팅해 **두 플랫폼이 같은 상대를 만나게** 한다.

### 2.3 화면 구성

| 화면 | 역할 | 스크린샷 후보 |
|---|---|---|
| 오늘 | 구단 키아트 위에 상태·다음 행동. 시즌 아크(`seasonSegment`)와 올해의 세 가지 긴장(`seasonTensions`) 노출 | ○ |
| 이번 주 | 훈련 카드 5장(Picker 대체). 각 카드에 효과·피로 비용 명시 | ○ |
| **승부** | 3×3 존 그리드 + 구종 4개 + 강도 3단. 포수 추천 카드. 카운트 스코어보드 | **◎ 주력** |
| **궤적** | 투구 3D 시리즈와 타구 비행을 Canvas로 렌더 | **◎ 주력** |
| 성장 | 능력 상승 시 게이지 애니메이션 + 등급 사다리 | ○ |
| 기록 | 시즌·통산·수상·마일스톤 | △ |

### 2.4 비주얼 방향

DOC-19 "Midnight Dugout"을 iOS에 적용한다.

- 키아트 3장(`pro-career-stadium-tunnel`, `high-school-stadium-night-v2`, `high-school-career-intro-v2`)을 PNG로 변환해 에셋 카탈로그에 넣는다. webp는 Xcode 에셋 카탈로그가 받지 않는다.
- 한 화면에 큰 키아트는 하나만(DOC-19 §7). 오늘 탭 헤더 = 구장, 승부 화면 = 궤적 자체가 앵커이므로 배경 이미지를 쓰지 않는다.
- 고대비 모드에서는 키아트를 제거하고 단색 배경으로 전환한다(DOC-19 §5).
- 색 리터럴을 `DesignSystem.swift` 한 파일로 모으고, `check-design-system.mjs`가 Swift도 검사하게 해서 재유입을 막는다.

## 3. 작업 목록

### Phase A — 팔 수 있는 앱 (P0) · 완료

| # | 작업 | 산출물 | 상태 |
|---|---|---|---|
| A1 | 유료앱 권한 모델 전환 | `AppEntitlement`·`CareerBootstrap.swift`, `MobileCareerStore` 게이트 제거 | 완료 |
| A2 | 라이벌 타자 파생 포팅 | `ProRivalBatter+Stats.swift` (proRival.ts 대응) | 완료 |
| A3 | 투구 세션 스토어 | `PitchSession.swift` — prepare/submit 루프, 리포트 누적 | 완료 |
| A4 | 승부 화면 | `PitchView.swift` — 존 그리드·구종·노림·힘 배분·포수 사인·카운트 | 완료 |
| A5 | 궤적 뷰 | `TrajectoryView.swift` — 포수 시점 투구 궤적 + 탑다운 타구 | 완료 |
| A6 | 중요 경기 연결 | `CareerFlowView`가 A3~A5를 호출, 하드코딩 리포트 제거 | 완료 |
| A7 | 커리어 시작 화면 | `CareerSetupView.swift` — 투수 유형 선택·이름·지명 | 완료 |

### Phase B — 게임처럼 보이는 앱 (P1) · 완료

| # | 작업 | 산출물 | 상태 |
|---|---|---|---|
| B1 | 디자인 토큰 분리 | `DesignSystem.swift`(색·여백·카드·키아트), `AppShell`에서 색 정의 제거 | 완료 |
| B2 | 키아트 에셋 | `Assets.xcassets/KeyArt*` 3종, `KeyArtHeader` 뷰 | 완료 |
| B3 | 앱 아이콘 variant | 라이트/다크/틴티드 3종 | 완료 |
| B4 | 런치스크린 | 명시 Info.plist + `LaunchLogo`·`LaunchBackground` | 완료 |
| B5 | 주간 계획 카드화 | Picker → 효과·비용이 보이는 카드 5장 | 완료 |
| B6 | 성장 연출 | `GrowthCelebrationView.swift`, `AbilityGaugeView.swift` | 완료 |
| B7 | 햅틱 큐 | `FeedbackCue`별 `sensoryFeedback` 분기 | 완료 |
| B8 | 오늘 탭 재구성 | 시즌 아크 바·세 가지 승부처·라이벌 예고 | 완료 |
| B9 | 기록 탭 재구성 | 스탯 타일·능력 게이지·통산 시즌 | 완료 |

### Phase C — 출고 규격 (P2)

| # | 작업 | 산출물 | 상태 |
|---|---|---|---|
| C1 | 디자인 검사 확장 | `check-design-system.mjs`가 Swift 색 리터럴·고정 글자 크기·유료앱 계약 검사 | 완료 |
| C2 | iOS 테스트 타깃 | `apps/ios/Tests`(유닛 22), `apps/ios/UITests`(스모크 1) | 완료 |
| C3 | CI 잡 | `ci.yml` iOS 잡 — 프로젝트 생성 검증·test·Release 빌드 | 완료 |
| C4 | 방향 고정 | 아이폰 세로 고정, 아이패드 전 방향 | 완료 |
| C5 | 로컬라이제이션 | — | **보류. §7 참조** |
| C6 | App Store 자산 | `marketing/appstore/README.md` — 사양·생성 절차·제출 점검표 | 완료 |
| C7 | 위젯 | — | 미착수 |

## 3.1 검증 결과

| 기준 | 결과 |
|---|---|
| 릴리스 빌드에서 커리어가 열린다 | `-configuration Release` 빌드 성공, 시뮬레이터 완주 |
| 같은 선택이 항상 같은 결과를 내지 않는다 | `testDifferentSeedsDivergeOnTheSameChoices` |
| 시드가 같으면 결과가 같다 | `testSameSeedAndSameCallsGiveSameOutcomes` |
| 능력치가 결과에 영향을 준다 | `testAbilityChangesTheAccumulatedReport` (6개 시드 합계 비교) |
| 세션이 반드시 끝난다 | `testSessionAlwaysTerminates` |
| 타자 교체가 코어를 깨뜨리지 않는다 | `testAdvancingBattersDoesNotFailTheSession` |
| 화면으로 실제 도달 가능하다 | `CareerSmokeUITests` — 시작 → 중요 경기 → 결과 반영 완주 |
| 색 리터럴이 토큰 밖에 없다 | `npm run check:design-system` 통과 |
| 금칙어가 없다 | `npm run check:copy` 통과 |

### 구현 중 발견해 고친 결함

- **라이벌 기억 matchupID 불일치.** 타석이 끝나고 다음 타자로 넘어갈 때 이전 타자의
  `RivalMemorySnapshot`을 그대로 넘겨 코어가 승부를 거부했다. 타자 교체 시 기억을 비운다.
- **한 구로 끝나는 중요 경기.** 1사에서 시작하면 병살 하나로 이닝이 끝나 주력 장면이 한 구
  만에 종료됐다. 모든 트리거를 무사 시작으로 바꿨다.
- **한글 PRODUCT_NAME.** `TEST_HOST` 경로가 깨져 테스트 타깃을 붙일 수 없었다. 번들 이름은
  ASCII로 두고 표시 이름만 Info.plist에서 한글로 준다.

## 4. 실행 순서 근거

A → B → C 순서를 고수한다.

- A 없이 B를 하면 **빈 화면을 예쁘게 칠하는 일**이 된다.
- C5(로컬라이제이션)를 A/B보다 먼저 하면 문자열이 바뀔 때마다 카탈로그를 다시 손봐야 한다. 화면이 확정된 뒤에 한 번에 처리한다.
- C7(위젯)은 별도 익스텐션 타깃이라 앱 본체와 독립적이다. 마지막으로 미룬다.

## 5. 검증 기준

| 기준 | 방법 |
|---|---|
| 릴리스 빌드에서 커리어가 열린다 | `xcodebuild -configuration Release` 후 시뮬레이터 실행 |
| 같은 선택이 항상 같은 결과를 내지 않는다 | 동일 계획으로 3회 승부 → 성적 분산 확인 |
| 시드가 같으면 결과가 같다 | 결정론 테스트(코어 계약 유지) |
| 능력치가 결과에 영향을 준다 | stuff 40 vs 70 투수로 동일 시드 승부 → 탈삼진 차이 |
| 색 리터럴이 토큰 밖에 없다 | `npm run check:design-system` |
| 금칙어(실존 구단명)가 없다 | `npm run check:copy` (이미 iOS 포함) |
| 빌드·테스트가 CI에서 돈다 | ci.yml iOS 잡 green |

## 7. 로컬라이제이션을 보류한 이유

계획 단계에서는 C5를 "String Catalog 하나 추가"로 잡았으나, 실제 문자열을 세어 보니
규모가 다르다.

| 위치 | 한국어 문자열(중복 제외) |
|---|---|
| `apps/ios/Sources` | 245 |
| `packages/simulation-core/Sources` | 834 |

엔진 쪽 834개는 UI 껍데기가 아니라 **게임 콘텐츠**다. 경기 피드백, 뉴스 헤드라인, 라이벌
프로필, 학교·구단 이름, 마일스톤 문구가 여기서 나온다. 그리고 이들은 데스크톱과 공유하는
코어에서 나오므로, iOS만 영어로 만들 수 없다.

여기에 기술적 제약이 하나 더 있다. SwiftUI는 `Text("리터럴")`만 자동으로 지역화 키로
쓴다. `PitchCopy.zone(_:)`처럼 함수가 만들어 준 `String`은 지역화되지 않는다. 제대로 하려면
표현 헬퍼를 전부 `LocalizedStringResource` 반환으로 바꿔야 한다.

UI 껍데기만 번역하면 **영어와 한국어가 한 화면에 섞인 앱**이 나온다. 한국어 전용보다 나쁘다.
따라서 이번 범위에서 뺐고, 대신 다음을 했다.

- `CFBundleDevelopmentRegion: ko`를 명시했다. 자동 생성 기본값(`en`)이 App Store에서 기본
  언어를 영어로 잘못 표시하던 문제를 고친 것이다.

영어판을 하려면 별도 단계로 다룬다. 순서는 (1) 코어 콘텐츠 문자열을 키·카탈로그로 분리,
(2) 표현 헬퍼를 `LocalizedStringResource`로 전환, (3) DOC-10 내러티브 바이블의 영어 대응본
작성. 세 번째가 가장 크고, 번역이 아니라 창작에 가깝다.

## 6. 범위 밖 (이번에 하지 않는 것)

- **고교 커리어 iOS 이식.** 코어(`HighSchoolCareer.swift` 2,042줄)는 준비돼 있으나 화면 수가 프로 커리어의 3배다. 프로 커리어가 유료앱으로 성립한 뒤 별도 단계로 다룬다.
- **피처랩 iOS 이식.** 동일 이유.
- **StoreKit.** 유료앱 모델에서는 필요 없다. 나중에 프리미엄 확장팩을 붙일 때 재검토한다.
- **Game Center / iCloud 동기화.** 저장 포맷(`ProCareerResult` Codable)은 이미 이식 가능하므로 나중에 붙일 수 있다.
