# 요구사항 추적성 매트릭스

| 항목 | 값 |
|---|---|
| 문서 ID | DOC-16 |
| 버전 | 1.0 Baseline |
| 목적 | 제품 요구사항이 사용 사례·기술 모듈·테스트에 연결됐는지 확인 |

## 1. 핵심 기능 추적

| Requirement | 요약 | Use Case | 주요 모듈 | 화면 | 검증 |
|---|---|---|---|---|---|
| PRD-FR-001 | 프리셋·자유 배분 생성 | UC-003 | Domain, Meta, Development | CRT-003~005 | 단위, 생성 예산 테스트 |
| PRD-FR-002 | 현재 세부 스탯 공개 | UC-003, UC-009 | Player, Protocol | PLR-002~005 | UI·산식 추적 테스트 |
| PRD-FR-003 | 잠재 범위·신뢰도 | UC-003, UC-009 | Development, Belief | PLR-003 | 범위 불변조건·표본 테스트 |
| PRD-FR-010 | 60~90분 고교 런 | UC-005, UC-012 | Career, Content | CAR-001 | 플레이테스트 세션 길이 |
| PRD-FR-013 | 학교 차별화 | UC-002, UC-003 | Career, Content | 학교 선택 | 자동 런·선택률 분석 |
| PRD-FR-014 | 미지명 종료·분석 | UC-013 | Career, Meta | META-001 | 미지명 회귀 경로 |
| PRD-FR-020 | 구종·코스·의도·강도 | UC-006~008 | Simulation | CAR-006 | 투구 조합 단위·UI 테스트 |
| PRD-FR-021 | 포수 주·대안 추천 | UC-006~008 | Simulation, Relationship | CAR-006 | 추천 입력·차별성 테스트 |
| PRD-FR-022 | 타자 계획 선확정 | UC-006 | Simulation | 내부 | QA-INV-001 |
| PRD-FR-023 | 장기 상대 적응 | UC-009 | Simulation, Analytics | CAR-008 | 재대결 분포 테스트 |
| PRD-FR-024 | 인과 피드백 | UC-007~009 | Protocol, Content | CAR-007~008 | reason code·플레이테스트 |
| PRD-FR-025 | 결과 보정 금지 | UC-006~009 | Simulation | 내부 | QA-INV-003 |
| PRD-FR-030 | 야구혼 정보·선택 | UC-013, UC-003 | Meta | META-002 | 메타 노드 테스트 |
| PRD-FR-031 | 능력 보너스 상한 | UC-003 | Meta, Development | CRT-001 | QA-INV-006 |
| PRD-FR-032 | 기억 최대 3장 | UC-003, UC-013 | Meta | CRT-002, META-003 | 속성 기반 슬롯 테스트 |
| PRD-FR-033 | 각성 3개 | UC-010 | Meta, Content | 각성 선택 | 횟수·중복 테스트 |
| PRD-FR-034 | 삶별 지명 목표 | UC-012~013 | Career, Meta, BalanceLab | 드래프트 | 100k 런 통계 테스트 |
| PRD-FR-035 | 업보 | UC-003, UC-013 | Meta | CRT-002 | 배율·제약 테스트 |
| PRD-FR-040 | 구매 전 지명 정보 | UC-012, UC-014 | Career, Commerce | CAR-009~010 | 잠금 UI E2E |
| PRD-FR-041 | 계약 시 영구 해금 | UC-014 | Commerce, Career | SYS-003 | 구매 매트릭스 |
| PRD-FR-042 | 저장 유지·후속 계속 | UC-014~015 | Persistence, Commerce | 계약 화면 | 취소·복원 E2E |
| PRD-FR-043 | 구매 비능력 원칙 | UC-014 | Commerce, Simulation | 내부 | QA-INV-008 |
| PRD-FR-050 | 자동 저장 | 전 Use Case | Persistence | 전역 상태 | 강제 종료 테스트 |
| PRD-FR-051 | 일관 복구 | UC-018 | Persistence | SYS-004 | 손상·revision 테스트 |
| PRD-FR-052 | 접근성 | 전 Use Case | UI Adapters | 전 화면 | 키보드·VoiceOver·확대 |
| PRD-FR-053 | 기본 모드 | UC-001 | Content, Persistence | APP-004 | 팩 로드·충돌 테스트 |
| PRD-FR-054 | 선언형 모드 | UC-001 | ContentCompiler | APP-004 | 임의 코드 차단·경로 테스트 |

## 2. 비기능 추적

| Requirement | 기술 구현 | 테스트·게이트 |
|---|---|---|
| PRD-NFR-001 결정론 | 목적별 PRNG, 고정소수점, 명령·이벤트 | 골든 해시, 플랫폼 fixture |
| PRD-NFR-002 반응성 | sidecar 비동기, 스냅숏, UI 구독 범위 | P95 성능 테스트 |
| PRD-NFR-003 진행 속도 | 추천 기본값, 자동 진행, 짧은 피드백 | 공당 시간·세션 길이 KPI |
| PRD-NFR-004 저장 신뢰성 | 원자 저장, checksum, 백업 | 손상·강제 종료·마이그레이션 |
| PRD-NFR-005 오프라인 | 로컬 코어·저장, 권한 캐시 | 네트워크 단절 E2E |
| PRD-NFR-006 지역화 | 안정 키, 콘텐츠 컴파일러 | 누락 키·치환 테스트 |
| PRD-NFR-007 개인정보 | 계정 없음, opt-in 분석 | 데이터 스캔·내보내기 검토 |
| PRD-NFR-008 플랫폼 중립 | portable save, Swift 코어 | Windows↔iOS fixture |

## 3. 릴리스 추적 체크리스트

### Pitcher Lab

- PRD-FR-001~005.
- PRD-FR-020~025.
- PRD-FR-030~033의 축소 버전.
- PRD-FR-050~052.
- PRD-NFR-001~004.

### 무료 고교 1.0

- 모든 생성·고교·드래프트·메타 요구사항.
- 구매 안내와 저장 유지.
- 초기 모드와 접근성.

### 프로 데뷔

- PRD-FR-040~044.
- 계약·2군·1군 주요 Use Case.

### 전체 프로

- 역할·트레이드·FA·부상·은퇴의 GDD 규칙과 Use Case 확장.

## 4. 테스트 케이스 명명

- `TC-UNIT-####`: 단위.
- `TC-PROP-####`: 속성 기반.
- `TC-DET-####`: 결정론.
- `TC-SIM-####`: 대량 시뮬레이션.
- `TC-E2E-####`: 사용자 경로.
- `TC-A11Y-####`: 접근성.
- `TC-SAVE-####`: 저장·마이그레이션.
- `TC-IAP-####`: 구매.

각 구현 PR은 연결된 Requirement와 최소 한 개의 Test Case를 명시해야 한다.
