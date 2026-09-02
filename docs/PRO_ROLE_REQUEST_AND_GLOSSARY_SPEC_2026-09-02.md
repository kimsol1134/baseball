# 1.2.8 P0: 보직 지원 선택 + 용어 카드 스펙

작성: PM, 2026-09-02. 구현: grok. 리뷰 근거: "선발·계투·마무리 컨셉으로 하고 싶은데 계투나 마무리만 들어감"(2건), "능력치 관련 선택할 때 내용은 엄청 긴데 뭔 소린지 모르겠음 / 자기만 아는 용어 사용 금지"(3건).

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. 워킹트리의 1.2.7·주간 결정 훅·게이트 정리 변경을 되돌리지 않는다.
2. 프로 주간 루프(`planWeek`) RNG 스트림에 `next*()` 삽입 금지. 판정은 해시 또는 결정적 규칙으로만.
3. 규칙 버전 게이트: 보직 지원은 `proRulesVersion >= 9`(이미 주간 결정 훅이 9를 쓴다) 커리어에서만 켠다. 새 규칙 버전을 또 올리지 않는다. v8 이하 저장은 바이트 동일.
4. 스냅샷 신규 필드는 Optional + `decodeIfPresent`, 수동 Equatable·`replacing` 반영. `ProCareerPersistence.currentSchemaVersion`(5) 유지.
5. ko/en/ja 전부 필수. `npm run check:ios-localization`·`check:copy` 통과. 실존 구단·선수명 금지. 투구 슬라이더 코드 접근 금지.
6. 골든 픽스처 재생성 금지. 테스트 삭제·약화 금지.
7. iOS 테스트는 한 번에 하나, 부팅된 iPhone 17 재사용.

## 1. 보직 지원 선택 (Role Request)

### 1.1 현재 구조
- 스냅샷 `rolePreference: ProRole?`가 이미 있고, 계약 `rolePromise`와 `roleMeeting`/`formCrisis`/`agingCrossroads` 결정이 이를 세팅한다. `planWeek`는 `state.rolePreference ?? trustAssignedRole`로 보직을 정한다(ProCareer.swift:646 부근).
- 즉 "선택"은 있지만 시즌 시작 시 플레이어가 직접 지원하는 입구가 없고, 결정 로테이션에 `roleMeeting`이 걸릴 때만 가능하다.

### 1.2 기능
- **시점**: 스프링캠프(시즌 첫 주간 계획 화면 진입 시, `seasonSegment == .springCamp`이고 아직 이 시즌에 지원하지 않았을 때) 1회. 오프시즌 계약에 `rolePromise`가 있으면 그 시즌은 지원 UI를 건너뛴다(계약 약속이 우선).
- **UI**: 주간 계획 화면 상단 카드 "보직 지원". 선택지 3개: 선발 / 중간(롱릴리프·셋업) / 마무리. 각 카드에 현재 능력 기준 **수락 전망**(유력 / 조건부 / 어려움)과 조건 한 줄(예: "체력 55 이상이면 선발 유력")을 표시한다.
- **판정(결정적, RNG 없음)**: `ProRoleRequestRules.evaluate(state:, requested:) -> ProRoleRequestOutcome`.
  - 선발: stamina ≥ 55 && managerTrust ≥ 45 → 수락. stamina ≥ 48 → 조건부(첫 6주 성과 후 재검토: 6주차에 `roleMeeting` 결정을 강제 삽입해 감독이 확정/철회). 그 외 거절 + 사유.
  - 마무리: stuff ≥ 58 && catcherTrust ≥ 45 → 수락. stuff ≥ 52 → 조건부. 그 외 거절.
  - 중간: 항상 수락.
  - 수락 시 `rolePreference = requested`, 신뢰 변화 없음. 조건부 시 `rolePreference = requested` + 스냅샷 새 필드 `roleRequest: ProRoleRequestState?`(requested, outcome, reviewWeek, season) 기록. 거절 시 `rolePreference` 유지(감독 배정) + 사유 뉴스 1줄 + managerTrust −1.
  - 조건부 재검토(6주차 roleMeeting 강제 삽입)는 주간 결정 슬롯을 하나 소비한다. 그 주에 부상·중요경기가 있으면 다음 결정 주로 미룬다(이 경우만 이월 허용).
- **수치 문턱은 초안**. 구현 후 프로 분포 스모크(`npm run run:pro-career:distribution:smoke`)에서 선발 비율이 극단으로 치우치지 않는지 확인하고 필요하면 조정, 보고서에 기록.
- **분석**: `GameAnalytics.Event.proRoleRequested = "pro_role_requested"` (requested, outcome, season 속성).

### 1.3 수용 기준
1. v9 새 커리어 시즌 1 스프링캠프에서 지원 카드가 보이고, 선발 수락 조건을 만족하는 투수는 선택 후 첫 주 `role == .starter`.
2. 조건부 지원 후 6주차에 roleMeeting이 열리고, 그 시즌 결정 총량은 여전히 최대 7.
3. 계약 rolePromise가 있는 시즌은 카드가 보이지 않는다.
4. v8 저장 로드 시 카드 없음, 시뮬레이션 결과 바이트 동일.
5. 단위 테스트(코어 판정 규칙, planWeek 통합) + iOS 스토어 테스트 + 접근성 ID(`pro.roleRequest.<role>`).

## 2. 용어 카드 (Glossary)

### 2.1 문제
결정·훈련·각성 선택지 설명이 길고, "구위·제구·변화구·야구혼·재능 벽·숙련·QS·WHIP·플래툰" 같은 용어가 설명 없이 쓰인다.

### 2.2 기능
- **효과 한 줄 고정**: `ProSeasonDecisionView` 선택지 카드와 고교/프로 훈련 선택 카드에서, 긴 설명(detail) **위**에 효과 요약 한 줄(`effect.summary` 또는 훈련의 성장 요약)을 항상 노출한다. 문구 밀도 설정이 "간결"이면 detail을 접고 요약만 남긴다. 이미 `immediate-effect` 키와 접기 인프라(SeenContentStore, ProgressiveDisclosure)가 있으니 재사용한다.
- **용어 사전**: `GlossaryCatalog` (packages/ios-layers/BaseballIOSDomain 또는 apps/ios/Sources/Presentation)에 용어 20개 내외를 정의. 각 항목: id, 표시명, 한 줄 정의, (선택) 관련 수치 범위. 문구는 `GameContent.xcstrings` `content.glossary.<id>.name|definition` ko/en/ja.
  - 필수 항목: 구위, 제구, 변화구, 체력, 피로, 감독의 믿음, 포수와의 호흡, 숙련(마스터리), 재능 벽, 야구혼, 각성, 계승, 보직(선발/중간/마무리), QS, ERA, WHIP, K/9, 플래툰, 투수연구소, 시즌 결정.
- **진입점 2개**: (a) 설명 텍스트 안의 용어를 자동 감지해 밑줄/색으로 표시하고 탭하면 하단 시트로 정의를 보여준다(`GlossaryText` 뷰: 문자열을 토큰화해 용어 매칭, 언어별 표시명으로 매칭). (b) 설정 화면 "용어 설명" 항목에서 전체 목록.
- 용어 감지는 ko/en/ja 각 언어의 표시명으로 한다. 한 카드에서 같은 용어가 여러 번 나오면 첫 번째만 강조한다.
- VoiceOver: 강조 용어는 "용어, 탭하면 설명" 힌트.

### 2.3 수용 기준
1. 시즌 결정 화면과 훈련 선택 화면에서 효과 요약이 설명 위에 항상 보인다(UI 테스트 또는 뷰 계약 테스트).
2. 결정 상세 문구에 포함된 "감독의 믿음"을 탭하면 정의 시트가 열린다(iOS 테스트로 GlossaryText 매칭 단위 검증 + 접근성 ID `glossary.term.<id>`).
3. 20개 용어 모두 ko/en/ja 존재, LocalizationCoverageTests에 패리티 테스트 추가.
4. `LayerBoundaryTests`·`LocalizationBoundaryTests` 계속 통과(뷰에서 엔진 직접 호출 금지).

## 3. 게이트
`swift test --package-path packages/simulation-core`, `swift test --package-path packages/ios-layers`, `npm run check`, `npm run run:pro-career:distribution:smoke`, iOS `BaseballIOSTests` 전체. 모두 종료 코드 0.

## 4. 산출물
`docs/PRO_ROLE_REQUEST_AND_GLOSSARY_REPORT_2026-09-02.md`: 변경 파일, 판정 문턱과 조정 내역, 용어 목록, 게이트 원문 결과, 미해결.
