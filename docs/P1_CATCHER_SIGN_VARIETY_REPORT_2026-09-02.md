# P1-2 포수 사인·상대 약점 다양화 구현 보고 (2026-09-02)

구현: grok-4.6. 스펙: `docs/P1_CATCHER_SIGN_VARIETY_SPEC_2026-09-02.md`.
커밋하지 않음. stash/reset/checkout 없음. xcodebuild 없음. npm 없음. 픽스처 재생성 없음.
작업 경로: `/Users/solkim/Dev/baseball-wt-catcher` (`p1/catcher-variety`). `/Users/solkim/Dev/baseball`은 건드리지 않음.

## 0. 규칙 준수

- `CatcherRecommendationEngine`·`SignSituation`에 난수 없음. v2 다양화는 투수·타자·카운트·직전 구(라이벌 기억)·적응 스냅샷·결정적 해시의 함수다.
- `CatcherSignRules.version` 기본값 1. exporter·CLI·기본 `PitchKernelEngine()`·테스트 기본 경로는 1. iOS `PitchSession`만 version 2.
- `preparationToken`은 version != 1일 때만 `catcher-sign:<n>`을 붙인다. v1 토큰 바이트는 그대로다.
- `AutoOutingSimulator.simulate(..., diverseScouting: Bool = false)`. 기존 `nextInt` 호출(핫존 row/col, 약점 2종, chase)은 켠 뒤에도 같은 순서·횟수로 소비한다. `planWeek`만 `usesWeeklyDecisionRules`(`proRulesVersion >= 9`)일 때 true.
- 고교 자동 경기·튜토리얼 커브 고정·v8 `planWeek`는 기본 false 경로.
- `ProCareerBootstrapCharacterizationTests`의 Wave0 경계는 `proRulesVersion: 8`로 고정해 v1 골든 nextSeed/주간 스탯 SHA를 지킨다. 단언을 약화하지 않았다.
- ko/en/ja 새 reasonCode 4종. 실존 구단·선수명 없음. 투구 슬라이더 코드 미접근.

## 1. 변경 파일

### simulation-core
- `packages/simulation-core/Sources/SimulationCore/CatcherSignRules.swift` — 신규. version 기본 1.
- `packages/simulation-core/Sources/SimulationCore/BatterScoutingProfileRules.swift` — 신규. 아키타입 9종 표 + FNV-1a 선택.
- `packages/simulation-core/Sources/SimulationCore/CatcherRecommendationEngine.swift` — v2 코스 후보·연속 감점·시퀀싱. v1 분기는 기존 동작.
- `packages/simulation-core/Sources/SimulationCore/SignSituation.swift` — `intentZone` / `diagonalOpposite`. `shift` 불변.
- `packages/simulation-core/Sources/SimulationCore/PitchKernelEngine.swift` — rivalMemory 전달, 토큰에 version, 새 reason 한국어 문장.
- `packages/simulation-core/Sources/SimulationCore/AutoOutingSimulator.swift` — `diverseScouting` 기본 false.
- `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` — `planWeek`가 v9에서만 diverseScouting true.
- `packages/simulation-core/Sources/SimulationCore/Domain.swift` — `PitchZone`/`PitchType` Hashable.
- `packages/simulation-core/Tests/SimulationCoreTests/BatterScoutingProfileRulesTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/CatcherSignVarietyTests.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/PitchKernelEngineTests.swift` — 200타석 통계 테스트.
- `packages/simulation-core/Tests/SimulationCoreTests/ProCareerBootstrapCharacterizationTests.swift` — v8 핀.

### iOS (작성만, 이 워크트리에서 실행하지 않음)
- `apps/ios/Sources/Application/PitchSession.swift` — livePlayVersion 2.
- `apps/ios/Sources/Platform/ProRivalBatter+Stats.swift` — seedToken = rival id + 시즌.
- `apps/ios/Sources/Presentation/HighSchoolPresentation+Drama.swift` — seedToken = rival id.
- `apps/ios/Sources/Features/Pitch/PitchScenario.swift` — 프로 스카우팅에 시즌 전달. 튜토리얼 커브 고정 유지.
- `apps/ios/Sources/Presentation/PitchPresentation.swift` / `PitchCopyKeys.swift`
- `apps/ios/Sources/Presentation/Localization/Localizable.xcstrings` — 새 키 ko/en/ja.
- `apps/ios/Tests/PitchSessionTests.swift` / `RivalAdaptationSessionTests.swift` / `PitchLocalizationTests.swift`
- `docs/localization/ios-copy-schema.json` — 새 키 4개 수동 삽입. 병합 후 `inventory:ios-localization --write`로 재정렬 가능.

`apps/ios/project.yml`은 바꾸지 않았다. 기존 파일에 테스트 메서드만 추가했으므로 xcodegen 불필요.

## 2. 약점 후보 표

키워드 매칭 순서는 `ProRivalBatter+Stats` 표와 같다. 가중치는 상대값.

| 아키타입 | 키워드 | 약점 (가중) | 강점 경향 | hot 후보 | cold 후보 |
|---|---|---|---|---|---|
| slugger | 거포 | changeup 50, curveball 35, slider 15 | 포심·슬라이더 | 높은/몸쪽·가운데 | 낮은 바깥·낮은 가운데·높은 바깥 |
| homeRun | 홈런 | changeup 45, curveball 40, slider 15 | 포심·슬라이더 | 동일 | 동일 |
| power | 파워 | changeup 40, curveball 35, slider 25 | 포심·슬라이더 | 동일 | 동일 |
| contact | 컨택, 무결점 | fourSeam 55, slider 45 | 체인지업·커브 | 가운데 바깥·가운데 | 높은 몸쪽 |
| spray | 교타, 정확 | fourSeam 50, slider 35, changeup 15 | 체인지업·커브 | 동일 | 동일 |
| patient | 선구안, 출루 | curveball 50, changeup 50 | 포심 | 존 안 가운데 | 낮은 바깥·높은 바깥 (체이스) |
| gap | 갭 | slider 40, changeup 35, fourSeam 25 | 포심·커브 | 갭 쪽 | 한복판·높은 몸쪽 |
| speed | 빠른 발, 빠른발, 도루 | curveball 40, changeup 35, fourSeam 25 | 포심·슬라이더 | 낮은 바깥·가운데 | 높은 몸쪽 |
| clutch | 득점권, 해결사, 중심 (기본) | slider 35, curveball 35, changeup 30 | 포심 | 가운데·몸쪽 | 낮은 바깥·높은 바깥 |

핫 ≠ 콜드, 약점 ≠ 강점. `BatterScoutingProfileRulesTests`에서 9×30 생성 시 약점 4구종 전부, 콜드존 ≥ 6종, 아키타입 내 약점 단일 붕괴 없음.

프로 chaseTendency는 기존 선구안/파워 값을 유지한다(정보 안개). 신뢰도도 기존 45 / 고교 명료도 값을 유지한다.

자동 등판 `diverseScouting == true`일 때 약점은 `weaknessDraw`(0/1, 기존 RNG) + 해시 비트로 4종 인덱스 `slider/changeup/curveball/four_seam`에 펼친다.

## 3. 코스 가중치 표 (v2)

후보 3개: 콜드존, `intentZone`(카운트 의도, 핫존이면 밀어 냄), 직전 구 시퀀싱(대각 → 눈높이 → 좌우 → 나머지 존 해시).

| 카운트 | 콜드 | 의도 | 시퀀스 | 비고 |
|---|---:|---:|---:|---|
| ahead (투수 앞, 2K) | 22 | 50 | 28 | 유인구 존 우선. chase면 이미 낮은 콜드는 반대 낮은 코너 |
| behind / 3-0 | 22 | 54 | 24 | 스트라이크 의도. 핫존(한복판)이면 콜드 쪽으로 민다 |
| first | 54 | 20 | 26 | 콜드 우선 |
| even | 44 | 26 | 30 | 콜드 우선, 직전 2구 동일 존이면 시퀀스 +25 / 콜드 −20 |

같은 존 3연속이면 다른 후보로 교체. `zoneReadStrength`는 읽힌 존 가중을 깎는다.

구종 v2: `level >= 500` 계단은 유지. `pitchReadStrength * 70 / 1000` 연속 감점(desired/lean). 같은 구종 2연속 뒤 `repeatPenalty` 110. 포심 뒤 체인지업 +28. 약점 구종을 방금 던진 뒤에는 다른 구종에 +28~43 해시 보너스.

## 4. 통계 테스트 수치

`PitchKernelEngineTests.testVersion2AcceptedRecommendationHitRateStaysNearVersion1AndSpreadsCalls` — 정교한 제구형, 고정 스카우팅(약점 슬라이더, 콜드 2-0), 200타석, 추천 1안 100% 수락.

- 계측 과정: v1 피안타율 **0.255**(51/200). 시퀀스 가중을 과하게 올리면 v2가 0.300~0.320까지 벌어졌다. 콜드 우선 가중 + 핫존 회피 후 **v2가 v1 대비 ±0.04 이내**로 통과.
- 같은 200타석에서 v2 추천 존 ≥ 5 / 9, 구종 ≥ 3.

`CatcherSignVarietyTests.testThirtyPitchSequenceV2UsesAtLeastFourZonesAndThreePitchesWhileV1StaysOnTwoZones` — 동일 타자 30구.

- v1 존 ≤ 2 (콜드 시프트만).
- v2 존 ≥ 4, 구종 ≥ 3.

v2 prepare 두 번 = 같은 추천·같은 토큰. v2 prepare + v1 submit = `invalidPreparationToken`.

## 5. 실행한 게이트 원문

시뮬레이터·xcodebuild·npm은 스펙대로 실행하지 않음.

```
swift test --package-path packages/simulation-core
```

```
Test Suite 'All tests' passed at 2026-09-02 19:05:47.193.
	 Executed 558 tests, with 1 test skipped and 0 failures (0 unexpected) in 466.923 (466.965) seconds
```

종료 코드 0. 스킵 1건은 기존 Wave0 생성 테스트(`BASEBALL_WAVE0_GENERATE=1` opt-in).

```
swift test --package-path packages/ios-layers
```

```
Test Suite 'All tests' passed at 2026-09-02 18:58:22.036.
	 Executed 13 tests, with 0 failures (0 unexpected) in 0.005 (0.007) seconds
```

종료 코드 0.

## 6. PM이 병합 후 실행할 명령

워크트리에는 node_modules가 없고, 다른 엔지니어가 같은 시뮬레이터에서 iOS 테스트를 돌리고 있어 여기서는 실행하지 않았다. 병합 후 직렬로:

```bash
# 1) 이 변경의 iOS 테스트 (부팅된 시뮬레이터만 재사용, 새 기기 만들지 말 것)
cd apps/ios
xcodebuild test -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BaseballIOSTests/PitchSessionTests \
  -only-testing:BaseballIOSTests/RivalAdaptationSessionTests \
  -only-testing:BaseballIOSTests/PitchLocalizationTests \
  -only-testing:BaseballIOSTests/JapaneseLocalizationTests \
  -only-testing:BaseballIOSTests/LocalizationCoverageTests \
  -only-testing:BaseballIOSTests/PresentationTests \
  CODE_SIGNING_ALLOWED=NO

# 2) 카탈로그 재정렬(선택) 후 현지화·카피 게이트
npm run inventory:ios-localization -- --write
npm run check:ios-localization
npm run check:copy
npm run check:korean-copy

# 3) 밸런스 밴드 (추천 수락 피안타율 0.17~0.3). 워크트리에서 못 돌림.
npm run check:balance
```

iPhone 17 Pro가 없으면 부팅된 `iPhone 17`을 쓴다. 새 시뮬레이터를 만들지 말 것.

## 7. 미해결

- 데스크톱 `apps/windows/src/proRival.ts`는 스펙 적용 목록에 없어 2종 약점 표를 그대로 둔다. iOS 중요 경기와 자동 등판(v9)만 다양화된다.
- `check:balance` / `check:ios-localization` / iOS xcodebuild는 PM 직렬 실행.
- `ios-copy-schema.json`은 키 4개를 수동으로 넣었다. `inventory:ios-localization --write`가 정렬·status를 다시 쓸 수 있다.
- v9 `planWeek` 등판 라인은 diverse scouting 때문에 v8과 다를 수 있다. v8 골든·v2 exporter(v8 고정)는 바이트 동일 경로를 유지한다.
- 고교 자동 경기(`HighSchoolCareer.simulateChapterGames`)는 `diverseScouting` 기본 false. 고교 v3 픽스처 보호.
- 튜토리얼(`PitchScenario.tutorial`) 약점은 커브 고정.

## 수정 라운드 H (병합 후 iOS)

작업 경로: `/Users/solkim/Dev/baseball` (`main`, HEAD `5769788b`). 커밋·stash·reset·checkout 없음. 골든/Kotlin 픽스처·CatcherSignRules 기본값 1 미변경. 테스트 삭제·약화 없음. xcodebuild는 부팅된 iPhone 17 (`641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF`)만, 한 번에 하나. 새 시뮬레이터 없음.

### 진단

1. `PitchSessionTests.testLiveSessionUsesCatcherSignRulesVersion2` — `XCTUnwrap` nil `PitchPreparation`.
   - **테스트 셋업.** 시드 `"catcher-v2"`는 `UInt64`가 아니라 `PitchKernelEngine.validate`가 `invalidSeed`를 던진다. `PitchSession.prepare()`는 이를 `.failed`로 삼키고 `preparation`을 nil로 둔다. v2 엔진이 prepare를 거부한 것이 아니다.
   - 시드를 `"20260902"`로 고친 뒤 prepare/submit는 통과했다. 토큰은 v2와 같고 v1과 다르다.
   - 이닝이 3아웃으로 먼저 끝나 30구를 못 채워 존이 2개만 모이는 셋업 문제도 있었다. 세션이 끝난 뒤에는 같은 라이브 투수·스카우팅으로 v2 커널 30구를 이어 받아 다양성 단언을 유지했다.
   - **실결함 아님.** live `PitchSession` v2 prepare→수락→submit 라운드트립 테스트를 추가해 한 구가 실제로 나가는지 잠갔다.

2. `RivalAdaptationSessionTests.testVersion2CatcherSignsStillWarnOnceTheBatterLocksOn` — `v2 사인이 읽힘 경고를 내지 않았습니다: []`.
   - **셋업 + 실결함.** 40구 뒤 이닝이 끝나 `preparation == nil`이면 reasonCodes가 `[]`가 된다. 밴드 단언은 `lastResult`로 통과하고 사인 카드만 비어 보였다.
   - **실결함:** v2 첫 reason 슬롯이 상호배타적이라 `sequence.setup_offspeed` 등이 이기면 `rival.read_pressure`가 빠졌다. locked_on / `detectedPitch`에서도 경고가 카드에 안 남을 수 있다.
   - 수정: `CatcherRecommendationEngine` v2만, locked_on 또는 detected pitch인데 `rival.pattern_detected`/`rival.read_pressure`가 없으면 `rival.read_pressure`를 추가. v1 분기·토큰 바이트(call canonical) 불변.
   - 테스트는 이닝 종료 후가 아니라 locked_on/detected인 **현재 사인**을 본다. 단언(경고 코드 필수)은 그대로다.

### 수정 파일

- `packages/simulation-core/Sources/SimulationCore/CatcherRecommendationEngine.swift`
- `packages/simulation-core/Tests/SimulationCoreTests/CatcherSignVarietyTests.swift` — locked-on v2 경고 + submit 라운드트립
- `apps/ios/Tests/PitchSessionTests.swift` — numeric seed, v2 round-trip, 30구 다양성
- `apps/ios/Tests/RivalAdaptationSessionTests.swift` — locked-on 동안 사인 검사

### 게이트 원문

`PitchSessionTests` (부팅된 iPhone 17):

```
Test Suite 'PitchSessionTests' passed at 2026-09-02 19:38:37.399.
	 Executed 37 tests, with 0 failures (0 unexpected) in 0.352 (0.359) seconds
** TEST SUCCEEDED **
```

`RivalAdaptationSessionTests`:

```
Test Suite 'RivalAdaptationSessionTests' passed at 2026-09-02 19:38:48.628.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.020 (0.021) seconds
** TEST SUCCEEDED **
```

`PitchLocalizationTests`:

```
Test Suite 'PitchLocalizationTests' passed at 2026-09-02 19:38:59.775.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.183 (0.184) seconds
** TEST SUCCEEDED **
```

`BaseballIOSTests` 전체:

```
Test Suite 'All tests' passed at 2026-09-02 19:41:02.950.
	 Executed 543 tests, with 0 failures (0 unexpected) in 111.506 (111.667) seconds
** TEST SUCCEEDED **
```

`swift test --package-path packages/simulation-core --filter "CatcherSignVariety|PitchKernelEngine|ProCareerBootstrapCharacterization"`:

```
Test Suite 'Selected tests' passed at 2026-09-02 19:41:31.889.
	 Executed 59 tests, with 1 test skipped and 0 failures (0 unexpected) in 19.944 (19.949) seconds
```

스킵 1건은 기존 Wave0 생성 테스트(`BASEBALL_WAVE0_GENERATE=1` opt-in).

`BaseballIOSUITests/Release128JourneyUITests/testManualSliderThrowsOnePitch`:

```
Test Case '-[BaseballIOSUITests.Release128JourneyUITests testManualSliderThrowsOnePitch]' passed (24.068 seconds).
Test Suite 'Release128JourneyUITests' passed at 2026-09-02 19:42:08.572.
	 Executed 1 test, with 0 failures (0 unexpected) in 24.068 (24.070) seconds
** TEST SUCCEEDED **
```
