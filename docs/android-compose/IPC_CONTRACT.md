# Pitch presentation IPC contract

Schema: `baseball-pitch-ipc-v1` · `schemaVersion: 1` · maximum UTF-8 message size: 64 KiB ·
maximum trajectory points: 64.

Both sides implement the same bounded contract:

- Kotlin: `apps/android/game-model/.../PitchIpcModels.kt` and
  `apps/android/unity-bridge/.../PitchIpcCodec.kt`;
- Unity C#: `apps/android-pitch-unity/Assets/PitchRuntime/Bridge/PitchIpcWire.cs` and
  `PitchBridgeReceiver.cs`.

Every command and acknowledgement contains `schema`, `schemaVersion`, `messageId`, `sessionId`,
and `presentationSeed`. A play command additionally contains an immutable, hash-checked
`PitchPresentationRequest` with `requestId`, `pitchId`, sequence, integer trajectory points, visual
policy, and `requestSha256`.

## Native → Unity commands

`initializeBridge`, `setQualityTier`, `playPresentation`, `pausePresentation`,
`resumePresentation`, and `cancelPresentation`.

Initialize and lifecycle commands reject request/quality payloads. Play requires the request and
matching presentation seed. Unknown commands, schema versions, enums, malformed JSON, bounds
violations, hash mismatches, stale sessions, and additive fields not covered by the strict bridge
codec fail closed.

## Unity → native acknowledgements

`unityReady`, `presentationStarted`, `presentationMarker` (release, plate, impact),
`presentationCompleted`, `presentationFailed`, `presentationPaused`,
`presentationResumed`, `presentationCancelled`, and `unityUnloaded`.

Terminal acknowledgements include `terminal.status`, `pitchId`, and `requestSha256`. Kotlin accepts
only the active session/request, requires started → ordered markers → terminal, and ignores exact
duplicates while rejecting message-ID reuse and stale/replayed payloads. The Unity receiver keeps
its own message fingerprint table and rejects a second live presentation.

The contract is presentation-only. A terminal acknowledgement never becomes a gameplay result; it
only tells Kotlin that the requested visual finished or failed.
