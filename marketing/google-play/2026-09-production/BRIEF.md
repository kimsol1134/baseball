# Google Play production creative · 2026-09-10

User request: production-ready screenshots, Remotion promotional video, and conversion-focused listing copy. Reference successful comparable baseball games. Arc Play Console is signed in.

## Scope
- Korean default listing (confirmed in Play Console; no other listing languages currently configured).
- Eight phone screenshots: 1080×1920 PNG RGB, actual latest Android UI with restrained headlines occupying less than 20%.
- Feature graphic 1024×500 PNG RGB and YouTube thumbnail 1280×720.
- 30-second portrait 1080×1920 and landscape 1920×1080 MP4, 30 fps, H.264/AAC; authored in existing apps/promo Remotion 4.0.499 project without upgrading pinned dependencies.
- Korean title/short description/full description, ordering and alt text, sources and upload manifest.
- Prepare locally and inspect Console read-only. No production release or YouTube publication is requested in this creation step.

## Strategy
Audience: Korean players who like baseball and character-growth/choice games, including players tired of roster collection.
Promise: 직접 던지는 한 구 + 선택으로 키우는 투수 커리어 + 실패 뒤에도 이어지는 유산.
Hook: 한 구는 손끝으로, 인생은 내 선택으로.
Show actual pitch control immediately, then rebirth and growth, conversation, draft, contract, professional season and records.
No fake gameplay, real-team/player IP, ranking/revenue claims, invented testimonials, promotional price text or store-badge CTA in graphics.

## Evidence and boundaries
Use actual Android app rendering and real game-kernel states in an isolated QA harness. Keep the user's launch-QA save untouched. No iOS UI presented as Android. Marketing presentation crops only OS chrome and scales proportionally.
Actual preview video sources must occupy at least 80% of runtime; a static real UI state is acceptable for brief career/choice beats, while pitch interactions are recorded.
Console app: 야구 못하면 또 환생함 / com.solkim.baseball.android. Production inactive; existing six phone screenshots and no preview-video URL. Default language ko-KR.
Release/device QA gates from previous work remain separate from creative completion.
