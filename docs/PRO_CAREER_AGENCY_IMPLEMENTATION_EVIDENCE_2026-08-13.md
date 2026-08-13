# 프로 커리어 주도권 개선 구현 증거

- 기준 계획: `PRO_CAREER_AGENCY_FINAL_IMPLEMENTATION_PLAN_2026-08-13.md`
- 구현일: 2026-08-13
- 범위: iOS 프로 커리어와 공유 SimulationCore
- 제외: 작업 중이던 Android/Unity 변경, 실사용자 검증, 프로덕션 롤아웃

## 이번 구현에서 닫은 문제

1. 주간 계획의 무음 기본 선택을 제거하고 실제 선택 전 진행을 막았다.
2. 구규칙 회복은 한 주·0경기임을 명시하고 구간 반복을 금지했다.
3. 새 프로 규칙 v2에서는 회복 훈련 중에도 역할별 예정 등판을 유지하고 실제 투구 수를 피로에 반영한다.
4. 직접 승부가 자동 등판 뒤 보너스 경기로 추가되던 중복을 없애고, 같은 주 예정 등판 한 행을 직접 승부 포함 경기로 교체한다.
5. 진행 결과에 주 수, 경기·선발·이닝, 감독의 믿음, 피로, 역할·레벨·주요 기록 변화를 함께 표시한다.
6. 서비스 기간·통산 기록·최근 성적·수상으로 선수 위상을 계산하고, 나이만으로 직접 승부 예산을 줄이지 않는다.
7. 시즌 선택은 다음 직접 승부에서 공개된 후속 반응으로 정확히 한 번 회수한다. 승부 사이에 선택이 여러 개 쌓이면 모두 회수한다.
8. 포수의 1안과 2안을 같은 정보 계층에서 한 탭으로 선택하며, 둘 다 포수 사인 수락으로 집계한다. 직접 수정은 계속 별도 판단으로 남는다.
9. 한국어·영어 화면은 예정 등판, 직접 승부 포함 여부, 회복 산식을 실행 전에 설명한다.

## 저장 호환 경계

- `proRulesVersion == nil`인 진행 중 저장은 구규칙 v1로 계속 실행한다.
- 구규칙의 회복 0경기, 베테랑 직접 승부 상한, 중요 경기 append 동작과 기존 commitment를 유지한다.
- 새 커리어는 v2로 시작한다.
- 구저장은 오프시즌 경계에서만 v2로 이동한다.
- 지연 결과 필드는 optional이며, 값이 없는 과거 결정 기록의 commitment는 바이트 단위로 같은 입력을 사용한다.

## 자동 검증 결과

### 통과

- `swift test --package-path packages/simulation-core`
  - 362 tests, 0 failures
  - 20시즌 완주 시드 100...119 포함
- 최종 호환 패치 뒤 선택 실행
  - `BalanceV3CompatibilityTests`: 3 tests, 0 failures
  - 신규 프로 주도권 핵심 테스트: 4 tests, 0 failures
- iOS 선택 실행
  - `ProSeasonDecisionTests` + `PitchSessionTests`: 45 tests, 0 failures
- `npm run check:balance`: 통과
- `npm run check:korean-copy:ci`: 1,393 strings, 오류 0, 경고 0
- `npm run check:copy`: 실존 야구 IP 및 내부 용어 미노출
- `npm run check:ios-localization`: pending surface 0
- `git diff --check`: 통과

### 이번 변경과 무관한 기존 전체 게이트 실패

`npm run check:design-system`은 다음 두 기존 파일에서 실패한다. 이번 변경 파일이 아니며 사용자 작업을 덮지 않았다.

- `apps/ios/Sources/HighSchoolCareerView.swift`: 얇은 세로 강조 레일
- `apps/ios/Sources/AppShell.swift`: 필수 계약 `최근 등판` 누락

## 아직 완료로 주장하지 않는 항목

- 실제 한국어 사용자 5명의 과업 검사와 문구 블라인드 평가
- 프로덕션 200시즌 및 후반기 30시즌의 행동 지표
- compact/standard/detailed 플레이 밀도 선택 UI
- 별도 reduced-load·1회 등판 건너뜀 명령과 완전한 구조화 receipt
- Android/Unity 패리티

따라서 이번 변경은 리뷰의 즉시 체감 문제를 닫는 안전한 iOS/코어 수직 구현이다. 계획 문서의 사람 검증과 전체 롤아웃 완료를 대신하지 않는다.
