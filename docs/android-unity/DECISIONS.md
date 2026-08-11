# Android Unity 결정 기록

작성 기준: 2026-08-11, `docs/ANDROID_UNITY_IMPLEMENTATION_PLAN_2026-08-11.md`

| 항목 | 결정 | 상태 |
|---|---|---|
| Unity | 6000.3.19f1 ARM64 editor | 고정 |
| 프로젝트 | `apps/android-unity` | 고정 |
| application ID | `com.solkim.baseball.android` | Play Console 생성 전 최종 재확인 필요 |
| 제품명 | 야구 못하면 또 환생함 | 고정 |
| 버전 | 1.0.0 (`versionCode` 1부터 단조 증가) | 고정 |
| Android | min API 26, target API 36 | 고정 |
| Unity Android toolchain | SDK platform 36, build-tools 36.0.0, NDK r27c (27.2.12479018), OpenJDK 17.0.18 | 설치 확인 |
| 아키텍처 | IL2CPP ARM64 | 고정 |
| 그래픽 | URP 17.3.0 mobile pipeline, OpenGLES3, 세로 | 소스 구성 완료; 라이선스 보유 Editor import 필요 |
| UI | UI Toolkit | 고정 |
| C# API 호환 | Unity UI의 `.NET Standard 2.1` 프로필. Editor API enum 이름은 legacy `NET_Standard_2_0` | 고정 |
| 에셋 | Local Addressables, 원격 catalog 없음 | 구성 코드·manifest 완료; 첫 Editor import 산출물 커밋 필요 |
| 저장 | 로컬 JSON envelope + SHA-256 + temp + 백업 3개 | 구현·fault-injection 정적 테스트 완료 |
| 계정/클라우드 | 없음 | 고정 |
| 분석 | Firebase Analytics + Amplitude, install UUID, 광고 ID 없음 | SDK/privacy gate 구현 완료; 외부 앱 등록·수신 검증 필요 |
| 크래시 | Firebase Crashlytics + IL2CPP symbols | SDK/CI upload 구현 완료; 외부 앱 등록·symbol 수신 검증 필요 |
| 판매 | 대한민국, 4,400원, 유료 게임 60분 무료 체험 | Play Console 설정 필요 |
| 폼 팩터 | small/normal 스마트폰, 세로, 태블릿/ChromeOS/TV/XR 제외 | AAB 업로드 후 CSV 검증 필요 |
| Native page size | AAB `PAGE_ALIGNMENT_16K` + 실제 16KB ARM64 기기 실행 | 둘 다 출시 차단; 미검증 |

## 외부 값

비밀값은 이 문서에 기록하지 않는다.

- Play Console app 생성: 미확인
- Firebase Android App ID: 미등록
- Amplitude 환경: 기존 iOS 프로젝트와 분리 가능한 Android production source로 등록 필요
- upload key alias/보관 책임자: 미확인
- 개인정보처리방침 HTTPS URL: 미확인

## 구현 중 결정

- Swift 런타임과 simulation sidecar는 포함하지 않는다.
- C# Core는 `UnityEngine`을 참조하지 않는다.
- iOS와 개별 난수 결과가 달라도 C# 내 결정론·규칙·분포 게이트를 지킨다.
- 시뮬레이션 결과를 저장한 뒤 3D 연출을 시작한다.
- Unity Ads, Unity Analytics, IAP, Authentication, Play Games Services를 포함하지 않는다.
- Android-only SDK import에서는 Firebase/Amplitude의 iOS, tvOS, desktop native binary를 제외한다. 관리 DLL과 Android Maven payload는 유지한다.
- 서드파티 버전, archive checksum, Maven 직접 의존성은 `THIRD_PARTY_LOCK.md`를 권위로 삼는다.
- Firebase Analytics를 production에서 사용하는 한 마스킹된 IP로 파생될 수 있는 대략적 위치를 Play Data Safety에 공개한다. Android 위치 권한과 GPS/정확한 위치는 사용하지 않는다. GA4의 세부 위치·기기 데이터 수집은 모든 판매 지역에서 끄고 증거를 남긴다.
- 분석 one-shot은 save aggregate의 lifetime/scoped receipt가 SDK 호출보다 먼저 원자 저장된다.
  lifetime receipt는 최대 128개를 절대 제거하지 않고, scoped receipt만 최근 512개를 유지한다.
  Firebase 의존성 확인 중 발생한 이벤트는 개인정보 검사를 거친 128개 startup FIFO에 보관한 뒤
  SDK 준비 직후 순서대로 비차단 전송한다. reset-all은 이전 익명 ID의 FIFO와 once 상태를 함께 지운다.
- 복귀 실험은 안정 install ID로 `guided`/`holdout`을 고정한다. 개인화 복귀 카드와 개인화 알림은
  guided에만 노출하며 holdout은 일반 다음 행동만 받는다. 종료된 일일 모드를 복귀 계획이나
  알림의 fallback으로 합성하지 않는다. pause는 계획과
  eligible receipt 저장을 끝낸 뒤 메인 스레드에서 session projection을 발행한다.
- 복귀 알림은 반복 trigger가 아닌 향후 서울 날짜 3개의 one-shot 알림이다. 앱 재개 때 horizon을
  다시 채운다. 알림 intent는 허용 목록으로 파싱한 비식별 안정 hash를 사용하며, 분석 영수증과
  내비게이션 완료 영수증을 aggregate에 따로 저장한다. 분석 저장 뒤 프로세스가 종료되면 SDK를
  중복 호출하지 않고 목적지만 복구하고, 완료 영수증까지 있으면 재시작·반복 intent 모두 무시한다.
  실제 route 소비 뒤 완료 저장 전 종료되는 경우 같은 허용 목적지의 재적용만 허용한다. reset-all은
  대기 intent를 지운다. API 33 미만은 런타임 알림 권한 거부 단계가 적용되지 않으며 smoke 증거에
  명시한다.
- 앱 밖 시스템 설정에서 알림 권한이 철회되면 재개 시 OS 상태를 다시 읽는다. 저장소가 busy이면
  correction을 idle까지 보류하고, aggregate의 `NotificationsEnabled=false` 저장 성공 뒤에만 UI와
  `reminder_changed(source=system)`을 확정한다. 실패한 correction은 다음 재개에서 재시도한다.
- Android 공유 성공의 관측 가능한 경계는 chooser를 연 시점이다. PNG와 한국어 요약 text를 같은
  `ACTION_SEND`에 싣되 Android가 완료 callback을 보장하지 않으므로 `life_card_shared`와
  `life_card_share_completed`는 보내지 않는다(`PARITY_EXCEPTIONS.md` EX-009).
- Medium managed stripping에서 JSON/reflective pitch 재개 타입을 보존하도록 `link.xml`에
  `Baseball.Core`, `Baseball.Application`, `Baseball.Presentation`, `Unity.Newtonsoft.Json`을 명시한다.
- `MobileRenderPipelineConfiguration`이 저사양 스마트폰 기준 URP asset/renderer를 생성하고 Graphics/Quality 양쪽에 지정한다. HDR, depth/opaque texture, 추가 광원, 실시간 그림자는 v1에서 끈다.
- `LocalAddressablesConfiguration`이 142개 runtime entry를 로컬 LZ4 bundle로 구성한다. remote catalog와 remote load path는 빌드 실패 조건이다.
- Android launcher는 legacy 512 아이콘, adaptive background/foreground, Android 13 monochrome themed icon을 함께 사용한다.
- Play feature graphic과 store icon은 OpenAI imagegen으로 만든 가상 새벽 야구장/공 모티프를
  사용한다. 실존 구단 IP를 넣지 않고 원본 참조 hash, PNG 치수·색상형식, 생성 provenance를
  `StoreAssets/manifest.json`으로 고정한다. 실제 release screenshot은 서명 기기 capture 전에는 만들지 않는다.
- 서명 후보는 clean worktree, production 분석 설정, 일치하는 Firebase package, upload keystore,
  `BASEBALL_UPLOAD_CERT_SHA256` 인증서 pin, IL2CPP public symbols를 모두 요구한다. Firebase CLI
  15.26.0 symbol upload 영수증과 실기기/Play 증거가 없으면 production RC 증거가 완성되지 않는다.
- RC build와 기기 smoke는 bundletool config의 `PAGE_ALIGNMENT_16K`를 fail-closed로 검사한다.
  RC는 동일 upload key로 signed universal APK를 만들고 `zipalign -P 16` 및 모든 ARM64
  `.so` ELF LOAD segment의 최소 `0x4000` 정렬을 검사한다. smoke도 기기용 APKS의 모든 APK에
  `zipalign -c -P 16 -v 4`와 같은 ELF 검사를 추가 적용한다. bundle
  config 하나만으로 native binary 호환성을 통과 처리하지 않는다. 별도로
  `getconf PAGE_SIZE=16384` 기기에서 install/launch/투구/crash·ANR 0 증거가 필요하다.
- RC wrapper는 source manifest만 믿지 않는다. AAB base merged manifest를 dump해 package, 네 개
  permission, portrait/non-resizable activity, non-exported share provider, touchscreen, small/normal
  12개 screen을 검사하고, universal/device APKS도 `apkanalyzer` permission union을 다시 확인한다.
- 전역 copy 검사는 계속 모든 플랫폼을 검사한다. 병렬 iOS 작업의 실패와 Android 포트의 결과를
  구분할 수 있도록 `npm run check:copy:android:unity`를 추가했으며, 이는 전역 gate를 대체하지 않는다.
- 2D shell은 app bootstrap에서 60fps를 요청한다. 첫 PitchStage는 RAM 6GB 이상을 High 후보로
  삼고 60-frame p95가 28ms를 넘거나 OS low-memory callback을 받으면 Low(30fps, render scale
  0.85, MSAA off, 짧은 trail, particle 35%, camera impulse off)로 내린다. 현재 thermal API
  bridge가 없으므로 memory+frame+low-memory가 fail-safe 정책이며 실제 Low/Mid/High 기기 p95로
  출시 전에 threshold를 재검증한다.

## 현재 검증 경계

- C# Core/Application/Persistence 및 Unity reference assembly 정적 컴파일은 통과했다.
- 실제 Unity EditMode/PlayMode import와 Android IL2CPP AAB는 이 머신의 만료된 Unity Personal entitlement 때문에 실행되지 않았다.
- 라이선스를 갱신한 첫 Unity import는 `.meta`, Addressables settings, URP asset/renderer를 생성한다. 이 산출물을 검토·커밋한 뒤 같은 commit으로 tests와 RC build를 다시 실행한다.
- AAB 기기 smoke, Play 무료 체험, 지원 기기 CSV, Firebase/Amplitude 수신, Crashlytics symbolication은 외부 출시 차단 항목이다.
