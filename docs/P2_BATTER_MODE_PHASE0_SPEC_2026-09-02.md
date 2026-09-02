# P2-3 타자 모드 Phase 0 스펙 — 설계 + 코어 프로토타입

작성: PM, 2026-09-02. 구현: grok (워크트리 `/Users/solkim/Dev/baseball-wt-batter`, 브랜치 `p2/batter-phase0`). 리뷰 근거: "타자 버전도 있으면"(5★), 8/23 답변에서 "타자 버전 개발 중"이라고 이미 약속함. 타자 모드는 새 게임 모드 수준이라 **이 Phase 0은 설계 확정과 코어 타격 커널 프로토타입까지**만 한다. UI·커리어 루프는 Phase 1 이후.

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. 이 워크트리에서만. main 트리 접근 금지. xcodebuild·npm 금지.
2. **기존 투수 커널·커리어·픽스처 무변경.** 새 코드는 전부 신규 파일(`packages/simulation-core/Sources/SimulationCore/Batting/…`)에 두고 기존 타입을 수정하지 않는다. 기존 타입 재사용은 import·호출만.
3. 결정론: 타격 커널도 per-swing `SplitMix64(derivedSeed)` 방식, 정수 산술. 골든 픽스처 `simulate_batting_golden.json`을 새로 만들어 테스트로 고정.
4. AGENTS.md: 실존 명칭 금지. **투구 슬라이더가 투수 모드의 핵심이듯, 타자 모드의 핵심 조작은 "타이밍 슬라이더"(같은 손맛 계열)여야 한다.** 원탭 자동 스윙은 보조 경로.
5. 테스트 삭제·약화 금지. 작업 끝에 워크트리 `.build` 삭제.

## 1. 설계 문서 (`docs/BATTER_MODE_DESIGN_2026-09-02.md`, 워크트리 안)
반드시 답할 것:
1. **모드 관계**: 별도 커리어 트랙(고교 타자 → 프로 타자)인지, 같은 계보에서 환생 시 선택인지. 권장: 같은 계보·같은 야구혼 경제, 시작 화면에서 "투수/타자" 선택, 계승 캡·재능 벽 규칙 공유. 저장 스키마는 별도 레코드(`BatterCareerSaveRecord`)로 투수 저장과 분리(저장 교착 재발 방지).
2. **핵심 조작**: 타이밍 슬라이더 — 투수 릴리스 후 공이 홈플레이트에 오는 동안 슬라이더를 밀어 접점 타이밍·높낮이를 맞춘다. 판정 축: 타이밍(빠름/정확/늦음, ms 단위 정수), 존 선택(9존 중 노림 존과 실제 코스의 거리), 스윙 여부(볼 참기). 결과: 헛스윙/파울/약한 타구/강한 타구(방향·비거리)/삼진/볼넷. 접근성: 원탭 자동 스윙 옵션.
3. **능력치 축 5개**(투수 구위·제구·변화구·체력에 대응): 컨택, 파워, 선구안, 주루, 수비. 성장·훈련·연구소(타격 연구소)의 대응 관계 표.
4. **한 타석의 재미 루프**: 투수 상대 스카우팅(구종 경향·결정구), 카운트별 노림, 리스크(2스트라이크 컷). 상대 투수 AI는 기존 `CatcherRecommendationEngine`을 뒤집어 사용할 수 있는지 검토(투수 AI가 포수 사인을 따르는 구조).
5. **시즌 루프 재사용**: 주간 계획·시즌 결정·계약·목표판·국가대표를 타자 스탯으로 일반화하는 데 필요한 추상화 목록과 예상 변경 범위(파일·LOC).
6. **Phase 계획**: Phase 1 코어 커리어(고교 타자 3년) → Phase 2 프로 타자 → Phase 3 iOS UI → Phase 4 Android. 각 단계 예상 규모와 게이트.
7. **밸런스 목표**: 타율·OPS·삼진율 밴드(기존 `check-balance.mjs` 밴드에 대응하는 타자 밴드 초안), 50/50/50 타자 기준.

## 2. 코어 프로토타입 (신규 파일만)
- `Batting/BattingDomain.swift`: `BatterAbilitySnapshot(contact, power, discipline, speed, defense)`, `SwingInput(timingOffsetMs: Int, targetZone: PitchZone, swung: Bool)`, `BattingOutcome`(enum), `BattedBall(direction, exitSpeedTenths, launchAngleTenths)`.
- `Batting/BattingKernelEngine.swift`: `resolveSwing(pitch: <기존 투구 결과 타입 재사용>, batter:, input:, seed:) -> BattingResolution`. 타이밍 창: 정확 ±40ms, 파울 ±90ms, 그 밖 헛스윙; 존 거리별 컨택 확률 감쇠; 파워→타구 속도; 선구안→볼 참기 시 스트라이크 오판율. 모두 정수 산술.
- `Batting/BattingAutoSimulator.swift`: 자동 타석(원탭/자동 진행용) — 능력치에서 타이밍 오차를 시드로 추출.
- 테스트: 결정론(같은 입력 두 번 동일), 골든 픽스처 생성·고정, 분포 테스트(50/50/50 타자 vs 기존 투수 50/50/50이 던지는 500타석: 타율 .240~.290, 삼진율 18~28%, 홈런/타석 1.5~4%), 파워 40 vs 60 단조성, 컨택 축 단조성.
- 밸런스 수치 초안이 밴드를 벗어나면 커널 상수를 조정하고 보고서에 기록.

## 3. 수용 기준
1. 설계 문서 7항목 전부 답변, Phase 계획에 규모 추정 포함.
2. 신규 파일만으로 `swift test --package-path packages/simulation-core` 전체 통과(기존 테스트 무변경·전부 통과 + 신규 타격 테스트).
3. 골든 픽스처 파일과 그것을 읽는 테스트 존재.
4. 기존 파일 diff가 0이어야 한다(`git status`로 확인해 보고서에 적기; Package.swift에 타깃 추가가 필요하면 그 한 줄만 허용).

## 4. 산출물
`docs/P2_BATTER_MODE_PHASE0_REPORT_2026-09-02.md`: 설계 문서 위치, 커널 상수 표, 분포 테스트 수치, 게이트 원문, Phase 1 착수 조건.
