# ADR-015: iOS localized presentation boundary

- 상태: 채택
- 날짜: 2026-08-12

## 결정

- iOS 표시 언어는 `AppLanguage`의 `ko`/`en` 두 값으로만 정규화한다. `en-*`는 영어,
  `ko-*`는 한국어이며 알 수 없는 locale은 개발 언어인 한국어로 처리한다.
- 표시 문구는 semantic `GameCopyKey`와 typed `CopyToken`으로 식별한다. 한국어 원문을
  key로 조회하거나, 문자열 변환·음가 변환·문장 조립으로 영어를 만들지 않는다.
- `Localizable.xcstrings`, `GameContent.xcstrings`, locale별 `InfoPlist.strings`를 앱 번들
  리소스로 포함한다. Swift 파일은 소스 그룹으로만 포함한다.
- 영어 key가 없을 때 Release-safe resolver는 한국어 대신 `Text unavailable`을 반환한다.
  Debug/Test resolver는 assertion을 발생시킨다.
- formatter는 기존 내부 숫자와 저장 단위를 그대로 받고 표시 단계에서만 영어 표기를 만든다.
  특히 mph와 KRW는 엔진·저장·분석으로 되돌아가지 않는다.
- Phase A에서는 기존 SwiftUI 호출부를 변경하지 않는다. 전체 호출부와 SimulationCore 문구의
  전환은 inventory의 각 항목이 의미·언어·UI 검수를 통과한 뒤 후속 단계에서 수행한다.

## 이유

언어 변경이 새 세계나 새 저장을 만들지 않도록 표시 계층을 기계 데이터에서 분리해야 한다.
완성된 한국어 문자열을 영어로 덮어쓰면 저장·알림·공유·접근성에 혼합 언어와 호환성 문제가
생기므로, Phase A에서 의미 ID·타입·검사 경계를 먼저 고정한다.

## 호환성 영향

- 저장 키, RNG, 콘텐츠 순서, 선택 효과, 분석 event name, 기존 한국어 API는 변경하지 않는다.
- 기존 한국어 화면은 호출부를 건드리지 않았으므로 문구와 동작 회귀가 없다.
- 현재 source inventory의 미전환 surface는 의도적으로 pending으로 남으며 release check를
  통과하지 못한다.

## Phase A 결정 기록

### 2026-08-12 / P1–P2 / semantic catalog spike와 exhaustive inventory

- 변경 파일: `apps/ios/Sources/Localization/*`, `apps/ios/project.yml`,
  `tools/inventory-ios-localization.mjs`, `tools/check-ios-localization.mjs`,
  `docs/localization/ios-copy-schema.json`, `docs/localization/IOS_ENGLISH_COPY_BIBLE.md`
- 결정: 13개 semantic catalog key만 `ui_verified` spike로 고정하고, 기존 iOS/Core Swift
  문자열은 source anchor/hash 기반 inventory 항목으로 모두 `inventory` 상태에 둔다.
- 이유: Phase A의 안전한 컴파일 기반을 먼저 검증하면서 미번역 문구가 영어 출시 준비로 오인되지
  않게 하기 위해서다.
- 콘텐츠 parity 영향: 없음. 신규 key는 기존 호출부에서 사용하지 않으며 콘텐츠 ID·배열·효과를
  변경하지 않는다.
- 저장 호환성 영향: 없음. `CopyToken`은 Codable 저장 모델에 연결하지 않는다.
- 실행한 테스트: `npm run inventory:ios-localization`, `npm run check:ios-localization -- --schema-only`,
  focused iOS unit tests, xcodegen, iOS Debug build (실행 결과는 작업 완료 보고에 기록).
- 결과: schema-only는 통과해야 하며, strict release check는 정확한 pending count와 legacy path
  count로 실패해야 한다.
- 남은 위험: 전체 UI·알림·공유·접근성·SimulationCore 문구는 후속 단계에서 semantic key로
  전환하고 영어 문장을 별도 검수해야 한다. 앱은 아직 English-ready가 아니다.
