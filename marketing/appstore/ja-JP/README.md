# App Store Connect 크리에이티브 · 일본어 전환판

일본 App Store의 유료 구매 전환을 위해 만든 Remotion 기반 크리에이티브 세트입니다.
기능을 나열하는 대신 `직접 투구 → 지명 실패 → 실패를 계승해 재도전`을 첫 세 장과
27.6초 미리보기에서 하나의 이야기로 보여 줍니다.

## 제출 파일

- 앱 미리보기: `preview/preview-ja-886x1920.mp4`
  - 886×1920, H.264 High, 30fps, 27.6초
  - 비디오 약 10 Mbps, AAC-LC 스테레오 약 256 kbps, 48 kHz
  - 추천 포스터: `preview/poster-ja.png` (0.5초)
- 6.9형 스크린샷: `screenshots-6.9/01.png`부터 `07.png`
  - 1320×2868, RGB PNG, 알파 채널 없음
- 6.5형 스크린샷: `screenshots-6.5/01.png`부터 `07.png`
  - 1284×2778, RGB PNG, 알파 채널 없음
- 검수 시트: `evidence/screenshots-contact-sheet.jpg`,
  `evidence/preview-contact-sheet.jpg`

## 전환 설계

1. 실제 스트라이크존과 구속을 크게 보여 주어 첫눈에 야구 게임임을 증명한다.
2. 지명이 보장되지 않는다는 위험을 보여 주어 3년의 선택에 무게를 만든다.
3. 실패가 다음 투수의 무기가 된다는 고유한 환생 루프를 즉시 회수한다.
4. 이후 장면은 편지·기억, 타자 적응, 유산 선택으로 루프가 실제 시스템임을 증명한다.
5. 마지막 장은 `買い切り・追加課金なし`와 전체 커리어 범위를 묶어 유료 가격 저항을 낮춘다.

## 일본어 화면 구성

일본어판은 한국어 앱 캡처를 사용하지 않습니다. 스크린샷과 영상에 보이는 상태 표시,
버튼, 결과 화면, 선수 정보까지 `JapaneseAppScreens.tsx`에서 일본어 Remotion UI로
재구성했습니다. 따라서 현재 제출 파일 안에는 한국어 UI가 노출되지 않습니다.

현재 저장소에는 일본어 앱 구현이 없으므로 이 화면들은 일본어 시뮬레이터 실캡처가 아닌
마케팅용 UI 재현본입니다. 실제 일본어 빌드가 준비되면 용어와 화면 상태가 제품 구현과
일치하는지만 최종 대조합니다.

## 재현

```bash
cd apps/promo
npm run render:asc:jp
```

- 일본어 앱 UI: `apps/promo/src/asc/JapaneseAppScreens.tsx`
- Remotion 컴포지션: `apps/promo/src/asc/StoreCreative.tsx`
- 컴포지션 등록: `apps/promo/src/Root.tsx`
- 렌더 스크립트: `apps/promo/package.json`

Apple 규격 확인:

- https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
