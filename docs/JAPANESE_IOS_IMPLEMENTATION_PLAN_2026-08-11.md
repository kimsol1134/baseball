# 일본어 iOS판 상세 구현 계획

| 항목 | 값 |
|---|---|
| 문서 ID | `DOC-JP-IOS-IMPLEMENTATION-2026-08-11` |
| 기준일 | 2026-08-11 KST |
| 상태 | 구현 승인안 |
| 실행 주체 | 이 저장소를 수정하는 AI 에이전트 |
| 대상 | `apps/ios`, `packages/simulation-core`, `marketing/appstore` |
| 제출 목표 | 개발 시작 후 3일 안에 App Store 심사 제출 |
| 출시 목표 | Apple 심사 승인 후 수동 출시 |
| 매출 목표 | 일본 결제 매출 6개월 누적 1억 원 |

이 문서는 기존 iOS 앱에 일본어를 추가하는 작업의 단일 실행 기준이다. 단순 문자열 번역이 아니라, 동일한 앱과 동일한 게임 규칙 안에 **한국 세계와 일본 세계를 독립된 콘텐츠·세이브로 제공**한다.

코드와 이 문서가 충돌하면 현재 코드가 기술적 사실 원본이다. 다만 아래의 제품 결정과 콘텐츠 불변 규칙은 임의로 축소하거나 변경하지 않는다. 구현 중 불가피한 설계 변경은 이 문서의 `결정 기록`에 먼저 남기고 진행한다.

---

## 1. 최종 제품 결정

### 1.1 앱과 배포

- 새 앱을 만들지 않는다. 기존 bundle ID `com.solkim.baseball.ios`를 유지한다.
- iOS 앱만 구현·출시한다. 다른 클라이언트의 일본어판은 이번 범위가 아니다.
- 공유 시뮬레이션 코어는 수정할 수 있지만, 기본 생성자와 기존 클라이언트의 한국 콘텐츠 동작은 보존한다.
- 한국 App Store의 기존 앱 이력, 리뷰, 버전 계보를 유지한다.
- App Store Connect에 `Japanese (Japan)` 현지화만 추가한다.
- 개발 완료와 심사 제출은 3일 목표다. 실제 공개 시점은 Apple 심사 완료에 종속된다.

### 1.2 일본판 제품 정의

- 일본어 앱 이름: `野球がダメならまた転生：投手育成`
- 홈 화면 표시 이름: `野球がダメならまた転生`
- 핵심 문구: `野球がダメなら、また転生。`
- 현재 시점의 독자적인 가상 일본 야구 세계를 사용한다.
- 죽음, 사고사, 사후세계, 이세계 전생을 넣지 않는다.
- `転生`은 한 선수의 커리어가 끝난 뒤 기억과 성장 요소가 다음 선수에게 이어지는 게임 시스템을 뜻한다.
- 문체는 가볍고 속도가 빠른 일본 웹소설 톤이다.
- 야구 규칙, 기록 표기, 경기 상황은 현실적이고 정확하게 유지한다.
- 주역과 라이벌 이름은 과장되고 기억에 남게 만들고, 일반 선수 명단은 현실적인 이름으로 받쳐 준다.
- 사투리는 캐릭터를 구분하는 짧은 대사에만 제한적으로 사용한다.

### 1.3 기능과 비주얼

- 고교 커리어, 프로 커리어, 환생, 주간 프로그램, 업적, Game Center, 공유 카드, 알림, iCloud 저장을 모두 제공한다.
- 임시 제거된 오늘의 이닝은 일본 출시 범위에도 넣지 않으며, 옛 저장 키만 세계별 데이터와 섞이지 않게 보존한다.
- 한국판과 게임 규칙, 성장 수치, 난이도, 보상, 투구 조작을 동일하게 유지한다.
- 아이콘, 키아트, 인물 초상, 배경, 경기 연출, 색상, 애니메이션은 재사용한다.
- 기존 아트에 한국어가 보이는 경우에만 일본어 대응 자산을 만든다.
- 앱 아이콘에는 문자가 없으므로 그대로 사용한다.
- 현재 확인된 문자 포함 자산은 `LaunchLogo`다. 전체 에셋은 출시 전에 다시 감사한다.
- 구단별 신규 로고와 유니폼은 1차 출시 범위가 아니다. 구단 정체성은 이름·연고지·설명으로 표현한다.

### 1.4 가격과 초기 운영

- 일본 출시 후 7일 동안 `¥500`.
- 8일째부터 정상가 `¥800`.
- 한국 가격 `₩4,400`은 유지한다.
- 앱 내부 결제, 광고, 구독을 추가하지 않는다.
- 일본 출시 후 첫 48시간은 유료 광고 없이 자연 유입을 관찰한다.
- 결제 매출의 원본은 App Store Connect 판매 보고서다. 보고서가 1~2일 늦는 것을 전제로 판단한다.
- Amplitude 신규 사용자·첫 실행은 판매량의 선행지표로만 사용하고 결제 건수로 부르지 않는다.

---

## 2. 절대 지켜야 할 콘텐츠 규칙

다음 규칙은 `AGENTS.md`보다 느슨하게 해석하지 않는다.

1. 실제 도도부현과 도시명은 사용할 수 있다.
2. 실존 프로 구단명, 약칭, 리그명, 선수명, 로고, 유니폼 문양, 슬로건은 사용하지 않는다.
3. 실존 학교명과 실존 대회명은 사용하지 않는다.
4. 학교·구단·대회는 지역적 작명법과 분위기를 통해 해당 지역을 떠올릴 수 있게 하되, 특정 실존 조직의 한두 글자만 바꾼 이름을 만들지 않는다.
5. 가상 명칭은 실존 명칭과 정확히 일치하지 않아야 할 뿐 아니라, 일반 사용자가 같은 조직으로 오인할 정도로 유사해서도 안 된다.
6. 실존 리그의 팀 구성, 색상, 약칭, 슬로건을 한 세트로 복제하지 않는다.
7. `甲子園`, 실존 양대 리그명, 실존 포스트시즌·결승전 브랜드명은 사용자 문구에 쓰지 않는다.
8. `死亡`, `死ぬ`, `事故死`, `死後`, `あの世`, `異世界転生`을 일본판 이야기 문구에 쓰지 않는다.
9. 일본 콘텐츠를 추가할 때 자동 금칙어 검사와 일본어 원어민의 혼동 가능성 검수를 모두 통과해야 한다.
10. 자동 검사는 사람 검수의 대체물이 아니다.

### 2.1 허용되는 현실감

- `東京都`, `大阪府`, `北海道`, `福岡県` 같은 행정구역 실명
- `札幌`, `仙台`, `東京`, `横浜`, `名古屋`, `大阪`, `広島`, `福岡` 같은 도시 실명
- 지역의 기후, 이동 거리, 음식, 응원 열기, 학교 작명 관습
- 일반적인 야구 용어인 `ドラフト`, `一軍`, `二軍`, `交流戦`, `全国大会`, `地区予選`

### 2.2 금지되는 구현 방식

- 실존 학교 이름에서 한자 한 글자만 교체
- 실존 구단의 도시·동물·대표색 조합을 그대로 복제
- 실제 구단 약칭을 내부 ID나 사용자 문구에 사용
- 실존 선수의 성명 전체, 대표 별명, 등번호, 경력 문구를 조합해 캐릭터 제작
- 실제 대회 로고·우승기·구장 고유 표식을 재현
- 한국 문자열을 일본어 화면에서 임시 fallback으로 노출

---

## 3. 현재 코드 기준선

### 3.1 조사 결과

- `apps/ios`에는 `.xcstrings`, `.strings`, `NSLocalizedString`, `String(localized:)` 기반의 현지화 계층이 없다.
- 한국어 사용자 문구가 iOS UI와 공유 코어에 직접 들어 있다.
- 한국어가 포함된 Swift 소스는 현재 83개다.
- 주요 콘텐츠 집중 파일은 다음과 같다.

| 영역 | 현재 주요 파일 |
|---|---|
| 고교 데이터·엔진 | `packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift` |
| 고교 사건·경기 | `packages/simulation-core/Sources/SimulationCore/HighSchoolContentCatalog.swift` |
| 관계 대사 | `packages/simulation-core/Sources/SimulationCore/RelationshipVoiceCatalog.swift` |
| 프로 데이터·엔진 | `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` |
| 투구 판정 문구 | `packages/simulation-core/Sources/SimulationCore/PitchKernelEngine.swift` |
| 고교 화면·표현 | `apps/ios/Sources/HighSchoolCareerView.swift`, `HighSchoolPresentation.swift` |
| 프로 화면·표현 | `apps/ios/Sources/CareerFlowView.swift`, `AppShell.swift` |
| 저장 | `HighSchoolCareerStore.swift`, `MobileCareerStore.swift`, `WeeklyProgramStore.swift`, `SaveSync.swift` |
| 알림 | `DailyReminder.swift` |
| 분석 | `GameAnalytics.swift` |
| 업적·Game Center | `Achievements.swift`, `AchievementStore.swift` |
| 스토어 자산 | `marketing/appstore` |

### 3.2 현재 저장 키

| 데이터 | 현재 키 |
|---|---|
| 고교 | `baseball-mobile-highschool-v1.json` |
| 프로 | `baseball-mobile-pro-v1.json` |
| 주간 프로그램 | `baseball-weekly-program-v2.json` |
| 업적 | `baseball.achievements.v1` |
| 분석 1회 플래그 | `baseball.analytics.once.*` |
| 종료된 일일 모드의 레거시 데이터 | `baseball.daily.*` |
| 마지막 설정 | `baseball.lastSetup` |
| 입력·오디오 설정 | `baseball.pitch.*`, `baseball.audio.*` |

기존 키는 이미 출시된 한국판 데이터다. 이름을 바꾸거나 일본판에서 읽으면 안 된다.

### 3.3 작업 시작 전 주의

현재 작업 트리에는 이 계획과 무관한 수정 파일과 새 파일이 존재할 수 있다. 실행 에이전트는 다음을 지킨다.

1. 시작 시 `git status --short`와 관련 파일의 `git diff`를 저장한다.
2. 사용자 변경을 reset, checkout, stash, 덮어쓰기 하지 않는다.
3. 특히 `apps/ios/Baseball.xcodeproj/project.pbxproj`, `AppShell.swift`, `DailyStreak.swift`, `HighSchoolPresentation.swift`, `PitchDramaView.swift`, `PlateFigures.swift`, `HighSchoolCareer.swift`, `PitchKernelEngine.swift`의 기존 변경과 병합한다.
4. Xcode 프로젝트의 원본은 `apps/ios/project.yml`이다. `project.yml`을 수정한 뒤 `xcodegen generate`를 실행하되, 생성 전후 `project.pbxproj` diff에서 사용자 변경 손실이 없는지 확인한다.
5. 기존 분석 계획 `docs/AMPLITUDE_DATA_DRIVEN_FINAL_PLAN_2026-08-11.md`에서 이미 구현된 변경이 있으면 보존하고 `world_id` 속성만 결합한다.

---

## 4. 목표 아키텍처

### 4.1 핵심 타입

공유 코어에 다음 개념을 추가한다.

```swift
public enum GameWorldID: String, Codable, CaseIterable, Sendable {
    case korea = "kr"
    case japan = "jp"
}

public struct WorldContentVersion: Codable, Equatable, Sendable {
    public let worldID: GameWorldID
    public let version: Int
}
```

`GameWorldID`는 콘텐츠 세계를 뜻한다. `ko`, `ja` 같은 언어 코드로 대체하지 않는다. 향후 한 세계에 여러 언어가 생겨도 저장 정체성이 흔들리지 않아야 한다.

### 4.2 콘텐츠 제공 계층

다음 구조를 권장한다.

```text
packages/simulation-core/Sources/SimulationCore/WorldContent/
├── GameWorldID.swift
├── WorldContentProviding.swift
├── WorldContentRegistry.swift
├── Korea/
│   ├── KoreaWorldContent.swift
│   ├── KoreaSchools.swift
│   ├── KoreaProLeague.swift
│   ├── KoreaCast.swift
│   └── KoreaNarrative.swift
└── Japan/
    ├── JapanWorldContent.swift
    ├── JapanGeography.swift
    ├── JapanSchools.swift
    ├── JapanProLeague.swift
    ├── JapanCast.swift
    └── JapanNarrative.swift
```

`WorldContentProviding`은 최소한 다음 데이터를 제공한다.

- 세계 ID와 콘텐츠 버전
- 지역권·도도부현·도시
- 학교, 감독, 포수, 라이벌
- 고교 챕터, 사건, 관계 대사, 경기 시나리오
- 가상 대회 이름과 단계
- 프로 리그, 구단, 감독, 경쟁자, 라이벌 타자
- 기본 선수 이름 풀
- 각성, 재능, 성격, 별명, 유산, 커뮤니티 반응의 표시 문구
- 드래프트, 계약, 시즌 뉴스, 은퇴, 환생의 동적 문장 생성기
- 세계별 시간대와 통화 표기 정보

### 4.3 기존 API 호환

- `HighSchoolCareerEngine()`와 `ProCareerEngine()`의 기본 세계는 반드시 `.korea`다.
- 기존 테스트와 다른 클라이언트가 사용하는 `HighSchoolCareerEngine.regions`, `.teams`, `.schools(for:)`, `ProCareerEngine.proTeams`는 한국 콘텐츠를 반환하는 호환 API로 남긴다.
- 신규 iOS 코드는 정적 한국 API를 호출하지 않고 주입된 세계의 엔진 또는 콘텐츠 팩을 사용한다.
- 기계 규칙 함수에는 세계를 넣지 않는다. 표시 콘텐츠 또는 콘텐츠 선택에만 세계를 전달한다.
- 같은 시드와 같은 입력에서 능력 성장, 경기 확률, 드래프트 평가 수치는 세계와 무관하게 같아야 한다.
- 구단 수 차이로 선택되는 구단 ID는 달라질 수 있지만 지명 성공 여부와 평가 점수는 달라지지 않아야 한다.

### 4.4 iOS 런타임 컨텍스트

다음 파일을 추가한다.

```text
apps/ios/Sources/Localization/
├── AppLanguage.swift
├── AppLocalization.swift
├── Localizable.xcstrings
└── WorldPreferenceStore.swift

apps/ios/Sources/World/
├── GameWorldRuntime.swift
├── GameWorldRoot.swift
└── WorldSaveNamespace.swift
```

권장 책임은 다음과 같다.

```swift
struct GameWorldRuntime: Sendable {
    let worldID: GameWorldID
    let language: AppLanguage
    let locale: Locale
    let calendar: Calendar
    let saveNamespace: WorldSaveNamespace
}
```

- `BaseballApp`은 전역 설정인 `WorldPreferenceStore`만 소유한다.
- `GameWorldRoot`가 세계별 `WeeklyProgramStore`, `HighSchoolCareerStore`, `MobileCareerStore`를 생성한다.
- 세계를 바꾸면 기존 저장을 삭제하지 않고 `GameWorldRoot`의 identity를 바꿔 해당 세계 스토어를 새로 만든다.
- 세계 전환 전 진행 중 투구가 있으면 저장 체크포인트를 확정하고 확인창을 띄운다.
- SwiftUI 루트에 `.environment(\.locale, runtime.locale)`를 적용한다.
- `String`을 반환하는 비-View 코드에서는 `AppLocalization`에 명시적인 locale을 전달한다. 기기 기본 locale에 암묵적으로 의존하지 않는다.

### 4.5 첫 실행 세계 선택 규칙

저장된 사용자 선택이 없을 때만 다음 순서로 결정한다.

1. 앱의 최우선 지원 언어가 일본어면 `.japan`.
2. 앱의 최우선 지원 언어가 한국어면 `.korea`.
3. 지원 언어가 둘 다 아니고 기기 지역이 일본이면 `.japan`.
4. 그 외는 `.korea`.

사용자 선택은 전역 키 `baseball.world.preferred`에 저장한다. 이 키는 진행 데이터가 아니므로 세계별로 나누지 않는다.

설정 화면에는 `言語と世界 / 언어와 세계` 섹션을 추가한다. 전환 확인 문구는 “진행이 삭제되는 것”이 아니라 “별도 저장으로 이동하는 것”을 정확히 설명한다.

---

## 5. 저장과 iCloud 분리 설계

### 5.1 키 정책

한국판은 기존 키를 그대로 사용한다. 별도 복사나 마이그레이션을 하지 않는다.

| 데이터 | 한국 세계 | 일본 세계 |
|---|---|---|
| 고교 | `baseball-mobile-highschool-v1.json` | `baseball-mobile-highschool-jp-v1.json` |
| 프로 | `baseball-mobile-pro-v1.json` | `baseball-mobile-pro-jp-v1.json` |
| 주간 | `baseball-weekly-program-v2.json` | `baseball-weekly-program-jp-v2.json` |
| 주간 outbox | 기존 주간 키 파생 | 일본 주간 키 파생 |
| 업적 로컬 원장 | `baseball.achievements.v1` | `baseball.achievements.jp.v1` |
| 마지막 선수 설정 | `baseball.lastSetup` | `baseball.jp.lastSetup` |
| 종료된 일일 모드 레거시 | 기존 `baseball.daily.*`를 읽기 전용 보존 | 신규 키·기록 생성 안 함 |
| 최고 구속·릴리스 | 기존 키 | `baseball.jp.*` 대응 키 |
| 알림 계획·처리 | 기존 키 | `baseball.jp.daily.reminder.*` |
| 분석 1회 플래그 | 기존 키 | 세계 ID가 포함된 신규 키 |

입력 방식, 소리, 음악, 진동, 알림 권한 허용 여부, 익명 분석 stable ID는 앱 전역으로 공유한다.

### 5.2 저장 레코드 세계 가드

`HighSchoolCareerStore.SaveRecord`와 `MobileCareerStore.ProSaveRecord`에 아래 옵셔널 필드를 추가한다.

```swift
var worldID: GameWorldID? = nil
var contentVersion: Int? = nil
```

규칙:

- 한국 키에서 `worldID == nil`인 레거시 레코드는 `.korea`로 인정한다.
- 일본 키에서는 `worldID == .japan`만 live 데이터로 인정한다.
- 명시된 world ID가 현재 런타임과 다르면 로드하지 않고 사용자에게 복구 가능한 오류를 보여 준다.
- 세계 불일치는 삭제나 tombstone 기록으로 바꾸지 않는다.
- 콘텐츠 버전이 오래돼도 스냅숏을 열 수 있어야 한다. 이미 저장된 이름과 뉴스는 역사 기록으로 보존한다.
- 새 사건과 새 선수만 현재 콘텐츠 버전을 사용한다.
- 세계 전환은 저장 파일 rename, copy, clear를 수행하지 않는다.

### 5.3 세계별 부가 상태

다음 항목도 진행으로 간주해 세계별로 나눈다.

- 주간 프로그램과 지급 영수증
- 회차 목표, 숙적 원장, 마지막 설정
- 한국 세계의 종료된 일일 모드 레거시 시도 횟수·최고점·플레이 날짜(읽기 전용, 일본 세계로 복사하지 않음)
- 최고 구속, 최고 릴리스, 최고 헛스윙 기록
- 알림에 저장된 선수의 다음 행동
- 온보딩·첫 투구·첫 경기의 1회 분석 플래그

다음 항목은 앱 전역으로 유지한다.

- 오디오·진동·자동 릴리스 설정
- 알림 시스템 권한
- 리뷰 요청 cooldown
- 익명 분석 사용자 ID
- Game Center 계정 인증

### 5.4 업적과 Game Center

- 앱 안 업적 원장은 세계별 키를 사용한다.
- `AchievementStore.shared`는 제거하지 않아도 되지만 `activate(world:)`로 현재 원장을 교체할 수 있어야 한다.
- 세계 전환 시 `freshlyUnlocked`를 비우고 해당 세계 원장을 읽는다.
- Game Center achievement/leaderboard ID는 기존 값을 유지한다.
- Game Center는 계정 단위 통합 기록이므로 한 세계에서 달성한 업적이 다른 세계에서도 시스템상 달성된 것으로 보일 수 있다. 앱 내부 목록은 각 세계의 로컬 원장을 표시한다.
- App Store Connect의 Game Center 제목·설명을 일본어로 현지화한다.
- 종료된 일일 리더보드에는 새 점수를 제출하지 않고 일본 출시 화면에도 노출하지 않는다.

### 5.5 알림 전환

- 알림 권한과 on/off 설정은 전역으로 유지한다.
- 알림 계획, 문구, request identifier는 세계별로 분리한다.
- 세계 전환 시 이전 세계의 pending request를 제거하고 새 세계의 현재 진행으로 다시 예약한다.
- 일본 세계는 `Asia/Tokyo`, 한국 세계는 `Asia/Seoul` 날짜 키를 사용한다.
- 두 시간대의 UTC offset이 같더라도 코드에서 명시적으로 분리한다.
- 일본 알림에 한국 선수명, 한국 학교명, 한국어 문장이 한 글자라도 나오면 출시 차단이다.

---

## 6. 일본 세계 콘텐츠 명세

### 6.1 지리

일본 세계는 8개 지역권과 47개 도도부현을 모두 포함한다.

| 지역권 ID | 표시명 | 도도부현 |
|---|---|---|
| `hokkaido` | 北海道 | 北海道 |
| `tohoku` | 東北 | 青森県, 岩手県, 宮城県, 秋田県, 山形県, 福島県 |
| `kanto` | 関東 | 茨城県, 栃木県, 群馬県, 埼玉県, 千葉県, 東京都, 神奈川県 |
| `chubu` | 中部 | 新潟県, 富山県, 石川県, 福井県, 山梨県, 長野県, 岐阜県, 静岡県, 愛知県 |
| `kinki` | 近畿 | 三重県, 滋賀県, 京都府, 大阪府, 兵庫県, 奈良県, 和歌山県 |
| `chugoku` | 中国 | 鳥取県, 島根県, 岡山県, 広島県, 山口県 |
| `shikoku` | 四国 | 徳島県, 香川県, 愛媛県, 高知県 |
| `kyushu_okinawa` | 九州・沖縄 | 福岡県, 佐賀県, 長崎県, 熊本県, 大分県, 宮崎県, 鹿児島県, 沖縄県 |

각 도도부현 데이터는 다음 필드를 가진다.

```swift
struct PrefectureContent: Codable, Equatable, Sendable {
    let id: String              // 예: "jp_13_tokyo"
    let regionID: String
    let displayName: String     // 東京都
    let shortName: String       // 東京
    let reading: String         // とうきょうと
    let representativeCities: [String]
    let flavor: String
}
```

### 6.2 고교

- 도도부현마다 네 가지 기존 학교 철학을 유지한다.
- 총 `47 × 4 = 188`개 가상 고교를 제공한다.
- 학교 철학 ID와 기계 효과는 한국판과 동일하게 유지한다.
- 학교 선택 UI는 `지역권 → 도도부현 → 네 학교` 순서로 표시한다.
- 마지막으로 선택한 지역권은 UI 편의 값으로 저장해도 되지만 새 선수의 지역은 도도부현 ID로 저장한다.

학교 레코드 필수 필드:

```swift
struct JapanSchoolContent: Codable, Equatable, Sendable {
    let id: String
    let prefectureID: String
    let city: String
    let schoolID: SchoolID
    let name: String
    let reading: String
    let philosophy: String
    let coachName: String
    let coachReading: String
    let coachArchetype: String
    let coachPersonality: String
    let coachRecord: String
    let catcherName: String
    let catcherReading: String
    let catcherArchetype: String
    let catcherPersonality: String
    let catcherRecord: String
    let tradeoff: String
}
```

콘텐츠 수용 기준:

- 학교 이름 188개가 모두 고유하다.
- 감독과 포수의 화면 표시 전체 이름도 같은 학교 목록 안에서 중복되지 않는다.
- 각 이름에 히라가나 reading이 있다.
- 실존 고교 전체 이름과 정확히 일치하지 않는다.
- 특정 실존 학교의 한 글자 치환으로 보이는 이름이 없다.
- 지역의 지명·산·강·바다·역사적 어휘를 사용할 수 있지만 실제 학교 고유 브랜드는 피한다.
- 이름만 보고 어느 도도부현 또는 지역권 분위기인지 짐작할 수 있어야 한다.
- 같은 접미사와 조어를 전국에 반복해 자동 생성 목록처럼 보이게 하지 않는다.

### 6.3 고교 대회

- 실제 대회명을 사용하지 않는다.
- UI의 일반 설명은 `地区予選`, `全国大会`, `春の全国大会`, `夏の全国大会`처럼 보통명사로 쓴다.
- 서사에서 쓰는 고유 대회명은 독자 명칭으로 두 개 이상 만든다.
- 봄 초청형 전국대회와 여름 전국선수권형 대회의 감정적 역할은 살리되 실제 명칭, 로고, 우승기, 구장명은 사용하지 않는다.
- 기존 8개 챕터와 중요 경기 횟수는 유지한다.
- `TournamentBanner2/4/6/8` 이미지는 문자와 실존 표식이 없는 한 그대로 사용한다.

### 6.4 프로 리그와 구단

- 일본 세계에는 12개 가상 프로 구단과 2개 독자 리그를 둔다.
- 리그는 각각 6개 구단이다.
- 교류전, 정규시즌, 포스트시즌, 결승 시리즈 역할은 구현하되 실존 브랜드명은 쓰지 않는다.
- 현재 프로 커리어의 주차 수, 성장, 승격, 보직, 은퇴 규칙은 변경하지 않는다.

권장 연고 도시 슬롯:

```text
札幌 / 仙台 / さいたま / 千葉 / 東京 / 横浜 /
名古屋 / 京都 / 大阪 / 神戸 / 広島 / 福岡
```

구단 데이터 필수 필드:

```swift
struct ProClubContent: Codable, Equatable, Sendable {
    let id: String
    let leagueID: String
    let homePrefectureID: String
    let homeCity: String
    let name: String
    let reading: String
    let shortDisplayName: String
    let need: TrainingFocus
    let demand: Int
    let developmentPlan: String
    let positionCompetitor: PersonContent
    let manager: PersonContent
}
```

수용 기준:

- 12개 ID, 전체 이름, 짧은 이름이 모두 고유하다.
- 실존 구단명, 통용 약칭, 대표 동물·도시·색상 조합을 복제하지 않는다.
- 두 리그 이름은 독자 명칭이며 실존 양대 리그와 발음·약칭이 겹치지 않는다.
- 한국 세계의 기존 10개 구단 데이터와 테스트는 그대로 유지한다.
- `LeagueTable`과 드래프트 팀 선택은 현재 세계의 구단 목록을 입력으로 받는다.
- 팀 수를 하드코딩한 테스트와 UI를 모두 제거하고 콘텐츠 팩의 팀 수를 기준으로 계산한다.

### 6.5 인물 이름

- 주인공 기본 이름, 고교 라이벌 8명 이상, 프로 라이벌 12명, 주요 감독·포수는 과장된 한자 이름과 기억하기 쉬운 reading을 사용한다.
- 일반 로스터는 실제 명단처럼 자연스러운 이름을 쓴다.
- 유명 실존 선수와 전체 이름이 일치하지 않게 한다.
- 유명 만화·게임 캐릭터와도 전체 이름이 정확히 겹치지 않게 검색한다.
- 주역 이름은 읽기 어려울 수 있으므로 프로필과 첫 등장에 후리가나를 보여 준다.
- 표와 경기 중 반복 표시는 성 또는 짧은 표시 이름만 사용해 정보 밀도를 줄인다.

기존 스냅숏에 다음 옵셔널 필드를 추가한다. 모든 신규 필드는 구저장 디코딩을 보존해야 한다.

- `PlayerIdentitySnapshot.nameReading`
- `SchoolSnapshot.nameReading`, 감독·포수 reading
- `RivalSnapshot.nameReading`
- `DraftTeamSnapshot.nameReading`, `leagueID`, `homeCity`
- `ProRivalBatter.nameReading`

일본어 선수 생성 화면에는 이름과 선택적 `ふりがな` 입력을 제공한다. 사용자가 reading을 입력하지 않으면 임의로 추측하지 않고 생략한다.

### 6.6 문체

일본어 편집 기준:

- 시스템 안내는 짧고 명확한 현대 일본어.
- 관계 대사는 한 화면에서 한 호흡으로 읽히게 작성.
- 대사 한 문장에 설정 설명을 몰아넣지 않는다.
- 자기풍자, 승부욕, 짧은 반전은 허용한다.
- 야구 기록과 판정은 농담으로 흐리지 않는다.
- 사투리를 모든 문장에 표기하지 않는다. 어미나 핵심 감탄사 한두 곳으로 지역성을 준다.
- 한국어 조사 처리용 `KoreanCopy.particle`은 일본 세계 문장에서 호출하지 않는다.
- 직역투인 `信頼を上げる`, `能力値が適用される`를 반복하지 말고 실제 인물 행동과 결과로 쓴다.
- `転生`을 설명할 때 `次の選手へ記憶と技術を受け継ぐ`를 기준 문장으로 사용한다.

### 6.7 일본 야구 표기

| 한국 표시 의미 | 일본판 기준 |
|---|---|
| 1군 / 2군 | 一軍 / 二軍 |
| 탈삼진 | 奪三振 |
| 볼넷 | 四球 |
| 방어율 | 防御率 |
| 이닝 | 投球回 또는 문맥상 `回` |
| 선발 | 先発 |
| 긴 이닝 구원 | ロングリリーフ |
| 필승조 | セットアッパー |
| 마무리 | クローザー |
| 드래프트 지명 | ドラフト指名 |
| 승-패-무 | 勝–敗–分 |

- 구속 단위 `km/h`, ERA, WHIP, OPS 등 익숙한 기록 약어는 유지한다.
- 일본 숫자·날짜·통화 포맷은 `FormatStyle`과 명시적 `ja_JP` locale을 사용한다.
- 프로 계약 금액은 일본 세계에서 JPY로 표시하고 소수점 없는 엔화를 사용한다.
- 금액은 게임 밸런스에 사용되지 않으므로 세계별 표시 통화가 기계 결과를 바꾸지 않게 한다.

---

## 7. 문자열 현지화 구현

### 7.1 문자열 분류

모든 사용자 문구를 다음 두 계층으로 나눈다.

1. **앱 UI 문구**: 버튼, 탭, 설정, 오류, 접근성, 안내, 포맷 라벨. `Localizable.xcstrings` 사용.
2. **세계 콘텐츠 문구**: 학교, 인물, 사건, 대사, 뉴스, 대회, 구단. `WorldContentProviding` 사용.

세계 콘텐츠를 String Catalog에 넣지 않는다. 한국과 일본이 서로 다른 고유명사와 세계 구조를 가지므로 번역 키-값 관계가 아니다.

### 7.2 String Catalog 규칙

- 키는 한국어 원문이 아니라 `settings.title`, `pitch.release.perfect` 같은 의미 키를 사용한다.
- 모든 키에 `ko`, `ja` 값을 넣는다.
- interpolation과 복수형은 String Catalog variation 또는 타입 안전 함수로 처리한다.
- 문자열을 이어 붙여 일본어 어순을 만들지 않는다.
- `Text(dynamicString)`은 이미 현지화된 동적 문구에만 사용한다.
- 접근성 label, hint, confirmation dialog, error message, notification UI도 같은 목록에 포함한다.
- `String(format:)`에 locale을 생략하지 않는다.
- 한국어 기본값은 기존 출시 문구와 동일하게 유지한다.

### 7.3 우선 변환 파일

다음 순서로 변환한다.

1. `BaseballApp.swift`, `AppShell.swift`, `OpeningView.swift`, `SettingsView.swift`
2. `HighSchoolSetupView.swift`, `HighSchoolCareerView.swift`, `HighSchoolPresentation.swift`
3. `PitchView.swift`, `PitchDramaView.swift`, `DeliveryControl.swift`, `PitchScenario.swift`, `PitchSession.swift`
4. `CareerFlowView.swift`, `MobileCareerStore.swift`, `LeagueView.swift`
5. `DailyReminder.swift`, `DailyStreak.swift`, `WeeklyProgram*.swift`
6. `Achievements*.swift`, `GameCenterBoardView.swift`, `RecordView.swift`
7. `LifeArchiveView.swift`, `LifeCardView.swift`, `RunRecapView.swift`, `ShareSheet.swift`
8. 나머지 접근성·오류·보조 문구 파일

### 7.4 Info.plist와 앱 이름

`apps/ios/project.yml`을 원본으로 다음 리소스를 포함한다.

```text
apps/ios/Sources/ko.lproj/InfoPlist.strings
apps/ios/Sources/ja.lproj/InfoPlist.strings
```

값:

```text
ko: CFBundleDisplayName = "야구 못하면 또 환생함";
ja: CFBundleDisplayName = "野球がダメならまた転生";
```

- 개발 언어는 `ko`로 유지한다.
- known region에 `ko`, `ja`, `Base`를 포함한다.
- `project.yml`을 수정하고 XcodeGen으로 프로젝트를 재생성한다.
- 생성된 프로젝트에서 Japanese localization과 String Catalog가 target membership에 포함됐는지 확인한다.

### 7.5 현지화 누락 검사

`tools/check-ios-localization.mjs`를 추가하고 package script `check:ios-localization`으로 연결한다.

검사 항목:

- `Localizable.xcstrings`의 모든 키에 ko/ja 값 존재
- 번역 상태가 `stale`, `needs_review`, 빈 문자열이 아님
- 일본 세계 콘텐츠의 필수 reading 누락 없음
- 일본 런타임 문자열에 한글 음절 없음
- 한국 런타임 문자열에 일본 세계 고유명이 섞이지 않음
- 일본 사용자 문구에 금지된 실존 IP와 죽음 표현 없음
- `CFBundleDisplayName` 현지화 존재
- 알림·공유 카드·접근성 문구가 검사 대상에서 제외되지 않음

주석의 한국어는 허용한다. 검사는 Swift 문자열 literal과 콘텐츠 데이터만 대상으로 삼는다.

---

## 8. 엔진과 표현 코드 변경 지도

### 8.1 `HighSchoolCareer.swift`

- 한국 지역·학교·캐스트·팀 배열을 `KoreaWorldContent`로 이동한다.
- `HighSchoolCareerEngine`에 `worldID` 또는 content provider를 주입한다.
- `start`에서 현재 세계의 학교, 라이벌, 챕터, 팀을 사용한다.
- `schools(for:)`, 드래프트 팀 선택, 프로로그 뉴스, 동적 결과 문장을 콘텐츠 제공자에 위임한다.
- 기계 수치와 RNG 소비 순서는 변경하지 않는다.
- 콘텐츠 배열 길이가 RNG 결과를 바꾸는 곳은 세계별로 허용하되 한국 세계의 기존 결과는 고정한다.
- 한국 기본 엔진의 대표 시드 golden snapshot을 리팩터링 전후 비교한다.

### 8.2 `HighSchoolContentCatalog.swift`

- 사건과 시나리오의 stable ID, inning, outs, runners, leverage, score differential은 공통 기계 데이터로 유지할 수 있다.
- title, summary, narrative는 세계별 콘텐츠로 분리한다.
- 일본 시나리오는 같은 기계 상황을 일본 고교야구 문맥으로 다시 쓴다.
- 모든 세계에서 scenario ID와 RNG 순서는 안정적으로 유지한다.

### 8.3 `RelationshipVoiceCatalog.swift`

- scene/aftermath API에 세계를 전달한다.
- 한국 조사 처리와 일본 문장 생성을 분리한다.
- 한국 대사 fallback을 일본에서 사용하지 않는다.
- 일본 대사는 짧은 웹소설 톤과 제한된 사투리 규칙을 따른다.

### 8.4 기타 공유 콘텐츠 파일

아래 파일의 기계 ID와 표시 문구를 분리한다.

- `AwakeningTree.swift`
- `CareerSignatureLegacy.swift`
- `CareerWind.swift`
- `ChapterGoal.swift`
- `CommunityBuzz.swift`
- `Nickname.swift`
- `Personality.swift`
- `PersonalityTrait.swift`
- `PitcherPresetCatalog.swift`
- `Talent.swift`
- `RivalMemory.swift`
- `SignSituation.swift`

원칙:

- enum raw value와 분석 ID는 번역하지 않는다.
- 화면 title/detail만 세계별 콘텐츠로 제공한다.
- 저장된 title/detail은 과거 기록으로 존중한다.
- 새로운 콘텐츠 선택은 현재 세계 팩만 사용한다.

### 8.5 `ProCareer.swift`

- 프로 구단 목록, 라이벌, 감독, 경쟁자, 시즌 뉴스, 계약·승격·보직·은퇴 문장을 세계별로 분리한다.
- `ProCareerEngine(world:)`를 추가하고 기본값은 `.korea`다.
- `HighSchoolCareerEngine.teams` 직접 참조를 현재 콘텐츠 팩의 프로 구단 목록으로 바꾼다.
- 10팀 하드코딩을 제거하고 일본 세계의 12팀을 수용한다.
- 시즌 길이, 승격 임계값, 부상 확률, 역할 결정, 은퇴 규칙은 바꾸지 않는다.
- 일본 세계에서 군 복무 관련 문구·시스템이 노출되는지 감사한다. 한국에만 의미 있는 표현은 일본 세계에서 동일한 기계 효과를 가진 일반적인 커리어 공백 또는 재활·조정 기간으로 표현하되, 기계 규칙 변경이 필요하면 별도 결정 기록을 남긴다.

### 8.6 `PitchKernelEngine.swift`와 투구 표시

- 판정 enum, 수치, RNG는 유지한다.
- 판정 설명과 코칭 문구는 stable result ID에서 세계별 문구로 변환한다.
- `PitchScenario`에 `worldID`를 넣거나 세션 생성 시 world를 명시한다.
- `PitchSession` 복원 시 현재 저장 envelope의 세계를 사용한다.
- 일본판에서는 볼카운트, 주자, 아웃, 판정, 릴리스 피드백을 일본 야구 용어로 표시한다.
- 영어 심판 음성은 양 세계에서 재사용한다. 현재 녹음은 한국어 음성이 아니므로 신규 녹음은 필수 범위가 아니다.

### 8.7 iOS Store 객체

`HighSchoolCareerStore`와 `MobileCareerStore` 생성자에 다음을 주입한다.

- `GameWorldRuntime`
- 세계별 엔진
- 세계별 `SaveSync`
- 세계별 `WeeklyProgramStore`

스토어가 직접 `HighSchoolCareerEngine.regions` 같은 한국 정적 데이터를 참조하지 않게 한다. 화면이 필요한 지역·학교·팀 데이터는 스토어 또는 runtime content를 통해 받는다.

### 8.8 한국어 전용 표현 도우미

- `KoreanCopy.particle` 호출부를 전수 검색한다.
- 한국 세계에서만 호출되게 하거나 세계별 문장 생성기로 이동한다.
- 일본 세계에서 조사 함수가 호출되면 테스트 실패로 처리한다.
- 어순이 다른 문장을 문자열 조각 조합으로 해결하지 않는다.

---

## 9. 분석 계측

### 9.1 공통 속성

모든 Firebase와 Amplitude 이벤트에 다음 낮은 카디널리티 속성을 추가한다.

```text
world_id = kr | jp
app_language = ko | ja
world_content_version = integer
```

- 기존 event name은 변경하지 않는다.
- `distribution`, `environment`, `ingestion_origin` 등 기존 또는 계획된 데이터 품질 속성을 보존한다.
- `Locale.current.region`을 App Store storefront로 기록하지 않는다. 기기 지역과 구매 국가를 같은 값으로 취급하면 안 된다.
- 일본 판매의 결제 원본은 App Store Connect의 Japan territory 보고서다.

### 9.2 1회 이벤트

- `onboarding_started`, `onboarding_completed`, `first_pitch`, `activation_first_game`의 once key를 세계별로 나눈다.
- 동일 stable user가 한국과 일본 세계를 각각 처음 시작하면 각 세계에서 한 번씩 기록된다.
- 이벤트 분석 단위는 `user_id + world_id`로 정의한다.
- 기존 한국 once key는 한국 세계에서 그대로 존중해 중복 activation을 만들지 않는다.

### 9.3 신규 권장 이벤트

```text
world_activated
world_switched
```

필수 속성:

| 이벤트 | 속성 |
|---|---|
| `world_activated` | `world_id`, `selection_source=automatic|saved|settings`, `has_existing_save` |
| `world_switched` | `from_world`, `to_world`, `from_has_save`, `to_has_save` |

고유 선수명, 학교명, 사용자 입력 이름은 분석 속성으로 보내지 않는다.

### 9.4 출시 지표

| 역할 | 지표 | 원본 |
|---|---|---|
| 매출 원본 | 일본 결제 매출·판매 건수 | App Store Connect Sales and Trends |
| 선행 유입 | 일본 세계 신규 고유 사용자 | Amplitude `world_id=jp`, production/app_store |
| 활성화 | `activation_first_game / onboarding_started` | Amplitude 고유 사용자 순서형 퍼널 |
| 반복 | D1 의미 경기 복귀 | Amplitude |
| 품질 | 크래시·저장 실패·언어 누락 | Xcode Organizer, 테스트, 사용자 리뷰 |

판매 보고서가 없는 최신 1~2일은 Amplitude로 임시 추정할 수 있지만 최종 누적 매출표에는 확정 판매 보고서만 입력한다.

---

## 10. 이미지·공유 카드·스토어 자산

### 10.1 앱 내부 이미지

- `Assets.xcassets`의 모든 raster 자산을 사람 눈과 OCR로 다시 검사한다.
- 문자나 실존 표식이 없는 키아트·인물·배경은 그대로 사용한다.
- `LaunchLogo`는 한국어 문자가 있으므로 한국·일본 자산을 분리한다.
- 일본 로고는 기존 붓글씨 질감, 크림색, 녹색 그림자, 투명 배경, 동일 안전 여백을 유지한다.
- 일본 로고 이미지 안의 `野球がダメなら また転生` 문자는 생성 단계에서 직접 렌더링한다. 후처리 합성으로 붙이지 않는다.

권장 launch 구조:

```text
apps/ios/Sources/Assets.xcassets/LaunchLogoKO.imageset
apps/ios/Sources/Assets.xcassets/LaunchLogoJA.imageset
apps/ios/Sources/ko.lproj/LaunchScreen.storyboard
apps/ios/Sources/ja.lproj/LaunchScreen.storyboard
```

- 두 storyboard는 배경색·로고 위치·크기를 동일하게 유지하고 image name만 다르게 한다.
- 현재 `UILaunchScreen` dictionary에서 localized launch storyboard 방식으로 전환한다.
- 실제 cold launch에서 일본 기기가 한국 로고를 한 프레임이라도 보여 주지 않는지 확인한다.
- localized storyboard가 대상 OS에서 안정적으로 동작하지 않으면 시스템 launch 화면은 문자 없는 공통 심볼로 만들고, 첫 SwiftUI 프레임에서 현지화 제목을 표시한다. 한국어 로고를 일본 사용자에게 노출하는 fallback은 금지한다.

### 10.2 공유 카드

- `LifeCardView.swift`와 share image 테스트를 세계별로 실행한다.
- 제목, 선수명, 학교명, 구단명, 기록 단위, 환생 문구를 일본어로 렌더링한다.
- 일본 이름의 후리가나는 공유 카드에서 공간이 충분할 때만 표시한다.
- 6.9인치 화면과 공유 이미지 고정 캔버스에서 잘림이 없어야 한다.
- 한국 카드의 픽셀 또는 레이아웃 기준선이 의도치 않게 변하지 않아야 한다.

### 10.3 App Store 스크린샷

다음 경로를 만든다.

```text
marketing/appstore/ja-JP/
├── STORE_COPY.md
├── SCREENSHOT_PLAN.md
├── screenshots-6.9/
└── evidence/
```

스크린샷은 8장을 권장한다.

1. `野球がダメなら、また転生。` — 핵심 훅과 실제 게임 화면
2. `高校3年間で、ドラフト指名をつかめ` — 고교 성장
3. `一球ずつ、自分で勝負する` — 직접 투구
4. `記憶と技術を、次の投手へ` — 죽음 없는 환생
5. `47都道府県、188の架空高校` — 일본 세계
6. `12球団、二つの架空リーグ` — 프로 세계
7. `高校から引退まで、一人の野球人生` — 전체 커리어
8. 한국 유료 스포츠 1위 이력 또는 기록·공유

규칙:

- 실제 앱 화면이 각 이미지의 중심이어야 한다.
- 기존 아트와 레이아웃을 유지하고 일본어 caption만 현지화한다.
- 가격을 스크린샷에 넣지 않는다.
- 한국 순위 이력을 쓸 경우 `韓国App Store 有料スポーツランキング1位（2026年8月）`처럼 국가·유료·카테고리·시점을 모두 적는다.
- 순위 증빙을 `evidence/`에 보관하고 사실 확인이 끝나기 전에는 8번 이미지에 넣지 않는다.

---

## 11. App Store Connect 작업

코드 밖에서 수행하지만 출시 완료 조건에 포함한다.

### 11.1 일본 현지화 메타데이터

| 필드 | 확정 또는 작성 기준 |
|---|---|
| Name | `野球がダメならまた転生：投手育成` |
| Subtitle | `高校からプロへ、人生を継ぐ野球育成` |
| Promotional text | `野球がダメなら、また転生。記憶と技術を次の投手へ。` |
| Description | 일본 세계·직접 투구·고교 3년·프로 커리어·죽음 없는 계승을 앞부분에 설명 |
| Keywords | 野球, 投手, 育成, シミュレーション, 転生, ドラフト 등; 실존 IP 제외 |
| What’s New | 일본어 지원과 일본 가상 야구 세계 추가를 구체적으로 명시 |
| Support URL | 일본어 문의가 가능한 기존 또는 신규 지원 페이지 |
| Privacy URL | 기존 정책을 유지하되 일본어 요약 또는 일본어 페이지 제공 |

### 11.2 가격

1. 일본 territory 가격을 출시 시점 `¥500`으로 예약한다.
2. 출시 8일째 `¥800`으로 오르는 가격 변경을 미리 예약한다.
3. 다른 territory 가격이 자동으로 바뀌지 않았는지 저장 직후 다시 확인한다.
4. 한국 `₩4,400`을 확인한다.
5. 앱 설명과 스크린샷에는 가격을 하드코딩하지 않는다.

### 11.3 Game Center

- 기존 achievement와 leaderboard ID에 일본어 제목·설명을 추가한다.
- 앱 내부의 일본어 제목과 App Store Connect 제목이 같은지 대조한다.
- 종료된 일일 leaderboard에는 새 점수를 제출하거나 일본어 화면에서 진입점을 만들지 않는다. App Store Connect의 기존 설정은 이번 출시에서 삭제하지 않는다.
- sandbox 계정으로 제출 전 실제 표시를 확인한다.

### 11.4 심사 노트

심사 노트에 다음을 적는다.

- 기존 유료 앱에 일본어와 일본 가상 야구 세계를 추가한 업데이트
- 기기 언어가 일본어이면 일본 세계가 기본으로 선택됨
- 설정에서 한국·일본 세계 전환 가능, 저장은 서로 독립
- 모든 구단·학교·대회·선수는 가상이며 실제 조직 라이선스를 주장하지 않음
- 앱 구매 후 추가 결제 없음
- Game Center와 iCloud는 실패해도 게임 진행 가능

---

## 12. 구현 작업 순서

각 작업은 앞 작업의 수용 기준을 통과한 뒤 진행한다. 콘텐츠 작성은 구조가 고정된 뒤 병행할 수 있다.

### P0. 기준선 고정

변경:

- 관련 파일의 기존 diff 기록
- 현재 Swift 테스트, copy 검사, iOS generic build 결과 기록
- 대표 한국 시드 3개에 대한 고교 시작 snapshot과 프로 시작 snapshot fixture 생성

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

- 기존 실패는 파일·줄·원인을 기록한다.
- 신규 구현 실패와 기존 실패를 구분할 수 있다.
- 사용자 변경을 건드리지 않는다.

### P1. 세계·언어 기반 추가

변경:

- `GameWorldID`, `WorldContentProviding`, registry 추가
- 기존 한국 콘텐츠를 Korea pack으로 이동 또는 adapter로 감싼다.
- `WorldPreferenceStore`, `GameWorldRuntime`, `GameWorldRoot` 추가
- `BaseballApp`을 세계 루트 구조로 변경
- `project.yml`에 ko/ja localization 추가

수용 기준:

- 기본 생성자에서 기존 한국 테스트가 통과한다.
- 일본어 locale 첫 설치는 `.japan`, 한국어는 `.korea`다.
- 설정 override가 앱 재실행 뒤 유지된다.
- 세계 전환으로 root store가 재생성된다.

### P2. 저장 네임스페이스 분리

변경:

- `WorldSaveNamespace` 추가
- 고교·프로·주간·업적·알림·best 기록 키 분리와 종료된 한국 일일 레거시의 비복사 보존
- 저장 envelope에 optional world/content version 추가
- `WeeklyProgramStore.shared`의 production 의존을 주입형 인스턴스로 대체
- `AchievementStore.activate(world:)` 추가

수용 기준:

- 기존 한국 저장 fixture를 byte migration 없이 로드한다.
- 일본 세계는 한국 키를 읽거나 쓰지 않는다.
- 양 세계에서 각각 진행 후 전환해도 두 진행이 그대로 복원된다.
- iCloud remote change가 현재 세계 스토어에만 적용된다.
- 일본 저장을 한국 세계로 주입한 테스트는 안전한 오류를 내고 데이터를 삭제하지 않는다.

### P3. UI String Catalog 전환

변경:

- `Localizable.xcstrings` 생성
- UI 정적 문구를 의미 키로 전환
- locale-aware formatter와 접근성 문구 전환
- InfoPlist localization 추가
- 설정의 언어·세계 전환 UI 추가

수용 기준:

- ko/ja 모든 키가 채워져 있다.
- 일본 UI 전체 흐름에 한국어 런타임 문자열이 없다.
- 한국 UI의 기존 문구 의미와 레이아웃이 유지된다.
- Dynamic Type XXXL에서 주요 버튼과 수치가 잘리지 않는다.

### P4. 일본 콘텐츠 팩 작성

변경:

- 8지역권·47도도부현
- 188학교와 캐스트
- 고교 사건·대사·시나리오
- 12구단·2리그·프로 캐스트
- 기본 선수·라이벌 이름
- 각성·재능·별명·성격·유산·뉴스 문구

수용 기준:

- 콘텐츠 수량 테스트 통과
- 모든 ID와 이름 고유성 통과
- reading 완전성 통과
- 실제 IP·죽음 표현 자동 검사 통과
- 일본어 편집자와 일본 야구 감수자의 승인 기록 존재
- placeholder, TODO, 한국어 fallback 없음

### P5. 엔진·화면 연결

변경:

- 고교/프로 엔진이 현재 world content 사용
- region/school selector를 8지역권→47도도부현로 변경
- PitchScenario/PitchSession 세계 문구 연결
- 프로 12구단 league table과 draft 연결
- 후리가나 표시
- currency/date/record format 일본화

수용 기준:

- 일본 신규 설치에서 일본 이름·학교·대회·구단만 나온다.
- 첫 시작부터 환생, 프로 은퇴까지 진행 가능하다.
- 한국 대표 시드의 numeric 결과가 기준 fixture와 같다.
- 일본 대표 시드도 저장·재실행 시 결정론적으로 같다.
- 기능 누락 없이 한국/일본 양쪽 smoke UI 테스트가 통과한다.

### P6. 알림·공유·업적·분석

변경:

- 일본 알림 문구와 Tokyo 날짜 키
- 일본 공유 카드
- Game Center 앱 내부 문구
- analytics world properties와 세계별 once key
- world activated/switched 이벤트

수용 기준:

- 알림, share image, achievement banner, error alert에 한국어 누락이 없다.
- 분석 이벤트에 PII 또는 선수·학교 고유명이 없다.
- 기존 event name과 production distribution filter가 유지된다.

### P7. 이미지와 스토어 자산

변경:

- 일본 launch logo와 localized launch screen
- 8개 일본 스크린샷
- 일본 store copy 문서

수용 기준:

- cold launch에서 언어가 잘못된 로고가 보이지 않는다.
- 일본 로고 글자가 이미지 안에서 자연스럽고 오탈자가 없다.
- 스크린샷이 실제 앱 경험을 보여 준다.
- 가격·실존 IP·검증되지 않은 순위 주장이 없다.

### P8. 전체 QA와 제출

변경:

- 버전 `1.1.0`, build는 현재 App Store build보다 큰 값으로 최종 단계에서 갱신
- Release archive 생성
- App Store Connect Japanese metadata, Game Center, 가격 예약
- 심사 노트 작성과 제출

수용 기준:

- 아래 Definition of Done 전부 통과
- archive validation 성공
- 일본어 metadata와 screenshot이 선택된 상태로 제출
- 한국 storefront의 이름·가격·스크린샷이 의도치 않게 바뀌지 않음

---

## 13. 3일 실행 일정

### Day 1 — 기반과 저장

| 시간 | 작업 | 게이트 |
|---|---|---|
| 0–2h | P0 기준선, dirty diff 보호, fixtures | 기존 동작 재현 |
| 2–6h | GameWorldID, content interface, Korea adapter | 한국 코어 테스트 통과 |
| 6–10h | GameWorldRoot, 자동 선택, 설정 전환 | locale/world 테스트 통과 |
| 10–14h | save namespace, weekly/achievement 분리와 종료된 일일 레거시 격리 | 양 세계 저장 격리 테스트 통과 |
| 14–18h | String Catalog 골격, InfoPlist localization | ko/ja 빌드 통과 |

### Day 2 — 일본 콘텐츠와 전체 화면

| 시간 | 작업 | 게이트 |
|---|---|---|
| 0–6h | 47도도부현, 188학교, 캐스트 | 콘텐츠 구조·고유성 검사 |
| 6–10h | 12구단, 2리그, 프로 캐스트 | league/draft 테스트 |
| 10–16h | 사건·대사·뉴스·각성·별명 transcreation | 일본어 편집 검수 |
| 16–22h | iOS UI, 접근성, 오류, 알림, 공유 카드 연결 | 일본 전체 문자열 검사 |
| 22–24h | 한국 회귀와 결정론 확인 | Korea golden 통과 |

### Day 3 — 자산, E2E, 제출

| 시간 | 작업 | 게이트 |
|---|---|---|
| 0–4h | 일본 launch logo, localized launch screen | cold launch QA |
| 4–8h | 일본 App Store 스크린샷·문구 | metadata 검수 |
| 8–14h | ko/ja 전체 E2E, 저장 전환, iCloud, Game Center | P0/P1 결함 0 |
| 14–18h | Release build/archive, organizer 확인 | archive validation |
| 18–22h | ASC 가격·현지화·심사 노트 | 제출 준비 완료 |
| 22–24h | 최종 diff/금칙어/한국 storefront 확인, 제출 | 심사 제출 |

일정이 밀릴 때 줄일 수 있는 것은 한국 1위 보조 스크린샷과 마케팅 부가 문구다. 저장 분리, 전체 기능, 일본 세계 콘텐츠, 일본어 QA는 줄이지 않는다.

---

## 14. 테스트 계획

### 14.1 공유 코어 단위 테스트

신규 권장 파일:

```text
packages/simulation-core/Tests/SimulationCoreTests/WorldContentTests.swift
packages/simulation-core/Tests/SimulationCoreTests/JapanWorldContentTests.swift
packages/simulation-core/Tests/SimulationCoreTests/WorldDeterminismTests.swift
```

필수 케이스:

1. 기본 engine world는 Korea.
2. 일본 8지역권·47도도부현·188학교.
3. 일본 12구단·리그당 6구단.
4. ID, 이름, reading 고유성과 완전성.
5. 모든 학교가 유효한 도도부현과 네 철학 중 하나에 속함.
6. 모든 구단이 유효한 리그와 연고 도시에 속함.
7. 한국 대표 시드 snapshot 회귀.
8. 일본 같은 시드·입력의 반복 실행 결과 동일.
9. 세계 간 numeric progression 비교에서 허용된 콘텐츠 필드 외 값 동일.
10. 금지된 실존 명칭과 죽음 표현 없음.

### 14.2 iOS 단위 테스트

신규 권장 파일:

```text
apps/ios/Tests/WorldPreferenceTests.swift
apps/ios/Tests/WorldSaveNamespaceTests.swift
apps/ios/Tests/WorldSaveIsolationTests.swift
apps/ios/Tests/LocalizationCoverageTests.swift
apps/ios/Tests/JapaneseFormattingTests.swift
apps/ios/Tests/JapaneseNotificationTests.swift
apps/ios/Tests/JapaneseShareCardTests.swift
apps/ios/Tests/WorldAnalyticsTests.swift
```

필수 케이스:

- ja/ko/기타 locale 기본 세계 결정
- saved override 우선순위
- 한국 legacy save의 nil world 허용
- 일본 save의 명시 world 필수
- cross-world load 거부와 비파괴
- 세계 전환 후 양쪽 진행 복원
- 세계별 weekly/outbox/lastSetup/achievement 분리와 종료된 한국 일일 레거시의 일본 세계 비노출
- audio/input/global permission 공유
- 일본 JPY, 날짜, 일군/이군, 경기 기록 표기
- 일본 알림 Tokyo day key와 일본어 copy
- 일본 share card 글자 잘림 없음
- 분석 공통 속성과 세계별 once 동작

### 14.3 UI 테스트

`apps/ios/UITests/JapaneseWorldSmokeUITests.swift`를 추가한다.

테스트 launch argument:

```text
-uiTestResetCareer
-uiTestAutoRelease
-uiTestWorld jp
-AppleLanguages (ja)
-AppleLocale ja_JP
```

필수 흐름:

1. 일본 첫 화면과 제목.
2. 이름·후리가나 입력.
3. 8지역권에서 도도부현 선택.
4. 네 가상 학교 선택.
5. 첫 불펜 투구.
6. 첫 공식 경기 완료.
7. 드래프트 결과.
8. 프로 진입과 12구단 중 하나 표시.
9. 기록·주간·설정 진입과 종료된 일일 딥 링크의 안전한 복귀.
10. 일본 공유 카드 생성.
11. 한국 세계로 전환 후 별도 저장 확인.
12. 다시 일본 세계로 전환해 이전 선수 복원.

한국 smoke test도 같은 build에서 다시 실행한다.

### 14.4 수동 QA 매트릭스

| 축 | 값 |
|---|---|
| 언어 | ko, ja |
| 설치 상태 | 신규, 기존 한국 저장, 양 세계 저장 존재 |
| 기기 | 작은 iPhone, 6.9인치 iPhone, 실제 기기 최소 1대 |
| 글자 크기 | 기본, 가장 큰 접근성 크기 |
| 네트워크 | 온라인, 오프라인 |
| iCloud | 로그인, 미로그인, 다른 기기 remote update |
| Game Center | 로그인, 미로그인 |
| 앱 수명주기 | cold launch, background/warm, 강제 종료 후 복원 |

출시 차단 결함:

- 크래시, 진행 불가, 저장 유실
- 일본판에 한국어 사용자 문구 노출
- 세계 전환으로 다른 세계 저장 삭제 또는 덮어쓰기
- 일본판에 실존 학교·구단·리그·선수 식별 요소 노출
- 죽음으로 환생을 설명하는 문구
- 일본 launch에서 한국어 로고 flash
- 버튼 잘림으로 주요 행동 수행 불가
- 한국판 기존 저장 또는 기능 회귀

---

## 15. 검증 명령

프로젝트 생성:

```sh
cd apps/ios
xcodegen generate
cd ../..
```

콘텐츠·문구 검사:

```sh
npm run check:copy
npm run check:ios-localization
rg -n 'NPB|日本野球機構|甲子園|死亡|事故死|死後|異世界転生' \
  apps/ios/Sources packages/simulation-core/Sources
```

`rg` 결과는 주석·검사 blocklist 안의 의도된 등장만 허용한다. 자동 검사가 같은 목록을 정확히 분류해야 한다.

공유 코어:

```sh
swift test --package-path packages/simulation-core
```

iOS generic build:

```sh
xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

설치된 simulator 확인 후 unit/UI test:

```sh
xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

archive 전 검증:

```sh
xcodebuild -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath artifacts/ios/Baseball-JP-1.1.0.xcarchive \
  archive
```

실행 환경에 해당 simulator가 없으면 임의의 이름을 가정하지 말고 `xcodebuild -showdestinations`로 실제 대상을 선택한다.

---

## 16. Definition of Done

### 코드

- [ ] 같은 bundle ID와 기존 앱 target 유지
- [ ] `GameWorldID`, content pack, runtime, save namespace 구현
- [ ] 한국 기본 API와 기존 저장 호환
- [ ] 일본 세계 저장 완전 분리
- [ ] 83개 한국어 포함 소스의 사용자 문구 분류 완료
- [ ] UI String Catalog ko/ja 완전성 통과
- [ ] 일본 세계 콘텐츠에 한국어 fallback 없음
- [ ] 분석 이벤트에 world/language/content version 포함

### 콘텐츠

- [ ] 8개 지역권
- [ ] 47개 도도부현
- [ ] 188개 가상 고교
- [ ] 12개 가상 프로 구단과 2개 가상 리그
- [ ] 고교·프로 주요 캐스트 reading
- [ ] 전체 사건·대사·뉴스 일본어 transcreation
- [ ] 죽음 없는 환생 표현
- [ ] 실존 IP·학교 혼동 검사와 사람 승인

### 기능

- [ ] 고교부터 프로 은퇴·환생까지 일본어 완주
- [ ] 주간 프로그램, 업적, Game Center, 공유, 알림 동일 제공
- [ ] 종료된 일일 모드의 진입·알림·신규 보상은 0개이고 레거시 키만 안전하게 보존
- [ ] 언어 전환 후 양 세계 저장 복원
- [ ] iCloud 충돌과 tombstone 회귀 없음
- [ ] 한국판 기능·밸런스·저장 회귀 없음

### 품질

- [ ] `swift test` 통과
- [ ] iOS Debug/Release build 통과
- [ ] ko/ja UI smoke 통과
- [ ] 작은 화면과 접근성 글자 크기 통과
- [ ] VoiceOver 핵심 흐름 통과
- [ ] cold launch 로고 언어 일치
- [ ] 출시 차단 결함 0건

### 스토어

- [ ] Japanese metadata 입력
- [ ] 일본 스크린샷 업로드
- [ ] Game Center 일본어 현지화
- [ ] 일본 가격 ¥500→¥800 예약
- [ ] 한국 가격 ₩4,400 확인
- [ ] 심사 노트와 지원 URL 확인
- [ ] App Store 심사 제출

---

## 17. 롤백 계획

### 17.1 코드 롤백

- 일본 세계 진입을 remote flag로 숨기는 구조를 새로 만들지 않는다. 오프라인 유료앱의 핵심 콘텐츠를 서버 상태에 의존시키지 않는다.
- 출시 차단 문제가 심사 전 발견되면 일본어 metadata와 Japan availability를 공개하지 않고 수정 build를 제출한다.
- 한국 세계는 기존 키와 기본 생성자를 유지하므로 일본 콘텐츠 오류가 한국 저장 migration으로 번지지 않게 한다.

### 17.2 출시 후 긴급 대응

- 일본 저장 손상 위험이 있으면 새 쓰기를 막는 수정 build를 최우선 제출하되 기존 일본 키를 삭제하지 않는다.
- 번역·콘텐츠 오류만 있으면 snapshot에 저장된 과거 기록은 그대로 두고 표시 정규화 또는 미래 사건 콘텐츠를 수정한다.
- 실존 명칭 충돌이 발견되면 해당 콘텐츠 ID는 유지하고 표시 이름만 새 독자 명칭으로 바꾼다.
- 가격 일정 오류는 App Store Connect에서 territory별로 수정하고 앱 업데이트와 결합하지 않는다.
- 한국 storefront metadata와 가격은 일본 긴급 수정 과정에서도 변경하지 않는다.

---

## 18. 실행 에이전트 작업 규약

1. 한 단계 시작 전 관련 파일과 테스트를 읽는다.
2. 구현 중 발견한 기존 동작을 문서 가정에 맞추려고 억지로 바꾸지 않는다.
3. 기계 규칙 변경과 콘텐츠 변경을 같은 diff에 섞지 않는다.
4. 한국 호환 adapter를 먼저 통과시킨 뒤 일본 콘텐츠를 연결한다.
5. 대규모 문자열 치환 후에는 파일 단위 검색이 아니라 전체 저장소 검사를 실행한다.
6. 새 필드는 optional/default를 사용해 기존 Codable 저장을 보존한다.
7. 삭제·초기화·키 rename으로 저장 호환 문제를 해결하지 않는다.
8. 실존 명칭 검사는 이름 생성 직후와 최종 release 직전에 두 번 한다.
9. 테스트가 실패하면 무시하거나 범위를 줄여 완료 처리하지 않는다.
10. 각 P 단계 완료 시 이 문서 아래 `결정 기록`에 실제 파일, 테스트 결과, 남은 위험을 남긴다.

---

## 19. 결정 기록

실행 에이전트가 아래 형식으로 누적한다.

```md
### YYYY-MM-DD / P단계 / 결정 제목

- 변경 파일:
- 결정:
- 이유:
- 호환성 영향:
- 실행한 테스트:
- 결과:
- 남은 위험:
```

문서 작성 시점에는 구현 변경을 수행하지 않았다.
