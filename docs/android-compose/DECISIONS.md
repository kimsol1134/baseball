# First-pass boundary decisions

These decisions make the vertical path safe to extend.

## Kotlin owns

- game state, persistence, revisions, save-before-publish ordering, and recovery;
- Compose screens, navigation, pitch HUD/input/result, accessibility, and platform orchestration;
- authoritative pitch/gameplay results and analytics caller semantics;
- the immutable `PitchPresentationRequest` sent to Unity;
- duplicate, stale, replay, lifecycle, and terminal acknowledgement acceptance.

## Unity owns only

- one full-screen runtime surface for the pitch session;
- ball mesh, trail, bounded trajectory interpolation, camera, and contact/impact visuals;
- presentation markers and a terminal presentation acknowledgement.

Unity has no career/save/result reducer, no player identity, no score authority, no analytics SDK,
and no product UI shell.

## Runtime lifecycle

`MainActivity` is Compose-only. `PitchUnityActivity` creates one concrete Unity 6
`UnityPlayerForActivityOrService` and one native overlay. `UnityRuntimeHost` uses the public
`IUnityPlayerLifecycleEvents` interface through reflection so the JVM modules still compile when
the generated export is absent. The normal Compose return path calls `pauseAndDetach`, retaining the
same Activity/player for same-process re-entry; an explicit host close calls `UnityPlayer.unload()`
and waits for `onUnityPlayerUnloaded`. The Activity intercepts Compose return, system back, and back
key dispatch, and reattaches the Unity view at index zero so the Kotlin overlay keeps input
ownership. The local emulator re-entered a second pitch in the same important-game session without
constructing a second runtime. `UnityPlayer.quit()` is never called.

## Generated output boundary

`apps/android-pitch-unity` and the export scripts are source. `artifacts/android-compose/unity-export`
and APK/build output are generated, ignored artifacts. The generated `unityLibrary` is consumed by
Gradle only after the export wrapper produces it; it is not hand-edited or treated as source.
