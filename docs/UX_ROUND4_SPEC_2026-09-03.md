# UX 4차 스펙 — D. 검증과 마감 (2026-09-03)

1~3차(커밋 0c0667a7 → ff7f9c1d)로 가독성·탭바·구조·정보 예산을 바꿨다. 4차는 **바꾼 것이 모든 기기·모든 국면에서 실제로 서 있는지 재고, 남은 예산 초과와 측정 공백을 메우는** 라운드다. 0절 절대 규칙·1절 기존 부품·보고서 양식은 `docs/UX_ROUND2_SPEC_2026-09-03.md`를 따른다. 측정은 `tools/measure-info-budget.mjs`, 예산표는 `docs/UX_ROUND3_SPEC_2026-09-03.md` C7. 보고서는 `docs/UX_ROUND4_REPORT_2026-09-03.md`, 스크린샷은 `apps/ios/releases/qa-1.2.9/round4/<항목>/`.

## D1. 투구 준비 화면 예산 (53/10/10 → ≤ 8/1/4)

근거: 3차 C7 표에서 유일하게 크게 초과한 화면. 원인은 포수 제안 카드 한 장(사인·칩 2·"포수의 생각" 4줄·1안/2안·내 선택 유지·상대 분석)이다.
- "포수의 생각"은 **기본 접힘**(`ProgressiveDisclosure`, contentID `pitch.sign.rationale`, `important: false`, 첫 회 포함 접힘). 펼치면 지금 문장.
- 1안/2안은 **세그먼트 한 줄**(선택된 안의 사인만 아래 한 줄)로. "내 선택 유지" 토글과 "상대 분석"은 `설정 ▾` 접기 하나로 묶는다.
- 사인 한 줄 + 칩 2개 + 던지기(고정 바)는 그대로. 슬라이더·와인드업·자동 릴리스 불변(2차 스펙 0절 3항).
- 완료 조건: 연습 투구 3구 뒤 측정 텍스트 ≤ 8, 20자+ 문장 ≤ 1, 버튼 ≤ 4. identifier(`pitch.selectedCall`, `pitch.acceptPrimaryCall`, `pitch.acceptAlternativeCall`, `pitch.holdCall`, `pitch.scouting.toggle`, `pitch.acceptCatcherCall`) 유지.

## D2. 측정 공백 메우기 — 훈련·결정 픽스처

근거: 3차에서 고교 훈련(추천 펼침)·프로 결정 카드는 픽스처가 없어 측정하지 못했다.
- DEBUG 전용 런치 인자 두 개를 `BaseballApp.swift`의 기존 픽스처 분기(`-uiTestDraftedCareerFixture` 옆)에 추가: `-uiTestTrainingFixture`(고교 1장, 학교 선택 완료, 훈련 국면 첫 주), `-uiTestSeasonDecisionFixture`(프로 1시즌 6주차 결정 대기). 픽스처 설치 함수는 `HighSchoolCareerStore`/`MobileCareerStore`의 **본체 파일 또는 새 `+Fixtures.swift` 확장**에 둔다(Lifecycle 파일 수정 금지). 결정론: 고정 시드, 커리어 RNG 소비 없이 스냅샷을 직접 만든다(기존 `installReviewImprovementFixtureForUITesting` 방식을 따른다).
- 두 픽스처로 C7을 재서 표에 채운다. 훈련 화면 예산 ≤ 8/1/3, 결정 카드 ≤ 9/1/3. 초과하면 이 라운드에서 맞춘다(C5·결정 카드 접기 조정).
- `QACaptureUITests`에 두 픽스처 캡처 케이스를 추가한다(기존 케이스 이름·identifier 변경 금지).

## D3. iPhone SE와 큰 글씨

근거: 고정 바 두 개(훈련하기 + 3번 연속)와 헤더는 iPhone 17 기준으로만 봤다.
- 시뮬레이터에 **iPhone SE(3세대)** 가 이미 있으면 그것을 쓰고, 없으면 `xcrun simctl create "iPhone SE (3rd generation)" ...`로 **하나만** 만들고 라운드가 끝나면 삭제한다(부팅은 iPhone 17과 동시에 하지 않는다 — 17을 shutdown 하고 SE를 boot).
- SE에서 6개 예산 화면 + 온보딩 4단계를 캡처. 고정 바가 화면의 30% 이상을 차지하면: 두 번째 줄(3번 연속)을 **아이콘+제목 한 줄**로 줄이고 설명은 첫 회에만.
- Dynamic Type 접근성 크기(`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` 런치 인자 또는 앱 설정 "아주 크게")에서 같은 화면을 캡처. 잘림(`…`)·겹침이 있는 곳은 `ViewThatFits` 또는 세로 재배치로 고친다. 특히 헤더 타일 3개, 칩 줄, 계약 숫자, 결정 칩.
- 완료 조건: SE·XXXL 캡처 12장 이상, 잘림·겹침 0.

## D4. VoiceOver 순서

근거: 고정 하단 바를 `safeAreaInset`으로 넣은 뒤 읽기 순서를 확인하지 않았다.
- `axe describe-ui`의 요소 순서(접근성 트리 순서)로 훈련·계약·투구 화면을 확인한다. 기대: 헤더 → 본문 → 고정 바(주 행동)가 **마지막**. 아니면 `accessibilitySortPriority`로 맞춘다.
- 알림 큐 카드(C1)는 헤더 바로 다음에 읽히고, 닫기 버튼에 `accessibilityLabel`이 있다.
- 완료 조건: 세 화면의 순서를 보고서에 나열.

## D5. 프로 2시즌 스모크

근거: 페르소나 3인 모두 정규 경로로 프로 2시즌 결산까지 가지 못했다. 결산·오프시즌·은퇴 화면은 코드 리뷰로만 검증됐다.
- `-uiTestDraftedCareerFixture`로 시작해 계약 서명 → 주간 자동 진행 → 결정 → 시즌 결산 → 오프시즌 → 2시즌 결산까지 `axe`로 플레이한다(40분 예산). 각 국면 첫 화면을 캡처하고 C7로 잰다.
- 발견되는 결함(잘림·겹침·빈 화면·막힘·같은 말 반복)은 이 라운드에서 고친다. 결산 화면은 2차 스펙 A 규칙(리뷰 제목 먼저, 큰 숫자 위계)을 적용.
- 완료 조건: 2시즌 결산 캡처 2장, 오프시즌·은퇴 미리보기 캡처, 발견·수정 목록.

## D6. 말투 통일 패스 (시스템 문구)

근거: 설정 푸터처럼 "~해요/~습니다"가 섞인 곳이 남아 있다.
- `Localizable.xcstrings`의 ko 값 중 시스템 문구(`settings.*`, `pro.*`, `training.*`, `pitch.*`, `meta.*`, `chapter.*`, `draft.*`, `fatigue.*`, `notice.*`)에서 "~해요/~에요/~네요"로 끝나는 문장을 "~합니다/~입니다" 또는 명사형으로 통일한다. 서사(`content.*`)와 대사는 건드리지 않는다. 코어 패리티가 잠긴 키(2차 스펙 0절 5항)는 제외.
- `node tools/check-korean-game-copy.mjs`와 `LocalizationCoverageTests` 통과. 바뀐 키 목록을 보고서에.

## D7. 순서와 규모

| 순서 | 항목 | 예상 | 비고 |
|---|---|---|---|
| 1 | D2 픽스처 + 측정 | 4h | 이후 항목의 측정 기반 |
| 2 | D1 투구 예산 | 3h | |
| 3 | D5 2시즌 스모크 | 1일 | 결함 수정 포함 |
| 4 | D3 SE·XXXL | 4h | 기기 생성/삭제 규칙 준수 |
| 5 | D4 VoiceOver 순서 | 2h | |
| 6 | D6 말투 통일 | 2h | |

시간이 모자라면 D6 → D4 순으로 뺀다. D1·D2·D5는 빼지 않는다. 항목마다 게이트를 돌리고, 라운드 끝에 유닛 테스트 전체를 한 번 더 돌린다.
