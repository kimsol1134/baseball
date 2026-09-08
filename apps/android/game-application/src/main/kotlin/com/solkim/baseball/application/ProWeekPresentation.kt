package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*

public data class ProWeekPreview(val title: String, val growth: String, val schedule: String, val condition: String)
public data class ProWeekResult(val careerId: String, val season: Int, val week: Int, val weeks: Int, val growth: List<String>,
    val games: Int, val outs: Int, val strikeouts: Int, val runs: Int, val fatigueBefore: Int, val fatigueAfter: Int, val injuries: Int,
    val role: String, val level: String)
public object ProWeekPresentation {
    public fun title(id: String): String = when (id.substringAfter(':')) {
        "develop_stuff" -> "구위"; "refine_command" -> "제구"; "develop_movement" -> "변화구"
        "build_stamina" -> "체력"; "recover" -> "회복"; "earn_trust" -> "신뢰"; else -> "훈련"
    }
    public fun preview(state: GameAggregateState, actionId: String): ProWeekPreview? {
        val pro = state.pro ?: return null
        val plan = ProWeekPlan.entries.firstOrNull { it.wire == actionId.substringAfter(':') } ?: return null
        val forecast = proWeekForecast(pro, plan)
        return ProWeekPreview(if (pro.week == 0) "시즌 준비" else "${pro.week + 1}주차 준비",
            if (forecast.growthActive) "${title(actionId)} 성장 진도 ${forecast.progress}/${forecast.required} → 훈련 1회 누적"
            else if (plan == ProWeekPlan.RECOVER || pro.injuryWeeks > 0) "몸을 회복하는 한 주" else "감독의 신뢰를 쌓는 한 주",
            "예정된 자동 등판 ${forecast.outings}경기",
            "예상 피로 ${forecast.fatigueMinimum}~${forecast.fatigueMaximum} · 현재 ${pro.fatigue}")
    }
    public fun result(before: GameAggregateState, after: GameAggregateState): ProWeekResult? {
        val old = before.pro ?: return null
        val next = after.pro ?: return null
        if (old.careerId != next.careerId || old.season != next.season || next.week <= old.week) return null
        val labels = listOf("구위", "제구", "무브먼트", "체력")
        val a = old.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val b = next.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val x = old.developmentProgress.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val y = next.developmentProgress.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val plans = listOf(ProWeekPlan.DEVELOP_STUFF, ProWeekPlan.REFINE_COMMAND, ProWeekPlan.DEVELOP_MOVEMENT, ProWeekPlan.BUILD_STAMINA)
        val growth = a.indices.mapNotNull { i ->
            val delta = AbilityDisplayScale.delta(a[i], b[i])
            if (delta != 0) "${labels[i]} ${if (delta > 0) "+" else ""}$delta"
            else if (y[i] != x[i]) "${labels[i]} 성장 진도 ${y[i]}/${proWeekForecast(next, plans[i]).required}" else null
        }
        val rows = next.currentGameLines.filter { it.season == next.season && it.week > old.week && it.week <= next.week }
        return ProWeekResult(next.careerId, next.season, next.week, next.week - old.week, growth,
            rows.size, rows.sumOf { it.outs }, rows.sumOf { it.strikeouts }, rows.sumOf { it.runsAllowed }, old.fatigue, next.fatigue, next.injuryWeeks,
            next.role.label, if (next.level == ProLevel.MAJOR) "1군" else "2군")
    }
}
