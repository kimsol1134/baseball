# iOS 1.2.0 프로 커리어 journey 선행 출시 근거

| 항목 | 값 |
|---|---|
| 확인일 | 2026-08-17 KST |
| 앱 | 야구 못하면 또 환생함: 투수 키우기 |
| Bundle ID | `com.solkim.baseball.ios` |
| App Store Connect App ID | `6794754217` |
| 버전 / 빌드 | `1.2.0 (57)` |
| ASC 버전 ID | `a57de4c7-946e-4b1e-9a32-c3b4a0224d71` |
| ASC 빌드 ID | `8032f2fe-5e49-48a2-9647-2bd0e15031c7` |
| 출시 방식 | 심사 승인 후 수동 출시 (`MANUAL`) |
| 핵심 변경 | `AppFeatureConfiguration.production.proCareerJourneyV1 = true` (iOS 단독 선행 출시, §21.7) |

## 1. 결정과 근거

2026-08-17 사용자 결정으로 프로 커리어 journey(신인 계약·시즌 정산·재계약/FA·투자·구단
유산·은퇴 명예)를 iOS 단독 선행 출시한다. 근거: 2026-08 출시 데이터에서 첫 인생 완주 전
이탈 43%가 프로 구간에 집중되고, 리뷰가 계약·FA·연봉·선발 보직 부재를 직접 지목했다.
결정 기록: `docs/PRO_CAREER_CONTRACT_LEGACY_DEPTH_IMPLEMENTATION_PLAN_2026-08-14.md` §20(2026-08-17), §21.7.

## 2. 자동 검증 (2026-08-17)

- 코어 `swift test` 453개 통과(스킵 1: opt-in Wave0 생성기).
- Wave 4 gate(`check:pro-career`) 14개 통과, Wave 5 gate(`check:pro-career:wave5`) 통과,
  분포 `seeds=1000 seasons=20` 위반 0.
- iOS 유닛 전체(프로모 익스포트 제외) 통과. production 플래그 전환에 맞춰 legacy 특성화
  테스트는 `AppFeatureConfiguration.legacyTests`(스키마-2 라이터 고정)로 이전.
- UI: 고교 드래프트·환생 스모크 통과, 수동 릴리스 제스처(투구 슬라이더 불변 규칙) 통과,
  일본어 journey 20시즌 완주(신인 계약 서명→20회 정산→최대 시즌 은퇴·명예) 통과 —
  전용 시뮬레이터 38분. 공유 시뮬레이터에서는 병렬 세션 테스트가 같은 앱 프로세스에
  끼어들어 오탐 실패가 났으므로, 여정급 UI 검증은 전용 시뮬레이터에서 실행한다.

## 3. 서명 IPA 검사

검사한 IPA: `/tmp/baseball-1.2.0-57/export/BaseballIOS.ipa`

- `CFBundleShortVersionString 1.2.0`, `CFBundleVersion 57`.
- `ko.lproj`, `en.lproj`, `ja.lproj`에 Localizable, GameContent, InfoPlist,
  LaunchScreen 리소스가 모두 존재한다.
- 일본어 앱 이름 `野球がダメならまた転生` 확인.
- `codesign --verify --deep --strict` 통과.

## 4. App Store Connect

- 빌드 57 업로드(2026-08-17 12:06 KST 직후) → 처리 상태 `VALID`.
- 업로드 시 Google 사전 빌드 프레임워크 vendor dSYM 경고는 1.1.2와 동일하며 심사 차단
  항목이 아니다.
- 버전 1.2.0 생성(releaseType `MANUAL`), 빌드 57 연결 완료.
- What's New를 ko·ja·en-US·en-GB·en-CA·en-AU 6개 로케일에 등록
  (`marketing/appstore/RELEASE_NOTES_1.2.0.md`).
- 빌드 번들 locales: `["ko","en","ja"]` — App Store 지원 언어에 Japanese 표시 충족.

## 5. 남은 절차

1. **TestFlight 일본어 스모크(AGENTS.md 배포 불변 규칙)** — 실기기가 모두 오프라인이라
   자동화 기기 테스트를 대신 TestFlight로 확인한다: 일본어 기기 설정에서 빌드 57을 설치해
   신인 계약 → 첫 정산까지 일본어 표기로 통과하는지 확인.
2. 스모크 통과 확인 뒤 심사 제출(reviewSubmission 생성·제출).
3. 심사 승인 후 수동 출시. 출시 후 실사용자 5명 이해도 관찰(§21.6-3)과 journey 코호트
   퍼널(`pro_contract_signed`→`life_completed`, `screen_stall_detected`) 모니터링.

이 작업에서는 Git stage, commit, push를 수행하지 않았다.
