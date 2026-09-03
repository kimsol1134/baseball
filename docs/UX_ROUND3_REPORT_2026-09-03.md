# UX 3차 개선 보고 — 2026-09-03

스펙: `docs/UX_ROUND3_SPEC_2026-09-03.md`. 0절 절대 규칙·1절 기존 부품·3절 양식은 2차 스펙과 같다. 커밋·푸시·stash 없음. 시뮬레이터 iPhone 17(`641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF`). 런치 전 `baseball.audio.sound` NO, 종료 때 `defaults delete`.

2차 결과는 커밋 `c9aed1a3`. 이 라운드는 그 위에 워킹트리만 작업했다.

측정값: `apps/ios/releases/qa-1.2.9/round3/budget.json`. 예산은 목표이지 CI 게이트가 아니다.

## C7. 정보 예산 측정 스크립트

- **만든 파일:** `tools/measure-info-budget.mjs`
- **동작:** 부팅된 시뮬레이터에서 `axe describe-ui`를 받아 첫 뷰포트(`y < 874`, 탭바 `y ≥ 780` 제외)의 텍스트 덩어리·20자+ 문장·버튼·숫자만 라벨을 센다. `--screen`/`--label`/`--launch`/`--out` 지원. 결과는 `budget.json`에 병합한다.
- **전후:** 아래 표. 훈련·결정·투구 준비 전용 픽스처는 없어서 해당 행은 오프닝/불펜으로 대체하거나 비웠다.

### C7 전후 표 (자동 밀도, iPhone 17)

| 화면 | 예산 텍스트/20자+/버튼 | before | after | 비고 |
|---|---|---|---|---|
| 고교 훈련(추천 펼침) | ≤8 / ≤1 / ≤3 | 6/2/1 (오프닝) | — | 훈련 픽스처 없음. 구현은 C5 |
| 고교 장 시작 | ≤8 / ≤2 / 1 | — | 6/2/1 (오프닝) | 오프닝 `시작하기` |
| 투구 준비(3구 이후) | ≤6 / 0 / ≤3 | — | 53/10/10 | 3구 뒤 타석·읽기 게이지는 접힘. 포수 카드·던지기 유지. 예산 초과 |
| 결정 카드 | ≤9 / ≤1 / 3 | — | — | 전용 픽스처 없이 미측정 |
| 드래프트 1화면 | ≤5 / ≤1 / 1 | 38/7/3 | **13/1/1** | 지명 픽스처. 버튼 예산 충족. 텍스트는 키아트 눈썹 포함 |
| 프로 주간 | ≤10 / ≤1 / ≤3 | 40/3/6 | **31/4/1** | 세그먼트 제거·알림 1장. 부상 카드 문장이 20자+ |

## C1. 알림은 한 번에 하나

- **바꾼 파일:** `CareerFlowView.swift` (`CareerNoticeQueue`), `CareerFlowChrome.swift` (`ResultBanner` 닫기), `ProWeeklyPlanView.swift`, `HighSchoolCareerView.swift`, `HighSchoolTrainingViews.swift` (`TrainingCommitBar`)
- **동작:** 우선순위 부상 → 성장 → 결정 후속 → 주간 배너. 한 장만 그린다. 고교는 팔 건강 → 훈련 결과 → 만개 → 성장 → 요약. 닫지 않은 알림이 있으면 주 버튼 라벨이 `확인하고 계속` (`hs.training.commit` / `pro.advanceWeek` identifier 유지). 후속 카드 identifier `pro.weekly.decisionFollowUp.*` 유지.
- **전후:** `round3/C1/before-pro-notices.png` → `round3/C1/after-pro-notices.png`, `after.png`
- **확인:** 리뷰 개선 픽스처 첫 화면 상단에 부상 카드 한 장. 역할 지원 카드는 알림이 아니라 주 결정이라 큐 밖에 남긴다.

## C2. 프로 "오늘 / 이번 주" 세그먼트 제거

- **바꾼 파일:** `AppShell.swift` (`ProCareerTabs`), `CareerFlowView.swift`, `TodayView.swift` (`ProCareerStatusHeader`, `ProCareerNewsSection`), `ProWeeklyPlanView.swift` (중복 타일 제거)
- **동작:** 세그먼트·TodayView 사용처를 끊고 `CareerFlowView` 상단에 키아트(주차·구단·보직) + 타일 3(피로·감독의 믿음·부상) + 시즌 진행바. 긴장·소식·최근 등판은 맨 아래 `ProgressiveDisclosure("소식")`. `TodayView.swift` 파일은 남김. `-uiTestOpenProWeek`는 읽고 무동작.
- **전후:** `round3/C2/before-pro-week.png` → `after-pro-week.png`
- **확인:** 오늘/이번 주 전환 UI 없음. 스크롤 없이 주차·상태 3개·부상 알림(또는 계획)이 보인다.

## C3. 헤더 압축

- **바꾼 파일:** `HighSchoolChapterHeaderViews.swift`, `CareerDirectionCard.swift` (`wordCopyKey`), `DesignSystem.swift` (`keyArtHeightCompact = 140`)
- **동작:** 타일 = 피로 · 팀의 믿음 · 전망(값 + 캡션 `당락선 N`, A3 색). "훈련 N" 타일·별도 전망 칩 삭제. 피로 캡션은 한 단어(`정상/지침/과로/탈진`). 바람·스킬을 한 줄 두 칩(`hs.wind.chip`, `hs.skillTree.open` 유지). 키아트 높이 훈련 140 / 사건 190.
- **전후:** `round3/C3/before.png` (2차 지명 화면의 훈련 타일·전망 칩) → `after.png`, `after-draft-header.png` (미지명 직전 헤더)
- **확인:** 전망 39 · 당락선 66, 피로 캡션 `과로`, 칩 `바람 · 배터리의 해 ▸` `스킬 3/3 ▸`.

## C4. 드래프트·유산을 두 화면으로

- **바꾼 파일:** `HighSchoolDraftLegacyViews.swift` (`DraftPeakResultView`), `HighSchoolCareerView.swift` (`draftLegacyStep` 로컬 상태)
- **동작:** `phase`는 쪼개지 않는다. 1화면 = 키아트 + 지명/미지명 도장 + 평가 점수 + 이유 칩 2개 + 주 행동 1개. 2화면 = 기존 유산/완료(이유 카드 제외). 앱을 다시 열면 1화면. identifier `hs.bestEvaluation`은 1화면 점수에 유지. 실제 프로 진입 버튼 `hs.enterPro`는 2화면에 유지.
- **전후:** `round3/C4/before-drafted.png` → `after-drafted.png`. 미지명 픽스처(`-uiTestUndraftedCareerFixture`)는 **지명 직전**이라 1화면이 아니라 드래프트 대기(`after-undrafted.png`).
- **확인:** 지명 1화면 텍스트 13·20자+ 1·버튼 1. 스펙 텍스트 ≤5는 키아트 눈썹 때문에 초과(목표이지 실패 아님).

## C5. 훈련 화면 — 추천 카드만 펼친다

- **바꾼 파일:** `HighSchoolTrainingViews.swift`
- **동작:** 선택된(추천) 카드만 칩+접기+강도+전망. 나머지 5장은 한 줄(아이콘·제목·칩 2개). 오늘의 기회 콜아웃 삭제(`기회` 칩만). 고정 바 두 번째 줄 설명은 `SeenContentStore` `hs.training.repeat.explained`로 첫 회만.
- **전후:** 훈련 픽스처 없이 코드로 확인. identifier `hs.focus.*`, `hs.focus.effect.*`, `hs.training.outlook`, `hs.training.commit` 유지.

## C6. 자동 접힘 14일 유효기간

- **바꾼 파일:** `ProgressiveDisclosure.swift` (`SeenContentStore`), `HighSchoolSetupView+NameStep.swift` (계승 상점 안내), `ProContractOfferView.swift` (계약 목표 안내)
- **테스트 파일:** `apps/ios/Tests/SeenContentStoreTests.swift` (배열 마이그레이션, 14일 재펼침)
- **동작:** `[id: timestamp]` (`baseball.seenContent.v2`). 기존 배열 키는 마이그레이션해 유지. `contains`는 14일 이내만 참. 펼친 뒤에만 `markSeen`. 투구 코치 팁·결정 접기는 같은 스토어를 쓰므로 유효기간이 따라간다.

## B5. 투구 화면 간결 모드 (2차 이월)

- **바꾼 파일:** `PitchView.swift`
- **동작:** 3구 이후 또는 밀도 `compact`에서 타석 카드·읽기 게이지를 한 줄 헤더(`연습 타자 · 우타 · 읽힘 N%` + `상세 ▾`)로 접고 점수판 아래에 고정한다. 포수 카드·슬라이더·와인드업(던지기)·자동 릴리스는 위치·동작 불변.
- **전후:** `round3/B5/after-first-pitch.png` (3구 전, 타석+읽기 펼침) → `after-3-pitches.png` (3구 뒤 타석·읽기 없음, 포수·던지기 유지).
- **확인:** 3구 뒤 슬라이더(던지기)가 첫 화면에 보인다. SE는 이번 라운드에서 실측하지 않음.

## B6. 키아트 다양화 (2차 이월)

- **바꾼 파일:** `HighSchoolChapterHeaderViews.swift` (`art(for:)` 장 기준), `TodayView.swift` (`ProCareerStatusHeader.art`)
- **동작:** 고교 1장 `careerIntro`, 2·3·4장 훈련 `stadiumNight`, 각성 `awakening`, 학교 선택 `schoolCrossroads`, 드래프트 `draftDay`, 유산/완료 `reincarnation`. 프로 계약 `majorDebut`, 은퇴 `retirement`, 주간 `proStadiumTunnel`. 높이는 C3의 140/190과 같음.
- **전후:** 지명 1화면은 유산 키아트(밤하늘), 미지명 직전은 드래프트 키아트, 프로 주간은 터널. `round3/B6/after-pro-header.png`, `round3/C4/after-drafted.png`.

## 게이트 (구현 뒤 한 번에 실행)

항목마다 전체 유닛 테스트를 돌리면 시뮬레이터를 독점해 C7 전후 측정이 막혀, 린트는 구현 직후·유닛 테스트는 전 항목 구현 뒤에 한 번 돌렸다.

```
node tools/check-design-system.mjs
→ 디자인 시스템 검사 통과: 원시 색상·레거시 토큰·scene/milestone 역할 오용 0, 고정 본문 크기 0, 고대비 토큰 대응 및 WCAG AA 대비, 공통 컴포넌트 계약 확인

node tools/check-ios-localization.mjs
→ iOS localization release check passed: 3911 catalog entries and zero pending surfaces

node tools/check-copy.mjs
→ 문구 품질 검사 통과 (전체 제품): 내부 용어 38종·실존 야구 IP 42종 미노출

node tools/check-korean-game-copy.mjs
→ 한국어 게임 문구 검사 통과: 1394개 문자열 · 오류 0 · 경고 0

xcodebuild test ... -only-testing:BaseballIOSTests
→ ** TEST SUCCEEDED **  Executed 574 tests, with 0 failures
```

(`SeenContentStoreTests` 2개 포함. 2차 게이트의 572에서 2 증가.)

## 새 카피 키 (ko / en / ja)

주입: `node tools/inject-copy-batch.mjs tools/copy-round3.json`

| 키 | ko |
|---|---|
| `notice.confirm-and-continue` | 확인하고 계속 |
| `notice.dismiss` | 닫기 |
| `fatigue.status.word.normal` | 정상 |
| `fatigue.status.word.tired` | 지침 |
| `fatigue.status.word.overwork` | 과로 |
| `fatigue.status.word.exhausted` | 탈진 |
| `chapter.metric.draft-outlook` | 전망 |
| `chapter.metric.draft-cutoff` | 당락선 %lld |
| `chapter.chip.wind` | 바람 · %@ ▸ |
| `chapter.chip.skill` | 스킬 %lld/%lld ▸ |
| `news.section.title` | 소식 |
| `news.section.summary` | 긴장·최근 등판·구단 소식 |
| `draft.result.prepare-next` | 다음 선수 준비 |
| `draft.result.back` | 결과로 |
| `pitch.compact.header` | %@ · %@ · 읽힘 %lld% |
| `pitch.compact.detail` | 상세 ▾ |
| `pitch.compact.collapse` | 접기 ▴ |

## 수정 금지 파일에 필요한 변경 "요청"

1. **`UITests/Release128JourneyUITests.swift`** — 2차 B1과 같음. 탭 `"고교"`/`"프로"` → `"커리어"`. 이번 라운드에서 추가로 손댈 내용은 없다. 파일은 그대로 두었다.
2. **`Application/HighSchoolCareerStore+Lifecycle.swift`**, **`Application/MobileCareerStore+Lifecycle.swift`**, **`Presentation/CareerSharePresentation.swift`**, **`Tests/CareerShareCardTests.swift`** — 이번 라운드에서 필요한 변경은 없다. 워킹트리에 이미 다른 세션 수정이 있어 그대로 두었다.

## 건너뛴 항목

없음. C6 → C5 → B6 → B5 제외 순서를 쓰지 않았다. C1·C2·C3·C7은 모두 넣었다.

측정만 빠진 것: 고교 훈련 실주행(추천 펼침), 프로 결정 카드, SE 투구 슬라이더 y. 구현은 코드에 있다.

## git status --short

```
 M apps/ios/Baseball.xcodeproj/project.pbxproj
 M apps/ios/Sources/Application/HighSchoolCareerStore+Lifecycle.swift
 M apps/ios/Sources/Application/MobileCareerStore+Lifecycle.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolCareerView.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolChapterHeaderViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolDraftLegacyViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+NameStep.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolTrainingViews.swift
 M apps/ios/Sources/Features/Pitch/PitchView.swift
 M apps/ios/Sources/Features/Pro/CareerFlowChrome.swift
 M apps/ios/Sources/Features/Pro/CareerFlowView.swift
 M apps/ios/Sources/Features/Pro/ProContractOfferView.swift
 M apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift
 M apps/ios/Sources/Features/Shell/AppShell.swift
 M apps/ios/Sources/Features/Shell/CareerDirectionCard.swift
 M apps/ios/Sources/Features/Shell/ProgressiveDisclosure.swift
 M apps/ios/Sources/Features/Shell/TodayView.swift
 M apps/ios/Sources/Presentation/CareerSharePresentation.swift
 M apps/ios/Sources/Presentation/DesignSystem.swift
 M apps/ios/Sources/Presentation/Localization/GameCopyKey.swift
 M apps/ios/Sources/Presentation/Localization/HighSchoolConclusionCopyKeys.swift
 M apps/ios/Sources/Presentation/Localization/Localizable.xcstrings
 M apps/ios/Sources/Presentation/Localization/MetaCopyKeys.swift
 M apps/ios/Sources/Presentation/Localization/PitchCopyKeys.swift
 M apps/ios/Tests/CareerShareCardTests.swift
 M apps/ios/UITests/Release128JourneyUITests.swift
 M docs/P2_CAREER_CARD_SHARE_REPORT_2026-09-02.md
?? apps/ios/Tests/SeenContentStoreTests.swift
?? docs/SABERMETRICS_STAGE1_WAR_SPEC_2026-09-02.md
?? docs/UX_ROUND3_REPORT_2026-09-03.md
?? tools/copy-round3.json
?? tools/measure-info-budget.mjs
```
