package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4State

/** Shared official-game accounting for both persistence implementations. */
internal object GameCompletionRules {
    fun afterHighSchool(before: GameAggregateState, next: HighSchoolPhase4State): ULong {
        if (before.meta.seedChallenge != null || before.highSchool?.challenge?.active == true || next.challenge.active) return before.meta.completedGameCount
        val previous = before.highSchool?.completedGameCounter ?: 0UL
        val increase = if (next.completedGameCounter > previous) next.completedGameCounter - previous else 0UL
        require(increase <= ULong.MAX_VALUE - before.meta.completedGameCount) { "meta.completed_games_exhausted" }
        return before.meta.completedGameCount + increase
    }

    fun completePitch(state: GameAggregateState, sessionId: String): GameAggregateState {
        val pitch = requireNotNull(state.pitch) { "pitch.missing" }
        require(pitch.sessionId == sessionId && pitch.boundary == PitchBoundary.TERMINAL) { "pitch.complete_boundary" }
        val official = !pitch.challengeRun && state.meta.seedChallenge == null && when (pitch.careerKind) {
            PitchCareerKind.HIGH_SCHOOL -> state.highSchool?.let { it.activePitch == null && pitch.sessionId !in it.completedGameReceipts } == true
            // Intermediate balls and plate appearances still have an active game owner.
            PitchCareerKind.PRO -> state.pro != null && state.pro.activePitch == null
            PitchCareerKind.TUTORIAL -> false
        }
        require(!official || state.meta.completedGameCount < ULong.MAX_VALUE) { "meta.completed_games_exhausted" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.COMPLETED),
            meta = if (official) state.meta.copy(completedGameCount = state.meta.completedGameCount + 1UL) else state.meta)
    }
}
