# 첫 선수 영구결번 난이도 — 최종 구현 계획

| 항목 | 값 |
|---|---|
| 문서 ID | `DOC-PRO-CAREER-RETIRED-NUMBER-BALANCE-2026-08-20` |
| 상태 | **구현 완료 — evidence §16** |
| 기준일 | 2026-08-20 KST |
| 실행 주체 | 이 저장소를 수정하는 AI 에이전트 |
| 제품 범위 | 첫 선수가 환생 없이 구단 영구결번까지 너무 쉽게 도달한다는 피드백 |
| 1차 코드 범위 | `packages/simulation-core`, `apps/ios` |
| 후속 | Kotlin/Android·Unity 패리티. 이번 실행에서 막지 않는다. |
| 비범위 | 환생 횟수 하드 게이트, 명예의 전당 묶기, 12시즌 노가다, 1회차 능력 하드캡 UI, 투구 슬라이더, 실존 구단 IP, 가격·광고 |

이 문서는 AI 에이전트가 위에서 아래로 구현할 수 있는 최종 명세다. 채팅에서 나온 초안보다 **이 문서가 우선**이다. 현재 코드와 이 문서가 충돌하면 기술적 사실은 코드를, 제품 결정은 이 문서를 따른다. 구현 중 상수를 바꿔야 하면 §18 결정 기록에 이유와 before/after 분포를 남긴다.

구현을 시작하기 전에 읽는다.

1. 루트 `AGENTS.md`
2. 이 문서 전체
3. `packages/simulation-core/Sources/SimulationCore/ProCareerJourney.swift`의 `ProRetirementRules`, `ProTeamCareerRecordRules`, `ProCareerRecognitionRules`
4. `packages/simulation-core/Sources/SimulationCore/ProCareer.swift`의 `simulateWeeklyOuting`, `resolveDevelopment`, `reviewSeason`, `currentRulesVersion`
5. `packages/simulation-core/Sources/SimulationCore/DifficultyScale.swift`
6. `packages/simulation-core/Sources/ProCareerDistributionRunner/main.swift`
7. `packages/simulation-core/Tests/SimulationCoreTests/ProCareerLegacyWave4Tests.swift`
8. `apps/ios/Sources/ProRetirementViews.swift`, `apps/ios/Sources/AppShell.swift`의 `CareerDirectionCard`

현재 dirty worktree의 사용자 변경을 reset, checkout, stash, 삭제, 덮어쓰기 하지 않는다.

한 번에 한 웨이브만 구현한다. Wave 0 특성화 테스트 없이 공식을 바꾸지 않는다.

---

## 0. 한 줄 결론

영구결번을 **환생 자물쇠**나 **더 긴 잔류 미션**으로 만들지 않는다.

최선은 공개 조건(마지막 구단 8시즌 · 유산 80 · 팬 60)을 유지한 채, **그 80점이 평범한 선발 출석으로 채워지지 않게** 생산 함수와 유산 가중치를 고치는 것이다.

구단 명예(`clubHall`)는 잔류의 보상으로 남기고, 영구결번은 그 구단의 얼굴이 된 커리어에만 준다. 환생은 영결을 열어 주는 별도 아이템이 아니라, 이미 있는 유산·숙련으로 그 얼굴이 될 확률을 조금 올리는 축이다.

---

## 1. 왜 이전 초안이 최선이 아닌가

이전 검토는 원인 진단은 맞았지만, 처방이 레버를 한꺼번에 당기는 쪽이었다.

| 이전 제안 | 최종 판정 | 이유 |
|---|---|---|
| 환생 N회 미만 영결 금지 | **기각** | 제목과 싸운다. 잘한 첫 인생을 벌한다. |
| 영결에 명예의 전당 70점 묶기 | **기각** | 구단의 상징과 리그 전설은 다른 이야기. 묶으면 명예가 한 줄로 붕괴한다. |
| 8시즌 → 12시즌 | **기각** | 리뷰는 이미 반복 작업이라고 한다. 쉬운 루프를 4년 더 늘리면 더 지루하다. |
| 팬 60 → 75 | **기각** | 팬은 시간 함수다. 숫자만 올리면 한 시즌 더 기다리면 된다. |
| 1회차 능력 하드캡 68~72 | **기각** | “게임이 막았다”로 읽힌다. 잠재력 UI를 새로 만들지 않는다. |
| 영결 전용 환생 유산·숙련 추가 | **기각** | 시스템이 이미 있다. 영결이 자동 합격인 한 새 아이템은 장식이다. 영결이 실제로 어려워지면 기존 +4 유산·야구혼이 차이를 만든다. |
| 성적 미달 랜덤 방출 | **기각** | 영결이 운으로 끊긴다. 이번 피드백의 답이 아니다. |
| 노화를 영결의 주 레버로 쓰기 | **기각** | 19세 시작 8시즌이면 은퇴 심사 나이는 26세. 현재 노화는 33세부터라 **영결 경로에 닿지 않는다.** 후속 품질 과제로 분리한다. |
| 시즌 상·자동 등판 난이도·유산 가중치 수정 | **채택** | 실제 원인이다. |

### 1.1 구조적 원인 (코드 사실)

1. 유산 점수 8시즌 잔류만으로 tenure 40 + continuity 8 = **48**. 선발 출석의 K·이닝이 30 근처를 채우면 수상 없이도 80에 가깝다.  
   `ProTeamCareerRecordRules.score` (`ProCareerJourney.swift`).
2. 시즌 상 문턱이 선발 출석상이다. 탈삼진 120, 이닝 120, BB9 2.5. 신인 프리셋 CLI 실측은 K/9 9.81 · 경기당 5.55이닝 · BB9 1.79라 **건강한 선발은 매년 2~3개**를 받는다.  
   `ProCareerRecognitionRules.currentSeasonRecognitions`.
3. 주간 자동 등판은 `DifficultyScale.pro`를 쓰지 않는다. 중요 경기만 시즌 보정이 있고, 시즌 기록의 대부분은 타선 50 고정이다.  
   `ProCareerEngine.simulateWeeklyOuting`.
4. 프로 주간 성장은 해당 능력 **2주당 +1**, 감쇠 없음. 8년은 전부 성장 구간이다.  
   `resolveDevelopment`, `ProDevelopmentProgress`는 진행값을 **0...1로 자른다**.
5. 프로 엔진은 `lifeNumber`를 읽지 않는다. 환생은 영결 판정에 관여하지 않는다.
6. 공식 분포 21.4%는 **강제 20시즌 + FA를 들어가는 `stable_random`** 분모다. 영결을 노리는 사람은 재계약한다. 체감 분모가 아니다.

### 1.2 제품으로 읽히는 경로

> 고교를 대충 키운다 → 첫 선수 지명 40~50% → 한 팀에 남는다 → 8년 뒤 영결

환생은 실패한 고교를 다시 하는 장치이지, 구단의 최고 명예를 위한 장치가 아니다.

### 1.3 성공의 감각

사용자는 다음을 구분할 수 있어야 한다.

- 한 팀에 오래 남으면 **구단 명예**를 받을 수 있다.
- **영구결번**은 그 구단에서 오래 *그리고* 그 시대의 얼굴로 던진 커리어다.
- 첫 선수에게 영결은 가능하지만 전설이다.
- 다음 선수 유산은 그 전설에 조금 더 다가가게 한다. 체크박스를 강제 해제하지는 않는다.

---

## 2. 최종 제품 결정

1. 영구결번 공개 게이트는 유지한다. 마지막 구단 **8시즌 · 유산 80 · 팬 60**. 은퇴 시점, 현재 팀만.
2. 유산 80의 *내용*을 바꾼다. 8년 출석만으로 80이 되지 않게 tenure 가중치를 낮추고, 드문 시즌 상이 점수를 만들게 한다.
3. 시즌 상은 정점 시즌만 준다. 선발 풀시즌 출석은 상이 아니다.
4. 주간 자동 등판에 시즌 난이도를 연결한다. 선수가 커질수록 리그가 따라온다.
5. 프로 주간 성장만 고능력에서 느려진다. 고교 `PitcherGrowthRules.grow`는 건드리지 않는다. 1회차 지명률 밴드를 깨지 않기 위해서다.
6. 진행 중 구저장의 **이미 쌓인 유산 점수·영결 preview**는 구공식으로 고정한다. 남은 시즌의 등판 난이도와 성장 속도만 새 규칙을 쓸 수 있다.
7. 환생 횟수로 영결을 잠그지 않는다. `lifeNumber`를 `ProCareerSnapshot`에 새로 넣지 않는다.
8. 명예의 전당 공식과 헌액 기준 70은 이번 작업에서 바꾸지 않는다.
9. 측정 분모를 `stable_random`의 12시즌 강제 완주에서 **`legacy_first`의 8시즌 잔류 영결 여부**로 교체한다.
10. 한국어·영어·일본어 카피를 함께 고친다. 일본어 스토어 문안만 바꾸고 바이너리 카탈로그를 빼먹지 않는다.

---

## 3. 목표와 비목표

### 3.1 목표

1. 재계약으로 한 팀에 8년 남은 첫 선수 상당 표본에서 영결이 **자동 합격이 아니게** 한다.
2. 같은 표본에서 구단 명예는 여전히 흔한 잔류 보상으로 남긴다.
3. 첫 선수 고교 지명률 밴드(UI 정보 활용 35~55%)를 깨지 않는다.
4. 구저장 커리어의 이미 표시된 유산 점수·영결 후보가 패치 직후 갑자기 사라지지 않는다.
5. 결정론, commitment, 시즌 결산 원자성, 비지배 계약 시장을 유지한다.
6. 한 시즌의 탭 수와 직접 투구 횟수를 늘리지 않는다.

### 3.2 비목표

- 환생 N회 잠금, 1회차 전용 영결 금지 플래그
- 명예의 전당을 영결 선결 조건으로 묶기
- 공개 게이트를 12시즌·유산 90·팬 75로 올리는 것 (1차 측정 전에 금지)
- 1회차 능력 하드캡과 그 UI
- 영결 전용 새 대표 유산·기억 카드
- 노화 곡선 재설계 (33세 −1은 그대로. 후속 문서)
- 방출·FA 시장 재설계
- 고교 성장·드래프트 공식·투구 커널 판정
- 주간 주수 24, 최대 20시즌, RA9 표기 변경
- 실존 구단명·약칭·로고
- 광고, 가격, 인앱 재화
- 완료된 과거 시즌 재시뮬레이션
- Android/Unity 동시 출시 필수

### 3.3 일정 압박 시 축소 순서

축소해도 안 되는 것: 구저장 유산 공식 고정, 자동 등판 시즌 오프셋, 시즌 상 문턱, 유산 가중치, ko/en/ja, 새 분포 분모.

1. 카피 톤 다듬기는 뒤로 미룰 수 있다. 숫자 8/80/60 표시는 남긴다.
2. 성장 감쇠는 시즌 상·유산보다 뒤다. 다만 8년 선형 성장이 남으면 상을 고쳐도 다시 세진다. 가능하면 포함한다.
3. 1,000시드 release 분포는 줄이지 않는다. 상수를 추측으로 확정하지 않기 때문이다.
4. 실패를 숨기려고 밴드를 넓히지 않는다.

---

## 4. 절대 불변 계약

### 4.1 콘텐츠·조작

- 실존 프로 구단명, 약칭, 리그명, 선수명, 로고, 유니폼 문양, 슬로건을 넣지 않는다.
- 직접 투구의 기본 조작은 투구 슬라이더다. 이 작업에서 투구 UI를 바꾸지 않는다.
- iOS 공개 빌드는 ko/en/ja 바이너리 현지화를 유지한다.

### 4.2 영구결번

- 영구결번은 은퇴 시점의 마지막 구단만 본다.
- 이전 구단에서 후보를 만들고 이적하면 이전 구단은 `clubHall`만 받을 수 있다.
- 진행 중에는 “후보”로만 쓴다. 확정 문장을 시즌 중에 저장하지 않는다.
- preview와 은퇴 저장 honor는 같은 순수 함수여야 한다.
- 복수 구단 영구결번, 사후 추서는 만들지 않는다.

### 4.3 저장 호환

- `journey.rulesVersion == 1` 커리어는 **구 유산 공식·구 시즌 상 문턱·구 영결 점수**를 유지한다.
- 새 커리어만 `journey.rulesVersion == 2`다.
- 오프시즌이 `journey.rulesVersion`을 올리지 않는다.
- `proRulesVersion`을 4로 올리는 것은 앞으로의 등판·성장에만 쓴다. 이미 쌓인 team record를 재작성하지 않는다.
- 완료된 `careerStats`와 typed recognition을 패치가 다시 계산해 상을 빼지 않는다.

### 4.4 밸런스 측정

- 실패를 숨기려고 수용 범위를 넓히지 않는다.
- 합성 출력으로 영결률을 보정하지 않는다. 실제 엔진 명령으로 시즌을 완주한다.
- 영결 체감 분모는 재계약 정책이다. FA를 강제 진입하는 정책은 진단만 한다.

---

## 5. 버전 규칙

지금 코드:

- `ProCareerEngine.currentRulesVersion == 3`
- `ProCareerJourneyState.rulesVersion` 기본값 1
- `validateJourneyState`가 `rulesVersion == 1`만 허용
- 오프시즌이 `proRulesVersion`을 `currentRulesVersion`으로 올린다
- `journey.rulesVersion`은 올리지 않는다

이번 작업:

| 필드 | 구저장 | 새 커리어 | 역할 |
|---|---|---|---|
| `journey.rulesVersion` | 1 유지 | **2** | 유산 점수, 시즌 상 문턱, 티어·영결 점수 |
| `proRulesVersion` | 다음 오프시즌에 4 | 4 | 자동 등판 오프셋, 주간 성장 틱 |

`ProCareerEngine.currentRulesVersion`을 **4**로 올린다.

`validateJourneyState`는 `(1...2).contains(journey.rulesVersion)`만 허용한다. 다른 값은 `unsupported journey rules version`.

`start`의 journey 생성은 `rulesVersion: 2`를 명시한다. 기본 인자 1에 의존하지 않는다.

레거시 마이그레이션(`migrateLegacyJourney`)은 계속 `rulesVersion: 1`을 넣는다.

---

## 6. 확정 공식

새 상수는 `ProTeamCareerRecordRules` / `ProCareerRecognitionRules`에 매직 넘버로 흩뿌리지 않는다. 공개 enum으로 모은다.

### 6.1 시즌 상 — `journey.rulesVersion >= 2`

파일: `ProCareerJourney.swift` `ProCareerRecognitionRules`.  
같은 문턱을 `ProCareerEngine.reviewSeason`의 비-journey 문자열 상 경로에도 적용한다. 두 경로가 어긋나면 실패다.

`currentSeasonRecognitions`에 `rulesVersion: Int`를 추가한다. 호출부가 빼먹으면 컴파일 실패해야 한다.

| 상 `contentID` | v1 (유지) | v2 |
|---|---|---|
| `pro.award.strikeouts` | K ≥ 120 | K ≥ **180** |
| `pro.award.run-prevention` | RA9 < 3.00 그리고 경기 ≥ 20 | RA9 < **2.70** 그리고 경기 ≥ 20 **그리고 아웃 ≥ 360** |
| `pro.award.command` | BB9 < 2.50 그리고 아웃 ≥ 180 | BB9 < **1.80** 그리고 아웃 ≥ **360** |
| `pro.award.hits` | H9 < 8.50 그리고 아웃 ≥ 180 | H9 < **7.50** 그리고 아웃 ≥ **360** |
| `pro.award.innings` | 아웃 ≥ 360 (120이닝) | 아웃 ≥ **486** (162이닝) |

RA9/BB9/H9는 기존과 같이 정수 천분율이다.

- RA9 < 2.70 → `runsAllowed * 27_000 / inningsOuts < 2_700`
- BB9 < 1.80 → `walks * 27_000 / inningsOuts < 1_800`
- H9 < 7.50 → `hits * 27_000 / inningsOuts < 7_500`

`pro.award.run-prevention`에 이닝 하한을 넣는 이유: 경기 20만 있으면 짧은 구원 시즌이 최소실점상을 받는다.

기존 `testSeasonHonorThresholdsAreExact`는 **v1 고정**이다. 지우거나 느슨하게 만들지 않는다. v2는 별도 테스트.

### 6.2 구단 유산 — `journey.rulesVersion >= 2`

```
tenure     = min(20, completedSeasons * 2)
strikeouts = min(30, strikeouts / 40)
workload   = min(18, inningsOuts / 200)
awards     = min(20, awardCount * 5)
continuity = min(8, consecutiveSeasons)
community  = min(8, communityPoints)
score      = min(100, 합)
```

v1 공식은 한 글자도 바꾸지 않는다.

```
tenure     = min(40, completedSeasons * 5)
strikeouts = min(25, strikeouts / 40)
workload   = min(15, inningsOuts / 180)
awards     = min(12, awardCount * 4)
continuity = min(8, consecutiveSeasons)
community  = min(8, communityPoints)
score      = min(100, 합)
```

티어 문턱 숫자는 유지한다. 점수의 의미가 바뀌므로 같은 80이 더 드물어진다.

| tier | 점수 | 완료 시즌 |
|---|---|---|
| 새 얼굴 | 0...14 | — |
| 전력의 한 축 | 15 | — |
| 중심 선수 | 35 | — |
| 구단 에이스 | 50 | 4 |
| 구단의 상징 | 65 | 6 |
| 영구결번 후보 | 80 | 8 |

`clubHall`은 계속 6시즌 · 유산 65. 1차 측정에서 재계약 8시즌 잔류의 clubHall이 20% 미만이면 65를 55로 내리는 것은 §10.3의 허용 조정이다. 구현 전에 미리 내리지 않는다.

`franchiseIcon` 목표의 (8시즌, 유산 80)은 그대로 두고, 내부 점수 함수만 버전을 따른다.

### 6.3 API

```swift
public enum ProTeamLegacyRules {
    public static func score(record: ProTeamCareerRecord, rulesVersion: Int) -> Int
    public static func score(record: ProTeamCareerRecord) -> Int // rulesVersion 1. 구테스트용
    public static func tier(record: ProTeamCareerRecord, rulesVersion: Int) -> ProTeamLegacyTier
    public static func nextTierProjection(record: ProTeamCareerRecord, rulesVersion: Int) -> Threshold?
}
```

`score(record:)` 무버전 오버로드는 v1만 계산한다. 새 프로덕션 호출부는 반드시 `rulesVersion`을 넘긴다.

프로덕션 호출부:

- `ProRetirementRules.preview`
- `ProCareerGoalRules.progress` (state.journeyState?.rulesVersion ?? 1)
- `ProCareerEngine` 시즌 결산의 teamLegacy before/after
- iOS `CareerDirectionCard`, 은퇴 preview

결산 UI는 저장된 `teamLegacyBefore`/`teamLegacyAfter`를 다시 계산하지 않는다. 이미 있는 계약이다.

### 6.4 작업 예시 — v2 단위 테스트로 고정

모든 예는 `consecutiveSeasons == completedSeasons`, community 0, 다른 필드 0.

| 이름 | 시즌 | K | 아웃 | 수상 | v2 점수 | 의미 |
|---|---:|---:|---:|---:|---:|---|
| 출석 선발 | 8 | 640 | 2_400 | 0 | 16+16+12+0+8+0 = **52** | 영결 아님. 상징 65 미만 |
| 출석+수상1 | 8 | 640 | 2_400 | 1 | 52+5 = **57** | 영결 아님 |
| 좋은 프랜차이즈 | 8 | 1_000 | 3_000 | 2 | 16+25+15+10+8 = **74** | 상징 가능, 영결 아님 |
| 얼굴 | 8 | 1_200 | 3_600 | 3 | 16+30+18+15+8 = **87** | 영결 점수 통과 |
| 정점 | 8 | 1_600 | 4_320 | 4 | 16+30+18+20+8 = **92** | 상한 근처 |
| 6년 기여 | 6 | 480 | 1_800 | 0 | 12+12+9+0+6 = **39** | clubHall 아님 |
| 6년 에이스 | 6 | 900 | 2_700 | 2 | 12+22+13+10+6 = **63** | 65 미만. clubHall은 정점이 더 필요 |

v1 회귀: Wave4의 `lastTeamAt80` (8시즌, K 1000, community 7)는 계속 80이어야 한다. `rulesVersion: 1`로 호출한다.

### 6.5 자동 등판 난이도 — `proRulesVersion >= 4`

`simulateWeeklyOuting`에 `batterOffset`을 받는다. `planWeek`는 다음을 넘긴다.

```
offset = (state.proRulesVersion ?? 1) >= 4
    ? DifficultyScale.pro(season: state.season)
    : 0
```

`DifficultyScale.pro(season:)`은 지금 그대로다. `min(8, max(0, season - 1))`. 시즌 1은 0, 시즌 9 이후는 8.

중요 경기는 이미 같은 함수를 쓴다. 주간 기록과 직접 승부의 타선 기준이 처음으로 같아진다.

`AutoOutingSimulator` 기본값 0은 고교·CLI 호환을 위해 유지한다. 고교는 자기 `batterOffset`을 계속 넘긴다.

이 웨이브에서 `DifficultyScale` 상수(`chapterCeiling`, `rebirthCeiling`, `seasonCeiling`)를 올리지 않는다. 1차 분포 뒤에만 §10.3으로 손댄다.

### 6.6 프로 주간 성장 — `proRulesVersion >= 4`

`PitcherGrowthRules.grow`는 고교와 공유하므로 **수정 금지**.

`ProDevelopmentProgress`의 `min(1, max(0, _))` 클램프를 **`min(8, max(0, _))`** 로 바꾼다. 구저장의 0/1은 그대로 읽힌다.

v3 이하: 지금처럼 2틱(0 → 1 → 성장 후 0).

v4 이상, 해당 능력 현재 값 기준 필요 틱:

| 능력 | 필요 주간 틱 |
|---|---:|
| ...54 | 2 |
| 55...64 | 3 |
| 65...72 | 4 |
| 73...80 | 6 |

틱은 그 주를 훈련했을 때만 오른다. 회복·신뢰·부상 주는 오르지 않는다. 성장이 발동하면 그 축은 0으로 돌아간다.

`developWeapon`은 구위와 변화 각각 자기 틱을 쓴다. 한 축만 문턱에 닿으면 그 축만 +1.

`seededDevelopmentProgress`는 연구소 투자가 해당 축을 1로 만든다. v4에서도 1이면 된다. 문턱을 건너뛰는 즉시 +1로 바꾸지 않는다.

---

## 7. 웨이브

한 웨이브가 테스트와 저장 계약을 통과하기 전에 다음 웨이브를 시작하지 않는다.

### Wave 0 — 구공식 고정

목적: 이후 커밋이 v1 영결·유산·상을 깨면 즉시 실패한다.

할 일:

- `ProCareerLegacyWave4Tests`의 점수·티어·영결 경계 테스트를 그대로 둔다.
- 테스트 이름에 `V1`을 명시해도 된다. 기대값을 바꾸지 않는다.
- `testSeasonHonorThresholdsAreExact`가 `rulesVersion: 1`을 넘기게 시그니처만 맞춘다. 문턱 숫자는 그대로다.
- `validateJourneyState`를 `1...2`로 열기 **전에**, rulesVersion 2를 거절하는 현재 동작을 한 테스트로 찍어 둔다. 다음 웨이브에서 그 테스트를 새 기대값으로 교체한다.

완료 조건:

```
swift test --package-path packages/simulation-core --filter ProCareerLegacyWave4Tests
swift test --package-path packages/simulation-core --filter ProCareerWave5Tests
```

실패 0.

### Wave 1 — 버전 배선

할 일:

- `currentRulesVersion = 4`
- 새 커리어 `journey.rulesVersion = 2`
- `validateJourneyState`가 1과 2를 허용
- 레거시 마이그레이션은 1
- 오프시즌이 `journey.rulesVersion`을 바꾸지 않는 테스트를 추가
- `ProCareerLegacyWave4Tests`의 `XCTAssertEqual(ProCareerEngine.currentRulesVersion, 3)`을 4로 갱신
- `commitment` / canonical token에 rulesVersion이 이미 있으면 중복 필드를 만들지 않는다

완료 조건:

- 새 `start` snapshot의 journey.rulesVersion == 2, proRulesVersion == 4
- unsigned v1 journey는 계속 로드되고 점수는 v1

### Wave 2 — 시즌 상 v2

할 일:

- `ProCareerRecognitionRules`에 버전 분기
- `reviewSeason` 비-journey 경로 동기화
- `ProCareerLegacyWave4Tests`에 v2 경계 표 테스트 추가 (120K는 탈삼진상 아님, 180K는 상, 359아웃+RA9 2.69는 최소실점상 아님, 360아웃+RA9 2.70 경계)

완료 조건: v1 상 테스트와 v2 상 테스트가 동시에 통과.

### Wave 3 — 유산 가중치 v2와 영결 preview

할 일:

- `score(record:rulesVersion:)` 구현
- `ProRetirementRules.preview`가 journey.rulesVersion을 사용
- 결산 teamLegacy before/after가 같은 버전을 사용
- `ProCareerGoalRules`가 같은 함수를 사용
- §6.4 표를 단위 테스트로 고정
- iOS `CareerDirectionCard` / 다음 티어 문구가 `state.journeyState?.rulesVersion ?? 1`을 넘김
- 은퇴 preview는 계속 8/80/60을 보여 준다. 숫자 라벨을 12/90으로 바꾸지 않는다

완료 조건:

- v1 lastTeamAt80 / fan 59·60 경계 테스트 통과
- v2 출석 선발 52점, 얼굴 87점
- preview와 `honors(for:)`가 같은 eligible 값

### Wave 4 — 자동 등판 오프셋 + 프로 성장 틱

할 일:

- `simulateWeeklyOuting`에 offset 전달
- `resolveDevelopment` v4 틱
- `ProDevelopmentProgress` 클램프 0...8
- 같은 시드·같은 투수에서 season 1 오프셋 0과 season 9 오프셋 8의 실점이 달라지는 테스트
- 능력 73에서 6틱 전에 +1이 없는 테스트
- 고교 성장 테스트는 건드리지 않는다

완료 조건:

- `HighSchoolCareerEngineTests`, `PitcherDevelopmentRulesTests` 실패 0
- 프로 v3 스냅샷은 2틱 성장을 유지

### Wave 5 — 분포 러너와 새 분모

할 일:

`ProCareerDistributionRunner`에 시즌 8 스냅샷을 기록한다. 커리어를 20시즌까지 돌려도, **시즌 8 결산 직후** 다음을 한 번 저장한다.

- `lastTeamSeasons`
- `lastTeamLegacy` (해당 rulesVersion)
- `fanSupport`
- `retiredNumberEligible`
- `clubHallForLastTeam` (마지막 구단이 clubHall 조건. 영결이면 중복 clubHall은 기존 규칙대로 제외하되, 이 진단 필드는 “명예 계층에 올랐는가”를 보기 위해 영결이어도 true로 센다)
- `seasonAwardCountThatSeason`
- `careerAwardCount`

강제 은퇴는 지금처럼 최대 시즌에만 한다.

**릴리스 강제 분모**를 교체한다.

| ID | 분모 | 분자 | 범위 | 강제 |
|---|---|---|---|---|
| `balance.legacy_first.retiredNumberAmongSeason8SameTeam8` | `legacy_first` 시즌 8에서 lastTeamSeasons ≥ 8 | 그 중 retiredNumberEligible | 80...200‰ (8~20%) | **예** |
| `balance.legacy_first.clubHonorAmongSeason8SameTeam8` | 위와 동일 | clubHall 또는 영결 | 350...700‰ (35~70%) | **예** |
| `balance.legacy_first.seasonAwardsPerSeason8Mean` | legacy_first 시즌 1...8의 시즌당 상 수 | 평균 × 1000 | 0...800 (시즌당 0.0~0.8개) | **예** |
| `stable_random` 12시즌 영결 5~25% | 기존 | 기존 | 기존 | **아니오. 진단** |
| 조기 fan 100 · 야망 10~50% · 비지배 시장 | 기존 | 기존 | 기존 | 예, 유지 |

`legacy_first`는 재계약한다. 영결을 노리는 사람의 분모다.

`stable_random`을 영결 강제 분모로 쓰지 않는다.

릴리스 커맨드:

```bash
swift run -c release --package-path packages/simulation-core pro-career-distribution-runner --release
```

환경 변수는 기존과 같다. `--release`는 1,000시드 × 20시즌 × 전 정책. 줄이지 않는다.

스모크 (상수 탐색, 강제 없음):

```bash
BASEBALL_PRO_DISTRIBUTION_SEEDS=32 \
BASEBALL_PRO_DISTRIBUTION_SEASONS=8 \
BASEBALL_PRO_DISTRIBUTION_POLICY=legacy_first \
BASEBALL_PRO_DISTRIBUTION_OUTPUT=artifacts/analysis/pro-career-retired-number/smoke-legacy-first-32x8.json \
swift run -c release --package-path packages/simulation-core pro-career-distribution-runner
```

Wave 5 구현 후 스모크를 먼저 보고, 범위 밖이면 §10.3만 허용한다. 밴드를 넓혀 맞추지 않는다.

결과 JSON은 `artifacts/analysis/pro-career-retired-number/`에 남긴다. SHA-256을 이 문서 §18에 추가한다.

### Wave 6 — iOS 카피 ko/en/ja

공개 숫자 8/80/60은 유지한다. 문구가 “오래 남으면 영결”로 읽히지 않게 한 줄을 더한다.

손댈 키 (새 키를 만드는 쪽을 선호. 기존 포맷 문자열의 인자 순서를 깨지 않는다):

- `pro.retirement.preview.retired-number` — 숫자 줄 유지
- 신규 `pro.retirement.preview.retired-number.hint`
  - ko: `잔류만으로는 부족합니다. 이 구단의 얼굴로 던진 시즌이 유산 80을 채워야 합니다.`
  - en: `Tenure is not enough. Only seasons as this club's face fill the 80 legacy points.`
  - ja: `残留だけでは足りません。この球団の顔として投げたシーズンがレガシー80を満たします。`
- 신규 `pro.journey.direction.legacy.hint`
  - ko: `구단 명예는 함께한 시간, 영구결번은 그 시간 위의 상징입니다.`
  - en: `Club hall is the years together. A retired number is the face of those years.`
  - ja: `球団殿堂は共にした時間、永久欠番はその時間の象徴です。`

`RetirementPreviewCard`에 eligible이 아닐 때 hint를 보여 준다. eligible이면 기존 달성 라벨만.

`CareerDirectionCard` 확장 영역에 legacy hint를 한 줄 넣는다.

실존 구단 암시 단어를 넣지 않는다. `check-korean-game-copy`와 `check-ios-localization`을 돌린다.

UITest identifier를 바꾸면 `CareerSmokeUITests`의 `pro.retirement.preview.retired-number`를 깨지 않게 힌트는 별 identifier `pro.retirement.preview.retired-number.hint`를 쓴다.

### Wave 7 — 게이트 스크립트와 문서 마감

- `tools/check-pro-career-retired-number.mjs`를 추가한다.  
  `ProCareerLegacyWave4Tests` + 신규 `ProCareerRetiredNumberBalanceTests`를 필터한다.
- 이 문서 상태를 구현 완료로 바꾸지 않는다. 에이전트는 evidence 절만 채운다.
- Android/Kotlin은 이 웨이브에서 강제하지 않는다. §12에 패리티 부채를 적는다.

---

## 8. 테스트 명세

신규 파일: `packages/simulation-core/Tests/SimulationCoreTests/ProCareerRetiredNumberBalanceTests.swift`

필수 케이스:

1. v1 score/tier/영결 경계는 Wave4와 바이트 단위로 같다.
2. v2 §6.4 표의 모든 행.
3. v2 상 문턱의 바로 아래/위.
4. `preview`가 last team만 보고, 이전 팀은 clubHall만.
5. fan 59 / 60 경계는 두 버전 모두 유지.
6. 새 start는 rulesVersion 2, 레거시 migrate는 1.
7. 오프시즌 후 journey.rulesVersion 불변, proRulesVersion 4.
8. v4 자동 등판이 season에 따라 offset을 넣는지. v3는 0.
9. 성장 틱 밴드.
10. `currentSeasonRecognitions`와 `reviewSeason` 비-journey 상의 contentID 집합이 같다.

iOS:

- `ProCareerJourneyWave1Tests`의 preview 키 존재 테스트가 새 hint 키를 허용하는지 확인한다. 기존 키가 사라지면 실패해야 한다.

고교:

- 기존 1회차 지명 밴드 테스트를 이 작업에서 돌린다. 실패하면 프로 변경이 고교를 건드린 것이다. 되돌려야 한다.

---

## 9. iOS 호출부

엔진이 계산한 값을 화면이 다시 계산하지 않는 기존 계약을 지킨다. 예외는 진행 중 방향 카드의 **현재** 유산 점수다. 이미 `ProTeamLegacyRules.score`를 직접 호출한다. 여기에 `rulesVersion`만 추가한다.

| 위치 | 할 일 |
|---|---|
| `AppShell.swift` `CareerDirectionCard` | `score`/`tier`/`nextTierProjection`에 rulesVersion |
| `ProRetirementViews.swift` | hint 줄. 점수는 계속 `retirementPreview` |
| `ProCareerPresentation.swift` | 팀 이름만. 새 판정 금지 |
| `Localizable.xcstrings`, `GameContent.xcstrings` 해당 키 | ko/en/ja |
| `docs/localization/ios-copy-schema.json` | 새 키 등록 (레포 관례대로) |

결산 화면이 `ProTeamLegacyRules.score`를 다시 호출하면 안 된다. 이미 있는 iOS 테스트 `settlement UI must render stored projections`를 유지한다.

---

## 10. 분포와 허용 조정

### 10.1 목표 감각

재계약으로 8년을 같은 팀에 채운 커리어:

- 영결 8~20%
- 구단 명예(또는 영결) 35~70%
- 시즌당 상 0.0~0.8개 (8년 합 0~6개 부근)

영결 0%면 과하게 조였다. 40%면 피드백이 남는다.

### 10.2 1,000시드 전에 볼 스모크

32시드 × 8시즌 × `legacy_first`. 강제하지 않는다. 방향만 본다.

- 시즌당 상 평균이 1.5를 넘으면 상이 아직 출석상이다. Wave 2 문턱을 먼저 본다.
- 8년 잔류 영결이 70%를 넘으면 유산 가중치가 아직 출석 점수다. Wave 3을 먼저 본다.
- 8년 잔류 영결이 0이고 상도 0이면 문턱이 벽이다. §10.3.

### 10.3 허용하는 상수 조정 (구현 중 한 번만, 기록 필수)

밴드를 맞추기 위해 아래 **한 축만**, 한 칸만 움직인다. 여러 축을 동시에 움직이지 않는다.

1. 탈삼진상 180 → 170 또는 190
2. 최소실점상 RA9 2.70 → 2.80 또는 2.60
3. 이닝상 486 → 450 또는 510
4. v2 tenure `seasons * 2` 상한 20 → 18 또는 22
5. clubHall 점수 65 → 55 (영결 80은 유지)
6. `DifficultyScale.seasonCeiling` 8 → 7 또는 9

금지:

- 영결 시즌을 8 → 10/12
- 영결 유산 80 → 90
- 팬 60 → 75
- 상을 120K/120이닝으로 되돌리기
- tenure를 다시 `* 5`로 올리기
- 수용 범위 8~20%를 5~40%로 넓히기

조정하면 §18에 스모크 JSON 경로, 바꾼 상수, 이유, 다음 측정값을 적는다.

### 10.4 고치지 말고 후속으로 넘길 신호

- 1회차 고교 지명률이 이 작업 때문에 움직임 → 프로 변경이 고교를 침범한 것. 롤백.
- 재계약 8년 잔류율 자체가 20% 아래로 떨어짐 → 등판 오프셋이 2군·미계약으로 커리어를 끊는 것. `seasonCeiling`만 한 칸 검토. 영결 게이트를 낮추지 않는다.
- 유저가 “너무 길다”고만 하면 이 문서의 범위가 아니다.

---

## 11. 환생은 이 작업에서 무엇을 하는가

아무것도 **새로 만들지 않는다.**

의도된 상호작용:

- 첫 선수는 성장이 느리고 상이 드물어 8년 출석만으로 80에 못 미친다.
- 다음 선수는 대표 유산 +4와 야구혼 스며듦으로 같은 8년을 더 좋은 정점 시즌으로 채울 수 있다.
- 그 차이가 환생의 보상이다.

`lifeNumber`를 프로에 넣거나, 회차별 영결 확률 보정을 넣거나, 영결 전용 유산을 추가하면 이 문서를 어긴 것이다.

후속 문서에서만 검토할 것:

- 노화 곡선 (26세 영결과 무관, 20시즌 최강자 체감용)
- 숙련이 프로 후반 정점을 조금 더 붙잡는 효과
- 1회차 고교 졸업 투수만 넣는 분포 러너 (지금은 프리셋 시작. 시작 능력은 1회차와 비슷하고, 8년 성장이 문제의 핵심이다)

---

## 12. Android / Unity

이번 실행의 완료 조건이 아니다.

기록: `apps/android/game-core/.../ProJourneyKernel.kt`의 `teamLegacy`는 이미 Swift와 다르다.

```
min(100, completedSeasons * 8 + awardCount * 5 + communityPoints)
```

Swift v1도 아닌 별 공식이다. 후속 패리티에서 Swift `score(record:rulesVersion:)`를 이식하고, clubHall 6/65와 영결 8/80/60을 맞춘다. 지금 Android 공식을 “더 어려운 영결”로 채택하지 않는다.

C# / Unity 포트도 같다. Swift가 원본이다.

---

## 13. 명시적으로 만지지 말 것

- `PitchKernelEngine`, 투구 슬라이더, 자동 릴리스 기본값
- `PitcherGrowthRules.grow` (고교 공유)
- 고교 드래프트 공식, `DifficultyScale.highSchool`, 1회차 지명 밴드
- `hallOfFameFormulaVersion`과 HOF 70
- 계약 시장 non-dominance, 연봉 공식
- 최대 20시즌, 24주
- 완료된 시즌의 수상을 재계산해 삭제
- 실존 야구 IP
- 사용자 dirty 파일

---

## 14. 구현 순서 (에이전트 체크리스트)

- [ ] Wave 0 구테스트 그린
- [ ] Wave 1 버전 배선 + 테스트
- [ ] Wave 2 상 v2 + 경계 테스트
- [ ] Wave 3 유산 v2 + preview + iOS score 호출부
- [ ] Wave 4 등판 오프셋 + 성장 틱
- [ ] 고교 관련 테스트 회귀
- [ ] 32시드 스모크. 필요 시 §10.3 한 칸
- [ ] Wave 5 러너 분모 교체 + 1,000시드 release
- [ ] Wave 6 ko/en/ja 카피 + localization 체크
- [ ] Wave 7 게이트 스크립트
- [ ] evidence 경로와 SHA-256을 §16에 기록

커밋은 웨이브 단위로 나눠도 된다. 한 커밋에 공식과 1,000시드 JSON과 카피를 섞지 않는다.

---

## 15. 완료의 정의

다음을 모두 만족해야 이 작업을 완료로 부른다.

1. 새 커리어는 journey rules 2, 구커리어 유산 점수는 구공식.
2. v1 Wave4 경계 테스트가 그대로 통과.
3. v2 출석 8년 선발이 유산 80 미만, 얼굴 커리어는 80 이상.
4. 주간 자동 등판이 `DifficultyScale.pro(season)`을 쓴다.
5. `legacy_first` 1,000시드에서 시즌 8 동일 구단 8년 영결 8~20%, 구단 명예 계층 35~70%, 시즌당 상 0.8개 이하.
6. 고교 1회차 지명 밴드 테스트 통과.
7. 은퇴 preview와 방향 카드가 ko/en/ja hint를 가지고, 일본어 키가 fallback 한국어가 아니다.
8. 투구 슬라이더 기본값 불변.

완료 후 이 문서 상단 상태를 `구현 완료 — evidence §16`으로 바꾼다. 상수를 조용히 문서와 다르게 두지 않는다.

---

## 16. Evidence

| 산출물 | 경로 | SHA-256 |
|---|---|---|
| 32시드 스모크 | `artifacts/analysis/pro-career-retired-number/smoke-legacy-first-32x8.json` | `a226f3a4c17e894e77e2a357260b08811ea9bcedc9b3c26e2560d86d44339345` |
| 1,000시드 release | `artifacts/analysis/pro-career-retired-number/swift-distribution-1000x20.json` | `cd0943d073260dc6a9b3c467e08fe87dc648d57777f21c7bd2d8ba645af64cbf` |

Release JSON: `mode=release`, `valid=true`, `failingChecks=[]`.

| 강제 지표 | 관측 | 밴드 | 판정 |
|---|---:|---|---|
| `legacy_first` 시즌 8 동일 구단 8년 영결 | 128‰ (12.8%) | 80...200 | 통과 |
| `legacy_first` 시즌 1...8 시즌당 상 | 79‰ (0.079개) | 0...800 | 통과 |
| `stable_random` franchise_icon | 224‰ | 100...500 | 통과 |
| `stable_random` enduring_pro | 341‰ | 100...500 | 통과 |
| failedRuns / 계약·finance 정합성 | 0 | 0 | 통과 |

진단(비강제):

- 구단 명예(유산 ≥ 65) 720‰. 잔류 보상으로 흔하다. 65 문턱을 올리면 영결 80과 붙는다.
- 명예의 전당 12시즌 비율 2‰. 공식·70점 기준은 유지. 시즌 상이 정점만 되면서 희귀해졌다.
- `record_book` 2‰. HOF 70 + 상 3개가 필요해서 전설 목표가 되었다.

구현 중 추가로 고친 것: 이미 충족한 커리어 목표가 이적·시즌 공백으로 연속 시즌이 리셋돼 결산에서 깨지지 않게 했다. `stable_random` seed 742가 그 경로였다.

---

## 17. 성공 기준 (출시 후, 이 문서 구현 범위 밖)

- 지명된 첫 선수가 한 팀에 남은 실사용 커리어의 영결률이 내부 8~20%와 같은 방향인가.
- “한 팀에 남았는데 영결이 아니다”가 구단 명예 화면으로 설명되는가.
- 두 번째·세 번째 선수에서 영결 후보가 조금 더 자주 보이는가.
- D2 리텐션이나 고교 완주율을 이 작업만의 KPI로 삼지 않는다.

---

## 18. 결정 기록

| 날짜 | 결정 | 이유 |
|---|---|---|
| 2026-08-20 | 환생 횟수 게이트 기각 | 제목·첫 인생 숙련과 충돌 |
| 2026-08-20 | 영결에 HOF 묶기 기각 | 구단 명예와 리그 명예를 분리 |
| 2026-08-20 | 12시즌·팬 75 기각 | 쉬운 루프의 시간만 늘림 |
| 2026-08-20 | 1회차 하드캡·영결 전용 유산 기각 | 새로운 시스템 없이 원인 함수를 고침 |
| 2026-08-20 | 공개 게이트 8/80/60 유지, 80의 내용을 변경 | preview·ambition·카피를 깨지 않고 출석 합격을 제거 |
| 2026-08-20 | 유산/상은 `journey.rulesVersion`, 등판/성장은 `proRulesVersion` | 진행 중 영결 preview Rug pull 방지와 앞으로의 난이도 적용을 분리 |
| 2026-08-20 | 강제 분모를 `legacy_first` 시즌 8 잔류로 교체 | 영결을 노리는 사람의 행동과 일치. `stable_random` 21.4%는 체감이 아님 |
| 2026-08-20 | 노화를 범위 밖으로 | 8년 영결 연령(26)에 닿지 않음 |
| 2026-08-20 | Android/Unity 비차단 | Swift가 원본. Kotlin teamLegacy는 이미 불일치 |
| 2026-08-20 | 고교 grow 함수 수정 금지 | 1회차 지명 밴드를 이 작업이 깨면 안 됨 |
| 2026-08-20 | `proRulesVersion` 비교를 `agencyRulesVersion=3`과 분리 | `currentRulesVersion`을 4로 올리면 v3 저장이 주체성 규칙을 잃는다 |
| 2026-08-20 | 구단 명예·HOF 12시즌·record_book 비율은 진단 | 1,000시드에서 영결 12.8%가 본 과제. 상 희귀화의 부작용으로 HOF/record_book이 전설이 된 것은 공식을 되돌리지 않음 |
| 2026-08-20 | 이미 충족한 목표는 결산에서 깨지지 않음 | FA 복귀로 연속 시즌이 리셋돼도 달성한 franchise icon을 몰수하지 않음 |

---

## 19. 구현 에이전트를 위한 금지 요약

하지 마라.

- `if lifeNumber == 1 { retiredNumberEligible = false }`
- 영결 조건에 `finalScore >= 70` 추가
- 8을 12로, 80을 90으로, 60을 75로 올리기
- `PitcherGrowthRules.grow`에 감쇠 넣기
- 실패를 숨기려고 8~20% 밴드를 넓히기
- 구저장 team record를 새 공식으로 다시 채점
- 실존 구단 이름
- 투구 슬라이더를 숨기거나 기본값을 자동 릴리스로 변경
- 사용자 uncommitted 변경 폐기
