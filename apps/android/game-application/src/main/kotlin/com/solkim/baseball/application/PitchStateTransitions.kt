package com.solkim.baseball.application

/** Shared by both writers. Transient suspension data must not leak into another boundary. */
public object PitchStateTransitions {
    public fun canAbandon(pitch: PitchDurableState?): Boolean = pitch != null &&
        (pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING) ||
            (pitch.boundary == PitchBoundary.SUSPENDED && pitch.suspendedFrom in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING))) &&
        pitch.committedPitchIds.isEmpty() && pitch.terminalPitchId == null
    public fun hasResult(pitch: PitchDurableState?): Boolean = pitch != null &&
        (if (pitch.boundary == PitchBoundary.SUSPENDED) pitch.suspendedFrom else pitch.boundary) in
        setOf(PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL)
    public fun resumeCommands(pitch: PitchDurableState?): List<GameCommand> = when (pitch?.boundary) {
        PitchBoundary.SUSPENDED -> listOf(GameCommand.ResumePitch(pitch.sessionId)) +
            if (pitch.suspendedFrom == PitchBoundary.RESERVED) listOf(GameCommand.StartPitch(pitch.sessionId)) else emptyList()
        PitchBoundary.RESERVED -> listOf(GameCommand.StartPitch(pitch.sessionId))
        else -> emptyList()
    }
    public fun abandon(pitch: PitchDurableState, reason: String): PitchDurableState {
        require(canAbandon(pitch)) { "pitch.abandon_boundary" }
        require(reason.isNotBlank()) { "pitch.abandon_reason" }
        return pitch.copy(boundary = PitchBoundary.ABANDONED, suspendedFrom = null, abandonedReason = reason).also { it.validate() }
    }
    public fun suspend(pitch: PitchDurableState, checkpoint: String): PitchDurableState {
        require(pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.COMMITTED, PitchBoundary.CONSUMED)) { "pitch.suspend_boundary" }
        require(checkpoint.isNotBlank()) { "pitch.suspend_checkpoint" }
        return pitch.copy(boundary = PitchBoundary.SUSPENDED, checkpoint = checkpoint, suspendedFrom = pitch.boundary).also { it.validate() }
    }
    public fun resume(pitch: PitchDurableState): PitchDurableState {
        require(pitch.boundary == PitchBoundary.SUSPENDED && pitch.suspendedFrom in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL)) { "pitch.resume_boundary" }
        return pitch.copy(boundary = requireNotNull(pitch.suspendedFrom), suspendedFrom = null).also { it.validate() }
    }
}
