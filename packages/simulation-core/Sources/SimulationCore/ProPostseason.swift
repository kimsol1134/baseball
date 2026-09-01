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

public enum ProPostseasonAvailabilityChoice: String, Codable, Sendable {
    case pitchAgain = "pitch_again"
    case restForDecider = "rest_for_decider"
}

public enum ProPostseasonGameStakes: String, Codable, Sendable {
    case standard
    case clinch
    case elimination
    case winnerTakeAll = "winner_take_all"
}

public enum ProPostseasonArmRisk: String, Codable, Sendable {
    case manageable
    case elevated
    case severe
}

public struct ProPostseasonGameLine: Codable, Equatable, Sendable, Identifiable {
    public let round: ProAutumnRound?
    public let gameNumber: Int
    public let teamRuns: Int
    public let opponentRuns: Int
    public let directlyPlayed: Bool
    public let playerPitches: Int?
    public let playerOuts: Int?
    public let playerRunsAllowed: Int?

    public var id: String { "\(round?.rawValue ?? "unknown")-\(gameNumber)" }
    public var won: Bool { teamRuns > opponentRuns }

    public init(
        round: ProAutumnRound? = nil,
        gameNumber: Int,
        teamRuns: Int,
        opponentRuns: Int,
        directlyPlayed: Bool,
        playerPitches: Int? = nil,
        playerOuts: Int? = nil,
        playerRunsAllowed: Int? = nil
    ) {
        self.round = round
        self.gameNumber = gameNumber
        self.teamRuns = teamRuns
        self.opponentRuns = opponentRuns
        self.directlyPlayed = directlyPlayed
        self.playerPitches = playerPitches
        self.playerOuts = playerOuts
        self.playerRunsAllowed = playerRunsAllowed
    }
}

/// v7 우승 결정전의 압축 시리즈 상태.
///
/// 선발은 홀수 경기를 직접 던지고, 불펜은 다음 경기 연투 또는 휴식을 선택한다. 기존 v6
/// 세이브에는 이 값이 없으므로 `ProPostseasonState.series`는 선택 필드로 유지한다.
public struct ProPostseasonSeriesState: Codable, Equatable, Sendable {
    public let round: ProAutumnRound?
    public let opponentTeamID: String?
    public let playerWinsRequired: Int?
    public let opponentWinsRequired: Int?
    public let playerWins: Int
    public let opponentWins: Int
    public let nextGameNumber: Int
    public let totalDirectAppearances: Int
    public let lastAppearancePitches: Int?
    public let lastAppearanceGameNumber: Int?
    public let availabilityDecision: ProPostseasonAvailabilityChoice?
    public let gameLines: [ProPostseasonGameLine]?
    public let rivalMemory: RivalMemorySnapshot?

    public init(
        round: ProAutumnRound? = nil,
        opponentTeamID: String? = nil,
        playerWinsRequired: Int? = nil,
        opponentWinsRequired: Int? = nil,
        playerWins: Int = 0,
        opponentWins: Int = 0,
        nextGameNumber: Int = 1,
        totalDirectAppearances: Int = 0,
        lastAppearancePitches: Int? = nil,
        lastAppearanceGameNumber: Int? = nil,
        availabilityDecision: ProPostseasonAvailabilityChoice? = nil,
        gameLines: [ProPostseasonGameLine]? = nil,
        rivalMemory: RivalMemorySnapshot? = nil
    ) {
        self.round = round
        self.opponentTeamID = opponentTeamID
        self.playerWinsRequired = playerWinsRequired
        self.opponentWinsRequired = opponentWinsRequired
        self.playerWins = playerWins
        self.opponentWins = opponentWins
        self.nextGameNumber = nextGameNumber
        self.totalDirectAppearances = totalDirectAppearances
        self.lastAppearancePitches = lastAppearancePitches
        self.lastAppearanceGameNumber = lastAppearanceGameNumber
        self.availabilityDecision = availabilityDecision
        self.gameLines = gameLines
        self.rivalMemory = rivalMemory
    }
}

public struct ProPostseasonState: Codable, Equatable, Sendable {
    public let seed: Int
    public let currentRound: ProAutumnRound?
    public let result: ProPostseasonResult
    public let gamesPlayed: Int
    public let series: ProPostseasonSeriesState?
    public let gameHistory: [ProPostseasonGameLine]?

    public init(
        seed: Int,
        currentRound: ProAutumnRound?,
        result: ProPostseasonResult,
        gamesPlayed: Int,
        series: ProPostseasonSeriesState? = nil,
        gameHistory: [ProPostseasonGameLine]? = nil
    ) {
        self.seed = seed
        self.currentRound = currentRound
        self.result = result
        self.gamesPlayed = gamesPlayed
        self.series = series
        self.gameHistory = gameHistory
    }
}

public enum ProPostseasonRules {
    public static let qualificationCut = 5
    public static let maximumPlayerPathGames = 5
    public static let maximumDirectAppearances = 5
    public static let finalWinsRequired = 3

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

    public static func finalMaximumBatters(for role: ProRole) -> Int {
        maximumBatters(for: role, round: .final)
    }

    public static func maximumBatters(for role: ProRole, round: ProAutumnRound) -> Int {
        switch role {
        case .starter: round == .final ? 7 : 6
        case .longRelief: round == .final ? 6 : 5
        case .setup: 4
        case .closer: 3
        }
    }

    public static func openingFinalSeries(previousDirectAppearances: Int) -> ProPostseasonSeriesState {
        openingSeries(
            round: .final,
            seed: 1,
            opponentTeamID: nil,
            previousDirectAppearances: previousDirectAppearances
        )
    }

    public static func openingSeries(
        round: ProAutumnRound,
        seed: Int,
        opponentTeamID: String?,
        previousDirectAppearances: Int
    ) -> ProPostseasonSeriesState {
        let requirements = winsRequired(round: round, seed: seed)
        return ProPostseasonSeriesState(
            round: round,
            opponentTeamID: opponentTeamID,
            playerWinsRequired: requirements.player,
            opponentWinsRequired: requirements.opponent,
            totalDirectAppearances: min(maximumDirectAppearances, max(0, previousDirectAppearances)),
            gameLines: []
        )
    }

    public static func winsRequired(round: ProAutumnRound, seed: Int) -> (player: Int, opponent: Int) {
        switch round {
        case .wildCard: return seed == 4 ? (1, 2) : (2, 1)
        case .semifinal, .playoff: return (2, 2)
        case .final: return (finalWinsRequired, finalWinsRequired)
        }
    }

    public static func shouldDirectlyPlayNextFinalGame(
        _ state: ProPostseasonState,
        role: ProRole = .starter
    ) -> Bool {
        guard state.currentRound == .final else { return false }
        return shouldDirectlyPlayNextGame(state, role: role)
    }

    public static func shouldDirectlyPlayNextGame(
        _ state: ProPostseasonState,
        role: ProRole
    ) -> Bool {
        guard let round = state.currentRound, state.result == .inProgress else { return false }
        let series = state.series ?? openingSeries(
            round: round,
            seed: state.seed,
            opponentTeamID: nil,
            previousDirectAppearances: state.gamesPlayed
        )
        guard series.totalDirectAppearances < maximumDirectAppearances else { return false }
        switch role {
        case .starter: return series.nextGameNumber % 2 == 1
        case .longRelief, .setup, .closer: return true
        }
    }

    public static func isConsecutiveAppearanceSituation(
        _ state: ProPostseasonState,
        role: ProRole
    ) -> Bool {
        guard role != .starter,
              shouldDirectlyPlayNextGame(state, role: role),
              let series = state.series,
              let lastGame = series.lastAppearanceGameNumber else { return false }
        return series.nextGameNumber == lastGame + 1
    }

    public static func requiresAvailabilityDecision(
        _ state: ProPostseasonState,
        role: ProRole
    ) -> Bool {
        isConsecutiveAppearanceSituation(state, role: role)
            && state.series?.availabilityDecision == nil
    }

    public static func canStartDirectAppearance(
        _ state: ProPostseasonState,
        role: ProRole
    ) -> Bool {
        guard shouldDirectlyPlayNextGame(state, role: role) else { return false }
        guard isConsecutiveAppearanceSituation(state, role: role) else { return true }
        return state.series?.availabilityDecision == .pitchAgain
    }

    public static func choosingAvailability(
        _ state: ProPostseasonState,
        choice: ProPostseasonAvailabilityChoice
    ) -> ProPostseasonState {
        guard let current = state.series else { return state }
        let series = ProPostseasonSeriesState(
            round: current.round,
            opponentTeamID: current.opponentTeamID,
            playerWinsRequired: current.playerWinsRequired,
            opponentWinsRequired: current.opponentWinsRequired,
            playerWins: current.playerWins,
            opponentWins: current.opponentWins,
            nextGameNumber: current.nextGameNumber,
            totalDirectAppearances: current.totalDirectAppearances,
            lastAppearancePitches: current.lastAppearancePitches,
            lastAppearanceGameNumber: current.lastAppearanceGameNumber,
            availabilityDecision: choice,
            gameLines: current.gameLines,
            rivalMemory: current.rivalMemory
        )
        return ProPostseasonState(
            seed: state.seed,
            currentRound: state.currentRound,
            result: state.result,
            gamesPlayed: state.gamesPlayed,
            series: series,
            gameHistory: state.gameHistory
        )
    }

    public static func consecutiveAppearanceFatiguePenalty(
        role: ProRole,
        lastAppearancePitches: Int
    ) -> Int {
        let pitchLoad = max(4, (max(0, lastAppearancePitches) + 4) / 5)
        switch role {
        case .starter: return 0
        case .longRelief: return pitchLoad + 2
        case .setup: return pitchLoad + 1
        case .closer: return pitchLoad
        }
    }

    public static func stakes(_ state: ProPostseasonState) -> ProPostseasonGameStakes {
        guard let round = state.currentRound else { return .standard }
        let series = state.series ?? openingSeries(
            round: round,
            seed: state.seed,
            opponentTeamID: nil,
            previousDirectAppearances: state.gamesPlayed
        )
        let requirements = winsRequired(round: round, seed: state.seed)
        let playerRequired = series.playerWinsRequired ?? requirements.player
        let opponentRequired = series.opponentWinsRequired ?? requirements.opponent
        let canClinch = series.playerWins + 1 >= playerRequired
        let canBeEliminated = series.opponentWins + 1 >= opponentRequired
        if canClinch && canBeEliminated { return .winnerTakeAll }
        if canClinch { return .clinch }
        if canBeEliminated { return .elimination }
        return .standard
    }

    public static func armRisk(projectedFatigue: Int) -> ProPostseasonArmRisk {
        switch min(100, max(0, projectedFatigue)) {
        case 0..<72: .manageable
        case 72..<88: .elevated
        default: .severe
        }
    }

    public static func isValidSeriesState(_ state: ProPostseasonState) -> Bool {
        guard let series = state.series else { return true }
        guard let round = state.currentRound else { return false }
        let requirements = winsRequired(round: round, seed: state.seed)
        let playerRequired = series.playerWinsRequired ?? requirements.player
        let opponentRequired = series.opponentWinsRequired ?? requirements.opponent
        guard series.round == nil || series.round == round,
              playerRequired == requirements.player,
              opponentRequired == requirements.opponent,
              (0...playerRequired).contains(series.playerWins),
              (0...opponentRequired).contains(series.opponentWins),
              series.nextGameNumber == series.playerWins + series.opponentWins + 1,
              (1...(playerRequired + opponentRequired)).contains(series.nextGameNumber),
              (0...maximumDirectAppearances).contains(series.totalDirectAppearances),
              series.totalDirectAppearances <= state.gamesPlayed,
              state.gamesPlayed >= series.playerWins + series.opponentWins,
              series.lastAppearancePitches.map({ (0...200).contains($0) }) ?? true,
              series.lastAppearanceGameNumber.map({ (1...5).contains($0) }) ?? true,
              (series.lastAppearancePitches == nil) == (series.lastAppearanceGameNumber == nil),
              series.lastAppearanceGameNumber.map({ $0 < series.nextGameNumber }) ?? true else {
            return false
        }
        if let lines = series.gameLines {
            guard lines.count == series.playerWins + series.opponentWins,
                  lines.enumerated().allSatisfy({ item in
                      let (index, line) = item
                      return line.gameNumber == index + 1
                          && (line.round == nil || line.round == round)
                          && line.teamRuns >= 0
                          && line.opponentRuns >= 0
                          && line.teamRuns != line.opponentRuns
                          && (line.directlyPlayed
                              ? line.playerPitches != nil
                                  && line.playerOuts != nil
                                  && line.playerRunsAllowed != nil
                              : line.playerPitches == nil
                                  && line.playerOuts == nil
                                  && line.playerRunsAllowed == nil)
                  }),
                  lines.filter(\.won).count == series.playerWins else { return false }
        }
        switch state.result {
        case .inProgress:
            return series.playerWins < playerRequired && series.opponentWins < opponentRequired
        case .champion:
            return round == .final
                && series.playerWins == playerRequired
                && series.opponentWins < opponentRequired
        case .runnerUp:
            return round == .final
                && series.opponentWins == opponentRequired
                && series.playerWins < playerRequired
        case .eliminated:
            return round != .final
                && series.opponentWins == opponentRequired
                && series.playerWins < playerRequired
        case .didNotQualify, .unavailable: return false
        }
    }

    public static func isValidGameHistory(_ state: ProPostseasonState) -> Bool {
        guard let history = state.gameHistory else { return true }
        guard history.count <= state.gamesPlayed,
              history.allSatisfy({ line in
                  line.round != nil
                      && line.gameNumber > 0
                      && line.teamRuns >= 0
                      && line.opponentRuns >= 0
                      && line.teamRuns != line.opponentRuns
                      && (line.directlyPlayed
                          ? line.playerPitches != nil
                              && line.playerOuts != nil
                              && line.playerRunsAllowed != nil
                          : line.playerPitches == nil
                              && line.playerOuts == nil
                              && line.playerRunsAllowed == nil)
              }) else { return false }
        return [ProAutumnRound.wildCard, .semifinal, .playoff, .final].allSatisfy { round in
            let lines = history.filter { $0.round == round }
            return lines.isEmpty || lines.map(\.gameNumber) == Array(1...lines.count)
        }
    }

    public static func isValidSeriesRivalMemory(
        _ state: ProPostseasonState,
        pitcherID: String
    ) -> Bool {
        guard let memory = state.series?.rivalMemory else { return true }
        guard memory.matchupID.hasPrefix("\(pitcherID):bench:"),
              memory.plateAppearancesSeen >= 0,
              memory.totalPitchesSeen >= memory.recentObservations.count,
              memory.recentObservations.count <= RivalMemoryEngine.maximumObservations else {
            return false
        }
        return memory.recentObservations.allSatisfy { observation in
            (0...2).contains(observation.zone.row)
                && (0...2).contains(observation.zone.column)
                && (0...3).contains(observation.balls)
                && (0...2).contains(observation.strikes)
        }
    }

    /// 우승 결정전의 한 경기만 정산한다. 팀 자동 경기와 직접 경기를 같은 시리즈 원장에
    /// 기록하되, 직접 등판 횟수는 플레이어가 실제로 던진 경기에서만 증가한다.
    public static func resolvingFinalGame(
        _ state: ProPostseasonState,
        won: Bool,
        directlyPlayed: Bool,
        pitches: Int? = nil,
        outs: Int? = nil,
        runsAllowed: Int? = nil,
        teamRuns: Int? = nil,
        opponentRuns: Int? = nil,
        rivalMemory: RivalMemorySnapshot? = nil
    ) -> ProPostseasonState {
        resolvingSeriesGame(
            state,
            won: won,
            directlyPlayed: directlyPlayed,
            pitches: pitches,
            outs: outs,
            runsAllowed: runsAllowed,
            teamRuns: teamRuns,
            opponentRuns: opponentRuns,
            rivalMemory: rivalMemory
        )
    }

    public static func resolvingSeriesGame(
        _ state: ProPostseasonState,
        won: Bool,
        directlyPlayed: Bool,
        pitches: Int? = nil,
        outs: Int? = nil,
        runsAllowed: Int? = nil,
        teamRuns: Int? = nil,
        opponentRuns: Int? = nil,
        rivalMemory: RivalMemorySnapshot? = nil
    ) -> ProPostseasonState {
        precondition(state.result == .inProgress && state.currentRound != nil)
        let round = state.currentRound ?? .final
        let current = state.series ?? openingSeries(
            round: round,
            seed: state.seed,
            opponentTeamID: nil,
            previousDirectAppearances: state.gamesPlayed
        )
        let requirements = winsRequired(round: round, seed: state.seed)
        let playerRequired = current.playerWinsRequired ?? requirements.player
        let opponentRequired = current.opponentWinsRequired ?? requirements.opponent
        let playerWins = current.playerWins + (won ? 1 : 0)
        let opponentWins = current.opponentWins + (won ? 0 : 1)
        let appearances = min(
            maximumDirectAppearances,
            current.totalDirectAppearances + (directlyPlayed ? 1 : 0)
        )
        let canContinueGameLedger = current.gameLines != nil || current.nextGameNumber == 1
        let newLine: ProPostseasonGameLine? = if let teamRuns, let opponentRuns {
            ProPostseasonGameLine(
                round: round,
                gameNumber: current.nextGameNumber,
                teamRuns: teamRuns,
                opponentRuns: opponentRuns,
                directlyPlayed: directlyPlayed,
                playerPitches: directlyPlayed ? max(0, pitches ?? 0) : nil,
                playerOuts: directlyPlayed ? max(0, outs ?? 0) : nil,
                playerRunsAllowed: directlyPlayed ? max(0, runsAllowed ?? 0) : nil
            )
        } else {
            nil
        }
        let gameLines = canContinueGameLedger && newLine != nil
            ? (current.gameLines ?? []) + [newLine!]
            : current.gameLines
        let canContinueHistory = state.gameHistory != nil || state.gamesPlayed == 0
        let history = canContinueHistory && newLine != nil
            ? (state.gameHistory ?? []) + [newLine!]
            : state.gameHistory
        let series = ProPostseasonSeriesState(
            round: round,
            opponentTeamID: current.opponentTeamID,
            playerWinsRequired: playerRequired,
            opponentWinsRequired: opponentRequired,
            playerWins: playerWins,
            opponentWins: opponentWins,
            nextGameNumber: current.nextGameNumber + 1,
            totalDirectAppearances: appearances,
            lastAppearancePitches: directlyPlayed ? max(0, pitches ?? 0) : current.lastAppearancePitches,
            lastAppearanceGameNumber: directlyPlayed
                ? current.nextGameNumber
                : current.lastAppearanceGameNumber,
            availabilityDecision: nil,
            gameLines: gameLines,
            rivalMemory: directlyPlayed ? (rivalMemory ?? current.rivalMemory) : current.rivalMemory
        )
        let played = state.gamesPlayed + 1
        if playerWins >= playerRequired {
            if let next = nextRound(after: round) {
                let nextSeries = openingSeries(
                    round: next,
                    seed: state.seed,
                    opponentTeamID: nil,
                    previousDirectAppearances: appearances
                )
                return ProPostseasonState(
                    seed: state.seed,
                    currentRound: next,
                    result: .inProgress,
                    gamesPlayed: played,
                    series: nextSeries,
                    gameHistory: history
                )
            }
            return ProPostseasonState(
                seed: state.seed,
                currentRound: .final,
                result: .champion,
                gamesPlayed: played,
                series: series,
                gameHistory: history
            )
        }
        if opponentWins >= opponentRequired {
            return ProPostseasonState(
                seed: state.seed,
                currentRound: round,
                result: round == .final ? .runnerUp : .eliminated,
                gamesPlayed: played,
                series: series,
                gameHistory: history
            )
        }
        return ProPostseasonState(
            seed: state.seed,
            currentRound: round,
            result: .inProgress,
            gamesPlayed: played,
            series: series,
            gameHistory: history
        )
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

    /// 정규시즌 승률 차이를 중심으로 순위 차이를 소폭 더한 포스트시즌 전력 우위.
    /// ±180으로 제한해 강팀도 단일 경기에서 충분히 질 수 있게 한다.
    public static func teamStrengthEdgePermille(
        _ state: ProCareerSnapshot,
        opponentTeamID: String? = nil
    ) -> Int {
        guard let opponentID = opponentTeamID ?? state.currentRival?.teamID else { return 0 }
        let rows = standings(state: state, week: LeagueTable.weeksPerSeason)
        guard let playerIndex = rows.firstIndex(where: { $0.teamID == state.team.id }),
              let opponentIndex = rows.firstIndex(where: { $0.teamID == opponentID }) else {
            return 0
        }
        let player = rows[playerIndex]
        let opponent = rows[opponentIndex]
        let playerRate = player.wins * 1_000 / max(1, player.wins + player.losses)
        let opponentRate = opponent.wins * 1_000 / max(1, opponent.wins + opponent.losses)
        let rankEdge = opponentIndex - playerIndex
        return min(180, max(-180, playerRate - opponentRate + rankEdge * 20))
    }

    public static func preparingSeries(
        _ postseason: ProPostseasonState,
        state: ProCareerSnapshot
    ) -> ProPostseasonState {
        guard postseason.result == .inProgress,
              let round = postseason.currentRound else { return postseason }
        if postseason.series?.round == round,
           postseason.series?.opponentTeamID != nil {
            return postseason
        }
        let opponentID = opponentTeamID(state: state, postseason: postseason, round: round)
        let requirements = winsRequired(round: round, seed: postseason.seed)
        let series: ProPostseasonSeriesState
        if let current = postseason.series {
            series = ProPostseasonSeriesState(
                round: round,
                opponentTeamID: opponentID,
                playerWinsRequired: requirements.player,
                opponentWinsRequired: requirements.opponent,
                playerWins: current.playerWins,
                opponentWins: current.opponentWins,
                nextGameNumber: current.nextGameNumber,
                totalDirectAppearances: current.totalDirectAppearances,
                lastAppearancePitches: current.lastAppearancePitches,
                lastAppearanceGameNumber: current.lastAppearanceGameNumber,
                availabilityDecision: current.availabilityDecision,
                gameLines: current.gameLines,
                rivalMemory: current.rivalMemory
            )
        } else {
            series = openingSeries(
                round: round,
                seed: postseason.seed,
                opponentTeamID: opponentID,
                previousDirectAppearances: postseason.gamesPlayed
            )
        }
        return ProPostseasonState(
            seed: postseason.seed,
            currentRound: round,
            result: postseason.result,
            gamesPlayed: postseason.gamesPlayed,
            series: series,
            gameHistory: postseason.gameHistory
        )
    }

    public static func opponentTeamID(
        state: ProCareerSnapshot,
        postseason: ProPostseasonState,
        round: ProAutumnRound
    ) -> String? {
        let rows = standings(state: state, week: LeagueTable.weeksPerSeason)
        func teamID(seed: Int) -> String? {
            rows.indices.contains(seed - 1) ? rows[seed - 1].teamID : nil
        }
        let candidates: [Int]
        switch round {
        case .wildCard:
            candidates = [postseason.seed == 4 ? 5 : 4]
        case .semifinal:
            candidates = postseason.seed == 3 ? [4, 5] : [3]
        case .playoff:
            candidates = postseason.seed == 2 ? [3, 4, 5] : [2]
        case .final:
            candidates = postseason.seed == 1 ? [2, 3, 4, 5] : [1]
        }
        let available = candidates.compactMap { seed in teamID(seed: seed).map { (seed, $0) } }
        guard !available.isEmpty else { return nil }
        if available.count == 1 { return available[0].1 }

        // 높은 시드가 더 자주 올라오되 하위 시드도 살아남는다. 후보 가중치는
        // 순서대로 n², (n-1)²…이며 커리어·시즌·라운드에 대해 결정론적이다.
        let weights = available.indices.map { index in
            let value = available.count - index
            return value * value
        }
        let total = weights.reduce(0, +)
        let hash = UInt64(StableHash.fnv1a64(
            "postseason-opponent|\(state.proCareerID)|\(state.season)|\(round.rawValue)"
        ), radix: 16) ?? 0
        var roll = Int(hash % UInt64(total))
        for (index, weight) in weights.enumerated() {
            if roll < weight { return available[index].1 }
            roll -= weight
        }
        return available[0].1
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
