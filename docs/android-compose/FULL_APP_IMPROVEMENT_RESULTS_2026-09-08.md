# 전체 개선 구현·검증 결과

## 반영한 내용

| 단계 | 결과 |
|---|---|
| 검증 기준·구조 | UI의 규칙 계산을 애플리케이션 계층으로 이동. 테스트 fixture를 별도 소스셋으로 분리. 기존 실패 5개 해소 |
| 기록 | 현재 선수의 고교/프로/시즌/지난 생 기록 선택, 직접+자동 경기 합산, 통산 우선 표시. 복원할 수 없는 과거 이닝은 0이 아닌 `—`로 표시 |
| 프로 주간 | 계획 선택과 실행 분리, 자동 등판·피로 범위 사전 표시, 실제 성장 진도·경기·몸 상태 결과 유지 및 재시작 복구 |
| 등판 | 실제 배정과 같은 보직·이닝·주자·목표 표시. 선발 테스트 중단 의미 표시. 중복 설명 축소 |
| 대화 | 주요 이득과 비용을 함께 미리 표시. 나머지 효과 확인 가능. 효과별 번역과 NPC 얼굴 유지 |
| 공통 UI | 이득/부담 색상, 선택 색상 통일. 짧은 버튼과 설명 분리. 선수 이름·대표 구종 구분 및 헤더 축소 |
| 기억 | 실제 선발 테스트·리드 유지·첫 세이브·최고 직접 등판을 중복 없이 기록. 선수·대화·결산·환생에 연결 |
| 추가 요청 | 큰 이닝 숫자, 아웃 점등, 점유 베이스 다이아몬드, 점수 차로 상황을 시각화. 투구 중에도 같은 베이스 표시 사용 |

## 검증 결과

- 게임 규칙: 전체 **155개 통과**, 제외 0.
- 애플리케이션: 전체 실행의 172개 중 169개 통과 후, 새 규칙 버전 기대값을 수정한 3개를 별도로 재실행해 통과. 이어 과거 이닝 누락 검사 1개를 추가해 검증했다. 총 **173개 경로**에 대한 검증이다.
- 저장 계층 **14개**, Android JVM **15개** 통과.
- UI: 확장 검사 **58개** 통과. 시각 상황판 검사 1개 추가 및 변경된 화면 재검증 통과. 작은 화면·큰 글씨·영어·일본어를 포함한다.
- Swift가 생성한 훈련 **216가지**, 고교 **38개 전이**, 세 정책의 프로 20시즌 **2,278개 전이**를 동일 규칙 버전으로 비교했다.
- Swift 자료 약 **1.4MB**를 `game-core/src/test/resources/fixtures/swift-release-parity-v4-v10.json`에 고정했다. 로컬 export 파일이 없어 비교가 제외되던 조건을 없앴고, 데이터 체크섬과 원본 소스 트리 해시를 확인한다.
- APK·테스트 APK 빌드 및 `lintDebug` 통과.
- 실제 번역 화면 6개에서 플레이어 이름을 제외한 의도치 않은 한글 잔존 없음. 신규 문구의 한국어·영어·일본어와 가상 구단 규칙 확인.

## 실기기

Galaxy A53 (`R5CT40GZSWZ`)에서 별도 검증 패키지를 사용했다.

- 새 설치 → 선수 생성 → 불펜 안내 확인 → 기본 슬라이더 한 구 → 학교 선택 통과.
- 공식 경기의 목표·베이스 점유 표시, 한 번의 조작에 한 구만 저장, 백그라운드 복귀, 저장 파일 재열기 통과.
- 일반/퍼펙트 릴리스의 실제 진동 호출 경로 실행.
- 30초 동안 리플레이 8회: 경기·투구 기록·보상·저장 리비전이 추가되지 않음.
- 반복 재생 표본: 지연 프레임 2.26%, 프레임 시간 중앙값 9ms / 95백분위 18ms / 99백분위 29ms. 해당 구간 전후 배터리 온도 32.8→32.9℃. 최초 진입·화면 전환을 포함한 별도 콜드 표본은 지연 프레임 10.45%였다. 짧은 검증이며 장시간 배터리·발열 인증을 의미하지 않는다.
- 처음 실행 시 앱이 전면에 유지되지 않아 자동 검사가 한 차례 중단됐고 재시도로 통과했다. 이를 제품 정상 통과 결과와 혼동하지 않도록 실패 로그도 남겼다.
- 사용 중인 `com.solkim.baseball.android.compose.qa`는 저장을 초기화하지 않고 업데이트했다. 설치 전후 내부 저장과 이전 네이티브 저장 파일의 SHA-256이 동일함을 확인했다. 원래 진행 중이던 입단 계약 화면으로 실행됐다.
- 검증용 `.audit.compose.qa` 앱은 자료 회수 후 종료·제거했다. 기존 `.compose.qa`, `.core.compose.qa`, `.reset.compose.qa` 데이터는 제거하지 않았다.

## 화면과 실행 증거

- [시각형 경기 전 상황판](/Users/solkim/Dev/baseball/artifacts/android-compose/improved-visual-closer-entry.png)
- [실기기 투구 화면](/Users/solkim/Dev/baseball/artifacts/android-compose/improvement-device-visual-mound.png)
- [실기기 투구 결과](/Users/solkim/Dev/baseball/artifacts/android-compose/improvement-device-visual-result.png)
- [업데이트 후 사용자 앱](/Users/solkim/Dev/baseball/artifacts/android-compose/improvement-user-app-ready.png)
- 전체·재검증 로그: `improvement-final-regression.log`, `improvement-final-rechecks.log`, `improvement-final-ui-suite.log`, `improvement-final-visual-recheck.log`, `improvement-completion-ui.log`.
- 규칙·저장: `improvement-core-full.log`, `improvement-portable-parity.log`, `improvement-final-build.log`.
- 실기기: `improvement-device-first-pitch-retry.log`, `improvement-device-direct-outing.log`, `improvement-device-visual-outing.log`, `improvement-device-haptics.log`, `improvement-device-replay.log`.
- 위 로그와 저장 확인값은 `artifacts/android-compose/`에 있다. QA 이전 화면인 `whole-audit-*.png`는 수정 후 이미지로 덮어쓰지 않았다.

이 작업은 앱 구현·QA·실기기 실행까지다. 스토어 게시나 공개 릴리스 제출은 수행하지 않았다.
