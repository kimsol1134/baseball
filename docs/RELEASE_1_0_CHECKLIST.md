# Project Diamond Soul 1.0 출시 체크리스트

기준일: 2026-07-22  
현재 출시 범위: Steam 유료 정식판과 별도 무료 데모
출시 순서: Windows 11 x64 우선, macOS는 서명·공증과 양 아키텍처 QA 후 추가
버전: 1.0.0

## 완료된 기술 게이트

- Swift 공유 코어의 단위·결정론·프로토콜 테스트 전체 통과
- React 단위 테스트, TypeScript 검사, Vite 프로덕션 빌드 통과
- Rust/Tauri 코어 검사와 macOS 앱 번들 생성
- 손상 저장 복구, 정상 백업 순환, 선택 확정 시 자동 저장
- 고대비, 글자 확대, 모션 감소, 효과음·진동 개별 설정
- 실제 데스크톱 앱에서 저장 복원, 중요 이닝 진입, 한 공 투구와 결과 상세 접기 확인
- 앱과 코어 버전 1.0.0 정렬, 제한된 CSP와 번들 아이콘 적용
- 개발용 프로 권한은 개발 빌드에서만 생성하며 공개 빌드에서는 자동 해금하지 않음
- iOS 개인정보 매니페스트 포함, generic Simulator 빌드 통과
- 프로덕션 npm 의존성 감사 결과 알려진 취약점 0건
- 로컬 옵트인 계측에 투구·커리어 결정 시간과 공당 조작 수 포함
- Steam 정식판·데모 빌드 권한 분리와 설정 누락 시 데모 기본값 적용
- Windows·macOS 공용 Steam Cloud 파일 스키마, 두 슬롯 회전 저장과 손상 복구 테스트 통과
- macOS ARM64 Steam 정식판·데모 데포 생성, 파일 체크섬과 sidecar 상태 검사 통과
- macOS 실제 앱 종료 시 회전 저장 flush와 접근성·분석 설정 제외 확인
- 데모가 첫 중요 경기 뒤 종료되고 정식판은 제한되지 않는 회귀 테스트
- Developer ID 인증서가 있으면 서명·공증하고 stapling을 검증하는 CI 경로 구성

## 현재 로컬 산출물

- 정식판: `artifacts/steam/full/macos-arm64/Project Diamond Soul.app`
- 데모: `artifacts/steam/demo/macos-arm64/Project Diamond Soul.app`
- 각 데포: 5개 파일, 26,599,491 bytes
- 검증: manifest SHA-256 전수 검사, sidecar health, `codesign --verify --deep --strict` 통과
- 실제 실행: 정식판 실행·종료와 종료 직전 저장 파일 기록 통과
- 제한: ad-hoc 서명이므로 Developer ID 서명·공증 전에는 공개 업로드 대상이 아님

## 공개 전 필수 게이트

### 제품

- [ ] 야구 게임을 처음 접하는 사용자 포함 30명 플레이테스트
- [ ] 중요 이닝 중앙 조작 수 18회 이하 확인
- [ ] 첫 삶 완료율, 다음 삶 시작률, 결과 원인 회상, 기억나는 인물 측정
- [ ] 치명적 크래시 0건, 저장 유실 0건, 진행 불가 0건
- [ ] 플레이테스트 결과에 따라 난이도·드래프트 분포 최종 고정
- [ ] [Steam 외부 테스트 계획](./STEAM_EXTERNAL_TEST_PLAN.md)의 Wave 0~2와 수치 게이트 통과

### macOS 배포

- [ ] Apple Developer ID Application 인증서로 앱과 sidecar 서명
- [ ] Hardened Runtime과 필요한 entitlement 최소화 확인
- [ ] 공증 제출과 stapling 완료
- [ ] Steam 비공개 브랜치에서 `.app` 설치·첫 실행·업데이트·삭제 확인
- [ ] `spctl`과 `codesign --verify --deep --strict` 통과

### Windows 배포

- [x] Windows CI에서 SteamPipe용 무설치 데포 폴더를 생성하는 워크플로 구성
- [ ] 원격 Windows CI의 실제 데포 생성 성공 확인
- [ ] 앱과 Swift sidecar 코드 서명
- [ ] Windows 11 표준 사용자 Steam 설치·실행·업데이트·삭제 확인
- [ ] SmartScreen, 방화벽, 백신 오탐 확인
- [ ] 키보드 전용·125/150/200% 배율·고대비 확인

### Steam 정식판과 데모

- [x] 배포 채널을 Steam으로 확정
- [x] 정식판과 데모의 프로 커리어 접근을 빌드 종류로 분리
- [ ] Steamworks 파트너 등록, 정식판 App ID와 데모 App ID 발급
- [ ] `Coming Soon` 페이지 최소 2주 공개와 정식 출시 30일 대기 충족
- [x] `localStorage` 자동 저장을 Steam Auto-Cloud용 회전 파일 저장으로 미러링
- [ ] 데모 저장의 정식판 승계와 다른 기기 복원 확인
- [ ] 가격·환불·고객지원 문구 검토
- [ ] 상점 자산과 실제 플레이 트레일러 준비
- [ ] Valve 스토어·빌드 검토 제출

### 이번 Steam 1.0 범위 밖

- iOS 정식판과 StoreKit은 Steam 출시 뒤 재검토한다.
- 모바일 웹은 설치 없는 티저와 Steam 위시리스트 유입에만 사용한다.

### 법무·운영

- [ ] `Project Diamond Soul` 명칭과 아이콘 상표 충돌 검토
- [ ] 개인정보 처리방침, 이용약관, 고객지원 주소 게시
- [ ] 야구 구단·선수·리그의 실제 상표나 식별 요소가 없는지 최종 확인
- [ ] 크래시·진단 데이터의 옵트인, 보존 기간, 삭제 절차 검토
- [ ] 릴리스 태그, 변경 내역, 롤백 가능한 이전 설치 파일 보관

## 재현 명령

```sh
npm ci
npm run check
xcodebuild -project apps/ios/ProjectDiamondSoul.xcodeproj \
  -scheme DiamondSoulIOS -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
npm run desktop:build -- --bundles app,dmg
npm run steam:build:full
npm run steam:smoke -- artifacts/steam/full/macos-arm64
npm run steam:build:demo
npm run steam:smoke -- artifacts/steam/demo/macos-arm64
```

일반 로컬 산출물은 `apps/windows/src-tauri/target/release/bundle/` 아래에 생성한다. 이 파일은 기능 검증용이며 서명·공증 전에는 공개 배포하지 않는다.

Steam 데포는 `artifacts/steam/<edition>/<platform>/` 아래에 생성한다. macOS ARM64 정식판과 데모 데포는 로컬 체크섬·sidecar 검사를 통과했지만 ad-hoc 서명이므로 공개 업로드 대상이 아니다.
