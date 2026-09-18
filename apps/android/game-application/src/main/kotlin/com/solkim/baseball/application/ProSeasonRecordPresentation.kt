package com.solkim.baseball.application

import com.solkim.baseball.core.pro.ProSeasonStats

public object ProSeasonRecordPresentation {
    public fun era(stats: ProSeasonStats): String = if (stats.inningsOuts == 0 || stats.earnedRuns == null) "—"
        else String.format(java.util.Locale.US, "%.2f", requireNotNull(stats.earnedRuns) * 27.0 / stats.inningsOuts)
    public fun line(stats: ProSeasonStats?): String = stats?.let {
        "${it.games}경기 · ${it.inningsOuts / 3}.${it.inningsOuts % 3}이닝 · ERA ${era(it)}\n${it.wins}승 ${it.losses}패 · ${it.strikeouts}탈삼진 · ${it.saves}세이브"
    } ?: "아직 기록이 없습니다."
}
