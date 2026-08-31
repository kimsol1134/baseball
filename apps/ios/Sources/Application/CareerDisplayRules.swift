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
}
