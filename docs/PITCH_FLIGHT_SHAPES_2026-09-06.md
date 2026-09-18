# 구종별 투구 궤적 시각화

2026-09-06. Android 포수 시점의 투구 표현을 개선했다.

- 직구: 시작점에서 실제 도착점까지 곧게 뻗는 직선.
- 슬라이더: 옆으로 꺾이는 흐름 강조.
- 커브: 다른 구종보다 큰 낙차 강조.
- 체인지업: 슬라이더와 반대쪽으로 흐르며 떨어지는 모양.

변화구는 저장된 물리 궤적과 직선 기준선의 차이를 화면에 확대해 표현한다. 출발 직후 과도한 반전이나 잘린 곡선이 생기지 않게 부드럽게 제한한다. 65개 표시 지점과 프레임 간 보간으로 공이 점 사이를 뛰지 않고 이동한다. 이는 이해를 돕는 시각화이며 물리 엔진·도착점·구속·판정·저장 데이터를 변경하지 않는다.

실제 코어에서 생성한 네 구종의 시작/도착점, 방향·낙차 차이, 프레임 간 연속성과 입력 불변성 검사 2개 통과. 앱 단위 13개, 실기기 네 구종 렌더와 기본 슬라이더 투구 검사 통과. debug/release 컴파일·lint·소스/문구 검사 통과. 비교 화면을 보고 커브 출발부의 과한 꺾임을 보완한 뒤 다시 검사했다.

![네 구종 비교](/Users/solkim/Dev/baseball/docs/assets/mobile-core/pitch-flight-four-types.png)

위 이미지는 Galaxy A53에서 실제 렌더러를 네 칸에 배치한 검사 캡처다. 각 구종은 실제 코어의 서로 다른 구종·코스 입력으로 생성되며, 도착점이 모두 같다는 뜻은 아니다. 전체 앱의 화면 구성은 유지된다.

최신 core QA 앱을 설치·실행했고 설치 전후 기존 사용자 저장 파일 해시 일치를 확인했다.

[렌더 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/pitch-flight-device.log) · [수동 투구 검사](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/pitch-flight-manual.log) · [최종 빌드](/Users/solkim/Dev/baseball/artifacts/mobile-core/qa/pitch-flight-coreqa.log)
