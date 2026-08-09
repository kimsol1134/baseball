# 야구 못하면 또 환생함 — Remotion 육성 데모

육성 선택이 게임의 핵심이라는 제품 방향을 85초 안에 보여 주는 대회 제출용 영상입니다. 실제 공개 웹 게임의 1920×1080 캡처만 기능 증거로 사용하며, 내레이션과 BGM 없이 효과음만 포함합니다. 경기 결과보다 `5일 훈련 → 피치 디자인 → 반복 숙련 → 시그니처 → 실패 계승 → 다른 공약으로 재육성`에 더 긴 시간을 배분했습니다.

## 구성

1. 마지막 3구보다 먼저 만들어야 할 5일
2. 압도형·코너·수싸움 공약과 `REPEAT · CONNECT · BRANCH` 규칙
3. D1 제구 → D2 분석 연계 → D3 피치랩 개방
4. `검은 선 제구` 선택 → D4 제구 반복 숙련 LV.2 → D5 회복 → 시그니처 완성
5. 완성 빌드의 실패와 `포수의 노트` 기억 선택
6. 능력·기억은 유지하고 5칸·공약·피치 디자인은 다시 설계
7. 압도형 공약에서 `가로지르는 슬라이더`와 결정구 숙련을 완성하고 경기에서 조건부 발동
8. 승리한 철학의 유산 1/3, 상대별 새 육성, 실제 유산 3/3 엔딩과 공개 URL

## 명령

```bash
npm run capture  # 공개 사이트에서 5일 육성·실패·재육성·유산 3/3 상태 28장 캡처
npm run lint     # ESLint + TypeScript
npm run dev      # Remotion Studio, 브라우저 자동 실행 없음
npm run render   # 1920×1080 H.264/AAC 최종 MP4
```

검증된 최종 렌더는 `renders/baseball-rebirth-development-demo-final.mp4`입니다. 85.056초, 15,859,149바이트, 1920×1080, 30fps, H.264/AAC이며 효과음만 사용합니다. 전체 디코딩과 대표 20프레임 검수를 통과했고, 통합 음량은 -18.00 LUFS, 트루피크는 -8.73 dBTP입니다. SHA-256은 `dc1f559cffc07ac105d653907418dd96d036185a6029f1a3335606b713ccefdb`입니다. 대표 프레임은 `renders/baseball-rebirth-development-demo-contact-sheet.jpg`에서 한 번에 확인할 수 있습니다.

기존 HyperFrames 영상과 자산은 `../baseball-rebirth-demo`에 그대로 보존합니다.
