# Android 7차 QA 개선 결과 · 2026-09-09

계획: `ANDROID_QA_ROUND7_IMPROVEMENT_PLAN_2026-09-09.md`. 기존 미커밋 작업과 세이브를 보존한 추가 수정이다. 세이브 크기/재개 성능과 TalkBack은 요청대로 이번 구현·판정 범위에서 제외했다.

## W-01: 주간 보상 조건 통일

`HighSchoolWeeklyRules.MIN_COMPLETED_FOR_REWARD`와 `rewardRejection`을 버튼·보상 표시·본문 설명·명령 검증·커널 수령에 연결했다. 최소 완료 수는 기존 커널 규칙대로 2개다. 요약 카드에 남아 있던 ‘하나 완료’ 안내도 제거하고, 펼침 메뉴 밖에 현재 수령 조건을 항상 표시한다.

완료 0/1개에서는 버튼이 비활성이고 실행 payload도 없다. 완료 2/3개에서는 기존 야구혼 15점과 도장을 한 번만 지급한다. 이미 받았거나 챌린지인 경우는 해당 이유를 안내한다. 버튼의 접근성 설명도 실제 조건을 사용한다.

native 저장으로 완료 0~3개, 불충족 3회 직접 호출, 수령 후 3회 재호출, 재시작, 주차 변경과 도장 보존을 검증했다. 실패한 규칙 요청은 파일과 revision을 바꾸지 않는다. 실제 Compose 화면에서 1/3 비활성→2/3 수령→수령 후 비활성과 1회 지급도 확인했다. 이 화면 검증은 과제 진행 수를 통제한 실제 고교 저장 fixture이며, 고교 커리어를 새로 완주했다는 뜻은 아니다.

## W-02: 규칙 거부를 저장 실패로 분류하지 않음

실패를 규칙 거부, 상태 충돌, 투구 상태, 명시적 공간 부족, I/O, 저장 검증/버전, 쓰기 금지, 원인 미확정으로 나눴다. 알려진 weekly 코드는 사용자 언어로 이유를 표시하며 원시 오류 코드를 화면에 출력하지 않는다. 알 수 없는 GameCommandException을 전부 정상 규칙 거부로 간주하지도 않는다.

‘저장 공간 부족’은 Android ENOSPC 또는 FileSystemException의 명시적인 공간 부족 근거가 있을 때만 사용한다. 일반 IOException의 `disk full` 같은 문자열이나 반복 클릭 횟수로 이를 추정하지 않는다. 검증/직렬화/마이그레이션/쓰기 금지도 공간 부족으로 분류하지 않는다.

반복 집계는 실제 저장 실패에 한해 action·종류·원인 코드·revision으로 묶는다. 규칙 거부는 반복 집계를 해제하고, 성공이나 다른 상태에서도 이전 실패를 이어받지 않는다. MainActivity는 파일 확인 성공, durable 확인, 실제 revision 갱신을 구분한다. 규칙 거부 때문에 불필요한 저장 재확인을 수행하지 않는다.

`weekly.incomplete`·이미 수령·챌린지·커리어 범위 거부를 반복해도 저장 실패/공간 부족/같은 버튼 재시도 문구가 나오지 않는 것을 검사했다. 규칙→I/O→규칙, revision 변경, 성공 후 실패, 저장 오류 코드별 분류도 검증했다. 6차의 명령 ID·원인 로그와 투구 전용 복구 처리는 유지했다.

## W-03: 프로에서 고교 주간 노트 숨김

`WeeklyNotePolicy`가 활성 커리어의 범위를 정한다. 프로 진행/은퇴/유산 단계에서는 고교 주간 노트 진입 칩·보상 표시·화면 도달을 차단한다. 고교 기록이 저장 파일에 남아 있다는 이유만으로 프로에 노출하지 않는다. 고교·드래프트·고교 환생 단계의 유효한 소유권에서는 계속 사용할 수 있다.

native bridge와 일반 reducer도 동일 정책으로 주간 보상 명령을 검사한다. 프로에서 캐시된 화면이나 직접 명령으로 고교 보상을 받을 수 없다. 잘못 복원된 P-024 화면은 기존 도달성 처리에 따라 유효한 화면으로 돌아간다. 기록 탭은 숨긴 칩의 빈자리를 남기지 않고 다시 배치한다.

기존 도장·수령 이력·야구혼·고교 기록은 삭제하거나 회수하지 않았다. 프로용 새 과제나 보상 밸런스를 만들지 않았다. 연계 프로 native fixture의 직접 요청 거부와 한/영/일 기록 화면의 주간 노트 비노출을 확인했다.

## W-04: 첫 실행 브라우저에 막히지 않는 문서 읽기

처음에는 Custom Tabs를 적용했지만, 실제 에뮬레이터에서 Chrome 첫 실행 화면이 나와 개인정보 본문에 도달하지 못했다. 해당 실패 캡처를 `link-first-attempt.png`에 보존했다. Custom Tabs 적용만으로 이 경우가 해결됐다고 처리하지 않았다.

최종 동작은 다음과 같다.

- 개인정보·문의 기본 진입은 앱 내부의 읽기 전용 `PolicyDocumentActivity`에서 해당 공식 HTTPS 페이지를 연다. 브라우저 계정 추가나 초기 설정이 필요 없다.
- `브라우저로 열기`는 Custom Tabs를 우선 사용하고, 미지원/실행 거부 시 일반 브라우저로 시도한다. 브라우저가 없으면 안내하며 URL 복사 경로는 남는다.
- 문서 읽기는 JavaScript·파일·content 접근을 끄고, 혼합 콘텐츠와 TLS 오류를 허용하지 않는다. 다른 앱이 문서 Activity를 직접 호출할 수 없으며 최초 URL은 개인정보/문의 두 주소로 제한한다.
- 로드 실패에는 재시도·브라우저 열기·주소 복사를 제공한다. WebView 자체를 만들 수 없는 환경에서도 오류 안내와 대체 버튼을 유지한다.

Chrome 초기 설정을 완료하지 않은 상태에서 두 본문의 제목을 실제 앱에서 확인했고, 뒤로 가면 설정 도움말로 돌아오는 것도 통과했다. 미지원/브라우저 없음/실행 거부는 launcher 대체 경로 테스트로 검사했다. 실제 기기에서 브라우저를 삭제하거나 네트워크를 끊은 시험은 수행하지 않았으며, 모든 브라우저/네트워크 조합을 실측했다고 주장하지 않는다.

새 의존성은 AndroidX Browser 1.8.0 하나이며 버전을 고정했다. 다른 라이브러리의 버전은 올리지 않았다. lockfile에는 새 모듈 및 해석된 build/test configuration을 반영했다. API 근거: [AndroidX Browser 릴리스 기록](https://developer.android.com/jetpack/androidx/releases/browser), [CustomTabsClient](https://developer.android.com/reference/androidx/browser/customtabs/CustomTabsClient).

## 검증 범위

- 단위 테스트 **31개 통과**: game-application 26개(Phase8ScreenProjection 13, Round7Weekly 3, Round4Transitions 6, SeedChallenge 4), game-core 5개(HighSchoolPhase4MetaRules).
- 계측 **고유 6개 통과**: Round7WeeklyUi 4개, Round4LivePitchUi 2개. 주간 보상, 프로 비노출, 링크 본문/복귀, 링크 실패 대체 경로와 기존 수동 슬라이더·고피로 종료·실제 중단 파일의 포기/재개를 포함한다.
- 한국어·영어·일본어 앱 문구를 반영하고 문구 매핑/가상 야구 콘텐츠 게이트를 검사했다. 웹 문서 자체는 기존 공식 사이트의 내용을 표시한다.
- release Kotlin 컴파일은 통과했다. 이는 서명된 RC 생성·설치 검증과 다르다.
- 최종 문구 매핑 3,264/3,264, 누락 0. 가상 야구 콘텐츠 문구 검사와 `git diff --check`도 통과했다.

전체 프로젝트 스위트 또는 실기기 검증 완료라는 의미는 아니다. 성능 측정과 TalkBack은 이번 결과에 포함하지 않는다.

## 사용자용 QA 업데이트

`com.solkim.baseball.android.compose.qa`를 초기화 없이 업데이트했다. 설치 ID·highSchool(주간 과제/도장 포함)·pro·pitchResume·앨범이 전후 동일하고, 작업 시작 시 보존한 원본과 비교해도 커리어가 유지됐다. 실제 사용자 QA 앱의 프로 기록 화면에서 `records.tab.P-024`가 없는 것을 확인했다.

- 빌드: debug + baseballLaunchQa + baseballQaNativeStore. 서명 RC 아님.
- APK SHA-256: `c4667148993499540cb28e5a94111f92177f72a3d07f6733d0b28be541f32f20`.
- 보존 비교: `update-preservation.json`; 최종 화면/트리: `updated-pro-records.png`, `updated-pro-records.xml`.
- 소스 기준: `source-manifest.json`. 통제된 주간 fixture와 테스트 클래스가 사용자용 APK에 포함되지 않음을 DEX에서 확인했다.

## 증거와 남은 조건

증거: `artifacts/qa/android-round7-fixes-2026-09-09/`의 단위/계측 로그, 1/3·수령 후 주간 화면, 프로 기록 화면, 개인정보·문의 본문과 Activity 기록, 브라우저 첫 실행 실패 캡처.

연결 기기는 `emulator-5554` 한 대였다. 실기기 검증은 기기 연결이 필요하며 RC preflight는 `BASEBALL_UPLOAD_KEYSTORE_PATH` 미설정으로 중단됐다. 서명 조건을 우회하지 않았고 스토어 업로드·출시는 수행하지 않았다.
