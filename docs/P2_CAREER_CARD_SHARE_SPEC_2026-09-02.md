# P2-1 커리어 카드 공유 스펙

작성: PM, 2026-09-02. 구현: grok (main 트리). 목적: 은퇴·드래프트·신기록·국가대표 순간을 이미지 카드로 공유해 커뮤니티 자연 확산을 만든다. 리뷰어 다수가 커뮤니티 유저이며, 공유물이 곧 광고다.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. `git add`는 절대 `-A`로 하지 말 것(어차피 커밋 금지).
2. 코어 규칙·시뮬레이션 무변경(순수 프레젠테이션 기능). 골든 픽스처 무변경.
3. ko/en/ja 필수, `npm run check:ios-localization`·`check:copy`·`check:design-system` 통과. 실존 구단·선수명 금지. 카드에 앱 이름과 App Store 배지 텍스트는 넣되 URL은 공유 텍스트에만.
4. 뷰는 스토어 프로젝션만(LayerBoundaryTests). iOS 테스트는 한 번에 하나, 부팅된 iPhone 17. 테스트 삭제·약화 금지.
5. **다른 엔지니어가 워크트리에서 시드 도전 링크(URL 스킴·유니버설 링크·`BaseballApp.swift` onOpenURL·`HighSchoolSetupView` 시드 입력)를 만들고 있다.** 이 작업은 `BaseballApp.swift`, `HighSchoolSetupView*.swift`, `project.yml`의 URL/entitlement 설정, `apps/landing`을 건드리지 않는다. 공유 텍스트에 넣을 도전 코드는 기존 각인 형식 `"<seed>-<life>"` 문자열만 쓴다.

## 1. 기존 자산
- `apps/ios/Sources/Platform/ShareSheet.swift`, `LifeCardView.swift:476`·`LifeArchiveView.swift:772`의 `ImageRenderer` 카드 굽기(고교 인생 카드). 이 렌더 파이프라인을 재사용한다.
- 시드-회차 각인(`parsedChallenge`, "시드-회차")이 이미 카드에 찍힌다.
- 프로: `ProRetirementViews.swift`(은퇴 훈장 카드), `RecordView.swift`(목표판·기록), `ProNationalTeamViews.swift`(결과 카드), 고교 드래프트 결론(`DraftConclusion*`), 목표판 `ProCareerGoalBoardRules`.

## 2. 기능
`CareerShareCard` 공용 렌더러(`apps/ios/Sources/Presentation/CareerShareCard.swift`): 1080×1350(4:5) 세로 카드, 디자인 시스템 토큰, 상단 앱 이름·투수 초상(기존 AvatarFace)·이름·투구 손, 중앙 본문, 하단 "시드 <seed>-<life> · 같은 시드로 도전" 각인 + 앱 이름. 문구 밀도 무관, 항상 풀 카드. 다크 배경 고정(공유물은 테마 무관).

카드 4종(본문 구성):
1. **은퇴 카드**: 통산 승·ERA·탈삼진·WHIP, 시즌 수, 훈장(영구결번·명예의 전당·국가대표 금), 팀 레거시 티어. 진입: 은퇴 화면 "카드 공유" 버튼.
2. **드래프트 카드**: 지명 라운드·순번·구단(가상), 고교 3년 요약(승·ERA·K), 등급. 진입: 드래프트 결론 화면.
3. **신기록 카드**: 통산 마일스톤 도달 순간(경기·탈삼진 임계값)과 시즌 결정 후속 결과 중 QS 카드. 진입: 주간 화면의 마일스톤/후속 결과 카드에 공유 아이콘.
4. **국가대표 카드**: 메달·면제 여부·결승 라인. 진입: 국가대표 결과 화면.

공유 텍스트(ko/en/ja): 한 줄 요약 + "도전 코드 <seed>-<life>" + App Store 링크 `https://apps.apple.com/app/id6794754217`. 이미지와 텍스트를 함께 `ShareSheet`로.

- 카드 생성은 메인 액터, 렌더 실패 시 텍스트만 공유(에러 무음 금지: 토스트 문구).
- 텔레메트리: `career_card_shared`(kind, season, has_medal 등 밴드), `CareerTelemetry.log`.
- 접근성 ID `share.card.<kind>`. VoiceOver 라벨 "카드 공유".
- 카드 미리보기 시트(공유 전 확인) 1장, "공유" 버튼.

## 3. 수용 기준
1. 4종 카드가 각각 렌더되어 PNG 데이터가 비어 있지 않다(유닛 테스트: `ImageRenderer` 결과 크기 1080×1350 ±0, 메인 액터).
2. 공유 텍스트가 3언어로 존재하고 도전 코드·스토어 링크를 포함한다(테스트).
3. UI 테스트 `Release128JourneyUITests`에 은퇴 카드 미리보기 열기 단계 추가(가능한 경로에서), 스크린샷 `apps/ios/releases/qa-1.2.9/share/`에 저장(200MB 이하).
4. 게이트: iOS `BaseballIOSTests` 전체, `npm run check:ios-localization`, `check:copy`, `check:design-system` 종료 코드 0. 코어 테스트는 변경이 없어야 하므로 `swift test --filter "ProCareerBootstrapCharacterization"`만.

## 4. 산출물
`docs/P2_CAREER_CARD_SHARE_REPORT_2026-09-02.md`: 카드 4종 레이아웃 설명, 진입점, 스크린샷 경로, 게이트 원문, 미해결.
