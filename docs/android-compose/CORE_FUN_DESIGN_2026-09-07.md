# 핵심 재미 설계: 직접 던지기 비중·성장 체감·퍼펙트 손맛 (2026-09-07)

결정 사항(사용자와 합의)
- 자동 경기 중 장마다 한 번 "이 경기는 내가 던진다"를 고를 수 있다. 결과는 승부처와 같은 가중치로 기록에 들어간다. 훈련 사이 불펜 연습은 넣지 않는다.
- 커널은 안드로이드에서 먼저 바꾼다. iOS는 검증 뒤 따라간다. Swift 정답지 픽스처는 새 기능을 쓰지 않는 경로에서 바이트 단위로 같아야 한다.
- 성장 체감은 구위·구속·제구 모두, 소리와 궤적 연출까지.
- 환생: 이름을 바꿔도 얼굴은 유지한다. 이름이 다르면 "기억을 이어받은 다른 선수"로 서사를 분기한다. 계보는 최근 3생.
- 튜토리얼 세 번째 공은 초심자 보정(기록 없음).
- iOS 문안 동기화는 안드로이드 출시 뒤. 출시는 한국어 먼저.
- 퍼펙트 손맛: 아래 1·2·3·4·5·7·8 전부, 9는 커널 작업에 포함, 6·10은 실기기 비교 뒤 결정.

## 1. "이 경기는 내가 던진다"

### 규칙
- 장 결산(CHAPTER_REVIEW) 화면에서, 그 장의 자동 경기 두 번 중 한 번을 직접 던질 수 있다. 장마다 한 번. 8장(드래프트 장)은 제외.
- 던진 경기는 승부처와 같은 규칙으로 기록된다: `performance`(투구·삼진·볼넷·실점·기대/실제 피해), 감독·포수 신뢰, 각성 전조, 피로, 팬 관심, 주간 노트.
- 그 장의 자동 경기는 두 번이 아니라 한 번만 시뮬레이션된다(직접 던진 경기가 나머지 하나를 대신한다).
- 시나리오는 승부처 목록과 분리된 "정규 경기" 목록에서 고른다(레버리지 350~520, 4~6회, 동점 또는 1점 차). 승부처 시나리오 선택 규칙은 건드리지 않는다.

### 커널 변경 (`game-core`)
- `HighSchoolState`에 `chapterGameClaimed: Boolean = false`, `performance.perfectReleases: Int = 0` 추가. 정식 해시(`canonical`)에는 값이 기본값이 아닐 때만 항목을 덧붙인다. 기존 세이브의 서명은 그대로다.
- 새 명령 `HighSchoolPhase4Command.ClaimChapterGame(seed)`: 전제 `phase == CHAPTER_REVIEW && chapter < 8 && !chapterGameClaimed`. 결과: `phase = IMPORTANT_GAME`, `currentGameScenario = regularScenario(state)`, `chapterGameClaimed = true`. `milestoneIndex`는 그대로.
- `recordImportantGame`: `chapterGameClaimed`가 참이면 `enterMilestone` 대신 `phase = CHAPTER_REVIEW`로 돌아간다(플래그는 `advanceChapter`에서 내린다).
- `advanceChapter`: 자동 경기 두 줄을 그대로 시뮬레이션한 뒤 `chapterGameClaimed`이면 첫 줄을 버린다. RNG 소비 순서가 바뀌지 않으므로 다른 줄과 이후 시드는 동일하다. 플래그를 내린다.
- 퍼펙트: `HighSchoolPitchSession.perfectReleases`(기본 0)를 `submitImportantGamePitch`에서 `delivery.isPerfectRelease`일 때 올리고, `finishImportantGame`이 `HighSchoolGameReport.perfectReleases`로 넘긴다. `recordImportantGame`의 전조 계산에 `+ perfectReleases / 3`을 더한다. `performance.perfectReleases`에 누적한다. Swift 오라클의 고정 보고서에는 이 값이 없으므로 0이며 결과가 같다.
- 코덱: `HighSchoolStateCodec`(스키마 9→10)에 두 필드를 선택 항목으로 추가. 읽기는 없으면 기본값. C# 스냅샷 브리지는 기본값 유지.
- 픽스처: `HighSchoolPhase4FixtureTest`는 새 명령을 쓰지 않으므로 그대로 통과해야 한다. 통과하지 않으면 설계 위반이다.

### 화면
- P010 장 결산에 "이 경기는 내가 던진다" 액션(설명: "이 장의 정규 경기 하나를 직접 던진다. 기록에 남는다."). 이미 던졌으면 "이번 장은 던졌다"로 비활성.
- 던진 뒤 장 결산으로 돌아오면 결과 한 줄("정규 경기 · 1이닝 0실점 · 퍼펙트 2")과 "다음 장으로".
- 시즌 라인에 정규 경기 구분 표시(승부처가 아니라 "정규").

## 2. 성장을 손으로 느끼게

| 능력 | 다음 공에서 보이는 것 | 구현 위치 |
|---|---|---|
| 구위 | 구속 숫자 상승(이미 있음) + 미트 소리 볼륨·음높이(구속 130→150km/h에 볼륨 0.8→1.2) | `PitchFeedbackPlan`에 `velocityTenthsKph` 전달, `Phase9AndroidServices.playPitchCue` 볼륨/재생 속도 |
| 제구 | 초록 구간 폭(이미 있음) + 성장 직후 첫 공에서 이전 표시선을 슬라이더 위에 2초 겹쳐 표시 | `PitchDeliveryControl.ReleaseMeterBar`에 `previousCommand` 파라미터, `PitchActivity`가 `meta.playerGrowth`에서 읽음 |
| 무브먼트 | 궤적의 휨 진폭을 투수 무브먼트로 스케일(무브먼트 20→80에 0.7배→1.3배). 표시만 바뀌고 판정은 동일 | `PitchDramaView` 곡선 진폭 |

## 3. 퍼펙트 손맛

현재: 중앙 2.5% 창, 품질 +90, 진동 1회, 금색 표시선 확대, "★ 퍼펙트 릴리스" 글자. 전용 소리 없음. 기록 없음.

| # | 제안 | 구현 |
|---|---|---|
| 1 | 미터가 금색 구간에 들어가는 순간 짧은 진동(예고) | `PitchDeliveryControl`: `inPerfect` 상승 에지에서 `windUp.tick` |
| 2 | 퍼펙트로 떼는 순간 0.1초 정지 + 릴리스 버튼에서 금색 링 확산 + 전용 소리 + 진동 2연타 | `PitchDeliveryControl` 릴리스 애니메이션, `PitchAudioCue.PERFECT_RELEASE`(새 샘플), `PitchHapticCue.PERFECT` 2회 |
| 3 | 궤적 금색, 비행 시간 15% 단축 | `PitchDramaCamera.replayDurationMs(perfect)`, `PitchDramaView` 색 |
| 4 | 미트 소리 1.3배·낮게, 삼진 콜 0.2초 앞당김 | `PitchFeedbackPlan.make(perfect)` 볼륨·타이밍 |
| 5 | 결과 카드 "★ 퍼펙트" 스탬프, 구속 금색, 포수 한마디 | `PitchResultCard` |
| 7 | 스코어보드 "퍼펙트 n연속" | `PitchActivity` 상태 + `PitchScoreboardBar` |
| 8 | 등판 요약 "퍼펙트 n/m", 라이프카드·시즌 결산 통산 퍼펙트 | 커널 `performance.perfectReleases`, P010·P028·P019 행 |
| 9 | 퍼펙트 3개당 각성 전조 +1 | 커널(1절) |
| 6 | 퍼펙트 뒤 자동 진행 600ms | 실기기 비교 뒤 |
| 10 | 창 2.5% 유지, 예고(1)를 제구에 비례해 일찍 | 실기기 비교 뒤 |

## 4. 환생 규칙
- 얼굴: 초상화 시드를 "이 계보의 첫 생 이름"으로 고정한다(`playerPortraitSeed`가 `archive.first().playerName`을 우선). 이름을 바꿔도 얼굴이 이어진다. 커널 변경 없음.
- 서사: 이름이 같으면 "다시 태어난 나", 다르면 "기억을 이어받은 다른 선수"(현재 `RebirthContinuity.samePlayer` 유지).
- 계보: 라이프카드와 환생 화면에 최근 3생의 대표 유산을 한 줄로.

## 5. 튜토리얼 세 번째 공
- 세 번째 연습 공에서만 슬라이더 판정 창을 제구 +15 기준으로 넓힌다(표시와 판정 모두). 기록에 남지 않는 연습이라 밸런스 영향 없음. `PitchActivity`가 `lastPresentation.pitchNumber == 2`일 때 `commandRating + 15`를 넘긴다.

## 6. 작업 순서와 검증
1. 화면만으로 되는 것: 퍼펙트 1·2·3·4·5·7, 성장 체감 표, 환생 얼굴·계보, 튜토리얼 보정. 단위 테스트·lint·빌드·에뮬레이터.
2. 커널: 1절 + 퍼펙트 8·9. `:game-core:test` 전체, 특히 `HighSchoolPhase4FixtureTest`·`ReleaseTrainingParityTest`가 바이트 동일해야 한다. 새 명령의 단위 테스트를 추가한다.
3. 화면: P010 액션·결과 줄, 라이프카드·시즌 결산 퍼펙트.
4. 실기기: 퍼펙트 6·10 비교, 공유 이미지, 은퇴 화면, 세이브 덮어 설치.
5. iOS: 출시 뒤 커널 1절과 문안을 Swift에 이식하고 픽스처를 재생성한다.

## 7. 구현 결과 (2026-09-07)

### 1절 "이 경기는 내가 던진다" — 완료
- 커널: `HighSchoolState.chapterGameClaimed`, `HighSchoolPerformance.perfectReleases`, 새 명령 `ClaimChapterGame`, 정규 시나리오 4종(`HighSchoolContentCatalog.regularScenarios`), `recordImportantGame`이 장 결산으로 복귀, `advanceChapter`가 두 줄을 그대로 시뮬레이션한 뒤 첫 줄을 버린다.
- 저장: 고교 상태 JSON은 두 필드를 기본값일 때 생략, phase-4 이진 스키마 9→10.
- 세이브 호환: 정식 해시가 `toString()`을 쓰는 자리가 있어 새 필드가 기존 세이브의 서명을 바꾼다. `SaveCommitmentCompatibility.stable()`이 기본값 토큰을 지운다. 프로 계승 문맥은 아홉 칸짜리 옛 형식을 유지하려고 퍼펙트를 0으로 넣는다.
- 픽스처: `HighSchoolPhase4FixtureTest`(Swift 오라클) 그대로 통과.

### 2·3절 성장 체감과 퍼펙트 — 화면 완료
- 금색 구간 진입 예고 진동, 퍼펙트 릴리스 0.1초 정지 + 금색 링 + 전용 소리(`baseball_perfect_release.wav`, 합성·피크 -3dB) + 진동 2연타.
- 궤적 금색·비행 15% 단축, 미트 소리 1.3배·낮게, 삼진 콜 0.2초 앞당김.
- 결과 카드 "★ 퍼펙트" 스탬프·금색 구속·포수 한마디, 스코어보드 연속 표시, 등판 요약·라이프카드·생 기록에 통산 퍼펙트.
- 구위: 미트 볼륨·음높이가 구속 130→150km/h에 0.8→1.2배. 제구: 성장 직후 첫 공에 이전 창을 점선으로 2.5초. 무브먼트: 궤적 진폭 0.7~1.3배(표시만).

### 4·5절 — 완료
- 초상화 시드가 계보 첫 생 이름으로 고정(이름을 바꿔도 얼굴 유지), 이름이 다르면 "기억을 이어받은 다른 선수" 문구. 환생·라이프카드에 최근 3생 계보 한 줄.
- 튜토리얼 세 번째 공만 제구 +15.

### 남은 것
- 퍼펙트 6(자동 진행 600ms)·10(예고를 제구에 비례해 일찍): 실기기 비교 뒤 결정.
- iOS 이식: 안드로이드 출시 뒤.
- 시즌 라인 화면: 안드로이드에는 아직 시즌 라인 목록 화면이 없어 `regular` 표시는 장 결산 줄로만 나온다.
