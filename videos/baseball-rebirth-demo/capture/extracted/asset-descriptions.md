# Canonical asset inventory

- `capture/screenshots/game-01-intro.png` — 1920×1080 actual browser intro: title, pitcher key art, primary CTA, and player dossier.
- `capture/screenshots/game-02-read-and-choose.png` — 1920×1080 actual play screen before pitch one: batter read, pitch cards, 3×3 zone, and release control.
- `capture/screenshots/game-03-hold-release.png` — 1920×1080 actual play screen while the release meter is moving through the target window.
- `capture/screenshots/game-04-first-life-hit.png` — 1920×1080 actual failure result showing `끝내기 안타` after the expected middle pitch.
- `capture/screenshots/game-05-memory-choice.png` — 1920×1080 actual game-over screen with the three inherited-memory choices.
- `capture/screenshots/game-06-memory-selected.png` — 1920×1080 actual game-over screen with `포수의 노트` selected and next-life CTA enabled.
- `capture/screenshots/game-07-next-life.png` — 1920×1080 actual third-life play screen with two inherited memories and a revealed recommended course.
- `capture/screenshots/game-08-strike-one.png` — 1920×1080 actual first-strike review screen after countering the batter's read.
- `capture/screenshots/game-09-batter-adapts.png` — 1920×1080 actual next-pitch screen showing that the batter now expects the previous pitch and the counter has changed.
- `capture/screenshots/game-10-strikeout.png` — 1920×1080 actual terminal review screen showing `헛스윙 삼진`.
- `capture/screenshots/game-11-victory.png` — 1920×1080 actual drafted ending with fictional club call and final scout report.
- `capture/screenshots/game-contact-sheet.jpg` — contact sheet of the eleven deterministic gameplay states in chronological order.
- `capture/screenshots/full-page.png` — 1920-wide full-page capture produced by HyperFrames; source of truth for the intro layout.
- `capture/assets/hero-key-art.png` — existing cinematic rear-view pitcher artwork used by the intro.
- `capture/assets/scene-game.webp` — existing pitcher-versus-batter artwork suited to the gameplay setup.
- `capture/assets/scene-legacy.webp` — existing reflective baseball artwork used by the failure and inheritance beat.
- `capture/assets/scene-rookie.webp` — existing rookie portrait used in the final scout report.
- `capture/assets/scene-draft.webp` — existing phone-call artwork used by the drafted ending.
- `capture/assets/icon.png` — square fictional-game icon; use only as a compact brand mark.

All game-state PNG files were captured from `http://localhost:3000/` with a fresh local save and deterministic keyboard inputs. They are the visual source of truth; do not rebuild the full interface or invent unavailable states.
