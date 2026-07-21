# 데이터 모델·명령·이벤트 프로토콜

| 항목 | 값 |
|---|---|
| 문서 ID | DOC-09 |
| 버전 | 1.0 Baseline |
| 원칙 | 안정 ID, 불변 이벤트, 결정론, 플랫폼 중립 저장 |

## 1. 도메인 경계

| Context | 책임 |
|---|---|
| World | 연도, 리그, 구단, 역사, 콘텐츠 잠금 |
| Person | 선수·감독·포수·스카우트의 정체성과 관계 |
| Player | 현재 스탯, 잠재 모델, 구종, 상태 |
| Development | 훈련, 성장 신호, 피로, 부상, 노쇠화 |
| Game | 일정, 로스터, 경기 상태, 투구·타석 결과 |
| Career | 학교, 드래프트, 계약, 역할, FA, 은퇴 |
| Meta | 야구혼, 기억, 각성, 업보, 해금 |
| Content | 사건, 조건, 선택, 문장, 밸런스 테이블 |
| Commerce | 프로 권한의 추상 상태만 보유 |

## 2. ID 규칙

- 모든 영속 엔터티는 UUID 또는 결정론적 128비트 ID를 가진다.
- 콘텐츠 ID는 사람이 읽을 수 있는 namespace 문자열을 사용한다.
- 예: `event.hs.coach.power_or_command.001`.
- 저장된 이벤트와 카드 ID는 삭제·재사용하지 않는다.
- 표시 이름은 ID와 분리한다.

## 3. 주요 엔터티

### WorldState

```swift
struct WorldState: Codable, Sendable {
    var id: WorldID
    var currentDate: GameDate
    var rulesetID: ContentID
    var teams: [TeamID: Team]
    var people: [PersonID: PersonSummary]
    var history: LeagueHistory
    var activeCareerID: CareerID?
    var revision: UInt64
}
```

### PlayerState

```swift
struct PlayerState: Codable, Sendable {
    var personID: PersonID
    var role: PlayerRole
    var handedness: Handedness
    var physical: PhysicalRatings
    var mechanics: PitchingMechanics
    var pitches: [PitchType: PitchProfile]
    var mental: MentalRatings
    var dynamic: DynamicPlayerState
    var potentialBeliefs: PotentialBeliefSet
    var latentModelRef: LatentModelID
}
```

`latentModelRef`가 가리키는 실제 학습률·성장 곡선은 사용자 스냅숏에 포함하지 않거나 암호화하려는 보안 대상이 아니다. 다만 UI DTO로 직접 전달하지 않는다.

### PitchProfile

- 실측: 평균·최고 구속, 회전, 움직임, 릴리스.
- 기술: 제구, 커맨드, 위장, 터널링, 유인구, 실전 숙련.
- 동적: 당일 감각, 피로 유지.
- 역할: primary, secondary, support, development.

### Relationship

```text
personA, personB
closeness
trust
competitiveTension
sharedHistoryTags
recentEvents
```

### CareerState

- 단계: middleSchool, highSchool, drafted, minor, major, freeAgent, retired.
- 챕터 또는 시즌.
- 소속·역할·감독 약속.
- 드래프트 관심.
- 프로 권한 잠금 상태.
- 주요 이정표.

### MetaState

- 야구혼 레벨·포인트.
- 해금 노드.
- 보유 기억 카드.
- 현재 장착 0~3장.
- 업보 해금.
- 완료 삶 요약.

## 4. 명령 카탈로그

### 세계·생성

- `CreateWorld`
- `ContinueInheritedWorld`
- `AllocateSoulPoints`
- `EquipMemoryCards`
- `SelectKarmaModifiers`
- `CreatePlayer`
- `ConfirmPlayerCreation`

### 진행·훈련

- `CommitTrainingPlan`
- `SelectFocusedTraining`
- `AdvanceToNextImportantEvent`
- `ChooseNarrativeOption`
- `SelectAwakening`

### 경기

- `CommitPregamePlan`
- `AcceptCatcherRecommendation`
- `SubmitPitchCall`
- `DelegatePlateAppearance`
- `RespondToManagerMoundVisit`
- `AcknowledgePostGameAnalysis`

### 커리어

- `SelectHighSchool`
- `RequestManagerMeeting`
- `DeclareDraftPreference`
- `AdvanceDraft`
- `SignProfessionalContract`
- `RequestRoleChange`
- `RequestTrade`
- `AcceptContractOffer`
- `DeclareRetirement`
- `AttemptComeback`

### 시스템

- `CreateSaveCheckpoint`
- `RestoreBackup`
- `ActivateContentPack`
- `SetDifficultyAxes`

## 5. 이벤트 카탈로그

### 생성·메타

- `WorldCreated`
- `SoulPointsAllocated`
- `MemoryCardsEquipped`
- `KarmaModifiersSelected`
- `PlayerCreated`
- `LifeCompleted`
- `SoulExperienceGranted`
- `MemoryCardUnlocked`

### 성장

- `TrainingPlanCommitted`
- `TrainingSessionResolved`
- `ReadinessChanged`
- `SkillRatingChanged`
- `PotentialBeliefUpdated`
- `FocusedTrainingReactionObserved`
- `AwakeningGranted`
- `FatigueChanged`
- `RecoveryDebtChanged`

### 경기

- `GameStarted`
- `ImportantMomentEntered`
- `BatterPlanCommitted`
- `CatcherRecommendationsGenerated`
- `PitchCallCommitted`
- `PitchExecuted`
- `PitchResolved`
- `BattedBallCreated`
- `RunnerAdvanced`
- `PlateAppearanceEnded`
- `InningEnded`
- `GameEnded`
- `PostGameAnalysisGenerated`

### 관계·커리어

- `RelationshipChanged`
- `ManagerPromiseCreated`
- `ManagerPromiseResolved`
- `ScoutInterestChanged`
- `DraftPickAnnounced`
- `PlayerWentUndrafted`
- `ProfessionalContractOffered`
- `ProfessionalContractSigned`
- `RoleChanged`
- `PlayerTraded`
- `PlayerReleased`
- `PlayerRetired`
- `ComebackAttemptResolved`
- `HallOfFameVoteResolved`

## 6. 투구 DTO

```swift
struct PitchContext: Codable, Sendable {
    let gameID: GameID
    let plateAppearanceID: PlateAppearanceID
    let inning: UInt8
    let half: InningHalf
    let outs: UInt8
    let balls: UInt8
    let strikes: UInt8
    let runners: RunnerState
    let scoreDifferential: Int8
    let leverage: UInt16
    let pitcherFatigue: UInt16
}

struct PitchCall: Codable, Sendable {
    let pitchType: PitchType
    let sector: ZoneSector
    let zoneIntent: ZoneIntent
    let effort: PitchEffort
}

struct PitchExecution: Codable, Sendable {
    let targetX: Int32
    let targetY: Int32
    let actualX: Int32
    let actualY: Int32
    let velocityTenthsKph: UInt16
    let horizontalBreakTenthsCm: Int16
    let verticalBreakTenthsCm: Int16
    let executionQuality: UInt16
}
```

## 7. 이벤트 불변성

- 발생한 이벤트 payload 의미를 사후 변경하지 않는다.
- 새로운 필드는 optional 또는 버전별 decoder로 추가한다.
- 잘못된 과거 이벤트를 수정해야 하면 보정 이벤트를 추가한다.
- 화면 문구는 이벤트에 저장하지 않고 reason code와 데이터로 재구성한다. 역사적 문장 보존이 필요한 뉴스는 별도 snapshot text를 저장할 수 있다.

## 8. JSON-RPC 예

### 요청

```json
{"jsonrpc":"2.0","id":"req-1042","method":"session.submitCommand","params":{"sessionID":"s-1","expectedRevision":118,"command":{"type":"SubmitPitchCall","pitchType":"slider","sector":"awayLow","zoneIntent":"chase","effort":"standard"}},"protocolVersion":1}
```

### 성공 응답

```json
{"jsonrpc":"2.0","id":"req-1042","result":{"revision":119,"events":[{"type":"PitchCallCommitted"},{"type":"PitchExecuted"},{"type":"PitchResolved","result":"swingingStrike"}],"snapshot":{"count":"1-2","shortFeedback":"노림수를 벗어난 낮은 슬라이더에 헛스윙했습니다."}}}
```

### 오류 응답

```json
{"jsonrpc":"2.0","id":"req-1042","error":{"code":"STALE_REVISION","message":"현재 상태가 변경되었습니다.","data":{"currentRevision":119}}}
```

## 9. 콘텐츠 스키마 예

```yaml
id: event.hs.catcher.trust.001
version: 1
stage: high_school
tags: [catcher, trust, pitching_plan]
conditions:
  recommendation_override_rate_min: 0.55
  shared_games_min: 2
cast:
  catcher:
    relationship: starting_catcher
text:
  title: event.hs.catcher.trust.001.title
  body: event.hs.catcher.trust.001.body
choices:
  - id: explain_plan
    text: event.hs.catcher.trust.001.choice.explain
    effects:
      - relationship: {target: catcher, trust: 4}
      - flag: catcher_understands_inner_fastball_plan
  - id: insist
    text: event.hs.catcher.trust.001.choice.insist
    effects:
      - identity: {independence: 3}
      - relationship: {target: catcher, trust: -2}
cooldown_days: 180
exclusive_group: catcher_major_conflict
```

## 10. 저장 manifest 예

```json
{
  "format":"DiamondSoulSave",
  "schemaVersion":4,
  "engineVersion":"0.7.0",
  "contentVersion":"base-0.7.0",
  "worldID":"...",
  "careerID":"...",
  "revision":4182,
  "createdAt":"2026-07-21T00:00:00Z",
  "lastSavedAt":"2026-07-21T01:12:04Z",
  "activeContentPacks":[{"id":"base","version":"0.7.0"}]
}
```

## 11. ViewSnapshot

UI는 전체 GameState가 아니라 목적별 스냅숏을 받는다.

- `HomeSnapshot`
- `PlayerDetailSnapshot`
- `TrainingSnapshot`
- `PitchDecisionSnapshot`
- `PostGameAnalysisSnapshot`
- `DraftSnapshot`
- `MetaProgressionSnapshot`

스냅숏은 다음을 포함한다.

- 표시 준비가 끝난 문자열 키와 숫자.
- action availability와 lock reason.
- stable row ID.
- 접근성용 요약.
- 현재 revision.

숨은 latent 값과 타자 실제 계획은 절대 포함하지 않는다.

## 12. 데이터 보존과 삭제

- 사용자는 세계·커리어를 로컬에서 삭제할 수 있다.
- 삭제는 휴지통 또는 확인 가능한 2단계로 수행한다.
- 구매 entitlement는 저장 삭제와 독립적이다.
- 텔레메트리 내보내기는 명시적 파일 생성이며 개인 이름을 익명 ID로 치환하는 옵션을 제공한다.
