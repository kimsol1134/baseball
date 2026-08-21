package com.solkim.baseball.core.pro

/** iOS `ProCareerRecognitionRules.awardContentIDs`. Callers must pass rulesVersion. */
public object ProCareerRecognitionRules {
    public const val STRIKEOUTS: String = "pro.award.strikeouts"
    public const val RUN_PREVENTION: String = "pro.award.run-prevention"
    public const val COMMAND: String = "pro.award.command"
    public const val HITS: String = "pro.award.hits"
    public const val INNINGS: String = "pro.award.innings"

    public fun awardContentIDs(stats: ProSeasonStats, rulesVersion: Int): List<String> {
        val ids = mutableListOf<String>()
        if (rulesVersion >= 2) {
            if (stats.strikeouts >= 180) ids += STRIKEOUTS
            if (stats.games >= 20 && stats.inningsOuts >= 360 && stats.runPerNinePermille < 2_700) ids += RUN_PREVENTION
            val bb9 = ninePermille(stats.walks, stats.inningsOuts)
            if (bb9 < 1_800 && stats.inningsOuts >= 360) ids += COMMAND
            val h9 = ninePermille(stats.hits, stats.inningsOuts)
            if (h9 < 7_500 && stats.inningsOuts >= 360) ids += HITS
            if (stats.inningsOuts >= 486) ids += INNINGS
        } else {
            if (stats.strikeouts >= 120) ids += STRIKEOUTS
            if (stats.runPerNinePermille < 3_000 && stats.games >= 20) ids += RUN_PREVENTION
            val bb9 = ninePermille(stats.walks, stats.inningsOuts)
            if (bb9 < 2_500 && stats.inningsOuts >= 180) ids += COMMAND
            val h9 = ninePermille(stats.hits, stats.inningsOuts)
            if (h9 < 8_500 && stats.inningsOuts >= 180) ids += HITS
            if (stats.inningsOuts >= 360) ids += INNINGS
        }
        return ids
    }

    public fun awardLabel(contentId: String, season: Int): String = when (contentId) {
        STRIKEOUTS -> "시즌 $season 탈삼진상"
        RUN_PREVENTION -> "시즌 $season 최소 실점상"
        COMMAND -> "시즌 $season 정밀 제구상"
        HITS -> "시즌 $season 피안타 억제상"
        INNINGS -> "시즌 $season 이닝 책임상"
        else -> "시즌 $season 수상"
    }

    private fun ninePermille(count: Int, inningsOuts: Int): Int =
        if (inningsOuts == 0) 9_990 else count * 27_000 / inningsOuts
}
