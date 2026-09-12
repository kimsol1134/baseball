# iOS 출시까지 남은 일 · 2026-09-12

2026-09-12 페르소나 QA(`docs/IOS_PERSONA_QA_2026-09-12.md`)에서 나온 지적은
`docs/IOS_QA_FIXES_2026-09-12.md`대로 고쳐 커밋 `ef14a238`·`333a4994`에 담았다.
이 문서는 **그 뒤에 남은 것**만 적는다. 고친 내용은 위 두 문서에 있다.

지금 상태: 게이트 넷(`check:ios-localization` · `check:copy` · `check:design-system` ·
`check:real-names`) 전부 통과, 단위 테스트 632개 전부 통과.

---

## 1. 출시 전에 해야 하는 것

### 1-1. 실기기 확인 — **아직 한 번도 안 했다**

이번 QA는 전부 iPhone 17 시뮬레이터다. 기기에서 다시 봐야 하는 것:

- **햅틱.** 투구 미터의 가장자리·퍼펙트 릴리스 햅틱은 시뮬레이터에서 검증되지 않는다. 이 게임의 손맛이 걸린 부분이다
- **오디오 지연.** 심판 콜이 공보다 먼저 나오지 않는지(`PitchFeedbackTimeline`이 삼진 콜을 0.2초 선행시킨다)
- **야외 밝기.** 미지명 화면은 `ClimaxViews.swift:62`에서 배경을 88% 어둡게 덮는다. 의도된 연출이지만 실기기 햇빛 아래에서 거의 검은 화면이면 `dim`을 0.75쯤으로 완화할지 판단한다
- **일본어 실기기 스모크.** `AGENTS.md`가 ASC 제출 조건으로 못 박은 항목이다. 앱 이름·시스템 문구·언어 판별 경로가 서명된 IPA에서 실제로 일본어로 뜨는지 확인하고 대상 버전·빌드와 함께 증거를 남긴다

### 1-2. 서명 IPA 현지화 검사

`AGENTS.md` 규칙: 심사 제출 전에 **서명된 IPA**의 `ja.lproj`·문자열 카탈로그·앱 이름을 검사하고,
App Store의 지원 언어에 `Japanese`가 뜨는지 대상 버전 기준으로 확인한다.
(현재 Debug 번들에는 ko/en/ja `InfoPlist.strings`와 `Localizable.strings`가 모두 들어 있는 것을 확인했다.)

### 1-3. 일본어 카피 사람 검수

기계번역 흔적은 걷어냈지만(단위·의뢰문·직역·용어·공백 잔존 0건), **일본어 화자의 읽기 검수는 받지 않았다.**
특히 대사·이벤트 문장 2,151개는 자동 검사로 잡히지 않는 어색함이 남아 있을 수 있다.
최소한 첫 회차 동선(오프닝 → 첫 불펜 → 선수 만들기 → 훈련 → 첫 경기 → 장 리뷰)의 문장만이라도 검수를 권한다.

---

## 2. 남은 결함

### 2-1. 알럿 확인 버튼이 접근성 트리에 두 번 잡힌다 (F-08, **미해결**)

알럿의 `Button`에 `accessibilityIdentifier`를 붙이면 같은 프레임의 요소가 2개가 된다
(식별자 없는 취소 버튼은 1개). VoiceOver가 같은 버튼을 두 번 읽는다.

시도해 본 것과 결과:

| 시도 | 결과 |
|---|---|
| `accessibilityElement(children: .combine)` 추가 | 여전히 2개 |
| 식별자를 `label:` 안쪽 뷰로 이동 | `app.buttons.matching(identifier:)`가 못 찾아 UI 테스트가 깨진다 |

대상 11곳(`PitchView:351`, `ProRetirementViews:36,233`, `ProImportantGameIntro:111`,
`ProOffseasonViews:144`, `ProOffseasonInvestmentView:85`, `SettingsView:213`,
`HighSchoolAwakeningViews:119`, `HighSchoolDraftLegacyViews:659,1026`, `HighSchoolTrainingViews:114`).
자동화는 `.firstMatch`로 견디고 있어 식별자를 유지했고, 코드에 제약으로 주석을 남겼다.

**다음에 시도할 것:** SwiftUI `alert` 대신 커스텀 확인 시트로 바꾸면 풀릴 가능성이 있다.
다만 iOS 26에서 `confirmationDialog`는 팝오버로 떠 취소가 안 보이는 문제가 있으니(기존 메모) 알럿을 유지한 채로는 방법이 없어 보인다.

### 2-2. 국면 전환 자동 스크롤이 제목과 키아트를 건너뛴다 (F-12, **의도된 동작**)

국면이 바뀌면 `proxy.scrollTo(Self.phaseAnchor, anchor: .top)`으로 새 국면 본문을 화면 맨 위로 올린다
(`HighSchoolCareerView.swift:620` 부근). 3차 패널의 "게임의 최다 보상이 화면 밖에서 소비된다"를
고치며 넣은 동작이라 이번에 되돌리지 않았다.

부작용은 남아 있다 — 경기 시작 화면과 드래프트 결과에 들어가면 **국면 제목과 키아트를 지나친 채**
중간부터 보인다. 바꾸려면 "보상을 바로 보여 준다"와 "무대를 먼저 보여 준다" 중 하나를 고르는
제품 판단이 필요하다.

---

## 3. 검증하지 못한 것

### 3-1. 프로 2시즌 이상 정규 주행

프로 후반부는 픽스처로만 열었는데 **픽스처의 시즌 데이터가 비어 있다**(0경기 0이닝).
그래서 다음 화면들을 **수치가 든 상태로 한 번도 보지 못했다**:

- 기록 탭 **세이버메트릭스 표**(IP·RA9·FIP·K%·BB%·WHIP·WAR)
- **능력 성장 그래프**(이번에 축 라벨을 Dynamic Type으로 바꿨다 — 글자가 커진 상태에서 겹치지 않는지 확인 필요)
- **앨범·궤적 재생**
- 시즌 비교 카드의 **ERA(평균자책)**

세이버 표는 셀 폭이 고정이다(`RecordView.swift:585~592`, 44~64pt). 접근성 글자 크기에서
값이 잘릴 가능성이 높다 — 가로 스크롤 안에 있어 넘치지는 않지만 셀 안에서 잘린다.

**하는 법:** 프로 시즌을 실제로 몇 주 진행해 `seasonLog`를 채운 뒤 기록 탭을 연다.
또는 시즌 로그가 든 픽스처를 새로 만든다(현재 `-uiTestSeasonReviewFixture`·`-uiTestRetiredShareFixture`
둘 다 경기 줄이 없다).

### 3-2. 접근성 글자 크기 — 투구 화면 밖

이번에 고친 것은 투구 화면이다. 같은 크기에서 확인하지 않은 화면:

- 기록 탭(세이버 표·순위표·앨범)
- 프로 주간 계획·시즌 결정·계약
- 유산·환생

### 3-3. `QACaptureUITests`

기준선에서도 끝나지 않는 알려진 문제라 이번에도 돌리지 않았다. 게이트로 쓰지 않는다.

---

## 4. 개선 제안 (결함은 아님)

| # | 내용 | 근거 |
|---|---|---|
| 4-1 | **통산·시즌 합계에 ERA를 더한다.** ERA는 시즌 비교 카드에만 있다(`ProSeasonComparison.swift:37`). 기록 탭 세이버 표·은퇴 화면·공유 카드는 전부 RA9다. 자책점 원장이 이미 저장되므로 데이터는 있다 | QA F-05 |
| 4-2 | 일본어 산문에서 `움직임`을 「動き」·「キレ」로 옮기는데 지표 라벨은 「変化量」이다. 뜻은 통하지만 라벨과 문장이 다른 말을 쓴다 | 6개 키 |
| 4-3 | 리그 순위표 행의 접근성 라벨에 **승차(GB)** 값이 빠져 있다 | `RecordView.swift` |
| 4-4 | 접근성 글자 크기에서 스코어보드의 `피로` 라벨이 「疲」/「労」 두 줄로 쪼개진다. 읽히긴 하지만 보기 나쁘다 | 일본어 AX3 |
| 4-5 | 미지명 화면 `dim` 0.88 완화 검토 (§1-1) | `ClimaxViews.swift:62` |

---

## 5. 테스트·개발 환경 위생

### 5-1. 단위 테스트가 실제 iCloud 키-값 저장소를 쓴다

`Exceeded maximum number of keys (1024) in store (D48DDX5D5W.com.solkim.baseball.ios)` —
한 번 실행에 52회 찍힌다. 테스트마다 `SaveSync(key: "…-\(UUID())")`로 새 키를 만들어
실제 `NSUbiquitousKeyValueStore`에 쓰기 때문이다. **제품은 고정 키 5개라 안전하다**
(`baseball-mobile-highschool-v1.json` 등). 다만 한도에 걸린 뒤로는 저장 검사가 의미를 잃는다.

→ 테스트용 스토어를 주입하거나 `tearDown`에서 키를 지운다.

### 5-2. 테스트가 실제 Amplitude로 이벤트를 쏜다

429(rate limit)를 받는다. `AnalyticsContext`가 Debug를 `distribution: debug`로 태깅하니
대시보드에서 거를 수는 있지만, 테스트에서는 이벤트 싱크를 끄는 편이 낫다.

### 5-3. 전체 스위트는 메모리를 크게 먹는다

20시즌 밸런스 테스트가 도는 동안 시뮬레이터가 1.6GB까지 올라간다. Unity 에디터·Android
에뮬레이터가 같이 떠 있으면 **48GB 기기에서도 스왑이 50GB까지 차서 페이지 스래싱**이 온다.
그 상태에서는 `RealPlayDraftRateTests.testSkillLadderOnBothCurves`가 결과를 못 내고
"Failing tests"에 오른다 — **코드 문제가 아니다**. 메모리가 정상일 때 단독 실행하면 128.4초에 통과한다.

돌리기 전에 무거운 에디터·에뮬레이터를 닫고, `sysctl vm.swapusage`·`memory_pressure`로
같이 지켜본다. 그리고 **런을 중간에 끊고 바로 다시 시작하지 않는다** — 끊긴 런이 시뮬레이터를
눌러 다음 런의 같은 테스트가 멈춘다.

---

## 6. 다음 사람이 재현하는 법

```bash
U=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF   # iPhone 17

# 빌드·설치
xcodebuild -project apps/ios/Baseball.xcodeproj -scheme BaseballIOS -configuration Debug \
  -destination "platform=iOS Simulator,id=$U" build
xcrun simctl install $U <DerivedData>/Build/Products/Debug-iphonesimulator/BaseballIOS.app

# 새 회차 (픽스처는 -uiTestResetCareer 와 같이 줘야 적용된다)
xcrun simctl launch $U com.solkim.baseball.ios -uiTestResetCareer
xcrun simctl launch $U com.solkim.baseball.ios -uiTestResetCareer -uiTestUndraftedCareerFixture

# 슬라이더 투구: 홀드 = sweepSeconds / 2
#   sweepSeconds = 1.18 − (기준구속tenths − 1100)/400 × 0.38 − 피로/100 × 0.24
axe touch -x 201 -y 778 --down --up --delay 0.44 --udid $U

# 일본어 + 접근성 글자
xcrun simctl ui $U content_size accessibility-extra-large
xcrun simctl launch $U com.solkim.baseball.ios -AppleLanguages "(ja)" -AppleLocale ja_JP -uiTestResetCareer
xcrun simctl ui $U content_size large    # 끝나면 되돌린다
```

증거 스크린샷은 `apps/ios/releases/qa-1.2.9/personas-0912/`(QA)와 `.../fixes-0912/`(수정 확인)에 있다(gitignore).
