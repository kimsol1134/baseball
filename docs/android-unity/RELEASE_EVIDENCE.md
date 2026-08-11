# Android Unity 릴리스 증거

현재 상태: 구현 중. RC가 아니며 이 문서의 빈 항목은 출시 차단 항목이다.

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

## 자동 검증

- Unity 참조 소스 컴파일: `npm run test:unity:references`
  - 2026-08-12, Unity `6000.3.19f1` 설치 참조로 production player, internal-QA player, Core, Platform, `Baseball.Platform.Tests`, Presentation EditMode tests, Android Editor source closure를 각각 `TreatWarningsAsErrors=true`로 컴파일
  - 결과: 경고 0개, 오류 0개
  - `tools/unity-reference-compile.sh`는 Unity 실행 파일, 관리 참조, Input System, URP 및 Unity NUnit 참조가 하나라도 없으면 종료 코드 2로 실패한다. `bin`/`obj`는 `mktemp`로 만든 저장소 밖 디렉터리에만 쓴 뒤 종료 시 삭제한다.
- static/EditMode 순수 계약: `npm run test:unity:static` — 319/319 통과
- EditMode: 2026-08-12 `npm run test:unity` 실행은 설치된 Editor의 유효 라이선스 부재(exit 198)로 테스트 실행 전 차단. 라이선스가 있는 Unity batchmode 결과 필요
- PlayMode: 위와 동일하게 유효 라이선스 부재로 테스트 실행 전 차단. Addressable 구장/portrait framing/missing-asset fail-closed PlayMode 소스는 참조 컴파일 0경고/0오류
- copy/IP: `npm run check:copy:android:unity` — 내부 용어 38종·실존 야구 IP 42종 미노출
- design: `npm run check:design-system` — 위반 0, 고대비 토큰/WCAG AA/공통 컴포넌트 계약 통과
- asset manifest: `npm run check:unity-assets` — 150 files (118 images, 7 icon sources, 24 audio) 통과
- Android 소스 계약: `npm run check:android:unity` — 통과. 이 결과 자체는 RC 증거가 아니다.
- save fault injection:
- Swift/C# fixture:
- Monte Carlo:

## Android 검증

- 기기 매트릭스:
- cold start:
- pitch p95 frame:
- peak memory:
- offline full loop:
- process-kill recovery:
- TalkBack/font 200%:
- crash/ANR:
- 16KB page-size 기기(`getconf PAGE_SIZE=16384`, `native_16k_execution=passed`) install/launch/full pitch:

## Play

- 내부 트랙:
- 무료 체험 시작/만료/구매 후 save:
- 지원 기기 CSV:
- 태블릿/ChromeOS/TV/XR 제외:
- 사전 출시 보고서:
- Data Safety/content rating/listing:

## 알려진 문제와 rollback

- 없음으로 승인하기 전까지 미기록 상태는 “검증되지 않음”으로 취급한다.
