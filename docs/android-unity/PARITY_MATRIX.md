# Android Unity 패리티 매트릭스

기준일: 2026-08-11

상태는 증거 층을 뜻한다.

- `NS`: 미착수
- `SOURCE`: 구현 소스, 결정론 fixture, 비-Unity 정적 테스트가 통과한 상태
- `DEFERRED`: 현행 iOS에서도 제품에서 제거되어 Android v1 노출 대상이 아닌 상태
- `UNITY`: 같은 commit을 Unity 6000.3.19f1 EditMode/PlayMode에서 실행한 상태
- `DEVICE`: 서명 Release IL2CPP 빌드를 지원 스마트폰에서 확인한 상태
- `ACCEPTED`: `DEVICE` 증거와 승인자 기록까지 갖춘 상태

이 머신의 Unity 6000.3.19f1 EditMode/PlayMode와 내부 검증 AAB/16KB emulator lane은 통과했다.
다만 현재 변경분은 clean commit으로 고정되지 않았고 production upload key 서명 AAB와 물리
스마트폰도 없다. 따라서 행 상태는 아직 `SOURCE`로 유지하며, clean commit의 test XML을 묶은 뒤
`UNITY`, production 기기 증거 뒤 `DEVICE`, 승인자 기록 뒤 `ACCEPTED`로 올린다.

| ID | 흐름 | iOS 기준 | 상태 | Android 소스/정적 증거 | Unity·기기 증거 |
|---|---|---|---|---|---|
| P-001 | 최초 실행/오프닝 | OpeningView/CareerBootstrap | SOURCE | `Bootstrap/AppRoot.cs`, `Presentation/Shell/*`; `RuntimeGameCoordinatorTests`, `AppRootPlayModeTests` | 대기 |
| P-002 | 선수 생성 | HighSchoolSetupView | SOURCE | 프리셋 이미지·4능력/구종 preview, 지역·난이도·계승·seed validation; `HighSchoolSetupContractTests`, `StoreRuntimeProjectionTests` | 대기 |
| P-003 | 프롤로그 | HighSchoolCareerView | SOURCE | `Core/HighSchool/*`, 저장형 튜토리얼 command; `HighSchoolApplicationFlowTests` | 대기 |
| P-004 | 튜토리얼 투구 | PitchView/DeliveryControl | SOURCE | `Core/Pitching/*`, `Presentation/Pitch/*`; exact 2타자·8구 및 재시작 tests | 대기 |
| P-005 | 학교 선택 | HighSchoolCareerView | SOURCE | 19지역·4후보 catalog, 실제 choice payload와 학교별 coach/catcher 2초상; setup/screen tests | 대기 |
| P-006 | 훈련 | HighSchoolCareerStore/View | SOURCE | 변화구 target, 1회/최대 3회 묶음, 6 focus×3 intensity 권위 전망, Swift-v4 exact 판정, 만개·대성공·성장 카드와 reduced-motion 경계; Core/Application/Presentation tests | 대기 |
| P-007 | 관계 이벤트 | HighSchoolCareerStore/View | SOURCE | 관계 catalog/voice/category projection, role portrait/SceneArt; `HighSchoolApplicationFlowTests`, screen projection tests | 대기 |
| P-008 | 중요 경기 | PitchSession/PitchScenario | SOURCE | 저장된 lineup/scenario/checkpoint, commit-before-3D, 동일 타자 suspend, 상황·사인·scouting HUD, 소비 성공 기준 전체 공 로그와 postgame 정산; pitch persistence/presentation tests | 대기 |
| P-009 | 각성 | AwakeningTree/ClimaxViews | SOURCE | `Core/HighSchool` awakening/goal/wind rules와 실제 choice UI; HS tests | 대기 |
| P-010 | 챕터 결산 | ChapterGoal/HighSchoolCareerView | SOURCE | chapter goal/advance reducer와 projection; HS application tests | 대기 |
| P-011 | 고교 8챕터 | HighSchoolCareer | SOURCE | Opening→tutorial→8 chapters→draft vertical; `ProductionCareerVerticalTests` | 대기 |
| P-012 | 대회/랭킹/리그 | TournamentBracket/ProspectRanking/LeagueTable | SOURCE | 순수 정렬·대회·랭킹 Core, chapter 2/4/6/8 배너와 실제 shell rows; Core/Presentation tests | 대기 |
| P-013 | 드래프트 | forecast/resolveDraft | SOURCE | forecast/resolve state transition과 지명·미지명 분기; HS vertical tests | 대기 |
| P-014 | 회차 결산/유산 | RunRecap/LifeArchive/CareerSignatureLegacy | SOURCE | 대표 유산·기억·RunPledge 원자 정산, 현재 회차 동결 recap, 성장·도장·야구혼·다음 목표와 quick/custom 환생; Core/Application/Presentation tests | 대기 |
| P-015 | 환생 | HighSchoolCareerStore | SOURCE | quick/custom rebirth, last setup, 중복 방지 receipt; vertical/meta tests | 대기 |
| P-016 | 프로 계약 | CareerFlowView/ProCareer | SOURCE | unsigned offer→실제 계약 payload; `CoreProCareerPortTests`, `ProApplicationFlowTests` | 대기 |
| P-017 | 프로 주간 계획 | CareerFlowView/ProCareer | SOURCE | 구위/변화구 성장 분리, 변화구 결정구 picker, 1주/구간 진행과 segment·역할·level·부상·phase 중단 규칙, 실제 payload; Pro Core/Application/Presentation tests | 대기 |
| P-018 | 프로 중요 경기 | PitchSession/ProCareer | SOURCE | 권위 PitchKernel 결과→Pro 4타자 반영, 재개/중복 방지; Pro/pitch tests | 대기 |
| P-019 | 시즌 결산 | ProCareer.reviewSeason | SOURCE | 개인 raw/고급 기록, 팀 전체 순위, 4능력·성장 일정, 결정 history/delta, 수상·이정표, phase별 다음 선택과 실제 payload; Pro/Presentation tests | 대기 |
| P-020 | 비시즌 | ProCareer.chooseOffseason | SOURCE | offseason/retirement choice state machine과 UI; Pro tests | 대기 |
| P-021 | 프로 최대 커리어 | ProCareer | SOURCE | 최대 12시즌/나이 종료 fixture; `ProductionCareerVerticalTests` | 대기 |
| P-022 | 프로 유산→다음 인생 | MobileCareerStore/HighSchoolCareerStore | SOURCE | Pro 기록 원자 archive→retire→rebirth vertical; Application tests | 대기 |
| P-023 | 오늘의 이닝 | `DAILY_INNING_RETIREMENT_PLAN_2026-08-11.md` | DEFERRED | 제품 진입·투구 command·알림·주간 신규 과제·보상 분석 caller 0개. 레거시 route는 현재 커리어/기록으로 복귀하고 옛 enum·저장 필드는 읽기 호환만 유지 | 재도입 설계 승인 전 비범위 |
| P-024 | 주간 야구 노트 | WeeklyProgram | SOURCE | 기록 탭 진입 카드, weekly observe/tasks/stamps/claim idempotency와 실제 rows; meta/shell tests | 대기 |
| P-025 | 기록/리그 | RecordView/LeagueView | SOURCE | HS/Pro raw·고급 기록, standings/leaderboard, 수상·결정·이정표, archive-only/weekly-only와 회차별 가상화 상세; screen tests | 대기 |
| P-026 | 로컬 업적 | Achievements | SOURCE | 15개 한국어 업적, 개별 ack와 저장; meta/screen tests | 대기 |
| P-027 | 설정 | SettingsView | SOURCE | aggregate settings/rollback, audio focus, 알림, 접근성, 다음 선수·계승·프로 진행, seed 공유, reset; tests | 대기 |
| P-028 | 공유 | LifeCardView/ShareSheet | SOURCE | 선택한 동결 회차의 전체 LifeCard를 타일 capture하고 기기 texture 한계에서는 전체 내용을 균일 축소한 PNG+한국어 text로 공유, 할당 실패 text fallback, non-exported FileProvider, chooser-tapped-only EX-009; platform/presentation tests | 대기 |
| P-029 | 복귀 카드/세션 | AppShell/GameAnalytics | SOURCE | guided/holdout, 서울 날짜, durable receipt, main-thread pause projection; lifecycle/presentation tests | 대기 |
| P-030 | 리뷰 요청 | ReviewPrompt | SOURCE | 3회차·좋은 결산·지명 결과 확인 reason별 lifetime receipt, 요청 간 24시간, Google Play Review fail-open; platform/presentation tests | 대기 |

`UNITY` 이상으로 올릴 때는 같은 행 마지막 열에 commit, test XML 또는 기기/OS, build SHA,
capture/log 경로와 승인자·날짜를 함께 기록한다. 허용 차이는 `PARITY_EXCEPTIONS.md`만 권위로
삼고, 그 밖의 차이는 상태를 올리기 전에 수정한다.
