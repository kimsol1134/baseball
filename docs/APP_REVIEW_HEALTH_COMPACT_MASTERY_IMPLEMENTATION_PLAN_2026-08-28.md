# 앱 리뷰 통합 개선 — 부상 설명·반복 문구 접기·1–100 능력과 무한 숙련 구현 계획

| 항목 | 값 |
|---|---|
| 문서 ID | `DOC-APP-REVIEW-HEALTH-COMPACT-MASTERY-2026-08-28` |
| 상태 | **구현·시뮬레이터·실기기 검증 완료 · 1.2.4 build 62 심사 대기 중** |
| 기준일 | 2026-08-28 KST |
| 실행 주체 | 이 저장소를 수정하는 AI 에이전트 |
| 출발점 | iOS 1.2.3 대한민국 리뷰 `재밌지만 한계가 명확함` |
| 1차 출시 범위 | 공유 Swift 코어 + iOS 앱 + 저장/RPC/스키마 |
| 패리티 범위 | Windows와 Android/Unity는 같은 규칙·표시 계약까지 완료 |
| 핵심 결과 | 설명 가능한 부상, 다시 읽지 않아도 되는 UI, 1–100 기본 능력, 100 이후 무한 숙련 |

이 문서는 아래 리뷰를 제품과 코드 수준에서 모두 해결하기 위한 최종 구현 명세다.

> 부상 이유와 대처를 알 수 없다. 피로를 낮게 유지해도 부상당한다. 반복되는 긴 글을 다시
> 읽고 싶지 않다. 능력치가 80에서 막혀 아쉽다.

채팅의 요약보다 **이 문서가 우선**이다. 구현 중 기술적 사실이 달라졌다면 코드를 따르되,
제품 결정을 임의로 바꾸지 말고 §19 결정 기록에 차이와 이유를 남긴다.

구현을 시작하기 전에 다음을 순서대로 읽는다.

1. 루트 `AGENTS.md` 전체.
2. 이 문서 전체.
3. `packages/simulation-core/Sources/SimulationCore/Domain.swift`의 `PitcherSnapshot`.
4. `PitcherDevelopmentRules.swift`, `PitchAbilityRules.swift`.
5. `HighSchoolCareer.swift`의 훈련·팔 위험·부상 처리.
6. `ProCareer.swift`의 `planWeek`, `resolveDevelopment`, `progressSummary` 호출 경계.
7. `apps/ios/Sources/AbilityGaugeView.swift`, `ProWeeklyPlanView.swift`, `MobileCareerStore.swift`, `CareerFlowView.swift`, `AppShell.swift`.
8. Windows `ratingScale.ts`, `AbilityGauge.tsx`, `ProCareerView.tsx`.
9. Android/Unity `PitcherSnapshot`, `ProCareerEngine`, `BaseballComponents.AbilityGauge`와 관련 화면 투영 코드.

현재 worktree에는 사용자 작업이 많이 있다. `reset`, `checkout`, `stash`, 대량 포맷, 관련 없는
파일 삭제를 하지 않는다. 수정 전 각 대상 파일의 `git diff`를 읽고 기존 변경을 보존한다.

---

## 0. 한 줄 결론

사용자에게는 익숙하지 않은 20–80 숫자를 더 이상 보여 주지 않는다. 기본 능력은 **1–100**으로
보여 주고, 100 이후에는 **구위·제구·변화구·체력 숙련 레벨이 사실상 무제한으로 계속 오른다.**
내부 투구 시뮬레이션은 검증된 20–80 저장 계약을 유지하며 숙련 효과는 점감하는 별도 보정으로
적용한다.

동시에 저피로 상태의 무작위 `과부하` 부상을 제거하고, 부상이 생긴 순간 원인·근거·회복 기간·
다음 행동을 강제로 보여 준다. 반복 설명은 처음 한 번만 펼치고 이후에는 핵심 수치만 남긴다.

---

## 1. 현재 코드에서 확인된 문제

### 1.1 프로 부상은 저피로에서도 매주 최소 2%다

`ProCareer.swift`의 현재 공식은 다음과 같다.

```swift
injuryRoll < max(2, fatiguePressure - 72)
```

피로 압력이 낮아도 매주 2%가 남는다. 단순 독립 계산으로 24주 동안 한 번 이상 다칠 가능성은
약 38%다. 그런데 뉴스 문구는 무조건 `과부하로 N주 부상자 명단`이다. 피로를 관리한 사용자는
자신의 선택과 결과를 연결할 수 없고, 시스템이 거짓 원인을 말한다고 느낀다.

### 1.2 부상 데이터는 있지만 결과 UI 우선순위가 없다

- `ProCareer.swift`는 부상 문구를 문자열 뉴스 배열에 넣는다.
- 성장, 구종 학습, 구간 전환, 중요 경기 문구가 뒤에서 다시 배열 앞에 삽입된다.
- `AppShell.swift`의 프로 홈은 `state.news.prefix(3)`만 보여 준다.
- `MobileCareerStore.progressSummary`에는 부상 변화가 없다.
- 구간 자동 진행은 부상이 나면 멈추지만, 멈춘 이유를 결과 배너가 말하지 않는다.

따라서 상태에는 `injuryWeeks > 0`이 생겼는데 사용자가 본 결과에는 부상 문장이 없는 경로가
존재한다.

### 1.3 고교는 인과가 있지만 설명이 흩어져 있다

고교 부상은 프로와 다르다. 투구 수와 피로로 `armRisk`가 쌓이고, 경고 이후 `참고 던진다`를
선택했을 때 임계를 넘으면 결정론적으로 다친다. 규칙 자체는 선택 가능하지만 다음 정보가 한곳에
모이지 않는다.

- 이번 경기에서 위험이 얼마나 올랐는지.
- 원인이 투구 수인지, 피로인지, 강행 선택인지.
- 지금 회복 훈련이 왜 필요한지.
- 몇 번 회복해야 정상으로 돌아오는지.

### 1.4 반복 화면은 같은 설명을 매주 다시 펼친다

프로 주간 화면은 매주 청사진 설명, 현재 위상 설명, 여섯 계획의 효과와 비용을 전부 노출한다.
일부 화면에는 접기 버튼이 있지만 `@State`뿐이라 뷰가 다시 만들어지면 본 여부를 기억하지 못한다.
프로 코어 루프가 20시즌이면 같은 종류의 결정을 수백 번 반복하므로, 처음에는 친절했던 설명이
후반에는 스크롤 비용이 된다.

### 1.5 80은 실제 하드캡인데 화면은 `한계 없음`이라고 말한다

- `PitcherGrowthRules.grow`는 주요 능력과 구종 프로필을 80으로 제한한다.
- `AbilityGaugeView`의 S재능은 사용자에게 `한계 없음`이라고 표시한다.
- 프로 능력이 80이어도 성장 게이지는 6틱을 소비한다.
- 게이지가 끝나면 실제 주요 능력이 그대로여도 `구위 +1` 같은 뉴스 라벨을 추가한다.

이 문제는 단순한 숫자 취향이 아니다. 게임이 한계를 숨기고, 완료되지 않은 성장을 완료됐다고
말하는 피드백 결함이다.

---

## 2. 반드시 지킬 제품 원칙

### 2.1 선택과 결과를 연결한다

- `과부하` 부상은 실제 과부하 조건에서만 발생한다.
- 다친 순간에는 뉴스 목록을 찾지 않아도 원인과 대처를 알 수 있어야 한다.
- 위험이 있는 선택은 실행 전에 최소한 `낮음/주의/높음`으로 예고한다.
- 위험 숫자를 숨겨 난이도를 만드는 방식을 쓰지 않는다.

### 2.2 설명을 줄여도 중요한 정보는 숨기지 않는다

자동 접기 대상은 반복되는 시스템 설명과 정적 도움말이다.

다음은 절대로 자동으로 접지 않는다.

- 새 부상과 회복 완료.
- 처음 발생한 사건과 되돌릴 수 없는 선택.
- 직전 행동의 결과와 비용.
- 새로 해금된 구종, 숙련, 각성, 역할, 소속 변화.
- 저장 실패나 진행 복구 안내.

### 2.3 성장은 무한하지만 경기 성능은 폭주하지 않는다

- 기본 능력 100 이후에도 훈련은 계속 의미가 있다.
- 숙련 레벨 저장에는 플레이상 도달 가능한 하드캡을 두지 않는다.
- 실전 보정은 점감하며 기존 투구 선택과 슬라이더 조작을 압도하지 않는다.
- 숙련이 높아도 나쁜 코스·잘못된 구종·나쁜 릴리스가 자동으로 좋은 결과가 되지 않는다.

### 2.4 내부 20–80 계약은 유지한다

- `PitcherSnapshot.stuff/command/movement/stamina`의 저장·RPC 범위는 20–80을 유지한다.
- 기존 타자, 수비, 구종 프로필 검증 범위를 한꺼번에 1–100으로 바꾸지 않는다.
- 사용자용 1–100 숫자는 단일 변환 함수로 만든 표현 계층이다.
- 밸런스가 검증되기 전 기존 투구 커널의 모든 계수를 재작성하지 않는다.

### 2.5 기존 저장을 잃지 않는다

- 숙련 필드가 없는 저장은 숙련 0으로 읽는다.
- 능력 80인 기존 선수는 업데이트 직후 다음 유효 성장부터 숙련을 얻는다.
- 기존 80을 100으로 **표시만 변환**한다. 저장 수치를 파괴적으로 다시 쓰지 않는다.
- iCloud 충돌 리비전과 삭제 묘비 규칙을 유지한다.

### 2.6 프로젝트 불변 규칙을 지킨다

- 실존 프로 구단명·약칭·리그명·선수명·로고·문양·슬로건을 넣지 않는다.
- 투구 슬라이더를 기본 직접 투구 조작으로 유지한다.
- iOS 공개 바이너리는 한국어·영어·일본어를 모두 포함한다.

---

## 3. 최종 사용자 경험

### 3.1 기본 능력 표시

사용자 화면은 다음처럼 표시한다.

```text
구위 87
프로 최상급
```

내부 값이 80이면:

```text
구위 100
기본 능력 완성
강속구 숙련 Lv.14
다음 숙련 4 / 6
```

사용자용 변환은 모든 클라이언트에서 동일하다.

```text
displayRating = clamp(round((internalRating - 20) * 100 / 60), 1, 100)
```

정수 구현은 부동소수점 차이를 피한다.

```swift
max(1, min(100, ((internalRating - 20) * 100 + 30) / 60))
```

고정점:

| 내부 | 사용자 표시 |
|---:|---:|
| 20 | 1 |
| 35 | 25 |
| 50 | 50 |
| 65 | 75 |
| 80 | 100 |

`before → after`, 재능 한계, 성장 결과, 접근성 문구도 반드시 같은 변환을 사용한다. 사용자 문구에
`20–80`을 설명하거나 노출하지 않는다. 내부 개발 문서와 디버그 화면만 예외다.

### 3.2 100 이후 숙련

네 기본 숙련을 둔다.

| 기본 능력 | 숙련 표시명 | 실전 의미 |
|---|---|---|
| 구위 | 강속구 숙련 | 구속·헛스윙 기여를 소폭 보정 |
| 제구 | 코스 숙련 | 목표 오차와 커맨드 기여를 소폭 보정 |
| 변화구 | 결정구 숙련 | 움직임·헛스윙·약한 타구 기여를 소폭 보정 |
| 체력 | 이닝 숙련 | 유효 피로와 후반 저하를 소폭 보정 |

숙련은 해당 주요 능력이 내부 80에 닿은 뒤 들어오는 성장 포인트로 오른다.

- 현재 79에서 성장 +2: 기본 능력 80, 숙련 +1.
- 현재 80에서 성장 +1: 숙련 +1.
- 현재 80에서 프로 성장 게이지 6틱 완료: 숙련 +1.
- 프로필 수치가 아직 80 미만이면 기존 프로필 성장도 함께 적용한다.
- 노화로 기본 능력이 80 아래로 내려가도 이미 얻은 숙련은 사라지지 않는다.
- 새 선수에게 이전 선수의 숙련 레벨을 통째로 넘기지 않는다. 기존 기억·유산·계보가 환생 보상을
  담당한다.

프로 계획 카드 예시:

```text
결정구를 더 날카롭게
변화구 100 · 결정구 숙련 Lv.8
다음 숙련 2/6 · 예상 피로 +8 · 부상 위험 낮음
```

### 3.3 숙련의 점감 효과

숙련 레벨은 계속 증가하지만 실전 보정은 다음 공용 함수로 점감한다.

```text
bonusPermille(level) = 120 * level / (level + 24)
```

- 레벨 0: 0‰.
- 레벨 5: 약 20‰.
- 레벨 10: 약 35‰.
- 레벨 25: 약 61‰.
- 레벨 50: 약 81‰.
- 레벨 100: 약 96‰.
- 무한히 성장해도 120‰에 점근한다.

이 값은 능력 전체를 12% 강화하지 않는다. 해당 능력이 결과 공식에 기여하는 **부분**만 보정한다.
구현은 `MasteryEffectRules` 한곳을 통해 다음처럼 적용한다.

1. 구위: 포심 구속 기여와 구위 기반 헛스윙 기여.
2. 제구: 목표 오차·커맨드 계산에서 제구가 담당하는 기여.
3. 변화구: 변화·헛스윙·약한 타구 계산에서 변화구가 담당하는 기여.
4. 체력: `effectiveFatigue`에서 체력이 줄이는 부분.

저장된 20–80 수치나 구종 프로필을 숙련 보정 때문에 80 초과로 쓰지 않는다. 계산 순간에만
고정점 보정을 적용한다. 첫 구현에서 `bonusPermille` 상한 120을 넘기지 않는다.

### 3.4 숙련 피드백

숙련이 오르면 일반 `능력 +1`과 구분한다.

```text
강속구 숙련 Lv.14 → Lv.15
100 이후에도 반복한 동작이 실전 감각으로 남았습니다.
```

- 레벨 1, 5, 10, 이후 10단위는 전용 마일스톤 연출을 사용한다.
- 그 외 레벨은 훈련 결과 카드의 한 행으로 표시한다.
- 실제 기본 능력이 오르지 않았는데 `구위 +1`이라고 표시하지 않는다.
- 숙련과 구종 프로필이 함께 올랐다면 두 결과를 각각 표시한다.

### 3.5 프로 부상 전 안내

주간 계획 카드에는 선택 후 예상되는 부상 위험 밴드를 표시한다.

| 예상 유효 피로 | 밴드 | 표시 |
|---:|---|---|
| 0–72 | low | 낮음 |
| 73–82 | caution | 주의 |
| 83–100 | high | 높음 |

실제 주간 투구 수는 시뮬레이션 결과이므로 거짓 단일 확률을 약속하지 않는다. 공용
`ProWeekHealthForecast`가 역할별 예상 투구 범위, 선택한 계획의 훈련 부하, 현재 체력을 이용해
`낮음/주의/높음`과 짧은 이유를 반환한다.

예:

```text
부상 위험 주의
현재 피로 64에 강한 구위 훈련과 선발 등판 부담이 더해질 수 있습니다.
```

### 3.6 프로 부상 발생 결과

부상 발생 주에는 일반 진행 배너보다 먼저 다음 카드를 보여 준다.

```text
팔 과부하 · 3주 회복

이번 주 선발 등판과 구위 훈련 뒤 유효 피로가 86까지 올랐습니다.
회복하는 동안 공식 경기에 나가지 않으며, 매주 피로가 감소합니다.

다음 행동: 회복 일정을 진행하세요.
```

필수 필드:

- 원인 `overload`.
- 시즌과 주차.
- 선택한 주간 계획.
- 발생 직전 원피로.
- 체력을 반영한 유효 피로.
- 그 주 실제 투구 수.
- 최초 회복 주수.
- 사용자가 지금 할 수 있는 행동.

카드는 앱 재실행 후에도 한 번은 복원되어야 한다. 뉴스 배열 순서에 의존하지 않는다.

### 3.7 프로 부상 공식

저피로에서 발생하던 최소 2%를 제거한다.

```swift
let injuryChancePercent = max(0, fatiguePressure - 72)
let generatedInjury = !recovering && injuryRoll < injuryChancePercent
    ? 2 + rng.nextInt(upperBound: 4)
    : max(0, state.injuryWeeks - 1)
```

v1에서는 `돌발 부상`을 새로 추가하지 않는다. 사용자 선택과 무관한 부상을 다시 넣으려면 별도
제품 결정, 별도 원인 문구, 보호 장치, 분포 검증이 필요하다. `과부하`라는 이름으로 베이스라인
랜덤 부상을 숨기는 것은 금지한다.

### 3.8 고교 팔 상태 결과

고교 확률·임계 공식은 이번 작업에서 바꾸지 않는다. 대신 중요 경기 종료 결과에 다음을 묶는다.

```text
팔 부담 +18 · 상태 주의
원인: 31구 투구, 경기 전 피로 61
권장: 다음 훈련은 회복
```

경고 뒤 `참고 던진다`로 부상당하면:

```text
팔 부상 · 재활 2회
원인: 팔 상태 경고 뒤 등판 강행
다음 행동: 재활 훈련 2회를 마쳐야 정상 훈련으로 돌아옵니다.
```

`armRisk` 원시 숫자는 설정의 상세 정보 또는 접근성 설명에는 제공할 수 있지만 기본 UI는
정상·주의·경고·회복 중과 변화량을 우선한다.

### 3.9 반복 설명 자동 접기

설명 밀도 설정은 세 단계다.

| 설정 | 동작 |
|---|---|
| 자동 | 처음 보는 설명은 펼침, 다음 방문부터 접힘. 기본값. |
| 항상 자세히 | 반복 설명도 항상 펼침. |
| 간단히 | 처음부터 핵심 수치만 표시. 단, 중요 알림은 항상 펼침. |

첫 자동 접기 대상:

1. 프로 주간 `투수 청사진`의 정적 강점·약점 설명.
2. 프로 주간 `현재 위상`의 정적 도움말.
3. 여섯 주간 계획의 반복 효과·비용 문장.
4. 프로 커리어 방향 카드의 영구결번·재정 설명 힌트.
5. 고교 `이번 삶의 바람` 상세 설명.
6. 이미 본 훈련 시스템 도움말과 구종 학습 규칙 설명.

각 카드의 접힌 상태에도 다음 정보는 남는다.

- 제목.
- 현재 수치.
- 직전 대비 변화.
- 선택 시 직접 비용.
- 부상 위험 밴드.
- 다음 성장 또는 숙련까지 남은 틱.
- 추천 여부.

안정적인 콘텐츠 ID 예:

```text
pro.weekly.blueprint.v1
pro.weekly.standing.v1
pro.weekly.plan.develop_stuff.v2
pro.weekly.plan.recover.v2
pro.direction.legacy-hint.v1
high-school.wind.<wind-id>.v1
high-school.pitch-learning.help.v1
```

문구의 의미가 바뀌면 ID 버전을 올려 한 번 다시 펼친다. 번역 언어는 ID에 넣지 않는다. 사용자가
언어를 바꿨다는 이유로 이미 이해한 시스템 도움말 전체를 다시 펼치지 않는다.

---

## 4. 데이터 모델과 계약

### 4.1 `AbilityMasterySnapshot`

파일: `packages/simulation-core/Sources/SimulationCore/Domain.swift`

```swift
public struct AbilityMasterySnapshot: Codable, Equatable, Sendable {
    public let stuff: Int
    public let command: Int
    public let movement: Int
    public let stamina: Int
}
```

규칙:

- 모든 값은 0 이상.
- 저장 타입은 Swift/C#/TypeScript 공통 안전 범위를 위해 부호 있는 32비트 범위 안에서 포화
  증가한다. `2_147_483_647`은 기술적 저장 한계이며 게임 디자인 하드캡으로 노출하지 않는다.
- 기본 생성자는 네 값을 0으로 둔다.
- 능력·계획별 조회와 불변 갱신 헬퍼를 제공한다.

### 4.2 `PitcherSnapshot.mastery`

`PitcherSnapshot`에 다음 옵셔널 필드를 추가한다.

```swift
public let mastery: AbilityMasterySnapshot?
```

- 구저장은 `nil`을 `.zero`로 읽는다.
- 신규 선수는 `mastery: .zero`를 명시한다.
- `CodingKeys`, 수동 `init(from:)`, 모든 초기화 경로, `Equatable`, C# 및 TypeScript 계약을 갱신한다.
- 기존 편의 생성자는 기본 인자 `mastery: nil`을 가져 대량 호출부를 한 번에 깨지 않게 한다.
- 고교에서 프로로 전달될 때 `PitcherSnapshot` 자체가 넘어가므로 숙련도 함께 전달된다.
- 환생 신규 선수 생성은 새 `PitcherSnapshot`을 만들기 때문에 이전 숙련을 자동 복사하지 않는다.

### 4.3 성장 영수증

기존 `PitcherGrowthRules.grow`는 최종 스냅숏만 반환해 실제 성장과 캡 소실을 구분할 수 없다.
새 공용 API를 추가한다.

```swift
public struct PitcherAdvancementReceipt: Equatable, Sendable {
    public let pitcher: PitcherSnapshot
    public let ability: TalentAbility
    public let baseBefore: Int
    public let baseAfter: Int
    public let masteryBefore: Int
    public let masteryAfter: Int
    public let profileChanges: [PitchProfileAdvancement]
}

public enum PitcherAdvancementRules {
    public static func advance(...) -> PitcherAdvancementReceipt
}
```

규칙:

1. 기본 능력은 최대 80까지 오른다.
2. 80을 넘는 성장 포인트는 같은 능력 숙련으로 간다.
3. 현재가 이미 80이면 모든 유효 성장 포인트가 숙련으로 간다.
4. 프로필 성장은 기존 규칙과 상한을 그대로 적용한다.
5. `grow`는 호환 래퍼로 남기되 내부적으로 `advance(...).pitcher`를 반환한다.
6. UI와 뉴스는 영수증의 실제 before/after만 사용한다.

모든 양의 성장 경로를 감사한다.

- 고교 훈련.
- 고교 관계 성장.
- 고교 중요 경기 성장.
- 각성·계승으로 적용되는 성장.
- 프로 주간 성장.
- 프로 시즌 결정의 양의 능력 효과.
- 구종 학습 완료 보정.

각 경로가 80에서 포인트를 조용히 버리지 않아야 한다. 다만 시작 프리셋 보정이나 밸런스
마이그레이션처럼 `성장 사건`이 아닌 정규화 경로는 숙련을 만들지 않는다.

### 4.4 숙련 효과 규칙

새 파일을 만든다.

```text
packages/simulation-core/Sources/SimulationCore/MasteryEffectRules.swift
```

한 파일이 다음의 단일 출처다.

- `bonusPermille(level:)`.
- 능력별 표시명과 마일스톤 판정.
- 고정점 곱셈과 반올림.
- 오버플로 방지.
- 투구 커널에서 사용할 능력별 보정 헬퍼.

UI 파일이나 각 엔진에 숙련 수식을 복사하지 않는다. C# 포트는 같은 골든 픽스처를 통과해야
하고 TypeScript는 표시 함수만 동일 계약으로 구현한다.

### 4.5 부상 이벤트

문자열 뉴스를 구조화된 결과로 대신할 수 있도록 추가한다.

```swift
public enum ProInjuryCause: String, Codable, Sendable {
    case overload
}

public struct ProInjuryEventSnapshot: Codable, Equatable, Sendable {
    public let cause: ProInjuryCause
    public let season: Int
    public let week: Int
    public let plan: ProWeekPlan
    public let rawFatigue: Int
    public let effectiveFatigue: Int
    public let pitches: Int
    public let recoveryWeeks: Int
}
```

`ProCareerResult`에 다음 옵셔널 필드를 추가한다.

```swift
public let injuryEvent: ProInjuryEventSnapshot?
```

- 부상 시작 결과에만 값이 있다.
- 회복 중 다음 주에는 새 발생 이벤트를 반복 생성하지 않는다.
- 결과 레코드가 저장되므로 앱 재실행 뒤에도 최초 발생 결과를 복원할 수 있다.
- `events` 문자열 배열은 분석·호환용으로 유지하며 부상 발생 시 `pro_injury_started`를 추가한다.
- 뉴스 문구도 기록 탭을 위해 유지하지만 중요 UI는 뉴스 파싱에 의존하지 않는다.

### 4.6 고교 건강 결과

고교는 기존 `HighSchoolCareerResult` 이벤트 구조를 우선 재사용한다. 필요한 원인 필드가 없다면
`HighSchoolArmHealthReceipt`를 옵셔널로 추가한다.

필드:

- `riskBefore`, `riskAfter`.
- `healthBefore`, `healthAfter`.
- `pitches`, `fatigueBefore`.
- `cause`: `outing_load`, `push_through`, `rehab`.
- `recoveryRemaining`.

고교 뉴스 문자열을 파싱해 원인을 복원하지 않는다.

### 4.7 규칙과 저장 버전

- `ProCareerEngine.currentRulesVersion`을 다음 버전으로 올린다.
- 고교에는 `growthRulesVersion` 옵셔널 필드를 추가하거나, 기존 `balanceVersion`과 분리된 명시적
  성장 규칙 버전을 둔다. 투구 물리 버전과 숙련 도입을 섞지 않는 쪽을 우선한다.
- iOS 프로 저장 스키마를 5로 올린다.
- iOS 고교 저장 스키마를 4로 올린다.
- `schemas/pro-career.schema.json`, `schemas/high-school-career.schema.json`, RPC 타입과 픽스처를 갱신한다.
- 구버전 앱이 더 높은 스키마 저장을 덮어쓰지 못하게 기존 raw schema downgrade gate를 유지한다.

구저장 마이그레이션:

| 필드 | 구저장 해석 |
|---|---|
| `pitcher.mastery` | 네 능력 모두 0 |
| `result.injuryEvent` | nil |
| 설명 본 기록 | 없음. 첫 방문에서 한 번 펼침 |
| 내부 능력 | 기존 20–80 값 그대로 |
| 사용자 표시 | 로드 직후 1–100 변환 |

---

## 5. iOS 표현 계층

### 5.1 `AbilityDisplayScale`

현재 `AbilityGaugeView.swift`의 `RatingScale`을 사용자 표시 계약으로 교체한다. 이름은
`AbilityDisplayScale`로 바꿔 내부 20–80 규칙과 혼동하지 않게 한다.

제공 함수:

- `displayRating(_ internalRating: Int) -> Int`.
- `displayDelta(before:after:)`.
- `displayCeiling(_ internalCeiling: Int) -> Int`.
- `meaning(forInternalRating:)` 또는 사용자 표시 구간의 단일 의미 함수.
- 게이지 위치 1–100.
- 색상 구간.

모든 능력 UI를 검색해 단일 함수로 연결한다.

- 선수 생성과 프롤로그.
- 고교 훈련·관계·장 결산.
- 프로 요약·주간 계획·성장 축하.
- 기록·은퇴·라이프 카드.
- 공유 카드와 접근성 텍스트.
- 스크린샷·UITest fixture.

피로, 신뢰, 팬 관심처럼 원래 0–100인 값은 이 변환을 사용하지 않는다.

### 5.2 `MasteryGaugeView`

새 공용 뷰를 추가한다.

필수 표시:

- 숙련명.
- 현재 레벨.
- 프로에서 다음 숙련까지 진행 틱.
- 현재 실전 보정의 짧은 의미.
- 새 마일스톤이면 before/after.

기본 능력 100이 아니고 숙련 0이면 숨긴다. 숙련이 한 번이라도 생겼다면 노화로 기본 능력이
내려가도 계속 표시한다.

### 5.3 부상 결과 카드

새 `ProInjuryResultCard`를 `CareerFlowView`의 일반 `ResultBanner`보다 먼저 배치한다.

우선순위:

1. 저장·진행 복구 오류.
2. 새 부상.
3. 회복 완료.
4. 숙련/기본 능력 성장 축하.
5. 일반 주간 요약.

`MobileCareerStore.perform`은 before/after와 `updated.injuryEvent`를 읽어:

- `lastSummary`에 부상을 억지로 합치지 않는다.
- 별도 `pendingInjuryEvent` 또는 저장된 결과 이벤트를 화면에 전달한다.
- 부상 발생 시 `feedbackCue = .setback`을 강제한다.
- 사용자가 확인하면 현재 세션의 표시 상태만 비우되 저장된 커리어 상태는 건드리지 않는다.

앱이 부상 결과를 보여 주기 전에 종료되면 다음 실행에서 다시 표시한다. 확인 영수증이 필요하면
프로 저장 래퍼에 `acknowledgedInjuryEventID`를 추가한다. 시즌·주차·리비전으로 안정 ID를 만든다.

### 5.4 설명 본 기록 저장소

새 파일:

```text
apps/ios/Sources/ProgressiveDisclosure.swift
```

구성:

- `CopyDensity`: `automatic`, `expanded`, `compact`.
- `SeenContentStore`: 안정 ID 집합의 읽기·쓰기·초기화.
- `ProgressiveDisclosure`: 제목·핵심 요약·상세 내용을 받는 공용 SwiftUI 컨테이너.

저장 키:

```text
baseball.copyDensity
baseball.seenContent.v1
```

`automatic` 동작:

1. 첫 등장 시 이번 뷰 인스턴스는 펼친 상태로 시작한다.
2. 실제 화면에 등장하면 ID를 본 것으로 기록한다.
3. 같은 뷰 인스턴스 안에서는 갑자기 접지 않는다.
4. 다음 화면 방문부터 접힌 상태로 시작한다.
5. 사용자가 수동으로 펼치거나 접을 수 있다.

VoiceOver 라벨에는 현재 상태와 `자세히 보기/접기` 행동을 포함한다. 최소 터치 영역을 지킨다.

### 5.5 설정 화면

`SettingsView.swift`에 `설명 표시` 선택을 추가한다.

- 자동 — 처음만 자세히.
- 항상 자세히.
- 간단히.

`모든 진행 초기화`는 `baseball.seenContent.*`와 `baseball.copyDensity`도 초기화한다. 단순 커리어
삭제는 사용자가 익힌 UI 설정을 유지한다.

---

## 6. Windows와 Android/Unity 패리티

### 6.1 Windows

필수 변경:

- `simulationTypes.ts`: 숙련과 구조화된 부상 이벤트.
- `ratingScale.ts`: 같은 1–100 변환 골든 값.
- `AbilityGauge.tsx`, `GrowthCelebration.tsx`: 사용자 숫자와 숙련.
- `ProCareerView.tsx`, `HighSchoolCareerView.tsx`: 부상 원인 카드와 위험 밴드.
- 반복 설명은 `localStorage` 기반 같은 콘텐츠 ID 계약으로 접는다.
- RPC 요청·응답 픽스처에 새 옵셔널 필드.

Swift와 TypeScript의 표시 변환 결과가 20...80 모든 정수에서 동일한 테스트를 추가한다.

### 6.2 Android/Unity

필수 변경:

- C# `PitcherSnapshot`과 도메인에 `AbilityMasterySnapshot`.
- `PitcherGrowthRules`/`ProCareerEngine`에 overflow→mastery 규칙.
- 프로 부상 최소 2% 제거와 `ProInjuryEventSnapshot`.
- Application read model과 Shell/Compose 투영에 사용자용 1–100 표시.
- `BaseballComponents.AbilityGauge`를 1–100 사용자 계약으로 변경.
- 설명 접기 상태는 플랫폼 설정 저장소에 같은 콘텐츠 ID로 저장.
- Swift 골든 픽스처와 C# 결과 비교.

Android 패리티 때문에 iOS 공개를 무기한 막지는 않되, 공유 저장/RPC를 읽는 빌드가 새 스키마를
손상시키지 않는지 확인한다. 같은 버전에서 크로스플랫폼 저장 동기화를 지원한다고 표시한다면
패리티 완료 전 출시하지 않는다.

---

## 7. 구현 웨이브

한 번에 한 웨이브만 진행한다. 각 웨이브의 테스트가 통과한 뒤 다음으로 간다.

### Wave 0 — 특성화 테스트와 기준 분포

코드를 바꾸기 전에 현재 결함을 재현하는 테스트를 만든다.

1. 저피로 프로 주에도 2% 부상이 가능한 시드를 찾는 결정론 테스트.
2. 부상 뉴스가 다른 뉴스 뒤로 밀려 홈의 3줄에서 사라지는 테스트 또는 표현 테스트.
3. 80에서 프로 성장 게이지 완료 후 값은 80인데 `+1` 라벨이 생기는 테스트.
4. 고교 팔 위험 증가의 투구 수·피로 기여 특성화.
5. 1,000시드 프로 정책별 현재 시즌 부상률 저장.
6. 숙련 도입 전 0숙련 투구 골든 픽스처 저장.

Wave 0은 결함 테스트가 **현재 코드에서 실패하거나 문제 동작을 명시적으로 증명**해야 한다.

### Wave 1 — 표시 1–100 단일 출처

1. 코어 또는 공용 표현 테스트에 변환 골든 표 추가.
2. iOS `AbilityDisplayScale` 구현.
3. 모든 iOS 능력 화면 교체.
4. `한계 없음`을 `기본 능력 100까지`로 변경.
5. ko/en/ja 접근성 문구 교체.
6. Windows/Android 표시 패리티.

Wave 1에서는 저장·시뮬레이션 숫자를 바꾸지 않는다.

### Wave 2 — 숙련 모델과 성장 영수증

1. `AbilityMasterySnapshot`과 `PitcherSnapshot.mastery`.
2. 수동 Codable·초기화·동등성·commitment 감사.
3. `PitcherAdvancementRules`와 실제 영수증.
4. 모든 양의 성장 경로를 새 영수증으로 연결.
5. 프로 80 성장 완료 시 숙련 +1, 거짓 기본 능력 `+1` 제거.
6. 고교 80 초과 성장의 숙련 전환.
7. 저장/RPC/스키마/TypeScript/C# 패리티.
8. iOS 숙련 결과 카드와 게이지.

Wave 2 끝에는 숙련이 저장되고 계속 오르지만 실전 보정은 아직 0이어도 된다. 단, 같은 릴리스에
Wave 3 없이 출시하지 않는다. 사용자에게 실전 성장이라고 말하면서 장식 숫자만 올리면 안 된다.

### Wave 3 — 숙련 점감 실전 효과와 밸런스

1. `MasteryEffectRules` 구현.
2. 구위·제구·변화구·체력의 담당 기여에만 보정.
3. 0숙련 골든 결과 완전 동일 확인.
4. 숙련 10/50/100/1,000 분포 비교.
5. 수동 릴리스 성공·실패 격차가 숙련 때문에 역전되지 않는지 확인.
6. 자동 릴리스 접근성 경로가 숙련을 중복 적용하지 않는지 확인.
7. C# 골든 패리티.

### Wave 4 — 프로 부상 규칙과 구조화 이벤트

1. 최소 2% 제거.
2. `ProInjuryEventSnapshot` 추가.
3. 결과·저장·RPC·스키마 연결.
4. 위험 전망 공용 함수.
5. 계획 카드 위험 밴드.
6. 부상 발생·회복 완료 결과 카드.
7. 뉴스는 기록용으로 유지하되 UI 의존 제거.
8. 부상 분포 테스트.

### Wave 5 — 고교 부상 원인 카드

1. 중요 경기 팔 부담 영수증.
2. 경고·강행·재활 결과 원인 표현.
3. 훈련 카드의 권장 행동 연결.
4. 기존 고교 부상률과 결정론 유지 확인.

### Wave 6 — 반복 설명 자동 접기

1. `ProgressiveDisclosure`와 본 기록 저장소.
2. 설명 밀도 설정.
3. 프로 반복 카드 적용.
4. 고교 바람·구종 도움말 적용.
5. 중요 알림이 접히지 않는 회귀 테스트.
6. 앱 재실행 뒤 본 기록 유지 UI 테스트.
7. Windows/Android 패리티.

### Wave 7 — 통합 QA·릴리스 게이트

1. 저장 마이그레이션과 iCloud 충돌.
2. ko/en/ja 번역과 레이아웃.
3. 접근성 큰 글자·VoiceOver.
4. 수동 투구 슬라이더 기본값 스모크.
5. 실제 기기 또는 TestFlight 부상·숙련·접기 종주.
6. 릴리스 노트와 리뷰 대응 문구.

---

## 8. 파일별 예상 변경 지도

### 공유 Swift 코어

- `Domain.swift`: 숙련 모델, `PitcherSnapshot.mastery`, Codable.
- `PitcherDevelopmentRules.swift`: `PitcherAdvancementRules`, 성장 영수증.
- `MasteryEffectRules.swift`: 신규.
- `PitchAbilityRules.swift`: 숙련 점감 보정.
- `PitchKernelEngine.swift`: 필요한 계산 지점에만 숙련 기여 연결.
- `HighSchoolCareerModels.swift`: 성장 규칙 버전/건강 영수증이 필요하면 추가.
- `HighSchoolCareer.swift`: overflow 숙련, 건강 원인 영수증.
- `ProCareerModels.swift`: 부상 이벤트 결과, 필요 버전 필드.
- `ProCareer.swift`: 부상 공식, 위험 전망, 숙련 성장, 거짓 라벨 제거.
- `SimulationProtocol/RPCServer.swift`: 새 옵셔널 필드.

### iOS

- `AbilityGaugeView.swift`.
- `HighSchoolPrologueViews.swift`.
- `HighSchoolChapterReviewViews.swift`.
- `HighSchoolTrainingViews.swift`.
- `HighSchoolTrainingResultViews.swift`.
- `HighSchoolCareerStore+ImportantGame.swift`.
- `ProWeeklyPlanView.swift`.
- `MobileCareerStore.swift`.
- `CareerFlowView.swift`.
- `AppShell.swift`.
- `CareerFlowChrome.swift`.
- `RecordView.swift`, `LifeCardView.swift`, `ProRetirementViews.swift`.
- `ProgressiveDisclosure.swift`: 신규.
- `SettingsView.swift`.
- `ProCareerPersistence.swift`, `HighSchoolCareerPersistence.swift`.
- `Localization/*.swift`, `Localizable.xcstrings`, `GameContent.xcstrings`.

### 계약·도구

- `schemas/pro-career.schema.json`.
- `schemas/high-school-career.schema.json`.
- 필요한 pitch/RPC schema와 픽스처.
- `tools/check-copy.mjs` 또는 새 사용자 능력 표시 정적 검사.
- `tools/check-ios-localization.mjs`.
- 프로 분포 runner와 balance check.

### Windows

- `simulationTypes.ts`.
- `ratingScale.ts`.
- `AbilityGauge.tsx`.
- `GrowthCelebration.tsx`.
- `HighSchoolCareerView.tsx`.
- `ProCareerView.tsx`.
- 저장·RPC 테스트.

### Android/Unity

- `Core/Pro/ProDomain.cs`, `ProCareerSnapshot.cs`, `ProCareerEngine.cs`.
- 공용 `PitcherSnapshot`과 성장 규칙.
- Application contracts/read models/ports.
- `Presentation/Common/BaseballComponents.cs`.
- HighSchool/Pro/Shell 화면 투영.
- EditMode 도메인·프레젠테이션 테스트.

---

## 9. 현지화 문구 계약

한국어·영어·일본어를 같은 변경에서 완료한다.

필수 키 범주:

- 기본 능력 100 완성.
- 숙련명 네 개.
- 숙련 레벨·다음 숙련·실전 보정.
- 숙련 상승·마일스톤.
- 부상 위험 낮음/주의/높음.
- 팔 과부하 원인·회복 기간·다음 행동.
- 고교 팔 부담 원인.
- 설명 표시 자동/항상 자세히/간단히.
- 자세히 보기/접기 접근성 행동.

금지 문구:

- 사용자 화면의 `20–80`.
- 실제 하드캡이 있는데 `한계 없음`, `No Ceiling`, `天井なし`.
- 저피로 랜덤 사건을 `과부하`라고 부르는 문구.
- 숙련만 올랐는데 기본 능력 `+1`이라고 말하는 문구.

`check-ios-localization`과 바이너리 `ja.lproj` 검사를 통과하지 않으면 ASC에 제출하지 않는다.

---

## 10. 분석 이벤트

개인 식별 정보 없이 다음을 추가한다.

| 이벤트 | 주요 속성 |
|---|---|
| `injury_risk_shown` | mode, risk_band, fatigue_band, plan, role |
| `injury_started` | mode, cause, recovery_weeks, risk_band, plan |
| `injury_result_acknowledged` | mode, cause, recovery_weeks |
| `mastery_gained` | ability, level_band, source, mode |
| `mastery_milestone` | ability, milestone, mode |
| `copy_detail_toggled` | content_id, expanded, density |
| `copy_density_changed` | from, to |

원시 선수명, 시드, 저장 ID, 자유 입력 문구를 보내지 않는다. 이벤트 추가가 게임 진행이나 저장
성공의 전제 조건이 되어서는 안 된다.

---

## 11. 테스트 계획

### 11.1 표시 변환

- 20...80 모든 내부 정수의 표시가 1...100.
- 단조 증가.
- 20→1, 50→50, 80→100.
- Swift/TypeScript/C# 골든 결과 동일.
- before/after와 재능 한계가 같은 변환.
- 피로·신뢰 수치에는 변환 미적용.

### 11.2 숙련 성장

- 79 +2 → 기본 80, 숙련 1.
- 80 +1 → 기본 80, 숙련 1.
- 80에서 프로 6틱 완료 → 숙련 +1, 기본 능력 `+1` 라벨 없음.
- 네 능력이 서로의 숙련을 올리지 않음.
- 변화구 대상 훈련은 선택 구종 프로필 성장과 변화구 숙련을 함께 보존.
- 32비트 안전 범위에서 포화 증가하고 오버플로하지 않음.
- 노화로 기본 능력이 내려가도 숙련 보존.
- 환생 신규 선수는 이전 숙련을 직접 상속하지 않음.
- 고교→프로는 같은 선수 숙련을 보존.
- 저장 encode/decode, iCloud 복구본, RPC round trip.

### 11.3 숙련 밸런스

동일 투수·동일 시드 범위를 숙련 0/10/50/100/1,000으로 비교한다.

출시 수용 기준:

- 숙련 0은 변경 전 골든 픽스처와 동일.
- 숙련 100의 담당 지표 개선은 숙련 0 대비 유의미하지만 15%를 넘지 않는다.
- 숙련 1,000과 100의 추가 개선은 5% 이내다.
- 나쁜 릴리스와 좋은 릴리스의 차이는 숙련 100에서도 유지된다.
- 모든 능력 숙련 1,000이 자동 무실점·자동 삼진을 만들지 않는다.
- 자동 릴리스가 수동 슬라이더의 최고 실행 보상을 넘지 않는다.

지표는 능력별로 K/9, BB9, H9, RA9, 평균 유효 피로, 평균 투구 수를 사용한다.

### 11.4 프로 부상

- 유효 피로 72 이하에서 과부하 부상 0%.
- 73부터 공식대로 확률 증가.
- 같은 시드·상태·선택은 같은 부상 결과.
- 부상 시작 결과에 구조화 이벤트 1개.
- 회복 주에는 새 시작 이벤트 없음.
- 구간 자동 진행이 부상에서 멈추고 결과 카드가 원인을 표시.
- 성장·구간·중요 경기 뉴스가 많아도 부상 카드가 사라지지 않음.
- 앱 종료·재실행 후 미확인 부상 카드 복원.
- 확인 후 반복 노출하지 않음.

분포 정책:

1. 안전 정책: 유효 피로 72를 넘기기 전에 회복 — 과부하 부상 0%.
2. 보통 정책: UI 추천을 따름 — 시즌 부상률을 측정하고 5–25% 목표.
3. 강행 정책: 고피로에서도 성장 선택 — 보통 정책보다 명확히 높은 부상률.

공식 고정값으로 보통 정책이 목표를 벗어나면 임계 72를 조정하기 전에 결과를 §19에 기록한다.
실패를 숨기려고 수용 밴드를 넓히지 않는다.

### 11.5 고교 건강

- 23구 이하 등판은 기존과 같이 투구 수 위험 0.
- 피로만 높고 투구 수 바닥을 넘지 않으면 기존 규칙 유지.
- 위험 밴드가 바뀐 경기에서 원인 카드 표시.
- 경고 후 강행 부상에 `push_through` 원인.
- 재활 횟수와 카드 문구 일치.
- 고교 부상률 기존 스펙 밴드 유지.

### 11.6 자동 접기

- 자동 모드 첫 방문 펼침.
- 같은 화면 인스턴스에서 갑자기 접히지 않음.
- 다음 방문 접힘.
- 앱 재실행 뒤 접힘 유지.
- 항상 자세히 모드는 본 기록과 무관하게 펼침.
- 간단히 모드는 첫 방문도 접힘.
- 새 콘텐츠 ID 버전은 다시 한 번 펼침.
- 부상·새 사건·직전 결과는 어떤 밀도에서도 펼침.
- VoiceOver에 상태와 토글 행동 포함.
- 큰 글자에서 핵심 수치와 주 행동이 가려지지 않음.

### 11.7 회귀

- 신규 게임 기본 투구 조작이 슬라이더.
- 한 구를 수동 슬라이더로 끝까지 던질 수 있음.
- 고교 시작→지명→프로→부상→회복→숙련→은퇴→환생 종주.
- ko/en/ja 앱 내부 언어 전환.
- 실존 구단명·통용 약칭 정적 검색.
- 기존 저장 v1–현재 버전 fixture 모두 로드.

---

## 12. UI 종주 시나리오

### 시나리오 A — 신규 사용자 능력 이해

1. 첫 선수 생성.
2. 프리셋 능력이 1–100으로 보임.
3. 숫자 의미를 `고교 주전 경쟁`, `프로 평균`처럼 이해.
4. 어떤 화면에도 20–80 설명이 없음.

### 시나리오 B — 기존 80 선수

1. 1.2.3에서 주요 능력 80인 저장 로드.
2. 화면은 100으로 표시.
3. 다음 성장 계획을 6틱 완료.
4. `구위 +1`이 아니라 `강속구 숙련 Lv.1` 표시.
5. 앱 재실행 후 숙련 유지.

### 시나리오 C — 안전한 피로 관리

1. 유효 피로가 72를 넘기 전에 회복.
2. 여러 시즌 진행.
3. `과부하` 부상이 발생하지 않음.
4. 계획 카드에서 위험이 낮음으로 일치.

### 시나리오 D — 고피로 강행과 부상

1. 높은 피로에서 강한 성장 계획 선택.
2. 위험 `높음` 확인.
3. 고정 시드로 부상 발생.
4. 화면 최상단에서 원인·피로·투구 수·회복 주수 확인.
5. 뉴스 탭을 열지 않고 다음 행동 이해.

### 시나리오 E — 반복 설명

1. 첫 프로 주간 화면에서 여섯 계획 설명 확인.
2. 다음 주 방문.
3. 제목·효과 요약·비용·위험·진행만 표시.
4. 선택한 카드만 펼쳐 세부 문구 확인.
5. 앱 재실행 뒤에도 같은 상태.

### 시나리오 F — 중요 정보 보호

1. 설정을 `간단히`로 변경.
2. 부상, 새 구종 완성, 숙련 마일스톤 발생.
3. 세 결과는 자동으로 펼쳐짐.
4. 주 행동을 하기 전 결과를 읽을 수 있음.

---

## 13. 검증 명령

실제 저장소 스크립트 이름이 바뀌었다면 `package.json`, `Package.swift`, Xcode scheme을 확인해
동등한 명령을 사용하고 §19에 기록한다.

최소 검증:

```bash
swift test --package-path packages/simulation-core
node tools/check-balance.mjs
node tools/check-copy.mjs
node tools/check-ios-localization.mjs
npm run build
```

iOS:

```bash
xcodebuild test -project apps/ios/Baseball.xcodeproj -scheme Baseball \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Windows와 Android는 각 앱의 기존 CI/정적 테스트 진입점을 사용한다. 저장소 전체 빌드가 너무 큰
출력을 만들면 AGENTS.md의 보관 상한을 지키고, 같은 DerivedData/빌드 디렉터리를 재사용한다.

---

## 14. 출시와 롤백

### 14.1 출시 순서

기능 플래그를 쓴다면 다음처럼 분리한다.

1. `abilityDisplay100`: 표시만. 가장 먼저 켤 수 있다.
2. `abilityMasteryV1`: 저장·성장·실전 효과를 한 세트로 켠다.
3. `explainableInjuryV1`: 새 부상 공식과 구조화 이벤트를 함께 켠다.
4. `progressiveDisclosureV1`: 자동 접기.

숙련 저장을 쓴 뒤 플래그를 꺼도 저장 필드를 버리거나 80으로 되돌리지 않는다. 롤백 빌드는 숙련을
읽고 보존하되 효과와 UI만 안전하게 숨길 수 있어야 한다.

### 14.2 출시 차단 조건

다음 중 하나라도 있으면 제출하지 않는다.

- 기존 저장이 열리지 않음.
- 80 선수의 다음 성장이 다시 사라짐.
- 부상 카드 없이 `injuryWeeks`만 증가하는 경로가 존재.
- 안전 정책에서 `과부하` 부상 발생.
- 설명 간단히 모드가 중요 결과를 숨김.
- 숙련 0이 기존 투구 골든 결과를 바꿈.
- 숙련이 슬라이더 실행보다 결과를 크게 지배.
- ko/en/ja 중 하나가 바이너리에서 누락.
- 기본 투구 슬라이더가 노출되지 않음.

---

## 15. 완료 정의

다음 항목이 모두 충족되어야 `구현 완료`로 문서 상태를 바꾼다.

- [ ] 사용자 능력 숫자는 모든 공개 화면에서 1–100이다.
- [ ] 내부 저장·RPC 주요 능력은 20–80 계약을 유지한다.
- [ ] 기존 80 선수는 100으로 보이고 다음 성장부터 숙련을 얻는다.
- [ ] 네 숙련 레벨이 저장·복원·고교→프로 전달된다.
- [ ] 숙련 효과가 점감하며 0숙련 골든 결과는 동일하다.
- [ ] 거짓 `능력 +1` 문구가 없다.
- [ ] 저피로 최소 2% 과부하 부상이 제거됐다.
- [ ] 프로 부상 발생 순간 원인·근거·회복·대처가 최상단에 보인다.
- [ ] 고교 팔 부담과 강행 부상의 원인이 결과 카드에 보인다.
- [ ] 반복 설명은 자동으로 처음만 펼쳐지고 본 상태를 기억한다.
- [ ] 중요 알림은 어떤 설명 밀도에서도 펼쳐진다.
- [ ] Swift/TypeScript/C# 표시와 저장 계약이 일치한다.
- [ ] 모든 구저장 fixture가 열린다.
- [ ] ko/en/ja 현지화와 실기기/TestFlight 스모크를 통과했다.
- [ ] 기본 수동 투구 슬라이더로 한 구를 끝까지 던졌다.
- [ ] 실존 구단명과 통용 약칭 검색을 통과했다.
- [ ] 생성한 임시 빌드·스크린샷·결과 번들을 보관 규칙에 맞게 정리했다.

---

## 16. 일정 압박 시 축소 순서

축소하면 안 되는 것:

- 부상 최소 2% 제거와 구조화된 부상 결과.
- 거짓 `+1` 제거.
- 기존 저장 호환.
- 사용자 1–100 표시의 단일 출처.
- 숙련 저장과 실제 점감 효과를 같은 출시에서 제공.
- ko/en/ja.
- 투구 슬라이더 회귀 검증.

뒤로 미룰 수 있는 것:

1. 숙련 10단위의 화려한 마일스톤 연출.
2. Windows/Android의 애니메이션 패리티. 데이터와 숫자 패리티는 미룰 수 없다.
3. 설명 본 기록의 클라우드 동기화. 로컬 유지로 먼저 출시 가능하다.
4. 기록 탭의 전체 부상 이력. 최초 발생 카드와 현재 회복 상태는 필수다.

기능을 줄인다는 이유로 숙련을 장식 숫자로 만들거나 부상 원인을 다시 뉴스 문자열 하나로 축소하지
않는다.

---

## 17. 구현 에이전트 작업 규칙

1. Wave 0 테스트 없이 밸런스 공식을 먼저 바꾸지 않는다.
2. 한 웨이브가 끝날 때 관련 테스트를 실행하고 결과를 문서 §19에 남긴다.
3. 기존 dirty 변경과 겹치는 파일은 먼저 diff를 읽고 최소 패치한다.
4. 새 모델 필드를 추가하면 생성자, Codable, Equatable, replacing, commitment, schema, RPC,
   Swift/TS/C# 타입을 체크리스트로 모두 갱신한다.
5. 사용자 표시 숫자를 각 화면에서 직접 계산하지 않는다.
6. 뉴스 문자열을 파싱해 중요 상태를 판단하지 않는다.
7. 번역 키를 한국어만 추가하고 영어·일본어를 나중으로 미루지 않는다.
8. 배포 전 서명된 IPA의 일본어 리소스와 App Store 지원 언어 `Japanese`를 확인한다.
9. 이미지·빌드·테스트 결과는 프로젝트 저장 안전 규칙에 맞게 정리한다.

---

## 18. 금지된 지름길

- 주요 능력 저장 범위를 곧바로 0–999로 확장.
- 타자·수비·구종 프로필까지 근거 없이 1–100으로 재작성.
- 80에서 성장한 척 라벨만 바꾸고 실제 숙련 저장을 만들지 않음.
- 숙련을 선형으로 커널 전체에 더해 후반 자동 승리 생성.
- 피로가 낮아도 2%를 유지하면서 문구만 `돌발`로 교체.
- 부상 결과를 `news.prefix` 개수만 늘려 해결.
- 모든 줄글을 무조건 숨기는 전역 compact 모드.
- 중요한 선택의 비용과 부상 위험까지 접기.
- 기존 저장을 새 프리셋으로 재생성.
- 현재 worktree를 reset/stash/checkout해 사용자 변경을 제거.

---

## 19. 구현 결정·측정 기록

구현 에이전트는 아래 표에 웨이브별 결과를 추가한다. 계획 단계에서는 비워 둔다.

| 날짜 | Wave | 변경/측정 | 결과 | 결정 이유 |
|---|---:|---|---|---|
| 2026-08-28 | 계획 | 제품·데이터·QA 계약 확정 | 미구현 | 리뷰 세 항목을 따로 땜질하지 않고 한 성장·피드백 개선으로 묶음 |
| 2026-08-28 | 2/3/4/6 패리티 보강 | Swift 숙련·부상 회귀 테스트, Windows 1–100 잠재 범위·건강 전망·부상 확인 영수증, Android/Unity 모델·코덱·부상 결과 보강 | 중간 측정 당시 Swift 신규 집중 테스트 4개와 Windows 103테스트/빌드 통과; Kotlin/Unity는 아래 최종 행에서 재검증 | 공용 저장·결과 계약을 먼저 맞추고, 중간 실패도 기록 |
| 2026-08-28 | 1 | 내부 20–80 저장을 유지하고 공개 능력 UI를 1–100으로 통일 | iOS 빌드 및 Presentation/현지화 테스트 통과 | 저장·투구 커널 계약을 깨지 않고 익숙한 숫자를 제공 |
| 2026-08-28 | 2/3 | 80 초과 성장→숙련, 포화 디코딩, 점감 효과, HS 훈련·관계·경기 overflow | `CompactMasteryHealthParityTests` 4/4 통과 | 100 이후 성장과 구저장 안전을 같은 규칙으로 검증 |
| 2026-08-28 | 4/5 | 프로 최소 2% 제거·구조화 부상, 고교 팔 원인 결과 카드 | 안전 정책 부상 0, 고부하 이벤트·저장 round-trip 통과 | 부상은 선택과 결과를 설명해야 함 |
| 2026-08-28 | 6 | 처음만 펼치는 설명·밀도 설정·본 기록 지속 | 실제 iOS 재실행 뒤 `간단히`와 `접혀 있음` 복원 확인 | 중요 결과는 펼치고 반복 설명만 줄임 |
| 2026-08-28 | 7 핵심 종주 | iOS 26.5 iPhone 17 Pro 시뮬레이터에서 1–100, 숙련 4축, 부상 근거·대처, 확인 영수증, 수동 슬라이더 한 구 완료 | 통과 · 관련 iOS 52+44+13 테스트와 구종 학습 재실행 UI 테스트 통과 | 화면·저장·조작을 실제 앱에서 함께 확인 |
| 2026-08-28 | 플랫폼 패리티 | Windows 103 테스트/빌드, Kotlin `:game-core:test`, Unity C# 정적 447 테스트, 전체 밸런스 게이트 | 모두 통과 | 0숙련 골든 결과와 플랫폼 저장 계약을 보존 |
| 2026-08-28 | 버전 결정 | `proRulesVersion`은 4 유지, 새 저장 스키마를 Pro 5/HS 4로 승격 | 채택 | 저피로 부상 제거는 구저장에도 적용해야 하는 버그 수정이고, 숙련은 optional identity라 일정 규칙을 다시 나누지 않음 |
| 2026-08-28 | 릴리스 게이트 | 1.2.4 build 62 서명 IPA·Apple 서버 검증, ko/en/ja 바이너리, 일본어 iPhone 16 Pro 스모크, 사용자 대상 6개 ASC 문안, build 연결 | 모두 통과 · 출시 방식 MANUAL | 바이너리·언어·스토어 문안을 출시 전에 함께 증명 |
| 2026-08-28 | App Review | 사용자 재확인 뒤 1.2.4 build 62 심사 제출 | 제출 `62f11307-2534-4821-9cec-9741328f15bb` · `WAITING_FOR_REVIEW` · 경고 없음 | 수동 출시를 유지하고 심사 제출까지만 수행 |

상수 변경 기록 형식:

```text
before: 공식/분포
after: 공식/분포
sample: 시드 수, 정책, 역할, 시즌 수
decision: 유지/조정/롤백
reason: 사용자 선택 가능성, 밸런스, 회귀 근거
```

---

## 20. 최종 제품 문장

이번 개선이 끝났을 때 사용자가 느껴야 하는 것은 다음 한 문장이다.

> 숫자는 이해하기 쉬워졌고, 100에 도달해도 내 투수는 계속 자기 공을 갈고닦는다. 다치면 왜
> 다쳤는지와 무엇을 해야 하는지 바로 알 수 있고, 이미 아는 설명은 다시 읽지 않아도 된다.
