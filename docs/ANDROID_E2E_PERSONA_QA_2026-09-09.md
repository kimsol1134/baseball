# 안드로이드 출시 전 페르소나 E2E QA (2026-09-09)

에뮬레이터(Pixel API 35, 1080×2400)에서 페르소나 5인의 관점으로 온보딩 → 첫 공식 경기 → 저장·복원 → 기기 변경까지 직접 조작해 검증했다.
보고서 아티팩트: https://claude.ai/code/artifact/91af66b3-8caa-4cfb-b1d6-7ad562a8db88

- 대상 빌드: `com.solkim.baseball.android.compose.qa` (`-PbaseballLaunchQa=true -PbaseballQaNativeStore=true`, versionCode 42 / 1.0.0-migration). 릴리스와 같은 `nativeAuthoritative` 저장 모드. 서명된 release APK는 아니다(키스토어 미설정).
- 기준 커밋 80c34832, 설치 빌드는 09:46 트리. **QA 중(09:54~) 다른 세션이 `ConversationScreen.kt`·`ConversationPresentation.kt`·`Phase8Screens.kt` 등을 동시 편집했다.**
- 증거: `artifacts/qa/android-e2e-2026-09-09/` (스크린샷 9장 + 소프트락 세이브 덤프)
- 판정: **출시 보류** — 차단 1 / 높음 5 / 중간 10 / 낮음 10, 크래시·ANR 0

## 페르소나

| ID | 인물 | 관심사 | 도달 지점 |
| --- | --- | --- | --- |
| P1 | 박하은(28) 라이트팬 | 큰 버튼만 누르고 설명은 훑음 | 오프닝 → 선수 만들기 → 첫 불펜 → 학교 → 훈련 → 중간계투 등판 완료 → 각성 |
| P2 | 정민호(34) 시뮬 베테랑 | 수치·용어 일관성 | 훈련 6종·각성 트리·기록 탭 6칩·3개 로케일 |
| P3 | 이수빈(24) 스토리 캐주얼 | 대사·관계·반복 피로 | 감독 대화·관계 화면·자동 진행 |
| P4 | 한경자(58) 접근성·대화면 | 글자 크기·터치 타깃·태블릿 | 배율 130/150%, 800dp 태블릿 |
| P5 | 서동혁(31) 이어하기·기기 이전 | 프로세스 종료·백업·복원 | 강제 종료 4회, 백업 왕복, 세이브 파일 검증 |

## 출시 차단

### B-01 고교 중요 경기에서 투구 결과 화면을 벗어나면 커리어 영구 소프트락

재현 100%:
1. 내 투수 → `한 경기 더`(또는 예정된 중요 경기) → `등판하기`
2. 공 1개를 던져 결과 화면이 뜨게 한다
3. 우상단 `나중에 이어하기` → `나가기`

결과: "중요 경기" 브리핑에 **`등판하기` 버튼이 사라진다.** 남는 클릭 요소는 `outing.details`와 하단 기록·설정 탭뿐. 앱 재시작·탭 전환 모두 무효. 강제 종료·시스템 글자 크기 변경으로도 동일하게 재현(4/4).

원인: 저장된 투구 세션의 `boundary`가 `terminal`일 때 `Phase8ScreenModels.kt:610-618`의 네 액션이 모두 비활성이다.
- `openImportantGame` — `activePitch != null`이라 false
- `nextImportantPitch` — `COMPLETED`·`ABANDONED`만 허용
- `resumePitch` — `PLAYING`·`SUSPENDED`만 허용
- `abandonPitch` — `RESERVED`·`PLAYING`·`SUSPENDED`만 허용

`COMMITTED`·`CONSUMED`도 같은 사각지대다. 같은 가드가 **프로(`Phase8ScreenModels.kt:905-911` `canFinishGame`)와 튜토리얼(`536-541` `hasPendingResult`)에는 이미 있고 고교 화면에만 빠져 있다.**

노출 창: 결과 화면은 매 투구마다 뜬다(경기 중 시간의 절반 가까이). 그 화면의 문구는 "이 타석은 그대로 남는다. 언제든 이어서 던질 수 있다"고 약속한다.

회복: 백업 파일이 있으면 복원으로 회복된다(검증 완료). 없으면 "모든 진행 삭제"뿐.

## 높음

- **H-01** 세이브가 `/sdcard/Android/data/<pkg>/files/save/save.json`에 있고 매니페스트가 `allowBackup="false"`. 자동 백업/Play Games 저장 게임 없음 → 기기 변경 시 자동 복원 경로 없음.
- **H-02** `Method exceeds compiler instruction limit: 20048 in Phase8ScreenProjection.project(...)` 46회+. 화면 전환 핫패스가 ART 최적화를 못 받는다. `Compiler allocated 12MB to compile Phase8SetupFields(...)`도 동반.
- **H-03** 베이스라인 프로파일 없음(`baselineprofile` 모듈·`baseline-prof.txt` 없음, `base.dm` 미포함 경고).
- **H-04** 릴리스 게이트 2건 실패 — `check-android-compose.mjs:140` 정규식이 새 `.audit.compose.qa` 접미사를 모름("debug fixture application ID suffix is not isolated"); `inventory-android-localization.py --check` 미번역 379/3182건.
- **H-05** 투구 화면 중앙 약 600px(화면 25%) 공백 + 조준 단계 3×3 격자가 빈 사각형뿐. 태블릿에서는 공백이 화면 절반.

## 중간

- **M-01** "연습 1/3"인데 1구 후 주 CTA가 `학교 선택하기`, 보조가 `한 구 더` → 튜토리얼 2/3 건너뜀.
- **M-02** 관계 화면에 "지난 최고의 등판을 떠올려봐. 그 공은 네가 던졌어."가 두 번 렌더.
- **M-03** 수싸움 선택 시 미리보기가 "제구 +2"만 표시. `GAME_PLANNING → command` 매핑 설명이 "훈련 효과 자세히" 안에만 있음.
- **M-04** 같은 축을 화면마다 수싸움 / 운영 / 경기 운영 / 경기 계획 / 타자 상대법과 제구로 다르게 부름. 투수 유형도 "힘으로 승부하는 투수" vs 도전 화면 "강속구형".
- **M-05** "남은 훈련"이 1 → 3 → 1 → 2로 요동. 같은 시점에 "훈련 3회"와 "남은 훈련 1회" 동시 표시. 훈련 계획 시트는 "최대 1회"라면서 "같은 훈련 3회" 제공.
- **M-06** 성장 예상 포맷 두 가지(`구위 +2` vs `구위 최소 +0, 최대 +2`). 상한 근처에서 "대성공 확률 37% · 성공 시 총 구위 +1"처럼 대성공 이득이 0으로 보임.
- **M-07** 일본어: 수싸움 → `マインド試合`(오역), 가볍게 → `ライト`(標準/強め와 톤 불일치), トレーニング/練習 혼용. 영어: `1 sessions left` 복수형 오류.
- **M-08** 오디오 포커스 요청 62회 / 반환 21회, 매번 `USAGE_GAME/CONTENT_TYPE_MUSIC` 영구 포커스 → 사용자 배경 음악을 반복 중단.
- **M-09** `largeScreens=false`·`resizeableActivity=false`·`screenOrientation=portrait`이지만 targetSdk 36은 600dp 이상에서 이를 무시한다. 800dp 확인 결과 최대 너비 제한이 없어 화면 절반이 공백.
- **M-10** 디스플레이 크기 변경 후 상단 상태 표시줄 자리에 하단 탭바 잔상(접근성 트리에는 없음). 실기기 확인 필요.

## 낮음

L-01 각성 트리 범례(✓/○)와 실제 자물쇠 아이콘 불일치 · L-02 "같은 훈련 3회"가 버튼인데 버튼 크롬 없음 · L-03 선수 만들기 최종 CTA만 좁은 폭 · L-04 첫 타자만 이름 있음 · L-05 삼진인데 경고색 지적 문구 · L-06 한 화면에 "자세히" 두 개 · L-07 "현재 예상 구속 ▾"에 값 없음 · L-08 루트 뒤로가기 즉시 종료 · L-09 설정 루트에 불필요한 '‹' · L-10 결과 화면의 배트·공 궤적선 구분 불가

## 통과

- 크래시·ANR 0건(약 40분, logcat 79,590줄)
- 콜드 스타트 1.26초(`am start -W`, 에뮬레이터)
- 일반 상태 저장·복원 완전(훈련 화면 강제 종료 후 동일 복원)
- 백업 저장/불러오기 왕복 정상(57.9KB), 소프트락 상태에서도 회복
- 투구 슬라이더가 기본, "한 번 눌러 던지기" 기본 OFF (조작 불변 규칙 충족)
- 터치 타깃 전부 ≥48dp, 글자 배율 130/150%에서 잘림 0
- ko/en/ja 3개 로케일 전환 정상
- 딥링크 `yagurebirth://challenge/12345-1` 정상
- PSS 161MB
- `PLAYING` 상태 중단은 "투구 이어 하기"·"이번 투구 포기"로 복구됨

## 권장 처리 순서

1. B-01 수정 — P008에 프로 화면과 같은 `hasPendingResult` 분기 추가. 세 화면이 같은 헬퍼를 쓰게 정리.
2. B-01 회귀 테스트 — 모든 `PitchBoundary` 값에서 각 화면 투영이 활성 액션 ≥1개를 내는지 검사.
3. H-04 게이트 복구.
4. H-01 백업 정책 결정(출시 후 변경 어려움).
5. M-01~M-06 문구·매핑 묶음 수정 + import/inventory 재실행.
6. H-05 투구 화면 여백.
7. H-02·H-03 성능(실기기 기준선 먼저).
8. M-07 일본어 감수.
9. M-09 실기기 대화면 확인.
10. L 항목 일괄 마감.

## 재검증 도구

uiautomator 드라이버가 `PitchReleaseMeter.sweepSeconds` 공식으로 릴리스 타이밍을 계산해 자동으로 퍼펙트 투구를 낸다. B-01 수정 후 위 3단계 재현으로 5분 내 검증 가능. 맥에 갤럭시 A53 실기기(`R5CT40GZSWZ`)가 연결되어 있어 성능·대화면 항목은 실기기로 다시 재는 편이 정확하다.

## QA 중 환경 변경(모두 원복)

`pm disable-user com.solkim.batterforge.uxpreview` → 재활성화 완료 / `font_scale` 1.3·1.5 → 1.0 / `wm size`·`wm density` 오버라이드 → reset / 앱 로케일 en·ja → 초기화 / `user_rotation` → 자동 회전 복구. `docs/localization/android-copy-inventory.json`은 `inventory-android-localization.py`를 `--check` 없이 실행하며 재생성되었다.
