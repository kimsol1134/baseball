import Foundation
import SimulationCore

/// The String Catalog table that owns a localized copy key.
public enum GameCopyTable: String, CaseIterable, Hashable, Sendable {
    case localizable = "Localizable"
    case gameContent = "GameContent"
}

/// Stable semantic identifiers for localized display copy.
///
/// The fixed cases are the Phase A catalog spike. `semantic` is the controlled bridge for
/// stable-ID content emitted by SimulationCore. Arbitrary dynamic keys are deliberately not
/// included in `allCases`; the statically declared iOS UI keys are included so catalog coverage
/// tests can enumerate them while core-emitted IDs remain inventory-driven.
public enum GameCopyKey: Hashable, Sendable, CaseIterable {
    case appTitle
    case actionNext
    case actionClose
    case settingsAudioTitle
    case settingsAudioSound
    case errorTextUnavailable
    case accessibilityStatLine
    case notificationReturnTitle
    case notificationReturnBody
    case shareCareerSummary
    case pitchResultStrike
    case draftUndraftedTitle
    case schoolHanbitTraditionalName
    case semantic(String, table: GameCopyTable)

    public static let allCases: [GameCopyKey] = [
        .appTitle,
        .actionNext,
        .actionClose,
        .settingsAudioTitle,
        .settingsAudioSound,
        .errorTextUnavailable,
        .accessibilityStatLine,
        .notificationReturnTitle,
        .notificationReturnBody,
        .shareCareerSummary,
        .pitchResultStrike,
        .draftUndraftedTitle,
        .schoolHanbitTraditionalName,
    ] + AppCopyKey.allCases

    public var rawValue: String {
        switch self {
        case .appTitle: "app.title"
        case .actionNext: "action.next"
        case .actionClose: "action.close"
        case .settingsAudioTitle: "settings.audio.title"
        case .settingsAudioSound: "settings.audio.sound"
        case .errorTextUnavailable: "error.text-unavailable"
        case .accessibilityStatLine: "accessibility.stat.line"
        case .notificationReturnTitle: "notification.return.title"
        case .notificationReturnBody: "notification.return.body"
        case .shareCareerSummary: "share.career.summary"
        case .pitchResultStrike: "content.pitch.result.strike"
        case .draftUndraftedTitle: "content.draft.undrafted.title"
        case .schoolHanbitTraditionalName: "content.school.hanbit_traditional.name"
        case .semantic(let value, _): value
        }
    }

    public var table: GameCopyTable {
        switch self {
        case .pitchResultStrike, .draftUndraftedTitle, .schoolHanbitTraditionalName:
            .gameContent
        case .semantic(_, let table):
            table
        default:
            .localizable
        }
    }

    /// Maps a core semantic ID without reading or transforming a source sentence.
    public init?(semanticID: String, table: GameCopyTable? = nil) {
        guard Self.isSemanticID(semanticID) else { return nil }
        self = .semantic(semanticID, table: table ?? Self.table(for: semanticID))
    }

    /// Creates a semantic key owned by the static iOS UI catalog.
    public static func localizable(_ semanticID: String) -> GameCopyKey {
        precondition(isSemanticID(semanticID), "Invalid iOS localization key: \(semanticID)")
        return .semantic(semanticID, table: .localizable)
    }

    /// Creates a semantic key owned by the game-content catalog.
    public static func gameContent(_ semanticID: String) -> GameCopyKey {
        precondition(isSemanticID(semanticID), "Invalid game-content key: \(semanticID)")
        return .semantic(semanticID, table: .gameContent)
    }

    public init?(coreToken: SimulationCore.CopyToken) {
        self.init(semanticID: coreToken.key)
    }

    /// The bridge accepts only lowercase semantic IDs with separators. This rejects Korean
    /// source text, whitespace, interpolation fragments, and arbitrary runtime sentences.
    public static func isSemanticID(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.first?.isLowercase == true,
              value.contains(".") || value.contains("-") else { return false }

        var previousWasSeparator = false
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x2E, 0x2D:
                guard !previousWasSeparator else { return false }
                previousWasSeparator = true
            case 0x61...0x7A, 0x30...0x39, 0x5F:
                previousWasSeparator = false
            default:
                return false
            }
        }
        return !previousWasSeparator
    }

    private static func table(for semanticID: String) -> GameCopyTable {
        semanticID.hasPrefix("content.") ? .gameContent : .localizable
    }
}

/// The copy schema is versioned independently from save keys and event names.
public enum GameCopySchema {
    public static let currentVersion = 1
    public static let version = currentVersion
}

/// Semantic keys used by the first static iOS UI batch. Keeping these identifiers in one place
/// prevents a view from quietly turning a Korean source sentence into a lookup key.
public enum AppCopyKey {
    public static let tabHighSchool = GameCopyKey.localizable("app.tab.high-school")
    public static let tabPro = GameCopyKey.localizable("app.tab.pro")
    public static let tabRecords = GameCopyKey.localizable("app.tab.records")
    public static let tabSettings = GameCopyKey.localizable("app.tab.settings")

    public static let openingEyebrow = GameCopyKey.localizable("opening.eyebrow")
    public static let openingSummary = GameCopyKey.localizable("opening.summary")
    public static let openingDescription = GameCopyKey.localizable("opening.description")
    public static let openingStart = GameCopyKey.localizable("opening.start")

    public static let prologueFirstLifeTitle = GameCopyKey.localizable("prologue.title.first-life")
    public static let prologueRebirthTitle = GameCopyKey.localizable("prologue.title.rebirth")
    public static let prologueFirstLifeCoachQuote = GameCopyKey.localizable("prologue.coach.quote.first-life")
    public static let prologueWindHeading = GameCopyKey.localizable("prologue.wind.heading")
    public static let prologueWindNeutralExplanation = GameCopyKey.localizable("prologue.wind.neutral-explanation")
    public static let prologueWindAccessibility = GameCopyKey.localizable("prologue.wind.accessibility")
    public static let prologueHandicapHeading = GameCopyKey.localizable("prologue.handicap.heading")
    public static let prologueThrow = GameCopyKey.localizable("prologue.action.throw")
    public static let prologueSkip = GameCopyKey.localizable("prologue.action.skip")
    public static let prologueCurrentPlayerTitle = GameCopyKey.localizable("prologue.current-player.title")
    public static let prologueInheritedStartTitle = GameCopyKey.localizable("prologue.inherited-start.title")
    public static let prologueInheritedStartJourney = GameCopyKey.localizable("prologue.inherited-start.journey")
    public static let prologueInheritedStartTotal = GameCopyKey.localizable("prologue.inherited-start.total")
    public static let prologueInheritedStartSoul = GameCopyKey.localizable("prologue.inherited-start.source.soul")
    public static let prologueInheritedStartBoost = GameCopyKey.localizable("prologue.inherited-start.source.boost")
    public static let prologueInheritedStartSource = GameCopyKey.localizable("prologue.inherited-start.source.line")
    public static let prologueAbilityTalent = GameCopyKey.localizable("prologue.ability.talent")
    public static let prologueAbilityCeiling = GameCopyKey.localizable("prologue.ability.ceiling")
    public static let prologueAbilityNoCeiling = GameCopyKey.localizable("prologue.ability.no-ceiling")
    public static let prologueAbilityExplanation = GameCopyKey.localizable("prologue.ability.explanation")
    public static let prologueAbilityAccessibility = GameCopyKey.localizable("prologue.ability.accessibility")
    public static let prologueAbilityMeaningBest = GameCopyKey.localizable("prologue.ability.meaning.best")
    public static let prologueAbilityMeaningProTop = GameCopyKey.localizable("prologue.ability.meaning.pro-top")
    public static let prologueAbilityMeaningAbovePro = GameCopyKey.localizable("prologue.ability.meaning.above-pro")
    public static let prologueAbilityMeaningProAverage = GameCopyKey.localizable("prologue.ability.meaning.pro-average")
    public static let prologueAbilityMeaningRegional = GameCopyKey.localizable("prologue.ability.meaning.regional")
    public static let prologueAbilityMeaningHighSchool = GameCopyKey.localizable("prologue.ability.meaning.high-school")
    public static let prologueAbilityMeaningStarter = GameCopyKey.localizable("prologue.ability.meaning.starter")
    public static let prologueAbilityMeaningDeveloping = GameCopyKey.localizable("prologue.ability.meaning.developing")
    public static let prologueAbilityMeaningFoundations = GameCopyKey.localizable("prologue.ability.meaning.foundations")
    public static let prologueAbilityCeilingReached = GameCopyKey.localizable("prologue.ability.ceiling-reached")

    public static let prologueKeys: [GameCopyKey] = [
        prologueFirstLifeTitle, prologueRebirthTitle, prologueFirstLifeCoachQuote,
        prologueWindHeading, prologueWindNeutralExplanation, prologueWindAccessibility,
        prologueHandicapHeading, prologueThrow, prologueSkip, prologueCurrentPlayerTitle,
        prologueInheritedStartTitle, prologueInheritedStartJourney,
        prologueInheritedStartTotal, prologueInheritedStartSoul,
        prologueInheritedStartBoost, prologueInheritedStartSource,
        prologueAbilityTalent, prologueAbilityCeiling, prologueAbilityNoCeiling,
        prologueAbilityExplanation, prologueAbilityAccessibility,
        prologueAbilityMeaningBest, prologueAbilityMeaningProTop,
        prologueAbilityMeaningAbovePro, prologueAbilityMeaningProAverage,
        prologueAbilityMeaningRegional, prologueAbilityMeaningHighSchool,
        prologueAbilityMeaningStarter, prologueAbilityMeaningDeveloping,
        prologueAbilityMeaningFoundations, prologueAbilityCeilingReached,
    ]

    public static let actionCancel = GameCopyKey.localizable("action.cancel")

    public static let reminderNudgeTitle = GameCopyKey.localizable("reminder.nudge.title")
    public static let reminderNudgeBody = GameCopyKey.localizable("reminder.nudge.body")
    public static let reminderNudgeEnable = GameCopyKey.localizable("reminder.nudge.enable")
    public static let reminderNudgeDecline = GameCopyKey.localizable("reminder.nudge.decline")
    public static let reminderNudgeAccessibility = GameCopyKey.localizable("reminder.nudge.accessibility")

    public static let reminderNudgeKeys: [GameCopyKey] = [
        reminderNudgeTitle, reminderNudgeBody, reminderNudgeEnable,
        reminderNudgeDecline, reminderNudgeAccessibility,
    ]

    public static let challengeEndEyebrow = GameCopyKey.localizable("challenge.end.eyebrow")
    public static let challengeEndScore = GameCopyKey.localizable("challenge.end.score")
    public static let challengeEndStats = GameCopyKey.localizable("challenge.end.stats")
    public static let challengeEndDisclaimer = GameCopyKey.localizable("challenge.end.disclaimer")
    public static let challengeEndCTA = GameCopyKey.localizable("challenge.end.cta")
    public static let challengeEndAccessibility = GameCopyKey.localizable("challenge.end.accessibility")
    public static let challengeEndCloseHint = GameCopyKey.localizable("challenge.end.close.hint")
    public static let challengeEndOutcomeDrafted = GameCopyKey.localizable("challenge.end.outcome.drafted")
    public static let challengeEndOutcomeUndrafted = GameCopyKey.localizable("challenge.end.outcome.undrafted")

    public static let challengeEndKeys: [GameCopyKey] = [
        challengeEndEyebrow, challengeEndScore, challengeEndStats,
        challengeEndDisclaimer, challengeEndCTA, challengeEndAccessibility,
        challengeEndCloseHint, challengeEndOutcomeDrafted, challengeEndOutcomeUndrafted,
    ]

    public static let importantGameOpponentTitle = GameCopyKey.localizable("content.important-game.opponent.title")
    public static let importantGameFinalShowdownTitle = GameCopyKey.localizable("content.important-game.final-showdown.title")
    public static let importantGameFinalShowdownBody = GameCopyKey.localizable("content.important-game.final-showdown.body")
    public static let importantGameSituationZero = GameCopyKey.localizable("content.important-game.display.situation.zero")
    public static let importantGameSituationOne = GameCopyKey.localizable("content.important-game.display.situation.one")
    public static let importantGameSituationMany = GameCopyKey.localizable("content.important-game.display.situation.many")
    public static let importantGameCareerMatchup = GameCopyKey.localizable("content.important-game.career-matchup.line")
    public static let importantGameStartAction = GameCopyKey.localizable("content.important-game.action.start")
    public static let importantGameScenarioAccessibility = GameCopyKey.localizable("content.important-game.accessibility.scenario")
    public static let importantGameRivalAccessibility = GameCopyKey.localizable("content.important-game.accessibility.rival")
    public static let importantGameRivalAccessibilitySignature = GameCopyKey.localizable("content.important-game.accessibility.rival.signature")

    public static let importantGameKeys: [GameCopyKey] = [
        importantGameOpponentTitle, importantGameFinalShowdownTitle, importantGameFinalShowdownBody,
        importantGameSituationZero, importantGameSituationOne, importantGameSituationMany,
        importantGameCareerMatchup, importantGameStartAction, importantGameScenarioAccessibility,
        importantGameRivalAccessibility, importantGameRivalAccessibilitySignature,
    ]

    public static let awakeningReadOnlyEmpty = GameCopyKey.localizable("awakening.read-only.empty")
    public static let awakeningReadOnlyProgress = GameCopyKey.localizable("awakening.read-only.progress")
    public static let awakeningGuide = GameCopyKey.localizable("awakening.guide")
    public static let awakeningEyebrow = GameCopyKey.localizable("awakening.key-art.eyebrow")
    public static let awakeningKeyArtTitle = GameCopyKey.localizable("awakening.key-art.title")
    public static let awakeningCounter = GameCopyKey.localizable("awakening.counter")
    public static let awakeningSelectionGuidance = GameCopyKey.localizable("awakening.selection.guidance")
    public static let awakeningSparkLeaps = GameCopyKey.localizable("awakening.spark.leaps")
    public static let awakeningSparkBeforeFirstGame = GameCopyKey.localizable("awakening.spark.before-first-game")
    public static let awakeningSparkNeedsProof = GameCopyKey.localizable("awakening.spark.needs-proof")
    public static let awakeningConfirmationTitle = GameCopyKey.localizable("awakening.confirmation.title")
    public static let awakeningConfirmationAction = GameCopyKey.localizable("awakening.confirmation.action")
    public static let awakeningConfirmationCancel = GameCopyKey.localizable("awakening.confirmation.cancel")
    public static let awakeningConfirmationMessage = GameCopyKey.localizable("awakening.confirmation.message")
    public static let awakeningBranchTitle = GameCopyKey.localizable("awakening.branch.title")
    public static let awakeningBranchSelectedCount = GameCopyKey.localizable("awakening.branch.selected-count")
    public static let awakeningTierLabel = GameCopyKey.localizable("awakening.tier.label")
    public static let awakeningLeapLabel = GameCopyKey.localizable("awakening.node.leap")
    public static let awakeningNextLabel = GameCopyKey.localizable("awakening.node.next")
    public static let awakeningSelectLabel = GameCopyKey.localizable("awakening.node.select")
    public static let awakeningLockReason = GameCopyKey.localizable("awakening.node.lock-reason")
    public static let awakeningNodeVoiceOwned = GameCopyKey.localizable("awakening.node.voice.owned")
    public static let awakeningNodeVoiceAvailableNow = GameCopyKey.localizable("awakening.node.voice.available-now")
    public static let awakeningNodeVoiceAvailableNext = GameCopyKey.localizable("awakening.node.voice.available-next")
    public static let awakeningNodeVoiceLocked = GameCopyKey.localizable("awakening.node.voice.locked")
    public static let awakeningSummaryTitle = GameCopyKey.localizable("awakening.summary.title")
    public static let awakeningSummaryEmpty = GameCopyKey.localizable("awakening.summary.empty")
    public static let awakeningSheetTitle = GameCopyKey.localizable("awakening.sheet.title")
    public static let awakeningSheetDone = GameCopyKey.localizable("awakening.sheet.done")

    public static let awakeningKeys: [GameCopyKey] = [
        awakeningReadOnlyEmpty, awakeningReadOnlyProgress, awakeningGuide,
        awakeningEyebrow, awakeningKeyArtTitle, awakeningCounter, awakeningSelectionGuidance,
        awakeningSparkLeaps, awakeningSparkBeforeFirstGame, awakeningSparkNeedsProof,
        awakeningConfirmationTitle, awakeningConfirmationAction, awakeningConfirmationCancel,
        awakeningConfirmationMessage, awakeningBranchTitle, awakeningBranchSelectedCount,
        awakeningTierLabel, awakeningLeapLabel, awakeningNextLabel, awakeningSelectLabel,
        awakeningLockReason, awakeningNodeVoiceOwned, awakeningNodeVoiceAvailableNow,
        awakeningNodeVoiceAvailableNext, awakeningNodeVoiceLocked, awakeningSummaryTitle,
        awakeningSummaryEmpty, awakeningSheetTitle, awakeningSheetDone,
    ]

    public static let schoolSelectionTitle = GameCopyKey.localizable("school.selection.title")
    public static let schoolSelectionStrength = GameCopyKey.localizable("school.selection.strength")
    public static let schoolSelectionCoach = GameCopyKey.localizable("school.selection.coach")
    public static let schoolSelectionCatcher = GameCopyKey.localizable("school.selection.catcher")
    public static let schoolSelectionCardAccessibility = GameCopyKey.localizable("school.selection.card.accessibility")
    public static let schoolSelectionConfirmTitle = GameCopyKey.localizable("school.selection.confirm.title")
    public static let schoolSelectionConfirmAction = GameCopyKey.localizable("school.selection.confirm.action")
    public static let schoolSelectionConfirmCancel = GameCopyKey.localizable("school.selection.confirm.cancel")
    public static let schoolSelectionConfirmMessage = GameCopyKey.localizable("school.selection.confirm.message")

    public static let schoolSelectionKeys: [GameCopyKey] = [
        schoolSelectionTitle, schoolSelectionStrength, schoolSelectionCoach, schoolSelectionCatcher,
        schoolSelectionCardAccessibility, schoolSelectionConfirmTitle, schoolSelectionConfirmAction,
        schoolSelectionConfirmCancel, schoolSelectionConfirmMessage,
    ]

    public static let chapterHeaderEyebrowFirst = GameCopyKey.localizable("chapter.header.eyebrow.first")
    public static let chapterHeaderEyebrowRepeat = GameCopyKey.localizable("chapter.header.eyebrow.repeat")
    public static let chapterHeaderTitle = GameCopyKey.localizable("chapter.header.title")
    public static let chapterMetricFatigue = GameCopyKey.localizable("chapter.metric.fatigue")
    public static let chapterMetricTeamTrust = GameCopyKey.localizable("chapter.metric.team-trust")
    public static let chapterMetricTraining = GameCopyKey.localizable("chapter.metric.training")
    public static let chapterWindExpand = GameCopyKey.localizable("chapter.wind.expand")
    public static let chapterWindCollapse = GameCopyKey.localizable("chapter.wind.collapse")
    public static let chapterWindAccessibility = GameCopyKey.localizable("chapter.wind.accessibility")
    public static let chapterWindEffect = GameCopyKey.localizable("chapter.wind.effect")

    public static let chapterHeaderKeys: [GameCopyKey] = [
        chapterHeaderEyebrowFirst, chapterHeaderEyebrowRepeat, chapterHeaderTitle,
        chapterMetricFatigue, chapterMetricTeamTrust, chapterMetricTraining,
        chapterWindExpand, chapterWindCollapse, chapterWindAccessibility, chapterWindEffect,
    ]

    public static let chapterReviewCardTitle = GameCopyKey.localizable("chapter.review.card.title")
    public static let chapterReviewStatLine = GameCopyKey.localizable("chapter.review.stat-line")
    public static let chapterReviewGrowthTitle = GameCopyKey.localizable("chapter.review.growth.title")
    public static let chapterReviewGrowthEmptyNoTraining = GameCopyKey.localizable("chapter.review.growth.empty.no-training")
    public static let chapterReviewGrowthEmptyWithTraining = GameCopyKey.localizable("chapter.review.growth.empty.with-training")
    public static let chapterReviewGrowthSummary = GameCopyKey.localizable("chapter.review.growth.summary")
    public static let chapterReviewAbilitiesTitle = GameCopyKey.localizable("chapter.review.abilities.title")
    public static let chapterReviewAbilityAccessibility = GameCopyKey.localizable("chapter.review.ability.accessibility")
    public static let chapterReviewNextStoryRival = GameCopyKey.localizable("chapter.review.next-story.rival")
    public static let chapterReviewContinue = GameCopyKey.localizable("chapter.review.continue")

    public static let chapterReviewKeys: [GameCopyKey] = [
        chapterReviewCardTitle, chapterReviewStatLine, chapterReviewGrowthTitle,
        chapterReviewGrowthEmptyNoTraining, chapterReviewGrowthEmptyWithTraining,
        chapterReviewGrowthSummary, chapterReviewAbilitiesTitle, chapterReviewAbilityAccessibility,
        chapterReviewNextStoryRival,
        chapterReviewContinue,
    ]

    public static let tournamentAceStart = GameCopyKey.localizable("tournament.ace-start")
    public static let tournamentDash = GameCopyKey.localizable("tournament.dash")
    public static let tournamentNationalNote = GameCopyKey.localizable("tournament.national-note")

    public static let tournamentKeys: [GameCopyKey] = [
        tournamentAceStart, tournamentDash, tournamentNationalNote,
    ]

    public static let chapterGoalCompleted = GameCopyKey.localizable("chapter.goal.completed")
    public static let chapterGoalProgress = GameCopyKey.localizable("chapter.goal.progress")

    public static let chapterGoalKeys: [GameCopyKey] = [
        chapterGoalCompleted, chapterGoalProgress,
    ]

    public static let trainingArmHealthRecovering = GameCopyKey.localizable("training.arm-health.guidance.recovering")
    public static let trainingArmHealthRisk = GameCopyKey.localizable("training.arm-health.guidance.risk")
    public static let trainingOpportunityTitle = GameCopyKey.localizable("training.opportunity.title")
    public static let trainingPrompt = GameCopyKey.localizable("training.prompt")
    public static let trainingBadgeOpportunity = GameCopyKey.localizable("training.badge.opportunity")
    public static let trainingBadgeSchoolStrength = GameCopyKey.localizable("training.badge.school-strength")
    public static let trainingPitchPickerTitle = GameCopyKey.localizable("training.pitch-picker.title")
    public static let trainingIntensityTitle = GameCopyKey.localizable("training.intensity.title")
    public static let trainingDoubleBonus = GameCopyKey.localizable("training.double-bonus")
    public static let trainingCommit = GameCopyKey.localizable("training.commit")
    public static let trainingRepeatTitle = GameCopyKey.localizable("training.repeat.title")
    public static let trainingRepeatStopExplanation = GameCopyKey.localizable("training.repeat.stop-explanation")

    public static let trainingKeys: [GameCopyKey] = [
        trainingArmHealthRecovering, trainingArmHealthRisk, trainingOpportunityTitle,
        trainingPrompt, trainingBadgeOpportunity, trainingBadgeSchoolStrength,
        trainingPitchPickerTitle, trainingIntensityTitle, trainingDoubleBonus,
        trainingCommit, trainingRepeatTitle, trainingRepeatStopExplanation,
    ]

    public static let trainingResultTitleBloom = GameCopyKey.localizable("training.result.title.bloom")
    public static let trainingResultTitleJackpot = GameCopyKey.localizable("training.result.title.jackpot")
    public static let trainingResultTitleGrowth = GameCopyKey.localizable("training.result.title.growth")
    public static let trainingResultTitleNoGrowth = GameCopyKey.localizable("training.result.title.no-growth")
    public static let trainingResultOpportunityBadge = GameCopyKey.localizable("training.result.badge.opportunity")
    public static let trainingResultDismiss = GameCopyKey.localizable("training.result.dismiss")
    public static let trainingResultFatigueSteady = GameCopyKey.localizable("training.result.fatigue.steady")
    public static let trainingResultFatigueChanged = GameCopyKey.localizable("training.result.fatigue.changed")
    public static let trainingResultHeadlineNoGain = GameCopyKey.localizable("training.result.headline.no-gain")
    public static let trainingResultGainValue = GameCopyKey.localizable("training.result.gain.value")
    public static let trainingResultGainRow = GameCopyKey.localizable("training.result.gain.row")

    public static let trainingResultKeys: [GameCopyKey] = [
        trainingResultTitleBloom, trainingResultTitleJackpot, trainingResultTitleGrowth,
        trainingResultTitleNoGrowth, trainingResultOpportunityBadge, trainingResultDismiss,
        trainingResultFatigueSteady, trainingResultFatigueChanged, trainingResultHeadlineNoGain,
        trainingResultGainValue, trainingResultGainRow,
    ]

    public static let setupQuickRebirthTitle = GameCopyKey.localizable("setup.quick-rebirth.title")
    public static let setupQuickRebirthSummary = GameCopyKey.localizable("setup.quick-rebirth.summary")
    public static let setupQuickRebirthAction = GameCopyKey.localizable("setup.quick-rebirth.action")
    public static let setupQuickRebirthHint = GameCopyKey.localizable("setup.quick-rebirth.hint")
    public static let setupProgressRebirth = GameCopyKey.localizable("setup.progress.rebirth")
    public static let setupProgressFirst = GameCopyKey.localizable("setup.progress.first")
    public static let setupNameTitleRebirth = GameCopyKey.localizable("setup.name.title.rebirth")
    public static let setupNameTitleFirst = GameCopyKey.localizable("setup.name.title.first")
    public static let setupNameDescription = GameCopyKey.localizable("setup.name.description")
    public static let setupNameDefault = GameCopyKey.localizable("setup.name.default")
    public static let setupNameSuggestionAction = GameCopyKey.localizable("setup.name.suggestion-action")
    public static let setupSeedPlaceholder = GameCopyKey.localizable("setup.seed.placeholder")
    public static let setupSeedError = GameCopyKey.localizable("setup.seed.error")
    public static let setupSeedChallengeSummary = GameCopyKey.localizable("setup.seed.challenge-summary")
    public static let setupSeedSummary = GameCopyKey.localizable("setup.seed.summary")
    public static let setupStadiumCaption = GameCopyKey.localizable("setup.name.stadium-caption")
    public static let setupRebirthCaption = GameCopyKey.localizable("setup.name.rebirth-caption")
    public static let setupInheritanceTitle = GameCopyKey.localizable("setup.inheritance.title")
    public static let setupInheritancePoints = GameCopyKey.localizable("setup.inheritance.points")
    public static let setupInheritanceAutomaticGrowth = GameCopyKey.localizable("setup.inheritance.automatic-growth")
    public static let setupInheritanceNextStep = GameCopyKey.localizable("setup.inheritance.next-step")
    public static let setupInheritanceMaxed = GameCopyKey.localizable("setup.inheritance.maxed")
    public static let setupInheritanceEmptyMemories = GameCopyKey.localizable("setup.inheritance.empty-memories")
    public static let setupInheritanceLegacy = GameCopyKey.localizable("setup.inheritance.legacy")
    public static let setupInheritanceShopTitle = GameCopyKey.localizable("setup.inheritance.shop.title")
    public static let setupInheritanceShopDescription = GameCopyKey.localizable("setup.inheritance.shop.description")
    public static let setupBoostTalentBreakTitle = GameCopyKey.localizable("setup.boost.talent-break.title")
    public static let setupBoostTalentBreakDetail = GameCopyKey.localizable("setup.boost.talent-break.detail")
    public static let setupBoostExtraMemoryTitle = GameCopyKey.localizable("setup.boost.extra-memory.title")
    public static let setupBoostExtraMemoryDetail = GameCopyKey.localizable("setup.boost.extra-memory.detail")
    public static let setupBoostHeadStartTitle = GameCopyKey.localizable("setup.boost.head-start.title")
    public static let setupBoostHeadStartDetail = GameCopyKey.localizable("setup.boost.head-start.detail")
    public static let setupBoostTrainingRhythmTitle = GameCopyKey.localizable("setup.boost.training-rhythm.title")
    public static let setupBoostTrainingRhythmDetail = GameCopyKey.localizable("setup.boost.training-rhythm.detail")
    public static let setupBoostCost = GameCopyKey.localizable("setup.boost.cost")
    public static let setupRegionTitle = GameCopyKey.localizable("setup.region.title")
    public static let setupRegionDescription = GameCopyKey.localizable("setup.region.description")
    public static let setupStyleTitle = GameCopyKey.localizable("setup.style.title")
    public static let setupStyleDescription = GameCopyKey.localizable("setup.style.description")
    public static let setupHandicapTitle = GameCopyKey.localizable("setup.handicap.title")
    public static let setupDifficultyTitle = GameCopyKey.localizable("setup.difficulty.title")
    public static let setupChallengeTitle = GameCopyKey.localizable("setup.challenge.title")
    public static let setupChallengeDescription = GameCopyKey.localizable("setup.challenge.description")
    public static let setupLegacyTitle = GameCopyKey.localizable("setup.legacy.title")
    public static let setupLegacyDescription = GameCopyKey.localizable("setup.legacy.description")
    public static let setupSoulDomainTitle = GameCopyKey.localizable("setup.soul-domain.title")
    public static let setupSoulDomainRule = GameCopyKey.localizable("setup.soul-domain.rule")
    public static let setupHandicapLabel = GameCopyKey.localizable("setup.handicap.label")
    public static let setupHandicapDescription = GameCopyKey.localizable("setup.handicap.description")
    public static let setupKarmaReward = GameCopyKey.localizable("setup.karma.reward")
    public static let setupSeedValidation = GameCopyKey.localizable("setup.seed.validation")
    public static let setupStartChallenge = GameCopyKey.localizable("setup.start.challenge")
    public static let setupStartRebirth = GameCopyKey.localizable("setup.start.rebirth")
    public static let setupStartFirst = GameCopyKey.localizable("setup.start.first")
    public static let setupActionNext = GameCopyKey.localizable("setup.action.next")
    public static let setupActionBack = GameCopyKey.localizable("setup.action.back")
    public static let setupKarmaCapacityHint = GameCopyKey.localizable("setup.karma.capacity-hint")
    public static let setupStatStuff = GameCopyKey.localizable("setup.stat.stuff")
    public static let setupStatCommand = GameCopyKey.localizable("setup.stat.command")
    public static let setupStatMovement = GameCopyKey.localizable("setup.stat.movement")
    public static let setupStatStamina = GameCopyKey.localizable("setup.stat.stamina")
    public static let setupSoulDomainBody = GameCopyKey.localizable("setup.soul-domain.body.label")
    public static let setupSoulDomainTechnique = GameCopyKey.localizable("setup.soul-domain.technique.label")
    public static let setupSoulDomainGame = GameCopyKey.localizable("setup.soul-domain.game.label")
    public static let setupSoulDomainBodyDetail = GameCopyKey.localizable("setup.soul-domain.body.detail")
    public static let setupSoulDomainTechniqueDetail = GameCopyKey.localizable("setup.soul-domain.technique.detail")
    public static let setupSoulDomainGameDetail = GameCopyKey.localizable("setup.soul-domain.game.detail")
    public static let setupDifficultyRelaxed = GameCopyKey.localizable("setup.difficulty.relaxed")
    public static let setupDifficultyStandard = GameCopyKey.localizable("setup.difficulty.standard")
    public static let setupDifficultyChallenging = GameCopyKey.localizable("setup.difficulty.challenging")

    public static let setupKarmaUnknownLandTitle = GameCopyKey.localizable("setup.karma.unknown-land.title")
    public static let setupKarmaUnknownLandDetail = GameCopyKey.localizable("setup.karma.unknown-land.detail")
    public static let setupKarmaStubbornCoachTitle = GameCopyKey.localizable("setup.karma.stubborn-coach.title")
    public static let setupKarmaStubbornCoachDetail = GameCopyKey.localizable("setup.karma.stubborn-coach.detail")
    public static let setupKarmaSingleWeaponTitle = GameCopyKey.localizable("setup.karma.single-weapon.title")
    public static let setupKarmaSingleWeaponDetail = GameCopyKey.localizable("setup.karma.single-weapon.detail")
    public static let setupKarmaGeniusGenerationTitle = GameCopyKey.localizable("setup.karma.genius-generation.title")
    public static let setupKarmaGeniusGenerationDetail = GameCopyKey.localizable("setup.karma.genius-generation.detail")
    public static let setupKarmaErasedMemoryTitle = GameCopyKey.localizable("setup.karma.erased-memory.title")
    public static let setupKarmaErasedMemoryDetail = GameCopyKey.localizable("setup.karma.erased-memory.detail")
    public static let setupKarmaNoLastChanceTitle = GameCopyKey.localizable("setup.karma.no-last-chance.title")
    public static let setupKarmaNoLastChanceDetail = GameCopyKey.localizable("setup.karma.no-last-chance.detail")

    public static let setupSignatureEffectNone = GameCopyKey.localizable("setup.signature-effect.none")
    public static let setupSignatureEffectStuff = GameCopyKey.localizable("setup.signature-effect.stuff")
    public static let setupSignatureEffectCommand = GameCopyKey.localizable("setup.signature-effect.command")
    public static let setupSignatureEffectMovement = GameCopyKey.localizable("setup.signature-effect.movement")
    public static let setupSignatureEffectStamina = GameCopyKey.localizable("setup.signature-effect.stamina")
    public static let setupSignatureEffectStuffCommand = GameCopyKey.localizable("setup.signature-effect.stuff-command")
    public static let setupSignatureEffectStuffMovement = GameCopyKey.localizable("setup.signature-effect.stuff-movement")
    public static let setupSignatureEffectStuffStamina = GameCopyKey.localizable("setup.signature-effect.stuff-stamina")
    public static let setupSignatureEffectCommandMovement = GameCopyKey.localizable("setup.signature-effect.command-movement")
    public static let setupSignatureEffectCommandStamina = GameCopyKey.localizable("setup.signature-effect.command-stamina")
    public static let setupSignatureEffectMovementStamina = GameCopyKey.localizable("setup.signature-effect.movement-stamina")
    public static let setupSignatureEffectStuffCommandMovement = GameCopyKey.localizable("setup.signature-effect.stuff-command-movement")
    public static let setupSignatureEffectStuffCommandStamina = GameCopyKey.localizable("setup.signature-effect.stuff-command-stamina")
    public static let setupSignatureEffectStuffMovementStamina = GameCopyKey.localizable("setup.signature-effect.stuff-movement-stamina")
    public static let setupSignatureEffectCommandMovementStamina = GameCopyKey.localizable("setup.signature-effect.command-movement-stamina")
    public static let setupSignatureEffectAll = GameCopyKey.localizable("setup.signature-effect.all")

    public static let setupRegionSeoulName = GameCopyKey.localizable("setup.region.seoul.name")
    public static let setupRegionIncheonName = GameCopyKey.localizable("setup.region.incheon.name")
    public static let setupRegionSuwonName = GameCopyKey.localizable("setup.region.suwon.name")
    public static let setupRegionDaejeonName = GameCopyKey.localizable("setup.region.daejeon.name")
    public static let setupRegionGwangjuName = GameCopyKey.localizable("setup.region.gwangju.name")
    public static let setupRegionDaeguName = GameCopyKey.localizable("setup.region.daegu.name")
    public static let setupRegionBusanName = GameCopyKey.localizable("setup.region.busan.name")
    public static let setupRegionChangwonName = GameCopyKey.localizable("setup.region.changwon.name")
    public static let setupRegionUlsanName = GameCopyKey.localizable("setup.region.ulsan.name")
    public static let setupRegionSejongName = GameCopyKey.localizable("setup.region.sejong.name")
    public static let setupRegionGyeonggiName = GameCopyKey.localizable("setup.region.gyeonggi.name")
    public static let setupRegionGangwonName = GameCopyKey.localizable("setup.region.gangwon.name")
    public static let setupRegionChungbukName = GameCopyKey.localizable("setup.region.chungbuk.name")
    public static let setupRegionChungnamName = GameCopyKey.localizable("setup.region.chungnam.name")
    public static let setupRegionJeonbukName = GameCopyKey.localizable("setup.region.jeonbuk.name")
    public static let setupRegionJeonnamName = GameCopyKey.localizable("setup.region.jeonnam.name")
    public static let setupRegionGyeongbukName = GameCopyKey.localizable("setup.region.gyeongbuk.name")
    public static let setupRegionGyeongnamName = GameCopyKey.localizable("setup.region.gyeongnam.name")
    public static let setupRegionJejuName = GameCopyKey.localizable("setup.region.jeju.name")
    public static let setupRegionSeoulFlavor = GameCopyKey.localizable("setup.region.seoul.flavor")
    public static let setupRegionIncheonFlavor = GameCopyKey.localizable("setup.region.incheon.flavor")
    public static let setupRegionSuwonFlavor = GameCopyKey.localizable("setup.region.suwon.flavor")
    public static let setupRegionDaejeonFlavor = GameCopyKey.localizable("setup.region.daejeon.flavor")
    public static let setupRegionGwangjuFlavor = GameCopyKey.localizable("setup.region.gwangju.flavor")
    public static let setupRegionDaeguFlavor = GameCopyKey.localizable("setup.region.daegu.flavor")
    public static let setupRegionBusanFlavor = GameCopyKey.localizable("setup.region.busan.flavor")
    public static let setupRegionChangwonFlavor = GameCopyKey.localizable("setup.region.changwon.flavor")
    public static let setupRegionUlsanFlavor = GameCopyKey.localizable("setup.region.ulsan.flavor")
    public static let setupRegionSejongFlavor = GameCopyKey.localizable("setup.region.sejong.flavor")
    public static let setupRegionGyeonggiFlavor = GameCopyKey.localizable("setup.region.gyeonggi.flavor")
    public static let setupRegionGangwonFlavor = GameCopyKey.localizable("setup.region.gangwon.flavor")
    public static let setupRegionChungbukFlavor = GameCopyKey.localizable("setup.region.chungbuk.flavor")
    public static let setupRegionChungnamFlavor = GameCopyKey.localizable("setup.region.chungnam.flavor")
    public static let setupRegionJeonbukFlavor = GameCopyKey.localizable("setup.region.jeonbuk.flavor")
    public static let setupRegionJeonnamFlavor = GameCopyKey.localizable("setup.region.jeonnam.flavor")
    public static let setupRegionGyeongbukFlavor = GameCopyKey.localizable("setup.region.gyeongbuk.flavor")
    public static let setupRegionGyeongnamFlavor = GameCopyKey.localizable("setup.region.gyeongnam.flavor")
    public static let setupRegionJejuFlavor = GameCopyKey.localizable("setup.region.jeju.flavor")

    public static let settingsControlTitle = GameCopyKey.localizable("settings.control.title")
    public static let settingsAutoRelease = GameCopyKey.localizable("settings.auto-release.label")
    public static let settingsAutoReleaseDescription = GameCopyKey.localizable("settings.auto-release.description")
    public static let settingsAutoReleaseFooter = GameCopyKey.localizable("settings.auto-release.footer")
    public static let settingsAudioSectionTitle = GameCopyKey.localizable("settings.audio.section-title")
    public static let settingsMusic = GameCopyKey.localizable("settings.audio.music")
    public static let settingsHaptics = GameCopyKey.localizable("settings.audio.haptics")
    public static let settingsHapticsFooter = GameCopyKey.localizable("settings.audio.haptics.footer")
    public static let settingsAudioFooter = GameCopyKey.localizable("settings.audio.footer")
    public static let settingsNotificationsSectionTitle = GameCopyKey.localizable("settings.notifications.title")
    public static let settingsNotificationToggle = GameCopyKey.localizable("settings.notifications.toggle")
    public static let settingsNotificationFooter = GameCopyKey.localizable("settings.notifications.footer")
    public static let settingsNavigationTitle = GameCopyKey.localizable("settings.navigation.title")
    public static let settingsProgressSectionTitle = GameCopyKey.localizable("settings.progress.title")
    public static let settingsNextPlayerLabel = GameCopyKey.localizable("settings.next-player.label")
    public static let settingsNextPlayerValue = GameCopyKey.localizable("settings.next-player.value")
    public static let settingsMemoriesLabel = GameCopyKey.localizable("settings.memories.label")
    public static let settingsMemoriesValue = GameCopyKey.localizable("settings.memories.value")
    public static let settingsSoulLabel = GameCopyKey.localizable("settings.soul.label")
    public static let settingsSoulValue = GameCopyKey.localizable("settings.soul.value")
    public static let settingsProLabel = GameCopyKey.localizable("settings.pro.label")
    public static let settingsProValue = GameCopyKey.localizable("settings.pro.value")
    public static let settingsShareCodeLabel = GameCopyKey.localizable("settings.share-code.label")
    public static let settingsShareCodeAccessibility = GameCopyKey.localizable("settings.share-code.accessibility")
    public static let settingsDeleteAction = GameCopyKey.localizable("settings.delete.action")
    public static let settingsDeleteFooter = GameCopyKey.localizable("settings.delete.footer")
    public static let settingsDeleteConfirmationTitle = GameCopyKey.localizable("settings.delete.confirm.title")
    public static let settingsDeleteConfirmationAction = GameCopyKey.localizable("settings.delete.confirm.action")
    public static let settingsDeleteConfirmationCancel = GameCopyKey.localizable("settings.delete.confirm.cancel")
    public static let settingsDeleteConfirmationMessage = GameCopyKey.localizable("settings.delete.confirm.message")

    public static let returnPlanCardTitle = GameCopyKey.localizable("return.plan.card.title")
    public static let returnPlanDismissAccessibility = GameCopyKey.localizable("return.plan.dismiss.accessibility")
    public static let returnPlanContinueGame = GameCopyKey.localizable("return.plan.continue.game")
    public static let returnPlanContinueHighSchool = GameCopyKey.localizable("return.plan.continue.high-school")
    public static let returnPlanContinuePro = GameCopyKey.localizable("return.plan.continue.pro")
    public static let returnPlanTitlePro = GameCopyKey.localizable("return.plan.title.pro")
    public static let returnPlanBodyProSeasonDecision = GameCopyKey.localizable("return.plan.body.pro.season-decision")
    public static let returnPlanBodyProImportantGame = GameCopyKey.localizable("return.plan.body.pro.important-game")
    public static let returnPlanBodyProRetirement = GameCopyKey.localizable("return.plan.body.pro.retirement")
    public static let returnPlanBodyProDefault = GameCopyKey.localizable("return.plan.body.pro.default")
    public static let returnPlanTitlePledge = GameCopyKey.localizable("return.plan.title.pledge")
    public static let returnPlanBodyPledge = GameCopyKey.localizable("return.plan.body.pledge")
    public static let returnPlanTitleNextPlayer = GameCopyKey.localizable("return.plan.title.next-player")
    public static let returnPlanBodyNextPlayer = GameCopyKey.localizable("return.plan.body.next-player")
    public static let returnPlanTitleHighSchoolPhase = GameCopyKey.localizable("return.plan.title.high-school-phase")
    public static let returnPlanBodyPrologue = GameCopyKey.localizable("return.plan.body.high-school.prologue")
    public static let returnPlanBodySchoolSelection = GameCopyKey.localizable("return.plan.body.high-school.school-selection")
    public static let returnPlanBodyTraining = GameCopyKey.localizable("return.plan.body.high-school.training")
    public static let returnPlanBodyRelationship = GameCopyKey.localizable("return.plan.body.high-school.relationship")
    public static let returnPlanBodyImportantGame = GameCopyKey.localizable("return.plan.body.high-school.important-game")
    public static let returnPlanBodyAwakening = GameCopyKey.localizable("return.plan.body.high-school.awakening")
    public static let returnPlanBodyChapterReview = GameCopyKey.localizable("return.plan.body.high-school.chapter-review")
    public static let returnPlanBodyDraft = GameCopyKey.localizable("return.plan.body.high-school.draft")
    public static let returnPlanBodyLegacy = GameCopyKey.localizable("return.plan.body.high-school.legacy")
    public static let returnPlanBodyCompleted = GameCopyKey.localizable("return.plan.body.high-school.completed")

    public static let proLockedEyebrow = GameCopyKey.localizable("pro.locked.eyebrow")
    public static let proLockedTitle = GameCopyKey.localizable("pro.locked.title")
    public static let proLockedPathTitle = GameCopyKey.localizable("pro.locked.path.title")
    public static let proLockedPathBody = GameCopyKey.localizable("pro.locked.path.body")
    public static let proLockedDistanceTitle = GameCopyKey.localizable("pro.locked.distance.title")
    public static let proLockedForecastBase = GameCopyKey.localizable("pro.locked.forecast.base")
    public static let proLockedForecastChapters = GameCopyKey.localizable("pro.locked.forecast.chapters")
    public static let proLockedForecastImminent = GameCopyKey.localizable("pro.locked.forecast.imminent")
    public static let proLockedInterested = GameCopyKey.localizable("pro.locked.interested")
    public static let proLockedSkipButton = GameCopyKey.localizable("pro.locked.skip.button")
    public static let proLockedSkipDescription = GameCopyKey.localizable("pro.locked.skip.description")
    public static let proLockedSkipLocked = GameCopyKey.localizable("pro.locked.skip.locked")
    public static let proNavigationTitle = GameCopyKey.localizable("pro.navigation.title")
    public static let proStartSheetTitle = GameCopyKey.localizable("pro.start.sheet-title")
    public static let proViewPicker = GameCopyKey.localizable("pro.view.picker")
    public static let proToday = GameCopyKey.localizable("pro.view.today")
    public static let proThisWeek = GameCopyKey.localizable("pro.view.this-week")

    public static let communityBuzzTitle = GameCopyKey.localizable("community-buzz.title")
    public static let communityBuzzFootnote = GameCopyKey.localizable("community-buzz.footnote")
    public static let communityBuzzWorldTitle = GameCopyKey.localizable("community-buzz.world.title")
    public static let communityBuzzWorldFootnote = GameCopyKey.localizable("community-buzz.world.footnote")

    public static let communityBuzzKeys: [GameCopyKey] = [
        communityBuzzTitle, communityBuzzFootnote,
        communityBuzzWorldTitle, communityBuzzWorldFootnote,
    ]

    public static let prospectRankingTitle = GameCopyKey.localizable("prospect-ranking.title")
    public static let prospectRankingNoGames = GameCopyKey.localizable("prospect-ranking.no-games")
    public static let prospectRankingForecastLabel = GameCopyKey.localizable("prospect-ranking.forecast.label")
    public static let prospectRankingForecastDetail = GameCopyKey.localizable("prospect-ranking.forecast.detail")
    public static let prospectRankingRowIdentity = GameCopyKey.localizable("prospect-ranking.row.identity")
    public static let prospectRankingOutsideTitle = GameCopyKey.localizable("prospect-ranking.outside.title")
    public static let prospectRankingOutsideDetail = GameCopyKey.localizable("prospect-ranking.outside.detail")
    public static let prospectRankingPlayerTag = GameCopyKey.localizable("prospect-ranking.player-tag")

    public static let prospectRankingKeys: [GameCopyKey] = [
        prospectRankingTitle, prospectRankingNoGames, prospectRankingForecastLabel,
        prospectRankingForecastDetail, prospectRankingRowIdentity,
        prospectRankingOutsideTitle, prospectRankingOutsideDetail, prospectRankingPlayerTag,
    ]

    public static let errorCareerOpenTitle = GameCopyKey.localizable("error.career.open.title")
    public static let errorRetry = GameCopyKey.localizable("error.retry")
    public static let errorReset = GameCopyKey.localizable("error.reset")
    public static let errorDeleteTitle = GameCopyKey.localizable("error.career.delete.title")
    public static let errorDeleteAction = GameCopyKey.localizable("error.career.delete.action")
    public static let errorCancel = GameCopyKey.localizable("error.cancel")
    public static let errorDeleteMessage = GameCopyKey.localizable("error.career.delete.message")
    public static let careerUnavailable = GameCopyKey.localizable("career.unavailable")

    public static let legacyHandoffSaveFailedTitle = GameCopyKey.localizable("pro.legacy-handoff.save-failed.title")
    public static let legacyHandoffLinkBrokenTitle = GameCopyKey.localizable("pro.legacy-handoff.link-broken.title")
    public static let legacyHandoffLinkBrokenMessage = GameCopyKey.localizable("pro.legacy-handoff.link-broken.message")
    public static let legacyHandoffFallbackAction = GameCopyKey.localizable("pro.legacy-handoff.link-broken.fallback-action")

    public static let proSeasonHeader = GameCopyKey.localizable("pro.dashboard.season-header")
    public static let proDashboardTitle = GameCopyKey.localizable("pro.dashboard.title")
    public static let proFatigueLabel = GameCopyKey.localizable("pro.dashboard.fatigue")
    public static let proManagerTrustLabel = GameCopyKey.localizable("pro.dashboard.manager-trust")
    public static let proInjuryLabel = GameCopyKey.localizable("pro.dashboard.injury")
    public static let proInjuryWeeks = GameCopyKey.localizable("pro.dashboard.injury-weeks")
    public static let proInjuryNormal = GameCopyKey.localizable("pro.dashboard.injury-normal")
    public static let proNextActionTitle = GameCopyKey.localizable("pro.dashboard.next-action")
    public static let proTensionsTitle = GameCopyKey.localizable("pro.dashboard.tensions")
    public static let proRivalTitle = GameCopyKey.localizable("pro.dashboard.rival")
    public static let proMilestoneTitle = GameCopyKey.localizable("pro.dashboard.milestone")
    public static let proLatestOutingTitle = GameCopyKey.localizable("pro.dashboard.latest-outing")
    public static let proDirectOuting = GameCopyKey.localizable("pro.dashboard.direct-outing")
    public static let proOutingWeek = GameCopyKey.localizable("pro.dashboard.outing-week")
    public static let proOutingLine = GameCopyKey.localizable("pro.dashboard.outing-line")
    public static let proOutingAccessibility = GameCopyKey.localizable("pro.dashboard.outing-accessibility")
    public static let proOutingAccessibilityPlayed = GameCopyKey.localizable("pro.dashboard.outing-accessibility.played")
    public static let proOutingAccessibilityDecision = GameCopyKey.localizable("pro.dashboard.outing-accessibility.decision")
    public static let proOutingAccessibilityDecisionPlayed = GameCopyKey.localizable("pro.dashboard.outing-accessibility.decision-played")
    public static let proOutingSummary = GameCopyKey.localizable("pro.dashboard.outing-summary")
    public static let proOutingSummaryHits = GameCopyKey.localizable("pro.dashboard.outing-summary.hits")
    public static let proRoleReliever = GameCopyKey.localizable("pro.role.reliever")
    public static let proDecisionWin = GameCopyKey.localizable("pro.decision.win")
    public static let proDecisionLoss = GameCopyKey.localizable("pro.decision.loss")
    public static let proDecisionSave = GameCopyKey.localizable("pro.decision.save")
    public static let proLatestNewsTitle = GameCopyKey.localizable("pro.dashboard.latest-news")
    public static let proSeasonProgressTitle = GameCopyKey.localizable("pro.dashboard.season-progress")
    public static let proSeasonProgressValue = GameCopyKey.localizable("pro.dashboard.season-progress-value")
    public static let proSeasonProgressAccessibility = GameCopyKey.localizable("pro.dashboard.season-progress.accessibility")
    public static let proLevelMajor = GameCopyKey.localizable("pro.level.majors")
    public static let proLevelMinor = GameCopyKey.localizable("pro.level.minors")
    public static let proRoleStarter = GameCopyKey.localizable("pro.role.starter")
    public static let proRoleLongRelief = GameCopyKey.localizable("pro.role.long-relief")
    public static let proRoleSetup = GameCopyKey.localizable("pro.role.setup")
    public static let proRoleCloser = GameCopyKey.localizable("pro.role.closer")
    public static let proSegmentSpringCamp = GameCopyKey.localizable("pro.segment.spring-camp")
    public static let proSegmentOpening = GameCopyKey.localizable("pro.segment.opening")
    public static let proSegmentFirstHalf = GameCopyKey.localizable("pro.segment.first-half")
    public static let proSegmentAllStarBreak = GameCopyKey.localizable("pro.segment.all-star-break")
    public static let proSegmentPennantRace = GameCopyKey.localizable("pro.segment.pennant-race")
    public static let proSegmentSeasonFinale = GameCopyKey.localizable("pro.segment.season-finale")
    public static let proSegmentPreparation = GameCopyKey.localizable("pro.segment.preparation")
    public static let proActionWeeklyPlan = GameCopyKey.localizable("pro.action.weekly-plan")
    public static let proActionImportantGame = GameCopyKey.localizable("pro.action.important-game")
    public static let proActionSeasonReview = GameCopyKey.localizable("pro.action.season-review")
    public static let proActionOffseasonDecision = GameCopyKey.localizable("pro.action.offseason-decision")
    public static let proActionDefault = GameCopyKey.localizable("pro.action.default")
    public static let proWeeklyPlanUntil = GameCopyKey.localizable("pro.weekly-plan.until")

    public static let highSchoolSetupKeys: [GameCopyKey] = [
        setupQuickRebirthTitle, setupQuickRebirthSummary, setupQuickRebirthAction, setupQuickRebirthHint,
        setupProgressRebirth, setupProgressFirst, setupNameTitleRebirth, setupNameTitleFirst,
        setupNameDescription, setupNameDefault, setupNameSuggestionAction, setupSeedPlaceholder,
        setupSeedError, setupSeedChallengeSummary, setupSeedSummary, setupStadiumCaption,
        setupRebirthCaption, setupInheritanceTitle, setupInheritancePoints,
        setupInheritanceAutomaticGrowth, setupInheritanceNextStep, setupInheritanceMaxed,
        setupInheritanceEmptyMemories, setupInheritanceLegacy, setupInheritanceShopTitle,
        setupInheritanceShopDescription, setupBoostTalentBreakTitle, setupBoostTalentBreakDetail,
        setupBoostExtraMemoryTitle, setupBoostExtraMemoryDetail, setupBoostHeadStartTitle,
        setupBoostHeadStartDetail, setupBoostTrainingRhythmTitle, setupBoostTrainingRhythmDetail,
        setupBoostCost,
        setupRegionTitle, setupRegionDescription, setupStyleTitle, setupStyleDescription,
        setupHandicapTitle, setupDifficultyTitle, setupChallengeTitle, setupChallengeDescription,
        setupLegacyTitle, setupLegacyDescription, setupSoulDomainTitle, setupSoulDomainRule,
        setupHandicapLabel, setupHandicapDescription, setupKarmaReward, setupSeedValidation, setupStartChallenge,
        setupStartRebirth, setupStartFirst, setupActionNext, setupActionBack, setupKarmaCapacityHint,
        setupStatStuff, setupStatCommand, setupStatMovement, setupStatStamina,
        setupSoulDomainBody, setupSoulDomainTechnique, setupSoulDomainGame,
        setupSoulDomainBodyDetail, setupSoulDomainTechniqueDetail, setupSoulDomainGameDetail,
        setupDifficultyRelaxed, setupDifficultyStandard, setupDifficultyChallenging,
        setupKarmaUnknownLandTitle, setupKarmaUnknownLandDetail,
        setupKarmaStubbornCoachTitle, setupKarmaStubbornCoachDetail,
        setupKarmaSingleWeaponTitle, setupKarmaSingleWeaponDetail,
        setupKarmaGeniusGenerationTitle, setupKarmaGeniusGenerationDetail,
        setupKarmaErasedMemoryTitle, setupKarmaErasedMemoryDetail,
        setupKarmaNoLastChanceTitle, setupKarmaNoLastChanceDetail,
        setupSignatureEffectNone, setupSignatureEffectStuff, setupSignatureEffectCommand,
        setupSignatureEffectMovement, setupSignatureEffectStamina, setupSignatureEffectStuffCommand,
        setupSignatureEffectStuffMovement, setupSignatureEffectStuffStamina,
        setupSignatureEffectCommandMovement, setupSignatureEffectCommandStamina,
        setupSignatureEffectMovementStamina, setupSignatureEffectStuffCommandMovement,
        setupSignatureEffectStuffCommandStamina, setupSignatureEffectStuffMovementStamina,
        setupSignatureEffectCommandMovementStamina, setupSignatureEffectAll,
        setupRegionSeoulName, setupRegionIncheonName, setupRegionSuwonName,
        setupRegionDaejeonName, setupRegionGwangjuName, setupRegionDaeguName,
        setupRegionBusanName, setupRegionChangwonName, setupRegionUlsanName,
        setupRegionSejongName, setupRegionGyeonggiName, setupRegionGangwonName,
        setupRegionChungbukName, setupRegionChungnamName, setupRegionJeonbukName,
        setupRegionJeonnamName, setupRegionGyeongbukName, setupRegionGyeongnamName,
        setupRegionJejuName, setupRegionSeoulFlavor, setupRegionIncheonFlavor,
        setupRegionSuwonFlavor, setupRegionDaejeonFlavor, setupRegionGwangjuFlavor,
        setupRegionDaeguFlavor, setupRegionBusanFlavor, setupRegionChangwonFlavor,
        setupRegionUlsanFlavor, setupRegionSejongFlavor, setupRegionGyeonggiFlavor,
        setupRegionGangwonFlavor, setupRegionChungbukFlavor, setupRegionChungnamFlavor,
        setupRegionJeonbukFlavor, setupRegionJeonnamFlavor, setupRegionGyeongbukFlavor,
        setupRegionGyeongnamFlavor, setupRegionJejuFlavor,
    ]

    public static let allCases: [GameCopyKey] = [
        tabHighSchool, tabPro, tabRecords, tabSettings,
        openingEyebrow, openingSummary, openingDescription, openingStart,
    ] + prologueKeys + [
        actionCancel,
        settingsControlTitle, settingsAutoRelease, settingsAutoReleaseDescription,
        settingsAutoReleaseFooter, settingsAudioSectionTitle, settingsMusic, settingsHaptics,
        settingsHapticsFooter, settingsAudioFooter, settingsNotificationsSectionTitle,
        settingsNotificationToggle, settingsNotificationFooter, settingsProgressSectionTitle,
        settingsNavigationTitle,
        settingsNextPlayerLabel, settingsNextPlayerValue, settingsMemoriesLabel, settingsMemoriesValue,
        settingsSoulLabel, settingsSoulValue, settingsProLabel, settingsProValue,
        settingsShareCodeLabel, settingsShareCodeAccessibility, settingsDeleteAction,
        settingsDeleteFooter, settingsDeleteConfirmationTitle, settingsDeleteConfirmationAction,
        settingsDeleteConfirmationCancel, settingsDeleteConfirmationMessage,
        returnPlanCardTitle, returnPlanDismissAccessibility, returnPlanContinueGame,
        returnPlanContinueHighSchool, returnPlanContinuePro, returnPlanTitlePro,
        returnPlanBodyProSeasonDecision, returnPlanBodyProImportantGame, returnPlanBodyProRetirement,
        returnPlanBodyProDefault, returnPlanTitlePledge, returnPlanBodyPledge,
        returnPlanTitleNextPlayer, returnPlanBodyNextPlayer, returnPlanTitleHighSchoolPhase,
        returnPlanBodyPrologue, returnPlanBodySchoolSelection, returnPlanBodyTraining,
        returnPlanBodyRelationship, returnPlanBodyImportantGame, returnPlanBodyAwakening,
        returnPlanBodyChapterReview, returnPlanBodyDraft, returnPlanBodyLegacy, returnPlanBodyCompleted,
        proLockedEyebrow, proLockedTitle, proLockedPathTitle, proLockedPathBody,
        proLockedDistanceTitle, proLockedForecastBase, proLockedForecastChapters,
        proLockedForecastImminent, proLockedInterested, proLockedSkipButton,
        proLockedSkipDescription, proLockedSkipLocked, proNavigationTitle, proStartSheetTitle,
        proViewPicker, proToday, proThisWeek,
        errorCareerOpenTitle, errorRetry, errorReset, errorDeleteTitle, errorDeleteAction,
        errorCancel, errorDeleteMessage, careerUnavailable,
        legacyHandoffSaveFailedTitle, legacyHandoffLinkBrokenTitle,
        legacyHandoffLinkBrokenMessage, legacyHandoffFallbackAction,
        proSeasonHeader, proDashboardTitle, proFatigueLabel, proManagerTrustLabel,
        proInjuryLabel, proInjuryWeeks, proInjuryNormal, proNextActionTitle, proTensionsTitle,
        proRivalTitle, proMilestoneTitle, proLatestOutingTitle, proDirectOuting, proOutingWeek,
        proOutingLine, proOutingAccessibility, proOutingAccessibilityPlayed,
        proOutingAccessibilityDecision, proOutingAccessibilityDecisionPlayed, proOutingSummary,
        proOutingSummaryHits, proRoleReliever, proDecisionWin, proDecisionLoss, proDecisionSave,
        proLatestNewsTitle, proSeasonProgressTitle, proSeasonProgressValue,
        proSeasonProgressAccessibility, proLevelMajor, proLevelMinor, proRoleStarter,
        proRoleLongRelief, proRoleSetup, proRoleCloser, proSegmentSpringCamp, proSegmentOpening,
        proSegmentFirstHalf, proSegmentAllStarBreak, proSegmentPennantRace,
        proSegmentSeasonFinale, proSegmentPreparation, proActionWeeklyPlan,
        proActionImportantGame, proActionSeasonReview, proActionOffseasonDecision, proActionDefault,
        proWeeklyPlanUntil,
    ] + communityBuzzKeys + prospectRankingKeys + reminderNudgeKeys + challengeEndKeys + schoolSelectionKeys + chapterHeaderKeys
        + chapterReviewKeys + tournamentKeys + chapterGoalKeys
        + trainingKeys + trainingResultKeys + highSchoolSetupKeys + importantGameKeys + awakeningKeys
        + highSchoolConclusionKeys + pitchKeys + proFlowKeys + recordKeys + metaKeys + legacyKeys
}

public extension AppCopyKey {
    /// Resolves a stable simulation region ID through the existing setup-region catalog.
    /// The raw Korean region is never used as a localization key.
    static func setupRegionName(for region: SchoolRegionID) -> GameCopyKey {
        switch region {
        case .seoul: setupRegionSeoulName
        case .incheon: setupRegionIncheonName
        case .suwon: setupRegionSuwonName
        case .daejeon: setupRegionDaejeonName
        case .gwangju: setupRegionGwangjuName
        case .daegu: setupRegionDaeguName
        case .busan: setupRegionBusanName
        case .changwon: setupRegionChangwonName
        case .ulsan: setupRegionUlsanName
        case .sejong: setupRegionSejongName
        case .gyeonggi: setupRegionGyeonggiName
        case .gangwon: setupRegionGangwonName
        case .chungbuk: setupRegionChungbukName
        case .chungnam: setupRegionChungnamName
        case .jeonbuk: setupRegionJeonbukName
        case .jeonnam: setupRegionJeonnamName
        case .gyeongbuk: setupRegionGyeongbukName
        case .gyeongnam: setupRegionGyeongnamName
        case .jeju: setupRegionJejuName
        }
    }
}
