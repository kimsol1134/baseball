# Compose Android app

Native Jetpack Compose host. The mound is a 2-cut canvas plus the hold-to-release slider.
Unity is not part of this product or its Gradle graph.

The launcher splash reuses the iOS `LaunchLogo@3x.png` verbatim as
`app/src/main/res/drawable-xxhdpi/launch_logo.png`, with the same `#080D0B`
background. Keep the copy synchronized when the iOS launch logo changes.
Android 8–11 centers it at 240dp; Android 12+ uses `launch_logo_system.xml`
to preserve the lettering inside the system splash mask. The launch theme is
scoped to `MainActivity` and restored to the normal app theme in `onCreate`.
Verified with a debug build and Android 15 emulator cold launch; screenshot:
`docs/assets/mobile-core/android-ios-launch-logo.png` (repository root).

The debug application ID is `com.solkim.baseball.android.compose.dev`.

For an isolated first-session QA install, build debug and its instrumentation APK with
`-PbaseballLaunchQa=true`. This uses `com.solkim.baseball.android.compose.qa` and leaves
the normal development and production saves intact. Remove the disposable QA package
after testing; never clear the production or development package to obtain a fresh run.

Add `-PbaseballQaNativeStore=true` with that QA flag to exercise the production legacy-envelope
writer and native career sidecars inside the isolated QA package. Ordinary debug uses the shadow
repository; shipping release always uses the native writer. Test both paths before a release.

```bash
./gradlew test --no-daemon --stacktrace
./gradlew :app:assembleDebug --no-daemon --stacktrace
```

C# save decode still lives in Kotlin (`CSharpLegacyGameStoreRepository`). The historical
`apps/android-unity` tree is an oracle, not a build dependency.
