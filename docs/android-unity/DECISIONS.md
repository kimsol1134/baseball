# Android Unity 결정 기록

작성 기준: 2026-08-11, `docs/ANDROID_UNITY_IMPLEMENTATION_PLAN_2026-08-11.md`

| 항목 | 결정 | 상태 |
|---|---|---|
| Unity | 6000.3.19f1 ARM64 editor | 고정 |
| 프로젝트 | `apps/android-unity` | 고정 |
| application ID | `com.solkim.baseball.android` | Firebase·Play 앱 등록 완료 |
| 제품명 | 야구 못하면 또 환생함 | 고정 |
| 버전 | 1.0.0 (`versionCode` 1부터 단조 증가) | 고정 |
| Android | min API 26, target API 36 | 고정 |
| Unity Android toolchain | SDK platform 36, build-tools 36.0.0, NDK r27c (27.2.12479018), OpenJDK 17.0.18 | 설치 확인 |
| 아키텍처 | IL2CPP ARM64 | 고정 |
| 그래픽 | URP 17.3.0 mobile pipeline, OpenGLES3, 세로 | Editor import·내부 AAB 검증 완료 |
| UI | UI Toolkit | 고정 |
| C# API 호환 | Unity UI의 `.NET Standard 2.1` 프로필. Editor API enum 이름은 legacy `NET_Standard_2_0` | 고정 |
| 에셋 | Local Addressables, 원격 catalog 없음 | Editor 생성 산출물 검토·clean commit 고정 완료 |
| 저장 | 로컬 JSON envelope + SHA-256 + temp + 백업 3개 | 구현·fault-injection 정적 테스트 완료 |
| 계정/클라우드 | 없음 | 고정 |
| 분석 | Firebase Analytics + Amplitude, install UUID, 광고 ID 없음 | production 프로젝트·CI secret 연결 완료; 실제 수신 검증 필요 |
| 크래시 | Firebase Crashlytics + IL2CPP symbols | CI symbol upload 영수증 완료; 실제 symbolication 검증 필요 |
| 판매 | 대한민국, 4,400원, 유료 게임 60분 무료 체험 | 가격 완료; 실제 Play 체험 경계 검증 필요 |
| 폼 팩터 | small/normal 스마트폰, 세로, 태블릿/ChromeOS/TV/XR 제외 | AAB 업로드 완료; 지원 기기 CSV 검증 필요 |
| Native page size | AAB `PAGE_ALIGNMENT_16K` + 실제 16KB ARM64 기기 실행 | production AAB의 API 35 16KB emulator 수직 루프 통과; 물리기기 대기 |

## 외부 값

비밀값은 이 문서에 기록하지 않는다.

- Play Console: 2026-08-12 `com.solkim.baseball.android` 유료 게임 생성, 대한민국 4,400원,
  internal versionCode 1 제공 및 closed Alpha 대한민국 전체 출시 구성 완료. 게시 제출은 한국 개인
  개발자 공개 전화 인증과 유료 앱 사업자·통신판매 정보가 없어 차단됐다.
- Firebase: project `baseball-reincarnation-android`(project number `951359066339`), Android App ID
  `1:951359066339:android:ea391d85ed2bac524cf5d6`, package `com.solkim.baseball.android` 등록 완료.
  GA4 전용 property `549574769`/Android stream `15421807578`를 기존 blog property와 분리해 연결했다.
  세부 위치·기기 수집은 off, 광고 개인 최적화는 307개 전 지역 off, Google Signals는 미활성이다.
- Amplitude: 별도 `Baseball Reincarnation Android Production` 프로젝트 생성 완료. API key는 macOS
  Keychain과 GitHub Actions secret에만 보관하고 저장소·문서·로그에는 기록하지 않는다.
- Firebase Crashlytics symbol uploader:
  `baseball-crash-symbol-uploader@baseball-reincarnation-android.iam.gserviceaccount.com`에
  `roles/firebasecrash.symbolMappingsAdmin`만 부여했다. service-account JSON은 저장소 밖과 GitHub
  Actions secret에만 보관한다.
- upload key alias/보관: `baseball-upload`; 인증서 SHA-256은 CI pin과 Firebase Android app에 등록했다.
  keystore와 암호는 저장소 밖 Application Support/macOS Keychain에, 동일 값은 GitHub Actions secret에
  보관한다. 계정 소유자의 별도 오프라인 복구본은 출시 전 추가한다.
- 개인정보처리방침 HTTPS URL: `https://baseball-reincarnation.vercel.app/privacy` (2026-08-12 배포·HTTPS 200 확인)
- 고객지원 HTTPS URL: `https://baseball-reincarnation.vercel.app/support` (2026-08-12 배포·HTTPS 200 확인)

## 구현 중 결정

- Swift 런타임과 simulation sidecar는 포함하지 않는다.
- C# Core는 `UnityEngine`을 참조하지 않는다.
- iOS와 개별 난수 결과가 달라도 C# 내 결정론·규칙·분포 게이트를 지킨다.
- 시뮬레이션 결과를 저장한 뒤 3D 연출을 시작한다.
- 계획 §3.2의 `10_Shell`/additive `20_PitchStage`/`90_PresentationSandbox` 장면 분리는
  명시적 수명 경계로 대체한다. Player build에는 빈 `00_Bootstrap`만 넣고, `AppRoot`가 Store를,
  `DontDestroyOnLoad` UI shell이 View stack을 소유한다. 투구 시작 때 저장 상태와 Addressables
  2D 자산이 준비된 뒤 전용 `Pitch Presentation Stage` 오브젝트를 만들고, 실패·중단·완료 때
  오브젝트를 파괴하면서 모든 lease와 URP 품질 override를 복원한다. 따라서 Core/Application
  상태는 scene object에 들어가지 않고 additive unload와 같은 메모리·실패 불변식을 지킨다.
  Editor-only sandbox는 고정 request의 EditMode/PlayMode presentation tests와 production/internal
  reference compile로 대체하며 Player scene list에 QA surface를 넣지 않는다.
- Unity Ads, Unity Analytics, IAP, Authentication, Play Games Services를 포함하지 않는다.
- Android-only SDK import에서는 Firebase/Amplitude의 iOS, tvOS, desktop native binary를 제외한다. 관리 DLL과 Android Maven payload는 유지한다.
- 서드파티 버전, archive checksum, Maven 직접 의존성은 `THIRD_PARTY_LOCK.md`를 권위로 삼는다.
- Firebase Analytics를 production에서 사용하는 한 마스킹된 IP로 파생될 수 있는 대략적 위치를 Play Data Safety에 공개한다. Android 위치 권한과 GPS/정확한 위치는 사용하지 않는다. GA4의 세부 위치·기기 데이터 수집은 모든 판매 지역에서 끄고 증거를 남긴다.
- 분석 one-shot은 save aggregate의 lifetime/scoped receipt가 SDK 호출보다 먼저 원자 저장된다.
  lifetime receipt는 최대 128개를 절대 제거하지 않고, scoped receipt만 최근 512개를 유지한다.
  Firebase 의존성 확인 중 발생한 이벤트는 개인정보 검사를 거친 128개 startup FIFO에 보관한 뒤
  SDK 준비 직후 순서대로 비차단 전송한다. reset-all은 이전 익명 ID의 FIFO와 once 상태를 함께 지운다.
- reset-all 확인 뒤에는 파괴 작업 전에 no-backup journal에 previous/candidate install ID를 fsync하며
  이 intent는 취소하지 않는다. repository reset receipt가 없는 부팅만 save 후보를 삭제하고, 이후
  install ID publication·analytics/review/reminder·stale epoch 파일·share PNG cache를 각 receipt로
  재개한다. repository 삭제 뒤 identity 발행이 실패한 이전 in-memory store는 write-poison하여
  lifecycle과 명령 저장이 이전 install canonical을 다시 만들지 못하게 한다. journal cleanup이 늦어도
  초기화 뒤 새 진행은 다시 삭제하지 않는다. 익명 ID 읽기/쓰기 실패는 임시 메모리 ID로 숨기지 않고
  store `OpenAsync`의 startup-failure/retry 경계로 전달한다. 알림은 `Awake`에서 ID를 별도 획득하지
  않고 Ready aggregate의 ID를 바인딩하며, 바인딩 실패 동안 권유·예약·intent 소비를 fail-closed한다.
- 복귀 실험은 안정 install ID로 `guided`/`holdout`을 고정한다. 개인화 복귀 카드와 개인화 알림은
  guided에만 노출하며 holdout은 일반 다음 행동만 받는다. 종료된 일일 모드를 복귀 계획이나
  알림의 fallback으로 합성하지 않는다. pause는 계획과
  eligible receipt 저장을 끝낸 뒤 메인 스레드에서 session projection을 발행한다.
- 복귀 알림은 반복 trigger가 아닌 향후 서울 날짜 3개의 one-shot 알림이다. 앱 재개 때 horizon을
  다시 채운다. 알림 intent는 허용 목록으로 파싱한 비식별 안정 hash를 사용하며, 분석 영수증과
  내비게이션 완료 영수증을 aggregate에 따로 저장한다. 분석 저장 뒤 프로세스가 종료되면 SDK를
  중복 호출하지 않고 목적지만 복구하고, 완료 영수증까지 있으면 재시작·반복 intent 모두 무시한다.
  실제 route 소비 뒤 완료 저장 전 종료되는 경우 같은 허용 목적지의 재적용만 허용한다. reset-all은
  대기 intent를 지우고 현재 Activity의 reminder intent를 비운다. Activity가 즉시 비워지지 않는
  기기에서는 이전 안정 token hash를 process-local tombstone으로 막으며, 새 token은 허용한다.
  tombstone은 새 프로세스/새 install ID로 넘기지 않고 비워진 Activity intent가 수동 재개 시의
  재소비를 막는다. API 33 미만은 런타임 알림 권한 거부 단계가 적용되지 않으며 smoke 증거에
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
- Setup/직접 Pro preset, 학교 coach/catcher, 관계 category, tournament chapter, HS/Pro/LifeCard 선수
  초상, BloomArt와 phase/level KeyArt는 local Addressables address를 실제 화면에서 lease하고 detach 때
  해제한다. 누락/실패는 의미가 같은 한국어 text를 유지하며 원격 fallback은 없다.
- PitchStage 재질은 `Baseball/PitchStageUnlit` 체크인 shader만 사용한다. exact GUID를
  `GraphicsSettings.alwaysIncludedShaders`에 보존하고 Editor build가 SerializedObject와 실제 asset/name을
  함께 검증한다. Player는 지원 여부/ready marker를 기록하고 smoke는 missing/unsupported/pink shader를
  비롯한 StrictMode·Firebase/Amplitude bridge 오류를 fail-closed로 검색한다.
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
- production 기기 smoke는 임의의 package-compatible AAB를 받지 않는다. 현재 clean Git commit과
  같은 RC의 `build-manifest.json`·`checksums.sha256`, AAB/symbol SHA-256, production
  distribution, IL2CPP Release, upload certificate pin을 먼저 검증한다. 16KB 기기에서는 실제
  저장형 투구 presentation 완료 marker를 확인한 뒤에만 native 실행을 통과 처리한다.
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

- clean commit `0797760a5dab711e42f723a5dfdf8b21a75dd29e`에서 C# 정적 suite,
  Unity reference compile, 실제 Unity 6000.3.19f1 EditMode/PlayMode, production upload-key AAB와
  Firebase symbol upload가 통과했다.
- 같은 AAB의 API 29, API 35 16KB, API 36 production smoke가 통과했다. 16KB lane은 실제 저장형
  투구 presentation marker와 shader ready, crash/ANR 0을 확인했다.
- 물리 Low/Mid/High 스마트폰, TalkBack·실제 저용량·성능, Play 12명/14일, 한국 개발자 계정 정보,
  무료 체험·사전 출시 보고서·지원 기기 CSV, 실제 분석 수신과 Crashlytics symbolication은 외부 차단이다.
