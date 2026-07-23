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

## 2026-07-23 커리어 장소 키아트 3종

| 항목 | 기록 |
|---|---|
| 원본 | `high-school-career-intro-source.png`, `high-school-stadium-source.png`, `pro-career-stadium-tunnel-source.png` |
| 생성 도구 | OpenAI Image Generation (`019f882f-c6f6-7761-a2a5-61d11e1f0568`) |
| 적용 파일 | `high-school-career-intro-v2.webp`, `high-school-stadium-night-v2.webp`, `pro-career-stadium-tunnel.webp` |
| 후처리 | 각 원본을 1600×900 WebP, quality 82로 축소. 런타임 파일은 각각 132 KiB 이하 |
| 용도 | 고교 진입·고교 진행/복구·프로 진행의 장소 규모와 커리어 단계 분리 |
| IP 검토 | 보이는 글자·숫자·팀 로고·리그·스폰서·국기 표식 없음. 실존 인물·구단·구장을 입력 또는 참조하지 않음 |

고교 커리어 진입 프롬프트:

> Create a wide 16:9 premium key-art background for the opening setup screen of an original fictional Korean high-school baseball career simulation. Night practice in a modest school ballpark: viewed along a shadowed dugout rail toward a bullpen lane, a single anonymous teenage pitcher seen only from behind at the far right tightening a generic glove before throwing, face completely hidden, no identifying features. Show grounded amateur details—worn pine-tar-dark bench wood, scuffed concrete, a mesh ball bag, chalk dust, chain-link backstop, compact light poles, a quiet neighborhood skyline—without looking poor or nostalgic. Sophisticated cinematic sports editorial realism with the project's Midnight Dugout palette: deep navy and charcoal shadows, cool cyan-white field lights, one restrained warm amber utility light, crisp rich texture and premium PC management-game finish. Composition: the entire left 52% must remain calm, dark and uncluttered for Korean UI copy; place the anonymous pitcher and brighter bullpen depth on the right; safe for responsive 16:9 and 3:1 crops. Entirely fictional and generic. No visible face, no words, no signage, no lettering, no numbers, no logos, no recognizable uniforms, no flags, no team or league marks, no sponsor boards, no trademarks, no watermark, no UI frame.

고교 구장 프롬프트:

> Create a wide 16:9 premium environmental key-art background for the active career dashboard and connection-recovery screen of an original fictional Korean high-school baseball simulation. A modest amateur school baseball ground at blue hour after rain, viewed from low beside the dugout steps across the chalked foul line toward the infield. Compact metal bleachers with only scattered indistinct silhouettes, chain-link backstop, small manual-looking scoreboard structure with its face completely dark and blank, four modest light poles, damp clay and grass reflecting the lights, neighborhood rooftops beyond the outfield. No player is the subject; the empty mound and field carry anticipation. Sophisticated cinematic sports editorial realism, grounded and premium rather than glossy: deep navy, graphite and muted emerald, cool cyan-white lights, restrained warm amber from the dugout, crisp rich texture matching a polished PC management game. Composition: keep left 48% dark and low-detail for interface copy; place mound, bleachers and brighter field depth center-right; safe for responsive 16:9 and 3:1 crops. Entirely fictional. No readable text, no letters, no numbers, no signage, no logos, no team marks, no league insignia, no flags, no sponsor boards, no branded uniforms, no trademarks, no watermark, no UI frame.

프로 구장 프롬프트:

> Create a wide 16:9 premium key-art background for the professional career hub of an original fictional Korean baseball simulation game. View from just inside a grand modern stadium tunnel at night, opening onto a brilliantly lit full-scale professional ballpark packed with an energetic but individually unrecognizable crowd. Foreground: dark polished concrete, one generic equipment trunk and a rail cropped at the edges; midground: expansive emerald field, glowing foul lines and tall light towers; background: layered upper decks, subtle luxury boxes, broadcast gantry and city-night haze. The scene must communicate a major promotion from modest school baseball to elite professional baseball through scale, crowd density, lighting and production infrastructure. Cinematic sports editorial realism, sophisticated Midnight Dugout art direction: deep navy shadows, cool cyan-white stadium lights, restrained warm amber concourse accents, rich materials, clear depth, premium PC management-game finish. Composition: preserve a calm dark text-safe zone across the left 46%, place the brightest stadium spectacle and crowd toward the center-right, strong readable horizon around 55% height, safe for responsive 16:9 and 3:1 crops. Entirely fictional and generic. No visible players' faces, no real people, no words, no signage, no lettering, no numbers, no logos, no uniforms with marks, no flags, no team colors that imply a real club, no league insignia, no sponsor boards, no trademarks, no watermark, no UI frame.

## `retired/`

현재 빌드에서 사용하지 않는 이전 기준본을 파괴하지 않고 보관하는 영역이다. 기존 인물 초상 3종은 여러 NPC 이름에 같은 얼굴이 반복되는 문제 때문에 교체했고, `gamecast-pitch-stadium-night-v3.webp`는 좌표 기반 TrackLab SVG가 투구 화면을 대체해 은퇴했다. 프롬프트 기록이 없던 `high-school-pitcher-dugout.webp`, `high-school-stadium-night.webp`, `gamecast-field-stadium-night-v2.webp`도 추적 가능한 새 커리어 키아트로 교체했다. 생성 시점의 정확한 프롬프트와 모델 기록은 남아 있지 않으므로 추정해서 적지 않는다.
