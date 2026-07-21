# 기술 요구사항 문서(TRD)

| 항목 | 값 |
|---|---|
| 문서 ID | DOC-03 |
| 버전 | 1.0 Baseline |
| 아키텍처 방향 | Swift 공유 코어 + 플랫폼별 네이티브/웹 UI |
| 1차 플랫폼 | Windows |
| 2차 플랫폼 | iOS·iPadOS |

## 1. 기술 목표

- Windows와 iOS에서 동일한 경기·성장·커리어 결과를 생성한다.
- 게임 규칙을 UI, 스토어, 파일 시스템과 분리한다.
- 같은 시드와 명령 순서에서 재현 가능한 결정론을 보장한다.
- 한 명의 개발자가 작은 프로토타입부터 전체 커리어까지 모듈 단위로 확장할 수 있게 한다.
- 저장 손상과 콘텐츠 변경에 강한 버전형 구조를 사용한다.
- 데이터·콘텐츠·밸런스 검증을 자동화한다.

![기술 아키텍처](../assets/architecture.png){width=6.2in}

## 2. 기술 스택 기준선

### 2.1 공유 코어

- 언어: Swift의 프로젝트 고정 안정 버전.
- 빌드: Swift Package Manager.
- 원칙: Foundation과 표준 라이브러리 위주, 플랫폼 프레임워크 의존 금지.
- 코어 대상: Windows x86_64 우선, 향후 ARM64와 Apple 플랫폼.
- 테스트: Swift Testing 또는 XCTest 호환 계층, 명령행에서 전체 수행.

Swift는 공식 Windows 도구 체인과 Swift Package Manager를 제공한다. 프로젝트는 개발 시작 시 검증된 안정 버전을 CI에 고정하고, 업그레이드는 ADR과 결정론 회귀 테스트를 통과한 뒤 진행한다.

### 2.2 Windows UI

- React + TypeScript.
- Tauri 2 데스크톱 셸.
- Swift 코어는 외부 바이너리(sidecar)로 패키징.
- 통신은 표준 입출력 기반 newline-delimited JSON-RPC.
- 긴 작업은 request ID와 progress event를 사용한다.
- 배포는 Windows용 NSIS 또는 MSI를 평가하되, 초기 베타는 NSIS 우선.

Tauri의 외부 바이너리 권한은 명시적 allow-list로 제한한다. UI가 임의 명령을 실행하지 못하고 등록된 코어 호스트만 호출하도록 한다.

### 2.3 iOS·iPadOS UI

- SwiftUI.
- iPhone: NavigationStack + 탭 중심.
- iPad: NavigationSplitView 기반 다중 열.
- 중요 경기 2D: SwiftUI Canvas 우선, 복잡한 애니메이션이 필요할 때 SpriteKit 어댑터.
- 구매: StoreKit의 현대 Swift API와 비소모성 상품.
- 코어: Swift Package를 앱에 직접 링크.

### 2.4 콘텐츠·도구

- 이벤트·구단·학교·문장: YAML 또는 JSON 원본.
- 런타임 로딩 전 콘텐츠 컴파일러가 정규화된 JSON 팩으로 변환.
- 빌드 도구: ContentCompiler, BalanceLab, SaveMigrator, EventPreviewer.
- 로컬라이제이션: 안정된 문자열 키와 언어별 완성 문장.

## 3. 모듈 구조

```text
Packages/
  BaseballDomain/          순수 엔터티·값 객체·규칙
  BaseballSimulation/      투구·타석·타구·경기 엔진
  BaseballDevelopment/     훈련·성장·피로·부상·노쇠화
  BaseballCareer/          학교·드래프트·프로·계약·은퇴
  BaseballMeta/            야구혼·기억·각성·업보
  BaseballContent/         콘텐츠 팩 모델·조건·효과
  BaseballProtocol/        명령·이벤트·스냅숏·오류
  BaseballPersistence/     저장 아카이브·마이그레이션
  BaseballAnalytics/       로컬 이벤트·밸런스 집계
Hosts/
  WindowsCoreHost/         JSON-RPC sidecar
Apps/
  WindowsDesktop/          React/Tauri
  iOS/                     SwiftUI
Tools/
  BalanceLab/
  ContentCompiler/
  EventPreviewer/
  SaveMigrator/
```

### 의존성 규칙

- Domain은 다른 프로젝트 모듈을 의존하지 않는다.
- Simulation·Development·Career·Meta는 Domain을 의존할 수 있다.
- Protocol은 공개 DTO를 정의하되 UI 타입을 포함하지 않는다.
- Persistence와 플랫폼 어댑터가 도메인 로직을 결정하지 않는다.
- UI는 도메인 엔터티를 직접 수정하지 않고 명령을 보낸다.

## 4. 명령·이벤트 아키텍처

![명령·이벤트 흐름](../assets/command_event.png){width=6.2in}

### 4.1 처리 규칙

1. UI는 `GameCommand`와 `expectedRevision`을 제출한다.
2. 코어는 현재 상태, 권한, 비즈니스 규칙을 검증한다.
3. 결정론 RNG를 사용해 필요한 계획과 결과를 생성한다.
4. 한 개 이상의 `DomainEvent`를 반환한다.
5. Reducer가 이벤트를 적용해 새 `GameState`를 만든다.
6. UI용 `ViewSnapshot`과 짧은 피드백을 생성한다.
7. 커밋 가능한 경계에서 원자적으로 저장한다.

### 4.2 이점

- 결과 재생과 버그 재현.
- 자동 저장과 중복 명령 방지.
- Windows·iOS 동일성 검증.
- AI 플레이테스터와 실제 UI가 같은 인터페이스 사용.
- 밸런스 실험의 대량 시뮬레이션.

## 5. 결정론과 수치

### 5.1 요구사항

- **TECH-001** 모든 확률 분기는 고정된 PRNG 스트림에서만 난수를 얻는다.
- **TECH-002** UI 애니메이션, 문장 변형, 오디오가 경기 결과 RNG를 소비하면 안 된다.
- **TECH-003** 플랫폼 간 부동소수점 오차가 분기를 바꾸지 않도록 핵심 판정은 정수 또는 고정소수점으로 처리한다.
- **TECH-004** 콘텐츠 순서 변경이 기존 저장의 RNG 결과를 무작위로 바꾸지 않도록 안정 ID를 사용한다.

### 5.2 RNG 설계

- root seed에서 목적별 스트림을 파생한다.
- 스트림 예: world, latentTalent, development, game, injury, relationship, narrative, cosmetic.
- 파생에는 안정된 해시와 엔터티 ID를 사용한다.
- PRNG 후보: SplitMix64로 시드 파생, xoshiro256 계열로 스트림 생성.
- 난수 요청은 의미 있는 태그와 함께 디버그 로그에 기록할 수 있다.

### 5.3 고정소수점 예

- 기술 능력: 내부 0~10,000, 표시 20~80.
- 위치: 플레이트 좌표 1/10,000 단위 정수.
- 구속: 0.1km/h.
- 움직임: 0.1cm.
- 확률: UInt32 전체 범위.
- 피로·자신감: 0~10,000.

## 6. 투구 엔진 파이프라인

### 6.1 보안적 순서

`BatterPlanCommitted`는 `SubmitPitchCall`보다 먼저 생성돼야 한다. 포수 추천기와 타자 AI는 플레이어가 제출할 투구를 읽을 수 없다.

### 6.2 단계

1. 경기 컨텍스트 구성.
2. 타자 계획 커밋.
3. 포수 주·대안 추천 생성.
4. 사용자 투구 콜 제출.
5. 목표 좌표와 실제 실행 분포 계산.
6. ABS 판정 또는 타자 반응.
7. 접촉 시 타구 속도·발사각·방향 계산.
8. 수비 결과와 주자 상태 계산.
9. 피로, 자신감, 패턴 메모리 갱신.
10. 인과 피드백과 분석 이벤트 생성.

### 6.3 자동 검증 불변조건

- 포수 추천 입력에 숨은 타자 계획이 포함되지 않는다.
- 타자 계획 생성 함수에 사용자 투구 콜 인자가 없다.
- 중요도는 연출과 진입 여부에만 영향을 주고 결과 분포를 수정하지 않는다.
- 같은 `PitchContext`와 같은 시드·명령은 같은 `PitchResolved`를 만든다.
- 선택 품질과 실행 품질은 최종 결과와 독립적으로 계산 가능하다.

## 7. 저장 포맷

### 7.1 Portable Save Archive

확장자 예: `.dscareer`.

```text
manifest.json
world.snapshot.json
career.snapshot.json
meta.snapshot.json
rng.json
events.ndjson
content-lock.json
checksums.json
optional/thumbnail.png
```

초기에는 사람이 검사 가능한 JSON과 ZIP 컨테이너를 사용한다. 용량이나 성능이 실제 문제로 확인되기 전에는 플랫폼별 DB를 저장의 원본으로 사용하지 않는다. 최근 저장 목록과 검색 인덱스는 별도 로컬 캐시를 사용할 수 있다.

### 7.2 저장 경계

- 주간 또는 챕터 계획 확정.
- 중요 선택 직후.
- 타석·이닝·경기 종료.
- 드래프트, 계약, 트레이드, FA.
- 구매 권한에 따른 프로 계약 진입.
- 앱 백그라운드·종료 요청.

### 7.3 원자성

1. 새 아카이브를 임시 경로에 기록.
2. 각 파일 체크섬 검증.
3. 이전 정상 저장을 백업 슬롯으로 유지.
4. rename 또는 플랫폼 원자 교체.
5. 실패 시 이전 정상 저장을 보존.

### 7.4 마이그레이션

- `schemaVersion`, `contentVersion`, `engineVersion`을 분리한다.
- 한 버전씩 순차 마이그레이션한다.
- 마이그레이션 전 자동 백업.
- 기존 이벤트 ID 삭제 금지. 폐기 상태로 유지한다.
- 호환 불가능한 모드는 명확한 오류와 안전한 복사본을 제공한다.

## 8. Windows IPC

### 8.1 프로토콜

- UTF-8 NDJSON.
- 각 요청: `jsonrpc`, `id`, `method`, `params`, `protocolVersion`.
- 각 응답: result 또는 typed error.
- 비동기 이벤트: progress, autosaveCompleted, entitlementChanged, fatalError.
- 한 줄 최대 크기와 전체 메시지 제한을 둔다.

### 8.2 메서드 예

- `session.create`
- `session.load`
- `session.submitCommand`
- `session.getSnapshot`
- `session.exportDebugBundle`
- `content.validate`
- `simulation.runBatch`

### 8.3 안전

- Tauri capability에서 코어 sidecar만 실행 허용.
- 셸 문자열을 조합하지 않고 구조화된 인자를 사용.
- 모드 파일은 sandbox 폴더에서 읽고 경로 traversal을 거부.
- UI의 저장 요청은 사용자 선택 경로를 플랫폼 어댑터가 검증한다.

## 9. 구매 권한

### 9.1 도메인 인터페이스

```swift
protocol EntitlementProvider: Sendable {
    func currentEntitlements() async throws -> Set<Entitlement>
    func purchase(_ product: ProductID) async throws -> PurchaseResult
    func restore() async throws -> Set<Entitlement>
}
```

코어는 StoreKit이나 Windows 스토어 타입을 알지 않는다. `SignProfessionalContract` 명령은 `proCareerAccess` 권한이 없으면 상태를 변경하지 않고 typed lock 응답을 반환한다.

### 9.2 iOS

- 비소모성 상품 한 개.
- 앱 시작·포그라운드·구매 완료 때 현재 entitlement를 갱신.
- 구매 복원 UI 제공.
- Xcode StoreKit 구성, Sandbox, 실제 테스트 계정의 세 단계로 검증.

### 9.3 Windows

- 무료 베이스 앱 + 프로 커리어 DLC 또는 영구 라이선스.
- 특정 스토어 API에 직접 결합하지 않고 어댑터를 사용.
- 오프라인 사용을 위한 서명된 로컬 entitlement 캐시와 재검증 정책은 배포 채널 확정 후 ADR로 고정한다.

## 10. 콘텐츠 엔진

### 10.1 이벤트 구성

- 안정 ID, 버전, 단계, 태그.
- 발동 조건.
- 인물 캐스팅 규칙.
- 언어별 문장 키.
- 선택지와 도메인 효과.
- 재발동 제한, 독점 그룹, 우선순위.

### 10.2 컴파일 검증

- 존재하지 않는 스탯·태그·이벤트 참조.
- 누락된 지역화 키와 변수.
- 도달 불가능하거나 항상 참인 조건.
- 무한 이벤트 연쇄.
- 합계가 예산을 넘는 효과.
- 저장과 호환되지 않는 ID 변경.
- 실제 상표·실명 금칙어 검사.

## 11. 성능 예산

### 코어

- 중요 투구 1회 해석: 일반 기기에서 즉시 완료되는 수준을 목표로 하며 성능 테스트 기준은 50ms 이하 P95로 시작한다.
- 한 주 자동 진행: 500ms 이하 P95 목표.
- 한 시즌 백그라운드 압축 진행: UI가 중단되지 않도록 비동기 처리와 진행률 제공.
- 10개 구단 리그 장기 시뮬레이션은 플레이어 주변 상세도에 따라 계층화한다.

### UI

- 화면 전환 100ms 이내 입력 반응.
- 긴 표는 가상화.
- 차트와 2D 경기 화면은 표시 스냅숏만 구독하여 불필요한 전체 재렌더링을 막는다.
- iOS에서는 Dynamic Type 최대 크기와 작은 화면에서 핵심 행동이 가려지지 않아야 한다.

## 12. 로깅과 진단

- 구조화 로그: timestamp, sessionID, revision, commandID, eventID, seed fragment.
- 일반 빌드에는 개인 식별자를 기록하지 않는다.
- 디버그 번들: 저장 복사본, 최근 명령·이벤트, 콘텐츠 버전, 시스템 정보, 로그.
- 숨은 스탯은 사용자 동의 없이 외부 전송하지 않는다.
- 플레이테스트 빌드는 로컬 CSV/JSON 내보내기를 우선한다.

## 13. 테스트 전략 요약

- 단위: 값 객체, 조건, 효과, 계약 규칙.
- 속성 기반: 능력 범위, 확률 보존, 상태 불변조건.
- 결정론 골든 파일: 동일 명령의 이벤트 해시.
- 대량 시뮬레이션: 구종·프리셋·드래프트 분포.
- 저장: 강제 종료, 손상, 버전 마이그레이션.
- IPC: 프로토콜 버전, 큰 메시지, sidecar 종료.
- UI: 키보드, Dynamic Type, 화면 읽기, 구매 잠금.
- StoreKit: 성공, 취소, 보류, 복원, 미확인 거래.

## 14. CI/CD

- 모든 PR에서 Swift 패키지 빌드·테스트.
- Windows에서 sidecar와 Tauri 빌드.
- 콘텐츠 컴파일·금칙어·지역화 검증.
- 결정론 골든 테스트.
- 저장 마이그레이션 회귀.
- 서명 없는 내부 설치 패키지 생성.
- 릴리스 태그에서 서명·공증·스토어 패키징.

## 15. 기술 리스크와 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| Swift Windows 서드파티 생태계 제약 | 빌드·배포 지연 | 코어 의존성 최소화, 초기 spike, 표준 Foundation 우선 |
| Tauri↔Swift IPC 복잡도 | 디버깅 비용 | 프로토콜을 작게 유지, 골든 테스트, request revision |
| 수치 경우의 수 폭발 | 밸런스 불가능 | 3층 메타 제한, 대량 시뮬레이션, dominance 검사 |
| 저장 포맷 성장 | 로딩·마이그레이션 문제 | 이벤트 tail 제한, 정기 스냅숏, 버전 도구 |
| 콘텐츠 문장 직접 집필 부담 | 콘텐츠 부족 | 핵심 사건 우선, 변수 템플릿, 재사용 가능한 구조 |
| 플랫폼 UI 이중 개발 | 개발량 증가 | 코어·프로토콜·디자인 토큰 공유, iOS는 Windows 검증 후 |

## 16. 기술 참고 기준

2026년 7월 기준 공식 문서를 참고한 기술 선택이다.

- Swift.org Windows 설치·플랫폼 지원: `https://www.swift.org/install/windows/`, `https://www.swift.org/platform-support/`
- Tauri 외부 바이너리와 Windows 배포: `https://v2.tauri.app/develop/sidecar/`, `https://v2.tauri.app/distribute/windows-installer/`
- Apple SwiftUI·NavigationStack·Canvas: `https://developer.apple.com/swiftui/`, `https://developer.apple.com/documentation/swiftui/navigationstack`
- Apple StoreKit 비소모성 구매와 entitlement: `https://developer.apple.com/documentation/storekit/`, `https://developer.apple.com/documentation/storekit/transaction/currententitlements`
