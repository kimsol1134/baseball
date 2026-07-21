# ADR-001: Swift 공유 시뮬레이션 코어

- 상태: 승인, P0 검증 중
- 결정일: 2026-07-21

## 맥락

Windows를 먼저 출시하지만 이후 iPhone·iPad에서 같은 야구 규칙, 저장 포맷, 이벤트 정의를 사용해야 한다. 시뮬레이션 코어는 UI 프레임워크와 분리되어야 하며 고정 시드 결과를 플랫폼 간에 재현해야 한다.

## 결정

시뮬레이션 코어를 Swift Package로 구현한다.

- 코어는 Foundation의 플랫폼별 난수나 부동소수점 난수에 의존하지 않는다.
- Windows에서는 실행 가능한 sidecar로 빌드한다.
- iOS에서는 같은 패키지를 앱에 직접 연결한다.
- Windows CI에서 Swift 빌드와 테스트를 항상 실행한다.

## 결과

- 게임 규칙과 iOS 앱 사이에 언어 경계가 없다.
- Windows 패키징에는 Swift 런타임과 sidecar 배포 검증이 필요하다.
- P0 Windows CI나 배포 Spike가 실패하면 Rust 공유 코어를 대안으로 재검토한다.

## 검증 기준

- macOS와 Windows에서 `swift test` 통과
- 같은 시드·명령의 이벤트 해시 일치
- Tauri 앱에 target triple별 sidecar 포함
- 비정상 종료와 배포용 Swift 런타임 포함 방식은 P0 후반에 추가 검증

