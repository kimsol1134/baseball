# iOS 출시 전 수정 지시서 · 2026-09-12

기준 커밋 `67e59a32` (1.2.9 / build 67). 근거 보고서: `docs/IOS_PERSONA_QA_2026-09-12.md`.
이 문서는 **작업자(에이전트)가 그대로 실행하기 위한 것**이다. 각 항목은 독립적으로 고칠 수 있고, 서로 의존하지 않는다.

---

## 실행 결과 (2026-09-12 적용 완료)

이 문서대로 작업했다. 아래가 실제로 반영된 상태다.

| ID | 결과 | 무엇을 했나 |
|---|---|---|
| F-01 | **완료 · 눈 확인** | `drawVerdict`에 `guard callStampLabel == nil` — 도장이 찍히는 판정에서는 결과 단어를 그리지 않는다. 한국어·일본어 모두 겹침 사라짐 |
| F-02 | **완료 · 눈 확인** | `isChoicePhase` → `hidesFloatingTabBarForPhase`로 이름을 바꾸고 `.chapterReview` 추가. 자동 주행이 "다음 이야기로"를 눌러 다음 국면으로 넘어갔다(이전에는 기록 탭으로 튕겼다) |
| F-03 | **완료** | 단위 mph 5건·버튼 의뢰문 6건·직역 4건을 한국어 원문에서 재번역. 용어 5종 통일(代表遺産/継承ポイント/覚醒/スタミナ/変化球). 공백 아티팩트 147건 정리. 주간 계획 효과 4문장 재작성. **잔존 0건**(조수사·낱말 공백·야드파운드 단위 전수 검사) |
| F-04 | **완료** | `ProCareerPresentation.GameLogStage` 도입. 고교는 "N장", 직접 등판은 "선발"로 표시하고 접근성 라벨도 같은 말을 쓴다. 커널 `started`는 건드리지 않았다 |
| F-05 | **완료** | `conclusion.life-card.ra9` 한국어 `방어율` → `RA9` |
| F-06 | **완료 · 눈 확인** | 릴리스 패드 높이 상한 140pt, 미터 캡션 두 줄 분리, 스코어보드 줄바꿈 허용, 결과 행은 접근성 크기에서 세로 배치. 일본어+AX3에서 **말줄임표 0개·화면 밖 요소 0개**, "자세히" 버튼 5pt → 112×48 |
| F-07 | **완료** | `ProgressiveDisclosure`의 라벨·힌트를 `label:` 뷰로 옮겨 본문 전파를 끊었다(17곳 공통) |
| F-08 | **미해결 — 제약으로 기록** | `accessibilityElement(children: .combine)`을 넣어도 요소가 2개로 유지된다(식별자 없는 취소 버튼은 1개). 식별자를 label 안으로 옮기면 `app.buttons.matching(identifier:)`가 못 찾아 UI 테스트가 깨진다. 식별자를 유지하고 코드에 주석으로 남겼다 |
| F-09 | **완료** | 성장 카드가 태어난 국면(`growthNoticePhase`)을 벗어나면 접힌다. 마지막 훈련이 장을 끝내는 경우에도 카드가 사라지지 않게 같은 갱신에서 새 국면을 기준으로 삼는다 |
| F-10 | **완료** | 성장 그래프 8·9pt → `BaseballType.annotation`. 공유 카드는 360×450 고정 캔버스라 검사기 예외로 등록 |
| F-11 | **완료(사용자 결정)** | 능력 `변화구`의 영어를 `Movement` → `Breaking`(4키). 지표 `움직임`은 `Movement` 유지. 이제 두 이름이 갈린다 |
| F-12 | **오진 — 변경 없음** | 스크롤이 "유지"되는 것이 아니라 국면 전환 시 `proxy.scrollTo(phaseAnchor, anchor: .top)`으로 **의도적으로** 새 국면 본문을 위로 올린다(`HighSchoolCareerView.swift:620` 부근). 3차 패널에서 "보상이 화면 밖에서 소비된다"를 고치며 넣은 동작이라 되돌리지 않았다. 부작용(국면 제목·키아트를 지나침)은 남아 있으니 바꾸려면 별도 판단이 필요하다 |
| F-13 | **완료** | (a) 미터 라벨을 피로 이분법에서 미터 기준 표현으로 바꾸고 문턱 20 (b) 선수 만들기 1단계 중복 4줄 → 2줄 (c) "카드 공유" → "이 장면 공유"로 구분 (d) 와인드업 접근성 라벨을 화면 문구와 일치 |
| G-01 | **완료** | `check-copy.mjs`가 주석 줄을 건너뛴다. 비주석 위반은 여전히 잡히는 것을 일부러 넣어 확인했다 |
| G-02 | **완료** | F-10으로 해소 |
| G-03 | **완료** | 낡은 기대값 갱신(pitchOutcome 11개·batterSide 양타·당락선 50·시나리오 31·claim-game·카피 4건), `completedLives: 0` 보충, 인자 조립을 `ProSeasonSettlementCopy.seasonComparisonSubtitle`로 분리 |

### 게이트 결과

| 게이트 | 결과 |
|---|---|
| `npm run check:ios-localization` | 통과 (4,156 엔트리) |
| `npm run check:copy` | 통과 |
| `npm run check:design-system` | 통과 |
| `npm run check:real-names` | 통과 |
| `xcodebuild test -only-testing:BaseballIOSTests` | **632개 통과 · 어서션 실패 0** |

단위 테스트 주의 한 가지: `RealPlayDraftRateTests.testSkillLadderOnBothCurves`가 전체 런에서
결과를 못 내고 "Failing tests"에 올라오는 경우가 있다. **코드 문제가 아니라 메모리 고갈이다** —
이 스위트는 시뮬레이터를 1.6GB까지 올리는데, Unity 에디터·Android 에뮬레이터가 같이 떠 있으면
48GB 기기에서도 스왑이 50GB까지 차서 페이지 스래싱이 온다. 메모리가 정상일 때 단독 실행하면
**128.4초에 통과**한다(`-only-testing:BaseballIOSTests/RealPlayDraftRateTests/testSkillLadderOnBothCurves`).
전체 스위트를 돌리기 전에 무거운 에디터·에뮬레이터를 닫을 것.

### 눈으로 확인한 것

| 항목 | 확인 내용 |
|---|---|
| F-01 | 첫 불펜 루킹 스트라이크 — 도장만 남고 겹침 사라짐(한국어·일본어) |
| F-02 | 장 1 리뷰 — 탭 바가 사라지고 "다음 이야기로"를 눌러 다음 국면으로 진행(이전에는 기록 탭으로 튕겼다) |
| F-04 | 기록 탭 고교 경기 — "**1장 선발 1.0이닝** · 직접 등판". 프로 목록은 기본값 `.pro`라 "N주차 · 선발/구원" 유지 |
| F-06 | 일본어+AX3 첫 불펜 — 말줄임표 0개, 화면 밖 요소 0개, "자세히" 5pt → 112×48 |

한국어·영어는 의도한 것만 바뀌었다(RA9 1 + 접근성 키 4 + F-11의 4 + F-13의 카피) — HEAD와 대조해 확인했다.

---

## 0. 시작 전에 반드시 읽을 것

### 0.1 절대 건드리지 말 것

- **커널 계산과 규칙 버전.** `packages/simulation-core` 안의 확률식·규칙 버전·난수 소비 순서를 바꾸면 골든 픽스처와 Swift↔Kotlin 패리티가 깨진다. 이 문서의 어떤 항목도 커널 계산 변경을 요구하지 않는다. F-04는 **표시 레이어에서만** 고친다.
- **`LocalizationCoverageTests`가 코어 문자열과 정확히 일치하도록 잠근 키군**: `content.awakening.*`, `content.career-wind.*`, `content.karma.*`, `content.event.*`의 summary, `content.training-focus.*`, `awakening.confirmation.message`, 프롤로그 정적 카탈로그. 이 키들의 **한국어**를 바꾸면 코어까지 같이 바꿔야 해서 결정론 픽스처가 위험하다. → **한국어는 손대지 말고 일본어만 바꾼다.** (F-03은 전부 일본어만 바꾸므로 안전하다.)
- 기존 `accessibilityIdentifier` 값. UI 테스트(`CareerSmokeUITests`, `Release128JourneyUITests`)가 이 문자열로 요소를 찾는다. 식별자를 **지우거나 이름을 바꾸지 않는다**.

### 0.2 카피 수정 방법 (중요)

`.xcstrings`를 **손으로 편집하지 않는다.** JSON 배치를 만들어 주입한다.

```jsonc
// /tmp/copy-ja-units.json
{
  "GameContent": {
    "content.event.evt-velocity-drop.title": { "ko": "2km/h의 하락", "en": "...", "ja": "時速2km/hの低下" }
  },
  "Localizable": {
    "conclusion.life-card.ra9": { "ko": "RA9", "en": "RA9", "ja": "RA9" }
  }
}
```

```bash
node tools/inject-copy-batch.mjs /tmp/copy-ja-units.json
```

- 세 언어를 **모두** 적어야 한다. 바꾸지 않을 언어는 **현재 값을 그대로** 적는다(현재 값은 카탈로그에서 읽어 온다).
- 세 언어의 플레이스홀더 서명(`%@`/`%lld` 종류와 순서)이 다르면 주입이 실패한다. `%1$@` 같은 위치 지정자도 그대로 유지한다.
- 한국어 문구를 새로 쓰거나 바꿀 때는 `tools/check-copy.mjs`의 금지어를 피한다. 대표적으로 **"감독 신뢰"→"감독의 믿음", "포수 신뢰"→"포수와의 호흡", "커맨드"→"제구", "무브먼트"→"변화구"**.

### 0.3 검증 방법

```bash
# 정적 게이트 (빠름 — 카피/레이아웃 변경 때마다)
npm run check:ios-localization
npm run check:copy
npm run check:design-system
npm run check:real-names

# 빌드
xcodebuild -project apps/ios/Baseball.xcodeproj -scheme BaseballIOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build

# 단위 테스트 (반드시 한 번에 하나만. 동시 실행하면 오디오 테스트가 깨지고 앱이 죽는다)
xcodebuild test -project apps/ios/Baseball.xcodeproj -scheme BaseballIOS \
  -destination "platform=iOS Simulator,id=<UDID>" -only-testing:BaseballIOSTests
```

**시뮬레이터 눈 확인이 필요한 항목(F-01, F-02, F-06)은 반드시 실제로 띄워서 본다.**

```bash
U=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF   # 부팅된 iPhone 17
xcrun simctl install $U <DerivedData>/Build/Products/Debug-iphonesimulator/BaseballIOS.app
xcrun simctl launch $U com.solkim.baseball.ios -uiTestResetCareer
axe describe-ui --udid $U            # 접근성 트리 + 프레임
xcrun simctl io $U screenshot out.png

# 슬라이더 투구를 코드로 던지기: 누르고 <홀드>초 뒤 떼기
#   sweepSeconds = 1.18 − (기준구속tenths − 1100)/400 × 0.38 − 피로/100 × 0.24
#   홀드 = sweepSeconds / 2   (포심 140.8km/h·피로 0 → 0.44초, 커브 109km/h → 0.59초)
axe touch -x 201 -y 778 --down --up --delay 0.44 --udid $U

# 픽스처는 -uiTestResetCareer 와 같이 줘야 적용된다 (단독으로 주면 조용히 무시된다)
xcrun simctl launch $U com.solkim.baseball.ios -uiTestResetCareer -uiTestSeasonReviewFixture
xcrun simctl launch $U com.solkim.baseball.ios -uiTestResetCareer -uiTestRetiredShareFixture

# 일본어 + 접근성 글자 크기
xcrun simctl ui $U content_size accessibility-extra-large
xcrun simctl launch $U com.solkim.baseball.ios -AppleLanguages "(ja)" -AppleLocale ja_JP -uiTestResetCareer
xcrun simctl ui $U content_size large    # 끝나면 되돌린다
```

렌더 테스트의 PNG는 `BASEBALL_SHOT_DIR`로 안 나온다. 결과 번들 첨부에서 꺼낸다.

```bash
RES=$(ls -td ~/Library/Developer/Xcode/DerivedData/Baseball-*/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool export attachments --path "$RES" --output-path /tmp/shots
# manifest.json 의 suggestedHumanReadableName 이 save(name:) 이름이고 파일명은 UUID다
```

---

## 1. 작업 목록

| ID | 제목 | 등급 | 주 파일 | 눈 확인 |
|---|---|---|---|---|
| F-01 | 투구 결과 글자와 판정 도장이 겹친다 | **P0** | `Features/Pitch/PitchDramaView.swift` | 필요 |
| F-02 | 장 리뷰 주 버튼이 탭 바 뒤에 깔린다 | **P0** | `Features/Shell/AppShell.swift` | 필요 |
| F-03 | 일본어 카피 재작업 | **P0** | xcstrings (도구 주입) | 권장 |
| F-04 | 고교 직접 등판이 기록에 "구원 · N주차" | P1 | `Features/Shell/RecordView.swift` | 권장 |
| F-05 | 라이프 카드가 RA9를 "방어율"이라 부른다 | P1 | xcstrings | — |
| F-06 | 접근성 글자 크기에서 투구 화면 정보 손실 | P1 | `Features/Pitch/PitchView.swift`, `DeliveryControl.swift` | 필요 |
| F-07 | `ProgressiveDisclosure` 접근성 라벨 전파 | P1 | `Features/Shell/ProgressiveDisclosure.swift` | — |
| F-08 | 알럿 확인 버튼이 접근성 트리에 2개 | P1 | 11개 알럿 사이트 | — |
| F-09 | 성장 카드가 국면을 넘어 남고 갱신 안 됨 | P2 | `Features/HighSchool/HighSchoolCareerView.swift` | — |
| F-10 | 성장 그래프·공유 카드 고정 글자 크기 | P2 | `Presentation/ProCareerPresentation.swift` 외 | — |
| F-11 | 영어 `Movement` 용어 충돌 | P2 | xcstrings | — |
| F-12 | 국면 전환 시 스크롤 위치 유지 | P2 | `HighSchoolCareerView.swift` | 권장 |
| F-13 | 잔가지 카피 4건 | P3 | xcstrings | — |
| G-01 | `check:copy` 주석 오탐 5건 | 게이트 | `tools/check-copy.mjs` | — |
| G-02 | `check:design-system` 실패 2건 | 게이트 | F-10과 동일 | — |
| G-03 | 단위 테스트 실패 10건 | 게이트 | `apps/ios/Tests/*` | — |

권장 순서: **G-03 → F-01 → F-02 → F-05 → F-04 → F-07 → F-09 → F-03 → F-06 → 나머지**.
(G-03을 먼저 초록으로 만들어야 이후 변경이 만든 진짜 회귀를 볼 수 있다.)

---

## F-01 [P0] 투구 결과 글자와 판정 도장이 겹친다

### 증상
루킹 스트라이크와 볼 — **게임에서 가장 흔한 두 결과** — 마다 결과 단어와 판정 도장이 같은 자리에 그려져 글자가 깨져 보인다. 애니메이션이 끝난 뒤에도 **영구적으로** 겹친 채 남는다. 한국어("루킹 스트라이크"+"스트라이크")·일본어("見逃しストライク"+"ストライク") 모두 재현.

### 원인
`apps/ios/Sources/Features/Pitch/PitchDramaView.swift`

```swift
// 659행 — 결과 한 단어: 폰트 32*scale, 캔버스 높이의 0.12 지점
context.draw(resolved, at: CGPoint(x: size.width / 2, y: size.height * 0.12 + rise), anchor: .center)

// 196행 — 판정 도장: 폰트 20*scale(최대 1.28배 punch), 캔버스 높이의 0.17 지점
let center = CGPoint(x: size.width / 2, y: size.height * 0.17)
```

370×260pt 캔버스에서 결과 단어는 y≈11~52pt, 도장은 y≈30~58pt를 차지한다. 두 그리기 모두 `progress`가 1이 되어도 불투명도 1로 남는다(`verdictFlash`는 `min(1, …)`, 도장 `opacity`도 `min(1, …)`).

### 고칠 것 — 권장안
**`.calledStrike`·`.ball`에서는 결과 단어를 그리지 않는다.** 그 두 결과는 도장이 곧 결과이고, 캔버스 바로 아래 `BaseballCard` 제목이 이미 "루킹 스트라이크"를 전체 문구로 보여 준다(`PitchView.swift`의 `lastPitchPanel`). 지금은 같은 말이 세 번 있다.

```swift
private func drawVerdict(context: GraphicsContext, size: CGSize) {
    // 도장이 찍히는 판정(루킹 스트라이크·볼)은 도장이 결과를 말한다. 둘을 같이 그리면
    // 같은 자리에서 글자가 겹쳐 깨져 보인다(QA 2026-09-12 F-01).
    guard callStampLabel == nil else { return }
    guard verdictFlash > 0 else { return }
    …
}
```

**대안(결과 단어를 유지하고 싶다면):** 도장 y를 존 위 여백으로 내리고 결과 단어를 올린다. 존 상단은 캔버스 높이의 약 0.28 지점이므로(`platePoint(y: 500)` → 디자인 y 130, `pitchBox` y 62~308) 결과 단어 `0.09`, 도장 `0.23` 정도가 후보다. **반드시 눈으로 확인한다** — 계산만으로는 겹침이 안 풀린다.

### 하지 말 것
- 도장 자체를 삭제하지 않는다. 도장은 Phase 4에서 의도해 넣은 연출이다.
- 도장을 존과 겹치게 내리지 않는다(코스를 읽는 눈을 방해한다 — 196행 주석).

### 완료 조건
1. `apps/ios/Tests/PitchDramaRenderTests.swift`의 `testCalledStrikeStampAndSeams`(progress 0.44/0.50/0.62/**1.0**)를 돌려 결과 번들 첨부 PNG를 꺼내 **글자 겹침이 없음을 눈으로 확인**한다.
2. 시뮬레이터에서 첫 불펜을 켜고 루킹 스트라이크와 볼을 각각 한 번씩 만들어 스크린샷으로 확인한다.
3. `-AppleLanguages "(ja)"`로도 한 번 확인한다(일본어가 더 길다).

---

## F-02 [P0] 장 리뷰 주 버튼이 탭 바 뒤에 깔린다

### 증상
장 정산 화면(`chapterReview`)에 들어오면 주 버튼 "다음 이야기로"가 y 806~858에 놓이는데 플로팅 탭 바가 y 791~874다. 초록 버튼이 탭 바를 통해 비쳐 보이고, **그 자리를 누르면 버튼이 아니라 탭 바가 먹어 기록 탭으로 이동한다**(자동 주행에서 두 번 연속 재현). 스크롤을 끝까지 내려도 버튼 중심이 탭 바 위 27pt까지밖에 안 올라온다. 고교 8장 × 회차마다 지나가는 화면이다.

### 원인
`apps/ios/Sources/Features/Shell/AppShell.swift:335`

```swift
static func isChoicePhase(_ phase: HighSchoolCareerPhase?) -> Bool {
    switch phase {
    case .schoolSelection, .relationship, .awakening: true
    default: false
    }
}
```

`.chapterReview`가 빠져 있어 탭 바가 계속 떠 있다. 그리고 리뷰 화면의 CTA는 고정 바가 아니라 본문 안 인라인 버튼이다 — `apps/ios/Sources/Features/HighSchool/HighSchoolChapterReviewViews.swift:116~122`의 `PrimaryButton`.

### 고칠 것 — 권장안
`isChoicePhase`에 `.chapterReview`를 더한다. 이 화면은 선택 화면과 같은 성격(읽고 한 번 누르고 넘어간다)이고, 탭 바가 없어야 할 이유가 학교·관계·각성과 같다.

```swift
case .schoolSelection, .relationship, .awakening, .chapterReview: true
```

**대안:** 탭 바를 유지하려면 리뷰 CTA를 `HighSchoolCareerView`의 `.safeAreaInset(edge: .bottom)`(548행 부근, `.training`/`.importantGame`이 쓰는 그 자리)으로 옮긴다. 이때 `HighSchoolChapterReviewViews`의 인라인 `PrimaryButton`은 제거해야 버튼이 두 개가 되지 않는다.

### 확인해야 할 것
`isChoicePhase`는 이름이 "선택 국면"이다. `.chapterReview`를 넣는 것이 이름과 맞는지 판단하고, 맞지 않으면 함수를 `hidesFloatingTabBar(_:)`처럼 의도를 드러내는 이름으로 바꾼다(호출부는 `AppShell.swift:239` 한 곳).

### 완료 조건
1. 시뮬레이터에서 장 1을 끝내고 리뷰 화면에 들어가, **화면에 들어오자마자 보이는 "다음 이야기로"를 그대로 눌러 다음 국면으로 넘어가는지** 확인한다(기록 탭으로 튕기면 실패).
2. `axe describe-ui`로 버튼 프레임이 탭 바 프레임(y 791~874)과 겹치지 않음을 확인한다.
3. `-only-testing:BaseballIOSUITests/CareerSmokeUITests`를 **단독으로** 돌려 통과 확인(이 스위트가 장 진행을 밟는다).

---

## F-03 [P0] 일본어 카피 재작업

### 증상
일본어가 **한국어가 아니라 영어에서 기계번역**됐다. 뜻이 사라진 문장, 앱 내부 모순(단위), 화면마다 다른 용어가 섞여 있다.

```
pro.weekly.plan.stuff.effect
  ko 구위·포심 구속·헛스윙 성장 · %@
  en Builds stuff, four-seam velocity, and whiffs · %@
  ja ビルド内容、フォーシーム 速度、および 空振り · %@      ← 동사 Builds가 명사 「ビルド内容」이 됐다
```

`AGENTS.md`가 일본어 지원을 ASC 제출 조건으로 못 박고 있으므로 출시 차단으로 다룬다.

### 작업 원칙
- **한국어 원문에서 다시 번역한다.** 영어를 거치지 않는다.
- 한국어·영어는 **바꾸지 않는다**(§0.1의 잠금 키군 때문에도 안전하다).
- 전부 `tools/inject-copy-batch.mjs` 배치로 넣는다(§0.2).

### F-03-a. 단위가 mph로 남은 5건 — **가장 먼저**

일본은 구속을 km/h로 쓴다. 런타임 포매터는 이미 일본어에 km/h를 쓰도록 분기돼 있어(`Presentation/Localization/GameFormatters.swift:22`), 지금은 **같은 회차 안에서 투구 화면은 「140.8 km/h」, 이벤트 문장은 「時速1.2マイル」**이라고 말한다.

| 키 (GameContent) | ko | 현재 ja |
|---|---|---|
| `content.event.evt-velocity-drop.title` | 2km/h의 하락 | 時速1.2マイルの落下 |
| `content.event.evt-velocity-drop.summary` | 두 경기 연속 최고 구속이 2km/h 낮게 찍혔습니다. | 連続試合では最高速度が時速 1.2 マイル低下します。 |
| `content.relationship.evt-velocity-drop.quote.high` | “두 경기째 2km/h. 네가 먼저 느꼈을 거라 생각하는데, 어때?” | 「2試合連続で時速1.2マイル。誰よりも早く感じると思っていたけど、どんな感じ？」 |
| `content.relationship.evt-velocity-drop.quote.mid` | “두 경기째 구속이 2km/h 빠졌어. 숫자는 거짓말을 안 해. 몸이 뭔가 말하는 중이야.” | 「2試合連続で時速1.2マイルを落としている。数字は嘘をつかない。体が何かを訴えている。」 |
| `content.draft-team.daejeon_rockets.competitor-record` | 최고 158.2km/h · 134탈삼진 | 最高時速98.3マイル・134奪三振 |

숫자도 km/h 값(2km/h, 158.2km/h)으로 되돌린다. 「落下」(물체가 떨어짐)는 구속 저하에 쓰는 말이 아니다 — 「低下」로.

### F-03-b. 버튼이 의뢰문(「～してください」)인 6건

일본어 UI 버튼은 명령형·명사형 짧은 말이다. 「もう一度選択してください」가 **취소 버튼**에 붙어 있으면 무슨 버튼인지 알 수 없다.

| 키 | ko | 현재 ja | 제안 |
|---|---|---|---|
| `awakening.confirmation.action` | 이걸로 각성한다 | この覚醒を選択してください | この覚醒を選ぶ |
| `awakening.confirmation.cancel` | 다시 고른다 | もう一度選択してください | 選び直す |
| `conclusion.confirmation.cancel` | 다시 고른다 | もう一度選択してください | 選び直す |
| `school.selection.confirm.cancel` | 다시 고른다 | もう一度選択してください | 選び直す |
| `prologue.action.skip` | 바로 학교 고르기 | 今すぐ学校を選択してください | すぐに学校を選ぶ |
| `setup.name.suggestion-action` | %@ 쓰기 | %@を使用してください | %@を使う |

### F-03-c. 직역 아티팩트 4건

| 키 | ko | 현재 ja | 문제 |
|---|---|---|---|
| `conclusion.legacy.confirm-action` | 대표 유산을 확정한다 | 署名のレガシーをロックインする | 「署名」은 서명(사인). ロックイン은 영어 그대로 |
| `conclusion.memory.confirm-action` | 기억을 확정한다 | 思い出を閉じ込めて | て형으로 끝나 문장이 안 끝난다 |
| `pro.decision.confirm.action` | 이 선택으로 결정 | この選択にコミットする | コミット는 불필요한 외래어 |
| `pro.offseason.confirm.military.action` | 다녀온다 | 出発と帰還 | 명사구라 버튼으로 안 읽힌다 |

### F-03-d. 용어 통일

한 개념에 일본어 표기를 **하나만** 쓴다. 권장 용어집:

| 개념 | 채택 | 바꿔야 할 키 |
|---|---|---|
| 대표 유산 | **代表遺産** | 현재 4가지가 섞여 있다(シグネチャーレガシー / シグネチャー レガシー / 署名のレガシー / 署名の遺産). 대상 10키: `conclusion.legacy.confirm-action`, `conclusion.life-card.signature`, `conclusion.life-card.signature-accessibility`, `conclusion.signature.title`, `legacy.archive.signature`, `legacy.high-school-summary.rebirth.both`, `legacy.high-school-summary.rebirth.signature`, `legacy.previous.signature`, `setup.inheritance.legacy`, `setup.legacy.title` |
| 계승 포인트 | **継承ポイント** | `レガシーポイント` 8키: `legacy.archive.stat.points`, `legacy.career-error.reset.confirm`, `legacy.pledge.reward`, `legacy.recap.points.title`, `pro.retired.soul-points`, `pro.retired.soul.confirm.title`, `pro.retired.soul.title` (그리고 같은 표기를 쓰는 나머지) |
| 각성 | **覚醒** | `目覚め` 2키: `record.high-school.awakenings`, `content.achievement.awakened_thrice.title` |
| 체력 | **スタミナ** | `体力` 3키: `pro.offseason.investment.focus.stamina`, `pro.role-request.condition.starter.conditional`, `content.glossary.stamina.name` |
| 변화구(능력) | **変化球** | `変化量`/`変化` 4키: `setup.stat.movement`, `record.ability.movement`, `pro.summary.movement`, `pro.offseason.investment.focus.movement` |
| 움직임(구종 지표) | **変化量** | `pitch.build.metric.movement` — **이미 맞다. 그대로 둔다.** 능력과 지표가 같은 말이 되지 않게 하는 것이 이 항목의 목적이다 |

전수 확인 스크립트:

```bash
python3 - <<'PY'
import json,collections
for name in ("Localizable","GameContent"):
    d=json.load(open(f"apps/ios/Sources/Presentation/Localization/{name}.xcstrings"))
    seen=collections.defaultdict(set)
    for k,v in d["strings"].items():
        loc=v.get("localizations",{})
        ko=loc.get("ko",{}).get("stringUnit",{}).get("value") or ""
        ja=loc.get("ja",{}).get("stringUnit",{}).get("value") or ""
        for term in ("대표 유산","계승 포인트","각성","체력","변화구"):
            if term in ko and len(ko)<=24 and ja: seen[term].add(ja[:0] or next((j for j in ("代表遺産","シグネチャーレガシー","署名","継承ポイント","レガシーポイント","覚醒","目覚め","スタミナ","体力","変化球","変化量") if j in ja), "-"))
    print(name, {t:sorted(v) for t,v in seen.items()})
PY
```
각 개념의 결과가 **한 가지**만 나오면 끝이다.

### F-03-e. 공백·조수사 아티팩트 (기계번역 흔적)

- 숫자와 조수사 사이 공백 **67건**: 「3 年の風」「%lld 回」「2 つの異なる日」 → 「3年の風」「%lld回」「2つの異なる日」
- 일본어 낱말 사이 불필요 공백 **25건**: 「トレーニング セッション」「ニックネーム コレクション」「空振り を構築」

찾는 법:

```bash
python3 - <<'PY'
import json,re
a=re.compile(r'(?:%\w*lld|%@|\d)\s+[つ回個人年点球本試章週日月秒分名度段位]')
b=re.compile(r'[ぁ-んァ-ヶ一-龠]\s+[ぁ-んァ-ヶ一-龠]')
for p in ["Localizable","GameContent"]:
    d=json.load(open(f"apps/ios/Sources/Presentation/Localization/{p}.xcstrings"))
    for k,v in d["strings"].items():
        ja=v.get("localizations",{}).get("ja",{}).get("stringUnit",{}).get("value")
        if ja and (a.search(ja) or b.search(ja)): print(p,k,"->",ja[:70])
PY
```

**주의:** `%lld` 뒤 공백을 지울 때 플레이스홀더 자체를 건드리면 주입이 실패한다. 서명(`%lld`,`%@`의 종류·순서)은 그대로 두고 주변 공백만 없앤다.

### 완료 조건
1. `npm run check:ios-localization` 통과
2. 위 세 스크립트가 각각 0건 / 개념당 1표기
3. 시뮬레이터를 일본어로 띄워 오프닝 → 첫 불펜 → 훈련 → 기록 탭을 눈으로 확인
4. 한국어·영어 값이 **하나도 바뀌지 않았는지** `git diff`로 확인

---

## F-04 [P1] 고교 직접 등판이 기록에 "구원 · N주차"로 남는다

### 증상
경기 시작 화면은 **"정규 경기 선발 등판 · 1회 0아웃 · 1회부터 마운드를 맡습니다"**라고 말한다. 그런데 기록 탭 "고교 경기" 목록은 같은 경기를 **"2주차 구원 1.1이닝"**으로 적는다. 고교는 주(week)가 아니라 장(chapter) 단위이고, 플레이어는 선발로 나간다.

### 원인
`packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift`

```swift
// 1125행 — 플레이어가 직접 던진 경기
let playedLine = ProGameLine(
    season: params.state.chapter.schoolYear,
    week: params.state.chapter.number,   // ← 장 번호가 week 필드에 들어간다
    …
    started: false,                       // ← 직접 등판인데 구원으로 기록된다
```
```swift
// 1392행 — 자동 시뮬 경기
return ProGameLine(… started: true, …)   // ← 반대로 들어가 있다
```

표시는 `apps/ios/Sources/Features/Shell/RecordView.swift`의 `GameLogRow`(1018행 부근)가 한다.

```swift
Text(copyResolver.resolve(.week, arguments: [.integer(line.week)]))      // "%lld주차"
Text(ProCareerPresentation.gameRole(line, resolver: copyResolver))        // line.started → 선발/구원
```

### 고칠 것 — **표시 레이어에서만**
`GameLogSection` / `GameLogRow`에 무대 구분을 넘겨, 고교 목록에서는

- `%lld주차` 대신 **`%lld장`**(새 키 `record.game-log.chapter`)을 쓰고,
- `line.played`(플레이어가 직접 던진 줄)이면 역할을 **선발**로 표시한다.

호출부 두 곳:
- 고교 — `RecordView.swift:221` `GameLogSection(title: copyResolver.resolve(.highSchoolGames), lines: lines)`
- 프로 — `RecordView.swift:439` `GameLogSection(title: copyResolver.resolve(.seasonOutings), lines: lines)`

새 키는 §0.2 배치로 넣는다(ko `%lld장` / en `Chapter %lld` / ja `第%lld章`).

### 하지 말 것 — 중요
`HighSchoolCareer.swift`의 `started: false`를 **뒤집지 않는다.** 이 값은 바로 아래에서

```swift
decision: DecisionRules.decide(started: false, isCloser: false, outs: …)
```

로 승패 판정에 쓰인다(`LeagueBaseline.swift:236`). 뒤집으면 고교 승패 기록이 전부 달라져 골든 픽스처와 밸런스 측정이 깨진다. 승패 규칙까지 바로잡고 싶다면 **별도 작업**으로 규칙 버전을 올려 진행한다(이 문서의 범위 밖).

### 완료 조건
1. `-uiTestResetCareer`로 새 회차를 시작해 정규 경기를 한 번 치른 뒤 기록 탭에서 **"N장 · 선발 X이닝"**으로 보이는지 확인
2. 프로 기록 탭은 그대로 **"N주차 · 선발/구원"**인지 확인(회귀 없음)
3. `npm run check:ios-localization` 통과

---

## F-05 [P1] 라이프 카드가 RA9를 "방어율"이라고 부른다

### 증상
공유용 라이프 카드의 지표 칸 한국어 이름이 "방어율"인데 값은 RA9(실점 기준)다. 방어율(ERA)은 자책점 기준이라 다른 수치다. 같은 지표를 다른 화면은 "9이닝당 실점"(`pro.totals.ra9`) 또는 "RA9"(`record.saber.ra9`)로 부른다 — 한국어 이름이 세 가지다. **공유 카드는 이 게임에서 가장 많이 밖으로 나가는 이미지다.**

### 원인
```
conclusion.life-card.ra9   ko='방어율'  en='RA9'  ja='RA9'
```
값은 `apps/ios/Sources/Features/HighSchool/LifeCardView.swift:131`의 `rateStat(AppCopyKey.conclusionLifeCardRA9, rate.ra9)`.

### 고칠 것
`conclusion.life-card.ra9`의 **한국어를 `RA9`로** 바꾼다(en/ja와 같아지고, 좁은 칸에 들어가며, `record.saber.ra9`의 한국어와 일치한다).

```bash
node tools/inject-copy-batch.mjs <(echo '{"Localizable":{"conclusion.life-card.ra9":{"ko":"RA9","en":"RA9","ja":"RA9"}}}')
```

칸 폭이 허락하면 `9이닝당 실점`(다른 화면과 같은 말)도 가능하지만, 라이프 카드는 4칸을 가로로 나눠 쓰므로 짧은 `RA9`를 권한다.

### 같이 볼 것 (선택)
`LifeCardView.swift:127`의 주석 "이닝이 있어야 **방어율**·WHIP이 성립한다"도 같이 고친다.
ERA 자체는 **시즌 비교 카드**에 있다(`ProSeasonComparison.swift:37`의 `earnedRunAverage`, ko "평균자책"). 없는 것은 **통산·시즌 합계 쪽 ERA**다 — 기록 탭 세이버 표·은퇴 화면·공유 카드가 전부 RA9만 쓴다. 합계 화면에 ERA를 더할지는 별도 판단이다(이 문서의 범위 밖).

### 완료 조건
`npm run check:ios-localization` 통과 + `-uiTestRetiredShareFixture`로 카드 화면 확인.

---

## F-06 [P1] 접근성 글자 크기에서 투구 화면이 정보를 잃는다

### 증상 (일본어 + `accessibility-extra-large`에서 실측)
- 주자·아웃 「0アウト…」 잘림
- 미터 안내 「制球・安定…」 / 템포 「速い・疲労…」 **둘 다 잘림 — 릴리스 창을 읽을 수 없다**
- 이번 등판 줄 「0回・0K・0BB・0R・…」 잘림
- 피로 라벨이 「疲」/「労」 두 줄로 쪼개짐
- 고정 릴리스 바가 커져(와인드업 버튼만 200pt) 스크롤 뷰포트가 좁아지고, **구종 선택 줄과 구속·움직임·코스·체감 피로 행이 잘린 채 걸쳐 보인다**
- 결과 카드의 "자세히" 버튼 프레임이 **5pt × 144pt**로 찌그러진다

### 위치
- 화면 구조: `apps/ios/Sources/Features/Pitch/PitchView.swift` — `VStack { 헤더 / ScoreboardBar / GeometryReader{ScrollView{ corePitchSurface }} / footer }` (362~372행). `footer`는 1102행, `DeliveryControl`을 담는다.
- 아레나 높이: `corePitchSurface(arenaHeight: max(150, min(260, geometry.size.height - 180)))` — 접근성 크기에서 `footer`가 커지면 남는 높이가 줄어드는데 하한 150이 걸려 스크롤 본문이 뷰포트를 넘는다.
- 잘리는 문구들: `Features/Pitch/DeliveryControl.swift`(제구·안정 구간 / 템포), `Features/Pitch/PitchScoreboardViews.swift`(주자·아웃·등판 줄)

### 고칠 것
1. **잘리는 문구는 잘리지 않게.** 한 줄 고정 대신 줄바꿈을 허용한다 — `.lineLimit(2)` + `.fixedSize(horizontal: false, vertical: true)`. `minimumScaleFactor`로 줄이는 방식은 접근성 크기의 목적을 거스른다.
2. **접근성 크기에서는 고정 바를 줄인다.** 같은 문제를 고교 화면은 이미 이렇게 푼다 — `HighSchoolCareerView.swift:534`와 `:552`:

```swift
// 스크롤 본문 맨 아래에 둔다(접근성 크기)
if state.phase == .training, typeSize.isAccessibilitySize { trainingCommitBar(state: state) }
…
// 표준 크기에서만 고정 바
.safeAreaInset(edge: .bottom) {
    if state.phase == .training, !typeSize.isAccessibilitySize { trainingCommitBar(state: state) }
```
투구 화면은 릴리스 패드가 **손이 닿아야 하는 조작**이라 스크롤 안으로 넣을 수는 없다. 대신 접근성 크기에서 와인드업 버튼 높이를 낮추고(예: 200 → 120) 캡션 두 줄을 접어 `footer` 전체 높이를 줄인다.
3. **"자세히" 버튼이 5pt로 찌그러지는 것**은 같은 `HStack`의 라벨이 공간을 다 먹기 때문이다. 접근성 크기에서 라벨과 버튼을 세로로 쌓거나 버튼에 `.layoutPriority(1)`·최소 너비를 준다.
4. 아레나 하한 `max(150, …)`을 접근성 크기에서 더 낮추는 것도 같이 검토한다.

### 완료 조건
`content_size accessibility-extra-large` + `-AppleLanguages "(ja)"`로 첫 불펜을 열어

1. 「制球・安定ゾーン」·템포·주자/아웃·등판 줄에 **말줄임표(…)가 없다**
2. 구종 버튼 줄과 구속 행이 **잘린 채 걸쳐 보이지 않는다**(스크롤로 온전히 볼 수 있으면 된다)
3. "자세히" 버튼 프레임 너비가 44pt 이상(`axe describe-ui`로 확인)
4. 한국어 표준 크기에서 레이아웃 회귀가 없다

---

## F-07 [P1] `ProgressiveDisclosure`가 펼친 내용 전체에 제목 라벨을 덮어쓴다

### 증상
시즌 결산 화면에서 「팬 지지 9 → 9」「시즌 변화 +0」「계약 기대 미달 −1」「현재 구단에서 시즌 완주 +1」 네 줄이 접근성 트리에 **전부 "팬 지지 변화 이유, 자세히 펼쳐짐"**으로 보고된다. VoiceOver 사용자는 내용을 하나도 듣지 못하고 제목만 반복해 듣는다.

### 원인
`apps/ios/Sources/Features/Shell/ProgressiveDisclosure.swift` — `DisclosureGroup`은 `:142`에서 시작하고, `:158`의 `.accessibilityLabel(...)`과 `:164`의 `.accessibilityHint(...)`가 **그룹 전체**에 붙어 자식 요소마다 전파된다(`:157`의 `accessibilityIdentifier`는 그대로 둔다).

```swift
DisclosureGroup(isExpanded: $expanded) { detail().padding(.top, 4) } label: { … }
.accessibilityIdentifier(contentID)
.accessibilityLabel(…)     // ← 여기
.accessibilityHint(…)
```

### 고칠 것
라벨·힌트를 `label:` 뷰에만 붙인다. `detail()`은 자기 접근성을 그대로 유지한다.

```swift
DisclosureGroup(isExpanded: $expanded) {
    detail().padding(.top, 4)
} label: {
    VStack(alignment: .leading, spacing: 3) { … }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(…)
        .accessibilityHint(…)
}
.accessibilityIdentifier(contentID)
```

`accessibilityIdentifier`는 **바깥에 그대로 둔다**(UI 테스트가 쓴다).

### 영향 범위
앱 전체 **17곳**: `Features/Pitch/PitchCatcherCard.swift`, `Features/Pro/{ProSeasonSettlementView,ProRetirementViews,ProContractOfferView,ProWeeklyPlanView,ProSeasonDecisionView}.swift`, `Features/Shell/{WeeklyProgramView,TodayView}.swift`, `Features/HighSchool/{HighSchoolSetupView+NameStep,HighSchoolSetupView+StyleStep,HighSchoolAwakeningViews,HighSchoolTrainingViews}.swift` 외. 한 파일만 고치면 전부 고쳐진다.

### 완료 조건
`-uiTestResetCareer -uiTestSeasonReviewFixture`로 결산 화면을 열고 `axe describe-ui`에서
"팬 지지 9 → 9" 같은 **본문 행이 자기 내용으로 보고되는지** 확인(제목 라벨이 아니라).
UI 테스트 `-only-testing:BaseballIOSUITests/CareerSmokeUITests` 통과.

---

## F-08 [P1] 알럿 확인 버튼이 접근성 트리에 두 번 잡힌다

### 증상
알럿의 확인 버튼이 **같은 프레임·같은 라벨로 2개** 존재한다. 식별자가 없는 취소 버튼은 1개다. VoiceOver가 같은 버튼을 두 번 읽고, 자동화는 라벨로 탭할 수 없다(`axe`가 `Multiple (2) accessibility elements matched`로 거부).

실측 확인: 학교 선택("이 학교로 간다"), 각성("이걸로 각성한다"), 오프시즌("시작한다").

### 원인 가설
alert의 `Button`에 `.accessibilityIdentifier(...)`를 붙인 자리에서만 생긴다(식별자 없는 버튼은 1개).

### 대상 11곳
```
Features/Pitch/PitchView.swift:351                      pitch.abort.(practice.)confirm
Features/Pro/ProRetirementViews.swift:36                pro.retire.confirm
Features/Pro/ProRetirementViews.swift:233               pro.newPlayer.confirm
Features/Pro/ProImportantGameIntro.swift:111            pro.postseason.availability.confirm
Features/Pro/ProOffseasonViews.swift:144                pro.offseason.confirm
Features/Pro/ProOffseasonInvestmentView.swift:85        pro.offseasonInvestment.confirm.action
Features/Shell/SettingsView.swift:213                   settings.deleteAll.confirm
Features/HighSchool/HighSchoolAwakeningViews.swift:119  hs.awakening.confirm
Features/HighSchool/HighSchoolDraftLegacyViews.swift:659 hs.legacy.finalize
Features/HighSchool/HighSchoolDraftLegacyViews.swift:1026 hs.fold.confirm
Features/HighSchool/HighSchoolTrainingViews.swift:114   hs.school.confirm
```

### 진행 방법 (조사 포함)
1. **한 곳(`hs.school.confirm`)에서 먼저 실험한다.** 식별자를 `Button`의 `label:` 안쪽 뷰로 옮겨 보고, `axe describe-ui`로 요소가 1개가 되는지 본다.
2. 요소가 1개가 되고 **UI 테스트가 여전히 그 식별자로 버튼을 찾으면**, 나머지 10곳에 같은 패턴을 적용한다.
3. 두 조건을 동시에 만족하는 방법이 없으면 **원상복구하고** 이 문서에 "SwiftUI alert 제약 — 수정 불가"로 기록한다. 식별자를 지워 UI 테스트를 깨뜨리지 않는다.

### 완료 조건
`axe describe-ui`에서 확인 버튼이 1개 + `-only-testing:BaseballIOSUITests/CareerSmokeUITests` 통과. (또는 3번의 기록)

---

## F-09 [P2] 성장 카드가 국면을 넘어 남고 갱신되지 않는다

### 증상
훈련 뒤 뜨는 "성장 · 제구 25 → 28" 카드가 **각성과 정규 경기를 지나 다음 장까지 그대로 떠 있다.** 그 사이 각성(제구 −2)과 경기로 능력이 바뀌어, 같은 화면 능력표에는 "제구 25"라고 적혀 있는데 카드는 "25 → 28"이라고 말한다.

### 원인
`apps/ios/Sources/Features/HighSchool/HighSchoolCareerView.swift:630`

```swift
private func currentHighSchoolNotice() -> HighSchoolNotice? {
    …
    if !career.pendingGains.isEmpty { return .growth }   // 국면과 무관하게 계속 참
```
`pendingGains`는 `acknowledgeGains()`(카드의 "닫기")로만 비워진다(`Application/HighSchoolCareerStore+ProLegacy.swift:277`).

### 고칠 것
성장 카드는 **훈련 결과를 보여 주는 자리**이므로 그 국면에서만 유효하다. 둘 중 하나:

- (권장) `currentHighSchoolNotice()`에서 `.growth`를 국면으로 제한한다 — 예: `if !career.pendingGains.isEmpty, career.state?.phase == .training { return .growth }`
- 또는 국면이 바뀔 때 스토어가 `pendingGains`를 비운다(단, 훈련 → 각성처럼 바로 넘어가는 흐름에서 카드를 볼 기회 자체가 사라지지 않는지 확인할 것)

프로 쪽도 같은 구조다(`Application/MobileCareerStore+Season.swift:370`) — 같이 볼 것.

### 완료 조건
훈련 → 각성 → 정규 경기로 넘어가면 성장 카드가 사라진다. 훈련 직후에는 여전히 보인다.

---

## F-10 / G-02 [P2] 고정 글자 크기 4곳 — `check:design-system` 실패

```
apps/ios/Sources/Presentation/ProCareerPresentation.swift:1696   .font(.system(size: 9).monospacedDigit())   // 성장 그래프 시즌 축
apps/ios/Sources/Presentation/ProCareerPresentation.swift:1752   .font(.system(size: 8))                     // 눈금 의미 라벨
apps/ios/Sources/Presentation/CareerShareCard.swift:197          .font(.system(size: 7, weight: .semibold))
apps/ios/Sources/Presentation/CareerShareCard.swift:200          .font(.system(size: 9, weight: .semibold).monospacedDigit())
```

2026-09-10 이식 커밋(`c4d17576`, `e7b19291`)에서 들어왔고 그때부터 게이트가 빨갛다.
검사 규칙은 `tools/check-design-system.mjs:90` — `.system(size: <숫자>)` 형태만 잡고 `13 * scale`처럼 배율을 곱한 값은 통과시킨다(Canvas 장면 좌표계라 Dynamic Type 대상이 아니라는 판단).

### 고칠 것
- **`ProCareerPresentation.swift`(성장 그래프)**: 화면에서 읽는 글자다. `BaseballType.annotation` 등 Dynamic Type 토큰으로 바꾼다. 축 라벨이 커져 겹치면 표시 개수를 줄이거나(격 시즌만) 회전시킨다.
- **`CareerShareCard.swift`(공유 카드)**: 고정 크기 캔버스에 굽는 이미지라 Dynamic Type 대상이 아니다. 두 가지 중 하나 —
  - 캔버스 스케일을 곱한 형태(`7 * scale`)로 바꿔 검사기를 통과시키거나,
  - `tools/check-design-system.mjs`에 `CareerShareCard.swift`를 명시적 예외로 추가한다(같은 파일이 `.font(.footnote` 예외로 이미 등록돼 있다). **예외를 추가한다면 왜 예외인지 주석으로 남긴다.**

### 완료 조건
`npm run check:design-system` 통과 + 기록 탭 성장 그래프를 접근성 글자 크기로 열어 축 라벨이 읽히는지 확인.

---

## F-11 [P2] 영어 `Movement`가 두 개념을 동시에 가리킨다

능력 "변화구"와 구종 지표 "움직임"이 **영어에서 둘 다 `Movement`**라 투구 화면에 다른 숫자 두 개가 같은 이름으로 뜬다.

| 키 | ko | 현재 en | 제안 en |
|---|---|---|---|
| `setup.stat.movement` | 변화구 | Movement | Breaking |
| `record.ability.movement` | 변화구 | Movement | Breaking |
| `pro.summary.movement` | 변화구 | Movement | Breaking |
| `pro.offseason.investment.focus.movement` | 변화구 | Movement | Breaking |
| `pitch.build.metric.movement` | 움직임 | Movement | **Movement (그대로)** |

`legacy.mastery.family.breaking`이 이미 `Breaking ball`을 쓰고 있어 용어가 이어진다.
**이건 출시된 언어의 용어 변경이라 제품 판단이 필요하다.** 확신이 없으면 F-03-d(일본어 쪽 `変化球`/`変化量` 분리)만 하고 영어는 별도 결정으로 미룬다.

---

## F-12 [P2] 국면이 바뀌어도 스크롤 위치가 유지된다

경기 시작 화면은 스크롤 100%, 드래프트 결과는 82% 지점에서 열려 **국면 제목과 키아트를 지나친 채** 보인다. 사용자는 화면 중간부터 읽기 시작한다.

`HighSchoolCareerView.swift:548`에 `.id("\(state.careerID)|\(state.phase.rawValue)")`로 국면마다 스크롤 정체성을 새로 주는 장치가 이미 있는데 실제로는 위치가 남는다. 드래프트처럼 같은 국면 안에서 단계(`draftLegacyStep`)만 바뀌는 경우도 있다.

### 고칠 것
`.id(...)`에 단계까지 넣거나(`|\(draftLegacyStep)`), 국면 전환 시 `ScrollViewReader`로 맨 위 앵커로 보낸다. 이미 `Self.phaseAnchor`가 있다(선언 `HighSchoolCareerView.swift:261`, 부착 `:395`·`:404`).

### 완료 조건
훈련 → 경기 → 장 리뷰 → 드래프트로 넘어갈 때마다 새 화면이 **맨 위부터** 보인다.

---

## F-13 [P3] 잔가지 카피 4건

| # | 내용 | 위치 |
|---|---|---|
| a | 피로 1에서도 미터 라벨이 "피로 영향"이라고 말한다(실제 차이 5ms). `loop.meter.tired`가 `fatigue > 0` 전부에 걸린다 | `Features/Pitch/DeliveryControl.swift:111` — 문턱을 두거나(예: 20 이상) 단계 표현으로 |
| b | 선수 만들기 1단계가 같은 말을 네 줄로 한다: 제목 "선수의 이름을 정하세요" / 부제 "이 투수의 이름을 정하세요" / 설명 "고교 3년 동안 이 이름으로 불립니다." / 캡션 "이 이름이 3년 동안 이 구장에서 불립니다." | 부제와 캡션 중 하나씩 지운다 |
| c | 드래프트 결과 화면에 "카드 공유"(`share.card.action`)와 "선수 카드 공유"(`conclusion.life-card.share`)가 위아래로 붙어 있어 차이를 알 수 없다 | 무엇이 다른지 드러나게 이름을 가른다 |
| d | 와인드업 버튼의 접근성 라벨("와인드업")과 화면 문구("누르고, 초록에서 놓기")가 다르다 | `Features/Pitch/DeliveryControl.swift` — 라벨을 화면 문구에 맞춘다 |

추가(낮음): 리그 순위표 행 접근성 라벨에 승차(GB) 값이 빠져 있다(`RecordView.swift`).
그리고 미지명 화면 배경은 `ClimaxViews.swift:62`에서 **의도적으로 88% 어둡게** 덮는다 — 버그가 아니다. 실기기 야외 밝기에서 거의 검은 화면이 되므로 `dim`을 0.75 정도로 완화하는 것만 검토한다.

---

## G-01 [게이트] `check:copy` 실패 5건 — 전부 주석 오탐

```
apps/ios/Sources/Application/HighSchoolCareerStore+Rebirth.swift:441 — 도전 런
apps/ios/Sources/Features/HighSchool/HighSchoolDraftLegacyViews.swift:687 — 도전 런
apps/ios/Sources/Features/HighSchool/HighSchoolDraftLegacyViews.swift:692 — 이번 생
packages/simulation-core/Sources/SimulationCore/PitchKernelEngine.swift:1289 — 무브먼트
packages/simulation-core/Sources/SimulationCore/ProCareerModels.swift:560 — 무브먼트
```

다섯 줄 모두 **`///` 또는 `//` 주석**이다. 플레이어에게 보이지 않는다.

### 고칠 것 (권장)
`tools/check-copy.mjs:137~140`의 줄 스캔에서 주석 줄을 건너뛴다(`blockedWorldTerms` 루프는 `:143`).

```js
const isComment = (line) => {
  const t = line.trim();
  return t.startsWith("//") || t.startsWith("*") || t.startsWith("/*");
};
…
lines.forEach((line, index) => {
  if (isComment(line)) return;
  if (line.includes(blocked)) failures.push(…);
});
```

`blockedWorldTerms`(실존 야구 IP) 검사에는 이 예외를 적용하지 않는 편이 안전하다 — 주석에도 실존 구단명을 적지 않는 것이 규칙이다.

**대안:** 주석 다섯 줄의 표현을 바꾼다(검사기는 그대로). 더 빠르지만 같은 일이 또 생긴다.

### 완료 조건
`npm run check:copy` 통과. 그리고 **일부러 플레이어 문구에 금지어를 넣어 보고 여전히 잡히는지** 확인한 뒤 되돌린다.

---

## G-03 [게이트] 단위 테스트 실패 10건 — 전부 낡은 기대값

`xcodebuild test -only-testing:BaseballIOSTests` → 632개 중 10개 실패. **제품 회귀는 없다.** 하나씩 확인한 결과는 아래와 같다.

### G-03-a. `LocalizationCoverageTests` 5개 — 기대 배열이 밀렸다

`apps/ios/Tests/LocalizationCoverageTests.swift:1702` `expectedKorean` — 고칠 줄은 `:1706`(batterSide)과 `:1707`(pitchOutcome)

```swift
(.batterSide, ["우타", "좌타", "우타"]),          // 세 번째는 "양타"(스위치 히터)가 맞다
(.pitchOutcome, ["볼", "루킹 스트라이크", "헛스윙", "파울", "인플레이 아웃",
                 "안타", "2루타", "3루타", "홈런", "몸에 맞는 공"]),   // 10개 — 실제 enum은 11개
```

Phase 2가 `PitchOutcome.reachedOnError`("실책 출루")를 추가하면서 기대 배열이 한 칸씩 밀렸다. **카탈로그가 맞고 테스트가 틀렸다.** `CopyToken.closedEnumDescriptors`의 실제 순서를 확인해 `실책 출루`를 올바른 자리에 넣고 `양타`로 고친다.

나머지 실패 키(같은 파일):
- `:541` `setup.inheritance.shop.description`, `setup.handicap.description` — 카피를 바꾼 뒤 잠금값이 안 따라왔다
- `:1799` `prologue.inherited-start.source.soul` — 현재 카탈로그 "야구혼과 지난 생의 기억", 기대 "야구혼과 이전 선수의 기억"
- `:1224` `testImportantGameCatalog…` — 키 개수 31 vs 기대값 불일치
- `:2434` `chapter.review.claim-game` — 새 키가 기대 목록에 없다

모두 **카탈로그의 현재 값을 정답으로 보고 기대값을 갱신**한다(§0.1의 잠금 키군이 아닌지 먼저 확인할 것).

### G-03-b. `CopyCallerContractTests` + `SabermetricsSurfaceTests` 2개 — 같은 원인

`Features/Pro` 아래 파일은 `resolve`에 인자를 직접 넘기면 안 된다는 계약을 어겼다.

```swift
// apps/ios/Sources/Features/Pro/ProSeasonSettlementView.swift:63
subtitle: copyResolver.resolve(
    .seasonComparisonSeasons,
    arguments: [.integer(comparison.previousLabel), .integer(comparison.currentLabel)]
),
```

`apps/ios/Sources/Presentation/ProFeatureCopy.swift:7`의 `enum ProSeasonSettlementCopy`에 헬퍼를 하나 더해 옮긴다(같은 파일 `:9`의 `title(arcTitleID:season:resolver:)`이 본보기다).

```swift
static func seasonComparisonSubtitle(previous: Int, current: Int, resolver: GameCopyResolver) -> String {
    resolver.resolve(.seasonComparisonSeasons, arguments: [.integer(previous), .integer(current)])
}
```

### G-03-c. `RetentionTests` 2개 — 테스트가 인자를 빠뜨렸다

`testCareerStartUsesAutomaticSoulRatherThanLargerProWallet`(:1498), `testChallengeRunIgnoresEquippedSignatureLegacyAndItsAnalytics`(:229).

테스트는 기대값을 `HighSchoolCareerEngine().start(...)`를 직접 불러 만드는데 **`completedLives`를 넘기지 않는다.** 커널은

```swift
// HighSchoolCareer.swift:351
let completed = min(params.completedLives ?? (params.lifeNumber - 1), params.lifeNumber - 1)
pitcher = HighSchoolRebirthGrowthRules.apply(pitcher, completedLives: max(0, completed))
```

로 폴백해 1생 완주 보너스(+3)를 얹는다. 스토어는 실제 아카이브가 비어 있으므로 `completedLives: 0`을 넘긴다(`Application/HighSchoolCareerStore+Lifecycle.swift:519`). **스토어가 맞다.** 테스트의 기대값 생성 호출에 `completedLives: 0`을 넣어 맞춘다.

### G-03-d. `ScopedPresentationLocalizationTests` 1개

`:172`, `:177` — 당락선 기대값 66, 실제 50. 고교 규칙 8·9의 의도된 밸런스 변경이다. 기대값을 50으로 갱신한다.

### 완료 조건
`xcodebuild test -only-testing:BaseballIOSTests`가 **0 실패**. 반드시 다른 시뮬레이터 작업과 겹치지 않게 단독으로 돌린다.

---

## 2. 참고 — 손대지 않아도 되는 것 (QA에서 확인 완료)

- 저장 게이트 교착은 고쳐져 있다(`MobileCareerStore+Persistence.swift:187`이 빌드 상수와 비교). 8/30 "저장공간" 리뷰의 원인이었다
- 투구 슬라이더가 기본값이다(`PitchControlPreferences.defaultAutoRelease = false`) — `AGENTS.md` 불변 규칙 충족
- ko/en/ja 2,119키 전부 번역돼 있고 앱 이름도 세 언어로 현지화돼 번들에 들어 있다
- `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption=false` 준비됨. 알림 권한은 설정에서 켤 때만 요청한다
- 앱 소스에 `fatalError`/`try!`가 없고 강제 언랩은 오디오 렌더 콜백 12곳뿐
- 은퇴 화면의 "시즌 1"은 픽스처가 8시즌 합계를 한 줄에 담기 때문이다(`ProRetirementViews.swift:333`이 `careerStats.count`를 쓴다). 제품 문제가 아니다

### 테스트 위생 (별건, 급하지 않음)
- 단위 테스트가 실제 `NSUbiquitousKeyValueStore`에 테스트마다 새 키를 써서 1024키 한도를 넘긴다(`Exceeded maximum number of keys (1024)` 한 번 실행에 52회). 제품은 고정 키 5개라 안전하지만, 한도에 걸린 뒤의 저장 검사는 의미가 없다 → 테스트용 스토어를 주입하거나 `tearDown`에서 키를 지운다
- 테스트가 실제 Amplitude로 이벤트를 쏴서 429를 받는다 → 테스트에서는 이벤트 싱크를 끈다
