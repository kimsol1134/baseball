# Unity 에셋 매니페스트 메모

## 결과

`tools/import-ios-assets-to-unity.mjs`는 iOS 원본을 손으로 재명명하지 않고 Unity 로컬 에셋으로 이관한다.
현재 `baseball-unity-asset-manifest-v1` 결과는 다음과 같다.

- xcassets `Contents.json`: 121개 검사
- 런타임 이미지: 118개
- Android 아이콘 파이프라인 원본/파생 대상: 7개
- 오디오: 24개
- 보존한 크레딧: `apps/ios/Audio/CREDITS.md` 1개
- 매니페스트가 추적하는 대상 파일: 149개(크레딧 제외)
- 매니페스트 SHA-256: `1a0cef0e45fc7fa0fb3f6ad7a2546ed4ef69d44516d0e9926d5e12e8c4e417f2`

매니페스트는 `apps/android-unity/Assets/Game/Content/Manifests/asset-manifest.json`에 있다. 생성 시각처럼 매번
달라지는 값은 기록하지 않으므로 동일 원본에서는 바이트 단위로 같은 JSON이 나온다.

## 명령

```bash
node tools/import-ios-assets-to-unity.mjs
node tools/import-ios-assets-to-unity.mjs --check
node tools/check-unity-assets.mjs
```

첫 명령은 checksum이 다른 파일만 복사한다. 기본 실행은 알 수 없는 파일을 삭제하지 않는다. 이전 매니페스트가 관리하던
대상 중 현재 원본에서 사라진 파일까지 정리해야 할 때만 `--prune`을 명시한다. `--check`는 파일을 쓰지 않고 원본 inventory와
현재 매니페스트가 같은지 확인한다.

`check-unity-assets.mjs`는 다음을 함께 검사한다.

- 원본/대상/매니페스트 SHA-256 일치
- logical key와 대상 경로의 대소문자 충돌
- 누락되거나 매니페스트 밖에 있는 이미지·오디오
- 허용한 import preset과 Local Addressables label
- 오디오마다 `CREDITS.md`의 원본 또는 변주 원본 항목 존재
- 복사한 크레딧이 iOS 원본과 바이트 단위로 동일함

## 이미지 선택과 분류

일반 imageset은 standard appearance 중 가장 높은 scale 파일 하나를 Unity 원본으로 고른다. 예를 들어 `LaunchLogo`는
720×720인 `LaunchLogo@3x.png`를 `Art/Bootstrap/LaunchLogo.png`로 복사한다. Unity는 하나의 고해상도 Sprite를 기기 scale에
맞춰 사용하므로 1x/2x/3x를 모두 번들에 넣지 않는다. 선택하지 않은 후보 경로도 `sourceCandidates`에 남는다.

AppIcon은 런타임 Addressable이 아니다. `AppIcon`, `AppIcon-Dark`, `AppIcon-Tinted` 세 원본을
`Art/PlatformIcons`로 분리해 Android adaptive/monochrome icon 생성 단계가 명시적으로 선택하도록 했다.
알림용 `baseball_notification_small.png`는 승인된 `AndroidMonochrome.png`(white + alpha)를
`Assets/Plugins/Android/BaseballManifest.androidlib/res/drawable`로 바이트 그대로 복사하는 매니페스트 대상이다. 런타임은 이 resource ID를
`AndroidNotification.SmallIcon`에 명시하며, 기본 아이콘이나 색이 채워진 launcher bitmap에 기대지 않는다.
`LaunchBackground.colorset`은 bitmap으로 만들지 않고 `BaseballTheme.cs`와 `theme.uss`의 canvas 토큰으로 유지한다.

분류는 `Bootstrap`, `KeyArt`, `Portraits`, `Presets`, `Scenes`, `Memories`, `Tournaments`, `Pitch`, `Meta`,
`PlatformIcons`이며 logical asset name의 대소문자를 보존한다.

## Unity import preset

`Assets/Game/Editor/Import/UnityAssetManifestImporter.cs`가 매니페스트를 읽고 TextureImporter/AudioImporter를 고정한다.

- UI/key art/portrait: Sprite, mipmap off, sRGB, Clamp, Android ETC2
- pitch billboard: Sprite, mipmap on, Android ETC2
- platform icon source: Default texture, 무압축 RGBA32
- 짧은 효과음: mono, Decompress on Load, ADPCM, preload
- crowd loop: Streaming, Vorbis, background load, preload off

`crowd-loop`만 Android/Unity가 안정적으로 읽는 파생물을 재현 가능하게 만든다. iOS의 ALAC `.m4a`
(SHA-256 `9c70cea7ce03d0c46cca5b7315cf6690fdda7df670c5f0f0dce43b2f3ee184c4`)를 ffmpeg의
`-map_metadata -1 -fflags +bitexact -flags:a +bitexact -c:a pcm_s16le -ar 44100 -ac 2`로 변환한다.
결과는 14초, 44.1 kHz, 16-bit signed PCM, stereo WAV이며 SHA-256은
`ecc7a9143df6e0ede59bc54db4b44578386bf1a8664f3c5c1aff6aa06d99389f`다. 매니페스트의
`ffmpeg-pcm-s16le-44100-stereo-bitexact-v1` 변환 표식과 source/target checksum을 검사기가 함께 검증한다.
Unity import 단계에서는 이 WAV를 Streaming/Vorbis/background-load/preload-off로 고정하고 런타임 AudioSource의
`loop=true`로 반복한다.

`addressableLabel`은 `bootstrap`, `setup`, `highschool`, `pro`, `pitch`, `meta`, `audio` 중 하나다. 이관기는 원격 URL이나
remote catalog를 만들지 않는다.

## Google Play 스토어 이미지

런타임 Addressables와 Play Console 업로드 소재는 서로 다른 배포 경계다. 스토어 소재는
`apps/android-unity/StoreAssets`에 두고 `baseball-android-store-assets-v1` 매니페스트로 별도 고정한다.

- `StoreIcon-512x512.png`: 512×512, 8-bit RGB, 승인된 AppIcon에서 리사이즈
- `FeatureGraphic-1024x500.png`: 1024×500, 8-bit RGB, 기존 키아트·한국어 로고를 참조한
  imagegen 보조 독자 구성
- 실제 게임 스크린샷: 서명 AAB와 물리 스마트폰 증거가 생기기 전에는 생성·대체하지 않음

`npm run check:android:unity`가 두 PNG의 IHDR 크기·색상 형식·SHA-256과 참조 원본 해시를
fail-closed로 확인한다. 제작 브리프와 교체 절차는 `apps/android-unity/StoreAssets/README.md`에 있다.

## 한국어 UI 폰트

런타임 UI는 기기별 OS 폰트에만 기대지 않는다. Pretendard 1.3.9 공식 릴리스의 원본 OpenType
`Pretendard-Regular.otf`와 `Pretendard-Bold.otf`를
`Assets/Game/Presentation/Common/Resources/Fonts`에 번들했다. 저작권은 Kil Hyung-jin 및 Pretendard 기여자에게 있으며
SIL Open Font License 1.1 전문을 같은 폴더의 `LICENSE.txt`로 보존한다.

- 공식 릴리스: `https://github.com/orioncactus/pretendard/releases/tag/v1.3.9`
- Regular SHA-256: `3ffbacde6ab8411f1d2db54bb9b1f0b3ee2a738932033722cf0388c06aed1c93`
- Bold SHA-256: `2e91915fab54df71cc9598ebf608b2bdb54c6fe3c066ac61dff0bc44fca71cc7`

`KoreanFontTextSettings`가 두 원본에서 multi-atlas dynamic TextCore `FontAsset`을 만들고 runtime `PanelSettings.textSettings`의
default/fallback에 지정한다. 현대 한글 줄바꿈 규칙도 켠다. USS에도 Regular resource를 기본 font definition으로 선언해
초기 프레임부터 동일한 폰트를 사용한다.

## 남은 통합 확인

- Addressables group/profile과 Local LZ4 bundle 연결은 Unity import로 생성·검토했고,
  PlayMode 및 16KB Android 내부 smoke의 airplane-mode 재실행에서 통과했다.
- `crowd-loop.wav`의 시작/끝 경계가 실제 Android 기기에서 매끄럽고 audio-focus 복귀 뒤 정상 재개되는지는 RC 기기에서
  청감 확인해야 한다. ALAC 컨테이너 지원 여부는 더 이상 빌드 경로의 조건이 아니다.
- adaptive foreground/background와 monochrome icon 소스와 Editor 적용 코드는 완료됐고 내부 검증
  launcher에서 생성·설치됐다. production 물리 launcher의 mask/safe-zone 육안 확인은 남는다.
- 알림 small icon은 매니페스트와 source contract로 고정됐지만, Android 8~15 실제 기기에서 상태 표시줄/알림 서랍의
  tint와 축소 가독성은 RC 빌드로 확인해야 한다.
- Unity 6000.3.19f1 batchmode import, EditMode/PlayMode, 내부 IL2CPP AAB가 통과했고 missing `.meta`는 0이다.
  같은 산출물을 clean production-candidate commit으로 고정한 뒤 물리기기에서 최종 확인한다.
