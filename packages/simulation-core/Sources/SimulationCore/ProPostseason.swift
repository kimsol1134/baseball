import Foundation

public enum ProAutumnRound: String, Codable, Sendable {
    case wildCard = "wild_card"
    case semifinal
    case playoff
    case final
}

public enum ProPostseasonResult: String, Codable, Sendable {
    case inProgress = "in_progress"
    case eliminated
    case champion
    case runnerUp = "runner_up"
    case didNotQualify = "did_not_qualify"
    case unavailable
}

public struct ProPostseasonState: Codable, Equatable, Sendable {
    public let seed: Int
    public let currentRound: ProAutumnRound?
    public let result: ProPostseasonResult
    public let gamesPlayed: Int

    public init(
        seed: Int,
        currentRound: ProAutumnRound?,
        result: ProPostseasonResult,
        gamesPlayed: Int
    ) {
        self.seed = seed
        self.currentRound = currentRound
        self.result = result
        self.gamesPlayed = gamesPlayed
    }
}

public enum ProPostseasonRules {
    public static let qualificationCut = 5
    public static let maximumPlayerPathGames = 5

    public static func trigger(for round: ProAutumnRound) -> ProSeasonTrigger {
        switch round {
        case .wildCard: .autumnWildCard
        case .semifinal: .autumnSemifinal
        case .playoff: .autumnPlayoff
        case .final: .autumnFinal
        }
    }

    public static func isAutumn(_ trigger: ProSeasonTrigger?) -> Bool {
        switch trigger {
        case .autumnWildCard, .autumnSemifinal, .autumnPlayoff, .autumnFinal: true
        default: false
        }
    }

    /// 정규 1위는 우승 결정전, 2위는 플레이오프, 3위는 준플레이오프, 4·5위는 와일드카드.
    public static func firstRound(forSeed seed: Int) -> ProAutumnRound {
        switch seed {
        case 1: .final
        case 2: .playoff
        case 3: .semifinal
        default: .wildCard
        }
    }

    public static func nextRound(after round: ProAutumnRound) -> ProAutumnRound? {
        switch round {
        case .wildCard: .semifinal
        case .semifinal: .playoff
        case .playoff: .final
        case .final: nil
        }
    }

    public static func extraOffset(for round: ProAutumnRound) -> Int {
        switch round {
        case .wildCard: 3
        case .semifinal: 4
        case .playoff: 5
        case .final: 6
        }
    }

    public static func maximumBatters(for round: ProAutumnRound) -> Int {
        switch round {
        case .wildCard: 4
        case .semifinal: 5
        case .playoff: 6
        case .final: 7
        }
    }

    public static func standings(
        state: ProCareerSnapshot,
        week: Int
    ) -> [LeagueTable.StandingRow] {
        let games = LeagueTable.gamesPlayed(week: week)
        let results = (state.gameLines ?? []).map {
            LeagueTable.PlayerGameResult(teamRuns: $0.teamRuns, opponentRuns: $0.opponentRuns)
        }
        return LeagueTable.standings(
            season: state.season,
            seed: state.proCareerID,
            gamesPlayed: games,
            playerTeamID: state.team.id,
            playerResults: results
        )
    }

    public static func rank(state: ProCareerSnapshot, week: Int) -> Int? {
        standings(state: state, week: week).firstIndex { $0.teamID == state.team.id }.map { $0 + 1 }
    }

    public static func evaluateEndOfSeason(_ state: ProCareerSnapshot) -> ProPostseasonState {
        let rows = standings(state: state, week: LeagueTable.weeksPerSeason)
        let rank = rows.firstIndex { $0.teamID == state.team.id }.map { $0 + 1 } ?? 10
        guard rank <= qualificationCut else {
            return ProPostseasonState(seed: 0, currentRound: nil, result: .didNotQualify, gamesPlayed: 0)
        }
        let round = firstRound(forSeed: rank)
        return ProPostseasonState(seed: rank, currentRound: round, result: .inProgress, gamesPlayed: 0)
    }

    public static func canPitchAutumn(level: ProLevel, injuryWeeks: Int) -> Bool {
        level == .major && injuryWeeks <= 0
    }

    public static func playerPath(
        from evaluated: ProPostseasonState,
        level: ProLevel,
        injuryWeeks: Int
    ) -> ProPostseasonState {
        guard evaluated.result == .inProgress else { return evaluated }
        guard canPitchAutumn(level: level, injuryWeeks: injuryWeeks) else {
            return ProPostseasonState(
                seed: evaluated.seed,
                currentRound: nil,
                result: .unavailable,
                gamesPlayed: 0
            )
        }
        return evaluated
    }

    public static func qualificationNews(for seed: Int) -> String {
        switch seed {
        case 1: "정규시즌 1위입니다. 우승 결정전 한 판이 남았습니다."
        case 2: "정규시즌 2위입니다. 플레이오프 한 판부터 올라갑니다."
        case 3: "정규시즌 3위입니다. 준플레이오프 한 판부터 시작합니다."
        case 4: "정규시즌 4위입니다. 와일드카드에서 한 승이면 올라갑니다."
        case 5: "정규시즌 5위입니다. 와일드카드에서 두 번을 이겨야 합니다."
        default: "플레이오프가 열립니다."
        }
    }

    public static func unavailableNews(level: ProLevel) -> String {
        level == .minor
            ? "구단은 가을에 올랐지만 2군이라 마운드에 서지 못했습니다."
            : "구단은 가을에 올랐지만 부상으로 마운드에 서지 못했습니다."
    }

    public static func eliminationNews(for round: ProAutumnRound?) -> String {
        switch round {
        case .wildCard: "와일드카드에서 탈락했습니다."
        case .semifinal: "준플레이오프에서 탈락했습니다."
        case .playoff: "플레이오프에서 탈락했습니다."
        default: "플레이오프에서 탈락했습니다."
        }
    }

    public static func resolving(
        _ state: ProPostseasonState,
        won: Bool
    ) -> ProPostseasonState {
        let played = state.gamesPlayed + 1
        guard let round = state.currentRound else {
            return ProPostseasonState(seed: state.seed, currentRound: nil, result: .eliminated, gamesPlayed: played)
        }
        if round == .wildCard {
            return resolvingWildCard(state, won: won, played: played)
        }
        if won, let next = nextRound(after: round) {
            return ProPostseasonState(seed: state.seed, currentRound: next, result: .inProgress, gamesPlayed: played)
        }
        if won {
            return ProPostseasonState(seed: state.seed, currentRound: .final, result: .champion, gamesPlayed: played)
        }
        let result: ProPostseasonResult = round == .final ? .runnerUp : .eliminated
        return ProPostseasonState(seed: state.seed, currentRound: round, result: result, gamesPlayed: played)
    }

    /// 4위는 1승이면 진출하고, 1차전 패는 2차전으로 이어진다. 5위는 2연승해야 한다.
    private static func resolvingWildCard(
        _ state: ProPostseasonState,
        won: Bool,
        played: Int
    ) -> ProPostseasonState {
        let advance = ProPostseasonState(
            seed: state.seed,
            currentRound: .semifinal,
            result: .inProgress,
            gamesPlayed: played
        )
        let stay = ProPostseasonState(
            seed: state.seed,
            currentRound: .wildCard,
            result: .inProgress,
            gamesPlayed: played
        )
        let out = ProPostseasonState(
            seed: state.seed,
            currentRound: .wildCard,
            result: .eliminated,
            gamesPlayed: played
        )
        if state.seed == 4 {
            if won { return advance }
            return played == 1 ? stay : out
        }
        if !won { return out }
        return played == 1 ? stay : advance
    }

    public static func hofBonus(for result: ProPostseasonResult) -> Int {
        switch result {
        case .champion: 4
        case .runnerUp: 2
        case .eliminated: 1
        case .inProgress, .didNotQualify, .unavailable: 0
        }
    }

    public static func recognitionIDs(for postseason: ProPostseasonState) -> [String] {
        switch postseason.result {
        case .didNotQualify, .inProgress, .unavailable:
            return []
        case .champion:
            return pathIDs(seed: postseason.seed, through: .final) + ["pro.autumn.champion"]
        case .runnerUp:
            return pathIDs(seed: postseason.seed, through: .final)
        case .eliminated:
            return pathIDs(
                seed: postseason.seed,
                through: postseason.currentRound ?? firstRound(forSeed: postseason.seed)
            )
        }
    }

    private static func pathIDs(seed: Int, through last: ProAutumnRound) -> [String] {
        let order: [ProAutumnRound] = [.wildCard, .semifinal, .playoff, .final]
        let start = firstRound(forSeed: seed)
        var ids = ["pro.autumn.qualified"]
        for round in order where index(round) >= index(start) && index(round) <= index(last) {
            ids.append(contentID(for: round))
        }
        return ids
    }

    private static func index(_ round: ProAutumnRound) -> Int {
        switch round {
        case .wildCard: 0
        case .semifinal: 1
        case .playoff: 2
        case .final: 3
        }
    }

    private static func contentID(for round: ProAutumnRound) -> String {
        switch round {
        case .wildCard: "pro.autumn.wild-card"
        case .semifinal: "pro.autumn.semifinal"
        case .playoff: "pro.autumn.playoff"
        case .final: "pro.autumn.final"
        }
    }
}
