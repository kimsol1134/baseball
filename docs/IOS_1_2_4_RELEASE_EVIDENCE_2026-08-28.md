# iOS 1.2.4 릴리스 증거

- 작성일: 2026-08-28 (Asia/Seoul)
- 앱 버전 / 빌드: `1.2.4 (62)`
- 번들 ID: `com.solkim.baseball.ios`
- App Store Connect 버전 ID: `e6ef5f26-1919-445d-831a-2fb618906eca`
- App Store Connect 빌드 ID / Delivery UUID: `766af332-fc0f-4555-9489-1eed37cfb39e`
- App Review 제출 ID: `62f11307-2534-4821-9cec-9741328f15bb`
- 출시 방식: 수동 출시

## 구현 범위

- 부상 발생 시 원인, 선택한 주간 계획, 원시·유효 피로, 투구 수, 회복 기간과 다음 행동을 한 카드에서 안내한다.
- 저피로 상태의 숨은 최소 부상 확률을 제거하고, 고교와 프로에서 팔 상태·위험 예측을 구조화했다.
- 반복 설명은 처음에는 펼쳐 보이고 이후에는 접힌 상태를 기억하며, 설정에서 설명 밀도를 바꿀 수 있다.
- 익숙하지 않은 사용자에게 능력치를 1–100으로 보여 주되, 내부 20–80 균형은 보존한다.
- 기본 능력 완성 뒤의 성장은 무한 숫자 상승이 아니라 구속·코스·결정구·이닝 숙련으로 이어진다.
- 직접 투구의 기본 조작은 기존 슬라이더로 유지한다.

## 자동 검증

- Swift 핵심 회귀: mastery/overflow, 고교 80 도달 뒤 성장, 부상 분포·구조화 이벤트·저장 호환성 통과.
- iOS 집중 테스트 묶음: 52개, 44개, 13개, 수정 회귀 22개 통과.
- iOS UI: 저장된 구종 복구 및 기본 수동 슬라이더 한 구 완료 테스트 통과.
- iOS 장기 회귀: 일본어 20시즌 최대 기간 시나리오 통과.
- Windows: 30개 파일, 103개 테스트와 production build 통과.
- Kotlin: `:game-core:test` 통과.
- Unity 정적 C#: 447개 테스트 통과.
- 밸런스 게이트 통과.
- iOS 현지화 검사: 3,463개 카탈로그 항목, 미완료 화면 0개.
- 제품 문구 검사: 내부 용어 38종 및 실존 야구 IP 42종 미노출.
- `git diff --check` 통과.
- 최종 Release iOS Simulator 빌드 통과.

## 시뮬레이터 종주

`Baseball QA iPhone 17 Pro` / iOS 26.5에서 다음을 직접 확인했다.

- 공개 능력치가 1–100으로 표시된다.
- 기본 설정에서 수동 투구 슬라이더가 보이며 한 구를 끝까지 던질 수 있다. 자동 릴리스는 꺼진 상태다.
- 설명 밀도를 간결하게 바꾼 뒤 앱을 다시 실행해도 설정이 유지된다.
- 리뷰 개선 fixture에서 부상 원인·계획·피로·투구 수·회복 행동과 4종 숙련도가 함께 표시된다.
- 부상 카드를 확인 처리한 뒤 앱을 다시 실행하면 재노출되지 않는다.

증거:

- [1–100 능력치 화면](evidence/ios-1.2.4/simulator-ability-1-to-100.jpg)
- [기본 수동 슬라이더 투구](evidence/ios-1.2.4/simulator-manual-slider-pitch.jpg)
- [부상 원인 및 숙련도 화면](evidence/ios-1.2.4/simulator-injury-mastery.jpg)

## 일본어 실제 기기 스모크

`iPhone 16 Pro` / iOS 26.5.2에서 운영 앱 데이터와 분리된 QA 번들로 일본어 실행을 확인했다.

- 오늘·이번 주 탭과 게임 핵심 문구가 일본어로 표시된다.
- 부상 원인, 발생 계획, 피로, 투구 수, 회복 안내와 4종 숙련도가 일본어로 표시된다.
- 한국어 대체 문자열 노출을 발견하지 않았다.
- 확인 뒤 QA 앱, QA 번들 ID와 개발 프로비저닝 프로파일을 제거했다.

증거:

- [일본어 오늘 화면](evidence/ios-1.2.4/iphone16pro-ja-today.png)
- [일본어 부상 및 숙련도 화면](evidence/ios-1.2.4/iphone16pro-ja-week-injury-mastery.png)

## 서명 아카이브와 IPA

- 아카이브: `apps/ios/releases/1.2.4/BaseballIOS-1.2.4-b62.xcarchive` (약 89 MB)
- 제출 IPA: `apps/ios/releases/1.2.4/export-manual/BaseballIOS.ipa` (약 28 MB)
- SHA-256: `8ee68006cdecbb2934457c4eeb0fff2aa334cbff3fa2dbddda43d84d38395e56`
- 아키텍처: `arm64`
- `get-task-allow=false`
- Game Center 및 iCloud KVS entitlement 포함.
- `ko.lproj`, `en.lproj`, `ja.lproj` 각각에 `Localizable.strings`, `GameContent.strings`, `InfoPlist.strings`, 현지화 LaunchScreen이 포함된다.
- Apple `altool --validate-app` 서버 검증 오류 0개.
- App Store Connect 처리 상태 `VALID`, 배포 대상 `APP_STORE_ELIGIBLE`, 비면제 암호화 미사용.

## App Store Connect 제출

- 기존 6개 로케일 `ko`, `ja`, `en-US`, `en-GB`, `en-AU`, `en-CA`를 유지한다.
- 스토어 설명과 새로운 기능 문안은 개발 변경 목록이 아니라 처음 보는 사용자가 게임의 선택·성장·환생 재미를 이해하도록 작성한다.
- ASC의 6개 로케일에서 `description`과 `whatsNew`가 저장소 기준 문안과 정확히 일치함을 검증했다.
- 문안 길이: 영어 2,216/497자, 한국어 981/285자, 일본어 801/227자 (`description`/`whatsNew`).
- 빌드 62를 버전 1.2.4에 연결했다. 출시 방식은 `MANUAL`이다.
- 사용자 재확인 후 App Review 제출을 완료했다.
- 제출 ID `62f11307-2534-4821-9cec-9741328f15bb`, 제출 시각 `2026-08-28T09:37:07.981Z`.
- 제출 및 앱 버전 상태는 `WAITING_FOR_REVIEW`, 제출 항목은 `READY_FOR_REVIEW`다.
- API 응답 경고는 없었으며 앱은 출시하지 않았다.
