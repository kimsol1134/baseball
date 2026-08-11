# High-school cross-language fixtures

These fixtures pin deterministic rules that are shared with
`packages/simulation-core/Sources/SimulationCore`.

- `career_wind_v1.json` is copied from `CareerWindTests.testV1SelectorGoldenCompatibility`.
- schedule, goal, ranking, bracket, and community tests use the exact Swift salts and the same
  `SplitMix64`/FNV-1a implementation.
- `career_20260811.json` records values emitted by a Swift `SimulationCore` fixture probe. The C#
  suite checks the exact start, prologue completion, `mirae_analytics` school choice, and first
  standard command-training transition (next seed, event hash, state commitment, ratings, and
  fatigue), in addition to the Korean schedule/goal/ranking/bracket/community payload.

The fixture intentionally stores stable IDs, integer values, Korean copy, seeds, and hashes. It
does not serialize CLR enum names as a wire contract.

Run standalone NUnit from a project outside `Assets` (the verification runner uses
`/tmp/baseball-highschool-standalone`) so `bin`/`obj` and test-platform DLLs cannot be imported as
Unity plug-ins.
