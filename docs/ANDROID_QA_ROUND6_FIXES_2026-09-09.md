# Android 6차 후속 개선 결과 · 2026-09-09

계획: `ANDROID_QA_ROUND6_IMPROVEMENT_PLAN_2026-09-09.md`. 기존 미커밋 작업을 보존한 추가 수정이다. 스토어 업로드·출시는 수행하지 않았다.

## U-01: 로그 누락과 부정확한 저장 실패 안내 개선

투구 불러오기·던지기·연출 완료·연습 종료·등판 종료·다음 공·빠른 진행의 예외를 `reportPitchFailure`로 연결했다. 오류 대화만 표시하고 예외를 버리던 경로에 단계, correlation ID, session/pitch ID, 실제 command ID, 기대/현재 revision, boundary, 생명주기, 앱 버전, 원인 스택이 남는다. 저장소는 원래 예외 타입을 유지하면서 실제 명령 정보를 suppressed context로 붙인다.

명령 이름은 클래스 이름이 아니라 직렬화 wire 이름을 사용한다. 릴리스 난독화에 의해 `consumePitch`·`terminalPitch` 등의 식별값이 바뀌지 않는다. 전체 세이브·선수 이름·설치 ID를 진단 메시지에 덤프하지 않는다. 예외 없는 상태 확인 대화에도 경고 기록이 남는다.

쓰기 명령이 생성되지 않은 읽기/사전 상태 검사 실패에는 command ID가 없으며, 이 경우 값을 추정하지 않고 작업 단계와 correlation ID로 추적한다.

오류 후에는 native 저장 파일을 다시 검증한다. 같은 session과 최신 pitch ID의 커밋 결과가 확인되고 화면용 결과도 재구성되면 다음과 같이 안내한다.

> 투구 결과는 저장됐어요. 결과 확인을 눌러 이어서 진행해 주세요.

`결과 확인`은 투구를 다시 실행하지 않고 consume/terminal 후속 처리만 수행한다. 디스크 상태를 확인하지 못했거나 대상 결과를 확정할 수 없으면 저장 성공을 주장하지 않고 복귀를 안내한다. 이 경우 새 투구 입력을 막고 `돌아가기`로 중단/복귀 경로를 제공한다. 파일이 없는 reconcile 결과를 durable 확인으로 취급하지 않으며, 같은 revision의 내용 충돌도 거부한다.

정상 `CancellationException`은 저장 실패 대화로 바꾸지 않는다. 종료된 Activity에 대화를 표시하지 않으며, 이전 request의 완료 콜백은 현재 투구에 적용하지 않는다. controller의 소비 처리도 session과 최신 커밋 pitch ID를 검사하고 이미 완료된 같은 결과의 재처리는 멱등적으로 끝낸다.

**확인 범위:** 저장 전 실패, 커밋 이후 consume 실패, consume 이후 terminal 실패를 주입해 native 파일 재검증·재시작·재시도를 통과했다. 명령 ID와 실패 단계가 연결되고, 투구/기록이 중복 적용되지 않는다. 실제 UI에서 저장 전 안내, 저장 후 결과 확인 버튼, Activity 종료 중 취소와 재개도 검증했다.

6차 QA에서 한 번 관측한 U-01 자체를 같은 업데이트 상황에서 재현한 것은 아니다. 진단 공백과 잘못된 안내 분류는 개선했지만 **최초 관측의 정확한 원인은 여전히 미확정**이다. 증거의 오류 대화는 명시적인 테스트 실패 주입 결과다.

## 추가 발견: 프로 경기의 이전 연출 정리 누락 수정

S-10의 정상 seed 여정을 native 저장과 UI에 연결하자, 입력 슬라이더 대신 이전 결과를 복구하는 동작이 재현됐다. native `CSharpLegacyAggregateBridge.clearPresentation`에는 고교 연출 정리만 있고 프로 분기가 없었다. 반면 일반 reducer에는 프로 정리가 구현돼 있어 두 writer의 동작이 달랐다.

프로 분기에 `lastPresentation`·`lastBattedBall`·`lastFielding` 정리와 커널 commitment 재계산을 추가했다. 고교 데이터와 게임 기록은 유지한다. 완료 또는 포기된 투구에서만 정리를 허용하여 아직 처리 중인 결과를 지우지 않는다.

다음 입력 상태에서는 이전 연출이 없고 `shouldRecoverPlayingPresentation`이 false임을 검사한다. 이 결함이 U-01의 최초 관측과 같은 원인이라는 근거는 아직 없으므로 별도 확인된 결함으로 기록한다.

## S-10: 같은 seed의 UI 검증 완료

`naturalHighFatiguePro` 도우미는 seed 7819로 직접 프로 시작→구위 훈련→첫 시즌 선택지→전력 포심 투구→규칙상 가능한 이닝 계속을 실행한다. 피로·주차·투구 수를 목표값으로 덮어쓰지 않는다.

생성된 프로 상태를 native 백업 가져오기 경로로 저장한 뒤 실제 예약·결과 복구·소비·완료·다음 투구 명령으로 입력 상태까지 연결했다. **4주차·18구·피로 80** 상태를 그대로 PitchActivity에 열어 슬라이더와 `pitch.exhaustionExit`를 확인했다. 버튼 실행 후 등판 종료 및 TERMINAL 저장을 검증했고 재검증 시 기록이 유지됐다.

커널 도달성과 별도로 편집한 피로 fixture의 UI만 확인하던 5차의 증거 공백을 닫았다. 이는 정상 규칙으로 생성한 자동화 여정과 에뮬레이터 UI 증거이며, 실기기 수동 완주를 의미하지 않는다.

## S-03

6차 QA의 픽셀 검증 정정에 따라 **오탐 철회로 종결**했다. 제품 수정으로 해결한 항목으로 집계하지 않는다. 5차 결과 문서에도 정정 주석을 추가했다. 추가 내비게이션 패치는 넣지 않았다.

## 검증 및 증거

application 관련 단위 테스트 47개 통과: Round6PitchRecovery 2, Phase7VerticalController 16, Round4Transitions 6, Round2ProgressIntegrity 4, Phase6ContractAudit 9, FileShadowProgressReset 3, CareerBackup 5, InitialPracticeEntry 2.

에뮬레이터 계측 고유 8개 통과: Round6PitchUi 4, Round4LivePitchUi 2, PitchEffortUi 2. 정상 슬라이더 투구, 고피로 종료, 기존 실제 중단 파일의 포기/재개, 작은 화면·큰 글자에서도 조작 노출을 포함한다. 최종 실행은 103.098초였으며, 전체 프로젝트 스위트 통과라는 뜻은 아니다.

원시 증거: `artifacts/qa/android-round6-fixes-2026-09-09/`.

- `pitch-diagnostics.log`: 테스트 실패 주입에 대한 오류 단계·실제 ID·durable 확인 결과.
- `round6-saved-result-dialog.png`, `round6-recovered-result.png`: 저장된 결과의 안내와 후속 처리 복구.
- `round6-unconfirmed-dialog.png`: 저장 전 실패 시 복귀 안내.
- `round6-natural-80.png`, `round6-natural-ended.png`, `round6-natural-proof.json`: 같은 seed의 입력·버튼·종료 증거.
- `unit-results.json`, `final-build.log`, `final-ui-tests.log`: 관련 테스트 결과.

신규 한국어·영어·일본어 안내를 카탈로그에 반영했다. 실제 실패 주입 UI는 한국어에서 실행했고 번역은 문구 매핑 게이트로 확인했다. 출시 전 실제 음성/언어별 조작 검증과 구분한다.

문구 매핑 3,249/3,249, 누락 0. 전체 제품 문구 검사와 `git diff --check`도 통과했다.

## 사용자용 QA 업데이트

`com.solkim.baseball.android.compose.qa`를 기존 설치 위에 업데이트했다. 초기화하지 않았으며, 설치 ID·고교·프로·pitchResume·앨범이 업데이트 전후 동일하다. 작업 시작 시 보존한 원본과 비교해도 커리어는 유지됐다. 전후 파일 크기는 모두 391,496바이트다.

- 빌드: debug + baseballLaunchQa + baseballQaNativeStore. 서명 RC 아님.
- APK SHA-256: `bad22867c75dbaeee4b292ca3c6fd70e61f1e2c203bbf4b0bb74d3847f67dcb0`.
- 비교: `update-preservation.json`; 화면: `updated-qa.png`; 소스 기준: `source-manifest.json`.
- 테스트 실패 주입 문자열·UI 테스트 클래스·자연 피로 fixture가 사용자용 APK에 포함되지 않음을 DEX에서 확인했다.

## 남은 외부 검증

이번 연결 확인에서도 `emulator-5554` 한 대만 보였다. A53 실기기, 2대 OS 자동 복원, 실제 태블릿·폴더블, TalkBack 실청취는 수행하지 못했다. native 백업 왕복이나 에뮬레이터 화면 테스트로 이를 대체하지 않는다.

RC preflight는 `BASEBALL_UPLOAD_KEYSTORE_PATH` 미설정으로 중단됐다. 서명 조건을 우회하지 않았고 debug QA를 release 검증으로 표시하지 않는다. 장비와 서명 설정이 준비되면 이 항목들을 이어서 검증해야 한다.
