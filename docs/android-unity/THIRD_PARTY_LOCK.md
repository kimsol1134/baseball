# Android Unity 서드파티 잠금

기준일: 2026-08-11
Unity: `6000.3.19f1`
원칙: 공식 배포물, exact version, Android에 필요한 모듈만 사용한다. 비밀값과 환경별 앱 설정은 이 문서나 소스에 넣지 않는다.

## Unity Package Manager

| 패키지 | 버전 | 공급/검증 | SHA-256 |
|---|---:|---|---|
| `com.unity.addressables` | 2.9.1 | Unity Registry tgz | `06dc6b4a4f29c7f1337394157f6a06b29ffdec059be612fded1dd4dbd393225e` |
| `com.unity.inputsystem` | 1.19.0 | Unity Registry tgz | `4a08d3d4ad260da37a0dd76c4575bb860a1d85fe305cf76b7c1a0de70496389c` |
| `com.unity.mobile.notifications` | 2.4.3 | Unity Registry tgz | `76cb026f5d5e9e235fb8ea35fdc28a5e2ae5705505912beee89a7ef373473563` |
| `com.unity.nuget.newtonsoft-json` | 3.2.2 | Unity Registry tgz | `5db19a6ec4478ab974922d155aa32b952bc34abadaa78afc7973cf049b62db41` |
| `com.unity.render-pipelines.universal` | 17.3.0 | Unity 6000.3.19f1 built-in | 설치 디렉터리 tree hash `886c767186c3ace723e55b65e2978d18a152d2fc70dadf4fe63d9696d7ad7c20` |
| `com.unity.test-framework` | 1.6.0 | Unity 6000.3.19f1 built-in | 설치 디렉터리 tree hash `0b906b175560276bbc3a2e527a53f9fed535c38bab1ecc24561dd55faef59f55` |

Registry 다운로드 형식은 `https://packages.unity.com/{package}/-/{package}-{version}.tgz`다. 실제 잠금은 [manifest.json](../../apps/android-unity/Packages/manifest.json)과 [packages-lock.json](../../apps/android-unity/Packages/packages-lock.json)이 담당한다.

## Firebase

| 항목 | 잠금 |
|---|---|
| Unity SDK | 13.14.0 |
| Firebase CLI (CI symbols upload only) | 15.26.0 |
| 공식 archive | `https://dl.google.com/firebase/sdk/unity/firebase_unity_sdk_13.14.0.zip` |
| archive SHA-256 | `186cc002d4a0ffdb823beb9645ab47a2415658e4821b1fa7438dc0b6d363cbf2` |
| import | `FirebaseAnalytics.unitypackage`, `FirebaseCrashlytics.unitypackage`만 |
| 라이선스 | Apache-2.0, `Assets/Firebase/LICENSE` |

Android 직접 의존성:

| Maven artifact | 버전 |
|---|---:|
| `com.google.firebase:firebase-common` | 22.1.0 |
| `com.google.firebase:firebase-analytics` | 23.2.0 |
| `com.google.android.gms:play-services-base` | 18.10.0 |
| `com.google.firebase:firebase-crashlytics-ndk` | 20.1.0 |
| `com.google.firebase:firebase-app-unity` | 13.14.0 |
| `com.google.firebase:firebase-analytics-unity` | 13.14.0 |
| `com.google.firebase:firebase-crashlytics-unity` | 13.14.0 |

원본 package의 iOS/tvOS 정적 라이브러리와 데스크톱 x86_64 네이티브 바이너리는 Android-only 제품에 포함하지 않았다. 관리 DLL, Android local Maven repository, Editor dependency metadata와 원본 version manifest는 유지한다.

`google-services.json`은 Firebase Console에서 `com.solkim.baseball.android` 앱을 등록한 뒤 별도로 받아야 한다. 파일이 없을 때 Analytics/Crashlytics는 게임을 막지 않으며 기본 runtime config는 전송을 끈다. 서명 RC workflow는 서비스 계정의 Application Default Credentials로 `firebase-tools@15.26.0 crashlytics:symbols:upload`를 실행하고 성공 로그/영수증을 AAB와 함께 보관한다. Firebase CLI는 런타임 또는 Unity 프로젝트 산출물에 포함하지 않는다.

## Amplitude

| 항목 | 잠금 |
|---|---|
| 공식 저장소/tag | `https://github.com/amplitude/unity-plugin`, `v2.8` |
| tag commit | `28b74ce7e1c90c916a91cb01c1d106e00ecbf649` |
| 공식 asset | `https://github.com/amplitude/unity-plugin/releases/download/v2.8/amplitude-unity-no-edm-and-dep.unitypackage` |
| asset SHA-256 | `758d56ae65900f34727c6a524e812c2df339c966f2efadb0e8ae00b0adcab671` |
| package 내부 metadata | 2.7.0(공식 v2.8 asset의 upstream metadata) |
| 라이선스 | MIT, `Assets/Amplitude/LICENSE.md` |

Android 직접 의존성은 `com.amplitude:android-sdk:2.40.1`, `com.squareup.okhttp3:okhttp:4.2.2`다. upstream의 floating `2.40.+` 선언은 재현성을 위해 `2.40.1`로 고정했다. iOS native plugin은 포함하지 않았다. API key가 없으면 destination은 생성되지 않는다.

## Google Play In-App Review

공식 Google Unity archive에서 UPM tgz 세 개를 embedded package로 보관한다.

| 패키지 | 버전 | 공식 tgz | SHA-256 |
|---|---:|---|---|
| `com.google.play.review` | 1.8.3 | `https://dl.google.com/games/registry/unity/com.google.play.review/com.google.play.review-1.8.3.tgz` | `be7396c8479c8929747adbb08995b2b2c73326679ac0694382c00957f361efcc` |
| `com.google.play.common` | 1.9.2 | `https://dl.google.com/games/registry/unity/com.google.play.common/com.google.play.common-1.9.2.tgz` | `b5e553317f0607e03baee0eb7614cd8b3acfda6c1d84723829853047d2d074d6` |
| `com.google.play.core` | 1.8.5 | `https://dl.google.com/games/registry/unity/com.google.play.core/com.google.play.core-1.8.5.tgz` | `2de4e5a9139308cc264448071d5aa3c88704a315d3b6b86caf65d2e68c07e048` |

라이선스는 각 embedded package의 `LICENSE.md`에 있다(Apache-2.0 및 Play Core SDK Terms). Android 직접 의존성은 `com.google.android.play:review:2.0.2`, `com.google.android.play:core-common:2.0.4`다.

재현성/중복 방지를 위해 두 가지 최소 patch를 적용했다.

- review package의 `review:2.0.0`을 Google Android 공식 현재 버전 `2.0.2`로 고정했다.
- core package의 EDM4U 1.2.172 UPM 의존성은 제거했다. Firebase가 공급한 더 최신 단일 사본 1.2.188을 `Assets/ExternalDependencyManager`에서 사용한다.

## Pretendard 한국어 UI 폰트

| 항목 | 잠금 |
|---|---|
| 공식 저장소/release | `https://github.com/orioncactus/pretendard`, `v1.3.9` |
| 공식 archive | `https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip` |
| 배포 경로 | archive의 원본 `public/static/Pretendard-{Regular,Bold}.otf`를 변환 없이 추출 |
| Regular SHA-256 | `3ffbacde6ab8411f1d2db54bb9b1f0b3ee2a738932033722cf0388c06aed1c93` |
| Bold SHA-256 | `2e91915fab54df71cc9598ebf608b2bdb54c6fe3c066ac61dff0bc44fca71cc7` |
| 라이선스 | SIL Open Font License 1.1, `Assets/Game/Presentation/Common/Resources/Fonts/LICENSE.txt` |

웹 데모의 WOFF2를 역변환하지 않는다. 공식 release OTF를 그대로 사용하므로 Reserved Font Name과 변형 폰트 재명명 문제를 피한다.
Unity runtime에서만 multi-atlas dynamic TextCore FontAsset을 메모리에 생성하며 원본 OTF 바이트는 수정하지 않는다.

## External Dependency Manager for Unity

| 항목 | 잠금 |
|---|---|
| 버전 | 1.2.188 |
| 공급 | Firebase Unity SDK 13.14.0 archive에 포함된 공식 사본 |
| 라이선스 | Apache-2.0, `Assets/ExternalDependencyManager/Editor/LICENSE` |
| version manifest | `Assets/ExternalDependencyManager/Editor/external-dependency-manager_version-1.2.188_manifest.txt` |

프로젝트에는 EDM4U 사본이 하나만 있다. Unity 라이선스 갱신 뒤 resolver를 실행해 생성된 Gradle dependency tree와 merged manifest를 릴리스 증거에 첨부해야 한다.

## 금지 SDK 확인

Unity Ads, Unity Analytics, Unity IAP, Unity Authentication, Play Games Services는 설치하지 않는다. 광고 ID, Android ID, App Set ID와 위치 기반 자동 수집 API도 호출하지 않는다.

## 아직 외부에서 공급해야 하는 값

- production `google-services.json`
- production Amplitude API key가 들어간 `analytics-config.generated.json`
- Crashlytics symbol upload 권한을 가진 Firebase CI 서비스 계정 JSON
- Play upload keystore/alias/password 환경변수
- 개인정보처리방침 HTTPS URL

이 값이 없더라도 오프라인 게임과 로컬 저장은 동작해야 하며, RC 서명/전송 검증만 차단된다.
