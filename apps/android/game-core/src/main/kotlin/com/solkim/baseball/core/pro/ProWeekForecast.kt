package com.solkim.baseball.core.pro

public data class ProWeekForecast(val outings: Int, val fatigueMinimum: Int, val fatigueMaximum: Int,
    val progress: Int, val required: Int, val growthActive: Boolean)

/** Shared by execution and preview. Preview has no RNG and cannot expose future game outcomes. */
internal fun weeklyOutingBudget(role: ProRole): Triple<Int, Int, Int> = when (role) {
    ProRole.STARTER -> Triple(1, 18, 96)
    ProRole.LONG_RELIEF -> Triple(2, 6, 42)
    ProRole.SETUP, ProRole.CLOSER -> Triple(3, 3, 24)
}
internal fun weeklyTrainingLoad(plan: ProWeekPlan): Int = when (plan) {
    ProWeekPlan.DEVELOP_STUFF -> 10; ProWeekPlan.DEVELOP_MOVEMENT -> 8; ProWeekPlan.DEVELOP_WEAPON -> 9
    ProWeekPlan.REFINE_COMMAND -> 6; ProWeekPlan.BUILD_STAMINA -> 7; ProWeekPlan.RECOVER -> -16; ProWeekPlan.EARN_TRUST -> 5
}
public fun proWeekForecast(state: ProState, plan: ProWeekPlan): ProWeekForecast {
    val modifiers = state.activeDecisionModifiers.orEmpty().filter { it.expiresWeek >= state.week + 1 }
    val budget = weeklyOutingBudget(state.role)
    val recovering = state.injuryWeeks > 0
    val outings = if (recovering || modifiers.any { it.suppressOutings }) 0 else budget.first + modifiers.sumOf { (it.extraOutingChance - (it.extraOutingsGranted ?: 0)).coerceAtLeast(0) }
    val base = if (recovering) -20 else weeklyTrainingLoad(plan) - ((state.pitcher.stamina - 50) / 15).coerceAtLeast(0)
    val minimum = (state.fatigue + base).coerceIn(0, 100)
    val maximum = (state.fatigue + base + (if (recovering) 0 else (outings * budget.third + 14) / 15)).coerceIn(0, 100)
    val (ability, progress) = when (plan) {
        ProWeekPlan.REFINE_COMMAND -> state.pitcher.command to state.developmentProgress.command
        ProWeekPlan.DEVELOP_MOVEMENT -> state.pitcher.movement to state.developmentProgress.movement
        ProWeekPlan.BUILD_STAMINA -> state.pitcher.stamina to state.developmentProgress.stamina
        else -> state.pitcher.stuff to state.developmentProgress.stuff
    }
    val needed = if (ProKernel.usesLiveOutingRules(state)) ProKernel.developmentTicksRequired(ability) else 2
    val efficiency = modifiers.mapNotNull { it.trainingEfficiencyPermille }.minOrNull() ?: 1000
    val required = if (efficiency >= 1000) maxOf(1, needed * 1000 / efficiency) else maxOf(needed, (needed * 1000 + efficiency - 1) / efficiency)
    return ProWeekForecast(outings, minimum, maximum, progress, required,
        !recovering && state.journeyState?.recoveryYearPending != true && plan !in setOf(ProWeekPlan.RECOVER, ProWeekPlan.EARN_TRUST))
}
