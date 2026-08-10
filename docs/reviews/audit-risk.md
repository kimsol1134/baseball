# 변경 위험·회귀 감사 — `codex/steam-release-rc` (5603fb8..HEAD + 작업 트리)

감사 범위: 커밋 12개(`5603fb8..64e2bb7`) + 미커밋 작업 트리. 총 68파일 / +6,386 −534.
저장소 소스는 **수정하지 않았다.** 실험은 전부 `/tmp/wkaudit`, `/tmp/oppaudit`에서 했다.

실제로 실행한 검증:
- `swift test`(simulation-core 전체) — **exit 0이 아니라 signal 11로 죽는다**(아래 F11 참조). 부분 실행으로 대체.
- `swift test --filter "SimulationEngineTests|PitchAbilityRulesTests|PitchDeliveryTests|AwakeningTreeTests|CareerSignatureLegacyTests"` → **44 tests, 0 failures**.
- `shasum -a 256 -c docs/MANIFEST.sha256` → 9건 FAILED(전부 오늘 변경과 무관한 기존 누락).
- Codable 전/후방 호환 디코딩 실험(`/tmp/wkaudit`).
- `trainingOpportunity` 재현 실험 4,000커리어 × 15회(`/tmp/oppaudit`).

---

## F1. 우타자의 타구 방향이 **좌우 반대로** 나간다 — 심각도: **높음(P0)**

**근거**
`packages/simulation-core/Sources/SimulationCore/PitchKernelEngine.swift:1413-1414`
```swift
let pullDirection = params.batter.batSide == .left ? -1 : 1
let pullShift = (1 - landedZone.column) * 90 * pullDirection
```

방향 부호의 의미는 코드 안에서 확정된다:
- `GameSituation.swift:472-478` — `direction < -180 → thirdBase`, `< -150 → leftField`. **음수 = 좌익 방향.**
- `apps/ios/Sources/PitchDramaView.swift:471-473` — `thirdBase: (26, -38)`, `leftField: (88, -32)`. 같은 부호 규약.

칸 번호의 의미도 확정된다:
- `PitchKernelEngine.swift:1261-1264` — `column = actualX <= -165 ? 0 : ...`
- `apps/ios/Sources/PitchView.swift:5-19` — 라벨표는 우타 기준, `column 0 = 몸쪽`(좌타는 `2 - column`으로 뒤집는다).
- `PitchDramaView.swift:172-178` — 우타 실루엣이 `zone.minX`(음수 x) 쪽에 선다. 즉 음수 x = 우타의 몸쪽.

따라서 **우타자**:
- 몸쪽(column 0) → 당겨야 함 → 좌익 → 음수. 코드는 `(1-0)*90*(+1) = +90` → **우익**. 반대.
- 바깥쪽(column 2) → 밀어야 함 → 우익 → 양수. 코드는 `−90` → **좌익**. 반대.

**좌타자**는 우연히 맞는다(column 0이 좌타에게는 바깥쪽 → 좌익 → −90 = 맞음).

**터지는 시나리오**
타자의 대부분인 우타를 상대로, 몸쪽 낮은 공을 던지면 2루수·우익수 쪽으로 굴러간다. `position(for:)`가 수비수를 그 방향으로 배정하므로 **병살 성립·수비 위치·장타 코스가 전부 야구와 반대로 돈다.** 이 커밋의 취지("코스 축이 실제로 의미 있게")를 정확히 뒤집는다. 화면(`PitchDramaView`)이 탑다운 궤적을 그리므로 야구를 아는 유저에게 즉시 보인다.

**고칠 방향**
`pullDirection`을 뒤집는다: `params.batter.batSide == .left ? 1 : -1`.
동시에 `PitchKernelEngineTests`에 "우타 + 몸쪽 → direction < 0, 좌타 + 몸쪽 → direction > 0" 두 줄짜리 단정을 넣는다. **지금 이걸 잡는 테스트는 한 줄도 없다**(`grep`로 `direction`을 쓰는 커널 테스트는 전부 `BattedBall`을 직접 만들어 수비만 검증한다).

---

## F2. 새 `WeeklyTaskKind` case가 **구버전 앱의 주간 저장을 통째로 날린다** — 심각도: **높음(P1)**

**근거**
- `apps/ios/Sources/WeeklyProgram.swift:9` — `case playedOnTwoDays = "played_on_two_days"` 추가.
- `apps/ios/Sources/WeeklyProgramStore.swift:243-252` — `SaveRecord`가 `program`(=`tasks[].kind`) + `stamps` + `revision` + `processedReceiptIDs` + `pendingReceipts`를 **한 파일에** 담는다.
- `WeeklyProgramStore.swift:271-272` — `try? JSONDecoder().decode(SaveRecord.self, ...)` — 실패하면 통째로 `nil`.
- `apps/ios/Sources/SaveSync.swift:12,33` — 이 파일은 **iCloud KVS로 동기화된다**(`NSUbiquitousKeyValueStore`).

실측(`/tmp/wkaudit`):
```
OLD->NEW: OK  stamps=1 rev=7            ← 옛 저장 → 새 앱: 정상
NEW->OLD (try?): nil — 전체 레코드 소실
NEW->OLD error: DecodingError.dataCorrupted:
  Path: program.tasks[0].kind. Cannot initialize OldKind from invalid String value played_on_two_days
```

**터지는 시나리오**
아이폰만 1.0.3으로 올리고 아이패드는 1.0.2에 남는 흔한 상황. 새 기기가 `played_on_two_days`가 든 보드를 iCloud에 올리는 순간, **옛 기기의 주간 노트·누적 스탬프·처리 영수증 원장·revision이 전부 0에서 다시 시작한다.** 영수증 원장이 비면 같은 행동이 두 번 반영될 수 있고, 이번 주 진행은 사라진다. (새 기기는 로컬 revision이 더 높아 무사하다.)

**고칠 방향**
`WeeklyTask`에 커스텀 `init(from:)`을 두어 알 수 없는 `kind`를 **버리되 나머지는 살리는** 관용 디코딩으로 바꾸거나, `kind`를 `String`으로 저장하고 표시 시점에 매핑한다. 출시 후에도 계속 case가 늘 것이므로 이건 이번 한 번의 문제가 아니다.
테스트: "새 case가 든 JSON에서 알 수 없는 항목만 빠지고 stamps/revision은 보존된다"를 `WeeklyProgramTests`에 추가.

---

## F3. 개인 최고 기록 축하가 **뜨자마자 사라진다** — 심각도: **중(P1)**

**근거**
`apps/ios/Sources/PitchView.swift:807, 819` 와 `827, 853`
```swift
let isWhiffRecord = whiffs > bestWhiffsInOuting          // body 평가 시점에 계산
...
.onAppear { if isWhiffRecord { bestWhiffsInOuting = whiffs } }   // @AppStorage 쓰기
```
```swift
let isRecord = average > bestDeliveryAverage
...
.onAppear { if isRecord { bestDeliveryAverage = average } }
```

**터지는 시나리오**
`@AppStorage` 쓰기 → 뷰 무효화 → body 재평가 → 이제 `isRecord == false` → "개인 최고" 배지, `BaseballTheme.milestone` 강조, "지금까지 가장 좋았습니다 / 한 등판 최다 헛스윙 — 키운 구위가 손에 잡힙니다" 문구가 **같은 프레임에 사라진다.** 즉 이번 커밋이 만든 "나아지고 있다는 증거"가 실제로는 한 순간도 화면에 남지 않는다. `.onAppear`는 다시 안 불리므로 값 자체는 정상 저장된다 — **저장은 되고 축하만 없다.**

**고칠 방향**
등판이 끝나는 시점(`stage`가 `.finished`가 되는 곳)에 `@State`로 `recordSnapshot`을 한 번 굳히고, 화면은 그 스냅숏을 읽는다. `@AppStorage` 쓰기는 그 뒤에.
테스트: 이건 SwiftUI 렌더 순환이라 단위 테스트가 어렵다 — `CareerSmokeUITests`에서 등판 종료 후 `pitch.deliveryAverage` 안의 "개인 최고" 존재를 확인하는 편이 현실적이다.

---

## F4. 공유 카드가 **매 렌더마다 1080×2040 비트맵을 동기 래스터화**한다 — 심각도: **중(P1)**

**근거**
- `apps/ios/Sources/LifeCardView.swift:358-366` — `LifeCardRenderer.image()`는 **캐시가 없다.** 호출할 때마다 `ImageRenderer(content: LifeCardView(...))`, `scale = 3`.
- `LifeCardView.swift:405`, `425` — `LifeCardPreview.body`와 `LifeCardShareButton.body`가 **body 안에서** 그걸 부른다.
- `apps/ios/Sources/HighSchoolCareerView.swift:1903-1914` — 기억 선택 화면에서 `lifeRecord(...)`를 body 안에서 새로 만들고 `LifeCardPreview` + `LifeCardShareButton`을 **나란히** 둔다 → 한 번의 body 평가에 **풀 렌더 2회**.
- 카드 높이는 600 → **680**으로 커졌고(`LifeCardView.swift:14`), 안에 `ViewThatFits` 후보 6개(`:200-206`)가 들어갔다 — 레이아웃 시도가 6번 돈다.
- `HighSchoolCareerView.swift:2179` 도 같은 패턴(`lifeRecord(...)` 인라인 생성 + 렌더).

**터지는 시나리오**
회차 마감 화면에서 기억 체크박스를 하나 누를 때마다 1080×2040 @3x 렌더가 2회 메인 스레드에서 돈다. 이 게임에서 감정이 가장 높은 화면이 가장 끊긴다. 구형 기기일수록 심하다.

**고칠 방향**
`LifeCardRenderer`에 `record`(또는 그 안정 ID) 키 캐시를 두거나, 화면이 `@State private var cardImage: UIImage?` 로 한 번만 굽고 `.task(id:)`로 갱신한다. `LifeCardShareButton`은 이미지를 **탭한 뒤** 굽는 것으로 충분하다.

---

## F5. "오늘의 기회"가 **몸 상태에 따라 눈앞에서 바뀌고**, 저피로에서 연속 중복이 21% 난다 — 심각도: **중(P2)**

**근거**
`packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift:3051-3073`
```swift
static func trainingOpportunity(careerID:index:fatigue:injuryRecovery:) {
    var pick = ...                              // 시드
    if index > 0 { ... if pick == previous { pick = (pick+1) % count } }   // 연속 방지
    let recoveryEarned = fatigue >= 45 || injuryRecovery > 0
    if !recoveryEarned { while pool[pick] == .recovery { pick = (pick+1) % count } }  // ← 연속 방지 이후
}
```
연속 방지 규칙이 **회복 건너뛰기보다 먼저** 돌기 때문에, 건너뛴 결과가 직전 초점과 같아질 수 있다.

실측(`/tmp/oppaudit`, 4,000커리어 × 15회):
```
저피로(회복 미획득) 연속 중복: 12,714/60,000 = 21.19%
고피로 연속 중복:                655/60,000 ≈ 1.1%
```
(고피로 쪽 1.1%는 연속 방지 비교 대상이 "보정 전 previous"라서 생기는 **기존** 미세 결함이고, 오늘 것이 아니다.)

`HighSchoolCareerEngineTests.swift:1420-1431`의 연속 방지 테스트는 `fatigue` 인자를 안 주므로 **기본값 100**으로 돌아간다 → 회복 건너뛰기 경로가 통째로 미검증이다.

추가로 `HighSchoolCareer.swift:3021-3025`에서 `updated(...)`가 **호출될 때마다** 기회를 다시 계산하고, 이제 그 입력에 가변 `fatigue`가 들어간다. 훈련 인덱스가 그대로여도 경기/관계 사건으로 피로가 45를 넘나들면 **같은 자리의 기회 문구가 바뀐다.** `opportunityHit`(성장 보너스, `:1511`)의 판정 기준도 함께 흔들린다.

**고칠 방향**
회복 건너뛰기를 연속 방지보다 **먼저** 돌리거나, 건너뛴 뒤 `previous`와 한 번 더 비교한다. `fatigue` 인자를 넣은 연속 방지 테스트를 추가한다.

---

## F6. 커널 결과에 **버전 간 골든 기준선이 없다** — 심각도: **중(P2, 테스트 공백)**

**근거**
- 커밋된 픽스처는 `packages/simulation-core/Tests/SimulationCoreTests/Fixtures/simulate_pitch_golden.json` 하나뿐이고, `SimulationEngineTests.swift:21-34`가 쓰는 **`SimulationEngine`(단순 `simulate`) 전용**이다. `PitchKernelEngine`을 지나가지 않는다.
- `PitchDeliveryTests`의 `testAbsentDeliveryKeepsTheOriginalEventHash` / `testNeutralDeliveryIsIdenticalToNoDelivery`는 **같은 빌드 안의 두 호출을 비교**할 뿐 커밋된 상수와 대조하지 않는다.

**시드 소비 순서는 안 바뀌었다** — 확인했다. 오늘 추가된 항은 전부 난수 추출 **뒤**에 붙는 순수 산술이다:
`PitchKernelEngine.swift:1414`(pullShift), `:1429`(heightAngleShift), `:1445-1450`(direction clamp), `:1381-1382`(perfectQualityBonus), `:1426`(perfect 구속 +6). 새 `generator.next*` 호출은 없다. `nextSeed` 진행은 동일하다.

**그러나 결과 자체는 바뀐다.** `contactChance` 720→790(`:1370`), `contactQuality` 430→495(`:1397`), `ratingDifficulty`의 `executionQuality` 항 `/2`→`/6`(`:1334, :1341`), `stuff` ×2→×3 + `pitcher.movement` ×2 신설(`:1331-1334`), 구속 벌 `/10`→`/5`(`:1408`), 2스트라이크·3볼 스윙질 보정(`:979-1002`).

**터지는 시나리오**
같은 커밋에서 `LifeCardShareText`(`LifeCardView.swift:378-390`)가 카드에 **"같은 판에 도전: `<seed>-<life>`"**를 적어 내보내기 시작했다. 1.0.2에서 공유한 카드를 1.0.3에서 열면 같은 시드가 **다른 경기**를 만든다. 게임이 문구로 약속한 것을 코드가 지키지 못한다.

**고칠 방향**
(a) 커널 이벤트 해시를 담은 골든 픽스처를 추가하고 밸런스 변경 시 의도적으로 갱신하는 절차를 둔다. (b) 시드 문구에 밸런스 버전을 함께 각인하거나("같은 판" 약속을 버전 안으로 한정), 재현 경로가 없으면 그 줄을 빼는 것이 정직하다.

---

## F7. 진행 중 v4 회차는 **지명이 쉬워지고 남은 장은 어려워진다** — 심각도: **중(P2)**

**근거**
같은 릴리스에서 세 가지가 동시에 움직였다:
1. `HighSchoolCareer.swift:2130-2132` — v4 지명 계수 `K×3 − BB×2 − R×3` → `K×4 − BB×2 − R×2`.
2. `HighSchoolCareer.swift:1996-2001` — v4 시즌 영점 1,120/1,590/1,710/2,900 → 1,900/2,700/2,900/**4,930**(약 1.7배).
3. `DifficultyScale.swift:23` — `chapterCeiling` 3 → **4**.
4. `HighSchoolCareer.swift:1892-1899` — 등판 피로 `pitches × staminaScale / 240` → `/200`, 최소 3 → **5**.

**터지는 시나리오**
3장까지 **옛 커널**(삼진 많고 실점 적음)로 쌓아 온 `performance`와 `seasonLog`를 가진 회차가 업데이트된다. 그 기록이 새 계수로 재평가된다: 삼진 가치 ↑, 실점 벌 ↓, 영점 ↑ → `gameQuality`와 `seasonTerm`(캡 ±2, `:2149-2157`)이 모두 **유리한 쪽**으로 움직인다. 반대로 4~8장의 상대는 `chapterCeiling` 4로 세지고 피로도 더 든다. 순수하게 손해는 아니지만 **중립이 아니고**, 밸런스 실측(20,000타석)은 전부 새 커널 기준이라 이 혼합 회차의 실제 통과율은 **아무도 재지 않았다.**

**고칠 방향**
`balanceVersion`을 5로 올려 신규 회차만 새 계수를 쓰게 하거나(진행 중 회차는 옛 v4 식 유지), 최소한 혼합 회차 시뮬레이션을 한 번 돌려 통과율을 확인한다. 출시 시점에 진행 중 회차를 가진 유저가 몇 명인지 모르면 후자만이라도.

---

## F8. `directionTenthsDegrees` clamp가 **파울라인에 10% 무더기**를 만든다 — 심각도: **낮음(P3)**

`PitchKernelEngine.swift:1445-1450` — 기저 분포는 `-450 + nextInt(901)`(균등 901칸)인데 `pullShift ±90`을 더한 뒤 `±450`으로 **자른다.** 당겨친 타구의 정확히 90/901 ≈ 10%가 `direction == 450`(또는 −450) 한 점에 쌓인다. `isTripleShape`의 경계(`|dir| >= 250`, `GameSituation.swift:470`) 안쪽이라 새 분류 경계를 만들지는 않지만, 수비 배치·비거리 기하가 파울라인 극단에 몰린다.

고칠 방향: 자르지 말고 **표본 구간을 미는** 방식으로. 예: `-450 + max(0,pullShift) + nextInt(901 - abs(pullShift))`.

---

## F9. 관계 사건 회전이 주석의 약속을 지키지 못한다 — 심각도: **낮음(P3)**

`HighSchoolCareer.swift:2395-2404`
```swift
let rotation = max(0, state.lifeNumber - 1) % candidates.count
let start = Int(seed % UInt64(candidates.count))
return candidates[(start + rotation) % candidates.count]
```
주석은 "연속한 회차는 **반드시** 다른 장면을 만난다"고 적었다. 그러나 `start`가 회차마다 달라지는 시드에서 나오므로 `start_n + n`과 `start_{n+1} + n + 1`이 같은 값이 될 수 있다. 회전은 겹칠 확률을 낮출 뿐 **보장하지 않는다.** 주석이 코드보다 강하다.

고칠 방향: 문구를 실제 보장에 맞추거나, 직전 회차에서 뽑힌 인덱스를 상태에 남겨 실제로 배제한다.

---

## F10. `DailyStreak.recordPlay()`가 **영수증 날짜가 아니라 오늘**로 찍힌다 — 심각도: **낮음(P3)**

`apps/ios/Sources/HighSchoolCareerStore.swift:1235` — `DailyStreak.recordPlay()`(기본값 `Date()`).
바로 위 `:1199-1204`의 주간 영수증은 `DailyStreak.key(for: completion.completedAt)`을 쓴다. `retryPendingGameCompletion`은 이름 그대로 **나중에 다시 부르는 경로**라, 자정을 넘겨 재시도되면 같은 한 경기가 주간 노트에는 어제로, 연속 일수에는 오늘로 들어간다.

고칠 방향: `DailyStreak.recordPlay(now: completion.completedAt)`.

한편 키 분리 자체는 정상이다 — `DailyInningView.swift:224-225`가 옛 키(`playedKey`)와 새 키(`recordPlay`)를 **둘 다** 쓰므로 `DailyReminder.swift:414`의 "오늘의 이닝 던졌으면 알림 건너뛰기"는 안 깨진다. 주간 `played-day:<날짜>` 영수증은 세 모드가 같은 ID를 쓰고 `WeeklyProgramStore.swift:177`이 `processedReceiptIDs`로 중복을 막으므로 **하루 두 번 세지 않는다** — 확인했다.

---

## F11. simulation-core 전체 스위트가 **signal 11로 죽는다** — 심각도: **중(P2, 기존 문제)**

`swift test`(필터 없음) 실행 결과:
```
error: Process '.../xctest ... BaseballSimulationPackageTests.xctest' exited with unexpected signal code 11
```
`ProCareerEngineTests` 부근에서 죽는다. 알려진 Swift 6.3 outlined-destroy 이슈로 보이며 오늘 변경 때문은 아니지만, **결과적으로 "전체 테스트가 통과한다"를 아무도 확인할 수 없는 상태로 출시가 진행된다.** 필터를 나눠 돌리는 CI 절차가 없다면 지금 만들어야 한다.

---

## 저장 호환 — 항목별 결론

| 필드 | 옛 저장 → 새 앱 | 새 저장 → 구버전 앱 |
|---|---|---|
| `LifeRecord.pitches/outs/hits/abilityStart/abilityFinal` (`HighSchoolCareerStore.swift:138-161`) | 안전. 전부 `Optional` + 기본 nil → `decodeIfPresent`. 카드가 `rateLine`/성장줄을 접는다(`LifeCardView.swift:264-266`) | 안전(무시됨) |
| `CareerPerformanceSnapshot.outs/hits` (`HighSchoolCareer.swift:224-225`) | 안전. `adding`이 `?? 0`으로 받는다(`:259-260`) | 안전 |
| `ImportantInningReport.hits` | 안전(옵셔널) | 안전 |
| `PitchSession.ResumeState.hitsAllowed` (`PitchSession.swift:164`) | 안전. `resume.hitsAllowed ?? 0`(`:240`) | 안전 |
| `ResumeState.LogLine.abilityMoment` (`PitchSession.swift:188`) | 안전(옵셔널) | 안전 |
| `ScoutingReportSnapshot.estimatedStrength/estimatedHotZone` (`PitchKernelDomain.swift:104-105`) | 안전. 옛 스냅숏 nil → `CatcherCard`가 "피할 것" 줄을 접는다(`PitchView.swift:1393`) | 안전 |
| **`WeeklyTaskKind.playedOnTwoDays`** | 안전 | **위험 — F2. 전체 레코드 소실** |

정리: **한 방향만 깨진다.** 옛 저장을 새 앱이 읽는 것은 전부 안전하고, 새 저장을 구버전이 읽는 경로만 `WeeklyTaskKind`에서 무너진다. iCloud KVS 동기화가 있으므로 이건 이론이 아니라 다기기 유저의 실제 경로다.

---

## 테스트가 실제로 잡는가 — 공백 목록

| 위험 | 지금 잡히나 | 필요한 테스트 |
|---|---|---|
| F1 타구 방향 반전 | **아니오** | 커널 테스트에 `batSide × landedZone.column → direction 부호` 2줄 |
| F2 새 case 전방 호환 | **아니오** | 알 수 없는 `kind`가 든 JSON에서 stamps/revision 보존 |
| F3 기록 축하 소멸 | **아니오** | UI 테스트에서 등판 종료 후 "개인 최고" 존재 확인 |
| F4 ImageRenderer 반복 | **아니오** (`LifeCardShareImageTests`는 이미지 내용만 본다) | 렌더 호출 횟수 계측 또는 캐시 단위 테스트 |
| F5 기회 연속 중복 | **아니오** (테스트가 `fatigue` 기본값 100만 쓴다) | `fatigue: 10`으로 연속 방지 단정 |
| F6 커널 결정론 | **아니오** (골든은 `SimulationEngine` 전용) | 커널 이벤트 해시 골든 픽스처 |
| F7 진행 중 회차 지명률 | **아니오** | 혼합 회차(옛 performance + 새 계수) 통과율 시뮬 |
| 저장 호환 나머지 | 예 — `CareerSignatureLegacyTests`(통과 확인) | — |
| 릴리스/퍼펙트 항등성 | 예 — `PitchDeliveryTests` 9건 전원 통과 | — |

---

## 확인하지 못한 것

- **`HighSchoolCareerStore.restore()` / `applyHigherResultlessRecordDuringSession()`의 동작 변경**
  (`:2357-2360`에서 revision 가드를 `.live` 안으로 옮김, `:2385`에서 `>` → `>=`).
  같은 리비전에서 result-less 레코드가 진행 중 이닝을 이긴다는 **의도된 설계**로 읽히고 `saveConflictPriority`(`:2482-2488`)가 그것을 뒷받침한다. 다만 스플릿브레인(동일 리비전에 live/삭제 레코드가 공존)에서 진행 중 선수가 사라지는 시나리오를 **재현 실험으로 확인하지는 못했다.** SaveSync 테스트 하네스가 있으면 그쪽에서 한 번 돌려 볼 것.
- `PitchView`의 햅틱 하트비트(`:404, :412-414`)가 화면 전환·백그라운드 진입에서 확실히 멈추는지 — 실기 확인 필요.
- `docs/MANIFEST.sha256` 9건 불일치는 `git log`로 확인한 결과 **전부 오늘 변경과 무관한 기존 누락**이다(`QA_RELEASE_GATES.md`는 b0a1f90, `RELEASE_1_0_CHECKLIST.md`는 0ba3ee8에서 갱신 후 매니페스트 미반영). 이번 릴리스 책임은 아니지만 매니페스트가 이미 신뢰할 수 없는 상태다.

---

# 출시 전 반드시 고칠 것

1. **F1 — 우타자 타구 방향 반전.** `PitchKernelEngine.swift:1413`의 `pullDirection` 부호를 뒤집고 부호 단정 테스트를 추가한다. 한 줄 수정이고, 안 고치면 이번 릴리스의 간판 기능(코스 축이 의미를 갖는다)이 대다수 타석에서 거꾸로 작동한다.
2. **F2 — `WeeklyTaskKind` 전방 호환.** `WeeklyTask`에 관용 디코딩을 넣는다. 다기기 유저의 주간 기록이 실제로 소실되고, 저장 파일 구조상 되돌릴 방법이 없다.
3. **F3 — 개인 최고 축하 소멸.** `@AppStorage` 쓰기를 body 평가와 분리한다. 이번 릴리스가 만든 리텐션 훅이 화면에 한 프레임도 안 남는다.
4. **F6 — "같은 판에 도전" 문구.** 커널 결과가 버전 간 재현되지 않으므로, 골든 픽스처로 고정하거나 시드 문구를 버전 안으로 한정한다. 공유물에 지킬 수 없는 약속을 새기는 중이다.
5. **F11 — 전체 테스트 실행 경로.** signal 11 때문에 "전 스위트 통과"를 증명할 수 없다. 최소한 분할 실행 스크립트를 릴리스 게이트에 넣는다.

F4·F5·F7은 출시를 막을 정도는 아니지만 F4(마감 화면 끊김)는 스크린샷·리뷰에 직접 닿는 화면이라 우선순위가 높다.
