# iOS 1.1.2 일본어 지원·심사 제출 근거

| 항목 | 값 |
|---|---|
| 확인일 | 2026-08-14 KST |
| 앱 | 야구 못하면 또 환생함: 투수 키우기 |
| Bundle ID | `com.solkim.baseball.ios` |
| App Store Connect App ID | `6794754217` |
| 버전 / 빌드 | `1.1.2 (53)` |
| ASC 버전 ID | `b9e9da9e-c17f-4ec9-a61c-1f443ab923f3` |
| ASC 빌드 ID | `cc406e0b-3cb2-4846-bf0a-1b0909acd3ca` |
| 심사 제출 ID | `6c460a87-07e1-497b-a6ea-385812eea60e` |
| 출시 방식 | 심사 승인 후 수동 출시 (`MANUAL`) |

## 1. 일본어 바이너리

- 앱 언어 모델과 locale 판별 경로에 일본어를 추가했다.
- `Localizable.xcstrings`와 `GameContent.xcstrings`의 3,200개 항목에 한국어·영어·일본어 번역이 모두 존재한다.
- `ja.lproj/InfoPlist.strings`와 `ja.lproj/LaunchScreen.storyboard`가 릴리스 타깃에 포함된다.
- 일본어 앱 이름은 `野球がダメならまた転生`으로 확인했다.
- 서명된 IPA 안의 `ko.lproj`, `en.lproj`, `ja.lproj`에 Localizable, GameContent, InfoPlist, LaunchScreen 리소스가 모두 존재한다.
- 배포 서명과 프로비저닝을 확인했고 `get-task-allow=false`, arm64, 서명 검증 통과 상태다.
- App Store Connect가 처리한 빌드 번들 `e30df4b7-0491-40f9-8285-dd8a0171243a`의 locales는 `en`, `ja`, `ko`다.

검사한 IPA: `/tmp/baseball-ios-1.1.2-53.jiL5kj/export/BaseballIOS.ipa`

## 2. 충돌 수정과 테스트

- 훈련 결과 화면에서 생명주기가 끝난 뷰 상태를 지연 클로저가 참조하지 않도록 수정했다.
- 알림 처리 완료 API를 안전한 경로로 정리했다.
- 전체 자동 테스트: 433 passed, 0 failed.
- 일본어 현지화 단위 테스트: 9 passed.
- 일본어 시뮬레이터 UI 스모크 테스트: 1 passed.
- Release 시뮬레이터 실행 스모크 테스트를 통과했다.
- 일본어로 설정한 iPhone 16 Pro 실기기에서 첫 화면부터 프롤로그까지 한국어 폴백 없이 UI 테스트를 통과했다(38.913초).
- 실기기 결과 번들: `/Users/solkim/Library/Developer/Xcode/DerivedData/Baseball-chdxnbswliseepamvlovfyabxpqc/Logs/Test/Test-BaseballIOS-2026.08.14_12-10-30-+0900.xcresult`

Release 구성에서 UI 테스트 타깃의 `@testable import`는 허용되지 않으므로 실기기 UI 자동화는 Debug 구성으로 실행했다. 실제 제출물은 별도로 서명된 Release IPA를 검사하고 App Store Connect 처리까지 확인했다.

## 3. App Store Connect 확인

- 빌드 53 처리 상태: `VALID`.
- 버전 1.1.2에 빌드 53 연결 완료.
- 버전 현지화: `ko`, `ja`, `en-US`, `en-GB`, `en-CA`, `en-AU`.
- 일본어 앱 이름과 부제, 설명, 프로모션 텍스트, 키워드, 새로운 기능 문안을 등록했다.
- 일본어 스크린샷 14장(6.5형 7장, 6.7형 7장)과 앱 미리보기 2개가 모두 `COMPLETE`다.
- App Privacy는 게시 상태이며 제품 상호작용, 기기 ID, 충돌 데이터 범주를 공개한다.
- 제출 전 검증 결과: 오류 0, 경고 0, 차단 항목 0.
- App Store Connect가 표시하는 바이너리 지원 언어에 Japanese가 포함됨을 API의 빌드 locales로 재확인했다.

업로드 과정에서 Firebase 및 Google의 사전 빌드 프레임워크에 대한 vendor dSYM 경고가 있었으나 빌드는 `VALID`로 처리됐고 심사 차단 항목은 아니었다.

## 4. 심사 제출 결과

- 제출 시각: 2026-08-14 12:26:44 KST (`2026-08-14T03:26:44.272Z`).
- 버전 상태: `WAITING_FOR_REVIEW`.
- 제출 상태: `WAITING_FOR_REVIEW`.
- 다음 단계: App Store 심사 결과를 기다린 뒤 승인되면 App Store Connect에서 수동 출시한다.

이 작업에서는 Git stage, commit, push를 수행하지 않았다.
