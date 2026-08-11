# Android Unity Core port status

Updated: 2026-08-11 (Asia/Seoul)
Source baseline: `fe7b585c32f5819dc4cd61dd16b92af46ee22b87`

## Completed in the first bounded workstream

- Pure C# domain primitives, wire-value helpers, talent/personality rules, pitching metrics.
- Exact SplitMix64 and UTF-8 FNV-1a 64-bit implementations.
- Balance-v4 pitcher preset and repertoire catalog.
- Pitch delivery, scouting estimate, sign situation, rival memory, sequence recognition.
- Game/base/out, fielding, runner, inning, and game-analysis snapshots and deterministic engines.
- Deep caught-fly sacrifice advancement, including third-base scoring, second-to-third tag-up,
  shallow/ground-ball rejection, and the inning-ending third-out guard.
- `PreparePitch` / `SubmitPitch`, including stale-token rejection, deterministic pitch physics,
  batter plan, contact resolution, game-state updates, event stream, next preparation, and event hash.
- Core assembly sources have no `UnityEngine`, `UnityEditor`, `System.Random`, or wall-clock references.

## Translation evidence

- `Assets/Tests/EditMode/Core/Fixtures/core_translation_v1.json` records Swift vectors and provenance.
- SplitMix64 seeds `0`, `1`, and `UInt64.max`: first five values match Swift exactly.
- StableHash covers empty, ASCII, mixed case, Korean, and emoji UTF-8 strings.
- The seed `20260721` full prepare/submit fixture matches plan commitment, preparation token,
  recommendation, outcome, execution, next seed, event order, and event hash.
- A 128-seed grid matches Swift outcome, actual location, velocity, and event hash exactly. A
  10,000-seed first-pitch corpus also matches Swift's exact outcome counts; provenance and the
  canonical digest are recorded in `pitch_oracle_v2.json`.
- Standalone Core NUnit/.NET run: 46 tests passed. The integrated static suite passes 205 tests,
  including the 128-vector pitch oracle and exact 10,000-seed distribution gate. Unity batchmode
  was attempted but blocked before compilation because this machine has no valid Unity Editor
  license (`exit 198`).
- Persistence now uses invariant string encoding for envelope `ulong` revisions, camel-case string
  enum conversion, strict deserialization, checksum validation, and tested JSON round trips. Actual
  IL2CPP-device round-trip evidence remains blocked with the Unity/device gates.

## Deliberately deferred or scoped gaps

These do not affect the exact first-pitch oracle above, but should be closed before the full D2
distribution gate:

- EX-007: C# fielding records the authoritative landing distance, hang time, and apex, while Unity
  presentation interpolates the visual flight every frame instead of persisting Swift's 31-sample
  batted-ball series. Final outcome/runners/score are unaffected; visual-path parity is approximate.
- EX-008: double-play success and outs are authoritative, but C# does not select/name Swift's middle
  infielder pivot. Android v1 does not expose the pivot player's name in result UI or analytics.
- Legacy pitcher balance-v1/v2/v3 migration helpers are out of Android v1 scope: Android has a new
  save schema and does not import an iOS save. They become required if cross-platform save import is
  approved later.
- Re-run the EditMode suite in Unity once a valid editor license is available.
- Run the persistence round-trip suite on an IL2CPP Android device once a signed candidate and
  physical-device lane are available.
