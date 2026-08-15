# Android Unity 릴리스 증거

기준 시각: 2026-08-13 KST
현재 상태: clean commit의 Unity 6000.3.19f1 테스트, production upload-key 서명 v5 AAB,
Firebase Crashlytics symbol upload, API 29/35(16KB)/36 production smoke, Play 내부·비공개
트랙 구성이 완료됐다. v5 AAB와 nativeCode symbols를 같은 Play edit로 commit했다. internal은
versionCode 5를 제공하고 closed Alpha는 v5 검토 중이며, 승인 전까지 v1을 계속 제공한다.
사업자등록번호는 실제 증빙과 대조해 계정에 저장했고 공개 전화번호는 SMS 인증 대기 중이다.
본인 Google 계정은 closed Alpha 초대를 수락해 실제 tester 상태가 됐다. **프로덕션 RC 승인은 아직
아니다.** 아래 사람·시간·물리기기 조건은 자동화 증거로 대체하지 않는다.

## 빌드

- Git commit: `0602e7f6453e3a46e7d6950979adc14c1e0a7352`
- build 입력: clean (`gitDirty=false`)
- GitHub Actions: [run 31637857817, attempt 2](https://github.com/kimsol1134/baseball/actions/runs/31637857817) —
  Static contracts, Licensed Unity tests, Signed production candidate 모두 성공. attempt 1 PlayMode는
  제품 assertion이 아니라 Unity Editor native import crash(exit 139)로 중단됐고, failed-job rerun에서
  같은 commit의 PlayMode 14/14와 signed build가 통과했다.
- PR P0 CI: [run 31616614826](https://github.com/kimsol1134/baseball/actions/runs/31616614826) —
  React, iOS, Swift macOS/Windows, Desktop macOS/Windows 모두 성공
- Unity PR gate: [run 31616614936](https://github.com/kimsol1134/baseball/actions/runs/31616614936) —
  Static contracts와 Licensed Unity tests 성공
- Unity: `6000.3.19f1`
- application ID: `com.solkim.baseball.android`
- version/versionCode: `1.0.0` / `5`
- distribution/build: `production`, Development=false, Internal QA=false
- Android: min API 26, target API 36, ARM64, OpenGLES3, IL2CPP Release
- AAB: `baseball-android-1.0.0-5.aab` (92,387,712 bytes)
- AAB SHA-256: `807bea12fb37e5a2825be504ccdcc91e083ac692300abb0b1be2c87110234dde`
- IL2CPP symbols: `baseball-android-1.0.0-5-1.0.0-v5-IL2CPP.symbols.zip`
- IL2CPP symbol SHA-256: `32bb7822f157d46a64d7b240917babcf83771618ab19f5bde569f4dfb5f75819`
- Firebase symbol receipt: `uploaded`, Firebase CLI `15.26.0`,
  `2026-08-12T21:01:22.489Z`
- upload certificate SHA-256 pin:
  `D0A8EC4FDCEC6F7F74BBEBCE747CB3D2FA308DB72CCA106D30AA2A782DAA445F`
- bundletool: `1.18.3`, native library alignment `PAGE_ALIGNMENT_16K`
- device APKS `zipalign -P 16`: `passed` (APK 2개)
- ARM64 ELF LOAD alignment: `passed` (native library 14개, minimum `0x4000`)
- merged manifest/package/permission/screen-set 검증: `passed`
- CI artifact retention: 30일. artifact
  `baseball-android-candidate-1.0.0-5-0602e7f6453e3a46e7d6950979adc14c1e0a7352`
  (GitHub artifact id `9158707186`)와 검증용 로컬 사본
  `artifacts/android/v5-upload`이 있다. 로컬 경로는 `.gitignore` 대상이며 배포 바이너리를 Git에
  커밋하지 않는다.

## 자동 검증

- `npm run test:unity:static`: 435/435 통과
- `npm run test:unity:references`: production player, internal-QA player, Core, Platform,
  Platform tests, Presentation tests, Android Editor 모두 warning/error 0
- Unity Test Runner:
  - EditMode 주요 어셈블리: Core 46/46, Application 121/121, Platform 60/60,
    Presentation 240/240, HighSchool 39/39, Pro 25/25, InternalQa 4/4
  - 주요 EditMode 535건과 bootstrap/persistence 격리 lifecycle·fault·100회 round-trip 39건 통과
  - PlayMode 14/14 통과
  - 생성된 NUnit XML 합계 588/588, 실패·skip 0
  - CI test artifact zip SHA-256:
    `ccbaace5c43ae5aa409fb9da7384950d18af471119c8167d5e4d972216518680`
    (GitHub artifact id `9158370646`)
- strict Unity import gate: 전체 `Assets` 파일·디렉터리 missing `.meta` 0,
  missing reviewed Addressables/URP asset 0
- copy/IP: 내부 용어 38종·실존 야구 IP 42종 미노출
- design: 원시 색상·레거시 토큰 위반 0, 고대비/WCAG AA/공통 컴포넌트 계약 통과
- asset manifest: 150 files (118 images, 7 icon sources, 24 audio) 통과
- Android source/build contract: 통과
- Swift/C# fixture: Pitch seed 1…128 exact, 훈련-v4 seed `20260811` exact
- Monte Carlo: Pitch seed 1…10,000 outcome 집계 exact

## Android production smoke

세 실행은 같은 v5 AAB와 build manifest/checksum/Git commit/certificate pin을 검증하고 clean install했다.
각각 cold start, first-interactive, same-process resume, portrait/rotation block, offline relaunch,
font 200%, low-memory callback, foreground, crash/ANR·PII·runtime bridge scan을 통과했다.

| 기기 | API/page | 결과 | 추가 증거 |
|---|---|---|---|
| `Android_SDK_built_for_arm64` low-memory emulator | API 29 / 4KB | passed | 알림 권한은 API<33 비대상; `/private/tmp/baseball-v5-api29-smoke/20260812T212604Z` |
| `sdk_gphone16k_arm64` | API 35 / 16KB | passed | 실제 production 투구, shader ready, 16KB native 실행·정렬 모두 passed; `/private/tmp/baseball-v5-smoke/20260812T211007Z` |
| `sdk_gphone64_arm64` target-edge emulator | API 36 / 4KB | passed | 알림 거부 포함; `/private/tmp/baseball-v5-api36-smoke/20260812T212855Z` |

16KB 실행은 `getconf PAGE_SIZE=16384`, `BASEBALL_PITCH_STAGE_SHADER_READY`, 실제 저장형 투구의
`BASEBALL_PITCH_PRESENTATION_COMPLETED`, crash/ANR 0을 모두 확인한 뒤에만
`native_16k_execution=passed`로 기록했다. 스토어용 실제 화면 9장은
`/tmp/baseball-store-screens-0797760`에 있고 그중 6장을 Play에 등록했다.

실제 저용량 저장장치 조작은 모든 lane에서 `not_tested`다. 내부 QA의 ENOSPC proxy는 통과했지만
물리 저장장치 증거로 해석하지 않는다.

## Play Console

- 앱/package 생성 완료: `야구 못하면 또 환생함` / `com.solkim.baseball.android`
- 유료 상태, 대한민국 가격 `KRW 4,400`, 제품 세금 카테고리 `디지털 앱 판매`
- Play가 App Bundle의 `16KB 지원`, min API 26, target SDK 36, ARM64, OpenGL ES 3.0을 확인
- Play App Bundle 탐색기: versionCode 5 활성, 신규 설치 91.5MB, update 24.7MB,
  지원 Android 기기 5,573대
- Play App Signing 범용 APK: `com.solkim.baseball.android` / `1.0.0` (5), SHA-256
  `6bd2fb671b2616ceb0f57a993112a2484282769a8250ab347d5c4e6170b9e4de`, signing certificate
  SHA-256 `AE6A526DAC8935B0B4F3848D3AE63A31A24D9C3DFB2913E1FFA61FA5019C40E8`
- 자동 보호: 설치 프로그램 선택 활성, 보호 수준 `양호`
- internal track: `1.0.0 v5 비공개 QA`, versionCode 5 `내부 테스터에게 제공됨`
- internal opt-in: `https://play.google.com/apps/internaltest/4701687514240048485`
- closed Alpha: `1.0.0 v5 비공개 QA`, versionCode 5 전체 출시 **검토 중**. 대한민국 1개 국가,
  테스터 이메일 목록 1개이며 승인 전 versionCode 1을 계속 제공
- closed Alpha opt-in URL에서 본인 Google 계정이 `You are a tester` 상태임을 2026-08-13 확인했다.
  초대 pool은 13명이지만 본인 외 실제 opt-in과 14일 연속 참여는 아직 확인하지 않았다.
- 스토어 등록정보: ko-KR 이름/필수 문구/그래픽과 production screenshots 6장 등록
- 개인정보처리방침: `https://baseball-reincarnation.vercel.app/privacy`
- 고객지원: `https://baseball-reincarnation.vercel.app/support`
- 콘텐츠 등급, 타겟 연령(13+), 광고 없음, 광고 ID 없음, Data Safety, 정부·금융·건강 앱 선언 완료
- 2026-08-13 등록정보·선언·closed Alpha v1 변경은 검토를 통과해 게시됐다. 이후 Android Publisher
  edit `01963951099059515908`에서 v5 AAB, nativeCode symbols, internal/Alpha track을 validate하고
  원자 commit했다. 게시 개요에는 closed Alpha v5 `전체 출시 시작`이 **검토 중**으로 표시된다.
- Play App Bundle 탐색기 `다운로드` 탭에서 versionCode 5의 `네이티브 디버그 기호`
  `native-debug-symbols.zip` 27.5MB가 연결된 것을 확인했다.
- Firebase Android 전용 GA4 앱 `1.0.0`의 production 수신을 Console에서 확인했다. 최근 28일
  Android 활성 사용자 15명, `UnityPlayerActivity` 화면 15회, `first_open` 9회,
  `session_start` 8회, `session_ended` 6회, `onboarding_started` 3회가 보였고 앱 안정성은
  crash-free users 100%였다. 이는 전용 stream 수신 증거이며 의도적 test crash의
  IL2CPP symbolication 증거는 아니다.
- Amplitude의 별도 `Baseball Reincarnation Android Production` 프로젝트는 총 28개 실시간
  이벤트, 이벤트 유형 4개, 이벤트 속성 23개, 사용자 속성 7개를 수신했다. 기존 iOS/default
  프로젝트와 분리된 production API key 경계가 실제로 동작한다.
- 무료 체험: Google의 신규 유료 게임 정책상 60분 체험은 기본 활성 대상이며 별도 앱 코드가
  필요 없다. 현재 Console에는 별도 토글이 보이지 않았으므로 실제 테스터 계정에서 설치→60분
  만료→구매→동일 save 유지까지 확인하기 전 완료로 판정하지 않는다.
- 과거 검증: versionCode 2 AAB와 `nativeCode` symbols를 같은 Play edit에
  `application/octet-stream`으로 업로드하고 internal/closed Alpha track update까지 검증했다.
  edit commit은 아래 한국 개발자 계정 정보 403 오류로 거부됐고, partial publish를 막기 위해 edit
  전체를 삭제했다. v5에서는 Android Publisher 범위를 포함한 ADC로 같은 절차를 재실행했고
  AAB 응답 SHA-256이 로컬 값과 일치한 뒤 심볼·두 트랙·validate·commit을 모두 성공시켰다.
- 사업자등록번호는 국세청 발급 증빙과 대조한 실제 값으로 계정에 저장했다. 공개 개발자 전화번호는
  기존 확인 연락처와 같은 번호로 입력하고 SMS 6자리 인증을 요청했다.
- 공정거래위원회 통신판매사업자 공식 조회에서 현재 등록 정보가 없음을 확인했다. 따라서
  전자상거래 라이선스 번호와 신고기관은 추측해 입력하지 않았다. 정부24 통신판매업 신고 완료 뒤
  관할 지자체가 발급한 값으로 마감한다.
- v2 내부 앱 공유 API도 시도했으나 앱이 아직 게시된 것으로 인정되지 않아 `NOT_PUBLISHED`로
  거부됐다. 트랙 또는 edit 변경은 발생하지 않았다.

## 남은 출시 차단

1. **한국 개발자 계정 정보**: 사업자등록번호 저장은 완료했다. 남은 일은 요청된 공개 개발자
   전화번호 SMS 코드를 계정 소유자가 확인하는 것과, 정부24에서 통신판매업을 신고해 발급받은
   번호·신고기관을 입력하는 것이다. 현재 공정위 공식 조회에는 등록 정보가 없으므로 민감정보와
   인증번호를 자동 생성하거나 추측하지 않는다. 2026-08-13 Console UI의 v1 검토 제출은
   성공했지만, 이 정보는 유료 프로덕션 게시 전에 여전히 마감해야 한다.
2. **비공개 테스트 시간 조건**: 본인 Google 계정 1개는 실제 tester 상태다. 실제 Google 계정
   테스터 12명 이상이 opt-in하고 14일 이상 계속 참여해야 프로덕션 액세스를 신청할 수 있다.
3. **물리 기기**: Low/Mid/High 실제 스마트폰에서 성능(p95 frame/peak memory), TalkBack 전체
   탐색, gesture/3-button Back, 실제 low-storage, background/force-stop, 구매 체험 경계를 확인한다.
   에뮬레이터 3종 결과는 이 증거를 대체하지 않는다.
4. **Play 검토 산출물**: v5 AAB+native symbols 원자 commit과 internal 제공은 완료했다. closed Alpha
   v5 검토 결과, 자동 사전 출시 보고서, 지원 기기 CSV, 태블릿/ChromeOS/TV/XR 제외와 무료 체험을
   확인해야 한다. Device Catalog CSV/제외 도구는 별도 Device Catalog 이용약관 동의 전까지 사용하지 않는다.
5. **Crashlytics 실오류 복원**: Firebase Analytics와 Amplitude Android production 수신은
   Console에서 확인했다. 남은 운영 증거는 내부/비공개 설치의 의도적 test crash가 업로드한
   IL2CPP symbol과 결합되어 사람이 읽을 수 있는 stack으로 복원되는지 확인하는 것이다.
6. **키 복구**: production upload keystore는 저장소 밖과 CI secret에 있으나 계정 소유자의
   별도 오프라인 복구본을 만들어야 한다.

## 알려진 비차단 경고

- Play는 Unity IL2CPP 번들에 R8 metadata가 없고 앱 최적화 점수가 낮다고 표시한다. R8/ProGuard가
  Unity IL2CPP symbol pipeline의 대체물은 아니므로 v5 차단으로 분류하지 않되, 실제 성능 증거와
  이후 최적화 작업으로 추적한다.
- 미기록 상태는 “검증되지 않음”으로 취급하며, 위 차단이 닫히기 전 production 출시를 주장하지 않는다.
