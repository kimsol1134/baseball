import Foundation

public enum ProNationalTournamentStage: String, Codable, Sendable {
    case group
    case awaitingFinal = "awaiting_final"
    case result
}

public enum ProNationalTournamentResult: String, Codable, Sendable {
    case gold
    case silver
    case bronze
    case groupExit = "group_exit"
}

public enum ProNationalOpponentGrade: String, Codable, Sendable {
    case a
    case b
    case c
    case d
}

public struct ProNationalOpponent: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let grade: ProNationalOpponentGrade
    public let batterOffset: Int

    public init(id: String, grade: ProNationalOpponentGrade, batterOffset: Int) {
        self.id = id
        self.grade = grade
        self.batterOffset = batterOffset
    }
}

public struct ProNationalTournamentGameLine: Codable, Equatable, Sendable, Identifiable {
    public let opponentID: String
    public let gameNumber: Int
    public let teamRuns: Int
    public let opponentRuns: Int
    public let directlyPlayed: Bool
    public let playerPitches: Int?
    public let playerOuts: Int?
    public let playerRunsAllowed: Int?
    public let playerStrikeouts: Int?
    public let playerWalks: Int?
    public let playerHits: Int?

    public var id: String { "\(opponentID)-\(gameNumber)" }
    public var won: Bool { teamRuns > opponentRuns }

    public init(
        opponentID: String,
        gameNumber: Int,
        teamRuns: Int,
        opponentRuns: Int,
        directlyPlayed: Bool,
        playerPitches: Int? = nil,
        playerOuts: Int? = nil,
        playerRunsAllowed: Int? = nil,
        playerStrikeouts: Int? = nil,
        playerWalks: Int? = nil,
        playerHits: Int? = nil
    ) {
        self.opponentID = opponentID
        self.gameNumber = gameNumber
        self.teamRuns = teamRuns
        self.opponentRuns = opponentRuns
        self.directlyPlayed = directlyPlayed
        self.playerPitches = playerPitches
        self.playerOuts = playerOuts
        self.playerRunsAllowed = playerRunsAllowed
        self.playerStrikeouts = playerStrikeouts
        self.playerWalks = playerWalks
        self.playerHits = playerHits
    }
}

public struct ProNationalTournamentState: Codable, Equatable, Sendable {
    public let seed: UInt64
    public let resumeSeed: String
    public let startingFatigue: Int
    public let groupGames: [ProNationalTournamentGameLine]
    public let stage: ProNationalTournamentStage
    public let finalOpponentID: String
    public let finalLine: ProNationalTournamentGameLine?
    public let result: ProNationalTournamentResult?
    public let fatigueCarry: Int
    public let injuryWeeks: Int
    public let fanDelta: Int
    public let exempted: Bool

    public init(
        seed: UInt64,
        resumeSeed: String,
        startingFatigue: Int,
        groupGames: [ProNationalTournamentGameLine],
        stage: ProNationalTournamentStage,
        finalOpponentID: String,
        finalLine: ProNationalTournamentGameLine? = nil,
        result: ProNationalTournamentResult? = nil,
        fatigueCarry: Int,
        injuryWeeks: Int,
        fanDelta: Int = 0,
        exempted: Bool = false
    ) {
        self.seed = seed
        self.resumeSeed = resumeSeed
        self.startingFatigue = startingFatigue
        self.groupGames = groupGames
        self.stage = stage
        self.finalOpponentID = finalOpponentID
        self.finalLine = finalLine
        self.result = result
        self.fatigueCarry = fatigueCarry
        self.injuryWeeks = injuryWeeks
        self.fanDelta = fanDelta
        self.exempted = exempted
    }

    public var groupWins: Int { groupGames.filter(\.won).count }
}

public struct ProNationalTeamRecord: Codable, Equatable, Sendable {
    public let season: Int
    public let result: ProNationalTournamentResult
    public let directGameLine: ProNationalTournamentGameLine?

    public init(
        season: Int,
        result: ProNationalTournamentResult,
        directGameLine: ProNationalTournamentGameLine?
    ) {
        self.season = season
        self.result = result
        self.directGameLine = directGameLine
    }
}

public struct ProNationalTeamCarryState: Codable, Equatable, Sendable {
    public let season: Int
    public let fatigue: Int
    public let injuryWeeks: Int

    public init(season: Int, fatigue: Int, injuryWeeks: Int) {
        self.season = season
        self.fatigue = fatigue
        self.injuryWeeks = injuryWeeks
    }
}

public enum ProNationalTeamRules {
    public static let tournamentNameKey = "content.national-team.tournament.name"
    public static let callInterval = 2
    public static let minimumSeason = 2
    public static let maximumAge = 31
    public static let marketScoreThreshold = 55
    public static let fanSupportThreshold = 60
    public static let winsToFinal = 2
    public static let fatigueCarry = 15
    public static let fatigueCarryHeavy = 25
    public static let heavyPitchThreshold = 80
    public static let goldFanDelta = 8
    public static let goldFanDeltaAlreadyCompleted = 10
    public static let silverFanDelta = 4
    public static let bronzeFanDelta = 2
    public static let declineFanDelta = -2
    public static let hofGoldBonus = 4
    public static let groupOutsTarget = 18
    public static let groupPitchCap = 96
    public static let injuryRecoveryMin = 2
    public static let injuryRecoverySpan = 3
    /// Same extra offset as the autumn championship series (`ProPostseasonRules.extraOffset(.final)`).
    public static let finalBatterOffset = 6

    public static let opponents: [ProNationalOpponent] = [
        .init(id: "east-coast", grade: .a, batterOffset: finalBatterOffset),
        .init(id: "southwest-isles", grade: .b, batterOffset: 5),
        .init(id: "northern-plains", grade: .c, batterOffset: 4),
        .init(id: "south-harbor", grade: .d, batterOffset: 2),
    ]

    public static func opponent(id: String) -> ProNationalOpponent? {
        opponents.first { $0.id == id }
    }

    public static func derivedSeed(from nextSeed: String) -> UInt64 {
        StableHash.fnv1a64Value("national-tournament:\(nextSeed)")
    }

    public static func shouldOfferCall(_ state: ProCareerSnapshot) -> Bool {
        guard ProCareerEngine.usesNationalTeamRules(state) else { return false }
        guard state.season >= minimumSeason, state.season % callInterval == 0 else { return false }
        guard state.age <= maximumAge else { return false }
        guard state.phase != .retirementDecision else { return false }
        if state.journeyState?.lastSettlement?.nextRoute == .forcedRetirement { return false }
        return qualifies(state)
    }

    public static func qualifies(_ state: ProCareerSnapshot) -> Bool {
        if marketScore(for: state) >= marketScoreThreshold { return true }
        if seasonAwardCount(for: state) >= 1 { return true }
        if (state.journeyState?.reputation.fanSupport ?? 0) >= fanSupportThreshold { return true }
        return false
    }

    public static func marketScore(for state: ProCareerSnapshot) -> Int {
        ProContractMarketRules.marketScore(state: state)
    }

    public static func seasonAwardCount(for state: ProCareerSnapshot) -> Int {
        if let ids = state.journeyState?.lastSettlement?.newAwardIDs, !ids.isEmpty {
            return ids.count
        }
        return (state.journeyState?.recognitions ?? []).filter {
            $0.kind == .award && $0.season == state.season
        }.count
    }

    public static func groupOpponents() -> [ProNationalOpponent] {
        opponents.filter { $0.grade != .a }
    }

    public static func finalOpponent() -> ProNationalOpponent {
        opponents.first { $0.grade == .a } ?? opponents[0]
    }

    public static func goldCount(in history: [ProNationalTeamRecord]?) -> Int {
        history?.filter { $0.result == .gold }.count ?? 0
    }

    public static func fanDelta(
        for result: ProNationalTournamentResult,
        militaryCompleted: Bool
    ) -> Int {
        switch result {
        case .gold:
            return militaryCompleted ? goldFanDeltaAlreadyCompleted : goldFanDelta
        case .silver: return silverFanDelta
        case .bronze: return bronzeFanDelta
        case .groupExit: return 0
        }
    }

    public static func fatigueCarry(pitches: Int?) -> Int {
        (pitches ?? 0) >= heavyPitchThreshold ? fatigueCarryHeavy : fatigueCarry
    }

    public static func newsKey(for result: ProNationalTournamentResult) -> String {
        switch result {
        case .gold: "content.pro-news.national-team.gold"
        case .silver: "content.pro-news.national-team.silver"
        case .bronze: "content.pro-news.national-team.bronze"
        case .groupExit: "content.pro-news.national-team.group-exit"
        }
    }
}
