# iOS 1.2.8 제출 체크리스트

순서대로 진행한다. 이 문서는 제출 절차만 적는다. 이 페이퍼워크 작업에서는 `project.yml`·소스를 바꾸지 않았고, `xcodebuild`·ASC API·`tools/asc-*.mjs`를 실행하지 않았다.

선행: 1.2.7이 심사 중이면 1.2.8 버전 레코드를 만들기 전에 1.2.7 상태(WAITING_FOR_REVIEW / PENDING_DEVELOPER_RELEASE / READY_FOR_SALE)를 확인한다. 출시 방식은 계속 `MANUAL`이다.

관련 문안: `marketing/appstore/RELEASE_NOTES_1.2.8.md`, 제출 스크립트 `tools/asc-submit-1-2-8.mjs`, 리뷰 답글 `docs/REVIEW_REPLIES_1_2_7.md`.

---

## 1. E2E 보고서 녹색 확인

- [ ] `docs/SIMULATOR_E2E_1_2_8_REPORT_2026-09-02.md`가 있고, 시나리오 1–8과 글자 깨짐 재현이 통과로 적혀 있다.
- [ ] 보직 지원(시나리오 2), 3주 결정·용어 탭(3), 후속 결과 카드(4), 투구 슬라이더 한 구(5)가 녹색이다. 보고서가 없거나 실패면 whatsNew에서 해당 줄을 빼거나 제출을 미룬다. 보직·용어는 전용 보고서가 없어 릴리스 노트에 **구현 중**으로 표시했다.
- [ ] 게이트 정리 보고 `docs/RELEASE_GATE_CLEANUP_1_2_8_REPORT_2026-09-02.md` 섹션 2가 전부 종료 코드 0인지 재확인한다.
- [ ] 서명 IPA에 `ko.lproj` / `en.lproj` / `ja.lproj`와 Localizable·GameContent·InfoPlist·LaunchScreen이 들어 있다. App Store 지원 언어에 `Japanese`가 보이기 전에는 제출·출시하지 않는다(AGENTS.md).

## 2. ASC에서 최신 빌드 번호 확인 후 `CURRENT_PROJECT_VERSION` 증가

- [ ] App Store Connect(또는 제출 시점에만 `node tools/asc-release-ops.mjs list-builds`)에서 이 앱의 최신 `CFBundleVersion`을 확인한다. **1.2.7은 빌드 65**였다.
- [ ] 다음 빌드는 확인한 최댓값 + 1이다. 65가 최신이면 66. 이미 66 이상이 있으면 그다음 숫자만 쓴다. 번호를 건너뛰지 말고, 이미 올라간 번호를 재사용하지 않는다.
- [ ] `apps/ios/project.yml`의 `MARKETING_VERSION`을 `1.2.8`로, `CURRENT_PROJECT_VERSION`을 위에서 정한 숫자로 바꾼다. 이 페이퍼워크 작업은 그 파일을 건드리지 않았다.
- [ ] Release 서명은 기존과 같다: team `D48DDX5D5W`, 인증서 `0AD1EB1475150FF6292A94B1DBA67478BEE6DFB8`, 프로파일 `Baseball App Store 1.2.4 1787906374037`. 프로파일이 만료됐으면 갱신 후 ExportOptions도 맞춘다.

## 3. xcodegen

다른 엔지니어가 빌드·테스트를 돌리는 동안에는 실행하지 않는다. 동시 `xcodebuild`는 테스트를 깨뜨린다.

```bash
cd apps/ios
xcodegen generate
```

`project.yml`을 바꾼 뒤에만 돌린다. 산출 `Baseball.xcodeproj`의 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`이 1.2.8과 새 빌드 번호인지 확인한다.

## 4. 아카이브·익스포트

1.2.4–1.2.5 경로와 `tools/asc-submit-1-2-8.mjs` 주석과 같다. `NN`은 2단계에서 정한 빌드 번호다.

```bash
cd apps/ios
mkdir -p releases/1.2.8

xcodebuild -project Baseball.xcodeproj \
  -scheme BaseballIOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath releases/1.2.8/BaseballIOS-1.2.8-bNN.xcarchive \
  archive
```

## 5. "Failed to Use Accounts" 대비 API 키

아카이브 또는 `-exportArchive`가 `Failed to Use Accounts`로 끝나면 Apple ID 계정 세션 대신 API 키를 붙인다.

```bash
xcodebuild -project Baseball.xcodeproj \
  -scheme BaseballIOS \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath releases/1.2.8/BaseballIOS-1.2.8-bNN.xcarchive \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_TW3Y8S4M9V.p8" \
  -authenticationKeyID TW3Y8S4M9V \
  -authenticationKeyIssuerID f4843e26-5b1f-4b00-bd4a-d24ca4539774 \
  archive
```

익스포트·검증·업로드:

```bash
cd apps/ios
cp releases/1.2.5/ExportOptions-AppStore-1.2.5.plist \
   releases/1.2.8/ExportOptions-AppStore-1.2.8.plist

xcodebuild -exportArchive \
  -archivePath releases/1.2.8/BaseballIOS-1.2.8-bNN.xcarchive \
  -exportPath releases/1.2.8/export-manual \
  -exportOptionsPlist releases/1.2.8/ExportOptions-AppStore-1.2.8.plist \
  -authenticationKeyPath "$HOME/.appstoreconnect/private_keys/AuthKey_TW3Y8S4M9V.p8" \
  -authenticationKeyID TW3Y8S4M9V \
  -authenticationKeyIssuerID f4843e26-5b1f-4b00-bd4a-d24ca4539774

xcrun altool --validate-app --type ios \
  --file releases/1.2.8/export-manual/BaseballIOS.ipa \
  --apiKey TW3Y8S4M9V \
  --apiIssuer f4843e26-5b1f-4b00-bd4a-d24ca4539774

xcrun altool --upload-app --type ios \
  --file releases/1.2.8/export-manual/BaseballIOS.ipa \
  --apiKey TW3Y8S4M9V \
  --apiIssuer f4843e26-5b1f-4b00-bd4a-d24ca4539774
```

`ExportOptions`의 `manageAppVersionAndBuildNumber`는 `false`로 둔다. IPA 처리가 `VALID`이고 지원 언어에 Japanese가 보일 때까지 버전을 연결하지 않는다.

## 6. TestFlight what's New — GET 후 409면 PATCH

로케일 `ko`, `ja`, `en-US`(필요하면 `en-GB` / `en-AU` / `en-CA`). 본문은 `RELEASE_NOTES_1.2.8.md`의 whatsNew와 같다.

1. `GET /v1/builds/{buildId}/betaBuildLocalizations`
2. 없는 로케일은 `POST /v1/betaBuildLocalizations` (`locale`, `whatsNew`, build 관계)
3. **409 Conflict**면 새로 만들지 않는다. 1의 목록(또는 `filter[locale]`)에서 해당 localization id를 읽고 `PATCH /v1/betaBuildLocalizations/{id}`로 `whatsNew`만 갱신한다
4. What to Test 미리보기가 노트와 같은지 확인한다

이 단계도 ASC API를 쓰므로, 페이퍼워크 전용 세션에서는 실행하지 말고 제출 담당이 돌린다.

## 7. reviewSubmissions 흐름

빌드가 `VALID`인 뒤에만. 먼저 계획만 보려면:

```bash
node tools/asc-submit-1-2-8.mjs --dry-run prepare
node tools/asc-submit-1-2-8.mjs --dry-run attach NN
node tools/asc-submit-1-2-8.mjs --dry-run submit
```

실제 제출(페이퍼워크 작업에서는 실행하지 않음):

```bash
node tools/asc-submit-1-2-8.mjs prepare NN
node tools/asc-submit-1-2-8.mjs inspect NN
node tools/asc-submit-1-2-8.mjs attach NN
node tools/asc-submit-1-2-8.mjs submit
```

스크립트가 하는 일:

1. `1.2.7`을 소스로 `1.2.8` 버전을 만들거나 재사용한다. `releaseType: MANUAL`
2. 로케일 `en-US` `en-GB` `en-AU` `en-CA` `ko` `ja`의 `whatsNew`를 노트 파일에서 읽어 맞춘다
3. 심사 메모를 넣고 데모 계정은 불필요로 둔다
4. 처리가 끝난 빌드 `NN`을 연결한다
5. `GET /v1/apps/{id}/reviewSubmissions?filter[platform]=IOS`
6. `WAITING_FOR_REVIEW`면 그대로 둔다. 없으면 `POST /v1/reviewSubmissions`
7. 항목이 없으면 `POST /v1/reviewSubmissionItems`로 1.2.8을 연결한다
8. `PATCH /v1/reviewSubmissions/{id}` `submitted: true`

일본어 실기기 또는 TestFlight 스모크와 IPA 현지화 검사가 끝나기 전에는 8을 실행하지 않는다. 승인 후에도 자동 출시하지 않는다.

## 8. 리뷰 답글

초안: `docs/REVIEW_REPLIES_1_2_7.md`. 날짜를 약속하지 않는다.

- [ ] **1.2.7 출시 후:** (a) 투구 손, (b) 저장 교착, (c) 이닝 집계, (d) 재계약 후속
- [ ] **1.2.8 출시 후:** (e) 8/29 3★ 한 문단. 1.2.7 답글과 같은 날에 올리지 않는다
