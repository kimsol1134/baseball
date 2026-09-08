# 게임 규칙 버전과 기준 데이터 재현

## 구분

| 경로 | 고교 규칙 | 프로 규칙 | 사용 목적 |
|---|---:|---:|---|
| 현재 Android 기본 엔진 | 5 | 11 | 강도별 성장 확률·진도·지원, 연속 등판·상황별 보직, 현재 포수 사인과 힘배분 |
| 고정 Swift 비교 엔진 | 4 | 10 | 동일 버전의 원본 기준 데이터와 결과·난수 비교 |

`HighSchoolContentCatalog.BALANCE_VERSION = 4`는 기존 콘텐츠/구버전 저장의 기본 해시 기준이다. 새 실행 규칙은 `HighSchoolGameplayRules.CURRENT = 5`로 별도 명시하고 `HighSchoolState.balanceVersion`에 기록한다. 이를 위해 예전 콘텐츠 상수를 바꿔 구버전 해시를 깨뜨리지 않는다.

고교 기본 엔진의 다음 명령 결과는 규칙 5로 기록한다. 기존 선수·일정·능력·구종·이미 완료한 기록을 재생성하지 않는다. 프로 10은 현재 엔진에서 명령이 완료되면 11로 기록한다. 9 이하의 기존 커리어 기능 조건은 즉시 올리지 않으며 기존 시즌 전환 규칙을 유지한다. 진행 중인 투구의 저장된 문맥과 토큰은 재사용한다.

과거 버전 비교는 생성자에 비교 버전을 명시한다. 미래 버전 상태를 과거 엔진에 넘겨 조용히 낮추는 것은 거부한다. 과거 버전 생성자는 테스트 값만 바꾸는 장치가 아니라 이전 성장·각성·드래프트·자동 사인·정산 계산 경로를 실행한다.

## 원인과 수정

- 이전 Swift v4 비교에 현재 강도 보너스·성장 진도·각성 횟수·드래프트 평가가 섞여 있었다. v4의 계산을 보존하고 v5와 구분했다.
- 이전 프로 자동 경기에도 새 포수 사인과 `outing-v2` 힘배분이 적용되고 있었다. 자동 경기의 첫 공부터 후속 공까지 같은 사인 버전을 사용하도록 했다.
- 프로 v10 비교에는 이전 이닝 정산을, v11에는 현재 직접+자동 등판 정산을 적용한다.
- 이전 fixture의 수치·체크섬·원본 트리 해시는 변경하지 않았다. 고정 계산 일부는 기존 커밋 `3d16180b`와 `ca68c792^`의 구현을 참조해 보존했다.

## 검증 근거

- `swift run --package-path packages/simulation-core release-parity-exporter`를 실제 실행해 기준 자료를 생성했다.
- 훈련 216가지 조합, 고교 38개 전이와 3개 정책의 프로 20시즌 전이 총 2,278개를 같은 버전끼리 비교했다.
- `HighSchoolPhase4FixtureTest`, `ProCareerFixtureTest`의 기존 체크섬과 수치 검사를 유지했다.
- 기존 제외 2개(`ReleaseTrainingParityTest`, `ReleaseCareerParityTest`)가 기준 자료를 읽어 실제로 실행되고 통과했다.
- `RulesVersionMigrationTest`는 이전 저장의 원본 바이트 보존, 선수·일정 보존, 다음 명령의 버전 기록, 재저장 후 복원과 역방향 버전 거부를 검사한다.

증거: `artifacts/android-compose/improvement-swift-reference.log`, `improvement-parity-versioned.log`, `improvement-core-full.log`, `improvement-final-build.log`.

이 문서는 Android 개선과 규칙 검증 기록이다. iOS 공개 바이너리 배포나 Android 스토어 출시를 수행했다는 의미는 아니다.
