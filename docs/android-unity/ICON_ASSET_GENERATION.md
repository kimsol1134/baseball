# Android 런처 아이콘 생성 기록

기준 원본: `apps/android-unity/Assets/Game/Art/PlatformIcons/AppIcon.png`
생성 방식: Codex built-in image generation/editing + chroma-key alpha 제거
생성일: 2026-08-11

## 결과

| 파일 | 역할 |
|---|---|
| `AndroidAdaptiveBackground.png` | Android adaptive icon의 불투명 배경. 기존 구장/도시/노을을 유지하고 홈 플레이트만 제거했다. |
| `AndroidAdaptiveForeground.png` | adaptive icon safe zone 안의 금빛 홈 플레이트 전경. 투명 PNG다. |
| `AndroidMonochrome.png` | Android 13+ themed icon용 단색 전경. foreground와 같은 alpha mask를 쓴다. |

세 파일은 1024×1024다. Foreground 비투명 bounding box는 650×400이며 1024 기준 중앙 safe zone 안에 위치한다.

## 배경 편집 prompt

```text
Use case: precise-object-edit
Asset type: Android adaptive launcher icon background layer, square 1024x1024
Primary request: Starting from the reference iOS app icon, remove only the raised glowing home plate object in the lower foreground and naturally reconstruct the infield dirt and chalk lines beneath it. Preserve the exact fictional Korean-city baseball stadium, sunset skyline, lighting, perspective, colors, photographic realism, and all other composition. Keep the central sunset glow and enough visual detail after circular/squircle launcher masks.
Constraints: background layer must be fully opaque edge-to-edge; no isolated logo object; no team marks, real league branding, text, letters, watermark, border, or transparent pixels. Change only the home plate object and the small patch it occupied.
```

## 전경 편집 prompt

```text
Use case: background-extraction
Asset type: Android adaptive launcher icon foreground layer, square 1024x1024
Primary request: Isolate and faithfully recreate only the luminous raised golden baseball home plate emblem from the reference icon. Keep its pentagonal shape, worn stone-and-metal texture, thin dark bevel, warm sunset rim light, and premium realistic finish. Place the emblem centered horizontally with its visual center around 60% of the canvas height; approximately 42% of canvas width so it stays inside Android adaptive-icon safe masks.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for removal.
Constraints: the background must be one uniform #00ff00 with no gradient, texture, floor, shadow, reflection, halo outside the object, or lighting variation. The plate must have crisp separated edges and generous padding. Do not use #00ff00 anywhere in the plate. No stadium, skyline, baseball, people, team marks, real league branding, text, letters, watermark, or border.
```

Chroma key는 imagegen skill의 `remove_chroma_key.py`에서 border auto-key, soft matte, despill을 사용했다. Monochrome는 최종 foreground의 RGB만 흰색으로 바꾸고 alpha를 픽셀 동일하게 유지했다.
