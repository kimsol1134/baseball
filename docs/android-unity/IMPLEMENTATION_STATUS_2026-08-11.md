# Android Unity 구현 상태 — 2026-08-11

기준 문서: [`../ANDROID_UNITY_IMPLEMENTATION_PLAN_2026-08-11.md`](../ANDROID_UNITY_IMPLEMENTATION_PLAN_2026-08-11.md)

이 문서는 구현 소스와 출시 증거를 구분한다. 현재 저장소에는 Android 프로덕션 후보를
만들기 위한 소스가 들어 있지만, **서명된 AAB와 실제 기기 증거가 없으므로 Google Play RC로
승인된 상태가 아니다.**

## 현재 판정

| 층 | 상태 | 근거 |
|---|---|---|
| 순수 C# Core | 구현·정적 검증 완료 | Pitch/HighSchool/Pro 결정론 엔진과 NUnit 계약 |
| Application/저장 | 구현·정적 검증 완료 | 단일 aggregate, 원자 저장, 복구, 명령 영수증, 투구 중단 재개 |
| Unity Presentation/Platform 소스 | 구현됨, Editor 실행 미검증 | UI Toolkit, 3D 투구, Android SDK 경계와 참조 어셈블리 컴파일 |
| Unity EditMode/PlayMode | 차단 | 이 머신의 Unity Personal entitlement가 없어 Editor가 테스트 import 전 종료 |
| Android IL2CPP AAB | 차단 | 같은 라이선스 차단으로 빌드 미실행 |
| 실제 Android 기기 | 차단 | 서명 AAB/APKS와 연결된 스마트폰이 없음 |
| Google Play/Firebase/Amplitude | 차단 | 외부 앱 등록, 자격 증명, 콘솔 설정과 수신 증거가 없음 |

## 소스 지도

- Unity 프로젝트: `apps/android-unity`
- 결정론 Core: `apps/android-unity/Assets/Game/Core`
- 저장·커리어·메타 흐름: `apps/android-unity/Assets/Game/Application`
- 부트스트랩과 서비스 공개: `apps/android-unity/Assets/Game/Bootstrap`
- UI Toolkit 및 투구 Presentation: `apps/android-unity/Assets/Game/Presentation`
- Android 분석·크래시·알림·공유·진동: `apps/android-unity/Assets/Game/Platform`
- Editor 빌드와 import 자동화: `apps/android-unity/Assets/Game/Editor`
- 정적/EditMode/PlayMode 테스트: `apps/android-unity/Assets/Tests`
- CI: `.github/workflows/unity-android.yml`
- Unity test wrapper: `tools/unity-android-test.sh`
- Android build wrapper: `tools/unity-android-build.sh`
- 실제 기기 smoke: `tools/android-unity-smoke/run.sh`

## 구현된 제품 범위

- 로그인·서버·클라우드 저장 없이 익명 install UUID와 로컬 저장만 사용한다.
- 한국어 UI, 스마트폰 세로 화면, safe area, 뒤로가기, 글자 확대·고대비·모션 감소를 다룬다.
- iOS의 고교 3년, 드래프트, 프로 커리어, 은퇴, 유산, 환생, 주간 노트,
  기록과 로컬 업적을 C# 상태 머신으로 옮겼다.
- 임시 제거된 일일 모드는 제품 진입·투구 명령·알림·신규 주간 과제·보상 분석을 모두
  차단했다. 옛 enum·저장 필드·링크는 데이터 손실 없이 읽고 현재 커리어로 복귀시키는 호환 코드만 유지한다.
- 포수 뒤 시점에서 구종·코스·의도·강도·릴리스 타이밍을 고르고, 공과 타구를 따라가는
  Unity 3D 연출을 사용한다. 경기 결과의 권위는 Presentation이 아니라 C# Pitch Core에 있다.
- 저장은 JSON envelope, SHA-256, temp 파일, canonical 파일, 순환 백업 세 개와 격리 복구를 사용한다.
- Firebase Analytics/Crashlytics와 Amplitude는 광고 ID 없이 익명 품질 분석만 보내도록 경계를 둔다.
- Android adaptive/monochrome 아이콘, 로컬 Addressables, 한국어 폰트, Android 호환 군중 ambience,
  audio focus, 햅틱, 알림 설정 이동, Android Sharesheet와 Play In-App Review 경계를 포함한다.

## 자동 검증 기록

2026-08-11 현재 마지막 로컬 결과:

| 명령/게이트 | 결과 | 비고 |
|---|---|---|
| `npm run test:unity:static` | 통과, 319/319 | 순수 C#과 Unity 비의존 계약; Unity Test Runner 대체물이 아님 |
| `npm run test:unity:references` | 통과 | production, internal QA, Core, Platform, Platform tests, Presentation tests, Android Editor가 경고·오류 0 |
| Swift/C# Pitch oracle | 통과 | seed 1…128 결과·위치·구속·event hash exact |
| Pitch 분포 oracle | 통과 | seed 1…10,000 outcome 집계 exact |
| `npm run check:design-system` | 통과 | 색상·토큰·본문 크기·고대비 계약 |
| `npm run check:unity-assets` | 통과 | 118 images, 7 icon sources, 24 audio |
| `npm run check:android:unity` | 소스 계약 통과 | Unity가 만들 `.meta` 396개는 아직 없음 |
| `npm run check:copy` / `check:copy:android:unity` | 통과 | 내부 용어 38종·실존 야구 IP 42종 미노출 |
| shell syntax/YAML/JSON/`git diff --check` | 통과 | 소스 계약과 최종 diff 형식 확인 |
| `npm run test:unity` | 미통과 | 유효한 Unity Editor entitlement 필요 |
| `npm run build:android:verify` | 미실행/차단 | Unity 라이선스와 Android import 필요 |
| `npm run smoke:android:unity` | 미실행/차단 | 서명 AAB와 실제 스마트폰 필요 |

## 반드시 남기는 패리티 경계

- 실제 경기 결과가 저장되기 전에 3D 연출을 시작해서는 안 된다.
- 앱이 결과 저장 직후 종료되면 같은 결과와 연출을 재생해야 하며 같은 공을 다시 던지게 해서는 안 된다.
- iOS의 31개 타구 비행 sample 대신 거리·체공·정점으로 Unity frame을 보간하는 시각적 차이는
  `PARITY_EXCEPTIONS.md`의 승인 범위다. 점수·주자·아웃·성장 차이는 허용하지 않는다.
- Android 첫 출시에는 과거 Android save가 없으므로 iOS 내부 balance v1-v3 save migration은 포함하지 않는다.
  iOS save를 Android로 가져오는 기능도 v1 범위가 아니다.

## 출시 차단 해제 순서

1. Unity Hub에서 6000.3.19f1을 사용할 수 있는 라이선스를 활성화한다.
2. 첫 import로 `.meta`, URP renderer/asset, Addressables settings를 생성하고 변경분을 검토한다.
3. `npm run test:unity`로 EditMode와 PlayMode XML이 모두 `Passed`인지 확인한다.
4. production Firebase/Amplitude 설정과 upload keystore를 비밀 저장소에서 주입한다.
5. `npm run build:android:rc`로 ARM64 IL2CPP AAB와 public symbols를 만든다.
6. Crashlytics symbol upload 영수증, AAB 인증서·merged manifest·dependencies를 보관한다.
7. `npm run smoke:android:unity`를 실제 세로 스마트폰에서 실행하고 스크린샷·logcat을 보관한다.
8. Play 내부 트랙에서 지원 기기 CSV, 사전 출시 보고서, Data Safety, 콘텐츠 등급,
   대한민국 4,400원/60분 무료 체험을 확인한다.
9. `DEVICE_MATRIX.md`, `PARITY_MATRIX.md`, `RELEASE_EVIDENCE.md`의 빈 칸이 모두 증거로 채워진 뒤 RC를 승인한다.

## 저장소 위생

- 이 작업은 iOS/Swift 구현을 Android C#의 oracle로 읽지만 iOS 소스를 포팅 작업의 산출물로 수정하지 않는다.
- 사용자 또는 다른 작업이 만든 기존 iOS/Swift 변경은 되돌리거나 Android 변경으로 주장하지 않는다.
- 실제 구단·리그·선수·로고·슬로건은 runtime 콘텐츠에 넣지 않는다. 도시명만 사용할 수 있다.
- Unity import 이전에는 생성되지 않은 `.meta`를 손으로 대량 위조하지 않는다.
