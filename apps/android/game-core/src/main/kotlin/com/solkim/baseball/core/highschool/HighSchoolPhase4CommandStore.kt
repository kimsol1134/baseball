package com.solkim.baseball.core.highschool

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
            if (envelope.expectedRevision != 0UL) {
                throw HighSchoolPhase4CommandException("command.start_required")
            }
            val result = when (val start = envelope.command) {
                is HighSchoolPhase4Command.Start -> kernel.start(start.request)
                is HighSchoolPhase4Command.StartConfigured -> kernel.startConfigured(start.request, start.primaryPitch, start.learningPitch)
                else -> throw HighSchoolPhase4CommandException("command.start_required")
            }
            val committed = commit(result.state, envelope, envelopeHash)
            current = committed
            return HighSchoolPhase4DispatchResult(committed, result.eventHash, duplicate = false)
        }
        kernel.validateSavedState(state)
        if (envelope.expectedRevision != state.revision) {
            throw HighSchoolPhase4CommandException("command.stale_revision")
        }
        if (envelope.command is HighSchoolPhase4Command.Start || envelope.command is HighSchoolPhase4Command.StartConfigured) {
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
        is HighSchoolPhase4Command.StartConfigured -> error("command.start_duplicate")
        is HighSchoolPhase4Command.ConfigureRebirth -> kernel.beginRebirth(state, command.seed, command.dayKey, command.setup)
        HighSchoolPhase4Command.BeginTutorial -> kernel.beginTutorial(state)
        is HighSchoolPhase4Command.CompleteTutorial -> kernel.completeTutorial(command.seed, state)
        is HighSchoolPhase4Command.ChooseSchool -> kernel.chooseSchool(command.seed, state, command.schoolId)
        is HighSchoolPhase4Command.SelectPledge -> kernel.selectPledge(state, command.pledgeId)
        is HighSchoolPhase4Command.Training -> kernel.commitTraining(command.seed, state, command.focus, command.intensity, command.targetPitch)
        is HighSchoolPhase4Command.TrainingBlock -> kernel.commitTrainingBlock(command.seed, state, command.requests, command.targetPitch, command.stopForSafety)
        is HighSchoolPhase4Command.Relationship -> kernel.resolveRelationship(command.seed, state, command.response)
        is HighSchoolPhase4Command.ReserveImportantGame -> kernel.reserveImportantGame(command.seed, state)
        is HighSchoolPhase4Command.SubmitPitch -> {
            state.activePitch?.let { active ->
                require(command.sessionId == active.sessionId) { "command.pitch_session_mismatch" }
            }
            kernel.submitPitch(state, command.sessionId, command.call, command.delivery)
        }
        HighSchoolPhase4Command.ContinueOuting -> kernel.continueOuting(state)
        HighSchoolPhase4Command.FinishImportantGame -> kernel.finishImportantGame(state)
        is HighSchoolPhase4Command.ChooseAwakening -> kernel.chooseAwakening(command.seed, state, command.awakening)
        is HighSchoolPhase4Command.AdvanceChapter -> kernel.advanceChapter(command.seed, state)
        is HighSchoolPhase4Command.ClaimChapterGame -> kernel.claimChapterGame(command.seed, state)
        is HighSchoolPhase4Command.ResolveDraft -> kernel.resolveDraft(command.seed, state)
        HighSchoolPhase4Command.PrepareLegacy -> kernel.prepareLegacy(state)
        is HighSchoolPhase4Command.SelectLegacy -> kernel.selectLegacy(state, command.legacyId)
        HighSchoolPhase4Command.FinalizeArchive -> kernel.finalizeArchive(state)
        is HighSchoolPhase4Command.BeginRebirth -> kernel.beginRebirth(state, command.seed, command.dayKey)
        HighSchoolPhase4Command.StartChallenge -> kernel.startChallenge(state)
        is HighSchoolPhase4Command.StartSeedChallenge -> kernel.startChallenge(state, command.seed, command.life, command.presetId)
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
