import Foundation

public enum HighSchoolCareerPhase: String, Codable, CaseIterable, Sendable {
    case prologue
    case schoolSelection = "school_selection"
    case training
    case relationship
    case importantGame = "important_game"
    case awakening
    case chapterReview = "chapter_review"
    case draft
    case legacy
    case completed
}

public enum ThrowingHand: String, Codable, CaseIterable, Sendable {
    case right
    case left
}

public enum BodyType: String, Codable, CaseIterable, Sendable {
    case compact
    case balanced
    case tall
}

public enum DifficultyLevel: String, Codable, CaseIterable, Sendable {
    case relaxed
    case standard
    case challenging
}

public enum InterventionAssist: String, Codable, CaseIterable, Sendable {
    case full
    case standard
    case minimal
}

public struct CareerDifficultySnapshot: Codable, Equatable, Sendable {
    public let careerHarshness: DifficultyLevel
    public let informationClarity: DifficultyLevel
    public let simulationDifficulty: DifficultyLevel
    public let interventionAssist: InterventionAssist
    public init(
        careerHarshness: DifficultyLevel = .standard,
        informationClarity: DifficultyLevel = .standard,
        simulationDifficulty: DifficultyLevel = .standard,
        interventionAssist: InterventionAssist = .standard
    ) {
        self.careerHarshness = careerHarshness
        self.informationClarity = informationClarity
        self.simulationDifficulty = simulationDifficulty
        self.interventionAssist = interventionAssist
    }
    public static let standard = CareerDifficultySnapshot()
}

public enum KarmaID: String, Codable, CaseIterable, Sendable {
    case unknownLand = "unknown_land"
    case stubbornCoach = "stubborn_coach"
    case singleWeapon = "single_weapon"
    case geniusGeneration = "genius_generation"
    case erasedMemory = "erased_memory"
    case noLastChance = "no_last_chance"

    public var rewardPermille: Int {
        switch self {
        case .unknownLand, .stubbornCoach: return 150
        case .singleWeapon: return 200
        case .geniusGeneration, .erasedMemory: return 250
        case .noLastChance: return 350
        }
    }
}

public struct PlayerIdentitySnapshot: Codable, Equatable, Sendable {
    public let name: String
    public let throwingHand: ThrowingHand
    public let bodyType: BodyType
    public let region: String
    /// Generated portrait identity for this one life. Optional keeps pre-feature saves readable;
    /// those saves retain their historical name-based portrait through `portraitSeed`.
    public let appearanceSeed: String?
    public init(
        name: String,
        throwingHand: ThrowingHand,
        bodyType: BodyType,
        region: String,
        appearanceSeed: String? = nil
    ) {
        self.name = name
        self.throwingHand = throwingHand
        self.bodyType = bodyType
        self.region = region
        self.appearanceSeed = appearanceSeed
    }

    public var portraitSeed: String {
        guard let appearanceSeed, !appearanceSeed.isEmpty else { return name }
        return appearanceSeed
    }

    public static let defaultPitcher = PlayerIdentitySnapshot(
        name: "민서준", throwingHand: .right, bodyType: .balanced, region: "서울"
    )
}

public enum SchoolID: String, Codable, CaseIterable, Sendable {
    case hanbitTraditional = "hanbit_traditional"
    case miraeAnalytics = "mirae_analytics"
    case haedongPower = "haedong_power"
    case cheongamDevelopment = "cheongam_development"
}

public enum RelationshipTarget: String, Codable, CaseIterable, Sendable {
    case coach
    case catcher
    case rival
}

public enum RelationshipResponse: String, Codable, CaseIterable, Sendable {
    case listen
    case explain
    case challenge
}

public enum DraftOutcome: String, Codable, Sendable {
    case drafted
    case undrafted
}

/// 고교 혹사 신호. 중요 경기의 투구 수와 당시 피로로 누적된 팔 상태를 세 단계로 나눈 것.
/// 부상 회복 중에는 `recovering`으로 덮어써 UI가 회복 카드를 보여 준다.
public enum ArmHealthState: String, Codable, CaseIterable, Sendable {
    case normal
    case caution
    case warning
    case recovering
}

public struct SchoolSnapshot: Codable, Equatable, Sendable {
    public let id: SchoolID
    public let name: String
    public let philosophy: String
    public let coachName: String
    public let coachArchetype: String
    public let catcherName: String
    public let catcherArchetype: String
    public let coachPersonality: String?
    public let coachRecord: String?
    public let catcherPersonality: String?
    public let catcherRecord: String?
    public let strength: TrainingFocus
    public let tradeoff: String

    public init(
        id: SchoolID,
        name: String,
        philosophy: String,
        coachName: String,
        coachArchetype: String,
        catcherName: String,
        catcherArchetype: String,
        coachPersonality: String? = nil,
        coachRecord: String? = nil,
        catcherPersonality: String? = nil,
        catcherRecord: String? = nil,
        strength: TrainingFocus,
        tradeoff: String
    ) {
        self.id = id
        self.name = name
        self.philosophy = philosophy
        self.coachName = coachName
        self.coachArchetype = coachArchetype
        self.catcherName = catcherName
        self.catcherArchetype = catcherArchetype
        self.coachPersonality = coachPersonality
        self.coachRecord = coachRecord
        self.catcherPersonality = catcherPersonality
        self.catcherRecord = catcherRecord
        self.strength = strength
        self.tradeoff = tradeoff
    }
}

public struct RivalSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let archetype: String
    public let contact: Int
    public let discipline: Int
    public let power: Int
    public let personality: String?
    public let signatureRecord: String?

    public init(
        id: String,
        name: String,
        archetype: String,
        contact: Int,
        discipline: Int,
        power: Int,
        personality: String? = nil,
        signatureRecord: String? = nil
    ) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.contact = contact
        self.discipline = discipline
        self.power = power
        self.personality = personality
        self.signatureRecord = signatureRecord
    }
}

public struct CareerChapterSnapshot: Codable, Equatable, Sendable {
    public let number: Int
    public let title: String
    public let schoolYear: Int
    public let season: String
    public let theme: String

    public init(number: Int, title: String, schoolYear: Int, season: String, theme: String) {
        self.number = number
        self.title = title
        self.schoolYear = schoolYear
        self.season = season
        self.theme = theme
    }
}

public struct CareerPerformanceSnapshot: Codable, Equatable, Sendable {
    public let importantGamesCompleted: Int
    public let pitches: Int
    public let strikeouts: Int
    public let walks: Int
    public let runsAllowed: Int
    public let expectedDamage: Int
    public let actualDamage: Int
    /// 실제로 잡은 아웃과 맞은 안타. 이닝·방어율·WHIP처럼 야구팬이 읽는 지표는 이 둘이
    /// 없으면 만들 수 없다. 이 필드가 없던 저장본은 nil이라 해당 지표만 접힌다.
    public let outs: Int?
    public let hits: Int?

    public init(
        importantGamesCompleted: Int = 0,
        pitches: Int = 0,
        strikeouts: Int = 0,
        walks: Int = 0,
        runsAllowed: Int = 0,
        expectedDamage: Int = 0,
        actualDamage: Int = 0,
        outs: Int? = nil,
        hits: Int? = nil
    ) {
        self.importantGamesCompleted = importantGamesCompleted
        self.pitches = pitches
        self.strikeouts = strikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.expectedDamage = expectedDamage
        self.actualDamage = actualDamage
        self.outs = outs
        self.hits = hits
    }

    func adding(_ report: ImportantInningReport) -> CareerPerformanceSnapshot {
        CareerPerformanceSnapshot(
            importantGamesCompleted: importantGamesCompleted + 1,
            pitches: pitches + report.pitches,
            strikeouts: strikeouts + report.strikeouts,
            walks: walks + report.walks,
            runsAllowed: runsAllowed + report.runsAllowed,
            expectedDamage: expectedDamage + report.expectedDamage,
            actualDamage: actualDamage + report.actualDamage,
            outs: (outs ?? 0) + (report.outs ?? 0),
            hits: (hits ?? 0) + (report.hits ?? 0)
        )
    }
}

public struct DraftTeamSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let need: TrainingFocus
    public let demand: Int
    public let developmentPlan: String
    public let positionCompetitor: String
    public let proCoach: String
    public let competitorProfile: String?
    public let competitorRecord: String?
    public let coachProfile: String?
    public let coachRecord: String?

    public init(
        id: String,
        name: String,
        need: TrainingFocus,
        demand: Int,
        developmentPlan: String,
        positionCompetitor: String,
        proCoach: String,
        competitorProfile: String? = nil,
        competitorRecord: String? = nil,
        coachProfile: String? = nil,
        coachRecord: String? = nil
    ) {
        self.id = id
        self.name = name
        self.need = need
        self.demand = demand
        self.developmentPlan = developmentPlan
        self.positionCompetitor = positionCompetitor
        self.proCoach = proCoach
        self.competitorProfile = competitorProfile
        self.competitorRecord = competitorRecord
        self.coachProfile = coachProfile
        self.coachRecord = coachRecord
    }
}

public struct DraftResultSnapshot: Codable, Equatable, Sendable {
    public let outcome: DraftOutcome
    public let evaluationScore: Int
    public let projectedRange: String
    public let team: DraftTeamSnapshot?
    public let round: Int?
    public let overallPick: Int?
    public let signingBonus: Int?
    public let firstSeasonGoal: String?
    /// 평가 점수가 어디서 왔는지. 화면이 이걸 보여 주지 않으면 시즌 기록도, 관계도,
    /// 각성도 "쌓기는 하는데 뭐가 달라졌는지 모르겠는" 것이 된다.
    public let evaluationBreakdown: [String]?
    public let summary: String

    public init(
        outcome: DraftOutcome,
        evaluationScore: Int,
        projectedRange: String,
        team: DraftTeamSnapshot?,
        round: Int?,
        overallPick: Int?,
        signingBonus: Int?,
        firstSeasonGoal: String?,
        evaluationBreakdown: [String]? = nil,
        summary: String
    ) {
        self.outcome = outcome
        self.evaluationScore = evaluationScore
        self.projectedRange = projectedRange
        self.team = team
        self.round = round
        self.overallPick = overallPick
        self.signingBonus = signingBonus
        self.firstSeasonGoal = firstSeasonGoal
        self.evaluationBreakdown = evaluationBreakdown
        self.summary = summary
    }
}

/// 오늘의 기회: 매 훈련마다 코치가 미는 분야 하나가 결정론적으로 바뀐다.
/// 적중하면 성장 신호 보너스 — 로테이션 선택에 매번 다른 이유를 만든다.
public struct TrainingOpportunitySnapshot: Codable, Equatable, Sendable {
    public let focus: TrainingFocus
    public let reason: String
    public init(focus: TrainingFocus, reason: String) {
        self.focus = focus
        self.reason = reason
    }
}

public struct CareerTrainingSnapshot: Codable, Equatable, Sendable {
    public let number: Int
    public let focus: TrainingFocus
    public let intensity: TrainingIntensity
    public let growth: Int
    public let fatigueChange: Int
    public let feedback: String
    public let metricBefore: Int?
    public let metricAfter: Int?
    public let fatigueBefore: Int?
    public let fatigueAfter: Int?
    public let opportunityHit: Bool?
    /// 이 훈련으로 만개한 능력. 화면이 축하 연출을 띄우는 신호다.
    public let bloomedAbility: TalentAbility?
    /// 만개한 뒤의 등급.
    public let bloomedGrade: TalentGrade?
    /// 대성공 — 성장이 두 배로 붙은 훈련. 화면이 잭팟 연출을 띄우는 신호다.
    /// 옛 저장본은 nil이며 false로 읽는다.
    public let jackpot: Bool?

    public init(
        number: Int,
        focus: TrainingFocus,
        intensity: TrainingIntensity,
        growth: Int,
        fatigueChange: Int,
        feedback: String,
        metricBefore: Int? = nil,
        metricAfter: Int? = nil,
        fatigueBefore: Int? = nil,
        fatigueAfter: Int? = nil,
        opportunityHit: Bool? = nil,
        bloomedAbility: TalentAbility? = nil,
        bloomedGrade: TalentGrade? = nil,
        jackpot: Bool? = nil
    ) {
        self.number = number
        self.focus = focus
        self.intensity = intensity
        self.growth = growth
        self.fatigueChange = fatigueChange
        self.feedback = feedback
        self.metricBefore = metricBefore
        self.metricAfter = metricAfter
        self.fatigueBefore = fatigueBefore
        self.fatigueAfter = fatigueAfter
        self.opportunityHit = opportunityHit
        self.bloomedAbility = bloomedAbility
        self.bloomedGrade = bloomedGrade
        self.jackpot = jackpot
    }
}

public struct CareerRelationshipResultSnapshot: Codable, Equatable, Sendable {
    public let number: Int
    public let category: String
    public let title: String
    public let response: RelationshipResponse
    public let trustBefore: Int
    public let trustAfter: Int
    public let fatigueBefore: Int
    public let fatigueAfter: Int
    public let fanInterestBefore: Int
    public let fanInterestAfter: Int
    public let growthFocus: TrainingFocus?
    public let abilityBefore: Int?
    public let abilityAfter: Int?
    public let feedback: String

    public init(number: Int, category: String, title: String, response: RelationshipResponse,
        trustBefore: Int, trustAfter: Int, fatigueBefore: Int, fatigueAfter: Int,
        fanInterestBefore: Int, fanInterestAfter: Int, growthFocus: TrainingFocus?,
        abilityBefore: Int?, abilityAfter: Int?, feedback: String) {
        self.number = number
        self.category = category
        self.title = title
        self.response = response
        self.trustBefore = trustBefore
        self.trustAfter = trustAfter
        self.fatigueBefore = fatigueBefore
        self.fatigueAfter = fatigueAfter
        self.fanInterestBefore = fanInterestBefore
        self.fanInterestAfter = fanInterestAfter
        self.growthFocus = growthFocus
        self.abilityBefore = abilityBefore
        self.abilityAfter = abilityAfter
        self.feedback = feedback
    }
}

/// 한 회차(런)의 챕터 뼈대. 시드+회차에서 결정론적으로 생성되며, 챕터별 훈련 수와 관계·경기·각성
/// 국면의 배치를 담는다. 스펙 범위: 훈련 12–16 / 관계 4–6 / 중요 경기 4–6 / 각성 3(고정).
/// 옛 저장본은 이 필드가 없어 nil이며 `fixedDefault`(기존 16/5/5/3 뼈대)로 읽어 진행 중 리듬을
/// 그대로 보존한다. [[focusStreak]]·시즌 아크의 옵셔널+백필 패턴과 같은 계열이다.
/// final class 박싱: 거대 스냅숏 구조체 안에 배열의 배열을 인라인으로 두면 Swift 6.3의
/// outlined destroy 코드젠 결함(전체 스위트 실행 시 오버릴리즈 크래시)을 밟는다.
/// 참조 타입으로 박싱하면 destroy 경로가 단순해지고 Codable JSON 형태는 struct와 동일하다.
public final class CareerScheduleSnapshot: Codable, Equatable, Sendable {
    /// 8개 챕터의 챕터별 훈련 횟수. 각 값 ≥ 1, 합은 12–16.
    public let trainingsByChapter: [Int]
    /// 8개 챕터의 챕터별 국면 배치. 각 원소는 relationship/importantGame/awakening을 순서대로 담는다.
    /// 드래프트(.draft)는 저장하지 않고 8챕터의 국면 뒤에 엔진이 덧붙인다.
    public let milestonesByChapter: [[HighSchoolCareerPhase]]

    public init(trainingsByChapter: [Int], milestonesByChapter: [[HighSchoolCareerPhase]]) {
        self.trainingsByChapter = trainingsByChapter
        self.milestonesByChapter = milestonesByChapter
    }

    public static func == (lhs: CareerScheduleSnapshot, rhs: CareerScheduleSnapshot) -> Bool {
        lhs.trainingsByChapter == rhs.trainingsByChapter && lhs.milestonesByChapter == rhs.milestonesByChapter
    }

    public var trainingTotal: Int { trainingsByChapter.reduce(0, +) }
    public var relationshipTotal: Int { count(.relationship) }
    public var importantGameTotal: Int { count(.importantGame) }
    public var awakeningTotal: Int { count(.awakening) }

    private func count(_ phase: HighSchoolCareerPhase) -> Int {
        milestonesByChapter.reduce(0) { $0 + $1.filter { $0 == phase }.count }
    }

    /// 이 장에 공식 경기가 있는가.
    ///
    /// 탈삼진 목표는 공식 경기에서만 쌓인다(불펜은 "기록에 남지 않는 연습"이다). 1장은
    /// 마일스톤이 관계 하나뿐이라 던질 기회가 아예 없는데, 화면은 "이번 이야기 탈삼진
    /// N개"를 네 곳에서 반복하고 게이지는 0에서 한 번도 움직이지 않은 채 장이 끝났다.
    /// 목표를 낼 자격이 있는 장인지 먼저 묻는다.
    public func hasImportantGame(inChapter chapterNumber: Int) -> Bool {
        let index = chapterNumber - 1
        guard milestonesByChapter.indices.contains(index) else { return false }
        return milestonesByChapter[index].contains(.importantGame)
    }

    /// Phase 4 이전의 고정 뼈대(훈련 16 / 관계 5 / 중요 경기 5 / 각성 3). 스케줄 필드가 없는 옛
    /// 저장본이 이 값으로 백필돼 저장 호환과 진행 중 회차의 리듬을 유지한다.
    public static let fixedDefault = CareerScheduleSnapshot(
        trainingsByChapter: [2, 2, 2, 2, 2, 2, 2, 2],
        milestonesByChapter: [
            [.relationship],
            [.relationship, .importantGame],
            [.awakening, .importantGame],
            [.relationship, .importantGame],
            [.relationship],
            [.awakening, .importantGame],
            [.relationship],
            [.awakening, .importantGame]
        ]
    )

    /// 상태 커밋먼트에 넣는 결정론적 토큰. 챕터별 훈련·국면을 그대로 담아 스케줄 변조를 탐지한다.
    var commitmentToken: String {
        let trainings = trainingsByChapter.map(String.init).joined(separator: ",")
        let milestones = milestonesByChapter
            .map { $0.map(\.rawValue).joined(separator: ",") }
            .joined(separator: ";")
        return "\(trainings)|\(milestones)"
    }
}

/// final class 박싱: 41개 저장 프로퍼티를 가진 값 타입으로 두면 Swift 6.3의 outlined destroy
/// 코드젠 결함(전체 스위트 실행 시 `outlined destroy of HighSchoolCareerSnapshot`에서
/// 오버릴리즈 크래시)을 밟는다. 개별 테스트는 전부 통과하고 스위트 전체를 돌릴 때만 터지며,
/// 모듈의 함수 구성이 조금만 바뀌어도 재발한다. `CareerScheduleSnapshot`과 같은 처방이다.
/// 모든 프로퍼티가 `let`이고 엔진은 항상 `replacing(...)`으로 새 인스턴스를 만들기 때문에
/// 참조 타입이 되어도 값 의미론이 그대로 유지되고, Codable JSON 형태도 struct와 동일하다.
public final class HighSchoolCareerSnapshot: Codable, Equatable, Sendable {
    public let careerID: String
    public let revision: UInt64
    public let lifeNumber: Int
    public let phase: HighSchoolCareerPhase
    public let identity: PlayerIdentitySnapshot
    public let difficulty: CareerDifficultySnapshot
    public let karmas: [KarmaID]
    public let legacyRewardPermille: Int
    public let memorySlots: Int
    public let pitcher: PitcherSnapshot
    public let schoolOptions: [SchoolSnapshot]
    public let school: SchoolSnapshot?
    public let rival: RivalSnapshot
    public let chapter: CareerChapterSnapshot
    public let chapterTrainingCount: Int
    public let totalTrainingsCompleted: Int
    public let milestoneIndex: Int
    public let relationshipsCompleted: Int
    public let relationshipTrust: Int
    public let managerTrust: Int?
    public let catcherTrust: Int?
    public let rivalTrust: Int?
    public let selectedAwakenings: [AwakeningID]
    public let awakeningOptions: [AwakeningID]
    public let fatigue: Int
    public let performance: CareerPerformanceSnapshot
    /// 이번 학년의 경기 기록. 직접 던진 중요 경기와 자동으로 흘러간 팀 경기가 함께 쌓인다.
    ///
    /// 예전에는 팀의 나머지 경기가 세계에 존재하지 않았다 — 누적 K/BB/실점만 있고
    /// "3학년 봄에 어땠는지"를 볼 방법이 없었다. 드래프트 평가가 직접 던진 4~6경기만 보고
    /// 내려지는 것도 같은 이유였다.
    ///
    /// **commitment 해시에 넣지 않는다.** 넣으면 이 필드가 없는 저장본이 전부 열리지 않는다.
    public let seasonLog: [ProGameLine]?
    public let currentGameScenario: ImportantGameScenarioContent?
    public let currentRelationshipEvent: CareerEventContent?
    public let lastTraining: CareerTrainingSnapshot?
    public let lastRelationship: CareerRelationshipResultSnapshot?
    public let news: [String]
    public let fanInterest: Int
    public let draftResult: DraftResultSnapshot?
    public let legacyOptions: [MemoryCardID]
    public let selectedMemories: [MemoryCardID]
    public let balanceVersion: Int?
    /// 회차 세계 규칙 버전. 이 필드가 없는 구저장본은 v1 바람을 그대로 사용한다.
    /// 신규 회차는 v2를 명시해 콘텐츠 풀이 바뀌어도 진행 중 규칙이 움직이지 않는다.
    public let worldRulesVersion: Int?
    /// 누적 팔 상태 위험(0–100). 옛 저장본은 값이 없어 nil이며 0으로 읽는다. [[focusStreak]] 패턴.
    public let armRisk: Int?
    /// 부상으로 강제된 남은 회복 훈련 횟수(0–2). nil은 부상 이력이 없다는 뜻이다.
    public let injuryRecovery: Int?
    /// 이 회차의 챕터 뼈대(챕터별 훈련 수·국면 배치). 옛 저장본은 없어 nil이며 엔진이
    /// `CareerScheduleSnapshot.fixedDefault`(16/5/5/3)로 읽는다. [[focusStreak]] 패턴.
    public let schedule: CareerScheduleSnapshot?
    /// 파생 상태(커밋 제외): careerID와 완료 훈련 수에서 항상 재계산된다.
    public let trainingOpportunity: TrainingOpportunitySnapshot?
    /// 이 회차의 재능. 능력마다 성장 한계가 다르고, 한계는 만개로 열린다.
    ///
    /// **커밋 해시에 넣지 않는다.** 넣으면 이 필드가 없는 저장본이 전부 열리지 않는다.
    /// nil은 재능 개념이 없던 저장본이라는 뜻이고, `TalentSnapshot.unlimited`로 읽어
    /// 예전과 똑같이 동작한다. [[focusStreak]] 패턴.
    public let talent: TalentSnapshot?
    /// 이번 회차에 적용된 영혼 상점 부스트. 옛 저장본은 nil. 커밋에는 있을 때만 넣는다.
    public let soulBoosts: [String]?
    /// 각성의 전조(0~6). 호투·만개가 쌓아 올리고, 각성 국면이 소비한다 —
    /// 전조가 많을수록 각성 때 열리는 갈래가 많다. 각성이 "일정이 주는 보상"이 아니라
    /// "시즌의 증명이 부르는 순간"이 되게 하는 값이다. 옛 저장본은 nil이며 0으로 읽는다.
    /// 커밋에는 있을 때만 넣는다. [[focusStreak]] 패턴.
    public let awakeningSparks: Int?
    /// 직전 삶에서 실제로 일어난 일만 환생 사건으로 되비추기 위한 작은 영수증.
    /// nil인 구저장본은 기존 전체 환생 사건 풀을 유지한다.
    public let rebirthEcho: RebirthEchoSnapshot?
    public let lineageLoadout: CareerLineageLoadout?
    public let stateCommitment: String

    public var effectiveWorldRulesVersion: CareerRulesVersion {
        .resolve(storedValue: worldRulesVersion)
    }

    public var careerWind: CareerWind {
        CareerWind.wind(careerID: careerID, rulesVersion: effectiveWorldRulesVersion)
    }

    public init(
        careerID: String,
        revision: UInt64,
        lifeNumber: Int,
        phase: HighSchoolCareerPhase,
        identity: PlayerIdentitySnapshot,
        difficulty: CareerDifficultySnapshot,
        karmas: [KarmaID],
        legacyRewardPermille: Int,
        memorySlots: Int,
        pitcher: PitcherSnapshot,
        schoolOptions: [SchoolSnapshot],
        school: SchoolSnapshot?,
        rival: RivalSnapshot,
        chapter: CareerChapterSnapshot,
        chapterTrainingCount: Int,
        totalTrainingsCompleted: Int,
        milestoneIndex: Int,
        relationshipsCompleted: Int,
        relationshipTrust: Int,
        managerTrust: Int? = nil,
        catcherTrust: Int? = nil,
        rivalTrust: Int? = nil,
        selectedAwakenings: [AwakeningID],
        awakeningOptions: [AwakeningID],
        fatigue: Int,
        performance: CareerPerformanceSnapshot,
        seasonLog: [ProGameLine]? = nil,
        currentGameScenario: ImportantGameScenarioContent?,
        currentRelationshipEvent: CareerEventContent?,
        lastTraining: CareerTrainingSnapshot?,
        lastRelationship: CareerRelationshipResultSnapshot? = nil,
        news: [String],
        fanInterest: Int,
        draftResult: DraftResultSnapshot?,
        legacyOptions: [MemoryCardID],
        selectedMemories: [MemoryCardID],
        balanceVersion: Int? = nil,
        worldRulesVersion: Int? = nil,
        armRisk: Int? = nil,
        injuryRecovery: Int? = nil,
        schedule: CareerScheduleSnapshot? = nil,
        trainingOpportunity: TrainingOpportunitySnapshot? = nil,
        talent: TalentSnapshot? = nil,
        soulBoosts: [String]? = nil,
        awakeningSparks: Int? = nil,
        rebirthEcho: RebirthEchoSnapshot? = nil,
        lineageLoadout: CareerLineageLoadout? = nil,
        stateCommitment: String
    ) {
        self.careerID = careerID
        self.revision = revision
        self.lifeNumber = lifeNumber
        self.phase = phase
        self.identity = identity
        self.difficulty = difficulty
        self.karmas = karmas
        self.legacyRewardPermille = legacyRewardPermille
        self.memorySlots = memorySlots
        self.pitcher = pitcher
        self.schoolOptions = schoolOptions
        self.school = school
        self.rival = rival
        self.chapter = chapter
        self.chapterTrainingCount = chapterTrainingCount
        self.totalTrainingsCompleted = totalTrainingsCompleted
        self.milestoneIndex = milestoneIndex
        self.relationshipsCompleted = relationshipsCompleted
        self.relationshipTrust = relationshipTrust
        self.managerTrust = managerTrust
        self.catcherTrust = catcherTrust
        self.rivalTrust = rivalTrust
        self.selectedAwakenings = selectedAwakenings
        self.awakeningOptions = awakeningOptions
        self.fatigue = fatigue
        self.performance = performance
        self.seasonLog = seasonLog
        self.currentGameScenario = currentGameScenario
        self.currentRelationshipEvent = currentRelationshipEvent
        self.lastTraining = lastTraining
        self.lastRelationship = lastRelationship
        self.news = news
        self.fanInterest = fanInterest
        self.draftResult = draftResult
        self.legacyOptions = legacyOptions
        self.selectedMemories = selectedMemories
        self.balanceVersion = balanceVersion
        self.worldRulesVersion = worldRulesVersion
        self.armRisk = armRisk
        self.injuryRecovery = injuryRecovery
        self.schedule = schedule
        self.trainingOpportunity = trainingOpportunity
        self.talent = talent
        self.soulBoosts = soulBoosts
        self.awakeningSparks = awakeningSparks
        self.rebirthEcho = rebirthEcho
        self.lineageLoadout = lineageLoadout
        self.stateCommitment = stateCommitment
    }

    /// 클래스라 == 가 합성되지 않는다. 모든 저장 프로퍼티를 비교해 struct 시절과 같은 값 동등성을 준다.
    public static func == (lhs: HighSchoolCareerSnapshot, rhs: HighSchoolCareerSnapshot) -> Bool {
        lhs.careerID == rhs.careerID
            && lhs.revision == rhs.revision
            && lhs.lifeNumber == rhs.lifeNumber
            && lhs.phase == rhs.phase
            && lhs.identity == rhs.identity
            && lhs.difficulty == rhs.difficulty
            && lhs.karmas == rhs.karmas
            && lhs.legacyRewardPermille == rhs.legacyRewardPermille
            && lhs.memorySlots == rhs.memorySlots
            && lhs.pitcher == rhs.pitcher
            && lhs.schoolOptions == rhs.schoolOptions
            && lhs.school == rhs.school
            && lhs.rival == rhs.rival
            && lhs.chapter == rhs.chapter
            && lhs.chapterTrainingCount == rhs.chapterTrainingCount
            && lhs.totalTrainingsCompleted == rhs.totalTrainingsCompleted
            && lhs.milestoneIndex == rhs.milestoneIndex
            && lhs.relationshipsCompleted == rhs.relationshipsCompleted
            && lhs.relationshipTrust == rhs.relationshipTrust
            && lhs.managerTrust == rhs.managerTrust
            && lhs.catcherTrust == rhs.catcherTrust
            && lhs.rivalTrust == rhs.rivalTrust
            && lhs.selectedAwakenings == rhs.selectedAwakenings
            && lhs.awakeningOptions == rhs.awakeningOptions
            && lhs.fatigue == rhs.fatigue
            && lhs.performance == rhs.performance
            && lhs.seasonLog == rhs.seasonLog
            && lhs.currentGameScenario == rhs.currentGameScenario
            && lhs.currentRelationshipEvent == rhs.currentRelationshipEvent
            && lhs.lastTraining == rhs.lastTraining
            && lhs.lastRelationship == rhs.lastRelationship
            && lhs.news == rhs.news
            && lhs.fanInterest == rhs.fanInterest
            && lhs.draftResult == rhs.draftResult
            && lhs.legacyOptions == rhs.legacyOptions
            && lhs.selectedMemories == rhs.selectedMemories
            && lhs.balanceVersion == rhs.balanceVersion
            && lhs.worldRulesVersion == rhs.worldRulesVersion
            && lhs.armRisk == rhs.armRisk
            && lhs.injuryRecovery == rhs.injuryRecovery
            && lhs.schedule == rhs.schedule
            && lhs.trainingOpportunity == rhs.trainingOpportunity
            && lhs.talent == rhs.talent
            && lhs.soulBoosts == rhs.soulBoosts
            && lhs.awakeningSparks == rhs.awakeningSparks
            && lhs.rebirthEcho == rhs.rebirthEcho
            && lhs.lineageLoadout == rhs.lineageLoadout
            && lhs.stateCommitment == rhs.stateCommitment
    }
}

/// 다음 삶이 기억할 수 있는 직전 선수의 사실만 담는다.
///
/// 전체 기록을 코어에 넘기지 않아 저장 결합도를 낮추고, 사건 선택에 필요한 최소 사실만
/// 무결성 해시에 포함한다. 이름은 표현에, 나머지는 모순 사건 제거에 사용한다.
public struct RebirthEchoSnapshot: Codable, Equatable, Sendable {
    public let previousPlayerName: String?
    public let previousSchoolName: String?
    public let previousNickname: String?
    public let inheritedMemoryCount: Int
    public let hadArmWarning: Bool
    public let hadCollapseGame: Bool
    public let wasUndrafted: Bool
    /// Added as optional facts so saves from before the richer echo receipt still decode and
    /// retain their original commitment token.
    public let previousLifeNumber: Int?
    public let previousCoachName: String?
    public let previousRivalName: String?
    public let inheritedLegacyID: String?
    public let automaticInheritanceTotal: Int?
    public let hadRunsAllowed: Bool?
    /// Oldest to newest. The selector first uses unseen events, then the least-recent event.
    public let recentEventIDs: [String]?

    public init(
        previousPlayerName: String? = nil,
        previousSchoolName: String? = nil,
        previousNickname: String? = nil,
        inheritedMemoryCount: Int = 0,
        hadArmWarning: Bool = false,
        hadCollapseGame: Bool = false,
        wasUndrafted: Bool = false,
        previousLifeNumber: Int? = nil,
        previousCoachName: String? = nil,
        previousRivalName: String? = nil,
        inheritedLegacyID: String? = nil,
        automaticInheritanceTotal: Int? = nil,
        hadRunsAllowed: Bool? = nil,
        recentEventIDs: [String]? = nil
    ) {
        self.previousPlayerName = previousPlayerName
        self.previousSchoolName = previousSchoolName
        self.previousNickname = previousNickname
        self.inheritedMemoryCount = inheritedMemoryCount
        self.hadArmWarning = hadArmWarning
        self.hadCollapseGame = hadCollapseGame
        self.wasUndrafted = wasUndrafted
        self.previousLifeNumber = previousLifeNumber
        self.previousCoachName = previousCoachName
        self.previousRivalName = previousRivalName
        self.inheritedLegacyID = inheritedLegacyID
        self.automaticInheritanceTotal = automaticInheritanceTotal
        self.hadRunsAllowed = hadRunsAllowed
        self.recentEventIDs = recentEventIDs
    }

    public var hasInheritedPower: Bool {
        inheritedMemoryCount > 0 || inheritedLegacyID != nil || (automaticInheritanceTotal ?? 0) > 0
    }

    public var hasRunsAllowedFact: Bool { hadRunsAllowed ?? hadCollapseGame }

    var commitmentToken: String {
        var tokens = [
            previousPlayerName ?? "none",
            previousSchoolName ?? "none",
            previousNickname ?? "none",
            String(inheritedMemoryCount),
            hadArmWarning ? "1" : "0",
            hadCollapseGame ? "1" : "0",
            wasUndrafted ? "1" : "0",
        ]
        if previousLifeNumber != nil || previousCoachName != nil || previousRivalName != nil
            || inheritedLegacyID != nil || automaticInheritanceTotal != nil
            || hadRunsAllowed != nil || recentEventIDs != nil {
            tokens += [
                String(previousLifeNumber ?? 0),
                previousCoachName ?? "none",
                previousRivalName ?? "none",
                inheritedLegacyID ?? "none",
                String(automaticInheritanceTotal ?? 0),
                hadRunsAllowed == true ? "1" : "0",
                recentEventIDs?.joined(separator: ",") ?? "none",
            ]
        }
        return tokens.joined(separator: ":")
    }
}

/// 영혼 상점 — 환생 때 야구혼 잔액을 소비해 이번 회차의 규칙을 산다.
///
/// 자동 스며듦(상한 8~20)은 공짜 계승이고, 상점은 그 너머의 잔액이 흘러갈 배수구다.
/// 스탯이 아니라 규칙을 팔아야 상한 인플레이션이 생기지 않는다.
public enum SoulBoostID: String, Codable, CaseIterable, Sendable {
    /// 가장 낮은 재능 등급을 한 단계 올린 채 시작한다.
    case talentBreak = "talent_break"
    /// 가져갈 기억 3장 → 4장. 전생의 기억을 한 장 더 가져온다.
    case extraMemory = "extra_memory"
    /// 자동 스며듦 상한 너머로 +5가 추가로 스며든다(재능 벽은 그대로 존중).
    case headStart = "head_start"
    /// 이번 회차 훈련 대성공(잭팟) 확률 16% → 26%.
    case trainingRhythm = "training_rhythm"

    /// 야구혼 비용. 회차당 획득이 대략 30~60이라, 큰 물건은 두세 회차를 모아야 한다.
    public var cost: Int {
        switch self {
        case .talentBreak: 240
        case .extraMemory: 160
        case .headStart: 120
        case .trainingRhythm: 90
        }
    }
}

/// 야구혼이 다음 선수의 시작 능력으로 스며드는 곡선의 저장 호환 버전.
///
/// nil인 기존 요청과 알 수 없는 미래 값은 영구히 v1로 읽는다. 새 회차를 정산하는 앱은
/// `current.rawValue`를 함께 저장해 콘텐츠 업데이트 뒤에도 같은 환산을 재현할 수 있다.
public enum SoulInheritanceRulesVersion: Int, Codable, CaseIterable, Hashable, Sendable {
    case v1 = 1
    case v2 = 2

    public static let current = SoulInheritanceRulesVersion.v2

    public static func resolve(storedValue: Int?) -> SoulInheritanceRulesVersion {
        storedValue.flatMap(SoulInheritanceRulesVersion.init(rawValue:)) ?? .v1
    }
}

public struct StartHighSchoolCareerParams: Codable, Equatable, Sendable {
    public let seed: String
    public let presetID: String
    public let lifeNumber: Int
    public let creationAllocation: CreationAllocationSnapshot
    public let inheritedSoulPoints: Int
    public let inheritedSoulDomain: SoulDomain?
    public let inheritedMemories: [MemoryCardID]
    public let identity: PlayerIdentitySnapshot
    public let difficulty: CareerDifficultySnapshot
    public let karmas: [KarmaID]
    /// 영혼 상점에서 산 부스트. 잔액 검증은 앱(지갑 주인)이 하고 커널은 적용만 한다.
    public let soulBoosts: [SoulBoostID]?
    /// 누적 야구혼 총량(평생 획득분). 스며듦은 이 값이 정한다 — 상점에서 쓴 잔액이
    /// 스며듦을 깎으면 소비처가 벌금이 된다. nil이면 잔액을 총량으로 본다(옛 저장본).
    public let inheritedSoulTotal: Int?
    /// 직전 회차에서 고른 대표 유산 하나. 옛 요청 JSON에는 없으므로 nil로 읽히며,
    /// 배열이 아니라 단일 ID라 같은 시작에 효과가 누적되지 않는다.
    public let signatureLegacyID: CareerSignatureLegacyID?
    /// 야구혼 환산 곡선. nil은 기존 저장의 v1 의미를 보존한다.
    public let inheritanceRulesVersion: Int?
    /// 직전 삶에서 확인된 사실. 도전 모드와 첫 삶은 nil이다.
    public let rebirthEcho: RebirthEchoSnapshot?
    public let lineageLoadout: CareerLineageLoadout?

    public init(
        seed: String,
        presetID: String,
        lifeNumber: Int = 1,
        creationAllocation: CreationAllocationSnapshot = .balanced,
        inheritedSoulPoints: Int = 0,
        inheritedSoulDomain: SoulDomain? = nil,
        inheritedMemories: [MemoryCardID] = [],
        identity: PlayerIdentitySnapshot = .defaultPitcher,
        difficulty: CareerDifficultySnapshot = .standard,
        karmas: [KarmaID] = [],
        soulBoosts: [SoulBoostID]? = nil,
        inheritedSoulTotal: Int? = nil
    ) {
        self.init(
            seed: seed,
            presetID: presetID,
            lifeNumber: lifeNumber,
            creationAllocation: creationAllocation,
            inheritedSoulPoints: inheritedSoulPoints,
            inheritedSoulDomain: inheritedSoulDomain,
            inheritedMemories: inheritedMemories,
            identity: identity,
            difficulty: difficulty,
            karmas: karmas,
            soulBoosts: soulBoosts,
            inheritedSoulTotal: inheritedSoulTotal,
            signatureLegacyID: nil,
            inheritanceRulesVersion: nil
        )
    }

    public init(
        seed: String,
        presetID: String,
        lifeNumber: Int = 1,
        creationAllocation: CreationAllocationSnapshot = .balanced,
        inheritedSoulPoints: Int = 0,
        inheritedSoulDomain: SoulDomain? = nil,
        inheritedMemories: [MemoryCardID] = [],
        identity: PlayerIdentitySnapshot = .defaultPitcher,
        difficulty: CareerDifficultySnapshot = .standard,
        karmas: [KarmaID] = [],
        soulBoosts: [SoulBoostID]? = nil,
        inheritedSoulTotal: Int? = nil,
        signatureLegacyID: CareerSignatureLegacyID?
    ) {
        self.init(
            seed: seed,
            presetID: presetID,
            lifeNumber: lifeNumber,
            creationAllocation: creationAllocation,
            inheritedSoulPoints: inheritedSoulPoints,
            inheritedSoulDomain: inheritedSoulDomain,
            inheritedMemories: inheritedMemories,
            identity: identity,
            difficulty: difficulty,
            karmas: karmas,
            soulBoosts: soulBoosts,
            inheritedSoulTotal: inheritedSoulTotal,
            signatureLegacyID: signatureLegacyID,
            inheritanceRulesVersion: nil
        )
    }

    public init(
        seed: String,
        presetID: String,
        lifeNumber: Int = 1,
        creationAllocation: CreationAllocationSnapshot = .balanced,
        inheritedSoulPoints: Int = 0,
        inheritedSoulDomain: SoulDomain? = nil,
        inheritedMemories: [MemoryCardID] = [],
        identity: PlayerIdentitySnapshot = .defaultPitcher,
        difficulty: CareerDifficultySnapshot = .standard,
        karmas: [KarmaID] = [],
        soulBoosts: [SoulBoostID]? = nil,
        inheritedSoulTotal: Int? = nil,
        signatureLegacyID: CareerSignatureLegacyID?,
        inheritanceRulesVersion: Int?,
        rebirthEcho: RebirthEchoSnapshot? = nil,
        lineageLoadout: CareerLineageLoadout? = nil
    ) {
        self.seed = seed
        self.presetID = presetID
        self.lifeNumber = lifeNumber
        self.creationAllocation = creationAllocation
        self.inheritedSoulPoints = inheritedSoulPoints
        self.inheritedSoulDomain = inheritedSoulDomain
        self.inheritedMemories = inheritedMemories
        self.identity = identity
        self.difficulty = difficulty
        self.karmas = karmas
        self.soulBoosts = soulBoosts
        self.inheritedSoulTotal = inheritedSoulTotal
        self.signatureLegacyID = signatureLegacyID
        self.inheritanceRulesVersion = inheritanceRulesVersion
        self.rebirthEcho = rebirthEcho
        self.lineageLoadout = lineageLoadout
    }
}

public struct ChooseSchoolParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public let schoolID: SchoolID
    public init(seed: String, state: HighSchoolCareerSnapshot, schoolID: SchoolID) {
        self.seed = seed; self.state = state; self.schoolID = schoolID
    }
}

public struct CommitCareerTrainingParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public let focus: TrainingFocus
    public let intensity: TrainingIntensity
    /// 변화구 훈련에서 집중할 구종. 이 키가 없는 구저장·RPC는 nil로 읽혀 전 변화구에
    /// 분산 성장하므로 하위 호환된다.
    public let targetPitch: PitchType?
    public init(
        seed: String,
        state: HighSchoolCareerSnapshot,
        focus: TrainingFocus,
        intensity: TrainingIntensity,
        targetPitch: PitchType? = nil
    ) {
        self.seed = seed
        self.state = state
        self.focus = focus
        self.intensity = intensity
        self.targetPitch = targetPitch
    }
}

public struct ResolveCareerRelationshipParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public let response: RelationshipResponse
    public init(seed: String, state: HighSchoolCareerSnapshot, response: RelationshipResponse) {
        self.seed = seed; self.state = state; self.response = response
    }
}

public struct RecordCareerGameParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public let report: ImportantInningReport
    public init(seed: String, state: HighSchoolCareerSnapshot, report: ImportantInningReport) {
        self.seed = seed; self.state = state; self.report = report
    }
}

public struct ChooseCareerAwakeningParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public let awakening: AwakeningID
    public init(seed: String, state: HighSchoolCareerSnapshot, awakening: AwakeningID) {
        self.seed = seed; self.state = state; self.awakening = awakening
    }
}

public struct AdvanceCareerChapterParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public init(seed: String, state: HighSchoolCareerSnapshot) { self.seed = seed; self.state = state }
}

public struct ResolveDraftParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public init(seed: String, state: HighSchoolCareerSnapshot) { self.seed = seed; self.state = state }
}

public struct SelectCareerLegacyParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: HighSchoolCareerSnapshot
    public let memoryCards: [MemoryCardID]
    public let signatureLegacyID: CareerSignatureLegacyID?
    public init(
        seed: String,
        state: HighSchoolCareerSnapshot,
        memoryCards: [MemoryCardID],
        signatureLegacyID: CareerSignatureLegacyID? = nil
    ) {
        self.seed = seed
        self.state = state
        self.memoryCards = memoryCards
        self.signatureLegacyID = signatureLegacyID
    }
}

public struct HighSchoolCareerEvent: Codable, Equatable, Sendable {
    public let eventType: String
    public let sequence: Int
    public let reasonCodes: [String]
    public init(eventType: String, sequence: Int = 0, reasonCodes: [String] = []) {
        self.eventType = eventType; self.sequence = sequence; self.reasonCodes = reasonCodes
    }
}

public struct HighSchoolCareerResult: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let nextSeed: String
    public let events: [HighSchoolCareerEvent]
    public let snapshot: HighSchoolCareerSnapshot
    public let eventHash: String
    public init(revision: UInt64, nextSeed: String, events: [HighSchoolCareerEvent], snapshot: HighSchoolCareerSnapshot, eventHash: String) {
        self.revision = revision; self.nextSeed = nextSeed; self.events = events; self.snapshot = snapshot; self.eventHash = eventHash
    }
}
