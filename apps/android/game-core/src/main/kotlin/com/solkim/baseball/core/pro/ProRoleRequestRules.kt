package com.solkim.baseball.core.pro

/** Same deterministic camp thresholds as the Swift authority. Requests never consume RNG. */
public object ProRoleRequestRules {
    public val requestableRoles: List<ProRole> = listOf(ProRole.STARTER, ProRole.LONG_RELIEF, ProRole.CLOSER)
    public const val REVIEW_WEEK: Int = 6

    public fun shouldOffer(state: ProState): Boolean = ProKernel.usesWeeklyDecisionRules(state) &&
        state.phase == ProCareerPhase.WEEKLY_PLAN && state.week == 0 && state.seasonSegment == ProSeasonSegment.SPRING_CAMP &&
        state.roleRequest?.season != state.season && state.journeyState?.contractHistory?.lastOrNull {
            it.endedSeason == null && it.signedSeason <= state.season
        }?.kind.let { it == null || it == ProContractKind.ROOKIE }

    public fun evaluate(state: ProState, requested: ProRole): ProRoleRequestOutcome {
        require(requested in requestableRoles) { "pro.role_request.role" }
        val assigned = if (state.level == ProLevel.MAJOR) {
            if (state.managerTrust >= 74) ProRole.STARTER else if (state.managerTrust >= 62) ProRole.LONG_RELIEF else ProRole.SETUP
        } else if (state.managerTrust >= 52) ProRole.STARTER else ProRole.LONG_RELIEF
        fun normalized(role: ProRole) = if (role == ProRole.SETUP) ProRole.LONG_RELIEF else role
        if (requested == normalized(state.role) || requested == normalized(assigned)) return ProRoleRequestOutcome.ACCEPTED
        return when (requested) {
            ProRole.STARTER -> when {
                state.pitcher.stamina >= 55 && (state.season == 1 || state.managerTrust >= 45) -> ProRoleRequestOutcome.ACCEPTED
                state.pitcher.stamina >= 48 -> ProRoleRequestOutcome.CONDITIONAL
                else -> ProRoleRequestOutcome.REJECTED
            }
            ProRole.CLOSER -> when {
                state.pitcher.stuff >= 58 && (state.season == 1 || state.catcherTrust >= 45) -> ProRoleRequestOutcome.ACCEPTED
                state.pitcher.stuff >= 52 -> ProRoleRequestOutcome.CONDITIONAL
                else -> ProRoleRequestOutcome.REJECTED
            }
            else -> ProRoleRequestOutcome.ACCEPTED
        }
    }

    public fun pendingReview(state: ProState, week: Int): Boolean = state.roleRequest?.let { request ->
        ProKernel.usesWeeklyDecisionRules(state) && request.season == state.season &&
            request.outcome == ProRoleRequestOutcome.CONDITIONAL && week >= request.reviewWeek &&
            state.decisionHistory.none { it.season == state.season && it.type == ProSeasonDecisionType.ROLE_MEETING && it.week >= request.reviewWeek }
    } ?: false
}
