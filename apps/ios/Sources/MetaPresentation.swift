import Foundation
import SimulationCore

enum MetaPresentation {
    static func achievementTitle(_ achievement: Achievement, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return achievement.title }
        return resolver.resolve(.gameContent("content.achievement.\(achievement.rawValue).title"))
    }

    static func achievementDetail(_ achievement: Achievement, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return achievement.detail }
        return resolver.resolve(.gameContent("content.achievement.\(achievement.rawValue).detail"))
    }

    static func weeklyTaskTitle(_ kind: WeeklyTaskKind, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return kind.title }
        return resolver.resolve(.gameContent("content.weekly-task.\(kind.rawValue).title"))
    }

    static func weeklyTaskNextAction(_ kind: WeeklyTaskKind, resolver: GameCopyResolver) -> String {
        guard resolver.language == .english else { return kind.nextAction }
        return resolver.resolve(.gameContent("content.weekly-task.\(kind.rawValue).next-action"))
    }

    static func ratingMeaning(_ value: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(ratingMeaningKey(value))
    }

    static func ratingMeaning(_ step: RatingScale.Step, resolver: GameCopyResolver) -> String {
        resolver.resolve(ratingMeaningKey(step.minimum))
    }

    private static func ratingMeaningKey(_ value: Int) -> GameCopyKey {
        switch RatingScale.steps.first(where: { value >= $0.minimum })?.minimum {
        case 75: AppCopyKey.prologueAbilityMeaningBest
        case 65: AppCopyKey.prologueAbilityMeaningProTop
        case 55: AppCopyKey.prologueAbilityMeaningAbovePro
        case 50: AppCopyKey.prologueAbilityMeaningProAverage
        case 47: AppCopyKey.prologueAbilityMeaningRegional
        case 43: AppCopyKey.prologueAbilityMeaningHighSchool
        case 38: AppCopyKey.prologueAbilityMeaningStarter
        case 33: AppCopyKey.prologueAbilityMeaningDeveloping
        default: AppCopyKey.prologueAbilityMeaningFoundations
        }
    }
}
