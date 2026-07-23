# 시각 자산 원본·검토 기록

## 2026-07-23 역할 장면 3종

| 항목 | 기록 |
|---|---|
| 원본 | `role-scenes-contact-sheet.png` |
| 생성 도구 | OpenAI Image Generation (`019f882f-c6f6-7761-a2a5-61d11e1f0568`) |
| 적용 파일 | `coach-role-scene.webp`, `catcher-role-scene.webp`, `rival-role-scene.webp` |
| 후처리 | 각 패널 안전 영역을 641×801로 자른 뒤 240×300 WebP, quality 82로 축소 |
| 용도 | 고교 관계 장면과 라이벌 스카우팅의 역할 분위기 보조 |
| 인물 정책 | 이름이 다른 NPC에 같은 얼굴을 붙이지 않도록 얼굴이 없거나 식별되지 않는 장면만 사용 |
| IP 검토 | 보이는 글자·등번호·팀 로고·리그 표식 없음. 실존 인물을 입력·참조하지 않음 |

생성 프롬프트:

> Create a single cohesive 3-panel horizontal editorial game-art contact sheet for a premium Korean fictional baseball career simulation at night. Each panel must be a separate 4:5 vertical scene with clean full-bleed boundaries and NO gutters crossing panels. Panel 1: anonymous baseball coach role scene, close-up of hands holding a dark clipboard and pencil at a dugout rail, face completely out of frame. Panel 2: anonymous catcher role scene, catcher mask and well-worn mitt resting on a dark bench under cool stadium lights, no person visible. Panel 3: anonymous rival batter role scene, backlit batter silhouette from behind inside the on-deck circle, face fully invisible and uniform entirely generic. Style: sophisticated cinematic sports editorial photography, midnight navy and cool cyan stadium lighting with restrained warm amber accents, rich texture, crisp premium UI key art, realistic but clearly fictional, consistent exposure and art direction across all three. No text, no lettering, no numbers, no logos, no trademarks, no recognizable team marks, no real people, no national or league insignia. Output should make each panel safe to crop independently to 240x300.

## 2026-07-23 Midnight Dugout 앱 아이콘

| 항목 | 기록 |
|---|---|
| 원본 | `app-icon-midnight.png` |
| 생성 도구 | OpenAI Image Generation (`019f882f-c6f6-7761-a2a5-61d11e1f0568`) |
| 후처리 | Tauri CLI 2.11.4로 Windows·macOS·iOS·Android 규격 파생본 생성 |
| IP 검토 | 글자·숫자·팀·리그·국기·인물 표식 없음. 야구공·다이아몬드·궤적의 일반 도형만 사용 |

생성 프롬프트:

> Square premium desktop game app icon for an original fictional Korean baseball career simulation, no text. A single white baseball with subtle red seams cuts through a midnight navy diamond-shaped stadium portal, leaving one restrained cyan data-trajectory arc and a small warm amber spark at the point of contact. Bold simple silhouette readable at 32 pixels, refined embossed materials, deep navy background, cool stadium-light palette matching a sophisticated 'Midnight Dugout' broadcast UI, centered composition, strong negative space, crisp polished commercial game icon. No letters, no numbers, no logos, no real team marks, no league insignia, no flags, no people, no trademarked shapes, no mockup frame, no rounded-square border; artwork fills the square.

## `retired/`

현재 빌드에서 사용하지 않는 이전 기준본을 파괴하지 않고 보관하는 영역이다. 기존 인물 초상 3종은 여러 NPC 이름에 같은 얼굴이 반복되는 문제 때문에 교체했고, `gamecast-pitch-stadium-night-v3.webp`는 좌표 기반 TrackLab SVG가 투구 화면을 대체해 은퇴했다. 생성 시점의 정확한 프롬프트와 모델 기록은 남아 있지 않으므로 추정해서 적지 않는다.
