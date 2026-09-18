# Android 리뷰 요청 연결

현재 Compose 앱의 리뷰 요청을 실제 플레이어 행동에 연결했다. 배포·업로드는 수행하지 않았다.

## 사용자 경험

- 지명 결과 또는 목표 달성·개인 최고 평가 결산을 읽고 유산 선택/기록 마무리/프로 진출을 진행한 뒤 Google Play 인앱 리뷰를 요청한다.
- 세 번째 생부터 기존 환생과 선발·마무리·제구형 새 경로 모두 요청 대상이다. 새 경로가 프롤로그를 건너뛰고 학교 선택으로 이동해도 동작한다.
- 화면을 열기만 하거나 저장 명령이 실패한 경우, 도전 모드, 투구 화면을 여는 행동에서는 요청하지 않는다.
- 기존 영속 제한(사유별 한 번, 요청 간 최소 24시간)을 유지한다.
- 리뷰 정보를 가져오는 단계의 네트워크 오류는 요청 기회를 소진하지 않는다. 요청 준비 중 중복 호출을 막고, 화면/진행이 바뀌거나 앱이 포커스를 잃으면 늦게 도착한 요청을 취소한다. 실제 launch 시도 뒤의 실패는 중복 노출을 피하기 위해 기록을 유지한다.
- 설정 첫 화면에 `Google Play에 리뷰 남기기`와 솔직한 플레이 경험을 요청하는 안내를 추가했다. 한국어·영어·일본어를 지원한다. 이 버튼은 인앱 리뷰 API 대신 공개 스토어 페이지를 열며, Play 앱이 없으면 웹으로 연결한다.

Google Play는 팝업 노출 여부·리뷰 작성 여부를 반환하지 않는다. 성공 콜백을 실제 리뷰 작성으로 집계하지 않는다. 별점 선별 질문이나 리뷰 보상은 없다. 참고: [Google 인앱 리뷰 안내](https://developer.android.com/guide/playcore/in-app-review), [Kotlin 통합 안내](https://developer.android.com/guide/playcore/in-app-review/kotlin-java).

## 구현

- `ReviewMomentPolicy.reasonAfter`는 저장 전후 상태와 실제 액션으로 요청 사유를 판별한다. 과거 숨겨진 확인 버튼의 별도 analytics receipt에 의존하지 않는다.
- `MainActivity`는 저장 성공 뒤 정책을 호출하고 늦은 응답의 유효성을 검사한다.
- `NativePlayReviewService`는 ReviewInfo 준비 후 launch 직전에 영속 요청 사유를 예약한다.
- `ReviewStoreLinks`는 프로덕션 앱 ID를 고정해 QA/디버그 패키지로 잘못 연결되지 않게 한다.
- 번역 원본은 `docs/localization/android-copy.json`에 추가했다. 전체 catalogue 재생성은 기존 원본과 생성물 사이의 무관한 차이까지 반영하므로, 런타임 catalogue에는 이번 세 키와 대응 source index만 반영했다.

## 검증

- Android debug APK 및 instrumentation APK 빌드 성공.
- `ScreenProjectionTest`/`GameCopyTest`: 23개 통과. 실제 결산 마무리와 네 환생 액션 실행, 세 번째 생 조건, 도전/미완료/중복/설치 변경 제외 검증 포함.
- `PlatformContractTest`: 29개 통과. 영속 기록과 사유별 중복·24시간 제한 포함.
- 앱 JVM 테스트: 16개 통과.
- 에뮬레이터 instrumentation: 설정의 세 언어·글자 배율 2배 표시, Play 앱/브라우저 fallback/모두 불가 분기 검증.
- 새 리뷰 문구의 실존 구단명·약칭 검색, 변경 공백 검사 통과.
- 증거: `artifacts/android-compose/review-qa/2026-09-13/` (설정 스크린샷 3장과 빌드/테스트 로그).

테스트는 격리 패키지 `com.solkim.baseball.android.review.compose.qa`에서 실행했다. 실제 Play 배포 계정의 네이티브 리뷰 팝업 노출과 리뷰 증가/설치 전환 효과는 이번 검증 범위에 포함되지 않는다.
