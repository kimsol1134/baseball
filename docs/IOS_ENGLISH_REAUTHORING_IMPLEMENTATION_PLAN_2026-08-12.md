# 영어권 iOS 동일 콘텐츠 재작성·배포 구현 계획

| 항목 | 값 |
|---|---|
| 문서 ID | `DOC-IOS-ENGLISH-REAUTHORING-2026-08-12` |
| 기준일 | 2026-08-12 KST |
| 상태 | 구현 승인 기준안 |
| 실행 주체 | 이 저장소를 수정하는 AI 에이전트 |
| 제품 범위 | 기존 iPhone용 iOS 앱 |
| 코드 범위 | `apps/ios`, `packages/simulation-core`, `tools`, `marketing/appstore`, iOS 지원·개인정보 페이지 |
| 배포 방식 | 기존 App Store 앱의 동일 bundle ID·동일 바이너리에 영어 추가 |
| 영어화 방식 | 문장별 직역이 아닌, 의미와 기능을 보존한 영어 완성 문장 재작성 |

이 문서는 한국어판과 **게임 내용이 완전히 같은 영어판**을 기존 iOS 앱에 추가하는 작업의
단일 실행 기준이다. 영어판은 다른 세계나 별도 게임이 아니다. 같은 선수, 같은 학교와 구단,
같은 사건, 같은 선택, 같은 결과를 영어로 자연스럽게 읽는 표시 계층이다.

코드와 이 문서가 충돌하면 현재 코드가 기술적 사실 원본이다. 다만 아래의 제품 결정과 콘텐츠
불변 조건은 임의로 축소하거나 변경하지 않는다. 구현 중 설계 변경이 필요하면 먼저 이 문서의
`결정 기록`에 이유, 호환성 영향, 대안을 남긴 뒤 진행한다.

> 이 계획은 현재 국제 확장 우선순위를 영어판으로 전환한다. 기존
> `docs/JAPANESE_IOS_IMPLEMENTATION_PLAN_2026-08-11.md`와 일본어 관련 작업 파일을 삭제하거나
> 되돌리라는 뜻은 아니다. 일본 별도 세계·별도 저장 구조는 이 영어판에 적용하지 않으며,
> 현재 작업 트리의 일본어 자산은 사용자 작업으로 간주해 보존한다.

---

## 1. 최종 제품 결정

### 1.1 앱과 배포 단위

- 새 앱과 새 App Store 레코드를 만들지 않는다.
- 기존 bundle ID `com.solkim.baseball.ios`를 유지한다.
- 기존 iPhone 전용 target, iOS 17 최소 버전, 앱 구매 1회 모델을 유지한다.
- 기존 한국어 앱에 `English` 앱 언어를 추가한 한 개의 바이너리를 배포한다.
- 기기 또는 iOS의 앱별 언어가 영어면 영어, 한국어면 한국어를 표시한다.
- 별도 인앱 언어 선택기는 1차 범위에 넣지 않는다. iOS가 제공하는 앱별 언어 설정을 사용한다.
- App Store의 기본 언어는 당장 바꾸지 않고 한국어를 유지한다. 영어 메타데이터를 별도
  현지화로 추가한다.
- 한국 App Store의 기존 앱 이력, 구매자, 리뷰, 세이브, Game Center ID, iCloud 계보를 유지한다.
- Android, Windows, Steam의 영어판은 이번 범위가 아니다.

### 1.2 "완전히 같은 내용"의 계약

언어에 따라 달라질 수 있는 것은 **표시 문구와 표시 형식뿐**이다.

| 반드시 동일 | 영어에서 다시 쓸 수 있음 |
|---|---|
| 콘텐츠 ID와 배열 순서 | 제목, 본문, 대사, 버튼 문장 |
| 사건 발생 조건과 확률 | 고유명사의 공식 영어 표기 |
| 선택지 수, 순서, 잠금 조건 | 영어 야구 용어와 문장 리듬 |
| 선택 효과, 성장치, 피로, 부상 위험 | 숫자·이닝·구속의 표시 형식 |
| RNG 소비 순서와 결정론 | 줄바꿈과 접근성용 완성 문장 |
| 경기 규칙과 판정 | 알림·공유 카드·스토어 문안 |
| 드래프트, 프로, 은퇴, 환생 규칙 | 영어권 독자가 이해하는 자연스러운 설명 |
| 학교·구단·감독·포수·라이벌의 정체성 | 같은 정체성의 로마자·영어 표시명 |
| 보상, 업적 조건, 주간 프로그램 | 영문 앱 이름과 마케팅 헤드라인 |
| 저장 키, iCloud 데이터, 분석 event name | `app_language`, copy version 분석 속성 |

다음은 금지한다.

- 영어 전용 사건, 선택지, 보상, 튜토리얼을 추가하는 것
- 한국어 콘텐츠를 영어에서 생략·통합·순서 변경하는 것
- 영어권에 낯설다는 이유로 군 복무, 고교 3년, 지역 문화 같은 기존 내용을 다른 제도로 바꾸는 것
- 같은 ID에 다른 효과나 수치를 붙이는 것
- 영어에서 난이도, 구속 임계값, 드래프트 확률, 시즌 길이를 조정하는 것
- 별도 영어 저장 슬롯 또는 영어 전용 커리어를 만드는 것
- 영어 화면에서 누락 문구를 한국어로 fallback하는 것

### 1.3 영어 재작성의 정의

이 작업은 단어·문장 단위 번역이 아니다. 한국어 원문이 맡는 **기능과 사실**을 먼저 추출하고,
그 계약을 영어 완성 문장으로 새로 쓴다.

영어 한 항목은 아래 다섯 요소를 원문과 동일하게 보존해야 한다.

1. 지금 무슨 일이 일어났는가.
2. 플레이어가 무엇을 선택하거나 알아야 하는가.
3. 선택의 비용·위험·보상이 무엇인가.
4. 결과가 확정인지 가능성인지.
5. 화자와 장면의 감정 온도가 어떤가.

금지 예시는 한국어 어순을 그대로 옮긴 문장, 명사를 연속해서 붙인 UI, 문장 조각을 영어
어순으로 조립한 결과다. 승인 가능한 영어는 의미 계약을 지키면서도 영어권 야구 게임에서
처음부터 작성된 것처럼 읽혀야 한다.

예시 원칙:

```text
한국어 기능: 첫 불펜 뒤, 포수가 각 구종을 언제 쓸지 플레이어에게 묻는다.
금지: After receiving the ball, the catcher asks when you want to use each pitch.
허용 방향: After your first bullpen, the catcher wants to know where each pitch fits in your game plan.
```

위 영어 문장은 최종 카피가 아니라 재작성 방식의 예시다.

### 1.4 영문 브랜드 작업안

구현과 스토어 자산 제작의 일관성을 위해 다음을 1차 작업안으로 사용한다.

| 위치 | 작업안 | 비고 |
|---|---|---|
| 브랜드·홈 화면 | `Mound Reborn` | 짧고 홈 화면에서 잘리지 않는 이름 |
| App Store 이름 | `Mound Reborn: Baseball Career` | 29자, 30자 제한 이내 |
| 부제 | `Pitch. Grow. Get Drafted.` | 직접 투구·성장·목표를 한 줄로 전달 |
| 핵심 시스템 용어 | `Rebirth` | 죽음보다 커리어 재시작과 계승을 뜻함 |

App Store 이름 중복 또는 상표 충돌이 발견되면 임의로 다른 이름을 배포하지 않는다. 대안과
검색 결과를 `결정 기록`에 남기고 사용자 승인을 받은 뒤 바꾼다. 앱 내부 콘텐츠 키와 저장 ID는
브랜드 변경과 무관하게 유지한다.

---

## 2. 범위

### 2.1 포함

- 첫 실행, 선수 생성, 학교 선택, 고교 커리어 전체
- 투구 선택, 제스처, 판정, 피드백, 경기 기록, VoiceOver 설명
- 관계 사건과 모든 신뢰도별 대사·선택지·후일담
- 드래프트 성공·실패, 환생, 기억 카드, 대표 유산, 회차 정산
- 프로 커리어, 리그표, 계약, 콜업, 보직, 오프시즌, 은퇴
- 주간 프로그램, 업적, Game Center 내부 문구, 설정, 오류
- 로컬 알림, 복귀 카드, 공유 텍스트와 공유 이미지
- 앱 표시 이름, launch logo, 문자 포함 이미지 감사
- App Store 이름·부제·키워드·설명·새 버전 문구
- 영어 App Store 스크린샷과 앱 미리보기 영상
- 영어 TestFlight 설명과 심사 노트
- iOS용 영어 지원 페이지와 개인정보 처리방침 진입 경로
- 영어 코호트를 구분하는 최소 분석 속성

### 2.2 제외

- 랜딩 대기자 모집과 수요 검증 실험
- 별도 영어 앱, 별도 SKU, 별도 bundle ID
- 영어 전용 세계, 서양 도시·학교·구단, 서양식 선수 이름 풀
- 일본어판 구현 또는 기존 일본어 작업 정리
- Android, Windows, Steam 현지화
- 신규 게임 콘텐츠, 신규 밸런스, 신규 수익화
- 앱 아이콘 변경. 현재 아이콘에는 문자가 없으므로 재사용한다.
- 영어 내레이션 녹음. 현재 심판·관중·효과음은 언어 독립적이므로 재사용한다.
- 원격 언어 kill switch. 오프라인 유료앱의 표시 언어를 서버에 의존시키지 않는다.

지원·개인정보 웹 페이지는 App Store 배포 요건을 위한 iOS 부속 범위다. 제품 랜딩 페이지를
영어로 전면 개편하는 작업은 포함하지 않는다.

---

## 3. 현재 코드 기준선

### 3.1 조사 결과

- `apps/ios`에는 현재 `.xcstrings`, `.strings`, `.lproj` 기반 현지화 계층이 없다.
- `CFBundleDevelopmentRegion`은 `ko`이며 이 값은 유지해야 한다.
- 현재 앱 버전 설정은 `1.0.4`, build `49`지만, 실제 구현 시 App Store의 최신 값을 다시 읽는다.
- 기존 감사에서 중복 제외 한국어 사용자 문구는 iOS UI 245개, 공유 코어 834개였다.
- 현재 단순 검색으로 한국어가 포함된 Swift 파일은 iOS 50개, 코어 33개다.
- 한국어 포함 줄은 주석까지 합쳐 iOS 3,938줄, 코어 2,437줄이므로 단순 치환으로 끝낼 수 없다.
- 공유 코어가 경기 피드백, 사건, 뉴스, 관계 대사, 학교·구단·인물 표시 문구를 직접 만든다.
- 다수의 스냅숏과 저장 레코드가 완성된 한국어 `String`을 보관한다.
- `DailyReminder.Plan`은 알림 제목과 본문 자체를 저장하므로 언어 변경 뒤 옛 한국어 알림이
  남을 수 있다.
- `PitchDecisionSnapshot`은 짧은 피드백, 상세 피드백, 접근성 문장을 완성 문자열로 저장한다.
- `LaunchLogo` 이미지에는 문자가 있어 영어 cold launch용 대응이 필요하다.
- 기존 분석 event name은 안정 ID로 운영 중이므로 바꾸면 안 된다.

### 3.2 우선 감사 파일

| 영역 | 주요 파일 |
|---|---|
| 프로젝트·앱 시작 | `apps/ios/project.yml`, `BaseballApp.swift`, `AppShell.swift`, `OpeningView.swift` |
| 고교 UI | `HighSchoolCareerView.swift`, `HighSchoolCareerStore.swift`, `HighSchoolSetupView.swift`, `HighSchoolPresentation.swift` |
| 투구 UI | `PitchView.swift`, `PitchSession.swift`, `PitchScenario.swift`, `PitchDramaView.swift`, `DeliveryControl.swift` |
| 프로 UI | `CareerFlowView.swift`, `MobileCareerStore.swift`, `LeagueView.swift`, `RecordView.swift` |
| 메타·공유 | `LifeCardView.swift`, `LifeArchiveView.swift`, `RunRecapView.swift`, `RunPledge.swift` |
| 시스템 표면 | `DailyReminder.swift`, `WeeklyProgram*.swift`, `Achievements*.swift`, `SettingsView.swift` |
| 분석 | `GameAnalytics.swift`, `AnalyticsContextTests.swift` |
| 고교 코어 | `HighSchoolCareer.swift`, `HighSchoolContentCatalog.swift`, `RelationshipVoiceCatalog.swift` |
| 투구 코어 | `PitchKernelEngine.swift`, `SimulationEngine.swift`, `PitchSequenceEvaluator.swift` |
| 프로 코어 | `ProCareer.swift`, `LeagueTable.swift`, `LeagueBaseline.swift` |
| 기타 콘텐츠 | `CareerWind.swift`, `CareerSignatureLegacy.swift`, `CommunityBuzz.swift`, `Nickname.swift`, `Talent.swift`, `AwakeningTree.swift` |
| 스토어 자산 | `apps/promo/src/asc`, `marketing/appstore`, `tools/asc-update-media.mjs` |

### 3.3 작업 트리 보존

문서 작성 시점에 다음 일본어 스토어 작업이 수정 또는 미추적 상태다.

```text
M  apps/promo/package.json
M  apps/promo/src/Root.tsx
M  apps/promo/src/asc/StoreCreative.tsx
M  apps/promo/src/theme.ts
?? apps/promo/src/asc/JapaneseAppScreens.tsx
?? marketing/appstore/ja-JP/
```

실행 에이전트는 다음을 지킨다.

1. 시작할 때 `git status --short`와 관련 diff를 기록한다.
2. 사용자 변경을 reset, checkout, stash, 삭제, 덮어쓰기 하지 않는다.
3. 영어 스토어 컴포넌트는 `EnglishAppScreens.tsx`처럼 독립 파일로 추가한다.
4. `package.json`, `Root.tsx`, `StoreCreative.tsx`, `theme.ts`를 수정해야 하면 현재 일본어 변경과
   병합하고, 삭제나 대규모 재작성은 피한다.
5. Xcode 프로젝트의 원본은 `apps/ios/project.yml`이다. `xcodegen generate` 전후에
   `project.pbxproj` diff를 확인한다.

---

## 4. 목표 아키텍처

### 4.1 언어와 세계를 분리한다

영어판은 새 세계가 아니다. 런타임에는 `GameWorldID`나 별도 저장 네임스페이스를 추가하지 않고
앱 표시 언어만 둔다.

```swift
enum AppLanguage: String, CaseIterable, Sendable {
    case korean = "ko"
    case english = "en"
}
```

언어 결정 규칙:

1. `Bundle.main.preferredLocalizations.first`를 읽는다.
2. `en`, `en-US`, `en-GB`, `en-AU`, `en-CA` 등은 모두 `.english`로 정규화한다.
3. `ko` 계열은 `.korean`으로 정규화한다.
4. 예상하지 못한 값은 개발 언어 `.korean`으로 떨어진다.
5. 테스트는 `-AppleLanguages (en)`과 `-AppleLocale en_US`를 사용한다.

앱 언어는 저장 파일에 넣지 않는다. iOS의 앱별 언어를 바꿔 다시 실행하면 같은 저장을 새 언어로
다시 렌더링해야 한다.

### 4.2 문구를 세 계층으로 나눈다

```text
apps/ios/Sources/Localization/
├── AppLanguage.swift
├── GameCopyKey.swift
├── GameCopyToken.swift
├── GameCopyResolver.swift
├── GameFormatters.swift
├── Localizable.xcstrings
├── GameContent.xcstrings
├── ko.lproj/InfoPlist.strings
└── en.lproj/InfoPlist.strings
```

| 계층 | 저장소 | 예시 |
|---|---|---|
| 정적 UI | `Localizable.xcstrings` | 탭, 버튼, 설정, 오류, 접근성 label |
| 게임 콘텐츠 | `GameContent.xcstrings` | 사건, 대사, 뉴스, 학교·구단·인물 표시명 |
| 번들 메타데이터 | `InfoPlist.strings` | 홈 화면 앱 표시 이름 |

규칙:

- 키는 한국어 원문이 아니라 `settings.audio.title`, `event.evt-catcher-sign.quote.low` 같은 의미 ID다.
- 모든 키에 `ko`와 `en`이 함께 있어야 한다.
- 한국어 값은 현재 출시 문구를 의미 변경 없이 옮긴다.
- 영어 값은 별도 완성 문장으로 재작성한다.
- 화면에서 문구 조각을 `+`, interpolation, 배열 join으로 조립해 영어 어순을 만들지 않는다.
- 변수는 이름, 팀, 학교, 기록, 수치처럼 실제로 변하는 값만 허용한다.
- 각 key의 변수 이름·순서·타입을 manifest로 검증한다.
- 접근성 label, hint, confirmation, error, notification, share 문구도 같은 체계에 넣는다.

### 4.3 코어는 의미를, iOS는 언어를 소유한다

`SimulationCore`에 Foundation locale이나 iOS bundle을 넣지 않는다. 코어는 언어 중립 ID와
타입이 있는 인자만 노출하고, iOS가 최종 문장을 해석한다.

권장 최소 타입:

```swift
public struct CopyToken: Equatable, Sendable {
    public let key: String
    public let arguments: [CopyArgument]
}

public enum CopyArgument: Equatable, Sendable {
    case userText(String)
    case contentID(String)
    case integer(Int)
    case decimal(Double)
}
```

이 타입은 기본적으로 `Codable`로 만들지 않는다. 표시 문장을 저장 상태와 event hash에서 분리하기
위한 값이다. 실제 저장 호환에 copy reference가 필요한 경우에만 별도 versioned optional 타입을
도입한다.

변환 원칙:

- 이미 안정 ID가 있는 콘텐츠는 그 ID로 key를 만든다.
- enum 표시는 raw value로 key를 만든다. raw value 자체는 번역하지 않는다.
- 동적 투구 피드백은 `outcome`, `reasonCodes`, execution band 같은 구조화된 결과로 key를 고른다.
- 관계 대사는 `eventID + trustBand + response`로 key를 고른다.
- 학교·구단·라이벌은 기존 ID를 재사용한다.
- 현재 ID가 없는 지역, 감독, 포수, 동적 뉴스에는 안정적인 presentation ID를 추가한다.
- presentation ID 추가가 RNG, 상태 commitment, event hash에 들어가지 않게 한다.
- 기존 shared client가 쓰는 한국어 `String` API는 한 번에 삭제하지 않는다. 기본 한국어 동작을
  보존하되 iOS는 raw 문자열을 직접 표시하지 않도록 이동한다.

### 4.4 저장과 iCloud 호환

영어판도 기존 키와 파일을 그대로 사용한다.

| 데이터 | 정책 |
|---|---|
| 고교 저장 | 기존 파일과 key 유지 |
| 프로 저장 | 기존 파일과 key 유지 |
| 주간 프로그램 | 기존 key와 지급 영수증 유지 |
| 업적 | 기존 로컬 원장 유지 |
| Game Center | 기존 achievement/leaderboard ID 유지 |
| iCloud | 기존 ubiquity key-value namespace 유지 |
| 분석 once flag | 기존 값을 유지하며 언어별로 복제하지 않음 |
| 사용자 설정 | 오디오·진동·자동 릴리스·알림 권한 유지 |

저장된 완성 문장은 다음 정책으로 처리한다.

1. **사용자 입력**: 선수 이름처럼 사용자가 직접 쓴 값은 그대로 표시한다. 자동 번역·자동
   로마자 변환을 하지 않는다.
2. **안정 ID가 있는 표시명**: 저장된 한국어 이름 대신 ID를 현재 언어의 표시명으로 해석한다.
3. **구조화 정보로 재생성 가능한 문장**: 결과 enum, reason code, 수치에서 현재 언어 문장을 만든다.
4. **새 저장에 의미 ID가 필요한 문장**: 기존 필드는 보존하고 optional `copyKey`와 typed argument를
   추가한다. 옛 저장은 필드가 없어도 열린다.
5. **옛 저장에서 복원이 불가능한 고정 문장**: 배포된 한국어 값과 key의 frozen mapping을
   `LegacyKoreanCopyIndex`에 둔다. 이 mapping은 옛 저장 읽기 전용이며 새 저장에는 쓰지 않는다.

금지:

- 언어별 저장 파일을 만드는 것
- 언어 변경 시 저장을 복사·rename·삭제·초기화하는 것
- 기존 한국어 문장을 영어로 덮어쓴 뒤 다른 클라이언트 호환을 깨는 것
- fallback을 이유로 영어 화면에 저장된 한국어 문장을 그대로 표시하는 것

알림은 별도 주의가 필요하다.

- `DailyReminder.Plan`은 장기적으로 `title/body`가 아니라 의미 key와 인자를 저장한다.
- 호환을 위해 기존 `title/body`는 optional legacy 필드로 읽을 수 있게 한다.
- 저장된 `scheduledLanguage` 또는 copy schema version이 현재 앱 언어와 다르면 pending request를
  제거하고 현재 언어로 다시 예약한다.
- 알림의 목적지, receipt, experiment assignment, reason은 그대로 유지한다.
- 언어 변경이 복귀 실험 코호트나 분석 분모를 새로 만들면 안 된다.

### 4.5 formatter와 고유명사

텍스트와 수치 표시를 분리한다.

| 항목 | 한국어 | 영어 | 내부 값 |
|---|---|---|---|
| 구속 | `149 km/h` | `92.6 mph` | 기존 `tenthsKPH` 유지 |
| 이닝 | 기존 한국어 정책 | `6⅔ IP` 같은 영어 야구 표기 | outs 기반 값 유지 |
| 9이닝당 실점(RA9) | 기존 표기 | `2.84 RA9` | 동일 계산값 |
| 타율 | 기존 표기 | `.286 AVG` | 동일 계산값 |
| 계약 금액 | 원화 | `KRW` 또는 `₩` 원화 표기 | 금액 변환 없음 |
| 날짜·숫자 | 한국어 locale | 영어 locale | 게임 일정·규칙 동일 |

- mph는 표시만 `kph / 1.609344`로 변환하고 한 자리 소수로 반올림한다.
- 현재 모델이 계산하는 값은 RA9이므로 ERA로 이름만 바꿔 표시하지 않는다.
- 변환된 mph를 엔진, 저장, 분석, 임계값 계산에 다시 넣지 않는다.
- 영어판도 같은 한국 세계이므로 계약 금액을 USD로 환산하지 않는다.
- 알림·연속 기록의 날짜 규칙을 현지화 작업 중 임의로 바꾸지 않는다.

고유명사 규칙:

- 실제 도시명은 통용 공식 영어 표기(`Seoul`, `Busan` 등)를 사용한다.
- 고정 인물은 ID별 영어 표시명을 큐레이션한다. 한글 음가를 기계적으로 한 글자씩 치환하지 않는다.
- 같은 인물은 모든 화면·알림·공유 카드에서 한 표기만 쓴다.
- 영어 이름 순서는 한 번 정한 표시명에 고정한다. 같은 인물을 화면마다 성-이름/이름-성으로
  바꾸지 않는다.
- 학교와 구단은 같은 ID·같은 지역·같은 정체성을 유지하며 자연스러운 영어 표시명을 만든다.
- 이름 풀의 개수와 배열 순서를 바꾸지 않는다. 서양식 이름 풀로 교체하지 않는다.
- 사용자가 입력한 이름은 한글이 포함돼도 허용한다. 영어 UI 한글 검사에서 사용자 입력은 명시적으로
  제외한다.

### 4.6 누락 fallback

- Debug/Test에서 key가 없거나 placeholder 타입이 다르면 즉시 assertion으로 실패한다.
- Release에서 영어 key 누락 시 한국어를 반환하지 않는다. 중립 영어 `Text unavailable`을 반환하고
  OSLog에 영역과 key를 남긴다.
- 이 fallback은 운영 전략이 아니라 최후 방어다. 출시 검사는 누락 0건을 강제한다.
- 번들에 영어 리소스가 통째로 없으면 iOS가 개발 언어 한국어를 선택할 수 있으므로, archive 내부의
  `en.lproj` 존재를 release gate로 검사한다.

---

## 5. 영어 카피 바이블

구현 시작 시 `docs/localization/IOS_ENGLISH_COPY_BIBLE.md`를 만들고 아래 내용을 고정한다.

### 5.1 목소리

- 기본 시점은 플레이어를 향한 2인칭 또는 짧은 현재형 서술이다.
- 스포츠 현장 문장은 짧고 구체적으로 쓴다.
- 성장·기록 화면은 감탄보다 변화의 원인과 결과를 먼저 말한다.
- 실패를 조롱하지 않는다. 실패는 다음 커리어의 정보와 계승으로 연결한다.
- 스카우트 문장은 미래를 확정하지 않고 현재 증거와 가능성을 말한다.
- 감독, 포수, 라이벌은 원문의 신뢰도별 감정선을 유지한다.
- 한국 배경을 서양 배경처럼 바꾸지 않는다. 낯선 제도는 자연스러운 문장 안에서 이해시키되 삭제하지 않는다.

### 5.2 핵심 용어 작업안

| 개념 | 영어 기준어 |
|---|---|
| 환생 | `Rebirth` |
| 회차 | `Career` 또는 문맥상 `Run` |
| 기억 카드 | `Memory Card` |
| 대표 유산 | `Signature Legacy` |
| 야구혼 | `Baseball Spirit` |
| 고교 3년 | `three-year high school career` |
| 프로 지명 | `get drafted` / `draft selection` |
| 미지명 | `undrafted` |
| 2군 | `Minors` |
| 1군 | `Majors` |
| 선발 | `Starter` |
| 롱릴리프 | `Long Reliever` |
| 셋업 | `Setup` 또는 문맥상 `Setup Man` |
| 마무리 | `Closer` |
| 구위 | `Stuff` |
| 제구 | `Control` |
| 변화구 | `Movement`가 아니라 사용자 문맥에 맞는 구종·break 표현 |
| 포심 | `Four-Seam Fastball` / 좁은 UI에서는 `Four-Seam` |
| 자동 릴리스 | `Auto Release` |

용어표는 실제 전체 문맥 감사 뒤 보완한다. 한 한국어 단어를 모든 영어 문맥에 기계적으로 같은
단어로 바꾸지 않는다. 다만 능력치 label처럼 학습 비용이 큰 용어는 한 표현으로 고정한다.

### 5.3 항목별 의미 계약

`docs/localization/ios-copy-schema.json`에 최소한 다음 필드를 둔다.

```json
{
  "key": "event.evt-catcher-sign.quote.low",
  "surface": "game_content",
  "source_anchor": "RelationshipVoiceCatalog/evt-catcher-sign/low",
  "placeholders": [
    { "name": "player", "type": "userText" }
  ],
  "facts": ["세 번 사인이 바뀌었다", "낮은 신뢰도의 포수가 불만을 말한다"],
  "player_task": "응답 하나를 고른다",
  "tone": "hurt, confrontational, not abusive",
  "status": "draft"
}
```

허용 status:

```text
inventory -> ko_locked -> en_draft -> semantic_reviewed -> language_reviewed -> ui_verified
```

출시 대상 key는 전부 `ui_verified`여야 한다.

### 5.4 작성·검수 순서

각 batch는 다음 순서를 지킨다.

1. 현재 한국어 문구와 실제 호출 문맥을 읽는다.
2. ID, 조건, 변수, 선택 효과를 확인한다.
3. 의미 계약을 작성한다.
4. 한국어 값을 현재 동작과 동일하게 catalog에 고정한다.
5. 원문을 보지 않고 의미 계약을 기준으로 영어 초안을 쓴다.
6. 다시 원문과 비교해 사실·불확실성·비용 누락을 찾는다.
7. 용어, 고유명사, placeholder, 길이를 검사한다.
8. 실제 화면과 VoiceOver에서 확인한다.
9. 영어에 능통한 검수자가 자연스러움과 야구 용어를 확인한다.

한 agent가 초안과 검수를 모두 수행해야 하는 상황이면 같은 turn에서 즉시 승인하지 않는다. batch를
완료한 뒤 다른 검수 pass에서 의미 계약만 보고 재검토한다.

### 5.5 실존 IP 금지

영어 문구, 고유명사, 스토어 문안에도 프로젝트 불변 규칙을 그대로 적용한다.

- 실존 프로 구단명, 통용 약칭, 리그명, 선수명, 로고, 유니폼 문양, 슬로건을 쓰지 않는다.
- 실제 도시명과 지역 분위기는 사용할 수 있다.
- 가상 학교·구단·대회는 독자 명칭을 유지한다.
- `KBO`, `KBO League`, `Korean Baseball Organization`, `MLB`, `Major League Baseball`,
  `NPB`, `Nippon Professional Baseball`을 사용자 문구와 마케팅에 넣지 않는다.
- 실제 한국 구단의 정식 영문명과 식별 가능한 약칭을 blocklist에 추가한다.
- `Giants`, `Tigers` 같은 일반 단어 하나만 기계적으로 금지하지 말고, 실존 조직을 식별하는
  전체 조합과 맥락을 검사한다.
- 모든 가상 학교·구단 영문명은 출시 전 현재 실존 명칭과의 혼동 가능성을 별도로 검색한다.

---

## 6. 구현 파일 지도

### 6.1 신규 파일

```text
apps/ios/Sources/Localization/AppLanguage.swift
apps/ios/Sources/Localization/GameCopyKey.swift
apps/ios/Sources/Localization/GameCopyToken.swift
apps/ios/Sources/Localization/GameCopyResolver.swift
apps/ios/Sources/Localization/GameFormatters.swift
apps/ios/Sources/Localization/Localizable.xcstrings
apps/ios/Sources/Localization/GameContent.xcstrings
apps/ios/Sources/Localization/ko.lproj/InfoPlist.strings
apps/ios/Sources/Localization/en.lproj/InfoPlist.strings

apps/ios/Tests/AppLanguageTests.swift
apps/ios/Tests/LocalizationCoverageTests.swift
apps/ios/Tests/EnglishFormattingTests.swift
apps/ios/Tests/LocalizedSaveCompatibilityTests.swift
apps/ios/Tests/EnglishNotificationTests.swift
apps/ios/Tests/EnglishShareCardTests.swift
apps/ios/Tests/LocalizationAnalyticsTests.swift
apps/ios/UITests/EnglishCareerSmokeUITests.swift

packages/simulation-core/Sources/SimulationCore/Presentation/CopyToken.swift
packages/simulation-core/Tests/SimulationCoreTests/LocalizationParityTests.swift
packages/simulation-core/Tests/SimulationCoreTests/Fixtures/ios_localization_parity_v1.json

docs/adr/ADR-015-ios-localized-presentation-boundary.md
docs/localization/IOS_ENGLISH_COPY_BIBLE.md
docs/localization/ios-copy-schema.json

tools/inventory-ios-localization.mjs
tools/check-ios-localization.mjs
tools/export-ios-localization-parity.mjs

apps/promo/src/asc/EnglishAppScreens.tsx
marketing/appstore/en-US/STORE_COPY.md
marketing/appstore/en-US/SCREENSHOT_PLAN.md
marketing/appstore/en-US/manifest.json
```

실제 코드 구조를 읽은 뒤 파일을 합치는 것은 허용하지만, 책임 경계와 검증 산출물은 유지한다.

### 6.2 기존 파일 변경 원칙

- `apps/ios/project.yml`: 영어 localizations와 resources를 target에 포함한다.
- `BaseballApp.swift`: 현재 app language와 resolver를 환경에 주입한다.
- View 파일: raw 한국어 literal 대신 의미 key 또는 이미 resolve된 copy를 사용한다.
- Store 파일: 사용자에게 보여 줄 완성 문장을 상태 원본으로 취급하지 않는다.
- Core catalog: ID·기계 데이터와 표시 문구를 분리한다.
- Engine: 기계 결과와 reason code를 유지하고 표시 문장은 descriptor로 옮긴다.
- `GameAnalytics.swift`: 기존 event name을 유지하고 공통 언어 속성만 추가한다.
- `DailyReminder.swift`: 문장 저장을 의미 key 저장으로 이행하고 언어 변경 시 재예약한다.
- `check-copy.mjs`: `.xcstrings`, `.strings`, 영어 marketing copy도 IP 검사 대상에 넣는다.
- `asc-update-media.mjs`: locale·media root·metadata 입력을 외부 설정으로 받아 영어 세트를 독립 처리한다.

---

## 7. 구현 단계

각 단계는 수용 기준을 통과한 뒤 다음 단계로 간다. 혼합 언어 상태를 배포 가능한 중간 결과로
간주하지 않는다.

### P0. 기준선 고정

작업:

- 현재 `git status`와 관련 diff 기록
- 현 버전의 core test, copy check, iOS Debug build 결과 기록
- 대표 고교·투구·프로 시드와 저장 fixture 생성
- 기존 event hash, numeric state, 선택지·효과 목록을 parity fixture로 고정
- 현재 저장 fixture를 한국어 UI에서 여는 테스트 확보

명령:

```sh
git status --short
npm run check:copy
swift test --package-path packages/simulation-core
xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

수용 기준:

- 기존 실패와 신규 실패를 구분할 기록이 있다.
- 대표 fixture에 콘텐츠 ID, 선택 효과, numeric state, event hash가 들어 있다.
- 사용자 작업 파일은 변경되지 않았다.

### P1. 전체 문구 inventory와 ADR

작업:

- `inventory-ios-localization.mjs`로 모든 Swift user-facing literal과 catalog 데이터를 수집
- 각 항목을 `static_ui`, `content`, `dynamic`, `proper_name`, `user_input`, `debug_only`로 분류
- persisted string field와 notification/share/accessibility surface를 별도 표기
- `ios-copy-schema.json` 생성
- ADR-015에서 표시 경계, 저장 호환, fallback, formatter 정책 확정
- 영어 카피 바이블과 용어표 작성

수용 기준:

- iOS 50개 + core 33개 한국어 포함 파일이 전부 검토되었다.
- 사용자 노출 가능 문자열은 모두 schema key 또는 명시적 제외 사유를 가진다.
- `debug_only`가 실제 UI error 경로에서 노출되지 않는지 테스트 또는 호출 분석이 있다.
- 문구 수는 기존 245/834 숫자를 참고하되 새 inventory 결과를 최종 기준으로 기록한다.

### P2. localization 기반 spike와 프로젝트 연결

작업:

- `AppLanguage`, resolver, 두 String Catalog, InfoPlist strings 추가
- UI key 2개, content key 2개, plural/format key 1개로 compile spike 수행
- `project.yml` 수정 후 XcodeGen 재생성
- `ko`, `en`, `Base`가 project known regions와 target resources에 들어갔는지 확인
- iOS 앱별 언어 변경 후 cold launch에서 같은 저장을 다른 언어로 표시하는 smoke test 작성

InfoPlist 값:

```text
ko: CFBundleDisplayName = "야구 못하면 또 환생함";
en: CFBundleDisplayName = "Mound Reborn";
```

수용 기준:

- 한국어 기기에서 기존 표시명이 유지된다.
- 영어 기기에서 영문 표시명과 영어 spike 문구가 보인다.
- 앱 언어 변경이 새 커리어를 만들거나 기존 저장을 바꾸지 않는다.
- archive에 `ko.lproj`, `en.lproj`, 두 catalog의 compiled resource가 존재한다.
- dynamic key와 placeholder formatter의 실제 컴파일 API가 ADR에 기록된다.

### P3. 공유 코어 표시 경계 분리

다음 순서로 진행한다.

1. enum label, pitch type, zone, outcome 같은 닫힌 집합
2. `HighSchoolContentCatalog`의 ID 기반 title/summary/narrative
3. `RelationshipVoiceCatalog`의 event/trust/response 기반 대사
4. 투구 feedback과 accessibility descriptor
5. 고교 훈련·관계·드래프트·환생의 동적 결과
6. 프로 시즌·계약·뉴스·은퇴의 동적 결과
7. 각성·재능·성격·별명·유산·커뮤니티 문구
8. 학교·구단·감독·포수·라이벌의 표시명

각 batch에서:

- 기계 ID와 numeric data를 먼저 고정한다.
- 기존 한국어 API의 결과를 fixture와 대조한다.
- iOS가 raw string 대신 token/resolver를 사용하도록 바꾼다.
- RNG 호출 횟수와 배열 순서를 바꾸지 않는다.
- event hash 입력에 locale, key, 영어 문자열을 넣지 않는다.
- 새 optional save field가 필요하면 old fixture decode와 round-trip을 먼저 테스트한다.

수용 기준:

- core 전체 테스트가 통과한다.
- P0의 대표 event hash와 numeric snapshot이 동일하다.
- 선택지 수·순서·효과 hash가 동일하다.
- 영어 iOS 경로가 core의 완성 한국어 문자열을 직접 표시하지 않는다.
- Windows/CLI가 쓰는 기본 한국어 API는 기존 테스트를 통과한다.

### P4. iOS 정적 UI와 formatter 전환

파일 순서:

1. `BaseballApp`, `OpeningView`, `AppShell`, `SettingsView`
2. `HighSchoolSetupView`, `HighSchoolCareerView`, `HighSchoolPresentation`
3. `PitchView`, `PitchDramaView`, `DeliveryControl`, `PitchScenario`, `PitchSession`
4. `CareerFlowView`, `MobileCareerStore`, `LeagueView`, `RecordView`
5. `WeeklyProgram*`, `Achievements*`, `GameCenterBoardView`
6. `LifeArchiveView`, `LifeCardView`, `RunRecapView`, `ShareSheet`
7. 모든 alert, error, empty state, accessibility label/hint

수용 기준:

- 모든 정적 user-facing key에 `ko/en` 값이 있다.
- 한국어 UI 문구의 의미와 동작이 바뀌지 않았다.
- 영어 UI에 한국어 hardcoded literal이 없다.
- 영어 구속·이닝·기록·원화 formatter가 단위 테스트를 통과한다.
- 작은 iPhone과 가장 큰 접근성 글자 크기에서 주요 CTA가 잘리지 않는다.

### P5. 영어 콘텐츠 재작성

batch 순서:

1. 온보딩, 핵심 조작, 투구 판정과 코칭
2. 고교 학교·인물·챕터·훈련
3. 관계 사건, 신뢰도 대사, 중요 경기
4. 드래프트 실패·성공, 환생, 기억, 유산
5. 프로 구단·인물·시즌·계약·은퇴
6. 주간 프로그램, 업적, 기록, 커뮤니티 반응
7. 오류, 알림, 공유, VoiceOver 같은 비화면 표면

수용 기준:

- 모든 schema item이 `language_reviewed` 이상이다.
- 콘텐츠 ID별 `ko/en` key 수가 같다.
- 영어가 한국어 문장 구조를 따라간 흔적 없이 자연스럽다.
- 사실, 선택 비용, 불확실성, 화자 감정이 원문과 같다.
- proper name 표기가 전체 앱에서 일관된다.
- 실존 IP 자동 검사와 검색 검토가 통과한다.
- placeholder, TODO, 임시 한국어 fallback이 없다.

### P6. 저장·알림·공유·접근성

작업:

- 기존 한국어 저장을 영어 UI로 여는 migration path 구현
- 영어로 새 저장 후 한국어로 다시 여는 왕복 테스트
- `DailyReminder.Plan` 의미 key 이행과 pending 알림 재예약
- 영어 notification title/body/action 검증
- 영어 share text, life card, recap image 렌더링
- 업적 banner와 Game Center 내부 설명 현지화
- 모든 핵심 화면의 VoiceOver label/hint/value 현지화
- launch logo의 `ko/en` localized asset 또는 문자 없는 공용 mark 적용

수용 기준:

- 언어 전환 전후 동일 save ID, revision, numeric state, receipt가 유지된다.
- pending 한국어 알림이 영어 선택 뒤 다시 울리지 않는다.
- 알림 재예약이 실험 variant와 receipt를 바꾸지 않는다.
- 영어 공유 이미지에 한글 UI 문구가 없고 잘림이 없다.
- 사용자가 입력한 한글 이름은 손상되지 않는다.
- cold launch에서 잘못된 언어 로고가 flash하지 않는다.

### P7. 자동 검사와 locale UI 테스트

작업:

- `check-ios-localization.mjs`와 npm script `check:ios-localization` 추가
- 기존 `check:copy`의 검사 확장
- 영어 전체 커리어 UI smoke test 추가
- 기존 한국어 smoke test 재실행
- screenshot attachment로 주요 화면 증거 보존

필수 영어 launch arguments:

```swift
app.launchArguments += [
    "-AppleLanguages", "(en)",
    "-AppleLocale", "en_US",
    "-uiTestResetCareer",
    "-uiTestAutoRelease",
    "-baseball.audio.sound", "NO"
]
```

수용 기준:

- 영어 접근성 트리의 앱 소유 문구에 한글 음절이 없다. 사용자 입력 값은 제외한다.
- 한국어 접근성 트리와 기존 smoke 흐름이 회귀하지 않는다.
- ko/en key, placeholder, plural variation, InfoPlist가 완전하다.
- Debug/Release build와 core test가 통과한다.

### P8. App Store 영어 자산과 TestFlight

작업:

- 실제 영어 앱 UI에서 결정적 fixture로 원본 screenshot 캡처
- 기존 7장 서사 순서 `직접 투구 → 미지명 → 환생 → 유산 → 적응 → 다음 선수 → 지명` 유지
- 영문 overlay와 실제 영어 화면으로 6.9형 제출 세트 렌더링
- 필요할 때만 6.5형 파생 세트 생성
- 같은 서사의 영어 앱 미리보기 영상 생성
- `marketing/appstore/en-US/STORE_COPY.md` 작성
- 영어 지원·개인정보 페이지 준비
- TestFlight `English QA` 외부 그룹에서 영어 사용자 검수

TestFlight는 수요 검증이 아니라 품질 검증이다. 최소 검수 항목:

- 영어가 자연스럽고 야구 용어가 맞는가.
- 첫 실행부터 첫 중요 경기까지 이해를 막는 문장이 없는가.
- 고교 실패·환생·다음 선수의 연결이 영어로도 같은 의미인가.
- 버튼·대사·알림·공유 카드에 혼합 언어가 없는가.
- 작은 화면과 VoiceOver에서 진행 가능한가.

수용 기준:

- 영어에 능통한 검수자 최소 1명의 전체 카피 승인 기록이 있다.
- 영어 TestFlight 플레이어 최소 5명이 첫 중요 경기까지 완료했다.
- 의미 오류, 진행 차단, 혼합 언어 P0 결함이 0건이다.
- screenshot과 preview의 문구가 실제 앱 기능을 과장하지 않는다.
- App Store media manifest의 크기, 길이, checksum이 검증된다.

### P9. 심사 제출과 배포

작업:

- App Store 최신 version/build를 읽고 다음 minor version과 더 큰 build를 정한다.
- 동일 앱 version에 영어 metadata를 추가한다.
- 영어 Game Center achievement/leaderboard metadata를 추가한다.
- 영어권 판매 territory와 현재 가격을 점검한다.
- 한국 가격·한국 metadata·한국 media가 바뀌지 않았는지 diff한다.
- 수동 출시와 7일 phased release를 설정한다.
- 심사 승인 뒤 직접 release한다.

영어 metadata locale:

1. `English (U.S.)`를 기준 원본으로 작성한다.
2. App Store Connect가 제공하는 `English (U.K.)`, `English (Australia)`,
   `English (Canada)` 슬롯에는 철자·키워드만 지역에 맞춰 검수한 같은 제품 내용을 넣는다.
3. New Zealand, Ireland, Singapore 등은 가장 가까운 승인된 English metadata가 보이는지
   storefront별 preview로 확인한다.
4. 한국어 primary language는 이번 버전에서 유지한다.

초기 확인 territory:

```text
United States, Canada, United Kingdom, Australia,
New Zealand, Ireland, Singapore
```

앱이 이미 더 넓게 판매 중이면 영어 출시를 이유로 기존 territory를 제거하지 않는다. 가격은 이번
현지화에서 임의 변경하지 않고 현재 paid-app price schedule을 유지한다.

수용 기준:

- 같은 bundle ID와 App Store record에 build가 연결돼 있다.
- 영어 product page에서 영어 name, subtitle, description, keywords, screenshots가 보인다.
- 한국 product page는 기존 한국어 자산과 가격을 유지한다.
- 심사 노트에 같은 콘텐츠·같은 저장·시스템 앱 언어 지원을 설명한다.
- phased release가 켜져 있고 중단 기준 담당자가 명시돼 있다.

---

## 8. 테스트 계획

### 8.1 공유 코어

필수 테스트:

1. localization refactor 전후 대표 event hash 동일.
2. 같은 seed와 입력의 numeric result 동일.
3. 콘텐츠 ID, 개수, 배열 순서 동일.
4. 선택지 개수, 순서, condition, effect 동일.
5. 영어 표시를 resolve해도 RNG state가 변하지 않음.
6. 기존 한국어 API 기본 동작 동일.
7. 기존 save fixture decode 성공.
8. 새 optional presentation field가 없는 옛 payload round-trip 성공.
9. 모든 content/proper-name ID에 ko/en key 존재.
10. 영어 실존 IP blocklist 통과.

### 8.2 iOS unit test

필수 테스트:

- `en-US`, `en-GB`, `en-AU`, `en-CA`가 `.english`로 정규화
- `ko-KR`가 `.korean`으로 정규화
- 알 수 없는 언어 fallback
- catalog key 완전성, 빈 값, review status
- placeholder 이름·타입·개수 일치
- plural과 숫자 formatter
- kph→mph 고정 반올림
- ERA, AVG, WHIP, innings 영어 표기
- KRW 표시와 금액 불변
- 한국어 save를 영어 copy로 표시
- 영어 상태에서 만든 save를 한국어로 복원
- 알림 legacy plan migration과 언어 재예약
- share image 영문 레이아웃
- analytics 공통 language 속성
- language switch가 once flag를 복제하지 않음
- missing key가 한국어 fallback을 하지 않음

### 8.3 UI smoke

영어 smoke는 최소 다음 장면을 지나간다.

1. launch와 opening
2. 선수 이름과 스타일 설정
3. 지역·학교 선택
4. 첫 불펜 투구
5. 첫 훈련과 관계 선택
6. 첫 중요 경기 완주
7. 경기 결과와 기록
8. 드래프트 미지명
9. 환생과 기억·유산 선택
10. 다음 선수 시작
11. 드래프트 지명과 프로 진입
12. 프로 주간·경기·오프시즌
13. 주간 프로그램·업적·설정
14. 공유 카드 생성
15. 종료된 일일 딥 링크의 안전한 복귀

한국어 smoke도 같은 build에서 다시 실행한다.

### 8.4 수동 QA matrix

| 축 | 값 |
|---|---|
| 앱 언어 | ko, en |
| region | KR, US, GB, AU, CA |
| 저장 | 신규, 기존 한국 save, 진행 중 투구, 프로 save, iCloud 복원 |
| 기기 | 작은 iPhone, 최신 큰 iPhone, 실제 기기 최소 1대 |
| 글자 크기 | 기본, 가장 큰 접근성 크기 |
| 접근성 | VoiceOver, Reduce Motion, Increase Contrast |
| 네트워크 | online, offline |
| 계정 | iCloud/Game Center 로그인·미로그인 |
| 수명주기 | cold, warm, background, 강제 종료 후 복원 |
| 알림 | 기존 예약 있음, 언어 변경, 알림 탭 딥 링크 |

출시 차단 결함:

- crash, 진행 불가, 저장 유실 또는 다른 저장 생성
- 영어판의 앱 소유 문구에 한국어 노출
- 한국판의 기존 문구·레이아웃·저장 회귀
- 같은 seed에서 기계 결과 또는 event hash 변경
- 영어에서 사건·선택·효과 누락 또는 순서 변경
- 실존 구단·리그·선수 식별 요소 노출
- 잘못된 통계·이닝·구속 변환
- 알림·공유·VoiceOver의 혼합 언어
- cold launch의 한국어 logo flash
- 주요 CTA 잘림

---

## 9. 자동 검사와 명령

### 9.1 npm script

root `package.json`에 추가한다.

```json
{
  "scripts": {
    "inventory:ios-localization": "node tools/inventory-ios-localization.mjs",
    "check:ios-localization": "node tools/check-ios-localization.mjs"
  }
}
```

`check:ios-localization` 검사 항목:

- 모든 schema key가 catalog에 존재
- 모든 key에 non-empty ko/en 값 존재
- stale, needs-review, draft 상태 0건
- ko/en placeholder signature 동일
- content ID별 title/body/choice key 완전성
- InfoPlist display name 양 언어 존재
- English resolved fixture에 앱 소유 한글 음절 없음
- notification, share, accessibility key가 inventory에서 빠지지 않음
- 영어 catalog와 marketing에 실존 IP 금칙어 없음
- key를 한국어 원문으로 사용한 항목 없음
- `Text(dynamicString)` 호출이 이미 resolve된 값인지 allowlist로 검증
- iOS View가 core의 legacy Korean display field를 직접 쓰는 경로 없음

### 9.2 전체 검증 명령

```sh
npm run inventory:ios-localization
npm run check:ios-localization
npm run check:copy
npm run check:dialogue-parity
swift test --package-path packages/simulation-core

cd apps/ios
xcodegen generate
cd ../..

xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Simulator test 전 실제 대상 확인:

```sh
xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -showdestinations
```

설치된 simulator를 선택해 unit/UI test:

```sh
xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=<installed iPhone>' \
  test
```

archive 전 리소스 검사:

```sh
xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath artifacts/ios/Baseball-English.xcarchive \
  archive
```

실행 환경에 해당 simulator가 없으면 임의 기기 이름을 고정하지 않는다.

---

## 10. App Store 문안·자산

### 10.1 문안 원칙

- 한국어 store copy를 문장별로 번역하지 않는다.
- 첫 세 줄에서 직접 투구, 고교 3년, 드래프트 목표를 명확히 말한다.
- 실패하면 환생하고 일부 성장이 다음 선수에게 남는 구조를 숨기지 않는다.
- 유료앱, 광고 없음, IAP 없음, 오프라인 플레이를 정확히 말한다.
- `한국어 전용` 문구를 제거하고 `English and Korean`을 명시한다.
- 실제 리그나 구단과 무관한 창작 세계임을 영어로 명시한다.
- 검증되지 않은 순위, 판매량, 비교 우위 주장을 쓰지 않는다.
- 미국식 야구 용어를 기본으로 하되 특정 실존 리그 라이선스를 암시하지 않는다.

### 10.2 스크린샷

한국어판과 같은 기능·같은 서사 순서를 보여 준다.

| # | 영어 메시지의 기능 | 실제 화면 |
|---|---|---|
| 1 | 마지막 한 구를 직접 던진다 | 투구 결과·스트라이크 존 |
| 2 | 못하면 이름이 불리지 않는다 | 드래프트 미지명 |
| 3 | 끝이 아니라 환생이다 | 환생 연출 |
| 4 | 전 커리어의 한 가지가 남는다 | 대표 유산 선택 |
| 5 | 타자도 배합을 읽는다 | 구종·코스·사인 선택 |
| 6 | 실패가 다음 선수의 시작이 된다 | 다음 선수 시작 능력 |
| 7 | 다음 커리어에는 지명될 수 있다 | 드래프트 지명 |

overlay headline은 영어로 새로 쓰되 기능 주장을 바꾸지 않는다. 한국어 화면 위에 영어 caption만
얹지 말고, 실제 영어 앱 UI를 캡처한다.

### 10.3 App Store Connect 작업

- English localized app name, subtitle, privacy URL
- English version description, promotional text, keywords, What's New
- English screenshots와 app preview
- English Game Center achievement·leaderboard 제목과 설명
- English TestFlight beta description과 What to Test
- English review notes
- English support/privacy URLs
- 현재 territory와 price schedule 확인

ASC 자동화는 `ASC_LOCALE`, `ASC_MEDIA_ROOT`, version/build를 명시적으로 받아야 한다. 기본값이
`ko`인 기존 스크립트를 무심코 실행해 한국 metadata를 영어로 덮어쓰지 않는다. `inspect` 결과와
업로드 전후 JSON diff를 release evidence로 보존한다.

---

## 11. 분석과 출시 후 판독

### 11.1 공통 속성

모든 Firebase와 Amplitude event의 기존 공통 context에 다음 낮은 카디널리티 속성을 추가한다.

```text
app_language = ko | en
copy_schema_version = integer
```

선택적으로 `format_region = KR | US | GB | AU | CA | other`를 넣을 수 있지만, 이 값은 기기
region이지 구매 storefront가 아니다. 결제 국가로 해석하거나 매출 원본으로 사용하지 않는다.

규칙:

- 기존 event name과 의미를 변경하지 않는다.
- language 전환으로 `onboarding_started`, `first_pitch`, `activation_first_game` once key를 새로
  만들지 않는다.
- 선수명, 학교명, 사용자 입력, copy 본문을 분석 속성으로 보내지 않는다.
- 기존 `distribution`, `environment`, `platform`, `ingestion_origin`, schema version을 보존한다.
- 매출·판매 국가는 App Store Connect Sales and Trends를 원본으로 사용한다.

### 11.2 출시 후 14일 readout

| 목적 | 지표 | 분리 |
|---|---|---|
| 유입 | 신규 production/app_store 사용자 | `app_language`, Amplitude country |
| 활성화 | 첫 중요 경기 완료 / onboarding started | `app_language=en` |
| 핵심 이해 | first pitch → activation first game | 영어 cohort |
| 반복 | D1 의미 경기 복귀, rebirth started | 영어 cohort |
| 구매 | territory별 paid app units와 proceeds | App Store Connect |
| 품질 | crash-free sessions, save error, review | build + language |
| 카피 | localization missing log, 영어 리뷰 언급 | build + copy version |

이 readout은 영어판을 만들지 말지 결정하는 gate가 아니다. 이미 배포 결정이 끝났으므로, 다음
카피·스토어 자산 개선과 추가 언어 우선순위를 정하는 데 사용한다.

---

## 12. 출시와 롤백

### 12.1 출시 방식

- App Review 제출은 manual release로 둔다.
- 승인 뒤 English product page와 territory preview를 마지막으로 확인한다.
- 기존 사용자 업데이트는 7일 phased release를 사용한다.
- 영어권 신규 구매자는 언제든 최신 버전을 직접 받을 수 있으므로, phased release가 신규 영어
  유입을 제한하는 장치라고 오해하지 않는다.
- 첫 24시간에는 crash, save load, missing copy, 한국 product page 회귀를 우선 감시한다.

### 12.2 중단 기준

아래 중 하나면 phased release를 즉시 pause한다.

- 저장 load 실패 또는 iCloud 진행 손상
- 한국어 기존 사용자 진행 회귀
- 핵심 흐름 crash 증가
- 영어 resource 누락으로 광범위한 한국어 fallback 또는 `Text unavailable` 노출
- 선택 효과·수치·event hash parity 실패가 운영에서 확인됨
- 실존 IP 충돌 가능성이 높은 영문 고유명사 발견

### 12.3 롤백 원칙

- 사용자 저장을 삭제하거나 이전 schema로 강제 rewrite하지 않는다.
- 심사 전 문제면 영어 metadata와 build 공개를 보류하고 수정 build를 제출한다.
- 배포 뒤 문제면 phased release를 pause하고 더 높은 build의 수정 버전을 낸다.
- 문구 문제는 key와 콘텐츠 ID를 유지한 채 영어 value만 고친다.
- 영어 App Store metadata만 제거해도 이미 설치된 앱의 영어 리소스는 남으므로, 심각한 앱 내
  문제는 반드시 수정 binary로 해결한다.
- 한국어 primary metadata, 가격, 저장 key는 영어 롤백 과정에서도 바꾸지 않는다.

---

## 13. 예상 작업량과 마일스톤

현재 문구 규모를 기준으로 한 현실적인 구현 순서다. Apple 심사 시간은 포함하지 않는다.

| 마일스톤 | 예상 | 완료 증거 |
|---|---:|---|
| M1 기준선·inventory·ADR | 1–2일 | schema, parity fixture, ADR |
| M2 localization 기반·코어 표시 분리 | 2–3일 | ko/en spike, core hash 회귀 통과 |
| M3 전체 UI·동적 문구 전환 | 2–3일 | raw Korean display path 0 |
| M4 영어 콘텐츠 재작성·검수 | 3–5일 | 모든 key `language_reviewed` |
| M5 저장·알림·공유·접근성 QA | 1–2일 | 언어 왕복·UI smoke 통과 |
| M6 스토어 자산·TestFlight·제출 | 1–2일 | release evidence, ASC draft |

총 구현 목표는 10–17 agent-day다. 일정이 밀릴 때 줄일 수 있는 것은 보조 store locale의 별도
키워드 최적화와 6.5형 파생 자산이다. 아래 항목은 줄이지 않는다.

- 전체 콘텐츠 parity
- 기존 저장과 한국어 회귀 검증
- 혼합 언어 0건
- 알림·공유·VoiceOver
- 실존 IP 검사
- 영어 카피 검수

---

## 14. Definition of Done

### 제품·코드

- [ ] 기존 bundle ID와 단일 iOS target 유지
- [ ] 별도 영어 세계·저장·SKU 없음
- [ ] `ko/en` app localizations가 같은 binary에 포함
- [ ] 한국어 개발 지역 유지
- [ ] UI·게임 콘텐츠·InfoPlist 현지화 계층 구현
- [ ] core 기계 데이터와 표시 copy 경계 분리
- [ ] 기존 한국어 API와 shared client 테스트 유지
- [ ] 기존 event name과 once semantics 유지

### 콘텐츠

- [ ] 모든 사용자 문구 inventory 완료
- [ ] 모든 key에 기존 한국어 값과 영어 재작성 값 존재
- [ ] 콘텐츠 ID, 개수, 순서, 선택, 효과 완전 동일
- [ ] 고유명사 영어 표시 일관성
- [ ] 영어 문장이 직역체가 아니라 자연스러운 완성 문장
- [ ] 사실·비용·불확실성·감정선 parity 승인
- [ ] 실존 IP·선수·학교·대회 혼동 검사 통과
- [ ] placeholder/TODO/한국어 fallback 0건

### 저장·기능

- [ ] 기존 한국어 save가 영어로 같은 진행을 표시
- [ ] 영어에서 진행 후 한국어로 돌아와 같은 save 복원
- [ ] save ID, revision, numeric state, event hash 불변
- [ ] iCloud·주간·업적·Game Center 계보 유지
- [ ] 알림 key 이행과 언어 변경 재예약
- [ ] 공유 카드·VoiceOver·오류·설정 영어 완전성
- [ ] cold launch logo 언어 일치

### 품질

- [ ] `swift test` 전체 통과
- [ ] `check:copy`, `check:dialogue-parity`, `check:ios-localization` 통과
- [ ] iOS Debug/Release build 통과
- [ ] ko/en UI smoke 통과
- [ ] 작은 화면·큰 접근성 글자 크기 통과
- [ ] 실제 iPhone 최소 1대 영어 QA
- [ ] 영어 TestFlight 검수 완료
- [ ] 출시 차단 결함 0건

### App Store

- [ ] English metadata와 privacy/support URL 입력
- [ ] 실제 영어 UI screenshot 업로드
- [ ] English app preview 처리 완료
- [ ] English Game Center metadata 입력
- [ ] 한국 metadata·가격·media 회귀 없음
- [ ] English-speaking territory 확인
- [ ] manual release + phased release 설정
- [ ] App Review 제출

---

## 15. 실행 에이전트 규약

1. 각 단계 시작 전 관련 구현과 테스트를 읽는다.
2. 문구 치환을 위해 게임 규칙을 바꾸지 않는다.
3. 기계 로직 변경과 영어 카피 대량 변경을 같은 diff에 섞지 않는다.
4. 작은 batch마다 한국어 회귀, 영어 완전성, parity test를 실행한다.
5. 안정 ID가 있는데 한국어 원문을 key로 사용하지 않는다.
6. ID가 없으면 한국어 문자열 비교로 영구 해결하지 말고 안정 ID를 설계한다.
7. legacy Korean mapping은 옛 저장 읽기 전용으로 격리한다.
8. 새 save field는 optional/default decode로 기존 저장을 보존한다.
9. 저장 삭제·키 rename·별도 영어 저장으로 migration 문제를 우회하지 않는다.
10. 사용자 입력은 번역하지 않고 손상 없이 보존한다.
11. 테스트 실패를 무시하거나 기능 범위를 줄여 완료 처리하지 않는다.
12. 대량 rewrite 뒤 저장소 전체에서 한글 노출, IP 금칙어, raw string 경로를 다시 검색한다.
13. 현재 일본어 관련 사용자 변경을 보존한다.
14. ASC write 전에는 반드시 inspect와 locale 확인을 수행한다.
15. 각 P 단계가 끝나면 아래 결정 기록에 파일, 테스트, 남은 위험을 남긴다.

---

## 16. 결정 기록

실행 에이전트가 아래 형식으로 누적한다.

```md
### YYYY-MM-DD / P단계 / 결정 제목

- 변경 파일:
- 결정:
- 이유:
- 콘텐츠 parity 영향:
- 저장 호환성 영향:
- 실행한 테스트:
- 결과:
- 남은 위험:
```

문서 작성 시점에는 구현 파일을 변경하지 않았다.

---

## 17. Apple 공식 기준

- [Localization](https://developer.apple.com/documentation/Xcode/localization/): String Catalog,
  locale별 테스트, TestFlight 검수의 공식 출발점.
- [How iOS Determines the Language For Your App](https://developer.apple.com/library/archive/qa/qa1828/_index.html):
  사용자의 선호 언어와 앱이 선언한 localization을 기준으로 언어를 고른다.
- [Localize app information](https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information/):
  앱 binary localization과 App Store metadata localization은 별개이며, 사용자 언어에 맞는 metadata가 표시된다.
- [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots):
  localization별 screenshot·preview 업로드와 현재 제출 규격의 기준.
- [Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers):
  영어 TestFlight 외부 검수 그룹 운영 기준.
- [Release a version update in phases](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases):
  기존 사용자 자동 업데이트를 7일에 걸쳐 배포하고 필요하면 중단하는 기준.
