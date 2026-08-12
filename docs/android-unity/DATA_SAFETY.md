# Android 데이터 보안 구현 기록

기준일: 2026-08-11
범위: `com.solkim.baseball.android` production RC
상태: SDK/런타임/정적 계약, 공개 개인정보처리방침, production Firebase/Amplitude 프로젝트·CI secret 연결 완료. 실제 수신 및 Play Data Safety 제출 증거는 미완료

## 제품 원칙

- 로그인, 계정, 광고, 인앱 구매, 클라우드 저장은 없다.
- 게임은 네트워크 없이 전체 커리어와 직접 투구를 진행할 수 있다.
- 네트워크는 익명 품질 분석과 크래시 진단에만 사용한다. SDK 초기화·전송 실패는 게임 진행이나 로컬 저장을 막지 않는다.
- 앱이 생성한 install-scoped UUID를 사용하며 광고 ID, Android ID, App Set ID, 전화번호, 이메일과 결합하지 않는다.
- 선수 이름, raw seed, career ID, save JSON, 자유 입력, 공유 이미지/파일명은 분석 또는 Crashlytics에 보내지 않는다.

## 설치된 SDK와 코드 설정

| SDK | 잠금 버전 | 런타임 설정 | 현재 검증 |
|---|---:|---|---|
| Firebase Analytics | Unity 13.14.0 / Android 23.2.0 | 광고 ID 권한 제거, 광고 ID 수집·광고 개인화 신호 false, production config에서만 활성 | 전용 GA4 property/Android stream·CI config 연결 완료; production 수신 대기 |
| Firebase Crashlytics | Unity 13.14.0 / NDK 20.1.0 | 비식별 custom key만 허용, IL2CPP public symbols 생성·CI 업로드 | 최소권한 symbol uploader·CI secret 연결 완료; test crash·symbolication 대기 |
| Amplitude Unity | v2.8 / Android 2.40.1 | AD ID, App Set ID, carrier, city, country, DMA, IP, lat/lng, region 수집 bridge option 비활성 | 별도 Android production project·CI API key 연결 완료; production 수신 대기 |

production RC는 `google-services.json`, Amplitude API key, Firebase symbol-upload 서비스 계정을 CI에서 주입해야 하며 저장소에는 넣지 않는다. 기본 리소스 설정은 세 SDK 전송을 모두 끈다.

## Android 권한과 식별자

허용 권한은 `INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`, `VIBRATE` 네 개뿐이다. `AD_ID`, fine/coarse location, 사진, 마이크, 카메라, 연락처, 계정, 전화, 외부 저장소 권한은 요청하지 않는다.

Firebase Analytics는 SDK 자체 app-instance ID를, Crashlytics는 Crashlytics installation UUID/Firebase installation ID를 별도로 생성한다. 따라서 Play Data Safety의 “기기 또는 기타 ID”는 앱 UUID만이 아니라 이 SDK 식별자까지 포함해 **수집함**으로 답한다. Crashlytics user identifier에는 앱 UUID를 설정하지 않는다.

## 위치 데이터에 대한 정확한 해석

GPS·Wi-Fi 위치 API와 Android 위치 권한은 사용하지 않으며 정확한 위치는 수집하지 않는다. 다만 Google Analytics for Firebase 기본 동작은 전송 시 마스킹된 IP로 대략적인 지역을 파생할 수 있다. 그러므로 Firebase Analytics를 production에서 켜는 현재 설계에서는 Play Data Safety의 **대략적인 위치**를 수집함으로 공개해야 한다.

2026-08-12 GA4 Admin에서 모든 지역의 “granular location and device data collection”을 꺼 도시, 기기 모델·이름, 화면 해상도 같은 세부 자동 속성을 차단했다. 광고 개인 최적화도 307개 전 지역에서 껐고 Google Signals는 활성화하지 않았다. Console screenshot은 `artifacts/release-evidence/ga4-data-collection-2026-08-12.png`에 보관한다. 제품 요구가 “대략적인 위치도 0”으로 바뀌면 Firebase Analytics를 production config에서 끄고 Amplitude만 사용하도록 빌드 계약을 변경해야 한다.

## Play Data Safety 답변 초안

최종 답변은 서명 AAB의 merged manifest, 실기기 네트워크/event dump, 각 vendor Console 설정과 맞춰 다시 확인한다.

| Play 데이터 범주 | 수집 | 공유 | 목적 | 연결성/비고 |
|---|---|---|---|---|
| 대략적인 위치 | 예 | 아니요 | 분석 | Firebase가 마스킹 IP로 파생할 수 있음; 정확한 위치·위치 권한 없음 |
| 앱 상호작용 | 예 | 아니요 | 분석 | 화면/퍼널/게임 단계의 저카디널리티 이벤트 |
| 앱 정보 및 성능 | 예 | 아니요 | 분석, 앱 기능 | 버전, 빌드, distribution, phase, 품질 tier |
| 크래시 로그 | 예 | 아니요 | 앱 기능 | stack trace, 예외, 비식별 custom key |
| 진단 | 예 | 아니요 | 앱 기능 | Crashlytics session/기기·OS 진단 정보 |
| 기기 또는 기타 ID | 예 | 아니요 | 분석, 앱 기능 | 앱 UUID, Firebase/Crashlytics installation ID; 광고 ID 아님 |

Crashlytics의 앱 문맥은 저장 버전·revision, 현재 route, 실제 Pitch stage 로드 여부와
적응형 품질 tier(`high`/`low`)만 보낸다. `distribution`은 빌드 설정에서 해석한
`editor`/`development`/`internal`/`closed`/`production` 중 하나이며 임의 문자열이나
Unity Quality Settings 이름은 보내지 않는다. SDK 준비 전 문맥은 프로세스 메모리에 마지막
한 건만 보관하고 준비 완료 시 재적용하며, subsystem reset 시 삭제한다.
| 개인 정보/연락처/금융/사진·동영상/오디오/파일/건강/메시지 | 아니요 | 아니요 | 해당 없음 | 앱 기능이 요청하거나 전송하지 않음 |

- 전송 중 암호화: 예(TLS를 사용하는 SDK 공식 전송)
- 데이터 판매: 없음
- 광고 목적 및 광고 개인화: 없음
- 계정 생성: 없음
- 데이터 수집은 앱 기능에 필수인가: 게임 플레이에는 필수 아님. 현재 production 품질 측정에는 기본 활성화로 설계됨
- 로컬 삭제: 설정의 “저장 데이터 초기화”와 앱 삭제로 save·앱 UUID·once receipt를 삭제/회전
- 원격 삭제/보존: 개인정보처리방침에 vendor 보존기간과 install ID를 이용한 요청 절차를 명시. Crashlytics 공식 문서상 관련 crash 식별자/stack은 90일 보존 후 제거 절차가 시작됨

## RC 필수 증거

- [ ] production Firebase Analytics와 Amplitude에 같은 테스트 action이 들어오고 production/development가 분리됨
- [ ] 실제 event payload에 선수 이름, seed, save, 자유 입력, 광고 ID가 없음
- [x] GA4 granular location/device data가 모든 지역에서 off이고, 광고 개인 최적화가 307개 전 지역 off이며 Google Signals는 미활성
- [ ] Firebase test crash가 symbolicated IL2CPP stack으로 표시됨
- [ ] `firebase-symbol-upload.json`과 CLI 성공 로그가 AAB artifact에 포함됨
- [ ] merged manifest의 활성 권한이 허용된 네 개뿐임
- [ ] 앱 초기화/삭제 뒤 앱 생성 UUID가 재사용되지 않음
- [x] 개인정보처리방침 HTTPS URL(`https://baseball-reincarnation.vercel.app/privacy`)과 Play Data Safety 답변 초안이 이 표와 일치함

참고: [Google Analytics 기본 수집](https://support.google.com/analytics/answer/11593727?hl=en), [세부 위치·기기 데이터 제어](https://support.google.com/analytics/answer/12002752?hl=en), [Firebase 개인정보·Crashlytics 보존](https://firebase.google.com/support/privacy/), [Firebase Analytics 수집 제어](https://firebase.google.com/docs/analytics/android/configure-data-collection).
