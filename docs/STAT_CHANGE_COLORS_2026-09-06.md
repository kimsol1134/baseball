# 훈련·스킬 수치 변화 색상 적용

2026-09-06. 현재 테스트 중인 Android 앱에 적용했다.

| 의미 | 색상 |
|---|---|
| 수치 상승 | 기존 팔레트의 코랄 레드 #EF746A |
| 수치 하락 | 공통 팔레트의 밝은 블루 #8FBAFF |
| 이전 값·변화 없음 | 기존 보조 글자색 #B4C1BB |

훈련 예상 성장과 비용, 훈련 결과와 상세, 스킬 목록의 효과 미리보기와 습득 확인창에 동일한 규칙을 적용했다. 전후 비교는 이전 값을 회색으로, 바뀐 값을 방향에 맞는 색과 굵은 글씨로 표시한다. +/−, 화살표와 실제 숫자를 보존해 색상만으로 의미를 전달하지 않는다. 범위 안의 +0도 변화 없음으로 표시한다.

색은 수치의 증가·감소를 뜻한다. 피로 +6은 빨강, 회복 −8은 파랑이며, 피로의 유불리는 기존 상태 설명과 경고로 구분한다. 선수 능력이나 저장 값, 성장·스킬 효과 계산은 변경하지 않았다.

## 실제 확인 화면

| 훈련 결과와 스킬 미리보기 | 스킬 습득 확인 |
|---|---|
| ![훈련 수치 색상](/Users/solkim/Dev/baseball/docs/assets/mobile-core/stat-colors-training.png) | ![스킬 수치 색상](/Users/solkim/Dev/baseball/docs/assets/mobile-core/stat-colors-skill.png) |

첫 이미지는 실제 앱의 훈련 직후 화면, 두 번째는 실기기의 스킬 화면 컴포넌트 검사 캡처다.

## 검증

- 색상 방향·혼합 스킬 효과·0·범위·회복·한국어/영어/일본어 문자열 보존 검사 통과.
- 네 가지 더그아웃 배경에서 최소 대비는 빨강 5.17:1, 파랑 7.45:1로 작은 글씨 기준 4.5:1 이상.
- 앱 단위 검사 13개, 실제 훈련/저장 재로드와 스킬 선택 확인 검사 2개 통과.
- debug/release 빌드 검사와 lint, 문구/소스 검사 통과. 검증 중 발견한 API 27 전용 시작 화면 속성은 버전별 리소스로 분리해 Android 8.0 호환성 오류를 해결했다.
- 최신 core QA 앱을 Galaxy A53에 업데이트했다. 설치 전후 기존 저장 파일의 SHA-256이 같음을 확인했다.

[빌드 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/stat-colors-final-build.log) · [훈련 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/stat-colors-training.log) · [스킬 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/stat-colors-skill.log)
