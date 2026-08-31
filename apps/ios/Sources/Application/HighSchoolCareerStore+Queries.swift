import Foundation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension HighSchoolCareerStore {
    nonisolated static var regions: [String] { HighSchoolCareerEngine.regions }

    nonisolated static var teams: [DraftTeamSnapshot] { HighSchoolCareerEngine.teams }

    nonisolated static func schools(for region: String) -> [SchoolSnapshot] {
        HighSchoolCareerEngine.schools(for: region)
    }

    func trainingOutlook(
        state: HighSchoolCareerSnapshot,
        focus: TrainingFocus,
        intensity: TrainingIntensity
    ) -> HighSchoolCareerEngine.TrainingGrowthOutlook {
        engine.trainingOutlook(state: state, focus: focus, intensity: intensity)
    }

    nonisolated static func trainingOutlook(
        state: HighSchoolCareerSnapshot,
        focus: TrainingFocus,
        intensity: TrainingIntensity
    ) -> HighSchoolCareerEngine.TrainingGrowthOutlook {
        HighSchoolCareerEngine().trainingOutlook(state: state, focus: focus, intensity: intensity)
    }

    nonisolated static func draftForecast(state: HighSchoolCareerSnapshot) -> HighSchoolCareerEngine.DraftForecastSnapshot {
        HighSchoolCareerEngine.draftForecast(state: state)
    }

    var draftForecast: HighSchoolCareerEngine.DraftForecastSnapshot? {
        state.map(Self.draftForecast(state:))
    }

    nonisolated static func appliedInheritance(for points: Int, storedRulesVersion: Int?) -> Int {
        HighSchoolCareerEngine.appliedInheritance(for: points, storedRulesVersion: storedRulesVersion)
    }

    nonisolated static func nextInheritanceStep(
        for points: Int,
        storedRulesVersion: Int?
    ) -> (soulPoints: Int, applied: Int)? {
        HighSchoolCareerEngine.nextInheritanceStep(for: points, storedRulesVersion: storedRulesVersion)
    }

    nonisolated static func recommendedRepertoire(presetID: String) -> StartingRepertoireSelection {
        CareerDisplayRules.recommendedRepertoire(presetID: presetID)
    }

    nonisolated static var pitchLearningPracticeCap: Int {
        CareerDisplayRules.pitchLearningPracticeCap
    }

    nonisolated static var pitchLearningQualityUses: Int {
        CareerDisplayRules.pitchLearningQualityUses
    }

    nonisolated static func pitcherIdentity(for pitcher: PitcherSnapshot) -> PitcherBuildIdentity {
        CareerDisplayRules.pitcherIdentity(for: pitcher)
    }

    nonisolated static var nicknameCatalogCount: Int {
        CareerDisplayRules.nicknameCatalogCount
    }

    nonisolated static var nicknameStrikeoutLadder: [Int] {
        CareerDisplayRules.nicknameStrikeoutLadder
    }

    nonisolated static func masteryBonusPermille(level: Int) -> Int {
        CareerDisplayRules.masteryBonusPermille(level: level)
    }
}
