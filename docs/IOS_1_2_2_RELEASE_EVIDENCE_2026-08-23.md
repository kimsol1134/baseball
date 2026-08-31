# iOS 1.2.2 App Store 제출 근거

| 항목 | 값 |
|---|---|
| 제출일 | 2026-08-23 KST |
| 앱 | 야구 못하면 또 환생함: 투수 키우기 |
| Bundle ID | `com.solkim.baseball.ios` |
| 버전 / 빌드 | `1.2.2 (60)` |
| App Store Connect App ID | `6794754217` |
| ASC 버전 ID | `f7b40595-cf09-4112-8703-aa9af67357d7` |
| ASC 빌드 ID | `b4b4f84f-638b-41c6-9e55-6f739080887c` |
| 심사 제출 ID | `cf7397c4-68e5-48f9-923a-6fa48cb731b8` |
| 제출 상태 | `WAITING_FOR_REVIEW` |
| 출시 방식 | 심사 승인 후 수동 출시 (`MANUAL`) |

## 바이너리

- Apple Distribution 서명과 `codesign --verify --deep --strict` 통과.
- `get-task-allow=false`, arm64, Game Center, iCloud KVS entitlement 확인.
- `PrivacyInfo.xcprivacy` plist 검증 통과.
- 서명 IPA SHA-256: `40dd7ecc563fa96eb77c291436cfd87b182e5c114486d8d8b0cb8ffa195d48d8`.
- App Store 처리 상태 `VALID`, 암호화 `exempt`.
- ASC 처리 번들의 locales가 `en`, `ko`, `ja`임을 확인.
- ko/en/ja에 Localizable, GameContent, InfoPlist, LaunchScreen 리소스 포함.
- 한국어 LaunchScreen에 기존 `LaunchLogo` 1x/2x/3x 포함.

## 검증

- 공유 Swift 전체 테스트: 479 passed, opt-in 1 skipped, failures 0.
- 구종 학습 실제 UI 종주: 선택, 잠금, 집중 훈련, 해금, 앱 재실행 복원, 개발 배지, 수동 투구 슬라이더 통과.
- 접근성 최대 글자 크기: 오프닝과 구종 선택 화면의 모든 조작 접근 및 44pt 타깃 통과.
- 일본어 iPhone 16 Pro 실기기 스모크: 오프닝→선수 생성→프롤로그, 31.853초, failures 0.
- iOS Release 빌드, 밸런스, 문구/IP, 한국어 문구, 관계 대사 정합성, 3개 언어 현지화 검사 통과.
- ASC strict validation: errors 0, warnings 0, blockers 0.

## App Store 미리보기

사용자 지정 A1·A3와 기존 P1 육성 여정을 886×1920 H.264 High Level 4.0, 30fps,
AAC 48kHz 스테레오로 변환했다. 눈누에서 상업 영상 사용이 허용된 `여기어때 잘난체`를
훅·페이오프용으로, `G마켓 산스`를 상황 설명용으로 로컬 번들했다. 폰트 파일과 라이선스,
출처, SHA-256은 `videos/pitcher-growth-pride/assets/fonts/`에 기록했다.

| 순서 | 파일 | SHA-256 |
|---|---|---|
| A1 | `marketing/appstore/previews-1.2.2-font/01-a1-last-ball.mp4` | `3dcf640119563f274f228ba82fa441979d792bd1d240b9422a9738d395d3aeb6` |
| A3 | `marketing/appstore/previews-1.2.2-font/02-a3-rebirth.mp4` | `f61bfc85daf9121330758baef5f66055edad14cecb506f38a08e79470cfc8efc` |
| P1 | `marketing/appstore/previews-1.2.2-font/03-p1-growth-journey.mp4` | `0d67a88fe1e8f47a458643acb976c35ab1b0e474135968b1d60ecb44e3147b00` |

- HyperFrames 0.7.109 → 0.8.10 업그레이드 후 세 컴포지션 strict 검사 errors 0, warnings 0.
- 세 영상 음량을 약 -14 LUFS로 통일하고 접촉 시트로 초반·중반·후반 프레임을 검수.
- 한국어 `IPHONE_67`, `IPHONE_65`에 A1→A3→P1 순서로 등록.
- 여섯 미리보기 모두 `COMPLETE`.
- 포스터 프레임: A1 `00:00:02:15`, A3 `00:00:04:00`, P1 `00:00:14:00`.
- 영어·일본어 기존 현지화 미리보기는 유지.

## App Store Connect

- 1.2.1의 설명, 키워드, 프로모션 텍스트, 지원 URL을 6개 로케일에 승계.
- ko, ja, en-US, en-GB, en-CA, en-AU에 1.2.2 업데이트 문안 등록.
- 빌드 60을 1.2.2에 연결하고 내부 TestFlight에서 `IN_BETA_TESTING` 확인.
- 최초 2편 제출 `3619eee9-6750-44ba-af92-76e18afe0764`는 영상 개선을 위해 취소.
- 3편 재제출 시각: `2026-08-23T11:56:17.802Z`.
- 최종 다음 단계: App Review 결과 대기. 승인 후 수동 출시.
