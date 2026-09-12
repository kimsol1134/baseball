# iOS 출시까지 남은 일 · 2026-09-12

> 배포 준비 후속: ASC 직접 조회 결과 1.2.9 (67)은 이미 판매 중이었다. 이번 수정의 배포 대상은
> **1.2.10 (68)**이다. 서명 IPA·Apple 서버 검증·스토어 메타데이터 준비 상태는
> [1.2.10 배포 증거](IOS_1_2_10_RELEASE_EVIDENCE_2026-09-12.md)에 기록한다.

2026-09-12 페르소나 QA(`docs/IOS_PERSONA_QA_2026-09-12.md`)에서 나온 지적은
`docs/IOS_QA_FIXES_2026-09-12.md`대로 고쳐 커밋 `ef14a238`·`333a4994`에 담았다.
이 문서는 후속 작업의 원본이다. 아래에는 9월 12일 추가 검증 결과와 아직 남은 항목을 함께 기록한다.

기준선은 게이트 넷과 단위 테스트 632개 통과였다. 후속 변경의 정적 게이트 넷은 통과했고,
관련 테스트 26개는 먼저 통과했다. **최종 전체 단위 테스트는 639개 통과, 실패·건너뜀 0개**다.
실제 테스트 시간 802.567초, `xcresult`와 `TEST EXECUTE SUCCEEDED` 확인. 실기기·사람 일본어 검수·ASC 제출은 이번 작업 범위에 포함하지 않았다.

---

## 1. 출시 전에 해야 하는 것

### 1-1. 실기기 확인 — **이번 수정본에서 미완료**

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

### 2-3. 즉시 숫자 효과가 없는 결정 요약의 끝 구분자 — **미수정 · 경미**

새 구종을 불펜에서만 연습하는 선택을 확정하면 결과 배너가 `선택 제목 —`로 끝난다.
효과 문자열이 비어 있는데 세 인자 요약 템플릿이 구분자를 남기기 때문이다.
겹치는 닫기 버튼은 수정했지만 이 끝 구분자는 남아 있다. 선택 결과·성장 수치는 별도 결과 카드에서
정상 확인된다. 근거: `ja-ax-decision-banner-final.png`.

---

## 3. 후속 검증 결과

### 3-1. 수치가 든 프로 후반부 — **엔진 진행 픽스처로 검증**

Debug 인자 `-uiTestPopulatedProFixture`를 추가했다. 시드 `20260912`, 배포와 같은
`AppFeatureConfiguration.production.proCareerJourneyV1` 설정으로 계약·주간 훈련·시즌 결정·
직접 등판·시즌 결산·오프시즌을 진행하고 **3시즌 리뷰 직전**에 멈춘다. 직접 등판은
`PitchSession`과 투구 커널을 끝까지 실행한다. 커널 소스·확률식·규칙 버전·난수 소비 순서는 수정하지 않았다.

| 시즌 | 경기 | 이닝 | 탈삼진 | 볼넷 | 실점 | 자책점 | ERA |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 29 | 143.1 | 75 | 47 | 37 | 34 | 2.13 |
| 2 | 26 | 123.2 | 65 | 34 | 42 | 41 | 2.98 |
| 3 | 29 | 140.1 | 82 | 39 | 48 | 46 | 2.95 |
| 합계 | 84 | 407.1 | 222 | 120 | 127 | 121 | 2.67 |

3시즌 경기 로그 29개, 성장 이력 3점, 저장 궤적 54개. `fixture-summary.json`으로 기록했다.
단위 검사로 현 시즌 로그의 아웃·실점 합계와 `currentStats` 일치, 과거 시즌의 자책점 원장,
성장 이력·앨범 존재, 실제 `reviewSeason` 정산 성공을 확인한다.

**발견하고 수정한 표시 문제:**

- 세이버 표에서 `112.1`, `4.33`, `11.8%` 같은 값이 접근성 크기에서 여러 줄로 갈라졌다.
  고정 폭 HStack을 열 너비를 함께 계산하는 `Grid`로 바꿨다. 값·헤더는 한 줄을 유지하고
  가로 스크롤로 ERA·RA9·FIP·K%·BB%·WHIP·WAR까지 읽는다.
- 성장 그래프의 축 이름 말줄임, 시즌 번호의 높이 부족, 범례 `+22`의 줄바꿈을 확인했다.
  접근성 크기는 숫자 축과 바로 아래 뜻풀이, 한 열 범례를 쓴다. 축·시즌 간격을 글자 크기에
  맞추고 긴 이력에는 가로 스크롤을 제공한다. 영어 기본 크기의 `Generational peak` 잘림도 수정했다.
- 일반 지표의 이닝과 은퇴 통산 숫자, 시즌 비교의 K/9·이닝 값이 잘렸다.
  접근성 크기에서 숫자 타일과 비교 행을 세로로 배치했다. ERA 비교 `2.98 → 2.95`도 실제 수치로 확인했다.
- 사용자의 추가 피드백에 따라 **다시 보는 공**을 다시 구성했다. 대표 장면 하나에 결과·구종·
  단위가 있는 구속·포수 시점의 존·공 위치·재생 버튼을 표시하고, 최근 나머지 5개는 접힌 목록으로 둔다.
  저장 궤적의 판정 좌표를 존 좌표에 맞춰 투영하며, 자동 재생 대신 버튼으로 재생한다.
  Reduce Motion에서는 정지 위치를 보여 준다. 재생 전후 프로 세이브 SHA-256이 같음을 확인했다. 동영상의 중간 프레임으로 공 이동도 확인했다.

한국어 기본 크기와 한국어·일본어 접근성 크기에서 그래프·표·앨범을 눈으로 확인했다.
영어도 기록 탭이 열리는지 확인했다. **사람이 UI로 두 시즌을 정규 주행했다는 뜻은 아니다.**
기존 `-uiTestSeasonReviewFixture` / `-uiTestRetiredShareFixture`는 호환을 위해 그대로 두었다.

### 3-2. 접근성 글자 크기 — **진행 동선 확인 및 수정**

iPhone 17 / iOS 26.5, `content_size accessibility-extra-large`에서 확인했다.

| 화면 | 결과 |
|---|---|
| 기록 탭 | 채워진 표·성장·앨범 확인. 순위표는 팀 이름과 성적을 두 줄로 분리, 투수 순위는 큰 글씨용 메뉴 정렬 및 행 재배치 |
| 프로 주간 계획 | 계획 안내·효과 칩·선택 동선 확인. 긴 칩이 카드 밖으로 나오는 문제를 공통 `FlowLayout`/`EffectChip`에서 수정 |
| 시즌 결정 | 후보를 선택하고 확정해 결과 화면 도달. 긴 효과 칩의 말줄임/넘침 수정. 결과 배너의 닫기 버튼이 글과 겹치는 문제도 발견해 별도 공간 확보 |
| 계약 | 갱신 제안의 기간·연봉·역할·보장액 및 확인 화면 확인. 오퍼를 실제 수락해 다음 국면으로 진행 |
| 유산 | 구규칙 기억 카드 제목 잘림을 수정. 현 규칙 대표 유산의 후보·근거·효과를 확인하고 선택·확정 |
| 환생 | 2회차 준비 화면의 제목·계승 유산·학교 선택·연습 버튼이 읽히고 접근 가능한지 확인 |
| 고교 결과 공통 능력 표시 | 3열 구속/제구/체력과 2열 성장 막대를 접근성 크기에서 세로로 배치 |
| 직접 투구 | 피로를 별도 행으로 배치해 일본어 `疲労`와 주자 상황을 모두 읽게 했다. 기본 수동 슬라이더로 커브 1구를 던져 스트라이크·1P·피로 2 반영 확인 |

화면 밖으로 스크롤되는 본문이나 장식 키아트의 프레임을 결함으로 계산하지 않았다.
큰 글씨에서는 정보가 더 많은 세로 공간을 사용한다. 종료 시 시스템 글자 크기를 `large`로 복원했다.

### 3-3. 새로 발견한 결함

| 항목 | 결과·원인 |
|---|---|
| **영어·일본어 프로 기록 탭 크래시** | `content.pro-milestone.season-role`이 `%1$lld`와 `%@`를 혼용해 Foundation이 정수를 객체 주소로 읽었다. 실제 일본어 크래시 스택 확인. 3언어를 완전한 위치 지정자로 고치고, Resolver에서 혼용을 차단. 주입기와 릴리스 게이트도 실제 `.xcstrings`를 검사하도록 보강 |
| **동명이인 투수 순위 충돌** | 코어 `PitcherRow.id`가 이름뿐이라 동일 이름의 행이 충돌했다. 코어를 바꾸지 않고 표시 순위로 행과 순위를 식별 |
| **은퇴 회고 `Text unavailable`** | 주간 성장·직접 등판의 구문 매핑이 없었다. 성장량 및 상대·K/BB/실점 요약을 현지화. 주간 분위기 정규식도 전체 문장과 맞게 수정 |
| **세이버 설명의 사실 오류** | 원장이 있는데도 "자책점을 따로 세지 않는다"고 적혀 있었다. RA9가 모든 실점을 세는 지표라는 설명으로 교체 |
| **일본어 은퇴/시즌 표기** | `退職しました`, `季節`을 해당 화면에서 `引退`, `シーズン`으로 수정. 사람 읽기 검수를 완료했다고 주장하지 않는다 |

### 3-4. `QACaptureUITests`

기준선에서도 끝나지 않는 알려진 문제다. **실행하지 않았고 게이트로 쓰지 않았다.**

---

## 4. 개선 제안 처리

| # | 결과 |
|---|---|
| 4-1 | **처리.** 세이버 표의 시즌·통산 및 은퇴 통산에 ERA 추가. 원장이 하나라도 없거나 0이닝이면 `—`. 가중 평균을 아웃 합계로 계산하고 완료 시즌 중복을 제외한다. 공유 카드의 상세 기록표에는 ERA가 이미 있었다 — 이 부분은 추가 누락으로 보지 않는다 |
| 4-2 | **처리.** 지표의 움직임을 뜻하는 일본어 산문 6키를 `変化量`으로 통일. 일반 동작을 묻는 대사의 `動き`까지 일괄 치환하지 않았다 |
| 4-3 | **처리.** 리그 행 접근성 라벨에 현지화된 승차 값 추가. 일본어 AX 트리에서 `ゲーム差` 확인 |
| 4-4 | **처리.** `疲労` 한 줄을 확보하되 주자 상황이 대신 잘리지 않게 접근성 스코어보드의 피로 행을 분리. 직접 투구 결과까지 눈으로 확인 |
| 4-5 | **보류.** `dim = 0.88` 유지. 실기기 야외 밝기 확인과 제품 판단은 사용자의 범위이며 시뮬레이터만으로 완화하지 않았다 |

---

## 5. 테스트·개발 환경 위생

### 5-1. iCloud KVS — **테스트 저장소 격리 구현**

`SaveSync`의 원격 저장소 기본 선택을 테스트 호스트에서 프로세스 내 메모리 저장소로 바꿨다.
동일 키를 다른 `SaveSync` 인스턴스로 복원해도 원격 복구 경로를 검증한다. 명시적으로 주입한
테스트 스토어는 그대로 사용한다. `prime`과 원격 변경 관찰도 실제 KVS를 만지지 않는다.
제품 실행은 기존 `NSUbiquitousKeyValueStore.default`를 사용한다. 기존 클라우드의 키를 일괄 삭제하지 않았다.

공유 Xcode 스킴과 `project.yml`의 테스트 환경에 `BASEBALL_TEST_ISOLATION=1`을 넣었다.
XCTest 환경변수도 인식한다. 실제 테스트 호스트에서 격리가 켜졌고, 로컬 파일을 없앤 뒤 다른
인스턴스로 메모리 거울에서 복원되는 것을 검사했다.

### 5-2. Amplitude/Firebase — **테스트 호스트 SDK 차단 구현**

같은 테스트 환경 판별로 `GameAnalytics.configure`의 SDK 초기화와 실제 `log` 전송을 차단한다.
`eventSinkForTesting`은 유지해 이벤트 계약 검사는 계속 동작한다. UI 테스트 인자 차단도 유지했다.

### 5-3. 스위트 메모리·실행 환경

`RealPlayDraftRateTests`는 회차 시뮬레이션마다 `autoreleasepool`을 비우도록 했다.
시드·표본 수·어서션·규칙 선택은 그대로다. 한 번에 테스트 런 하나만 실행했다.

**이번 전체 실행의 환경 제약:** Unity 정상 종료와 Android 종료를 요청했으나, Unity의 Firebase
설정 창과 임시 파일 오류 때문에 정상 종료가 완료되지 않았고 Android도 다른 작업에서 재실행됐다.
전체 실행 직전 프로세스 확인을 중단 조건으로 연결하지 못해 두 프로세스가 남은 채 런이 시작됐다.
사용자가 경고한 대로 테스트를 중간에 끊고 재시작하지 않았다. Android를 다시 종료하고 Unity 강제
종료는 미저장 변경 유실 가능성 때문에 사용자 확인을 요청했다. 이후 해당 Unity 프로세스는 외부 작업에서
종료됐고 새 에디터 프로세스가 실행됐다. 이 작업에서는 강제 종료하지 않았다.
**완전히 격리된 환경의 실행이라고 적지 않는다.**

재발 방지를 위해 `tools/test-ios-unit.sh`에 실행 전 프로세스 검사와 중복 실행 잠금을 추가했다.
Unity·Android 에뮬레이터·다른 xcodebuild가 있으면 **테스트를 시작하지 않고 종료**한다.
진행 중인 이번 런에서 이 거부 동작(종료 코드 2)을 실제 확인했다. 다음 전체 검증은 이 래퍼를 사용한다.

5초 간격 `memory_pressure`, `vm.swapusage`, 앱/Unity/에뮬레이터 RSS 기록은 `unit-memory.jsonl`에 있다.
최종 결과: **639/639 통과, 실패 0, 건너뜀 0**. `testSkillLadderOnBothCurves`는 122.561초에 통과했다.
테스트 앱 RSS의 5초 간격 관측 최고치는 **1,240MiB(약 1.21GiB)**, `memory_pressure`의 free 지표는
최저 80%였다. 스왑 사용량은 관측 시작 5,780MiB → 종료 5,532MiB였고 페이지 스래싱/중단은 관찰하지 않았다.
배경 작업이 달랐으므로 이전 실행 대비 성능 개선 비율은 주장하지 않는다.

전체 로그의 **iCloud 키 한도 초과 경고 0건, 429/rate-limit 오류 0건**.
Game Center 인증 등 시뮬레이터 환경 로그는 남아 있으며 테스트 어서션 실패로 세지 않았다.
MCP 호출은 300초 후 응답 시간 제한에 걸렸지만 `xcodebuild`는 살아 있었다. 중복 실행 없이 기존
프로세스와 로그를 추적하고, 완료된 원본 xcresult의 `test-results summary`로 결과를 확정했다.
증거: `unit-test-summary.json`, `unit-memory.jsonl`.

원본 결과 번들(24시간 보관 정책 적용):
`~/Library/Developer/XcodeBuildMCP/workspaces/baseball-dc28df04f978/result-bundles/test_sim_2026-09-12T05-48-07-368Z_pid91599_2c97a246.xcresult`

---

## 6. 다음 사람이 재현하는 법

```bash
U=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF   # iPhone 17

# 전체 단위 테스트는 무거운 앱/다른 Xcode 작업이 없어야 시작한다.
BASEBALL_SIMULATOR_ID="$U" tools/test-ios-unit.sh

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


## 7. 후속 작업 증거

후속 증거: `apps/ios/releases/qa-1.2.9/remaining-0912/` (gitignore).

- 원인: `ko-ax-growth-before.png`, `ko-ax-saber-before.png`, `ja-ax-decision-options.png`, `ja-ax-decision-applied.png`
- 기록/앨범: `ko-large-album-final.png`, `ko-large-growth-final.png`, `ko-large-saber-final.png`, `ja-ax-saber-final.png`
- 큰 글씨: `ja-ax-retired-era.png`, `ja-ax-pitcher-leaders.png`, `ja-ax-weekly-plan-card.png`, `ja-ax-decision-banner-final.png`, `ja-ax-growth.png`, `ja-ax-standings.png`, `ja-ax-decision-chip-final.png`, `ja-ax-comparison-final.png`
- 진행: `ja-ax-contract-confirm.png`, `ja-ax-contract-signed.png`, `ja-ax-legacy-final.png`, `ja-ax-legacy-alert.png`, `ja-ax-legacy-finalized.png`, `ja-ax-rebirth.png`
- 구규칙 기억 카드: `ja-ax-memory-title-final.png`, `ja-ax-highschool-stats-final.png`
- 재생: `album-replay-proof.mp4`, `replay-frame-2.9.png`, `ko-large-album-expanded.png`
- 기본 투구: `ja-ax-pitch-final.png`, `ja-ax-manual-pitch-result.png`
- 데이터: `fixture-summary.json`, `replay-save-integrity.json`, 카피 주입 JSON 배치들

추가 재현:

```bash
xcrun simctl launch "$U" com.solkim.baseball.ios -uiTestResetCareer -uiTestPopulatedProFixture
# 계약/주간 계획/결정/결산/은퇴: contract_offer, weekly_plan, season_decision, season_settlement, completed
xcrun simctl launch "$U" com.solkim.baseball.ios -uiTestResetCareer -uiTestPopulatedProFixture -uiTestProPhase season_settlement
# 기록 탭을 누르면 해당 섹션으로 이동: album, growth, saber, standings
xcrun simctl launch "$U" com.solkim.baseball.ios -uiTestResetCareer -uiTestPopulatedProFixture -uiTestRecordSection saber
# 대표 유산 화면. 드래프트 결과의 다음 행동을 누르면 유산 후보가 열린다.
xcrun simctl launch "$U" com.solkim.baseball.ios -uiTestResetCareer -uiTestRebornFixture -uiTestStopAtLegacy
```


## 8. 후속 커밋과 보관

- `d1bc4342` — 프로 후반 수치 픽스처, 기록/앨범/접근성 화면, 문자열 크래시 및 회고 표시 보완
- `ad57f8b0` — 테스트 저장소/분석 SDK 격리, 회차별 메모리 정리, 단독 실행 가드
- 문서 커밋 — 이 원본에 검증 결과·미수정 사항·환경 제약 기록

검증에만 쓰인 홍보 렌더 프레임 600장(약 201MiB)은 테스트 종료 및 열린 파일 없음 확인 후 정리했다.
QA 스크린샷·JSON 결과·카피 주입 배치는 보존했다. XcodeBuildMCP 테스트 제품 약 326MiB는 지정된
24시간 보관 정책에 맡겼으며 다른 임시 폴더로 복사하지 않았다.
