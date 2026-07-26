# App Store 제출 자산

유료앱(paid up-front) 배포용 자산 사양과 생성 방법. 계획 문서는 `docs/IOS_PAID_APP_PLAN.md`.

## 1. 스크린샷

무료 체험이 없으므로 **스크린샷이 유일한 데모**다. 아래 순서를 지킨다. 순서 자체가 게임의
주장이다 — "이건 텍스트 관리 게임이 아니라 한 구씩 던지는 야구 게임이다".

| 순번 | 화면 | 잡아야 할 것 |
|---|---|---|
| 1 | 승부(투구 결정) | 3×3 존 그리드, 포수 사인, 카운트. **가장 먼저 보여야 한다** |
| 2 | 투구 결과 + 궤적 | 궤적 곡선과 존 판정, 결과 문구 |
| 3 | 오늘의 상태 | 구장 키아트, 시즌 아크, 올해의 세 가지 승부처 |
| 4 | 커리어 시작 | 투수 유형 3종과 능력 게이지 |
| 5 | 기록 | 시즌·통산·수상 |

### 필수 크기

| 기기 | 해상도(px) | 시뮬레이터 |
|---|---|---|
| 6.9" 아이폰 | 1320 × 2868 또는 1290 × 2796 | iPhone 16 Pro Max / 17 Pro Max |
| 6.5" 아이폰 (선택) | 1242 × 2688 | iPhone 11 Pro Max |
| 13" 아이패드 | 2064 × 2752 | iPad Pro 13-inch (M4) |

`TARGETED_DEVICE_FAMILY: "1,2"`이므로 **아이패드 스크린샷이 필수**다.

### 생성

UI 스모크 테스트가 위 화면들을 순서대로 지나가며 스크린샷을 첨부한다. 필요한 기기에서 돌린 뒤
결과 번들에서 뽑아낸다.

```bash
cd apps/ios
xcodebuild -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:BaseballIOSUITests \
  -resultBundlePath /tmp/shots.xcresult test CODE_SIGNING_ALLOWED=NO
xcrun xcresulttool export attachments --path /tmp/shots.xcresult --output-path ./out
```

첨부 이름은 `01-career-setup` … `08-after-game`이다. 제출용 5장은 위 표 순서로 다시 고른다.

주의: 스모크 테스트는 매번 새 커리어를 만들고 시드가 무작위라 구단·상대가 달라진다. 제출본은
마음에 드는 실행을 골라 쓰고, 같은 실행에서 나온 5장으로 맞춘다.

## 2. 앱 아이콘

`apps/ios/Sources/Assets.xcassets/AppIcon.appiconset`에 라이트·다크·틴티드 3종이 있다.
다크/틴티드는 `tools/`가 아니라 원본에서 파생한 것이라, 원본을 교체하면 세 장을 함께 갱신한다.

**남은 문제**: 현재 아이콘은 야간 구장 사진이라 60pt 홈 화면 크기에서 디테일이 뭉갠다.
단일 실루엣(홈플레이트 또는 공) 중심으로 다시 그리는 것이 좋다. 이번 범위 밖.

## 3. 스토어 텍스트

Steam 스토어 초안(`docs/STEAM_STORE_PAGE_DRAFT.md`)을 재사용하되 다음을 바꾼다.

- 분량: 프로모션 텍스트 170자, 설명 4,000자 제한.
- "PC/Steam" 언급 제거.
- 무료 고교 커리어 · 프로 IAP 해금 문구 제거. **앱 구매 = 전체 이용**으로 통일한다.
- 첫 3줄에 "한 구씩 직접 던지는 투수 육성"이 들어가야 한다. 접힌 설명에서 잘리는 지점이다.

## 4. 제출 전 확인

- [ ] 릴리스 구성 빌드 성공 (`-configuration Release`)
- [ ] 실기기 1대 이상에서 새 커리어 → 중요 경기 → 결과 반영 완주
- [ ] 개인정보 처리방침 URL (수집 없음이므로 정적 페이지 1장)
- [ ] 연령 등급 설문 (폭력·도박 없음)
- [ ] 수출 규정: `ITSAppUsesNonExemptEncryption: false` — project.yml에 설정됨
- [ ] `PrivacyInfo.xcprivacy` 수집 없음 상태 유지
- [ ] 아이패드 레이아웃 확인 (커리어 탭 분할 뷰)
