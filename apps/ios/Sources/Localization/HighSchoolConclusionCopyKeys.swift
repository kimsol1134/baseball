import Foundation

/// Static UI copy for the high-school conclusion boundary.
///
/// The list is kept separate from the view so conclusion controls, labels, hints, and share-card
/// copy can be audited as one catalog surface. Dynamic simulation values are passed as typed
/// arguments or resolved through SimulationCore presentation descriptors.
public extension AppCopyKey {
    static let conclusionChronicleTitle = GameCopyKey.localizable("conclusion.chronicle.title")
    static let conclusionDraftTitle = GameCopyKey.localizable("conclusion.draft.title")
    static let conclusionDraftIntro = GameCopyKey.localizable("conclusion.draft.intro")
    static let conclusionScoutTitle = GameCopyKey.localizable("conclusion.scout.title")
    static let conclusionRecordTitle = GameCopyKey.localizable("conclusion.record.title")
    static let conclusionOfficialGames = GameCopyKey.localizable("conclusion.record.official-games")
    static let conclusionRecordStats = GameCopyKey.localizable("conclusion.record.stats")
    static let conclusionAwakeningTraining = GameCopyKey.localizable("conclusion.record.awakening-training")
    static let conclusionResolveDraft = GameCopyKey.localizable("conclusion.draft.resolve")
    static let conclusionPlayerRecordCard = GameCopyKey.localizable("conclusion.player-record.card")
    static let conclusionDraftSummaryDrafted = GameCopyKey.localizable("conclusion.draft-summary.drafted")
    static let conclusionDraftSummaryUndrafted = GameCopyKey.localizable("conclusion.draft-summary.undrafted")
    static let conclusionProjectedFirstRound = GameCopyKey.localizable("conclusion.draft.projected-range.first-round")
    static let conclusionProjectedMiddleRounds = GameCopyKey.localizable("conclusion.draft.projected-range.middle-rounds")
    static let conclusionProjectedLateRounds = GameCopyKey.localizable("conclusion.draft.projected-range.late-rounds")
    static let conclusionProjectedUndrafted = GameCopyKey.localizable("conclusion.draft.projected-range.undrafted")
    static let conclusionFirstSeasonGoal = GameCopyKey.localizable("conclusion.draft.first-season-goal")
    static let conclusionBreakdownAbility = GameCopyKey.localizable("conclusion.draft.breakdown.ability")
    static let conclusionBreakdownHighSchool = GameCopyKey.localizable("conclusion.draft.breakdown.high-school")
    static let conclusionBreakdownSeason = GameCopyKey.localizable("conclusion.draft.breakdown.season")
    static let conclusionBreakdownAwakening = GameCopyKey.localizable("conclusion.draft.breakdown.awakening")
    static let conclusionBreakdownRelationship = GameCopyKey.localizable("conclusion.draft.breakdown.relationship")
    static let conclusionBreakdownHandicap = GameCopyKey.localizable("conclusion.draft.breakdown.handicap")
    static let conclusionBreakdownArm = GameCopyKey.localizable("conclusion.draft.breakdown.arm")
    static let conclusionEvaluationScore = GameCopyKey.localizable("conclusion.evaluation.score")
    static let conclusionEvaluationBreakdownAccessibility = GameCopyKey.localizable("conclusion.evaluation.accessibility")
    static let conclusionWindReview = GameCopyKey.localizable("conclusion.wind.review")
    static let conclusionDraftAdjustment = GameCopyKey.localizable("conclusion.wind.draft-adjustment")
    static let conclusionInheritanceAdjustment = GameCopyKey.localizable("conclusion.wind.inheritance-adjustment")
    static let conclusionSignatureTitle = GameCopyKey.localizable("conclusion.signature.title")
    static let conclusionSignatureDescription = GameCopyKey.localizable("conclusion.signature.description")
    static let conclusionSignatureRemainder = GameCopyKey.localizable("conclusion.signature.remainder")
    static let conclusionMemoryTitle = GameCopyKey.localizable("conclusion.memory.title")
    static let conclusionMemoryDescription = GameCopyKey.localizable("conclusion.memory.description")
    static let conclusionMemoryMore = GameCopyKey.localizable("conclusion.memory.more")
    static let conclusionLegacyConfirmAction = GameCopyKey.localizable("conclusion.legacy.confirm-action")
    static let conclusionMemoryConfirmAction = GameCopyKey.localizable("conclusion.memory.confirm-action")
    static let conclusionLegacyConfirmationTitle = GameCopyKey.localizable("conclusion.legacy.confirmation-title")
    static let conclusionMemoryConfirmationTitle = GameCopyKey.localizable("conclusion.memory.confirmation-title")
    static let conclusionConfirmationCancel = GameCopyKey.localizable("conclusion.confirmation.cancel")
    static let conclusionConfirmationConfirm = GameCopyKey.localizable("conclusion.confirmation.confirm")
    static let conclusionLegacyConfirmationMessage = GameCopyKey.localizable("conclusion.legacy.confirmation-message")
    static let conclusionMemoryConfirmationMessage = GameCopyKey.localizable("conclusion.memory.confirmation-message")
    static let conclusionCompletionTitle = GameCopyKey.localizable("conclusion.completion.title")
    static let conclusionCompletionEnded = GameCopyKey.localizable("conclusion.completion.ended")
    static let conclusionCarriedMemorySummary = GameCopyKey.localizable("conclusion.completion.carried-memory")
    static let conclusionTeamWaiting = GameCopyKey.localizable("conclusion.team.waiting")
    static let conclusionCoachName = GameCopyKey.localizable("conclusion.team.coach-name")
    static let conclusionCompetitorFallback = GameCopyKey.localizable("conclusion.team.competitor-fallback")
    static let conclusionEnterPro = GameCopyKey.localizable("conclusion.pro.enter")
    static let conclusionNotOver = GameCopyKey.localizable("conclusion.pro.not-over")
    static let conclusionLegacyPreviewTitle = GameCopyKey.localizable("conclusion.legacy-preview.title")
    static let conclusionLegacyPreviewBody = GameCopyKey.localizable("conclusion.legacy-preview.body")
    static let conclusionAwaitingRetirementTitle = GameCopyKey.localizable("conclusion.pro.awaiting-retirement-title")
    static let conclusionAwaitingRetirementBody = GameCopyKey.localizable("conclusion.pro.awaiting-retirement-body")
    static let conclusionBestEvaluationRecordTitle = GameCopyKey.localizable("conclusion.best-evaluation.record-title")
    static let conclusionBestEvaluationNextTitle = GameCopyKey.localizable("conclusion.best-evaluation.next-title")
    static let conclusionBestEvaluationRecordBody = GameCopyKey.localizable("conclusion.best-evaluation.record-body")
    static let conclusionBestEvaluationNextBody = GameCopyKey.localizable("conclusion.best-evaluation.next-body")
    static let conclusionRebirthAction = GameCopyKey.localizable("conclusion.rebirth.action")
    static let conclusionRebirthSummaryWithEul = GameCopyKey.localizable("conclusion.rebirth.summary.eul")
    static let conclusionRebirthSummaryWithReul = GameCopyKey.localizable("conclusion.rebirth.summary.reul")
    static let conclusionFoldTitle = GameCopyKey.localizable("conclusion.fold.title")
    static let conclusionFoldBody = GameCopyKey.localizable("conclusion.fold.body")
    static let conclusionFoldConfirmationTitle = GameCopyKey.localizable("conclusion.fold.confirmation-title")
    static let conclusionFoldAction = GameCopyKey.localizable("conclusion.fold.action")
    static let conclusionFoldCancel = GameCopyKey.localizable("conclusion.fold.cancel")
    static let conclusionFoldMessage = GameCopyKey.localizable("conclusion.fold.message")
    static let conclusionSeasonRecordTitle = GameCopyKey.localizable("conclusion.season-record.title")
    static let conclusionDirectOutings = GameCopyKey.localizable("conclusion.season-record.direct-outings")
    static let conclusionTeamGames = GameCopyKey.localizable("conclusion.season-record.team-games")
    static let conclusionRecentGames = GameCopyKey.localizable("conclusion.season-record.recent-games")
    static let conclusionSeasonLabel = GameCopyKey.localizable("conclusion.season-record.season")
    static let conclusionSeasonSummary = GameCopyKey.localizable("conclusion.season-record.summary")
    static let conclusionSeasonRA9 = GameCopyKey.localizable("conclusion.season-record.ra9")
    static let conclusionRoleStarter = GameCopyKey.localizable("conclusion.season-record.role.starter")
    static let conclusionRoleReliever = GameCopyKey.localizable("conclusion.season-record.role.reliever")
    static let conclusionDecisionWin = GameCopyKey.localizable("conclusion.season-record.decision.win")
    static let conclusionDecisionLoss = GameCopyKey.localizable("conclusion.season-record.decision.loss")
    static let conclusionDecisionSave = GameCopyKey.localizable("conclusion.season-record.decision.save")
    static let conclusionLineAccessibility = GameCopyKey.localizable("conclusion.season-record.line-accessibility")
    static let conclusionDraftRevealWaiting = GameCopyKey.localizable("conclusion.draft-reveal.waiting")
    static let conclusionDraftRevealRound = GameCopyKey.localizable("conclusion.draft-reveal.round")
    static let conclusionDraftRevealDrafted = GameCopyKey.localizable("conclusion.draft-reveal.drafted")
    static let conclusionDraftRevealPick = GameCopyKey.localizable("conclusion.draft-reveal.pick")
    static let conclusionDraftRevealBonus = GameCopyKey.localizable("conclusion.draft-reveal.bonus")
    static let conclusionDraftRevealComplete = GameCopyKey.localizable("conclusion.draft-reveal.complete")
    static let conclusionDraftRevealNotCalled = GameCopyKey.localizable("conclusion.draft-reveal.not-called")
    static let conclusionDraftRevealUndraftedBody = GameCopyKey.localizable("conclusion.draft-reveal.undrafted-body")
    static let conclusionDraftRevealContinue = GameCopyKey.localizable("conclusion.draft-reveal.continue")
    static let conclusionDraftRevealSkip = GameCopyKey.localizable("conclusion.draft-reveal.skip")
    static let conclusionChronicleStage = GameCopyKey.localizable("conclusion.chronicle.stage")
    static let conclusionChronicleAdmission = GameCopyKey.localizable("conclusion.chronicle.admission")
    static let conclusionChroniclePersonality = GameCopyKey.localizable("conclusion.chronicle.personality")
    static let conclusionChroniclePersonalityChanged = GameCopyKey.localizable("conclusion.chronicle.personality-changed")
    static let conclusionChronicleAwakening = GameCopyKey.localizable("conclusion.chronicle.awakening")
    static let conclusionChronicleNickname = GameCopyKey.localizable("conclusion.chronicle.nickname")
    static let conclusionChronicleGameFirst = GameCopyKey.localizable("conclusion.chronicle.game.first")
    static let conclusionChronicleGameShutout = GameCopyKey.localizable("conclusion.chronicle.game.shutout")
    static let conclusionChronicleGameStrikeouts = GameCopyKey.localizable("conclusion.chronicle.game.strikeouts")
    static let conclusionChronicleGameRough = GameCopyKey.localizable("conclusion.chronicle.game.rough")
    static let conclusionChronicleChapterGoal = GameCopyKey.localizable("conclusion.chronicle.chapter-goal")
    static let conclusionChronicleDrafted = GameCopyKey.localizable("conclusion.chronicle.drafted")
    static let conclusionChronicleUndrafted = GameCopyKey.localizable("conclusion.chronicle.undrafted")
    static let conclusionChroniclePledge = GameCopyKey.localizable("conclusion.chronicle.pledge")
    static let conclusionChronicleBloom = GameCopyKey.localizable("conclusion.chronicle.bloom")
    static let conclusionChronicleProStart = GameCopyKey.localizable("conclusion.chronicle.pro-start")
    static let conclusionChronicleDraftedNoRound = GameCopyKey.localizable("conclusion.chronicle.drafted-no-round")
    static let conclusionSignatureEvidenceDynamic = GameCopyKey.gameContent("content.signature-legacy.evidence.dynamic")
    static let conclusionRebirthStampTitle = GameCopyKey.localizable("conclusion.rebirth-stamp.title")
    static let conclusionRebirthStampLife = GameCopyKey.localizable("conclusion.rebirth-stamp.life")
    static let conclusionRebirthStampBody = GameCopyKey.localizable("conclusion.rebirth-stamp.body")
    static let conclusionRebirthStampAccessibility = GameCopyKey.localizable("conclusion.rebirth-stamp.accessibility")
    static let conclusionLifeCardHeader = GameCopyKey.localizable("conclusion.life-card.header")
    static let conclusionLifeCardDrafted = GameCopyKey.localizable("conclusion.life-card.drafted")
    static let conclusionLifeCardUndrafted = GameCopyKey.localizable("conclusion.life-card.undrafted")
    static let conclusionLifeCardSchoolUnknown = GameCopyKey.localizable("conclusion.life-card.school-unknown")
    static let conclusionLifeCardWind = GameCopyKey.localizable("conclusion.life-card.wind")
    static let conclusionLifeCardResultDrafted = GameCopyKey.localizable("conclusion.life-card.result-drafted")
    static let conclusionLifeCardResultUndrafted = GameCopyKey.localizable("conclusion.life-card.result-undrafted")
    static let conclusionLifeCardScoutScore = GameCopyKey.localizable("conclusion.life-card.scout-score")
    static let conclusionLifeCardGrowthTitle = GameCopyKey.localizable("conclusion.life-card.growth-title")
    static let conclusionLifeCardGrowthTotal = GameCopyKey.localizable("conclusion.life-card.growth-total")
    static let conclusionLifeCardGrowthStuff = GameCopyKey.localizable("conclusion.life-card.growth.stuff")
    static let conclusionLifeCardGrowthCommand = GameCopyKey.localizable("conclusion.life-card.growth.command")
    static let conclusionLifeCardGrowthMovement = GameCopyKey.localizable("conclusion.life-card.growth.movement")
    static let conclusionLifeCardGrowthStamina = GameCopyKey.localizable("conclusion.life-card.growth.stamina")
    static let conclusionLifeCardGrowthAccessibilityUp = GameCopyKey.localizable("conclusion.life-card.growth.accessibility.up")
    static let conclusionLifeCardGrowthAccessibilityNoChange = GameCopyKey.localizable("conclusion.life-card.growth.accessibility.no-change")
    static let conclusionLifeCardStatsTitle = GameCopyKey.localizable("conclusion.life-card.stats-title")
    static let conclusionLifeCardInnings = GameCopyKey.localizable("conclusion.life-card.innings")
    static let conclusionLifeCardRA9 = GameCopyKey.localizable("conclusion.life-card.ra9")
    static let conclusionLifeCardWHIP = GameCopyKey.localizable("conclusion.life-card.whip")
    static let conclusionLifeCardK9 = GameCopyKey.localizable("conclusion.life-card.k9")
    static let conclusionLifeCardGames = GameCopyKey.localizable("conclusion.life-card.games")
    static let conclusionLifeCardStrikeouts = GameCopyKey.localizable("conclusion.life-card.strikeouts")
    static let conclusionLifeCardHits = GameCopyKey.localizable("conclusion.life-card.hits")
    static let conclusionLifeCardWalks = GameCopyKey.localizable("conclusion.life-card.walks")
    static let conclusionLifeCardRuns = GameCopyKey.localizable("conclusion.life-card.runs")
    static let conclusionLifeCardSeasonLine = GameCopyKey.localizable("conclusion.life-card.season-line")
    static let conclusionLifeCardSeasonLineNoPitches = GameCopyKey.localizable("conclusion.life-card.season-line.no-pitches")
    static let conclusionLifeCardSeasonLineNoWalks = GameCopyKey.localizable("conclusion.life-card.season-line.no-walks")
    static let conclusionLifeCardSeasonLineEmpty = GameCopyKey.localizable("conclusion.life-card.season-line.empty")
    static let conclusionLifeCardSignature = GameCopyKey.localizable("conclusion.life-card.signature")
    static let conclusionLifeCardSignatureAccessibility = GameCopyKey.localizable("conclusion.life-card.signature-accessibility")
    static let conclusionLifeCardCoach = GameCopyKey.localizable("conclusion.life-card.coach")
    static let conclusionLifeCardCatcher = GameCopyKey.localizable("conclusion.life-card.catcher")
    static let conclusionLifeCardRival = GameCopyKey.localizable("conclusion.life-card.rival")
    static let conclusionLifeCardFooter = GameCopyKey.localizable("conclusion.life-card.footer")
    static let conclusionLifeCardComplete = GameCopyKey.localizable("conclusion.life-card.complete")
    static let conclusionLifeCardChallenge = GameCopyKey.localizable("conclusion.life-card.challenge")
    static let conclusionLifeCardPreviewAccessibility = GameCopyKey.localizable("conclusion.life-card.preview-accessibility")
    static let conclusionLifeCardShare = GameCopyKey.localizable("conclusion.life-card.share")
    static let conclusionLifeCardShareSubject = GameCopyKey.localizable("conclusion.life-card.share-subject")
    static let conclusionLifeCardShareBodyHeader = GameCopyKey.localizable("conclusion.life-card.share-body-header")
    static let conclusionLifeCardShareBodyChallenge = GameCopyKey.localizable("conclusion.life-card.share-body-challenge")

    static let highSchoolConclusionKeys: [GameCopyKey] = [
        conclusionChronicleTitle, conclusionDraftTitle, conclusionDraftIntro, conclusionScoutTitle,
        conclusionRecordTitle, conclusionOfficialGames, conclusionRecordStats, conclusionAwakeningTraining,
        conclusionResolveDraft, conclusionPlayerRecordCard, conclusionDraftSummaryDrafted,
        conclusionDraftSummaryUndrafted, conclusionEvaluationScore, conclusionEvaluationBreakdownAccessibility,
        conclusionProjectedFirstRound, conclusionProjectedMiddleRounds, conclusionProjectedLateRounds,
        conclusionProjectedUndrafted, conclusionFirstSeasonGoal, conclusionBreakdownAbility,
        conclusionBreakdownHighSchool, conclusionBreakdownSeason, conclusionBreakdownAwakening,
        conclusionBreakdownRelationship, conclusionBreakdownHandicap, conclusionBreakdownArm,
        conclusionWindReview, conclusionDraftAdjustment, conclusionInheritanceAdjustment,
        conclusionSignatureTitle, conclusionSignatureDescription, conclusionSignatureRemainder,
        conclusionMemoryTitle, conclusionMemoryDescription, conclusionMemoryMore,
        conclusionLegacyConfirmAction, conclusionMemoryConfirmAction, conclusionLegacyConfirmationTitle,
        conclusionMemoryConfirmationTitle, conclusionConfirmationCancel, conclusionLegacyConfirmationMessage,
        conclusionConfirmationConfirm,
        conclusionMemoryConfirmationMessage, conclusionCompletionTitle, conclusionCompletionEnded,
        conclusionCarriedMemorySummary, conclusionTeamWaiting, conclusionCoachName, conclusionCompetitorFallback,
        conclusionEnterPro, conclusionNotOver, conclusionLegacyPreviewTitle, conclusionLegacyPreviewBody,
        conclusionAwaitingRetirementTitle, conclusionAwaitingRetirementBody,
        conclusionBestEvaluationRecordTitle, conclusionBestEvaluationNextTitle,
        conclusionBestEvaluationRecordBody, conclusionBestEvaluationNextBody, conclusionRebirthAction,
        conclusionRebirthSummaryWithEul, conclusionRebirthSummaryWithReul, conclusionFoldTitle,
        conclusionFoldBody, conclusionFoldConfirmationTitle, conclusionFoldAction, conclusionFoldCancel,
        conclusionFoldMessage, conclusionSeasonRecordTitle, conclusionDirectOutings, conclusionTeamGames,
        conclusionRecentGames, conclusionSeasonLabel, conclusionSeasonSummary, conclusionSeasonRA9,
        conclusionRoleStarter, conclusionRoleReliever, conclusionDecisionWin, conclusionDecisionLoss,
        conclusionDecisionSave, conclusionLineAccessibility, conclusionDraftRevealWaiting,
        conclusionDraftRevealRound, conclusionDraftRevealDrafted, conclusionDraftRevealPick,
        conclusionDraftRevealBonus, conclusionDraftRevealComplete, conclusionDraftRevealNotCalled,
        conclusionDraftRevealUndraftedBody, conclusionDraftRevealContinue, conclusionDraftRevealSkip,
        conclusionChronicleStage, conclusionChronicleAdmission, conclusionChroniclePersonality,
        conclusionChroniclePersonalityChanged, conclusionChronicleAwakening, conclusionChronicleNickname,
        conclusionChronicleGameFirst, conclusionChronicleGameShutout, conclusionChronicleGameStrikeouts,
        conclusionChronicleGameRough, conclusionChronicleChapterGoal, conclusionChronicleDrafted,
        conclusionChronicleUndrafted, conclusionChroniclePledge, conclusionChronicleBloom,
        conclusionChronicleProStart, conclusionChronicleDraftedNoRound,
        conclusionRebirthStampTitle, conclusionRebirthStampLife, conclusionRebirthStampBody,
        conclusionRebirthStampAccessibility, conclusionLifeCardHeader, conclusionLifeCardDrafted,
        conclusionLifeCardUndrafted, conclusionLifeCardSchoolUnknown, conclusionLifeCardWind,
        conclusionLifeCardResultDrafted, conclusionLifeCardResultUndrafted, conclusionLifeCardScoutScore,
        conclusionLifeCardGrowthTitle, conclusionLifeCardGrowthTotal, conclusionLifeCardGrowthStuff,
        conclusionLifeCardGrowthCommand, conclusionLifeCardGrowthMovement, conclusionLifeCardGrowthStamina,
        conclusionLifeCardGrowthAccessibilityUp, conclusionLifeCardGrowthAccessibilityNoChange,
        conclusionLifeCardStatsTitle, conclusionLifeCardInnings, conclusionLifeCardRA9,
        conclusionLifeCardWHIP, conclusionLifeCardK9, conclusionLifeCardGames, conclusionLifeCardStrikeouts,
        conclusionLifeCardHits, conclusionLifeCardWalks, conclusionLifeCardRuns, conclusionLifeCardSeasonLine,
        conclusionLifeCardSeasonLineNoPitches,
        conclusionLifeCardSeasonLineNoWalks, conclusionLifeCardSeasonLineEmpty,
        conclusionLifeCardSignature, conclusionLifeCardSignatureAccessibility,
        conclusionLifeCardCoach, conclusionLifeCardCatcher, conclusionLifeCardRival,
        conclusionLifeCardFooter, conclusionLifeCardComplete, conclusionLifeCardChallenge,
        conclusionLifeCardPreviewAccessibility, conclusionLifeCardShare,
        conclusionLifeCardShareSubject, conclusionLifeCardShareBodyHeader,
        conclusionLifeCardShareBodyChallenge,
    ]
}
