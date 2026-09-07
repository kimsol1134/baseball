# Android 공개 출시 가능 여부 점검

2026-09-06. 판정: **공개 출시 보류, 출시 후보를 확정하고 검증할 단계**.

## 확인한 내용

- 직전 개선의 실제 기기·저장·수동 투구 검증은 [개선 보고서](/Users/solkim/Dev/baseball/docs/CORE_LOOP_IMPROVEMENTS_2026-09-06.md)에 기록했다.
- 이번 점검에서 출시 소스 검사, 3개 언어 카탈로그 일치, Kotlin 문구 매핑 2,643개 전부, 전체 제품 문구 검사와 변경분 공백 검사를 통과했다.
- 구형 미지명 문장 1개가 번역 목록에서 빠져 있던 문제를 발견했다. 기존 저장/시뮬레이션 문자열은 보존하고 표시용 별칭을 추가했다. 한국어·영어·일본어에서 새 서사 문구로 표시되는 회귀 검사 포함 GameCopyTest 8개가 통과했다.
- 현재 소스의 compileReleaseKotlin 및 lintRelease가 통과했다. [실행 로그](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/android-release-readiness-20260906.log).
- targetSdk는 36이다. 2026-08-31부터의 휴대폰 신규/업데이트 제출 요건인 API 36 이상을 충족한다. [Google 공식 요건](https://developer.android.com/google/play/requirements/target-sdk?hl=ko).

## 아직 출시 가능으로 표시할 수 없는 이유

1. 최신 개선본의 production 서명 AAB가 없다. 확인한 로컬 AAB는 이전 커밋의 코드 40·41이다. 현재 소스의 기본 버전 코드는 42다.
2. 현재 프로세스의 업로드 키 경로·암호·별칭, Firebase 설정 경로·Amplitude 키 주입이 없고, 점검한 프로젝트/사용자 Gradle 설정에서도 서명 설정을 찾지 못했다. 컴퓨터 전체에 키가 없다는 뜻은 아니다. 비밀 값은 출력하지 않았다.
3. 최신 변경본은 아직 출시용 clean commit으로 고정되지 않았다. 프로젝트의 production RC 스크립트는 clean 소스를 요구하며 dirty 후보를 Play 제출 대상으로 인정하지 않는다.
4. 최신 서명 후보 기준의 설치/업데이트 후 기존 저장, 중단·복귀, 파일 복원, 지원 기기 및 16KB 조건과 production 외부 SDK 설정 검증이 필요하다. QA 앱·이전 고정 후보의 통과를 이 파일의 검증으로 대체하지 않는다.
5. 오늘 Play Console 연결은 두 차례 시간 초과로 실패했다. 현재 정책 경고·프로덕션 이용 자격·등록정보/Data Safety·출시 전 보고서를 확인하지 못했다. 9월 5일의 코드 41/internal·closed-alpha/production 비활성 기록은 [과거 관찰](/Users/solkim/Dev/baseball/docs/android-compose/PLAY_RELEASE_BASELINE.json)이며 오늘 상태로 단정하지 않는다.

## 권고

추가 기능 확대를 멈추고, 최신 소스를 고정해 정식 서명 후보를 만든 뒤 그 후보로 필수 출시 검증을 수행한다. 사용자가 담당하기로 한 플레이테스트에서는 처음 하는 사람이 설명 없이 슬라이더를 던지고, 성장과 피로를 구분하고, 환생 후 다음 행동을 찾는지 확인한다. 새 콘텐츠를 더 넣는 것보다 현재 핵심 루프의 이해와 안정성을 확인하는 것이 우선이다.

이번 점검에서는 업로드·트랙 변경·공개 출시·계정 설정 변경을 수행하지 않았다. 릴리스 컴파일은 서명 산출물과 production 외부 SDK 실수신 검증을 포함하지 않는다.
