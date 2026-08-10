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
    public init(name: String, throwingHand: ThrowingHand, bodyType: BodyType, region: String) {
        self.name = name; self.throwingHand = throwingHand; self.bodyType = bodyType; self.region = region
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

    public init(
        importantGamesCompleted: Int = 0,
        pitches: Int = 0,
        strikeouts: Int = 0,
        walks: Int = 0,
        runsAllowed: Int = 0,
        expectedDamage: Int = 0,
        actualDamage: Int = 0
    ) {
        self.importantGamesCompleted = importantGamesCompleted
        self.pitches = pitches
        self.strikeouts = strikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.expectedDamage = expectedDamage
        self.actualDamage = actualDamage
    }

    func adding(_ report: ImportantInningReport) -> CareerPerformanceSnapshot {
        CareerPerformanceSnapshot(
            importantGamesCompleted: importantGamesCompleted + 1,
            pitches: pitches + report.pitches,
            strikeouts: strikeouts + report.strikeouts,
            walks: walks + report.walks,
            runsAllowed: runsAllowed + report.runsAllowed,
            expectedDamage: expectedDamage + report.expectedDamage,
            actualDamage: actualDamage + report.actualDamage
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
            && lhs.stateCommitment == rhs.stateCommitment
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
        inheritanceRulesVersion: Int?
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
    public init(seed: String, state: HighSchoolCareerSnapshot, focus: TrainingFocus, intensity: TrainingIntensity) {
        self.seed = seed; self.state = state; self.focus = focus; self.intensity = intensity
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

private struct RelationshipImpact {
    let trust: Int
    let fatigue: Int
    let fanInterest: Int
    let growthFocus: TrainingFocus?
    let outcome: String
}

public struct HighSchoolCareerEngine: Sendable {
    private struct RegionalSchoolNames: Sendable {
        let traditional: String
        let analytics: String
        let power: String
        let development: String
    }

    private static let regionalSchoolNames: [String: RegionalSchoolNames] = [
        "서울": .init(traditional: "서울덕성고", analytics: "서울배성고", power: "서울충림고", development: "서울경원고"),
        "인천": .init(traditional: "인천해문결고", analytics: "인천동림고", power: "인천항성고", development: "인천송해고"),
        "수원": .init(traditional: "수원화성빛고", analytics: "수원장림고", power: "수원화담결고", development: "수원매화솔고"),
        "대전": .init(traditional: "대전갑천별고", analytics: "대전들샘결고", power: "대전유진고", development: "대전중원고"),
        "광주": .init(traditional: "광주무등결고", analytics: "광주예향결고", power: "광주서빛람고", development: "광주무원고"),
        "대구": .init(traditional: "대구팔공결고", analytics: "대구능금결고", power: "대구달원고", development: "대구청림고"),
        "부산": .init(traditional: "부산해남고", analytics: "부산항성고", power: "부산항해솔고", development: "부산오륙결고"),
        "창원": .init(traditional: "마산해강고", analytics: "창원가람솔고", power: "창원누리결고", development: "진해동림고"),
        "울산": .init(traditional: "울산대명고", analytics: "울산문성고", power: "울산태원고", development: "울산장생고"),
        "세종": .init(traditional: "세종한별고", analytics: "세종새빛고", power: "세종금빛고", development: "세종연서고"),
        "경기": .init(traditional: "성남유림고", analytics: "고양서람빛고", power: "시흥소명고", development: "용인청림고"),
        "강원": .init(traditional: "강릉해람고", analytics: "원주원흥고", power: "춘천호반고", development: "속초설해고"),
        "충북": .init(traditional: "청주직지솔고", analytics: "청주세명고", power: "충주성문고", development: "진천덕원고"),
        "충남": .init(traditional: "공주금강고", analytics: "천안능수결고", power: "아산곡교결고", development: "서산해명고"),
        "전북": .init(traditional: "전주한옥솔고", analytics: "군산새만결고", power: "정읍인원고", development: "익산보석고"),
        "전남": .init(traditional: "화순화원고", analytics: "순천정원솔고", power: "목포항남고", development: "여수진원고"),
        "경북": .init(traditional: "포항해오름고", analytics: "경주월림고", power: "구미도원고", development: "안동하회고"),
        "경남": .init(traditional: "마산달빛결고", analytics: "김해수로결고", power: "양산물빛고", development: "거제푸른섬고"),
        "제주": .init(traditional: "제주한라원고", analytics: "서귀포해원고", power: "제주탐라빛고", development: "제주오름고")
    ]

    public static let chapters: [CareerChapterSnapshot] = [
        .init(number: 1, title: "낯선 마운드", schoolYear: 1, season: "봄", theme: "첫 고교 훈련과 첫 공식 등판이 기다린다"),
        .init(number: 2, title: "첫 번째 증명", schoolYear: 1, season: "여름", theme: "여름 대회 출전 명단과 맡을 역할이 정해진다"),
        .init(number: 3, title: "첫 겨울", schoolYear: 1, season: "겨울", theme: "봄이 오기 전까지 가장 부족한 한 가지를 다듬는다"),
        .init(number: 4, title: "전국의 시선", schoolYear: 2, season: "봄", theme: "전국대회에서 라이벌과 다시 만난다"),
        .init(number: 5, title: "흔들리는 배터리", schoolYear: 2, season: "여름", theme: "포수와 자꾸 엇갈리는 사인을 바로잡아야 한다"),
        .init(number: 6, title: "에이스의 책임", schoolYear: 2, season: "가을", theme: "피로가 쌓인 채 가을 대회 마운드에 오른다"),
        .init(number: 7, title: "마지막 겨울", schoolYear: 2, season: "겨울", theme: "스카우트가 지켜볼 마지막 시즌을 준비한다"),
        .init(number: 8, title: "드래프트 데이", schoolYear: 3, season: "여름", theme: "마지막 전국대회를 치르고 드래프트 결과를 기다린다")
    ]

    /// 지역 선택 UI가 쓰는 순서 있는 목록. 사전 키 순회는 순서가 흔들리므로 여기서 고정한다.
    ///
    /// 학교 이름 76개(19지역 × 4)는 처음부터 쓰여 있었는데, iOS가 지역을 "서울"로 하드코딩해
    /// 4개만 노출됐다 — 모든 회차가 같은 네 학교에서 시작하는 이유가 데이터 부족이 아니라
    /// 배선 누락이었다.
    public static let regions: [String] = [
        "서울", "인천", "수원", "대전", "광주", "대구", "부산", "창원", "울산", "세종",
        "경기", "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주"
    ]

    /// 지역별 캐스트 풀 — 학교 유형(철학·아키타입·대사 톤)은 같아도 사람은 지역마다
    /// 다르다. 전국 어디서 시작해도 감독·포수가 4쌍 고정이면 회차가 쌓일수록
    /// "함께한 사람들"이 같은 줄로 반복된다(4차 패널 P1). 지역 인덱스로 순환하므로
    /// 순수 함수이고, 이미 시작된 회차의 스냅숏에는 영향이 없다.
    private static let coachPools: [SchoolID: [String]] = [
        .hanbitTraditional: ["윤태문", "강일도", "백승관", "임동혁", "조범석"],
        .miraeAnalytics: ["노재형", "한기표", "유상민", "신정록", "곽태윤"],
        .haedongPower: ["오승렬", "마동준", "채희성", "도진광", "하병철"],
        .cheongamDevelopment: ["배도환", "어재원", "편상욱", "소진철", "반석호"],
    ]
    private static let catcherPools: [SchoolID: [String]] = [
        .hanbitTraditional: ["서준호", "김도현", "박성재", "이재영", "정우빈"],
        .miraeAnalytics: ["한도윤", "송지헌", "오세민", "권혁준", "남기율"],
        .haedongPower: ["차민석", "변진서", "육정환", "구자헌", "표재신"],
        .cheongamDevelopment: ["문하진", "안시후", "방준서", "석민규", "탁이현"],
    ]
    private static func castName(_ pools: [SchoolID: [String]], _ id: SchoolID, region: String) -> String {
        let pool = pools[id] ?? ["무명"]
        let index = regions.firstIndex(of: region) ?? 0
        return pool[index % max(1, pool.count)]
    }

    public static func schools(for region: String) -> [SchoolSnapshot] {
        let names = regionalSchoolNames[region] ?? regionalSchoolNames["서울"]!
        return [
            .init(id: .hanbitTraditional, name: names.traditional, philosophy: "기본기와 긴 이닝", coachName: castName(coachPools, .hanbitTraditional, region: region), coachArchetype: "원칙형", catcherName: castName(catcherPools, .hanbitTraditional, region: region), catcherArchetype: "안정형",
                coachPersonality: "새벽 반복 훈련을 고집하며 핑계보다 공 하나를 더 던지게 합니다.", coachRecord: "재임 14년 · 전국대회 4강 6회",
                catcherPersonality: "실투 뒤에도 먼저 투수에게 공을 돌려주는 매일 출전형 포수입니다.", catcherRecord: "중학 마지막 시즌 26경기 · 도루저지율 .438",
                strength: .stamina, tradeoff: "새 구종을 시험할 기회가 적습니다."),
            .init(id: .miraeAnalytics, name: names.analytics, philosophy: "기록을 활용한 타자 상대법", coachName: castName(coachPools, .miraeAnalytics, region: region), coachArchetype: "분석형", catcherName: castName(catcherPools, .miraeAnalytics, region: region), catcherArchetype: "분석형",
                coachPersonality: "확률표를 들고 한 베이스와 불펜 교체 시점을 끝까지 계산합니다.", coachRecord: "데이터 코치 경력 11년 · 지역대회 우승 4회",
                catcherPersonality: "말수는 적지만 타자의 노림수를 먼저 읽고 결정적인 순간 직접 해결합니다.", catcherRecord: "전국중학대회 포수상 · 8홈런",
                strength: .gamePlanning, tradeoff: "데이터가 적을 때 판단이 흔들릴 수 있습니다."),
            .init(id: .haedongPower, name: names.power, philosophy: "빠른 직구와 공격적인 승부", coachName: castName(coachPools, .haedongPower, region: region), coachArchetype: "승부형", catcherName: castName(catcherPools, .haedongPower, region: region), catcherArchetype: "공격형",
                coachPersonality: "에이스에게 가장 엄격하며 위기일수록 몸쪽 정면승부를 요구합니다.", coachRecord: "전국대회 결승 3회 · 프로 지명 투수 5명",
                catcherPersonality: "몸쪽 사인을 두려워하지 않고 큰 경기에서 투수를 강하게 끌고 갑니다.", catcherRecord: "중학 마지막 시즌 24경기 선발 · 도루저지 11회",
                strength: .velocity, tradeoff: "빠른 공을 많이 던질수록 피로가 쌓이고 제구가 흔들립니다."),
            .init(id: .cheongamDevelopment, name: names.development, philosophy: "개인별 투구 동작과 변화구 훈련", coachName: castName(coachPools, .cheongamDevelopment, region: region), coachArchetype: "육성형", catcherName: castName(catcherPools, .cheongamDevelopment, region: region), catcherArchetype: "공감형",
                coachPersonality: "무심한 표정으로 결단을 내리지만 큰 경기에서는 선수를 먼저 믿습니다.", coachRecord: "7년간 프로 지명 12명 · 변화구 캠프 9회",
                catcherPersonality: "블로킹 천 번을 기본으로 여기며 투수의 버릇까지 잡아내는 완벽주의자입니다.", catcherRecord: "중학 마지막 시즌 무실책 · 4경기 연속 장타",
                strength: .breakingBall, tradeoff: "팀이 연패하면 개인 훈련 시간이 줄어듭니다.")
        ]
    }

    public static let teams: [DraftTeamSnapshot] = [
        .init(id: "seoul_comets", name: "서울 코메츠", need: .command, demand: 72, developmentPlan: "2군 선발로 뛰며 원하는 코스에 던지는 능력 향상", positionCompetitor: "차윤호", proCoach: "문재석", competitorProfile: "느린 커브와 타이밍 싸움으로 살아남은 베테랑 선발", competitorRecord: "최근 시즌 9승 · ERA 3.91", coachProfile: "선수와 대화부터 시작하는 수비 중심 지도자", coachRecord: "3년 연속 포스트시즌 진출"),
        .init(id: "busan_marines", name: "부산 블루웨일스", need: .stamina, demand: 66, developmentPlan: "긴 이닝을 맡는 선발로 훈련", positionCompetitor: "도현우", proCoach: "강태림", competitorProfile: "높은 포심과 낙차 큰 포크볼을 앞세운 우완 에이스", competitorRecord: "최근 시즌 11승 · 142탈삼진", coachProfile: "큰 경기일수록 선발에게 한 이닝을 더 맡기는 승부사", coachRecord: "챔피언십 시리즈 진출 2회"),
        .init(id: "incheon_waves", name: "인천 크레스트핀스", need: .breakingBall, demand: 70, developmentPlan: "결정구 한 종을 프로 수준으로 강화", positionCompetitor: "백승찬", proCoach: "윤도환", competitorProfile: "슬라이더와 템포 변화로 버티는 왼손 선발", competitorRecord: "최근 시즌 8승 · 126탈삼진", coachProfile: "베테랑 자율과 강한 수비를 함께 요구하는 감독", coachRecord: "정규시즌 상위 3위 2회"),
        .init(id: "daegu_forge", name: "대구 포지", need: .velocity, demand: 75, developmentPlan: "빠른 직구를 유지하며 불펜으로 빠른 1군 데뷔", positionCompetitor: "신재원", proCoach: "권민철", competitorProfile: "낮은 코스와 완급을 반복하는 젊은 우완 에이스", competitorRecord: "최근 시즌 12승 · ERA 3.44", coachProfile: "기본 수비와 세대교체를 함께 밀어붙이는 내야 출신 지도자", coachRecord: "신인 투수 4명 1군 데뷔"),
        .init(id: "daejeon_rockets", name: "대전 로켓츠", need: .gamePlanning, demand: 68, developmentPlan: "포수와 구종 순서를 맞추는 선발 훈련", positionCompetitor: "장하준", proCoach: "배성우", competitorProfile: "빠른 포심으로 타자의 배트를 늦추는 파이어볼러", competitorRecord: "최고 158.2km/h · 134탈삼진", coachProfile: "한번 고른 선발은 충분한 기회를 주는 장기 운영형 감독", coachRecord: "3년 연속 승률 5할 이상"),
        .init(id: "gwangju_phoenix", name: "광주 피닉스", need: .breakingBall, demand: 64, developmentPlan: "직구와 같은 궤도에서 갈라지는 변화구 훈련", positionCompetitor: "서이준", proCoach: "남기석", competitorProfile: "큰 각도의 커브로 삼진을 쌓는 왼손 정통파", competitorRecord: "최근 시즌 10승 · 151탈삼진", coachProfile: "선수를 믿고 공격적으로 뛰게 하는 젊은 감독", coachRecord: "최근 2년 승률 .561"),
        .init(id: "suwon_guardians", name: "수원 가디언즈", need: .command, demand: 61, developmentPlan: "볼넷을 줄인 뒤 1군 긴 이닝 구원으로 데뷔", positionCompetitor: "주성민", proCoach: "오태건", competitorProfile: "낮은 팔 각도와 체인지업으로 볼넷을 줄이는 선발", competitorRecord: "최근 시즌 BB/9 1.8 · 퀄리티스타트 17회", coachProfile: "투수의 팔이 나오는 타이밍을 직접 잡는 잠수함 출신 지도자", coachRecord: "4년 연속 포스트시즌 진출"),
        .init(id: "changwon_meteors", name: "창원 미티어스", need: .velocity, demand: 69, developmentPlan: "직구의 움직임과 최고 구속을 함께 향상", positionCompetitor: "류한결", proCoach: "차경호", competitorProfile: "회전이 좋은 왼손 직구로 뜬공을 만드는 선발", competitorRecord: "최근 시즌 ERA 2.48 · 9승", coachProfile: "타격 이론과 편안한 소통을 함께 쓰는 감독", coachRecord: "주전 3명 개인 최고 기록 달성"),
        .init(id: "jeonju_hanok", name: "전주 한울스", need: .stamina, demand: 58, developmentPlan: "체력을 키워 선발 한 자리에 도전", positionCompetitor: "문시온", proCoach: "신도영", competitorProfile: "빠른 포심과 짧은 슬라이더로 삼진을 모으는 우완 선발", competitorRecord: "최근 시즌 178탈삼진 · ERA 2.71", coachProfile: "젊은 선수에게 먼저 기회를 주는 장기 육성형 감독", coachRecord: "신인 6명 1군 출전 명단 등록"),
        .init(id: "jeju_storm", name: "제주 스톰", need: .gamePlanning, demand: 63, developmentPlan: "기록을 활용해 선발과 구원을 오가는 투수로 훈련", positionCompetitor: "한유찬", proCoach: "조민규", competitorProfile: "묵직한 포심과 컷패스트볼로 긴 이닝을 버티는 우완 선발", competitorRecord: "최근 시즌 13승 · 147탈삼진", coachProfile: "큰 경기 경험을 바탕으로 한 번의 강한 승부를 강조하는 감독", coachRecord: "포스트시즌 진출 3회")
    ]

    private static let rivals: [RivalSnapshot] = [
        .init(id: "rival-seo", name: "서하준", archetype: "천재 교타형", contact: 47, discipline: 44, power: 39,
            personality: "배트가 공을 끝까지 따라갑니다. 같은 코스를 두 번 놓치지 않는 왼손 타자입니다.", signatureRecord: "봄 대회 타율 .421 · 31안타"),
        .init(id: "rival-lee", name: "권태오", archetype: "초구 거포형", contact: 42, discipline: 37, power: 49,
            personality: "느린 발을 감출 만큼 타구 판단이 빠릅니다. 초구 실투를 그냥 보내지 않습니다.", signatureRecord: "전국대회 7홈런 · 22타점"),
        .init(id: "rival-park", name: "남도현", archetype: "안타 제조형", contact: 46, discipline: 45, power: 37,
            personality: "파울로 버티며 투구 수를 늘리고 마지막에는 짧은 스윙으로 안타를 만듭니다.", signatureRecord: "11경기 연속 안타 · 출루율 .492"),
        .init(id: "rival-kang", name: "배시우", archetype: "외다리 장타형", contact: 39, discipline: 40, power: 50,
            personality: "높게 떠오른 공을 우측 담장으로 보내는 왼손 거포입니다. 실투 하나가 곧 실점입니다.", signatureRecord: "장타율 .711 · 8홈런"),
        .init(id: "rival-yoon", name: "류건우", archetype: "장신 호타준족형", contact: 44, discipline: 40, power: 43,
            personality: "큰 스윙 궤도와 빠른 발을 함께 씁니다. 변화구가 뜨면 주저 없이 당겨칩니다.", signatureRecord: "18경기 14도루 · 5홈런"),
        .init(id: "rival-choi", name: "정세현", archetype: "득점권 해결사형", contact: 44, discipline: 43, power: 48,
            personality: "늦은 카운트와 득점권에서 오히려 스윙이 짧아지는 해결사입니다.", signatureRecord: "득점권 타율 .438 · 끝내기 3회"),
        .init(id: "rival-home-run", name: "강이안", archetype: "몸쪽 사냥형", contact: 41, discipline: 44, power: 50,
            personality: "몸쪽 공도 피하지 않고 잡아당깁니다. 불리한 카운트에서도 장타를 버리지 않습니다.", signatureRecord: "봄·여름 대회 14홈런 · 장타율 .804"),
        .init(id: "rival-speed", name: "문재윤", archetype: "질주형 중심타자", contact: 47, discipline: 40, power: 46,
            personality: "타구가 뜨는 순간 2루를 노립니다. 실투 하나로 경기 흐름을 바꾸는 호타준족입니다.", signatureRecord: "20도루 · 6홈런 · 21득점")
    ]

    // MARK: - 고교 혹사·부상 시스템

    // 팔 상태 밴드 경계. HighSchoolCareerView.tsx의 armHealthState()와 반드시 같은 값을 쓴다.
    static let armCautionThreshold = 35
    static let armWarningThreshold = 55
    // 이 임계를 넘긴 채 "참고 던진다"를 고르면 결정론적으로 부상이 난다. 경고에서 한두 번 강행하면
    // 넘도록 (경고 + 강행 증가분) 언저리에 둔다.
    static let armInjuryThreshold = 72
    // 중요 경기 투구 수/피로가 바닥을 넘을 때만 팔에 부담이 쌓인다. 가벼운 등판(투구 ≤24·피로 ≤55)은
    // 위험을 0으로 두므로, 회복 훈련으로 피로만 관리하면 경고 없이 완주할 수 있다.
    static let armFatigueFloor = 55
    /// 실측 등판의 투구 수 분포에 맞춘 바닥.
    ///
    /// 24로 두면 한 이닝 등판(실측 평균 15구)이 거의 이 선을 넘지 못해, 팔 위험이 쌓이지
    /// 않고 트레이너·재활 콘텐츠가 통째로 사장됐다. 혹사 시스템은 만들어 두고 도달할 수
    /// 없으면 없는 것과 같다.
    static let armPitchFloor = 23
    static let armPushThroughRisk = 15   // "참고 던진다"가 올리는 위험
    static let armRestRelief = 45        // "짧은 휴식"이 덜어 내는 위험
    static let armExamRelief = 8         // "정밀 검진" 뒤 남는 최소 피로 회복

    static let armCareEventID = "evt-arm-care"

    // MARK: - 런 뼈대 시드 가변화 (Phase 4)

    /// 훈련이 부족한 회차의 훈련당 성장 신호에 더하는 보정 계수(결손 1당). 훈련 총량이 12–16으로
    /// 흔들려도 총 성장 기대가 유사 범위(±15%)에 머물도록 드래프트 밸런스를 보호한다. 40시드
    /// 지명률 밴드(25–65%)에 맞춰 실측·조정된 값이다.
    static let trainingCompensationPerDeficit = 24

    /// 스케줄이 없는(옛 저장본) 상태는 고정 뼈대로 읽어 진행 중 리듬을 그대로 유지한다.
    private func schedule(for state: HighSchoolCareerSnapshot) -> CareerScheduleSnapshot {
        state.schedule ?? .fixedDefault
    }

    /// 시드+회차(careerID에 함께 담김)에서 결정론적으로 회차 뼈대를 만든다. 스펙 범위:
    /// 훈련 12–16 / 관계 4–6 / 중요 경기 4–6 / 각성 3(고정). 각 챕터는 최소 1회 훈련을 받아
    /// 빈 챕터가 없고, 8챕터(드래프트 직전 챕터)는 각성→경기→드래프트 finale 구조를 유지한다.
    static func makeSchedule(careerID: String) -> CareerScheduleSnapshot {
        var generator = SplitMix64(seed: UInt64(StableHash.fnv1a64("run_skeleton|\(careerID)"), radix: 16) ?? 0x5348_4c53_4b45_4c00)
        let trainingTotal = 12 + generator.nextInt(upperBound: 5)      // 12–16
        // 4–6.
        //
        // 5–7로 늘려 확장 사건 26종의 노출률 병목(개당 4~5%)을 풀려 했지만 되돌렸다.
        // 관계 슬롯 수는 저장본 검증(`relationshipsCompleted` 범위)과 회차 뼈대 패킹,
        // 그리고 환생 사건 보장 슬롯 계산에 함께 걸려 있어서, 한 칸을 늘리자 그 셋이 동시에
        // 어긋났다. 노출률은 **확장 사건을 늘리는 쪽**으로 푸는 것이 맞다 — 슬롯을 늘리면
        // 회차가 길어지기만 하고 콘텐츠 절대량은 그대로다.
        let relationshipTotal = 4 + generator.nextInt(upperBound: 3)   // 4–6
        let gameTotal = 4 + generator.nextInt(upperBound: 3)           // 4–6

        // 훈련: 챕터마다 1회를 깔고(빈 챕터 없음) 남는 훈련을 챕터당 최대 3회까지 흩뿌린다.
        var trainings = [Int](repeating: 1, count: 8)
        var remaining = trainingTotal - 8
        while remaining > 0 {
            let candidates = (0..<8).filter { trainings[$0] < 3 }
            trainings[candidates[generator.nextInt(upperBound: candidates.count)]] += 1
            remaining -= 1
        }

        // 국면: 8챕터 finale는 각성1·경기1로 고정(드래프트는 엔진이 덧붙임). 나머지 관계 전부,
        // 경기 gameTotal-1, 각성 2를 챕터 1–7에 배치한다.
        //
        // 배치는 타입을 "한 바퀴에 하나씩" 뽑는 패스 방식으로 짜서 관계·경기·각성이 서로 엇갈리게
        // 한다(원래 고정 뼈대와 같은 리듬). 이렇게 하면 경기(≥3개)가 항상 앞쪽에 깔리고 네 번째
        // 관계 슬롯(팔 상태 씬의 방아쇠)이 그 뒤에 놓여, 혹사 시스템이 어느 시드에서도 성립한다.
        // 셔플 대신 타입 우선순위만 시드로 섞어(6가지) 회차별 변주를 준다.
        var queues: [(phase: HighSchoolCareerPhase, count: Int)] = [
            (.relationship, relationshipTotal), (.importantGame, gameTotal - 1), (.awakening, 2)
        ]
        for index in queues.indices.reversed() where index > 0 {
            queues.swapAt(index, generator.nextInt(upperBound: index + 1))
        }
        var sequence: [HighSchoolCareerPhase] = []
        while queues.contains(where: { $0.count > 0 }) {
            for index in queues.indices where queues[index].count > 0 {
                sequence.append(queues[index].phase)
                queues[index].count -= 1
            }
        }

        // 엮인 순서를 유지한 채 챕터 1–7에 최대한 고르게 나눠 담는다(챕터당 1–2국면). 어느 챕터가
        // 하나 더 받는지는 시드가 정한다.
        var milestones = [[HighSchoolCareerPhase]](repeating: [], count: 8)
        var counts = [Int](repeating: sequence.count / 7, count: 7)
        let extraOffset = generator.nextInt(upperBound: 7)
        for index in 0..<(sequence.count % 7) { counts[(extraOffset + index) % 7] += 1 }
        var cursor = 0
        for chapter in 0..<7 {
            for _ in 0..<counts[chapter] where cursor < sequence.count {
                milestones[chapter].append(sequence[cursor]); cursor += 1
            }
        }
        milestones[7] = [.awakening, .importantGame]
        return CareerScheduleSnapshot(trainingsByChapter: trainings, milestonesByChapter: milestones)
    }

    /// 경고 상태에서 다음 관계 국면을 대체하는 합성 health 이벤트. 세 응답이 그대로 세 선택지가 된다.
    private func armCareEvent() -> CareerEventContent {
        CareerEventContent(id: Self.armCareEventID, title: "팔 상태 경고", category: "health",
            summary: "최근 등판 뒤 팔이 평소보다 무겁습니다. 트레이너가 오늘 어떻게 할지 묻습니다.")
    }

    /// 누적 위험과 회복 상태로부터 결정론적 3단(+회복) 신호를 만든다.
    static func armHealthState(armRisk: Int?, injuryRecovery: Int?) -> ArmHealthState {
        if (injuryRecovery ?? 0) > 0 { return .recovering }
        let risk = armRisk ?? 0
        if risk >= armWarningThreshold { return .warning }
        if risk >= armCautionThreshold { return .caution }
        return .normal
    }

    private func armSignalNews(_ state: ArmHealthState, pitches: Int) -> String? {
        switch state {
        case .warning: return "무리한 투구가 이어집니다 · 투구 수 \(pitches). 다음 훈련 전에 팔 상태를 살펴야 합니다."
        case .caution: return "투구 수 \(pitches)로 팔에 피로가 쌓이기 시작했습니다. 회복 훈련을 고려하세요."
        case .normal, .recovering: return nil
        }
    }

    /// 관계 국면 이벤트를 고르되, 경고 상태이고 핵심 인물(감독·포수·라이벌) 슬롯이 지난 뒤라면
    /// 합성 팔 상태 이벤트로 대체한다. 핵심 3슬롯은 보존해 관계의 기본 서사를 깨지 않는다.
    private func relationshipEventForSlot(_ state: HighSchoolCareerSnapshot, seed: UInt64) -> CareerEventContent {
        if state.relationshipsCompleted >= Self.coreRelationshipCategories.count,
           Self.armHealthState(armRisk: state.armRisk, injuryRecovery: state.injuryRecovery) == .warning {
            return armCareEvent()
        }
        return relationshipEvent(for: state, seed: seed)
    }

    public init() {}

    public func start(_ params: StartHighSchoolCareerParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed)
        guard let preset = PitcherPresetCatalog.all.first(where: { $0.id == params.presetID }) else {
            throw SimulationError.invalidPitcherLab("unknown career pitcher preset")
        }
        let boosts = Set(params.soulBoosts ?? [])
        // 직전 회차가 기억 확장(슬롯 4)으로 골랐을 수 있으므로 계승은 4장까지 받는다.
        guard params.creationAllocation.total == 5, params.inheritedMemories.count <= 4,
              params.karmas.count == Set(params.karmas).count, params.karmas.count <= 2,
              !params.identity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !params.identity.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SimulationError.invalidPitcherLab("career creation or inherited memories are invalid")
        }
        let careerID = "career-\(params.seed)-life-\(params.lifeNumber)"
        // 재능을 계승보다 먼저 뽑는다. 계승이 이번 회차의 벽(재능 상한)을 넘지 않아야
        // "왜 안 오르지"의 답이 회차 시작부터 일관된다.
        var talent = TalentRules.make(careerID: careerID)
        // 재능 돌파 — 가장 낮은 등급 하나를 한 단계 위로. 벽을 없애지 않고 옮긴다.
        if boosts.contains(.talentBreak) {
            let abilities: [TalentAbility] = [.stuff, .command, .movement, .stamina]
            if let lowest = abilities.min(by: { talent.grade($0) < talent.grade($1) }),
               let index = TalentGrade.allCases.firstIndex(of: talent.grade(lowest)),
               index + 1 < TalentGrade.allCases.count {
                talent.setGrade(TalentGrade.allCases[index + 1], for: lowest)
            }
        }
        // 신규 회차는 v2 버킷을 명시해 저장한다. nil인 구저장본은 영구히 v1로 읽히므로
        // 콘텐츠가 늘어도 진행 중 회차의 바람과 결과는 움직이지 않는다.
        let worldRulesVersion = CareerRulesVersion.v2
        let wind = CareerWind.wind(careerID: careerID, rulesVersion: worldRulesVersion)
        var pitcher = renamed(params.identity.name, pitcher: applyCreation(params.creationAllocation, to: preset.pitcher), hand: params.identity.throwingHand)
        pitcher = applyInheritance(max(params.inheritedSoulTotal ?? params.inheritedSoulPoints, params.inheritedSoulPoints), domain: params.inheritedSoulDomain, memories: params.inheritedMemories, talent: &talent,
            rulesVersion: SoulInheritanceRulesVersion.resolve(storedValue: params.inheritanceRulesVersion),
            bonusPoints: boosts.contains(.headStart) ? 5 : 0, to: pitcher)
        pitcher = applyKarmas(params.karmas, to: pitcher)
        pitcher = CareerSignatureLegacy.apply(params.signatureLegacyID, to: pitcher)
        let rewardPermille = 1_000 + params.karmas.reduce(0) { $0 + $1.rewardPermille } + wind.rewardBonusPermille
        let memorySlots = (params.karmas.contains(.erasedMemory) ? 2 : 3) + (boosts.contains(.extraMemory) ? 1 : 0)
        let base = HighSchoolCareerSnapshot(
            careerID: careerID, revision: 0, lifeNumber: params.lifeNumber,
            phase: .prologue, identity: params.identity, difficulty: params.difficulty, karmas: params.karmas,
            legacyRewardPermille: rewardPermille, memorySlots: memorySlots,
            pitcher: pitcher, schoolOptions: Self.schools(for: params.identity.region), school: nil,
            rival: rival(seed: seed, difficulty: params.difficulty.simulationDifficulty, karmas: params.karmas, windBonus: wind.rivalBonus), chapter: Self.chapters[0], chapterTrainingCount: 0,
            totalTrainingsCompleted: 0, milestoneIndex: 0, relationshipsCompleted: 0,
            relationshipTrust: 50, managerTrust: 50, catcherTrust: 50, rivalTrust: 50,
            selectedAwakenings: [], awakeningOptions: [], fatigue: 5,
            performance: CareerPerformanceSnapshot(), currentGameScenario: nil, currentRelationshipEvent: nil, lastTraining: nil,
            news: (wind.newsLine.map { [$0] } ?? []) + Self.prologueNews(identity: params.identity, lifeNumber: params.lifeNumber, inheritedMemoryCount: params.inheritedMemories.count),
            fanInterest: wind.startingFanInterest,
            draftResult: nil, legacyOptions: [], selectedMemories: [], balanceVersion: PitcherPresetCatalog.balanceVersion,
            worldRulesVersion: worldRulesVersion.rawValue,
            armRisk: 0, injuryRecovery: 0, schedule: Self.makeSchedule(careerID: careerID),
            talent: talent,
            soulBoosts: boosts.isEmpty ? nil : boosts.map(\.rawValue).sorted(),
            stateCommitment: ""
        )
        return result(seed: seed, state: signed(base), event: "high_school_career_started")
    }

    /// 받는 쪽 환생: 첫 삶은 기존 문구를 그대로 쓰고, 두 번째 삶부터는 세계가 회차를 알은체한다.
    /// 세계관 규칙상 명확한 환생 기억이 아니라 "설명하기 어려운 감각"으로만 표현한다.
    static func prologueNews(identity: PlayerIdentitySnapshot, lifeNumber: Int, inheritedMemoryCount: Int) -> [String] {
        guard lifeNumber >= 2 else {
            return ["\(identity.region) 중학교 마지막 대회에서 보여준 공이 같은 지역 네 고교의 관심을 끌었습니다."]
        }
        let openers = [
            "\(identity.region) 중학교 마지막 대회. 처음 서는 마운드인데 흙의 감촉이 낯설지 않았습니다. 같은 지역 네 고교가 다시 지켜보고 있습니다.",
            "\(identity.region) 중학교 마지막 대회에서 던진 마지막 공. 포수 미트에 꽂히는 소리가 어딘가 익숙했습니다. 네 고교의 시선이 모입니다.",
            "\(identity.region) 중학교 마지막 대회를 마친 뒤, 어깨보다 먼저 마음이 다음 이닝을 준비하고 있었습니다. 네 고교에서 제안이 도착했습니다."
        ]
        var news = [openers[(lifeNumber - 2) % openers.count]]
        if inheritedMemoryCount > 0 {
            news.append("처음 잡는 그립인데 손끝이 먼저 기억합니다 · 설명하기 어려운 감각 \(inheritedMemoryCount)가지")
        }
        return news
    }

    public func completePrologue(_ params: AdvanceCareerChapterParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .prologue)
        let identity = params.state.identity
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .schoolSelection,
            news: ["고교 진학 제안 도착 · \(identity.name) · \(identity.region) 4개 학교"] + params.state.news)
        return result(seed: seed, state: signed(next), event: "middle_school_prologue_completed")
    }

    public func normalizeRegionalSchools(_ params: AdvanceCareerChapterParams) throws -> HighSchoolCareerResult {
        _ = try validatedSeed(params.seed)
        try validateState(params.state)
        let sourceBalanceVersion = params.state.balanceVersion ?? 1
        // 플랫폼 load-time 정규화는 콘텐츠만 backfill한다. 출시된 v3 진행 저장을 v4
        // 밸런스로 암묵 승격하면 Windows/iOS의 같은 저장이 다른 결과를 내므로, v1/v2만
        // 기존 출시 목표였던 v3까지 옮기고 v3 이상은 그대로 둔다.
        let normalizationTargetVersion = 3
        let needsBalanceMigration = sourceBalanceVersion < normalizationTargetVersion
        let options = Self.schools(for: params.state.identity.region)
        let selectedSchool = params.state.school.flatMap { current in
            options.first(where: { $0.id == current.id })
        }
        let normalizedRival = Self.rivals.first(where: { $0.id == params.state.rival.id }).map { profile in
            let difficultyBonus = params.state.difficulty.simulationDifficulty == .relaxed ? -3
                : params.state.difficulty.simulationDifficulty == .challenging ? 4 : 0
            let generationBonus = params.state.karmas.contains(.geniusGeneration) ? 4 : 0
            let bonus = difficultyBonus + generationBonus
            return RivalSnapshot(id: profile.id, name: profile.name, archetype: profile.archetype,
                contact: needsBalanceMigration ? clamp(profile.contact + bonus, 20, 80) : params.state.rival.contact,
                discipline: needsBalanceMigration ? clamp(profile.discipline + bonus, 20, 80) : params.state.rival.discipline,
                power: needsBalanceMigration ? clamp(profile.power + bonus, 20, 80) : params.state.rival.power,
                personality: profile.personality, signatureRecord: profile.signatureRecord)
        } ?? params.state.rival
        let normalizedDraft = params.state.draftResult.map { draft in
            let team = draft.team.flatMap { current in Self.teams.first(where: { $0.id == current.id }) } ?? draft.team
            return DraftResultSnapshot(outcome: draft.outcome, evaluationScore: draft.evaluationScore,
                projectedRange: draft.projectedRange, team: team, round: draft.round, overallPick: draft.overallPick,
                signingBonus: draft.signingBonus, firstSeasonGoal: draft.firstSeasonGoal, summary: draft.summary)
        }
        let normalizedNews = params.state.news.map { item in
            if item == "고교 진학 제안 도착 · \(params.state.identity.name) · 4개 학교" {
                return "고교 진학 제안 도착 · \(params.state.identity.name) · \(params.state.identity.region) 4개 학교"
            }
            if item == "중학교 마지막 대회에서 보여준 공이 네 학교의 관심을 끌었습니다." {
                return "\(params.state.identity.region) 중학교 마지막 대회에서 보여준 공이 같은 지역 네 고교의 관심을 끌었습니다."
            }
            return item
        }
        let managerTrust = params.state.managerTrust ?? params.state.relationshipTrust
        let catcherTrust = params.state.catcherTrust ?? params.state.relationshipTrust
        let rivalTrust = params.state.rivalTrust ?? params.state.relationshipTrust
        let balanceMigration = PitcherPresetCatalog.migrate(
            params.state.pitcher,
            fromVersion: sourceBalanceVersion,
            targetVersion: normalizationTargetVersion
        )
        let migratedPitcher = balanceMigration?.pitcher ?? params.state.pitcher
        let migratedTraining = balanceMigration.flatMap { migrate(params.state.lastTraining, ratingOffsets: $0.ratingOffsets) }
            ?? params.state.lastTraining
        let migratedRelationship = balanceMigration.flatMap { migrate(params.state.lastRelationship, ratingOffsets: $0.ratingOffsets) }
            ?? params.state.lastRelationship
        let normalized = signed(replacing(params.state, pitcher: migratedPitcher,
            schoolOptions: options, school: selectedSchool,
            rival: normalizedRival, relationshipTrust: (managerTrust + catcherTrust + rivalTrust) / 3,
            managerTrust: managerTrust, catcherTrust: catcherTrust, rivalTrust: rivalTrust,
            lastTraining: migratedTraining, lastRelationship: migratedRelationship,
            news: normalizedNews, draftResult: normalizedDraft,
            balanceVersion: max(sourceBalanceVersion, normalizationTargetVersion)))
        let eventHash = StableHash.fnv1a64("\(normalized.careerID)|\(normalized.revision)|regional_schools_normalized|\(normalized.stateCommitment)")
        return HighSchoolCareerResult(revision: normalized.revision, nextSeed: params.seed, events: [], snapshot: normalized, eventHash: eventHash)
    }

    public func chooseSchool(_ params: ChooseSchoolParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .schoolSelection)
        let regionalSchools = Self.schools(for: params.state.identity.region)
        guard let school = regionalSchools.first(where: { $0.id == params.schoolID }) else {
            throw SimulationError.invalidPitcherLab("school is not available")
        }
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .training, schoolOptions: regionalSchools, school: school,
            news: ["\(school.name) 입학이 확정됐습니다. \(school.coachName) 감독은 첫 훈련부터 ‘\(school.philosophy)’을 강조했습니다."] + params.state.news)
        return result(seed: seed, state: signed(next), event: "school_selected", reasons: ["school.\(school.id.rawValue)"])
    }

    /// 훈련 판정의 결정론 부분. 무작위 폭(±45)을 제외한 신호 합.
    ///
    /// `commitTraining`과 `trainingOutlook`이 같은 식을 써야 한다 — 화면이 판정식을
    /// 흉내 내다 어긋나면 전망이 거짓말이 된다.
    private static func trainingSignalBase(
        state: HighSchoolCareerSnapshot, focus: TrainingFocus, intensity: TrainingIntensity,
        schedule: CareerScheduleSnapshot, opportunityHit: Bool
    ) -> Int {
        let base = intensity == .light ? 130 : intensity == .standard ? 210 : 280
        let schoolBonus = state.school?.strength == focus ? 110 : 0
        let fatiguePenalty = max(0, state.fatigue - 45) * 3
        // 훈련 수가 적은 회차 보정: 결손(16 - 총 훈련)에 비례해 성장 신호를 올려 총 성장 기대를
        // 16회 기준 근처(±15%)에 붙인다. 드래프트 밸런스를 스케줄 가변화로부터 보호한다.
        let scheduleCompensation = max(0, 16 - schedule.trainingTotal) * trainingCompensationPerDeficit
        return base + schoolBonus + (opportunityHit ? 90 : 0) - fatiguePenalty + scheduleCompensation
    }

    private static func trainingGrowth(signal: Int) -> Int {
        signal >= 430 ? 2 : signal >= 260 ? 1 : 0
    }

    /// 훈련 한 번의 성장 전망. 화면이 코어에 물어본다.
    ///
    /// 훈련의 진짜 결정 — "학교 특기와 오늘의 기회가 겹치는 턴에 강도를 몰아붙인다" — 이
    /// 화면에 전혀 드러나지 않아서, 최적 행동이 "기회 배지를 따라 누르기"로 납작해졌다.
    /// 무작위 폭은 그대로 두고 구간만 말한다. 정확한 결과를 약속하지 않는다.
    public enum TrainingGrowthOutlook: String, Codable, Sendable {
        /// 재능 벽에 막혀 수치는 오르지 않는다. 대신 만개 게이지가 쌓인다.
        case wall
        case none
        case zeroOrOne
        case one
        case oneOrTwo
        case two
    }

    public func trainingOutlook(
        state: HighSchoolCareerSnapshot, focus: TrainingFocus, intensity: TrainingIntensity
    ) -> TrainingGrowthOutlook {
        if (state.injuryRecovery ?? 0) > 0 { return .none }
        let talent = state.talent ?? .unlimited
        let ability = TalentAbility.from(focus)
        if rating(for: focus, pitcher: state.pitcher) >= min(80, talent.ceiling(ability)) { return .wall }
        let deterministic = Self.trainingSignalBase(
            state: state, focus: focus, intensity: intensity,
            schedule: schedule(for: state),
            opportunityHit: state.trainingOpportunity?.focus == focus
        )
        let windGrowth = state.careerWind.rules.trainingGrowthBonus(for: focus)
        let lowest = Self.trainingGrowth(signal: max(60, deterministic - 45)) + windGrowth
        let highest = Self.trainingGrowth(signal: max(60, deterministic + 45)) + windGrowth
        if lowest >= 2 { return .two }
        if lowest == 1, highest >= 2 { return .oneOrTwo }
        switch (lowest, highest) {
        case (1, 1): return .one
        case (0, 0): return .none
        default: return .zeroOrOne
        }
    }

    public func commitTraining(_ params: CommitCareerTrainingParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .training)
        let schedule = schedule(for: params.state)
        let chapterTrainings = schedule.trainingsByChapter[params.state.chapter.number - 1]
        guard params.state.school != nil, params.state.chapterTrainingCount < chapterTrainings,
              params.state.totalTrainingsCompleted < schedule.trainingTotal else {
            throw SimulationError.invalidPitcherLab("career training is out of order")
        }
        let number = params.state.totalTrainingsCompleted + 1
        // 부상 회복 강제: 남은 재활 횟수가 있으면 무엇을 골랐든 회복 훈련으로 소비된다(성장 없음).
        let injuryRecovery = params.state.injuryRecovery ?? 0
        let isRehab = injuryRecovery > 0
        let effectiveFocus: TrainingFocus = isRehab ? .recovery : params.focus
        let windRules = params.state.careerWind.rules
        var generator = SplitMix64(seed: seed ^ UInt64(number) ^ 0x4341_5245_4552)
        let opportunityHit = !isRehab && params.focus == params.state.trainingOpportunity?.focus
        let deterministicSignal = Self.trainingSignalBase(
            state: params.state, focus: params.focus, intensity: params.intensity,
            schedule: schedule, opportunityHit: opportunityHit
        )
        let signal = max(60, deterministicSignal + generator.nextInt(upperBound: 91) - 45)
        // 대성공(잭팟) — 16% 확률로 성장이 두 배가 된다. 가변 보상은 훈련 버튼을
        // 누르는 손에 긴장을 만든다: 이번엔 터질까. 재능 벽은 TalentRules.apply가
        // 뒤에서 그대로 자르므로 잭팟도 벽을 넘지 못하고, 초과분은 만개 게이지로 쌓인다.
        let jackpotChance = params.state.soulBoosts?.contains(SoulBoostID.trainingRhythm.rawValue) == true ? 26 : 16
        let jackpot = !isRehab && effectiveFocus != .recovery && generator.nextInt(upperBound: 100) < jackpotChance
        // 회복은 회복만 한다. 예전에는 회복 훈련도 스태미나가 +1~2씩 올라서
        // '강한 회복'이 피로 -3에 무료 성장이었다 — 강도 선택의 긴장이 0이 되는 지점.
        let baseGrowth = (isRehab || effectiveFocus == .recovery) ? 0 : Self.trainingGrowth(signal: signal)
        let windGrowth = isRehab ? 0 : windRules.trainingGrowthBonus(for: effectiveFocus)
        // 바람의 +1은 잭팟에 곱해지지 않는다. 표시에 적힌 고정 보너스와 실제 값이 같다.
        let rawGrowth = (jackpot ? baseGrowth * 2 : baseGrowth) + windGrowth
        // 재능이 성장을 자른다. 한계에 막힌 훈련은 헛되지 않고 만개 게이지로 쌓인다 —
        // 막혔다는 이유로 훈련이 낭비가 되면 재능은 그냥 벌점이 된다.
        let ability = TalentAbility.from(params.focus)
        let talentBefore = params.state.talent ?? .unlimited
        let (growthSignal, talentAfter, bloomed) = rawGrowth > 0
            ? TalentRules.apply(
                talent: talentBefore,
                ability: ability,
                current: rating(for: params.focus, pitcher: params.state.pitcher),
                points: rawGrowth
            )
            : (0, talentBefore, nil)
        let pitcher = grow(
            params.state.pitcher, focus: params.focus, points: growthSignal,
            balanceVersion: params.state.balanceVersion
        )
        let baseFatigueCost = params.intensity == .light ? 3 : params.intensity == .standard ? 8 : 15
        let fatigueCost = baseFatigueCost + windRules.trainingFatigueModifier(for: effectiveFocus)
        let recovery = params.focus == .recovery ? windRules.adjustedRecovery(18) : 0
        // 재활은 훈련 강도와 무관하게 피로를 크게 덜고, 남은 위험도 조금씩 씻어 낸다.
        let fatigue = isRehab
            ? clamp(
                params.state.fatigue + windRules.trainingFatigueModifier(for: .recovery)
                    - windRules.adjustedRecovery(24),
                0, 100
            )
            : clamp(params.state.fatigue + fatigueCost - recovery, 0, 100)
        let nextInjuryRecovery = isRehab ? injuryRecovery - 1 : injuryRecovery
        let nextArmRisk = isRehab ? max(0, (params.state.armRisk ?? 0) - 10) : (params.state.armRisk ?? 0)
        let metricBefore = rating(for: effectiveFocus, pitcher: params.state.pitcher)
        let metricAfter = rating(for: effectiveFocus, pitcher: pitcher)
        let growth = metricAfter - metricBefore
        let bloomedGrade = bloomed.map { talentAfter.grade($0) }
        let feedback = isRehab
            ? "재활 훈련으로 팔 상태를 회복합니다. 이번 훈련은 성장 없이 지나갑니다.\(nextInjuryRecovery > 0 ? " 남은 회복 \(nextInjuryRecovery)회." : " 다음 훈련부터 정상으로 돌아옵니다.")"
            : bloomed.flatMap { ability in bloomedGrade.map { TalentRules.bloomHeadline(ability: ability, to: $0) } }
                ?? blockedFeedback(
                    ability: ability, talent: talentAfter, growth: growth,
                    rawGrowth: rawGrowth, allowed: growthSignal,
                    fatigueChange: fatigue - params.state.fatigue, focus: params.focus
                )
        let training = CareerTrainingSnapshot(number: number, focus: effectiveFocus, intensity: params.intensity,
            growth: growth, fatigueChange: fatigue - params.state.fatigue,
            feedback: jackpot && baseGrowth > 0 && growth > 0 ? "대성공! 오늘은 몸이 완전히 열렸습니다. \(feedback)" : feedback,
            metricBefore: metricBefore, metricAfter: metricAfter,
            fatigueBefore: params.state.fatigue, fatigueAfter: fatigue,
            opportunityHit: opportunityHit,
            bloomedAbility: bloomed, bloomedGrade: bloomedGrade,
            jackpot: jackpot && baseGrowth > 0 && growth > 0)
        let chapterCount = params.state.chapterTrainingCount + 1
        let phase: HighSchoolCareerPhase = chapterCount == chapterTrainings ? milestone(for: params.state.chapter.number, index: 0, schedule: schedule) : .training
        let optionState = replacing(params.state, pitcher: pitcher, fatigue: fatigue, lastTraining: training,
            awakeningSparks: bloomed != nil ? min(6, (params.state.awakeningSparks ?? 0) + 1) : params.state.awakeningSparks)
        let options = phase == .awakening ? awakeningOptions(state: optionState, seed: seed) : []
        let scenario = phase == .importantGame ? gameScenario(for: params.state, seed: seed) : nil
        // 경고 상태가 이어지면 다음 관계 국면을 팔 상태 선택으로 대체한다(핵심 3슬롯은 보존).
        let armSignalAfter = Self.armHealthState(armRisk: nextArmRisk, injuryRecovery: nextInjuryRecovery)
        let relationshipEvent: CareerEventContent? = phase == .relationship
            ? (params.state.relationshipsCompleted >= Self.coreRelationshipCategories.count && armSignalAfter == .warning
                ? armCareEvent()
                : relationshipEvent(for: params.state, seed: seed))
            : nil
        let bloomNews = bloomed.flatMap { ability in
            bloomedGrade.map { ["\(ability.label) 재능이 만개했습니다 — \($0.label)"] }
        }
        let next = replacing(params.state, revision: params.state.revision + 1, phase: phase, pitcher: pitcher,
            chapterTrainingCount: chapterCount, totalTrainingsCompleted: number, awakeningOptions: options,
            fatigue: fatigue, performance: params.state.performance, lastTraining: training, currentGameScenario: scenario,
            currentRelationshipEvent: relationshipEvent,
            news: isRehab
                ? ["\(number)번째 재활 훈련 · 팔 상태를 회복합니다."] + params.state.news
                : bloomNews.map { $0 + params.state.news },
            armRisk: nextArmRisk, injuryRecovery: nextInjuryRecovery,
            talent: talentAfter,
            // 재능 만개도 각성의 전조다 — 훈련장에서 몸이 먼저 깨어난다.
            awakeningSparks: bloomed != nil ? min(6, (params.state.awakeningSparks ?? 0) + 1) : params.state.awakeningSparks)
        return result(seed: seed, state: signed(next),
            event: isRehab ? "career_training_rehab" : "career_training_completed",
            reasons: ["training.\(effectiveFocus.rawValue)"])
    }

    public func resolveRelationship(_ params: ResolveCareerRelationshipParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .relationship)
        // 팔 상태 경고 이벤트는 관계 국면을 빌려 세 선택지(참고 던진다·짧은 휴식·정밀 검진)로 나온다.
        if params.state.currentRelationshipEvent?.id == Self.armCareEventID {
            return resolveArmCare(seed: seed, state: params.state, response: params.response)
        }
        let impact = relationshipImpact(state: params.state, response: params.response)
        let eventCategory = params.state.currentRelationshipEvent?.category ?? "coach"
        let relationshipTarget = Self.relationshipTarget(forEventCategory: eventCategory)
        let relationshipCategory = relationshipTarget.rawValue
        let isCoach = relationshipTarget == .coach
        // 고집불통 감독: 신뢰를 잃을 땐 두 배로 잃고, 얻을 땐 절반만 얻는다.
        // 예전에는 잃는 쪽만 두 배라 '도전'만 안 고르면 완전 무료 +15%였다.
        let karmaAdjustedTrustChange = params.state.karmas.contains(.stubbornCoach) && isCoach
            ? (impact.trust < 0 ? impact.trust * 2 : impact.trust / 2)
            : impact.trust
        let windRules = params.state.careerWind.rules
        let trustChange = windRules.adjustedRelationshipTrustChange(
            karmaAdjustedTrustChange, target: relationshipTarget
        )
        // 대화로 얻는 성장도 재능의 한계를 넘지 않는다. 여기만 뚫리면 훈련으로 막힌 능력을
        // 대화로 올리는 우회로가 생기고, 재능이라는 규칙이 그 자리에서 무의미해진다.
        let talentBefore = params.state.talent ?? .unlimited
        var talentAfter = talentBefore
        var relationshipBloom: TalentAbility?
        let pitcher: PitcherSnapshot
        if let focus = impact.growthFocus {
            let ability = TalentAbility.from(focus)
            let (allowed, updated, bloomed) = TalentRules.apply(
                talent: talentBefore, ability: ability,
                current: rating(for: focus, pitcher: params.state.pitcher), points: 1
            )
            talentAfter = updated
            relationshipBloom = bloomed
            pitcher = grow(
                params.state.pitcher, focus: focus, points: allowed,
                balanceVersion: params.state.balanceVersion
            )
        } else {
            pitcher = params.state.pitcher
        }
        let managerBefore = params.state.managerTrust ?? params.state.relationshipTrust
        let catcherBefore = params.state.catcherTrust ?? params.state.relationshipTrust
        let rivalBefore = params.state.rivalTrust ?? params.state.relationshipTrust
        let managerAfter = relationshipCategory == "coach" ? clamp(managerBefore + trustChange, 0, 100) : managerBefore
        let catcherAfter = relationshipCategory == "catcher" ? clamp(catcherBefore + trustChange, 0, 100) : catcherBefore
        let rivalAfter = relationshipCategory == "rival" ? clamp(rivalBefore + trustChange, 0, 100) : rivalBefore
        let fatigueAfter = clamp(params.state.fatigue + impact.fatigue, 0, 100)
        let fanInterestAfter = clamp(
            params.state.fanInterest + windRules.adjustedFanInterestChange(impact.fanInterest), 0, 100
        )
        let growthBefore = impact.growthFocus.map { rating(for: $0, pitcher: params.state.pitcher) }
        let growthAfter = impact.growthFocus.map { rating(for: $0, pitcher: pitcher) }
        let relationshipHeadline = relationshipNews(state: params.state, response: params.response, seed: seed, impact: impact)
        let relationshipResult = CareerRelationshipResultSnapshot(
            number: params.state.relationshipsCompleted + 1,
            category: relationshipCategory,
            title: params.state.currentRelationshipEvent?.title ?? "대화",
            response: params.response,
            trustBefore: relationshipCategory == "coach" ? managerBefore : relationshipCategory == "catcher" ? catcherBefore : rivalBefore,
            trustAfter: relationshipCategory == "coach" ? managerAfter : relationshipCategory == "catcher" ? catcherAfter : rivalAfter,
            fatigueBefore: params.state.fatigue,
            fatigueAfter: fatigueAfter,
            fanInterestBefore: params.state.fanInterest,
            fanInterestAfter: fanInterestAfter,
            growthFocus: impact.growthFocus,
            abilityBefore: growthBefore,
            abilityAfter: growthAfter,
            feedback: impact.outcome
        )
        let nextBase = replacing(params.state, revision: params.state.revision + 1,
            pitcher: pitcher,
            relationshipsCompleted: params.state.relationshipsCompleted + 1,
            relationshipTrust: (managerAfter + catcherAfter + rivalAfter) / 3,
            managerTrust: managerAfter, catcherTrust: catcherAfter, rivalTrust: rivalAfter,
            fatigue: fatigueAfter, lastRelationship: relationshipResult,
            news: relationshipBloom.map {
                ["\($0.label) 재능이 만개했습니다 — \(talentAfter.grade($0).label)", relationshipHeadline] + params.state.news
            } ?? ([relationshipHeadline] + params.state.news),
            fanInterest: fanInterestAfter,
            talent: talentAfter)
        let next = advanceMilestone(nextBase, seed: seed)
        return result(seed: seed, state: signed(next), event: "career_relationship_resolved", reasons: ["relationship.\(params.response.rawValue)"])
    }

    /// 팔 상태 경고에서의 세 선택을 처리한다. 관계 슬롯을 한 칸 소비하되(핵심 인물 슬롯은 이미 지난 뒤),
    /// 건강 채널(→ 감독)의 신뢰만 소폭 움직이고 실제 효과는 위험·피로·부상으로 나타난다.
    private func resolveArmCare(seed: UInt64, state: HighSchoolCareerSnapshot, response: RelationshipResponse) -> HighSchoolCareerResult {
        let priorRisk = state.armRisk ?? 0
        var nextRisk = priorRisk
        var nextInjuryRecovery = state.injuryRecovery ?? 0
        var fatigueDelta = 0
        var trustDelta = 0
        var fanDelta = 0
        var injured = false
        var outcome = ""
        var headline = ""
        switch response {
        case .challenge: // 참고 던진다: 능력 유지, 위험 상승, 임계를 넘으면 결정론적 부상
            nextRisk = clamp(priorRisk + Self.armPushThroughRisk, 0, 100)
            trustDelta = -2; fanDelta = 1
            if nextRisk >= Self.armInjuryThreshold {
                injured = true
                let severity = nextRisk >= 92 ? 2 : 1
                nextInjuryRecovery = severity
                nextRisk = 50 // 부상 뒤에도 마모는 남는다
                fatigueDelta = 6
                if state.karmas.contains(.noLastChance) {
                    // '마지막 기회는 없다' — 문구가 약속한 그대로. 부상 하나가 시즌을 끝내고
                    // 지금까지의 성적으로 드래프트 평가를 받는다. 이것이 이 카르마의 값이다.
                    outcome = "팔이 버티지 못했습니다. 시즌이 여기서 끝났고, 지금까지의 기록으로 평가받습니다."
                    headline = "시즌 아웃 · \(state.pitcher.name), 부상으로 조기 드래프트 평가에 들어갑니다."
                } else {
                    outcome = "무리한 등판이 겹쳐 팔에 이상이 왔습니다. 다음 훈련 \(severity)회는 재활로 씁니다."
                    headline = "팔 부상 · \(state.pitcher.name), 무리한 등판이 반복돼 재활에 들어갑니다."
                }
            } else {
                fatigueDelta = 4
                outcome = "오늘도 예정대로 던졌습니다. 능력은 지켰지만 팔의 위험이 더 커졌습니다."
                headline = "\(state.pitcher.name), 경고에도 등판을 강행했습니다 · 팔 위험 누적."
            }
        case .listen: // 짧은 휴식: 성장 없이 팔을 쉬게 해 피로와 위험을 크게 던다
            nextRisk = max(0, priorRisk - Self.armRestRelief)
            fatigueDelta = -30; trustDelta = 2
            outcome = "이번 등판은 건너뛰고 팔을 쉬게 했습니다. 피로와 위험이 크게 줄었습니다."
            headline = "\(state.pitcher.name), 짧은 휴식으로 팔을 아꼈습니다 · 회복 우선."
        case .explain: // 정밀 검진: 상태를 정확히 공개하고 위험을 제거한다
            nextRisk = 0
            fatigueDelta = -Self.armExamRelief; trustDelta = 1
            outcome = "정밀 검진 결과 큰 손상은 없었습니다. 검진 전 위험 수치는 \(priorRisk), 관리 계획을 새로 세웠습니다."
            headline = "\(state.pitcher.name), 정밀 검진으로 팔 상태를 확인했습니다 · 위험 관리 시작."
        }
        let managerBefore = state.managerTrust ?? state.relationshipTrust
        let catcherBefore = state.catcherTrust ?? state.relationshipTrust
        let rivalBefore = state.rivalTrust ?? state.relationshipTrust
        let windRules = state.careerWind.rules
        let adjustedTrustDelta = windRules.adjustedRelationshipTrustChange(trustDelta, target: .coach)
        let adjustedFanDelta = windRules.adjustedFanInterestChange(fanDelta)
        let managerAfter = clamp(managerBefore + adjustedTrustDelta, 0, 100) // health 채널 → 감독 믿음
        let fatigueAfter = clamp(state.fatigue + fatigueDelta, 0, 100)
        let fanAfter = clamp(state.fanInterest + adjustedFanDelta, 0, 100)
        let relationshipResult = CareerRelationshipResultSnapshot(
            number: state.relationshipsCompleted + 1, category: "coach",
            title: state.currentRelationshipEvent?.title ?? "팔 상태 경고", response: response,
            trustBefore: managerBefore, trustAfter: managerAfter,
            fatigueBefore: state.fatigue, fatigueAfter: fatigueAfter,
            fanInterestBefore: state.fanInterest, fanInterestAfter: fanAfter,
            growthFocus: nil, abilityBefore: nil, abilityAfter: nil, feedback: outcome)
        let nextBase = replacing(state, revision: state.revision + 1,
            relationshipsCompleted: state.relationshipsCompleted + 1,
            relationshipTrust: (managerAfter + catcherBefore + rivalBefore) / 3,
            managerTrust: managerAfter, catcherTrust: catcherBefore, rivalTrust: rivalBefore,
            fatigue: fatigueAfter, lastRelationship: relationshipResult,
            news: [headline] + state.news, fanInterest: fanAfter,
            armRisk: nextRisk, injuryRecovery: nextInjuryRecovery)
        // noLastChance 부상은 남은 3년을 지운다 — 커리어가 드래프트 평가로 직행한다.
        if injured, state.karmas.contains(.noLastChance) {
            let ended = replacing(nextBase, phase: .draft, awakeningOptions: [])
            return result(seed: seed, state: signed(ended),
                event: "career_arm_injury_season_ending",
                reasons: ["arm_care.\(response.rawValue)", "karma.no_last_chance"])
        }
        let next = advanceMilestone(nextBase, seed: seed)
        return result(seed: seed, state: signed(next),
            event: injured ? "career_arm_injury" : "career_arm_care",
            reasons: ["arm_care.\(response.rawValue)"])
    }

    public func recordImportantGame(_ params: RecordCareerGameParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .importantGame)
        let expected = params.state.performance.importantGamesCompleted + 1
        guard params.report.scenarioNumber == expected, params.report.pitches > 0, params.report.recommendationAccepted <= params.report.pitches else {
            throw SimulationError.invalidPitcherLab("career important game report is invalid")
        }
        let gameGrowth = CareerGameGrowth.evaluating(state: params.state, report: params.report)
        let performance = params.state.performance.adding(params.report)
        let baseInterestGain = max(2, params.report.strikeouts * 2 - params.report.runsAllowed * 2)
        let interest = clamp(
            params.state.fanInterest + params.state.careerWind.rules.adjustedFanInterestChange(baseInterestGain),
            0, 100
        )
        let headline = params.report.runsAllowed == 0
            ? "\(params.state.pitcher.name), \(params.state.rival.name)과의 승부에서 무실점"
            : "\(params.state.pitcher.name), \(params.report.strikeouts)탈삼진 · \(params.report.walks)볼넷 · \(params.report.runsAllowed)실점"
        let callback = relationshipCallback(state: params.state, report: params.report)
        // Deterministic arm signal: overwork is driven by this outing's pitch count, with pre-game
        // fatigue amplifying it. A normal-length outing (pitches at/under the floor) adds no risk
        // no matter how tired — so ordinary play never drifts toward injury; only heavy pitch loads do.
        let priorRisk = params.state.armRisk ?? 0
        let pitchStress = max(0, params.report.pitches - Self.armPitchFloor)
        let fatigueStress = max(0, params.state.fatigue - Self.armFatigueFloor)
        let nextRisk = clamp(priorRisk + (pitchStress > 0 ? pitchStress + fatigueStress : 0), 0, 100)
        let priorSignal = Self.armHealthState(armRisk: priorRisk, injuryRecovery: params.state.injuryRecovery)
        let nextSignal = Self.armHealthState(armRisk: nextRisk, injuryRecovery: params.state.injuryRecovery)
        let armNews = (nextSignal != priorSignal ? armSignalNews(nextSignal, pitches: params.report.pitches) : nil)

        // 각성의 전조 — 호투가 몸을 깨운다. 무실점이나 삼진쇼는 +2, 판정(과정)이 좋았으면 +1.
        // 각성이 일정표의 선물이 아니라 시즌의 증명이 부르는 순간이 되게 하는 적립이다.
        let sparkGain = (params.report.runsAllowed == 0 || params.report.strikeouts >= 4 ? 2 : 0)
            + (params.report.actualDamage <= params.report.expectedDamage ? 1 : 0)
        let gameGrowthBloom = gameGrowth?.bloomedAbility == nil ? 0 : 1
        let sparks = min(6, (params.state.awakeningSparks ?? 0) + sparkGain + gameGrowthBloom)
        let sparkNews: String? = sparkGain >= 2 ? "등판을 마친 손끝이 낯설게 뜨겁다 — 각성의 전조."
            : sparkGain == 1 ? "공 하나하나가 손에 남는다 — 희미한 전조." : nil

        // 수싸움 적중은 이미 끝난 커널 결과 위의 과정 보상이다. 승부 확률에는 손대지 않고,
        // 감독·포수 믿음에 경기당 최대 3점만 남긴다. Wave 3 이전 리포트(nil)는 아래
        // 옵셔널 값을 전부 nil로 유지해 기존 저장본의 상태/커밋을 바꾸지 않는다.
        let sequenceTrustReward = (params.state.balanceVersion ?? 1) >= 4
            ? PitchSequenceMasteryRules.trustReward(for: params.report.sequenceMasteryCount)
            : 0
        let masteryManagerTrust: Int? = sequenceTrustReward > 0
            ? clamp((params.state.managerTrust ?? params.state.relationshipTrust) + sequenceTrustReward, 0, 100)
            : nil
        let masteryCatcherTrust: Int? = sequenceTrustReward > 0
            ? clamp((params.state.catcherTrust ?? params.state.relationshipTrust) + sequenceTrustReward, 0, 100)
            : nil
        let masteryRelationshipTrust: Int? = if let masteryManagerTrust, let masteryCatcherTrust {
            (masteryManagerTrust + masteryCatcherTrust
                + (params.state.rivalTrust ?? params.state.relationshipTrust)) / 3
        } else {
            nil
        }
        let masteryNews: String? = sequenceTrustReward > 0
            ? "수싸움 적중 \(params.report.sequenceMasteryCount ?? 0)회 — 감독과 포수의 믿음 +\(sequenceTrustReward)."
            : nil
        let gameGrowthNews = gameGrowth.map { "\($0.title). \($0.detail)" }

        // 직접 던진 경기를 시즌 기록지에 남긴다. 예전에는 성적 합계에만 더해져서
        // "던진 이닝"이 영원히 0이었다 — played 줄이 없으면 이닝을 셀 근거가 없다.
        // 지역 생성기만 쓰므로 커널 RNG 스트림과 골든 픽스처에는 영향이 없다.
        var lineRNG = SplitMix64(seed: seed ^ 0x4853_504C_4159)  // "HSPLAY"
        let outs = params.report.outs ?? min(27, params.report.pitches / 5)
        let support: Int
        let opponentRuns: Int
        if let entryDifferential = params.report.scoreDifferentialAtEntry {
            let opponentEarlier = lineRNG.nextInt(upperBound: 3)
            opponentRuns = opponentEarlier + params.report.runsAllowed
            support = max(0, opponentEarlier + entryDifferential + lineRNG.nextInt(upperBound: 2))
        } else {
            support = LeagueBaseline.highSchoolTeamRuns(using: &lineRNG)
            opponentRuns = params.report.runsAllowed
                + LeagueBaseline.restOfHighSchoolTeamRuns(outsCovered: max(0, 27 - outs), using: &lineRNG)
        }
        let playedLine = ProGameLine(
            season: params.state.chapter.schoolYear,
            week: params.state.chapter.number,
            outingNumber: (params.state.seasonLog?.count ?? 0) + 1,
            started: false,
            outs: outs,
            strikeouts: params.report.strikeouts,
            walks: params.report.walks,
            runsAllowed: params.report.runsAllowed,
            pitches: params.report.pitches,
            teamRuns: support,
            opponentRuns: opponentRuns,
            decision: DecisionRules.decide(
                started: false, isCloser: false, outs: outs,
                runsAllowed: params.report.runsAllowed,
                teamRuns: support, opponentRuns: opponentRuns
            ),
            played: true
        )

        // 스태미나가 등판 피로 곡선을 정한다(60 기준 기존과 동일: 80→가볍고 30→무겁다).
        // 커널 검증만 받고 아무 데도 안 읽히던 능력치가 처음으로 마운드 위에서 일한다.
        let staminaScale = max(60, 140 - params.state.pitcher.stamina)
        let nextBase = replacing(params.state, revision: params.state.revision + 1,
            pitcher: gameGrowth?.applying(to: params.state.pitcher),
            relationshipTrust: masteryRelationshipTrust,
            managerTrust: masteryManagerTrust,
            catcherTrust: masteryCatcherTrust,
            fatigue: clamp(params.state.fatigue + max(3, params.report.pitches * staminaScale / 240), 0, 100),
            performance: performance,
            seasonLog: (params.state.seasonLog ?? []) + [playedLine],
            news: ([headline] + (callback.map { [$0] } ?? []) + (armNews.map { [$0] } ?? [])
                + (sparkNews.map { [$0] } ?? []) + (masteryNews.map { [$0] } ?? [])
                + (gameGrowthNews.map { [$0] } ?? []) + params.state.news),
            fanInterest: interest, armRisk: nextRisk,
            talent: gameGrowth?.resultingTalent,
            awakeningSparks: sparks)
        let next = advanceMilestone(nextBase, seed: seed)
        return result(
            seed: seed,
            state: signed(next),
            event: "career_important_game_completed",
            reasons: ["important_game.\(expected)"]
                + (sequenceTrustReward > 0 ? ["pitch_sequence.mastery_trust"] : [])
                + (gameGrowth.map { [$0.reasonCode] } ?? [])
        )
    }

    public func chooseAwakening(_ params: ChooseCareerAwakeningParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .awakening)
        guard params.state.awakeningOptions.contains(params.awakening), !params.state.selectedAwakenings.contains(params.awakening) else {
            throw SimulationError.invalidPitcherLab("career awakening is not available")
        }
        let nextBase = replacing(params.state, revision: params.state.revision + 1,
            pitcher: applyAwakening(params.awakening, to: params.state.pitcher),
            selectedAwakenings: params.state.selectedAwakenings + [params.awakening], awakeningOptions: [],
            news: ["‘\(awakeningTitle(params.awakening))’을 익혔습니다. \(awakeningEffect(params.awakening))"] + params.state.news,
            // 전조는 각성이 소비한다. 다음 각성은 다시 증명으로 채워야 한다.
            awakeningSparks: params.state.awakeningSparks != nil ? 0 : nil)
        let next = advanceMilestone(nextBase, seed: seed)
        return result(seed: seed, state: signed(next), event: "career_awakening_selected", reasons: ["awakening.\(params.awakening.rawValue)"])
    }

    public func advanceChapter(_ params: AdvanceCareerChapterParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .chapterReview)
        guard params.state.chapter.number < 8 else { throw SimulationError.invalidPitcherLab("final chapter cannot advance") }
        let chapter = Self.chapters[params.state.chapter.number]

        // 챕터가 넘어가는 동안 팀은 경기를 계속 치른다. 예전에는 그 경기들이 세계에
        // 존재하지 않아서, 직접 던진 4~6경기만으로 3년이 요약됐다.
        let autoGames = Self.simulateChapterGames(
            state: params.state,
            chapter: params.state.chapter,
            seed: seed
        )
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .training,
            chapter: chapter, chapterTrainingCount: 0, milestoneIndex: 0,
            seasonLog: (params.state.seasonLog ?? []) + autoGames,
            news: [Self.chapterGameHeadline(autoGames), "\(chapter.title) — \(chapter.theme)."] + params.state.news)
        return result(seed: seed, state: signed(next), event: "career_chapter_advanced", reasons: ["chapter.\(chapter.number)"])
    }


    /// 고교 자동 경기의 평균 9이닝당 실점(천분율). 드래프트 시즌 항의 영점이다.
    /// `AutoOutingSimulator`나 타자 오프셋을 바꾸면 이 값을 다시 재야 한다 —
    /// 안 그러면 시즌 항이 전원 가산점이나 전원 감점으로 무너진다.
    /// 고교 자동 경기의 평균 9이닝당 실점 영점(‰). 드래프트 시즌 항이 이 값을 0으로 삼는다.
    ///
    /// **실제 회차를 돌려서 잰다.** 예전에는 오프셋 −6 고정으로 120경기를 돌려 1_610을 얻었는데,
    /// 실제 일정은 대회 챕터가 프로 수준(오프셋 0)이라 그 값이 처음부터 낮았다. 난이도 보정까지
    /// 들어오자 격차가 벌어져 드래프트 통과율이 30%에서 10%로 떨어졌다 — 리그 전체가 세졌는데
    /// 영점만 옛날 자리에 있으면 **모든 회차가 평균 이하로 찍힌다.**
    ///
    /// 실측(회차당 25시드, 자동 경기만): 1회차 2_529‰ · 3회차 4_259‰. 난이도 보정 1점당
    /// 약 432‰다.
    static let highSchoolBaselineRA9Permille = 2_530
    /// 난이도 보정 1점당 오르는 9이닝당 실점(‰).
    static let ra9PermillePerOffsetPoint = 432

    /// 이 회차의 시즌 항 영점. 상대가 세진 만큼 "평균"의 자리도 올라간다.
    static func highSchoolBaseline(lifeNumber: Int) -> Int {
        difficultyAdjustedHighSchoolBaseline(
            firstLifeBaseline: highSchoolBaselineRA9Permille,
            lifeNumber: lifeNumber
        )
    }

    /// v4 시작 유형별 자동 경기 영점.
    ///
    /// PitchKernel은 제구·변화구 프로필의 장점을 실제 실점 억제로 바꾼다. 하나의 RA9
    /// 영점만 쓰면 그 강점을 능력 총점에 이어 시즌 항에서도 3~5점 다시 받게 된다.
    /// 유형별 기대 기록보다 얼마나 잘했는지를 비교해 스타일은 보존하고 이중 가산만 없앤다.
    /// v3 이하 저장은 공통 영점을 유지하고, v4 migration 뒤부터 새 영점을 사용한다.
    static func highSchoolBaseline(
        lifeNumber: Int,
        pitcherID: String,
        balanceVersion: Int?
    ) -> Int {
        guard (balanceVersion ?? 1) >= 4 else {
            return highSchoolBaseline(lifeNumber: lifeNumber)
        }
        let firstLifeBaseline: Int = switch pitcherID {
        case "pitcher-command": 1_120
        case "pitcher-artist": 1_590
        case "pitcher-stamina": 1_710
        default: 2_900
        }
        return difficultyAdjustedHighSchoolBaseline(
            firstLifeBaseline: firstLifeBaseline,
            lifeNumber: lifeNumber
        )
    }

    private static func difficultyAdjustedHighSchoolBaseline(
        firstLifeBaseline: Int,
        lifeNumber: Int
    ) -> Int {
        func meanScale(_ life: Int) -> Int {
            let scales = (1...8).map { DifficultyScale.highSchool(chapter: $0, lifeNumber: life) }
            return scales.reduce(0, +) * 100 / scales.count   // 100배 고정소수
        }
        let delta = meanScale(lifeNumber) - meanScale(1)
        return firstLifeBaseline + ra9PermillePerOffsetPoint * delta / 100
    }

    /// 챕터 하나가 지나는 동안 팀이 치르는 경기.
    ///
    /// 두 경기로 잡은 이유: 8챕터 × 2 = 14경기이고, 여기에 직접 던진 4~6경기를 더하면
    /// 학년당 20경기 안팎이 된다. 고교 야구의 한 시즌 규모에 가깝고, 무엇보다 **직접 던진
    /// 경기가 전체의 4분의 1을 차지해** 주인공 자리를 잃지 않는다.
    ///
    /// 커널 RNG 스트림을 건드리지 않으려고 시드에서 지역 생성기를 만들어 쓴다.
    /// 골든 픽스처는 `SimulationEngine.simulatePitch` 경로만 덮으므로 영향이 없다.
    static func simulateChapterGames(
        state: HighSchoolCareerSnapshot,
        chapter: CareerChapterSnapshot,
        seed: UInt64
    ) -> [ProGameLine] {
        var rng = SplitMix64(seed: seed ^ 0x4853_4741_4d45)  // "HSGAME"
        let simulator = AutoOutingSimulator()
        // 고교 타자는 프로 기준선보다 약하다. 대회 챕터만 프로 수준으로 올린다 —
        // 전국 무대에서 갑자기 상대가 세지는 것이 이 게임의 긴장 구조다.
        // 대회 챕터는 프로 수준, 나머지는 고교 수준. 여기에 학년·회차 보정을 더한다 —
        // 직접 던진 경기만 세지고 자동 경기가 그대로면 시즌 기록이 두 세계로 갈린다.
        let base = chapter.theme.contains("대회") ? 0 : -6
        let offset = base + DifficultyScale.highSchool(chapter: chapter.number, lifeNumber: state.lifeNumber)
        let alreadyPlayed = state.seasonLog?.count ?? 0

        return (0..<2).map { index in
            let line = simulator.simulate(
                pitcher: state.pitcher,
                startingFatigue: state.fatigue + index * 6,
                outsTarget: 18,
                pitchCap: 90,
                batterOffset: offset,
                baseSeed: rng.next()
            )
            let support = LeagueBaseline.highSchoolTeamRuns(using: &rng)
            let othersOuts = max(0, 27 - line.outs)
            let opponentRuns = line.runsAllowed
                + LeagueBaseline.restOfHighSchoolTeamRuns(outsCovered: othersOuts, using: &rng)
            return ProGameLine(
                season: chapter.schoolYear,
                week: chapter.number,
                outingNumber: alreadyPlayed + index + 1,
                started: true,
                outs: line.outs,
                strikeouts: line.strikeouts,
                walks: line.walks,
                runsAllowed: line.runsAllowed,
                pitches: line.pitches,
                teamRuns: support,
                opponentRuns: opponentRuns,
                decision: DecisionRules.decide(
                    started: true,
                    isCloser: false,
                    outs: line.outs,
                    runsAllowed: line.runsAllowed,
                    teamRuns: support,
                    opponentRuns: opponentRuns
                ),
                played: false,
                hits: line.hits,
                homeRuns: line.homeRuns
            )
        }
    }

    /// 자동 경기 두 개를 한 줄 뉴스로. 숫자만 쌓이고 아무 말도 없으면 읽히지 않는다.
    static func chapterGameHeadline(_ games: [ProGameLine]) -> String {
        let outs = games.reduce(0) { $0 + $1.outs }
        let strikeouts = games.reduce(0) { $0 + $1.strikeouts }
        let runs = games.reduce(0) { $0 + $1.runsAllowed }
        let wins = games.filter { $0.decision == .win }.count
        let innings = outs / 3
        return "팀 경기 \(games.count)차례 등판 · \(innings)이닝 \(strikeouts)탈삼진 \(runs)실점"
            + (wins > 0 ? " · \(wins)승" : "")
    }

    /// 드래프트 평가의 결정론 부분 — 분산(v4 ±1, 이전 저장 ±5)만 뺀 전부.
    ///
    /// `resolveDraft`와 **같은 함수**를 쓰는 것이 예측의 정직함이다. 예측 공식을
    /// 따로 두면 언젠가 둘이 어긋나고, "1라운드 예측 → 미지명"의 배신은 게임에
    /// 대한 신뢰 전체를 무너뜨린다.
    struct DraftEvaluationComponents {
        let ratingScore: Int
        let performanceScore: Int
        let processBonus: Int
        let awakeningScore: Int
        let relationshipScore: Int
        let seasonTerm: Int
        let karmaPenalty: Int
        let overusePenalty: Int
        /// 팬 관심 항. 표시만 되고 판정에 안 쓰이면 "만들다 만 축"이 더 선명해진다
        /// (3차 패널 P2) — 캡 ±3으로 관계·시즌 항보다 작게, 흥행은 실력을 못 이긴다.
        let fanTerm: Int
        /// 회차 바람의 공개된 평가 보정. v1/nil 저장본은 항상 0이다.
        let windDelta: Int

        var total: Int {
            ratingScore + performanceScore + processBonus + awakeningScore
                + relationshipScore + seasonTerm + fanTerm + windDelta - karmaPenalty - overusePenalty
        }
    }

    static func draftEvaluationCore(state: HighSchoolCareerSnapshot) -> DraftEvaluationComponents {
        let usesV4Balance = (state.balanceVersion ?? 1) >= 4
        let ratings = state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        let gameQuality = state.performance.strikeouts * 3 - state.performance.walks * 2 - state.performance.runsAllowed * 3
        let processBonus = max(-8, min(10, (state.performance.expectedDamage - state.performance.actualDamage) / 350))
        let ratingScore = ratings / 4 + 15
        // 실제 경기의 결과와 기대 피해 차이는 서로 연관된 신호다. v4는 둘을 함께 보여 주되
        // 같은 호투를 두 번 크게 더하지 않도록 결과 항만 완만하게 만든다.
        let performanceScore = gameQuality / (usesV4Balance ? 6 : 4)
        let awakeningScore = state.selectedAwakenings.count
        let relationshipScore = (state.relationshipTrust - 50) / 10
        let karmaPenalty = (state.karmas.contains(.unknownLand) ? 3 : 0)
            + (state.karmas.contains(.noLastChance) ? 2 : 0)
        let residualRisk = state.armRisk ?? 0
        let overusePenalty = residualRisk >= Self.armWarningThreshold ? 4 : residualRisk >= 45 ? 2 : 0
        // 자동 시즌 항은 v4에서 기울기와 캡을 함께 줄여 직접 던진 승부보다 작게 유지한다.
        // 영점은 고교 리그 평균(실측 RA9, 회차별 기준선) — 프로 기준을 쓰면 전원 가산점이 된다.
        let autoLines = (state.seasonLog ?? []).filter { !$0.played }
        let autoOuts = autoLines.reduce(0) { $0 + $1.outs }
        let autoRuns = autoLines.reduce(0) { $0 + $1.runsAllowed }
        let seasonCap = usesV4Balance ? 2 : 4
        let seasonSlope = usesV4Balance ? 1 : 4
        let seasonTerm = autoOuts == 0
            ? 0
            : min(seasonCap, max(-seasonCap, (Self.highSchoolBaseline(
                lifeNumber: state.lifeNumber,
                pitcherID: state.pitcher.id,
                balanceVersion: state.balanceVersion
            ) - autoRuns * 27_000 / autoOuts) * seasonSlope / 1_000))
        // 팬 관심: 40이 중립. 스카우트는 소문(만원 관중)에 아주 조금 흔들린다.
        let fanTerm = min(3, max(-3, (state.fanInterest - 40) / 15))
        return DraftEvaluationComponents(
            ratingScore: ratingScore, performanceScore: performanceScore, processBonus: processBonus,
            awakeningScore: awakeningScore, relationshipScore: relationshipScore, seasonTerm: seasonTerm,
            karmaPenalty: karmaPenalty, overusePenalty: overusePenalty, fanTerm: fanTerm,
            windDelta: state.careerWind.rules.draftEvaluationDelta
        )
    }

    /// 예고 화면과 실제 지명이 공유하는 공개 문턱. v3 저장의 57/61/65는 영구 보존한다.
    static func draftThreshold(state: HighSchoolCareerSnapshot) -> Int {
        let legacy = state.difficulty.careerHarshness == .relaxed ? 57
            : state.difficulty.careerHarshness == .challenging ? 65 : 61
        return legacy + ((state.balanceVersion ?? 1) >= 4 ? 2 : 0)
    }

    /// RNG bucket을 실제 드래프트 점수 변화로 바꾸는 저장 버전별 순수 규칙.
    static func draftVariance(balanceVersion: Int?, roll: Int) -> Int {
        if (balanceVersion ?? 1) >= 4 {
            precondition((0..<5).contains(roll))
            return roll == 0 ? -1 : roll == 4 ? 1 : 0
        }
        precondition((0..<11).contains(roll))
        return roll - 5
    }

    /// 미디어의 가상 지명 명단 — "스크롤을 내려 내 이름을 찾는" 그 화면.
    public struct DraftForecastSnapshot: Equatable, Sendable {
        /// 분산을 뺀 예상 점수(20~95).
        public let score: Int
        /// 당락 문턱. 난도에 따라 다르다.
        public let threshold: Int
        /// "1라운드 예상" 같은 밴드 문구.
        public let band: String
        /// 지금 성적 기준으로 가장 주목하는 구단.
        public let interestedTeam: String
    }

    public static func draftForecast(state: HighSchoolCareerSnapshot) -> DraftForecastSnapshot {
        let score = min(95, max(20, draftEvaluationCore(state: state).total))
        let threshold = draftThreshold(state: state)
        // 밴드 경계는 resolveDraft의 라운드 경계와 같다. 경계 ±분산 구간은
        // 정직하게 "당락 경계"라고 말한다 — 예측이 확신을 팔면 안 된다.
        let band = score >= 78 ? "1라운드 예상"
            : score >= 70 ? "2~3라운드 예상"
            : score >= threshold + 5 ? "4~6라운드 예상"
            : score >= threshold - 5 ? "당락 경계 — 남은 경기가 정한다"
            : "미지명권 — 아직 명단 밖"
        return DraftForecastSnapshot(
            score: score, threshold: threshold, band: band,
            interestedTeam: bestTeam(for: state.pitcher, seed: 0).name
        )
    }

    public func resolveDraft(_ params: ResolveDraftParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .draft)
        var generator = SplitMix64(seed: seed ^ 0x4452_4146_5400)
        let core = Self.draftEvaluationCore(state: params.state)
        // v4는 화면이 알려 준 기회나 한 방향 훈련을 일관되게 따른 회차가 분산 훈련보다
        // 분명히 앞서도록 한다. 직접 경기 결과는 ÷6으로 중복 가산을 누르고, 자동 시즌은
        // 기울기 1·캡 ±2의 보조 신호만 남긴다. v3 이하는 저장 당시 식을 그대로 쓴다.
        let usesV4Balance = (params.state.balanceVersion ?? 1) >= 4
        let varianceRoll = generator.nextInt(upperBound: usesV4Balance ? 5 : 11)
        // v4 경계의 작은 운은 남기되 대부분은 화면의 예측값 그대로 간다.
        // -1 / 0 / +1 = 20% / 60% / 20%라 직접 만든 1점 차이를 자주 뒤집지 않는다.
        let variance = Self.draftVariance(
            balanceVersion: params.state.balanceVersion,
            roll: varianceRoll
        )
        // Overwork history reads through residual arm risk at draft time: a run still carrying a
        // high, unaddressed risk takes a small durability ding, while a run that got hurt but
        // rehabbed clean (risk bled back down) passes through unpenalised — "회복 후 무사 통과".
        let score = clamp(core.total + variance, 20, 95)
        let threshold = Self.draftThreshold(state: params.state)
        let drafted = score >= threshold
        let team = drafted ? Self.bestTeam(for: params.state.pitcher, seed: seed) : nil
        let round = drafted ? (score >= 78 ? 1 : score >= 70 ? 2 : 4) : nil
        let pick = round.map { ($0 - 1) * 10 + generator.nextInt(upperBound: 10) + 1 }
        let draft = DraftResultSnapshot(
            outcome: drafted ? .drafted : .undrafted, evaluationScore: score,
            // Derived from the outcome so a drafted player never reads as "미지명" — e.g. a 57–60
            // score that clears the relaxed 57 threshold still shows a concrete round range.
            projectedRange: !drafted ? "미지명" : score >= 78 ? "1라운드" : score >= 70 ? "2~3라운드" : "4~6라운드",
            team: team, round: round, overallPick: pick,
            signingBonus: round.map { max(40_000_000, 300_000_000 - $0 * 45_000_000) },
            firstSeasonGoal: team.map { _ in "퓨처스 선발 10경기와 볼넷률 8% 이하" },
            // 평가가 어디서 왔는지 항목으로 보여 준다. 부호를 붙여야 무엇이 깎았는지 읽힌다.
            evaluationBreakdown: [
                "능력 \(core.ratingScore)",
                "고교 공식 경기 \(core.performanceScore >= 0 ? "+" : "")\(core.performanceScore)",
                "시즌 기록 \(core.seasonTerm >= 0 ? "+" : "")\(core.seasonTerm)",
                "각성 +\(core.awakeningScore)",
                "관계 \(core.relationshipScore >= 0 ? "+" : "")\(core.relationshipScore)",
            ] + (core.karmaPenalty > 0 ? ["핸디캡 -\(core.karmaPenalty)"] : [])
              + (core.overusePenalty > 0 ? ["팔 상태 -\(core.overusePenalty)"] : []),
            summary: drafted
                ? "지명 구단 · \(team?.name ?? "프로 구단"). 구위와 고교 경기 기록에서 높은 평가를 받았습니다."
                : "마지막 라운드까지 이름이 불리지 않았습니다. 다음 선수에게 남길 기록을 고르세요."
        )
        // 기억은 **회차를 접을 때** 고른다.
        //
        // 예전에는 지명 여부와 무관하게 곧바로 기억 선택으로 넘어갔다. 그런데 지명은 회차의
        // 끝이 아니다 — 프로 커리어가 남아 있다. 성공한 순간에 "다음 생에 무엇을 남길지"를
        // 묻는 것은 아직 끝나지도 않은 이야기의 유언을 받는 것과 같다.
        //
        // 지금은 지명되면 완료 화면으로 바로 간다. 프로로 갈 수도 있고, 이 회차를 접고
        // 다시 시작할 수도 있는데, 기억은 **후자를 고를 때** 정한다(`openLegacy`).
        // 미지명은 회차가 강제로 끝나므로 그대로 기억 선택으로 간다.
        let memories = memoryOptions(state: params.state, seed: seed, drafted: drafted)
        let next = replacing(params.state, revision: params.state.revision + 1,
            phase: drafted ? .completed : .legacy,
            news: [drafted ? "드래프트 지명 · \(team?.name ?? "프로 구단") · \(params.state.pitcher.name)" : "드래프트가 끝날 때까지 이름이 불리지 않았습니다."] + params.state.news,
            draftResult: draft, legacyOptions: memories)
        return result(seed: seed, state: signed(next), event: "career_draft_resolved", reasons: ["draft.\(draft.outcome.rawValue)"])
    }

    /// 지명된 회차를 접고 기억 선택으로 들어간다.
    ///
    /// 지명되면 완료 화면에서 멈춘다 — 프로로 갈지, 이 회차를 접고 다시 시작할지는 플레이어의
    /// 선택이다. 후자를 골랐을 때만 이 함수가 불린다. 미지명은 `resolveDraft`가 이미
    /// `.legacy`로 보냈으므로 여기 오지 않는다.
    public func openLegacy(_ params: AdvanceCareerChapterParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed)
        try validate(params.state, phase: .completed)
        guard params.state.draftResult?.outcome == .drafted else {
            throw SimulationError.invalidPitcherLab("미지명 선수는 이미 유산을 고르는 단계입니다.")
        }
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .legacy)
        return result(seed: seed, state: signed(next), event: "career_legacy_opened", reasons: ["legacy.opened"])
    }

    public func selectLegacy(_ params: SelectCareerLegacyParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .legacy)
        if let signatureLegacyID = params.signatureLegacyID {
            guard params.memoryCards.isEmpty else {
                throw SimulationError.invalidPitcherLab("signature legacy cannot be mixed with career memories")
            }
            let next = replacing(
                params.state,
                revision: params.state.revision + 1,
                phase: .completed,
                legacyOptions: [],
                selectedMemories: []
            )
            return result(
                seed: seed,
                state: signed(next),
                event: "career_legacy_selected",
                reasons: ["signature_legacy.\(signatureLegacyID.rawValue)"]
            )
        }
        let unique = Array(Set(params.memoryCards))
        guard unique.count == params.state.memorySlots, unique.allSatisfy(params.state.legacyOptions.contains) else {
            throw SimulationError.invalidPitcherLab("select the available number of offered career memories")
        }
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .completed,
            legacyOptions: unique, selectedMemories: unique)
        return result(seed: seed, state: signed(next), event: "career_legacy_selected", reasons: unique.map { "memory.\($0.rawValue)" })
    }

    /// 스케줄에서 챕터별 국면을 읽는다. 8챕터(드래프트 직전 챕터)는 저장된 국면 뒤에 .draft를
    /// 덧붙여 finale 구조를 보장하고, 국면을 모두 소진하면 .chapterReview로 넘어간다.
    private func milestone(for chapter: Int, index: Int, schedule: CareerScheduleSnapshot) -> HighSchoolCareerPhase {
        var events = schedule.milestonesByChapter[chapter - 1]
        if chapter == 8 { events.append(.draft) }
        return index < events.count ? events[index] : .chapterReview
    }

    private func advanceMilestone(_ state: HighSchoolCareerSnapshot, seed: UInt64) -> HighSchoolCareerSnapshot {
        let index = state.milestoneIndex + 1
        let phase = milestone(for: state.chapter.number, index: index, schedule: schedule(for: state))
        let options = phase == .awakening ? awakeningOptions(state: state, seed: seed) : []
        let scenario = phase == .importantGame ? gameScenario(for: state, seed: seed) : nil
        let relationshipEvent = phase == .relationship ? relationshipEventForSlot(state, seed: seed) : nil
        if phase == .draft {
            return replacing(state, phase: .draft, milestoneIndex: index, awakeningOptions: [])
        }
        return replacing(state, phase: phase, milestoneIndex: index, awakeningOptions: options,
            performance: state.performance, currentGameScenario: scenario, currentRelationshipEvent: relationshipEvent)
    }

    private func rival(seed: UInt64, difficulty: DifficultyLevel, karmas: [KarmaID], windBonus: Int = 0) -> RivalSnapshot {
        var generator = SplitMix64(seed: seed ^ 0x5249_5641_4c00)
        let base = Self.rivals[generator.nextInt(upperBound: Self.rivals.count)]
        let difficultyBonus = difficulty == .relaxed ? -3 : difficulty == .challenging ? 4 : 0
        let generationBonus = karmas.contains(.geniusGeneration) ? 4 : 0
        let bonus = difficultyBonus + generationBonus + windBonus
        return RivalSnapshot(id: base.id, name: base.name, archetype: base.archetype,
            contact: clamp(base.contact + bonus, 20, 80), discipline: clamp(base.discipline + bonus, 20, 80),
            power: clamp(base.power + bonus, 20, 80), personality: base.personality, signatureRecord: base.signatureRecord)
    }

    private func awakeningOptions(state: HighSchoolCareerSnapshot, seed: UInt64) -> [AwakeningID] {
        let focus = state.lastTraining?.focus ?? .gamePlanning
        let focusOptions: [TrainingFocus: [AwakeningID]] = [
            .velocity: [.explosiveFastball, .risingFourSeam],
            .command: [.pinpointEdge, .repeatableRelease, .firstPitchStrike],
            .breakingBall: [.disappearingBreaker, .sweepingSlider, .frozenChangeup, .curveballClock, .sinkerTunnel],
            .stamina: [.ironArm, .lateInningReserve, .trafficController],
            .recovery: [.calmUnderPressure, .lateInningReserve, .repeatableRelease],
            .gamePlanning: [.twoStrikePlan, .batterySync, .pickoffRhythm, .trafficController]
        ]
        let performanceOptions: [AwakeningID] = state.performance.walks > state.performance.strikeouts
            ? [.pinpointEdge, .repeatableRelease, .batterySync]
            : state.performance.actualDamage > state.performance.expectedDamage
                ? [.twoStrikePlan, .disappearingBreaker, .trafficController]
                : [.scoutComposure, .calmUnderPressure, .firstPitchStrike]
        let strongestOptions: [AwakeningID] = state.pitcher.stuff >= state.pitcher.command && state.pitcher.stuff >= state.pitcher.movement
            ? [.explosiveFastball, .risingFourSeam]
            : state.pitcher.command >= state.pitcher.movement
                ? [.pinpointEdge, .repeatableRelease]
                : [.disappearingBreaker, .sweepingSlider]
        var generator = SplitMix64(seed: seed ^ UInt64(state.chapter.number) ^ 0x4157_414b_4500)
        var result: [AwakeningID] = []
        for pool in [focusOptions[focus] ?? [], performanceOptions, strongestOptions] {
            let candidates = pool.filter { !state.selectedAwakenings.contains($0) }
            guard !candidates.isEmpty else { continue }
            let offset = generator.nextInt(upperBound: candidates.count)
            let ordered = Array(candidates[offset...] + candidates[..<offset])
            if let option = ordered.first(where: { !result.contains($0) }) { result.append(option) }
        }
        var options = AwakeningID.allCases.filter { !state.selectedAwakenings.contains($0) && !result.contains($0) }
        for index in options.indices.reversed() where index > 0 {
            options.swapAt(index, generator.nextInt(upperBound: index + 1))
        }
        for option in options where result.count < 3 && !result.contains(option) {
            result.append(option)
        }
        // 전조가 갈래 수를 정한다. 호투·만개 없이 도착한 각성은 몸이 절반만 깨어난 것이라
        // 길이 하나뿐이고, 시즌을 증명으로 채웠으면 세 갈래가 전부 열린다.
        // 옛 저장본(nil)은 예전과 같은 3갈래 — 규칙이 소급해서 벌하지 않는다.
        if let sparks = state.awakeningSparks {
            // 전조 0이어도 두 갈래는 남긴다 — 선택지가 하나면 선택이 아니라 통보다.
            let opened = sparks >= 3 ? 3 : 2
            return Array(result.prefix(opened))
        }
        return result
    }

    private static let coreRelationshipCategories = ["coach", "catcher", "rival"]

    // Every non-core event category (growth/health/team/media/life/…), in catalog order.
    private static let extendedRelationshipCategories: [String] = {
        let core: Set<String> = ["coach", "catcher", "rival"]
        var seen = Set<String>()
        var ordered: [String] = []
        for event in HighSchoolContentCatalog.events where !core.contains(event.category) {
            if seen.insert(event.category).inserted { ordered.append(event.category) }
        }
        return ordered
    }()

    private func relationshipEvent(for state: HighSchoolCareerSnapshot, seed: UInt64) -> CareerEventContent {
        let slot = state.relationshipsCompleted
        // 핵심 3인(감독·포수·라이벌)은 매 회차 반드시 만난다. 다만 **만나는 순서를 회차마다
        // 섞는다** — 예전에는 언제나 감독 → 포수 → 라이벌이라, 회차를 반복할수록 첫 세 장면이
        // 같은 순서로 지나갔다.
        if slot < Self.coreRelationshipCategories.count {
            var orderGenerator = SplitMix64(
                seed: UInt64(StableHash.fnv1a64("core_order|\(state.careerID)"), radix: 16) ?? seed
            )
            var order = Self.coreRelationshipCategories
            for index in order.indices.reversed() where index > 0 {
                order.swapAt(index, orderGenerator.nextInt(upperBound: index + 1))
            }
            let category = order[slot]
            let candidates = HighSchoolContentCatalog.events.filter { $0.category == category }
            return candidates[Int(seed % UInt64(candidates.count))]
        }
        // 2회차부터는 환생 사건이 후보에 들어온다. 처음 하는 사람에게는 뜻이 통하지 않으므로
        // 1회차에는 아예 뽑지 않는다.
        if state.lifeNumber > 1 {
            var rebirthGenerator = SplitMix64(
                seed: UInt64(StableHash.fnv1a64("rebirth_event|\(state.careerID)|\(slot)"), radix: 16) ?? seed
            )
            // 회차마다 확장 슬롯 하나는 환생 사건이 **반드시** 나온다. 슬롯마다 1/3 확률만
            // 걸었을 때는 2회차의 절반 가까이가 회차 자각 장면을 한 번도 못 만났다 —
            // "처음 밟는데 익숙한 마운드"는 2회차의 간판인데 절반에게 안 보였다.
            // 나머지 슬롯은 예전처럼 1/3 확률로만 얹는다. 전부 주면 회차 자각이 배경이 된다.
            let extendedSlot = slot - Self.coreRelationshipCategories.count
            let extendedSlotCount = max(1, schedule(for: state).relationshipTotal - Self.coreRelationshipCategories.count)
            var guaranteeGenerator = SplitMix64(
                seed: UInt64(StableHash.fnv1a64("rebirth_guarantee|\(state.careerID)"), radix: 16) ?? seed
            )
            let guaranteedSlot = guaranteeGenerator.nextInt(upperBound: extendedSlotCount)
            if extendedSlot == guaranteedSlot || rebirthGenerator.nextInt(upperBound: 3) == 0 {
                let pool = HighSchoolContentCatalog.rebirthEvents
                return pool[rebirthGenerator.nextInt(upperBound: pool.count)]
            }
        }
        // Later slots surface the wider pool so the 26 non-core events become reachable.
        // Each run draws a distinct category per slot, varying by run — careerID embeds both
        // the seed and the life number — while staying fully deterministic.
        let runSeed = UInt64(StableHash.fnv1a64("relationship_pool|\(state.careerID)"), radix: 16) ?? seed
        var generator = SplitMix64(seed: runSeed)
        var categories = Self.extendedRelationshipCategories
        for index in categories.indices.reversed() where index > 0 {
            categories.swapAt(index, generator.nextInt(upperBound: index + 1))
        }
        let category = categories[(slot - Self.coreRelationshipCategories.count) % categories.count]
        let candidates = HighSchoolContentCatalog.events.filter { $0.category == category }
        return candidates[Int(generator.next() % UInt64(candidates.count))]
    }

    private func relationshipNews(state: HighSchoolCareerSnapshot, response: RelationshipResponse, seed: UInt64, impact: RelationshipImpact) -> String {
        let content = state.currentRelationshipEvent ?? relationshipEvent(for: state, seed: seed)
        let category = content.category
        // Non-core moments (a fan letter, a call from home, a scout's question) read as their
        // own headline rather than being forced into a coach/catcher/rival voice.
        if !Self.coreRelationshipCategories.contains(category) {
            return "\(content.title) — \(impact.outcome)"
        }
        let name = category == "coach" ? "\(state.school?.coachName ?? "담당") 감독" : category == "catcher" ? "\(state.school?.catcherName ?? "주전") 포수" : state.rival.name
        let responseSummary: String
        switch (category, response) {
        case ("coach", .listen): responseSummary = "감독이 본 문제를 끝까지 들었습니다."
        case ("coach", .explain): responseSummary = "최근 등판 기록을 꺼내 자신의 생각을 설명했습니다."
        case ("coach", .challenge): responseSummary = "다음 등판에서 증명할 기회를 요청했습니다."
        case ("catcher", .listen): responseSummary = "포수가 본 타자 반응을 먼저 들었습니다."
        case ("catcher", .explain): responseSummary = "사인을 바꾼 이유와 자신이 본 타자 반응을 말했습니다."
        case ("catcher", .challenge): responseSummary = "다음 경기에서 두 사람의 생각을 직접 시험해 보기로 했습니다."
        case ("rival", .listen): responseSummary = "상대가 읽어 낸 투구 습관을 물었습니다."
        case ("rival", .explain): responseSummary = "그 공으로 노렸던 것을 숨기지 않고 말했습니다."
        default: responseSummary = "다음 타석에서는 다른 공으로 답하겠다고 했습니다."
        }
        return "\(content.title) · \(name) — \(responseSummary) \(impact.outcome)"
    }

    // Non-core events still land on one of the three people for the trust bookkeeping the UI
    // and save integrity expect; their real payload is the fatigue / fan interest / ability
    // change carried by the impact.
    public static func relationshipTarget(forEventCategory category: String) -> RelationshipTarget {
        switch category {
        case "coach": return .coach
        case "catcher", "growth", "game", "awakening", "fan": return .catcher
        case "rival": return .rival
        default: return .coach // health, team, draft, media, life, legacy
        }
    }

    private func relationshipImpact(state: HighSchoolCareerSnapshot, response: RelationshipResponse) -> RelationshipImpact {
        let category = state.currentRelationshipEvent?.category ?? "coach"
        if !Self.coreRelationshipCategories.contains(category) {
            return extendedRelationshipImpact(category: category, response: response)
        }
        if (state.balanceVersion ?? 1) >= 4,
           response == .listen,
           category == "coach" || category == "catcher" {
            return .init(
                trust: 4,
                fatigue: 0,
                fanInterest: 0,
                growthFocus: nil,
                outcome: "상대의 말을 끝까지 듣고 다음 준비 기준을 함께 확인했습니다."
            )
        }
        let archetype = category == "coach" ? state.school?.coachArchetype : category == "catcher" ? state.school?.catcherArchetype : state.rival.archetype
        switch (category, archetype, response) {
        case ("coach", "원칙형", .listen): return .init(trust: 8, fatigue: 0, fanInterest: 0, growthFocus: .stamina, outcome: "정해진 이닝을 버티기 위한 경기 전 준비 순서를 함께 정했습니다.")
        case ("coach", "원칙형", .explain): return .init(trust: 2, fatigue: 0, fanInterest: 0, growthFocus: .command, outcome: "등판 기록은 받아들였지만 맡은 역할은 그대로 유지됐습니다.")
        case ("coach", "원칙형", .challenge): return .init(trust: state.fatigue < 45 ? 5 : -7, fatigue: 6, fanInterest: 2, growthFocus: state.fatigue < 45 ? .velocity : nil, outcome: state.fatigue < 45 ? "추가 불펜에서 선발 테스트 기회를 얻었습니다." : "지친 상태에서 무리하게 등판을 요구해 감독의 믿음이 줄었습니다.")
        case ("coach", "분석형", .listen): return .init(trust: 3, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "감독이 지적한 수치를 다음 훈련에 반영했습니다.")
        case ("coach", "분석형", .explain): return .init(trust: 8, fatigue: 0, fanInterest: 0, growthFocus: .gamePlanning, outcome: "기록을 근거로 다음 등판의 구종과 코스 순서를 다시 짰습니다.")
        case ("coach", "분석형", .challenge): return .init(trust: -4, fatigue: 4, fanInterest: 2, growthFocus: .velocity, outcome: "추가 테스트는 얻었지만 준비 과정을 설득하지 못했습니다.")
        case ("coach", "승부형", .listen): return .init(trust: 2, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "지시는 받아들였지만 경쟁 구도는 바뀌지 않았습니다.")
        case ("coach", "승부형", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 1, growthFocus: .command, outcome: "최근 결과를 인정받아 한 번 더 선발 경쟁에 남았습니다.")
        case ("coach", "승부형", .challenge): return .init(trust: 8, fatigue: 6, fanInterest: 4, growthFocus: .velocity, outcome: "공개 불펜에서 가장 좋은 공으로 자리를 걸게 됐습니다.")
        case ("coach", "육성형", .listen): return .init(trust: 6, fatigue: -2, fanInterest: 0, growthFocus: .breakingBall, outcome: "동작 하나를 고쳐 볼 개인 훈련 시간을 받았습니다.")
        case ("coach", "육성형", .explain): return .init(trust: 7, fatigue: 0, fanInterest: 0, growthFocus: .command, outcome: "몸 상태에 맞춰 훈련 강도를 다시 조정했습니다.")
        case ("coach", "육성형", .challenge): return .init(trust: 1, fatigue: 4, fanInterest: 2, growthFocus: .velocity, outcome: "도전은 허락받았지만 교정 훈련 한 회를 포기했습니다.")
        case ("catcher", "안정형", .listen): return .init(trust: 8, fatigue: 0, fanInterest: 0, growthFocus: .gamePlanning, outcome: "다음 경기의 첫 세 타자 사인을 함께 고정했습니다.")
        case ("catcher", "안정형", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 0, growthFocus: .command, outcome: "사인을 바꾸는 기준을 하나로 맞췄습니다.")
        case ("catcher", "안정형", .challenge): return .init(trust: -4, fatigue: 2, fanInterest: 1, growthFocus: nil, outcome: "시험은 받아들였지만 포수의 불안은 남았습니다.")
        case ("catcher", "분석형", .listen): return .init(trust: 4, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "포수가 정리한 타자 반응표를 건네받았습니다.")
        case ("catcher", "분석형", .explain): return .init(trust: 8, fatigue: 0, fanInterest: 0, growthFocus: .gamePlanning, outcome: "두 사람이 본 근거를 합쳐 다음 경기의 구종 순서를 만들었습니다.")
        case ("catcher", "분석형", .challenge): return .init(trust: 2, fatigue: 2, fanInterest: 2, growthFocus: .breakingBall, outcome: "불펜에서 두 가지 구종 순서를 같은 타자를 상대로 시험했습니다.")
        case ("catcher", "공격형", .listen): return .init(trust: 2, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "포수의 공격적인 의도는 확인했지만 승부 순서는 정하지 못했습니다.")
        case ("catcher", "공격형", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 1, growthFocus: .command, outcome: "강한 공을 쓸 카운트를 좁혀 합의했습니다.")
        case ("catcher", "공격형", .challenge): return .init(trust: 8, fatigue: 3, fanInterest: 4, growthFocus: .velocity, outcome: "다음 경기 첫 타자에게 가장 자신 있는 구종 순서를 시험하기로 했습니다.")
        case ("catcher", "공감형", .listen): return .init(trust: 7, fatigue: -2, fanInterest: 0, growthFocus: .breakingBall, outcome: "받기 어려운 공을 추려 둘만의 불펜 시간을 잡았습니다.")
        case ("catcher", "공감형", .explain): return .init(trust: 7, fatigue: 0, fanInterest: 0, growthFocus: .command, outcome: "손에서 빠지는 날의 대체 사인을 정했습니다.")
        case ("catcher", "공감형", .challenge): return .init(trust: -2, fatigue: 3, fanInterest: 2, growthFocus: .breakingBall, outcome: "어려운 공을 더 받기로 했지만 경기 전 부담도 커졌습니다.")
        case ("rival", _, .listen): return .init(trust: 3, fatigue: 0, fanInterest: 1, growthFocus: .gamePlanning, outcome: "상대가 읽은 반복 습관 하나를 알아냈습니다.")
        case ("rival", _, .explain): return .init(trust: 1, fatigue: 0, fanInterest: 3, growthFocus: .command, outcome: "서로의 의도를 확인한 재대결이 기사에 실렸습니다.")
        case ("rival", _, .challenge): return .init(trust: -1, fatigue: 2, fanInterest: 7, growthFocus: .breakingBall, outcome: "다음 맞대결이 대회에서 가장 기대되는 승부가 됐습니다.")
        default: return .init(trust: 2, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "대화를 차분히 마쳐 감독·포수의 믿음이 조금 올랐습니다.")
        }
    }

    private func extendedRelationshipImpact(category: String, response: RelationshipResponse) -> RelationshipImpact {
        switch (category, response) {
        case ("growth", .listen): return .init(trust: 6, fatigue: 0, fanInterest: 0, growthFocus: .breakingBall, outcome: "포수와 함께 새 구종을 언제 쓸지 정리했습니다.")
        case ("growth", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 0, growthFocus: .command, outcome: "지금 잡은 그립의 감각을 설명해 제구 기준을 맞췄습니다.")
        case ("growth", .challenge): return .init(trust: 1, fatigue: 4, fanInterest: 2, growthFocus: .breakingBall, outcome: "다음 경기에서 바로 시험하기로 하고 불펜을 늘렸습니다.")
        case ("health", .listen): return .init(trust: 5, fatigue: -6, fanInterest: 0, growthFocus: nil, outcome: "오늘은 공을 놓고 회복에 집중하기로 했습니다.")
        case ("health", .explain): return .init(trust: 3, fatigue: -2, fanInterest: 0, growthFocus: .stamina, outcome: "몸 상태를 기록으로 설명해 훈련 강도를 조정했습니다.")
        case ("health", .challenge): return .init(trust: -3, fatigue: 6, fanInterest: 1, growthFocus: nil, outcome: "쉬라는 말을 미루고 던졌지만 피로가 더 쌓였습니다.")
        case ("team", .listen): return .init(trust: 5, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "팀이 정한 순서를 먼저 받아들였습니다.")
        case ("team", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 1, growthFocus: .gamePlanning, outcome: "내가 맡을 이닝과 역할을 분명히 정리했습니다.")
        case ("team", .challenge): return .init(trust: 2, fatigue: 4, fanInterest: 2, growthFocus: .stamina, outcome: "더 긴 이닝을 맡겠다고 나서 팀의 기대를 키웠습니다.")
        case ("draft", .listen): return .init(trust: 3, fatigue: 0, fanInterest: 2, growthFocus: nil, outcome: "스카우트가 무엇을 보는지 차분히 들었습니다.")
        case ("draft", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 3, growthFocus: .command, outcome: "무엇을 바꿨는지 근거를 들어 설명했습니다.")
        case ("draft", .challenge): return .init(trust: 1, fatigue: 4, fanInterest: 4, growthFocus: .velocity, outcome: "지켜보는 앞에서 가장 좋은 공으로 승부했습니다.")
        case ("media", .listen): return .init(trust: 2, fatigue: 0, fanInterest: 3, growthFocus: nil, outcome: "질문의 뜻을 되물어 차분히 답했습니다.")
        case ("media", .explain): return .init(trust: 3, fatigue: 0, fanInterest: 4, growthFocus: .gamePlanning, outcome: "그 공을 고른 이유를 솔직히 설명했습니다.")
        case ("media", .challenge): return .init(trust: 0, fatigue: 2, fanInterest: 6, growthFocus: nil, outcome: "다음 경기에서 결과로 답하겠다고 했습니다.")
        case ("fan", .listen): return .init(trust: 2, fatigue: 0, fanInterest: 4, growthFocus: nil, outcome: "팬이 좋아하는 공이 무엇인지 귀담아들었습니다.")
        case ("fan", .explain): return .init(trust: 3, fatigue: 0, fanInterest: 5, growthFocus: .command, outcome: "그 공을 왜 아끼는지 답장에 적었습니다.")
        case ("fan", .challenge): return .init(trust: 1, fatigue: 2, fanInterest: 6, growthFocus: .velocity, outcome: "다음 경기에서 그 공을 꼭 보여 주겠다고 약속했습니다.")
        case ("game", .listen): return .init(trust: 5, fatigue: 0, fanInterest: 1, growthFocus: .gamePlanning, outcome: "지난 상황을 포수와 되짚어 다음 수를 정리했습니다.")
        case ("game", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 1, growthFocus: .command, outcome: "그때의 선택을 설명해 배터리의 기준을 맞췄습니다.")
        case ("game", .challenge): return .init(trust: 2, fatigue: 3, fanInterest: 2, growthFocus: .breakingBall, outcome: "같은 상황이 오면 더 공격적으로 가기로 했습니다.")
        case ("awakening", .listen): return .init(trust: 4, fatigue: 0, fanInterest: 1, growthFocus: .breakingBall, outcome: "몸에 익은 동작을 포수와 다시 확인했습니다.")
        case ("awakening", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 1, growthFocus: .command, outcome: "반복해 온 동작의 감각을 말로 정리했습니다.")
        case ("awakening", .challenge): return .init(trust: 2, fatigue: 3, fanInterest: 2, growthFocus: .velocity, outcome: "익힌 동작을 경기에서 바로 써 보기로 했습니다.")
        case ("life", .listen): return .init(trust: 4, fatigue: -3, fanInterest: 0, growthFocus: nil, outcome: "가족의 이야기를 먼저 들으며 마음을 가라앉혔습니다.")
        case ("life", .explain): return .init(trust: 3, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "지금의 계획을 차분히 설명했습니다.")
        case ("life", .challenge): return .init(trust: 1, fatigue: 4, fanInterest: 1, growthFocus: nil, outcome: "부족한 시간을 훈련으로 메우기로 했습니다.")
        case ("legacy", .listen): return .init(trust: 3, fatigue: 0, fanInterest: 1, growthFocus: nil, outcome: "가장 좋았던 경기와 힘들었던 경기를 조용히 되짚었습니다.")
        case ("legacy", .explain): return .init(trust: 3, fatigue: 0, fanInterest: 2, growthFocus: .gamePlanning, outcome: "세 해의 기록에서 남길 것을 골라 적었습니다.")
        case ("legacy", .challenge): return .init(trust: 2, fatigue: 2, fanInterest: 2, growthFocus: .command, outcome: "다음 선수에게 남길 한 가지를 분명히 정했습니다.")
        // 환생 사건(2회차부터). 케이스가 없던 동안 세 응답이 전부 default(+2 고정)로
        // 떨어져서, 회차 자각용으로 넣은 장면의 선택지가 장식이었다.
        case ("rebirth", .listen): return .init(trust: 4, fatigue: -4, fanInterest: 0, growthFocus: nil, outcome: "낯익은 감각을 부정하지 않고 받아들이자 마음이 오히려 가라앉았습니다.")
        case ("rebirth", .explain): return .init(trust: 3, fatigue: 0, fanInterest: 0, growthFocus: .gamePlanning, outcome: "몸이 먼저 아는 것들을 노트에 적어 승부 계획으로 바꿨습니다.")
        case ("rebirth", .challenge): return .init(trust: 1, fatigue: 3, fanInterest: 2, growthFocus: .velocity, outcome: "설명할 수 없는 확신을 시험하려고, 그 공을 그 코스에 다시 던져 봤습니다.")
        default: return .init(trust: 2, fatigue: 0, fanInterest: 1, growthFocus: nil, outcome: "이번 일을 차분히 넘기며 마음을 다잡았습니다.")
        }
    }

    private func relationshipCallback(state: HighSchoolCareerSnapshot, report: ImportantInningReport) -> String? {
        guard let event = state.currentRelationshipEvent, state.news.first?.hasPrefix(event.title) == true else { return nil }
        switch event.category {
        case "coach": return report.runsAllowed == 0
            ? "면담 뒤 받은 등판 기회에서 무실점으로 감독의 선택에 답했습니다."
            : "면담 뒤 받은 등판 기회였지만 \(report.runsAllowed)실점으로 경쟁은 계속됩니다."
        case "catcher": return report.recommendationAccepted * 2 >= report.pitches
            ? "포수와 맞춘 사인을 절반 이상 유지해 배터리의 약속을 지켰습니다."
            : "포수 사인을 자주 바꾼 탓에 경기 뒤 다시 승부 순서를 맞추기로 했습니다."
        default: return report.strikeouts > report.walks
            ? "라이벌과 약속한 재대결에서 \(report.strikeouts)개의 삼진을 잡았습니다."
            : "라이벌은 지난 경기에서 본 구종 순서를 다시 읽어냈습니다."
        }
    }

    private func awakeningTitle(_ awakening: AwakeningID) -> String {
        switch awakening {
        case .explosiveFastball: return "폭발하는 포심"
        case .pinpointEdge: return "바늘끝 제구"
        case .disappearingBreaker: return "사라지는 변화구"
        case .ironArm: return "강철의 어깨"
        case .calmUnderPressure: return "고요한 마운드"
        case .batterySync: return "포수와 한마음"
        case .risingFourSeam: return "떠오르는 포심"
        case .sinkerTunnel: return "같은 길에서 갈라지는 공"
        case .frozenChangeup: return "멈춘 체인지업"
        case .sweepingSlider: return "스위퍼 궤도"
        case .curveballClock: return "일정한 커브 타이밍"
        case .repeatableRelease: return "흔들리지 않는 투구 동작"
        case .pickoffRhythm: return "주자를 묶는 리듬"
        case .twoStrikePlan: return "2스트라이크 승부법"
        case .firstPitchStrike: return "초구 스트라이크"
        case .trafficController: return "주자를 두고도 침착하게"
        case .lateInningReserve: return "후반에도 남는 힘"
        case .scoutComposure: return "압박 속 침착함"
        }
    }

    private func awakeningEffect(_ awakening: AwakeningID) -> String {
        switch awakening {
        case .explosiveFastball: return "직구의 위력은 크게 오르지만 제구가 어려워지고 체력이 빨리 줄어듭니다."
        case .risingFourSeam: return "포심 헛스윙이 늘지만 변화구 움직임이 조금 줄어듭니다."
        case .pinpointEdge, .repeatableRelease: return "원하는 코스에 더 꾸준히 던지지만 최고 구속이 조금 줄어듭니다."
        case .firstPitchStrike: return "초구 제구가 좋아지지만 긴 이닝의 여유가 조금 줄어듭니다."
        case .disappearingBreaker, .sweepingSlider, .frozenChangeup, .curveballClock: return "변화구로 헛스윙을 더 잡지만 제구가 어려워지거나 체력이 더 듭니다."
        case .sinkerTunnel: return "포심과 체인지업의 궤도가 닮아 약한 타구를 더 만듭니다."
        case .ironArm, .lateInningReserve: return "공 하나당 체력 소모가 줄고 긴 이닝에 강해집니다."
        case .batterySync: return "포수와 맞춘 코스의 제구와 약한 타구 유도가 좋아집니다."
        case .calmUnderPressure, .pickoffRhythm, .twoStrikePlan, .trafficController, .scoutComposure: return "주자나 2스트라이크처럼 압박이 큰 상황에서 덜 흔들리지만 다른 능력이 조금 줄어듭니다."
        }
    }

    private func gameScenario(for state: HighSchoolCareerSnapshot, seed: UInt64) -> ImportantGameScenarioContent {
        let count = state.performance.importantGamesCompleted
        // 기준값은 회차 안에서 고정이어야 하고(careerID), 보폭은 풀 크기(20)와 서로소여야
        // 한다(7). 예전에는 기준값이 매 행동마다 바뀌는 체인 시드라 어떤 보폭을 써도
        // 생일 문제로 한 회차의 41%가 같은 장면을 두 번 봤다. 회차 고정 기준 + 서로소
        // 보폭이면 경기 20번까지 중복이 없고, 회차가 바뀌면 기준이 바뀐다.
        // 시기 고정 장면은 추첨하지 않고 그 챕터에 놓는다 — "드래프트 전 마지막
        // 이닝"이 1학년 봄에 나오면 첫 하이라이트에서 서사가 3년 뒤를 말한다(QA).
        // 결승은 전국대회 챕터에, 마지막 이닝은 드래프트의 여름에 — 추첨보다 낫다.
        // 상시 장면만 순환시키면 풀 크기가 고정되어 무중복 보장(서로소 보폭)도 산다.
        if state.chapter.number == 8,
           let finale = HighSchoolContentCatalog.scenarios.first(where: { $0.id == "game-one-run" }) {
            return finale
        }
        if state.chapter.number == 4,
           let final = HighSchoolContentCatalog.scenarios.first(where: { $0.id == "game-national-final" }) {
            return final
        }
        let pool = HighSchoolContentCatalog.scenarios.filter { $0.minChapter <= 1 }
        let runBase = UInt64(StableHash.fnv1a64("game_scenario|\(state.careerID)"), radix: 16) ?? seed
        // 보폭 7은 상시 풀 크기(18)와 서로소다. 크기가 변하면 테스트가 막는다.
        let index = (Int(runBase % UInt64(pool.count)) + count * 7) % pool.count
        return pool[index]
    }

    private static func bestTeam(for pitcher: PitcherSnapshot, seed: UInt64) -> DraftTeamSnapshot {
        let values: [TrainingFocus: Int] = [.velocity: pitcher.stuff, .command: pitcher.command, .breakingBall: pitcher.movement,
            .stamina: pitcher.stamina, .gamePlanning: pitcher.command, .recovery: pitcher.stamina]
        return Self.teams.max { lhs, rhs in
            (values[lhs.need, default: 0] * 10 + lhs.demand) < (values[rhs.need, default: 0] * 10 + rhs.demand)
        }!
    }

    private func memoryOptions(state: HighSchoolCareerSnapshot, seed: UInt64, drafted: Bool = false) -> [MemoryCardID] {
        var options = MemoryCardID.allCases
        // Drafted and undrafted runs shuffle from the same pool but on a different salt, so a
        // successful life surfaces a different set of memories than a failed one.
        let outcomeSalt: UInt64 = drafted ? 0x4452_4146_5445_4400 : 0
        var generator = SplitMix64(seed: seed ^ UInt64(state.performance.pitches) ^ 0x4d45_4d4f_5259 ^ outcomeSalt)
        for index in options.indices.reversed() where index > 0 {
            options.swapAt(index, generator.nextInt(upperBound: index + 1))
        }
        return Array(options.prefix(5))
    }

    private func applyCreation(_ allocation: CreationAllocationSnapshot, to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        var value = grow(pitcher, focus: .velocity, points: allocation.stuff)
        value = grow(value, focus: .command, points: allocation.command)
        value = grow(value, focus: .breakingBall, points: allocation.movement)
        return grow(value, focus: .stamina, points: allocation.stamina)
    }

    private func applyKarmas(_ karmas: [KarmaID], to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        guard karmas.contains(.singleWeapon) else { return pitcher }
        let strongest: TrainingFocus = pitcher.stuff >= pitcher.command && pitcher.stuff >= pitcher.movement ? .velocity
            : pitcher.command >= pitcher.movement ? .command : .breakingBall
        var value = grow(pitcher, focus: strongest, points: 3)
        value = PitcherSnapshot(id: value.id, name: value.name, stuff: strongest == .velocity ? value.stuff : max(20, value.stuff - 2),
            command: strongest == .command ? value.command : max(20, value.command - 2),
            movement: strongest == .breakingBall ? value.movement : max(20, value.movement - 2),
            stamina: max(20, value.stamina - 2), pitchProfiles: value.pitchProfiles, throwingHand: value.throwingHand)
        return value
    }

    /// 야구혼이 시작 능력으로 스며드는 회차당 상한.
    ///
    /// 예전에는 누적 야구혼 **전액**이 한 능력에 들어갔다(분야 미선택이면 제구). 첫 회차
    /// 보상(+40~60)만으로 제구가 80에 닿아 2회차와 30회차의 시작 선수가 완전히 같아졌고,
    /// 제구를 올리는 기억 카드 10장이 2회차부터 죽었다 — 환생 루프가 한 번 돌고 멈췄다.
    ///
    /// 저장 호환 v1은 `8 + 총량/60`(최대 20)을 영구 보존한다. 신규 정산용 v2는
    /// `(총량 - 20)/4`(최소 1, 최대 20)로 더 천천히 자란다. 총량은 기록이고,
    /// 스며드는 양은 버전별 상한이 정한다.
    public static func inheritancePointCap(for points: Int) -> Int {
        inheritancePointCap(for: points, rulesVersion: .v1)
    }

    public static func inheritancePointCap(
        for points: Int,
        rulesVersion: SoulInheritanceRulesVersion
    ) -> Int {
        switch rulesVersion {
        case .v1:
            return min(20, 8 + max(0, points) / 60)
        case .v2:
            return min(20, max(1, (max(0, points) - 20) / 4))
        }
    }

    public static func inheritancePointCap(for points: Int, storedRulesVersion: Int?) -> Int {
        inheritancePointCap(
            for: points,
            rulesVersion: .resolve(storedValue: storedRulesVersion)
        )
    }

    /// 잔액이 이번 회차에 실제로 스며드는 양. 정산·상점 화면이 이 값을 쓴다 —
    /// 화면이 상한을 모르고 큰 숫자를 약속하면 게임이 거짓 영수증을 발행하는 셈이다.
    public static func appliedInheritance(for points: Int) -> Int {
        appliedInheritance(for: points, rulesVersion: .v1)
    }

    public static func appliedInheritance(
        for points: Int,
        rulesVersion: SoulInheritanceRulesVersion
    ) -> Int {
        min(max(0, points), inheritancePointCap(for: points, rulesVersion: rulesVersion))
    }

    public static func appliedInheritance(for points: Int, storedRulesVersion: Int?) -> Int {
        appliedInheritance(
            for: points,
            rulesVersion: .resolve(storedValue: storedRulesVersion)
        )
    }

    private func applyInheritance(
        _ points: Int, domain: SoulDomain?, memories: [MemoryCardID],
        talent: inout TalentSnapshot, rulesVersion: SoulInheritanceRulesVersion,
        bonusPoints: Int = 0, to pitcher: PitcherSnapshot
    ) -> PitcherSnapshot {
        var value = pitcher
        var remaining = Self.appliedInheritance(for: points, rulesVersion: rulesVersion)
            + max(0, bonusPoints)

        // 이번 회차의 벽 아래에서만 스며든다. 계승이 벽을 뚫으면 만개(벽이 열리는 순간)가
        // 그 능력에서 영원히 사라진다.
        func headroom(_ focus: TrainingFocus) -> Bool {
            let ability = TalentAbility.from(focus)
            return rating(for: focus, pitcher: value) < min(80, talent.ceiling(ability))
        }

        // 분야를 골랐으면 절반을 그 분야에 먼저 준다. 나머지는 가장 낮은 능력부터 1점씩 —
        // 한 능력 몰빵이 아니라 밑을 끌어올리는 계승이라, 훈련과 기억 카드가 할 일이 남는다.
        if let domain, remaining > 0 {
            let focus: TrainingFocus = domain == .body ? .velocity : domain == .technique ? .command : .gamePlanning
            var share = remaining / 2
            while share > 0, headroom(focus) {
                value = grow(value, focus: focus, points: 1)
                share -= 1
                remaining -= 1
            }
        }
        let rotation: [TrainingFocus] = [.velocity, .command, .breakingBall, .stamina]
        while remaining > 0 {
            let open = rotation.filter(headroom)
            guard let lowest = open.min(by: { rating(for: $0, pitcher: value) < rating(for: $1, pitcher: value) }) else { break }
            value = grow(value, focus: lowest, points: 1)
            remaining -= 1
        }
        // 벽에 막힌 계승분은 소각하지 않는다 — 만개 두드림(압박)으로 스민다.
        // 4점당 1회, 임계 직전까지만: 훈련 없이 공짜 만개가 나면 그건 이월이 아니라
        // 다른 화폐다(4차 패널 P2 — "잔여 계승은 벽을 두드린 흔적으로 남는다").
        if remaining >= 4 {
            let target = TalentAbility.allCases.min {
                talent.grade($0).ceiling != talent.grade($1).ceiling
                    ? talent.grade($0).ceiling < talent.grade($1).ceiling
                    : talent.pressure($0) < talent.pressure($1)
            }
            if let target {
                let knocks = remaining / 4
                let capped = min(talent.grade(target).bloomThreshold - 1,
                                 talent.pressure(target) + knocks)
                talent.setPressure(max(talent.pressure(target), capped), for: target)
            }
        }
        for memory in memories {
            switch memory {
            case .velocityBlueprint: value = tuned(value, stuff: 2, command: -1, pitch: .fourSeam, velocity: 10, whiff: 2)
            case .fingertipMemory: value = tuned(value, movement: 2, stamina: -1, nonFastball: true, profileMovement: 3, whiff: 2)
            case .catcherNotebook: value = tuned(value, command: 2, profileCommand: 1, weakContact: 2)
            case .rivalNotebook: value = tuned(value, command: 1, movement: 1, nonFastball: true, whiff: 2)
            case .recoveryRoutine: value = tuned(value, stamina: 2, fatigueCost: -1)
            case .pressureRehearsal: value = tuned(value, command: 1, stamina: 1, control: 2)
            case .firstPitchMap: value = tuned(value, command: 2, stamina: -1, control: 2)
            case .twoStrikeSequence: value = tuned(value, movement: 2, stamina: -1, nonFastball: true, whiff: 3)
            case .fatigueDiary: value = tuned(value, stamina: 2, control: 1, fatigueCost: -1)
            case .mechanicsVideo: value = tuned(value, stuff: -1, command: 2, control: 3)
            case .schoolPlaybook: value = tuned(value, command: 1, movement: 1, profileCommand: 1)
            case .coachLetter: value = tuned(value, command: 1, stamina: 1)
            case .draftReport: value = tuned(value, stuff: 1, command: 1)
            case .stadiumEcho: value = tuned(value, stuff: 2, command: -1, whiff: 1)
            case .teamFirstPromise: value = tuned(value, command: 1, stamina: 1, weakContact: 2)
            case .failureScorebook: value = tuned(value, command: 2, movement: 1, stamina: -1)
            case .winterProgram: value = tuned(value, stuff: 1, stamina: 2, fatigueCost: -1)
            case .bullpenCompass: value = tuned(value, stuff: 1, stamina: 1, fatigueCost: -1)
            }
        }
        return value
    }

    private func applyAwakening(_ awakening: AwakeningID, to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        switch awakening {
        case .explosiveFastball: return tuned(pitcher, stuff: 4, command: -2, pitch: .fourSeam, velocity: 15, whiff: 5, fatigueCost: 1)
        case .risingFourSeam: return tuned(pitcher, stuff: 3, movement: -1, pitch: .fourSeam, profileMovement: 4, whiff: 6, weakContact: 2)
        case .pinpointEdge: return tuned(pitcher, stuff: -1, command: 4, control: 2, profileCommand: 3)
        case .batterySync: return tuned(pitcher, command: 2, movement: 1, control: 2, profileCommand: 2, weakContact: 3)
        case .repeatableRelease: return tuned(pitcher, stuff: -1, command: 4, control: 3, profileCommand: 2)
        case .firstPitchStrike: return tuned(pitcher, command: 3, stamina: -1, control: 3)
        case .disappearingBreaker: return tuned(pitcher, command: -1, movement: 4, nonFastball: true, profileMovement: 4, whiff: 5)
        case .sinkerTunnel: return tuned(pitcher, movement: 3, pitchSet: [.fourSeam, .changeup], profileMovement: 3, weakContact: 5)
        case .frozenChangeup: return tuned(pitcher, movement: 3, stamina: -1, pitch: .changeup, profileMovement: 6, whiff: 7)
        case .sweepingSlider: return tuned(pitcher, command: -1, movement: 4, pitch: .slider, profileMovement: 7, whiff: 6)
        case .curveballClock: return tuned(pitcher, movement: 4, stamina: -1, pitch: .curveball, profileMovement: 7, whiff: 5)
        case .ironArm: return tuned(pitcher, movement: -1, stamina: 5, fatigueCost: -2)
        case .lateInningReserve: return tuned(pitcher, stamina: 4, pitch: .fourSeam, whiff: 2, fatigueCost: -2)
        case .calmUnderPressure: return tuned(pitcher, command: 2, stamina: 1, control: 2, profileCommand: 2)
        case .pickoffRhythm: return tuned(pitcher, command: 1, stamina: 2, control: 1, weakContact: 1)
        case .twoStrikePlan: return tuned(pitcher, command: 2, movement: 2, stamina: -1, nonFastball: true, whiff: 3)
        case .trafficController: return tuned(pitcher, stuff: -1, command: 2, stamina: 2, weakContact: 3)
        case .scoutComposure: return tuned(pitcher, stuff: 2, command: 2, stamina: -1, control: 1)
        }
    }

    private func tuned(_ pitcher: PitcherSnapshot, stuff: Int = 0, command: Int = 0, movement: Int = 0, stamina: Int = 0,
        pitch: PitchType? = nil, pitchSet: Set<PitchType>? = nil, nonFastball: Bool = false, velocity: Int = 0,
        control: Int = 0, profileCommand: Int = 0, profileMovement: Int = 0, whiff: Int = 0,
        weakContact: Int = 0, fatigueCost: Int = 0) -> PitcherSnapshot {
        let profiles = pitcher.pitchProfiles?.map { profile in
            let matches = pitch.map { profile.pitchType == $0 }
                ?? pitchSet.map { $0.contains(profile.pitchType) }
                ?? (nonFastball ? profile.pitchType != .fourSeam : true)
            return PitchProfileSnapshot(pitchType: profile.pitchType, role: profile.role,
                velocityTenthsKPH: clamp(profile.velocityTenthsKPH + (matches ? velocity : 0), 1_000, 1_700),
                control: clamp(profile.control + (matches ? control : 0), 20, 80),
                command: clamp(profile.command + (matches ? profileCommand : 0), 20, 80),
                movement: clamp(profile.movement + (matches ? profileMovement : 0), 20, 80),
                whiff: clamp(profile.whiff + (matches ? whiff : 0), 20, 80),
                weakContact: clamp(profile.weakContact + (matches ? weakContact : 0), 20, 80),
                fatigueCost: clamp(profile.fatigueCost + (matches ? fatigueCost : 0), 0, 20))
        }
        return PitcherSnapshot(id: pitcher.id, name: pitcher.name,
            stuff: clamp(pitcher.stuff + stuff, 20, 80), command: clamp(pitcher.command + command, 20, 80),
            movement: clamp(pitcher.movement + movement, 20, 80), stamina: clamp(pitcher.stamina + stamina, 20, 80),
            pitchProfiles: profiles, throwingHand: pitcher.throwingHand)
    }

    private func grow(
        _ pitcher: PitcherSnapshot,
        focus: TrainingFocus,
        points: Int,
        balanceVersion: Int? = PitcherPresetCatalog.balanceVersion
    ) -> PitcherSnapshot {
        guard points > 0 else { return pitcher }
        let profiles = pitcher.pitchProfiles?.map { profile in
            // 결정구 완성 — 육성 중 구종이 제구+헛스윙+범타 합 150을 넘으면 실전
            // 구종(secondary)으로 승격한다. 승격 전에는 포수가 승부처에서 안 부르고
            // 대체 후보에서도 빠진다(-120 감점·필터). 로그라이트인데 레퍼토리가
            // 영원히 고정이면 "내 결정구를 만들었다"는 서사가 시스템에 없다.
            let promoted: PitchUsageRole = profile.role == .development
                && profile.command + profile.whiff + profile.weakContact >= 150
                ? .secondary : profile.role
            return PitchProfileSnapshot(pitchType: profile.pitchType, role: promoted,
                velocityTenthsKPH: clamp(profile.velocityTenthsKPH + (focus == .velocity ? points * 5 : 0), 1_000, 1_700),
                control: clamp(profile.control + (focus == .command ? points : 0), 20, 80),
                command: clamp(profile.command + (focus == .command || focus == .gamePlanning ? points : 0), 20, 80),
                movement: clamp(profile.movement + (focus == .breakingBall && profile.pitchType != .fourSeam ? points : 0), 20, 80),
                whiff: clamp(profile.whiff + (focus == .breakingBall && profile.pitchType != .fourSeam ? points : 0), 20, 80),
                weakContact: profile.weakContact,
                // 하한 1 — 피로라는 축 자체를 훈련으로 소거할 수 있으면 투구수 관리가
                // 게임에서 사라진다. 100구를 던지면 팔은 무거워야 한다.
                fatigueCost: focus == .stamina
                    ? ((balanceVersion ?? 1) >= 4
                        ? PitchAbilityRules.reducedFatigueCost(profile.fatigueCost, by: points / 2)
                        : max(1, profile.fatigueCost - points / 2))
                    : profile.fatigueCost)
        }
        return PitcherSnapshot(id: pitcher.id, name: pitcher.name,
            stuff: clamp(pitcher.stuff + (focus == .velocity ? points : 0), 20, 80),
            command: clamp(pitcher.command + (focus == .command || focus == .gamePlanning ? points : 0), 20, 80),
            movement: clamp(pitcher.movement + (focus == .breakingBall ? points : 0), 20, 80),
            stamina: clamp(pitcher.stamina + (focus == .stamina || focus == .recovery ? points : 0), 20, 80), pitchProfiles: profiles, throwingHand: pitcher.throwingHand)
    }

    private func rating(for focus: TrainingFocus, pitcher: PitcherSnapshot) -> Int {
        switch focus {
        case .velocity: return pitcher.stuff
        case .command, .gamePlanning: return pitcher.command
        case .breakingBall: return pitcher.movement
        case .stamina, .recovery: return pitcher.stamina
        }
    }

    /// 한계에 막혔을 때는 그 사실을 말해 준다. 아무 말 없이 0이 뜨면 플레이어는 훈련이
    /// 실패한 줄 알고 같은 곳에 더 넣지 않는다 — 만개는 계속 두드려야 오는데.
    private func blockedFeedback(
        ability: TalentAbility,
        talent: TalentSnapshot,
        growth: Int,
        rawGrowth: Int,
        allowed: Int,
        fatigueChange: Int,
        focus: TrainingFocus
    ) -> String {
        guard rawGrowth > 0, allowed < rawGrowth else {
            return trainingFeedback(focus: focus, growth: growth, fatigueChange: fatigueChange)
        }
        let grade = talent.grade(ability)
        let remaining = max(0, grade.bloomThreshold - talent.pressure(ability))
        let suffix = remaining > 0
            ? " 한 번 더 밀어붙이면 열릴 수도 있습니다(남은 두드림 \(remaining)회)."
            : ""
        return "\(ability.label)\(RelationshipVoiceCatalog.particle(ability.label, final: "이", open: "가")) 지금 재능의 한계(\(grade.ceiling))에 닿아 있습니다.\(suffix)"
    }

    private func trainingFeedback(focus: TrainingFocus, growth: Int, fatigueChange: Int) -> String {
        let metric: String
        switch focus {
        case .velocity: metric = "구위"
        case .command: metric = "제구"
        case .breakingBall: metric = "변화구"
        case .stamina, .recovery: metric = "체력"
        case .gamePlanning: metric = "타자 상대법과 제구"
        }
        if growth > 0 {
            let recovery = fatigueChange < 0 ? " 피로도 \(-fatigueChange) 줄었습니다." : ""
            return "\(metric) 능력치가 \(growth) 올랐습니다.\(recovery)"
        }
        if focus == .recovery && fatigueChange < 0 {
            return "능력치는 그대로지만 피로가 \(-fatigueChange) 줄었습니다."
        }
        return "이번 훈련에서는 능력치가 오르지 않았습니다. 피로와 훈련 강도를 조절해 다시 시도할 수 있습니다."
    }

    private func replacing(_ state: HighSchoolCareerSnapshot, revision: UInt64? = nil,
        phase: HighSchoolCareerPhase? = nil, pitcher: PitcherSnapshot? = nil,
        schoolOptions: [SchoolSnapshot]? = nil, school: SchoolSnapshot? = nil,
        rival: RivalSnapshot? = nil,
        chapter: CareerChapterSnapshot? = nil, chapterTrainingCount: Int? = nil, totalTrainingsCompleted: Int? = nil,
        milestoneIndex: Int? = nil, relationshipsCompleted: Int? = nil, relationshipTrust: Int? = nil,
        managerTrust: Int? = nil, catcherTrust: Int? = nil, rivalTrust: Int? = nil,
        selectedAwakenings: [AwakeningID]? = nil, awakeningOptions: [AwakeningID]? = nil, fatigue: Int? = nil,
        performance: CareerPerformanceSnapshot? = nil, seasonLog: [ProGameLine]?? = nil, lastTraining: CareerTrainingSnapshot? = nil,
        lastRelationship: CareerRelationshipResultSnapshot? = nil,
        currentGameScenario: ImportantGameScenarioContent? = nil,
        currentRelationshipEvent: CareerEventContent? = nil,
        news: [String]? = nil, fanInterest: Int? = nil, draftResult: DraftResultSnapshot? = nil,
        legacyOptions: [MemoryCardID]? = nil, selectedMemories: [MemoryCardID]? = nil,
        balanceVersion: Int? = nil, armRisk: Int? = nil, injuryRecovery: Int? = nil,
        worldRulesVersion: Int?? = nil,
        talent: TalentSnapshot? = nil,
        awakeningSparks: Int?? = nil,
        stateCommitment: String? = nil
    ) -> HighSchoolCareerSnapshot {
        HighSchoolCareerSnapshot(careerID: state.careerID, revision: revision ?? state.revision, lifeNumber: state.lifeNumber,
            phase: phase ?? state.phase, identity: state.identity, difficulty: state.difficulty, karmas: state.karmas,
            legacyRewardPermille: state.legacyRewardPermille, memorySlots: state.memorySlots,
            pitcher: pitcher ?? state.pitcher, schoolOptions: schoolOptions ?? state.schoolOptions,
            school: school ?? state.school, rival: rival ?? state.rival, chapter: chapter ?? state.chapter,
            chapterTrainingCount: chapterTrainingCount ?? state.chapterTrainingCount,
            totalTrainingsCompleted: totalTrainingsCompleted ?? state.totalTrainingsCompleted,
            milestoneIndex: milestoneIndex ?? state.milestoneIndex,
            relationshipsCompleted: relationshipsCompleted ?? state.relationshipsCompleted,
            relationshipTrust: relationshipTrust ?? state.relationshipTrust,
            managerTrust: managerTrust ?? state.managerTrust,
            catcherTrust: catcherTrust ?? state.catcherTrust,
            rivalTrust: rivalTrust ?? state.rivalTrust,
            selectedAwakenings: selectedAwakenings ?? state.selectedAwakenings,
            awakeningOptions: awakeningOptions ?? state.awakeningOptions, fatigue: fatigue ?? state.fatigue,
            performance: performance ?? state.performance, seasonLog: seasonLog ?? state.seasonLog,
            currentGameScenario: currentGameScenario ?? state.currentGameScenario,
            currentRelationshipEvent: currentRelationshipEvent ?? state.currentRelationshipEvent,
            lastTraining: lastTraining ?? state.lastTraining,
            lastRelationship: lastRelationship ?? state.lastRelationship,
            news: news ?? state.news, fanInterest: fanInterest ?? state.fanInterest,
            draftResult: draftResult ?? state.draftResult, legacyOptions: legacyOptions ?? state.legacyOptions,
            selectedMemories: selectedMemories ?? state.selectedMemories,
            balanceVersion: balanceVersion ?? state.balanceVersion,
            worldRulesVersion: worldRulesVersion ?? state.worldRulesVersion,
            armRisk: armRisk ?? state.armRisk, injuryRecovery: injuryRecovery ?? state.injuryRecovery,
            schedule: state.schedule,
            trainingOpportunity: Self.trainingOpportunity(
                careerID: state.careerID,
                index: totalTrainingsCompleted ?? state.totalTrainingsCompleted),
            talent: talent ?? state.talent,
            soulBoosts: state.soulBoosts,
            awakeningSparks: awakeningSparks ?? state.awakeningSparks,
            stateCommitment: stateCommitment ?? state.stateCommitment)
    }

    static let opportunityReasons: [TrainingFocus: [String]] = [
        .velocity: ["어제 불펜에서 팔 스윙이 가벼웠다. 오늘 직구를 밀어붙이자.", "하체 힘이 붙었다. 구속을 끌어올릴 타이밍이다.", "공 끝이 살아 있다. 오늘은 세게 던져 보자."],
        .command: ["포수가 미트를 거의 안 움직였다. 코스 훈련이 먹힐 날이다.", "던지는 리듬이 잡혔다. 오늘 존 구석을 노리자.", "밸런스가 좋다. 원하는 곳에 꽂는 연습을 늘리자."],
        .breakingBall: ["어제 변화구 회전이 좋았다. 오늘 확실히 내 것으로 만들자.", "손끝 감각이 살아 있다. 변화구를 다듬을 기회다.", "타자들이 변화구에 늦게 반응했다. 오늘 더 벼리자."],
        .stamina: ["긴 이닝을 버틸 몸을 만들 적기다.", "회복이 빨라졌다. 오늘 체력 훈련이 잘 붙는다.", "다음 등판까지 여유가 있다. 체력을 쌓자."],
        .recovery: ["팔이 무겁다는 신호다. 오늘은 회복이 최고의 훈련이다.", "쉬는 것도 실력이다. 몸을 만들 날이다.", "피로가 쌓였다. 오늘 회복하면 내일이 달라진다."],
        .gamePlanning: ["상대 타선 기록이 도착했다. 오늘 파고들자.", "포수와 사인을 맞출 시간이 났다. 수 싸움을 늘리자.", "경기 감각이 올라 있다. 상대 분석이 잘 먹힌다."],
    ]

    static func trainingOpportunity(careerID: String, index: Int) -> TrainingOpportunitySnapshot {
        let focusPool = TrainingFocus.allCases
        let seedValue = StableHash.fnv1a64Value("\(careerID)|opportunity|\(index)")
        var pick = Int(seedValue % UInt64(focusPool.count))
        if index > 0 {
            let previous = Int(StableHash.fnv1a64Value("\(careerID)|opportunity|\(index - 1)") % UInt64(focusPool.count))
            if pick == previous { pick = (pick + 1) % focusPool.count }
        }
        let focus = focusPool[pick]
        let reasons = Self.opportunityReasons[focus] ?? []
        let reason = reasons.isEmpty ? "" : reasons[Int((seedValue >> 8) % UInt64(reasons.count))]
        return TrainingOpportunitySnapshot(focus: focus, reason: reason)
    }

    private func signed(_ state: HighSchoolCareerSnapshot) -> HighSchoolCareerSnapshot {
        replacing(state, stateCommitment: commitment(state))
    }

    private func commitment(_ state: HighSchoolCareerSnapshot) -> String {
        let school = state.school?.id.rawValue ?? "none"
        let ratings = "\(state.pitcher.stuff):\(state.pitcher.command):\(state.pitcher.movement):\(state.pitcher.stamina)"
        let performance = "\(state.performance.importantGamesCompleted):\(state.performance.pitches):\(state.performance.strikeouts):\(state.performance.walks):\(state.performance.runsAllowed):\(state.performance.expectedDamage):\(state.performance.actualDamage)"
        let scenario = state.currentGameScenario?.id ?? "none"
        let draft = state.draftResult.map { "\($0.outcome.rawValue):\($0.evaluationScore):\($0.team?.id ?? "none")" } ?? "none"
        var canonical: [String] = [state.careerID, String(state.revision), state.phase.rawValue,
            state.identity.name, state.identity.throwingHand.rawValue, state.identity.bodyType.rawValue, state.identity.region, school,
            state.difficulty.careerHarshness.rawValue, state.difficulty.informationClarity.rawValue,
            state.difficulty.simulationDifficulty.rawValue, state.difficulty.interventionAssist.rawValue,
            state.karmas.map(\.rawValue).joined(separator: ","), String(state.legacyRewardPermille), String(state.memorySlots),
            String(state.chapter.number), String(state.chapterTrainingCount), String(state.totalTrainingsCompleted),
            String(state.milestoneIndex), String(state.relationshipsCompleted), String(state.relationshipTrust),
            state.selectedAwakenings.map(\.rawValue).joined(separator: ","), state.awakeningOptions.map(\.rawValue).joined(separator: ","),
            String(state.fatigue), ratings, performance, scenario, draft, state.legacyOptions.map(\.rawValue).joined(separator: ","),
            state.selectedMemories.map(\.rawValue).joined(separator: ",")]
        if state.rivalTrust != nil {
            canonical.append("relationships:\(state.managerTrust ?? state.relationshipTrust):\(state.catcherTrust ?? state.relationshipTrust):\(state.rivalTrust ?? state.relationshipTrust)")
        } else if state.managerTrust != nil || state.catcherTrust != nil {
            canonical.append("staff:\(state.managerTrust ?? state.relationshipTrust):\(state.catcherTrust ?? state.relationshipTrust)")
        }
        if let balanceVersion = state.balanceVersion {
            canonical.append("balance_version:\(balanceVersion)")
        }
        // Missing means shipped v1 and must retain the exact old canonical hash. Once a version is
        // stored, it is integrity-protected so a save cannot flip its world rules without detection.
        if let worldRulesVersion = state.worldRulesVersion {
            canonical.append("world_rules_version:\(worldRulesVersion)")
        }
        // Overwork/injury fields are appended only when present so pre-feature saves — which lack
        // them (nil) — still hash to their stored commitment. Mirrors the focusStreak precedent.
        if let armRisk = state.armRisk {
            canonical.append("arm_risk:\(armRisk)")
        }
        if let injuryRecovery = state.injuryRecovery {
            canonical.append("injury_recovery:\(injuryRecovery)")
        }
        if let awakeningSparks = state.awakeningSparks {
            canonical.append("awakening_sparks:\(awakeningSparks)")
        }
        if let soulBoosts = state.soulBoosts, !soulBoosts.isEmpty {
            canonical.append("soul_boosts:\(soulBoosts.joined(separator: ","))")
        }
        // 스케줄 필드도 있을 때만 덧붙여, 이 기능 이전(스케줄 없음) 저장본이 기존 커밋먼트로 그대로
        // 검증되게 한다. 팔·focusStreak 필드와 같은 조건부 계열이다.
        if let schedule = state.schedule {
            canonical.append("schedule:\(schedule.commitmentToken)")
        }
        if let relationship = state.lastRelationship {
            let relationshipValues: [String] = [
                "last_relationship", String(relationship.number), relationship.category, relationship.title,
                relationship.response.rawValue, String(relationship.trustBefore), String(relationship.trustAfter),
                String(relationship.fatigueBefore), String(relationship.fatigueAfter),
                String(relationship.fanInterestBefore), String(relationship.fanInterestAfter),
                relationship.growthFocus?.rawValue ?? "none", relationship.abilityBefore.map(String.init) ?? "none",
                relationship.abilityAfter.map(String.init) ?? "none", relationship.feedback,
                "current_fan_interest", String(state.fanInterest)
            ]
            canonical.append(relationshipValues.joined(separator: ":"))
        }
        return StableHash.fnv1a64(canonical.joined(separator: "|"))
    }

    private func migrate(_ training: CareerTrainingSnapshot?, ratingOffsets: [TrainingFocus: Int]) -> CareerTrainingSnapshot? {
        guard let training else { return nil }
        let offset = ratingOffsets[training.focus, default: 0]
        return CareerTrainingSnapshot(
            number: training.number, focus: training.focus, intensity: training.intensity,
            growth: training.growth, fatigueChange: training.fatigueChange, feedback: training.feedback,
            metricBefore: training.metricBefore.map { clamp($0 + offset, 20, 80) },
            metricAfter: training.metricAfter.map { clamp($0 + offset, 20, 80) },
            fatigueBefore: training.fatigueBefore, fatigueAfter: training.fatigueAfter
        )
    }

    private func migrate(_ relationship: CareerRelationshipResultSnapshot?, ratingOffsets: [TrainingFocus: Int]) -> CareerRelationshipResultSnapshot? {
        guard let relationship else { return nil }
        let offset = relationship.growthFocus.flatMap { ratingOffsets[$0] } ?? 0
        return CareerRelationshipResultSnapshot(
            number: relationship.number, category: relationship.category, title: relationship.title,
            response: relationship.response, trustBefore: relationship.trustBefore, trustAfter: relationship.trustAfter,
            fatigueBefore: relationship.fatigueBefore, fatigueAfter: relationship.fatigueAfter,
            fanInterestBefore: relationship.fanInterestBefore, fanInterestAfter: relationship.fanInterestAfter,
            growthFocus: relationship.growthFocus,
            abilityBefore: relationship.abilityBefore.map { clamp($0 + offset, 20, 80) },
            abilityAfter: relationship.abilityAfter.map { clamp($0 + offset, 20, 80) }, feedback: relationship.feedback
        )
    }

    private func validate(_ state: HighSchoolCareerSnapshot, phase: HighSchoolCareerPhase) throws {
        guard state.phase == phase else {
            throw SimulationError.invalidPitcherLab("career state or phase is invalid")
        }
        try validateState(state)
    }

    private func validateState(_ state: HighSchoolCareerSnapshot) throws {
        // 관계는 스펙상 4–6회이므로 상한을 6으로 둔다. 옛 저장본(≤5)도 그대로 유효하다.
        let relationshipResultIsValid = state.lastRelationship.map { relationship in
            relationship.number == state.relationshipsCompleted
                && (1...6).contains(relationship.number)
                && ["coach", "catcher", "rival"].contains(relationship.category)
                && !relationship.title.isEmpty && !relationship.feedback.isEmpty
                && (0...100).contains(relationship.trustBefore) && (0...100).contains(relationship.trustAfter)
                && (0...100).contains(relationship.fatigueBefore) && (0...100).contains(relationship.fatigueAfter)
                && (0...100).contains(relationship.fanInterestBefore) && (0...100).contains(relationship.fanInterestAfter)
                && (relationship.abilityBefore.map({ (20...80).contains($0) }) ?? true)
                && (relationship.abilityAfter.map({ (20...80).contains($0) }) ?? true)
                && (relationship.abilityBefore == nil) == (relationship.abilityAfter == nil)
        } ?? true
        // 스케줄이 있으면 구조를 확인해(8챕터·각 챕터 훈련 ≥1·스펙 총량) 손상 저장본이 엔진 인덱싱을
        // 깨뜨리지 않게 한다. 없으면(옛 저장본) 고정 뼈대로 읽으므로 검사 대상이 아니다.
        let scheduleIsValid = state.schedule.map { schedule in
            schedule.trainingsByChapter.count == 8 && schedule.milestonesByChapter.count == 8
                && schedule.trainingsByChapter.allSatisfy { $0 >= 1 }
                && (12...16).contains(schedule.trainingTotal)
                && (4...6).contains(schedule.relationshipTotal)
                && (4...6).contains(schedule.importantGameTotal)
                && schedule.awakeningTotal == 3
        } ?? true
        let worldRulesVersionIsValid = state.worldRulesVersion.map {
            CareerRulesVersion(rawValue: $0) != nil
        } ?? true
        guard state.stateCommitment == commitment(state),
              (0...16).contains(state.totalTrainingsCompleted), (0...6).contains(state.relationshipsCompleted),
              (0...100).contains(state.fatigue), (0...100).contains(state.relationshipTrust),
              state.managerTrust.map({ (0...100).contains($0) }) ?? true,
              state.catcherTrust.map({ (0...100).contains($0) }) ?? true,
              state.rivalTrust.map({ (0...100).contains($0) }) ?? true,
              relationshipResultIsValid, scheduleIsValid, worldRulesVersionIsValid else {
            throw SimulationError.invalidPitcherLab("career state or phase is invalid")
        }
    }

    private func validatedSeed(_ value: String) throws -> UInt64 {
        guard let seed = UInt64(value) else { throw SimulationError.invalidSeed(value) }
        return seed
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(upper, max(lower, value))
    }

    private func renamed(_ name: String, pitcher: PitcherSnapshot, hand: ThrowingHand? = nil) -> PitcherSnapshot {
        PitcherSnapshot(id: pitcher.id, name: name, stuff: pitcher.stuff, command: pitcher.command,
            movement: pitcher.movement, stamina: pitcher.stamina, pitchProfiles: pitcher.pitchProfiles, throwingHand: hand ?? pitcher.throwingHand)
    }

    private func result(seed: UInt64, state: HighSchoolCareerSnapshot, event: String, reasons: [String] = []) -> HighSchoolCareerResult {
        var generator = SplitMix64(seed: seed ^ UInt64(state.revision) ^ 0x4556_454e_5400)
        let nextSeed = String(generator.next())
        let events = [HighSchoolCareerEvent(eventType: event, reasonCodes: reasons)]
        let eventHash = StableHash.fnv1a64("\(state.careerID)|\(state.revision)|\(event)|\(nextSeed)|\(state.stateCommitment)")
        return HighSchoolCareerResult(revision: state.revision, nextSeed: nextSeed, events: events, snapshot: state, eventHash: eventHash)
    }
}
