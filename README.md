# Project Diamond Soul

데이터 중심 야구 로그라이트 RPG의 P0 관통 프로토타입이다. 현재 구현은 한 투구를 `React → Tauri → Swift sidecar`로 전달하고, 고정 시드에서 결정론적 결과 이벤트를 반환한다.

전체 개발 기준선은 [DEVELOPMENT_PLAN.md](./docs/docs/DEVELOPMENT_PLAN.md)를 따른다. 상세 PRD·TRD·프로토타입·QA 문서는 [개발 문서 패키지](./docs/README.md)에서 찾을 수 있다.

## 현재 구현

- 정수 연산 기반 SplitMix64 결정론적 RNG
- 투수·타자·카운트·피로·구종·3×3 코스·강도 모델
- `health`, `simulatePitch` JSON-RPC 2.0 메서드
- 결과, 원인 피드백, 다음 시드, 이벤트 해시
- 표시 문구와 분리된 불변 이벤트·화면 스냅숏 응답
- Swift sidecar와 1,000구 이상 배치 실행 CLI
- Tauri 2 + React 19 투구 선택 화면
- 프런트엔드에서 직접 프로세스를 실행하지 않는 제한된 Tauri 명령 경계
- sidecar 비정상 종료 표시와 재연결 경로
- JSON fixture 골든 테스트를 포함한 Swift 단위·결정론·프로토콜 테스트
- TypeScript 프로토콜·연결 테스트
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

배치 시뮬레이션:

```sh
swift run --package-path packages/simulation-core simulation-cli --iterations 10000
```

## 주요 경로

```text
apps/windows/                  React + Tauri 데스크톱 앱
packages/simulation-core/     Swift 코어, JSON-RPC sidecar, CLI, 테스트
schemas/                      JSON-RPC 및 투구 요청 스키마
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
- macOS 로컬 테스트·릴리스 빌드와 Windows CI 구성

남은 P0 항목:

- JSON+ZIP portable save archive 쓰기·읽기
- 원자적 교체, 정상 백업 보존, 강제 종료 복구 테스트
- 원격 Windows CI의 실제 통과 확인

실제 포수 추천 엔진과 타석 상태 전이는 P1에서 구현한다.
