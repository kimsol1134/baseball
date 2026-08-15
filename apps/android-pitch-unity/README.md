# Pitch-only Unity library source

This Unity 6 project is the presentation side of the migration boundary. It exports one generated
`unityLibrary` for the real Android host. The source contains only the bounded bridge, trajectory
renderer, ball/trail material, and a fixed camera/scene.

`bash
../../tools/export-android-pitch-unity.sh
`

The output under `artifacts/android-compose/unity-export/` is generated and ignored. Do not hand
edit it or move gameplay/save authority into this project. Kotlin owns the pitch result, HUD,
input, persistence, and terminal acceptance.
