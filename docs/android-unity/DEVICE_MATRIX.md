# Android 기기 매트릭스

| 역할 | 최소 조건 | 실제 기기 | 상태 | 증거 |
|---|---|---|---|---|
| Low | API 26–29, 4GB RAM, Samsung | API 29 ARM64 emulator (2GB) | v2 emulator production smoke 통과 / 물리 대기 | `/private/tmp/baseball-v2-api29-smoke-a65b9da/20260812T160137Z` |
| Mid | Galaxy A34급, Android 13–15 | 미확보 | 대기 | |
| High | Galaxy S20 FE 이상, 120Hz 포함 | 미확보 | 대기 | |
| API edge | Android 16/API 36 | API 36 ARM64 emulator | v2 production smoke 통과 / 물리 대기 | `/private/tmp/baseball-v2-api36-smoke-a65b9da/20260812T160713Z` |
| 16KB page | `getconf PAGE_SIZE=16384`, ARM64, API 35+ | `sdk_gphone16k_arm64`, API 35 emulator | v2 production AAB 수직 루프 통과 / 물리 대기 | `/private/tmp/baseball-v2-16k-smoke-a65b9da/20260812T155332Z`; 실제 투구·shader·crash/ANR 0 |
| Play farm | 사전 출시 보고서 | v2 AAB+symbols edit upload 검증, commit 대기 | 계정 정보 해결 뒤 대기 | Play versionCode 1 활성; v2 edit는 partial publish 없이 폐기 |

각 기기에서 clean install, update, airplane mode, background/force-stop, gesture/3-button navigation, 글자 200%, TalkBack, pitch frame time, peak memory를 기록한다.

16KB production emulator 행은 smoke `device-metadata.txt`의 `native_page_size=16384`, `result.txt`의
`native_16k_execution=passed`, APK `zipalign -P 16`, ARM64 ELF LOAD 정렬, 설치/실행
screenshot, crash/ANR scan이 모두 있어야 완료한다. 4KB device 또는 bundletool config만으로
이 행을 통과 처리하지 않는다. 물리 스마트폰 행은 별도로 닫아야 한다.
