# Project Diamond Soul

데이터 중심 야구 로그라이트 RPG의 무료 고교 커리어 1.0 출시 후보다. 선수 생성·훈련·관계·중요 이닝 직접 투구·행동 기반 각성·드래프트·환생을 `React → Tauri → Swift sidecar`로 실행하며, 고정 시드에서 결정론적 결과와 복구 가능한 자동 저장을 제공한다.

프로 커리어와 iOS 클라이언트의 기능 구현도 포함하지만 공개 빌드에서 개발 권한으로 자동 해금하지 않는다. 상용 구매·복원, 배포 서명, 실제 장치 QA 등 공개 전 게이트는 [출시 체크리스트](./docs/RELEASE_1_0_CHECKLIST.md)와 [QA 현황](./docs/QA_RELEASE_GATES.md)에서 관리한다.

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
- 9개 포지션별 범위·포구·송구 능력과 담당 야수 판정
- 주자 속도·포수 송구 기반 자동 도루 및 키스톤 수비 기반 병살
- 아웃카운트와 회초·회말을 보존하는 결정론적 이닝 상태 전이
- 최근 120구의 존율·헛스윙률·강한 타구율·예상/실제 피해 분석
- macOS·Windows Swift 및 데스크톱 구성 CI
- 네 프리셋과 자유 생성 포인트 5점으로 시작하는 Pitcher Lab
- 훈련 6회, 중요 이닝 3회, 포수 관계 2회, 각성 2회의 검증형 상태 머신
- 숨은 성장 특성과 공개 잠재 범위·성장 단서 분리, 상태 commitment 검증
- 스카우팅 평가, 야구혼 분야·기억 카드·학교·코치 후보 해금
- 선택한 야구혼 2점과 기억을 적용한 두 번째 삶 및 최종 비교
- 체크섬 주 저장·정상 백업 기반 자동 저장, 강제 종료 재개와 분석 JSON 내보내기
- 이름·지역·투구 손·체격을 포함한 중학교 프롤로그와 고교 선수 생성
- 학교·감독·포수 4조합, 라이벌 6종과 8개 고교 커리어 챕터
- 훈련 16회, 관계 5회, 중요 경기 5회, 각성 3회의 고교 상태 머신
- 관계·성장 사건 36개, 중요 경기 상황 12개, 각성·기억 후보 각 18개
- 10개 프로 구단 수요에 따른 지명·미지명 결말과 기억 3장 계승
- 지명 구단·순위·계약금·육성 계획·경쟁자·담당 코치·첫 시즌 목표 미리보기
- 고교 커리어 전용 자동 저장·백업 복구와 고대비·모션 감소 설정
- 포수 콜 자동 적용, 직전 선택 반복, 결과 우선 공개와 상세 분석 접기
- 목표·실제 투구 궤적, 절차적 효과음·진동, 모션 감소·개별 음소거
- 인물 성향별 관계 결과와 다음 중요 경기 콜백
- 최근 행동을 반영한 각성 후보 3개와 실제 구종·능력 장단점
- 단계적 드래프트 공개와 건너뛰기
- 기록 기반 1군 콜업·보직 변화, 3주 반복, 커리어 마일스톤·수상 타임라인

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

## P1 완료 상태

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
- 포지션별 담당 야수와 포수 도루 저지, 키스톤 병살 판정
- 세 번째 아웃 뒤 공수 교대까지 이어지는 이닝 상태 전이

## P2 진행 상태

현재 완료:

- 새 실험, 네 프리셋 선택과 생성 포인트 5점 자유 배분
- 현재 능력, 잠재 범위와 훈련 반응 단서를 함께 보여주는 성장 대시보드
- 훈련 6회, 회복, 중요 이닝 3회와 라이벌 재대결
- 포수 관계 사건 2회, 각성 선택 2회, 최종 스카우팅 리포트
- 야구혼·기억·학교·코치 해금과 같은 구조의 두 번째 삶
- 첫 삶과 두 번째 삶의 최종 능력·평가·기대 피해 비교
- 확정 revision 자동 저장, 정상 백업 복구와 로컬 분석 내보내기

다음 구현:

- 실제 플레이테스터 모집과 P2 정량·정성 통과 기준 측정
- P2 실제 플레이테스트의 두 번째 삶 시작률과 정성 피드백 측정

## P3 완료 상태

현재 완료:

- 중학교 프롤로그, 자유 선수 생성과 학교 4종 선택
- 8개 챕터 전체와 훈련·관계·중요 경기·각성의 결정론적 진행
- 기존 Pitch Kernel을 재사용하는 5개 중요 경기 직접 투구
- 10개 구단 수요 기반 드래프트와 지명·미지명 양쪽 완결 경로
- 미지명 기억 3장 계승, 뉴스·팬 관심과 프로 구단 육성 계획 미리보기
- 체크섬 자동 저장·백업 복구, 키보드 기본 경로, 고대비와 모션 감소

## P4–P7 구현 상태

- P4: 첫 삶 튜토리얼, 4축 난이도, 업보 6종, 저장 v1→v2, 로컬 옵트인 분석, 익명 진단, 글자 크기·고대비·모션 감소, 선언형 콘텐츠 팩과 프로 잠금
- P5: 지명 저장 승계, 권한 인터페이스, 신인 계약, 2군·1군/보직 경쟁, 주간 계획·피로·부상·중요 경기와 3시즌 슬라이스
- P6: 10구단, FA·군 복무·노쇠화, 계약, 최대 12시즌, 수상·이정표·은퇴·명예의 전당 및 20개 완주 회귀
- P7: iOS 17 SwiftUI 앱, iPhone 단방향 UX, iPad 분할 보기, Dynamic Type·VoiceOver·백그라운드 저장, 공유 코어 Simulator 빌드

아직 외부 승인이 필요한 게이트는 [QA_RELEASE_GATES.md](docs/QA_RELEASE_GATES.md)에 별도로 기록한다.
