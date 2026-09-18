# 성장·환생 핵심 흐름 개선 완료

2026-09-06. iOS·Android에 요청한 네 가지 개선을 반영했다. 기본 수동 슬라이더와 기존 캐릭터 초상 체계를 유지했다. 아래 화면은 실제 네이티브 실행 캡처다.

| 개선 | 최종 동작 |
|---|---|
| 성장·피로 구분 | 영구 능력 변화와 현재 피로 비용을 별도 줄로 표시한다. 투구 미터는 실제 속도와 피로 영향을 안내한다. |
| 성장 카드 축소 | 작은 성장에는 대표 변화 한 줄과 컨디션만 먼저 보인다. 전체 능력 변화·구간 비교·설명은 펼쳐서 확인한다. 제구 목표를 넘었을 때 비교 게이지를 강조한다. |
| 환생 직후 행동 | 첫 화면에서 ‘학교를 고르고 시작’ 또는 선택적인 ‘지금 몸으로 한 구 던지기’를 누른다. 한 구가 끝나면 학교 선택으로 진행한다. |
| 캐릭터 서사 통일 | 같은 이름으로 이어가는 기본 흐름은 ‘다시 태어난 나’, ‘지난 생의 나’로 표현한다. 다른 이름을 선택하면 다른 선수의 기록을 이어받는 문구로 구분한다. |

## 성장의 실제 효과

저장용 제구 35/40/50/65/80에서 안정 구간 폭은 각각 18.0/19.5/21.0/22.5/24.0%다. 목표 사이에서도 계속 증가하며, 목표에 도달해야 효과가 갑자기 열리는 구조는 아니다. 다음 제구 목표까지 남은 성장은 작은 진행 막대로 표시한다.

초반 성장에 더 많은 폭을 배분했고 모든 제구 값에서 종전 구간보다 좁아지지 않는다. 예를 들어 제구 35 → 36은 18.0 → 18.3%다. 명목 구속 135km/h·피로 5 → 11·모션 축소 끔을 고정한 계산에서 한 번 통과하는 안정 구간 시간은 약 167.49 → 167.65ms다. 이는 피로가 성장 이득을 지우던 이전 예시를 보완한 계산이며, 이용자가 한 번의 성장을 손으로 구분했다는 실험 결과는 아니다. 따라서 작은 변화의 그래프를 과장하거나 매번 큰 축하를 띄우지 않는다.

퍼펙트 2.5%, 추가 릴리스 보정 최대 60/1000, 직접 조준·기존 저장된 입력·자동 중립 입력 규칙은 유지한다. 피로 비용과 공식 경기 결과는 그대로 반영된다.

## 환생과 연습

- 이번 생 첫 등판 준비를 가까운 목표로 보여준다. 지난 생 전체 탈삼진 갱신 목표는 상세에 남긴다.
- 과거 편지·시작 능력 비교·부가 효과는 펼쳐보기로 옮겼다. iOS의 환생 후 다짐도 선택적으로 펼친다.
- 연습은 환생한 현재 능력과 피로 0을 사용한다. 공식 경기 수·성장 보상·과거 기록·계승 데이터가 바뀌지 않는지 저장 전후와 재로드로 확인했다.
- Android 연습 조작이 커리어 피로를 참조하던 부분을 수정했다. 표시·조작과 실제 연습 판정이 모두 같은 컨디션을 사용한다.
- 같은 이름의 비교는 앞뒤 공백과 대소문자를 정규화한다. 초상 연결은 유지하며 과거 저장된 편지·기록 자체를 덮어쓰지 않는다.
- 한국어·영어·일본어 문구를 함께 반영했다. 장기 약속·기록 관련 경로에서도 ‘다음 선수’ 대신 ‘다음 생’을 사용한다.

## 실제 화면

| iOS 환생 첫 화면 | Android 환생 첫 화면 — 영어 |
|---|---|
| ![iOS 환생](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-ios-reborn-ready-ko.png) | ![Android 환생](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-android-reborn-ready.png) |

| iOS 작은 성장 | iOS 제구 목표 달성 |
|---|---|
| ![작은 성장](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-ios-small-growth.png) | ![목표 달성](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-ios-control-milestone.png) |

| Android 성장 — 기본 크기 | Android 성장 — 글자 크기 2배 |
|---|---|
| ![Android 성장](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-android-training.png) | ![Android 큰 글씨](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-android-training-large.png) |

다른 실제 회차의 캡처이므로 능력·일정·선택 유산이 서로 다르다. iOS 성장 캡처는 훈련 직후 각성으로 넘어간 화면이다. 비교 게이지의 선은 직전 구간, 초록은 현재 구간, 금색은 퍼펙트다.

[일본어 환생 화면](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-ios-reborn-ready-ja.png) · [수동 한 구 연습 종료](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-ios-reborn-practice-finished.png) · [Android 일본어 투구](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-android-slider-ja.png) · [영어 투구](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-android-slider-en.png) · [한국어 투구](/Users/solkim/Dev/baseball/docs/assets/mobile-core/loop-android-slider-ko.png)

## 검증 결과

- Swift 시뮬레이션 코어 14개 통과. 제구 전 범위와 모든 입력 점수에서 기존 구간 하한, 단조성, 퍼펙트 보존, 보정 상한과 직렬화를 확인했다. 고정 조건 2,048쌍의 엔진 검사에서 실행 품질 증가는 최대 15/1000, 결과 변화는 4쌍이었다.
- iOS 단위·저장 통합 70개 통과. UI 5개 경로가 통과했다: 작은 성장, 목표 달성, 일본어 환생 후 바로 진행, 환생 후 수동 한 구, 일본어 고교 한 회차의 드래프트·환생 연결. 마지막 설명 문구 수정 후 연습의 조건과 3개 언어를 재검증했다.
- Android 코어 14개, 애플리케이션 18개, 앱 10개 통과. 애플리케이션 검사는 두 가지 환생 경로를 실제 파일 저장소에서 재로드하는 검사와 현지화·HUD 검사를 포함한다. 최종 APK 빌드와 lint 통과.
- Galaxy A53 실기기: 환생 버튼과 기억 펼치기, 기본/2배 글씨의 훈련과 저장 재로드, 한국어·영어·일본어 기본 슬라이더 수동 투구 통과. 연습 피로 수정 뒤 최종 APK에서 일본어 투구와 기본 크기 훈련을 다시 통과했다.
- 전체 제품 문구 검사 통과: 내부 용어 38종·실존 야구 IP 42종 미노출. 변경분 공백 오류 검사 통과.

검증 중 발견한 iOS 접근성 식별자 전파 문제와 Android 연습 피로 참조 문제는 수정 후 재검증했다. 제구 목표 UI 테스트는 실제 시작 포인트 배분으로 목표 직전 능력치를 만든 뒤 정상 훈련 명령으로 목표를 넘긴다.

[iOS 검증 기록](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/loop-ios-verification.json) · [Android 검증 기록](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/loop-android-verification.json) · [Android QA APK](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/app-coreqa.apk)

## 남은 판단 범위

요청한 구현과 위 기술 검증은 완료했다. 실제 이용자가 성장과 피로를 구분하는지, 환생을 같은 캐릭터의 재도전으로 이해하는지, 반복 플레이의 재미가 좋아졌는지는 사용자 관찰이 필요하다. 기술 테스트로 유료 앱 순위나 유지율 개선을 입증했다고 판단하지 않는다.

검증 대상은 iPhone 17 시뮬레이터와 Galaxy A53의 별도 QA 앱이다. 스토어 제출·TestFlight 업로드는 수행하지 않았다. iOS 공개 배포에는 서명 IPA의 3개 언어 리소스 검사, 일본어 실기기/TestFlight 검증과 대상 App Store 버전의 Japanese 표시 확인이 별도로 필요하다.
