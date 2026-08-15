# Dependency and toolchain lock

The first pass keeps versions explicit in `apps/android/gradle/libs.versions.toml` and records the
resolved Android app graph in `apps/android/app/gradle.lockfile`.

| Component | Pin |
|---|---|
| Gradle wrapper | 9.1.0 |
| Android Gradle Plugin | 9.0.0 |
| Kotlin / Compose compiler plugin | 2.2.10 |
| Compose BOM | 2026.06.01 |
| Activity Compose | 1.12.4 |
| AndroidX Core KTX | 1.17.0 |
| JUnit | 4.13.2 |
| Android compile/target | API 36 |
| Android minimum | API 26 |
| Unity editor | 6000.3.19f1 revision 7689f4515d75 |
| Unity backend/ABI | IL2CPP, ARM64, OpenGL ES 3 |

The generated Unity Gradle project is normalized only by
`tools/normalize-android-pitch-unity-export.mjs` for the isolated export-to-app property handoff.
Generated source is not hand-maintained. The app ID is a shadow migration ID; production package
and signing configuration are intentionally not changed.
