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
    private struct RegionalSchoolNames: Sendable {
        let traditional: String
        let analytics: String
        let power: String
        let development: String
    }

    private static let regionalSchoolNames: [String: RegionalSchoolNames] = [
        "서울": .init(traditional: "서울덕성고", analytics: "서울배성고", power: "서울충림고", development: "서울경원고"),
        "인천": .init(traditional: "인천제문포고", analytics: "인천동림고", power: "인천항성고", development: "인천송해고"),
        "수원": .init(traditional: "수원유림고", analytics: "수원장림고", power: "수원화홍고", development: "수원매원고"),
        "대전": .init(traditional: "대전한별고", analytics: "대전대림고", power: "대전유진고", development: "대전중원고"),
        "광주": .init(traditional: "광주제원고", analytics: "광주동진고", power: "광주진광고", development: "광주무원고"),
        "대구": .init(traditional: "대구경원고", analytics: "대구상림고", power: "대구달원고", development: "대구청림고"),
        "부산": .init(traditional: "부산해남고", analytics: "부산항성고", power: "부산개원고", development: "부산남경고"),
        "창원": .init(traditional: "마산해강고", analytics: "창원용해고", power: "창원기성고", development: "진해동림고"),
        "울산": .init(traditional: "울산대명고", analytics: "울산문성고", power: "울산태원고", development: "울산장생고"),
        "세종": .init(traditional: "세종한별고", analytics: "세종새빛고", power: "세종금빛고", development: "세종연서고"),
        "경기": .init(traditional: "성남유림고", analytics: "고양백송고", power: "시흥소명고", development: "용인청림고"),
        "강원": .init(traditional: "강릉해람고", analytics: "원주원흥고", power: "춘천호반고", development: "속초설해고"),
        "충북": .init(traditional: "청주원흥고", analytics: "청주세명고", power: "충주성문고", development: "진천덕원고"),
        "충남": .init(traditional: "공주금강고", analytics: "천안북원고", power: "아산온천고", development: "서산해명고"),
        "전북": .init(traditional: "전주완성고", analytics: "군산상림고", power: "정읍인원고", development: "익산보석고"),
        "전남": .init(traditional: "화순화원고", analytics: "순천효원고", power: "목포항남고", development: "여수진원고"),
        "경북": .init(traditional: "포항해철고", analytics: "경주월림고", power: "구미도원고", development: "안동하회고"),
        "경남": .init(traditional: "마산용해고", analytics: "김해가원고", power: "양산물빛고", development: "거제옥림고"),
        "제주": .init(traditional: "제주한라원고", analytics: "서귀포해원고", power: "제주탐라빛고", development: "제주오름고")
    ]

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

    public static func schools(for region: String) -> [SchoolSnapshot] {
        let names = regionalSchoolNames[region] ?? regionalSchoolNames["서울"]!
        return [
            .init(id: .hanbitTraditional, name: names.traditional, philosophy: "기본기와 긴 이닝", coachName: "윤태문", coachArchetype: "원칙형", catcherName: "서준호", catcherArchetype: "안정형",
                coachPersonality: "새벽 반복 훈련을 고집하며 핑계보다 공 하나를 더 던지게 합니다.", coachRecord: "재임 14년 · 전국대회 4강 6회",
                catcherPersonality: "실투 뒤에도 먼저 투수에게 공을 돌려주는 매일 출전형 포수입니다.", catcherRecord: "중학 마지막 시즌 26경기 · 도루저지율 .438",
                strength: .stamina, tradeoff: "새 구종을 시험할 기회가 적습니다."),
            .init(id: .miraeAnalytics, name: names.analytics, philosophy: "데이터와 경기 설계", coachName: "노재형", coachArchetype: "분석형", catcherName: "한도윤", catcherArchetype: "분석형",
                coachPersonality: "확률표를 들고 한 베이스와 불펜 교체 시점을 끝까지 계산합니다.", coachRecord: "데이터 코치 경력 11년 · 지역대회 우승 4회",
                catcherPersonality: "말수는 적지만 타자의 노림수를 먼저 읽고 결정적인 순간 직접 해결합니다.", catcherRecord: "전국중학대회 포수상 · 8홈런",
                strength: .gamePlanning, tradeoff: "데이터가 적을 때 판단이 흔들릴 수 있습니다."),
            .init(id: .haedongPower, name: names.power, philosophy: "출력과 공격적인 승부", coachName: "오승렬", coachArchetype: "승부형", catcherName: "차민석", catcherArchetype: "공격형",
                coachPersonality: "에이스에게 가장 엄격하며 위기일수록 몸쪽 정면승부를 요구합니다.", coachRecord: "전국대회 결승 3회 · 프로 지명 투수 5명",
                catcherPersonality: "몸쪽 사인을 두려워하지 않고 큰 경기에서 투수를 강하게 끌고 갑니다.", catcherRecord: "중학 마지막 시즌 24경기 선발 · 도루저지 11회",
                strength: .velocity, tradeoff: "피로와 제구 비용을 감수해야 합니다."),
            .init(id: .cheongamDevelopment, name: names.development, philosophy: "개인별 폼과 변화구 육성", coachName: "배도환", coachArchetype: "육성형", catcherName: "문하진", catcherArchetype: "공감형",
                coachPersonality: "무심한 표정으로 결단을 내리지만 큰 경기에서는 선수를 먼저 믿습니다.", coachRecord: "7년간 프로 지명 12명 · 변화구 캠프 9회",
                catcherPersonality: "블로킹 천 번을 기본으로 여기며 투수의 버릇까지 잡아내는 완벽주의자입니다.", catcherRecord: "중학 마지막 시즌 무실책 · 4경기 연속 장타",
                strength: .breakingBall, tradeoff: "팀이 연패하면 개인 훈련 시간이 줄어듭니다.")
        ]
    }

    public static let teams: [DraftTeamSnapshot] = [
        .init(id: "seoul_comets", name: "서울 코메츠", need: .command, demand: 72, developmentPlan: "2군 선발 로테이션에서 커맨드 완성", positionCompetitor: "차윤호", proCoach: "문재석", competitorProfile: "느린 커브와 타이밍 싸움으로 살아남은 베테랑 선발", competitorRecord: "최근 시즌 9승 · ERA 3.91", coachProfile: "선수와 대화부터 시작하는 수비 중심 지도자", coachRecord: "3년 연속 포스트시즌 진출"),
        .init(id: "busan_marines", name: "부산 블루웨일스", need: .stamina, demand: 66, developmentPlan: "긴 이닝형 선발 육성", positionCompetitor: "도현우", proCoach: "강태림", competitorProfile: "높은 포심과 낙차 큰 포크볼을 앞세운 우완 에이스", competitorRecord: "최근 시즌 11승 · 142탈삼진", coachProfile: "큰 경기일수록 선발에게 한 이닝을 더 맡기는 승부사", coachRecord: "챔피언십 시리즈 진출 2회"),
        .init(id: "incheon_waves", name: "인천 웨이브스", need: .breakingBall, demand: 70, developmentPlan: "결정구 한 종을 프로 수준으로 강화", positionCompetitor: "백승찬", proCoach: "윤도환", competitorProfile: "슬라이더와 템포 변화로 버티는 왼손 선발", competitorRecord: "최근 시즌 8승 · 126탈삼진", coachProfile: "베테랑 자율과 강한 수비를 함께 요구하는 감독", coachRecord: "정규시즌 상위 3위 2회"),
        .init(id: "daegu_forge", name: "대구 포지", need: .velocity, demand: 75, developmentPlan: "출력 유지와 불펜 조기 데뷔", positionCompetitor: "신재원", proCoach: "권민철", competitorProfile: "낮은 코스와 완급을 반복하는 젊은 우완 에이스", competitorRecord: "최근 시즌 12승 · ERA 3.44", coachProfile: "기본 수비와 세대교체를 함께 밀어붙이는 내야 출신 지도자", coachRecord: "신인 투수 4명 1군 데뷔"),
        .init(id: "daejeon_rockets", name: "대전 로켓츠", need: .gamePlanning, demand: 68, developmentPlan: "배터리 게임 플랜 중심 선발 육성", positionCompetitor: "장하준", proCoach: "배성우", competitorProfile: "빠른 포심으로 타자의 배트를 늦추는 파이어볼러", competitorRecord: "최고 158.2km/h · 134탈삼진", coachProfile: "한번 고른 선발은 충분한 기회를 주는 장기 운영형 감독", coachRecord: "3년 연속 승률 5할 이상"),
        .init(id: "gwangju_phoenix", name: "광주 피닉스", need: .breakingBall, demand: 64, developmentPlan: "변화구 터널과 약한 타구 강화", positionCompetitor: "서이준", proCoach: "남기석", competitorProfile: "큰 각도의 커브로 삼진을 쌓는 왼손 정통파", competitorRecord: "최근 시즌 10승 · 151탈삼진", coachProfile: "선수를 믿고 공격적으로 뛰게 하는 젊은 감독", coachRecord: "최근 2년 승률 .561"),
        .init(id: "suwon_guardians", name: "수원 가디언즈", need: .command, demand: 61, developmentPlan: "볼넷 억제 후 1군 롱릴리프", positionCompetitor: "주성민", proCoach: "오태건", competitorProfile: "낮은 팔 각도와 체인지업으로 볼넷을 지우는 선발", competitorRecord: "최근 시즌 BB/9 1.8 · 퀄리티스타트 17회", coachProfile: "투수의 릴리스 타이밍을 직접 잡는 잠수함 출신 지도자", coachRecord: "4년 연속 포스트시즌 진출"),
        .init(id: "changwon_meteors", name: "창원 미티어스", need: .velocity, demand: 69, developmentPlan: "포심 형태와 최고 구속 동시 개발", positionCompetitor: "류한결", proCoach: "차경호", competitorProfile: "회전 효율이 좋은 왼손 포심으로 타구를 띄우는 선발", competitorRecord: "최근 시즌 ERA 2.48 · 9승", coachProfile: "타격 이론과 편안한 소통을 함께 쓰는 감독", coachRecord: "주전 3명 커리어 하이 달성"),
        .init(id: "jeonju_hanok", name: "전주 한울스", need: .stamina, demand: 58, developmentPlan: "체력 기반 선발 후보 경쟁", positionCompetitor: "문시온", proCoach: "신도영", competitorProfile: "빠른 포심과 짧은 슬라이더로 삼진을 모으는 우완 선발", competitorRecord: "최근 시즌 178탈삼진 · ERA 2.71", coachProfile: "젊은 선수에게 먼저 기회를 주는 장기 육성형 감독", coachRecord: "신인 6명 1군 엔트리 등록"),
        .init(id: "jeju_storm", name: "제주 스톰", need: .gamePlanning, demand: 63, developmentPlan: "데이터 적응형 스윙맨 육성", positionCompetitor: "한유찬", proCoach: "조민규", competitorProfile: "묵직한 포심과 컷패스트볼로 긴 이닝을 버티는 우완 선발", competitorRecord: "최근 시즌 13승 · 147탈삼진", coachProfile: "큰 경기 경험을 바탕으로 한 번의 강한 승부를 강조하는 감독", coachRecord: "포스트시즌 진출 3회")
    ]

    private static let rivals: [RivalSnapshot] = [
        .init(id: "rival-seo", name: "서하준", archetype: "천재 교타형", contact: 68, discipline: 64, power: 55,
            personality: "배트가 공을 끝까지 따라갑니다. 같은 코스를 두 번 놓치지 않는 왼손 타자입니다.", signatureRecord: "봄 대회 타율 .421 · 31안타"),
        .init(id: "rival-lee", name: "권태오", archetype: "초구 거포형", contact: 62, discipline: 52, power: 72,
            personality: "느린 발을 감출 만큼 타구 판단이 빠릅니다. 초구 실투를 그냥 보내지 않습니다.", signatureRecord: "전국대회 7홈런 · 22타점"),
        .init(id: "rival-park", name: "남도현", archetype: "안타 제조형", contact: 67, discipline: 65, power: 51,
            personality: "파울로 버티며 투구 수를 늘리고 마지막에는 짧은 스윙으로 안타를 만듭니다.", signatureRecord: "11경기 연속 안타 · 출루율 .492"),
        .init(id: "rival-kang", name: "배시우", archetype: "외다리 장타형", contact: 55, discipline: 56, power: 76,
            personality: "높게 떠오른 공을 우측 담장으로 보내는 왼손 거포입니다. 실투 하나가 곧 실점입니다.", signatureRecord: "장타율 .711 · 8홈런"),
        .init(id: "rival-yoon", name: "류건우", archetype: "장신 호타준족형", contact: 64, discipline: 57, power: 61,
            personality: "큰 스윙 궤도와 빠른 발을 함께 씁니다. 변화구가 뜨면 주저 없이 당겨칩니다.", signatureRecord: "18경기 14도루 · 5홈런"),
        .init(id: "rival-choi", name: "정세현", archetype: "득점권 해결사형", contact: 63, discipline: 62, power: 70,
            personality: "늦은 카운트와 득점권에서 오히려 스윙이 짧아지는 해결사입니다.", signatureRecord: "득점권 타율 .438 · 끝내기 3회"),
        .init(id: "rival-home-run", name: "강이안", archetype: "몸쪽 사냥형", contact: 60, discipline: 65, power: 76,
            personality: "몸쪽 공도 피하지 않고 잡아당깁니다. 불리한 카운트에서도 장타를 버리지 않습니다.", signatureRecord: "봄·여름 대회 14홈런 · 장타율 .804"),
        .init(id: "rival-speed", name: "문재윤", archetype: "질주형 중심타자", contact: 68, discipline: 58, power: 68,
            personality: "타구가 뜨는 순간 2루를 노립니다. 실투 하나로 경기 흐름을 바꾸는 호타준족입니다.", signatureRecord: "20도루 · 6홈런 · 21득점")
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
            pitcher: pitcher, schoolOptions: Self.schools(for: params.identity.region), school: nil,
            rival: rival(seed: seed, difficulty: params.difficulty.simulationDifficulty, karmas: params.karmas), chapter: Self.chapters[0], chapterTrainingCount: 0,
            totalTrainingsCompleted: 0, milestoneIndex: 0, relationshipsCompleted: 0,
            relationshipTrust: 50, selectedAwakenings: [], awakeningOptions: [], fatigue: 5,
            performance: CareerPerformanceSnapshot(), currentGameScenario: nil, currentRelationshipEvent: nil, lastTraining: nil,
            news: ["\(params.identity.region) 중학교 마지막 대회에서 보여준 공이 같은 지역 네 고교의 관심을 끌었습니다."], fanInterest: 5,
            draftResult: nil, legacyOptions: [], selectedMemories: [], stateCommitment: ""
        )
        return result(seed: seed, state: signed(base), event: "high_school_career_started")
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
        let options = Self.schools(for: params.state.identity.region)
        let selectedSchool = params.state.school.flatMap { current in
            options.first(where: { $0.id == current.id })
        }
        let normalizedRival = Self.rivals.first(where: { $0.id == params.state.rival.id }).map { profile in
            RivalSnapshot(id: profile.id, name: profile.name, archetype: profile.archetype,
                contact: params.state.rival.contact, discipline: params.state.rival.discipline, power: params.state.rival.power,
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
        let normalized = signed(replacing(params.state, schoolOptions: options, school: selectedSchool,
            rival: normalizedRival, news: normalizedNews, draftResult: normalizedDraft))
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
        var generator = SplitMix64(seed: seed ^ 0x5249_5641_4c00)
        let base = Self.rivals[generator.nextInt(upperBound: Self.rivals.count)]
        let difficultyBonus = difficulty == .relaxed ? -3 : difficulty == .challenging ? 4 : 0
        let generationBonus = karmas.contains(.geniusGeneration) ? 4 : 0
        let bonus = difficultyBonus + generationBonus
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
        phase: HighSchoolCareerPhase? = nil, pitcher: PitcherSnapshot? = nil,
        schoolOptions: [SchoolSnapshot]? = nil, school: SchoolSnapshot? = nil,
        rival: RivalSnapshot? = nil,
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
            pitcher: pitcher ?? state.pitcher, schoolOptions: schoolOptions ?? state.schoolOptions,
            school: school ?? state.school, rival: rival ?? state.rival, chapter: chapter ?? state.chapter,
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
        guard state.phase == phase else {
            throw SimulationError.invalidPitcherLab("career state or phase is invalid")
        }
        try validateState(state)
    }

    private func validateState(_ state: HighSchoolCareerSnapshot) throws {
        guard state.stateCommitment == commitment(state),
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
