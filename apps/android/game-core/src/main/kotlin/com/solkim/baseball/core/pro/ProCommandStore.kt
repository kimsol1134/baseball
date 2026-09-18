package com.solkim.baseball.core.pro

public class ProCommandStore(
    private val kernel: ProKernel = ProKernel(),
    initialState: ProState? = null,
) {
    private var current: ProState? = initialState

    init { current?.let(kernel::validateSavedState) }

    public fun snapshot(): ProState? = current

    public fun dispatch(envelope: ProCommandEnvelope): ProDispatchResult {
        try { envelope.validate() } catch (error: IllegalArgumentException) { throw ProCommandException(error.message ?: "pro.command.invalid") }
        val commandHash = ProCommandCodec.envelopeHash(envelope)
        val state = current
        val boundSession = state?.commandReceipts?.firstOrNull()?.sessionId
        if (boundSession != null && boundSession != envelope.sessionId) throw ProCommandException("pro.command.session_mismatch")
        val existing = state?.commandReceipts?.firstOrNull { it.commandId == envelope.commandId }
        if (existing != null) {
            if (existing.commandHash != commandHash) throw ProCommandException("pro.command.duplicate_tampered")
            return ProDispatchResult(state ?: error("pro.command.state"), existing.resultHash, duplicate = true)
        }
        if (state == null) {
            if (envelope.expectedRevision != 0UL || (envelope.command !is ProCommand.StartLinked && envelope.command !is ProCommand.StartDirect)) throw ProCommandException("pro.command.start_required")
            val result = when (val command = envelope.command) {
                is ProCommand.StartLinked -> kernel.startLinked(command.request)
                is ProCommand.StartDirect -> kernel.startDirect(command.request)
                else -> error("unreachable")
            }
            return commit(result, envelope, commandHash)
        }
        kernel.validateSavedState(state)
        if (envelope.expectedRevision != state.revision) throw ProCommandException("pro.command.stale_revision")
        if (envelope.command is ProCommand.StartLinked || envelope.command is ProCommand.StartDirect) throw ProCommandException("pro.command.start_duplicate")
        return commit(apply(state, envelope.command), envelope, commandHash)
    }

    private fun commit(result: ProResult, envelope: ProCommandEnvelope, commandHash: String): ProDispatchResult {
        val priorRevision = current?.revision ?: 0UL
        val revision = maxOf(result.state.revision, priorRevision + 1UL)
        val resultHash = ProCommandCodec.resultHash(result.state, envelope)
        val receipt = ProCommandReceipt(envelope.commandId, envelope.sessionId, commandHash, resultHash, revision)
        val unsigned = result.state.copy(revision = revision, commandReceipts = result.state.commandReceipts + receipt, commitment = "")
        val committed = unsigned.copy(commitment = ProKernel().commitment(unsigned))
        kernel.validateSavedState(committed)
        current = committed
        return ProDispatchResult(committed, resultHash, duplicate = false, injuryEvent = result.injuryEvent)
    }

    private fun apply(state: ProState, command: ProCommand): ProResult = when (command) {
        is ProCommand.StartLinked, is ProCommand.StartDirect -> error("pro.command.start_duplicate")
        is ProCommand.RequestRole -> kernel.requestRole(state, command.seed, command.requested)
        ProCommand.SignContract -> kernel.signContract(state, state.seed)
        is ProCommand.AcceptContractOffer -> kernel.acceptContractOffer(state, command.seed, command.offerId, command.ambition)
        is ProCommand.PlanWeek -> kernel.planWeek(state, command.seed, command.plan, command.targetPitch)
        is ProCommand.AdvanceSegment -> kernel.advanceSegment(state, command.seed, command.plan, command.targetPitch, command.maximumWeeks)
        is ProCommand.ApplySeasonDecision -> kernel.applySeasonDecision(state, command.seed, command.decisionId, command.choiceId)
        is ProCommand.ReserveImportantGame -> kernel.reserveImportantGame(state, command.seed)
        is ProCommand.SubmitPitch -> {
            require(command.pitchSessionId == state.activePitch?.sessionId) { "pro.command.pitch_session_mismatch" }
            kernel.submitPitch(state, command.pitchSessionId, command.call, command.delivery)
        }
        ProCommand.ContinueOuting -> kernel.continueOuting(state)
        ProCommand.HandOffOuting -> kernel.finishImportantGame(state, handOff = true)
        ProCommand.FinishImportantGame -> kernel.finishImportantGame(state)
        is ProCommand.ReviewSeason -> kernel.reviewSeason(state, command.seed)
        is ProCommand.AcknowledgeSeasonSettlement -> kernel.acknowledgeSeasonSettlement(state, command.seed, command.settlementId)
        is ProCommand.ChooseOffseason -> kernel.chooseOffseason(state, command.seed, command.decision)
        is ProCommand.ChooseInvestment -> kernel.chooseInvestment(state, command.seed, command.investment, command.focus)
        is ProCommand.SelectLegacy -> kernel.selectLegacy(state, command.legacyId)
        ProCommand.NormalizeBalance -> kernel.normalizeBalance(state)
        is ProCommand.RespondNationalTeamCall -> kernel.respondToNationalTeamCall(state, command.seed, command.accepted)
        is ProCommand.StartNationalFinal -> kernel.startNationalFinal(state, command.seed)
        is ProCommand.ResolveNationalFinalAutomatically -> kernel.resolveNationalFinalAutomatically(state, command.seed)
        is ProCommand.AcknowledgeNationalTeamResult -> kernel.acknowledgeNationalTeamResult(state, command.seed)
    }
}
