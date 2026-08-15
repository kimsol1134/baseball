package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind

public object HighSchoolPhase4Wire {
    public const val SCHEMA: String = "baseball-high-school-phase4-command-v1"
    public const val SCHEMA_VERSION: Int = 1
    public const val MAX_COMMAND_ID_LENGTH: Int = 128
}

public object HighSchoolRebirthEntryPath {
    public const val QUICK_REBIRTH: String = "quick_rebirth"
    public const val CUSTOMIZE: String = "customize"
    public const val COMPLETION_FLOW: String = "completion_flow"
    public val values: Set<String> = setOf(QUICK_REBIRTH, CUSTOMIZE, COMPLETION_FLOW)

    public fun requireValid(value: String) {
        require(value in values) { "rebirth.entry_path" }
    }
}

public sealed interface HighSchoolPhase4Command {
    public data class Start(val request: HighSchoolPhase4StartRequest) : HighSchoolPhase4Command
    public data object BeginTutorial : HighSchoolPhase4Command
    public data class CompleteTutorial(val seed: String) : HighSchoolPhase4Command
    public data class ChooseSchool(val seed: String, val schoolId: HighSchoolSchoolId) : HighSchoolPhase4Command
    public data class SelectPledge(val pledgeId: String) : HighSchoolPhase4Command
    public data class Training(
        val seed: String,
        val focus: HighSchoolTrainingFocus,
        val intensity: HighSchoolTrainingIntensity,
        val targetPitch: PitchKind? = null,
    ) : HighSchoolPhase4Command
    public data class TrainingBlock(
        val seed: String,
        val requests: List<Pair<HighSchoolTrainingFocus, HighSchoolTrainingIntensity>>,
    ) : HighSchoolPhase4Command
    public data class Relationship(
        val seed: String,
        val response: HighSchoolRelationshipResponse,
    ) : HighSchoolPhase4Command
    public data class ReserveImportantGame(val seed: String) : HighSchoolPhase4Command
    public data class SubmitPitch(
        val sessionId: String,
        val call: PitchCall,
        val delivery: PitchDelivery = PitchDelivery.NEUTRAL,
    ) : HighSchoolPhase4Command
    public data object FinishImportantGame : HighSchoolPhase4Command
    public data class ChooseAwakening(val seed: String, val awakening: HighSchoolAwakening) : HighSchoolPhase4Command
    public data class AdvanceChapter(val seed: String) : HighSchoolPhase4Command
    public data class ResolveDraft(val seed: String) : HighSchoolPhase4Command
    public data object PrepareLegacy : HighSchoolPhase4Command
    public data class SelectLegacy(val legacyId: String) : HighSchoolPhase4Command
    public data object FinalizeArchive : HighSchoolPhase4Command
    public data class BeginRebirth(
        val seed: String,
        val dayKey: String,
        /** The actual product entry path; old two-field command wires mean completion_flow. */
        val entryPath: String = HighSchoolRebirthEntryPath.COMPLETION_FLOW,
    ) : HighSchoolPhase4Command {
        init { HighSchoolRebirthEntryPath.requireValid(entryPath) }
    }
    public data object StartChallenge : HighSchoolPhase4Command
    public data object EndChallenge : HighSchoolPhase4Command
    public data object ClaimWeeklyReward : HighSchoolPhase4Command
    public data class SaveReturnPlan(val plan: HighSchoolReturnPlan) : HighSchoolPhase4Command
    /** C# Meta's save-backed experiment/receipt preparation command. */
    public data class PrepareReturnPlan(val dayKey: String, val developmentRulesVersion: Int) : HighSchoolPhase4Command
    public data class SaveNextRunIntent(val intent: HighSchoolNextRunIntent) : HighSchoolPhase4Command
    public data object ClearNextRunIntent : HighSchoolPhase4Command
    public data object DismissReturnPlan : HighSchoolPhase4Command
    public data class AcknowledgeAchievement(val achievementId: String) : HighSchoolPhase4Command
}

public data class HighSchoolPhase4CommandEnvelope(
    val schema: String = HighSchoolPhase4Wire.SCHEMA,
    val schemaVersion: Int = HighSchoolPhase4Wire.SCHEMA_VERSION,
    val commandId: String,
    val sessionId: String,
    val expectedRevision: ULong,
    val command: HighSchoolPhase4Command,
) {
    public fun validate() {
        require(schema == HighSchoolPhase4Wire.SCHEMA) { "command.schema" }
        require(schemaVersion == HighSchoolPhase4Wire.SCHEMA_VERSION) { "command.schemaVersion" }
        require(commandId.isNotBlank() && commandId.length <= HighSchoolPhase4Wire.MAX_COMMAND_ID_LENGTH) { "command.commandId" }
        require(sessionId.isNotBlank() && sessionId.length <= HighSchoolPhase4Wire.MAX_COMMAND_ID_LENGTH) { "command.sessionId" }
    }
}

public data class HighSchoolPhase4DispatchResult(
    val state: HighSchoolPhase4State,
    val eventHash: String,
    val duplicate: Boolean,
)

public class HighSchoolPhase4CommandException(message: String) : IllegalArgumentException(message)

/**
 * In-memory command boundary used by tests and the future application repository. It is not
 * wired into production save writing during Phase 4.
 */
public class HighSchoolPhase4CommandStore(
    private val kernel: HighSchoolPhase4Kernel = HighSchoolPhase4Kernel(),
    initialState: HighSchoolPhase4State? = null,
) {
    private var current: HighSchoolPhase4State? = initialState

    public fun snapshot(): HighSchoolPhase4State? = current

    public fun dispatch(envelope: HighSchoolPhase4CommandEnvelope): HighSchoolPhase4DispatchResult {
        try {
            envelope.validate()
        } catch (error: IllegalArgumentException) {
            throw HighSchoolPhase4CommandException(error.message ?: "command.invalid")
        }
        val envelopeHash = HighSchoolPhase4CommandCodec.envelopeHash(envelope)
        val state = current
        val boundSession = state?.commandReceipts?.firstOrNull()?.sessionId
        if (!boundSession.isNullOrBlank() && boundSession != envelope.sessionId) {
            throw HighSchoolPhase4CommandException("command.session_mismatch")
        }
        val existing = state?.commandReceipts?.firstOrNull { it.commandId == envelope.commandId }
        if (existing != null) {
            if (existing.commandHash != envelopeHash) throw HighSchoolPhase4CommandException("command.duplicate_tampered")
            return HighSchoolPhase4DispatchResult(current ?: error("command.state"), existing.resultHash, duplicate = true)
        }
        if (state == null) {
            if (envelope.command !is HighSchoolPhase4Command.Start || envelope.expectedRevision != 0UL) {
                throw HighSchoolPhase4CommandException("command.start_required")
            }
            val result = kernel.start(envelope.command.request)
            val committed = commit(result.state, envelope, envelopeHash)
            current = committed
            return HighSchoolPhase4DispatchResult(committed, result.eventHash, duplicate = false)
        }
        kernel.validateSavedState(state)
        if (envelope.expectedRevision != state.revision) {
            throw HighSchoolPhase4CommandException("command.stale_revision")
        }
        if (envelope.command is HighSchoolPhase4Command.Start) {
            throw HighSchoolPhase4CommandException("command.start_duplicate")
        }
        val result = apply(state, envelope.command)
        val committed = commit(result.state, envelope, envelopeHash)
        current = committed
        return HighSchoolPhase4DispatchResult(committed, result.eventHash, duplicate = false)
    }

    private fun commit(
        state: HighSchoolPhase4State,
        envelope: HighSchoolPhase4CommandEnvelope,
        commandHash: String,
    ): HighSchoolPhase4State {
        val revision = (current?.revision ?: 0UL) + 1UL
        val resultHash = HighSchoolPhase4CommandCodec.resultHash(state, envelope)
        return kernel.commitShadowState(
            state.copy(
                revision = revision,
                commandReceipts = state.commandReceipts + HighSchoolCommandReceipt(
                    envelope.commandId, revision, resultHash, commandHash, envelope.sessionId,
                ),
            ),
        )
    }

    private fun apply(state: HighSchoolPhase4State, command: HighSchoolPhase4Command): HighSchoolPhase4Result = when (command) {
        is HighSchoolPhase4Command.Start -> error("command.start_duplicate")
        HighSchoolPhase4Command.BeginTutorial -> kernel.beginTutorial(state)
        is HighSchoolPhase4Command.CompleteTutorial -> kernel.completeTutorial(command.seed, state)
        is HighSchoolPhase4Command.ChooseSchool -> kernel.chooseSchool(command.seed, state, command.schoolId)
        is HighSchoolPhase4Command.SelectPledge -> kernel.selectPledge(state, command.pledgeId)
        is HighSchoolPhase4Command.Training -> kernel.commitTraining(command.seed, state, command.focus, command.intensity, command.targetPitch)
        is HighSchoolPhase4Command.TrainingBlock -> kernel.commitTrainingBlock(command.seed, state, command.requests)
        is HighSchoolPhase4Command.Relationship -> kernel.resolveRelationship(command.seed, state, command.response)
        is HighSchoolPhase4Command.ReserveImportantGame -> kernel.reserveImportantGame(command.seed, state)
        is HighSchoolPhase4Command.SubmitPitch -> {
            require(command.sessionId == state.activePitch?.sessionId) { "command.pitch_session_mismatch" }
            kernel.submitPitch(state, command.sessionId, command.call, command.delivery)
        }
        HighSchoolPhase4Command.FinishImportantGame -> kernel.finishImportantGame(state)
        is HighSchoolPhase4Command.ChooseAwakening -> kernel.chooseAwakening(command.seed, state, command.awakening)
        is HighSchoolPhase4Command.AdvanceChapter -> kernel.advanceChapter(command.seed, state)
        is HighSchoolPhase4Command.ResolveDraft -> kernel.resolveDraft(command.seed, state)
        HighSchoolPhase4Command.PrepareLegacy -> kernel.prepareLegacy(state)
        is HighSchoolPhase4Command.SelectLegacy -> kernel.selectLegacy(state, command.legacyId)
        HighSchoolPhase4Command.FinalizeArchive -> kernel.finalizeArchive(state)
        is HighSchoolPhase4Command.BeginRebirth -> kernel.beginRebirth(state, command.seed, command.dayKey)
        HighSchoolPhase4Command.StartChallenge -> kernel.startChallenge(state)
        HighSchoolPhase4Command.EndChallenge -> kernel.endChallenge(state)
        HighSchoolPhase4Command.ClaimWeeklyReward -> kernel.claimWeeklyReward(state)
        is HighSchoolPhase4Command.SaveReturnPlan -> kernel.saveReturnPlan(state, command.plan)
        is HighSchoolPhase4Command.PrepareReturnPlan -> kernel.prepareReturnPlan(state, command.dayKey, command.developmentRulesVersion)
        is HighSchoolPhase4Command.SaveNextRunIntent -> kernel.saveNextRunIntent(state, command.intent)
        HighSchoolPhase4Command.ClearNextRunIntent -> kernel.clearNextRunIntent(state)
        HighSchoolPhase4Command.DismissReturnPlan -> kernel.dismissReturnPlan(state)
        is HighSchoolPhase4Command.AcknowledgeAchievement -> kernel.acknowledgeAchievement(state, command.achievementId)
    }
}
