# P2-2 시드 도전 링크 스펙 (커스텀 URL 스킴 + 유니버설 링크 스캐폴딩)

작성: PM, 2026-09-02. 구현: grok (워크트리 `/Users/solkim/Dev/baseball-wt-link`, 브랜치 `p2/seed-link`). 목적: "같은 시드로 누가 더 잘 키우나"를 링크 한 번으로 시작하게 해 친구 초대 루프를 만든다.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. 이 워크트리에서만 작업. main 트리 접근 금지.
2. **xcodebuild·npm 실행 금지**(다른 엔지니어가 시뮬레이터 점유). iOS 코드·테스트는 작성만. `swift test --package-path packages/ios-layers`는 가능(파서를 ios-layers Domain에 두면 여기서 검증 가능).
3. **다른 엔지니어가 main에서 카드 공유(`CareerShareCard`, ShareSheet 호출부, 은퇴·드래프트·기록 뷰)를 만들고 있다.** 이 작업은 그 파일들을 건드리지 않는다. 공유 텍스트에 링크를 넣는 건 저쪽이 아니라 **이쪽**이 `ChallengeLink.shareURL(seed:life:)` 헬퍼로 제공하고, 병합 후 PM이 연결한다.
4. 실존 명칭 금지. 코어 시뮬레이션 무변경.

## 1. 기존 자산
- 시드 입력: `HighSchoolSetupView.swift:206` `parsedChallenge` — "<seed>-<life>" 토큰(seed UInt64, life 1~999)이면 도전 모드, `seedOverride`로 시작.
- 앱 진입: `apps/ios/Sources/Features/Shell/BaseballApp.swift`. 번들 ID `com.solkim.baseball.ios`, 팀 `D48DDX5D5W`. `apps/ios/project.yml`이 xcodegen 원본(entitlements 파일 없음).
- 랜딩: `apps/landing`(Next.js), 도메인은 `NEXT_PUBLIC_SITE_URL` 환경 변수(고정 도메인 없음).

## 2. 기능
### 2.1 링크 형식
- 커스텀 스킴: `yagurebirth://challenge/<seed>-<life>` (즉시 동작, 도메인 불필요).
- 유니버설 링크: `https://<SITE>/challenge/<seed>-<life>` — SITE는 빌드 설정 `CHALLENGE_LINK_HOST`(xcconfig/Info.plist 키)로 주입, 기본값은 비워 두고 비어 있으면 스킴 링크만 생성.
- 파서 `ChallengeLink`(packages/ios-layers/Sources/BaseballIOSDomain/ChallengeLink.swift): `parse(url:) -> (seed: String, life: Int)?` — 두 형식 모두, 대소문자·트레일링 슬래시·쿼리 무시, 검증 규칙은 `parsedChallenge`와 동일. `shareURL(seed:life:host:)`, `shareText(...)`는 키만 반환(문구는 앱 카탈로그).

### 2.2 앱 배선
- `project.yml`: `CFBundleURLTypes`(스킴 `yagurebirth`), `com.apple.developer.associated-domains` entitlement `applinks:$(CHALLENGE_LINK_HOST)` — 호스트가 비어 있으면 entitlement가 빈 배열이 되도록 xcodegen 설정(빌드 깨지지 않게). 프로젝트 재생성(`xcodegen generate`)은 PM이 병합 후 수행하므로 **pbxproj는 수정하지 말 것**.
- `BaseballApp.swift`: `.onOpenURL`과 `NSUserActivity`(browsingWeb) 처리 → `ChallengeLink.parse` → 앱 상태 `pendingChallenge` 저장 → 고교 시작 화면이 열려 있으면 시드 입력에 토큰을 채우고 "도전 모드" 요약 표시, 커리어 진행 중이면 "현재 커리어를 마치고 새 선수로 시작할 때 적용" 배너(기존 커리어를 덮어쓰지 않는다 — 저장 보호 원칙).
- 고교 시작 화면(`HighSchoolSetupView+NameStep.swift` 부근)에 "도전 링크 복사/공유" 버튼: 현재 시드-회차로 링크 생성 → 시스템 공유 시트(텍스트).
- 문구 ko/en/ja: `app.challenge-link.*`(배너, 적용됨, 잘못된 링크, 공유 텍스트 "같은 시드로 나보다 잘 키워 봐 · 코드 <token>").
- 텔레메트리: `challenge_link_opened`(source: scheme|universal, valid), `challenge_link_shared`.

### 2.3 랜딩
- `apps/landing/app/challenge/[token]/page.tsx`: 토큰 표시, 앱 열기 버튼(스킴 링크), App Store 링크(id6794754217), OG 이미지 재사용. `public/.well-known/apple-app-site-association` 정적 JSON(`appID: "D48DDX5D5W.com.solkim.baseball.ios"`, paths `/challenge/*`) + `next.config.ts`에서 해당 경로를 `application/json`으로 서빙하는 헤더. 도메인 배포는 사용자가 해야 하므로 보고서에 절차를 적는다.

## 3. 수용 기준
1. `ChallengeLink.parse` 단위 테스트: 스킴/https/대소문자/잘못된 토큰/life 범위(ios-layers 테스트에서 실행).
2. iOS 테스트 파일 작성: 앱 진입 → pendingChallenge → 시작 화면 반영(스토어/뷰 계약), 커리어 진행 중 배너 노출, 잘못된 링크 무시. (PM이 실행)
3. 랜딩 페이지·AASA 파일 존재, JSON 유효(간단한 node 스크립트로 검증 가능하면 실행, npm은 금지이므로 `node -e`만).
4. `swift test --package-path packages/ios-layers` 종료 코드 0.

## 4. 산출물
`docs/P2_SEED_CHALLENGE_LINK_REPORT_2026-09-02.md`: 링크 형식, 배선 지점, 도메인 배포 절차(AASA·HTTPS·entitlement 값 설정), PM이 병합 후 실행할 명령(xcodegen, iOS 테스트, npm 게이트), 미해결.
