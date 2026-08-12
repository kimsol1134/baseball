# iOS English Copy Bible — Phase A foundation

Status: Phase A foundation only. The app is not English-ready. The source inventory remains pending
until later phases move each user-facing surface through semantic review and UI verification.

## Voice

- Address the player directly in second person or use short present-tense narration.
- Keep baseball action concrete and compact.
- Explain the cause and consequence before adding emotion.
- Treat failure as information that can lead into the next career; never mock the player.
- Scouts describe evidence and possibility, not guaranteed futures.
- Preserve the emotional temperature of coaches, catchers, rivals, and relationship bands.
- Keep the Korean setting and institutions. Explain unfamiliar context naturally instead of replacing it.

## Terminology baseline

| Korean concept | English working term |
| --- | --- |
| 환생 | Rebirth |
| 회차 | Career or Run, depending on context |
| 기억 카드 | Memory Card |
| 대표 유산 | Signature Legacy |
| 야구혼 | Baseball Spirit |
| 고교 3년 | three-year high school career |
| 프로 지명 | get drafted / draft selection |
| 미지명 | undrafted |
| 2군 | Minors |
| 1군 | Majors |
| 선발 | Starter |
| 롱릴리프 | Long Reliever |
| 셋업 | Setup |
| 마무리 | Closer |
| 구위 | Stuff |
| 제구 | Control |
| 자동 릴리스 | Auto Release |

These are working terms, not permission to mechanically replace a Korean word in every sentence.
Each future entry must be rewritten from its meaning contract and checked in context.

## Formatting rules

- Preserve internal units and numeric values. Convert km/h to mph only at display time.
- Use baseball innings notation such as `6⅔ IP` in English.
- Preserve the simulation's actual metric names. Use `2.84 RA9`, `.286 AVG`, and `1.24 WHIP`
  as compact English stat labels; never relabel an RA9 value as ERA.
- Keep contract and reward amounts in KRW. Never convert them to USD.
- Preserve dates, ordering, RNG consumption, choice effects, analytics event names, save keys, and content IDs.
- User-entered names are not translated or transliterated.

## Key and review rules

- Production keys are semantic IDs such as `settings.audio.title` and
  `event.evt-catcher-sign.quote.low`; a Korean sentence is never a key.
- Typed copy references carry only IDs and typed arguments. They do not enter saves, RNG, event hashes,
  or analytics event names.
- Every completed key has both `ko` and `en` values, matching placeholder signatures, and a review
  status of `ui_verified`.
- Missing English copy never falls back to Korean. Release-safe resolution returns `Text unavailable`.
- Debug/Test resolution asserts on missing keys or placeholder mismatches.

## Review sequence

1. Read the existing source and call context.
2. Confirm the stable ID, conditions, variables, choices, and effects.
3. Write the meaning contract: event, player task, cost/risk/reward, certainty, and tone.
4. Lock the Korean value without changing behavior.
5. Write English from the contract rather than translating sentence order.
6. Check facts, uncertainty, variables, terminology, proper names, and length.
7. Verify the rendered UI, notification, share surface, and VoiceOver copy.

The Phase A catalog is a compile-safe spike, not a complete release catalog.
