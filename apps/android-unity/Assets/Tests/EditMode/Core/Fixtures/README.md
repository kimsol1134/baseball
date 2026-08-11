# Core translation fixtures

`core_translation_v1.json` is a translation oracle captured from the Swift `SimulationCore` at
commit `fe7b585c32f5819dc4cd61dd16b92af46ee22b87`.

- SplitMix64 and FNV-1a values were printed directly by Swift using the production constants.
- The pitch row uses the same `makePrepareParams` values as `PitchKernelEngineTests.swift`, seed
  `20260721`, and submits the primary catcher recommendation.
- `PitchKernelTranslationTests` intentionally repeats the values as constants. This avoids adding
  a JSON dependency to the pure Core test assembly while leaving a machine-readable provenance
  artifact for the future fixture exporter.
- `pitch_oracle_v2.json` was exported from the same Swift production input at commit
  `23acbb8ec233836e802009c8852c430e08075d3c`. It commits all outcome/location/velocity/event-hash
  fields for seeds 1...128 as one canonical FNV-1a digest, plus exact outcome counts for seeds
  1...10,000. `PitchKernelTranslationTests` rebuilds both gates from C# on every static/EditMode run.
