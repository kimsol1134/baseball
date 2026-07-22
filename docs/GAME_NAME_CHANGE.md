# 게임명 변경 기록

기준일: 2026-07-22  
상태: 확정

## 결정

정식 게임명을 **야구 못하면 또 환생함**으로 변경한다.

- 현재 정식명: `야구 못하면 또 환생함`
- 구 공개명·프로젝트 코드명: `Project Diamond Soul`
- 기존 기획 단계 후보명: `야구혼`

`야구혼`은 정식 게임명이 아니라 여러 삶을 거치며 축적되는 인게임 메타 진행의 명칭으로만 유지한다.

## 적용 범위

다음 사용자 노출 영역은 새 정식명으로 통일한다.

- 랜딩페이지 제목, 메타데이터, 접근성 이름, 소셜 공유 이미지
- Windows·macOS 데스크톱 앱 표시명과 창 제목
- iOS 앱 표시명과 빌드 제품명
- Steam 빌드 설명, macOS 앱 번들명, 스토어·출시 문서
- 루트 README, 개발 문서, 마스터 Markdown·Word 문서
- 스키마와 예제 콘텐츠의 사람이 읽는 제목·작성자 표기

## 호환성을 위해 유지하는 내부 식별자

아래 값은 외부에 표시되는 게임명이 아니라 저장·빌드·프로젝트 호환성을 위한 기술 식별자이므로 이번 변경에서 유지한다.

- npm 패키지·워크스페이스: `project-diamond-soul`, `@diamond-soul/*`
- Rust 크레이트·실행 파일: `diamond-soul`, `diamond-soul.exe`
- 저장 키·이벤트·파일 접두사: `diamond-soul.*`
- JSON Schema `$id`: `https://diamond-soul.local/...`
- Tauri·iOS 번들 ID: `com.solkim.diamondsoul`, `com.diamondsoul.ios`
- Xcode 프로젝트·타깃·스킴: `ProjectDiamondSoul`, `DiamondSoulIOS`
- CI 아티팩트·키체인 등 자동화용 `diamond-soul-*` 식별자

이 값들을 바꾸려면 기존 저장 데이터 마이그레이션, 설치 업데이트 경로, 클라우드 저장, 서명·배포 설정을 별도 검증해야 한다.

## 출시 체크

- Steam Coming Soon 페이지 검토 전에 새 정식명의 상표·검색 혼동 가능성을 확인한다.
- Steamworks App ID가 발급되면 스토어 제목, 데모 연결, 위시리스트 URL을 새 정식명 기준으로 최종 검수한다.
- 새 이름이 적용된 Windows·macOS·iOS 빌드의 설치명과 실행 파일 경로를 실제 배포 환경에서 확인한다.
