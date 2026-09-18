package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolWeeklyRules

/** A retained high-school archive does not make its tasks part of an active pro career. */
public object WeeklyNotePolicy {
    public fun isAvailable(state: GameAggregateState): Boolean = state.highSchool != null &&
        state.meta.seedChallenge == null && (state.pro == null || state.pro.phase == com.solkim.baseball.core.pro.ProCareerPhase.COMPLETED) && state.stage in setOf(GameStage.HIGH_SCHOOL, GameStage.DRAFT, GameStage.BETWEEN_LIVES)

    public fun requirement(): String = "주간 과제 ${HighSchoolWeeklyRules.MIN_COMPLETED_FOR_REWARD}개 이상 완료하면 받을 수 있어요."

    public fun rejection(state: GameAggregateState): String? = when {
        state.meta.seedChallenge != null || state.highSchool?.challenge?.active == true -> "weekly.challenge_locked"
        !isAvailable(state) -> "weekly.career_unavailable"
        else -> HighSchoolWeeklyRules.rewardRejection(requireNotNull(state.highSchool).weekly)
    }

    public fun explanation(state: GameAggregateState): String = when (rejection(state)) {
        "weekly.already_claimed" -> "이번 주 보상을 이미 받았어요."
        "weekly.challenge_locked" -> "도전 모드에서는 주간 보상을 받을 수 없어요."
        "weekly.career_unavailable" -> "주간 노트 보상은 고교 과정에서 받을 수 있어요."
        else -> requirement()
    }

    public fun canClaim(state: GameAggregateState): Boolean = rejection(state) == null
    public fun requireClaimable(state: GameAggregateState) {
        rejection(state)?.let { throw GameCommandException(it) }
    }
}
