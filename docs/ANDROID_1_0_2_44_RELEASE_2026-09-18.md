# Android 1.0.2 (44) 프로덕션 제출 — 2026-09-18

현재 코드로 서명된 Compose 후보를 Google Play 프로덕션 트랙에 올렸다. Publisher API에서 프로덕션 릴리스 **1.0.2 (44) / status completed** 와 한국어·영어·일본어 등록정보 갱신을 확인했다. Google 심사 완료·스토어 공개 반영은 이 시각의 completed 트랙과 같지 않을 수 있어, 공개 Play 페이지의 버전 표시는 별도로 재확인해야 한다.

## 배포 범위

- 패키지: `com.solkim.baseball.android`
- 기존 1.0.1 (43) → 1.0.2 (44), 기존 대상 국가 전체, 출시율 100%.
- 국가·가격 변경 없음. 한국어·영어·일본어 출시 노트와 등록정보(제목·짧은 설명·전체 설명·예고편 URL·폰 스크린샷 8장·피처 그래픽)를 함께 갱신했다.
- 퍼펙트 판정을 화면의 주황 구간과 맞추고, 환생 문안을 이번 선수/다음 선수로 정리했다.
- 직접 투구의 기본 조작은 타이밍 슬라이더. 16KB 에뮬레이터 설정에서 보조 조작(한 번 탭)은 꺼져 있었다.

## 소스와 검증

- 소스: `android/core-fun-quality-2026-09-07`, 커밋 `7c2c685aeabfab529c0ba664a5b9c4668d36864d`.
- 서명 AAB SHA-256: `6760efda75b3e9664b4bb2c66bf6c838632a3b2eb3cbae7f6e1a3aada4a1ac0a`.
- 업로드 인증서 SHA-256: `d0a8ec4fdcec6f7f74bbebce747cb3d2fa308db72cca106d30aa2a782daa445f`.
- APK 16KB zipalign 검사 통과. 패키지 리소스에 `기본 조작은 투구 슬라이더` 포함.
- 16KB 에뮬레이터(`sdk_gphone16k_arm64`)에 1.0.2 (44) 설치 후 홈·설정·조작 화면을 열었다. `settings.assist`는 false, 문구는 “By default, you time each pitch yourself.”
- `npm run check:copy`, `check:real-names`, `check:android:compose`, `check:android:compose:release`, `:game-core/:game-application/:game-persistence` 테스트 통과.

## 증거

- `artifacts/android-compose/rc/1.0.2-44/`
- `artifacts/android-compose/rc/1.0.2-44/play-upload.json`

[Play 게시 개요](https://play.google.com/console/u/1/developers/5198814359992339237/app/4973220489799176676/publishing)
