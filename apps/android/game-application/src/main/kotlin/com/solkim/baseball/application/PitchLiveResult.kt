package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.BattedBall
import com.solkim.baseball.core.pitch.FieldingResolutionSnapshot
import com.solkim.baseball.core.pitch.PitchOutcome

/** Reads the live mound drama from the last presentation. Log history is not the current camera. */
public object PitchLiveResult {
    public fun outcome(state: GameAggregateState): PitchOutcome? = when (state.pitch?.careerKind) {
        PitchCareerKind.PRO -> {
            if (state.pro?.lastPresentation == null) null
            else state.pro.activePitch?.log?.entries?.lastOrNull()?.outcome
        }
        PitchCareerKind.HIGH_SCHOOL, PitchCareerKind.TUTORIAL ->
            state.highSchool?.lastPresentation?.outcome?.let { wire ->
                PitchOutcome.entries.firstOrNull { it.wire == wire }
            }
        null -> null
    }

    public fun battedBall(state: GameAggregateState): BattedBall? = when (state.pitch?.careerKind) {
        PitchCareerKind.PRO -> state.pro?.lastBattedBall
        PitchCareerKind.HIGH_SCHOOL, PitchCareerKind.TUTORIAL -> state.highSchool?.lastPresentation?.battedBall
        null -> null
    }

    public fun fielding(state: GameAggregateState): FieldingResolutionSnapshot? = when (state.pitch?.careerKind) {
        PitchCareerKind.PRO -> state.pro?.lastFielding
        PitchCareerKind.HIGH_SCHOOL, PitchCareerKind.TUTORIAL -> state.highSchool?.lastPresentation?.fielding
        null -> null
    }
}
