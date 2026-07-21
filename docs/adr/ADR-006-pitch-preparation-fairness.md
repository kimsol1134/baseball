# ADR-006: Stateless sidecar의 타자 계획 선확정

- 상태: 승인
- 결정일: 2026-07-21

## 맥락

타자 계획은 사용자의 투구 콜보다 먼저 확정돼야 하고 포수 추천은 숨은 계획을 읽어서는 안 된다. 현재 Windows 어댑터는 요청마다 Swift sidecar를 새로 실행하므로 메모리 세션만으로 선확정 상태를 유지할 수 없다.

## 결정

- `preparePitch`는 사용자 투구 콜을 받지 않는다.
- 코어는 seed, 공개 경기 컨텍스트, 타자 스카우팅 정보만으로 숨은 타자 계획을 생성한다.
- 숨은 계획 자체는 UI에 반환하지 않고 commitment hash만 노출한다.
- 포수 추천기는 숨은 계획이나 seed를 인자로 받지 않고 공개 정보만 사용한다.
- 준비 결과는 seed, revision, pitch number, 계획 commitment, 주·대안 추천으로 만든 `preparationToken`으로 봉인한다.
- `submitPitch`는 동일 입력으로 계획과 추천을 재구성해 토큰을 확인한 뒤에만 투구 콜을 처리한다.
- stale 또는 변조 토큰은 `-32010 Invalid preparation token` 오류로 거부한다.
- 한 투구 응답에 다음 공의 준비 토큰을 함께 넣어 추가 IPC 왕복을 피한다.

## 결과

- stateless process 경계에서도 타자 AI가 제출된 콜을 본 뒤 계획을 바꾸지 못한다.
- 포수 추천과 타자 계획의 정보 경계를 함수 인자와 자동 테스트로 검증할 수 있다.
- 토큰은 로컬 치팅 방지용 암호 서명이 아니라 결정론과 stale state 검사용이다.

## 검증

- 이벤트 순서가 `batter_plan_committed` → `catcher_recommendations_generated` → `pitch_call_committed`이다.
- 서로 다른 숨은 계획에서도 같은 공개 입력의 포수 추천이 같다.
- 중요도만 바꿔도 투구 실행과 결과가 바뀌지 않는다.
- 같은 seed·context·call이 동일 이벤트 스트림과 해시를 만든다.
- 변조 준비 토큰을 프로토콜에서 거부한다.
