package com.solkim.baseball.core.pro

/** 시즌을 한 문장으로 남기는 닫힌 제목 집합. */
public enum class ProSeasonArcTitle(public val wire: String) {
    FIRST_HALF_ACE("first_half_ace"),
    DOMINANT("dominant"),
    LONG_TUNNEL("long_tunnel"),
    LATE_RECOVERY("late_recovery"),
    AUTUMN_DOOR_CLOSED("autumn_door_closed"),
    AUTUMN_CHAMPION("autumn_champion"),
    AUTUMN_RUNNER_UP("autumn_runner_up"),
    AUTUMN_ELIMINATED("autumn_eliminated"),
    AUTUMN_UNAVAILABLE("autumn_unavailable"),
    QUIET("quiet"),
}

public object ProSeasonArcRules {
    public fun title(gameLines: List<ProGameLine>, postseason: ProPostseasonState?): ProSeasonArcTitle {
        if (postseason != null) {
            when (postseason.result) {
                ProPostseasonResult.CHAMPION -> return ProSeasonArcTitle.AUTUMN_CHAMPION
                ProPostseasonResult.RUNNER_UP -> return ProSeasonArcTitle.AUTUMN_RUNNER_UP
                ProPostseasonResult.ELIMINATED -> return ProSeasonArcTitle.AUTUMN_ELIMINATED
                ProPostseasonResult.DID_NOT_QUALIFY -> return ProSeasonArcTitle.AUTUMN_DOOR_CLOSED
                ProPostseasonResult.UNAVAILABLE -> return ProSeasonArcTitle.AUTUMN_UNAVAILABLE
                ProPostseasonResult.IN_PROGRESS -> Unit
            }
        }
        val first = split(gameLines, 1..12)
        val second = split(gameLines, 13..24)
        return when (quality(first) to quality(second)) {
            SplitQuality.GOOD to SplitQuality.POOR -> ProSeasonArcTitle.FIRST_HALF_ACE
            SplitQuality.GOOD to SplitQuality.GOOD -> ProSeasonArcTitle.DOMINANT
            SplitQuality.POOR to SplitQuality.POOR -> ProSeasonArcTitle.LONG_TUNNEL
            SplitQuality.POOR to SplitQuality.GOOD -> ProSeasonArcTitle.LATE_RECOVERY
            else -> ProSeasonArcTitle.QUIET
        }
    }

    public fun contentId(title: ProSeasonArcTitle): String = "pro.arc.${title.wire}"

    private enum class SplitQuality { GOOD, EVEN, POOR }

    private fun split(lines: List<ProGameLine>, weeks: IntRange): Pair<Int, Int> =
        lines.filter { it.week in weeks }.fold(0 to 0) { partial, line ->
            (partial.first + line.runsAllowed) to (partial.second + line.outs)
        }

    private fun quality(split: Pair<Int, Int>): SplitQuality {
        val runs = split.first
        val outs = split.second
        if (outs < 27) return SplitQuality.EVEN
        val ra9 = runs * 27_000 / outs
        if (ra9 < 3_500) return SplitQuality.GOOD
        if (ra9 >= 4_500) return SplitQuality.POOR
        return SplitQuality.EVEN
    }
}
