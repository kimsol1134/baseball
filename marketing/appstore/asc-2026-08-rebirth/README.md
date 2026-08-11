# ASC 크리에이티브 · 환생 서사판

2026-08-11 최신 iOS 시뮬레이터 빌드의 실제 UI를 사용한 한국어 App Store Connect 제출 세트입니다.

## 제출 파일

- 앱 미리보기: `preview/preview-kr-886x1920.mp4`
  - 886×1920, H.264, AAC, 30fps, 27.6초
  - 추천 포스터 타임코드: `00:00:01:00`
- 6.7형 스크린샷: `screenshots-6.7/01.png`부터 `07.png`
  - 1320×2868
- 6.5형 스크린샷: `screenshots-6.5/01.png`부터 `07.png`
  - 1284×2778

## 갤러리 순서

1. 마지막 한 구를 직접 던진다
2. 못하면 이름은 불리지 않는다
3. 그래도 끝이 아니다 — 또, 환생함
4. 전 생의 한 가지를 이번 생에 남긴다
5. 타자도 당신의 공을 읽는다
6. 전 생의 실패가 이번 생의 시작이 된다
7. 이번 생엔 이름이 불릴까

첫 세 장은 `직접 투구 → 미지명 → 환생`을 하나의 연속 광고로 읽히게 설계했습니다. 이후 네 장은 대표 유산, 타자 적응, 다음 선수, 지명 성공으로 그 약속이 실제 게임 시스템임을 증명합니다.

## 소스와 재현

- Remotion 컴포지션: `apps/promo/src/asc/StoreCreative.tsx`
- 실제 앱 캡처: `apps/promo/public/asc/`
- 전체 렌더: `cd apps/promo && npm run render:asc`
- 영상만: `npm run render:asc-preview`
- 6.7형만: `npm run render:asc-screenshots:67`
- 6.5형만: `npm run render:asc-screenshots:65`

화면 카피와 레이아웃은 Remotion에서 결정적으로 렌더됩니다. 캡처는 실제 앱 UI 테스트 흐름에서 얻었으며 제품 화면을 임의로 합성하지 않았습니다.
