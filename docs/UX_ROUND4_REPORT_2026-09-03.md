# UX 4차 개선 보고 — 2026-09-03

스펙: `docs/UX_ROUND4_SPEC_2026-09-03.md`. 0절 절대 규칙·1절 기존 부품·3절 양식은 2차 스펙과 같다. 커밋·푸시·stash 없음. 시뮬레이터 iPhone 17(`641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF`). D3만 iPhone SE(3세대) 하나(`C699BFF1-BE79-46A1-8215-0B1B2514E294`)를 만들고 17을 shutdown한 뒤 boot, 끝나면 삭제하고 17을 다시 boot. 런치 전 `baseball.audio.sound` NO, 종료 때 `defaults delete`.

3차 결과는 워킹트리 위. 측정값: `apps/ios/releases/qa-1.2.9/round4/budget.json`. 예산은 목표이지 CI 게이트가 아니다.

순서: D2 → D1 → D5 → D3 → D4 → D6.

## D2. 측정 공백 메우기 — 훈련·결정 픽스처

- **만든 파일:** `HighSchoolCareerStore+Fixtures.swift`, `MobileCareerStore+Fixtures.swift`
- **바꾼 파일:** `BaseballApp.swift` (런치 인자 `-uiTestTrainingFixture`, `-uiTestSeasonDecisionFixture`), `QACaptureUITests.swift` (`testCaptureTrainingFixture`, `testCaptureSeasonDecisionFixture`), `CareerBootstrapTests.swift` (픽스처 2개), `project.pbxproj`
- **동작:** 고정 시드. 고교는 start → 프롤로그 완료 → 학교 선택만으로 1장 훈련 첫 주 서명 스냅샷. 프로는 `CareerBootstrap.startCareer` 뒤 JSON으로 1시즌 6주차·`seasonDecision`·포수 경기 계획 결정을 덮고 `resignFixtureForTesting`. Lifecycle 파일은 수정하지 않음. 커리어 훈련/주간 루프 RNG는 소비하지 않음.
- **전후:** 3차에는 훈련·결정 행이 비어 있었음. `round4/D2/hs-training.png`, `round4/D2/pro-decision.png`
- **예산 맞춤:** 훈련은 자세히/강도/전망을 접고, 챕터 목표 긴 설명을 뺐고, 고정 바 둘째 줄을 아이콘+제목으로 줄임. 결정은 서사·타이밍을 `startsCollapsed` 접기로, 선택지 본문은 기본 숨김(칩+제목만). 바람 칩 접근성 라벨이 20자+ 1개로 남음.
- **확인:** 유닛 테스트 2개 통과. identifier 유지.

## D1. 투구 준비 화면 예산

- **바꾼 파일:** `PitchCatcherCard.swift`, `ProgressiveDisclosure.swift` (`startsCollapsed`), `PitchCopyKeys.swift`
- **동작:** "포수의 생각" `contentID pitch.sign.rationale`, `important: false`, 첫 회 포함 접힘. 1안/2안 세그먼트 한 줄 + 선택된 사인 한 줄. "내 선택 유지"·상대 분석을 `설정 ▾` 접기로. 사인 한 줄·칩 2·던지기·슬라이더·자동 릴리스 위치 불변. identifier 6개 유지.
- **전후:** `round4/D1/opening.png` → `before-3.png` (3구 전) → `after-pitch1.png` → `after-3.png` (3구, 타석 한 줄 헤더 + 포수 카드 접힘 + 던지기)
- **확인:** 3구 뒤 슬라이더/던지기 첫 화면. 측정 텍스트는 점수판·구종 그리드·칩이 그대로라 예산을 넘김(아래 표).

## D5. 프로 2시즌 스모크

- **경로:** `-uiTestDraftedCareerFixture` → 결과 1화면 → 유산 2화면(`hs.enterPro`) → 계약 서명(한 구단의 상징) → 주간. axe 탭이 화면 밖 activation point를 찍어 주간 자동 진행이 자주 막힘. 1시즌 0주차 스프링캠프·1주차(첫 공식 등판)까지 실주행.
- **캡처:** `round4/D5/00-drafted.png` … `01-draft-result.png` … `02-legacy.png` … `03-contract.png` … `04-week.png` … `05-after-week1.png`. 은퇴 미리보기는 기존 `installRetiredShareFixtureForUITesting`를 `-uiTestRetiredShareFixture`로만 연결해 `10-retirement-preview.png`. 2시즌 결산·오프시즌 실주행 화면은 도달하지 못함.
- **발견:**
  1. 보직 지원 카드가 선발·긴 이닝 구원 모두 "이미 맡은 보직입니다"를 그림(주간 첫 화면).
  2. `확인하고 계속`이 알림 뒤에 주 버튼을 가림 — C1 의도이나 자동 진행을 막음.
  3. axe `--id` 탭이 y>화면 좌표를 써서 서명 확인(`제안 수락`)·주간 진행이 한 번에 안 됨. 좌표 탭으로 우회.
- **수정:** 이 라운드에서 보직 카피 중복은 고치지 않음(발견 목록).

## D3. iPhone SE와 큰 글씨

- **기기:** SE 3세대 없음 → `C699BFF1-BE79-46A1-8215-0B1B2514E294` 하나 생성. 17 shutdown → SE boot → 캡처 → SE delete → 17 boot.
- **바꾼 파일:** `HighSchoolTrainingViews.swift` (둘째 줄 아이콘+제목), `HighSchoolChapterHeaderViews.swift` / `TodayView.swift` (`ViewThatFits` 타일·칩, 접근성 크기에서 키아트 72pt)
- **캡처 12장+:** `round4/D3/se/` 8장(훈련·결정·드래프트·프로주간·온보딩 4), `round4/D3/xxxl/` 4장.
- **확인:** SE 훈련에서 고정 바는 아이콘+제목 한 줄, 30% 미만. SE 투구에서 던지기 첫 화면. XXXL 훈련은 큰 글씨+고정 바가 타일 숫자와 겹칠 수 있음(키아트 축소 후에도 세로 예산이 빠듯). 잘림 `…`은 SE 본문에서 보이지 않음.

## D4. VoiceOver 순서

- **바꾼 파일:** `TrainingCommitBar` / `rookieSignBar` / `DeliveryControl` `accessibilitySortPriority(-50)`. 알림 `CareerFlowNotices`·고교 알림 `+8`. 닫기 `accessibilityLabel` (`notice.dismiss`) — `CareerFlowChrome` 배너, 결정 후속 카드.
- **순서 (axe describe-ui y 순, `round4/D4/`):**
  - **훈련:** 키아트 제목 → 타일 3(피로·믿음·전망) → 바람/스킬 칩 → 나와의 약속 → 무엇을 훈련할까요 → 추천 카드 → 자세히. 고정 바(`hs.training.commitBar`)는 우선순위 −50으로 본문 뒤.
  - **계약:** 키아트·제안 숫자 → 목표 카드 → `pro.contractOffer.signBar`(−50) 마지막.
  - **투구:** 점수판·타석 → 포수 카드(사인·1안/2안·설정) → `pitch.throw`/`pitch.windup`(−50) 마지막.
- **알림:** 헤더 다음 우선순위 8. 닫기 라벨 `닫기`.

## D6. 말투 통일 패스

- `Localizable.xcstrings` ko 값 중 `settings.*` `pro.*` `training.*` `pitch.*` `meta.*` `chapter.*` `draft.*` `fatigue.*` `notice.*`에서 "~해요/~에요/~네요" 종결 **0건**. 2차 A4 이후 시스템 문구는 이미 "~합니다" 쪽. 서사 `content.*`는 건드리지 않음.
- `node tools/check-korean-game-copy.mjs` 통과. 바뀐 키: 없음(이 항목). D1에서 넣은 새 키만 아래 목록.

## 게이트

린트는 항목 구현 직후, 유닛 테스트는 라운드 끝에 한 번.

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
→ ** TEST SUCCEEDED **  Executed 576 tests, with 0 failures
```

(`CareerBootstrapTests` 픽스처 2개 포함. 3차 게이트 574에서 2 증가.)

## C7 예산 표 (자동 밀도, iPhone 17)

| 화면 | 예산 텍스트/20자+/버튼 | after | 비고 |
|---|---|---|---|
| 고교 훈련(추천 펼침) | ≤8 / ≤1 / ≤3 | 51/1/9 | 픽스처로 실측. 20자+는 바람 칩 a11y 1개. 헤더 타일·칩·카드 제목이 텍스트 수 |
| 고교 장 시작 | ≤8 / ≤2 / 1 | — | 이번 라운드 재측정 없음(3차 6/2/1) |
| 투구 준비(3구 이후) | ≤8 / ≤1 / ≤4 | 57/7/17 | 포수 카드는 접힘. 점수판·구종 그리드·칩이 카운트 |
| 결정 카드 | ≤9 / ≤1 / 3 | 28/4/4 | 서사 접힘. 20자+ 4는 선택지 VoiceOver 라벨 3+경고 1 |
| 드래프트 1화면 | ≤5 / ≤1 / 1 | — | 3차 13/1/1. 이번 라운드 SE 캡처만 |
| 프로 주간 | ≤10 / ≤1 / ≤3 | 37/2/5 | 계약 직후 스프링캠프. 보직 지원 카드 포함 |

## 새 카피 키 (ko / en / ja)

주입: `node tools/inject-copy-batch.mjs tools/copy-round4.json`

| 키 | ko |
|---|---|
| `pitch.catcher.settings` | 설정 ▾ |
| `pitch.catcher.option.a` | 1안 |
| `pitch.catcher.option.b` | 2안 |

## 수정 금지 파일에 필요한 변경 "요청"

1. **`UITests/Release128JourneyUITests.swift`** — 2·3차와 같음. 탭 `"고교"`/`"프로"` → `"커리어"`. 손대지 않음.
2. **`Application/HighSchoolCareerStore+Lifecycle.swift`**, **`Application/MobileCareerStore+Lifecycle.swift`**, **`Presentation/CareerSharePresentation.swift`**, **`Tests/CareerShareCardTests.swift`** — 이번 라운드에서 필요한 변경은 없다. 워킹트리에 이미 다른 세션 수정이 있어 그대로 두었다.

## 건너뛴 항목

없음. D6·D4를 빼지 않았다. D1·D2·D5는 넣었다.

D5의 2시즌 결산·오프시즌 실주행 캡처는 시간·axe 화면 밖 탭 때문에 못 채움. 은퇴는 기존 픽스처 미리보기.

## git status --short

```
 M apps/ios/Baseball.xcodeproj/project.pbxproj
 M apps/ios/Sources/Application/HighSchoolCareerStore+Lifecycle.swift
 M apps/ios/Sources/Application/MobileCareerStore+Lifecycle.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolCareerView.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolChapterHeaderViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolChapterReviewViews.swift
 M apps/ios/Sources/Features/HighSchool/HighSchoolTrainingViews.swift
 M apps/ios/Sources/Features/Pitch/DeliveryControl.swift
 M apps/ios/Sources/Features/Pitch/PitchCatcherCard.swift
 M apps/ios/Sources/Features/Pro/CareerFlowChrome.swift
 M apps/ios/Sources/Features/Pro/CareerFlowView.swift
 M apps/ios/Sources/Features/Pro/ProContractOfferView.swift
 M apps/ios/Sources/Features/Pro/ProSeasonDecisionView.swift
 M apps/ios/Sources/Features/Shell/AvatarFace.swift
 M apps/ios/Sources/Features/Shell/BaseballApp.swift
 M apps/ios/Sources/Features/Shell/ProgressiveDisclosure.swift
 M apps/ios/Sources/Features/Shell/TodayView.swift
 M apps/ios/Sources/Presentation/CareerSharePresentation.swift
 M apps/ios/Sources/Presentation/DesignSystem.swift
 M apps/ios/Sources/Presentation/Localization/Localizable.xcstrings
 M apps/ios/Sources/Presentation/Localization/PitchCopyKeys.swift
 M apps/ios/Tests/CareerBootstrapTests.swift
 M apps/ios/Tests/CareerShareCardTests.swift
 M apps/ios/UITests/QACaptureUITests.swift
 M apps/ios/UITests/Release128JourneyUITests.swift
 M docs/P2_CAREER_CARD_SHARE_REPORT_2026-09-02.md
 M tools/measure-info-budget.mjs
?? apps/ios/Sources/Application/HighSchoolCareerStore+Fixtures.swift
?? apps/ios/Sources/Application/MobileCareerStore+Fixtures.swift
?? docs/SABERMETRICS_STAGE1_WAR_SPEC_2026-09-02.md
?? docs/UX_ROUND4_REPORT_2026-09-03.md
?? tools/copy-round4.json
?? tools/round4-d5-play.mjs
```
