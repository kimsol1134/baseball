# Android 기기 매트릭스

| 역할 | 최소 조건 | 실제 기기 | 상태 | 증거 |
|---|---|---|---|---|
| Low | API 26–29, 4GB RAM, Samsung | API 29 ARM64 emulator (2GB) | v5 emulator production smoke 통과 / 물리 대기 | `/private/tmp/baseball-v5-api29-smoke/20260812T212604Z` |
| Mid | Galaxy A34급, Android 13–15 | 미확보 | 대기 | |
| High | Galaxy S20 FE 이상, 120Hz 포함 | 미확보 | 대기 | |
| API edge | Android 16/API 36 | API 36 ARM64 emulator | v5 production smoke 통과 / 물리 대기 | `/private/tmp/baseball-v5-api36-smoke/20260812T212855Z` |
| 16KB page | `getconf PAGE_SIZE=16384`, ARM64, API 35+ | `sdk_gphone16k_arm64`, API 35 emulator | v5 production AAB 수직 루프 통과 / 물리 대기 | `/private/tmp/baseball-v5-smoke/20260812T211007Z`; 실제 투구·shader·crash/ANR 0 |
| Play farm | 사전 출시 보고서 | v5 closed Alpha 검토 중 | 승인 뒤 자동 보고서 대기 | internal v5 제공; Alpha는 승인 전 v1 유지; 지원 기기 5,573대 |

각 기기에서 clean install, update, airplane mode, background/force-stop, gesture/3-button navigation, 글자 200%, TalkBack, pitch frame time, peak memory를 기록한다.

Play App Bundle 탐색기에서 versionCode 5의 지원 Android 기기 5,573대를 확인했다. Device Catalog
CSV와 기기 제외는 별도 Device Catalog 서비스 약관 동의가 필요한 기능이므로 승인 전에는 사용하지 않는다.

16KB production emulator 행은 smoke `device-metadata.txt`의 `native_page_size=16384`, `result.txt`의
`native_16k_execution=passed`, APK `zipalign -P 16`, ARM64 ELF LOAD 정렬, 설치/실행
screenshot, crash/ANR scan이 모두 있어야 완료한다. 4KB device 또는 bundletool config만으로
이 행을 통과 처리하지 않는다. 물리 스마트폰 행은 별도로 닫아야 한다.
