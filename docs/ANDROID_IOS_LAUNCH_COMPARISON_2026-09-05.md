# Android 출시 전 iOS 비교 및 개선 제안

기준일: 2026-09-05 KST. 비교 소스: `9b2ced70` 및 조사 시작 시 이미 존재하던 미커밋 변경. Android 제품은 `apps/android`의 Compose/Kotlin 앱이며, `apps/android-unity`는 현재 제품의 런타임이 아닌 과거 구현이다. 이번 작업은 코드 조사와 검증이며 제품 코드를 수정하지 않았다.

## 판단

Android에는 고교 → 직접 투구 → 드래프트 → 프로 → 은퇴·환생의 큰 구조와 대표팀·시즌 결산이 이미 있다. 그러나 현재 작업본을 곧바로 출시 후보로 간주하기 어렵다. 빌드 의존성 정리, 기존 Swift 기준 회귀 실패, 대표팀 보상 이월 실패가 남고, iOS 1.2.8에서 강조한 프로 선택의 다양성·후속 결과·보직 지원이 완전히 연결되지 않았다.

사용자가 제공한 iOS 스포츠 유료 1위 성과는 사업적 전제로 받아들였다. 순위가 특정 기능의 효과임을 입증하는 사용자 데이터는 이번에 조회하지 않았다. 성공한 iOS의 투구 슬라이더, 성장·지명·환생의 보상을 우선 재현하고 Android에서 첫 플레이와 시즌 진행이 끊기지 않게 만드는 것이 권장 방향이다.

## 비교 범위와 한계

- 현재 iOS 소스와 로컬 릴리스 문안을 비교했다. 로컬 문서에는 1.2.8 판매 중, 1.2.9 제목 잘림 수정으로 기록되어 있다. 공개 스토어 페이지 열기는 실패했으며 ASC/Play Console에서 현재 배포 버전·트랙은 조회하지 않았다. 따라서 현재 소스의 모든 기능이 판매 바이너리에 실렸다고 단정하지 않는다.
- 기존 Android 문서는 주로 8월 14~17일 Unity 연동 시점이다. 9월 4일 이후 변경과 구분했다.
- 이번에 최신 Android 앱을 실기기나 에뮬레이터에서 플레이하지 않았다. 전체 Gradle 테스트가 의존성 단계에서 실패했다. 화면 가림·조작 지연은 확정 버그가 아니라 다음 빌드에서 확인할 항목이다.
- 로컬에는 production 메타데이터를 가진 RC 37~41이 있다. 최신 41의 소스는 `898335ed`, AAB는 23,753,896바이트다. 각 매니페스트의 `playUpload`는 `not-performed`다. 별도 업로드 여부는 이 파일로 알 수 없고, 이 과거 산출물로 현재 작업본의 동작을 보증할 수도 없다.

## 실제 차이

| 항목 | iOS 현재 소스 | Android 현재 소스 | 판단과 개선 |
|---|---|---|---|
| 핵심 투구 | 타이밍 슬라이더, 조준, 심장박동, 짧은 오탭 취소, 퍼펙트 피드백 | 슬라이더 기본값 `false` 자동 릴리스 설정, 프레임 기반 미터, 심장박동·코칭, Canvas 투구 화면 구현 | 큰 기능 누락으로 보지 않는다. Galaxy 60/120Hz에서 타이밍·발열·햅틱을 실제 비교한다. 자동 투구를 기본으로 바꾸지 않는다. |
| 프로 결정 빈도 | v9 이상 3주 간격·시즌 최대 7회 | 같은 일정과 최대 횟수 구현 | 이미 따라잡은 항목이다. '프로 결정이 없다'고 판단하면 안 된다. |
| 프로 결정의 내용과 후속 결과 | 등판 간격·2군 재정비·신구종 실전·베테랑 조언, 일정 기간 효과를 적용하고 결과 카드 표시 | 기존 6종 결정과 일부 특수 결정 위주. 신규 4종 enum/분기 미확인. `activeDecisionModifiers`·`resolvedFollowUps` 저장 구조는 있지만 현행 명령·주간 화면에서 iOS와 같은 동작 연결을 찾지 못함 | 출시 전 이식 우선순위가 높다. 결정 횟수만 늘고 내용·결과가 같으면 반복감이 남는다. |
| 보직 선택 | 스프링캠프 보직 지원, 자격 평가, `requestRole` 명령과 화면 | 역할 회의 이벤트의 보직 변경은 존재. 스프링캠프 지원 액션/명령은 없음. `roleRequest` 저장 필드 존재 | '보직 변경 없음'이 아니라 '원하는 시점의 보직 지원 없음'이다. 신청→평가→결과→재실행 방지를 함께 이식한다. |
| 첫 선수 만들기 | 현재 작업본 첫 생 3단계, 추천 이름·빈 이름 대체, 재환생 시 추가 설정 | 첫 생 4단계, 이름 필수, 구종 단계는 프리셋 설명만 표시 | 첫 생은 추천 이름과 기본 구종으로 간단하게 시작한다. 설명만 읽는 단계를 줄이고 첫 슬라이더 체험까지의 시간을 측정한다. |
| 환생 빌드 선택 | 재환생 때 배우는 구종·주 구종, 난이도, 야구혼 분야와 대표 유산 등 선택 UI | 빠른 다음 생·사용자 설정, 유산 선택은 이미 존재. 설정 화면에는 손·유형·4종 핸디캡이 있고, 구종 설명만 표시하며 `HighSchoolDifficulty()` 기본값을 전달 | 환생 자체가 없는 것이 아니다. 새 생을 다르게 만드는 선택권이 좁다. 구종·야구혼·난이도 선택을 저장/실제 능력 적용까지 연결한다. |
| 용어 도움 | 주간 화면에서 용어를 눌러 짧은 설명, 선택 효과·결과 카드 | 설정에 29개 용어 목록. 공통 행 렌더러는 일반 `Text` 표시 | 용어집은 유지하면서 피로·보직·감독 신뢰 등 필요한 위치에 탭 설명을 제공한다. 식별용 ID는 설명으로 노출하지 않는다. |
| 언어 | Localizable 1,937개 + GameContent 2,100개 키에 ko/en/ja 항목 존재 | 기본/en/ja 리소스 각각 12개. 화면·콘텐츠·공유 본문은 한국어 하드코딩 다수 | 영어/일본어 지원 완료 상태가 아니다. 국내 우선 출시와 해외 확장을 분리하거나, 해외 동시 출시라면 번역 체계를 출시 선행 조건으로 잡는다. 키 수는 품질 점수가 아니다. |
| 공유·유입 | 드래프트·은퇴 등 카드 이미지, 시드 도전 링크 생성과 수신 처리 | 라이프카드 이미지 공유는 존재. 새 드래프트/대표팀/은퇴/기록 버튼은 `text/plain`. Manifest에 도전 링크 VIEW 필터 없음 | 이미지 공유가 전혀 없는 것은 아니다. 성취 순간 카드와 스토어/도전 링크를 연결해 공유 후 유입을 완성한다. |
| 화면 구성 | 단계별 전용 화면과 점진적 정보 공개 | 다수 화면이 공통 카드의 '모든 정보 행 → 액션' 구조. 훈련·관계·주간 계획은 선택 그리드 적용 | 실제 가림은 미검증. 긴 정보보다 '현재 상황 → 한 가지 결정 → 결과'가 먼저 보이게 하고 주 행동을 고정 영역으로 검토한다. |
| 저장·출시 검증 | 실제 판매 이력 및 플랫폼별 저장 경로 | 원자적 저장·복구·중복 방지 설계, 과거 Unity 세이브 어댑터 유지 | 설계는 있으나 최신 UI 교체 후의 실제 업데이트 설치·중단 복구 증거를 새로 확보해야 한다. |

### 핵심 소스 근거

- Android 빌드/제품: [README](../apps/android/README.md), [Gradle](../apps/android/app/build.gradle.kts), [Manifest](../apps/android/app/src/main/AndroidManifest.xml), [lockfile](../apps/android/app/gradle.lockfile).
- 투구: [Android 조작](../apps/android/app/src/main/java/com/solkim/baseball/android/PitchDeliveryControl.kt), [기본 설정](../apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/GameAggregateModels.kt), [iOS 조작](../apps/ios/Sources/Features/Pitch/DeliveryControl.swift).
- 프로: [Android 결정 일정](../apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProCatalog.kt), [명령](../apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProCommands.kt), [커널](../apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProKernel.kt), [iOS 커널](../packages/simulation-core/Sources/SimulationCore/ProCareer.swift), [iOS 주간 화면](../apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift).
- 생성/환생: [Android 화면](../apps/android/app/src/main/java/com/solkim/baseball/android/Phase8Screens.kt), [명령 연결](../apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/Phase8ScreenModels.kt), [iOS 생성](../apps/ios/Sources/Features/HighSchool/HighSchoolSetupView.swift), [구종](../apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+RepertoireStep.swift), [계승 설정](../apps/ios/Sources/Features/HighSchool/HighSchoolSetupView+HandicapStep.swift).
- 언어/공유: [Android 영어 리소스](../apps/android/app/src/main/res/values-en/strings.xml), [일본어 리소스](../apps/android/app/src/main/res/values-ja/strings.xml), [용어](../apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/BaseballGlossary.kt), [공유](../apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/CareerShareCopy.kt), [iOS 공유](../apps/ios/Sources/Presentation/CareerSharePresentation.swift).

## 이번에 실행한 검증

| 검증 | 결과 | 해석 |
|---|---|---|
| `node tools/check-android-compose.mjs` | 통과 | 소스/참조 정적 검사 |
| `node tools/check-android-compose-release.mjs` | 통과 | 소스와 제품 표시만 확인. AAB 인수를 주지 않았으므로 서명·실행·Play 통과가 아님 |
| `node tools/check-dialogue-parity.mjs` | 통과 | 해당 스크립트가 검사하는 관계 대사 9종 범위 |
| `node tools/check-android-phase9.mjs` | 실패 | 스크립트는 스키마 7을 문자열로 요구. 현재 `HighSchoolPhase4StateCodec`은 9이며 버전 7 이상 training evidence 읽기 존재. 검증 도구의 이전 기준 문제로 보이며 저장 고장 자체를 입증하지 않음 |
| `./gradlew test --no-daemon --console=plain` | 실패 | `:app:processDebugNavigationResources`에서 lockfile의 `androidx.games:games-frame-pacing:2.1.2` 미해결. Unity 제거와 lockfile의 불일치 |
| `:game-core:test` | 103개 중 2개 실패 | 아래 상세 |
| `:game-application:test` | 82개 통과 | 파일 저장 기반 고교→프로 20시즌→은퇴 테스트 포함. 실제 화면 조작 검증과는 별개 |
| `:game-persistence:test` | 14개 통과 | 저장 모듈 단위 테스트 범위 |

실패 1: `ProCareerFixtureTest.committedCurrentSwiftMultiSeedFixtureMatchesKotlinProBoundary`의 seed 100 첫 주 기록. 기대 `[1,1,18,5,0,0,4,79]`, 실제 `[1,1,18,5,1,0,3,74]`로 볼넷·피안타·투구 수가 다르다. 이 fixture는 과거 Swift 기준이다. 현재 iOS와 같은 버전·시드·입력을 고정해 재생성한 뒤 실제 규칙 차이와 오래된 기대값을 구분해야 한다. 기대값만 덮어써 통과시키면 안 된다.

실패 2: `ProNationalTeamTest.goldPathExemptsMilitaryAndCarryAppliesNextSpring`의 다음 시즌 피로. 기대 25, 실제 0. 테스트 이름 전체가 실패한 것이지 금메달/병역 면제가 모두 실패했다는 뜻은 아니다. 실패 위치는 `chooseOffseason(CONTINUE)` 뒤 참가 피로 이월 비교다. 대표팀 참가의 비용과 다음 시즌 균형에 영향을 줄 수 있으므로 출시 전에 규칙과 구현을 대조한다.

## 권장 실행 순서

### 1. 출시 후보를 재현 가능하게 만들기 — 필수

1. Unity 제거 후 실제 Gradle 그래프에 맞춰 lockfile과 검증 도구를 갱신한다. 잠금/검사 자체를 끄지 않는다.
2. 프로 fixture와 대표팀 피로 이월 실패를 해결한다. Android/iOS의 비교 기준 rulesVersion·스키마·seed를 명시한다.
3. 현재 변경을 확정한 소스에서 debug 테스트·lint·서명 RC를 다시 만든다. 로컬 기본 versionCode 37을 그대로 쓰지 말고 Play의 최신 값을 조회해 더 높은 번호를 정한다. 로컬 RC만 해도 41까지 존재한다.
4. 동일한 후보로 새 게임, 수동 슬라이더 한 구, 고교 완주, 지명/미지명, 프로 2시즌, 대표팀, 은퇴, 환생, 중단 복구를 확인한다. 과거 테스트 설치 사용자가 있다면 덮어 설치 후 기존 세이브도 검증한다.

완료 기준: 전체 검사 통과 + 위 경로에서 진행 막힘/중복 보상/저장 유실 없음 + 검사한 소스와 AAB가 대응.

### 2. iOS 최근 재미 개선을 완성하기 — 출시 전 권장

- 신규 결정 4종을 조건·즉시 효과·기간 효과·후속 결과까지 이식한다.
- 스프링캠프 보직 지원을 추가한다. '지원'이 무조건 원하는 보직으로 변경되는 동작이 되지 않게 평가와 결과를 보여 준다.
- 주간 화면 상단에 이번 주 결정, 선택 효과 한 줄, 지난 결정의 결과를 배치한다.
- 3주 결정 주기와 기존 중요 경기/부상/대표팀 분기가 충돌하지 않는지 확인한다.

완료 기준: 새 프로 커리어에서 결정→저장/재시작→3주 후 결과, 보직 지원→평가→반영까지 조작 가능. 상태 필드/화면 문구만 있는 것은 완료로 치지 않는다.

### 3. 첫 플레이와 두 번째 삶을 다듬기 — 출시 전 권장

- 추천 이름과 기본 구종을 제공하고 첫 생의 설명 전용 단계를 줄인다. 목표는 첫 실행 후 90초 안에 슬라이더를 직접 한 번 던지는 흐름이며, 이는 제안한 UX 목표이지 측정 결과가 아니다.
- 훈련/관계/주간 계획의 행동 버튼을 쉽게 찾도록 한다. 피로가 높으면 회복의 이유를 선택 근처에 표시한다.
- 환생 때 구종·계승 분야·난이도를 바꾸고, '지난 생과 무엇이 달라졌는지'를 보여 준다. 빠른 환생 경로는 유지한다.
- 용어 설명은 설정뿐 아니라 해당 숫자·선택 옆에서 열리게 한다.

완료 기준: 작은 화면과 글자 100/130/150/200%, 키보드 표시 상태에서 제목·선택·주 행동을 읽고 누를 수 있다. 신규 이용자가 도움 없이 첫 훈련과 두 번째 삶을 시작한다.

### 4. 국내 출시와 해외 확장 구분하기

출시 시점이 중요하면 한국어 국내판을 먼저 안정화하는 선택이 합리적이다. 영어·일본어로 동시에 판매하려면 이름만 번역된 상태를 넘어 화면, 대사, 숫자/단위, 공유 본문, 알림, 접근성 라벨까지 번역해야 한다. iOS의 콘텐츠 키 체계를 Android에 매핑해 이후 업데이트에서 번역 누락을 검출하도록 한다.

공유는 드래프트·대표팀 메달·은퇴 카드부터 개선한다. 이미지+성취 요약+플랫폼에 맞는 설치 링크를 보내고, 이후 같은 시드 도전 링크 수신을 연결한다. 기존 커리어를 덮어쓰지 않는 격리가 선행 조건이다. 소셜 기능 추가보다 완주 안정화가 먼저다.

## Android에서 별도로 확인할 출시 조건

- `minSdk=26`, `targetSdk=36`이 설정되어 있다. 최신 타깃 설정만으로 동작 검증을 대신하지 않는다.
- Android 16에서는 edge-to-edge 회피가 불가능하고 뒤로 가기 동작도 달라진다. 현재 코드에 insets 처리와 BackHandler가 일부 있으므로 이를 '없음'으로 보고 새로 만드는 것이 아니라, 제스처/3버튼 내비게이션과 키보드·투구 중 복귀에서 확인한다. [Android 16 공식 변경사항](https://developer.android.com/about/versions/16/behavior-changes-16)
- 16KB 환경은 Unity를 제거했더라도 최종 AAB의 네이티브 SDK 포함 여부와 설치 결과로 확인한다. [공식 16KB 안내](https://developer.android.com/guide/practices/page-sizes)
- Galaxy 보급형·중급형·고급형에서 첫 실행, 슬라이더 타이밍, 20분 플레이 후 발열/프레임, 홈→복귀, 프로세스 종료→재개를 확인한다. API 26/29의 하한 호환성, 35/36의 최근 동작을 함께 확인한다.
- Crashlytics/Analytics는 기본 수집 off 및 RC 주입 경로가 있다. 동의 후 실제 수신, 거부 시 미수집, 리셋 후 상태를 후보 빌드로 확인하고 Play 신고와 맞춘다.
- 2023-11-13 이후 생성된 개인 개발자 계정에 해당한다면 최소 12명·연속 14일 비공개 테스트 후 프로덕션 접근 신청 조건을 확인한다. 모든 계정에 일률 적용하거나 로컬 문서만으로 충족했다고 판단하지 않는다. [Play 공식 테스트 조건](https://support.google.com/googleplay/android-developer/answer/14151465)
- 기존 8월 체크리스트의 Unity export 필요, RC 미생성, 스크린샷 재사용 지침은 현재 사실과 재대조한다. 현재 네이티브 앱 캡처와 실제 지원 기능으로 스토어 소재를 갱신한다.

## 출시 후 측정 제안

설치→첫 수동 투구→첫 공식 경기→첫 드래프트→두 번째 삶, 프로 진입→첫 결정→첫 결과 카드→2시즌의 이탈을 OS별 동일한 이벤트 정의로 비교한다. D1/D7, 충돌·ANR, 환불 사유도 함께 본다. 기존 분석 프로젝트를 이번 조사에서 조회하지 않았으므로 수치나 개선 폭은 제시하지 않는다. iOS 순위를 Android 성과 예측치로 환산하지 않는다.
