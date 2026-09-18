# Android 1.0.1 (43) 프로덕션 제출 — 2026-09-13

리뷰 유도 기능을 포함한 서명 빌드를 Google Play 프로덕션에 제출했다. 콘솔에서 **검토 중인 변경사항 / 1.0.1 (43) / 전체 출시 시작**을 확인했다. 최종 확인 시 자동 사전 검사가 진행 중이며, 검사 성공 후 Google 심사로 전송된다. 관리형 게시가 꺼져 있어 승인 후 자동 공개된다. 아직 실제 공개 완료로 판정하지 않는다.

## 배포 범위

- 패키지: `com.solkim.baseball.android`
- 기존 1.0.0 (42) → 1.0.1 (43), 기존 대상 국가 전체, 출시율 100%.
- 국가·가격 변경 없음. 한국어·영어·일본어 출시 노트 포함.
- 리뷰 요청은 실제 커리어 진행 뒤에 연결하고, 설정에서 스토어 리뷰 페이지를 열 수 있다.
- 작업 중이던 별도 투구 UI·iOS·마케팅 수정은 포함하지 않았다.

## 소스와 검증

- 소스: `codex/android-review-release-20260913`, 커밋 `7caf6bd36044470dd0c583b26c7d6724b33ac859`.
- [릴리스 CI](https://github.com/kimsol1134/baseball/actions/runs/34753159776): 성공, 테스트 419개 통과.
- 서명 AAB SHA-256: `653c004c02c99f4f47ba98dbc204c7e742c3d329b56c3e779982f666c9d9ba1e`.
- AAB/APK DEX 일치, 서명 인증서 확인, 16KB 네이티브 정렬 및 APK 정렬 확인.
- Samsung 실기기에서 42→43 업데이트 후 등판 상태·투구 수·피로 보존 확인.
- 실기기 설정의 리뷰 링크가 정확한 Google Play 앱 페이지를 여는 것 확인.
- 16KB 에뮬레이터에서 기존 기록 복원, 기본 슬라이더 직접 투구 완료(루킹 스트라이크 144.3km/h), 재시작 후 기록 보존 확인.
- Play 검사: 지원 기기 감소 없음. 가독화 파일·네이티브 디버그 기호 미첨부 권장 경고 2개, 제출 차단 오류 없음.

## 증거 및 정리

- `artifacts/android-compose/review-release-43/deployment.json`
- `artifacts/android-compose/review-release-43/verification/`
- `artifacts/android-compose/review-release-43/rc/`: 서명 배포 산출물.
- 재현 가능한 격리 소스는 `artifacts/android-compose/review-release-source/`에 보존.
- 작업 전용 16KB 에뮬레이터와 AVD 삭제 완료. 일회성 CI runner 정상 종료.

[Play 게시 개요](https://play.google.com/console/u/1/developers/5198814359992339237/app/4973220489799176676/publishing)
