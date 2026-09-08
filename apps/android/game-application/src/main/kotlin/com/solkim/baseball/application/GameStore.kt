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

/**
 * The application-facing repository boundary. File work is deliberately hidden behind
 * suspending methods so the GameStore never performs persistence on a caller/UI thread.
 */
public interface GameStoreRepository {
    public suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState>
    public suspend fun load(): SaveLoadResult<GameAggregateState>
    public suspend fun reset()
}

/**
 * Explicit Phase 7 fixture boundary. It is process-local and never resolves to the production
 * package/save directory. The store still reports [NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY]
 * so a production composition cannot accidentally turn this vertical into a cutover.
 */
public interface ShadowFixtureGameStoreRepository : GameStoreRepository

/** Only explicit progress deletion may begin a new receipt/revision chain. */
public interface FreshProgressGameStoreRepository : GameStoreRepository {
    public suspend fun saveFreshProgress(value: GameAggregateState): SaveWriteResult<GameAggregateState>
}

public class InMemoryShadowFixtureGameStoreRepository(
    initial: GameAggregateState,
) : ShadowFixtureGameStoreRepository {
    private var current: GameAggregateState = initial
    private val shadowPath = java.nio.file.Paths.get("shadow-fixture", "save.json")

    override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> {
        require(revision == value.revision) { "shadow_fixture.revision" }
        current = value
        val payloadTree = GameAggregateCodec.encodePayload(value)
        val envelope = SaveEnvelope(
            schema = "android-unity-save-v1",
            schemaVersion = 1,
            revision = revision,
            writtenAtUtc = "1970-01-01T00:00:00.000Z",
            payloadSha256 = payloadTree.canonicalSha256(),
            payload = value,
            payloadTree = payloadTree,
        )
        return SaveWriteResult(envelope, shadowPath)
    }

    override suspend fun load(): SaveLoadResult<GameAggregateState> {
        val payloadTree = GameAggregateCodec.encodePayload(current)
        val envelope = SaveEnvelope(
            schema = "android-unity-save-v1",
            schemaVersion = 1,
            revision = current.revision,
            writtenAtUtc = "1970-01-01T00:00:00.000Z",
            payloadSha256 = payloadTree.canonicalSha256(),
            payload = current,
            payloadTree = payloadTree,
        )
        return SaveLoadResult(SaveLoadStatus.LOADED_CANONICAL, envelope, shadowPath)
    }

    override suspend fun reset() {
        current = GameAggregateState.initial(current.installId)
    }
}

/**
 * Debug/emulator-only durable fixture repository. Its directory is supplied by the Compose
 * shadow application and is never the legacy Unity persistentDataPath or a production package
 * save location. Keeping this boundary on the marker interface lets process-kill tests restore
 * the same aggregate while the public authority mode remains nativeShadowReadOnly.
 */
public class FileShadowFixtureGameStoreRepository(
    public val directory: java.nio.file.Path,
    clock: com.solkim.baseball.persistence.SaveClock = com.solkim.baseball.persistence.SystemSaveClock,
    private val resetSideEffects: ResetSideEffects = NoResetSideEffects,
    faults: com.solkim.baseball.persistence.SaveFaultInjector = com.solkim.baseball.persistence.SaveFaultInjector.NONE,
) : ShadowFixtureGameStoreRepository, FreshProgressGameStoreRepository {
    private val delegate = com.solkim.baseball.persistence.AtomicJsonRepository(
        layout = com.solkim.baseball.persistence.SaveFileLayout(directory),
        codec = GameAggregateCodec,
        clock = clock,
        faults = faults,
    )
    // Persist the fresh state outside the files being cleared, before touching the old save.
    private val resetIntent = com.solkim.baseball.persistence.AtomicJsonRepository(
        layout = com.solkim.baseball.persistence.SaveFileLayout(directory.resolve("progress-reset")),
        codec = GameAggregateCodec,
        clock = clock,
    )

    override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> =
        withContext(Dispatchers.IO) { finishPendingReset(); delegate.save(value, revision) }

    override suspend fun load(): SaveLoadResult<GameAggregateState> =
        withContext(Dispatchers.IO) { finishPendingReset(); delegate.load() }

    override suspend fun saveFreshProgress(value: GameAggregateState): SaveWriteResult<GameAggregateState> = withContext(Dispatchers.IO) {
        finishPendingReset()
        validateFreshProgress(value)
        resetIntent.save(value, value.revision)
        requireNotNull(finishPendingReset())
    }

    private fun validateFreshProgress(value: GameAggregateState) {
        value.validate()
        require(value.revision == 1UL && value.stage == GameStage.OPENING && value.highSchool == null && value.pro == null && value.pitch == null &&
            value.commandReceipts.singleOrNull()?.eventName == "game.reset") { "reset.intent_invalid" }
    }

    private fun finishPendingReset(): SaveWriteResult<GameAggregateState>? {
        val pending = resetIntent.load()
        if (pending.status == SaveLoadStatus.NO_SAVE) return null
        require(pending.status in setOf(SaveLoadStatus.LOADED_CANONICAL, SaveLoadStatus.RECOVERED_BACKUP)) { "reset.intent_unavailable" }
        val fresh = requireNotNull(pending.envelope).payload
        validateFreshProgress(fresh)
        delegate.reset()
        val written = delegate.save(fresh, fresh.revision)
        resetSideEffects.clearAnalytics()
        resetSideEffects.clearReview()
        resetSideEffects.clearReminders()
        resetSideEffects.clearScopedEpoch()
        resetSideEffects.clearShareCache()
        resetIntent.reset()
        return written
    }

    override suspend fun reset(): Unit = withContext(Dispatchers.IO) { delegate.reset(); resetIntent.reset() }
}

public class IoGameStoreRepository(
    private val delegate: KotlinSaveRepository<GameAggregateState>,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) : GameStoreRepository {
    override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> =
        withContext(ioDispatcher) { delegate.save(value, revision) }

    override suspend fun load(): SaveLoadResult<GameAggregateState> =
        withContext(ioDispatcher) { delegate.load() }

    override suspend fun reset(): Unit = withContext(ioDispatcher) { delegate.reset() }
}

public data class ReconcileResult(
    public val reconciled: Boolean,
    public val previousRevision: ULong,
    public val persistedRevision: ULong,
    public val state: GameAggregateState,
)

/** The single asynchronous aggregate authority used by the Compose application scope. */
public interface GameStore {
    public val state: StateFlow<GameSaveAggregate>
    public val busy: StateFlow<Boolean>

    public suspend fun dispatch(envelope: CommandEnvelope<GameCommand>): DispatchResult

    public suspend fun dispatchBatch(envelopes: List<GameCommandEnvelope>): List<GameDispatchResult> =
        envelopes.map { dispatch(it) }

    public suspend fun reconcilePersistedRevision(): ReconcileResult
}

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
                is GameCommand.ReservePitch -> reservePitch(state, command)
                is GameCommand.StartPitch -> startPitch(state, command)
                is GameCommand.CommitPitch -> commitPitch(state, command)
                is GameCommand.ConsumePitch -> consumePitch(state, command)
                is GameCommand.MarkPitchTerminal -> terminalPitch(state, command)
                is GameCommand.CompletePitch -> completePitch(state, command)
                is GameCommand.SuspendPitch -> suspendPitch(state, command)
                is GameCommand.ResumePitch -> resumePitch(state, command)
                is GameCommand.AbandonPitch -> abandonPitch(state, command)
                is GameCommand.ClearPitchPresentation -> clearPitchPresentation(state, command)
                is GameCommand.UpdateCompanion -> state.copy(meta = state.meta.copy(companion = PitcherCompanionRules.apply(state, command.operation, command.value))) to "companion.updated"
                is GameCommand.UpdateSettings -> updateSettings(state, command)
                is GameCommand.SetPitchHoldCall -> setPitchHoldCall(state, command)
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

    private fun reservePitch(state: GameAggregateState, command: GameCommand.ReservePitch): Pair<GameAggregateState, String> {
        require(state.pitch == null || state.pitch.boundary == PitchBoundary.COMPLETED || state.pitch.boundary == PitchBoundary.ABANDONED) { "pitch.reserve_active" }
        require(!state.deleted) { "pitch.reserve_deleted" }
        when (command.careerKind) {
            PitchCareerKind.HIGH_SCHOOL -> {
                val highSchool = state.highSchool
                require(highSchool != null && highSchool.run.careerId == command.careerId) { "pitch.reserve_highSchool_career" }
                require(highSchool.run.phase != com.solkim.baseball.core.highschool.HighSchoolPhase.COMPLETED) { "pitch.reserve_highSchool_inactive" }
            }
            PitchCareerKind.PRO -> {
                val pro = state.pro
                require(pro != null && pro.careerId == command.careerId) { "pitch.reserve_pro_career" }
                require(pro.phase != ProCareerPhase.COMPLETED) { "pitch.reserve_pro_inactive" }
            }
            PitchCareerKind.TUTORIAL -> state.requireActiveTutorialPitch(
                careerId = command.careerId,
                boundary = PitchBoundary.RESERVED,
                challengeRun = command.challengeRun,
                errorPrefix = "pitch.reserve_tutorial",
            )
        }
        val next = PitchDurableState(command.sessionId, command.careerKind, command.careerId, command.gameId, command.seed, PitchBoundary.RESERVED, challengeRun = command.challengeRun)
        return state.copy(pitch = next) to "pitch.reserved"
    }

    private fun enterSetup(state: GameAggregateState): Pair<GameAggregateState, String> {
        val settled = ProRetirementLedger.settle(state)
        require(settled.canEnterPlayerSetup()) { "setup.active_career" }
        return settled.copy(stage = GameStage.SETUP) to "setup.opened"
    }

    private fun resetProgress(state: GameAggregateState): Pair<GameAggregateState, String> =
        GameAggregateState.initial(state.installId) to "game.reset"

    private fun startPitch(state: GameAggregateState, command: GameCommand.StartPitch): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.RESERVED) { "pitch.start_boundary" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.PLAYING)) to "pitch.playing"
    }

    private fun commitPitch(state: GameAggregateState, command: GameCommand.CommitPitch): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.PLAYING) { "pitch.commit_boundary" }
        require(command.pitchId.isNotBlank() && command.resultHash.isNotBlank()) { "pitch.commit_payload" }
        require(command.pitchId !in pitch.committedPitchIds) { "pitch.commit_duplicate" }
        val next = pitch.copy(
            boundary = PitchBoundary.COMMITTED,
            pitchIndex = pitch.pitchIndex + 1,
            committedPitchIds = pitch.committedPitchIds + command.pitchId,
            resultHashes = pitch.resultHashes + command.resultHash,
            checkpoint = command.checkpoint ?: pitch.checkpoint,
        )
        return state.copy(pitch = next) to "pitch.committed"
    }

    private fun consumePitch(state: GameAggregateState, command: GameCommand.ConsumePitch): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.COMMITTED) { "pitch.consume_boundary" }
        require(command.pitchId in pitch.committedPitchIds && command.pitchId !in pitch.consumedPitchIds) { "pitch.consume_payload" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.CONSUMED, consumedPitchIds = pitch.consumedPitchIds + command.pitchId)) to "pitch.consumed"
    }

    private fun terminalPitch(state: GameAggregateState, command: GameCommand.MarkPitchTerminal): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.CONSUMED) { "pitch.terminal_boundary" }
        require(command.pitchId in pitch.consumedPitchIds && command.terminalHash.isNotBlank()) { "pitch.terminal_payload" }
        val resultHashes = pitch.resultHashes.toMutableList()
        resultHashes[pitch.consumedPitchIds.indexOf(command.pitchId)] = command.terminalHash
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.TERMINAL, terminalPitchId = command.pitchId, resultHashes = resultHashes)) to "pitch.terminal"
    }

    private fun completePitch(state: GameAggregateState, command: GameCommand.CompletePitch): Pair<GameAggregateState, String> =
        GameCompletionRules.completePitch(state, command.sessionId) to "pitch.completed"

    private fun suspendPitch(state: GameAggregateState, command: GameCommand.SuspendPitch): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.COMMITTED, PitchBoundary.CONSUMED)) { "pitch.suspend_boundary" }
        require(command.checkpoint.isNotBlank()) { "pitch.suspend_checkpoint" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.SUSPENDED, checkpoint = command.checkpoint, suspendedFrom = pitch.boundary)) to "pitch.suspended"
    }

    private fun resumePitch(state: GameAggregateState, command: GameCommand.ResumePitch): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.SUSPENDED && pitch.suspendedFrom != null) { "pitch.resume_boundary" }
        return state.copy(pitch = pitch.copy(boundary = pitch.suspendedFrom, suspendedFrom = null)) to "pitch.resumed"
    }

    private fun abandonPitch(state: GameAggregateState, command: GameCommand.AbandonPitch): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)) { "pitch.abandon_boundary" }
        require(command.reason.isNotBlank()) { "pitch.abandon_reason" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.ABANDONED, abandonedReason = command.reason)) to "pitch.abandoned"
    }

    private fun clearPitchPresentation(state: GameAggregateState, command: GameCommand.ClearPitchPresentation): Pair<GameAggregateState, String> {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.COMPLETED || pitch.boundary == PitchBoundary.ABANDONED) {
            "pitch.clear_boundary"
        }
        return when (pitch.careerKind) {
            PitchCareerKind.PRO -> {
                val pro = state.pro
                if (pro != null && (pro.lastPresentation != null || pro.lastBattedBall != null || pro.lastFielding != null)) {
                    val cleared = pro.copy(
                        lastPresentation = null,
                        lastBattedBall = null,
                        lastFielding = null,
                        commitment = "",
                    )
                    val resigned = cleared.copy(commitment = com.solkim.baseball.core.pro.ProKernel().commitment(cleared))
                    state.copy(pro = resigned) to "pitch.presentation_cleared"
                } else {
                    state to "pitch.presentation_already_clear"
                }
            }
            PitchCareerKind.HIGH_SCHOOL, PitchCareerKind.TUTORIAL -> {
                val highSchool = state.highSchool
                if (highSchool?.lastPresentation != null) {
                    val resigned = com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel()
                        .commitShadowState(highSchool.copy(lastPresentation = null))
                    state.copy(highSchool = resigned) to "pitch.presentation_cleared"
                } else {
                    state to "pitch.presentation_already_clear"
                }
            }
        }
    }

    private fun recordAnalytics(state: GameAggregateState, command: GameCommand.RecordAnalytics): Pair<GameAggregateState, String> {
        require(!state.analytics.contains(command.receiptId)) { "analytics.receipt_duplicate" }
        Phase9AnalyticsContract.validateManual(command.eventName, command.properties)
        if (command.eventName.startsWith("review_moment_")) {
            require(state.highSchool?.challenge?.active != true) { "analytics.challenge_suppressed" }
            val run = state.highSchool?.run ?: throw GameCommandException("analytics.review_career_missing")
            val expectedReceipt = when (command.eventName) {
                "review_moment_drafted_reveal_confirmed" -> {
                    require(run.draftResult?.outcome == com.solkim.baseball.core.highschool.HighSchoolDraftOutcome.DRAFTED) { "analytics.review_draft_not_ready" }
                    "review-moment:${run.careerId}:drafted-reveal-confirmed"
                }
                "review_moment_good_recap" -> {
                    require(Phase8ScreenProjection.recapDeservesReview(state)) { "analytics.review_recap_not_ready" }
                    "review-moment:${run.careerId}:good-recap"
                }
                else -> throw GameCommandException("analytics.review_event_unknown")
            }
            require(command.receiptId == expectedReceipt) { "analytics.review_receipt_scope" }
        }
        if (command.eventName in Phase9AnalyticsContract.nonRetiredEvents) {
            require(state.highSchool?.challenge?.active != true) { "analytics.challenge_suppressed" }
        }
        return state to "analytics.recorded"
    }

    private fun updateSettings(state: GameAggregateState, command: GameCommand.UpdateSettings): Pair<GameAggregateState, String> =
        state.copy(settings = command.settings) to "settings.updated"

    private fun setPitchHoldCall(state: GameAggregateState, command: GameCommand.SetPitchHoldCall): Pair<GameAggregateState, String> {
        val pitch = state.pitch ?: throw GameCommandException("pitch.hold_call_missing")
        require(pitch.sessionId == command.sessionId) { "pitch.hold_call_session" }
        if (pitch.holdCall == command.holdCall) return state to "pitch.hold_call"
        return state.copy(pitch = pitch.copy(holdCall = command.holdCall)) to "pitch.hold_call"
    }

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
            meta = reducedState.meta.copy(album = PlayerAlbum.capture(previousState, reducedState), playerGrowth = PlayerGrowthReceipt.transition(previousState, reducedState, envelope.commandId), companion = PitcherCompanionRules.transition(previousState, reducedState)),
            revision = nextRevision,
            commandReceipts = reducedState.commandReceipts + receipt,
            analytics = reducedState.analytics.copy(receipts = reducedState.analytics.receipts + analyticsReceipt),
        ).committed()
        // Matrix transitions are derived before the repository save.  The aggregate therefore
        // owns the handoff even if the native SDK, observer, or process dies immediately after
        // read-back verification.
        val projected = Phase9AnalyticsProjector.project(previousState, base, envelope)
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
        val projected = Phase9AnalyticsProjector.project(previousState, wiped, envelope)
        val committed = wiped.copy(
            analytics = wiped.analytics.copy(receipts = wiped.analytics.receipts + projected),
        ).committed()
        committed.validate()
        return GameDispatchResult(committed, resultHash, duplicate = false)
    }

    private fun requirePitch(state: GameAggregateState, sessionId: String): PitchDurableState {
        val pitch = state.pitch ?: throw GameCommandException("pitch.missing")
        require(pitch.sessionId == sessionId) { "pitch.session_mismatch" }
        return pitch
    }

    private fun commandName(command: Any): String = command.javaClass.simpleName.replace('$', '.').replace("Command", "").replaceFirstChar { it.lowercase() }
}

public fun interface AnalyticsReceiptSink {
    public fun publish(receipts: List<AnalyticsReceipt>)
}

public class AnalyticsReceiptProjection(
    private val sink: AnalyticsReceiptSink,
    private val durableReceiptIds: (() -> Set<String>)? = null,
    private val establishDurableBaseline: ((Collection<String>) -> Unit)? = null,
) {
    private val published = linkedSetOf<String>()
    private val baseline = linkedSetOf<String>()
    private val pendingAfterSave = linkedSetOf<String>()
    private var baselineEstablished: Boolean = false

    /** Marks receipts already durable before this process attached; they are never replayed. */
    @Synchronized
    public fun establishBaseline(state: GameAggregateState) {
        ensureBaseline(state)
    }

    /**
     * A platform-state write failure is not permission to treat the current aggregate as a new
     * stream. Keep the baseline closed until the native ledger has acknowledged it; only receipts
     * observed in a verified before→after save are allowed through while that boundary is down.
     */
    @Synchronized
    private fun ensureBaseline(state: GameAggregateState): Boolean {
        if (baselineEstablished) {
            refreshDurableBaseline(state)
            return true
        }
        if (!baselineEstablished) {
            val beforeBaseline = runCatching { durableReceiptIds?.invoke() }.getOrNull()
            val historicIds = state.analytics.receipts.map { it.receiptId }.filterNot(pendingAfterSave::contains)
            // The native platform ledger records the boundary exactly once. If that write or its
            // read-back fails, leave the boundary unopened so historic receipts cannot be replayed
            // merely because this process restarted.
            val boundaryWritten = if (establishDurableBaseline == null) {
                true
            } else {
                runCatching {
                    requireNotNull(establishDurableBaseline).invoke(historicIds)
                    requireNotNull(durableReceiptIds?.invoke()) { "analytics.baseline_read" }
                }.isSuccess
            }
            if (!boundaryWritten) return false
            val durable = runCatching { durableReceiptIds?.invoke() }.getOrNull()
                ?: beforeBaseline
                ?: if (establishDurableBaseline != null) return false else null
            baseline += state.analytics.receipts
                .filter { it.receiptId !in pendingAfterSave && (durable == null || it.receiptId in durable) }
                .map { it.receiptId }
            published += baseline
            baselineEstablished = true
            return true
        }
        return false
    }

    private fun refreshDurableBaseline(state: GameAggregateState) {
        val durable = runCatching { durableReceiptIds?.invoke() }.getOrNull() ?: return
        val newlyHandedOff = state.analytics.receipts
            .filter { it.receiptId in durable }
            .map { it.receiptId }
        baseline += newlyHandedOff
        published += newlyHandedOff
    }

    /**
     * Projects only the durable before→after delta, plus an earlier failed enqueue that is still
     * retryable. Sink/SDK failure is intentionally swallowed after the save has been verified;
     * failed receipt IDs remain absent from [published] and are retried by a later call.
     */
    @Synchronized
    public fun publishAfterSave(before: GameAggregateState, after: GameAggregateState) {
        runCatching {
            val beforeIds = before.analytics.receipts.map { it.receiptId }.toSet()
            val newDurable = after.analytics.receipts.filter { it.receiptId !in beforeIds }
            pendingAfterSave += newDurable.map { it.receiptId }
            val baselineReady = ensureBaseline(before)
            // A missing platform baseline must not replay old receipts. New receipts are still
            // handed off after the aggregate save and remain in pendingAfterSave on failure.
            refreshDurableBaseline(after)
            val retryable = if (baselineReady) {
                after.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in newDurable.map(AnalyticsReceipt::receiptId).toSet() }
            } else {
                emptyList()
            }
            enqueue(newDurable + retryable)
        }
    }

    /** Explicit in-process retry hook for a receipt whose observer enqueue failed. */
    @Synchronized
    public fun retryPending(state: GameAggregateState) {
        runCatching {
            if (!ensureBaseline(state)) return@runCatching
            refreshDurableBaseline(state)
            enqueue(state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published })
        }
    }

    @Synchronized
    public fun pending(state: GameAggregateState): List<AnalyticsReceipt> {
        return try {
            if (!ensureBaseline(state)) return state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published }
            refreshDurableBaseline(state)
            state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published }
        } catch (_: Throwable) {
            // A failed durable-ledger read is itself a retryable handoff failure. Never report a
            // historic receipt as new merely because the observer could not be inspected.
            state.analytics.receipts.filter { it.receiptId in pendingAfterSave && it.receiptId !in published }
        }
    }

    private fun enqueue(receipts: List<AnalyticsReceipt>) {
        val unique = receipts.distinctBy { it.receiptId }.filter { it.receiptId !in published }
        if (unique.isEmpty()) return
        try {
            sink.publish(unique)
            published += unique.map { it.receiptId }
            pendingAfterSave.removeAll(unique.map(AnalyticsReceipt::receiptId).toSet())
        } catch (_: Throwable) {
            // A verified save has already committed. Leave IDs unacknowledged for retry.
        }
    }
}

public class KotlinGameStore private constructor(
    initial: GameAggregateState,
    private val repository: GameStoreRepository?,
    public val authorityMode: NativeAuthorityMode,
    private val analyticsProjection: AnalyticsReceiptProjection? = null,
    private val allowShadowFixtureWrites: Boolean = false,
) : GameStore {
    private val closed = AtomicBoolean(false)
    private val mutex = Mutex()
    private val _state = MutableStateFlow(initial)
    private val _busy = MutableStateFlow(false)
    private var pendingFreshProgressCommandId: String? = null

    override val state: StateFlow<GameAggregateState> = _state.asStateFlow()
    override val busy: StateFlow<Boolean> = _busy.asStateFlow()
    public val current: GameAggregateState get() = state.value

    public val supportsCareerBackup: Boolean get() = repository is CSharpLegacyGameStoreRepository

    public suspend fun exportCareerBackup(): ByteArray = mutex.withLock {
        check(!closed.get()) { "game.store.closed" }
        require(CareerBackup.isAvailable(current)) { "backup.challenge_active" }
        requireNotNull(repository as? CSharpLegacyGameStoreRepository).exportCareer()
    }

    public suspend fun importCareerBackup(bytes: ByteArray, expectedRevision: ULong): Unit = mutex.withLock {
        check(!closed.get()) { "game.store.closed" }
        require(CareerBackup.isAvailable(current)) { "backup.challenge_active" }
        require(current.revision == expectedRevision) { "backup.stale_revision" }
        _busy.value = true
        try {
            withContext(kotlinx.coroutines.NonCancellable) {
                val restored = requireNotNull(repository as? CSharpLegacyGameStoreRepository).importCareer(bytes, expectedRevision)
                _state.value = restored
                analyticsProjection?.establishBaseline(restored)
            }
        } finally { _busy.value = false }
    }

    init {
        analyticsProjection?.establishBaseline(initial)
        // Reconcile only receipts that were not durably handed to the native boundary.  A
        // process-local baseline is retained for legacy test sinks, while the app composition
        // supplies the native outbox/once ledger through [durableReceiptIds].
        analyticsProjection?.retryPending(initial)
    }

    override suspend fun dispatch(envelope: GameCommandEnvelope): GameDispatchResult = mutex.withLock {
        withContext(kotlinx.coroutines.NonCancellable) { dispatchLocked(envelope) }
    }

    override suspend fun dispatchBatch(envelopes: List<GameCommandEnvelope>): List<GameDispatchResult> = mutex.withLock {
        withContext(kotlinx.coroutines.NonCancellable) {
            envelopes.map { dispatchLocked(it) }
        }
    }

    // Once a file write begins, publication must finish even if its Activity is destroyed.
    // Cancellation may stop a caller waiting for the mutex, but cannot split this commit.
    private suspend fun dispatchLocked(envelope: GameCommandEnvelope): GameDispatchResult {
        ensureOpen()
        _busy.value = true
        try {
            val before = state.value
            check(pendingFreshProgressCommandId == null || envelope.command == GameCommand.ResetProgress) { "game.store.reset_pending" }
            val nativeLegacyRepository = repository as? NativeAuthoritativeGameStoreRepository
            val reduced = nativeLegacyRepository?.dispatchLegacy(before, envelope)
                ?: GameStateReducer.dispatch(before, envelope)
            if (reduced.duplicate) return reduced
            if (nativeLegacyRepository == null && authorityMode != NativeAuthorityMode.NATIVE_AUTHORITATIVE && !allowShadowFixtureWrites) {
                throw SaveRepositoryException(com.solkim.baseball.persistence.SaveFailureCode.WRITE_DISABLED, "nativeShadowReadOnly.save_disabled")
            }
            if (nativeLegacyRepository == null) {
                val save = repository ?: throw IllegalStateException("game.store.repository_missing")
                if (envelope.command == GameCommand.ResetProgress && save is FreshProgressGameStoreRepository) {
                    pendingFreshProgressCommandId = envelope.commandId
                    save.saveFreshProgress(reduced.state)
                } else save.save(reduced.state, reduced.state.revision)
            }
            // StateFlow publication is after verified read-back and before observer/SDK work.
            _state.value = reduced.state
            pendingFreshProgressCommandId = null
            analyticsProjection?.publishAfterSave(before, reduced.state)
            return reduced
        } finally {
            _busy.value = false
        }
    }

    override suspend fun reconcilePersistedRevision(): ReconcileResult = mutex.withLock {
        ensureOpen()
        _busy.value = true
        try {
            val before = state.value
            val load = repository?.load()
            if (load == null || load.status == SaveLoadStatus.NO_SAVE) {
                return@withLock ReconcileResult(false, before.revision, before.revision, before)
            }
            if (load.status != SaveLoadStatus.LOADED_CANONICAL && load.status != SaveLoadStatus.RECOVERED_BACKUP) {
                throw IllegalStateException("game.store.reconcile_unsupported:${load.status}")
            }
            val candidate = requireNotNull(load.envelope).payload
            require(candidate.installId == before.installId) { "game.store.reconcile_install" }
            val confirmedFreshProgress = repository is FreshProgressGameStoreRepository && pendingFreshProgressCommandId != null &&
                candidate.commandReceipts.singleOrNull()?.let { it.commandId == pendingFreshProgressCommandId && it.eventName == "game.reset" } == true &&
                candidate.revision == 1UL && candidate.stage == GameStage.OPENING && candidate.highSchool == null && candidate.pro == null && candidate.pitch == null
            require(candidate.revision >= before.revision || confirmedFreshProgress) { "game.store.reconcile_rollback" }
            if (candidate.revision == before.revision && !confirmedFreshProgress) {
                pendingFreshProgressCommandId = null
                return@withLock ReconcileResult(false, before.revision, candidate.revision, before)
            }
            if (repository !is NativeAuthoritativeGameStoreRepository) candidate.validate()
            _state.value = candidate
            pendingFreshProgressCommandId = null
            analyticsProjection?.publishAfterSave(before, candidate)
            ReconcileResult(true, before.revision, candidate.revision, candidate)
        } finally {
            _busy.value = false
        }
    }

    /** Compatibility alias for callers that already used the old name; it remains suspending. */
    public suspend fun reconcile(): Boolean = reconcilePersistedRevision().reconciled

    /**
     * Retries the post-save analytics handoff without dispatching a game command.  The aggregate
     * is already durable at this point; this hook is deliberately separate so an SDK/file
     * observer failure can never turn into a second command or a lost in-process receipt.
     */
    public fun retryAnalyticsHandoff() {
        analyticsProjection?.retryPending(current)
    }

    /** True when the native/observer handoff still needs an in-process retry. */
    public fun analyticsHandoffPending(receiptId: String): Boolean =
        analyticsProjection?.pending(current)?.any { it.receiptId == receiptId } == true

    public fun close() { closed.set(true) }

    private fun ensureOpen() {
        check(!closed.get()) { "game.store.closed" }
    }

    public companion object {
        public fun fromState(
            state: GameAggregateState,
            repository: KotlinSaveRepository<GameAggregateState>? = null,
            authorityMode: NativeAuthorityMode = NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
            analyticsProjection: AnalyticsReceiptProjection? = null,
            ioRepository: GameStoreRepository? = null,
        ): KotlinGameStore {
            state.validate()
            require(repository == null || ioRepository == null) { "game.store.repository_ambiguous" }
            val boundary = ioRepository ?: repository?.let(::IoGameStoreRepository)
            if (authorityMode == NativeAuthorityMode.NATIVE_AUTHORITATIVE) requireNotNull(boundary) { "game.store.repository_required" }
            return KotlinGameStore(state, boundary, authorityMode, analyticsProjection)
        }

        /**
         * Phase 7 composition only: state advances through a process-local fixture repository.
         * This keeps the public authority mode shadow-read-only and makes a production file write
         * impossible from the Compose vertical until the later cutover gate.
         */
        public fun fromShadowFixture(
            state: GameAggregateState,
            repository: ShadowFixtureGameStoreRepository = InMemoryShadowFixtureGameStoreRepository(state),
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore {
            state.validate()
            return KotlinGameStore(
                initial = state,
                repository = repository,
                authorityMode = NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY,
                analyticsProjection = analyticsProjection,
                allowShadowFixtureWrites = true,
            )
        }

        public suspend fun open(
            installId: String,
            repository: KotlinSaveRepository<GameAggregateState>,
            authorityMode: NativeAuthorityMode,
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore {
            return open(installId, IoGameStoreRepository(repository), authorityMode, analyticsProjection)
        }

        public suspend fun open(
            installId: String,
            repository: GameStoreRepository,
            authorityMode: NativeAuthorityMode,
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore {
            require(installId.isNotBlank()) { "game.store.install" }
            val loaded = repository.load()
            val initial = when (loaded.status) {
                SaveLoadStatus.NO_SAVE -> GameAggregateState.initial(installId)
                SaveLoadStatus.LOADED_CANONICAL, SaveLoadStatus.RECOVERED_BACKUP -> {
                    val payload = requireNotNull(loaded.envelope).payload
                    require(payload.installId == installId) { "game.store.install_mismatch" }
                    if (repository !is NativeAuthoritativeGameStoreRepository) payload.validate()
                    payload
                }
                SaveLoadStatus.FUTURE_VERSION -> throw IllegalStateException("game.store.future_schema")
                SaveLoadStatus.MIGRATION_REQUIRED -> throw IllegalStateException("game.store.migration_required")
                SaveLoadStatus.UNRECOVERABLE_CORRUPTION -> throw IllegalStateException("game.store.unrecoverable")
            }
            return KotlinGameStore(
                initial,
                repository,
                authorityMode,
                analyticsProjection,
                allowShadowFixtureWrites = repository is ShadowFixtureGameStoreRepository,
            )
        }

        /** Test/composition convenience; production callers should open from a coroutine scope. */
        public fun openBlocking(
            installId: String,
            repository: KotlinSaveRepository<GameAggregateState>,
            authorityMode: NativeAuthorityMode,
            analyticsProjection: AnalyticsReceiptProjection? = null,
        ): KotlinGameStore = runBlocking { open(installId, repository, authorityMode, analyticsProjection) }
    }
}
