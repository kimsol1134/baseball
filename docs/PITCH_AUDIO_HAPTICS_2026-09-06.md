# Android 투구 효과음·햅틱 연결

2026-09-06. iOS의 [결과별 효과음 매핑](/Users/solkim/Dev/baseball/apps/ios/Sources/Platform/GameAudioCueMapping.swift), [음원 재생](/Users/solkim/Dev/baseball/apps/ios/Sources/Platform/GameAudio.swift), [햅틱](/Users/solkim/Dev/baseball/apps/ios/Sources/Platform/Haptics.swift)을 확인해 Android에 반영했다.

## 발견한 원인

- 투구 화면이 release/plate/impact 문자열을 메뉴용 출력 함수에 보내고 있었다. 그 함수는 해당 문자열을 처리하지 않아 투구 효과가 누락됐다.
- release 음원 파일이 실제로는 스트라이크 음성 파일과 동일했다. 공을 놓을 때 심판 콜이 나오는 잘못된 연결이었다.
- 효과음 재생 속도가 0.33/0.67/1.0으로 계산됐다. 정상적인 음색·속도를 유지하지 못하는 값이었다.
- 실기기 기록에는 기존 진동이 완료된 경우도 있었지만, 릴리스 직후 미터 틱이 릴리스 진동을 덮어 취소한 사례가 있었다.

## 최종 동작

| 장면 | 소리 |
|---|---|
| 손을 떼는 순간 | iOS의 짧은 공기 소리·낮아지는 음을 참고한 110ms 합성음 |
| 볼 | 포구음. iOS도 별도 볼 음성 파일이 없고 합성 볼 콜은 비활성이다. |
| 스트라이크 | 포구 또는 헛스윙 뒤 Strike 콜 |
| 삼진 | 일반 Strike 콜을 생략하고 Strike three, you're out 풀콜 → 함성 |
| 파울 | 짧은 파울 타격음 |
| 인플레이 | 타구 세기에 맞는 타격음과 결과별 관중 반응 |

iOS에서 사용하던 CC0 음원을 복사했다. [Android 음원 크레딧](/Users/solkim/Dev/baseball/apps/android/platform/AUDIO_CREDITS.md)에 출처를 연결했다. 릴리스 합성음은 [재생성 스크립트](/Users/solkim/Dev/baseball/tools/generate-android-pitch-release.py)로 관리한다.

투구에는 타입으로 구분한 출력 요청을 사용해 잘못된 문자열 연결을 방지했다. 음원을 미리 준비하고 로드 완료를 확인한 뒤 재생한다. 투구 음원은 정상 속도 1.0으로 재생하며 포구·콜·관중 순서를 분리했다. 삼진 음성이 끝나기 전에 함성이 덮지 않도록 간격을 둔다.

누르기·안정 구간 진입·릴리스·퍼펙트와 결과에 햅틱을 연결했다. 고급 효과를 지원하면 최적화된 프리셋을, 그렇지 않으면 짧은 기본 패턴을 쓴다. 손을 뗀 뒤 남은 프레임이 틱을 내지 못하게 했고 릴리스 진동 보호 구간을 뒀다. 볼·파울은 iOS처럼 별도 결과 진동을 생략하며, 퍼펙트 릴리스 뒤에는 결과 진동을 겹치지 않는다.

앱 효과음/진동 끄기와 시스템 진동 설정을 존중한다. 시스템 강도는 변경하지 않았다. 화면을 떠나면 재생 중 효과와 예약된 출력을 중단하며, 이전 투구의 지연 효과가 다음 투구에 섞이지 않게 한다.

## 검증

- 판정·타이밍 매핑 3개, 플랫폼 계약 28개, 앱 단위 13개 통과.
- debug/release 컴파일·lint, 소스/문구 검사 통과.
- Galaxy A53에서 음원 전체 로드 완료와 정상 속도 스트림 재생을 확인했다. 별도 출력 테스트로 포구·스트라이크·삼진 풀콜과 진동 패턴을 실행했다.
- 실제 기본 슬라이더로 한 구를 던져 결과 저장과 학교 선택까지 통과했다. 시스템 진동 기록에서 누르기·구간 틱·릴리스·결과 패턴의 완료를 확인했다.
- 기존 사용자 설정은 효과음·진동 켜짐, 시스템 터치 진동은 낮음이었다. 시스템 설정을 임의로 올리지 않았다.
- 최신 core QA 앱을 Galaxy A53에 설치·실행했다. 설치 전후 기존 저장 파일 해시가 같다.

[출력 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/pitch-feedback-device.log) · [실제 수동 투구](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/pitch-feedback-manual.log) · [음원 재생 기록](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/pitch-feedback-device-output.log) · [기기 진동 완료 기록](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/pitch-feedback-vibrations.log)

기기 출력의 실행과 완료를 확인한 결과다. 촉감이 iPhone과 물리적으로 같다는 의미는 아니며, 모터와 사용자 강도 설정에 따라 달라진다.
