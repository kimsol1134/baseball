---
format: 1920x1080
duration: 85s
message: "타자는 직전 공을 기억하고, 플레이어는 실패한 삶을 기억한다"
arc: "Demo Loop → 실패 → 기억 계승 → 적응 → 승리"
audience: "OpenAI Game Challenge 심사위원과 한국의 게임 플레이어"
mode: autonomous
music: "tense cinematic sports underscore, sparse percussion, rising pulse, triumphant final lift"
---

## Video direction

- Palette: `frame.md`의 `colors.cream`(#070A09)을 주 캔버스로, `colors.ink-black-alt`(#E7E7E5)을 주 텍스트로, `colors.ink-black`(#A5AC9D)을 보조 텍스트로, `colors.fire-orange`(#C8F24A)을 유일한 강조색으로 쓴다. 실패 프레임만 `colors.cream-muted`(#FF685C)를 단독 강조색으로 허용한다.
- Type and surface: display/body는 Pretendard 역할 토큰, chrome은 mono label 역할을 따른다. 모서리는 각지고 그림자·그라디언트·장식용 둥근 카드가 없으며, 1px hairline과 큰 활자 하나가 위계를 만든다. 실제 게임 캡처의 색과 UI는 변경하지 않는다.
- Motion grammar: 모든 진입은 명시적 `fromTo`와 부드러운 long-tail settle을 사용하고, `power3` 계열의 매끈한 감속을 기본으로 한다. 내레이션이 없으므로 각 공개 시점은 화면 문구와 SFX cue에 맞추며, 핵심 결과는 프레임 후반 50%에서 드러난다. 중간 seam은 방향·속도를 맞춘 cut-the-curve 또는 blur-snap으로 잇는다.
- Framing: 실제 캡처는 브라우저 chrome 없이 화면의 최소 40%를 차지한다. 오버레이는 캡처를 가리지 않는 상단 83% 안에 두고 하단 17% caption keep-out을 비운다. 캡처의 특정 부위를 움직일 때는 같은 스크린샷의 crop을 사용하며 전체 UI를 재구성하지 않는다.
- Rhythm: Frame 2의 두 번째 규칙 카드, Frame 4의 `여기까지`, Frame 7의 삼진 결과, Frame 8의 최종 URL은 의도적으로 정지해 읽히는 breather다. 나머지 프레임은 선택과 결과를 순차 공개하되 마지막 공개 후 카메라는 멈춘다.
- Negative list: 실존 구단·리그·선수·로고, 브라우저 chrome, 가짜 기능, 두 번째 강조색, 자의적 수치, 보라·파랑 AI 그라디언트, bokeh, drop shadow, 둥근 glass card, 기본 bounce, 무한 반복, 랜덤, lazy breathing, 후반부 무의미한 pan/push, 초반 25%에 전부 쏟는 slideshow, 요소마다 따로 떠다니는 screensaver motion을 금지한다.

## Frame 1 — 마지막 한 구

- scene: 실제 릴리스 화면을 극단적으로 확대해 초록 구간과 손을 놓는 순간만 보인 뒤 전체 게임 화면으로 빠르게 풀백한다.
- voiceover: ""
- duration: 7s
- poster: 5.4s
- transition_in: cut
- status: animated
- src: compositions/frames/01-last-pitch.html
- type: hook
- persuasion: Stakes amplification
- beat: tension + curiosity
- blueprint: zoom-out-workspace-reveal (Adapt)
- focal: assets/game-03-hold-release.png
- roles: game-03-hold-release = focal actual-game surface · scene-game = background (dim 45%)
- asset_candidates: assets/game-03-hold-release.png — 초록 릴리스 구간을 통과하는 실제 1920×1080 플레이 화면; assets/scene-game.webp — 투수와 타자가 마주한 보조 키 아트
- sfx: riser, whoosh-short

narrativeRole: 첫 3초 안에 “한 구가 한 생을 바꾼다”는 생존의 압박을 체감시킨다.
keyMessage: 이 게임에서 한 번의 릴리스는 한 번의 삶만큼 무겁다.

Adapt: 전체 게임 화면이 처음부터 완성된 하나의 world라는 구조와 단 한 번의 decelerating zoom-out을 유지한다. 디자인 툴 workspace 대신 실제 투구 캡처가 containing whole이며, 보조 키 아트는 최초 깊이층으로만 쓴다.

Scene 1 (0.0–1.7s): `scene-game`을 45% 어둡게 깐 layered-depth 배경 위에서 `game-03-hold-release`의 릴리스 미터 crop만 frame-wide로 보인다. 초록 목표 구간과 바늘이 유일한 초점이며 blur-to-sharp focus resolve(`depth-of-field-blur`)가 심장박동 cue에 맞춰 끝난다; full-bleed detail, 3 depth layers.

Scene 2 (1.7–4.9s): 같은 screenshot world가 단 한 번의 decelerating zoom-out(`viewport-change`, `coordinate-target-zoom`)으로 미터→릴리스 패널→전체 투구 UI까지 끊김 없이 드러난다. 중간 3.2s에 작은 mono kicker `OUT ONE · LIFE ONE`이 상단 hairline 옆에 공개되며, zoom-out이 4.9s에 완전히 멈춘다; rule-of-thirds, actual UI가 70% hierarchy.

Scene 3 (4.9–7.0s): 카메라는 잠기고, 좌상단의 display 문장 `한 구가`가 먼저, 5.8s에 accent 절 `한 생을 바꾼다`가 per-word staggered reveal(`dynamic-content-sequencing`)로 더 크게 붙는다. 전체 게임 화면은 그대로 읽히며 마지막 1.2s는 완전 정지한다; asymmetric 60/40, top 83% only.

## Frame 2 — 기억하는 경기

- scene: 실제 인트로의 제목과 선수 dossier를 넓게 보여준 뒤, 화면 위 두 문장이 순서대로 고정된다: “타자는 직전 공을 기억한다.” “플레이어는 실패한 삶을 기억한다.”
- voiceover: ""
- duration: 8s
- poster: 5.8s
- transition_in: zoom-through 0.5s
- status: animated
- src: compositions/frames/02-memory-game.html
- type: product_intro
- persuasion: Category definition
- beat: clarity + intrigue
- blueprint: titlecard-reveal (Adapt)
- focal: assets/game-01-intro.png
- roles: game-01-intro = focal actual intro · hero-key-art = supporting cutout
- asset_candidates: assets/game-01-intro.png — 제목, 투수 키 아트, CTA, 선수 dossier가 모두 보이는 실제 브라우저 인트로; assets/hero-key-art.png — 기존 시네마틱 투수 키 아트
- sfx: whoosh-cinematic, ping

narrativeRole: 영상의 한 문장 약속을 두 번째 비트 안에 명확히 선언한다.
keyMessage: 타자의 적응과 플레이어의 기억 계승이 서로 맞물리는 투수 로그라이트다.

Adapt: Product_Intro title-card prelude의 3-card chain을 두 규칙 카드로 줄이되, 각 카드의 단일 restrained move와 충분한 hold를 유지한다. 첫 카드의 바탕에는 실제 인트로와 원본 투수 cutout을 그대로 둔다.

Scene 1 (0.0–2.2s): `game-01-intro`가 frame-wide로 놓이고 `hero-key-art`가 동일 인물 영역 뒤에 supporting depth로 겹친다. 실제 제목과 dossier는 선명하게 유지하고 주위만 35% dim; 상단 mono label `BROWSER PITCHING ROGUELITE`가 hairline draw(`svg-path-draw`)와 함께 늦게 나타난다; asymmetric 60/40, focal ≥70%.

Scene 2 (2.2–4.7s): blur-away→snap-into-focus handoff(`depth-of-field-blur`)로 dark flat card가 인트로를 덮고 첫 규칙 `타자는 직전 공을 기억한다.`가 한 번의 gentle fade + scale settle(`scale-swap-transition`)로 왼쪽 상단 60%에 들어온다. `직전 공`만 acid accent; 선언형 broadside, 50% negative space.

Scene 3 (4.7–8.0s): full-opacity hard cut으로 두 번째 flat card `플레이어는 실패한 삶을 기억한다.`가 교대하고, 5.8s에 `실패한 삶`이 acid로 snap된다(`discrete-text-sequence`). 6.2s 이후 정지해 메시지를 읽히며 작은 `PLAY → FAIL → INHERIT` label만 하단 keep-out 위에 남는다; centered-left title card, no camera motion.

## Frame 3 — 읽고, 고르고, 놓는다

- scene: 실제 플레이 캡처 안에서 포수의 리드, 슬라이더 선택, 바깥 낮은 코스, 릴리스 버튼을 하나의 커서 동선으로 차례로 강조하고 홀드 화면으로 전환한다.
- voiceover: ""
- duration: 12s
- poster: 9.2s
- transition_in: crossfade 0.4s
- status: animated
- src: compositions/frames/03-read-choose-release.html
- type: feature_showcase
- persuasion: Show-don't-tell proof
- beat: control + anticipation
- blueprint: cursor-ui-demo (Adapt)
- focal: assets/game-02-read-and-choose.png
- roles: game-02-read-and-choose = focal actual UI · game-03-hold-release = supporting actual state
- asset_candidates: assets/game-02-read-and-choose.png — 타자 읽기, 구종, 3×3 코스, 릴리스가 보이는 실제 첫 투구 화면; assets/game-03-hold-release.png — 릴리스 미터가 움직이는 실제 홀드 화면
- sfx: click, click-soft, whoosh-short

narrativeRole: 심사위원이 조작법을 설명 없이 이해하게 하고 플레이 가능성을 직접 증명한다.
keyMessage: 읽기, 선택, 타이밍이 모두 마지막 공의 결과를 바꾼다.

Adapt: locked static-stage state tour와 cursor-as-actor를 유지한다. UI를 재구성하지 않고 실제 캡처 위에 산성 연두 custom cursor, hairline focus box, 짧은 step label만 얹고 마지막에 실제 홀드 상태로 same-anchor swap한다.

Scene 1 (0.0–2.3s): `game-02-read-and-choose`가 브라우저 chrome 없이 frame-wide로 자리 잡고 카메라는 고정된다. custom cursor가 좌측 `타자 읽기` 영역으로 이동해 클릭 ripple(`cursor-click-ripple`)을 남기고 `01 · READ` label이 1.4s에 공개된다; actual UI 85%, 3 depth layers from screenshot + focus box + cursor.

Scene 2 (2.3–5.1s): cursor가 구종 영역의 선택된 `슬라이더`로 이동하며 카메라는 계속 고정된다. cursor click + ripple(`cursor-click-ripple`)과 `02 · PITCH` label이 같은 beat에 답하고 focus box는 이전 영역에서 새 영역으로 hard state-swap(`dynamic-content-sequencing`)한다.

Scene 3 (5.1–7.9s): cursor가 3×3 존의 바깥 낮은 칸으로 이동해 클릭하고, hairline progress가 읽기 패널→구종→코스를 한 번만 채운다(`stat-bars-and-fills`). `03 · ZONE`과 `타자의 노림 반대`가 6.6s에 순차 공개된다; rule-of-thirds path, UI hierarchy preserved.

Scene 4 (7.9–10.0s): cursor가 릴리스 버튼으로 내려가 click + ripple(`cursor-click-ripple`)을 수행한다. peak velocity에서 `game-03-hold-release`로 same-anchor scale swap(`scale-swap-transition`)하고 `04 · HOLD / RELEASE`가 가장 늦게 공개된다.

Scene 5 (10.0–12.0s): 실제 홀드 화면의 미터 crop만 밝아지고 바늘을 따라 accent tracking line이 한 번 진행한다(`stat-bars-and-fills`). cursor는 손을 놓는 위치에서 멈추고 11.0s 이후 카메라와 모든 오버레이가 정지한다; focal meter upper-right, caption band clear.

## Frame 4 — 기다리던 공

- scene: 포심과 가운데 코스가 타자의 노림과 겹친 실제 `끝내기 안타` 화면을 먼저 보여주고, 어둡게 닫히며 `이번 생은 여기까지` 화면으로 넘어간다.
- voiceover: ""
- duration: 9s
- poster: 6.5s
- transition_in: squeeze 0.45s
- status: animated
- src: compositions/frames/04-failure.html
- type: pain_point
- persuasion: Consequence proof
- beat: shock + loss
- blueprint: kinetic-type-beats (Adapt)
- focal: assets/game-04-first-life-hit.png
- roles: game-04-first-life-hit = focal actual result · game-05-memory-choice = supporting actual next state · scene-legacy = background (dim 50%)
- asset_candidates: assets/game-04-first-life-hit.png — 예상 구종을 가운데에 던져 끝내기 안타를 허용한 실제 결과; assets/game-05-memory-choice.png — 이번 생 종료와 기억 선택 화면; assets/scene-legacy.webp — 실패 후 회고 장면 보조 이미지
- sfx: impact-bass-2, error

narrativeRole: 실패가 연출용 장식이 아니라 플레이 선택의 즉각적인 대가임을 보여준다.
keyMessage: 타자의 노림을 그대로 던지면 이번 삶은 끝난다.

Adapt: Problem multi-beat statement build의 한 문장씩 교대하는 구조를 유지하되, bare canvas 대신 실제 판정과 실제 game-over state를 증거로 쓴다. 이 프레임의 유일한 강조색은 failure red이며 bounce나 glitch는 쓰지 않는다.

Scene 1 (0.0–2.4s): `game-04-first-life-hit`가 frame-wide로 즉시 보이고 actual `끝내기 안타`가 focal이다. 1.0s에 red hairline이 결과 영역을 가로지르고 `기다리던 공이었다.`가 상단에 chunk reveal(`dynamic-content-sequencing`)로 들어온다; actual result 75%, split UI preserved.

Scene 2 (2.4–4.7s): `끝내기`와 `안타` 두 단어가 서로 다른 방향의 kinetic beat-slam(`kinetic-beat-slam`, smooth settle)으로 화면 중앙을 차례로 점유한다. 원본 결과 화면은 50% dim되고, 각 단어는 다음 단어가 오면 full-opacity hard cut으로 교대한다; centered display, one display moment at a time.

Scene 3 (4.7–6.8s): downward cut-the-curve seam으로 `scene-legacy`가 50% dim background가 되고 `game-05-memory-choice`의 game-over 영역이 우측 55%에 실제 surface로 들어온다. 왼쪽에는 `이번 생은`만 먼저 masked slide(`gsap-effects`)로 공개된다; asymmetric 45/55, 3 layers.

Scene 4 (6.8–9.0s): red display `여기까지.`가 7.2s에 motion-blur fly-in(`motion-blur-streak`)으로 날아와 선명하게 멈춘다. 7.8s 이후 모든 motion이 끝나고 실제 기억 카드가 어둠 속에서 다음 프레임을 예고한 채 정지한다.

## Frame 5 — 실패가 남기는 것

- scene: 실제 기억 카드 세 장이 차례로 살아나고 `포수의 노트`가 선택되며, 추천 코스 공개 효과가 다음 삶으로 이어지는 한 줄로 정리된다.
- voiceover: ""
- duration: 11s
- poster: 8.4s
- transition_in: blur-crossfade 0.5s
- status: animated
- src: compositions/frames/05-inherit-memory.html
- type: benefit_highlight
- persuasion: Loss-to-value reframing
- beat: relief + agency
- blueprint: grid-card-assemble (Adapt)
- focal: assets/game-06-memory-selected.png
- roles: game-05-memory-choice = supporting actual choices · game-06-memory-selected = focal actual selected state
- asset_candidates: assets/game-05-memory-choice.png — 세 가지 기억 선택지가 보이는 실제 게임 오버 화면; assets/game-06-memory-selected.png — 포수의 노트가 선택되고 다음 삶 CTA가 열린 실제 화면
- sfx: pop, chime

narrativeRole: 패배를 벌점이 아니라 다음 전략을 만드는 자원으로 뒤집는다.
keyMessage: 실패는 사라지지 않고, 플레이어가 고른 능력으로 계승된다.

Adapt: Benefits vertical-list의 누적 assemble과 chosen-item stop을 유지한다. 카드 자체를 새로 그리지 않고 `game-05-memory-choice`에서 동일한 세 card crop을 가져와 직접 슬롯에 넣으며, 선택 순간은 `game-06-memory-selected`로 실제 state swap한다.

Scene 1 (0.0–2.2s): `game-05-memory-choice`가 frame-wide로 놓이고 상단 `CHOOSE ONE MEMORY`만 밝게 남는다. 세 카드 영역은 어둡게 유지한 채 첫 crop `좋은 타이밍 판정 범위 +14`가 직접 슬롯으로 짧게 들어온다(`center-outward-expansion` short-path); triptych scaffold, camera static.

Scene 2 (2.2–5.8s): 두 번째와 세 번째 실제 card crop이 각각 3.1s와 4.5s에 direct-to-slot assemble하며, 각 카드의 effect 한 줄이 mask-wipe로 늦게 읽힌다. accent marker만 spring-pop(`spring-pop-entrance`, smooth register)하고 나머지는 low drama; triptych fills across upper 75%.

Scene 3 (5.8–8.4s): focus slot이 `포수의 노트`로 이동하며 이 카드만 선명하고 이웃은 dim-by-position 된다. 6.7s 클릭 cue에 `game-06-memory-selected`로 full-state swap(`discrete-text-sequence`)해 실제 체크와 활성화된 다음 삶 CTA를 보여준다; chosen card ≥45% hierarchy.

Scene 4 (8.4–11.0s): 카드 배열은 8.4s에 완전히 멈추고 왼쪽 빈 영역에 `실패는`이 먼저, 9.3s에 acid display `능력이 된다.`가 per-word reveal(`dynamic-content-sequencing`)로 붙는다. 마지막 1.0s는 선택된 실제 카드와 문장을 함께 정지해 읽힌다.

## Frame 6 — 타자도, 나도 적응한다

- scene: 세 번째 삶의 실제 화면에서 추가 기억과 추천 코스를 보여주고, 첫 스트라이크 뒤 타자의 예상 구종이 바뀌며 다음 카운터 구종도 바뀌는 두 화면을 연속 비교한다.
- voiceover: ""
- duration: 13s
- poster: 10.0s
- transition_in: zoom-through 0.5s
- status: animated
- src: compositions/frames/06-adaptation.html
- type: feature_showcase
- persuasion: Mechanism proof
- beat: insight + momentum
- blueprint: cursor-ui-demo (Adapt)
- focal: assets/game-09-batter-adapts.png
- roles: game-07-next-life = supporting actual inherited state · game-08-strike-one = supporting actual result · game-09-batter-adapts = focal actual adaptation state
- asset_candidates: assets/game-07-next-life.png — 두 기억과 추천 코스가 보이는 실제 세 번째 삶; assets/game-08-strike-one.png — 카운터 승부가 통과한 실제 첫 스트라이크; assets/game-09-batter-adapts.png — 직전 공을 기억해 예상과 카운터가 바뀐 실제 다음 투구 화면
- sfx: click-soft, ping, impact-bass-1

narrativeRole: 이 게임만의 적응 시스템이 매 투구 새로운 판단을 요구한다는 증거를 제시한다.
keyMessage: 같은 공은 읽히고, 직전 선택을 역이용해야 살아남는다.

Adapt: static-stage state tour를 세 실제 screenshot state로 운용하고 cursor는 각 state의 원인을 가리키는 배우로만 쓴다. 카메라는 click 사이의 짧은 target focus만 허용하며 마지막 비교가 나타난 뒤 완전히 잠근다.

Scene 1 (0.0–2.8s): `game-07-next-life`가 frame-wide로 나타나고 `LIFE 03`와 두 개의 memory pill, 추천 코스를 차례로 hairline focus한다. cursor는 memory→추천 코스로 이동하고 `전생의 정보` label이 1.8s에 공개된다; actual UI 85%, left read panel dominant.

Scene 2 (2.8–5.7s): cursor가 추천 슬라이더와 바깥 낮은 코스를 차례로 클릭(`cursor-click-ripple`), 선택된 두 영역 사이 accent connector가 draw-on(`svg-path-draw`)한다. 다음 결과로 향하는 짧은 pan/focus-lock(`viewport-change`)이 5.2s에 멈춘다.

Scene 3 (5.7–7.8s): same-anchor swap으로 `game-08-strike-one`이 들어오고 actual `헛스윙` 결과를 그대로 보여준다. strike count의 첫 불이 progress fill(`stat-bars-and-fills`)로 켜지며 `선택이 통했다`가 6.8s에만 공개된다; result center ≥50%.

Scene 4 (7.8–10.6s): cut-the-curve로 `game-09-batter-adapts`가 들어오고 cursor가 바뀐 `타자 읽기`와 새 카운터 구종을 차례로 가리킨다. 이전 read의 작은 crop과 새 read의 crop이 split-screen으로 8.8s/9.7s에 공개되어 `직전 공 기억` 변화가 실제 문구로 비교된다; split 40/60, no reconstructed copy.

Scene 5 (10.6–13.0s): split은 새 state 하나로 수렴하고 display `같은 공은 읽힌다.`가 먼저, 11.5s에 acid `카운터는 바뀐다.`가 이어진다. cursor는 다음 구종 위에 정지하고 12.0s 이후 motion을 멈춘다; asymmetric 70/30, held tactical read.

## Frame 7 — 기억은 공략이 된다

- scene: 실제 세 번째 스트라이크 결과가 화면을 가득 채운 뒤 UI가 옆으로 밀리며 `헛스윙 삼진`과 세 투구의 선택 변화가 큰 활자로 남는다.
- voiceover: ""
- duration: 12s
- poster: 7.8s
- transition_in: push-slide LEFT 0.45s
- status: animated
- src: compositions/frames/07-strikeout.html
- type: feature_showcase
- persuasion: Payoff demonstration
- beat: triumph + release
- blueprint: video-text-pivot (Adapt)
- focal: assets/game-10-strikeout.png
- roles: game-10-strikeout = focal actual terminal result · game-08-strike-one = supporting actual strike state · game-09-batter-adapts = supporting actual setup state
- asset_candidates: assets/game-10-strikeout.png — 실제 헛스윙 삼진과 3스트라이크 카운트가 보이는 종결 화면; assets/game-08-strike-one.png — 첫 스트라이크 결과 보조 화면; assets/game-09-batter-adapts.png — 마지막 카운터 선택 직전 보조 화면
- sfx: whoosh-cinematic, impact-bass-1

narrativeRole: 실패에서 얻은 정보가 실제 승리로 환원되는 루프의 정점을 보여준다.
keyMessage: 전생의 기억과 이번 타석의 읽기가 마지막 아웃을 만든다.

Adapt: product video를 세 장의 연속 실제 state로 대체하고, 중앙 증거가 옆으로 물러나 같은 anchor의 hero result에 무게를 넘기는 signature move를 그대로 유지한다. 원본 blueprint의 gradient pill은 flat acid rule로 바꿔 `frame.md`를 지킨다.

Scene 1 (0.0–3.0s): `game-08-strike-one`과 `game-09-batter-adapts`가 같은 full-frame anchor에서 1.2s에 scale-swap하며 첫 스트라이크→변경된 카운터를 짧게 복기한다. 각 state는 실제 화면 그대로이고 `1 STRIKE`, `NEW COUNTER` mono label만 순차 공개된다; camera static, actual UI ≥75%.

Scene 2 (3.0–6.2s): `game-10-strikeout`이 center에 크게 들어와 3.8s까지 단독으로 보인 뒤, 4.4s부터 왼쪽 58%로 부드럽게 slide+scale down한다. 같은 중앙 anchor에서 오른쪽 hero `3 STRIKES`와 actual `헛스윙 삼진` crop이 3D depth가 아닌 flat broadside type로 커지며 weight transfer(`scale-swap-transition`)를 완성한다; split 58/42.

Scene 3 (6.2–9.3s): screenshot과 stat이 peak velocity에서 함께 걷히고 빈 center에 `기억은`이 먼저, 7.6s에 acid `공략이 된다.`가 character-stream reveal(`dynamic-content-sequencing`)로 타이핑된다. 한 문장만 70% width를 차지하고 카메라는 고정된다.

Scene 4 (9.3–12.0s): flat acid rule이 왼쪽에서 scaleX snap하며 문장 아래를 봉인하고(`stat-bars-and-fills` progress form), `마지막 아웃` mono stamp가 10.2s에 붙는다. 10.7s 이후 실제 삼진 결과의 작은 corner crop과 문장이 완전 정지한다; no glow halo, top 83% clear.

## Frame 8 — 이번 생엔, 이름이 불렸다

- scene: 실제 지명 엔딩과 최종 스카우트 리포트를 충분히 보여준 뒤, UI가 가장자리로 걷히고 게임 제목, `브라우저에서 바로 플레이`, 다음 시즌의 Hive 확장 계획이 최종 잠금 화면으로 남는다.
- voiceover: ""
- duration: 13s
- poster: 8.8s
- transition_in: blur-crossfade 0.55s
- status: animated
- src: compositions/frames/08-drafted.html
- type: cta
- persuasion: Future pacing + friction reduction
- beat: fulfillment + invitation
- blueprint: logo-assemble-lockup (Adapt)
- focal: assets/game-11-victory.png
- roles: game-11-victory = focal actual ending · scene-draft = background (dim 45%) · icon = supporting brand mark
- asset_candidates: assets/game-11-victory.png — 가상 구단의 지명 전화와 최종 스카우트 리포트가 보이는 실제 엔딩; assets/scene-draft.webp — 지명 전화를 받는 기존 결말 키 아트; assets/icon.png — 정사각형 가상 게임 아이콘
- sfx: notification, chime, impact-bass-2

narrativeRole: 한 생의 보상을 끝까지 보여주고 심사위원이 즉시 직접 플레이하도록 초대한 뒤, Hive로 이어질 다음 시즌의 확장성을 짧게 증명한다.
keyMessage: 설치도 로그인도 없이 전체 환생 루프를 브라우저에서 바로 플레이하고, 다음 시즌에는 Hive 기반 일일 리더보드·LiveOps·모바일/PC 확장으로 이어갈 수 있다.

Adapt: CTA button-wordmark-build의 clear→mark build→final lockup 순서를 유지한다. 새 로고를 만들지 않고 기존 icon과 실제 게임 제목을 사용하며, diagonal accent slash가 최종 브라우저 URL로 시선을 넘기는 signature wipe가 된다.

Scene 1 (0.0–3.6s): `scene-draft`를 45% dim한 full-bleed 배경 위에 `game-11-victory`가 frame-wide로 선명하게 놓인다. 1.3s phone vibration cue에 실제 `INCOMING CALL`, 2.1s에 실제 scout score 영역을 hairline focus하며 `이번 생엔, 이름이 불렸다.`를 그대로 읽게 한다; actual ending ≥80%, camera locked.

Scene 2 (3.6–6.3s): victory screenshot은 same-center scale down으로 좌측 55% evidence panel이 되고, 우측에 기존 `icon`이 scale-up-with-rotate(`spring-pop-entrance`, smooth settle)로 들어온다. 5.0s부터 제목 `야구 못하면`과 accent `또 환생함`이 두 덩어리로 cascade(`waterfall-entry`)해 균형 잡힌 lockup을 만든다; asymmetric 55/45, no invented mark.

Scene 3 (6.3–9.6s): actual victory panel이 어두운 캔버스로 정리되고 icon+title lockup이 center로 이동한다. 7.5s에 thin acid diagonal line이 sweep→full-frame band→slash로 변하는 mask wipe를 수행하고, 그 움직임을 따라 `브라우저에서 바로 플레이`가 letter-by-letter build(`discrete-text-sequence`)된다; centered CTA, one accent.

Scene 4 (9.6–13.0s): slash 왼쪽에 icon+title, 오른쪽에 `baseball-rebirth-last-pitch.kimsol1134.chatgpt.site`가 left-to-right wipe로 완성된다. 하단 keep-out 위의 2단 strip에 현재 빌드의 `설치 없음 · 로그인 없음 · 키보드/터치`와 미래 계획임을 분명히 한 `NEXT SEASON WITH HIVE · 일일 리더보드 · LIVEOPS · MOBILE ↔ PC`가 10.8s에 함께 공개되고, 11.2s부터 최종 lockup은 dead-static hold로 남는다; full-width strip, final frame only.
