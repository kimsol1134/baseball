# iOS·Android 현재 차이 재점검

이 문서는 개선 전 재점검 기록이다. 이후 적용한 수정과 검증은 [후속 개선 결과](PARITY_IMPROVEMENTS_2026-09-05.md)를 따른다.

기준: 2026-09-05, HEAD `9b2ced701aa34c06984128cf22b4fcef04665443` 위의 현재 미커밋 작업본. Android는 `apps/android`의 Kotlin/Compose 제품이다. 최근 저장·문구·훈련·직접 투구·햅틱 수정을 포함한다.

현재 로컬 iOS 소스와 Android 소스의 비교다. 판매 중인 App Store 바이너리, Play Console 트랙, 실제 온라인 서비스 상태는 이번에 조회하지 않았다. 이번 재점검에서는 제품 코드를 변경하거나 빌드·실기기 검사를 다시 실행하지 않았다. 아래 기존 검증 결과는 앞선 작업의 기록이며 전체 기능 동등성을 보증하지 않는다.

## 판단

고교→투구→드래프트→프로→은퇴·환생의 큰 흐름은 양쪽에 있다. 최근 사용자 피드백으로 드러난 직접 구종/코스 선택, 진동 재생, 훈련 선택/실행, 저장 중단 오류도 수정했다. 그러나 아직 같은 게임 경험이라고 판단할 수 없다. 구종 학습에는 실제 규칙 차이가 있고, 관계 대화·각성·결산에는 사용자가 읽고 판단하는 정보의 차이가 남는다. 기기 변경 시 기록 복원도 별도 공백이다.

이전 문서의 정적 검사 통과, 번역 키 매핑 완료, 일부 커리어 완주 통과는 각각 해당 검사 범위의 결과다. 이를 모든 iOS 기능과 화면의 이식 완료로 해석해서는 안 된다. 동등성 비율을 산출할 기준은 없으므로 임의의 완료율은 제시하지 않는다.

## 남은 차이

| 항목 | iOS 현재 구현 | Android 현재 구현 | 사용자 영향과 필요한 작업 |
|---|---|---|---|
| 구종 습득 과정 | 그립→불펜→실전 적응의 학습 프로젝트, 연습 진척과 좋은 실전 사용 기록. 고교에서 프로로 프로젝트를 연결 | 선택한 구종의 능력 성장과 연습 중→실전 구종 역할 승격. 같은 학습 프로젝트는 확인되지 않음 | 신구종을 완성하는 목표와 성취 과정이 다르다. 화면만 복제하지 말고 상태·훈련·실전 사용·프로 이월·기존 저장 호환까지 이식해야 한다. |
| 관계 대화 | 사건별 대사와 선택지, 감독/포수/라이벌 신뢰 구간에 따른 말투, 인물 이름·초상화와 상황 그림 | 사건 제목/요약과 관계 수치는 있으나 선택지는 주로 감독·포수·라이벌 등 분류별 공통 문구. 사건/신뢰 구간별 본문을 고르는 UI 경로는 확인되지 않음 | 문장만 자연스럽게 고쳐도 비슷한 선택이 반복된다. 사건·신뢰도에 맞는 대사와 선택지를 연결해야 한다. 관계 효과 계산 자체가 없는 것은 아니다. |
| 각성 선택 | 분야별 트리, 보유/가능/잠김, 선행 조건과 단계 건너뛰기, 효과 설명과 선택 확인 | 가능한 각성을 평면 목록과 공통 설명으로 표시 | 무엇을 얻고 다음에 무엇을 열 수 있는지 판단하기 어렵다. Android 코어에 선행 조건·불꽃을 사용하는 해금 규칙은 이미 있어, 전체 트리와 효과를 화면에 연결하는 작업이 우선이다. |
| 드래프트·이번 생 결산 | 평가 기준점과의 차이, 주요 가점/부족한 항목, 다음 생 조언, 선수 성향과 연대기 | 결과·총 평가·기본 기록·유산 선택 중심. 코어의 평가 근거 필드는 UI에서 사용하지 않음 | 왜 지명되거나 탈락했는지와 다음 생에 바꿀 점이 덜 선명하다. 이미 저장된 평가 근거부터 표시하고, 상세 점수 분해·성향·연대기는 실제 데이터 경로를 추가해야 한다. |
| 능력치 눈금 | 내부 20~80 값을 표시용 1~100으로 환산 | 훈련 등에서 내부 20~80 값을 직접 표시 | 같은 능력도 숫자가 달라 보인다. 예: 내부 44는 iOS 40, Android 44. 실제 선수 능력을 바꾸지 않고 공통 표시 계층을 적용해야 한다. |
| 훈련 결과 전달 | 전후 능력치 타일, 성장·발현·구종 학습 진척과 수치 연출 | 성장량·피로·숙련·발현 결과는 표시. 모든 전후 값 타일과 연출은 같지 않음 | 훈련의 실제 효과가 있어도 성장 체감이 약할 수 있다. 구종 학습과 눈금 정리 후 전후 비교를 보강한다. |
| 투구 햅틱의 세부 표현 | 지원 기기에서 누르는 동안 연속 진동의 세기/선명도가 타이밍에 따라 변함. 미터 끝 반전 피드백도 있음 | 시작·타이밍·릴리스·성공의 기본 진동 효과와 심장박동. 같은 연속 강도 변화·미터 끝 피드백은 없음 | 현재 Android에 햅틱이 없는 것은 아니다. 누르는 동안 손으로 타이밍을 느끼는 방식이 다르다. 기기 지원에 맞춰 추가 조정하고 실제 촉감을 비교해야 한다. |
| 기기 변경·재설치 복원 | 고교/프로 저장에 iCloud 미러와 로컬 백업을 연결한 코드 | 원자적 로컬 저장·손상 복구·복귀 동기화는 있음. 계정 기반 원격 복원 경로는 확인되지 않으며 시스템 자동 백업도 `allowBackup=false` | 장기간 키운 선수를 다른 기기로 가져오는 경로가 부족하다. 출시 전 복원 방식을 정하고 기기 변경/재설치 복원을 검증해야 한다. 로컬 손상 복구와 다른 문제다. |
| 온라인 순위·업적 | Game Center 인증·점수 제출·업적 동기화와 순위 화면 | 게임 속 가상 리그 순위와 업적/공유는 있음. Play Games 등 온라인 계정 경쟁 연동은 확인되지 않음 | 다른 이용자와 경쟁하는 경험이 다르다. 코어 재미와 저장 안정화 다음 순서로 검토할 기능이다. 게임 내 리그 순위를 온라인 이용자 순위로 안내하면 안 된다. |

## 최근 개선되어 더 이상 동일한 누락으로 분류하지 않는 항목

- **직접 투구:** 구종과 3×3 목표 코스가 기본 화면에 노출되고 슬라이더는 하단 고정이다. 목표 코스 선택은 조준이며 제구·릴리스 판정에 따라 실제 도착점은 달라진다. 기본 자동 릴리스는 양쪽 모두 꺼짐이다.
- **햅틱 재생:** Galaxy에서 기본 효과의 서비스 기록이 `finished`까지 도달한 것을 앞선 검사에서 확인했다. API가 성공을 반환한 것만으로 판정하지 않았다. 앱/시스템 진동 설정을 존중한다. 두 플랫폼의 촉감이 같다는 뜻은 아니다.
- **훈련 기본 조작:** 종류·강도·대상 구종 선택 후 실행, 비용/전망, 결과, 상황에 따라 멈추는 최대 3회 반복 훈련이 있다. 기본 성장·피로 계산을 대조했고 선택값/결과/저장 검사를 수행했다. 위 학습 프로젝트 차이는 별도로 남아 있다.
- **프로 선택과 보직 지원:** 신규 결정 4종, 기간 효과와 후속 결과, 스프링캠프 보직 지원을 연결했다. 프로 결정이 없거나 보직을 신청할 수 없는 상태로 다시 분류하지 않는다.
- **첫 화면·환생:** 반복 앱 이름과 개발자용 상태 설명을 줄였고, 첫 선수 생성과 환생의 구종·계승·난이도 선택을 개선했다.
- **첫 사인 저장 실패:** 저장 완료 직후 화면 취소로 메모리 상태가 뒤처지는 경계를 수정하고 복귀 시 저장 상태와 맞추도록 했다. 관련 취소 재현과 저장 검증을 수행했다. 이것이 원격 백업까지 구현됐다는 의미는 아니다.
- **언어·공유:** 한국어/영어/일본어 매핑과 성취 이미지·도전 코드/링크 경로를 구현했다. 번역 키 검사는 모든 대사의 자연스러움이나 모든 화면의 가독성 검사를 대신하지 않는다.

## 다음 작업 순서

플레이 경험을 맞추는 순서는 **구종 학습 → 사건별 관계 대화 → 각성 트리와 드래프트·환생 결산 → 능력 눈금과 훈련 결과 → 투구 햅틱 세부 조정**을 제안한다. 최근 불편 신고와 성장·반복 플레이에 직접 연결되는 항목부터 처리하는 순서다.

출시 준비에서는 **기록 복원 방식과 최신 서명 후보 검증**을 별도 선행 과제로 다뤄야 한다. 온라인 순위는 이후 확장 후보로 둔다. 유료 순위 목표에 대한 효과 크기는 실제 이용 데이터 없이 수치로 예측하지 않는다.

각 항목의 완료 기준은 화면 존재가 아니라 실제 선택→결과→저장→재시작이다. 구종 학습은 고교→프로 이월까지, 복원은 다른 기기/재설치까지 확인한다. 새 규칙은 기존 선수 상태를 임의 초기화하지 않도록 이행 규칙이 필요하다.

## 출시·검증에서 아직 확인하지 않은 것

- 현재 변경 전체를 담은 새 서명 production AAB와 그 후보의 업데이트 설치 검사. 과거 RC 41이나 Galaxy의 QA debug 앱으로 이를 대체할 수 없다.
- 실제 Play 최신 versionCode/트랙, 실제 앱 서명 인증서에 맞는 verified App Links, 수정한 웹 설치 버튼의 배포 상태.
- 현재 최종 후보로 처음부터 끝까지 하는 한국어·영어·일본어 화면 플레이. 기존 검사는 첫 플레이·훈련 등 특정 경로와 코어/저장 자동 검사다.
- iOS와 Android를 나란히 사용한 투구 촉감·타이밍 체감 비교. Android에서 진동 재생과 선택값 저장이 확인된 사실과 구분한다.

## 소스와 기존 검증 근거

아래 경로는 저장소 루트 기준이다.

| 항목 | iOS | Android |
|---|---|---|
| 구종 학습/훈련 | `apps/ios/Sources/Features/HighSchool/HighSchoolTrainingViews.swift:461`, `packages/simulation-core/Sources/SimulationCore/ProCareer.swift` | `apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolKernel.kt:1776`, `apps/android/app/src/main/java/com/solkim/baseball/android/TrainingScreen.kt` |
| 관계 대화 | `apps/ios/Sources/Features/HighSchool/HighSchoolRelationshipViews.swift` | `apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/Phase8ScreenModels.kt:547`, 같은 파일 `:1406` |
| 각성 | `apps/ios/Sources/Features/HighSchool/HighSchoolAwakeningViews.swift:95` | 위 `Phase8ScreenModels.kt:578`, `apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolKernel.kt:986` |
| 결산 | `apps/ios/Sources/Features/HighSchool/HighSchoolDraftLegacyViews.swift` | 위 `Phase8ScreenModels.kt:607`, 위 `HighSchoolKernel.kt:938` |
| 능력 눈금 | `apps/ios/Sources/Features/Pitch/AbilityGaugeView.swift:25` | `apps/android/app/src/main/java/com/solkim/baseball/android/TrainingScreen.kt:51` |
| 햅틱 | `apps/ios/Sources/Platform/Haptics.swift:114`, `apps/ios/Sources/Features/Pitch/DeliveryControl.swift:303` | `apps/android/app/src/main/java/com/solkim/baseball/android/PitchTouchFeedback.kt`, `PitchDeliveryControl.kt` |
| 저장 | `packages/ios-layers/Sources/BaseballIOSPersistence/SaveSync.swift`, `apps/ios/Sources/Application/HighSchoolCareerStore.swift:269`, `MobileCareerStore.swift:104` | `apps/android/app/src/main/AndroidManifest.xml:29`, `apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/GameStore.kt` |
| 온라인 경쟁 | `apps/ios/Sources/Application/AchievementStore.swift:66`, `apps/ios/Sources/Features/Meta/GameCenterBoardView.swift` | `apps/android/app/build.gradle.kts`, `apps/android/platform/build.gradle.kts`, `apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProKernel.kt` |

기존 검증 세부 기록: [저장·문구](PLAYER_POLISH_2026-09-05.md), [훈련](TRAINING_COMPARISON_2026-09-05.md), [직접 투구·햅틱](PITCH_CONTROL_HAPTICS_2026-09-05.md), [전체 개선 이력](LAUNCH_IMPROVEMENT_STATUS.md). 생성 증거는 보관 정책에 따라 최근 3개 QA 묶음만 유지한다.
