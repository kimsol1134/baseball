# Android 기기 매트릭스

| 역할 | 최소 조건 | 실제 기기 | 상태 | 증거 |
|---|---|---|---|---|
| Low | API 26–29, 4GB RAM, Samsung | API 29 ARM64 emulator (2GB) | emulator production smoke 통과 / 물리 대기 | `/tmp/baseball-api29-smoke-0797760/20260812T143247Z` |
| Mid | Galaxy A34급, Android 13–15 | 미확보 | 대기 | |
| High | Galaxy S20 FE 이상, 120Hz 포함 | 미확보 | 대기 | |
| API edge | Android 16/API 36 | API 36 ARM64 emulator | production smoke 통과 / 물리 대기 | `/tmp/baseball-api36-smoke-0797760/20260812T143452Z` |
| 16KB page | `getconf PAGE_SIZE=16384`, ARM64, API 35+ | `sdk_gphone16k_arm64`, API 35 emulator | production AAB 수직 루프 통과 / 물리 대기 | `/tmp/baseball-final-smoke-0797760/20260812T134607Z`; 실제 투구·shader·crash/ANR 0 |
| Play farm | 사전 출시 보고서 | AAB 업로드 완료, 검토 미제출 | 계정 정보 해결 뒤 대기 | Play versionCode 1 활성 |

각 기기에서 clean install, update, airplane mode, background/force-stop, gesture/3-button navigation, 글자 200%, TalkBack, pitch frame time, peak memory를 기록한다.

16KB production emulator 행은 smoke `device-metadata.txt`의 `native_page_size=16384`, `result.txt`의
`native_16k_execution=passed`, APK `zipalign -P 16`, ARM64 ELF LOAD 정렬, 설치/실행
screenshot, crash/ANR scan이 모두 있어야 완료한다. 4KB device 또는 bundletool config만으로
이 행을 통과 처리하지 않는다. 물리 스마트폰 행은 별도로 닫아야 한다.
