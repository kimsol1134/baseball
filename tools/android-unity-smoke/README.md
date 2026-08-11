# Android Unity 실기기 smoke

서명된 AAB를 기기 맞춤 APKS로 변환해 설치하고, 실제 Android 기기에서 다음 수직 흐름을 검사합니다.

- 기존 대상 패키지와 앱 데이터를 제거한 clean install 뒤 cold start, 각 재실행의 `am start`
  성공, foreground/resumed 상태 확인
- 실제 저장소가 준비되고 화면에 활성 버튼이 배치된 뒤 출력되는
  `BASEBALL_FIRST_INTERACTIVE`를 명시적 timeout 안에 확인
- HOME 이동 뒤 같은 process로 background→foreground warm resume
- bundletool `PAGE_ALIGNMENT_16K`, 생성 APK `zipalign -P 16`, 모든 ARM64 `.so` ELF LOAD
  16KB 정렬, `apkanalyzer` merged permission 허용 목록, `small/normal × 6 density`의 정확한
  compatible-screens 집합과 기기 native page size 기록
- production 모드 일곱 screenshot(내부 QA 모드는 추가 screenshot)의 PNG IHDR 기준
  portrait(`height > width`) 검증
- 기기가 landscape 회전을 요청해도 앱이 portrait를 유지하는지 검증
- airplane mode에서 offline 재실행
- force-stop 뒤 재실행
- `POST_NOTIFICATIONS` 거부 상태 재실행
- 시스템 글자 크기 200% 상태 재실행
- `RUNNING_LOW` trim-memory callback 뒤 process/foreground 유지
- crash·ANR 및 앱 logcat의 민감정보 표식 검사
- `/data` 여유 공간과 `diskstats` 기록. 실제 low-storage 조작은 하지 않으며 내부 모드에서
  별도 샌드박스 ENOSPC 저장 실패 proxy를 실행
- 각 단계 screenshot, 시작 결과, logcat, bundletool 결과 보관

## 사전 조건

- USB로 연결되고 `adb devices`에서 `device` 상태인 Android 8(API 26) 이상 기기. 알림 권한 거부 검증은 API 33 이상에서만 실행하며, 그보다 낮으면 증거에 `not_applicable_api_lt_33`으로 남긴다.
- JDK의 `java`, `jarsigner`, `unzip`, PNG 크기를 읽는 `od`, 증거 검증용 `node`
- Android SDK의 `adb`, cmdline-tools 16.0 `apkanalyzer`, build-tools 36.0.0 `zipalign`,
  Android NDK `llvm-readelf`
- 서명된 release AAB. bundletool은 Unity 6000.3.19f1 Android Build Support 번들을 기본 사용
- APKS 서명용 keystore와 alias
- store/key 비밀번호가 각각 한 줄로 든 권한 제한 파일

비밀번호 값 자체를 환경변수나 명령 출력에 넣지 않고, bundletool의 `file:` 입력으로 전달합니다.

## 환경변수

필수:

```bash
export BASEBALL_AAB=/absolute/path/baseball-release.aab
export BASEBALL_ANDROID_KEYSTORE=/absolute/path/release.keystore
export BASEBALL_ANDROID_KEY_ALIAS=release
export BASEBALL_ANDROID_STORE_PASSWORD_FILE=/absolute/secret/store-pass.txt
export BASEBALL_ANDROID_KEY_PASSWORD_FILE=/absolute/secret/key-pass.txt
```

선택:

```bash
export BASEBALL_ADB_SERIAL=device-serial
export BASEBALL_ADB=/absolute/path/to/adb
export BASEBALL_UNITY_ANDROID_SDK=/absolute/path/to/AndroidPlayer/SDK
export BASEBALL_BUNDLETOOL_JAR=/absolute/path/bundletool-all.jar
export BASEBALL_UNITY_ANDROID_PLAYER=/absolute/path/to/AndroidPlayer
export BASEBALL_ZIPALIGN=/absolute/path/to/zipalign
export BASEBALL_APKANALYZER=/absolute/path/to/apkanalyzer
export BASEBALL_LLVM_READELF=/absolute/path/to/llvm-readelf
export BASEBALL_ANDROID_PACKAGE_ID=com.solkim.baseball.android
export BASEBALL_SMOKE_EVIDENCE_ROOT=/absolute/evidence/root
export BASEBALL_SMOKE_LAUNCH_TIMEOUT_SECONDS=20
export BASEBALL_SMOKE_SETTLE_SECONDS=1
export BASEBALL_SMOKE_MODE=production
```

`adb`는 `BASEBALL_ADB` 실행 파일, `PATH`, Unity 6000.3.19f1 번들 Android SDK 순서로 찾습니다.
bundletool, zipalign, apkanalyzer, llvm-readelf도 각각 override 후 Unity 번들 순서로 찾습니다.
다른 Unity 설치를 쓰면 `BASEBALL_UNITY_ANDROID_SDK`와 `BASEBALL_UNITY_ANDROID_PLAYER`로
루트를 지정하세요.

실행:

```bash
bash tools/android-unity-smoke/run.sh
```

`production`이 기본 모드이며 서명된 프로덕션 AAB에 내부 QA hook이 있다고 가정하거나 Android
intent extra를 보내지 않습니다. 모든 cold/relaunch 구간은 passive first-interactive marker만
기다립니다. marker가 없거나 timeout이면 `*-first-interactive.txt`에 마지막 app log와 기대 marker를
남기고 실패합니다. 생성된 base-master APK의 application ID와 `debuggable=false`도 확인하므로
Local Verification 개발 AAB를 production smoke 증거로 사용할 수 없습니다.

## 내부 QA 모드

`Baseball/Build/Android/Local Verification`으로 만든 개발 AAB에서만 사용합니다. 이 빌드는
`BuildOptions.Development`와 `BASEBALL_INTERNAL_QA`를 동시에 적용합니다. RC 빌드는 두 조건을
모두 거부하며, 내부 명령 문자열과 bridge 구현은 전처리 단계에서 player IL에서 제거됩니다.
internal smoke는 base-master APK가 `debuggable=true`가 아니면 QA intent를 보내기 전에 실패합니다.

```bash
export BASEBALL_SMOKE_MODE=internal
export BASEBALL_SMOKE_QA_SEED=20260811
# 실제 의도적 crash까지 검증할 때만 1. 기본값은 0.
export BASEBALL_SMOKE_QA_CRASH_PROBE=0
bash tools/android-unity-smoke/run.sh
```

내부 모드는 안정된 `baseball.qa.*` Android intent extra로 다음 실제 개발 전용 경계를 검사합니다.

- 고정 seed/phase fixture와 opening→setup→고교 prologue 전이
- 결정된 pitch snapshot의 High/Low 품질 presentation 완료
- crash reporter nonfatal 호출과 선택적 실제 abort crash/relaunch
- 실제 사용자 save와 분리된 `persistentDataPath/internal-qa`에서 손상 복구와 atomic swap fault rollback
- ENOSPC 쓰기 실패 proxy가 `IoFailed`로 fail-closed 되는지 확인
- fake analytics destination의 비식별 event/log view
- 실제 Application command를 이용한 onboarding→tutorial pitch checkpoint 저장, force-stop, 재실행 복원

`low_storage_real=not_tested`는 의도적인 표기입니다. 스크립트는 기기 파티션을 채우거나 사용자
파일을 지우지 않습니다. 내부 ENOSPC proxy 통과를 실제 저용량 기기 검증으로 해석하면 안 됩니다.

성공 시 evidence 아래에 `.apks`, screenshot, 시작/foreground/first-interactive 측정값,
`clean-install.txt`,
`apk-permissions.txt`, `base-master-manifest.xml`, `apk-compatible-screens.txt`, 비식별 기기 모델·API,
서명 검증, logcat과 `result.txt`가 남습니다. 기기 serial과 비밀번호는 evidence에 기록하지 않습니다.

`native_page_size=16384`와 `native_16k_execution=passed`인 기기 실행 증거가 별도 출시 차단
항목입니다. 4KB 기기 smoke는 `native_16k_execution=not_tested`로 기록되며, 통과해도 16KB
기기 실행을 통과한 것으로 간주하지 않습니다.

## 종료 코드와 복구

- `0`: 모든 검사 통과
- `1`: 설치·실행·안정성·보안 검사 실패
- `2`: AAB, 도구, 서명 입력 또는 기기 사전 조건 누락

이 README와 source/static 검사는 실기기 통과 증거가 아닙니다. `result.txt`는 모든 실제 단계가
완료된 실행에서만 만들어지며, 기기나 AAB가 없으면 종료 코드 2로 끝납니다.

스크립트는 시작 전 airplane mode, 화면 회전, 글자 크기, 알림 권한 상태를 기록하고
성공·실패·중단 시 복원을 시도합니다. 다만 테스트 대상인 정확한 package ID의 기존 앱과
앱 데이터는 clean-install 증거를 만들기 위해 삭제하며 복구할 수 없습니다. 전용 QA 기기를
사용하세요. 다른 패키지나 기기 파일은 삭제하지 않습니다.
airplane mode에서도 adb가 유지되어야 하므로 Wi-Fi adb 대신 USB 연결을 사용하세요.
