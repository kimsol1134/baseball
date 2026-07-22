# Project Diamond Soul 1.0 출시 체크리스트

기준일: 2026-07-22  
현재 출시 범위: 무료 고교 커리어 데스크톱 앱  
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

## 현재 로컬 산출물

- 앱: `apps/windows/src-tauri/target/release/bundle/macos/Project Diamond Soul.app`
- 설치 이미지: `apps/windows/src-tauri/target/release/bundle/dmg/Project Diamond Soul_1.0.0_aarch64.dmg`
- DMG 크기: 4,502,789 bytes
- SHA-256: `9df5e9fe2f6547c473547ade14aea057e02abb7b6b9950a623cabf9e1296dc54`
- 검증: `codesign --verify --deep --strict` 통과, `hdiutil verify` 통과
- 예상 제한: ad-hoc 서명이므로 Developer ID 서명·공증 전 Gatekeeper 평가는 거부됨

## 공개 전 필수 게이트

### 제품

- [ ] 야구 게임을 처음 접하는 사용자 포함 30명 플레이테스트
- [ ] 중요 이닝 중앙 조작 수 18회 이하 확인
- [ ] 첫 삶 완료율, 다음 삶 시작률, 결과 원인 회상, 기억나는 인물 측정
- [ ] 치명적 크래시 0건, 저장 유실 0건, 진행 불가 0건
- [ ] 플레이테스트 결과에 따라 난이도·드래프트 분포 최종 고정

### macOS 배포

- [ ] Apple Developer ID Application 인증서로 앱과 sidecar 서명
- [ ] Hardened Runtime과 필요한 entitlement 최소화 확인
- [ ] 공증 제출과 stapling 완료
- [ ] 새 사용자 계정에서 DMG 설치·첫 실행·업데이트·삭제 확인
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

### iOS

- [ ] 무료 고교에서 프로로 이어지는 실제 제품 진입 흐름 확정
- [ ] StoreKit 2 구매·복원과 현재 entitlement 연동
- [ ] 실제 iPhone/iPad에서 VoiceOver, Dynamic Type, 햅틱, 백그라운드 저장 확인
- [ ] 강제 종료·저장 복원·오프라인 실행·구매 복원 확인
- [ ] App Store 개인정보, 연령 등급, 스크린샷과 심사 노트 완료

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
```

로컬 산출물은 `apps/windows/src-tauri/target/release/bundle/` 아래에 생성한다. 이 파일은 기능 검증용이며 서명·공증 전에는 공개 배포하지 않는다.

Steam 데포는 `artifacts/steam/<edition>/<platform>/` 아래에 생성한다. macOS ARM64 정식판과 데모 데포는 로컬 체크섬·sidecar 검사를 통과했지만 ad-hoc 서명이므로 공개 업로드 대상이 아니다.
