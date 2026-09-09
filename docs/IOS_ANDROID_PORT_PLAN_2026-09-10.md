# Android 최근 개선의 iOS 이식 계획 · 2026-09-10

대상: `android/core-fun-quality-2026-09-07` 브랜치의 9/7~9/9 작업 (커밋 82개 + 미커밋 103파일)을 iOS(`packages/simulation-core`, `packages/ios-layers`, `apps/ios`)에 반영한다.

이 문서는 이식 순서와 각 단계의 완료 조건을 정한다. 스토어 제출이나 출시 판정은 범위에 없다.

## 0. 현재 상태

| 축 | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| 고교 규칙 | 4 | 7 |
| 프로 규칙 | 10 | 13 |
| 고교 저장 스키마 | 4 (`HighSchoolCareerPersistence.currentSchemaVersion`) | 코덱 11 / 외부 11 |
| 프로 저장 스키마 | `nationalTeamSchemaVersion` 기준 | 6 |
| 자책점(ER) | 없음 — `PitchingMetrics.swift`가 전부 실점(RA) 기준 | nullable ER + 주자 책임 원장 |
| 자동 등판 | `AutoOutingSimulator`가 18아웃 + 체력 보너스로 상한 | 투구 수·체력·실점·상황 기반 교체, 완투 가능 |
| 퍼펙트 릴리스 | 판정·연출·업적만 있고 집계 없음 | 등판·시즌·통산 집계 + 고교 3개마다 각성 전조 |
| 미터 바늘 | 선형 (`DeliveryControl.MeterDriver`) | `PitchReleaseMeter.phase()`의 릴리스 지점 감속 |
| 선수 앨범·리플레이 | 없음 (계보 아카이브 `LifeArchiveView`는 별개) | 있음 |
| 공유 카드 | 4종 존재 (`CareerShareCard`) | 초상 + 상세 기록표로 재설계 |
| 대화 화면 | `RelationshipCard` 44pt 초상 | 84dp 초상 + 3 풀카드 + 비용 선노출 + 프로 9종 |

Swift 코어는 Android 패리티 테스트의 **정답지**다. `apps/android/game-core/src/test/resources/fixtures/swift-release-parity-v4-v10.json`이 고교 4 / 프로 10 경로를 고정하고 있으므로, **기존 버전 경로의 계산을 바꾸면 안 된다.** 새 규칙은 전부 버전 분기로 들어간다.

## 1. 단계

### Phase 0 — 기준점 고정

- 안드로이드 미커밋 103파일(2~7차 QA 수정)을 커밋해 이식 기준 SHA를 확정한다. 지금은 워킹 트리가 기준이라 이식 도중 원본이 흔들린다.
- 이식 대상 항목표(이 문서 §2)를 확정하고, 각 항목의 Kotlin 원본 파일과 iOS 목적지를 적는다.
- 산출: 기준 SHA, 항목표.

### Phase 1 — Swift 고교 규칙 4 → 7

- 1-A **버전 게이팅 도입.** `HighSchoolGameplayRules` 상당물을 Swift에 신설하고 `balanceVersion` 분기를 만든다. v4 경로는 한 줄도 바꾸지 않는다. 미래 버전 상태를 과거 엔진에 넘기면 거부한다.
- 1-B **투구 확률 재조정.** 구위·무브먼트·구종·구속의 중복 헛스윙 보너스를 단일 완만 효과로 통합. 제구가 낮으면 볼넷·실투가 실제로 나오고, 가운데 몰린 공은 타구 품질에 반영된다.
- 1-C **자동 경기 난이도.** 초반 타자 약화 -6 → -1, 환생 횟수만으로 상대 능력이 오르던 보정 제거. 학년·대회 차이는 유지.
- 1-D **완료 생애 계승.** 1~4생애 내부 능력 +3, 이후 +1씩 최대 +16. 새 선수 생성 시 1회 적용, 소급 변경 없음. 드래프트 평가를 새 난이도에 맞춰 보정.
- 1-E **훈련 진도제.** 가볍게/보통/강하게 = 35/60/80, 피로 70 이상은 절반, 100마다 기존 성장 계산 호출. 강한 훈련 기본 피로 15 → 11.
- 1-F **퍼펙트 릴리스 집계.** 등판·시즌·통산 카운터 추가, 고교는 3개마다 각성 전조.
- 1-G **장별 직접 등판.** 장 결산에서 그 장의 정규 경기 1개를 직접 던진다. 자동 경기는 2회 → 1회. 두 줄을 모두 시뮬레이션한 뒤 하나를 버려 난수 소비 순서를 보존한다(Kotlin이 쓴 방식 그대로).

게이트: `npm run test:swift` 통과, v4 픽스처 수치·체크섬 불변, v7 경로의 세이브 왕복.

### Phase 2 — Swift 프로 규칙 10 → 13

- 2-A **ER 원장.** nullable ER + 투구 중 주자 책임 원장. 과거 시즌은 추정하지 않고 `—`. 이닝당 지표는 정수 아웃 수 기준. 사구는 BB에 넣지 않는다.
- 2-B **수비 실책과 승계 주자.** 1루가 빈 상황의 평범한 땅볼 실책(주자 정지, 타자만 1루), 가상의 3번째 아웃 이후 실점은 비자책. 승계 주자와 본인 출루 주자를 구분하고 후속 투수 기록을 분리.
- 2-C **완투·완봉.** 투구 수·체력·실점·후반 무실점 상황으로 교체를 판단하고 18아웃 상한을 제거한다. 7~9회 계속 투구, 마운드 유지 / 불펜 교체 / 자동 진행 3분기. 체력 보너스가 다른 능력 상승에 잠식되지 않게 한다. CG는 9이닝 책임 + 경기 결정, SHO는 실제 무실점 승리.
- 2-D **직접+자동 혼합 정산.** 직접 던지지 않은 이닝을 실제 투구 엔진으로 계산한다. 이닝 비율로 안타·삼진·실점을 나눠 갖던 방식 제거.
- 2-E **타선·보직·노화.** 상위 출루형 / 중심 장타 / 하위 타선 구분, 24주에 선발 28회·셋업/마무리 60회 배정, 나이에 따른 구속·헛스윙·무브먼트 변화.
- 2-F **승격·명예의 전당.** `ProCallUpRules` 상당물로 커널과 UI가 조건을 공유. 명예의 전당을 현실적인 삼진·이닝·승리·세이브·ERA 기준으로 재조정.

게이트: `npm run test:swift`, 프로 v10 픽스처 불변, 20시즌 장기 시뮬레이션 지표를 `docs/android-compose/benchmarks/pro-pitching-2023-2025.json` 기준(ERA 4.4516 / WHIP 1.4389 / K/9 7.4584 / BB/9 3.6397)과 대조.

### Phase 3 — 저장 스키마와 마이그레이션

- 고교 스키마 4 → 5, 프로 스키마 +1. ER·CG/SHO·퍼펙트 카운터·능력 이력·앨범을 **전부 optional**로 추가해 구버전 파일이 그대로 열리게 한다.
- 기존 저장 파일 픽스처로 열기 → 명령 실행 → 재저장 → 재열기 왕복을 검사한다.
- 주의: Swift 6.3 outlined-destroy 결함 때문에 큰 값 타입에 필드를 더하면 전체 스위트가 segfault한다. 새 상태 묶음은 `final class`로 박싱한다(`PitchDelivery`가 별도 인자인 이유와 같은 문제).
- 주의: 바이트 비교 검사에는 `JSONEncoder.sortedKeys`를 쓴다. 같은 값도 인코딩마다 키 순서가 다르다.
- 9/9 저장 차단 수정(`docs/IOS_REVIEW_SAVE_BLOCK_DEBUG_RESULTS_2026-09-09.md`)의 저장 성공 후 전환 규칙을 깨지 않는지 확인한다.

### Phase 4 — 투구 손맛

- 4-A **릴리스 미터 감속 곡선.** `PitchReleaseMeter.phase()`를 iOS `MeterDriver`에 이식한다. `RELEASE_DWELL_SPAN = 0.09`, `releaseDwell(command) = 0.60 + (command−35)/45 × 0.18`, 가우시안 `eased = offset × (1 − dwell × exp(−ratio²))`. 판정 기하(`PitchReleaseWindow`, 문턱 975)는 손대지 않는다 — 이미 양쪽이 동일하다.
- 4-B **예고 햅틱.** `secondsToRelease(elapsed, sweep)`로 중앙 도달 시각을 계산해 울린다. 곡선이 바뀌어도 도달 시각은 같다.
- 4-C **마운드 흔들림.** 진동 설정에서 분리하고(진동을 꺼도 판정이 쉬워지지 않게) 흔들림 크기를 제구 창의 1/4 이하로 묶는다.
- 4-D **연출.** 결과 프리즈의 궤적 잔상, 실밥 2줄 회전(퍼펙트 금색), 판정 도장, 무브먼트가 정하는 휨 폭, 퍼펙트 시 비행 15% 단축 + 삼진콜 0.2초 선행. 모션 감소에서는 새 장식을 그리지 않는다.
- 4-E **오디오.** 퍼펙트 전용 종소리, 비행 중 구속 비례 공기음, 연속 재생 시 피치 미세 흔들기, 구위 비례 미트 소리를 `SoundBank`/`GameAudio`에 추가한다. 음원은 Android가 iOS에서 가져간 CC0이므로 원본이 이미 있다.

게이트: 시뮬레이터에서 금색 통과 시간 실측(제구 35 ≈ 44ms, 80 ≈ 51ms, 초록 구간 불변), 진동 off에서 흔들림 유지 확인, reduce motion 확인.

### Phase 5 — 기록·앨범·공유

- 5-A **선수 앨범.** 등판 단위 보존 + 시즌 전환 직전/직후 수집으로 유실 방지, 자동 결과가 직접 결과로 정산되면 교체. 조회는 명령을 내리지 않는다.
- 5-B **투구 리플레이.** 저장된 궤적·구종·구속·결과·주자 상황을 기존 렌더러로 읽기 전용 재생. RNG·명령·보상 경로를 호출하지 않는다. 예산: 페이지당 128 / 전체 512 / 궤적 정수 65,536, 한도 도달 시 새 재생 추가 중단 + 안내(기존 재생 삭제 없음).
- 5-C **공유 카드 재설계.** 기존 `CareerShareCard` 4종을 초상 + 기록표 구조로 교체한다. 기본 12개(G·GS·W·L·SV·IP·H·HR·BB·SO·R·NP), 비율(WHIP·K/9·BB/9·H/9·K/BB·RA/9 + Phase 2 이후 ERA). 분모는 항상 아웃 수/3, 없는 값은 `—`.
- 5-D **능력 시각화.** 구위·제구·무브먼트·체력 0–100 막대(주황·파랑·보라·청록 고정), 훈련 결과 450ms 채움 애니메이션(모션 감소 시 즉시), 환생 비교 3종, `AbilityHistoryPoint` 기반 상세 성장 그래프. 가로축은 저장된 변화 순서이며 시간 간격을 가장하지 않는다.

### Phase 6 — 대화와 진로 UX

- 6-A **대화 장면.** 84pt 초상 + 짧은 상황 대사 + 3개 풀카드 선택지, 비용을 선택 전에 노출(부상처럼 수치상 이득으로 보이는 것 포함), 선택 후 같은 화면에 결과 유지, 모달 없음. 원문 산문은 펼침으로 유지.
- 6-B **프로 대화 9종.** 선발 기회·새 구종 시험·2군 재정비·추가 불펜·포수 배합·보직 회의·기록 도전·라이벌 분석(화자는 포수)·시즌 마지막. 예상 효과는 실제 명령과 같은 시드로 계산하고 미리보기는 상태를 쓰지 않는다.
- 6-C **드래프트 요약.** 지명 구단·라운드·전체 순위를 먼저, 고교 통산·시작 대비 성장·훈련/대화 횟수·투수 유형·신뢰 기반 감독의 한마디. 신분 카드 중복 제거.
- 6-D **계약과 시즌 결정.** 카드 선택과 확정 명령을 분리한다(선택만으로 명령 0회). 연봉/계약금 라벨 구분, 시즌 결정에 이득·손실 칩.
- 6-E **환생 경로 선택.** 선발 / 마무리 / 제구형 — 각각 체력형+포심, 변화구형+슬라이더, 제구형+체인지업으로 능력 배분과 주력 구종이 갈리고 프로 목표까지 이어진다. 확인 전에는 시작하지 않는다. 기존 이어가기 경로는 남긴다.

### Phase 7 — 안정성과 플랫폼 (iOS 방식으로 재구현)

- 7-A **실패 분류.** 규칙 거부 / 상태 충돌 / 투구 상태 / 공간 부족 / I/O / 검증·버전 / 쓰기 금지 / 원인 미확정. **규칙 거부를 저장 실패로 분류하지 않는다.** 공간 부족은 명시적 근거가 있을 때만.
- 7-B **투구 실패 진단·복구.** 단계·correlation ID·session/pitch ID·명령 ID·기대/현재 revision을 남기고, 실패 후 저장 파일을 재검증해 "저장됐어요 → 결과 확인"과 "미확정 → 돌아가기"를 구분한다. 결과 확인은 투구를 재실행하지 않는다.
- 7-C **투구 상태 전이 공통화.** 중단·재개·포기 규칙을 한 곳에서 정의하고, 결과가 커밋된 투구는 포기 대신 결과 확인으로 보낸다.
- 7-D **명령 영수증.** 새 명령 ID를 저장 revision에 결합해 재전송을 거부하고 최근 256개를 보존한다. 복원 불가능한 옛 ID는 그대로 둔다.
- 7-E **iOS 고유 대응 확인 후 필요분만.** 백업/복원은 iCloud·파일 경로, 알림은 `UNUserNotificationCenter`(`DailyReminder` 확장), 문서 읽기는 `SFSafariViewController`. Android의 백업 XML·Custom Tabs·Compose 레이아웃 수정(S-03 등)은 이식하지 않는다.

### Phase 8 — 문구·현지화·검증

- 신규 문구를 `Localizable.xcstrings`에 ko/en/ja로 추가하고 `npm run check:ios-localization` 통과.
- 실존 구단·리그·선수명 검색(AGENTS.md 콘텐츠 불변 규칙).
- UI 테스트와 스모크. **테스트는 반드시 직렬 실행한다** — 동시 실행 시 오디오 실패로 앱이 죽는다. macOS에 `timeout`이 없으므로 대기 처리에 주의한다. `QACaptureUITests`는 기준선에서도 실패하므로 게이트로 쓰지 않는다.

## 2. Kotlin 원본 → iOS 목적지

| 항목 | Kotlin 원본 | iOS 목적지 |
|---|---|---|
| 미터 감속 곡선 | `game-core/.../pitch/PitchReleaseMeter.kt` | `apps/ios/Sources/Features/Pitch/DeliveryControl.swift` (`MeterDriver`) |
| 고교 규칙 5~7 | `game-core/.../highschool/HighSchoolKernel.kt`, `HighSchoolPhase4Kernel.kt`, `HighSchoolPhase4Rules.kt` | `packages/simulation-core/.../HighSchoolCareer.swift`, `SimulationEngine.swift` |
| 프로 규칙 11~13 | `game-core/.../pro/ProKernel.kt`, `ProCatalog.kt`, `ProCallUpRules.kt` | `packages/simulation-core/.../ProCareer.swift`, `AutoOutingSimulator.swift`, `SabermetricsRules.swift` |
| 세이브 호환 | `game-core/.../SaveCommitmentCompatibility.kt` | `packages/ios-layers/.../HighSchoolCareerPersistence.swift`, `ProCareerPersistence.swift` |
| 앨범·리플레이 | `game-application/.../PlayerAlbum.kt`, `AlbumReplayRetention.kt` | 신규 `packages/ios-layers/.../PlayerAlbum.swift` + `apps/ios/Sources/Features/` |
| 공유 카드 | `app/.../PlayerAlbumView.kt` | `apps/ios/Sources/Presentation/CareerShareCard.swift` |
| 대화 | `app/.../ConversationScreen.kt`, `game-application/.../ProConversationPresentation.kt` | `apps/ios/Sources/Features/HighSchool/HighSchoolRelationshipViews.swift`, `Features/Pro/` |
| 실패 분류·복구 | `game-application/.../GameActionFailurePresentation.kt`, `PitchFailureRecovery.kt`, `PitchStateTransitions.kt` | `apps/ios/Sources/Application/`, `packages/ios-layers/` |
| 영수증 | `game-application/.../CommandReceiptRetention.kt` | `packages/ios-layers/.../SaveSync.swift` |

## 3. 위험

1. **패리티 정답지 훼손.** Swift v4/v10 경로를 건드리면 Android의 `swift-release-parity-v4-v10.json`과 픽스처 테스트가 깨진다. 새 규칙은 전부 버전 분기로 넣고, 매 단계 끝에 기존 픽스처 체크섬을 확인한다.
2. **반대 방향 패리티 부재.** 이식이 끝나면 고교 7 / 프로 13에 대한 Swift↔Kotlin 대조가 필요하다. `release-parity-exporter`를 새 버전으로 확장하는 작업을 Phase 2 끝에 넣는다.
3. **Swift 6.3 outlined-destroy.** 큰 값 타입에 필드를 더하면 전체 코어 스위트가 segfault한다. Phase 3에서 박싱 전략을 먼저 정한다.
4. **세이브 하위 호환.** 출시 중인 iOS 세이브가 열려야 한다. optional 필드 + 왕복 픽스처로 매 단계 확인한다.
5. **범위.** Phase 1·2가 전체 작업의 대부분이고 나머지 단계가 여기에 의존한다. Phase 1을 마치기 전에 Phase 5~6 화면을 만들면 표시할 데이터가 없다.

## 4. 진행 규칙

- 단계마다 완료 조건을 만족하고 증거를 남긴 뒤 다음 단계로 간다. 실패한 게이트를 통과로 적지 않는다.
- 각 Phase는 독립 커밋으로 남기고, 규칙 변경 커밋에는 버전 번호와 분기 근거를 적는다.
- 실기기·스토어 검증은 별도이며 이 계획의 완료 조건이 아니다.
