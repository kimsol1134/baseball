# 훈련 종류를 처음부터 노출

2026-09-06. Android 훈련 화면의 ‘다른 훈련 고르기’ 펼치기를 제거했다. 구위·제구·변화구·체력·회복·수싸움을 항상 선택 버튼으로 표시한다. 최대 세 개씩 배치하며 큰 글씨에서는 버튼 전체가 줄바꿈된다. 선택한 훈련의 상세만 보여 긴 카드 목록은 만들지 않는다. 재활 중에는 회복만 활성화하고 나머지 종류는 숨기지 않는다.

Galaxy A53에서 여섯 종류의 최초 노출, 학습 카드 연결, 다른 훈련 선택, 명시적 실행 전 횟수 미소모, 실행 후 저장 재로드를 확인했다. 한국어 기본 크기와 일본어 글자 크기 2배 검사가 통과했다. 마지막 줄 배치 보완 뒤 한국어 실기기 검사를 다시 통과했다. 앱 단위·컴파일·lint·문구 검사 통과.

최신 core QA 앱을 설치·실행했고 설치 전후 기존 저장 파일 해시가 같음을 확인했다.

![훈련 선택 화면](/Users/solkim/Dev/baseball/docs/assets/mobile-core/training-choices-visible.png)

[실기기 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/training-choices-device.log) · [큰 글씨 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/training-choices-large.log)
