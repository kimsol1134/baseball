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

## 내부 식별자 변경

프로젝트 내부 식별자는 `baseball` 네임스페이스로 통일한다.

- npm 패키지·워크스페이스: `baseball`, `@baseball/*`
- Rust 크레이트·실행 파일: `baseball`, `baseball.exe`
- 저장 키·이벤트·파일 접두사: `baseball.*`
- JSON Schema `$id`: `https://baseball.local/...`
- Tauri·iOS 번들 ID: `com.solkim.baseball`, `com.solkim.baseball.ios`
- Xcode 프로젝트·타깃·스킴: `Baseball`, `BaseballIOS`
- CI 아티팩트·키체인 등 자동화용 `baseball-*` 식별자

기존 `diamond-soul` 저장과 설치 경로를 자동 마이그레이션하지 않는 브레이킹 변경이다.

## 출시 체크

- Steam Coming Soon 페이지 검토 전에 새 정식명의 상표·검색 혼동 가능성을 확인한다.
- Steamworks App ID가 발급되면 스토어 제목, 데모 연결, 위시리스트 URL을 새 정식명 기준으로 최종 검수한다.
- 새 이름이 적용된 Windows·macOS·iOS 빌드의 설치명과 실행 파일 경로를 실제 배포 환경에서 확인한다.
