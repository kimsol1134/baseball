# 보직 지원 + 용어 카드 구현 보고 (2026-09-02)

구현: grok-4.6. 스펙: `docs/PRO_ROLE_REQUEST_AND_GLOSSARY_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음. 픽스처 재생성 없음. 시뮬레이터는 부팅된 iPhone 17만 재사용.

## 0. 규칙 준수

- 워킹트리의 1.2.7·주간 결정 훅·게이트 정리 변경을 되돌리지 않았다.
- `planWeek` RNG 스트림에 `next*()`를 넣지 않았다. 보직 지원 판정은 문턱만 쓴다. `requestRole`은 시드를 검증만 하고 `nextSeed`를 그대로 반환한다.
- 규칙 버전은 9로 유지했다. 보직 지원은 `proRulesVersion >= 9`에서만 켠다. 새 버전을 올리지 않았다.
- 스냅샷 필드 `roleRequest`는 Optional + 합성 Codable(`decodeIfPresent`). 스키마 버전 5 유지. `==`와 `replacing`에 반영.
- v8 저장은 필드가 없어 nil로 디코드되고, commitment에 `role_request` 토큰이 붙지 않아 바이트 동일 경로를 유지한다.
- ko/en/ja 카탈로그를 넣었다. 실존 구단·선수명 없음. 투구 슬라이더 코드는 접근하지 않았다.
- 골든 픽스처를 재생성하지 않았다. 테스트를 삭제하거나 단언을 약화하지 않았다.

## 1. 변경 파일

이 작업에서 직접 손댄 파일만 적는다. 워킹트리의 1.2.7·주간 결정 훅·게이트 정리 미커밋 변경은 그대로 두었다.

### simulation-core
- `packages/simulation-core/Sources/SimulationCore/ProCareerModels.swift` — `ProRoleRequest*` 타입, 스냅샷 Optional 필드, `RequestProRoleParams`
- `packages/simulation-core/Sources/SimulationCore/ProRoleRequestRules.swift` — 결정적 판정·노출 게이트
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` — `requestRole`, 6주차 roleMeeting 강제 삽입(부상·중요경기만 이월), commitment, 시즌 롤오버 시 필드 비움
- `packages/simulation-core/Sources/SimulationCore/ProCareer+Journey.swift` — 여정 오프시즌 롤오버에서 `roleRequest` 비움
- `packages/simulation-core/Tests/SimulationCoreTests/ProRoleRequestTests.swift` — 코어 판정·planWeek 통합·v8 리플레이

### iOS
- `packages/ios-layers/Sources/BaseballIOSDomain/GlossaryCatalog.swift`
- `apps/ios/Sources/Application/CareerDisplayRules.swift` — 보직 지원 프로젝션
- `apps/ios/Sources/Application/MobileCareerStore+Season.swift` — `requestRole` + `CareerTelemetry`
- `apps/ios/Sources/Platform/GameAnalytics.swift` — `pro_role_requested`
- `apps/ios/Sources/Presentation/GlossaryText.swift` — 인라인 매칭·시트·설정 목록
- `apps/ios/Sources/Presentation/ProFeatureCopy.swift` — 수락 전망 문구
- `apps/ios/Sources/Presentation/ProCareerPresentation.swift` — 거절 뉴스 키 해석
- `apps/ios/Sources/Presentation/Localization/ProCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/MetaCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/GameContent.xcstrings`
- `apps/ios/Sources/Presentation/Localization/Localizable.xcstrings`
- `apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift` — 스프링캠프 보직 지원 카드
- `apps/ios/Sources/Features/Pro/ProSeasonDecisionView.swift` — 효과 요약을 설명 위에, compact면 detail 접기, `GlossaryText`
- `apps/ios/Sources/Features/HighSchool/HighSchoolTrainingViews.swift` — 성장 요약을 설명 위에
- `apps/ios/Sources/Features/Shell/SettingsView.swift` — 용어 설명
- `apps/ios/Tests/ProRoleRequestAndGlossaryTests.swift`
- `apps/ios/Tests/LocalizationCoverageTests.swift` — 용어 20개 ko/en/ja 패리티
- `docs/localization/ios-copy-schema.json` — `inventory:ios-localization --write`
- `tools/inject-role-request-glossary-copy.mjs` — 카탈로그 키 주입용 일회 스크립트

`apps/ios/project.yml`은 이 작업에서 바꾸지 않았다. iOS 게이트에서 `xcodegen generate`를 실행해 `Baseball.xcodeproj/project.pbxproj`가 갱신됐다.

## 2. 보직 지원

시점: v9, `phase == weeklyPlan`, `week == 0`, `seasonSegment == springCamp`, 이번 시즌에 아직 지원하지 않음.
계약 `kind`가 `renewal_long` / `prove_it` / `free_agent`이면 카드를 숨긴다. 신인 계약(`rookie` 또는 kind nil)은 시즌 1 수용 기준에 맞게 카드를 연다.

선택지: 선발 / 중간(`long_relief`) / 마무리. 셋업은 중간으로 정규화한다.

### 문턱 (PM 수정 라운드)

이미 맡은 보직(`state.role` 또는 그 시즌 `trustAssignedRole`, 셋업은 중간으로 정규화)을 다시 지원하면 항상 수락이고 믿음은 변하지 않는다. 시즌 1만 선발/마무리 수락에서 믿음·호흡 문턱을 뺀다. 체력·구위 문턱과 시즌 2+ 믿음 문턱은 그대로다.

| 보직 | 수락 | 조건부 | 거절 |
|---|---|---|---|
| 선발 | 이미 맡은 보직은 항상 수락(신뢰 변화 없음). 시즌 1은 stamina ≥ 55. 시즌 2+는 stamina ≥ 55 && managerTrust ≥ 45 | stamina ≥ 48 | 그 외. 믿음 −1, 뉴스 키 |
| 마무리 | 이미 맡은 보직은 항상 수락(신뢰 변화 없음). 시즌 1은 stuff ≥ 58. 시즌 2+는 stuff ≥ 58 && catcherTrust ≥ 45 | stuff ≥ 52 | 그 외. 믿음 −1, 뉴스 키 |
| 중간 | 항상 수락 | — | — |

수락·조건부: `rolePreference = requested`. 조건부만 `reviewWeek = 6`을 기록하고, 그 주(또는 부상·중요경기면 다음 결정 주)에 `roleMeeting`을 강제 삽입한다. 이 경우만 이월한다. 시즌 결정 상한은 그대로 7.

분석: `GameAnalytics.Event.proRoleRequested = "pro_role_requested"` (requested, outcome, season). 스토어는 `CareerTelemetry`만 부른다.

분포 스모크는 플레이어 지원을 자동으로 넣지 않는다. 8시드 최종 보직은 starter 3 / long_relief 4 / closer 1이라 선발이 극단으로 치우치지 않았다. 문턱은 그대로 두었다.

## 3. 용어 목록

`GlossaryCatalog` 20개. 키는 `content.glossary.<id>.name|definition` (ko/en/ja).

| id | ko | en | ja |
|---|---|---|---|
| stuff | 구위 | Stuff | 球威 |
| command | 제구 | Command | 制球 |
| movement | 변화구 | Movement | 変化球 |
| stamina | 체력 | Stamina | 体力 |
| fatigue | 피로 | Fatigue | 疲労 |
| manager-faith | 감독의 믿음 | Manager faith | 監督の信頼 |
| catcher-chemistry | 포수와의 호흡 | Catcher trust | 捕手との呼吸 |
| mastery | 숙련 | Mastery | 熟練 |
| talent-wall | 재능 벽 | Talent wall | 才能の壁 |
| baseball-spirit | 야구혼 | Baseball spirit | 野球魂 |
| awakening | 각성 | Awakening | 覚醒 |
| lineage | 계승 | Lineage | 継承 |
| role | 보직 | Role | 役割 |
| qs | QS | QS | QS |
| era | ERA | ERA | ERA |
| whip | WHIP | WHIP | WHIP |
| k9 | K/9 | K/9 | K/9 |
| platoon | 플래툰 | Platoon | プラトゥーン |
| pitcher-lab | 투수연구소 | Pitcher lab | 投手研究所 |
| season-decision | 시즌 결정 | Season decision | シーズン決定 |

매칭: 현재 언어 표시명, 첫 등장만, 긴 이름이 겹침을 이긴다. 라틴 토큰은 단어 경계. 접근성 ID `glossary.term.<id>`, 힌트 `glossary.term.hint`.

효과 요약: 시즌 결정 선택지와 고교 훈련 카드에서 성장/효과 한 줄이 detail 위에 있다. CopyDensity compact면 detail을 접는다.

## 4. 게이트 원문 결과

시뮬레이터: `iPhone 17 (641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF) (Booted)`. 새로 만들지 않았다. xcodebuild는 한 번에 하나만 돌렸다.

### 4.1 `swift test --package-path packages/simulation-core`

종료 코드 0.

```
Test Suite 'BaseballSimulationPackageTests.xctest' passed at 2026-09-02 12:51:57.735.
	 Executed 546 tests, with 1 test skipped and 0 failures (0 unexpected) in 470.123 (470.163) seconds
Test Suite 'All tests' passed at 2026-09-02 12:51:57.735.
	 Executed 546 tests, with 1 test skipped and 0 failures (0 unexpected) in 470.123 (470.164) seconds
WAVE5_DISTRIBUTION seeds=1000 seasons=20 negative_funds=0 duplicate_finance=0 duplicate_settlement=0 contractless_active_seasons=0 season3_before_fan100=0
```

`ProRoleRequestTests` 12/12 포함.

### 4.2 `swift test --package-path packages/ios-layers`

종료 코드 0.

```
Test Suite 'BaseballIOSLayersPackageTests.xctest' passed at 2026-09-02 12:43:50.063.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.006 (0.007) seconds
Test Suite 'All tests' passed at 2026-09-02 12:43:50.063.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.006 (0.008) seconds
```

### 4.3 `npm run check`

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
Test Suite 'All tests' passed at 2026-09-02 13:02:20.524.
	 Executed 546 tests, with 1 test skipped and 0 failures (0 unexpected) in 488.916 (488.961) seconds
```

test:web:

```
 Test Files  30 passed (30)
      Tests  103 passed (103)
   Start at  13:02:20
   Duration  619ms (transform 1.23s, setup 0ms, import 1.77s, tests 166ms, environment 891ms)
```

build:web:

```
✓ built in 117ms
```

test:tauri:

```
test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.05s
```

check:tauri:

```
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.72s
```

### 4.4 `npm run run:pro-career:distribution:smoke`

종료 코드 0.

```
PRO_CAREER_DISTRIBUTION output=artifacts/analysis/pro-career-wave6/swift-distribution-smoke.json valid=true failures=
```

스모크 JSON `finalRoles`: closer 1, long_relief 4, starter 3 (시드 8). 지원 UI를 자동 선택하지 않으므로 기존 신뢰 배정 분포다. 문턱 조정 없음.

### 4.5 iOS `BaseballIOSTests`

첫 xcodebuild는 테스트 파일 ViewBuilder의 `try XCTUnwrap` 때문에 컴파일 실패(종료 65). 언랩을 렌더러 밖으로 옮긴 뒤 같은 부팅 기기에서 한 번 더 돌렸다.

`cd apps/ios && xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS -destination 'platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF' -only-testing:BaseballIOSTests test CODE_SIGNING_ALLOWED=NO`

종료 코드 0.

```
Test Suite 'BaseballIOSTests.xctest' passed at 2026-09-02 13:06:51.687.
	 Executed 528 tests, with 0 failures (0 unexpected) in 113.675 (113.856) seconds
Test Suite 'All tests' passed at 2026-09-02 13:06:51.687.
	 Executed 528 tests, with 0 failures (0 unexpected) in 113.675 (113.856) seconds
** TEST SUCCEEDED **
```

`LayerBoundaryTests`·`LocalizationBoundaryTests`·`LocalizationCoverageTests.testGlossaryCatalogHasKoreanEnglishJapaneseParity` 포함.

정적 게이트(이미 `npm run check` 전에도 통과):

`npm run check:ios-localization` 종료 코드 0.

```
iOS localization release check passed: 3753 catalog entries and zero pending surfaces
```

`npm run check:copy` 종료 코드 0.

```
문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출
```

## 5. 미해결

- 선택지·훈련 카드 전체가 Button이라, 그 안의 용어 링크 탭은 부모 버튼이 먹을 수 있다. 시즌 결정 **상세**(카드 밖)와 설정 목록은 시트가 열린다. 매칭은 단위 테스트로 고정했다.
- 분포 러너는 보직 지원을 고르지 않는다. 사람이 선발을 대량 수락하면 선발 비율이 올라갈 수 있다.
- Android Kotlin 포팅은 스펙 범위 밖.
- 커밋하지 않음.
