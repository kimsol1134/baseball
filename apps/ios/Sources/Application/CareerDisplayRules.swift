import Foundation
import SimulationCore
import BaseballIOSDomain

/// 화면·프레젠테이션이 시뮬레이션 규칙 엔진을 직접 부르지 않도록 막는 조회 창구.
enum CareerDisplayRules {
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

    nonisolated static func goalPermille(current: Int, target: Int, completed: Bool = false) -> Int {
        ProCareerGoalBoardRules.permille(current: current, target: target, completed: completed)
    }

    nonisolated static func goalPermilleBand(_ permille: Int) -> String {
        ProCareerGoalBoardRules.permilleBand(permille)
    }
}
