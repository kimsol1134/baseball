# 세이버메트릭스 1단계 + 간이 WAR 구현 보고 (2026-09-03)

구현: grok-4.6(중단: Grok Build 잔액 소진) + PM 마감. 스펙: `docs/SABERMETRICS_STAGE1_WAR_SPEC_2026-09-02.md`.
저장 형식·시뮬레이션·픽스처 무변경. 전부 `ProSeasonStats`에서 파생한 표시 전용 값이다.

## 1. 변경 파일
- 코어: `packages/simulation-core/Sources/SimulationCore/SabermetricsRules.swift`(신규), `Tests/SimulationCoreTests/SabermetricsRulesTests.swift`(신규, 9건)
- iOS: `RecordView.swift`(세이버 섹션 `record.saber`), `ProSeasonSettlementView.swift`(FIP·WAR 한 줄), `ProRetirementViews.swift`(통산 WAR), `CareerSharePresentation.swift`(은퇴 카드: 시즌 행을 "시즌 N · WAR x.x"로 병합), `CareerDisplayRules.swift`/`MobileCareerStore+Queries.swift`(`saberBoard` 프로젝션), `GlossaryCatalog.swift`(FIP·WAR·K%·BB%·RA9·QS·대체 수준), 문구 키(`RecordCopyKeys`·`ProCopyKeys`·`ShareCopyKeys`·`ProFeatureCopy`), `Localizable.xcstrings`/`GameContent.xcstrings`(ko/en/ja), 테스트 `SabermetricsSurfaceTests.swift`(신규) 외 계약 테스트 갱신
- 게이트: `tools/check-balance.mjs`에 WAR 밴드 2줄

## 2. 리그 상수 v1 (분포 스모크 400 선발 등판·7,073아웃에서 측정, 동결)
| 항목 | 값 |
|---|---|
| RA9 | 3.45 |
| K/9 · BB/9 · HR/9 | 7.72 · 2.26 · 0.75 |
| H/9 · WHIP | 9.05 · 1.26 |
| K% · BB% | 20.1% · 5.9% |
| FIP 상수 | 3.33 (리그 FIP = 리그 RA9가 되도록) |

스펙 초안(RA9 3.60, HR/9 0.9)은 측정값으로 교체했다. 스펙의 `×27` 표기는 K/9 패턴이고 FIP는 `(13HR+3BB−2K)/IP + 상수`로 구현했다(센티 정수).

## 3. 간이 WAR
```
raap9       = lgFIP − FIP                                (센티)
replacement = 27 + round(81 × GS / G)                    (센티: 구원 0.27, 선발 1.08)
leverage    = 마무리(세이브 ≥ 10, 선발 0) 1.3, 그 외 1.0
WAR×100     = round((raap9 + replacement) × outs × leverage / 243000)   // /27 아웃/9이닝, /9 runsPerWin, 퍼밀
```
정수 반올림 규칙 고정(`divRound`), 통산 WAR = 시즌 WAR 합(재계산 아님, 테스트로 고정). 명예의 전당·계약 시장·목표판 판정에는 쓰지 않는다(`testScoringRulesDoNotImportDisplayWAR`).

## 4. 밸런스 밴드 (`npm run check:balance`)
- 선발 평균 WAR = 2.400 (허용 1.5~2.5) 통과
- 마무리 평균 WAR = 0.690 (허용 −0.5~2.5) 통과

## 5. 게이트 원문
- `swift test --package-path packages/simulation-core`: Executed 598 tests, 1 skipped, 0 failures
- `npm run check`: 종료 코드 0 (디자인·문구·밸런스·코어·웹·데스크톱)
- `npm run check:ios-localization`: passed, 4036 catalog entries
- iOS `BaseballIOSTests`: 1차 580건 중 3건 실패 → 원인은 `record.saber.season-header` 키가 카탈로그에 미주입(grok 중단 지점). `tools/copy-saber.json`에서 주입 후 `LocalizationCoverageTests`·`ProCareerGoalBoardSurfaceTests`·`SabermetricsSurfaceTests` 51건 통과. 전체 재실행 결과는 아래 6절.

## 6. PM 마감 기록
- 전체 iOS 스위트 재실행: Executed 580 tests, 0 failures, TEST SUCCEEDED. `testRetirementSharePreviewOpens` passed (25.956s).
- 세이버 섹션 스크린샷 `apps/ios/releases/qa-1.2.9/saber/records-saber.png`는 유닛 테스트의 `ImageRenderer` 캡처라 가로 스크롤 표 본문이 비어 보인다(렌더러 제약). 실기기 화면은 UI 여정 테스트의 기록 탭 캡처로 확인: (실행 후 기입)

## 7. 미해결 / 다음 단계
- 자책점·사구·타구 유형 카운터(BABIP·GB%·HR/FB), LOB%, 홀드, WPA는 2단계.
- WAR를 명예의 전당·계약에 반영하는 것은 규칙 버전 11 항목.
- 안드로이드는 표시 전용이라 코어 패리티 영향 없음. Compose 기록 화면이 생기면 같은 공식을 Kotlin에 옮긴다.
