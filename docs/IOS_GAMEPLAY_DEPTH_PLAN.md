# iOS 게임플레이 깊이 계획 — 최종 확정 사양 (시즌 기록 표면화·고교 시즌·아트)

| 항목 | 값 |
|---|---|
| 문서 ID | DOC-IOS-DEPTH |
| 버전 | 2.0 (최종 확정 — 이 문서대로 위에서 아래로 구현한다) |
| 기준일 | 2026-07-26 |
| 목표 | 한국 App Store **유료 게임 1위** |
| 선행 문서 | DOC-IOS-PAID, DOC-IOS-TOP, DOC-19 §7, GAME_QUALITY_REVIEW_2026-07-23 |
| 범위 | `packages/simulation-core` + `apps/ios` + `tools`. **`apps/windows`는 일시 중지 — 작업하지 않는다** (§8) |

## 0. v1.0과 무엇이 달라졌나

v1.0의 6개 작업 중 **4.5개가 이미 구현·검증 완료**됐다(코어 149 테스트·밸런스 17/17·iOS 55+4 통과).
이 문서는 코드를 전수 재확인한 결과로 v1.0을 대체한다. 완료분은 §1에 "사실 기록"으로만 남기고,
남은 작업(§3~§6)은 구현 세션이 재조사 없이 그대로 따라갈 수 있게 파일·함수·문자열 단위로 적었다.

**v1.0에서 잘라낸 것**과 이유:

| 잘라낸 것 | 이유 |
|---|---|
| §2.2 "상대 타선 티어 오프셋(-4~+4) + 주차 기반 상대 로테이션" (프로) | 구현체가 flat 50 변주를 유지했고, 승패 판정이 상대 타선 시뮬에 의존하지 않게 설계돼 실익이 "로그에 상대 팀명이 찍히는 것"뿐이다. 상대 팀명 표기는 §3-A4로 축소 반영, 타선 티어는 **폐기**(밸런스 재튜닝 비용 대비 화면 효과 0) |
| §2.3 "선발 투구수 상한 곡선(스태미나 티어별)" | 96 고정이 유지됐고 커널이 피로로 이미 구속·제구를 깎는다. 이중 장치라 폐기 |
| §2.3(5) "고교 자동 경기를 챕터 테마별 상대 강도 3티어로" | 고교 득점 PMF(`highSchoolRunsPerGamePermille`)가 이미 있고, 상대 강도는 §5에서 챕터당 오프셋 1개 정수로 축소 |
| §2.4 로그 행 포맷의 "vs 부산" | `ProGameLine`에 상대 팀 필드가 없다. §3-A4에서 옵셔널로 추가하는 조건부 항목으로 격하 — 못 하면 행에서 상대명을 뺀다 |
| §5.2 관계 응답 다이얼로그 검토 | 원탭 유지로 확정(반복 선택은 리듬을 죽인다). 종결 |
| §9 결정 대기 5건 | 전부 §9에서 확정했다. 결정 대기 상태는 남기지 않는다 |

## 1. 완료 확인 (2026-07-26 실측 — 구현하지 말 것, 회귀만 막을 것)

전부 코드에서 직접 확인했다. 구현 세션은 이 절을 건드리지 않는다.

| # | 항목 | 확인된 위치 |
|---|---|---|
| 1 | 와인드업 햅틱 (스위트스폿 접근 시 강해지는 연속 햅틱) | `apps/ios/Sources/Haptics.swift` (188줄) |
| 2 | 조준 난이도 — 조준점 드리프트 | `DeliveryControl.swift` + MeterDriver, 계약 문자열 `autoRelease` 유지 |
| 3 | 파울 렌더 수정 — `isFairBall`을 `isBatted`에서 분리 | `PitchDramaView.swift:37,49,57` |
| 4 | 용어 통일 구위/제구/변화구/체력 + `check-copy`가 "공의 위력"·"공의 움직임" 차단 | `tools/check-copy.mjs:41,43` |
| 5 | 학교 선택 확인 다이얼로그 (`hs.school.confirm`) | `HighSchoolCareerView.swift:271-292` |
| 6 | 좌측 레일 제거 + 얇은 세로 막대 CI 차단(허용 목록 2파일) | `tools/check-design-system.mjs:107-124` |
| 7 | 스코어보드 재설계 — 표차(리드/동점/뒤짐)·레버리지 말로 표기 | `PitchView.swift:337-370` |
| 8 | 포수 사인 상황 정책 — RNG 없는 `SignSituation`, recommend에 배선 | `SignSituation.swift`, `PitchKernelEngine.swift:22-68`, `SignSituationTests` |
| 9 | 자동 시즌 코어 1차 — 아래 상세 | `LeagueBaseline.swift`, `ProCareer.swift` |

9번의 실측 상세 (v1.0 §2와 다른 점 포함):

- `LeagueBaseline.swift` 신설: 팀 득점 PMF(프로 19칸·고교 15칸, 천분율), `teamRuns(using:)`,
  `PitchingDecision`(win/loss/save/noDecision), `ProGameLine`(13필드, `Identifiable`),
  `DecisionRules.decide(...)` — 선발승 5이닝 규칙·세이브 3점 차 규칙 그대로.
- `planWeek`(`ProCareer.swift:287-421`)이 등판마다 `ProGameLine`을 만들어
  `gameLines: [ProGameLine]?`(옵셔널, **commitment 해시 불포함** — `commitment(_:)`는
  `ProCareer.swift:653-657`에서 확인)에 누적한다. 승·패·세이브가 `currentStats`에 집계된다.
- `ProSeasonStats`에 `losses` 추가 + **수기 디코더**(`ProCareer.swift:101-114`) — 구세이브 키 없으면 0.
- `resolveImportantGame`(`ProCareer.swift:423-472`)이 `report.outs ?? max(3, pitches/5)` 폴백을 쓰고,
  `played: true` 라인을 로그에 합류시킨다. `ImportantInningReport`에 `outs: Int?`, `teamRuns: Int?` 추가됨.
- `ProCareerSnapshot`은 **`final class`** — Swift 6.3 outlined destroy SIGSEGV 회피
  (`ProCareer.swift:126-131` 주석, `HighSchoolCareerSnapshot`과 같은 처방). `==` 수기 구현.
- 테스트: `LeagueBaselineTests`(PMF 합 1000 검증 포함), `ProCareerEngineTests` 재베이스라인 완료.

**v1.0의 판단 중 구현이 반증한 것**: "A는 7~10일 규모" — 코어 절반이 이미 끝나 남은 것은
코어 마감 1~2일 + iOS 표면화 2~3일 + 고교 2~3일이다. "±4점 캡을 §9에서 결정" — 확정됐다(§9-2).

## 2. 두 결정에 대한 비판적 검토 (결론: 유지하되, 각각 수정 1건이 필수)

### 2.1 팀 득점 PMF + 판정 규칙 (상대 팀 완전 시뮬 안 함) — 유지. 단, 두 가지 티가 난다

야구를 아는 플레이어가 시즌 로그를 훑을 때 들키는 지점을 실제 코드에서 찾았다.

**티 ① — 구원 등판의 상대 점수가 전부 0~2점이다.** `planWeek`에서
`opponentRuns = outingLine.runsAllowed + bullpenRuns`인데 구원은 `bullpenRuns = 0`이다
(`ProCareer.swift:325-326`). 마무리가 깨끗한 1이닝을 던지면 상대 최종 점수가 **0점**으로 찍힌다 —
로그에 5:0 세이브 상황이 즐비하고, "내가 등판만 하면 우리 팀 투수진 전체가 무실점"이라는
불가능한 패턴이 된다. §3-A2에서 잔여 이닝 실점 모델로 고친다. 이걸 안 고치고 로그를
표면화하면 PMF 방식의 약점이 화면에 그대로 인쇄된다.

**티 ② — 중요 경기의 장내 점수와 사후 승패가 모순된다.** 이제 스코어보드가
"1점 리드"를 보여주는데(`PitchView.swift:337-`, `PitchScenario.swift:79-89`의
`scoreDifferential` 1~2), `resolveImportantGame`은 iOS가 `teamRuns: nil`을 보내므로
PMF에서 **독립적으로** 팀 득점을 새로 뽑는다(`ProCareer.swift:433`). 1점 리드 상황을
무실점으로 막았는데 최종 스코어 2:5 패전이 나올 수 있다. 스코어보드 개선(완료 항목 7)이
이 모순을 사용자 가시 결함으로 승격시켰다. §3-A1에서 진입 시 표차와 정합하는 정산으로 고친다.

수용하는 단순화(고치지 않는다, 근거 포함):
- **연장전 없음, 동점이면 노디시전** — 리그 최상위 무대(KBO)가 실제로 무승부 제도를 운영하므로
  한국 플레이어에게 동점 종료는 이상하지 않다. 행에 승패 칩을 안 붙이면 자연스럽다.
- **구원승 없음** (DecisionRules상 구원은 save/loss/nd만) — 벌처 윈은 전체 승의 소수이고,
  화면에 "구원승 0"을 따로 표기하지 않는 한 부재를 증명할 방법이 플레이어에게 없다.
- **홀드 없음** — 필승조 구간의 보상은 감독의 믿음·세이브 전환으로 이미 존재. 추후 확장 여지만 둔다.
- **홈/원정, 순위표 없음** — 순위 서사는 `seasonSegment`·`standingsRace` 트리거가 담당한다.
  순위표를 넣으려면 나머지 9개 구단의 시즌을 시뮬해야 하므로 PMF 결정의 취지와 정면 충돌한다.

대안(상대 팀 완전 시뮬)의 비용을 다시 확인했다: 타석 루프가 지금의 2배(상대 공격 이닝),
상대 투수 모델 신설, `check-balance` 밴드 전면 재튜닝. 화면에 더 나오는 것은 상대 타자
이름뿐이다. **기각 유지.**

### 2.2 고교 자동 경기의 드래프트 반영 ±4점 캡 — 유지. 단, "장식이 되지 않는 조건"을 명시한다

캡 반영이 앞뒤가 맞는지 실제 산식으로 검산했다. 현재 드래프트 점수는
`ratings/4 + 15 + gameQuality/4 + processBonus(≤10) + 각성 + 관계 + 분산(±5) − 업보 − 혹사`
(`HighSchoolCareer.swift:1380-1400`), 합격선 57~65. `gameQuality/4`는 직접 플레이 4~6경기에서
보통 ±8~15점을 만든다. 자동 경기 항 ±4는 그 절반 이하 — "직접 던진 순간이 지배한다"는
의도와 정합한다. **±4는 분산(±5)보다 작으므로, 자동 항만으로 당락이 뒤집히는 경우는
경계선 빌드뿐이다. 이것이 올바른 크기다.**

다만 ±4가 로그를 장식으로 만들지 않으려면 두 가지가 필수다:
1. **화면에 항을 분해해서 보여줄 것** — 드래프트 결과 카드에 "시즌 기록 +3" 식으로
   기여분이 한 줄 찍혀야 캡 반영이 존재를 증명한다(§5.4).
2. **자동 경기 성적이 능력치의 함수일 것** — 같은 커널로 던지므로 자동 충족된다.
   훈련으로 키운 능력이 자동 경기 RA9로 나타나고, 그것이 ±4로 돌아온다. 루프가 닫힌다.

캡이 없으면 어떻게 되나도 검토했다: 자동 14경기가 직접 4~6경기를 물량으로 눌러
"훈련 시켜놓고 구경하는 게임"이 된다. **캡 유지.**

## 3. A — 자동 시즌 마감 (코어, 남은 것) — P0

표면화(§4) 전에 끝내야 한다. 로그가 화면에 나온 뒤 `ProGameLine` 모양을 바꾸면
그때부터는 진짜 세이브 호환 문제가 된다. **지금은 `gameLines`를 쓴 빌드가 TestFlight에
나간 적이 없으므로**(이 작업은 미배포 워킹트리에만 존재) `ProGameLine` 필드 추가가
자유롭다 — 그래도 전 필드 옵셔널 + `decodeIfPresent` 관례를 따른다(비용이 0에 가깝고,
중간 빌드를 태운 내부 테스터를 보호한다).

### A1. 중요 경기 점수 정합 (티 ② 수정)

- `apps/ios/Sources/PitchSession.swift` — `report(scenarioNumber:)`가 현재 `outs`·`teamRuns`를
  **채우지 않는다**(159행, 코어의 폴백 경로가 실배포 경로다). 다음을 채운다:
  - `outs`: 세션 시작 시 `(inning-1)*3+outs`를 저장해 두고, 매 `absorb`에서 현재
    `gameState.inningState`로 갱신한 차분. `PitchSession`에 `outsRecorded: Int` 계산 프로퍼티 추가.
  - 신규 필드 `scoreDifferentialAtEntry: Int?`를 `ImportantInningReport`에 추가(옵셔널)하고
    `session.scenario.scoreDifferential`을 채운다. (`teamRuns`는 iOS가 직접 채우지 않는다 —
    절대 점수 배분은 코어의 일이다.)
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` — `resolveImportantGame`:
  `report.scoreDifferentialAtEntry`가 있으면 다음 정산으로 교체:
  ```
  opponentEarlier = rng.nextInt(upperBound: 4)              // 등판 전 상대 득점
  lateTeam        = rng.nextInt(upperBound: 3)              // 강판 후 우리 타선 추가 득점
  lateBullpen     = started ? rng.nextInt(upperBound: 3) : 0
  opponentRuns    = opponentEarlier + report.runsAllowed + lateBullpen
  teamRuns        = max(0, opponentEarlier + diffAtEntry + lateTeam)
  ```
  이러면 "1점 리드로 등판 → 무실점 → (불펜이 안 무너지는 한) 승리"가 성립하고, 패배는
  반드시 내 실점 또는 불펜 실점으로 설명된다. `scoreDifferentialAtEntry`가 nil이면(구세이브·
  데스크톱) 기존 PMF 경로 유지.
- 테스트: `ProCareerEngineTests`에 표 테스트 — 리드 유지→승, 리드+대량 실점→패,
  리드+무실점+5이닝 미만→ND, nil 폴백 경로. RNG 소비가 바뀌므로 기존 resolveImportantGame
  단정 재베이스라인.

### A2. 구원 등판의 상대 점수 모델 (티 ① 수정)

- `ProCareer.swift` `planWeek`: `bullpenRuns` 계산을 역할 공통의 "나 이외 실점"으로 교체:
  ```
  // 내가 던지지 않은 이닝의 실점. 선발이면 불펜 3~4이닝, 구원이면 나머지 8이닝 몫이다.
  let othersOuts = max(0, 27 - outingLine.outs)
  let othersRuns = LeagueBaseline.restOfTeamRuns(outsCovered: othersOuts, using: &rng)
  let opponentRuns = outingLine.runsAllowed + othersRuns
  ```
- `LeagueBaseline.swift`에 추가:
  ```swift
  /// 내가 던지지 않은 이닝에서 우리 팀 나머지 투수들이 준 점수.
  /// 팀 득점 PMF에서 하나 뽑아 잔여 이닝 비율로 줄인다 — 마무리가 등판한 날에도
  /// 앞선 여덟 이닝의 실점이 존재해야 상대 점수가 0~2점에 못 박히지 않는다.
  static func restOfTeamRuns(outsCovered: Int, using rng: inout SplitMix64) -> Int {
      let full = teamRuns(using: &rng)
      return full * outsCovered / 27
  }
  ```
- **세이브 판정과의 결합 주의**: `DecisionRules.decide`의 세이브 조건은
  `runsAllowed == 0 && 리드 ≤ 3` 유지 — othersRuns가 커지면 세이브 기회 자체가
  줄어드는 방향이므로 마무리 세이브 전환율을 §6 밴드로 감시한다.
- 재베이스라인: `planWeek` RNG 소비 순서 변경 — `ProCareerEngineTests`의 주간 결과 단정 갱신.

### A3. `ProGameLine`에 피안타·피홈런 + 시즌 롤오버 정리

- `WeeklyOutingLine`에 `hits`, `homeRuns` 추가. 루프 안에서 `result.snapshot.outcome`이
  single/double/triple/homeRun일 때 집계(현재 K·BB만 센다, `ProCareer.swift:618-621`).
- `ProGameLine`에 `hits: Int?`, `homeRuns: Int?` **옵셔널** 추가 + 수기 `init(from:)`
  (`ProSeasonStats.losses` 디코더와 같은 관례). `resolveImportantGame` 쪽은 `PitchSession`이
  피안타를 세지 않으므로 nil 허용(행 표기는 "6.1이닝 7K 2BB 2실점"으로 피안타 없이도 성립).
- **시즌 롤오버**: `chooseOffseason`이 현재 `gameLines`를 **리셋하지 않는다**
  (`ProCareer.swift:521`의 `replacing`이 그대로 끌고 간다 — 구원 12시즌이면 800행,
  `outingNumber`도 시즌을 넘어 계속 증가). 새 시즌 진입 시 `gameLines: []`로 비운다.
  과거 시즌은 `careerStats` 합계가 담당한다. `outingNumber`는 시즌 내 등판 번호로 복원된다.
- 테스트: 롤오버 후 `gameLines == []` 단정, hits 옵셔널 디코드 왕복
  (`RoundTripStabilityTests` 패턴), 피안타 집계 단정 1건.

### A4. (조건부) 상대 팀명

- `ProGameLine`에 `opponentTeamID: String?` 옵셔널 추가. `planWeek`에서
  `Self.proTeams`(자기 팀 제외 9팀)를 `(week + outingIndex)` 결정론 로테이션으로 선택.
  중요 경기는 `state.currentRival?.teamID`. 표기는 팀명 축약(예: "부산 블루웨일스"→"부산" —
  `DraftTeamSnapshot.name`의 첫 어절). 밸런스 영향 0(표기 전용, 타선 강도와 무관).
- 일정이 밀리면 이 항목만 잘라도 §4는 성립한다(행에서 상대명 생략).

## 4. B — iOS 표면화 (핵심 남은 작업) — P1

DOC-19 §7 언어(눈썹+괘선, 모노스페이스 큰 숫자, 의미색 면은 상태 변화만). 코어 무변경.

### 4.1 `RecordView.swift` — 시즌 헤더와 경기 로그

- 헤더 Metric 3종 중 "승"(46행)을 `"\(wins)-\(losses)-\(saves)"` 값의 **"승-패-세이브"**로 교체.
  9이닝당 실점은 유지(`runsPerNine`).
- **경기별 로그 리스트 신설**: `state.gameLines ?? []`를 역순으로, 상자 없이 괘선 구분.
  한 행(전부 역할 토큰·`monospacedDigit`):
  ```
  12주차 · 선발 6.1이닝 · 7K 2BB 2실점 · 4:2 승
  ```
  - 이닝은 `ProGameLine.inningsText`(이미 존재). 점수는 `"\(teamRuns):\(opponentRuns)"`.
  - 승패 칩: win "승"(positive 글자색) / loss "패"(negative) / save "세이브"(positive) /
    noDecision **표기 없음**. 의미색 면 금지 — 글자색만(§7.2 준수).
  - `played == true` 행은 라임 눈썹 **"직접 등판"**. 이것이 이 화면의 유일한 강조다.
  - 행 수가 많으므로(구원 최대 72행) `LazyVStack` + 최근 20행 기본, "전체 보기" 토글.
  - 접근성: 행 단위 `.accessibilityElement(children: .combine)`.
- 과거 시즌 행(61-68행)에 `승-패-세이브`와 9이닝당 실점 추가:
  `"14G · 88.2이닝 · 9-4-0 · 3.85"`.
- 빈 상태: `gameLines`가 nil/빈 배열(구세이브·시즌 초)이면 로그 섹션 자체를 숨긴다.

### 4.2 `AppShell.swift` — TodayDashboard "최근 등판" 카드

- `TodayDashboard`(184행~)의 "최근 소식" 카드 **위**에 신설:
  ```swift
  if let line = state.gameLines?.last {
      BaseballCard(title: "최근 등판") { ... }
  }
  ```
  내용: 큰 모노스페이스 스코어 `4:2`(heroNumeral 축소형) + 결과 문구(승/패/세이브/노디시전) +
  `"6.1이닝 · 7K · 2BB · 2실점"` 한 줄 + `played`면 "직접 등판" 눈썹.
  **`advanceBlock()`으로 3주를 건너뛰어도**(`MobileCareerStore.swift:110-119`) 이 카드와
  §4.1 로그에 그 주들의 등판이 전부 남는 것이 이 작업의 존재 이유다.
- 뉴스 프로즈(`planWeek`의 "N주차 · X경기 · ..." 라인)는 그대로 둔다 — 중복이 아니라
  질감이 다르다(뉴스는 흐름, 카드는 구조).

### 4.3 테스트·CI

- `PitchSessionTests`/`PresentationTests`에 행 포맷터 유닛(이닝 표기·칩 분기·ND 무표기).
- `CareerSmokeUITests`: 기록 탭 진입 → `record.gameLog` 식별자 존재 단정
  (주 1회 진행 후). 새 식별자: `record.gameLog`, `today.lastOuting`.
- `check:design-system`: 고정 폰트·얇은 막대 규칙 통과 확인. `contractChecks`에 2줄 추가:
  `["apps/ios/Sources/RecordView.swift", "gameLines"]`,
  `["apps/ios/Sources/AppShell.swift", "최근 등판"]`.
- `check:copy`: "승-패-세이브"·"직접 등판"·"노디시전" 모두 금지어 목록과 충돌 없음(확인 완료).

## 5. C — 고교 시즌 (자동 경기·시즌 기록·드래프트 캡 항) — P2

현재 고교에는 시즌 기록이 없다 — 누적 `CareerPerformanceSnapshot`(7필드,
`HighSchoolCareer.swift:216-255`)뿐이고 팀의 나머지 경기는 세계에 존재하지 않는다.

### 5.1 코어 — `AutoOutingSimulator` 추출 (공용화)

- `ProCareerEngine.simulateWeeklyOuting`(`ProCareer.swift:552-650`)을
  `SimulationCore/AutoOutingSimulator.swift` **public** 타입으로 이동:
  ```swift
  public struct AutoOutingSimulator {
      public struct Line { outs, hits, homeRuns, strikeouts, walks, runsAllowed, pitches }
      public func simulate(pitcher:startingFatigue:outsTarget:pitchCap:batterOffset:baseSeed:) -> Line
  }
  ```
  `batterOffset: Int = 0`을 타자 3능력치 기준선(50)에 가산 — 고교 상대(§5.2)와 CLI(§6)가 쓴다.
  `ProCareerEngine`은 위임 호출로 바꾼다(RNG 소비 순서 불변 — 재베이스라인 없음을 테스트로 확인).
- public으로 여는 이유: `SimulationCLI`는 별도 모듈이라 internal에 접근 못 한다(§6).
  `DecisionRules`·`LeagueBaseline.teamRuns`도 CLI가 쓰므로 public으로 승격.

### 5.2 코어 — 챕터 자동 경기와 시즌 로그

- `HighSchoolCareerEngine.advanceChapter`(`HighSchoolCareer.swift:1366-1375`)에서 챕터를
  넘길 때 자동 경기 **2회**를 돌린다(총 8챕터 → 자동 14경기 + 직접 4~6경기):
  - `AutoOutingSimulator.simulate(outsTarget: 18, pitchCap: 90, batterOffset: 챕터 오프셋)`.
    오프셋: 일반 챕터 `-6`(고교 평균 타자는 프로 기준 50보다 약하다), 대회 테마 챕터
    (`chapter.theme`에 "대회" 포함) `0`.
  - 팀 득점은 `LeagueBaseline.highSchoolTeamRuns`, 상대 점수는 `runsAllowed +
    restOfTeamRuns(outsCovered: 27-outs)`(고교 PMF 버전 추가), 판정은 `DecisionRules.decide`.
  - `HighSchoolCareerSnapshot`(이미 `final class` — 필드 추가 안전)에
    `seasonLog: [ProGameLine]?` **옵셔널** 추가. `ProGameLine`을 재사용하되
    `season = chapter.schoolYear`, `week = chapter.number`, `played = false`.
    직접 플레이한 중요 경기도 정산 시 `played: true`로 합류시킨다
    (`resolveImportantGame` 상당 경로 — 고교 쪽 정산 함수에서 `performance.adding` 직후).
  - `==`·수기 디코더·`replacing`에 필드 추가. **commitment 해시에 넣지 않는다.**
- `advanceChapter`는 현재 RNG를 소비하지 않으므로, 시드에서 로컬 `SplitMix64`를 만들어
  쓰고 `nextSeed` 체인은 기존 방식 유지. **`HighSchoolCareerEngineTests` 중 챕터 전이를
  단정하는 테스트 재베이스라인 필요.**

### 5.3 코어 — 드래프트 캡 항

- `resolveDraft`(`HighSchoolCareer.swift:1377-1400`)의 `score` 합산에 추가:
  ```swift
  // 자동 시즌 항: 시즌 로그의 9이닝당 실점을 ±4점으로 접는다. 직접 던진 승부(gameQuality)가
  // 지배해야 하므로 캡이 분산(±5)보다 작다 — 경계선 빌드에서만 당락을 움직인다.
  let autoLines = (params.state.seasonLog ?? []).filter { !$0.played }
  let autoOuts = autoLines.reduce(0) { $0 + $1.outs }
  let autoRuns = autoLines.reduce(0) { $0 + $1.runsAllowed }
  let seasonTerm = autoOuts == 0 ? 0
      : clamp((5_500 - autoRuns * 27_000 / autoOuts) * 2 / 1_000, -4, 4)   // RA9 3.5→+4, 5.5→0, 7.5→-4
  ```
  구세이브(`seasonLog == nil`)는 항이 0 — 점수 불변, 호환 유지.
- `DraftResultSnapshot.summary` 또는 신규 옵셔널 `evaluationBreakdown: [String]?`에
  `"시즌 기록 \(seasonTerm >= 0 ? "+" : "")\(seasonTerm)"`을 포함 — §2.2의 "존재 증명" 조건.
- 테스트: seasonTerm 표 테스트(0이닝→0, RA9 3.0→+4 캡, RA9 9.0→-4 캡), 구세이브 nil 경로,
  드래프트 컷라인 회귀(1라운드 비율 ~35-45% 스펙은 `HighSchoolCareerEngineTests`의 기존
  분포 테스트로 감시 — seasonTerm이 평균 0 근처가 되도록 오프셋 튜닝).

### 5.4 iOS — 고교 기록 섹션

- `HighSchoolCareerView.swift`에 학년 전환·드래프트 직전 화면에서 보이는 기록 섹션:
  학년별 누계(경기·이닝·K·BB·실점·9이닝당 실점, `seasonLog` 집계) + 최근 경기 행(§4.1 포맷 재사용,
  상대명 없음). 드래프트 결과 카드에 평가 분해 줄("시즌 기록 +3") 표기.
- 카피는 `HighSchoolPresentation.swift`. UITest: 드래프트 화면에서 `hs.seasonRecord` 식별자.

## 6. D — `check-balance` 등판 밴드 + CLI — P3

- `SimulationCLI/main.swift`에 `--outings N` 모드 추가: §5.1의 public
  `AutoOutingSimulator`로 티어-50 선발(기존 `--preset`/`--contact` 인자 재사용,
  outsTarget 18 · pitchCap 96 · offset 0) N경기를 돌리고 `DecisionRules`로 판정까지 붙여
  JSON 집계 출력: `{games, outs, strikeouts, walks, runsAllowed, pitches, wins, losses, saves, noDecisions}`.
- `tools/check-balance.mjs`에 섹션 추가 (`--outings 400`):
  | 지표 | 밴드(초안) |
  |---|---|
  | 9이닝당 실점 | 3.5 ~ 5.5 |
  | K/9 | 6.5 ~ 10.5 |
  | BB/9 | 2.0 ~ 4.5 |
  | 선발 승률(승/경기) | 0.25 ~ 0.55 |
  | 노디시전 비율 | 0.15 ~ 0.45 |
  **절차**: 먼저 로컬에서 측정값을 뽑고, 밴드 밖이면 `LeagueBaseline` 상수(othersRuns·PMF)를
  튜닝한 뒤 커밋한다. 측정 없이 밴드를 넓혀 맞추지 않는다 — 밴드 변경은 이 문서에 사유를 적는다.
- 마무리 세이브 전환율은 CLI 2회차(`outsTarget 3`)로 별도 측정, 밴드 0.25~0.55.


### 6.1 실측 결과 (2026-07-26) — 밴드 확정

`swift run -c release simulation-cli --outings 400`(기본 프리셋 `power_prospect`, 상대 타선 50):

| 지표 | 실측 | 확정 밴드 | 실제 야구 |
|---|---|---|---|
| 평균 이닝 | 5.55 | 4.6 ~ 6.2 | 약 5.2 |
| RA9 | 3.42 | 2.6 ~ 4.6 | 약 4.4 |
| K/9 | 9.81 | 8.0 ~ 11.5 | 약 8.5 |
| BB/9 | 1.79 | 1.2 ~ 3.2 | 약 3.2 |
| 선발 승률 | 0.490 | 0.30 ~ 0.62 | 약 0.35 |
| 노디시전 | 0.198 | 0.10 ~ 0.35 | 약 0.35 |
| 마무리 세이브율 | 0.245 | 0.15 ~ 0.40 | — |

**드러난 부채 — 커널이 실제 야구보다 투수에게 유리하다.**

신인급 프리셋(구위 42·제구 34, 50이 리그 평균)이 평균 타자를 상대로 **RA9 3.42·BB9 1.79**를
찍는다. 평균 이하 투수가 엘리트 성적을 내고 있다는 뜻이다. 타석 단위 검사가 이걸 못 잡은 것은
밴드가 넓기 때문이다(BB% 허용 0.04~0.11인데 실측 0.055 — MLB는 약 0.085).

원인 후보 둘: ① 커널의 볼넷·헛스윙 판정이 투수 쪽으로 기울어 있다, ② 포수 사인 상황 정책(§4)이
볼넷을 적극적으로 회피하면서 BB9를 더 눌렀다.

**이번 작업에서 고치지 않았다.** 커널 판정을 건드리면 골든 픽스처·타석 밴드·적응 위계가 한꺼번에
움직이고, 그건 별도 작업이다. 대신 밴드를 **실측값 기준 회귀 탐지선**으로 두고 이 격차를 여기
적어 둔다. 밴드를 실제 야구 값으로 좁히면 오늘 당장 실패한다. 격차를 줄이는 작업을 할 때 이
밴드도 함께 좁힌다. **밴드를 넓혀 통과시키는 것은 금지** — 벗어나면 원인을 찾는다.

부수 확인: 제구형 프리셋이 파워형보다 볼넷이 적다(1.23 < 1.79). 프리셋 차이가 등판 성적에
반영되므로 육성 선택이 실제로 성적을 바꾼다.

## 7. E — 아트 브리프 → 이미지 — P4 (병렬 가능, 코드 의존 없음)

파이프라인 실측: `KeyArtHeader`(`DesignSystem.swift:297-`)는 `KeyArt` enum(현재 3케이스:
`proStadiumTunnel`·`stadiumNight`·`careerIntro`) + imageset, 높이 **190pt**(`keyArtHeight`,
`DesignSystem.swift:122`), 하단을 캔버스색 그라데이션으로 페이드, 고대비에서 단색 폴백 자동.
**규격: 390×190pt @3x = 1170×570px PNG.** 이미지 안 글자 금지, 실존 구단·리그 요소 금지,
주 피사체는 상단 2/3(하단은 페이드로 덮인다), Midnight Dugout 팔레트(야간 남색+라임).

생성은 codex CLI `image_gen`으로 별도 수행. 우선순위 순:

| # | 화면 (삽입 위치) | enum case / 에셋명 | 브리프 |
|---|---|---|---|
| 1 | 학교 선택 (`HighSchoolCareerView` 학교 카드 상단) | `schoolCrossroads` / `KeyArtSchoolCrossroads` | 이른 봄 저녁, 고교 야구장 갈림길에 선 교복 뒷모습 실루엣. 네 조명탑이 지평선에 다른 밝기로. 라임빛 노을 한 줄 |
| 2 | 드래프트 결과 (draft phase 카드) | `draftDay` / `KeyArtDraftDay` | 어두운 대기실, 중계 화면 빛만 얼굴에 떨어지는 옆모습. 손에 쥔 모자. 지명 직전의 긴장 |
| 3 | 1군 데뷔 (`major_debut` 트리거 시) | `majorDebut` / `KeyArtMajorDebut` | 불펜 게이트가 열리며 쏟아지는 관중석 빛, 게이트 안 어둠의 투수 실루엣 |
| 4 | 은퇴 회고 (`.completed` 화면) | `retirement` / `KeyArtRetirement` | 소등 직후 빈 구장, 마운드 위 글러브와 공 하나 |
| 5 | 환생 전환 (기억 선택 화면) | `reincarnation` / `KeyArtReincarnation` | 밤하늘로 떠오르는 공이 별자리 궤적을 그리고, 궤적 끝이 새벽 고교 구장으로. "다시"의 톤 |
| 6 | 각성 (AwakeningCard 상단) | `awakening` / `KeyArtAwakening` | 손끝 실밥이 라임빛으로 발광하는 클로즈업, 배경은 흐린 야간 훈련장 |

- 파일: `Assets.xcassets` imageset 6개, `DesignSystem.swift` `KeyArt` case 6개, 각 화면
  `KeyArtHeader` 1줄. 용량 +~3MB(허용). 학교별 4장 확장은 **하지 않는다**(§9-3).
- 잔여 소품목(같은 PR로): **각성 확인 다이얼로그** — 학교 선택과 동일 패턴
  (`HighSchoolCareerView.swift`의 confirmationDialog는 현재 학교 1곳뿐).
  제목 `"'{옵션명}'으로 각성할까요?"`, 식별자 `hs.awakening.confirm`, UITest 갱신.

## 8. 교차 영향 총괄 (전 작업 공통 체크리스트)

| 영역 | 규칙 |
|---|---|
| **세이브 호환** | 신규 필드 전부 옵셔널 + 수기 `decodeIfPresent` 디코더 + **commitment 해시 불포함**. `ProCareerSnapshot`·`HighSchoolCareerSnapshot`의 commitment 입력 목록(`ProCareer.swift:653`)에 새 필드를 넣지 않는다. 어기면 구세이브 `state commitment mismatch`로 전멸 |
| **Swift 6.3 outlined destroy** | 두 스냅숏은 이미 `final class`라 필드 추가 안전. **값 타입 주의 대상**: `ProGameLine`(A3·A4 후 16 저장 프로퍼티), `ImportantInningReport`(A1 후 11개). 전체 스위트를 한 바이너리로 돌려(`swift test`, `--filter` 금지) SIGSEGV가 나면 해당 타입을 final class로 박싱한다 — 개별 필터 실행은 통과해 버리므로 증거가 안 된다 |
| **골든 픽스처** | 안전 유지 조건: 커널(`PitchKernelEngine`·`SimulationEngine`) RNG 스트림을 소비하는 코드를 추가하지 않는다. A1·A2·5.2의 새 난수는 전부 ProCareer/HS 레벨 `rng` 체인. `simulate_pitch_golden.json`은 `SimulationEngine.simulatePitch`만 커버 |
| **재베이스라인** | A1: resolveImportantGame 단정. A2: planWeek 단정. 5.2: HS 챕터 전이 단정. 5.1 추출은 재베이스라인 **없음이 정상** — 생기면 추출이 잘못된 것 |
| **CI 게이트** | `check:design-system` — 고정 폰트 0·얇은 막대 허용 목록 밖 0·contractChecks 기존 문자열 보존 + §4.3 신규 2줄. `check:copy` — 새 카피에 금지어 없음(§4.3에서 확인 완료), 자동 경기 코드 주석에 "KBO"/실구단명 금지. `check:balance` — A2 후 재실행, §6 밴드 추가 후 통과 확인 |
| **데스크톱 (일시 중지)** | 옵셔널 필드 추가는 RPC·TS 구조적 타이핑에 무해. `apps/windows/src/simulationTypes.ts`는 수동 미러 — **재개 시** `ProGameLine`·`seasonLog`·`PitchingDecision` 동기화 목록에 추가만 해 둔다(지금 작업 금지). 데스크톱 `PitcherLabView`는 `outs:`를 안 보내므로 폴백 경로가 이를 커버한다 |

## 9. 확정된 결정 (재논의하지 않는다)

1. **승패는 팀 득점 PMF + 판정 규칙** — 확정. 단 §3-A1(중요 경기 점수 정합)·A2(구원 상대
   점수)를 전제 조건으로 한다. 상대 팀 완전 시뮬 기각.
2. **고교 자동 경기 드래프트 반영 ±4 캡** — 확정. 평가 분해 표기(§5.3)가 전제 조건.
3. **학교 키아트는 갈림길 1장** — 확정. 학교별 4장 확장 안 함.
4. **관계 응답은 원탭 유지** — 확정.
5. **스코어보드는 표차 표기** — 이미 구현·출고 상태로 확정.
6. **시즌 로그는 시즌 단위 리셋**(§3-A3) — 통산은 `careerStats` 합계가 담당. 확정.

## 10. 구현 순서 (이대로 위에서 아래로)

| 순서 | 작업 | 층 | 규모 | 선행 |
|---|---|---|---|---|
| 1 | §3 A1~A4 코어 마감 (점수 정합·구원 모델·피안타·롤오버·상대명) | 코어+iOS 세션 | 1.5~2일 | 없음 |
| 2 | §4 iOS 표면화 (RecordView 로그·최근 등판 카드) | iOS | 2~3일 | 1 |
| 3 | §5 고교 시즌 (시뮬레이터 추출·자동 경기·캡 항·기록 섹션) | 코어+iOS | 2~3일 | 1 (5.1은 병렬 가능) |
| 4 | §6 밸런스 밴드 + CLI | 코어+tools | 0.5~1일 | 1, 3(공용 시뮬레이터) |
| 5 | §7 아트 6장 + 각성 다이얼로그 | 에셋+iOS | 0.5일+생성 | 없음 (전 단계와 병렬) |

완료 정의: `swift test`(전체 한 바이너리) · iOS 유닛+UITest · `npm run check:design-system` ·
`check:copy` · `check:balance`(신규 밴드 포함) 전부 통과 + 시뮬레이터에서 3주 건너뛰기 후
기록 탭에 등판 로그가 남는 것을 확인.
