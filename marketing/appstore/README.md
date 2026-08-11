# App Store 제출 자산

유료앱(paid up-front) 배포용 자산 사양과 생성 방법. 계획 문서는 `docs/IOS_PAID_APP_PLAN.md`.

## 1. 최신 ASC 세트

2026-08-11 현재 앱 화면과 환생 루프를 반영한 제출본은 `asc-2026-08-rebirth/`에 있다.

- 영상: 886×1920, 30fps, 27.6초
- 6.7형: 1320×2868, 7장
- 6.5형: 1284×2778, 7장
- 생성: `cd apps/promo && npm run render:asc`

첫 세 장은 `직접 투구 → 미지명 → 환생`, 이후 네 장은 `대표 유산 → 타자 적응 → 다음 선수 → 지명 성공` 순서다. 세부 파일과 추천 포스터 타임코드는 `asc-2026-08-rebirth/README.md`를 따른다.

## 2. 스크린샷 캡처 원칙

무료 체험이 없으므로 **스크린샷이 유일한 데모**다. 아래 순서를 지킨다. 순서 자체가 게임의
주장이다 — "이건 텍스트 관리 게임이 아니라 한 구씩 던지는 야구 게임이다".

| 순번 | 화면 | 전달할 약속 |
|---|---|---|
| 1 | 투구 결과 | 마지막 한 구를 직접 던진다 |
| 2 | 드래프트 미지명 | 못하면 이름은 불리지 않는다 |
| 3 | 환생 스탬프 | 그래도 끝이 아니다 |
| 4 | 대표 유산 선택 | 전 생의 한 가지를 남긴다 |
| 5 | 투구 결정 | 타자도 투수의 공을 읽는다 |
| 6 | 두 번째 선수 | 실패가 다음 생의 시작 능력이 된다 |
| 7 | 드래프트 지명 | 이번 생에는 이름이 불릴 수 있다 |

### 필수 크기

| 기기 | 해상도(px) | 시뮬레이터 |
|---|---|---|
| 6.7" 아이폰 | 1320 × 2868 | 현재 ASC 6.7형 슬롯 |
| 6.5" 아이폰 (선택) | 1284 × 2778 | 기존 ASC 6.5형 슬롯 |
| 아이패드 | 이번 릴리스 제외 | `TARGETED_DEVICE_FAMILY: "1"` (iPhone 전용) |

이번 릴리스는 `TARGETED_DEVICE_FAMILY: "1"`인 **iPhone 전용 제출본**이다. 따라서 아이패드
스크린샷은 제출하지 않으며, iPad 레이아웃 검증은 후속 범위로 남긴다.

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

캡처는 최신 앱 UI를 보존하는 원본이고, 제출용 카피·배치·규격 파생은 Remotion 컴포지션에서 결정적으로 렌더한다.

주의: 스모크 테스트는 매번 새 커리어를 만들고 시드가 무작위라 선수·상대가 달라진다. 제출본은
고정된 `apps/promo/public/asc/` 캡처만 사용해 다시 렌더해야 재현 가능한 결과를 유지할 수 있다.

## 3. 앱 아이콘

`apps/ios/Sources/Assets.xcassets/AppIcon.appiconset`에 라이트·다크·틴티드 3종이 있다.
다크/틴티드는 `tools/`가 아니라 원본에서 파생한 것이라, 원본을 교체하면 세 장을 함께 갱신한다.

2026-08-02 사용자 제공 이미지인 **D안 골드 프레임·투구 공**을 최종 아이콘으로 반영했다.
60px에서도 금색 프레임, 공, 붉은 투구 궤적이 함께 남아 게임의 투구 정체성을 전달한다.

- 60px 확인본: `icon-options/60px/icon-d-user-submitted-60.png`
- 사용자 원본: `icon-options/icon-d-user-submitted.png`
- 기존 3안 비교 자산: `icon-options/icon-a-homeplate.png`, `icon-options/icon-b-strike-zone.png`, `icon-options/icon-c-baseball.png`
- build 40 반영본: `AppIcon.png`, `AppIcon-Dark.png`, `AppIcon-Tinted.png`

## 4. 스토어 텍스트

Steam 스토어 초안(`docs/STEAM_STORE_PAGE_DRAFT.md`)을 재사용하되 다음을 바꾼다.

- 분량: 프로모션 텍스트 170자, 설명 4,000자 제한.
- "PC/Steam" 언급 제거.
- 무료 고교 커리어 · 프로 IAP 해금 문구 제거. **앱 구매 = 전체 이용**으로 통일한다.
- 첫 3줄에 "한 구씩 직접 던지는 투수 육성"이 들어가야 한다. 접힌 설명에서 잘리는 지점이다.

## 5. 제출 전 확인

- [ ] 릴리스 구성 빌드 성공 (`-configuration Release`)
- [ ] 실기기 1대 이상에서 새 커리어 → 중요 경기 → 결과 반영 완주
- [ ] 개인정보 처리방침 URL (수집 없음이므로 정적 페이지 1장)
- [ ] 연령 등급 설문 (폭력·도박 없음)
- [ ] 수출 규정: `ITSAppUsesNonExemptEncryption: false` — project.yml에 설정됨
- [ ] `PrivacyInfo.xcprivacy` 수집 없음 상태 유지
- [x] 지원 기기 범위 확인 — iPhone 전용, iPad는 이번 릴리스에서 제외

## 6. 한국 Meta 광고

출시 직후 한국 App Store 유료 구매를 검증하기 위한 7일 계획과 소재 매니페스트는
`meta-ads/2026-08-launch/PLAN.md`와 `meta-ads/2026-08-launch/manifest.json`에 있다.
세로·정사각·가로 광고 소재도 같은 폴더에 보관한다. 현재는 광고를 집행하지 않았으며,
App Store 심사 승인 후 캠페인 링크와 Meta 결제 설정을 확인하고 시작한다.
