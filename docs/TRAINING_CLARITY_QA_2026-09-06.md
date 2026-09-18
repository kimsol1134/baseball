# 훈련 가독성·구종 학습 동작 개선 및 반복 QA

2026-09-06. 사용자가 지적한 성장 예상, 강도 줄바꿈, 구종 학습 카드 동작을 Android에 반영했다.

- 성장 예상에 능력 이름을 명시한다. 같은 최소·최대는 `무브먼트 +2`처럼 한 번만 표시하고, 범위는 `최소 +0, 최대 +3`처럼 구분한다. 상승 예상이 0이면 숫자 대신 컨디션·강도를 확인하라는 문장을 보여준다.
- 강도·구종 선택 버튼을 글자 길이에 맞춰 배치한다. 공간이 부족하면 버튼 전체가 다음 줄로 이동한다. 글자 크기 2배에서도 ‘몰아붙이기’가 단어 중간에서 꺾이지 않는다.
- 진행 중인 구종 학습 카드를 누르면 해당 구종의 변화구 훈련을 선택한다. 선택과 실제 훈련 실행을 분리해 탭만으로 훈련 횟수를 소모하지 않는다. 재활·학습 완료 상태에는 잘못된 선택 안내를 표시하지 않는다.
- 수치 상승/하락 색상과 실제 저장값은 유지했다.

## 실제 화면과 검증

[한국어 훈련 선택](/Users/solkim/Dev/baseball/docs/assets/mobile-core/training-clarity-ko-selected.png) · [영어](/Users/solkim/Dev/baseball/docs/assets/mobile-core/training-clarity-en-selected.png) · [일본어](/Users/solkim/Dev/baseball/docs/assets/mobile-core/training-clarity-ja-selected.png)

- Galaxy A53: 한국어·영어·일본어 글자 크기 2배에서 학습 카드 선택 → 대상 구종 확인 → 강도 선택 → 훈련 실행 → 결과/저장 재로드 통과. 각 1개씩 3개 검사.
- 실제 학습 카드 선택 전후 훈련 횟수가 같고, 실행 후 정확히 1 증가하는지 확인했다.
- 스킬 선택·구종 학습·환생 시작 비교·슬라이더 취소/릴리스 회귀 5개 통과.
- 성장 예상 0/고정/범위의 3개 언어 검사를 포함한 표시 로직 5개 통과.
- debug/release 컴파일, lint, 카탈로그 일치, Kotlin 문구 매핑 2,642개, 제품 문구 검사 및 변경분 공백 검사 통과.
- 수정 후 반복 검사에서 발견한 버튼 간격을 보완하고 다시 3개 언어 실기기 검사를 수행했다. 확인한 경로에서 남은 실패는 없다.

관련해서 앞선 반복 QA에서 수정한 설정·삭제·저장 복원·투구 오류 안내·색상·효과음·햅틱은 다음 보고서에 기록했다.

- [설정과 추가 오류 수정](/Users/solkim/Dev/baseball/docs/SETTINGS_SIMPLIFICATION_2026-09-06.md)
- [수치 변화 색상](/Users/solkim/Dev/baseball/docs/STAT_CHANGE_COLORS_2026-09-06.md)
- [투구 효과음과 햅틱](/Users/solkim/Dev/baseball/docs/PITCH_AUDIO_HAPTICS_2026-09-06.md)

검사는 별도 QA 앱으로 수행했다. 최신 core QA 앱 설치 전후 사용자의 저장 파일 해시가 같은지 확인했다. 모든 기기·모든 진행 조합에서 버그가 전혀 없다는 의미는 아니며, 위에 명시한 사용자 경로와 회귀 검사 범위의 결과다.
