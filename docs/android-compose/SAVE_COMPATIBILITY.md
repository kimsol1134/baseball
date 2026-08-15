# Legacy save compatibility harness

The Phase 6 harness remains a read/re-encode and shadow-read contract; it does not enable writes in
the .compose.dev package and does not delete or migrate the current save directory. Phase 10 adds
a separately gated nativeAuthoritative internal package that writes the frozen legacy envelope
only through the atomic repository for the exercised settings command.

## Current fixture provenance

The fixtures were pulled from the current oracle emulator save location before the harness was
written and are retained as test resources:

| Fixture | Path | SHA-256 |
|---|---|---|
| current | `apps/android/game-persistence/src/test/resources/legacy/save-v1-current.json` | `81a47127e2fbf5cf571afe8e1a70e528d6a043842b3d4e6c1ada3bd7cd746a42` |
| backup-1 | `apps/android/game-persistence/src/test/resources/legacy/save-v1-backup-1.json` | `efe1f772c383064e7e7a4326fa6468cb0b65acb7b6f25a4af7ad1e0733fd20f0` |

The current envelope is `android-unity-save-v1`, `schemaVersion: 1`, with decimal-string envelope
revision \"6\" and canonical payload SHA-256
`4de30c7533a3932ca5b9088c2dc6cde64d300bf246dd41afa0394dc38e123b7a`. The current C# payload
contains the aggregate revision as a JSON number; the decoder accepts that real representation as
well as a decimal string and compares the exact unsigned value.

## Harness guarantees

- strict UTF-8 JSON parsing with duplicate-key, trailing-data, depth, and size rejection;
- exact schema/version classification (valid, future, migration-required, invalid);
- canonical key-sorted payload hash verification;
- semantic checks for aggregate version, revision, install ID, stage, deletion flag, and receipts;
- unknown/additive envelope and payload fields survive decode/re-encode;
- corrupt, checksum-invalid, duplicate, unsupported, and incompatible inputs fail closed;
- `apps/android-unity` remains the oracle and its production save path is not touched by the
  shadow package;
- the Phase 10 internal writer uses `getExternalFilesDir(null)/save`, retains unknown root fields,
  rotates three backups, verifies the canonical read-back, and rejects typed writes and unported
  legacy commands;
- install-ID mismatch fails closed before a write, and `nativeShadowReadOnly` remains write-disabled.

Tests: `LegacySaveCodecTest` uses the real current fixture, exercises additive fields, and covers
corrupt/future/older cases. Phase 10's package, emulator, and rollback evidence is in
[PHASE10_CUTOVER_EVIDENCE.md](PHASE10_CUTOVER_EVIDENCE.md).
