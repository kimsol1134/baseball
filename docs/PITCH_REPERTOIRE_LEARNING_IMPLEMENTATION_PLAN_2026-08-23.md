# 캐릭터 구종 선택·신규 구종 학습 최종 구현 계획

| 항목 | 값 |
|---|---|
| 문서 상태 | 구현·검증 완료 |
| 기준일 | 2026-08-23 |
| 1차 범위 | 공유 Swift 코어 + iOS + Windows 계약 호환 |
| 핵심 대상 | 고교 커리어, 프로 직행 생성, 프로 커리어 승계, 직접 투구 |
| 지원 구종 | 포심, 슬라이더, 커브, 체인지업 |
| 신규 실제 구종 추가 | 1차 범위에서 제외 |

> 구현 감사(2026-08-23): 공유 코어, 저장/RPC/스키마, iOS/Windows UI, ko/en/ja,
> 분석 이벤트, 자동 경기, 밸런스 게이트와 정적·단위·빌드 검증을 완료했다. iPhone 17 Pro
> iOS 26.5 시뮬레이터에서 §11.3 시나리오 1–8을 하나의 실제 UI 종주 테스트로 통과했고,
> 접근성 최대 글자 크기에서 오프닝 진입과 구종 선택·주력 지정·시작 버튼 접근도 별도
> 검증했다. 개발 구종 해금·앱 재실행 복원·기본 수동 투구 슬라이더 제스처까지 통과했다.

## 0. 최종 결론

첫 구현은 다음 구조로 확정한다.

1. 모든 신규 선수는 **포심 + 플레이어가 고른 변화구/오프스피드 2개**, 총 3개의 실전 구종으로 시작한다.
2. 슬라이더·커브·체인지업 중 고르지 않은 1개는 첫 `학습 구종`이 된다.
3. 시작 구종 3개 중 하나를 `주력 구종`으로 플레이어가 지정한다.
4. 학습 구종은 훈련으로 `그립 탐색 → 불펜 반복 → 실전 준비` 단계를 거친다.
5. 실전 준비가 끝나면 직접 투구에서 사용할 수 있는 `개발 구종`이 된다.
6. 추가 훈련과 실전 과정 평가를 충족하면 `보조 구종`으로 완성된다.
7. 학습 과정은 0–100 경험치 막대가 아니라 **세 단계와 작은 완료 조건**으로 보여 준다.
8. 직접 투구는 새 구종을 포함해 항상 기존 **투구 슬라이더를 기본 조작**으로 사용한다.

이 결정의 이유는 간단하다. 두 구종 시작은 성장 서사는 강하지만 초반 수싸움을 약하게 만들고, 네 구종 전부 시작은 현재와 같아 학습의 의미가 없다. 세 구종 시작은 첫 경기부터 배합이 성립하면서도 “내가 아직 못 던지는 한 공”이라는 명확한 성장 목표를 남긴다.

---

## 1. 사용자 관점 비판 검토

### 1.1 앞선 안: 포심 + 첫 결정구, 두 구종 시작

**장점**

- 첫 선택이 강하게 기억된다.
- 새 구종 해금의 보상이 크다.
- 초보자가 처음 보는 선택지가 적다.

**치명적인 문제**

- 이 게임의 직접 투구 재미는 구종·코스·노림·힘 배분과 라이벌의 반복 학습에서 나온다. 두 구종만 있으면 초반 중요 경기에서 구종 반복을 피할 선택지가 빠르게 고갈된다.
- 프롤로그가 끝난 뒤에도 한동안 `빠른 공/느린 공`의 이분법에 머물 수 있다.
- 성장 콘텐츠를 보여 주기 위해 핵심 전투 콘텐츠를 일부러 빈약하게 만드는 구조다.
- 첫 훈련 몇 번을 변화구 학습에 쓰지 않은 플레이어는 “육성 자유”를 선택했는데 실제 투구 재미가 덜한 벌을 받는다.
- 회차 반복 시 매번 초반 배합이 빈약해져 로그라이트 재시작 피로가 커진다.

**판정: 기각.** 신규 구종의 보상을 키우기 위해 초반 핵심 재미를 희생하면 안 된다.

### 1.2 현재 구조 유지: 네 구종을 모두 주고 역할만 선택

**장점**

- 밸런스·세이브·투구 엔진 변경이 작다.
- 경기 선택지는 처음부터 풍부하다.

**문제**

- 이름만 `개발 구종`이고 실제로는 처음부터 던질 수 있어 “배운다”는 사건이 없다.
- 역할 선택은 숫자·추천 빈도의 변화일 뿐, 플레이어가 새 능력을 얻었다고 느끼기 어렵다.
- 기존 자동 승격은 화면 연출과 선택이 없어 기억에 남지 않는다.

**판정: 기각.** 구현 비용은 낮지만 사용자가 요청한 콘텐츠의 핵심을 충족하지 못한다.

### 1.3 처음부터 실제 구종 7종 이상으로 확장

예: 투심, 커터, 포크 계열을 즉시 추가하는 안.

**장점**

- 장기 학습 후보가 많다.
- 선수별 구종 조합 차이가 크게 난다.

**문제**

- 이 프로젝트의 구종은 단순 이름이 아니다. 구속, 제구, 움직임, 헛스윙, 약한 타구, 피로, 이상적인 높이, 타자 약점, 포수 추천, 라이벌 적응, 궤적 렌더가 함께 움직인다.
- 구종 수와 학습 시스템을 동시에 바꾸면 재미가 없을 때 원인이 “학습 루프”인지 “신규 구종 밸런스”인지 분리할 수 없다.
- 모바일 투구 화면에 6~7개 구종을 바로 노출하면 한 구의 결정 시간이 늘어난다.
- 스키마, TypeScript, Android/Unity 픽스처까지 한 번에 흔들린다.

**판정: 1차 범위에서 기각.** 학습 루프가 검증된 뒤 별도 설계·밸런스 작업으로 진행한다.

### 1.4 숫자형 0–100 학습 게이지

**장점**

- 이해와 구현이 쉽다.
- 보상량 조절이 편하다.

**문제**

- 훈련을 누를 때마다 숫자만 오르면 기존 능력치 훈련과 감정적으로 구분되지 않는다.
- 69와 70 사이에서 갑자기 공식 경기 사용이 열리는 이유가 서사적으로 약하다.
- “몇 번 더 눌러야 하나”만 남아 반복 노동으로 읽힐 위험이 크다.

**판정: 내부 계산에만 제한적으로 사용.** 화면은 단계, 완료 표식, 다음 행동을 보여 준다.

### 1.5 삼진·무실점 같은 좋은 결과로만 완성

**문제**

- 좋은 선택과 좋은 실행 뒤에 안타를 맞을 수 있는 게임 철학과 충돌한다.
- 결과 RNG 때문에 학습이 막히면 투구 엔진에 대한 불신이 커진다.
- 접근성 자동 릴리스 사용자가 불리해질 수 있다.

**판정: 기각.** 실전 완성은 릴리스·실행 품질과 사용 경험으로 평가하고 타석 결과는 조건에 넣지 않는다.

---

## 2. 반드시 지킬 제품 원칙

### 2.1 직접 투구의 재미를 먼저 보호한다

- 신규 선수도 첫 공식 경기부터 실전 구종 3개를 가진다.
- 투구 슬라이더는 기본 조작으로 계속 노출한다.
- 새 구종을 처음 던질 때도 자동 연출로 대신하지 않는다.
- 포수 추천은 도움일 뿐, 학습 구종을 강제로 던지게 하지 않는다.

### 2.2 선택은 정체성이어야 하고 함정이 아니어야 한다

- 어떤 두 변화구를 골라도 시작 능력 총예산은 동일하다.
- 추천 조합은 제공하지만 비추천 선택을 잠그지 않는다.
- 학습 구종 선택 때문에 영구적으로 손해 보는 프리셋을 만들지 않는다.
- 주력 구종 지정은 포수 추천과 표현에 영향을 주되 숨은 결과 보정은 만들지 않는다.

### 2.3 학습은 확실히 전진한다

- 대상 구종 훈련은 능력치 성장 RNG와 별개로 최소 1의 연습 진전을 보장한다.
- 재능 벽 때문에 능력치가 0 상승이어도 학습 단계는 전진한다.
- 부상 재활로 강제된 회복 훈련에는 학습 진전을 주지 않는다.
- 실전 검증을 못 만나도 추가 훈련으로 완성할 수 있는 우회 경로를 둔다.

### 2.4 기존 플레이어의 것을 빼앗지 않는다

- 구세이브의 모든 `pitchProfiles`는 실전 사용 가능 상태로 읽는다.
- 진행 중인 회차에 새 시작 구종 규칙을 소급하지 않는다.
- 구세이브의 `.development` 역할 구종도 계속 경기에서 사용할 수 있어야 한다.

### 2.5 세계관·현지화 규칙을 지킨다

- 신규 코치, 학교, 대회, 구단 문구는 독자적인 가상 명칭만 쓴다.
- 실존 구단명, 약칭, 선수명, 로고, 유니폼 문양, 슬로건을 넣지 않는다.
- iOS 공개 바이너리용 문구는 한국어·영어·일본어를 함께 완료한다.

---

## 3. 최종 사용자 경험

### 3.1 신규 선수 생성: `나의 구종 구성`

선수 유형을 고른 뒤, 생성 포인트를 확정하기 전에 한 화면을 추가한다.

#### 기본 규칙

- 포심은 기본 선택이며 해제할 수 없다.
- 슬라이더·커브·체인지업 중 정확히 2개를 시작 구종으로 고른다.
- 선택하지 않은 1개는 화면 하단의 `고교에서 배울 구종`으로 즉시 표시한다.
- 실전 구종 3개 중 정확히 1개를 주력 구종으로 지정한다.

#### 첫 사용자 기본값

화면 진입 시 프리셋별 추천 구성을 미리 선택해 둔다. 사용자는 그대로 계속하거나 바꿀 수 있다.

| 프리셋 | 추천 시작 변화구 | 추천 주력 | 첫 학습 구종 |
|---|---|---|---|
| 강속구 원석 | 슬라이더 + 체인지업 | 포심 | 커브 |
| 정교한 제구형 | 슬라이더 + 체인지업 | 체인지업 | 커브 |
| 변화구 아티스트 | 슬라이더 + 커브 | 슬라이더 | 체인지업 |
| 체력형 선발 | 커브 + 체인지업 | 포심 | 슬라이더 |

이 표는 UX 기본값이며 우열을 만들기 위한 보너스 표가 아니다.

#### 화면 카드에 보여 줄 정보

- 구종명.
- 프리셋 기준 예상 구속.
- `헛스윙`, `속도 차`, `범타`, `초기 제구` 중 핵심 태그 2개.
- 잘 맞는 대표 용도 한 줄.
- 초반 위험 한 줄.
- 현재 선택 상태: `시작 구종`, `주력`, `나중에 학습`.

#### 재도전 UX

- 두 번째 삶부터 직전 구성을 기본값으로 복원한다.
- `지난 구성 그대로`를 한 번에 확정할 수 있다.
- 다른 구성을 고르면 환생 비교 화면에 `구종 구성 변경`을 기록한다.

### 3.2 훈련 화면: `구종 연구`

기존 변화구 훈련을 선택했을 때 다음을 표시한다.

1. 보유 변화구 다듬기.
2. 현재 학습 구종 연구.

학습 구종을 선택하면 일반 변화구 성장과 함께 학습 진전이 발생한다. 별도 재화는 만들지 않는다. 이미 존재하는 훈련 기회와 피로가 비용이다.

#### 화면 표현

```text
구종 연구 · 커브

✓ 그립 탐색
● 불펜 반복  3 / 5
○ 실전 준비

다음: 같은 릴리스를 두 번 더 반복하면 공식 경기에서 시험할 수 있습니다.
이번 훈련: 연습 진전 +2 · 피로 +8 전망
```

- 전체 0–100 퍼센트는 표시하지 않는다.
- 현재 단계, 누적 표식, 다음 해금 조건을 표시한다.
- 훈련 결과 카드에는 능력 성장과 학습 진전을 별도 행으로 보여 준다.
- 성장 0이어도 `커브 반복 감각 +2`가 보이면 눌렀는데 아무 일도 없었다고 느끼지 않는다.

### 3.3 학습 단계와 정확한 규칙

내부 값은 `practiceCredits`를 사용한다. UI는 단계와 단계 내 표식만 보여 준다.

| 단계 | 조건 | 공식 경기 사용 | 훈련 선택 가능 |
|---|---:|---|---|
| 그립 탐색 | 0–1 | 불가 | 가능 |
| 불펜 반복 | 2–4 | 불가 | 가능 |
| 실전 준비 | 5 이상 | 가능, `개발 구종` | 가능 |
| 보조 구종 완성 | 아래 완성 조건 | 가능, `보조 구종` | 가능 |

#### 훈련 1회당 연습 진전

| 강도 | 진전 |
|---|---:|
| 가볍게 | +1 |
| 표준 | +2 |
| 집중 | +3 |

적용 조건:

- 실제 선택 focus가 `.breakingBall`이어야 한다.
- `targetPitch`가 활성 학습 구종과 일치해야 한다.
- 재활 강제 훈련이 아니어야 한다.
- 진전은 RNG를 소비하지 않는다.
- 기존 능력치 성장, 잭팟, 재능 벽, 피로, 팔 위험 규칙은 그대로 적용한다.

#### 실전 준비 전환

`practiceCredits >= 5`가 되는 확정 훈련 결과에서 다음을 동시에 처리한다.

- 해당 프로필을 공식 경기 사용 가능 상태로 전환한다.
- 역할은 `.development`로 유지한다.
- 뉴스/연대기에 첫 해금 사건을 기록한다.
- 다음 중요 경기의 포수 추천 후보에 낮은 가중치로 포함한다.
- 투구 화면에 `개발 중` 배지를 표시한다.

#### 보조 구종 완성

다음 두 경로 중 하나를 만족하면 완성한다.

**실전 가속 경로**

- `practiceCredits >= 7`.
- `qualityUses >= 2`.

**훈련 전용 우회 경로**

- `practiceCredits >= 9`.

완성 시:

- 역할을 `.development`에서 `.secondary`로 바꾼다.
- 포수 추천의 개발 구종 감점을 제거한다.
- `새 구종 완성` 결과 카드와 연대기 사건을 1회만 보여 준다.
- 동일 구종에 대해 완성 보상을 중복 지급하지 않는다.

### 3.4 실전 과정 평가

`qualityUse`는 타석 결과와 무관하다.

#### 수동 투구 슬라이더

- 해당 개발 구종을 던짐.
- `DeliveryScoring.score(delivery) >= 65` 또는 커널 `executionQuality >= 650`.

#### 접근성 자동 릴리스

- 해당 개발 구종을 던짐.
- 커널 `executionQuality >= 600`.

#### 공통 제한

- 한 타석에서 최대 1회.
- 한 등판에서 최대 2회.
- 삼진, 안타, 볼넷, 실점 여부는 조건에 넣지 않는다.
- 몸에 맞는 공처럼 명백히 위험한 실행은 execution 기준을 통과하지 않으므로 별도 결과 벌점은 만들지 않는다.

등판 종료 시 `ImportantInningReport`에 구종별 실전 사용 영수증을 실어 커리어 엔진이 검증·반영한다. iOS 화면이나 스토어가 학습 상태를 직접 수정하면 안 된다.

### 3.5 경기 화면

- 공식 경기 구종 목록에는 실전 사용 가능한 프로필만 표시한다.
- 잠긴 구종은 비활성 버튼으로 남기지 않고 경기 화면에서 숨긴다.
- 개발 구종에는 `개발 중` 배지를 붙인다.
- 첫 개발 구종 선택 시 한 번만 “완성 전이라 코스가 흔들릴 수 있다”는 설명을 보여 준다.
- 이후에는 일반 구종과 같은 투구 슬라이더·코스·노림·힘 배분 흐름을 사용한다.
- 포수가 개발 구종을 추천할 때는 추천 이유에 성장 상태가 아니라 현재 상황상 필요한 이유를 먼저 말한다.

---

## 4. 코어 데이터 계약

### 4.1 `PitchProfileSnapshot` 확장

`packages/simulation-core/Sources/SimulationCore/Domain.swift`

```swift
public enum PitchAvailability: String, Codable, Sendable {
    case locked
    case gameReady = "game_ready"
}

public struct PitchProfileSnapshot: Codable, Equatable, Sendable {
    // 기존 필드 유지
    public let availability: PitchAvailability?

    public var isGameReady: Bool {
        availability == nil || availability == .gameReady
    }
}
```

호환 규칙:

- `availability == nil`은 구버전 프로필이며 반드시 실전 사용 가능으로 읽는다.
- 신규 회차의 모든 프로필은 `locked` 또는 `gameReady`를 명시한다.
- `role`은 전술적 지위, `availability`는 사용 가능 여부다. 둘을 합치지 않는다.
- `.development` 역할이라고 잠긴 것으로 간주하면 안 된다. 구세이브의 개발 구종은 `availability == nil`이므로 계속 사용할 수 있어야 한다.

모든 프로필 재생성 함수는 `availability`를 보존해야 한다. 다음 경로를 전수 검색한다.

```bash
rg "PitchProfileSnapshot\(" packages/simulation-core apps/ios
rg "profile\.role" packages/simulation-core
```

### 4.2 학습 프로젝트

`packages/simulation-core/Sources/SimulationCore/PitchLearning.swift` 신규.

```swift
public enum PitchLearningStage: String, Codable, Sendable {
    case grip
    case bullpen
    case liveTrial = "live_trial"
    case completed
}

public struct PitchLearningProjectSnapshot: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let practiceCredits: Int
    public let qualityUses: Int
    public let stage: PitchLearningStage
    public let startedChapter: Int?
    public let completedChapter: Int?
}

public struct StartingRepertoireSelection: Codable, Equatable, Sendable {
    public let readyBreakingPitches: [PitchType]
    public let primaryPitch: PitchType
    public let learningPitch: PitchType
}
```

검증 규칙:

- `readyBreakingPitches`는 정확히 2개이며 중복이 없어야 한다.
- 값은 슬라이더·커브·체인지업만 허용한다.
- `learningPitch`는 나머지 정확히 1개여야 한다.
- `primaryPitch`는 포심 또는 준비된 두 변화구 중 하나여야 한다.
- 포심은 항상 실전 가능이어야 한다.
- 신규 규칙 회차에는 정확히 3개의 game-ready 프로필과 1개의 locked 프로필이 있어야 한다.
- 프로젝트의 구종은 locked/game-ready 개발 프로필과 동일한 안정 ID를 가져야 한다.
- `practiceCredits`는 0...9 이상을 허용하되 저장에는 상한 9로 clamp한다.
- `qualityUses`는 0...2로 clamp한다.
- 단계는 점수에서 파생해 검증하고 클라이언트가 임의 단계를 보내지 못하게 한다.

### 4.3 고교 스냅숏

`HighSchoolCareerSnapshot`에 다음 옵셔널 필드를 추가한다.

```swift
public let repertoireRulesVersion: Int?
public let pitchLearningProject: PitchLearningProjectSnapshot?
```

- 신규 회차는 `repertoireRulesVersion = 1`.
- 구세이브는 nil이며 기존 네 프로필을 모두 준비된 것으로 취급한다.
- 두 필드는 존재할 때만 `stateCommitment`에 추가한다.
- `==`, init, replacing, normalize, start, rebirth, draft/legacy 경로에 모두 전달한다.

### 4.4 프로 스냅숏

`ProCareerSnapshot`에도 동일한 두 필드를 추가한다.

```swift
public let repertoireRulesVersion: Int?
public let pitchLearningProject: PitchLearningProjectSnapshot?
```

- 고교 출신은 현재 프로젝트를 그대로 승계한다.
- 프로 직행 신규 선수도 `StartingRepertoireSelection`을 받는다.
- 구버전 프로 저장은 nil이며 모든 기존 프로필을 준비된 것으로 취급한다.
- 프로 commitment에 필드가 있을 때만 canonical token을 추가한다.

### 4.5 시작 파라미터

다음 타입에 옵셔널 선택을 추가한다.

- `StartHighSchoolCareerParams.startingRepertoire`
- `StartProCareerParams.startingRepertoire`

호환 규칙:

- 키가 없으면 legacy 시작으로 처리해 기존 테스트·RPC fixture를 깨지 않는다.
- 새 iOS/Windows 생성 UI는 항상 값을 보낸다.
- `repertoireRulesVersion = 1`인데 selection이 없으면 코어가 거부한다.
- legacy 시작과 신규 시작을 UI 추측으로 구분하지 말고 명시 버전으로 구분한다.

### 4.6 훈련 결과 영수증

`CareerTrainingSnapshot`에 옵셔널 필드를 추가한다.

```swift
public let pitchLearning: PitchLearningReceiptSnapshot?
```

영수증에는 다음을 포함한다.

- pitchType.
- stageBefore / stageAfter.
- practiceCreditsBefore / after.
- justUnlockedForGames.
- justCompleted.

UI는 결과를 재계산하지 않고 이 영수증만 렌더한다.

### 4.7 중요 경기 영수증

`ImportantInningReport`에 다음을 옵셔널로 추가한다.

```swift
public let pitchLearningUses: [PitchLearningUseReceipt]?
```

```swift
public struct PitchLearningUseReceipt: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let pitchesThrown: Int
    public let qualityUses: Int
}
```

- 세션은 원시 공 로그에서 집계한다.
- 커리어 엔진은 활성 프로젝트 구종만 반영한다.
- qualityUses는 등판당 최대 2인지 다시 검증한다.
- 필드가 없는 구버전 리포트는 학습 진전 0으로 처리한다.

---

## 5. 엔진 규칙과 상태 전이

### 5.1 시작 선수 변환

`PitcherPresetCatalog`의 네 프로필 템플릿은 그대로 보존한다. 신규 회차 시작 시 별도 변환 함수가 역할과 availability를 정한다.

```swift
PitchRepertoireRules.apply(
    selection: StartingRepertoireSelection,
    to: preset.pitcher
) -> (pitcher: PitcherSnapshot, project: PitchLearningProjectSnapshot)
```

결과:

- primaryPitch 프로필: `.primary`, `.gameReady`.
- 다른 준비 구종 2개: `.secondary`, `.gameReady`.
- learningPitch: `.development`, `.locked`.
- 물리 프로필 수치는 프리셋 템플릿 그대로 유지.

역할 재지정 자체는 능력치를 바꾸지 않는다.

단, 세 구종 시작에서 “어느 구종을 나중에 배우는가”가 숨은 난이도 선택이 되지 않도록
잠긴 구종의 초기 전술 가치를 준비된 두 변화구에 임시 분산한다. 현재 v1 보정은 다음과 같다.

- 슬라이더 학습: 준비된 두 변화구에 커맨드 +10, 헛스윙 +10, 범타 +4.
- 커브 학습: 준비된 두 변화구에 커맨드 +5, 헛스윙 +5, 범타 +3.
- 체인지업 학습: 추가 보정 없음.

이 값은 `practiceCredits >= 5`로 학습 구종이 실전 해금되는 순간 정확히 회수한다. 따라서
초기 세 구종 구간만 균형을 맞추고, 네 구종 완성 뒤의 장기 능력 총량은 프리셋 원본과 같다.
보정과 회수는 프로필에 공개되는 값만 바꾸며 숨은 결과 보정을 만들지 않는다.

### 5.2 공식 투구 검증

다음 모든 경로에서 locked 프로필을 제외한다.

- `PitchSession.repertoire`.
- `PitchKernelEngine.validate`.
- `CatcherRecommendationEngine` 후보.
- `PitchKernelEngine` 내부 추천 후보.
- `AutoOutingSimulator`.
- 튜토리얼/중요 경기/프로 경기 시나리오 생성.
- Windows `preparePitch`/`submitPitch`.

커널 경계는 `pitcher.profile(for:) != nil`만 확인하지 말고 `profile.isGameReady`까지 확인한다.

### 5.3 성장 규칙

현재 `PitcherGrowthRules.grow`의 자동 개발→보조 승격은 신규 규칙에서 비활성화한다.

- `profile.availability == nil`: legacy 자동 승격 동작 유지.
- `profile.availability != nil`: 학습 프로젝트 엔진만 역할을 승격할 수 있음.

이 분기가 없으면 능력치 합이 임계값을 넘는 순간 프로젝트 단계를 건너뛸 수 있다.

### 5.4 훈련 커밋

`HighSchoolCareerEngine.commitTraining` 순서:

1. 기존 단계·상태·훈련 횟수 검증.
2. 기존 성장 RNG와 능력치 성장 계산.
3. 피로·팔 위험·재활 계산.
4. 대상이 활성 학습 구종이면 deterministic practice credit 계산.
5. 프로젝트 stage 파생.
6. 5점 도달 시 profile availability를 gameReady로 전환.
7. 완성 조건 충족 시 role을 secondary로 전환.
8. training receipt, news, state commitment 확정.

학습 진전은 기존 RNG 소비 순서를 바꾸지 않는다. 진전 계산 때문에 `generator.next...`를 추가 호출하지 않는다.

프로의 `resolveDevelopment`도 동일한 `PitchLearningRules`를 호출해야 하며 별도 임계값을 만들지 않는다.

### 5.5 대상 검증 강화

현재 legacy 호출은 잘못된 `targetPitch`를 nil로 정규화해 전체 변화구 성장으로 처리할 수 있다. 신규 규칙에서는 다음을 거부한다.

- 포심을 변화구 학습 대상으로 전달.
- 프로필에 없는 구종.
- 활성 프로젝트가 아닌 locked 구종.
- 이미 완성된 구종을 학습 프로젝트 대상으로 전달.

legacy nil 호출만 기존 `전체 변화구 분산 성장` 의미를 유지한다.

### 5.6 실전 반영

`recordImportantGame` / `resolveImportantGame`에서:

1. 리포트의 프로젝트 구종 사용만 추출.
2. 기존 qualityUses에 더하되 2로 clamp.
3. `practiceCredits >= 7 && qualityUses >= 2`면 완성.
4. 완성 사건은 기록 반영과 같은 revision에서 확정.
5. 앱 종료 후 경기 완료 후속 작업이 재실행되어도 중복 완성되지 않게 pending receipt를 멱등 처리.

---

## 6. iOS 구현 계획

iOS 17+의 기존 Observation 구조를 유지한다. 신규 전역 ViewModel을 만들지 않는다.

### 6.1 생성 화면

대상:

- `apps/ios/Sources/HighSchoolSetupView.swift`
- `apps/ios/Sources/CareerSetupView.swift`
- `apps/ios/Sources/CareerBootstrap.swift`

구성 요소:

- `StartingRepertoireCard`
- `PitchSelectionRow`
- `PrimaryPitchSelector`
- `LearningPitchSummary`

상태 소유:

- 아직 확정 전인 선택은 생성 화면의 `@State` 값 타입으로 소유한다.
- 프리셋이 바뀌면 그 프리셋 추천값으로 재설정하되, 같은 프리셋 안의 사용자 변경은 보존한다.
- 코어 start가 성공한 뒤에만 저장 상태가 된다.

필수 preview:

- 기본 추천 구성.
- 사용자가 추천을 변경한 구성.
- Dynamic Type 접근성 크기.
- 영어 긴 구종 설명.
- 일본어 구성.

### 6.2 훈련 화면

대상:

- `HighSchoolTrainingViews.swift`
- `HighSchoolTrainingResultViews.swift`
- `ProWeeklyPlanView.swift`

변경:

- 보유 구종과 학습 구종을 같은 segmented picker에 억지로 섞지 않는다.
- `TrainingPitchTargetCard` 안에서 `보유 구종`과 `구종 연구` 섹션으로 구분한다.
- 활성 프로젝트 상세가 필요하면 로컬 `@State var presentedProject: PitchLearningProjectSnapshot?`와 `.sheet(item:)`을 사용한다.
- 시트는 자신의 닫기 동작을 소유하고 `dismiss()`를 호출한다.
- 확정 콜백에는 `PitchType` 안정 ID만 넘긴다.

### 6.3 경기 화면

대상:

- `PitchSession.swift`
- `PitchView.swift`
- `PitchViewParts.swift`
- `PitchCopy.swift`

변경:

- `repertoire`에서 `isGameReady`만 반환.
- 개발 구종 표시용 `PitchDevelopmentBadge` 추가.
- resume 시 저장된 selectedPitchType이 더 이상 game-ready가 아니면 포수 새 사인으로 복원.
- 구종 수가 3→4로 변해도 OptionRow 탭 크기 44pt 이상 유지.
- VoiceOver 레이블에 `개발 구종` 상태 포함.
- 투구 슬라이더 접근성 식별자와 기본 노출 조건은 변경하지 않는다.

### 6.4 스토어

대상:

- `HighSchoolCareerStore+Progress.swift`
- `HighSchoolCareerStore+ImportantGame.swift`
- `MobileCareerStore.swift`

원칙:

- 스토어는 코어 영수증을 표시 상태로 옮기기만 한다.
- 스토어가 practiceCredits, stage, qualityUses를 계산하지 않는다.
- 생성 선택 외에는 여러 boolean modal 상태를 만들지 않는다.
- 완료 축하가 동일 revision에서 두 번 나타나지 않도록 receipt ID 또는 revision을 기준으로 소비한다.

---

## 7. Windows·스키마·다른 플랫폼

공유 코어의 Codable 계약이 바뀌므로 iOS UI만 구현하고 끝내면 안 된다.

### 7.1 JSON Schema

갱신 대상:

- `schemas/pitch-kernel.schema.json`
- `schemas/high-school-career.schema.json`
- `schemas/pro-career.schema.json`
- `schemas/pitcher-lab.schema.json`은 해당 기능을 노출할 때만 확장하되 새 optional 필드 디코딩은 확인.

새 필드는 모두 구세이브 호환을 위해 optional로 시작한다.

### 7.2 Windows TypeScript

갱신 대상:

- `apps/windows/src/simulationTypes.ts`
- `HighSchoolCareerView.tsx`
- `ProCareerView.tsx`
- 생성/자동 저장 관련 테스트.

1차 완료 기준:

- 신규 필드를 손실 없이 저장·복원.
- 잠긴 구종을 투구 버튼에서 비활성화가 아니라 숨김.
- 신규 생성에서 iOS와 동일한 3+1 선택 가능.
- 플랫폼별 다른 기본 구성을 만들지 않음.

### 7.3 Android/Unity

- Swift oracle fixture에 새 optional 필드가 생겨도 기존 파서가 깨지지 않는지 확인한다.
- Android 구현이 이번 PR 범위가 아니라면 신규 규칙 회차 생성을 노출하지 않는다.
- 신규 규칙을 노출하는 플랫폼에서는 투구 슬라이더형 직접 조작을 기본값으로 검증한다.
- fixture 재생성은 해당 플랫폼 계약 테스트가 요구할 때만 수행하고 생성 산출물은 보존 정책에 맞게 정리한다.

---

## 8. 저장·마이그레이션

### 8.1 고교 iOS 저장

- `HighSchoolCareerPersistence.currentSchemaVersion`을 3으로 올린다.
- v1/v2 레코드는 repertoire 필드 nil로 복원한다.
- nil 상태에서 프로필을 잠그거나 역할을 다시 쓰지 않는다.
- v3 쓰기부터 신규 필드를 보존한다.

### 8.2 프로 iOS 저장

- 현재 journey schema 계열을 유지하면서 repertoire 필드를 지원하는 새 버전을 추가한다.
- journey 저장을 legacy schema로 낮춰 쓰지 않는 기존 보호 규칙을 유지한다.
- 고교→프로 진입 시 `StartProCareerParams`에 학습 프로젝트를 명시적으로 전달한다.

### 8.3 commitment

구저장 해시 보존이 최우선이다.

- repertoireRulesVersion이 nil이면 canonical 문자열을 절대 바꾸지 않는다.
- 값이 있을 때만 다음 토큰을 append한다.

```text
repertoire:v1:<primary>:<ready-sorted>:<learning>:<credits>:<quality>:<stage>
```

- ready 목록은 rawValue 정렬 후 해시한다.
- profile availability와 project가 모순되면 validate에서 거부한다.
- 손상 저장은 기존 정책대로 원본을 덮지 않고 백업 복구 경로를 사용한다.

### 8.4 진행 중 경기 복구

- `PitchSession.ResumeState.selectedPitchType`이 복원된 시나리오 repertoire에 있는지 확인한다.
- 없으면 `holdCall = false`로 두고 다음 포수 추천을 받는다.
- pitch log의 과거 locked/ready 표시는 결과 기록이므로 삭제하지 않는다.

---

## 9. 밸런스 기준

### 9.1 학습 속도 목표

- 표준 훈련만 사용하면 3회째 실전 준비 직전 또는 도달, 4회 이내 확정.
- 집중 훈련이면 2회째 불펜 반복, 3회 이내 실전 준비.
- 가벼운 훈련만 사용하면 5회에 실전 준비.
- 실전 가속 경로는 훈련 전용 경로보다 보통 1회 빠르게 완성.
- 고교 3년 동안 학습에 전혀 투자하지 않는 선택도 유효하되 기존 세 구종의 완성도가 더 높아야 한다.

### 9.2 성능 목표

10,000회 이상 시뮬레이션에서 다음을 확인한다.

- 시작 변화구 조합별 드래프트 점수 평균 차이 2점 이내.
- 특정 learningPitch 선택의 평균 실점 차이가 5%를 넘지 않음.
- 3구종 집중형과 4구종 완성형의 전체 성적이 한쪽으로 일방적이지 않음.
- 4구종형은 라이벌 적응과 좌우/속도 배합에서 이득, 3구종형은 개별 프로필 완성도에서 이득.
- 포수의 개발 구종 추천 비율은 game-ready 직후 전체 사인의 5~15% 범위.
- 개발 구종 반복 사용이 최적 전략이 되지 않음.

### 9.3 UX 목표

- 첫 생성 화면에서 80% 이상이 45초 안에 구종 구성을 확정.
- 학습 훈련 뒤 90% 이상이 “다음에 무엇을 하면 되는지” 설명 가능.
- 첫 실전 해금 사용자의 60% 이상이 다음 중요 경기에서 새 구종을 한 번 이상 자발적으로 사용.
- `왜 아직 못 던지는지 모르겠다` 피드백 10% 미만.
- 새 기능 이후 한 공 결정 시간 중앙값이 기존 대비 15% 이상 증가하지 않음.

---

## 10. 분석 이벤트

공 단위 외부 분석은 추가하지 않는다. 기존 개인정보·옵트인 원칙을 유지하고 집계만 기록한다.

### 신규 이벤트

`repertoire_selected`

- preset_id
- ready_pitch_ids
- primary_pitch_id
- learning_pitch_id
- life_number
- used_recommended_default

`pitch_learning_training_completed`

- pitch_id
- stage_before / stage_after
- intensity_id
- credits_gained
- just_game_ready
- just_completed

`pitch_learning_game_summary`

- pitch_id
- pitches_thrown
- quality_uses_gained
- completed_after_game
- manual_delivery_rate

### 금지

- 공 하나마다 이벤트 전송.
- 실제 사용자 이름을 pitch 학습 이벤트에 포함.
- 렌더된 현지화 문자열을 ID 대신 전송.

---

## 11. 테스트 계획

### 11.1 공유 코어 단위 테스트

신규 `PitchLearningRulesTests.swift`:

- 정확히 2개의 시작 변화구만 허용.
- 중복 구종 거부.
- 포심을 learningPitch로 보내면 거부.
- primary가 준비 목록 밖이면 거부.
- 신규 시작 결과가 3 ready + 1 locked.
- legacy availability nil은 모두 game-ready.
- locked pitch submit 거부.
- locked pitch catcher 추천 제외.
- locked pitch 자동 경기 제외.
- light/standard/intensive credit가 1/2/3.
- 재활 훈련 credit 0.
- RNG seed 소비가 학습 기능 전후 동일.
- 5점에서만 game-ready 전환.
- 7+2에서 secondary 완성.
- 9+0에서도 훈련 전용 완성.
- 나쁜 결과지만 좋은 실행인 공이 quality use 획득.
- 좋은 결과지만 나쁜 실행인 공은 quality use 미획득.
- 한 타석/등판 cap.
- 완료 멱등성.

기존 테스트 보강:

- `PitcherDevelopmentRulesTests`: availability 보존, 신규 규칙 자동 승격 금지.
- `PitchKernelEngineTests`: locked call 거부, legacy development call 허용.
- `HighSchoolCareerEngineTests`: 시작·훈련·경기·드래프트 승계.
- `ProCareerEngineTests`: 프로 직행과 고교 프로젝트 승계.
- `RoundTripStabilityTests`: 신규 optional 필드 JSON 왕복.
- balance v1–v4 호환 테스트: 기존 commitment 불변.

### 11.2 iOS 단위 테스트

- 추천 기본 구성 생성.
- 사용자 선택 validation.
- training receipt 표시 행.
- game-ready/완성 축하 1회.
- resume selected pitch 유효성.
- 한국어·영어·일본어 구종/단계 copy key 완전성.

### 11.3 UI 테스트

필수 식별자:

```text
setup.repertoire
setup.pitch.slider
setup.pitch.curveball
setup.pitch.changeup
setup.pitch.primary
setup.pitch.learning
hs.training.pitchLearning
hs.training.pitchLearning.stage
pitch.developmentBadge
```

시나리오:

1. 추천 구성 그대로 신규 커리어 시작.
2. 두 변화구를 바꾸고 주력 지정.
3. 변화구 훈련 3회 이상 진행.
4. 해금 전 공식 경기에서 학습 구종이 보이지 않음.
5. 실전 준비 후 경기에서 표시됨.
6. 개발 구종을 투구 슬라이더로 한 구 끝까지 던짐.
7. 앱 종료·복원 후 같은 프로젝트/구종 상태 유지.
8. 접근성 글자 크기에서 구종 선택 카드와 경기 버튼이 잘리지 않음.

### 11.4 검증 명령

구현 에이전트는 관련 범위 완료마다 작은 검증부터 실행한다.

```bash
swift test --package-path packages/simulation-core
npm run test:web
npm run build:web
npm run check:copy
npm run check:ios-localization
npm run check:balance
```

iOS:

```bash
xcodebuild test \
  -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=<기존 프로젝트 시뮬레이터>' \
  -derivedDataPath <기존 안정 DerivedData 경로>
```

새 임시 DerivedData나 새 시뮬레이터를 반복 생성하지 않는다.

---

## 12. 구현 순서

### Phase A — 호환 테스트 고정

예상 1–2일.

- 현재 legacy 프로필/commitment/save fixture 골든 테스트 추가.
- 기존 `.development` 구종이 실제 사용 가능하다는 테스트 추가.
- 현재 RNG/eventHash 기준선 기록.

**완료 조건:** 기능 코드를 넣기 전 구세이브 보호 테스트가 실패 시점을 잡을 수 있음.

### Phase B — 도메인·학습 규칙

예상 3–4일.

- PitchAvailability.
- StartingRepertoireSelection.
- PitchLearningProjectSnapshot.
- PitchLearningRules.
- preset 변환과 validation.
- grow/tuned/migrate의 availability 보존.

**완료 조건:** 코어 테스트만으로 3+1 시작, 5점 해금, 7+2/9 완성이 증명됨.

### Phase C — 고교·프로 상태 머신

예상 4–5일.

- start params.
- snapshot/replacing/equality/commitment.
- 훈련 진전과 결과 receipt.
- 중요 경기 use receipt.
- 고교→프로 승계.
- legacy normalization.

**완료 조건:** 같은 seed/선택/행동의 eventHash가 반복 일치하고 저장 왕복이 성공.

### Phase D — 투구 커널·자동 경기

예상 2–3일.

- locked 검증.
- 포수 추천 필터.
- 직접 투구 repertoire 필터.
- auto outing 필터.
- resume 방어.

**완료 조건:** 잠긴 구종은 어떤 공식 경기 경로에서도 사용되지 않고, 해금 revision부터 모든 경로가 동일하게 인식.

### Phase E — iOS 생성·훈련·경기 UI

예상 4–6일.

- setup 선택 화면.
- 훈련 프로젝트 카드/결과.
- 개발 배지/완성 축하.
- previews, VoiceOver, Dynamic Type.
- ko/en/ja copy.

**완료 조건:** UI 테스트 시나리오 1–8 통과, 기본 투구 슬라이더 회귀 없음.

### Phase F — Windows·스키마 호환

예상 3–4일.

- JSON schema.
- TypeScript types.
- 생성/훈련/경기 표시.
- autosave tests.

**완료 조건:** `test:web`, `build:web`, sidecar smoke 통과.

### Phase G — 밸런스·출시 게이트

예상 3–5일.

- 조합별 대량 시뮬레이션.
- 학습 속도/추천 빈도 조정.
- 세 언어 실제 앱 스모크.
- 실존 명칭 검색.
- 저장 복구와 구버전 회차 검증.

**완료 조건:** §9 수치 게이트와 App Store 다국어 불변 규칙 충족.

총 예상: 20–29 개발일. 신규 실제 구종 추가는 포함하지 않는다.

---

## 13. 구현 에이전트 작업 체크리스트

### 코드를 바꾸기 전

- [x] 현재 dirty worktree를 확인하고 사용자 변경을 덮지 않는다.
- [x] 관련 `AGENTS.md` 불변 규칙을 다시 읽는다.
- [x] Phase A legacy characterization test를 먼저 추가한다.
- [x] `PitchProfileSnapshot` 생성 지점을 `rg`로 전수 목록화한다.

### 코어

- [x] availability nil = legacy ready 규칙 구현.
- [x] 모든 profile copy에서 availability 보존.
- [x] starting selection validation.
- [x] 학습 credit에 RNG 미사용.
- [x] 신규 규칙 자동 승격 차단.
- [x] locked kernel/recommendation/auto outing 차단.
- [x] state commitment 조건부 확장.

### iOS

- [x] 생성 선택은 로컬 `@State` 값 타입.
- [x] 상세 시트는 `.sheet(item:)`.
- [x] 훈련 결과는 코어 receipt 렌더만 수행.
- [x] 구종 선택 탭 44pt 이상.
- [x] 투구 슬라이더 기본 노출 유지.
- [x] ko/en/ja 동시 완료.
- [x] previews와 accessibility identifiers.

### 저장·다른 플랫폼

- [x] 고교 schema v3 migration.
- [x] 프로 journey save downgrade 방지 유지.
- [x] Windows TypeScript/schema/autosave 갱신.
- [x] Android fixture/parser 호환 확인.

### 완료 전

- [x] Swift tests.
- [x] iOS unit/UI smoke.
- [x] web tests/build.
- [x] copy/localization checks.
- [x] balance simulation.
- [x] 실존 구단명·약칭·선수명 검색.
- [x] 임시 빌드·스크린샷·결과 번들 정리.

---

## 14. 1차 범위에서 하지 않을 것

- 투심·커터·포크 계열 실제 구종 추가.
- 구종 삭제·망각·봉인.
- 경기마다 활성 구종 로드아웃 교체.
- 구종 학습 전용 화폐·대기 시간·확률형 아이템.
- 결과 RNG에 따른 학습 실패.
- 구종별 별도 부상 판정.
- 학습을 대신하는 자동 투구 연출.
- 투구 슬라이더를 보조 기능으로 격하.

추가 실제 구종은 이 기능의 사용자 지표를 확인한 뒤 별도 문서로 설계한다. 그때는 구종 하나마다 물리 프로필, 이상적 코스, 타자 상성, 포수 추천, 라이벌 적응, 궤적 렌더, 오디오/카피, 대량 밸런스 테스트를 모두 갖춰야 한다.

---

## 15. 최종 완료 정의

이 기능은 단순히 선택 화면이 생겼다고 완료가 아니다. 다음 문장이 모두 참이어야 완료다.

1. 신규 선수 생성에서 내가 쓸 세 구종과 나중에 배울 한 구종을 직접 정할 수 있다.
2. 첫 공식 경기부터 세 구종으로 충분한 배합 플레이가 가능하다.
3. 학습 훈련은 매번 눈에 보이는 진전을 남긴다.
4. 해금 전 구종은 커널·포수·자동 경기 어디에서도 새어 나오지 않는다.
5. 해금 후에는 직접 투구 슬라이더로 실제 한 구를 던질 수 있다.
6. 실전 결과가 나빠도 좋은 실행은 학습 경험으로 인정된다.
7. 구세이브 플레이어는 기존 구종을 하나도 잃지 않는다.
8. 고교에서 시작한 학습이 프로까지 이어진다.
9. 한국어·영어·일본어에서 같은 규칙과 상태가 보인다.
10. 어떤 시작 조합도 명백한 정답이 아니며, 3구종 집중형과 4구종 완성형 모두 유효하다.
