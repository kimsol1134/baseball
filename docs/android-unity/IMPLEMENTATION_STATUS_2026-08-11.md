# Android Unity 구현 상태 — 2026-08-11

기준 문서: [`../ANDROID_UNITY_IMPLEMENTATION_PLAN_2026-08-11.md`](../ANDROID_UNITY_IMPLEMENTATION_PLAN_2026-08-11.md)

이 문서는 구현 소스와 출시 증거를 구분한다. clean commit의 Unity 테스트, production upload-key
서명 AAB, Firebase symbols, API 29/35(16KB)/36 smoke, Play 내부·비공개 트랙은 준비됐다. 다만
**한국 개발자 정보, 12명/14일 비공개 테스트와 물리 스마트폰 증거가 없으므로 Google Play RC로
승인된 상태가 아니다.**

## 현재 판정

| 층 | 상태 | 근거 |
|---|---|---|
| 순수 C# Core | 구현·정적 검증 완료 | Pitch/HighSchool/Pro 결정론 엔진과 NUnit 계약 |
| Application/저장 | 구현·정적 검증 완료 | 단일 aggregate, 원자 저장, 복구, 명령 영수증, 투구 중단 재개 |
| Unity Presentation/Platform 소스 | 구현·Unity 검증 완료 | UI Toolkit, 3D 투구, Android SDK 경계, 실제 EditMode/PlayMode |
| Unity EditMode/PlayMode | 통과 | Unity 6000.3.19f1: 주요 EditMode 533건+격리 fault tests, PlayMode 14/14 |
| Android IL2CPP AAB | production 후보 통과 | clean SHA의 upload-key AAB/public symbols, 16KB 정렬·병합 manifest·권한 검증 |
| 실제 Android 기기 | emulator 통과 / 물리 대기 | API 29, API 35 16KB, API 36 production smoke 통과 |
| Google Play/Firebase/Amplitude | 부분 통과 | Play internal/closed 및 Firebase symbol upload 완료; 계정 정보·시간 조건·실제 수신 대기 |

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
- 전체 초기화는 파괴 작업 전에 no-backup reset journal을 fsync한다. save 삭제·새 install ID·분석·리뷰·
  알림·옛 install epoch·공유 PNG cache를 개별 receipt로 완료하며, 중간 종료 뒤에도 같은 후보 ID로
  수렴하고 이미 완료한 save 삭제를 반복하지 않는다. 삭제 뒤 ID 발행이 실패한 이전 store는
  write-poison되어 pause·resume·명령 저장을 수행하지 않는다.
- Firebase Analytics/Crashlytics와 Amplitude는 광고 ID 없이 익명 품질 분석만 보내도록 경계를 둔다.
- Android adaptive/monochrome 아이콘, 로컬 Addressables, 한국어 폰트, Android 호환 군중 ambience,
  audio focus, 햅틱, 알림 설정 이동, Android Sharesheet와 Play In-App Review 경계를 포함한다.
- Setup/직접 Pro 프리셋, 학교 동행자, 관계·대회, 선수 단계별 초상, talent bloom과 phase/level KeyArt가
  로컬 Addressables를 실제 화면에서 사용한다. Pitch 3D 재질은 체크인한 전용 shader를
  `GraphicsSettings.alwaysIncludedShaders`로 보존하고 build/runtime/smoke에서 fail-closed 검증한다.

## 자동 검증 기록

2026-08-12 현재 마지막 로컬 결과:

| 명령/게이트 | 결과 | 비고 |
|---|---|---|
| `npm run test:unity:static` | 통과, 433/433 | 순수 C#과 Unity 비의존 계약; Unity Test Runner 대체물이 아님 |
| `npm run test:unity:references` | 통과 | production, internal QA, Core, Platform, Platform tests, Presentation tests, Android Editor가 경고·오류 0 |
| Swift/C# Pitch oracle | 통과 | seed 1…128 결과·위치·구속·event hash exact |
| Pitch 분포 oracle | 통과 | seed 1…10,000 outcome 집계 exact |
| `npm run check:design-system` | 통과 | 색상·토큰·본문 크기·고대비 계약 |
| `npm run check:unity-assets` | 통과 | 118 images, 7 icon sources, 24 audio |
| `npm run check:android:unity` | 소스 계약 통과 | missing `.meta` 0, missing reviewed Addressables/URP asset 0 |
| `npm run check:copy` / `check:copy:android:unity` | 통과 | 내부 용어 38종·실존 야구 IP 42종 미노출 |
| shell syntax/YAML/JSON/`git diff --check` | 통과 | 소스 계약과 최종 diff 형식 확인 |
| `npm run test:unity` | 통과 | 실제 Unity EditMode 주요 533건+격리 tests, PlayMode 14/14 |
| `npm run build:android:verify` | 통과 | 내부 검증 AAB SHA `03fe9b…091a`, symbols SHA `89a52b…91d8` |
| production API 29 smoke | 통과 | `/tmp/baseball-api29-smoke-0797760/20260812T143247Z` |
| production 16KB smoke | 통과 | `/tmp/baseball-final-smoke-0797760/20260812T134607Z`; 실제 투구 marker 포함 |
| production API 36 smoke | 통과 | `/tmp/baseball-api36-smoke-0797760/20260812T143452Z` |

## 반드시 남기는 패리티 경계

- 실제 경기 결과가 저장되기 전에 3D 연출을 시작해서는 안 된다.
- 앱이 결과 저장 직후 종료되면 같은 결과와 연출을 재생해야 하며 같은 공을 다시 던지게 해서는 안 된다.
- iOS의 31개 타구 비행 sample 대신 거리·체공·정점으로 Unity frame을 보간하는 시각적 차이는
  `PARITY_EXCEPTIONS.md`의 승인 범위다. 점수·주자·아웃·성장 차이는 허용하지 않는다.
- Android 첫 출시에는 과거 Android save가 없으므로 iOS 내부 balance v1-v3 save migration은 포함하지 않는다.
  iOS save를 Android로 가져오는 기능도 v1 범위가 아니다.

## 출시 차단 해제 순서

1. 한국 개인 개발자의 공개 전화번호를 인증하고 유료 앱 사업자·통신판매 정보를 실제 값으로 제출한다.
2. closed Alpha의 opt-in 테스터를 12명 이상 확보하고 14일 이상 유지한다.
3. Low/Mid/High 실제 세로 스마트폰에서 성능, TalkBack, 실제 저용량, Back/재개를 기록한다.
4. Play 변경 13개를 검토 제출하고 사전 출시 보고서, 지원 기기 CSV, 폼 팩터 제외와 60분 체험을 확인한다.
5. 내부/비공개 설치에서 Firebase/Amplitude 수신과 Crashlytics symbolication을 확인한다.
6. `DEVICE_MATRIX.md`, `PARITY_MATRIX.md`, `RELEASE_EVIDENCE.md`의 빈 칸이 모두 증거로 채워진 뒤 RC를 승인한다.

## 저장소 위생

- 이 작업은 iOS/Swift 구현을 Android C#의 oracle로 읽지만 iOS 소스를 포팅 작업의 산출물로 수정하지 않는다.
- 사용자 또는 다른 작업이 만든 기존 iOS/Swift 변경은 되돌리거나 Android 변경으로 주장하지 않는다.
- 실제 구단·리그·선수·로고·슬로건은 runtime 콘텐츠에 넣지 않는다. 도시명만 사용할 수 있다.
- Unity가 생성한 `.meta`·Addressables·URP 산출물은 source asset과 함께 검토해 보존한다.
