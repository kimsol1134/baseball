# Android Unity 릴리스 증거

현재 상태: production-candidate 소스와 로컬 Unity/16KB 내부 검증, production upload key,
Firebase/Amplitude 프로젝트·CI secret 연결 완료. clean commit 서명 RC·실기기·Play 검증 대기.
**승인된 RC가 아니며** production 칸의 빈 항목은 출시 차단 항목이다.

## 빌드

- Git commit:
- Dirty 여부:
- Unity: 6000.3.19f1
- application ID: `com.solkim.baseball.android`
- version/versionCode:
- AAB SHA-256:
- IL2CPP symbol SHA-256:
- Crashlytics symbol upload receipt:
- AAB signing certificate SHA-256 pin:
- bundletool `PAGE_ALIGNMENT_16K` config:
- signed universal/device-targeted APK `zipalign -P 16` report (`apk-zipalign.txt`):
- ARM64 `.so` `llvm-readelf -lW` LOAD alignment report (`elf-alignment.txt`):

### 내부 검증 산출물 — production RC 아님

- source baseline commit: `358a706a9cf50d669928aa7d79164e9bb2860955` + dirty working tree
- version/versionCode: `1.0.0` / `1`
- distribution/build: `internal-verification`, Development + `BASEBALL_INTERNAL_QA`, debug signing
- AAB: `artifacts/android/1.0.0-1/baseball-android-1.0.0-1-debug-signed-verification.aab`
- AAB SHA-256: `03fe9b59c64728fa972c34cf9bb989a59334cb9003d97db88545ebfcb251091a`
- IL2CPP symbols SHA-256: `89a52b969153f697163fbcf8451a543bbeec9b6862fb6e3e0f4d42e380b291d8`
- build manifest/checksums: `artifacts/android/1.0.0-1/`
- 16KB internal smoke: `artifacts/android-unity-smoke/20260812T004753Z/`

## 자동 검증

- Unity 참조 소스 컴파일: `npm run test:unity:references`
  - 2026-08-12, Unity `6000.3.19f1` 설치 참조로 production player, internal-QA player, Core, Platform, `Baseball.Platform.Tests`, Presentation EditMode tests, Android Editor source closure를 각각 `TreatWarningsAsErrors=true`로 컴파일
  - 결과: 경고 0개, 오류 0개
  - `tools/unity-reference-compile.sh`는 Unity 실행 파일, 관리 참조, Input System, URP 및 Unity NUnit 참조가 하나라도 없으면 종료 코드 2로 실패한다. `bin`/`obj`는 `mktemp`로 만든 저장소 밖 디렉터리에만 쓴 뒤 종료 시 삭제한다.
- static/EditMode 순수 계약: `npm run test:unity:static` — 433/433 통과
- Unity Test Runner: `npm run test:unity` — 2026-08-12 실제 Unity 6000.3.19f1 batchmode 통과
  - EditMode 주요 어셈블리: Core 46/46, Application 119/119, Platform 60/60,
    Presentation 240/240, HighSchool 39/39, Pro 25/25, InternalQa 4/4
  - bootstrap/persistence 격리 lifecycle·fault·100회 round-trip 전 항목 통과
  - PlayMode: 14/14 통과
  - XML/log: `artifacts/unity/editmode-*.xml`, `artifacts/unity/playmode.xml`
- Android verification build: `BASEBALL_BUILD_MODE=verification bash tools/unity-android-build.sh` —
  ARM64 IL2CPP Release compiler configuration AAB/public symbols 생성과 wrapper 증거 검증 통과
- strict Unity import gate: `BASEBALL_REQUIRE_UNITY_META=1 node tools/check-android-unity-release.mjs` —
  전체 `Assets` 파일·디렉터리 missing `.meta` 0, reviewed Addressables/URP generated asset 0
- internal device smoke: 16KB API 35 ARM64 전용 emulator에서 clean install, cold/resume,
  portrait/rotation block, offline, notification denial, font 200%, low-memory, high/low pitch,
  save corruption/fault/failure proxy, analytics fixture, tutorial checkpoint restart, crash probe 통과.
  Firebase/Amplitude·shader·StrictMode, crash/ANR, PII scan 0건
- copy/IP: `npm run check:copy:android:unity` — 내부 용어 38종·실존 야구 IP 42종 미노출
- design: `npm run check:design-system` — 위반 0, 고대비 토큰/WCAG AA/공통 컴포넌트 계약 통과
- asset manifest: `npm run check:unity-assets` — 150 files (118 images, 7 icon sources, 24 audio) 통과
- Android 소스 계약: `npm run check:android:unity` — 통과. missing Unity-generated `.meta` 0,
  missing reviewed Addressables/URP asset 0. 이 결과 자체는 production RC 증거가 아니다.
- save fault injection: 정적 suite에서 canonical/backup 실패, stale revision, 투구 suspend/consume/complete, 분석 receipt 저장 실패의 no-publish·retry 계약 통과. 실제 Android 저장장치 fault lane은 기기 증거 대기
- reset crash points: journal fsync 이후 repository 삭제를 1회만 수행하고 install ID·분석·리뷰·알림·
  stale epoch·공유 PNG 정리를 receipt로 재개한다. 초기화 뒤 새 진행을 저장하고 종료해도 다음 부팅에서
  repository를 다시 지우지 않는다. repository 삭제 뒤 ID 발행이 실패하면 이전 in-memory store를
  write-poison하여 pause·resume·명령이 이전 install save를 다시 만들지 못하게 하고 candidate startup으로
  수렴한다. ID 저장 오류는 임시 ID를 만들지 않고 startup retry 경계로 전달하며, 알림 서비스도 별도
  ID를 만들지 않고 Ready aggregate의 ID가 바인딩될 때까지 권유·예약·intent 소비를 닫는다.
- Swift/C# fixture: Pitch seed 1…128 exact 및 훈련-v4 seed `20260811` exact 통과
- Monte Carlo: Pitch seed 1…10,000 outcome 집계 exact 통과
- RC 기기 smoke 연결: production 모드는 현재 clean Git commit과 일치하는 `build-manifest.json`,
  `checksums.sha256`, AAB/symbol SHA-256, production distribution, IL2CPP Release 및
  `BASEBALL_UPLOAD_CERT_SHA256` pin을 모두 검증한다. 16KB 기기에서는 실제 저장형 투구의
  `BASEBALL_PITCH_PRESENTATION_COMPLETED` marker까지 확인해야만
  `native_16k_execution=passed`를 기록한다. 내부 검증 AAB의 16KB high/low pitch는 통과했지만,
  production 서명 AAB·물리 스마트폰 증거가 아니므로 해당 production 값은 아직 비어 있다.

## Android 검증

- 기기 매트릭스: `DEVICE_MATRIX.md`; 16KB API 35 ARM64 emulator 내부 lane 통과
- cold start: internal `passed`
- pitch p95 frame:
- peak memory:
- offline full loop: internal relaunch `passed`; production 물리기기 대기
- process-kill recovery: internal tutorial checkpoint relaunch `passed`
- TalkBack/font 200%: font 200% internal `passed`; TalkBack 물리기기 대기
- crash/ANR: internal scan `passed`
- 16KB page-size 기기(`getconf PAGE_SIZE=16384`, `native_16k_execution=passed`) install/launch/full pitch:

## Play

- 콘솔 사전 확인: 2026-08-12 로그인 성공, 앱 미생성, package 사용 가능 확인. 법적 선언 직전까지 생성 양식 준비
- 개인정보처리방침: `https://baseball-reincarnation.vercel.app/privacy` — HTTPS 200, Android
  Firebase/Amplitude/Crashlytics 처리 범위와 문의·삭제 절차 공개
- 고객지원: `https://baseball-reincarnation.vercel.app/support` — HTTPS 200, iOS/Android 저장·복구·
  구매·문제 제보 안내 및 지원 이메일 공개
- 내부 트랙: 앱 생성·production AAB 업로드 전
- 무료 체험 시작/만료/구매 후 save:
- 지원 기기 CSV:
- 태블릿/ChromeOS/TV/XR 제외:
- 사전 출시 보고서:
- Data Safety/content rating/listing:

## 현재 외부 차단

- Play 앱 최종 생성은 개발자 프로그램 정책·미국 수출법을 계정 소유자가 명시 확인해야 한다.
- Firebase project/Android app/전용 GA4 property·stream과 별도 Amplitude Android production project를
  생성했다. config/API key/최소권한 Crashlytics service account는 저장소 밖과 GitHub Actions secret에
  연결했고 GA4 세부 위치·기기 수집 및 광고 개인 최적화를 전 지역에서 껐다.
- production upload keystore·alias·암호·certificate SHA-256 pin을 생성해 저장소 밖 Keychain/Application
  Support와 GitHub Actions secret에 연결했다. 별도 오프라인 복구본은 아직 필요하다.
- production Firebase/Amplitude 수신과 Crashlytics symbolication receipt가 없다.
- 연결된 Android는 16KB API 35 emulator뿐이며 Low/Mid/High 물리 스마트폰과 Play farm 증거가 없다.
- worktree는 Unity import 산출물과 구현 변경으로 dirty이므로 통합 검증 뒤 clean commit·push하고 CI RC를 실행해야 한다.

## 알려진 문제와 rollback

- 없음으로 승인하기 전까지 미기록 상태는 “검증되지 않음”으로 취급한다.
