package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolDifficulty
import com.solkim.baseball.core.highschool.HighSchoolIdentity
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.ZoneIntent
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.PitchPresentationRequest
import java.util.concurrent.atomic.AtomicLong

public enum class Phase7Route {
    OPENING,
    SETUP,
    PROLOGUE,
    TUTORIAL,
    SCHOOL,
    TRAINING,
    RELATIONSHIP,
    IMPORTANT_GAME,
    PITCH,
    POSTGAME,
    AWAKENING,
    CHAPTER,
}

public data class PitchLaunch(
    public val sessionId: String,
    public val expectedRevision: ULong,
)

public object Phase7RoutePolicy {
    public fun route(state: GameAggregateState): Phase7Route {
        val pitch = state.pitch
        if (pitch != null && pitch.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) {
            return Phase7Route.PITCH
        }
        if (state.stage == GameStage.OPENING) return Phase7Route.OPENING
        if (state.stage == GameStage.SETUP) return Phase7Route.SETUP

        val highSchool = state.highSchool ?: return Phase7Route.OPENING
        if (highSchool.run.phase == HighSchoolPhase.PROLOGUE && highSchool.tutorial.started && !highSchool.tutorial.completed) {
            return Phase7Route.TUTORIAL
        }
        if (pitch?.boundary == PitchBoundary.COMPLETED &&
            pitch.careerKind == PitchCareerKind.HIGH_SCHOOL &&
            highSchool.activePitch == null &&
            highSchool.lastPresentation != null
        ) {
            return Phase7Route.POSTGAME
        }
        return when (highSchool.run.phase) {
            HighSchoolPhase.PROLOGUE -> if (highSchool.tutorial.started) Phase7Route.TUTORIAL else Phase7Route.PROLOGUE
            HighSchoolPhase.SCHOOL_SELECTION -> Phase7Route.SCHOOL
            HighSchoolPhase.TRAINING -> Phase7Route.TRAINING
            HighSchoolPhase.RELATIONSHIP -> Phase7Route.RELATIONSHIP
            HighSchoolPhase.IMPORTANT_GAME -> Phase7Route.IMPORTANT_GAME
            HighSchoolPhase.AWAKENING -> Phase7Route.AWAKENING
            HighSchoolPhase.CHAPTER_REVIEW -> Phase7Route.CHAPTER
            HighSchoolPhase.DRAFT,
            HighSchoolPhase.LEGACY,
            HighSchoolPhase.COMPLETED -> Phase7Route.POSTGAME
        }
    }
}

/**
 * Typed application actions for the Phase 7 vertical. This class has no Android or Compose
 * dependency; the UI only projects [GameStore.state] and calls these suspend boundaries.
 */
public class Phase7VerticalController(
    public val store: GameStore,
    public val shellSessionId: String = "phase7-shell",
) {
    private val commandSequence = AtomicLong(0)
    private val tutorialPitchSession = "phase7:tutorial"

    public fun route(): Phase7Route = Phase7RoutePolicy.route(store.state.value)

    public suspend fun enterSetup() {
        dispatch(GameCommand.EnterSetup)
    }

    public suspend fun startHighSchool(name: String) {
        val trimmed = name.trim().ifBlank { "민서준" }.take(40)
        dispatch(
            GameCommand.HighSchool(
                HighSchoolPhase4Command.Start(
                    HighSchoolPhase4StartRequest(
                        seed = "20260814",
                        presetId = "power_prospect",
                        stableUserId = store.state.value.installId,
                        weekKey = "2026-W33",
                        dayKey = "2026-08-14",
                        identity = HighSchoolIdentity(name = trimmed, region = "서울"),
                        difficulty = HighSchoolDifficulty(),
                    ),
                ),
            ),
        )
    }

    public suspend fun beginTutorial() {
        dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.BeginTutorial))
    }

    public suspend fun completeTutorial() {
        dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("20260814")))
    }

    public suspend fun chooseSchool(schoolId: HighSchoolSchoolId = HighSchoolSchoolId.HAEDONG_POWER) {
        dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool("20260815", schoolId)))
    }

    public suspend fun commitTraining() {
        val highSchool = requireNotNull(store.state.value.highSchool) { "phase7.highSchool_missing" }
        val focus = highSchool.run.trainingOpportunity?.focus ?: HighSchoolTrainingFocus.COMMAND
        val targetPitch = highSchool.run.pitcher.pitchProfiles.firstOrNull()?.pitchType
        dispatch(
            GameCommand.HighSchool(
                HighSchoolPhase4Command.Training(
                    seed = "${20260816 + highSchool.run.totalTrainingsCompleted}",
                    focus = focus,
                    intensity = HighSchoolTrainingIntensity.STANDARD,
                    targetPitch = targetPitch,
                ),
            ),
        )
    }

    public suspend fun resolveRelationship() {
        dispatch(
            GameCommand.HighSchool(
                HighSchoolPhase4Command.Relationship("20260820", HighSchoolRelationshipResponse.LISTEN),
            ),
        )
    }

    public suspend fun chooseAwakening(awakening: HighSchoolAwakening? = null) {
        val highSchool = requireNotNull(store.state.value.highSchool) { "phase7.highSchool_missing" }
        val selected = awakening ?: highSchool.run.awakeningOptions.firstOrNull() ?: error("phase7.awakening_missing")
        dispatch(
            GameCommand.HighSchool(
                HighSchoolPhase4Command.ChooseAwakening("20260821", selected),
            ),
        )
    }

    public suspend fun advanceChapter() {
        dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.AdvanceChapter("20260822")))
    }

    public suspend fun reserveTutorialPitch(): PitchLaunch {
        val state = store.state.value
        val pitch = GameCommand.ReservePitch(
            sessionId = tutorialPitchSession,
            careerKind = PitchCareerKind.TUTORIAL,
            careerId = TUTORIAL_CAREER_ID,
            gameId = "tutorial",
            seed = "20260814",
            challengeRun = false,
        )
        dispatch(pitch)
        dispatch(GameCommand.StartPitch(tutorialPitchSession))
        return PitchLaunch(tutorialPitchSession, store.state.value.revision)
    }

    public suspend fun reserveImportantGame(): PitchLaunch {
        dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.ReserveImportantGame("20260823")))
        return reserveCurrentHighSchoolPitch()
    }

    /** Starts another durable pitch boundary inside an important game after the prior PA ended. */
    public suspend fun reserveNextImportantPitch(): PitchLaunch {
        val state = store.state.value
        val highSchool = requireNotNull(state.highSchool) { "phase7.highSchool_missing" }
        val active = requireNotNull(highSchool.activePitch) { "phase7.pitch_missing" }
        require(state.pitch?.boundary == PitchBoundary.COMPLETED || state.pitch?.boundary == PitchBoundary.ABANDONED) {
            "phase7.previous_pitch_not_complete"
        }
        dispatch(GameCommand.ClearPitchPresentation(active.sessionId))
        return reserveCurrentHighSchoolPitch()
    }

    public suspend fun resumePitch(sessionId: String): PitchLaunch {
        dispatch(GameCommand.ResumePitch(sessionId))
        return PitchLaunch(sessionId, store.state.value.revision)
    }

    public suspend fun suspendPitch(sessionId: String, reason: String = "back") {
        dispatch(GameCommand.SuspendPitch(sessionId, "phase7:$reason"))
    }

    public suspend fun abandonPitch(sessionId: String, reason: String = "user_abandoned") {
        dispatch(GameCommand.AbandonPitch(sessionId, reason))
    }

    /** Dismisses the saved Compose postgame projection; it never rewinds the authoritative report. */
    public suspend fun dismissPostgame() {
        val state = store.state.value
        val pitch = requireNotNull(state.pitch) { "phase7.pitch_missing" }
        require(pitch.boundary == PitchBoundary.COMPLETED) { "phase7.postgame_boundary" }
        require(pitch.careerKind == PitchCareerKind.HIGH_SCHOOL || pitch.careerKind == PitchCareerKind.PRO) { "phase7.postgame_career" }
        require(
            state.highSchool?.lastPresentation != null || state.pro?.lastPresentation != null ||
                (pitch.careerKind == PitchCareerKind.PRO && state.pro?.activePitch == null),
        ) { "phase7.postgame_missing" }
        dispatch(GameCommand.ClearPitchPresentation(pitch.sessionId))
    }

    public suspend fun preparePresentation(sessionId: String, pitchIndex: Int): PitchPresentationRequest {
        val state = store.state.value
        val pitch = requireNotNull(state.pitch) { "phase7.pitch_missing" }
        require(pitch.sessionId == sessionId) { "phase7.pitch_session" }
        val highSchool = state.highSchool
        val savedHighSchool = highSchool?.lastPresentation
        val savedPro = state.pro?.lastPresentation
        val request = when {
            pitch.careerKind == PitchCareerKind.HIGH_SCHOOL && savedHighSchool != null ->
                PitchPresentationFactory.fromHighSchoolPresentation(sessionId, savedHighSchool.pitchNumber, savedHighSchool)
            pitch.careerKind == PitchCareerKind.PRO && savedPro != null -> {
                val outcome = state.pro?.activePitch?.log?.entries?.lastOrNull()?.outcome ?: PitchOutcome.CALLED_STRIKE
                PitchPresentationFactory.fromTrajectoryPresentation(sessionId, state.pro?.activePitch?.pitchIndex ?: pitch.pitchIndex.coerceAtLeast(1), savedPro, outcome)
            }
            else -> {
            val index = pitch.checkpoint
                ?.removePrefix("phase7-index:")
                ?.substringBefore(':')
                ?.toIntOrNull()
                ?: pitchIndex.coerceIn(0, 3)
            KotlinPitchPresentationSession().request(
                sessionId = sessionId,
                index = index,
                sequence = pitch.pitchIndex.coerceAtLeast(1),
            )
            }
        }
        if (pitch.boundary in setOf(PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL)) {
            require(request.pitchId in pitch.committedPitchIds) { "phase7.presentation_not_committed" }
        }
        return request
    }

    /** Generates the authoritative result, saves it in HighSchool, then commits its renderer snapshot. */
    public suspend fun submitPitch(
        sessionId: String,
        pitchIndex: Int,
        pitchType: PitchKind,
        zone: PitchZone,
        delivery: PitchDelivery,
    ): PitchPresentationRequest {
        val state = store.state.value
        val pitch = requireNotNull(state.pitch) { "phase7.pitch_missing" }
        require(pitch.sessionId == sessionId && pitch.boundary == PitchBoundary.PLAYING) { "phase7.pitch_not_playing" }
        val request = when (pitch.careerKind) {
            PitchCareerKind.TUTORIAL -> KotlinPitchPresentationSession().request(sessionId, pitchIndex, pitch.pitchIndex + 1)
            PitchCareerKind.HIGH_SCHOOL -> {
                val call = PitchCall(pitchType, zone, ZoneIntent.EDGE, PitchIntensity.NORMAL)
                dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.SubmitPitch(sessionId, call, delivery)))
                val presentation = requireNotNull(store.state.value.highSchool?.lastPresentation) { "phase7.presentation_missing" }
                PitchPresentationFactory.fromHighSchoolPresentation(sessionId, presentation.pitchNumber, presentation)
            }
            PitchCareerKind.PRO -> {
                val call = PitchCall(pitchType, zone, ZoneIntent.EDGE, PitchIntensity.NORMAL)
                dispatch(GameCommand.Pro(ProCommand.SubmitPitch(sessionId, call, delivery)))
                val after = store.state.value
                val presentation = requireNotNull(after.pro?.lastPresentation) { "phase7.pro_presentation_missing" }
                val outcome = after.pro?.activePitch?.log?.entries?.lastOrNull()?.outcome ?: PitchOutcome.CALLED_STRIKE
                PitchPresentationFactory.fromTrajectoryPresentation(sessionId, after.pro?.activePitch?.pitchIndex ?: pitch.pitchIndex + 1, presentation, outcome)
            }
        }
        dispatch(
            GameCommand.CommitPitch(
                sessionId = sessionId,
                pitchId = request.pitchId,
                resultHash = Hashing.fnv1a64Hex("${request.pitchId}|${request.requestSha256}|${store.state.value.commitment}"),
                checkpoint = "phase7-index:$pitchIndex:${request.requestSha256}",
            ),
        )
        return request
    }

    /** Rebuilds and durably commits a HighSchool result saved just before a process death. */
    public suspend fun commitSavedPresentation(sessionId: String, pitchIndex: Int = 0): PitchPresentationRequest {
        val state = store.state.value
        val pitch = requireNotNull(state.pitch) { "phase7.pitch_missing" }
        require(pitch.sessionId == sessionId && pitch.boundary == PitchBoundary.PLAYING) {
            "phase7.saved_presentation_boundary"
        }
        val request = when (pitch.careerKind) {
            PitchCareerKind.HIGH_SCHOOL -> {
                val presentation = requireNotNull(state.highSchool?.lastPresentation) { "phase7.presentation_missing" }
                PitchPresentationFactory.fromHighSchoolPresentation(sessionId, presentation.pitchNumber, presentation)
            }
            PitchCareerKind.PRO -> {
                val presentation = requireNotNull(state.pro?.lastPresentation) { "phase7.pro_presentation_missing" }
                val outcome = state.pro?.activePitch?.log?.entries?.lastOrNull()?.outcome ?: PitchOutcome.CALLED_STRIKE
                PitchPresentationFactory.fromTrajectoryPresentation(sessionId, state.pro?.activePitch?.pitchIndex ?: pitch.pitchIndex + 1, presentation, outcome)
            }
            PitchCareerKind.TUTORIAL -> error("phase7.saved_presentation_career")
        }
        dispatch(
            GameCommand.CommitPitch(
                sessionId = sessionId,
                pitchId = request.pitchId,
                resultHash = Hashing.fnv1a64Hex("${request.pitchId}|${request.requestSha256}|${store.state.value.commitment}"),
                checkpoint = "phase7-index:${pitchIndex.coerceIn(0, 3)}:${request.requestSha256}",
            ),
        )
        return request
    }

    public suspend fun consumePresentation(sessionId: String, request: PitchPresentationRequest) {
        val state = store.state.value
        when (state.pitch?.boundary) {
            PitchBoundary.COMMITTED -> dispatch(GameCommand.ConsumePitch(sessionId, request.pitchId))
            PitchBoundary.CONSUMED,
            PitchBoundary.TERMINAL,
            PitchBoundary.COMPLETED -> Unit
            else -> error("phase7.consume_boundary")
        }
        if (store.state.value.pitch?.boundary == PitchBoundary.CONSUMED) {
            dispatch(GameCommand.MarkPitchTerminal(sessionId, request.pitchId, request.requestSha256))
        }
    }

    /** Returns only after the consume/terminal state is durable and the authoritative game report is saved. */
    public suspend fun completePitchAndPostgame(sessionId: String) {
        val state = store.state.value
        if (state.pitch?.boundary == PitchBoundary.COMPLETED) return
        require(state.pitch?.boundary == PitchBoundary.TERMINAL) { "phase7.postgame_boundary" }
        if (state.highSchool?.activePitch?.ended == true) dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.FinishImportantGame))
        if (state.pro?.activePitch?.ended == true) dispatch(GameCommand.Pro(ProCommand.FinishImportantGame))
        if (store.state.value.pitch?.boundary == PitchBoundary.TERMINAL) {
            dispatch(GameCommand.CompletePitch(sessionId))
        }
    }

    private suspend fun reserveCurrentHighSchoolPitch(): PitchLaunch {
        val state = store.state.value
        val highSchool = requireNotNull(state.highSchool) { "phase7.highSchool_missing" }
        val active = requireNotNull(highSchool.activePitch) { "phase7.pitch_missing" }
        dispatch(
            GameCommand.ReservePitch(
                sessionId = active.sessionId,
                careerKind = PitchCareerKind.HIGH_SCHOOL,
                careerId = highSchool.run.careerId,
                gameId = active.log.gameId,
                seed = active.seed,
                challengeRun = highSchool.challenge.active,
            ),
        )
        dispatch(GameCommand.StartPitch(active.sessionId))
        return PitchLaunch(active.sessionId, store.state.value.revision)
    }

    private suspend fun dispatch(command: GameCommand, sessionId: String = commandSession(command)) {
        val sequence = commandSequence.incrementAndGet()
        val envelope = GameCommandEnvelope(
            commandId = "phase7-${Hashing.fnv1a64Hex("${store.state.value.installId}|${store.state.value.revision}|$sequence")}",
            sessionId = sessionId,
            expectedRevision = store.state.value.revision,
            command = command,
        )
        store.dispatch(envelope)
    }

    private fun commandSession(command: GameCommand): String = when (command) {
        is GameCommand.ReservePitch -> command.sessionId
        is GameCommand.StartPitch -> command.sessionId
        is GameCommand.CommitPitch -> command.sessionId
        is GameCommand.ConsumePitch -> command.sessionId
        is GameCommand.MarkPitchTerminal -> command.sessionId
        is GameCommand.CompletePitch -> command.sessionId
        is GameCommand.SuspendPitch -> command.sessionId
        is GameCommand.ResumePitch -> command.sessionId
        is GameCommand.AbandonPitch -> command.sessionId
        is GameCommand.ClearPitchPresentation -> command.sessionId
        GameCommand.EnterSetup,
        is GameCommand.HighSchool,
        is GameCommand.Pro,
        is GameCommand.UpdateSettings,
        is GameCommand.RecordAnalytics -> shellSessionId
    }
}
