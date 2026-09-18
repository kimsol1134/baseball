package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolTournamentRules

import com.solkim.baseball.core.highschool.HighSchoolContentCatalog
import com.solkim.baseball.core.highschool.HighSchoolDifficulty
import com.solkim.baseball.core.highschool.HighSchoolPledgeRules
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolAchievementRules
import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolIdentity
import com.solkim.baseball.core.highschool.HighSchoolKarma
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolRebirthEntryPath
import com.solkim.baseball.core.highschool.HighSchoolRelationshipTarget
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.core.highschool.HighSchoolReturnDestination
import com.solkim.baseball.core.highschool.HighSchoolSeasonLine
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity
import com.solkim.baseball.core.pro.OffseasonDecision
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProDevelopmentFocus
import com.solkim.baseball.core.pro.ProEntitlement
import com.solkim.baseball.core.pro.ProFanReasonKind
import com.solkim.baseball.core.pro.ProGameLine
import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.core.pro.ProMerchandiseTier
import com.solkim.baseball.core.pro.ProSettlementNextRoute
import com.solkim.baseball.core.pro.ProOffseasonInvestment
import com.solkim.baseball.core.pro.ProHighSchoolLegacyContext
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProLevel
import com.solkim.baseball.core.pro.ProNationalTeamRules
import com.solkim.baseball.core.pro.ProNationalTournamentStage
import com.solkim.baseball.core.pro.ProRole
import com.solkim.baseball.core.pro.ProSeasonSegment
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProWeekPlan
import com.solkim.baseball.core.pro.careerGames
import com.solkim.baseball.core.pro.careerStrikeouts
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.model.Hashing
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.WeekFields


internal fun hs(command: HighSchoolPhase4Command): GameCommand = GameCommand.HighSchool(command)
internal fun proCommand(command: ProCommand): GameCommand = GameCommand.Pro(command)

internal fun tutorialSession(state: GameAggregateState): String = CareerWire.tutorialSession(state.highSchool?.run?.careerId)

internal fun tutorialCommands(state: GameAggregateState, context: ScreenCommandContext): List<GameCommand> {
    val session = tutorialSession(state)
    return listOf(
        GameCommand.ReservePitch(session, PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "tutorial", context.seed(state, "tutorial-pitch"), false),
        GameCommand.StartPitch(session),
    )
}

internal fun importantGameCommands(state: GameAggregateState, context: ScreenCommandContext): List<GameCommand> {
    val highSchool = requireNotNull(state.highSchool)
    val seed = context.seed(state, "important-game")
    val reserved = HighSchoolPhase4Kernel().reserveImportantGame(seed, highSchool).state
    val active = requireNotNull(reserved.activePitch)
    return listOf(
        hs(HighSchoolPhase4Command.ReserveImportantGame(seed)),
        GameCommand.ReservePitch(active.sessionId, PitchCareerKind.HIGH_SCHOOL, highSchool.run.careerId, active.log.gameId, active.seed, highSchool.challenge.active),
        GameCommand.StartPitch(active.sessionId),
    )
}

internal fun nextHighSchoolPitchCommands(state: GameAggregateState): List<GameCommand> {
    val highSchool = requireNotNull(state.highSchool)
    val active = requireNotNull(highSchool.activePitch)
    return listOf(
        GameCommand.ClearPitchPresentation(active.sessionId),
        GameCommand.ReservePitch(active.sessionId, PitchCareerKind.HIGH_SCHOOL, highSchool.run.careerId, active.log.gameId, active.seed, highSchool.challenge.active),
        GameCommand.StartPitch(active.sessionId),
    )
}

internal fun proImportantGameCommands(state: GameAggregateState, context: ScreenCommandContext): List<GameCommand> {
    val pro = requireNotNull(state.pro)
    val seed = context.seed(state, "pro-important-game")
    val reserved = ProKernel().reserveImportantGame(pro, seed).state
    val active = requireNotNull(reserved.activePitch)
    return listOf(
        proCommand(ProCommand.ReserveImportantGame(seed)),
        GameCommand.ReservePitch(active.sessionId, PitchCareerKind.PRO, pro.careerId, active.log.gameId, active.seed, false),
        GameCommand.StartPitch(active.sessionId),
    )
}

internal fun nextProPitchCommands(state: GameAggregateState): List<GameCommand> {
    val pro = requireNotNull(state.pro)
    val active = requireNotNull(pro.activePitch)
    return listOf(
        GameCommand.ClearPitchPresentation(active.sessionId),
        GameCommand.ReservePitch(active.sessionId, PitchCareerKind.PRO, pro.careerId, active.log.gameId, active.seed, false),
        GameCommand.StartPitch(active.sessionId),
    )
}

internal fun settingsCommand(state: GameAggregateState, transform: (GameSettingsState) -> GameSettingsState): GameCommand =
    GameCommand.UpdateSettings(transform(state.settings))

internal fun linkedRequest(state: GameAggregateState, context: ScreenCommandContext): ProStartLinkedRequest {
    val run = requireNotNull(state.highSchool).run
    val pitcher = run.pitcher.toPitcherSnapshot()
    return ProStartLinkedRequest(
        seed = context.seed(state, "pro-linked"),
        highSchoolCareerId = run.careerId,
        pitchLearningProject = run.pitchLearningProject,
        identityName = run.identity.name,
        pitcher = pitcher,
        teamId = requireNotNull(run.draftResult?.teamId) { "pro.drafted_team_missing" },
        draftRound = run.draftResult?.round,
        signingBonus = run.draftResult?.signingBonus?.toLong(),
        overallPick = run.draftResult?.overallPick,
        sourceFanInterest = run.fanInterest,
        draftEvaluation = run.draftResult?.evaluationScore ?: 60,
        entitlement = ProEntitlement(),
        activeHighSchoolPreserved = true,
        highSchoolLegacyContext = ProHighSchoolLegacyContext(requireNotNull(state.highSchool).startingPitcher.toPitcherSnapshot(), pitcher, run.performance.copy(perfectReleases = 0), run.selectedAwakenings.map { it.wire }, run.managerTrust, run.catcherTrust, run.rivalTrust),
    )
}

internal fun com.solkim.baseball.core.highschool.HighSchoolPitcher.toPitcherSnapshot(): PitcherSnapshot = PitcherSnapshot(
    id = id,
    name = name,
    stuff = stuff,
    command = command,
    movement = movement,
    stamina = stamina,
    pitchProfiles = pitchProfiles.ifEmpty { listOf(PitchProfileSnapshot(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1_400, command, command, stuff, stuff, command, 1), PitchProfileSnapshot(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1_240, command, command, movement, movement, movement, 1)) },
    throwingHand = throwingHand,
    mastery = mastery,
)

internal fun HighSchoolTrainingFocus.pitchKindOrNull(): PitchKind? = when (this) {
    HighSchoolTrainingFocus.VELOCITY -> PitchKind.FOUR_SEAM
    HighSchoolTrainingFocus.BREAKING_BALL -> PitchKind.SLIDER
    else -> null
}
