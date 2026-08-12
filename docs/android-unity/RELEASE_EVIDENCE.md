# Android Unity 릴리스 증거

기준 시각: 2026-08-12 KST
현재 상태: clean commit의 Unity 6000.3.19f1 테스트, production upload-key 서명 v2 AAB,
Firebase Crashlytics symbol upload, API 29/35(16KB)/36 production smoke, Play 내부·비공개
트랙 구성이 완료됐다. v2 AAB와 Play native symbols를 같은 edit에 올리는 데도 성공했지만 한국
개발자 계정 정보 오류로 원자 commit 전에 edit를 폐기했다. 사업자등록번호는 실제 증빙과 대조해
계정에 저장했으며 공개 전화번호는 SMS 인증 대기 중이다. **프로덕션 RC 승인은 아직 아니다.** 아래 사람·시간·물리기기 조건은
자동화 증거로 대체하지 않는다.

## 빌드

- Git commit: `a65b9da366408b6026c96feff6ee6d8b45761da1`
- build 입력: clean (`gitDirty=false`)
- GitHub Actions: [run 31609581076](https://github.com/kimsol1134/baseball/actions/runs/31609581076) —
  Static contracts, Licensed Unity tests, Signed production candidate 모두 성공
- PR P0 CI: [run 31616614826](https://github.com/kimsol1134/baseball/actions/runs/31616614826) —
  React, iOS, Swift macOS/Windows, Desktop macOS/Windows 모두 성공
- Unity PR gate: [run 31616614936](https://github.com/kimsol1134/baseball/actions/runs/31616614936) —
  Static contracts와 Licensed Unity tests 성공
- Unity: `6000.3.19f1`
- application ID: `com.solkim.baseball.android`
- version/versionCode: `1.0.0` / `2`
- distribution/build: `production`, Development=false, Internal QA=false
- Android: min API 26, target API 36, ARM64, OpenGLES3, IL2CPP Release
- AAB: `baseball-android-1.0.0-2.aab` (92,235,415 bytes)
- AAB SHA-256: `39c78b869feea4edd1316eed4c91940944dcf77e173713dd7f9643dbb86818e9`
- IL2CPP symbols: `baseball-android-1.0.0-2-1.0.0-v2-IL2CPP.symbols.zip`
- IL2CPP symbol SHA-256: `bf43df4a3ff7e9fe2c0bf58e754dde96afe8387e263ad404656253abc7dfa285`
- Firebase symbol receipt: `uploaded`, Firebase CLI `15.26.0`,
  `2026-08-12T15:18:02.092Z`
- upload certificate SHA-256 pin:
  `D0A8EC4FDCEC6F7F74BBEBCE747CB3D2FA308DB72CCA106D30AA2A782DAA445F`
- bundletool: `1.18.3`, native library alignment `PAGE_ALIGNMENT_16K`
- device APKS `zipalign -P 16`: `passed` (APK 2개)
- ARM64 ELF LOAD alignment: `passed` (native library 14개, minimum `0x4000`)
- merged manifest/package/permission/screen-set 검증: `passed`
- CI artifact retention: 30일. 검증용 로컬 사본은
  `/private/tmp/baseball-v2-artifact.mmN5iv/android/1.0.0-2`에 있다.

## 자동 검증

- `npm run test:unity:static`: 433/433 통과
- `npm run test:unity:references`: production player, internal-QA player, Core, Platform,
  Platform tests, Presentation tests, Android Editor 모두 warning/error 0
- Unity Test Runner:
  - EditMode 주요 어셈블리: Core 46/46, Application 119/119, Platform 60/60,
    Presentation 240/240, HighSchool 39/39, Pro 25/25, InternalQa 4/4
  - bootstrap/persistence 격리 lifecycle·fault·100회 round-trip 전 항목 통과
  - PlayMode 14/14 통과
  - CI test artifact digest:
    `3053dfc3173c1ecaf5be35102bd95e4617654c7b905351ab2219153adf855545`
- strict Unity import gate: 전체 `Assets` 파일·디렉터리 missing `.meta` 0,
  missing reviewed Addressables/URP asset 0
- copy/IP: 내부 용어 38종·실존 야구 IP 42종 미노출
- design: 원시 색상·레거시 토큰 위반 0, 고대비/WCAG AA/공통 컴포넌트 계약 통과
- asset manifest: 150 files (118 images, 7 icon sources, 24 audio) 통과
- Android source/build contract: 통과
- Swift/C# fixture: Pitch seed 1…128 exact, 훈련-v4 seed `20260811` exact
- Monte Carlo: Pitch seed 1…10,000 outcome 집계 exact

## Android production smoke

세 실행은 같은 v2 AAB와 build manifest/checksum/Git commit/certificate pin을 검증하고 clean install했다.
각각 cold start, first-interactive, same-process resume, portrait/rotation block, offline relaunch,
font 200%, low-memory callback, foreground, crash/ANR·PII·runtime bridge scan을 통과했다.

| 기기 | API/page | 결과 | 추가 증거 |
|---|---|---|---|
| `Android_SDK_built_for_arm64` low-memory emulator | API 29 / 4KB | passed | 알림 권한은 API<33 비대상; `/private/tmp/baseball-v2-api29-smoke-a65b9da/20260812T160137Z` |
| `sdk_gphone16k_arm64` | API 35 / 16KB | passed | 실제 production 투구, shader ready, 16KB native 실행·정렬 모두 passed; `/private/tmp/baseball-v2-16k-smoke-a65b9da/20260812T155332Z` |
| `sdk_gphone64_arm64` target-edge emulator | API 36 / 4KB | passed | 알림 거부 포함; `/private/tmp/baseball-v2-api36-smoke-a65b9da/20260812T160713Z` |

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
- 자동 보호: 설치 프로그램 선택 활성, 보호 수준 `양호`
- internal track: versionCode 1 `내부 테스터에게 제공됨`
- internal opt-in: `https://play.google.com/apps/internaltest/4701687514240048485`
- closed Alpha: versionCode 1, 대한민국 1개 국가, 테스터 이메일 목록 1개, 전체 출시 구성 완료
- 스토어 등록정보: ko-KR 이름/필수 문구/그래픽과 production screenshots 6장 등록
- 개인정보처리방침: `https://baseball-reincarnation.vercel.app/privacy`
- 고객지원: `https://baseball-reincarnation.vercel.app/support`
- 콘텐츠 등급, 타겟 연령(13+), 광고 없음, 광고 ID 없음, Data Safety, 정부·금융·건강 앱 선언 완료
- 무료 체험: Google의 신규 유료 게임 정책상 60분 체험은 기본 활성 대상이며 별도 앱 코드가
  필요 없다. 현재 Console에는 별도 토글이 보이지 않았으므로 실제 테스터 계정에서 설치→60분
  만료→구매→동일 save 유지까지 확인하기 전 완료로 판정하지 않는다.
- Play native debug symbols: versionCode 2 AAB와 `nativeCode` symbols를 같은 Play edit에
  `application/octet-stream`으로 업로드하고 internal/closed Alpha track update까지 검증했다.
  edit commit은 아래 한국 개발자 계정 정보 403 오류로 거부됐고, partial publish를 막기 위해 edit
  전체를 삭제했다. 따라서 현재 Play 활성 버전은 안전하게 versionCode 1이며, 계정 정보 해결 후
  동일 v2 쌍을 새 edit에서 다시 올린다.
- 사업자등록번호는 국세청 발급 증빙과 대조한 실제 값으로 계정에 저장했다. 공개 개발자 전화번호는
  기존 확인 연락처와 같은 번호로 입력하고 SMS 6자리 인증을 요청했다.
- 공정거래위원회 통신판매사업자 공식 조회에서 현재 등록 정보가 없음을 확인했다. 따라서
  전자상거래 라이선스 번호와 신고기관은 추측해 입력하지 않았다. 정부24 통신판매업 신고 완료 뒤
  관할 지자체가 발급한 값으로 마감한다.
- v2 내부 앱 공유 API도 시도했으나 앱이 아직 게시된 것으로 인정되지 않아 `NOT_PUBLISHED`로
  거부됐다. 트랙 또는 edit 변경은 발생하지 않았다.

## 남은 출시 차단

1. **한국 개발자 계정 정보**: Play 게시 개요의 유일한 제출 오류다. 사업자등록번호 저장은
   완료했다. 남은 일은 요청된 공개 개발자 전화번호 SMS 코드를 계정 소유자가 확인하는 것과,
   정부24에서 통신판매업을 신고해 발급받은 번호·신고기관을 입력하는 것이다. 현재 공정위 공식
   조회에는 등록 정보가 없으므로 민감정보와 인증번호를 자동 생성하거나 추측하지 않는다.
2. **비공개 테스트 시간 조건**: Play 대시보드 기준 현재 참여 선택 0명이다. 실제 Google 계정
   테스터 12명 이상이 opt-in하고 14일 이상 계속 참여해야 프로덕션 액세스를 신청할 수 있다.
3. **물리 기기**: Low/Mid/High 실제 스마트폰에서 성능(p95 frame/peak memory), TalkBack 전체
   탐색, gesture/3-button Back, 실제 low-storage, background/force-stop, 구매 체험 경계를 확인한다.
   에뮬레이터 3종 결과는 이 증거를 대체하지 않는다.
4. **Play 검토 산출물**: 계정 정보 해결 뒤 v2 AAB+native symbols를 같은 edit로 원자 commit하고,
   현재 pending 변경을 검토 제출한 뒤
   사전 출시 보고서·지원 기기 CSV·태블릿/ChromeOS/TV/XR 제외·무료 체험을 확인한다.
5. **운영 수신**: 내부/비공개 설치에서 Firebase Analytics·Amplitude 수신과 실제 Crashlytics
   symbolication을 확인한다.
6. **키 복구**: production upload keystore는 저장소 밖과 CI secret에 있으나 계정 소유자의
   별도 오프라인 복구본을 만들어야 한다.

## 알려진 비차단 경고

- Play는 Unity IL2CPP 번들에 R8 metadata가 없고 앱 최적화 점수가 낮다고 표시한다. R8/ProGuard가
  Unity IL2CPP symbol pipeline의 대체물은 아니므로 v2 차단으로 분류하지 않되, 실제 성능 증거와
  이후 최적화 작업으로 추적한다.
- 미기록 상태는 “검증되지 않음”으로 취급하며, 위 차단이 닫히기 전 production 출시를 주장하지 않는다.
