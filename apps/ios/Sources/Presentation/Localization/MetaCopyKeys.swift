import Foundation
import BaseballIOSDomain

/// Shared collection, progression, setup, and system-surface copy.
enum MetaUICopyKey: String, CaseIterable, Sendable {
    case achievementsTitle = "meta.achievements.title"
    case achievementsOffline = "meta.achievements.offline"
    case achievementsUnlocked = "meta.achievements.status.unlocked"
    case achievementsLocked = "meta.achievements.status.locked"
    case achievementsAccessibility = "meta.achievements.accessibility"
    case achievementsBanner = "meta.achievements.banner"
    case achievementsDismiss = "meta.achievements.dismiss"
    case achievementsBannerItem = "meta.achievements.banner-item"

    case growthJackpotTitle = "meta.growth.jackpot.title"
    case growthTitle = "meta.growth.title"
    case growthClose = "meta.growth.close"
    case growthNextStep = "meta.growth.next-step"
    case growthJackpotBody = "meta.growth.jackpot.body"

    case careerSetupEyebrow = "meta.career-setup.eyebrow"
    case careerSetupTitle = "meta.career-setup.title"
    case careerSetupPlayerName = "meta.career-setup.player-name"
    case careerSetupNamePlaceholder = "meta.career-setup.name-placeholder"
    case careerSetupPitcherType = "meta.career-setup.pitcher-type"
    case careerSetupExplanation = "meta.career-setup.explanation"
    case careerSetupAction = "meta.career-setup.action"

    case weeklyPreparing = "meta.weekly.preparing"
    case weeklyProgramTitle = "meta.weekly.title"
    case weeklyClaimed = "meta.weekly.status.claimed"
    case weeklyRewardReady = "meta.weekly.status.reward-ready"
    case weeklyProgramProgress = "meta.weekly.status.progress"
    case weeklySummaryAccessibilityClaimed = "meta.weekly.summary.accessibility.claimed"
    case weeklySummaryAccessibilityReady = "meta.weekly.summary.accessibility.ready"
    case weeklySummaryAccessibilityProgress = "meta.weekly.summary.accessibility.progress"
    case weeklyInstructions = "meta.weekly.instructions"
    case weeklyTaskAccessibility = "meta.weekly.task.accessibility"
    case weeklyTaskAccessibilityComplete = "meta.weekly.task.accessibility.complete"
    case weeklyOneForStamp = "meta.weekly.one-for-stamp"
    case weeklyOneForPerfect = "meta.weekly.one-for-perfect"
    case weeklyClaimAction = "meta.weekly.claim-action"
    case weeklyStampPerfect = "meta.weekly.stamp.perfect"
    case weeklyStampComplete = "meta.weekly.stamp.complete"
    case weeklyVault = "meta.weekly.vault"
    case weeklyStampLinePerfect = "meta.weekly.vault.line-perfect"
    case weeklyStampLine = "meta.weekly.vault.line"
    case weeklyPerfectBadge = "meta.weekly.vault.perfect-badge"

    case abilityTalent = "meta.ability.talent"
    case abilityNoCeiling = "meta.ability.no-ceiling"
    case abilityCeiling = "meta.ability.ceiling"
    case abilityCeilingReached = "meta.ability.ceiling-reached"
    case abilityAccessibility = "meta.ability.accessibility"
    case abilityAccessibilityGained = "meta.ability.accessibility.gained"
    case abilityAccessibilityTalent = "meta.ability.accessibility.talent"
    case abilityBaseComplete = "meta.ability.base-complete"
    case masteryStuff = "meta.mastery.stuff"
    case masteryCommand = "meta.mastery.command"
    case masteryMovement = "meta.mastery.movement"
    case masteryStamina = "meta.mastery.stamina"
    case masteryLevel = "meta.mastery.level"
    case masteryProgress = "meta.mastery.progress"
    case masteryMeaning = "meta.mastery.meaning"
    case masteryAccessibility = "meta.mastery.accessibility"

    case statTileCurrentAccessibility = "meta.stat-tile.accessibility.current"
    case statTileCurrentCaptionAccessibility = "meta.stat-tile.accessibility.current-caption"
    case statTileChangedAccessibility = "meta.stat-tile.accessibility.changed"
    case statTileChangedCaptionAccessibility = "meta.stat-tile.accessibility.changed-caption"
    case settingsCopySectionTitle = "settings.copy.section-title"
    case settingsCopyDensity = "settings.copy.density"
    case settingsCopyDensityAutomatic = "settings.copy.density.automatic"
    case settingsCopyDensityExpanded = "settings.copy.density.expanded"
    case settingsCopyDensityCompact = "settings.copy.density.compact"
    case settingsCopyDensityFooter = "settings.copy.density.footer"
    case disclosureAccessibilityExpanded = "meta.disclosure.accessibility.expanded"
    case disclosureAccessibilityCollapsed = "meta.disclosure.accessibility.collapsed"
    case disclosureHintExpand = "meta.disclosure.hint.expand"
    case disclosureHintCollapse = "meta.disclosure.hint.collapse"
}

extension MetaUICopyKey {
    var gameCopyKey: GameCopyKey { .localizable(rawValue) }
}

extension GameCopyResolver {
    func resolve(_ key: MetaUICopyKey, arguments: [LocalizedCopyArgument] = []) -> String {
        resolve(key.gameCopyKey, arguments: arguments)
    }
}

extension AppCopyKey {
    static let metaKeys = MetaUICopyKey.allCases.map(\.gameCopyKey)
}

extension CopyDensity {
    var copyKey: MetaUICopyKey {
        switch self {
        case .automatic: .settingsCopyDensityAutomatic
        case .expanded: .settingsCopyDensityExpanded
        case .compact: .settingsCopyDensityCompact
        }
    }
}
