# 프로 커리어 주체성·몰입 개선 최종 구현 계획

| 항목 | 값 |
|---|---|
| 문서 ID | `DOC-PRO-CAREER-AGENCY-FINAL-2026-08-13` |
| 상태 | **구현 준비 완료(Ready for implementation)** |
| 기준일 | 2026-08-13 |
| 대상 | `packages/simulation-core` + `apps/ios` |
| 입력 | 외부 사용자 리뷰 1건과 현재 코드·테스트·기존 계획의 대조 검토 |
| 제품 목표 | 프로 투수를 “다음 세대의 재료”가 아니라 선택·등판·평가가 이어지는 한 명의 커리어로 느끼게 한다. |
| 우선순위 | 기록 정합성 → 선택의 결과 피드백 → 투구 판단 → 노년기 대우 → 한국어 품질 |
| 범위 밖 | Android/Unity 동시 구현, 전체 로스터 시뮬레이션, 타자 커리어, 새 화폐·수익화 |

이 문서는 AI 에이전트가 위에서 아래로 구현할 수 있는 최종 명세다. 오래된 계획의 체크박스를 그대로 실행하지 말고, 충돌할 때는 이 문서와 현재 코드를 우선한다.

특히 프로 커리어 관련 내용에서 다음 문서를 부분적으로 대체한다.

- `docs/GAMEPLAY_RETENTION_IMPLEMENTATION_PLAN_2026-08.md`의 프로 시즌 결정 빈도와 즉시 효과 중심 설계
- `docs/IOS_TOP_TIER_PLAN.md`의 오래된 시즌 수·주간 반복 설명
- ADR-013과 Android 패리티 문서의 12시즌 표기

역사적 리뷰와 과거 릴리스 근거는 삭제하지 않는다. 구현이 끝나면 현재 규칙을 설명하는 ADR과 패리티 표만 갱신한다.

---

## 1. 최종 결론

이전의 단순 처방인 “포수 대안을 보여 주고, 베테랑 직접 경기를 늘리고, 반응 문구를 추가한다”는 최선이 아니다. 그대로 구현하면 다음 부작용이 생긴다.

1. 현재 중요 경기는 주간 자동 등판을 대체하지 않고 **추가 경기로 누적**된다. 직접 경기 수만 늘리면 몰입보다 시즌 성적 왜곡이 커진다.
2. 현재 직접 플레이는 대체로 한 이닝이다. 선발의 예정 등판을 단순히 이 기록으로 교체하면 선발 이닝이 사라진다.
3. 현재 `recover`는 훈련 회복이 아니라 **해당 주 등판 0회**를 뜻한다. 더구나 `advanceSegment()`가 같은 선택을 여러 주 반복하므로, 한 번의 탭이 여러 주 미등판으로 번진다.
4. 포수의 2안은 코어에 이미 있지만 화면에 없다. 단순 노출만 하면 의미 있는 선택이 아니라 탭 하나만 늘어날 수 있다.
5. 현재 시즌 선택은 대체로 즉시 수치만 바꾸고 끝난다. 선택지를 3회에서 7회로 늘리면 반응이 깊어지는 것이 아니라 반복 피로만 늘어난다.
6. `balanceVersion`은 투구 밸런스와 프로 콘텐츠 규칙을 함께 가르는 데 쓰인다. 이를 다시 올려 진행 중 시즌을 일괄 변경하면 구저장·결정론·pending 상태가 흔들린다.
7. 한국어만 고쳐서는 선택과 기록의 모순을 숨기는 데 그친다.

따라서 최종안은 다음 두 릴리스로 분리한다.

- **안전 패치:** 회복의 다주 자동 반복을 즉시 막고, 현재 규칙의 “등판 없음”을 선택 전에 공개하며, 결과 요약에 실제 등판 수를 보여 준다. RNG와 시즌 결과 산식은 바꾸지 않는다.
- **프로 규칙 v2:** 새 시즌 경계부터 훈련·출전 가능 상태·구단 기용을 분리하고, 직접 플레이를 예정된 등판의 일부로 합성하며, 선택의 후속 반응과 커리어 위상을 저장한다.

새 규칙은 `balanceVersion`과 독립된 `proRulesVersion`으로 관리한다. 진행 중인 구규칙 시즌의 과거 결과는 재작성하지 않는다.

---

## 2. 리뷰를 코드로 재현한 결과

| 리뷰 증상 | 현재 구현 근거 | 판정 |
|---|---|---|
| “휴식·훈련 딸깍” | `ProCareerEngine.planWeek`가 `recover`이면 `restingWeek = true`, 경기 0회, 피로 -20으로 처리한다. | 사실이며 비용이 UI에서 충분히 공개되지 않는다. |
| 한 선택 뒤 긴 미등판 | `MobileCareerStore.advanceSegment()`가 선택한 `selectedPlan`을 최대 24회 반복 호출한다. | 명백한 상호작용 결함이다. |
| 포수 지시만 따라도 고민 없음 | `PitchSession`은 기본적으로 매 투구 `primaryRecommendation`을 선택한다. `alternativeRecommendation`은 코어에 있으나 `CatcherCard`에 없다. | UI 노출과 정책 밸런스가 모두 부족하다. |
| 직접 경기와 자동 기록의 관계가 불명확 | `planWeek`가 자동 경기들을 먼저 누적한 뒤 `.importantGame`을 열고, `resolveImportantGame`이 다시 경기 1회를 더한다. | 직접 경기가 예정 등판을 대체하지 않는 정합성 결함이다. |
| 후반기·베테랑 직접 경기가 적음 | `maximumImportantGames(for:)`는 1~8시즌 3회, 9시즌 이후 2회다. | 직접 플레이 밀도는 줄지만 이것을 실제 총등판 수로 해석하면 안 된다. |
| 좋은 베테랑이 이유 없이 사라짐 | 주간 총등판은 역할·회복·부상으로 정해지고, 장기 성적에서 만든 위상이나 기용 설명 상태가 없다. | 성적과 대우를 잇는 모델이 없다. |
| 선택 후 반응 없음 | 시즌 결정은 `ProDecisionEffect`를 즉시 적용하고 기록한다. 다음 등판·구간·시즌에서 회수되는 결과가 없다. | 숫자 변화는 있으나 서사적·시스템적 후속 반응이 없다. |
| 번역투·어색한 한국어 | `check:korean-copy` 기본 대상은 고교 관련 Swift 3개 파일이고, 프로 화면과 두 `.xcstrings` 카탈로그는 기본 검사 범위가 아니다. 사람 평가 자료는 있으나 실제 응답은 없다. | 출시용 프로 한국어 QA가 비어 있다. |

추가로 기술 표기는 “평균자책점”이 아니라 **9이닝당 실점(RA9)** 이다. 현재 시뮬레이션은 자책점과 비자책점을 구분하지 않으므로, 자책점 모델을 만들지 않는 한 UI·테스트·분석에서 ERA라고 부르지 않는다.

---

## 3. 기각한 대안

| 대안 | 기각 이유 | 채택한 대안 |
|---|---|---|
| 베테랑 중요 경기 상한만 2→5로 올린다. | 현재 구조에서는 자동 경기 위에 추가되어 경기·승수·이닝을 왜곡한다. | 예정 등판 1회를 예약하고, 그 등판 안의 승부처를 직접 플레이한다. |
| 포수 추천을 무작정 약하게 만든다. | 포수가 무능해 보이고 초보자만 벌을 받는다. | 1안은 안전한 평균 선택, 2안·직접 수정은 보이는 정보로 더 나은 판단이 가능하게 한다. |
| 포수 2안을 그대로 한 줄 더 보여 준다. | 한 선택이 모든 면에서 우월하면 장식이고, 둘 다 비슷하면 읽을 이유가 없다. | 이득·위험 구조가 다른 비지배 대안이라는 코어 계약과 정책 시뮬레이션을 먼저 만든다. |
| 회복을 선택해도 기존 산식 그대로 등판시킨다. | 투구 수에 따른 피로가 없는 현재 모델에서는 회복·부상·체력의 의미가 무너진다. | 훈련 부하와 등판 부하를 분리해 합산한다. |
| 시즌 선택을 7회로 다시 늘린다. | 20시즌에 최대 140회가 되어 반복 피로가 커지고, 즉시 수치 효과의 얕음은 그대로다. | 시즌당 3회 유지, 각 선택에 한 번의 지연 결과를 연결한다. |
| `balanceVersion`을 5로 올려 모두 즉시 전환한다. | 투수 물리와 프로 스케줄 규칙이 결합되고, 진행 중 시즌·pending 상태의 결정론을 깨뜨린다. | 별도 `proRulesVersion`, 새 시즌 경계 마이그레이션을 쓴다. |
| 랜덤 이벤트와 대사를 많이 추가한다. | 원인과 결과가 불명확한 잡음만 늘고, 리뷰의 “내 행동에 대한 반응”을 해결하지 못한다. | 선택 ID와 후속 결과 ID를 직접 연결하고 정확히 한 번 회수한다. |
| 계승 보상을 더 강조한다. | 현 선수가 다음 세대를 위한 재료처럼 느껴진다는 비판을 강화한다. | 은퇴 전에는 현 선수의 위상·목표·등판을 정보 계층 최상단에 둔다. |
| 한국어 문구만 전면 개작한다. | 잘못된 일정과 기록을 자연스럽게 포장할 뿐이다. | 시스템 계약을 먼저 고친 뒤 장면 단위로 한국어를 다시 쓴다. |

---

## 4. 목표와 비목표

### 4.1 목표

1. 선택 전에 **이번 선택이 훈련·등판·피로·관계에 무엇을 하는지** 알 수 있다.
2. 자동 진행 뒤 **무엇을 했고, 무슨 일이 생겼고, 왜 생겼으며, 다음에 무엇을 고를지** 한 화면에서 알 수 있다.
3. 직접 플레이한 승부는 시즌의 별도 보너스 경기가 아니라 예정된 한 등판에 정확히 한 번 포함된다.
4. 포수 1안을 따르는 것은 안전하지만 상시 최적은 아니며, 보이는 정보를 읽은 선택이 유의미하게 더 낫다.
5. 건강하고 최근 성적이 좋은 투수는 나이만으로 갑자기 사라지지 않는다. 기용이 줄면 이유와 대응 선택이 먼저 나온다.
6. 프로 커리어의 현재 선수가 은퇴 전까지 제품의 주인공으로 남는다.
7. 한국어는 한국어 장면으로 먼저 작성하고, 핵심 행동의 결과를 오해할 여지가 없다.

### 4.2 비목표

- 전체 1군·2군 로스터, 트레이드 시장, 샐러리캡을 구현하지 않는다.
- 실제 프로 구단·리그·선수·로고·유니폼·슬로건을 사용하지 않는다.
- 진행 시간을 늘리기 위한 에너지·대기·출석 압박을 추가하지 않는다.
- 모든 투구 전에 팝업이나 확인 탭을 강제하지 않는다.
- 완료된 과거 시즌의 기록을 새 규칙으로 재시뮬레이션하지 않는다.
- 자책점 모델 없이 “평균자책점” 표기를 도입하지 않는다.
- Android/Unity의 현재 사용자 변경 파일을 건드리지 않는다. 공유 코어 규칙이 안정된 뒤 별도 패리티 작업으로 넘긴다.

---

## 5. 절대 불변 제품 계약

### 5.1 행동 공개 계약

모든 주간 계획 카드는 실행 전에 다음 네 항목을 표시한다.

- 성장: 어떤 게이지가 얼마나 진행되는가
- 등판: 예정 등판 유지, 부하 축소, 1회 건너뜀, 부상 결장 중 무엇인가
- 몸 상태: 예상 피로 방향과 부상 위험 단계
- 관계: 감독·포수 평가에 가능한 영향과 그 이유

수치가 확정이면 수치로, 확률이면 범위나 정성 단계로 표시한다. 결과를 숨긴 채 “좋은 선택/나쁜 선택”만 쓰지 않는다.

### 5.2 등판 회계 계약

프로 규칙 v2의 한 주에는 다음 등식이 성립해야 한다.

```text
예정 등판 수 = 자동 완료 등판 수 + 직접 플레이 예약 수 + 정당한 결장 수
```

pending이 없는 안정 상태에서는 다음도 성립해야 한다.

```text
currentStats.games = 이번 시즌 gameLines.count
currentStats의 이닝·K·BB·실점·투구 수·승·패·세이브
  = 이번 시즌 gameLines 각 필드의 합
```

구저장에는 `gameLines`가 없거나 불완전할 수 있으므로 이 강한 검증은 **v2로 시작한 시즌**에만 적용한다.

### 5.3 직접 플레이 계약

- 직접 플레이는 새 경기를 만들지 않는다.
- 선발·긴 이닝 구원의 경우 사용자가 던진 승부처와 자동 보완 구간을 합쳐 `ProGameLine` 한 행을 만든다.
- `played == true`는 “이 경기의 일부를 직접 던짐”을 뜻한다. UI 문구도 “직접 승부 포함”으로 맞춘다.
- 저장 후 재개해도 같은 상대·점수 상황·자동 보완 결과가 유지된다.
- 같은 pending 등판을 두 번 resolve할 수 없다.

### 5.4 무음 기용 축소 금지

건강한 선수가 정규 역할에서 한 시즌 예상 2회 이하로 떨어질 수 있는 유일한 이유는 다음 중 하나다.

- 명시된 부상 또는 재활
- 사용자가 확인한 1회 건너뜀
- 성적·능력·역할 경쟁으로 발생한 기용 면담
- 사용자가 택한 보직 전환·군 복무·은퇴

나이와 시즌 번호만으로 기용을 줄이지 않는다. 최근 두 시즌의 표본이 충분하고 RA9가 우수한 선수는 한 번에 한 역할 단계보다 더 크게 강등할 수 없으며, 그마저도 면담과 이유 ID가 있어야 한다.

### 5.5 선택 회수 계약

- 시즌 결정은 즉시 효과와 지연 효과를 각각 미리 보여 준다.
- 지연 효과는 다음 등판, 다음 구간, 시즌 결산 중 약속한 시점에 정확히 한 번 발생한다.
- 지연 효과가 시즌 끝까지 발동하지 못하면 시즌 결산에서 명시적으로 정산한다.
- 한 결정의 후속 결과는 `sourceDecisionID`로 원인과 연결된다.

### 5.6 저장·결정론 계약

- 같은 상태·같은 명령·같은 시드는 같은 결과를 낸다.
- 시스템 시간, Swift `random()`, 배열의 불안정 순서에 의존하지 않는다.
- 신규 무작위는 기존 `SplitMix64` 또는 안정 해시를 사용한다.
- v1 상태의 RNG 소비 순서와 결과는 의도한 안전 패치 외에는 바꾸지 않는다.
- 새 저장 필드는 옵셔널 aggregate 하나로 추가하고, 구저장 해시는 필드가 없을 때 바이트 단위로 유지한다.

### 5.7 콘텐츠 계약

- 새 상태에는 현지화된 자유 문장을 저장하지 않는다. 안정 ID와 수치만 저장하고 화면에서 현지화한다.
- 과거 저장에 이미 들어 있는 `news`, `choiceTitle` 등 문자열은 그대로 읽되 새 규칙에서 확대 생산하지 않는다.
- 실존 야구 IP 검사는 `npm run check:copy`를 단일 원본으로 유지한다.

---

## 6. 목표 상태 모델

`ProCareerSnapshot`은 이미 저장 프로퍼티가 많은 `final class`이며 수기 `==`와 `replacing(...)`을 쓴다. 개별 필드를 계속 늘리지 말고 옵셔널 aggregate 하나만 추가한다.

```swift
public struct ProCareerAgencyState: Codable, Equatable, Sendable {
    public let rulesVersion: Int
    public let playPace: ProPlayPace
    public let standing: ProCareerStanding
    public let usagePlan: ProUsagePlan?
    public let pendingOuting: ProPendingOuting?
    public let pendingConsequences: [ProPendingConsequence]
    public let lastReceipt: ProPeriodReceipt?
}
```

`ProCareerSnapshot`에는 다음 한 필드만 추가한다.

```swift
public let agencyState: ProCareerAgencyState?
```

### 6.1 규칙 버전

```swift
public enum ProCareerRulesVersion: Int, Codable, Sendable {
    case legacyV1 = 1
    case agencyV2 = 2
}
```

- `agencyState == nil`은 `legacyV1`로 해석한다.
- `PitcherPresetCatalog.balanceVersion`은 계속 투구 물리·성장 밸런스만 맡는다.
- 시즌 결정 생성 여부를 `balanceVersion >= 4`로 가르는 기존 코드는 v1 호환 경로에 남기고, v2에서는 `proRulesVersion`으로 분리한다.
- 새 규칙 상수는 `ProCareerAgencyRules.currentVersion`에 둔다.

### 6.2 플레이 밀도

```swift
public enum ProPlayPace: String, Codable, Sendable {
    case compact   // 시즌당 직접 승부 예산 2
    case standard  // 시즌당 직접 승부 예산 3, 기본값
    case detailed  // 시즌당 직접 승부 예산 5
}
```

- 이 값은 결과에 영향을 주므로 단순 앱 설정이 아니라 서명된 커리어 상태다.
- 계약 직전과 오프시즌에만 변경할 수 있다.
- 베테랑이라는 이유로 예산을 3→2로 자동 삭감하지 않는다.
- 예산은 상한이다. 의미 있는 예정 등판이 없는데 filler 경기를 억지로 만들지 않는다.
- 플레이 밀도는 총등판 수를 바꾸지 않고, 자동 완료할 등판 중 몇 개에 직접 승부를 포함할지만 바꾼다.

### 6.3 기용 계획

```swift
public struct ProUsagePlan: Codable, Equatable, Sendable {
    public let season: Int
    public let role: ProRole
    public let expectedOutings: ClosedRange<Int>
    public let expectedStarts: ClosedRange<Int>
    public let reviewWeek: Int
    public let reasonIDs: [ProUsageReason]
}
```

Swift `ClosedRange`의 Codable 안정성이나 RPC 호환이 불편하면 `minimumOutings`, `maximumOutings`의 명시적 정수 필드로 구현한다.

기용 점수는 0...100의 정수로 중앙화한다.

| 입력 | 초기 비중 | 설명 |
|---|---:|---|
| 현재 능력 | 35% | 구위·제구·변화·체력과 역할 적합도 |
| 최근 2시즌 성적 | 30% | 표본 보정 RA9, K-BB, 맡은 이닝 |
| 현재 시즌 최근 6등판 | 15% | 짧은 흐름이 장기 성적을 덮지 않도록 제한 |
| 감독의 믿음 | 10% | 현재 관계 |
| 계약 보직 약속 | 10% | 계약의 실제 의미 |

구현 규칙은 다음과 같다.

- 작은 표본은 리그 기준으로 수축한다. 1~2경기 무실점이 에이스 점수가 되지 않는다.
- `age`, `season >= 9`는 기용 점수의 직접 입력이 아니다.
- 나이는 기존처럼 능력 하락·부상 위험을 통해 간접적으로만 작용한다.
- 현재 역할은 주 단위로 출렁이지 않는다. 개막, 6주, 13주, 20주, 부상 복귀 시점에서만 재평가한다.
- 역할이 바뀌면 `reasonIDs`와 before/after 예상 등판 범위를 저장하고 자동 진행을 즉시 멈춘다.
- 기존 `rolePreference`는 해당 시즌의 사용자 약속으로 존중하되, 건강·성적상 불가능하면 면담을 연다. 조용히 덮어쓰지 않는다.

비중은 초기값이다. 웨이브 0에서 저장한 기준선과 웨이브 3의 10,000시즌 시뮬레이션으로 조정할 수 있지만, 변경 이유와 before/after 분포를 분석 산출물에 남겨야 한다.

### 6.4 커리어 위상과 후반기 아크

```swift
public enum ProCareerStanding: String, Codable, Sendable {
    case prospect
    case regular
    case established
    case ace
    case clubSymbol = "club_symbol"
}
```

- 위상은 서비스 기간, 최근 성적, 통산 이닝, 수상, 보직을 조합해 계산한다.
- 한 주 부진으로 떨어지지 않도록 승급·강등 임계값에 히스테리시스를 둔다.
- 위상은 허구의 명예 칭호가 아니라 기용 면담의 말투, 역할 안정성, 시즌 목표, 은퇴 회고에 사용한다.
- 저장된 성적이 근거를 충족하지 않으면 `ace`나 `clubSymbol`을 부여하지 않는다.

9시즌 이후 또는 32세 이후에는 나이가 아니라 위상·최근 성적·건강으로 다음 중 하나의 시즌 아크를 연다.

- 기록 도전
- 선발 자리 수성
- 보직 전환
- 부상 복귀
- 마지막 시즌·작별

아크는 문구만 바꾸지 않는다. 기용 계획, 시즌 결정 후보, 직접 승부 트리거, 시즌 결산에 모두 연결한다.

### 6.5 예정 등판과 직접 승부

```swift
public struct ProPendingOuting: Codable, Equatable, Sendable {
    public let id: String
    public let season: Int
    public let week: Int
    public let scheduledIndex: Int
    public let role: ProRole
    public let outsTarget: Int
    public let pitchCap: Int
    public let trigger: ProSeasonTrigger
    public let context: ProPlayableWindow
    public let complementSeed: UInt64
}
```

정확한 필드명은 현재 `ImportantGameScenario`와 RPC 모델을 재사용해도 되지만 다음 정보는 반드시 저장한다.

- 어떤 예정 등판을 예약했는지
- 선발/구원과 목표 아웃·투구 제한
- 상대·라이벌·점수 차·이닝 상황
- 사용자가 던지지 않는 구간을 만드는 고정 시드
- 시즌과 주차, 중복 resolve를 막는 안정 ID

주간 처리 순서는 다음으로 고정한다.

1. 역할·건강·명시적 availability로 예정 등판 슬롯을 만든다.
2. 직접 승부 트리거가 있으면 슬롯 하나를 `pendingOuting`으로 예약한다.
3. 예약되지 않은 슬롯만 자동 시뮬레이션한다.
4. 예약 슬롯은 아직 `currentStats.games`나 `gameLines`에 넣지 않는다.
5. 사용자가 승부처를 완료하면 선발·긴 이닝 구원은 남은 구간을 고정 시드로 자동 보완한다.
6. 사용자 구간과 자동 보완 구간을 합친 `ProGameLine` 한 행을 추가한다.
7. pending을 지우고 해당 주의 등판 회계와 영수증을 완성한다.

사용자가 직접 등판 화면을 닫아도 pending을 버리지 않는다. 같은 상황에서 재시작하게 한다. 자동 포기나 새 시드 재추첨 버튼은 만들지 않는다.

`ProGameLine`에는 하위 호환 옵셔널 필드를 추가한다.

```swift
public let directOuts: Int?
```

- v1 행은 nil이다.
- v2 자동 행은 0이다.
- v2 직접 승부 포함 행은 사용자가 실제로 잡은 아웃 수다.
- v2 행의 `hits`, `homeRuns`는 자동 보완 구간과 직접 승부 구간을 합산한 non-nil 값이어야 한다.
- `ProGameLine`은 수기 디코더를 사용하므로 `directOuts = decodeIfPresent(...)`까지 같은 변경에서 추가한다.

v2 검증에서는 `.importantGame` phase와 `agencyState.pendingOuting != nil`이 정확히 일치해야 한다. v1의 기존 `.importantGame`은 pending outing이 없으므로 규칙 버전별로 검증을 분기한다.

### 6.6 훈련·출전 가능 상태·등판 부하 분리

`ProWeekPlan`의 raw value는 저장·RPC 호환 때문에 유지한다. 의미만 규칙 버전별로 분기한다.

#### v1

- 기존 결과 산식을 유지한다.
- `.recover`는 등판 0회다.
- 안전 패치 UI에서 이 비용을 명시하고 구간 자동 진행을 금지한다.

#### v2

- `.recover`는 **훈련 회복**이다. 성장 0, 훈련 부하 감소, 정상 예정 등판 유지다.
- 등판을 줄이는 선택은 별도 `ProAvailabilityChoice`로 보낸다.

```swift
public enum ProAvailabilityChoice: String, Codable, Sendable {
    case available
    case reducedLoad = "reduced_load"
    case skipNextOuting = "skip_next_outing"
}
```

`PlanProWeekParams` 또는 이를 대체하는 v2 명령에는 하위 호환 옵셔널 `availability`를 추가한다. v1은 nil만 기존 의미로 처리하고, v2는 nil을 `.available`로 정규화한다. RPC·저장 재개 호출자가 새 필드 부재로 실패하지 않아야 한다.

- `available`: 역할에 따른 예정 등판을 유지한다.
- `reducedLoad`: 해당 주 목표 아웃·투구 수를 약 25% 줄인다. 0경기로 만들지 않는다.
- `skipNextOuting`: 예정 슬롯 정확히 1개만 결장 처리한다. 신뢰 비용과 회복 효과를 확인 화면에 표시한다.
- 부상은 선택이 아니라 의료 상태이며 별도 reason ID로 기록한다.
- 한 번의 availability 선택을 다음 주에 자동 재사용하지 않는다.

피로는 다음 한 함수에서 계산한다.

```text
주간 피로 변화 = 훈련 부하 + 실제 등판 부하 - 체력 완화 + 회복 조정
```

초기 튜닝값은 다음으로 시작하고 웨이브 0 기준선과 비교한다.

| 항목 | 초기값 |
|---|---:|
| 구위 훈련 | +10 |
| 변화 훈련 | +8 |
| 제구 훈련 | +6 |
| 체력 훈련 | +7 |
| 신뢰 중심 | +5 |
| 회복 훈련 | -16 |
| 실제 등판 부하 | `ceil(주간 총 투구 수 / 15)` |
| 체력 완화 | `max(0, (stamina - 50) / 15)` |
| reduced load 추가 회복 | -4 |
| 1회 건너뜀 추가 회복 | -8 |

모든 연산은 정수이고 최종 피로는 0...100으로 clamp한다. 상수를 화면이나 여러 엔진 함수에 복제하지 말고 `ProWorkloadRules` 한 곳에 둔다.

이 값은 설계 시작점이지 근거 없는 고정 진리가 아니다. 평균 피로, 부상률, 역할별 이닝, 회복 선택률이 수용 밴드를 벗어나면 상수만 조정하고 이유를 분석 보고서에 기록한다. 수용 밴드를 넓혀 실패를 숨기지 않는다.

### 6.7 기간 결과 영수증

```swift
public struct ProPeriodReceipt: Codable, Equatable, Sendable {
    public let id: String
    public let season: Int
    public let startWeek: Int
    public let endWeek: Int
    public let selectedPlan: ProWeekPlan
    public let availability: ProAvailabilityChoice
    public let scheduledOutings: Int
    public let autoResolvedOutings: Int
    public let pendingDirectOutings: Int
    public let missedOutings: Int
    public let statsDelta: ProStatsDelta
    public let abilityDelta: ProAbilityDelta
    public let fatigueDelta: Int
    public let managerTrustDelta: Int
    public let catcherTrustDelta: Int
    public let reasonIDs: [ProFeedbackReason]
    public let resolvedConsequenceIDs: [String]
    public let stopReason: ProAdvanceStopReason
}
```

영수증은 자유 문장이 아니라 수치와 안정 ID를 저장한다. 화면은 항상 다음 순서로 보여 준다.

1. **선택:** 몇 주 동안 무엇을 선택했는가
2. **결과:** 등판·선발·이닝·승패·세이브·K/BB·RA9 변화
3. **몸과 성장:** 성장 게이지, 능력 상승, 피로·부상
4. **반응:** 감독·포수·기용 계획이 왜 바뀌었는가
5. **다음:** 자동 진행이 멈춘 이유와 바로 선택할 행동

`advanceSegment()`는 다음 중 하나가 생기면 즉시 멈추고 정확한 `stopReason`을 남긴다.

- 구간 경계
- 시즌 결정
- 직접 승부 예약
- 역할·레벨·소속·위상·기용 범위 변화
- 부상 발생 또는 복귀
- 지연 결과 회수
- 주요 기록
- 시즌 종료

현재처럼 신뢰·피로 두 숫자만 보여 주는 `progressSummary`를 규칙 원본으로 쓰지 않는다. UI는 `ProPeriodReceipt`를 렌더링한다.

### 6.8 시즌 결정과 지연 결과

시즌 결정은 현재의 6·13·20주, 최대 3회를 유지한다. 기존 3·6·9·12·15·18·21주 기록은 호환용으로만 읽는다.

```swift
public struct ProPendingConsequence: Codable, Equatable, Sendable {
    public let id: String
    public let sourceDecisionID: String
    public let trigger: ProConsequenceTrigger
    public let kind: ProConsequenceKind
    public let previewID: String
}
```

각 선택은 다음을 가진다.

- 즉시 수치 효과 1개 묶음
- 미리 공개되는 지연 효과 1개
- 다음 직접 등판, 다음 구간, 시즌 결산 중 하나의 발동 시점
- 성공·실패 또는 관계 반응을 설명하는 안정 ID

동시에 열린 지연 결과는 최대 2개다. 세 번째가 생기려 하면 가장 이른 것을 먼저 회수할 수 있는 선택지만 제안하거나, 시즌 결산형으로 병합한다. 숨은 큐를 무한히 쌓지 않는다.

예시:

- “포수와 함께 짠다” → 포수 신뢰 즉시 상승 + 다음 직접 승부에서 1안/2안 위험 설명 정확도 상승
- “내 공을 밀어붙인다” → 변화구 성장 + 다음 직접 승부에서 같은 패턴이 통하면 감독 반응, 읽히면 반대 반응
- “몸을 관리한다” → 피로 감소 + 다음 기용 재평가에서 reduced load 없이 예정 범위 유지 여부 확인

후속 결과는 숨은 결과 조작이 아니라 이미 공개한 약속을 회수해야 한다.

### 6.9 포수 1안·2안·직접 선택

코어의 `PitchPreparation`에 이미 1안과 2안이 있다. UI를 열기 전에 다음 계약을 추가한다.

- 두 안은 구종·코스·존 의도·강도 중 최소 한 축이 다르다.
- 이득과 위험 구조가 달라야 한다. 동일 상황에서 한 안이 모든 공개 지표를 지배하면 생성 실패로 본다.
- 2안은 “나쁜 안”이 아니라 다른 실패 비용을 가진 안이다.
- 포수 신뢰와 스카우팅 품질은 설명·추천 정확도를 높이지만 정답을 보장하지 않는다.
- 타자 적응과 최근 배합은 추천 평가에 포함한다.

`CatcherCard`는 다음 세 경로를 같은 정보 계층에 둔다.

- 포수 1안: 한 탭 적용
- 포수 2안: 한 탭 적용
- 직접 수정: 기존 구종·코스·존 의도·강도 편집

각 안에는 정확한 확률 대신 짧은 정성 태그를 표시한다.

- 노리는 이득: 예) 약점 정면 공략, 뜨거운 코스 회피, 카운트 선점
- 감수하는 위험: 예) 장타 위험, 볼넷 위험, 반복 노출
- 포수 확신: 낮음·보통·높음

매 투구마다 모달 선택을 강제하지 않는다. 현재 선택을 명확히 보여 주고 1안·2안을 한 탭으로 바꿀 수 있게 한다. `holdCall`과 체크포인트 저장은 1안/2안/직접의 실제 선택을 함께 보존하도록 확장한다.

정책 밸런스는 다음 네 전략으로 검증한다.

1. 1안만 계속 수락
2. 1안과 2안 중 공개 정보로 더 나은 쪽 선택
3. 공개 정보와 최근 배합을 읽어 직접 수정
4. 같은 콜 반복

2·3번은 숨은 RNG 결과를 미리 보는 oracle이 아니다. 사용자에게 공개된 상태만 사용한다.

---

## 7. 저장 호환과 마이그레이션

### 7.1 원칙

- 진행 중 v1 시즌은 v1로 끝낸다.
- 안전 패치는 UI 명령 범위만 줄이고 기록을 재작성하지 않는다.
- 새 규칙 전환은 계약 직전 또는 오프시즌의 원자적 명령 안에서만 한다.
- `.seasonDecision`, `.importantGame`, 부상 처리 중간에는 전환하지 않는다.
- 완료된 커리어는 마이그레이션하지 않는다.

### 7.2 전환 표

| 저장 상태 | 처리 |
|---|---|
| 새 커리어, 계약 전 | 계약 시 rollout 대상이면 v2 생성 |
| v1 주간 진행 중 | 현재 시즌 v1 유지, 안전 패치만 적용 |
| v1 시즌 결산·오프시즌 | 선택 적용과 같은 원자적 저장에서 v2 생성 |
| v1 중요 경기 pending | 기존 방식으로 먼저 resolve한 뒤 시즌 경계에서 전환 |
| v1 시즌 결정 pending | 기존 결정 먼저 적용, 시즌 경계에서 전환 |
| v2 | 항상 저장된 v2 규칙으로 진행 |
| completed | 그대로 보존 |

### 7.3 보존 항목

다음은 전환 전후 값이 같아야 한다.

- `proCareerID`, 선수 정체성, 구단, 나이, 시즌, 서비스 기간
- 투수 능력과 구종 프로필
- 완료 시즌 기록, 현 시즌 완료 기록, 수상, 주요 기록
- 계약, 역할, 감독·포수 신뢰, 부상
- `nextSeed`
- v1에서 이미 생성된 pending·결정 기록

v2 초기 `standing`과 `usagePlan`은 보존된 성적에서 결정론적으로 파생한다. 마이그레이션 자체는 RNG를 소비하지 않는다.

### 7.4 서명

- `agencyState == nil`이면 현재 commitment 문자열을 한 글자도 바꾸지 않는다.
- `agencyState != nil`일 때만 `agency:v2:<canonical-hash>`를 추가한다.
- nested enum raw value, 배열 순서, 수치만 canonical 입력에 넣는다. 현지화 문구는 넣지 않는다.
- `pendingOuting`, `pendingConsequences`, `lastReceipt`의 변조를 검출한다.
- 마이그레이션은 두 번 실행해도 두 번째 결과가 완전히 같아야 한다.

### 7.5 롤아웃과 중단

코어가 원격 설정을 직접 읽지 않는다. 앱이 계약·오프시즌 경계에서만 목표 규칙 버전을 명령에 전달한다.

초기 rollout은 `StableHash(proCareerID) % 100`의 고정 버킷을 사용한다.

1. 내부·TestFlight v2 100%
2. 프로덕션 신규 계약 10%, 기존 커리어 마이그레이션 0%
3. 신규 50%, 시즌 경계 마이그레이션 10%
4. 신규·마이그레이션 100%

중단 빌드는 신규 전환 비율만 0으로 만든다. 이미 v2인 저장을 v1으로 되돌리지 않는다.

---

## 8. 구현 웨이브

한 웨이브의 수용 기준과 증거를 끝내기 전에 다음 웨이브를 시작하지 않는다. 단, 한국어 원고 초안은 시스템 의미가 확정된 화면부터 병행할 수 있다.

### 웨이브 0 — 재현 픽스처와 기준선

**목표:** 무엇을 고치는지 수치로 고정한다. 제품 동작은 바꾸지 않는다.

작업:

1. `recover + advanceSegment` 한 번으로 여러 주 0경기가 되는 iOS 회귀 테스트를 추가한다.
2. 자동 등판 뒤 중요 경기를 resolve하면 같은 주의 경기 수가 추가되는 현재 동작을 characterization test로 고정한다. 이 테스트는 v2 구현 때 새 기대값으로 바꾼다.
3. 시즌 10 이상, 최근 2시즌 RA9 2.00 미만·10승 이상·건강한 선수를 만드는 픽스처를 추가한다.
4. v3, v4, 시즌 결정 pending, 중요 경기 pending 저장 JSON을 골든 픽스처로 보관한다.
5. `simulation-cli`에 프로 커리어 다중 시즌·정책 시뮬레이션 명령을 추가한다.
6. 1,000시드 기준선을 아래 경로에 저장한다.

```text
artifacts/analysis/pro-career-agency-baseline-2026-08-13/
  README.md
  career-distribution.json
  pitch-policy-distribution.json
  veteran-usage.json
  recovery-flow.json
```

기준선에는 평균만 쓰지 말고 median, p10, p90, elite tail을 포함한다.

수용 기준:

- 현재 결함이 테스트에서 실제로 재현된다.
- 기존 `npm run check:balance`가 통과해도 리뷰 증상을 잡지 못한다는 차이가 문서화된다.
- 골든 저장 4종이 현재 빌드에서 decode·resume된다.

### 웨이브 1 — 안전 패치

**목표:** 한 번의 회복 선택이 여러 주 미등판으로 번지는 즉시 결함을 RNG 변경 없이 막는다.

작업:

1. `MobileCareerStore.selectedPlan`을 선택 해제가 가능한 상태로 바꾸거나, 회복 실행 직후 반드시 재선택을 요구하는 동등한 상태를 만든다.
2. v1에서 `.recover`가 선택되면 `advanceSegment()`와 `advanceBlock()`을 비활성화한다.
3. 회복 카드는 “이번 주 등판 없음 · 피로 회복 · 성장 없음”을 실행 전에 표시한다.
4. 회복은 `advanceWeek()` 한 번만 허용하고 실행 뒤 선택을 해제한다.
5. 일반 계획의 구간 진행 버튼은 반복 주 수와 중단 조건을 버튼 아래 표시한다.
6. 결과 요약에 최소한 진행 주 수, 경기·선발·이닝, 신뢰, 피로를 보여 준다.
7. 저장 실패 시 UI·주간 과제·분석 이벤트가 함께 rollback되는 기존 원자성 테스트를 유지한다.

주요 파일:

- `apps/ios/Sources/MobileCareerStore.swift`
- `apps/ios/Sources/CareerFlowView.swift`
- `apps/ios/Sources/Localization/Localizable.xcstrings`
- `apps/ios/Tests/ProSeasonDecisionTests.swift`

수용 기준:

- 회복을 고른 상태에서 구간 진행 API가 코어를 2회 이상 호출하지 않는다.
- 한 번의 회복은 정확히 1주·0경기·피로 -20의 v1 결과다.
- 일반 계획의 v1 시드 결과와 `nextSeed`는 패치 전과 같다.
- VoiceOver가 회복의 등판 비용을 버튼 실행 전에 읽는다.

이 웨이브는 별도 핫픽스로 출시할 수 있다.

### 웨이브 2 — v2 상태·서명·마이그레이션 골격

**목표:** 행동을 바꾸기 전에 저장 계약을 완성한다.

작업:

1. `ProCareerAgencyState`와 하위 안정 타입을 새 코어 파일에 추가한다.
2. `ProCareerSnapshot`에 `agencyState` 하나를 추가하고 생성자, 수기 `==`, `replacing(...)`을 함께 수정한다.
3. commitment v1/v2 분기를 추가한다.
4. 계약·오프시즌 경계의 idempotent 마이그레이션을 추가한다.
5. v2 검증기를 추가하되 아직 기본 rollout은 0%로 둔다.
6. RPC Codable 왕복과 `simulation-cli` 출력을 갱신한다.

권장 파일 분리:

- `packages/simulation-core/Sources/SimulationCore/ProCareerAgency.swift`
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerAgencyPersistenceTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/BalanceV3CompatibilityTests.swift`

수용 기준:

- v3/v4 골든 저장의 JSON decode, commitment 검증, 다음 명령 결과가 이전과 같다.
- v1 저장에는 `agencyState`가 없어도 정상 동작한다.
- 마이그레이션을 두 번 요청해도 snapshot과 `nextSeed`가 같다.
- pending 상태에서는 마이그레이션을 거부하고 안전한 오류를 낸다.
- 변조된 pending outing·consequence·receipt는 검증에서 거부된다.

### 웨이브 3 — 기용·부하·예정 등판 회계

**목표:** 회복과 기용, 자동 경기와 직접 경기를 구조적으로 분리한다.

작업:

1. 기존 `planWeek`를 v1 경로로 보존하고 v2 경로를 추가한다.
2. `ProUsageRules`, `ProWorkloadRules`, 예정 등판 슬롯 생성을 코어에 구현한다.
3. v2 `.recover`와 `ProAvailabilityChoice`를 구현한다.
4. `ProPendingOuting` 예약 → 직접 승부 → 자동 보완 → 한 행 합성을 구현한다.
5. `directOuts`와 v2 등판 회계 검증을 추가한다.
6. `ProPeriodReceipt`를 모든 주·구간 진행 결과에 생성한다.
7. `advanceSegment()`가 receipt stop reason을 기준으로 멈추게 한다.

권장 파일 분리:

- `packages/simulation-core/Sources/SimulationCore/ProCareerSchedule.swift`
- `packages/simulation-core/Sources/SimulationCore/ProWorkloadRules.swift`
- `packages/simulation-core/Sources/SimulationCore/ProCareerAgency.swift`
- `apps/ios/Sources/MobileCareerStore.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerScheduleTests.swift`
- `apps/ios/Tests/ProCareerReceiptTests.swift`

수용 기준:

- v2 회복+available은 성장 0, 피로 감소, 역할에 맞는 예정 등판 유지다.
- `skipNextOuting`은 정확히 슬롯 1개만 결장 처리한다.
- 선발 직접 승부는 자동 보완과 합쳐 게임 1회로 기록되고 목표 이닝 밴드를 유지한다.
- pending 상태 저장·재개·resolve 결과가 중단 없는 실행과 같다.
- `currentStats`와 `gameLines` 합계가 v2 시즌에서 항상 일치한다.
- 직접 플레이 밀도를 바꿔도 같은 역할·건강 조건의 총 예정 등판 수는 같다.

### 웨이브 4 — 커리어 위상·기용 면담·후속 반응

**목표:** 장기 성적이 대우와 이야기로 이어지게 한다.

작업:

1. `ProCareerStanding`과 히스테리시스 규칙을 구현한다.
2. 시즌 시작·6·13·20주·부상 복귀의 기용 재평가를 구현한다.
3. 기용이 의미 있게 바뀌면 자동 진행을 멈추고 이유·대안을 보여 준다.
4. 시즌 결정 3회에 `ProPendingConsequence`를 연결한다.
5. 베테랑 시즌 아크를 기용·직접 승부·결산에 연결한다.
6. 현 선수의 위상·올해 목표·다음 등판을 계승 정보보다 위에 배치한다.
7. `ProPeriodReceipt` 전체 UI를 완성한다.

기용 면담의 최소 선택:

- 현재 역할을 받아들인다.
- 기존 역할에 다시 도전한다. 요구 조건과 위험을 공개한다.
- 조건이 되면 FA를 검토한다.
- 후반기에는 마지막 시즌 또는 은퇴를 선택할 수 있다.

수용 기준:

- 건강하고 최근 두 시즌 RA9 2.50 이하, 시즌당 360아웃 이상인 선수가 나이만으로 2회 이하 기용 계획을 받지 않는다.
- 위 선수의 역할을 두 단계 이상 낮추려 하면 엔진 검증이 실패한다.
- 기용 변화에는 항상 하나 이상의 reason ID와 사용자 확인 국면이 있다.
- 시즌 결정의 후속 결과가 정확히 한 번 발생하고 저장 재개 후 중복되지 않는다.
- 20시즌 완주에서 현 선수의 목표가 은퇴 전에 계승 UI보다 우선한다.

### 웨이브 5 — 포수 대안과 투구 정책 밸런스

**목표:** 포수 말을 따르는 것이 자동 정답이 아니라 판단의 출발점이 되게 한다.

작업:

1. recommendation trade-off 안정 타입과 검증기를 추가한다.
2. 중복·지배 관계가 있는 1안/2안 생성을 테스트에서 거부한다.
3. `PitchSession`에 1안·2안 적용과 체크포인트 복원을 추가한다.
4. `CatcherCard`에 두 안의 이득·위험·확신을 대칭 배치한다.
5. 선택 출처를 `primary`, `alternative`, `manual`로 기록한다.
6. 4개 정책의 커리어·투구 시뮬레이션을 `check:pro-career`에 추가한다.

주요 파일:

- `packages/simulation-core/Sources/SimulationCore/PitchKernelDomain.swift`
- `packages/simulation-core/Sources/SimulationCore/PitchKernelEngine.swift`
- `apps/ios/Sources/PitchSession.swift`
- `apps/ios/Sources/PitchView.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/PitchKernelEngineTests.swift`
- `apps/ios/Tests/PitchSessionTests.swift`
- `tools/check-pro-career.mjs`

수용 기준은 10절의 밸런스 게이트를 모두 만족해야 한다.

### 웨이브 6 — 한국어 재작성·사람 검수·출시

**목표:** 새 시스템의 원인과 결과를 자연스럽고 오해 없이 전달한다.

작업:

1. 프로 계약 → 주간 계획 → 결과 영수증 → 직접 승부 → 기용 면담 → 베테랑 → 은퇴의 한국어 화면 목록을 만든다.
2. 장면, 화자, 감정, 사용자가 알아야 할 행동을 먼저 정의하고 한국어 원고를 작성한다.
3. 한국어 의미가 승인된 뒤 영어를 같은 의미로 갱신한다. 기계 번역을 최종 원고로 쓰지 않는다.
4. `check-korean-game-copy.mjs`가 프로 Swift와 `.xcstrings`의 한국어 값을 기본 검사하게 확장한다.
5. 최소 5명의 한국어 사용자로 전체 프로 경로 과업 검사를 한다.
6. 최소 20쌍의 프로 문구 블라인드 A/B를 실제 응답으로 평가한다.
7. rollout 버킷과 분석 이벤트를 활성화한다.

사람 과업 검사에서 모든 평가자는 다음 질문에 답해야 한다.

- 회복을 고르면 이번 주 등판이 있는가
- 구간 진행은 몇 주 동안 같은 계획을 반복하는가
- 직접 승부가 시즌 경기 수에 추가되는가, 예정 경기 안에 포함되는가
- 기용이 바뀐 이유는 무엇인가
- 선택의 후속 결과는 언제 확인하는가
- 다음에 할 행동은 무엇인가

수용 기준:

- 핵심 행동 6문항은 5명 전원이 정답이어야 한다.
- 개작 선호율 80% 이상, AI 느낌 중앙값 2 이하, 가독성 중앙값 4 이상이다.
- 합성 응답을 실제 평가 근거로 사용하지 않는다.
- `check:copy`, `check:korean-copy:ci`, `check:ios-localization`이 모두 통과한다.

---

## 9. 파일별 구현 지도

| 파일/영역 | 책임 |
|---|---|
| `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` | v1/v2 명령 분기, 시즌 전환, 검증, 기존 호환 |
| `ProCareerAgency.swift` 신규 | aggregate 상태, receipt, consequence, standing, play pace 타입 |
| `ProCareerSchedule.swift` 신규 | 역할별 예정 슬롯, pending 예약, 직접/자동 합성 |
| `ProWorkloadRules.swift` 신규 | 훈련·등판·체력·회복 부하의 단일 원본 |
| `LeagueBaseline.swift` | `ProGameLine.directOuts` 하위 호환 필드 |
| `PitchKernelDomain.swift` | 추천 대안의 이득·위험 안정 모델 |
| `PitchKernelEngine.swift` | 비지배 1안/2안 생성·검증 |
| `apps/ios/Sources/MobileCareerStore.swift` | 원자적 명령, receipt 전달, 자동 진행 중단, 분석 이벤트 |
| `apps/ios/Sources/CareerFlowView.swift` | 계획·availability·기용·영수증 UI |
| `apps/ios/Sources/PitchSession.swift` | 1안/2안/직접 선택과 저장 재개 |
| `apps/ios/Sources/PitchView.swift` | 대칭 비교 CatcherCard |
| `apps/ios/Sources/ProCareerPresentation.swift` | 안정 ID→현지화 문구, legacy 문자열 어댑터 |
| `Localizable.xcstrings`, `GameContent.xcstrings` | 한국어 원본과 영어 의미 동기화 |
| `tools/check-balance.mjs` | 기존 투구·등판 평균 회귀 유지 |
| `tools/check-pro-career.mjs` 신규 | 시즌 tail, 정책, 기용, 회복, 회계 게이트 |
| `tools/check-korean-game-copy.mjs` | 프로 Swift·xcstrings 기본 검사 확장 |

새 Swift 파일을 앱 타깃에 추가하면 `apps/ios/project.yml`을 원본으로 Xcode 프로젝트를 재생성하고 diff를 확인한다. SimulationCore의 새 파일은 SwiftPM 타깃 포함 여부를 확인한다.

---

## 10. 테스트와 출시 게이트

### 10.1 하드 정합성 게이트

다음은 수치 튜닝과 무관하게 한 건이라도 실패하면 출시하지 않는다.

- 회복 한 번이 사용자 재확인 없이 두 주 이상 반복되지 않는다.
- v2 예정 등판 회계 등식이 모든 테스트 시드에서 성립한다.
- v2 안정 상태의 `currentStats`와 `gameLines` 합계가 일치한다.
- 직접 승부가 총 경기 수를 추가하지 않는다.
- pending 직접 승부의 저장·재개·중복 제출이 안전하다.
- 건강한 우수 베테랑의 설명 없는 급격한 기용 축소가 없다.
- 지연 결과가 0회 또는 2회 이상 적용되지 않는다.
- v3/v4 골든 저장이 decode·resume된다.
- v1 시드 결과가 의도하지 않게 바뀌지 않는다.
- 저장 실패가 화면·과제·분석 상태까지 원자적으로 rollback된다.
- 실제 야구 IP 문자열이 새 콘텐츠에 없다.

### 10.2 프로 시즌 시뮬레이션 게이트

CI의 `npm run check:pro-career`는 역할·프리셋을 층화해 정책당 최소 1,000시즌을 실행한다. 릴리스 후보의 `npm run check:pro-career -- --release`는 정책당 최소 10,000시즌을 실행하고 tail 판정은 이 결과로 한다.

| 지표 | 초기 수용 범위 |
|---|---:|
| 1안 전용 선발 평균 RA9 | 3.2~5.0 |
| 1안 전용 qualified 시즌 중 RA9 < 2.00 이고 10승 이상 | 5% 이하 |
| 공개 정보 기반 1안/2안 선택의 직접 통제 구간 실점 개선 | 1안 전용 대비 5~15% |
| 공개 정보 기반 직접 수정의 직접 통제 구간 실점 개선 | 1안 전용 대비 5~18% |
| 같은 콜 반복의 피안타율 | 1안 전용보다 최소 0.03 높음 |
| 2안이 공개 정보상 더 적합한 상태 비율 | 25~60% |
| 건강한 선발의 시즌 예정 선발 | 20~24회 |
| 직접 플레이 밀도별 총 예정 등판 차이 | 0 |

`qualified`는 우선 시즌 360아웃 이상으로 정의한다. 역할상 이 기준이 맞지 않는 구원은 별도 이닝·세이브 밴드를 둔다.

초기 수용 범위가 웨이브 0 기준선과 심하게 충돌하면 숫자를 조용히 바꾸지 않는다. 분석 산출물에 다음을 남긴 뒤 한 번만 재설정한다.

- 기존 분포
- 새 분포
- 리뷰 증상과 연결되는 tail
- 변경 이유
- 초보자·숙련자에 미치는 영향

### 10.3 기용 시나리오 게이트

표 테스트를 최소 다음 경우로 만든다.

1. 35세, 최근 2시즌 우수, 건강, 선발 약속 → 선발 범위 유지
2. 35세, 최근 2시즌 부진, 건강 → 면담 후 한 단계 역할 전환 가능
3. 29세, 우수하지만 부상 → 부상 reason으로 일시 결장
4. 24세, 작은 표본 무실점 → 즉시 에이스 승격 금지
5. `clubSymbol`이지만 현재 능력 급락 → 설명 있는 보직 전환, 무조건 선발 보장 아님
6. FA 자격 있음·기용 축소 → 이동 선택 노출
7. FA 자격 없음·기용 축소 → 존재하지 않는 선택 미노출
8. 20시즌째 → 강제 종료 규칙과 마지막 시즌 아크 일치

### 10.4 UI·접근성 게이트

- 회복 카드가 등판 여부를 VoiceOver로 먼저 읽는다.
- Dynamic Type 최대 접근성 크기에서 1안/2안의 이득·위험이 잘리지 않는다.
- 색만으로 1안·2안·직접 선택을 구분하지 않는다.
- 결과 영수증의 핵심 수치는 한 화면에서 읽기 순서가 선택→결과→이유→다음이다.
- 직접 승부 화면을 종료·복귀해도 같은 pending 상황이 열린다.
- “직접 승부 포함”과 “자동 완료”를 기록 행에서 구분할 수 있다.
- RA9를 평균자책점으로 읽거나 표기하지 않는다.

### 10.5 명령

각 웨이브의 관련 테스트 뒤, 릴리스 후보에서는 아래 전체 게이트를 실행한다.

```sh
npm run check:copy
npm run check:korean-copy:ci
npm run test:korean-copy
npm run check:ios-localization
npm run check:design-system
npm run check:balance
npm run check:pro-career
swift test --package-path packages/simulation-core

cd apps/ios
xcodegen generate
xcodebuild test \
  -project Baseball.xcodeproj \
  -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=<available iPhone>' \
  -only-testing:BaseballIOSTests
```

로컬에 지정 기기가 없으면 임의로 부팅하기 전에 `xcrun simctl list devices available`로 사용 가능한 기기를 확인한다. 실행하지 못한 실기기·접근성 검증을 “통과”로 기록하지 않는다.

---

## 11. 분석 이벤트와 제품 검증

이벤트 이름은 `GameAnalytics.Event`의 기존 규칙을 따른다. 개인정보나 자유 문장을 보내지 않는다.

| 이벤트 | 필수 속성 |
|---|---|
| `pro_plan_selected` | rules_version, season, week, plan, availability, predicted_outings |
| `pro_period_advanced` | rules_version, weeks, scheduled, auto, pending, missed, stop_reason, fatigue_delta, trust_delta |
| `pro_usage_plan_changed` | old_role, new_role, old_range, new_range, reason_id, standing |
| `pro_direct_outing_reserved` | season, week, role, trigger, play_pace |
| `pro_direct_outing_resolved` | role, direct_outs, total_outs, resumed, completion_time_bucket |
| `pro_pitch_strategy_summary` | 경기 종료 시 primary_count, alternative_count, manual_count, changed_axes_count, 직접 통제 투구 수 |
| `pro_consequence_resolved` | source_decision_type, consequence_kind, trigger |
| `pro_rules_migrated` | from_version, to_version, season_boundary |

투구 선택 이벤트를 매 공마다 전송하지 않는다. 기존 `PitchSession.gameFinishedAnalyticsMetrics`에 집계하고 경기 종료 시 한 번만 보낸다. 정확성 지표와 제품 지표를 분리한다.

### 정확성 지표

- accidental multiweek recovery: 0
- unexplained usage drop: 0
- duplicate pending resolution: 0
- save/migration failure: 0
- stats/gameLines mismatch: 0

### 학습 지표

- 1안 선택률 40~75%를 초기 건강 범위로 본다. 90% 이상이면 선택이 장식일 가능성이 높고, 20% 미만이면 포수가 무능해 보일 가능성이 높다.
- 2안 또는 직접 수정 사용률 25% 이상을 목표로 한다.
- 결과 영수증 이후 바로 다음 행동을 완료하는 비율을 기존 요약 대비 비교한다.
- 베테랑 시즌의 직접 승부 완료율과 기용 면담 후 계속 플레이율을 별도로 본다.

최소 200개 v2 시즌 완료와 30개 후반기 시즌 완료 전에는 장기 몰입 개선을 확정적으로 주장하지 않는다. 표본이 부족하면 방향성만 보고 규칙을 크게 재조정하지 않는다.

---

## 12. 한국어 작성 규칙

1. 한 문장은 “상태 설명”보다 플레이어가 방금 한 행동과 다음 행동을 먼저 쓴다.
2. `결과`, `정리`, `확인`, `다음`, `차분히`, `증명` 같은 범용 단어를 장면마다 반복하지 않는다.
3. 감독, 포수, 기록 화면의 목소리를 구분한다.
4. 수치가 이미 보이면 같은 수치를 추상 문장으로 다시 말하지 않는다.
5. 손해를 완곡하게 숨기지 않는다. “회복합니다”만 쓰지 말고 등판 0회 또는 예정 등판 유지 여부를 함께 쓴다.
6. “ERA”를 자연스럽게 번역하려 하지 말고 실제 모델인 “9이닝당 실점”을 쓴다.
7. 현 선수의 은퇴 전 화면에서 “다음 세대”를 주된 보상으로 앞세우지 않는다.
8. 외부 게임의 대사를 말뭉치처럼 복사하지 않는다.
9. 실존 구단·리그·선수·별칭과 혼동되는 문구가 없는지 `check:copy`로 확인한다.

기본 한국어 검사 대상에 다음을 포함한다.

- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift`
- 프로 agency 신규 Swift 파일
- `apps/ios/Sources/ProCareerPresentation.swift`
- `apps/ios/Sources/MobileCareerStore.swift`
- `apps/ios/Sources/CareerFlowView.swift`
- `apps/ios/Sources/PitchView.swift`
- `apps/ios/Sources/Localization/Localizable.xcstrings`
- `apps/ios/Sources/Localization/GameContent.xcstrings`

---

## 13. AI 에이전트 실행 규칙

1. 시작할 때 `git status --short`를 읽고 기존 사용자 변경을 보존한다. 이 문서 작성 시점의 Android/Unity 변경은 다른 작업이므로 수정·정리·되돌리기 금지다.
2. 한 웨이브만 작업 범위로 잡는다. 웨이브 1과 v2 구조 개편을 한 PR에 섞지 않는다.
3. 현재 코드를 사실의 원본으로 삼고, 오래된 문서의 12시즌·7회 결정·중요 경기 상한을 그대로 옮기지 않는다.
4. 게임 결과 규칙은 SimulationCore에 두고 SwiftUI에서 복제 계산하지 않는다.
5. `ProCareerSnapshot`을 바꾸면 생성자, 수기 `==`, `replacing(...)`, Codable 왕복, commitment, 구저장 테스트를 한 작업으로 수정한다.
6. v1 경로를 삭제하거나 “깨끗하게 정리”하지 않는다. rollout과 구저장 때문에 유지한다.
7. 새로운 RNG 소비를 추가하기 전에 어느 스트림을 소비하는지 테스트 이름과 코드 주석에 적는다.
8. 골든 시드가 바뀌면 “테스트 재베이스라인”으로 덮지 말고 v1/v2 중 어느 계약이 바뀌었는지 먼저 증명한다.
9. 숫자 상수를 화면에 복제하지 않는다. rules 타입을 단일 원본으로 사용한다.
10. 현지화 문장을 snapshot의 새 필드에 저장하지 않는다.
11. 정적 검사 결과를 사람 검수로, 합성 설문 응답을 실제 사용자 평가로 주장하지 않는다.
12. 각 웨이브 완료 시 이 문서의 수용 기준별 테스트 이름·명령·결과를 별도 evidence 문서에 남긴다.

### 즉시 중단 조건

다음 중 하나가 발생하면 다음 웨이브로 진행하지 말고 원인을 해결한다.

- v3/v4 저장이 열리지 않거나 다음 명령 결과가 달라진다.
- v1 RNG 결과가 설명 없이 바뀐다.
- 직접 승부가 추가 경기로 남거나 선발 이닝을 한 이닝으로 축소한다.
- 회복 선택의 등판 효과를 카드에서 알 수 없다.
- 건강한 우수 베테랑을 reason ID 없이 강등·미기용한다.
- 1안 또는 2안이 모든 공개 지표에서 항상 우월하다.
- 결과 영수증이 엔진 데이터가 아니라 UI 추측으로 만들어진다.
- 신규 한국어에 실존 야구 IP가 포함된다.
- 기존 Android/Unity 사용자 변경과 충돌한다.

---

## 14. 리뷰 문장별 완료 판정

| 리뷰의 문제 | 완료로 보는 증거 |
|---|---|
| “뭘 선택하든 반응이 없다” | 모든 자동 진행에 receipt가 있고 시즌 결정의 지연 결과가 한 번 회수된다. |
| “휴식 딸깍, 훈련 딸깍” | 회복 다주 반복 0건, 훈련·availability·기용이 분리되고 구간 결과가 집계된다. |
| “포수가 시키는 대로면 된다” | 1안 전용 elite tail 5% 이하, 공개 정보 기반 선택이 5~15% 개선, 2안 사용 상태 25~60%. |
| “1점대·10승이 무난하다” | 10,000시즌 tail 게이트와 역할별 분포가 CI에서 검증된다. 기술 표기는 RA9로 정확하다. |
| “말년에 1년에 2번만 던진다” | 직접 플레이와 총등판이 분리되고, 건강한 우수 베테랑의 예정 선발 20~24회 및 기용 이유가 보인다. |
| “팀 레전드를 쩌리 취급한다” | 성적 기반 standing, 후반기 아크, 기용 면담, 은퇴 회고가 같은 저장 근거를 사용한다. |
| “다음 세대를 위한 재물” | 은퇴 전 정보 구조에서 현 선수의 위상·목표·다음 등판이 계승보다 우선한다. |
| “한국어를 읽어도 무슨 말인지 모르겠다” | 핵심 행동 6문항 5/5 정답, 5명 블라인드 평가와 정적 검사가 모두 통과한다. |

---

## 15. 완료 정의

### 코드 완료

- 웨이브 0~6의 하드 수용 기준을 모두 통과했다.
- v1 안전 패치와 v2 규칙이 별도 경로로 존재한다.
- 저장·결정론·등판 회계·정책 밸런스·현지화 테스트가 CI에 들어갔다.
- 새 분석 이벤트와 개인정보 선언이 실제 구현과 일치한다.
- 현재 규칙을 설명하는 ADR, QA 게이트, iOS/Android 패리티 문서의 시즌 수·직접 등판 의미가 갱신됐다.
- Android 구현은 별도 작업으로 명확히 남았고 기존 변경을 건드리지 않았다.

### 제품 검증 완료

- 프로덕션 v2에서 정확성 지표가 모두 0이다.
- 최소 200개 v2 시즌과 30개 후반기 시즌 표본이 있다.
- 1안 선택률이 건강 범위에 있고 2안·직접 판단이 실제로 사용된다.
- 베테랑 기용 변화의 reason ID 누락이 없다.
- 한국어 실제 평가 결과가 저장소 evidence에 있고 합격 기준을 만족한다.
- 리뷰의 여섯 과업 질문을 새 사용자가 설명할 수 있다.

코드가 merge되었다는 이유만으로 이 문제를 해결 완료로 표시하지 않는다. 안전 패치 출시, v2 rollout, 실제 시즌 표본과 사람 검수까지 끝났을 때 최종 완료다.
