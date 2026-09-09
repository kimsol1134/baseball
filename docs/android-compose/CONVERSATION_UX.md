# Android conversation UX — 2026-09-09

The relationship phase now opens a focused character scene. The player sees an 84dp portrait, a short event-specific line, and three full-card responses. Routine recollections, the original authored scene, and secondary positive effects are disclosed on demand. Costs remain visible before selection, including an injury that could otherwise look beneficial because the post-injury arm-risk value is lower.

The same scene layout remains after a successful choice: the same actor responds, committed changes appear, and one button continues to the next schedule. There is no result dialog covering another screen. The existing receipt preference still survives recreation; acknowledging it never dispatches a career command. Old receipt formats fall back to a neutral response, and receipts for a different career or completed-conversation count are ignored.

## Coverage

- High school: coach, catcher, rival, and fallback relationship scenes. Ordinary coach/catcher/rival beats vary by event and relationship tone. Full original prose remains available. Rare narrative scenes without a compact authored beat retain their full text rather than being truncated.
- Professional: rotation opportunity, new pitch trial, farm reset, extra bullpen, catcher game plan, role meeting, record chase, rival analysis, and season finale. Rival analysis correctly uses the catcher as the speaker. Other professional decision types retain their existing specialized presentation.
- Professional effects are projected with the same kernel and seed as the captured action, including clamps and role changes; the preview never writes state.
- Card presses lock immediately until a new state or a failed-save retry. Opening effect details does not commit a choice.
- Korean, English, and Japanese: 79 new semantic entries; existing entries preserved except the deliberately renamed game-planning display label. Large text reflows and scrolls without ellipsis; the portrait becomes smaller to make room.
- Pitch controls and simulation balance are unchanged.

Support is shown as an action and benefit, for example `배합 연습 성장량 ↑ · 1회`. The training selector uses the same name and explains pitch sequencing in plain language. Expanding the effect explains its one-use lifetime, persistence through other training, and ability caps. Old stored `다음 … 훈련 지원` receipts receive the same display treatment without changing saved mechanics.

## Validation

- 31 focused JVM tests: conversation scenes and tone, exact preview/commit deltas, injuries, real native-store persistence, choice costs, localization, and screen projection.
- 12 Android instrumentation tests on the existing `BatterQA_API35` emulator, isolated `com.solkim.baseball.android.compose.qa` package: three actors × three locales × 1×/2× text; complete visible default choices; full-card selection; double-tap prevention; failed-save retry; inspector safety; locale-stable portraits; non-modal commit-to-result flow; professional choices; training layouts and controls; persisted result recreation and acknowledgement.
- Debug APK and instrumentation APK assembled; Android lint passed.
- New conversation copy searched for real club/league names; none found.
- The localization inventory was refreshed. Its 24 review items concern existing source templates, including dynamically signed numeric strings; this is not a claim that the entire app has zero outstanding localization review items.

## Review images

- [Coach](../assets/mobile-core/conversation-ux/coach.png)
- [Catcher](../assets/mobile-core/conversation-ux/catcher.png)
- [Rival](../assets/mobile-core/conversation-ux/rival.png)
- [Committed result](../assets/mobile-core/conversation-ux/result.png)

No store upload or release was performed.
