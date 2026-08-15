# Compose migration app

This is the shadow-read-only Android shell for the Compose + pitch-only Unity migration. Its
application ID is intentionally `com.solkim.baseball.android.compose.dev`; it is not the
production package.

`bash
./gradlew test --no-daemon --stacktrace
cd ../..
./tools/export-android-pitch-unity.sh
cd apps/android
./gradlew :app:assembleDebug --no-daemon --stacktrace
`

The generated `unityLibrary` is included only when the export wrapper has produced
`artifacts/android-compose/unity-export/current/unityLibrary`. The oracle
`apps/android-unity` remains untouched and authoritative until migration gates pass.
