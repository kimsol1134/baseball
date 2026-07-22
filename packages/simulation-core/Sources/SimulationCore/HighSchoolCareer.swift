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
        name: "문동윤", throwingHand: .right, bodyType: .balanced, region: "서울"
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

public struct SchoolSnapshot: Codable, Equatable, Sendable {
    public let id: SchoolID
    public let name: String
    public let philosophy: String
    public let coachName: String
    public let coachArchetype: String
    public let catcherName: String
    public let catcherArchetype: String
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

    public init(id: String, name: String, archetype: String, contact: Int, discipline: Int, power: Int) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.contact = contact
        self.discipline = discipline
        self.power = power
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

    public init(
        id: String,
        name: String,
        need: TrainingFocus,
        demand: Int,
        developmentPlan: String,
        positionCompetitor: String,
        proCoach: String
    ) {
        self.id = id
        self.name = name
        self.need = need
        self.demand = demand
        self.developmentPlan = developmentPlan
        self.positionCompetitor = positionCompetitor
        self.proCoach = proCoach
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
        self.summary = summary
    }
}

public struct CareerTrainingSnapshot: Codable, Equatable, Sendable {
    public let number: Int
    public let focus: TrainingFocus
    public let intensity: TrainingIntensity
    public let growth: Int
    public let fatigueChange: Int
    public let feedback: String

    public init(number: Int, focus: TrainingFocus, intensity: TrainingIntensity, growth: Int, fatigueChange: Int, feedback: String) {
        self.number = number
        self.focus = focus
        self.intensity = intensity
        self.growth = growth
        self.fatigueChange = fatigueChange
        self.feedback = feedback
    }
}

public struct HighSchoolCareerSnapshot: Codable, Equatable, Sendable {
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
    public let selectedAwakenings: [AwakeningID]
    public let awakeningOptions: [AwakeningID]
    public let fatigue: Int
    public let performance: CareerPerformanceSnapshot
    public let currentGameScenario: ImportantGameScenarioContent?
    public let currentRelationshipEvent: CareerEventContent?
    public let lastTraining: CareerTrainingSnapshot?
    public let news: [String]
    public let fanInterest: Int
    public let draftResult: DraftResultSnapshot?
    public let legacyOptions: [MemoryCardID]
    public let selectedMemories: [MemoryCardID]
    public let stateCommitment: String

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
        selectedAwakenings: [AwakeningID],
        awakeningOptions: [AwakeningID],
        fatigue: Int,
        performance: CareerPerformanceSnapshot,
        currentGameScenario: ImportantGameScenarioContent?,
        currentRelationshipEvent: CareerEventContent?,
        lastTraining: CareerTrainingSnapshot?,
        news: [String],
        fanInterest: Int,
        draftResult: DraftResultSnapshot?,
        legacyOptions: [MemoryCardID],
        selectedMemories: [MemoryCardID],
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
        self.selectedAwakenings = selectedAwakenings
        self.awakeningOptions = awakeningOptions
        self.fatigue = fatigue
        self.performance = performance
        self.currentGameScenario = currentGameScenario
        self.currentRelationshipEvent = currentRelationshipEvent
        self.lastTraining = lastTraining
        self.news = news
        self.fanInterest = fanInterest
        self.draftResult = draftResult
        self.legacyOptions = legacyOptions
        self.selectedMemories = selectedMemories
        self.stateCommitment = stateCommitment
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
        karmas: [KarmaID] = []
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
    public init(seed: String, state: HighSchoolCareerSnapshot, memoryCards: [MemoryCardID]) {
        self.seed = seed; self.state = state; self.memoryCards = memoryCards
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
    public static let chapters: [CareerChapterSnapshot] = [
        .init(number: 1, title: "낯선 마운드", schoolYear: 1, season: "봄", theme: "첫 고교 훈련과 첫 공식 등판이 기다린다"),
        .init(number: 2, title: "첫 번째 증명", schoolYear: 1, season: "여름", theme: "여름 대회 엔트리와 맡을 보직이 정해진다"),
        .init(number: 3, title: "첫 겨울", schoolYear: 1, season: "겨울", theme: "봄이 오기 전까지 가장 부족한 한 가지를 다듬는다"),
        .init(number: 4, title: "전국의 시선", schoolYear: 2, season: "봄", theme: "전국대회에서 라이벌과 다시 만난다"),
        .init(number: 5, title: "흔들리는 배터리", schoolYear: 2, season: "여름", theme: "포수와 자꾸 엇갈리는 사인을 바로잡아야 한다"),
        .init(number: 6, title: "에이스의 책임", schoolYear: 2, season: "가을", theme: "피로가 쌓인 채 가을 대회 마운드에 오른다"),
        .init(number: 7, title: "마지막 겨울", schoolYear: 3, season: "겨울", theme: "스카우트가 지켜볼 마지막 시즌을 준비한다"),
        .init(number: 8, title: "드래프트 데이", schoolYear: 3, season: "여름", theme: "마지막 전국대회를 치르고 드래프트 결과를 기다린다")
    ]

    public static let schools: [SchoolSnapshot] = [
        .init(id: .hanbitTraditional, name: "부산해남고", philosophy: "기본기와 긴 이닝", coachName: "김성곤", coachArchetype: "원칙형", catcherName: "강민준", catcherArchetype: "안정형", strength: .stamina, tradeoff: "새 구종을 시험할 기회가 적습니다."),
        .init(id: .miraeAnalytics, name: "서울덕성고", philosophy: "데이터와 경기 설계", coachName: "염경윤", coachArchetype: "분석형", catcherName: "양의준", catcherArchetype: "분석형", strength: .gamePlanning, tradeoff: "데이터가 적을 때 판단이 흔들릴 수 있습니다."),
        .init(id: .haedongPower, name: "광주동진고", philosophy: "출력과 공격적인 승부", coachName: "선동현", coachArchetype: "승부형", catcherName: "김상준", catcherArchetype: "공격형", strength: .velocity, tradeoff: "피로와 제구 비용을 감수해야 합니다."),
        .init(id: .cheongamDevelopment, name: "인천제문고", philosophy: "개인별 폼과 변화구 육성", coachName: "김태현", coachArchetype: "육성형", catcherName: "박경원", catcherArchetype: "공감형", strength: .breakingBall, tradeoff: "팀이 연패하면 개인 훈련 시간이 줄어듭니다.")
    ]

    public static let teams: [DraftTeamSnapshot] = [
        .init(id: "seoul_comets", name: "잠실 트윈스타즈", need: .command, demand: 72, developmentPlan: "2군 선발 로테이션에서 커맨드 완성", positionCompetitor: "임찬윤", proCoach: "류지훈"),
        .init(id: "busan_marines", name: "사직 자이언스", need: .stamina, demand: 66, developmentPlan: "긴 이닝형 선발 육성", positionCompetitor: "박세준", proCoach: "김태현"),
        .init(id: "incheon_waves", name: "문학 랜딩스", need: .breakingBall, demand: 70, developmentPlan: "결정구 한 종을 프로 수준으로 강화", positionCompetitor: "김강윤", proCoach: "이승용"),
        .init(id: "daegu_forge", name: "대구 라이온하츠", need: .velocity, demand: 75, developmentPlan: "출력 유지와 불펜 조기 데뷔", positionCompetitor: "원태윤", proCoach: "박진문"),
        .init(id: "daejeon_rockets", name: "대전 이글윙스", need: .gamePlanning, demand: 68, developmentPlan: "배터리 게임 플랜 중심 선발 육성", positionCompetitor: "문동윤", proCoach: "김경민"),
        .init(id: "gwangju_phoenix", name: "광주 타이곤즈", need: .breakingBall, demand: 64, developmentPlan: "변화구 터널과 약한 타구 강화", positionCompetitor: "이의준", proCoach: "이범준"),
        .init(id: "suwon_guardians", name: "수원 위저즈", need: .command, demand: 61, developmentPlan: "볼넷 억제 후 1군 롱릴리프", positionCompetitor: "고영준", proCoach: "이강준"),
        .init(id: "changwon_meteors", name: "창원 다이너스", need: .velocity, demand: 69, developmentPlan: "포심 형태와 최고 구속 동시 개발", positionCompetitor: "구창윤", proCoach: "이호진"),
        .init(id: "jeonju_hanok", name: "고척 히어로스", need: .stamina, demand: 58, developmentPlan: "체력 기반 선발 후보 경쟁", positionCompetitor: "안우준", proCoach: "홍원준"),
        .init(id: "jeju_storm", name: "잠실 베어킹스", need: .gamePlanning, demand: 63, developmentPlan: "데이터 적응형 스윙맨 육성", positionCompetitor: "곽민재", proCoach: "이승준")
    ]

    public init() {}

    public func start(_ params: StartHighSchoolCareerParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed)
        guard let preset = PitcherPresetCatalog.all.first(where: { $0.id == params.presetID }) else {
            throw SimulationError.invalidPitcherLab("unknown career pitcher preset")
        }
        guard params.creationAllocation.total == 5, params.inheritedMemories.count <= 3,
              params.karmas.count == Set(params.karmas).count, params.karmas.count <= 2,
              !params.identity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !params.identity.region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SimulationError.invalidPitcherLab("career creation or inherited memories are invalid")
        }
        var pitcher = renamed(params.identity.name, pitcher: applyCreation(params.creationAllocation, to: preset.pitcher))
        pitcher = applyInheritance(params.inheritedSoulPoints, domain: params.inheritedSoulDomain, memories: params.inheritedMemories, to: pitcher)
        pitcher = applyKarmas(params.karmas, to: pitcher)
        let rewardPermille = 1_000 + params.karmas.reduce(0) { $0 + $1.rewardPermille }
        let memorySlots = params.karmas.contains(.erasedMemory) ? 2 : 3
        let base = HighSchoolCareerSnapshot(
            careerID: "career-\(params.seed)-life-\(params.lifeNumber)", revision: 0, lifeNumber: params.lifeNumber,
            phase: .prologue, identity: params.identity, difficulty: params.difficulty, karmas: params.karmas,
            legacyRewardPermille: rewardPermille, memorySlots: memorySlots,
            pitcher: pitcher, schoolOptions: Self.schools, school: nil,
            rival: rival(seed: seed, difficulty: params.difficulty.simulationDifficulty, karmas: params.karmas), chapter: Self.chapters[0], chapterTrainingCount: 0,
            totalTrainingsCompleted: 0, milestoneIndex: 0, relationshipsCompleted: 0,
            relationshipTrust: 50, selectedAwakenings: [], awakeningOptions: [], fatigue: 5,
            performance: CareerPerformanceSnapshot(), currentGameScenario: nil, currentRelationshipEvent: nil, lastTraining: nil,
            news: ["중학교 마지막 대회에서 보여준 공이 네 학교의 관심을 끌었습니다."], fanInterest: 5,
            draftResult: nil, legacyOptions: [], selectedMemories: [], stateCommitment: ""
        )
        return result(seed: seed, state: signed(base), event: "high_school_career_started")
    }

    public func completePrologue(_ params: AdvanceCareerChapterParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .prologue)
        let identity = params.state.identity
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .schoolSelection,
            news: ["고교 진학 제안 도착 · \(identity.name) · 4개 학교"] + params.state.news)
        return result(seed: seed, state: signed(next), event: "middle_school_prologue_completed")
    }

    public func chooseSchool(_ params: ChooseSchoolParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .schoolSelection)
        guard let school = params.state.schoolOptions.first(where: { $0.id == params.schoolID }) else {
            throw SimulationError.invalidPitcherLab("school is not available")
        }
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .training, school: school,
            news: ["\(school.name) 입학이 확정됐습니다. \(school.coachName) 감독은 첫 훈련부터 ‘\(school.philosophy)’을 강조했습니다."] + params.state.news)
        return result(seed: seed, state: signed(next), event: "school_selected", reasons: ["school.\(school.id.rawValue)"])
    }

    public func commitTraining(_ params: CommitCareerTrainingParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .training)
        guard params.state.school != nil, params.state.chapterTrainingCount < 2, params.state.totalTrainingsCompleted < 16 else {
            throw SimulationError.invalidPitcherLab("career training is out of order")
        }
        let number = params.state.totalTrainingsCompleted + 1
        var generator = SplitMix64(seed: seed ^ UInt64(number) ^ 0x4341_5245_4552)
        let base = params.intensity == .light ? 130 : params.intensity == .standard ? 210 : 280
        let schoolBonus = params.state.school?.strength == params.focus ? 110 : 0
        let fatiguePenalty = max(0, params.state.fatigue - 45) * 3
        let signal = max(60, base + schoolBonus - fatiguePenalty + generator.nextInt(upperBound: 91) - 45)
        let growth = signal >= 430 ? 2 : signal >= 260 ? 1 : 0
        let pitcher = grow(params.state.pitcher, focus: params.focus, points: growth)
        let fatigueCost = params.intensity == .light ? 3 : params.intensity == .standard ? 8 : 15
        let recovery = params.focus == .recovery ? 18 : 0
        let fatigue = clamp(params.state.fatigue + fatigueCost - recovery, 0, 100)
        let training = CareerTrainingSnapshot(number: number, focus: params.focus, intensity: params.intensity,
            growth: growth, fatigueChange: fatigue - params.state.fatigue,
            feedback: growth > 0 ? "훈련 전보다 공의 힘과 동작이 분명히 좋아졌습니다." : "능력치는 그대로지만 같은 동작을 반복하는 횟수가 늘었습니다.")
        let chapterCount = params.state.chapterTrainingCount + 1
        let phase: HighSchoolCareerPhase = chapterCount == 2 ? milestone(for: params.state.chapter.number, index: 0) : .training
        let optionState = replacing(params.state, pitcher: pitcher, fatigue: fatigue, lastTraining: training)
        let options = phase == .awakening ? awakeningOptions(state: optionState, seed: seed) : []
        let scenario = phase == .importantGame ? gameScenario(for: params.state, seed: seed) : nil
        let relationshipEvent = phase == .relationship ? relationshipEvent(for: params.state, seed: seed) : nil
        let next = replacing(params.state, revision: params.state.revision + 1, phase: phase, pitcher: pitcher,
            chapterTrainingCount: chapterCount, totalTrainingsCompleted: number, awakeningOptions: options,
            fatigue: fatigue, performance: params.state.performance, lastTraining: training, currentGameScenario: scenario,
            currentRelationshipEvent: relationshipEvent)
        return result(seed: seed, state: signed(next), event: "career_training_completed", reasons: ["training.\(params.focus.rawValue)"])
    }

    public func resolveRelationship(_ params: ResolveCareerRelationshipParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .relationship)
        let impact = relationshipImpact(state: params.state, response: params.response)
        let isCoach = (params.state.currentRelationshipEvent?.category ?? "coach") == "coach"
        let trustChange = params.state.karmas.contains(.stubbornCoach) && isCoach && impact.trust < 0
            ? impact.trust * 2 : impact.trust
        let pitcher = impact.growthFocus.map { grow(params.state.pitcher, focus: $0, points: 1) }
            ?? params.state.pitcher
        let nextBase = replacing(params.state, revision: params.state.revision + 1,
            pitcher: pitcher,
            relationshipsCompleted: params.state.relationshipsCompleted + 1,
            relationshipTrust: clamp(params.state.relationshipTrust + trustChange, 0, 100),
            fatigue: clamp(params.state.fatigue + impact.fatigue, 0, 100),
            news: [relationshipNews(state: params.state, response: params.response, seed: seed, impact: impact)] + params.state.news,
            fanInterest: clamp(params.state.fanInterest + impact.fanInterest, 0, 100))
        let next = advanceMilestone(nextBase, seed: seed)
        return result(seed: seed, state: signed(next), event: "career_relationship_resolved", reasons: ["relationship.\(params.response.rawValue)"])
    }

    public func recordImportantGame(_ params: RecordCareerGameParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .importantGame)
        let expected = params.state.performance.importantGamesCompleted + 1
        guard params.report.scenarioNumber == expected, params.report.pitches > 0, params.report.recommendationAccepted <= params.report.pitches else {
            throw SimulationError.invalidPitcherLab("career important game report is invalid")
        }
        let performance = params.state.performance.adding(params.report)
        let interest = clamp(params.state.fanInterest + max(2, params.report.strikeouts * 2 - params.report.runsAllowed * 2), 0, 100)
        let headline = params.report.runsAllowed == 0
            ? "\(params.state.pitcher.name), \(params.state.rival.name)과의 승부에서 무실점"
            : "\(params.state.pitcher.name), \(params.report.strikeouts)탈삼진 · \(params.report.walks)볼넷 · \(params.report.runsAllowed)실점"
        let callback = relationshipCallback(state: params.state, report: params.report)
        let nextBase = replacing(params.state, revision: params.state.revision + 1,
            fatigue: clamp(params.state.fatigue + max(3, params.report.pitches / 3), 0, 100),
            performance: performance, news: ([headline] + (callback.map { [$0] } ?? []) + params.state.news), fanInterest: interest)
        let next = advanceMilestone(nextBase, seed: seed)
        return result(seed: seed, state: signed(next), event: "career_important_game_completed", reasons: ["important_game.\(expected)"])
    }

    public func chooseAwakening(_ params: ChooseCareerAwakeningParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .awakening)
        guard params.state.awakeningOptions.contains(params.awakening), !params.state.selectedAwakenings.contains(params.awakening) else {
            throw SimulationError.invalidPitcherLab("career awakening is not available")
        }
        let nextBase = replacing(params.state, revision: params.state.revision + 1,
            pitcher: applyAwakening(params.awakening, to: params.state.pitcher),
            selectedAwakenings: params.state.selectedAwakenings + [params.awakening], awakeningOptions: [],
            news: ["‘\(awakeningTitle(params.awakening))’을 익혔습니다. \(awakeningEffect(params.awakening))"] + params.state.news)
        let next = advanceMilestone(nextBase, seed: seed)
        return result(seed: seed, state: signed(next), event: "career_awakening_selected", reasons: ["awakening.\(params.awakening.rawValue)"])
    }

    public func advanceChapter(_ params: AdvanceCareerChapterParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .chapterReview)
        guard params.state.chapter.number < 8 else { throw SimulationError.invalidPitcherLab("final chapter cannot advance") }
        let chapter = Self.chapters[params.state.chapter.number]
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .training,
            chapter: chapter, chapterTrainingCount: 0, milestoneIndex: 0,
            news: ["\(chapter.title) — \(chapter.theme)."] + params.state.news)
        return result(seed: seed, state: signed(next), event: "career_chapter_advanced", reasons: ["chapter.\(chapter.number)"])
    }

    public func resolveDraft(_ params: ResolveDraftParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .draft)
        var generator = SplitMix64(seed: seed ^ 0x4452_4146_5400)
        let ratings = params.state.pitcher.stuff + params.state.pitcher.command + params.state.pitcher.movement + params.state.pitcher.stamina
        let gameQuality = params.state.performance.strikeouts * 3 - params.state.performance.walks * 2 - params.state.performance.runsAllowed * 3
        let processBonus = max(-8, min(10, (params.state.performance.expectedDamage - params.state.performance.actualDamage) / 350))
        let ratingScore = ratings / 4
        let performanceScore = gameQuality / 5
        let awakeningScore = params.state.selectedAwakenings.count * 2
        let relationshipScore = (params.state.relationshipTrust - 50) / 10
        let variance = generator.nextInt(upperBound: 9) - 4
        let karmaPenalty = (params.state.karmas.contains(.unknownLand) ? 3 : 0)
            + (params.state.karmas.contains(.noLastChance) ? 2 : 0)
        let score = clamp(ratingScore + performanceScore + processBonus + awakeningScore + relationshipScore + variance - karmaPenalty, 20, 95)
        let threshold = params.state.difficulty.careerHarshness == .relaxed ? 57
            : params.state.difficulty.careerHarshness == .challenging ? 65 : 61
        let drafted = score >= threshold
        let team = drafted ? bestTeam(for: params.state.pitcher, seed: seed) : nil
        let round = drafted ? (score >= 78 ? 1 : score >= 70 ? 2 : 4) : nil
        let pick = round.map { ($0 - 1) * 10 + generator.nextInt(upperBound: 10) + 1 }
        let draft = DraftResultSnapshot(
            outcome: drafted ? .drafted : .undrafted, evaluationScore: score,
            projectedRange: score >= 78 ? "1라운드" : score >= 70 ? "2~3라운드" : score >= 61 ? "4~6라운드" : "미지명",
            team: team, round: round, overallPick: pick,
            signingBonus: round.map { max(40_000_000, 300_000_000 - $0 * 45_000_000) },
            firstSeasonGoal: team.map { _ in "퓨처스 선발 10경기와 볼넷률 8% 이하" },
            summary: drafted
                ? "지명 구단 · \(team?.name ?? "프로 구단"). 현재 구위와 고교 경기 기록에서 높은 평가를 받았습니다."
                : "마지막 라운드까지 이름이 불리지 않았습니다. 다음 선수에게 남길 기록을 고르세요."
        )
        let phase: HighSchoolCareerPhase = drafted ? .completed : .legacy
        let memories = drafted ? [] : memoryOptions(state: params.state, seed: seed)
        let next = replacing(params.state, revision: params.state.revision + 1, phase: phase,
            news: [drafted ? "드래프트 지명 · \(team?.name ?? "프로 구단") · \(params.state.pitcher.name)" : "드래프트가 끝날 때까지 이름이 불리지 않았습니다."] + params.state.news,
            draftResult: draft, legacyOptions: memories)
        return result(seed: seed, state: signed(next), event: "career_draft_resolved", reasons: ["draft.\(draft.outcome.rawValue)"])
    }

    public func selectLegacy(_ params: SelectCareerLegacyParams) throws -> HighSchoolCareerResult {
        let seed = try validatedSeed(params.seed); try validate(params.state, phase: .legacy)
        let unique = Array(Set(params.memoryCards))
        guard unique.count == params.state.memorySlots, unique.allSatisfy(params.state.legacyOptions.contains) else {
            throw SimulationError.invalidPitcherLab("select the available number of offered career memories")
        }
        let next = replacing(params.state, revision: params.state.revision + 1, phase: .completed,
            legacyOptions: unique, selectedMemories: unique)
        return result(seed: seed, state: signed(next), event: "career_legacy_selected", reasons: unique.map { "memory.\($0.rawValue)" })
    }

    private func milestone(for chapter: Int, index: Int) -> HighSchoolCareerPhase {
        let schedules: [[HighSchoolCareerPhase]] = [
            [.relationship], [.relationship, .importantGame], [.awakening, .importantGame],
            [.relationship, .importantGame], [.relationship], [.awakening, .importantGame],
            [.relationship], [.awakening, .importantGame, .draft]
        ]
        let events = schedules[chapter - 1]
        return index < events.count ? events[index] : .chapterReview
    }

    private func advanceMilestone(_ state: HighSchoolCareerSnapshot, seed: UInt64) -> HighSchoolCareerSnapshot {
        let index = state.milestoneIndex + 1
        let phase = milestone(for: state.chapter.number, index: index)
        let options = phase == .awakening ? awakeningOptions(state: state, seed: seed) : []
        let scenario = phase == .importantGame ? gameScenario(for: state, seed: seed) : nil
        let relationshipEvent = phase == .relationship ? relationshipEvent(for: state, seed: seed) : nil
        if phase == .draft {
            return replacing(state, phase: .draft, milestoneIndex: index, awakeningOptions: [])
        }
        return replacing(state, phase: phase, milestoneIndex: index, awakeningOptions: options,
            performance: state.performance, currentGameScenario: scenario, currentRelationshipEvent: relationshipEvent)
    }

    private func rival(seed: UInt64, difficulty: DifficultyLevel, karmas: [KarmaID]) -> RivalSnapshot {
        let rivals = [
            RivalSnapshot(id: "rival-seo", name: "이정훈", archetype: "패턴 학습형 중심타자", contact: 62, discipline: 58, power: 66),
            RivalSnapshot(id: "rival-lee", name: "이대훈", archetype: "초구 공격형", contact: 65, discipline: 47, power: 61),
            RivalSnapshot(id: "rival-park", name: "박용태", archetype: "존 관리형", contact: 58, discipline: 67, power: 55),
            RivalSnapshot(id: "rival-kang", name: "이승윤", archetype: "장타 특화형", contact: 53, discipline: 54, power: 72),
            RivalSnapshot(id: "rival-yoon", name: "구자윤", archetype: "변화구 대응형", contact: 63, discipline: 59, power: 57),
            RivalSnapshot(id: "rival-choi", name: "최형준", archetype: "포심 사냥형", contact: 60, discipline: 52, power: 68)
        ]
        var generator = SplitMix64(seed: seed ^ 0x5249_5641_4c00)
        let base = rivals[generator.nextInt(upperBound: rivals.count)]
        let difficultyBonus = difficulty == .relaxed ? -3 : difficulty == .challenging ? 4 : 0
        let generationBonus = karmas.contains(.geniusGeneration) ? 4 : 0
        let bonus = difficultyBonus + generationBonus
        return RivalSnapshot(id: base.id, name: base.name, archetype: base.archetype,
            contact: clamp(base.contact + bonus, 20, 80), discipline: clamp(base.discipline + bonus, 20, 80),
            power: clamp(base.power + bonus, 20, 80))
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
        return result
    }

    private func relationshipEvent(for state: HighSchoolCareerSnapshot, seed: UInt64) -> CareerEventContent {
        let category = state.relationshipsCompleted % 3 == 0 ? "coach" : state.relationshipsCompleted % 3 == 1 ? "catcher" : "rival"
        let candidates = HighSchoolContentCatalog.events.filter { $0.category == category }
        return candidates[Int(seed % UInt64(candidates.count))]
    }

    private func relationshipNews(state: HighSchoolCareerSnapshot, response: RelationshipResponse, seed: UInt64, impact: RelationshipImpact) -> String {
        let content = state.currentRelationshipEvent ?? relationshipEvent(for: state, seed: seed)
        let category = content.category
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

    private func relationshipImpact(state: HighSchoolCareerSnapshot, response: RelationshipResponse) -> RelationshipImpact {
        let category = state.currentRelationshipEvent?.category ?? "coach"
        let archetype = category == "coach" ? state.school?.coachArchetype : category == "catcher" ? state.school?.catcherArchetype : state.rival.archetype
        switch (category, archetype, response) {
        case ("coach", "원칙형", .listen): return .init(trust: 8, fatigue: 0, fanInterest: 0, growthFocus: .stamina, outcome: "정해진 이닝을 버티는 루틴을 함께 정했습니다.")
        case ("coach", "원칙형", .explain): return .init(trust: 2, fatigue: 0, fanInterest: 0, growthFocus: .command, outcome: "등판 기록은 받아들였지만 보직은 그대로 유지됐습니다.")
        case ("coach", "원칙형", .challenge): return .init(trust: state.fatigue < 45 ? 5 : -7, fatigue: 6, fanInterest: 2, growthFocus: state.fatigue < 45 ? .velocity : nil, outcome: state.fatigue < 45 ? "추가 불펜에서 선발 테스트 기회를 얻었습니다." : "지친 팔로 무리한 요구를 했다는 평가가 남았습니다.")
        case ("coach", "분석형", .listen): return .init(trust: 3, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "감독이 지적한 수치를 다음 훈련 기준으로 삼았습니다.")
        case ("coach", "분석형", .explain): return .init(trust: 8, fatigue: 0, fanInterest: 0, growthFocus: .gamePlanning, outcome: "기록을 근거로 다음 등판의 투구 계획을 다시 짰습니다.")
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
        case ("catcher", "분석형", .explain): return .init(trust: 8, fatigue: 0, fanInterest: 0, growthFocus: .gamePlanning, outcome: "두 사람이 본 근거를 합쳐 다음 경기 시퀀스를 만들었습니다.")
        case ("catcher", "분석형", .challenge): return .init(trust: 2, fatigue: 2, fanInterest: 2, growthFocus: .breakingBall, outcome: "불펜에서 두 시퀀스를 같은 타자 역할로 비교했습니다.")
        case ("catcher", "공격형", .listen): return .init(trust: 2, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "포수의 공격적인 의도는 확인했지만 승부 순서는 정하지 못했습니다.")
        case ("catcher", "공격형", .explain): return .init(trust: 4, fatigue: 0, fanInterest: 1, growthFocus: .command, outcome: "강한 공을 쓸 카운트를 좁혀 합의했습니다.")
        case ("catcher", "공격형", .challenge): return .init(trust: 8, fatigue: 3, fanInterest: 4, growthFocus: .velocity, outcome: "다음 경기 첫 타자에게 가장 강한 시퀀스를 시험하기로 했습니다.")
        case ("catcher", "공감형", .listen): return .init(trust: 7, fatigue: -2, fanInterest: 0, growthFocus: .breakingBall, outcome: "받기 어려운 공을 추려 둘만의 불펜 시간을 잡았습니다.")
        case ("catcher", "공감형", .explain): return .init(trust: 7, fatigue: 0, fanInterest: 0, growthFocus: .command, outcome: "손에서 빠지는 날의 대체 사인을 정했습니다.")
        case ("catcher", "공감형", .challenge): return .init(trust: -2, fatigue: 3, fanInterest: 2, growthFocus: .breakingBall, outcome: "어려운 공을 더 받기로 했지만 경기 전 부담도 커졌습니다.")
        case ("rival", _, .listen): return .init(trust: 3, fatigue: 0, fanInterest: 1, growthFocus: .gamePlanning, outcome: "상대가 읽은 반복 습관 하나를 알아냈습니다.")
        case ("rival", _, .explain): return .init(trust: 1, fatigue: 0, fanInterest: 3, growthFocus: .command, outcome: "서로의 의도를 확인한 재대결이 기사에 실렸습니다.")
        case ("rival", _, .challenge): return .init(trust: -1, fatigue: 2, fanInterest: 7, growthFocus: .breakingBall, outcome: "다음 맞대결이 대회에서 가장 기다리는 승부가 됐습니다.")
        default: return .init(trust: 2, fatigue: 0, fanInterest: 0, growthFocus: nil, outcome: "다음 일정에서 선택의 결과를 확인하게 됐습니다.")
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
            : "라이벌은 다시 만난 타석에서도 이전 승부의 흔적을 놓치지 않았습니다."
        }
    }

    private func awakeningTitle(_ awakening: AwakeningID) -> String {
        switch awakening {
        case .explosiveFastball: return "폭발하는 포심"
        case .pinpointEdge: return "바늘끝 경계"
        case .disappearingBreaker: return "사라지는 궤적"
        case .ironArm: return "강철의 어깨"
        case .calmUnderPressure: return "고요한 마운드"
        case .batterySync: return "배터리 동기화"
        case .risingFourSeam: return "떠오르는 포심"
        case .sinkerTunnel: return "싱커 터널"
        case .frozenChangeup: return "멈춘 체인지업"
        case .sweepingSlider: return "스위퍼 궤도"
        case .curveballClock: return "커브의 시계"
        case .repeatableRelease: return "반복되는 릴리스"
        case .pickoffRhythm: return "주자를 묶는 리듬"
        case .twoStrikePlan: return "2스트라이크 설계"
        case .firstPitchStrike: return "초구 스트라이크"
        case .trafficController: return "주자 교통정리"
        case .lateInningReserve: return "후반 이닝의 여력"
        case .scoutComposure: return "스카우트 앞의 평정"
        }
    }

    private func awakeningEffect(_ awakening: AwakeningID) -> String {
        switch awakening {
        case .explosiveFastball: return "포심 위력은 크게 오르지만 커맨드와 체력 소모를 감수합니다."
        case .risingFourSeam: return "포심 헛스윙이 늘지만 변화구 움직임이 조금 줄어듭니다."
        case .pinpointEdge, .repeatableRelease: return "경계 재현이 좋아지는 대신 최고 출력이 조금 줄어듭니다."
        case .firstPitchStrike: return "초구 제구가 좋아지지만 긴 이닝의 여유가 조금 줄어듭니다."
        case .disappearingBreaker, .sweepingSlider, .frozenChangeup, .curveballClock: return "결정구 움직임과 헛스윙이 늘지만 커맨드나 체력을 감수합니다."
        case .sinkerTunnel: return "포심과 체인지업의 궤도가 닮아 약한 타구를 더 만듭니다."
        case .ironArm, .lateInningReserve: return "공 하나당 체력 소모가 줄고 긴 이닝에 강해집니다."
        case .batterySync: return "포수와 맞춘 코스의 제구와 약한 타구 유도가 좋아집니다."
        case .calmUnderPressure, .pickoffRhythm, .twoStrikePlan, .trafficController, .scoutComposure: return "특정 경기 상황의 실행력이 좋아지는 대신 한쪽 능력에 비용이 생깁니다."
        }
    }

    private func gameScenario(for state: HighSchoolCareerSnapshot, seed: UInt64) -> ImportantGameScenarioContent {
        let count = state.performance.importantGamesCompleted
        let index = (Int(seed % UInt64(HighSchoolContentCatalog.scenarios.count)) + count * 5)
            % HighSchoolContentCatalog.scenarios.count
        return HighSchoolContentCatalog.scenarios[index]
    }

    private func bestTeam(for pitcher: PitcherSnapshot, seed: UInt64) -> DraftTeamSnapshot {
        let values: [TrainingFocus: Int] = [.velocity: pitcher.stuff, .command: pitcher.command, .breakingBall: pitcher.movement,
            .stamina: pitcher.stamina, .gamePlanning: pitcher.command, .recovery: pitcher.stamina]
        return Self.teams.max { lhs, rhs in
            (values[lhs.need, default: 0] * 10 + lhs.demand) < (values[rhs.need, default: 0] * 10 + rhs.demand)
        }!
    }

    private func memoryOptions(state: HighSchoolCareerSnapshot, seed: UInt64) -> [MemoryCardID] {
        var options = MemoryCardID.allCases
        var generator = SplitMix64(seed: seed ^ UInt64(state.performance.pitches) ^ 0x4d45_4d4f_5259)
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
            stamina: max(20, value.stamina - 2), pitchProfiles: value.pitchProfiles)
        return value
    }

    private func applyInheritance(_ points: Int, domain: SoulDomain?, memories: [MemoryCardID], to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        let focus: TrainingFocus = domain == .body ? .velocity : domain == .technique ? .command : .gamePlanning
        var value = grow(pitcher, focus: focus, points: max(0, points))
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
            pitchProfiles: profiles)
    }

    private func grow(_ pitcher: PitcherSnapshot, focus: TrainingFocus, points: Int) -> PitcherSnapshot {
        guard points > 0 else { return pitcher }
        let profiles = pitcher.pitchProfiles?.map { profile in
            PitchProfileSnapshot(pitchType: profile.pitchType, role: profile.role,
                velocityTenthsKPH: clamp(profile.velocityTenthsKPH + (focus == .velocity ? points * 5 : 0), 1_000, 1_700),
                control: clamp(profile.control + (focus == .command ? points : 0), 20, 80),
                command: clamp(profile.command + (focus == .command || focus == .gamePlanning ? points : 0), 20, 80),
                movement: clamp(profile.movement + (focus == .breakingBall && profile.pitchType != .fourSeam ? points : 0), 20, 80),
                whiff: clamp(profile.whiff + (focus == .breakingBall && profile.pitchType != .fourSeam ? points : 0), 20, 80),
                weakContact: profile.weakContact,
                fatigueCost: focus == .stamina ? max(0, profile.fatigueCost - points / 2) : profile.fatigueCost)
        }
        return PitcherSnapshot(id: pitcher.id, name: pitcher.name,
            stuff: clamp(pitcher.stuff + (focus == .velocity ? points : 0), 20, 80),
            command: clamp(pitcher.command + (focus == .command || focus == .gamePlanning ? points : 0), 20, 80),
            movement: clamp(pitcher.movement + (focus == .breakingBall ? points : 0), 20, 80),
            stamina: clamp(pitcher.stamina + (focus == .stamina || focus == .recovery ? points : 0), 20, 80), pitchProfiles: profiles)
    }

    private func replacing(_ state: HighSchoolCareerSnapshot, revision: UInt64? = nil,
        phase: HighSchoolCareerPhase? = nil, pitcher: PitcherSnapshot? = nil, school: SchoolSnapshot? = nil,
        chapter: CareerChapterSnapshot? = nil, chapterTrainingCount: Int? = nil, totalTrainingsCompleted: Int? = nil,
        milestoneIndex: Int? = nil, relationshipsCompleted: Int? = nil, relationshipTrust: Int? = nil,
        selectedAwakenings: [AwakeningID]? = nil, awakeningOptions: [AwakeningID]? = nil, fatigue: Int? = nil,
        performance: CareerPerformanceSnapshot? = nil, lastTraining: CareerTrainingSnapshot? = nil,
        currentGameScenario: ImportantGameScenarioContent? = nil,
        currentRelationshipEvent: CareerEventContent? = nil,
        news: [String]? = nil, fanInterest: Int? = nil, draftResult: DraftResultSnapshot? = nil,
        legacyOptions: [MemoryCardID]? = nil, selectedMemories: [MemoryCardID]? = nil, stateCommitment: String? = nil
    ) -> HighSchoolCareerSnapshot {
        HighSchoolCareerSnapshot(careerID: state.careerID, revision: revision ?? state.revision, lifeNumber: state.lifeNumber,
            phase: phase ?? state.phase, identity: state.identity, difficulty: state.difficulty, karmas: state.karmas,
            legacyRewardPermille: state.legacyRewardPermille, memorySlots: state.memorySlots,
            pitcher: pitcher ?? state.pitcher, schoolOptions: state.schoolOptions,
            school: school ?? state.school, rival: state.rival, chapter: chapter ?? state.chapter,
            chapterTrainingCount: chapterTrainingCount ?? state.chapterTrainingCount,
            totalTrainingsCompleted: totalTrainingsCompleted ?? state.totalTrainingsCompleted,
            milestoneIndex: milestoneIndex ?? state.milestoneIndex,
            relationshipsCompleted: relationshipsCompleted ?? state.relationshipsCompleted,
            relationshipTrust: relationshipTrust ?? state.relationshipTrust,
            selectedAwakenings: selectedAwakenings ?? state.selectedAwakenings,
            awakeningOptions: awakeningOptions ?? state.awakeningOptions, fatigue: fatigue ?? state.fatigue,
            performance: performance ?? state.performance,
            currentGameScenario: currentGameScenario ?? state.currentGameScenario,
            currentRelationshipEvent: currentRelationshipEvent ?? state.currentRelationshipEvent,
            lastTraining: lastTraining ?? state.lastTraining,
            news: news ?? state.news, fanInterest: fanInterest ?? state.fanInterest,
            draftResult: draftResult ?? state.draftResult, legacyOptions: legacyOptions ?? state.legacyOptions,
            selectedMemories: selectedMemories ?? state.selectedMemories, stateCommitment: stateCommitment ?? state.stateCommitment)
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
        let canonical: [String] = [state.careerID, String(state.revision), state.phase.rawValue,
            state.identity.name, state.identity.throwingHand.rawValue, state.identity.bodyType.rawValue, state.identity.region, school,
            state.difficulty.careerHarshness.rawValue, state.difficulty.informationClarity.rawValue,
            state.difficulty.simulationDifficulty.rawValue, state.difficulty.interventionAssist.rawValue,
            state.karmas.map(\.rawValue).joined(separator: ","), String(state.legacyRewardPermille), String(state.memorySlots),
            String(state.chapter.number), String(state.chapterTrainingCount), String(state.totalTrainingsCompleted),
            String(state.milestoneIndex), String(state.relationshipsCompleted), String(state.relationshipTrust),
            state.selectedAwakenings.map(\.rawValue).joined(separator: ","), state.awakeningOptions.map(\.rawValue).joined(separator: ","),
            String(state.fatigue), ratings, performance, scenario, draft, state.legacyOptions.map(\.rawValue).joined(separator: ","),
            state.selectedMemories.map(\.rawValue).joined(separator: ",")]
        return StableHash.fnv1a64(canonical.joined(separator: "|"))
    }

    private func validate(_ state: HighSchoolCareerSnapshot, phase: HighSchoolCareerPhase) throws {
        guard state.phase == phase, state.stateCommitment == commitment(state),
              (0...16).contains(state.totalTrainingsCompleted), (0...5).contains(state.relationshipsCompleted),
              (0...100).contains(state.fatigue), (0...100).contains(state.relationshipTrust) else {
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

    private func renamed(_ name: String, pitcher: PitcherSnapshot) -> PitcherSnapshot {
        PitcherSnapshot(id: pitcher.id, name: name, stuff: pitcher.stuff, command: pitcher.command,
            movement: pitcher.movement, stamina: pitcher.stamina, pitchProfiles: pitcher.pitchProfiles)
    }

    private func result(seed: UInt64, state: HighSchoolCareerSnapshot, event: String, reasons: [String] = []) -> HighSchoolCareerResult {
        var generator = SplitMix64(seed: seed ^ UInt64(state.revision) ^ 0x4556_454e_5400)
        let nextSeed = String(generator.next())
        let events = [HighSchoolCareerEvent(eventType: event, reasonCodes: reasons)]
        let eventHash = StableHash.fnv1a64("\(state.careerID)|\(state.revision)|\(event)|\(nextSeed)|\(state.stateCommitment)")
        return HighSchoolCareerResult(revision: state.revision, nextSeed: nextSeed, events: events, snapshot: state, eventHash: eventHash)
    }
}
