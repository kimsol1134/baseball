package com.solkim.baseball.application

public object PitchFailureRecovery {
    /** Call only after successful durable-store reconciliation. Never match a previous pitch. */
    public fun hasSavedResult(state: GameAggregateState, sessionId: String, pitchId: String?): Boolean {
        val pitch = state.pitch ?: return false
        return pitchId != null && pitch.sessionId == sessionId && pitch.committedPitchIds.lastOrNull() == pitchId &&
            pitch.boundary in setOf(PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL, PitchBoundary.COMPLETED)
    }
}
