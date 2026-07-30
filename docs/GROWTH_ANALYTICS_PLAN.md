# Activation 검증 캠페인 + 데이터 분석 환경 구축 계획서

앱: **야구 못하면 또 환생함** (2026-07-30 작성, 코드 구현은 이미 저장소에 반영됨)

## 0. 입력 정보

| 항목 | 값 |
|---|---|
| 앱 설명 | 고교야구 투수를 3년간 육성해 프로 드래프트에 도전하고, 실패하면 야구혼을 계승해 환생하는 로그라이트. 사인 → 조준 → 투구의 실조작 손맛이 코어. **유료 ₩4,400, iOS.** |
| 플랫폼/스택 | iOS 네이티브 (SwiftUI, iOS 17+) |
| 분석 툴 | **Amplitude** (선택 이유: 이번 목표가 "반복 사용·이탈 지점" 확인인데, 무료 플랜 50k MTU에서 리텐션 차트·코호트가 가장 강력하고 Starter 템플릿으로 초보 셋업이 빠름) |
| 연동 스택 | Firebase / Google Ads (UAC) / Amplitude |
| 일 예산 | 10,000원 |
| 캠페인 기간 | 1주일 (D1~D7) |
| 타겟 지역 | 전 세계 |

> ### ⚠️ 유료 앱이라는 사실이 이 계획의 가장 큰 변수다
> UAC 저CPI 전략은 **무료 앱** 기준이다. ₩4,400 유료 앱은 광고를 본 사람이 결제까지 해야 설치가 잡히므로, 일 1만 원 예산으로는 **설치 0~2건**이 현실적이다. 그래서 이 계획은 두 갈래로 운영한다:
> - **A트랙(권장): 출시 첫 주 무료 프로모션 기간에 캠페인 실행.** 가격을 0원으로 내린 3~5일 동안 캠페인을 돌려 전 세계 실유저를 모으고 activation 퍼널을 채운다. 기간 종료 후 ₩4,400 복원(“지금이 최저가” 서사와도 맞음).
> - **B트랙: 유료 상태로 그대로 실행.** 설치는 거의 없겠지만 콘솔 셋업→소재→운영→분석의 전 사이클을 실비용으로 연습한다. 이 경우 activation 데이터의 주 공급원은 광고가 아니라 **TestFlight 테스터 + 오가닉 구매자**다.
> 어느 쪽이든 아래 구축 단계는 동일하다.

---

## 1. Activation 순간 정의

**activation 이벤트: `activation_first_game` — 첫 중요 경기 완료(첫 등판을 끝까지 던진 순간)**

- **왜 이 순간인가:** 이 게임의 가치는 "포수 사인을 읽고 → 코스를 조준하고 → 손으로 던지고 → 판정과 기록이 쌓이는" 코어 루프다. 첫 불펜 투구(`first_pitch`)는 너무 얕고(튜토리얼 1구), 드래프트 도달은 너무 늦다(수십 분). **첫 중요 경기를 끝까지 던졌다** = 코어 루프를 한 바퀴 완주했고 "이 게임이 뭔지" 이해했다는 가장 이른 증거다. 설치 후 약 3~5분 지점이라 광고 전환 신호로도 시차가 짧다.
- **1인 1회 보장:** 클라이언트에서 `UserDefaults` 플래그로 최초 1회만 전송(`GameAnalytics.logOnce`), 유닛 테스트로 고정. Google Ads 쪽에서도 전환 집계 방식을 "1회"로 설정(아래 3-C).

### 이벤트 설계 전체 (구현 완료)

| 이벤트 | 시점 | 1회? | 용도 |
|---|---|---|---|
| `onboarding_started` | 선수 만들기 진입 | ✓ | 퍼널 1단 |
| `onboarding_completed` | 커리어 생성 완료 | ✓ | 퍼널 2단 |
| `first_pitch` | 첫 불펜 투구 | ✓ | 퍼널 3단 |
| **`activation_first_game`** | **첫 중요 경기 완료** | **✓** | **퍼널 4단 = 광고 전환 목표** |
| `game_finished` (K/BB/실점) | 매 경기 | | 반복 사용 |
| `chapter_advanced` (chapter) | 챕터 전진 | | 진행 깊이 |
| `draft_resolved` (drafted/score) | 드래프트 | | 완주율 |
| `rebirth_started` (life_number) | 환생 | | **코어 리텐션** — 회차를 다시 시작하는 사람이 남는 사람 |
| `life_card_shared` | 카드 공유 | | 바이럴 신호 |

---

## 2. 코드 레벨 구현 — ✅ 완료 (저장소 반영)

- `apps/ios/Sources/GameAnalytics.swift` — Firebase Analytics + Amplitude 이중 전송 파사드. **설정이 없으면 전부 무동작**(GoogleService-Info.plist 없으면 Firebase OFF, `AMPLITUDE_API_KEY` 비면 Amplitude OFF).
- SPM 의존성: `firebase-ios-sdk` 11.x(FirebaseAnalytics), `Amplitude-Swift` 1.9+ (`project.yml`).
- Info.plist: `SKAdNetworkItems`(구글 어트리뷰션용) 등록. **IDFA·ATT 미사용** — 프롬프트 없이 SKAdNetwork로만 어트리뷰션.
- 훅: 위 표의 각 시점(스토어·설정 화면·카드 공유)에 삽입, `logOnce` 1회성 유닛 테스트 포함.

### 남은 코드 작업 (키 발급 후 5분)
1. Firebase 콘솔에서 받은 `GoogleService-Info.plist`를 `apps/ios/Sources/`에 넣고 `xcodegen generate`.
2. `project.yml`의 `AMPLITUDE_API_KEY: ""`에 Amplitude 키 입력.
3. ⚠️ **앱 개인정보 라벨 갱신 필수**: 현재 "수집 안 함"으로 심사 중. 분석이 켜진 빌드(1.0.1)를 내보내기 **전에** ASC → 앱 개인정보에서 **식별자(기기 ID) + 사용 데이터(제품 상호작용)** / 목적 "분석" / "사용자에게 연결되지 않음"으로 수정·게시할 것. 이 순서를 지키면 정책 위반이 없다.

---

## 3. 웹 콘솔 세팅 (초보자용, 화면 단위)

### 3-A. Firebase 콘솔 (console.firebase.google.com)
1. **프로젝트 추가** → 이름 `baseball-reincarnation` → Google 애널리틱스 "사용 설정"(기본 계정 OK) → 만들기.
2. 프로젝트 홈 → **iOS+ 버튼** → 번들 ID `com.solkim.baseball.ios` 입력 → 앱 등록.
3. **GoogleService-Info.plist 다운로드** → 위 2절대로 프로젝트에 추가.
4. 왼쪽 메뉴 **애널리틱스 → 이벤트**: 앱 실행 후 24시간 안에 `activation_first_game`이 목록에 나타난다(디버그로 즉시 보려면 Xcode 스킴 인자에 `-FIRDebugEnabled` 추가 → 애널리틱스 → DebugView).
5. 이벤트 목록에서 `activation_first_game` 행의 **"전환으로 표시" 토글 ON** ← Google Ads로 내보내는 스위치다.
6. **프로젝트 설정(톱니) → 통합 → Google Ads → 연결**: 사용할 Ads 계정 선택 → 연결 완료.

### 3-B. Amplitude (amplitude.com)
1. 가입 → Organization 생성 → **Create Project** → 이름 `baseball-ios`, 플랫폼 iOS.
2. 프로젝트 생성 직후 나오는 **API Key 복사** → `project.yml`의 `AMPLITUDE_API_KEY`에 붙여넣기.
3. 데이터 확인: 왼쪽 **Data → Events** 에서 앱 실행 후 이벤트가 실시간으로 뜬다(Ingestion Debugger).

### 3-C. Google Ads (ads.google.com)
1. 계정 생성 시 "전문가 모드로 전환"(스마트 캠페인 강요 회피) → 결제 프로필(원화) 등록.
2. **도구 → 측정 → 전환**: Firebase 연동이 되어 있으면 "가져오기" 탭에 `activation_first_game (Firebase)`가 보인다 → **가져오기** 체크 → 전환으로 추가.
3. 그 전환의 설정에서 **집계 방식 = "1회"** 로 변경(기본 "모든 전환" 금지 — 1인 1회 원칙).
4. **캠페인 → 새 캠페인 → 앱 프로모션 → 앱 설치** → 앱스토어에서 앱 검색·선택.
5. 설정: 위치 **모든 국가**, 언어 **모든 언어**, 일 예산 **₩10,000**, 입찰 **"설치 수 최대화"** (전환 선택 단계에서 `activation_first_game`을 캠페인 전환 목표에 포함).
6. 광고 소재(아래 4절) 입력 → 게시.

---

## 4. 광고 소재 가이드

UAC는 소재를 조합해 자동 생성한다. **광고문안 5개 · 이미지 최대 20 · 영상 최대 20**을 넣을 수 있고, 초기엔 문안 5 + 이미지 4 + 영상 1이면 충분하다.

**문안(각 30자 이내, 예시):**
1. `못 던지면 환생. 다시 던진다` — 컨셉 훅
2. `포수 사인 읽고, 내 손으로 던지는 투구` — 코어 손맛
3. `3년 뒤 드래프트, 네 이름이 불릴까` — 목표 제시
4. `삼진 하나에 관중이 일어선다` — 도파민
5. `광고 없음. 과금 없음. 야구뿐` — 유료 프리미엄 차별점

**이미지:** 실기기 스크린샷 그대로(승부 화면·회차 카드·드래프트 호명·대진표). 1200×628(가로)·1080×1080(정방) 두 비율은 꼭 포함.
**영상(선택, 15~20초):** 투구 제스처 → 삼진 풀콜("Strike three!") → 회차 카드 공유 순서의 세로 화면 녹화 하나면 충분. QuickTime 실기기 녹화로 제작 가능.
**소재 원칙:** 텍스트 과다 금지, 첫 2초에 투구 장면, 실제 게임 화면만(과장 소재는 리젝+환불 유발).

---

## 5. 캠페인 운영 — D1~D7 일자별 플랜

| 일자 | 할 일 | 판단 기준 |
|---|---|---|
| **D1** | 캠페인 게시(설치 수 최대화). Ads·Firebase·Amplitude 3곳에서 데이터 유입 확인만. 손대지 않기 | 노출이 0이면: 결제 프로필/심사 상태 확인 |
| **D2** | 지표 기록 시작(아래 표). 소재별 성과는 아직 무시(학습 중) | 설치 > 0 확인 |
| **D3** | **워밍업 종료 판정**: 최근 3일 `activation_first_game` 합계 확인 | 일 평균 10건 이상? |
| **D4** | **일 10건 이상이면**: 캠페인 입찰을 "설치 수 최대화 → **인앱 액션 가능성 높은 사용자(전환: activation_first_game)**"로 전환. **10건 미만이면(유료 앱은 이 경우가 기본값)**: 입찰 전환하지 말 것(데이터 부족 상태에서 전환하면 학습이 망가진다). 대신 ① A트랙이면 무료 프로모션 기간을 연장/시작 ② 소재에 가격·프리미엄 소구 강화 ③ 전환 목표를 한 단계 앞(`first_pitch`)으로 낮춰 신호량 확보 — 셋 중 하나 | |
| **D5** | 소재 성과 확인(Ads → 광고 자산 → 실적 등급). "낮음" 자산 1~2개 교체 | 교체는 하루 1번만 |
| **D6** | 국가별 리포트 확인(Ads → 위치). CPI 낮고 activation율 정상인 국가 메모(다음 캠페인 타겟) | activation율 5% 미만 국가는 다음에 제외 |
| **D7** | 캠페인 일시중지 → 결산: 총비용/설치/CPI/activation 수/CPA/D1 리텐션. Amplitude 대시보드 스크린샷 보관 | 아래 6절 대시보드로 분석 |

**매일 기록할 5가지**: 비용 / 설치 수 / CPI / activation 수 / activation율(=activation÷설치).

---

## 6. Amplitude Activation 대시보드 (화면 단위)

### 6-1. Activation Funnel
1. 왼쪽 **Create(+) → Chart → Funnel Analysis**.
2. 단계 추가: ① `onboarding_started` ② `onboarding_completed` ③ `first_pitch` ④ `activation_first_game`. (설치 자체는 Amplitude의 첫 이벤트 = ①로 근사.)
3. 우측 설정: **Conversion window = 1 day**, Counting = **Uniques**.
4. 저장 → 이름 "Activation Funnel". **각 계단 사이 이탈률이 그대로 보인다** — 어느 단이 30% 이상 깎이면 그 화면이 다음 개선 대상.

### 6-2. Retention
1. **Create → Chart → Retention Analysis**.
2. Starting event = **Any Active Event**, Returning event = **Any Active Event** → 앱 전체 D1/D7 리텐션.
3. 하나 더: Starting = `activation_first_game`, Returning = `game_finished` → **"activation한 유저가 돌아와서 또 경기를 하는가"** = 진짜 제품 리텐션.
4. 코호트 비교: Segment에서 `rebirth_started` 수행 유저 그룹을 만들어 겹쳐 보기 — 환생 경험자가 리텐션이 높다면 "환생까지 빨리 데려가기"가 성장 레버라는 증거다.

### 6-3. 반복 사용·깊이 보드
1. **Create → Dashboard** → 이름 "야구환생 — Activation".
2. 위 퍼널·리텐션 2개 + 추가 차트: `game_finished` **Weekly Users**(반복 사용), `chapter_advanced`의 chapter 값 분포(어디까지 가는가), `draft_resolved` drafted true/false 비율(완주 난이도 체감), `life_card_shared` 수(바이럴).
3. 대시보드 우측 상단 **Share → 이메일 구독(주 1회)** 걸어 두면 자동 리포트.

---

## 7. 목표 재확인

이 사이클의 성공 = **매출이 아니라**: ① 소재→캠페인→유저 획득을 한 번 완주 ② Activation Funnel에서 실제 이탈 지점을 눈으로 확인 ③ activation 유저의 D1/D7 리텐션 숫자를 확보. 이 세 가지가 다음 업데이트(무엇을 고칠지)와 다음 캠페인(어느 나라, 어떤 소재)의 근거가 된다.

## 부록 — 전체 체크리스트

- [x] 이벤트 설계·코드 구현·1회성 테스트 (저장소 완료)
- [x] SKAdNetwork 등록, ATT 미사용 확인
- [x] Firebase 프로젝트 생성 → plist 프로젝트에 추가 (프로젝트 `baseball-reincarnation`, plist 커밋됨)
- [x] Amplitude 프로젝트 생성 → API 키 입력 (워크스페이스 purple-shape-779806, 인제스천 검증 완료)
- [ ] **개인정보 라벨 "수집함"으로 갱신·게시** (분석 빌드 제출 전 필수! — 1.0 승인 후 진행)
- [ ] 1.0 승인 후 → 분석 포함 1.0.1 빌드 제출 (빌드 20 TestFlight 업로드는 완료, ASC 제출만 남음)
- [ ] Firebase: activation 이벤트 "전환으로 표시" + Google Ads 연결 (이벤트가 콘솔에 노출되는 최대 24h 후 가능)
- [ ] Google Ads: 전환 가져오기(1회 집계) → 캠페인 게시 (계정·결제 프로필 생성은 사용자 몫)
- [x] Amplitude: 퍼널·리텐션·대시보드 3종 생성 — Activation Funnel(4단), Retention(activation→game_finished), 대시보드 "야구환생 — Activation"
- [ ] D1~D7 운영표 기록 → D7 결산
