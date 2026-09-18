package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandEnvelope
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandStore
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProCommandEnvelope
import com.solkim.baseball.core.pro.ProCommandStore
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.persistence.KotlinSaveRepository
import com.solkim.baseball.persistence.SaveLoadStatus
import com.solkim.baseball.persistence.SaveRepositoryException
import com.solkim.baseball.persistence.SaveLoadResult
import com.solkim.baseball.persistence.SaveWriteResult
import com.solkim.baseball.persistence.SaveEnvelope
import com.solkim.baseball.model.canonicalSha256
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.runBlocking
import java.util.concurrent.atomic.AtomicBoolean

public object GameStateReducer {
    public fun dispatch(state: GameAggregateState, envelope: GameCommandEnvelope): GameDispatchResult {
        try { envelope.validate() } catch (error: IllegalArgumentException) { throw GameCommandException(error.message ?: "game.command.invalid") }
        val commandHash = GameCommandCodec.commandHash(envelope)
        val existing = state.commandReceipts.firstOrNull { it.commandId == envelope.commandId }
        if (existing != null) {
            if (existing.commandHash != commandHash) throw GameCommandException("game.command.duplicate_tampered")
            return GameDispatchResult(state, existing.resultHash, duplicate = true)
        }
        if (envelope.expectedRevision != state.revision) throw GameCommandException("game.command.stale_revision")

            val reduced = try {
            when (val command = envelope.command) {
                GameCommand.EnterSetup -> enterSetup(state)
                GameCommand.ResetProgress -> resetProgress(state)
                is GameCommand.HighSchool -> reduceHighSchool(state, envelope, command.command)
                is GameCommand.Pro -> reducePro(state, envelope, command.command)
                is GameCommand.ReservePitch -> PitchCommands.reserve(state, command).let { it.state to it.eventName }
                is GameCommand.StartPitch -> PitchCommands.start(state, command).let { it.state to it.eventName }
                is GameCommand.CommitPitch -> PitchCommands.commit(state, command).let { it.state to it.eventName }
                is GameCommand.ConsumePitch -> PitchCommands.consume(state, command).let { it.state to it.eventName }
                is GameCommand.MarkPitchTerminal -> PitchCommands.terminal(state, command).let { it.state to it.eventName }
                is GameCommand.CompletePitch -> PitchCommands.complete(state, command).let { it.state to it.eventName }
                is GameCommand.SuspendPitch -> PitchCommands.suspend(state, command).let { it.state to it.eventName }
                is GameCommand.ResumePitch -> PitchCommands.resume(state, command).let { it.state to it.eventName }
                is GameCommand.AbandonPitch -> PitchCommands.abandon(state, command).let { it.state to it.eventName }
                is GameCommand.ClearPitchPresentation -> PitchCommands.clearPresentation(state, command).let { it.state to it.eventName }
                is GameCommand.UpdateCompanion -> state.copy(meta = state.meta.copy(companion = PitcherCompanionRules.apply(state, command.operation, command.value))) to "companion.updated"
                is GameCommand.UpdateSettings -> updateSettings(state, command)
                is GameCommand.SetPitchHoldCall -> PitchCommands.holdCall(state, command).let { it.state to it.eventName }
                is GameCommand.RecordAnalytics -> recordAnalytics(state, command)
            }
        } catch (error: GameCommandException) {
            throw error
        } catch (error: IllegalArgumentException) {
            throw GameCommandException(error.message ?: "game.command.rejected")
        }
        return try {
            commit(
                previousState = state,
                reducedState = reduced.first,
                envelope = envelope,
                commandHash = commandHash,
                eventName = reduced.second,
            )
        } catch (error: GameCommandException) {
            throw error
        } catch (error: IllegalArgumentException) {
            throw GameCommandException(error.message ?: "game.command.rejected")
        }
    }

    private fun reduceHighSchool(state: GameAggregateState, envelope: GameCommandEnvelope, command: HighSchoolPhase4Command): Pair<GameAggregateState, String> {
        if (command == HighSchoolPhase4Command.ClaimWeeklyReward) WeeklyNotePolicy.requireClaimable(state)
        val base = ProRetirementLedger.settle(state)
        val existing = if (command is HighSchoolPhase4Command.StartSeedChallenge) SeedChallengeRules.checkpoint(base, command) else base.highSchool
        val isStart = ProRetirementLedger.isHighSchoolStart(command)
        if (existing == null && !isStart) throw GameCommandException("game.highSchool.start_required")
        if (existing != null && isStart) throw GameCommandException("game.highSchool.start_duplicate")
        val nested = HighSchoolPhase4CommandStore(initialState = existing).dispatch(
            HighSchoolPhase4CommandEnvelope(
                commandId = envelope.commandId,
                sessionId = envelope.sessionId,
                expectedRevision = existing?.revision ?: 0UL,
                command = ProRetirementLedger.prepareInitialCommand(base, command),
            ),
        )
        val next = if (isStart) ProRetirementLedger.attachInitialWallet(nested.state, base.meta.standaloneSoulBalance) else nested.state
        val nextMeta = base.meta.copy(
            standaloneSoulBalance = if (isStart) 0 else base.meta.standaloneSoulBalance,
            completedGameCount = GameCompletionRules.afterHighSchool(base, next),
            activeHighSchoolCareerId = next.run.careerId,
            lifeArchiveCareerIds = next.archive.map { it.careerId },
        )
        val nextStage = when {
            base.pro != null && base.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY) &&
                (command is HighSchoolPhase4Command.PrepareReturnPlan || command is HighSchoolPhase4Command.SaveReturnPlan || command == HighSchoolPhase4Command.DismissReturnPlan) -> base.stage
            next.run.phase == com.solkim.baseball.core.highschool.HighSchoolPhase.COMPLETED && (base.pro == null || base.pro.phase == ProCareerPhase.COMPLETED) -> GameStage.BETWEEN_LIVES
            else -> GameStage.HIGH_SCHOOL
        }
        return SeedChallengeRules.finish(base, command, base.copy(highSchool = next, meta = nextMeta, stage = nextStage)) to "highSchool.${commandName(command)}"
    }

    private fun reducePro(state: GameAggregateState, envelope: GameCommandEnvelope, command: ProCommand): Pair<GameAggregateState, String> {
        require(state.highSchool?.challenge?.active != true) { "challenge.pro_locked" }
        val settled = ProRetirementLedger.settle(state)
        val isStart = command is ProCommand.StartLinked || command is ProCommand.StartDirect
        val restarting = isStart && settled.pro?.phase == ProCareerPhase.COMPLETED
        if (restarting) require(settled.pitch == null || settled.pitch.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) { "pro.restart_active_pitch" }
        val base = if (restarting) settled.copy(pro = null, pitch = null) else settled
        val existing = base.pro
        if (existing == null && !isStart) throw GameCommandException("game.pro.start_required")
        if (existing != null && isStart) throw GameCommandException("game.pro.start_duplicate")
        val nested = ProCommandStore(initialState = existing).dispatch(
            ProCommandEnvelope(
                commandId = envelope.commandId,
                sessionId = envelope.sessionId,
                expectedRevision = existing?.revision ?: 0UL,
                command = command,
            ),
        )
        val next = nested.state
        val nextStage = when (next.phase) {
            ProCareerPhase.RETIREMENT_DECISION -> GameStage.RETIREMENT
            ProCareerPhase.LEGACY_SELECTION -> GameStage.LEGACY
            ProCareerPhase.COMPLETED -> GameStage.BETWEEN_LIVES
            else -> GameStage.PRO
        }
        return ProRetirementLedger.settle(base.copy(
            pro = next,
            stage = nextStage,
            meta = base.meta.copy(activeHighSchoolCareerId = next.sourceHighSchoolCareerId ?: base.meta.activeHighSchoolCareerId),
        )) to "pro.${commandName(command)}"
    }

    private fun enterSetup(state: GameAggregateState): Pair<GameAggregateState, String> {
        val settled = ProRetirementLedger.settle(state)
        require(settled.canEnterPlayerSetup()) { "setup.active_career" }
        return settled.copy(stage = GameStage.SETUP) to "setup.opened"
    }

    private fun resetProgress(state: GameAggregateState): Pair<GameAggregateState, String> =
        GameAggregateState.initial(state.installId) to "game.reset"

    private fun recordAnalytics(state: GameAggregateState, command: GameCommand.RecordAnalytics): Pair<GameAggregateState, String> {
        require(!state.analytics.contains(command.receiptId)) { "analytics.receipt_duplicate" }
        AnalyticsContract.validateManual(command.eventName, command.properties)
        if (command.eventName.startsWith("review_moment_")) {
            require(state.highSchool?.challenge?.active != true) { "analytics.challenge_suppressed" }
            val run = state.highSchool?.run ?: throw GameCommandException("analytics.review_career_missing")
            val expectedReceipt = when (command.eventName) {
                "review_moment_drafted_reveal_confirmed" -> {
                    require(run.draftResult?.outcome == com.solkim.baseball.core.highschool.HighSchoolDraftOutcome.DRAFTED) { "analytics.review_draft_not_ready" }
                    "review-moment:${run.careerId}:drafted-reveal-confirmed"
                }
                "review_moment_good_recap" -> {
                    require(ScreenProjection.recapDeservesReview(state)) { "analytics.review_recap_not_ready" }
                    "review-moment:${run.careerId}:good-recap"
                }
                else -> throw GameCommandException("analytics.review_event_unknown")
            }
            require(command.receiptId == expectedReceipt) { "analytics.review_receipt_scope" }
        }
        if (command.eventName in AnalyticsContract.nonRetiredEvents) {
            require(state.highSchool?.challenge?.active != true) { "analytics.challenge_suppressed" }
        }
        return state to "analytics.recorded"
    }

    private fun updateSettings(state: GameAggregateState, command: GameCommand.UpdateSettings): Pair<GameAggregateState, String> =
        state.copy(settings = command.settings) to "settings.updated"

    private fun commit(
        previousState: GameAggregateState,
        reducedState: GameAggregateState,
        envelope: GameCommandEnvelope,
        commandHash: String,
        eventName: String,
    ): GameDispatchResult {
        if (envelope.command is GameCommand.ResetProgress) {
            return commitFreshWipe(previousState, envelope, commandHash, eventName)
        }
        val nextRevision = reducedState.revision + 1UL
        val resultHash = GameCommandCodec.resultHash(previousState, envelope, eventName)
        val receipt = GameCommandReceipt(envelope.commandId, envelope.sessionId, envelope.expectedRevision, nextRevision, commandHash, resultHash, eventName)
        val analyticsReceipt = when (val command = envelope.command) {
            is GameCommand.RecordAnalytics -> AnalyticsReceipt(command.receiptId, command.eventName, nextRevision, previousState.commitment, command.properties)
            else -> AnalyticsReceipt("command:${envelope.commandId}", eventName, nextRevision, previousState.commitment)
        }
        val base = reducedState.copy(
            meta = reducedState.meta.copy(abilityHistory = AbilityHistory.transition(previousState, reducedState, envelope.commandId), album = PlayerAlbum.capture(previousState, reducedState), playerGrowth = PlayerGrowthReceipt.transition(previousState, reducedState, envelope.commandId), companion = PitcherCompanionRules.transition(previousState, reducedState)),
            revision = nextRevision,
            commandReceipts = reducedState.commandReceipts + receipt,
            analytics = reducedState.analytics.copy(receipts = reducedState.analytics.receipts + analyticsReceipt),
        ).committed()
        // Matrix transitions are derived before the repository save.  The aggregate therefore
        // owns the handoff even if the native SDK, observer, or process dies immediately after
        // read-back verification.
        val projected = AnalyticsProjector.project(previousState, base, envelope)
        val committed = base.copy(
            analytics = base.analytics.copy(receipts = base.analytics.receipts + projected),
        ).committed()
        committed.validate()
        return GameDispatchResult(committed, resultHash, duplicate = false)
    }

    /** Progress wipe starts a new legal receipt chain whose first receipt is this reset. */
    private fun commitFreshWipe(
        previousState: GameAggregateState,
        envelope: GameCommandEnvelope,
        commandHash: String,
        eventName: String,
    ): GameDispatchResult {
        val nextRevision = 1UL
        val resultHash = GameCommandCodec.resultHash(previousState, envelope, eventName)
        val receipt = GameCommandReceipt(
            envelope.commandId,
            envelope.sessionId,
            expectedRevision = 0UL,
            committedRevision = nextRevision,
            commandHash,
            resultHash,
            eventName,
        )
        val analyticsReceipt = AnalyticsReceipt("command:${envelope.commandId}", eventName, nextRevision, previousState.commitment)
        val wiped = GameAggregateState.initial(previousState.installId).copy(
            revision = nextRevision,
            commandReceipts = listOf(receipt),
            analytics = AnalyticsReceiptState(listOf(analyticsReceipt)),
        ).committed()
        val projected = AnalyticsProjector.project(previousState, wiped, envelope)
        val committed = wiped.copy(
            analytics = wiped.analytics.copy(receipts = wiped.analytics.receipts + projected),
        ).committed()
        committed.validate()
        return GameDispatchResult(committed, resultHash, duplicate = false)
    }

    private fun commandName(command: Any): String = command.javaClass.simpleName.replace('$', '.').replace("Command", "").replaceFirstChar { it.lowercase() }
}

