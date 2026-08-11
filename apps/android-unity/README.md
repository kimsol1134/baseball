# Android Unity port

This directory is a Unity **6000.3.19f1** project for the portrait Android port.
The checked-in bootstrap scene is intentionally empty: `AppRoot` is created before
scene load and persists across scenes. Feature scenes and presentation composition
are separate workstreams.

## Assembly boundaries

- `Baseball.Core` has no assembly references and sets `noEngineReferences: true`.
- `Baseball.Application` references Core and `Unity.Newtonsoft.Json`, also with
  `noEngineReferences: true`.
- `Baseball.Bootstrap` is the narrow Unity lifecycle adapter. It owns
  `Application.persistentDataPath`, pause/resume, and low-memory callbacks. It may
  depend on Platform, but Platform must never depend on Bootstrap.
- EditMode tests are isolated test assemblies and are excluded from players.

Game state must remain in immutable Core/Application snapshots. A scene or view must
dispatch a typed command instead of mutating state directly.

The Unity 6000.3.19f1 package graph is exact-version locked: URP 17.3.0,
Input System 1.19.0, Addressables 2.9.1, Mobile Notifications 2.4.3,
Newtonsoft Json 3.2.2, and Test Framework 1.6.0. The lock also records the full
resolved transitive closure; no floating Git dependency is used.

## Save contract

`AtomicSaveRepository<TPayload>` writes this layout under the injected save directory:

```text
save.json
save.tmp
save.bak.1
save.bak.2
save.bak.3
save.corrupt.<UTC>.<origin>.json
```

The envelope fixes schema `android-unity-save-v1`, schema version `1`, decimal-string
revision, UTC write time, and a SHA-256 over canonicalized payload JSON. Writes perform
payload validation and a serialize/deserialize round trip before touching the canonical
file, flush `save.tmp`, rotate only a valid canonical into three backups, atomically
replace it, and verify the committed checksum and revision. Any post-swap failure rolls
the previous canonical bytes back.

Loads trust a valid canonical first. If it is corrupt, all backups are checked and the
highest valid revision wins; an injected semantic-priority policy breaks equal-revision
ties. The corrupt canonical is quarantined and the recovered backup becomes canonical.
A future schema and an older unmigrated schema are preserved without overwrite.
Explicit reset removes temp/backups/quarantine before deleting canonical last, then
verifies that no save candidate can be recovered.

`PersistentStore<TState,TCommand>` serializes command execution, enforces command IDs,
revision preconditions, revision `+1`, and durable receipts. It publishes the new state
only after `IStateSaver.SaveAsync` succeeds. Downstream UI and analytics observers cannot
turn an already durable command into a failure.

The top-level aggregate is currently version `3`. Version `2` adds save-backed product
settings and version `3` adds analytics one-shot receipts. Lifetime receipts are never
evicted; only scoped time-series receipts use a bounded 512-entry LRU. Return-plan
experiment assignment, anonymous receipt, Seoul saved-day key, development-rules version,
same-day welcome handling, and the pledge recap suggestion are in the same aggregate.
The recap suggestion is not an active next-run choice until `SetNextRunIntentCommand`
itself saves successfully.

`Assets/Game/Application/Persistence/link.xml` preserves `Baseball.Core`,
`Baseball.Application`, `Baseball.Presentation`, and `Unity.Newtonsoft.Json`. These are
reflection targets for opaque HighSchool/Pro snapshots and pitch request/result,
presentation, and checkpoint DTOs. A static test fails if one of these preservation
entries is removed.

## Runtime composition

`AppRoot` captures Unity's main-thread synchronization context, obtains the anonymous
install ID from Android's `noBackupFilesDir`, and opens a real
`AtomicSaveRepository<GameSaveAggregate>`. The aggregate is validated with
`GameSaveValidator` and uses `GameSaveSemanticPriority`; career commands are delegated
to `CoreHighSchoolCareerPort` and `CoreProCareerPort`.

Scene-level composition can observe the runtime without constructing a mock store:

```csharp
RuntimeGameServices.Ready += HandleStoreReady;
if (RuntimeGameServices.TryGetStore(out var store)) HandleStoreReady(store);
```

`Ready`, `StoreChanged`, `BecameUnavailable`, and `StartupFailed` are published on the
captured Unity main thread. Event subscribers are isolated from one another. The store's
`StatePublished` event remains the source for subsequent save-backed state changes.
Presentation may reference both `Baseball.Bootstrap` and `Baseball.Application` to
consume this boundary and the store type it exposes. Dependencies continue in one
direction; Platform must not add a reverse Bootstrap or Presentation reference.

## Validation

Expected Unity command:

```bash
UNITY_BIN=/Applications/Unity/Hub/Editor/6000.3.19f1/Unity.app/Contents/MacOS/Unity

"$UNITY_BIN" -batchmode -nographics -quit \
  -projectPath /Users/solkim/Dev/baseball/apps/android-unity \
  -runTests -testPlatform EditMode \
  -testResults /tmp/baseball-editmode.xml \
  -logFile /tmp/baseball-unity-editmode.log
```

On the current machine this command stops with exit `198` because no valid Unity Editor
license is activated. Android Build Support is present with API 36/build-tools 36.0.0,
NDK r27c, and OpenJDK 17.0.18; those modules were installed externally, not by repository
code. License activation is therefore the remaining prerequisite for Unity EditMode and
Android AAB execution.

As a license-independent check, Application, Bootstrap, and Core compile against
`.NET Standard 2.1`; a second compile includes AppRoot and the Unity 6000.3.19f1
`UnityEngine.CoreModule` reference. The persistence, application, Core adapter, and
Bootstrap lifecycle suites cover recovery, save-before-publish, snapshot resume,
duplicate callbacks, exception isolation, main-thread publication, and idempotent
disposal. Unity EditMode and Android IL2CPP round-trip tests remain the release authority
once those external prerequisites are available. Static Newtonsoft round trips and
`link.xml` validation cannot prove managed-code stripping behavior; an actual IL2CPP AAB
build and on-device process-restart round trip remain blocked solely by the expired
offline Unity Personal entitlement described above.
