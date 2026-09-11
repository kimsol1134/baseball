package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*

public data class ProConversationView(
    val teamId: String,
    val decisionId: String,
    val type: ProSeasonDecisionType,
    val title: String,
    val detail: String,
    val choices: List<ProDecisionChoice>,
)

public object ProConversationPresentation {
    public fun view(state: GameAggregateState): ProConversationView? {
        val pro = state.pro ?: return null
        val decision = pro.pendingDecision ?: return null
        return ProConversationView(pro.team.id, decision.id, decision.type, decision.title, decision.detail, decision.choices)
    }

    /** Scouting a rival is a conversation with the catcher, not an invented rival appearance. */
    public fun role(type: ProSeasonDecisionType?): String? = when (type) {
        ProSeasonDecisionType.CATCHER_GAME_PLAN, ProSeasonDecisionType.RIVAL_ANALYSIS -> "catcher"
        ProSeasonDecisionType.ROTATION_PUSH, ProSeasonDecisionType.NEW_PITCH_TRIAL,
        ProSeasonDecisionType.FARM_RESET, ProSeasonDecisionType.EXTRA_BULLPEN,
        ProSeasonDecisionType.ROLE_MEETING, ProSeasonDecisionType.RECORD_CHASE,
        ProSeasonDecisionType.SEASON_FINALE, ProSeasonDecisionType.FORM_CRISIS -> "coach"
        null -> null
        else -> "staff"
    }

    public fun effects(before: ProState, after: ProState): List<ChoiceEffect> = buildList {
        fun change(label: String, from: Int, to: Int) { if (from != to) add(ChoiceEffect.fromSource("$label ${if (to > from) "+" else ""}${to - from}")) }
        if (before.role != after.role) add(ChoiceEffect("보직: ${after.role.label}"))
        if (before.activeDecisionModifiers != after.activeDecisionModifiers) add(ChoiceEffect("다음 등판 준비에 반영됐어요."))
        change("감독 신뢰", before.managerTrust, after.managerTrust)
        change("포수 신뢰", before.catcherTrust, after.catcherTrust)
        change("피로", before.fatigue, after.fatigue)
        val old = before.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val next = after.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        listOf("구위", "제구", "무브먼트", "체력").forEachIndexed { i, label ->
            change(label, AbilityDisplayScale.rating(old[i]), AbilityDisplayScale.rating(next[i]))
        }
    }

    public fun preview(state: ProState, seed: String, choiceId: String): List<ChoiceEffect> {
        val decision = state.pendingDecision ?: return emptyList()
        return effects(state, ProKernel().applySeasonDecision(state, seed, decision.id, choiceId).state)
    }
}
