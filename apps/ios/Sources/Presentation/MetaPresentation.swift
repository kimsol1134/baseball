import Foundation
import SimulationCore
import BaseballIOSDomain

enum MetaPresentation {
    static func achievementTitle(_ achievement: Achievement, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return achievement.title }
        return resolver.resolve(.gameContent("content.achievement.\(achievement.rawValue).title"))
    }

    static func achievementDetail(_ achievement: Achievement, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return achievement.detail }
        return resolver.resolve(.gameContent("content.achievement.\(achievement.rawValue).detail"))
    }

    static func weeklyTaskTitle(_ kind: WeeklyTaskKind, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return kind.title }
        return resolver.resolve(.gameContent("content.weekly-task.\(kind.rawValue).title"))
    }

    static func weeklyTaskNextAction(_ kind: WeeklyTaskKind, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return kind.nextAction }
        return resolver.resolve(.gameContent("content.weekly-task.\(kind.rawValue).next-action"))
    }

    static func ratingMeaning(
        _ value: Int,
        context: GrowthStageContext = .highSchool,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ratingMeaningKey(value, context: context))
    }

    static func ratingMeaning(
        _ step: RatingScale.Step,
        context: GrowthStageContext = .highSchool,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ratingMeaningKey(step.minimum, context: context))
    }

    static func ratingMeaningKey(_ value: Int, context: GrowthStageContext) -> GameCopyKey {
        let minimum = RatingScale.steps.first(where: { value >= $0.minimum })?.minimum
        if context == .pro {
            return switch minimum {
            case 75: MetaUICopyKey.growthMeaningBest.gameCopyKey
            case 65: MetaUICopyKey.growthMeaningProTop.gameCopyKey
            case 55: MetaUICopyKey.growthMeaningAbovePro.gameCopyKey
            case 50: MetaUICopyKey.growthMeaningProAverage.gameCopyKey
            case 47: MetaUICopyKey.growthMeaningRotation.gameCopyKey
            case 43: MetaUICopyKey.growthMeaningCallUp.gameCopyKey
            case 38: MetaUICopyKey.growthMeaningRole.gameCopyKey
            case 33: MetaUICopyKey.growthMeaningFarm.gameCopyKey
            default: MetaUICopyKey.growthMeaningAdjusting.gameCopyKey
            }
        }
        return switch minimum {
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
