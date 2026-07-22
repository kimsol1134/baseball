# Project Diamond Soul

데이터 중심 야구 로그라이트 RPG의 P1 Pitch Kernel 프로토타입이다. 현재 구현은 한 타석의 투구 선택을 `React → Tauri → Swift sidecar`로 전달하고, 고정 시드에서 결정론적 이벤트 스트림과 결과를 반환한다.

전체 개발 기준선은 [DEVELOPMENT_PLAN.md](./docs/docs/DEVELOPMENT_PLAN.md)를 따른다. 상세 PRD·TRD·프로토타입·QA 문서는 [개발 문서 패키지](./docs/README.md)에서 찾을 수 있다.

## 현재 구현

- 정수 연산 기반 SplitMix64 결정론적 RNG
- 투수·타자·카운트·피로·구종·3×3 코스·강도 모델
- `health`, `listPitcherPresets`, `simulatePitch`, `preparePitch`, `submitPitch` JSON-RPC 2.0 메서드
- 결과, 원인 피드백, 다음 시드, 이벤트 해시
- 표시 문구와 분리된 불변 이벤트·화면 스냅숏 응답
- Swift sidecar와 1,000구 이상 배치 실행 CLI
- Tauri 2 + React 19 투구 선택 화면
- 프런트엔드에서 직접 프로세스를 실행하지 않는 제한된 Tauri 명령 경계
- sidecar 비정상 종료 표시와 재연결 경로
- JSON fixture 골든 테스트를 포함한 Swift 단위·결정론·프로토콜 테스트
- TypeScript 프로토콜·연결 테스트
- JSON+ZIP portable save archive와 SHA-256·CRC32 무결성 검증
- 임시 파일 검증, 정상 백업 3개 순환, 손상 원본 보존·복구
- 타자 계획 commitment와 stale 준비 토큰 검증
- 공개 정보만 사용하는 포수 주 추천·대안 추천
- 존 의도, 실제 위치·구속·무브먼트, ABS, 스윙·접촉·타구 모델
- 볼카운트, 파울, 삼진, 볼넷, 인플레이까지 이어지는 완전한 타석 루프
- 네 가지 투수 프리셋과 구종별 구속·제구·커맨드·무브먼트·헛스윙·약한 타구·피로 프로필
- 프리셋 선택과 구종별 20~80 능력치를 보여주는 플레이 화면
- 같은 매치업의 최근 24구를 학습하는 라이벌 적응과 반복 패턴 경고
- 준비 전에 확정되는 라이벌 노림수와 기억 변조 방지 토큰
- 중립 타구 결과와 분리된 내야·외야 수비 및 안타·홈런 구장 팩터
- 볼넷·안타·장타에 따른 주자 진루와 실점 상태
- 최근 120구의 존율·헛스윙률·강한 타구율·예상/실제 피해 분석
- macOS·Windows Swift 및 데스크톱 구성 CI

## 요구 환경

- Node.js 22 이상
- Swift 6.3 계열
- Rust stable

Rust가 시스템에 없다면 프로젝트 내부에만 설치할 수 있다.

```sh
./tools/bootstrap-rust.sh
```

## 시작하기

```sh
npm install
npm run desktop:dev
```

`desktop:dev`는 Swift sidecar를 release 모드로 빌드하고 현재 Rust target triple에 맞는 이름으로 복사한 뒤 Tauri 앱을 실행한다.

## 검증 명령

```sh
npm run test:swift
npm run test:web
npm run build:web
npm run prepare:sidecar
npm run check:tauri
```

전체 검증:

```sh
npm run check
```

배치 타석 시뮬레이션:

```sh
swift run -c release --package-path packages/simulation-core simulation-cli --iterations 10000 --strategy primary --preset power_prospect --memory persistent --defense 55 --park 980
```

`--strategy`는 `primary`, `alternative`, `fixed`를 지원한다. `--preset`은 `power_prospect`, `precision_commander`, `breaking_ball_artist`, `innings_eater`를 지원한다. `--memory`는 타석마다 초기화하는 `reset`과 같은 라이벌에게 이어지는 `persistent`를 지원한다. `--defense`는 20~80, `--park`는 중립 1000 기준 700~1300 범위다.

샘플 저장 아카이브 생성과 재검증:

```sh
swift run --package-path packages/simulation-core save-archive-cli --output prototype.dscareer
```

## 주요 경로

```text
apps/windows/                  React + Tauri 데스크톱 앱
packages/simulation-core/     Swift 코어, JSON-RPC sidecar, CLI, 테스트
schemas/                      JSON-RPC, Pitch Kernel, 저장 manifest·checksum 스키마
docs/adr/                     아키텍처 결정 기록
tools/                        sidecar 빌드와 로컬 도구 체인 실행기
```

## P0 범위

현재 확률과 결과 분포는 시스템 연결과 재현성을 검증하기 위한 초기값이다.

완료된 P0 항목:

- Swift 코어와 React·Tauri 앱의 NDJSON JSON-RPC 왕복
- 한 투구 세로 관통 데모와 결정론적 이벤트 해시
- 이벤트와 UI용 스냅숏 분리
- sidecar 오류 감지·사용자 재연결 경로
- portable save archive 쓰기·읽기와 강제 종료 복구 테스트
- macOS 로컬 테스트·릴리스 빌드와 Windows CI 구성

남은 P0 항목:

- 원격 Windows CI의 실제 통과 확인

## P1 진행 상태

현재 완료:

- 타자 계획 선확정과 포수 추천 정보 차단
- 주·대안 추천, 구종·3×3 코스·존 의도·강도 입력
- 투구 실행 분포, ABS, 스윙, 접촉, 타구 속도·발사각·방향
- 삼진·볼넷·인플레이까지의 타석 상태 전이
- 선택·실행·결과를 분리한 reason code와 화면 피드백
- 전략별 10만 타석 배치 비교 도구
- 네 가지 투수 프리셋과 16개 구종별 개별 프로필
- 프리셋별 구속·목표 오차·헛스윙·피로 차이를 검증하는 통계 테스트
- 라이벌의 타석 간 최근 24구 기억과 구종·코스 반복 학습
- 반복 전략이 혼합 전략보다 평균적으로 더 많은 인플레이를 허용하는 통계 테스트
- 중립 타구와 분리된 수비·구장 최종 판정 및 결정론적 주자 진루
- 기대 피해와 실제 피해를 구분하는 최근 120구 경기 후 분석

다음 구현:

- 포지션별 야수·병살·도루와 아웃카운트가 포함된 이닝 상태 전이
