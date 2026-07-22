# 야구 못하면 또 환생함 Steam 출시 계획

기준일: 2026-07-22  
최종 목표: Steam 정식 출시  
첫 지원 플랫폼: Windows 11 x64  
두 번째 플랫폼: macOS 13 이상

## 1. 확정한 제품 구조

첫 Steam 출시는 다음 두 앱으로 준비한다.

1. **야구 못하면 또 환생함 정식판**: 고교 커리어부터 프로 은퇴까지 포함하는 유료 게임.
2. **야구 못하면 또 환생함 Demo**: 핵심 투구, 성장, 관계, 첫 중요 경기까지 보여 주는 무료 데모.

무료 고교 베이스 게임과 프로 커리어 DLC를 따로 판매하지 않는다. 첫 제품에서 구매·복원·환불 권한을 게임 내부에 별도로 구현하면 출시 위험과 사용자 설명 비용이 커진다. 정식판 구매 자체를 전체 콘텐츠 권한으로 삼고, 데모와 정식판은 빌드 종류로 구분한다.

현재 코드는 `steam_full`, `steam_demo`, `web_teaser` 빌드를 구분한다. 정식판만 프로 커리어를 포함하며, 설정이 빠진 프로덕션 빌드는 데모로 닫힌다. 데모는 첫 중요 경기 결과가 저장된 뒤 선수 기록과 정식판에서 이어질 범위를 보여 주고 더 진행하지 않는다.

## 2. 채널 우선순위

| 우선순위 | 채널 | 역할 |
|---|---|---|
| 1 | Steam Windows | 본 제품, 외부 테스트, 첫 매출과 리뷰 |
| 2 | Steam macOS | Apple 서명·공증과 Intel/Apple Silicon QA 후 같은 스토어 페이지에 추가 |
| 3 | 모바일 웹 | 10~15분 분량의 선택형 티저와 Steam 위시리스트 유입 |
| 보류 | iOS 정식판 | Steam 출시와 밸런스 안정화 이후 재검토 |

모바일 웹에 전체 게임을 먼저 배포하지 않는다. 전체 Swift 엔진을 위한 서버 운영, 모바일·Steam 간 계정과 저장 동기화, 정식판 가치 설명이 동시에 필요해진다. 웹은 설치 없는 체험이라는 장점만 살리고 본편은 Steam에 집중한다.

## 3. 출시 방식

정식 출시 전 `Coming Soon` 페이지와 Steam 데모를 먼저 공개한다. 현재 단계에서는 Early Access로 판매하지 않는다. 외부 테스트에서 프로 커리어의 완주 품질이 정식 출시 기준에 못 미칠 때만 Early Access를 다시 검토한다.

Steam Direct에서 배포할 새 정식 제품의 앱 등록비는 미화 100달러다. 정식 제품 App ID를 만든 뒤 그 제품 관리 페이지에서 별도의 연동 데모 App ID를 추가한다. 첫 제품은 등록비 결제 후 출시까지 30일 대기와 최소 2주의 공개 `Coming Soon` 기간이 필요하므로 Steamworks 등록과 스토어 페이지 준비를 먼저 시작한다.

## 4. 기술 출시 구조

### Windows 데포

- SteamPipe에는 NSIS/MSI 설치 파일이 아니라 실행 가능한 게임 폴더를 올린다.
- 게임 실행 파일, Swift sidecar, 같은 Swift 버전의 런타임 DLL, 고지 문서를 한 데포에 포함한다.
- sidecar 빌드 입력의 target-triple 접미사는 Tauri 번들 단계에서 제거하고, 실행 시 앱이 찾는 `simulation-sidecar.exe` 이름으로 데포에 넣는다.
- Steam에서 설치한 일반 사용자 권한으로 첫 실행, 저장, 업데이트, 삭제를 검증한다.
- WebView2가 없는 환경의 선행 설치 정책을 Steam 설치 스크립트 또는 고정 런타임 번들 중 하나로 확정한다.
- 코드 서명은 SmartScreen 신뢰와 백신 오탐 감소를 위해 공개 전 적용한다.

### macOS 데포

- DMG가 아니라 공증된 `.app` 번들을 macOS 데포에 올린다.
- Developer ID 서명, Hardened Runtime, Apple 공증을 완료한다.
- Steam 오버레이를 연동할 경우 Valve가 안내하는 macOS entitlement를 적용한다.
- Apple Silicon과 Intel 빌드를 각각 검증하거나 universal 앱을 만든다.

### 저장

- 현재 브라우저 `localStorage` 자동 저장을 플랫폼의 사용자 데이터 폴더에 있는 명시적 저장 파일로 이전한다.
- 정식판과 데모가 같은 저장 스키마를 사용하고, 데모 종료 저장을 정식판이 승계한다.
- Steam Auto-Cloud에 저장 파일 경로를 등록해 API 코드 없이 동기화를 먼저 제공한다.
- Windows와 macOS가 같은 파일을 읽도록 OS별 경로만 다르고 데이터 포맷은 동일하게 유지한다.

### Steamworks 기능

Steamworks API 통합은 출시 자체의 필수 조건이 아니다. 첫 업로드는 API 없이도 가능하게 유지하고 다음 순서로 추가한다.

1. Steam Auto-Cloud
2. Steam 오버레이와 정식판 스토어 이동
3. 업적
4. 필요할 때만 플레이 시간·통계·리더보드

Steam App ID가 발급되기 전에는 코드에 임의 ID를 넣지 않는다. `steam_appid.txt`는 로컬 개발용으로만 만들고 공개 데포에는 포함하지 않는다.

## 5. 데모 범위

데모는 플레이어가 다음 세 가지를 직접 경험한 뒤 끝나야 한다.

- 포수 추천을 참고하거나 거슬러 한 타석을 해결한다.
- 훈련 또는 관계 선택 하나가 다음 중요 경기에서 되돌아온다.
- 첫 중요 경기와 성장 결과를 보고 정식판에서 이어질 목표를 이해한다.

권장 플레이 시간은 30~45분이다. 전체 고교 커리어를 무료로 제공하지 않는다. 데모 종료 화면은 개발 용어나 결제 압박 없이 현재 선수의 기록, 이어질 프로 가능성, 정식판·위시리스트 이동만 보여 준다.

## 6. 출시 게이트

### Steamworks 운영

- [ ] Steamworks 파트너 등록과 세금·지급 정보 완료
- [ ] 정식판 앱 등록비 결제와 App ID 발급
- [ ] 데모 App ID 생성과 정식판 연결
- [ ] `Coming Soon` 페이지를 출시 최소 2주 전에 공개
- [ ] 가격, 지원 언어, 고객지원 연락처 확정

### 빌드

- [x] Windows Steam 데포 폴더 생성·검사 CI 구성
- [x] 원격 Windows CI에서 NSIS 설치 파일 생성, 무인 설치, Swift sidecar 상태 검사 통과
- [ ] 실제 원격 Windows CI에서 데포 생성 성공 확인
- [ ] GitHub Actions 결제 또는 지출 한도를 복구한 뒤 `Steam depot artifacts` 6개 작업 재실행
- [ ] 깨끗한 Windows 11 표준 사용자 계정에서 Steam 설치·실행·업데이트·삭제 통과
- [ ] sidecar와 Swift 런타임 누락 없이 오프라인 실행 통과
- [x] 정식판·데모 공용 회전 파일 저장과 단일 기기 손상 복구 통과
- [x] 실제 macOS 앱 종료 직전 저장 flush와 관리 대상 키만 기록되는지 확인
- [ ] Steam에서 데모 저장을 정식판이 승계
- [ ] Steam Auto-Cloud 다른 기기 동기화·충돌 복구 통과
- [ ] macOS는 서명·공증·Steam 실행을 통과한 뒤 지원 OS에 표시

### 제품

- [ ] 야구 게임 초보자를 포함한 외부 플레이테스트 30명
- [ ] 첫 세션 진행 불가, 저장 유실, 치명적 크래시 0건
- [ ] 데모 완료율과 위시리스트 전환 측정
- [ ] 정식판 프로 커리어 최소 10개 시드 완주 QA
- [ ] 실제 출시 화면만 사용한 트레일러와 스크린샷 준비

### Valve 검토

- [ ] 스토어 페이지와 정식 빌드를 목표일 최소 7영업일 전에 검토 제출
- [ ] 표시한 모든 OS에서 실행 확인
- [ ] 스토어에 적은 기능이 현재 빌드에 모두 포함됨을 확인
- [ ] 데모는 별도 체크리스트와 데포 검토 통과

스토어 설명과 자산 범위는 [STEAM_STORE_PAGE_DRAFT.md](./STEAM_STORE_PAGE_DRAFT.md)에서 관리한다.

## 7. 현재 판정

| 항목 | 판정 | 이유 |
|---|---|---|
| 게임 기능 | 출시 후보 | 고교·프로 완주 흐름과 자동 테스트가 있으나 외부 테스트가 없음 |
| Windows Steam판 | 설치형 RC 통과·데포 검증 대기 | 원격 Windows CI에서 NSIS 생성, 무인 설치, Swift 런타임 포함, sidecar 상태 검사를 통과했다. Steam 무설치 데포 작업은 GitHub Actions 지출 한도 때문에 실행 전에 차단됨 |
| macOS Steam판 | ARM64 내부 RC 통과 | 정식판·데모 체크섬, sidecar, 번들 무결성, 실제 종료 저장을 통과했다. 빈 서명 ID 대신 ad-hoc 서명을 명시하는 수정도 같은 커밋에서 재검증했다. Intel 원격 빌드와 Developer ID 서명·공증은 남아 있음 |
| Steam 데모 | 내부 RC 통과 | 첫 중요 경기 종료 지점, 정식판과 같은 저장 파일, ARM64 데포와 종료 조건 회귀 테스트를 구현했으나 Steam App ID와 외부 테스트가 없음 |
| 모바일 웹 | 보조 채널 | 반응형·웹 실행 경계의 기반만 유지하고 본편보다 우선하지 않음 |

따라서 지금 앱을 Steam에 바로 제출할 수는 없다. 저장·데모·데포 생성 코드에서 로컬로 끝낼 수 있는 작업과 Windows 설치형 RC 검증은 완료했다. 다음 순서는 **GitHub Actions 결제/지출 한도 복구와 Steam 6종 CI 재실행 → Steamworks 등록과 App ID 발급 → 깨끗한 Windows Steam QA → 외부 데모 테스트 → 스토어·빌드 검토**다. 테스트 운영 기준은 [STEAM_EXTERNAL_TEST_PLAN.md](./STEAM_EXTERNAL_TEST_PLAN.md)를 따른다.

## 8. 공식 근거

- [Steam Direct 등록비와 회수 조건](https://partner.steamgames.com/doc/gettingstarted/appfee)
- [첫 제품의 30일 대기와 2주 Coming Soon 요건](https://partner.steamgames.com/steamdirect/)
- [Steam 데모 구성과 정식판 저장 승계](https://partner.steamgames.com/doc/store/application/demos?l=english)
- [SteamPipe 빌드·데포 업로드](https://partner.steamgames.com/doc/sdk/uploading?language=english)
- [Valve 스토어·빌드 검토 절차](https://partner.steamgames.com/doc/store/review_process?language=english)
- [Steamworks API는 출시에 필수가 아님](https://partner.steamgames.com/doc/sdk/api?language=english)
- [Steam Auto-Cloud](https://partner.steamgames.com/doc/features/cloud?language=english)
- [macOS 64비트·Apple 공증 요건](https://partner.steamgames.com/doc/store/application/platforms?language=english)
- [Tauri macOS Developer ID 서명과 공증 환경 변수](https://v2.tauri.app/distribute/sign/macos/)
- [Tauri sidecar 빌드 입력과 런타임 이름 규칙](https://v2.tauri.app/develop/sidecar/)
- [GitHub-hosted Windows·Intel/Apple Silicon macOS 러너](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
