# ADR-014: iOS 네이티브 단방향 커리어 흐름

- 상태: 채택
- 날짜: 2026-07-22

## 결정

- iOS 17을 최소 버전으로 하고 Windows UI를 재사용하지 않는다.
- `오늘의 상태 → 이번 주 선택 → 중요 장면 → 결과`를 탭과 `NavigationStack`으로 구성한다.
- iPad regular width는 `NavigationSplitView`로 선수 요약과 결정을 비교한다.
- 루트 `@Observable` 저장소가 공유 `SimulationCore`를 직접 호출하고 백그라운드 전환마다 원자 저장한다.
- 시스템 Dynamic Type, VoiceOver 결합 레이블과 최소 44pt 조작 영역을 사용한다.

## 결과

PC와 규칙·결정론·Codable 저장 모델은 공유하면서 화면 구조와 상호작용은 모바일에 맞게 독립적으로 진화할 수 있다.
