# 페르소나 기반 에뮬레이터 E2E QA

실사용자를 모집한 리서치가 아니라, 대표적인 사용 동기를 가정해 실제 앱과 native 저장 경로를 실행한 QA다. 화면만 그린 fixture 검증은 별도 보조 검증으로 구분한다.

## 격리와 범위

기존 `emulator-5554`를 재사용하고 이번 실행에서 새로 설치한 `com.solkim.baseball.android.audit.compose.qa`에서만 진행한다. 기존 compose/core/reset 앱과 연결된 실기기의 기록에는 쓰지 않는다. 초기화는 새 audit 패키지에만 수행한다.

## 페르소나

| 유형 | 행동과 기대 | 실행 방식 |
|---|---|---|
| 야구 입문자 | 첫 화면→이름·지역→유형→슬라이더 첫 투구→학교→가벼운 제구 훈련. 결과를 읽고 홈으로 나갔다 돌아와도 성과가 남아야 함 | 실제 Activity, UIAutomator 터치, native 저장 |
| 수동 투구 팬 | 중간계투로 주자를 승계한 상황을 읽고 직접 던짐. 주자 다이아몬드, 목표, 한 구의 저장, 복귀 후 중복 방지를 확인 | 정상 게임 명령으로 승부처까지 준비 후 실제 PitchActivity 제스처 |
| 빠른 진행·기록 팬 | 프로부터 시작, 제구 계획 선택·확정, 한 시즌 진행, 2시즌 진입, 지난 시즌 WHIP/경기 보존 확인, 카드·공유, 백업·복원 | 생성·첫 훈련·기록·공유는 UI. 긴 일정은 실제 앱 명령으로 진행하는 hybrid E2E |
| 캐릭터 애착형 | 기본 난이도로 고교 3년→드래프트→유산→환생, 이름·얼굴 기준·기록·투구 재생 보존과 재접속 | 졸업까지 native 명령, 환생 및 복귀는 실제 Activity UI |

명령으로 진행한 중요한 경기에서도 완벽 입력만 반복하지 않는다. 780~915 / 740~860의 여러 입력을 사용한다. 스냅샷의 성적·시즌·성장치를 수정해 목표 지점으로 점프하지 않는다. OS 공유 선택창까지만 열고 타인에게 전송하지 않는다.

## 실행 결과

Android 15 / API 35, 1080×2400, 60Hz 에뮬레이터에서 실행했다.

| 최종 검증 | 결과 | 증거 로그 |
|---|---|---|
| 새 게임→실제 슬라이더→학교 선택 | 통과 | `01-newcomer-opening-final.log` |
| 가벼운 제구 훈련→결과 유지→홈/재실행 | 통과, 훈련 1회만 저장 | `02-newcomer-training-final.log` |
| 실제 승계 주자 표시→슬라이더 한 구→복귀 | 통과, 추가 투구 중복 없음 | `03-manual-pitcher-final.log` |
| 프로 첫 주 UI→1시즌→2시즌→통계/카드/공유/복원 | 통과, 17경기·258아웃(86이닝)·WHIP 1.08 | `04-season-fan-complete.log` |
| 저장된 시즌의 재접속·OS 공유 선택창 | 통과, 전송하지 않고 닫음 | `04b-stable-geometry.log` |
| 고교 졸업→유산→같은 이름으로 환생→복귀 | 통과, 20경기·298아웃(99⅓이닝)과 투구 궤적 보존 | `05-attachment-rebirth.log` |
| 보조 UI 21개 | 20개 최초 통과, 큰 글씨 숫자 1건 수정 후 관련 9개 재검증 통과 | `06-ui-matrix.log`, `07-large-text-final.log` |
| Android JVM / lint / APK 빌드 | 15개 단위 테스트 및 lint·빌드 통과 | `unit-lint.log`, `final-check-build.log` |

프로 백업 61,707바이트를 별도 설치 ID의 native 저장소에 복원하고 다시 열어 앨범을 대조했다. 손상 백업의 거부, 쓰기 경로 장애 때 상태 불변, 장애 해소 후 같은 명령 재시도, 재접속까지 통과했다.

모든 로그·이미지·JSON은 `artifacts/android-compose/persona-e2e/`에 있다. `evidence/persona-fan.json`, `persona-attached.json`, `persona-newcomer.json`에 실제 완료 수치를 기록했다. 긴 일정은 명령으로 진행했으므로 위 6개 경로를 모두 순수 UI E2E로 부르지는 않는다.

## 발견 및 보완

- 새 화면 전환의 500ms 입력 차단 중에도 버튼이 활성으로 보일 수 있는 불일치를 보완했다. 차단 시간에는 해당 화면의 조작도 비활성화하며, 기존 전환 보호는 유지한다. `MainActivity.kt`.
- 훈련 결과는 인라인 박스가 아니라 실제 `훈련 완료` Dialog였다. UIAutomator 테스트를 실제 표시 문구 기준으로 수정했다. 앱 결함으로 집계하지 않는다.
- Compose의 점유 베이스는 Android 접근성에서 `selected` 대신 `checked`로 노출된다. 실제 XML에서 2루 주자 있음/checked=true와 녹색 점유 그림을 확인하고 기존 direct-outing 테스트를 수정했다.
- 에뮬레이터 cold 첫 투구에서 기존 10초 한도 초과 1회를 관찰해 25초 한도와 구간 시간을 기록하도록 했다. 재실행에서 측정한 7.94초는 자동화 탭·idle 대기까지 포함하므로 앱 자체의 시작 성능 측정값으로 해석하지 않는다.
- 관성 스크롤 도중 탭은 스크롤을 멈추는 데 소비되어 카드 클릭 콜백에 도달하지 않았다. 임시 진단 로그로 확인한 후 느린 스크롤과 350ms 동안 동일한 버튼 경계 확인을 적용했다. 실제 공유 선택창까지 재검증했다. 임시 앱 진단 로그는 제거했고, 이 실패는 앱의 카드 생성 장애로 집계하지 않는다.
- 글씨 2배/280dp 성적표에서 `162.2`가 2줄로 갈라지는 실제 표시 문제를 수정했다. 숫자의 측정 폭으로 열 수를 1~3개 사이에서 조정하고, 모든 글자와 실제 글자 경계가 한 줄 안에 들어오는지 검증한다. 표 전체를 한 컨테이너로 묶어 기존 부모 레이아웃 때문에 커지던 행간도 정리했다.

## 추가 개선 후보

1. 표의 과도한 행간은 이번에 정리했다. 남은 개선으로 카드 보기 버튼을 상세 표 위에 유지하면 상세 성적을 확인한 뒤 공유하는 동선이 더 짧아진다.
2. ‘여러 주 진행’과 선택한 훈련의 관계가 불명확하다. 현재 배치 payload는 구위 훈련 고정이다. 선택 계획을 반영하거나 감독에게 맡겼을 때 어떤 훈련이 진행되는지 표시할 필요가 있다. 코드에서 확인한 UX 후보이며 요구사항 위반으로 단정하지 않는다.
3. 기록 탭의 ‘앨범’, 상단 ‘기록 카드’, 본문 ‘선수 앨범’ 표기를 통일하면 경로를 이해하기 쉽다.

## 한계

한 시즌 프로 경로와 고교 졸업·환생 경로를 다룬다. 모든 구단·학교·난이도·20시즌 조합의 전수 검증은 아니다. 실제 햅틱의 느낌, 장시간 발열·배터리, 외부 메신저의 최종 전송은 이번 에뮬레이터 QA의 범위가 아니다.


## 재현 조건

빌드는 `-PbaseballLaunchQa=true -PbaseballAuditQa=true -PbaseballQaNativeStore=true`를 함께 사용한다. 기본 투구 설정을 바꾸지 않는다. `FirstPitchLocalizedSmokeTest` 후 `PersonaJourneyE2ETest#newcomerSelectsSchoolAndGetsPersistentTrainingFeedback`, `DirectOutingAuditTest`를 순서대로 실행한다. 프로 및 환생 페르소나는 각각 새 audit 저장에서 `busyBaseballFanCompletesSeasonInspectsSharesAndRestoresRecords`, `attachedPlayerFinishesSchoolAndRebirthKeepsThePreviousLife`를 개별 실행한다. 기존 앱이나 연결된 실기기에 `pm clear`를 실행해서는 안 된다.

검증 후 audit 앱과 테스트 APK를 에뮬레이터에서 제거했고, 기존 compose/core/reset 패키지가 남아 있음을 확인했다. 연결된 실기기에는 설치·초기화·테스트 명령을 보내지 않았다. 표준 `-PbaseballLaunchQa=true` 빌드를 다시 만들어 기본 APK 출력이 audit 전용 패키지로 남지 않도록 정리했다 (`standard-qa-build.log`).
