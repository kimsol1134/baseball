# iOS 관계 국면 암전 회귀 검사

## 회귀 원인과 계약

`f74bff6` 이전의 `PhaseCurtain` 수식어는 국면이 바뀌을 때
`BaseballTheme.canvas`를 화면 전체에 불투명하게 올렸다. 연속 선택이 지연된
종료 애니메이션을 취소하면 커튼이 남아 하단 탭 외의 화면이 검게 보였다.

고교 커리어 국면은 전면 불투명 커튼 없이 즉시 교체한다. 국면 흐름에
`.phaseCurtain` 또는 `PhaseCurtain` 구현을 다시 추가하지 않는다.

## 자동 검사

`CareerSmokeUITests.testRapidRelationshipChoicesNeverLeaveOpaqueBlankFrame`는 초기화된 커리어를
실제 UI로 진행하고, 관계 선택을 두 번 반복한다. 각 선택 직후 30ms 간격의
연속 스크린샷 네 장을 검사한다. 버튼 존재나 탭 가능 여부는 판정 근거로 쓰지
않는다.

픽셀 기준은 다음과 같다.

- 상태 바와 하단 탭을 제외한 중앙 영역: `x 8–92%`, `y 10–78%`
- 성능을 위해 짧은 변을 기준으로 약 120개 격자로 표본화
- RGB 최댓값이 `40/255`를 넘는 표본이 `0.5%` 미만이면 암전 프레임으로 판정

정상 화면의 글자, 카드 테두리, 액션 색은 임계치를 넘는다. 회귀 커튼의
`#080D0B`는 최댓값이 `13/255`이므로 중앙을 완전히 덮으면 빠짐없이 실패한다.

`PresentationTests.testCareerPhaseFlowDoesNotInstallOpaquePhaseCurtain`는 원인 구현의
재도입을 소스 단계에서 막는 보조 안전망이다.

## 실행

```sh
xcodebuild test \
  -project apps/ios/Baseball.xcodeproj \
  -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:BaseballIOSUITests/CareerSmokeUITests/testRapidRelationshipChoicesNeverLeaveOpaqueBlankFrame
```

실행 중인 시뮬레이터가 없으면 자동으로 부팅하지 않고, generic iOS Simulator
대상으로 빌드해 컴파일을 먼저 검증한다.
