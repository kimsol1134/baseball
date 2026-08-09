---
workflow: product-launch-video
flow: automation
storyboard: no
message: "타자는 직전 공을 기억하고, 플레이어는 실패한 삶을 기억한다"
destination: contest-submission-youtube
aspect: 1920x1080
language: ko
audience: "OpenAI Game Challenge 심사위원과 한국의 게임 플레이어"
length: 85s
angle: "한 타석에서 실패, 계승, 적응, 승리까지 보여주는 실제 플레이 아크"
narration: no
style_preset: broadside
---

## Intent

브라우저에서 바로 플레이되는 게임의 실제 화면을 중심으로, 한 번의 실패가 다음 생의
전략으로 이어지는 핵심 루프를 85초 안에 보여주는 대회 제출용 데모다. 영화적인 긴장감은
살리되 게임 화면과 조작 결과가 주인공이어야 하며, 홍보용 재해석보다 실제 플레이 쇼케이스에
가깝게 구성한다.

## Assets

- `../../apps/game-web` — 실제 브라우저 게임 원본; 로컬 실행 화면을 캡처해 시각적 진실로 사용한다.
- `../../apps/game-web/public/hero-key-art.png` — 도입과 마무리에 사용할 기존 키 아트.
- `../../apps/game-web/public/scene-game.webp` — 투구 장면 보조 이미지.
- `../../apps/game-web/public/scene-legacy.webp` — 기억 계승 장면 보조 이미지.
- `../../apps/game-web/public/scene-draft.webp` — 지명 결말 보조 이미지.
- `../../apps/game-web/SUBMISSION_KIT.md` — 대회 소개 문구와 3분 데모 동선의 사실 기준.

## Customizations

- 사이트의 실제 캡처 화면을 주요 에셋으로 사용한다.
- 실제 조작의 원인과 결과가 보이도록 `구종 선택 → 코스 선택 → 홀드/릴리스 → 판정`을 순서대로 보여준다.
- 첫 생의 실패, 기억 계승, 다음 생에서 타자의 적응을 역이용한 삼진, 지명 결말을 하나의 아크로 잇는다.
- 마지막 잠금 화면은 현재 브라우저 빌드와 다음 시즌의 Hive 확장 계획을 분리해 보여주며, 이미 연동된 기능처럼 표현하지 않는다.
- 내레이션 없이 짧은 한국어 화면 문구, 긴장감 있는 배경음, 투구·판정 효과음으로 전달한다.

## Notes

- 16:9 제출/YouTube 재생을 기준으로 1920×1080으로 제작한다.
- 대회 제한 3분보다 짧고 제품 데모 권장 구간 안인 85초를 목표로 한다.
- 실존 프로 구단명, 구단 약칭, 리그명, 선수명, 로고, 유니폼 문양, 슬로건을 넣지 않는다.
- 캡처 화면을 임의로 미화해 실제로 없는 기능이나 결과를 암시하지 않는다.
