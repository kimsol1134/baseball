import Foundation
import SimulationCore
import BaseballIOSDomain

/// 화면·프레젠테이션이 시뮬레이션 규칙 엔진을 직접 부르지 않도록 막는 조회 창구.
enum CareerDisplayRules {
    nonisolated static func draftEvaluationBreakdown(
        state: HighSchoolCareerSnapshot
    ) -> HighSchoolCareerEngine.DraftEvaluationBreakdown {
        HighSchoolCareerEngine.draftEvaluationBreakdown(state: state)
    }

    nonisolated static func recommendedTraining(state: HighSchoolCareerSnapshot) -> TrainingFocus {
        HighSchoolCareerEngine.recommendedTraining(state: state)
    }

    nonisolated static func recommendedTrainingIntensity(state: HighSchoolCareerSnapshot) -> TrainingIntensity {
        HighSchoolCareerEngine.recommendedTrainingIntensity(state: state)
    }

    enum FatigueDisplayBand: String, Sendable {
        case normal, tired, overwork, exhausted
    }

    nonisolated static func highSchoolFatigueBand(fatigue: Int) -> FatigueDisplayBand {
        if fatigue >= HighSchoolCareerEngine.fatigueDisplayExhaustionThreshold { return .exhausted }
        if fatigue >= HighSchoolCareerEngine.fatigueDisplayWarningThreshold { return .overwork }
        if fatigue >= HighSchoolCareerEngine.fatigueDisplayCautionThreshold { return .tired }
        return .normal
    }

    nonisolated static func proFatigueBand(fatigue: Int) -> FatigueDisplayBand {
        if fatigue >= ProWeekHealthForecast.fatigueDisplayExhaustionThreshold { return .exhausted }
        if fatigue >= ProWeekHealthForecast.fatigueDisplayWarningThreshold { return .overwork }
        if fatigue >= ProWeekHealthForecast.fatigueDisplayCautionThreshold { return .tired }
        return .normal
    }

    nonisolated static func recommendedRepertoire(presetID: String) -> StartingRepertoireSelection {
        PitchLearningRules.recommendedSelection(presetID: presetID)
    }

    nonisolated static var pitchLearningPracticeCap: Int {
        PitchLearningRules.maximumPracticeCredits
    }

    nonisolated static var pitchLearningQualityUses: Int {
        PitchLearningRules.requiredQualityUses
    }

    nonisolated static func pitcherIdentity(for pitcher: PitcherSnapshot) -> PitcherBuildIdentity {
        PitcherBuildRules.identity(for: pitcher)
    }

    nonisolated static func pitcherIdentity(for readout: PitchAbilityReadout) -> PitcherBuildIdentity {
        PitchAbilityRules.identity(for: readout)
    }

    nonisolated static func investmentCost(for investment: ProOffseasonInvestment) -> Int64 {
        ProFinanceRules.investmentCost(for: investment)
    }

    nonisolated static func usesContractDepthRules(_ state: ProCareerSnapshot) -> Bool {
        ProCareerEngine.usesContractDepthRules(state)
    }

    nonisolated static func totalGuaranteedSalary(for offer: ProContractOffer) -> Int {
        ProContractMarketRules.totalGuaranteedSalary(for: offer)
    }

    nonisolated static func signingBonusBand(for offer: ProContractOffer) -> String {
        ProContractMarketRules.signingBonusBand(for: offer)
    }

    nonisolated static func canRequestContractCounter(_ state: ProCareerSnapshot) -> Bool {
        guard usesContractDepthRules(state) else { return false }
        guard state.phase == .contractOffer else { return false }
        guard let market = state.journeyState?.pendingContractMarket,
              market.kind == .freeAgency,
              market.counterOffer == nil,
              let stay = market.offers.first(where: { $0.preservesTeamLegacy && $0.teamID == state.team.id }) else {
            return false
        }
        return stay.years >= 1
    }

    nonisolated static func canRequestExtraYear(_ state: ProCareerSnapshot) -> Bool {
        guard canRequestContractCounter(state),
              let market = state.journeyState?.pendingContractMarket,
              let stay = market.offers.first(where: { $0.preservesTeamLegacy && $0.teamID == state.team.id }) else {
            return false
        }
        let remaining = ProCareerEngine.maximumCareerSeasons - market.forSeason + 1
        return stay.years < 5 && stay.years < remaining
    }

    nonisolated static func counterAvailability(
        market: ProContractMarket,
        state: ProCareerSnapshot,
        kind: ProContractCounterKind
    ) -> ProCounterAvailability {
        ProContractMarketRules.counterAvailability(market: market, state: state, kind: kind)
    }

    nonisolated static func counterAvailability(
        for state: ProCareerSnapshot,
        kind: ProContractCounterKind
    ) -> ProCounterAvailability {
        guard let market = state.journeyState?.pendingContractMarket else {
            return .unavailable(.years)
        }
        return counterAvailability(market: market, state: state, kind: kind)
    }

    nonisolated static func offseasonInvestmentOptions(for state: ProCareerSnapshot) -> [ProOffseasonInvestment] {
        var options: [ProOffseasonInvestment] = [.pitchLab, .recoveryTeam, .fanFoundation]
        if usesContractDepthRules(state) {
            options.append(contentsOf: [.equipment, .personalTrainer])
        }
        options.append(.none)
        return options
    }

    nonisolated static var nicknameCatalogCount: Int {
        NicknameRules.catalogCount
    }

    nonisolated static var nicknameStrikeoutLadder: [Int] {
        NicknameRules.strikeoutLadder
    }

    nonisolated static func masteryBonusPermille(level: Int) -> Int {
        MasteryEffectRules.bonusPermille(level: level)
    }

    nonisolated static func relationshipTarget(
        forEventCategory category: String
    ) -> RelationshipTarget {
        HighSchoolCareerEngine.relationshipTarget(forEventCategory: category)
    }

    nonisolated static func usesFinalSeriesRules(_ state: ProCareerSnapshot) -> Bool {
        ProCareerEngine.usesFinalSeriesRules(state)
    }

    nonisolated static func liveClimate(for state: ProCareerSnapshot) -> ProSeasonClimate? {
        ProCareerEngine.liveClimate(for: state)
    }

    nonisolated static func liveBatterOffset(for state: ProCareerSnapshot) -> Int {
        ProCareerEngine.liveBatterOffset(for: state)
    }

    nonisolated static func shouldOfferRoleRequest(_ state: ProCareerSnapshot) -> Bool {
        ProRoleRequestRules.shouldOffer(state)
    }

    nonisolated static var roleRequestRoles: [ProRole] {
        ProRoleRequestRules.requestableRoles
    }

    nonisolated static func roleRequestEvaluation(
        state: ProCareerSnapshot,
        requested: ProRole
    ) -> ProRoleRequestEvaluation {
        ProRoleRequestRules.evaluate(state: state, requested: requested)
    }

    nonisolated static func isAlreadyAssignedRole(
        _ requested: ProRole,
        state: ProCareerSnapshot
    ) -> Bool {
        ProRoleRequestRules.isAlreadyAssigned(requested, state: state)
    }

    nonisolated static func shouldOfferNationalTeamCall(_ state: ProCareerSnapshot) -> Bool {
        ProNationalTeamRules.shouldOfferCall(state)
    }

    nonisolated static func nationalFinalBatterOffset() -> Int {
        ProNationalTeamRules.finalBatterOffset
    }

    nonisolated static func nationalOpponentNameKey(_ opponentID: String) -> String {
        "content.national-team.opponent.\(opponentID)"
    }

    nonisolated static func nationalTeamMarketScore(_ state: ProCareerSnapshot) -> Int {
        ProNationalTeamRules.marketScore(for: state)
    }

    nonisolated static func nationalTeamFanSupport(_ state: ProCareerSnapshot) -> Int {
        state.journeyState?.reputation.fanSupport ?? 0
    }

    nonisolated static func goalBoard(for state: ProCareerSnapshot) -> ProCareerGoalBoard {
        ProCareerGoalBoardRules.board(state: state)
    }

    nonisolated static func advancementBoard(for state: ProCareerSnapshot) -> ProAdvancementBoard {
        ProAdvancementRules.board(state: state)
    }

    nonisolated static func abilityHistory(for state: ProCareerSnapshot) -> [AbilityHistoryPoint] {
        AbilityGrowthHistoryRules.history(state: state)
    }

    nonisolated static func seasonComparison(for state: ProCareerSnapshot) -> CareerComparison? {
        ProSeasonComparisonRules.compare(state: state)
    }

    /// 회차 기록을 코어가 아는 모양으로 옮겨 담아 계보 비교를 만든다.
    nonisolated static func lineageComparison(for records: [LifeRecord]) -> CareerComparison? {
        CareerLineageComparisonRules.compare(lives: records.map {
            CareerLifeSummary(
                lifeNumber: $0.lifeNumber,
                games: $0.games,
                strikeouts: $0.strikeouts,
                walks: $0.walks,
                runsAllowed: $0.runsAllowed,
                evaluationScore: $0.evaluationScore
            )
        })
    }

    nonisolated static func goalPermille(current: Int, target: Int, completed: Bool = false) -> Int {
        ProCareerGoalBoardRules.permille(current: current, target: target, completed: completed)
    }

    nonisolated static func goalPermilleBand(_ permille: Int) -> String {
        ProCareerGoalBoardRules.permilleBand(permille)
    }

    nonisolated static func saberBoard(for state: ProCareerSnapshot) -> SaberMetricsBoard {
        let lines = state.gameLines ?? []
        return SabermetricsRules.board(
            completed: state.careerStats,
            current: displaying(state.currentStats, lines: lines),
            currentLines: lines
        )
    }

    nonisolated static func saberSeason(_ stats: ProSeasonStats, lines: [ProGameLine] = []) -> SaberMetricsLine {
        SabermetricsRules.season(displaying(stats, lines: lines), lines: lines)
    }

    private nonisolated static func displaying(
        _ stats: ProSeasonStats,
        lines: [ProGameLine]
    ) -> ProSeasonStats {
        ProSeasonStats(
            season: stats.season,
            teamID: stats.teamID,
            games: stats.games,
            starts: stats.starts,
            inningsOuts: stats.inningsOuts,
            strikeouts: stats.strikeouts,
            walks: stats.walks,
            runsAllowed: stats.runsAllowed,
            hits: max(stats.hits, lines.reduce(0) { $0 + ($1.hits ?? 0) }),
            homeRuns: max(stats.homeRuns, lines.reduce(0) { $0 + ($1.homeRuns ?? 0) }),
            pitches: stats.pitches,
            wins: stats.wins,
            losses: stats.losses,
            saves: stats.saves,
            postseasonGames: stats.postseasonGames
        )
    }

    struct ChallengeStamp: Equatable, Sendable {
        let seed: String
        let lifeNumber: Int

        var code: String { "\(seed)-\(lifeNumber)" }
    }

    /// Existing imprint `"<seed>-<life>"`. Parses `career-<seed>-life-<n>` or a fallback seed.
    nonisolated static func challengeStamp(
        highSchoolCareerID: String?,
        lifeNumber: Int? = nil,
        fallbackSeed: String? = nil
    ) -> ChallengeStamp? {
        if let careerID = highSchoolCareerID, careerID.hasPrefix("career-") {
            let parts = careerID.split(separator: "-")
            if parts.count >= 2 {
                let seed = String(parts[1])
                if parts.count >= 4, parts[2] == "life", let parsed = Int(parts[3]) {
                    return ChallengeStamp(seed: seed, lifeNumber: parsed)
                }
                if let lifeNumber {
                    return ChallengeStamp(seed: seed, lifeNumber: lifeNumber)
                }
            }
        }
        if let fallbackSeed, !fallbackSeed.isEmpty {
            return ChallengeStamp(seed: fallbackSeed, lifeNumber: lifeNumber ?? 1)
        }
        return nil
    }
}
