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

## 5. 문안 개선과 심사 제출

- 2026-08-17 14:53 사용자 지시: "심사 제출 진행 + ASC 메타데이터를 유저 입장에서
  다운로드 받고 싶어지게 개선(기능 나열 금지)".
- What's New를 기능 목록에서 **유저가 겪을 장면 서사**로 전면 재작성(ko/en×4/ja),
  프로모션 텍스트 신규 등록(새 버전에 승계되지 않아 비어 있었음), 설명의 프로 구간을
  journey 내용(계약 서명·연봉·FA·영구결번)으로 치환. 원본: `marketing/appstore/RELEASE_NOTES_1.2.0.md`.
- 심사 제출: reviewSubmission `2e3ce284-4416-4d8d-9a8b-a6e6c5150d30`, 버전 1.2.0 아이템,
  제출 시각 2026-08-17 14:59 KST, 상태 `WAITING_FOR_REVIEW`.
- 일본어 스모크: 시뮬레이터 20시즌 journey UI 통과(§2). 실기기가 오프라인이라 기기
  스모크는 TestFlight 빌드 57로 대체 가능하며, 사용자가 제출을 직접 지시했다. 심사 중에도
  TestFlight 확인에서 문제가 발견되면 제출 철회로 되돌릴 수 있다.

## 6. 남은 절차

1. 심사 승인 후 수동 출시(MANUAL).
2. 출시 후 실사용자 5명 이해도 관찰(§21.6-3)과 journey 코호트 퍼널
   (`pro_contract_signed`→`life_completed`, `screen_stall_detected`) 모니터링.

이 작업에서는 Git stage, commit, push를 수행하지 않았다.
