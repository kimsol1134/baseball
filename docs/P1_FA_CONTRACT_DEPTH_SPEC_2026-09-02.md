# P1-3 FA 다년 계약·계약금·잔류 협상·연봉 사용처 스펙

작성: PM, 2026-09-02. 구현: grok (main 트리). 리뷰 근거: "FA는 보통 4년 이상인데 1년씩 계약이고 팀만 바뀜, 계약금·연봉도 없음, 그 돈으로 장비·특별 훈련·트레이너 선택이 필요"(2★), "FA면 랜덤으로 다른 팀 가는 게 아니라 접촉 구단을 보고 남을지 고르고 싶다"(5★), "한 팀 프차 미션"(2★).

## 0. 절대 규칙
1. 커밋·푸시·stash·reset·checkout 금지. main 워킹트리(HEAD는 "reserve rules version 10 gates" 커밋)에서 작업.
2. **모든 새 동작은 `ProCareerEngine.usesContractDepthRules(state)`(proRulesVersion ≥ 10) 뒤에 둔다.** v9 이하 저장은 시장 생성·검증·수락 전부 바이트 동일. `validateStoredJourneyMarket`이 시장을 재생성해 동등 비교하므로, 재생성 함수에 규칙 버전을 전달해 기존 저장의 pending market이 무효가 되지 않게 한다.
3. **와이어 포맷·오라클 보호**: `swift-pro-career-contract-wave3-oracle-v1.json`(sha256 2개 하드코딩)과 `ProCareerFixtureExporter`의 `wave3OfferCanonical`은 v9 이하 경로에서 **바이트 동일**해야 한다. 익스포터는 레거시 경로를 명시 고정한다. Kotlin 테스트·픽스처 수정 금지.
4. 골든 픽스처(`swift-pro-career-oracle-v1/v2.json`, 고교 v3, 투구 골든) 재생성 금지. 프로 주간 루프 RNG 무삽입. 시장 생성은 지금처럼 해시(`StableHash`)만 사용.
5. 저니 상태 신규 필드는 Optional + 기본값, `canonicalToken`은 **v10 필드가 nil이면 기존과 동일 문자열**을 내야 한다.
6. ko/en/ja 필수. `npm run check:ios-localization`·`check:copy`·`check:design-system` 통과. 실존 구단명 금지. 뷰는 스토어 프로젝션만(LayerBoundaryTests). 투구 슬라이더 접근 금지.
7. **다른 엔지니어가 별도 워크트리에서 국가대표 대회를 만들고 있다.** 이 작업은 `ProPostseason.swift`, `PitchScenario.swift`, `ProImportantGameIntro.swift`, `MobileCareerStore+ImportantGame.swift`, `CareerFlowView.swift`의 importantGame 분기, `militaryCompleted` 관련 코드를 건드리지 않는다. `ProCareerPhase`에 케이스를 추가하지 않는다.
8. iOS 테스트는 한 번에 하나, 부팅된 iPhone 17 재사용. 테스트 삭제·약화 금지.

## 1. 기존 구조 (조사 결과 요약)
- `ProContractMarketRules`(1056줄, 무상태·해시 기반): `renewalMarket` 2오퍼(현팀 renewal_long 3~4년 / prove_it 1년), `freeAgencyMarket` 정확히 3오퍼(잔류 stay 3~4년 / 도전 challenge 2~3년 / 기회 opportunity 1~2년). `isValid`(:631~)가 `(1...4).contains(years)`·`signingBonus == nil`을 강제. `acceptContract`(ProCareer.swift:136~)에 같은 가드(:174-176). 계약금은 신인 시장에만 존재.
- 재정: `ProFinanceState`(careerEarnings, availableFunds, transactions), `ProFinanceRules.investmentCost`(pitchLab 5천만 / recoveryTeam 4천만 / fanFoundation 2천만). `ProOffseasonInvestment` 4케이스, 오프시즌당 1회, 계약 협상 오프시즌에는 투자 단계가 없음(`.underContract` 경로만 `.offseasonInvestment`로 감).
- iOS: `ProContractOfferView`(오퍼 카드, `pro.contractOffer.*` ID), `ProOffseasonInvestmentView`(`Self.options` 배열), `MobileCareerStore+Season.swift` `acceptContract(marketID:offerID:ambition:)`, `chooseInvestment(investment:focus:)`.

## 2. 기능 (v10에서만)

### 2.1 FA 시장 확장
- **오퍼 4개**: 잔류 / 도전 / 기회 + **장기 안정**(`long_term`: 4~5년, 연봉 배수 ×0.85~0.95, contender 아닌 안정 구단, `preservesTeamLegacy = false`, 기대치 accessible). 잔류 오퍼는 마지막 팀 레거시 점수 ≥ 65이면 5년까지 허용.
- **연수 상한 5년**(v10): `isValid`·`acceptContract` 가드·`cappedYears`·`nonDominated` 축을 규칙 버전 인자로 분기.
- **계약금**: FA 오퍼마다 `signingBonus = annualSalary × (60~140)% `(해시, 1천만 단위 반올림). 도전 오퍼는 낮게, 장기 안정은 높게. 수락 시 `signing_bonus` 트랜잭션으로 즉시 입금(신인 경로와 같은 멱등 ID 규약). `totalGuaranteedSalary`는 계약금 포함.
- **접촉 구단 표시**: 각 오퍼에 `interest: ProClubInterest`(enum: hot/warm/cool, 해시 + demand 랭킹·팀 outlook에서 결정) 를 붙여 카드에 "관심 높음/보통/낮음" 배지와 한 줄 사유(`content.contract.interest.<level>.<reason>` 키)를 보여준다. 리뷰가 원한 "어느 팀이 접촉했는지"의 최소 구현.
- **잔류 협상 1회**: 잔류 오퍼에 한해 "요구하기" 버튼: 선택지 2개 — 연수 +1(최대 5) 또는 연봉 +10%. 수락 판정은 결정적: `fanSupport ≥ 55 && marketScore ≥ 60`이면 수락, `marketScore ≥ 70`이면 무조건 수락, 그 외 거절(오퍼 그대로 유지, 팬 지지 −1). 협상 결과는 `pendingContractMarket`에 `counterOffer: ProContractCounterState?`(요청 종류·결과·적용 여부)로 기록해 재생성 검증과 저장 복구가 일치하게 한다. 협상은 시장당 1회.

### 2.2 재계약 시장
- `renewal_long` 최대 5년(마지막 팀 레거시 ≥ 65일 때). 계약금은 재계약에는 없음(현실 관례).

### 2.3 연봉 사용처
- `ProOffseasonInvestment`에 2케이스 추가: `equipment`(장비 업그레이드, 3천만: 다음 시즌 부상 압력 −6, `ProSeasonBenefit(kind: .injuryMitigation …)`과 별개로 `ProSeasonBenefit.kind` 에 `.equipmentEdge` 추가), `personalTrainer`(개인 트레이너, 4천만: 다음 시즌 훈련 성장 효율 +100‰ — 주간 결정 modifier의 `trainingEfficiencyPermille` 경로 재사용, 시즌 롤오버에 만료).
- **협상 오프시즌에도 투자 가능**(1.2.7 미룬 항목): 계약 수락 후 `.offseasonInvestment` 페이즈로 진입한다(v10). 기존 `.underContract` 경로와 동일한 검증(`.offseasonInvestment` 케이스, ProCareer+Journey.swift:1623 부근)을 통과해야 한다.
- 오프시즌당 투자 1회 규칙 유지. 잔액 부족 시 비활성 + 사유 문구.

### 2.4 iOS
- `ProContractOfferView`: 4번째 카드, 계약금 줄, 관심 배지, 잔류 카드의 "요구하기" 시트(선택지 2 + 결과 문구), 접근성 ID `pro.contractOffer.counter.<kind>`, `pro.contractOffer.interest.<level>`.
- `ProOffseasonInvestmentView.options`에 장비·트레이너 추가, 아이콘·비용·효과 한 줄. 협상 후 투자 화면 진입 경로 배선(`CareerFlowView`의 `.offseasonInvestment` 분기는 이미 존재).
- 스토어: `requestContractCounter(kind:) -> Bool`, 텔레메트리 `pro_contract_counter_requested`(kind, accepted), 기존 `proContractSigned`에 `years`, `signing_bonus_band`, `interest` 속성 추가.
- 용어 사전에 "계약금", "구단 관심" 2항목 추가(ko/en/ja).

## 3. 수용 기준
1. v10 새 커리어 FA 시장 오퍼 4개, 잔류 5년 조건, 계약금 범위·1천만 단위, 수락 시 입금 트랜잭션 멱등(테스트).
2. 잔류 협상 결정성: 같은 상태 두 번 → 같은 결과. 협상 후 저장·복구 시 `validateStoredJourneyMarket` 통과.
3. v9 저장: 시장 3오퍼·연수 ≤ 4·계약금 nil 유지, `ProContractMarketWave3` 관련 Swift 테스트와 익스포터 출력 바이트 동일(익스포터를 돌려 `swift-pro-career-contract-wave3-oracle-v1.json`과 `cmp` — 차이가 나면 안 된다).
4. 협상 오프시즌 → 투자 페이즈 → 다음 시즌 스프링캠프까지 통합 테스트.
5. 장비·트레이너 효과가 다음 시즌 1회만 적용되고 롤오버에 만료(테스트).
6. 게이트: `swift test` simulation-core 전체, ios-layers, `npm run check`, `npm run run:pro-career:distribution:smoke`, iOS `BaseballIOSTests` 전체. 모두 종료 코드 0.

## 4. 산출물
`docs/P1_FA_CONTRACT_DEPTH_REPORT_2026-09-02.md`: 변경 파일, 오퍼 표(연수·배수·계약금 범위·관심 규칙), 협상 판정 표, 게이트 원문, 익스포터 cmp 결과, 미해결.
