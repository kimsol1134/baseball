# Amplitude 데이터 기반 게임 개선 최종 실행 계획

| 항목 | 값 |
|---|---|
| 문서 ID | `DOC-AMPLITUDE-FINAL-PLAN-2026-08-11` |
| 기준 시각 | 2026-08-11 KST |
| 상태 | **Wave 0만 즉시 구현 가능** |
| 실행 주체 | 저장소를 수정하는 AI 에이전트 |
| 대상 | `apps/ios`, `packages/simulation-core`, Amplitude 프로젝트 `846813` |
| 최종 목표 | 첫날 몰입을 훼손하지 않고, 신뢰 가능한 실험으로 의미 있는 D1 경기 복귀를 개선한다. |
| 우선순위 | 이 문서가 기존 Amplitude·리텐션 구현 계획과 충돌하면 이 문서가 우선한다. 단, 현재 코드는 언제나 문서보다 강한 사실 원본이다. |

이 문서는 AI 에이전트가 그대로 읽고 구현할 수 있는 최종 명세다. 오래된 리뷰의 미완료 항목을 그대로 구현하지 않는다. **Wave 0을 구현·검증·배포한 뒤 데이터 게이트를 통과하기 전에는 Wave 2의 제품 변경을 시작하지 않는다.**

---

## 1. 최종 판단

현재 최선은 새 리텐션 기능이나 온보딩 개편을 더 만드는 것이 아니다.

1. 복귀 실험의 적격 분모와 다음날 복귀 이벤트를 먼저 바로잡는다.
2. Amplitude 안에서 iOS 직접 수집 경로만 식별할 수 있게 만든다.
3. 수정된 한 빌드에서 고유 사용자 기준선을 다시 만든다.
4. 그 뒤에만 기존 개인화 복귀 계획의 효과 또는 정확한 첫 경기 이탈 국면에 따라 한 가지 제품 변경을 선택한다.

이 순서가 필요한 이유는 다음과 같다.

- 최근 7일 활성 473명 중 신규가 472명이다. 현재 지표는 안정된 장기 코호트가 아니라 출시 직후 신규 유입에 지배된다.
- 평균 세션은 22분 5초이고 온보딩 시작 대비 첫 경기 완료는 86.82%다. 첫날 재미가 전반적으로 실패했다는 근거는 없다.
- 의미 있는 D1은 22/235, 9.36%지만 기존 차트는 24시간 `on or after` 정의다. 새 복귀 실험의 KST 다음날 정의와 직접 비교할 수 없다.
- 핵심 이벤트 일부가 Amplitude에서 HTTP API와 iOS SDK 두 수집원으로 보인다. 원시 이벤트 횟수는 중복 가능성을 제거하기 전 제품 사용량으로 쓰면 안 된다.
- 개인화 복귀 실험은 현재 이벤트 67건 수준이고 `return_plan_cold_start`가 관측되지 않았다. 효과 결론을 낼 수 없다.

---

## 2. 이전 제안에 대한 비판적 검토

### 2.1 이미 구현된 항목을 다시 만들 위험이 있었다

다음 개선은 현재 코드에 이미 존재한다.

- 튜토리얼 불펜 `maximumPitches = 8`: `apps/ios/Sources/PitchScenario.swift`
- 첫 선수의 첫 훈련 최소 성장 +1: `packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift`
- 공식 경기가 없는 챕터에서 탈삼진 목표 숨김: `apps/ios/Sources/HighSchoolCareerView.swift`
- 이름 화면 진입 시 키보드 자동 포커스 제거: `apps/ios/Sources/HighSchoolSetupView.swift`

따라서 이 항목을 신규 구현하는 작업은 금지한다. 필요한 것은 회귀 테스트와 새 빌드 단위 효과 측정이다.

### 2.2 38명의 손실이 튜토리얼에서 발생했다고 단정할 수 없다

`first_pitch` 453명에서 `activation_first_game` 415명으로 38명이 줄었지만, 그 사이에는 불펜, 학교 선택, 훈련, 관계, 챕터 전환, 첫 중요 경기 진입과 중단이 모두 포함된다. 이 수치만으로 불펜이 원인이라고 말할 수 없다.

`phase_entered`와 `game_abandoned`가 이미 구현되어 있으므로, 새 빌드에서 국면별 고유 사용자 퍼널을 먼저 만들어야 한다. 온보딩 전체 개편은 금지한다.

### 2.3 Firebase 전송을 제거하면 안 된다

`GameAnalytics.log`가 Firebase와 Amplitude에 함께 보내는 것은 의도된 구조다.

- Firebase: GA4와 광고 전환 측정
- Amplitude: 제품 퍼널과 리텐션 분석

문제는 이중 목적지가 아니라 Firebase 또는 다른 경로가 같은 Amplitude 프로젝트로 다시 유입되는지 여부다. 로컬 코드에서 Firebase를 제거하지 않는다. Amplitude 직접 이벤트를 식별할 속성을 추가하고 외부 데이터 소스를 감사한다.

### 2.4 현재 `return_plan_cold_start`는 D1 앱 복귀를 완전히 측정하지 못한다

현재 이벤트는 앱 프로세스가 새로 시작될 때만 기록된다. 앱이 백그라운드에 살아 있다가 다음 KST 날짜에 다시 활성화되면 이벤트가 발생하지 않는다. 처리 방식이 실험군과 대조군의 앱 실행 패턴에 따라 달라지면 효과 추정도 편향될 수 있다.

따라서 다음날 **cold와 warm을 모두 포함하는** 새 이벤트가 필요하다. 기존 이벤트는 호환용으로만 유지한다.

### 2.5 현재 실험 적격 분모가 활성화 사용자만이라는 보장이 없다

`BaseballApp.logSessionEnd()`는 현재 진행에서 복귀 계획이 없으면 `daily_inning` 기본 계획을 만들고 `return_plan_eligible`을 기록한다. 첫 공식 경기를 끝내지 않은 사용자도 분모에 들어갈 수 있다.

실험 적격은 최소 한 번의 실제 경기 완료 후로 제한해야 한다. 적격 정의가 바뀌므로 기존 `next_action_v1`과 섞지 않고 `next_action_v2`로 새 실험을 시작한다.

### 2.6 이벤트 200건은 통계적 유의성 기준이 아니다

실험 단위는 이벤트나 `plan_receipt`가 아니라 **고유 사용자**다. 같은 사용자가 여러 날 적격 이벤트를 만들 수 있다.

기준 D1이 약 9.4%일 때 +5%p 차이를 일반적인 80% 검정력으로 확인하려면 대략 1,300명 규모가 필요할 수 있다. 고유 사용자 200명은 다음 용도로만 쓴다.

- 계측과 배정이 정상인지 확인
- 매우 큰 차이가 있는지 탐색
- 신뢰구간과 절대 전환을 보고 다음 표본 계획 재계산

200명 시점에 작은 상승을 성공으로 확정하지 않는다.

---

## 3. 데이터 계약과 성공 지표

### 3.1 분석 코호트

모든 정식 판단은 아래 조건을 동시에 만족해야 한다.

```text
distribution = app_store
environment = production
ingestion_origin = ios_sdk_direct
experiment_id = next_action_v2       # 복귀 실험에만 적용
```

빌드 비교 시 한 차트 안에서 서로 다른 `development_rules_version`을 섞지 않는다.

### 3.2 실험 단위

- 배정 단위: 안정 익명 사용자 ID
- 분석 단위: 사용자별 `next_action_v2` 최초 적격 1회
- 연결 키: `plan_receipt`
- 날짜 기준: `Asia/Seoul` 날짜 키
- 반복 적격 이벤트는 운영 진단에는 쓰되 실험 표본 수에는 중복 포함하지 않는다.

### 3.3 핵심 지표

| 역할 | 지표 | 정의 |
|---|---|---|
| Primary | D1 의미 경기 복귀 | 최초 `return_plan_eligible` 다음 KST 날짜에 `game_finished`가 발생한 고유 사용자 비율 |
| Secondary | D1 앱 복귀 | 최초 적격 다음 KST 날짜에 `return_plan_next_day_open(day_gap=1)`이 발생한 고유 사용자 비율 |
| Mechanism | 복귀 후 경기 전환 | `return_plan_next_day_open` 뒤 같은 세션 `game_finished` |
| Guardrail | 카드 닫기 | guided 복귀 사용자 중 `return_plan_dismissed` 고유 사용자 비율 |
| Guardrail | 첫 경기 활성화 | `activation_first_game / onboarding_started` 순서형 고유 사용자 퍼널 |
| Data quality | 필수 속성 충족 | 대상 이벤트에서 필수 속성이 모두 존재하는 비율 |

`return_plan_shown`, `return_plan_tapped`, `reminder_opened`는 이미 앱을 연 사용자에게만 발생하므로 Primary D1 KPI로 사용하지 않는다.

---

## 4. Wave 0 — 즉시 구현할 계측 수정

### 4.1 실행 범위

Wave 0은 제품 밸런스, 보상, 투구 규칙, 화면 수를 바꾸지 않는다. 분석 계약과 테스트만 수정한다.

주요 파일:

- `apps/ios/Sources/GameAnalytics.swift`
- `apps/ios/Sources/DailyReminder.swift`
- `apps/ios/Sources/BaseballApp.swift`
- `apps/ios/Sources/HighSchoolCareerStore.swift`
- `apps/ios/Tests/AnalyticsContextTests.swift`
- `apps/ios/Tests/RetentionHookTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/HighSchoolCareerEngineTests.swift`
- 튜토리얼 시나리오 테스트가 들어갈 기존 iOS 테스트 파일
- `docs/ANALYTICS_TRACKING_PLAN.md`
- `docs/IMPROVEMENT_TRACKER.md`

#### 사전 기준선 blocker

2026-08-11 현재 `npm run check:copy`는 이 문서와 무관한 기존 5건 때문에 실패한다.

- `apps/ios/Sources/DailyInningView.swift`: 주석의 `도전 런`
- `packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift`: 주석의 실존 리그명 2건
- `packages/simulation-core/Sources/SimulationCore/PitchKernelEngine.swift`: 주석의 실존 리그명 2건

Wave 0 에이전트는 동작·상수·계산식을 바꾸지 말고 주석만 독자 세계관 표현으로 교체한 뒤 기준선 검사를 통과시킨다. 이 5건을 Wave 0 변경의 회귀로 오인하지 않으며, 검사 실패를 무시한 채 완료 처리하지도 않는다.

### 4.2 `DailyReminder.Plan`에 실험 ID를 저장한다

현재 `Plan`은 variant는 저장하지만 experiment ID는 저장하지 않고, 분석 속성에서 전역 상수를 사용한다. 앱 업데이트 뒤 옛 v1 영수증이 v2로 잘못 기록될 수 있다.

구현 요구:

1. `DailyReminder.Plan`에 `experimentID: String?`을 추가한다.
2. 옵셔널 필드로 추가하여 기존 저장본 디코딩을 보존한다.
3. `carryingReceipt`와 `carryingExperiment`에서 실험 ID를 함께 보존한다.
4. 새 적격 계획은 `next_action_v2`를 저장한다.
5. 기존 experiment ID가 없는 저장 계획은 분석에서 `next_action_v1`로 분류한다.
6. `analyticsProperties`와 알림 `userInfo`는 전역 상수 대신 계획에 저장된 실험 ID를 사용한다.
7. v2 배정 해시는 `experiment_id + stableID`를 사용하여 v2 안에서 안정적인 50:50을 만든다.

### 4.3 실험 적격을 실제 경기 완료 뒤로 제한한다

순수 함수 또는 작은 정책 타입으로 아래 규칙을 한 곳에 둔다.

```text
eligible = GameAnalytics.completedGameCount() > 0
```

구현 요구:

1. 적격이 아니면 `return_plan_eligible`을 기록하지 않는다.
2. 적격이 아니면 v2 영수증과 variant를 새로 만들지 않는다.
3. `session_ended`는 계속 기록하되 `return_eligible=false`, `experiment_id=none`, `variant=ineligible`을 보낸다.
4. 적격이면 `return_eligible=true`와 동결된 v2 속성을 보낸다.
5. 첫 경기 완료 전 사용자에게 복귀 카드나 알림을 새로 노출하지 않는다. 기존 첫 경기 이후 옵트인 정책은 유지한다.

### 4.4 cold와 warm을 모두 세는 다음날 복귀 이벤트를 추가한다

새 이벤트:

```text
return_plan_next_day_open
```

필수 속성:

| 속성 | 값 |
|---|---|
| `plan_receipt` | 떠날 때 동결된 익명 영수증 |
| `experiment_id` | `next_action_v1` 또는 `next_action_v2` |
| `variant` | `holdout` 또는 `guided` |
| `saved_day_key` | 적격 세션 종료 KST 날짜 |
| `return_day_key` | 앱 활성화 KST 날짜 |
| `day_gap` | 날짜 차이 |
| `launch_type` | `cold` 또는 `warm` |
| `destination`, `reason` | 낮은 카디널리티 값 |
| `development_rules_version` | 동결된 규칙 버전 |

구현 요구:

1. 기존 `coldStartProperties`를 일반화한 `nextDayOpenProperties` 순수 함수를 만든다.
2. `day_gap >= 1`이고 적격 영수증이 있을 때만 값을 반환한다.
3. 앱 최초 활성화에서는 새 이벤트를 `launch_type=cold`로 기록한다.
4. `.background -> .active` 전환에서는 저장 계획을 갱신하기 **전에** 새 이벤트를 `launch_type=warm`으로 기록한다.
5. `logOnce` scope는 `experiment_id|plan_receipt|return_day_key`로 하여 같은 날 cold/warm 중 하나만 남긴다.
6. 기존 `return_plan_cold_start`는 cold 경로에서만 한 버전 이상 계속 보내되 Primary KPI에서 제외한다.

### 4.5 Amplitude 직접 수집원을 식별한다

Firebase 전송은 유지한다.

`GameAnalytics.log`에서 공통 속성을 만든 뒤:

- Firebase payload: 현재 공통 속성 유지
- Amplitude 직접 payload: 아래 두 속성을 추가

```text
ingestion_origin = ios_sdk_direct
event_schema_version = 2
```

이 속성은 Amplitude 직접 전송에만 붙인다. HTTP API 또는 Firebase 재수집 이벤트와 직접 이벤트를 구분하는 감사 기준이다. 무작위 UUID 같은 고카디널리티 속성을 새로 추가하지 않는다.

### 4.6 `game_abandoned`의 분석 가능 속성을 보완한다

현재 속성에 아래를 추가한다.

- `life_number`
- `act_number`
- `phase`
- `development_rules_version`

`first_pitch -> phase_entered -> game_abandoned/activation_first_game`을 첫 회차와 동일 규칙 버전에서 분석할 수 있어야 한다.

### 4.7 이미 구현된 첫 세션 수정의 회귀 테스트를 추가한다

제품 동작은 바꾸지 않고 다음 계약을 테스트한다.

1. 튜토리얼 시나리오의 `maximumPitches == 8`.
2. 튜토리얼 세션은 어떤 합법적 투구 결과에서도 8구를 넘겨 진행하지 않는다.
3. 첫 선수의 첫 비재활 훈련은 여러 대표 시드에서 실제 성장 1 이상이다.
4. 두 번째 훈련과 다음 회차는 0성장 가능성을 유지한다.
5. 공식 경기가 없는 챕터는 `ChapterGoalCard` 노출 정책이 false다. 가능하면 뷰 조건을 순수 함수로 추출해 테스트한다.
6. 첫 이름 화면은 명시적 사용자 탭 전에는 포커스를 요구하지 않는다.

### 4.8 Wave 0 테스트

필수 테스트 케이스:

- 기존 v1 `Plan` JSON 디코딩 성공
- v1 계획이 앱 업데이트 뒤에도 `experiment_id=next_action_v1`로 기록됨
- 신규 v2 계획의 ID와 variant가 저장 왕복 뒤 동일함
- 첫 경기 전 세션 종료는 실험 비적격
- 첫 경기 완료 뒤 세션 종료는 v2 적격
- 같은 KST 날짜에는 next-day-open 없음
- 자정 뒤 cold 활성화에서 1회 발생
- 자정 뒤 warm 활성화에서 1회 발생
- cold 후 warm이 이어져도 같은 영수증·날짜에는 총 1회
- holdout과 guided 모두 next-day-open 기록
- Amplitude 전용 payload에만 `ingestion_origin=ios_sdk_direct`
- `game_abandoned` 필수 속성 존재

---

## 5. Wave 0 수용 기준

아래가 모두 통과해야 Wave 0 완료다.

- 기존 저장본 디코딩 및 복귀 계획 저장 왕복 테스트 통과
- `next_action_v1`과 `next_action_v2`가 섞이지 않음
- 실험 비적격 사용자에게 `return_plan_eligible`이 발생하지 않음
- cold/warm 다음날 복귀를 동일 계약으로 기록
- Firebase 이벤트 전송 유지
- iOS 직접 Amplitude 이벤트에만 수집원 표식 존재
- 튜토리얼·첫 훈련·챕터 목표의 현재 수정이 회귀 테스트로 고정됨
- 실제 구단명, 구단 약칭, 리그명, 선수명, 로고, 유니폼 문양, 슬로건 신규 사용 0건
- 기존 사용자 워킹트리 변경을 되돌리거나 덮어쓰지 않음

공통 검증:

```sh
git status --short
npm run check:copy
npm run check:design-system
npm run check:balance
swift test --package-path packages/simulation-core
cd apps/ios
xcodegen generate
xcodebuild test \
  -project Baseball.xcodeproj \
  -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BaseballIOSTests
```

지정 시뮬레이터가 없으면 `xcrun simctl list devices available`에서 사용 가능한 iPhone을 선택한다.

---

## 6. Wave 1 — 배포 후 Amplitude 운영 작업

이 단계는 Wave 0 코드가 실제 배포된 뒤 수행한다. 코드와 외부 Amplitude 설정을 한 PR의 완료 조건으로 묶지 않는다.

### 6.1 데이터 소스 감사

1. `ingestion_origin=ios_sdk_direct`가 있는 이벤트를 정식 분석의 기준으로 고정한다.
2. HTTP API 이벤트의 설정 출처를 Amplitude Data Sources에서 확인한다.
3. Firebase/GA4 import가 동일 프로젝트에 같은 이벤트를 재전송한다면 import를 중단하거나 별도 소스로 격리한다.
4. 원인을 확인하기 전 이벤트 횟수 차이를 중복률로 단정하지 않는다.
5. `game_finished`의 direct 이벤트에서 `mode`, `build`, `distribution`, `environment`, `development_rules_version` 충족률을 계산한다.

### 6.2 Amplitude 거버넌스

- 42개 이벤트를 tracking plan에 수용하거나 명시적으로 deprecated 처리한다.
- 각 이벤트에 owner, category, description을 지정한다.
- 안정된 이벤트와 속성의 snake_case 명명 규칙을 등록한다.
- 핵심 이벤트의 필수 속성 누락 경보를 만든다.
- 목표: Unexpected 이벤트 10% 미만, 핵심 필수 속성 충족 99% 이상.

### 6.3 필수 차트

1. **Activation v2**
   - 고유 사용자 순서형 퍼널
   - `onboarding_started -> onboarding_completed -> first_pitch -> activation_first_game`
   - prod + direct + build 필터

2. **First-game path**
   - 첫 회차만 사용
   - `first_pitch` 뒤 `phase_entered.phase`와 `game_abandoned`를 국면별로 분해
   - 이벤트 횟수가 아니라 고유 사용자와 마지막 도달 단계 사용

3. **Return experiment v2**
   - 사용자별 최초 `return_plan_eligible`
   - variant별 `return_plan_next_day_open(day_gap=1)`
   - 이어지는 같은 KST 날짜 `game_finished`
   - 절대 사용자 수, 분모, 전환율, 차이의 신뢰구간을 함께 표시

4. **Ingestion audit**
   - event name × Amplitude source × `ingestion_origin`
   - build별 필수 속성 충족률

---

## 7. Wave 2 진입 게이트 — 데이터가 쌓일 때까지 제품 변경 금지

아래 조건을 모두 만족하기 전에는 새 리텐션 장치, 알림 강화, 온보딩 재설계를 구현하지 않는다.

- Wave 0 포함 빌드가 정식 활성 사용자의 80% 이상
- 최소 3개의 완결된 KST 날짜
- `next_action_v2` 최초 적격 고유 사용자 200명 이상
- variant별 최초 적격 사용자 비중이 40~60% 범위
- `return_plan_next_day_open` 필수 속성 충족 99% 이상
- direct `game_finished`의 `mode` 충족 99% 이상
- HTTP/SDK 혼합 수집원의 처리 방침이 문서화됨
- D1 결과를 이벤트 건수가 아닌 최초 적격 고유 사용자로 재계산함

200명은 효과 확정 게이트가 아니라 **계측 검토 게이트**다. 그 시점의 실제 기준율과 목표 최소 효과(MDE)를 사용해 다음 표본 수를 다시 계산한다.

---

## 8. Wave 2 의사결정 트리

### 8.1 guided가 의미 있는 경기 복귀를 개선한 경우

조건:

- guided의 D1 `game_finished` 절대 전환이 holdout보다 높음
- 차이의 신뢰구간과 표본 수를 함께 검토함
- 카드 닫기·첫 경기 활성화 가드레일 악화가 없음

행동:

1. 표본 계획까지 충족하고 하한이 0보다 높으면 guided를 기본값으로 확대한다.
2. 알림 허용을 강제하거나 빈도를 늘리지 않는다.
3. 가장 높은 `reason`이 아니라 **reason별 전환율과 분모**를 함께 보고 문구를 다듬는다.

### 8.2 다음날 앱은 열지만 경기를 하지 않는 경우

신호:

- `return_plan_next_day_open` 상승
- 같은 날짜 `game_finished` 개선 없음

행동:

1. 알림 횟수를 늘리지 않는다.
2. 딥 링크 목적지, 이어하기 CTA, 저장 복구 실패를 먼저 점검한다.
3. `destination`별 open -> game 퍼널에서 가장 큰 단일 마찰만 수정한다.

### 8.3 카드 탭 사용자는 잘 플레이하지만 전체 D1은 개선되지 않는 경우

해석:

카드가 효과가 있다는 뜻이 아니라, 원래 복귀한 적극 사용자만 탭했을 가능성이 높다.

행동:

- 카드 탭률을 인과 성과로 사용하지 않는다.
- holdout/guided 최초 적격 비교가 개선되지 않으면 개인화 노출 확대를 중단한다.

### 8.4 guided와 holdout 차이가 없거나 악화된 경우

행동:

1. 알림 강도를 올리지 않는다.
2. 복귀 카드의 추가 변형을 연속 실험하지 않는다.
3. 다음 독립 실험은 앱 밖 알림이 아니라 **세션 종료 시 사용자가 직접 고른 하나의 미완 목표**로 한다.
4. 기존 `next_run_intent_saved/applied`를 활용하고 새 평행 시스템을 만들지 않는다.
5. 한 빌드에는 하나의 제품 가설만 노출한다.

### 8.5 첫 경기 전환이 특정 국면에서만 낮은 경우

행동:

1. `phase_entered` 퍼널에서 직전 단계 대비 손실 5%p 이상인 첫 국면 하나만 선택한다.
2. 해당 국면의 탭 수·필수 스크롤·중단 이벤트를 재현한다.
3. 한 번에 화면 하나만 단순화한다.
4. 이미 구현된 8구 상한, 첫 훈련 +1, 목표 숨김, 키보드 비활성화를 다시 수정하지 않는다.
5. 수정 후 `activation_first_game`과 D1 가드레일을 함께 본다.

### 8.6 첫 경기 경로에 5%p 이상의 단일 병목이 없는 경우

온보딩을 더 줄이지 않는다. 현재 첫 경기 활성화 86.82%를 보존하고 리텐션 실험에 집중한다.

---

## 9. 명시적 비목표

이 계획에서 구현하지 않는다.

- 에너지, 강제 대기, 출석 보상 압박, 연속 기록 소멸
- 알림 기본 활성화 또는 반복 알림 확대
- Firebase Analytics 제거
- 새 공유 기능 또는 바이럴 보상
- 데일리 이닝 대규모 확장
- 프로 콘텐츠 추가
- 온보딩 전체 재작성
- 이벤트 수를 고유 사용자 수처럼 사용하는 대시보드
- 200명 시점의 통계적 유의성 선언
- 실제 프로 구단명·약칭·리그명·선수명·로고·유니폼·슬로건 사용

---

## 10. AI 에이전트 실행 규칙

1. 시작 시 `git status --short`를 확인하고 기존 변경을 사용자 작업으로 취급한다.
2. 현재 코드를 사실의 원본으로 삼고 오래된 문서만 보고 기능을 다시 만들지 않는다.
3. Wave 0 외 작업은 사용자가 명시적으로 다음 Wave를 요청하거나 해당 데이터 게이트 산출물이 존재할 때만 수행한다.
4. 이벤트 이름 변경 대신 새 이벤트 추가와 호환 기간을 사용한다.
5. 저장 필드는 옵셔널로 추가하고 구저장본 디코딩 테스트를 먼저 쓴다.
6. 실험 ID, variant, 영수증, 규칙 버전은 적격 순간에 동결한다.
7. 이름, 자유 문구, 원시 시드, `careerID`를 분석으로 보내지 않는다.
8. 분석 지표는 정식 prod + direct 코호트만 사용한다.
9. 테스트 실패나 Xcode 프로젝트 재생성 diff를 숨기지 않는다.
10. 완료 시 아래를 보고한다.
    - 수정 파일
    - 테스트 명령과 결과
    - 저장 호환성 확인
    - 새 이벤트와 속성 계약
    - 아직 수동으로 해야 하는 Amplitude 설정
    - 다음 Wave 진입 여부: 기본값은 `아니오`

---

## 11. 근거와 추적 가능한 산출물

- `artifacts/analysis/amplitude-2026-08-11/amplitude_observations.csv`
- `artifacts/analysis/amplitude-2026-08-11/amplitude_game_user_analysis.ipynb`
- `artifacts/analysis/amplitude-2026-08-11/report_artifact.json`
- `artifacts/analysis/amplitude-2026-08-11/report_source_notes.md`
- `docs/ANALYTICS_TRACKING_PLAN.md`
- `docs/IMPROVEMENT_TRACKER.md`
- `docs/reviews/review-first-session.md`
- `docs/reviews/review-retention.md`
- `apps/ios/Sources/GameAnalytics.swift`
- `apps/ios/Sources/DailyReminder.swift`
- `apps/ios/Sources/BaseballApp.swift`

## 12. 최종 완료 정의

이 계획의 완료는 기능을 많이 추가하는 것이 아니다.

1. 복귀 실험의 분모가 실제 활성화 사용자로 고정된다.
2. cold와 warm 다음날 복귀가 모두 측정된다.
3. v1과 v2 실험이 저장·분석에서 섞이지 않는다.
4. Amplitude 직접 이벤트를 다른 수집원과 분리할 수 있다.
5. 기존 첫 세션 개선이 회귀 테스트로 보호된다.
6. 수정 빌드의 고유 사용자 데이터가 게이트를 통과한다.
7. 그 데이터가 지목한 단 하나의 제품 병목만 다음 실험으로 선택된다.

이 일곱 조건이 충족되기 전에는 “게임 개선이 끝났다”거나 “복귀 기능이 D1을 올렸다”고 기록하지 않는다.
