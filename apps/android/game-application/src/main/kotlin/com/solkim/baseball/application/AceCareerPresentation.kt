package com.solkim.baseball.application

import com.solkim.baseball.core.pro.ProRole

public object AceCareerPresentation {
    public fun pathTitle(path: String): String = when (path) {
        "endurance" -> "끝까지 책임지는 선발"
        "closer" -> "마지막 아웃의 주인공"
        "command" -> "적은 공으로 이기는 투수"
        else -> "나만의 투수"
    }
    public fun preferredRole(state: GameAggregateState): String? = when (state.meta.companion?.careerPath) {
        "closer" -> "closer"; "endurance", "command" -> "starter"; else -> null
    }
    public fun leagueLine(state: GameAggregateState): String? {
        val pro = state.pro ?: return null
        val team = pro.standings.firstOrNull { it.teamId == pro.team.id }
        return if (team == null) "${pro.team.name} · 시즌 준비" else
            "${pro.team.name} ${team.rank}위 · ${team.wins}승 ${team.losses}패 ${team.draws}무"
    }
    public fun goal(state: GameAggregateState): Pair<String, String>? {
        val pro = state.pro ?: return null
        val rows = (pro.careerStats.filter { it.season != pro.season } + pro.currentStats)
        val saves = rows.sumOf { it.saves }
        if (state.meta.companion?.careerPath == "command") {
            val stats = pro.currentStats
            val bb9 = if (stats.inningsOuts > 0) "%.2f".format(java.util.Locale.ROOT, stats.walks * 27.0 / stats.inningsOuts) else "—"
            return "제구로 증명 · 100이닝, BB/9 2.00 이하" to "${stats.inningsOuts / 3}.${stats.inningsOuts % 3}이닝 · BB/9 $bb9"
        }
        if (state.meta.companion?.careerPath == "endurance") {
            val previous = state.meta.retiredProCareers.flatMap { it.careerStats }.maxOfOrNull { it.completeGames ?: 0 } ?: 0
            if (previous > 0) return "전생의 시즌 완투 기록에 도전" to "이번 시즌 ${pro.currentStats.completeGames ?: 0}회 · 전생 최고 ${previous}회"
        }
        if (pro.role == ProRole.CLOSER || state.meta.companion?.careerPath == "closer") {
            if (pro.role != ProRole.CLOSER) return "마무리의 길" to "스프링캠프에서 마무리 보직에 지원하기"
            val target = if (saves == 0) 1 else (saves / 30 + 1) * 30
            return (if (target == 1) "첫 세이브" else "통산 ${target}세이브") to "$saves / $target"
        }
        if (rows.none { (it.completeGames ?: 0) > 0 }) return "첫 완투에 도전" to "투구 수와 체력을 아껴 마지막 아웃까지"
        if (rows.none { (it.shutouts ?: 0) > 0 }) return "첫 완봉승에 도전" to "첫 공부터 마지막 공까지 무실점"
        val prior = state.meta.album.filter { it.scope.id.startsWith("pro:${pro.careerId}:") }.flatMap { it.rows }.maxOfOrNull { it.strikeouts } ?: 0
        return "한 경기 ${prior + 1}탈삼진에 도전" to "완투 ${rows.sumOf { it.completeGames ?: 0 }}회 · 완봉승 ${rows.sumOf { it.shutouts ?: 0 }}회"
    }
    public fun inningDecision(state: GameAggregateState): String? {
        val pro = state.pro ?: return null
        val p = pro.activePitch ?: return null
        if (!p.ended || p.game.inningState?.outs != 0) return null
        val remaining = (27 - p.outs).coerceAtLeast(0)
        val fullStart = p.assignment?.role == com.solkim.baseball.core.pitch.OutingRole.STARTER && p.assignment?.entryInning == 1 && p.assignment?.entryOuts == 0
        val record = when {
            fullStart && p.outs >= 27 && p.runsAllowed == 0 -> "9이닝 무실점 · 팀의 마지막 공격을 기다립니다"
            p.context.inning >= 9 -> "9회 마지막 아웃 · 등판 종료"
            !com.solkim.baseball.core.pro.ProOutingUsageRules.canContinue(pro) -> "불펜이 남은 아웃을 이어받습니다"
            fullStart && p.outs >= 18 && p.runsAllowed == 0 -> "완봉 도전까지 아웃 ${remaining}개"
            fullStart && p.outs >= 18 -> "완투까지 아웃 ${remaining}개"
            else -> "다음 이닝도 책임질까요?"
        }
        return "${p.context.inning}회 종료 · ${p.pitches}구 · ${p.runsAllowed}실점\n$record"
    }
}
