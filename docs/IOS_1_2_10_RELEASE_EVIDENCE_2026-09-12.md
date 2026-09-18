# iOS 1.2.10 (68) 배포 준비 증거 · 2026-09-12

> 후속 최종 상태: [1.2.10 (69) 심사 제출 완료](IOS_1_2_10_B69_SUBMISSION_2026-09-12.md). 아래 내용은 68번 빌드 준비 당시의 기록으로 보존한다.

## 상태

**서명 아카이브·IPA·Apple 서버 검증·스토어 메타데이터 준비 완료. 업로드 및 최종 제출은 미완료.**

App Store Connect를 조회해 1.2.9 (67)이 이미 판매 중임을 확인했다. 이번 수정은 1.2.10 (68)으로 준비한다.
앞서 로컬 IPA만 보고 1.2.9를 미출시 후보처럼 설명한 판단을 정정한다.

| 항목 | 값 |
|---|---|
| 앱 ID / 번들 ID | `6794754217` / `com.solkim.baseball.ios` |
| 현재 판매 버전 | `1.2.9 (67)`, `READY_FOR_SALE` / `READY_FOR_DISTRIBUTION` |
| 현재 버전 공개 시각 | `2026-09-05T16:36:11Z` (Apple Lookup API) |
| 새 버전 / 빌드 | `1.2.10 (68)` |
| 새 ASC 버전 ID | `4f58916e-106d-4d32-9ffa-7acecdeae3fa` |
| 새 버전 상태 | `PREPARE_FOR_SUBMISSION` |
| 출시 방식 | `MANUAL` |
| 기존 기능 QA | 단위 테스트 639개 통과, 실패/건너뜀 0; 환경 제약은 남은 작업 문서에 기록 |
| 이번 변경 | 버전/빌드 번호, 릴리스 노트, 배포 검사 도구. 게임 로직 변경 없음 |

## 서명된 배포물

- Archive: `apps/ios/releases/1.2.10/BaseballIOS-1.2.10-b68.xcarchive` (약 111MiB)
- IPA: `apps/ios/releases/1.2.10/export-manual/BaseballIOS.ipa` (35,938,566 bytes, 약 34.3MiB)
- SHA-256: `94b8092bbe2b3330ee6e2fdf96b9a600ce08b9883e4b8a0ca38aa4219c7c8dda`
- 아키텍처: `arm64`, `get-task-allow=false`
- 앱 및 dSYM UUID: `A4DAA3D8-7879-332D-B184-5F7A7DC31D58`
- 프로파일: 기존 `Baseball App Store 1.2.9` 재사용. 번들 식별자는 동일하며 만료일은 `2027-08-28T06:08:14`.
- 아카이브와 export 성공. `codesign --verify --deep --strict` 통과.
- Game Center, iCloud KVS entitlement 및 앱 식별자 일치 확인.
- 최신 문자열 포맷 방어 코드 포함, Debug 전용 프로 픽스처 인자 미포함 확인.

고정 DerivedData는 기존 프로젝트 경로를 재사용했고 재시도용 디렉터리를 만들지 않았다.
검사용 IPA 압축 해제 사본은 검사 직후 제거했다. IPA·아카이브·최신 dSYM은 보존한다.

## 바이너리 현지화

정확히 위 SHA-256의 IPA를 검사했다.

| 언어 | 앱 표시 이름 | Localizable | GameContent | 시작 화면 |
|---|---|---:|---:|---|
| ko | 야구 못하면 또 환생함 | 2,127개 | 2,153개 | LaunchScreenV2 포함 |
| en | Mound Reborn | 2,127개 | 2,153개 | LaunchScreenV2 포함 |
| ja | 野球がダメならまた転生 | 2,127개 | 2,153개 | LaunchScreenV2 포함 |

`record.album.play`, `record.album.catcher-view`, `record.saber.era`와 수정된 시즌 역할 포맷이
세 언어에 모두 들어 있다. 일본어 판별 코드는 기존 검증된 소스에서 변경하지 않았다.
**리소스 포함 확인을 실제 기기 실행이나 대상 App Store 화면 확인으로 대신하지 않는다.**

검사 재현:

```bash
python3 tools/check-ios-release-ipa.py \
  apps/ios/releases/1.2.10/export-manual/BaseballIOS.ipa \
  --version 1.2.10 --build 68 \
  --output apps/ios/releases/1.2.10/evidence/ipa-inspection.json
```

## Apple 서버 검증 및 ASC 준비

`altool --validate-app` 결과:

> VERIFY SUCCEEDED with no errors

`apple-validation.log`에 정확한 IPA 경로와 성공 결과를 보관했다. 이것은 **업로드·심사 승인·출시가 아니다.**

- 현재 1.2.9에서 설명·키워드·지원 URL 등 기존 메타데이터를 새 버전으로 복사했다.
- `ko`, `ja`, `en-US`, `en-GB`, `en-AU`, `en-CA` 여섯 로케일의 새로운 기능을
  `marketing/appstore/RELEASE_NOTES_1.2.10.md`에 맞춰 저장하고 API 재조회로 완전 일치 확인했다.
- 리뷰 설명을 최신 변경과 기본 수동 투구 슬라이더, 일본어 실행 방법, 로그인 불필요 안내로 갱신했다.
- 리뷰 세부사항 ID: `b233293b-6724-4034-8b9a-022a91e1399c`. 기존 연락처를 유지했다.
- 가격·판매 지역·현재 판매 중인 1.2.9는 수정하지 않았다.
- `asc validate` 결과: **차단 1건 — 새 버전에 빌드가 아직 연결되지 않음**. 경고 0건.
- App Privacy의 게시 상태는 공용 ASC API로 확인할 수 없다는 정보 항목이 있었다.
  실제 공개 App Store 페이지에서 식별자·사용 데이터·진단의 "사용자에게 연결되지 않은 데이터" 표시가
  게시되어 있음을 확인했다. 비공개 ASC App Privacy 화면은 브라우저 로그인 부재로 확인하지 못했다.
  이번 작업에서 개인정보 선언 자체는 바꾸지 않았다.

## 남아 있는 명시적 조건

1. **업로드 권한**: 완성된 IPA의 App Store Connect/TestFlight 업로드와 새 버전 연결을 별도로 확인 요청했다.
   `AGENTS.md`의 "TestFlight 업로드는 별도로 확보된 권한 범위에서만 수행한다" 조건을 따른다.
   기존 내부 테스트 그룹(`내부 테스트`)은 모든 빌드에 접근하도록 설정되어 있다. 외부 테스터나 그룹은 추가하지 않는다.
2. **일본어 실기기/TestFlight 스모크**: 미완료. 이전에 사용자가 직접 맡기로 했던 범위를 이번에 자동화해도
   되는지 확인 요청했다. iPhone 16 Pro는 처음에는 연결되었으나 이후 터널이 `unavailable`로 바뀌었다.
   실제 앱 설치·실행이나 세이브 초기화는 하지 않았다. 기기가 다시 연결되어야 진행할 수 있다.
3. **대상 버전의 Japanese 표시 증거**: 미완료. 현재 공개 페이지는 1.2.9이며 지원 언어가 한국어·영어·일본어다.
   이 증거를 1.2.10 (68)의 확인으로 재사용하지 않는다. 새 빌드의 언어 확인과 대상 화면 증거가 필요하다.
4. **사람 확인**: 햅틱·실제 오디오 지연·야외 밝기·일본어 화자의 문장 검수는 수행하지 않았다.

위 일본어 필수 조건이 충족되기 전에는 App Review 제출·수동 출시하지 않는다.
F-08 및 경미한 끝 구분자 문제 등 잔여 항목은 `IOS_REMAINING_WORK_2026-09-12.md`에 유지한다.

## 증거 위치

`apps/ios/releases/1.2.10/evidence/` 아래에 다음을 보존한다(gitignore).

- `versions-before.json`, `builds-before.json`, `version-created.json`
- `archive.log`, `export.log`, `ipa-inspection.json`, `apple-validation.log`
- `metadata-final.json`, 로케일별 갱신 응답, `review-notes.txt`
- `asc-readiness-before-upload.json`, `testflight-groups-before.json`
- `public-store-current.json`, `public-store-observation.json`, `device-before.json`, `device-latest.json`
- `checker-negative-case.txt`: Python 최적화 모드에서도 잘못된 버전 입력을 거부함

Apple 안내: [새 버전 만들기](https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version),
[빌드 업로드](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

## 실기기 실행 · 2026-09-12 19:31 KST

사용자가 연결한 실기기에서 실행을 요청해 iPhone 16 Pro에 1.2.10 (68)을 설치하고 전면 실행했다.
동일 Release 아카이브를 개발 서명으로 다시 내보냈으며 App Store IPA는 변경하지 않았다.
기존 개발 프로파일의 Associated Domains 누락으로 첫 export가 실패해, 등록된 기기와 기존 개발 인증서로
`Baseball Device 1.2.10` 프로파일을 생성한 뒤 export에 성공했다.
기존 앱 1.2.3 (61)을 업데이트했으며 앱 삭제·세이브 초기화·언어 강제 변경은 하지 않았다.
`devicectl` 설치·실행 성공 및 실행 프로세스 PID 21391을 확인했다.
네트워크 screenshotr 서비스가 지원되지 않아 스크린샷은 얻지 못했다.
이 실행만으로 일본어 스모크나 UI 육안 검증 완료로 간주하지 않는다. TestFlight 업로드는 하지 않았다.
증거: `evidence/export-device.log`, `device-install.json`, `device-launch.json`, `device-processes.json`.
설치용 IPA는 `export-device/BaseballIOS.ipa`에 보존하고 설치에 사용한 압축 해제 사본은 제거했다.
