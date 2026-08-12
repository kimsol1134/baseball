# Android 기기 매트릭스

| 역할 | 최소 조건 | 실제 기기 | 상태 | 증거 |
|---|---|---|---|---|
| Low | API 26–29, 4GB RAM, Samsung | 미확보 | 대기 | |
| Mid | Galaxy A34급, Android 13–15 | 미확보 | 대기 | |
| High | Galaxy S20 FE 이상, 120Hz 포함 | 미확보 | 대기 | |
| API edge | Android 16/API 36 | emulator/실기기 미생성 | 대기 | |
| 16KB page | `getconf PAGE_SIZE=16384`, ARM64, API 35+ | `sdk_gphone16k_arm64`, API 35 emulator | 내부 검증 통과 / production 출시 차단 | internal high/low pitch·restart·fault 통과; production 물리기기 필요 |
| Play farm | 사전 출시 보고서 | AAB 미업로드 | 대기 | |

각 기기에서 clean install, update, airplane mode, background/force-stop, gesture/3-button navigation, 글자 200%, TalkBack, pitch frame time, peak memory를 기록한다.

16KB production 행은 smoke `device-metadata.txt`의 `native_page_size=16384`, `result.txt`의
`native_16k_execution=passed`, APK `zipalign -P 16`, ARM64 ELF LOAD 정렬, 설치/실행
screenshot, crash/ANR scan이 모두 있어야 완료한다. 4KB device 또는 bundletool config만으로
이 행을 통과 처리하지 않는다.
