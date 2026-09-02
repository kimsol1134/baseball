# P2-2 시드 도전 링크 구현 보고

구현: grok-4.6. 스펙: `docs/P2_SEED_CHALLENGE_LINK_SPEC_2026-09-02.md`.
워크트리 `/Users/solkim/Dev/baseball-wt-link`, 브랜치 `p2/seed-link`.
커밋·푸시·stash·reset·checkout 없음. `xcodebuild`·`npm` 없음. `project.pbxproj` 미수정.
카드 공유 예약 파일(`CareerShareCard`, ShareSheet 호출부, 은퇴·드래프트·기록 뷰) 미수정.

HEAD: `187a3b51a7f97dfebe15d5231c4ecfab2fdde2ad`.

## 0. 규칙 준수

- 이 워크트리에서만 작업. `/Users/solkim/Dev/baseball` 미접근.
- 코어 시뮬레이션 무변경. 실존 구단·선수명 없음. 투구 슬라이더 코드 미접근.
- `ChallengeLink.shareURL(seed:life:host:)` / `shareText`만 제공. 카드 공유 쪽 연결은 병합 후 PM 작업.
- 호스트가 비어 있으면 associated domains는 빈 배열. `applinks:` 빈 호스트로 서명이 깨지지 않게 했다.

## 1. 링크 형식

토큰 규칙: `"<seed>-<life>"`. 시드는 `UInt64`, 회차는 1...999. 고교 시작 화면 `parsedChallenge`와 동일하며 이제 `ChallengeLink.parseToken`을 쓴다.

| 형식 | 예 |
|---|---|
| 커스텀 스킴 | `yagurebirth://challenge/12345-4` |
| 유니버설 링크 | `https://<CHALLENGE_LINK_HOST>/challenge/12345-4` |

- 대소문자·트레일링 슬래시·쿼리는 무시한다.
- `CHALLENGE_LINK_HOST`가 비어 있으면 `shareURL`은 스킴만 만든다.
- `shareText`는 카탈로그 키 `app.challenge-link.share-text`와 토큰만 반환한다. 문구는 앱 카탈로그.

## 2. 배선 지점

### Domain (`packages/ios-layers`)

- `Sources/BaseballIOSDomain/ChallengeLink.swift` — `parse(url:)`, `parseToken`, `shareURL`, `shareText`, `open`, 배너/시작 화면 판정
- `Tests/BaseballIOSDomainTests/ChallengeLinkTests.swift` — 스킴/https/대소문자/잘못된 토큰/life 범위. `swift test`로 실행됨
- `Package.swift` — `BaseballIOSDomainTests` 타깃 추가

### iOS 앱 (작성만, 실행하지 않음)

- `apps/ios/project.yml` — 스킴 `yagurebirth`, `CHALLENGE_LINK_HOST` 기본 `""`, associated domains `[]`
- `apps/ios/Sources/Info.plist` — URL 타입 + `CHALLENGE_LINK_HOST`
- `apps/ios/Sources/BaseballIOS.entitlements` — `com.apple.developer.associated-domains` 빈 배열
- `BaseballApp.swift` — `.onOpenURL` + `NSUserActivityTypeBrowsingWeb` → `pendingChallenge`
- `ChallengeLinkSession.swift` — 앱 진입 계약(잘못된 링크는 기존 pending을 덮지 않음)
- `AppShell.swift` — 커리어 진행 중 배너, 잘못된 링크 안내. 저장 중인 커리어는 덮어쓰지 않음
- `HighSchoolCareerView.swift` / `HighSchoolSetupView.swift` / `+NameStep.swift` — 시작 화면 시드 입력 채움, 도전 모드 요약, 공유 버튼(`ActivityShareButton`, ShareSheet.swift 미수정)
- `GameAnalytics.swift` — `challenge_link_opened`(`source`, `valid`), `challenge_link_shared`(`life_number`). 원시 시드 없음
- 문구 `app.challenge-link.*` ko/en/ja: banner, applied, invalid, share-text, share-action
- `apps/ios/Tests/ChallengeLinkSessionTests.swift` — 진입 → pending → 시작 화면, 진행 중 배너, 잘못된 링크 무시

### 랜딩

- `apps/landing/app/challenge/[token]/page.tsx` — 토큰, 앱 열기(`yagurebirth://challenge/<token>`), App Store `id6794754217`, OG `/opengraph-image-v2.png`
- `apps/landing/public/.well-known/apple-app-site-association` — `appID: D48DDX5D5W.com.solkim.baseball.ios`, `paths: ["/challenge/*"]`
- `apps/landing/next.config.ts` — 해당 경로 `Content-Type: application/json`

## 3. 검증

```
swift test --package-path packages/ios-layers
```

종료 코드 0. ChallengeLinkTests 10건 포함 All tests 24건 통과.

AASA·카탈로그 JSON은 `node -e`로 파싱·필드 확인(npm 없음).

iOS 앱 테스트·xcodegen·npm 게이트는 실행하지 않음.

## 4. PM이 병합 후 실행할 명령

시뮬레이터는 부팅된 iPhone 17만 재사용. 새 기기 만들지 말 것.

```bash
# 1) xcodegen (이 작업은 pbxproj를 고치지 않았다. 새 테스트 파일을 넣으려면 생성 필요)
cd apps/ios
xcodegen generate

# 2) iOS 단위 테스트
xcodebuild test -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BaseballIOSTests/ChallengeLinkSessionTests \
  -only-testing:BaseballIOSTests/LocalizationCoverageTests \
  -only-testing:BaseballIOSTests/JapaneseLocalizationTests \
  -only-testing:BaseballIOSTests/LayerBoundaryTests \
  CODE_SIGNING_ALLOWED=NO

# 필요하면 스위트 전체
xcodebuild test -project Baseball.xcodeproj -scheme BaseballIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BaseballIOSTests \
  CODE_SIGNING_ALLOWED=NO

# 3) 카탈로그 스냅샷 갱신 후 npm 게이트
cd ../..
npm run inventory:ios-localization -- --write
npm run check:ios-localization
npm run check:copy
npm run check:design-system

# 4) 랜딩 타입체크(선택)
npm run landing:typecheck
```

카드 공유 엔지니어 병합 후: 은퇴·드래프트·기록 카드 공유 텍스트에 `ChallengeLink.shareURL(seed:life:host:)` / `shareText`를 연결. 이 작업은 그 호출부를 넣지 않았다.

## 5. 도메인 배포 절차 (AASA · HTTPS · entitlement)

유니버설 링크는 도메인이 정해진 뒤에만 산다. 지금은 스킴 링크만 동작한다.

1. 랜딩을 HTTPS로 올린다. `NEXT_PUBLIC_SITE_URL`에 그 오리진을 넣는다(스킴+호스트, 끝 슬래시 없이).
2. 배포본에서 아래가 **리다이렉트 없이** 200이어야 한다.
   - `https://<HOST>/.well-known/apple-app-site-association`
   - `Content-Type: application/json`
   - `appID` = `D48DDX5D5W.com.solkim.baseball.ios`
   - `paths` = `/challenge/*`
3. Apple Developer의 App ID `com.solkim.baseball.ios`에 Associated Domains를 켠다.
4. `apps/ios/project.yml`에서 호스트만 넣는다(스킴 없이):

```yaml
        CHALLENGE_LINK_HOST: example.com
        # entitlements:
        com.apple.developer.associated-domains: [applinks:$(CHALLENGE_LINK_HOST)]
```

   호스트가 다시 비면 associated domains를 `[]`로 되돌려 서명 오류를 막는다.

5. `cd apps/ios && xcodegen generate` 후 앱을 다시 아카이브한다.
6. Apple AASA CDN 반영까지 몇 시간이 걸릴 수 있다. 실기기에서 `https://<HOST>/challenge/<seed>-<life>`가 앱을 여는지만 확인한다. 시뮬레이터 유니버설 링크는 참고용이다.
7. 스킴 `yagurebirth://challenge/<seed>-<life>`는 도메인 없이도 설치 기기에서 즉시 동작한다.

## 6. 미해결

- iOS `BaseballIOSTests` / UI 테스트 / `xcodegen generate` / npm 게이트는 이 워크트리에서 실행하지 않았다.
- `CHALLENGE_LINK_HOST`가 비어 있어 유니버설 링크 entitlement는 빈 배열이다. 공유 URL은 스킴만 나온다.
- 카드 공유 텍스트에 도전 URL을 넣는 연결은 다른 엔지니어 작업 + 병합 후 PM.
- `inventory:ios-localization --write`가 카탈로그 배열 순서를 다시 쓸 수 있다. 키 5개는 xcstrings와 schema에 이미 있다.
- 첫 회차 오프닝이 떠 있는 동안에는 배너를 띄우지 않고, 오프닝을 닫은 시작 화면에 토큰을 채운다.
