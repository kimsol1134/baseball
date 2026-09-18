package com.solkim.baseball.application

import java.math.BigDecimal
import java.math.RoundingMode

/** Baseball innings are outs/3, never the decimal-looking IP display string. */
public data class AlbumPitchingStats(
    val games: Int, val outs: Int, val strikeouts: Int, val runs: Int,
    val hits: Int?, val walks: Int?, val starts: Int? = null, val wins: Int? = null,
    val losses: Int? = null, val saves: Int? = null, val homeRuns: Int? = null, val pitches: Int? = null,
    val inningsKnown: Boolean = true,
    val earnedRuns: Int? = null,
    val completeGames: Int? = null, val shutouts: Int? = null,
) {
    public val innings: String get() = if (inningsKnown) "${outs / 3}.${outs % 3}" else "—"
    private fun rate(count: Int?, factor: Int, denominator: Int = outs): String {
        if (!inningsKnown || count == null || denominator <= 0) return "—"
        return BigDecimal.valueOf(count.toLong()).multiply(BigDecimal.valueOf(factor.toLong()))
            .divide(BigDecimal.valueOf(denominator.toLong()), 2, RoundingMode.HALF_UP).toPlainString()
    }
    public val whip: String get() = rate(if (hits != null && walks != null) hits + walks else null, 3)
    public val rates: List<Pair<String, String>> get() = listOf(
        "ERA" to rate(earnedRuns, 27), "WHIP" to whip, "K/9" to rate(strikeouts, 27), "BB/9" to rate(walks, 27),
        "H/9" to rate(hits, 27), "K/BB" to rate(strikeouts, 1, walks ?: 0), "RA/9" to rate(runs, 27),
    )
    public val line: List<Pair<String, String>> get() = listOf(
        "G" to games.toString(), "GS" to display(starts), "W" to display(wins), "L" to display(losses), "SV" to display(saves), "IP" to innings,
        "H" to display(hits), "HR" to display(homeRuns), "BB" to display(walks), "SO" to strikeouts.toString(), "R" to runs.toString(), "ER" to display(earnedRuns), "NP" to display(pitches), "CG" to display(completeGames), "SHO" to display(shutouts),
    )
    private fun display(value: Int?): String = value?.toString() ?: "—"
    public companion object {
        public fun from(record: CareerRecordView): AlbumPitchingStats = from(PlayerAlbumPage(record.scope, record.games, record.outs, record.runs, record.strikeouts,
            record.inningsKnown, record.rows, details = record.details))
        public fun from(page: PlayerAlbumPage): AlbumPitchingStats {
            val d = page.details
            if (d.isEmpty() && page.rows.size == page.games && page.rows.sumOf { it.outs } == page.outs && page.inningsKnown) {
                return AlbumPitchingStats(page.games, page.outs, page.strikeouts, page.runs, page.rows.sumOf { it.hits }, page.rows.sumOf { it.walks },
                    wins = if (page.rows.all { it.decision.isNotBlank() }) page.rows.count { it.decision == "win" } else null,
                    losses = if (page.rows.all { it.decision.isNotBlank() }) page.rows.count { it.decision == "loss" } else null,
                    saves = if (page.rows.all { it.decision.isNotBlank() }) page.rows.count { it.decision == "save" } else null,
                    homeRuns = if (page.rows.all { it.homeRuns != null }) page.rows.sumOf { it.homeRuns ?: 0 } else null,
                    pitches = if (page.rows.all { it.pitches != null }) page.rows.sumOf { it.pitches ?: 0 } else null,
                    earnedRuns = if (page.rows.all { it.earnedRuns != null }) page.rows.sumOf { it.earnedRuns ?: 0 } else null,
                    completeGames = if (page.rows.all { it.completeGame != null }) page.rows.count { it.completeGame == true } else null,
                    shutouts = if (page.rows.all { it.completeGame != null }) page.rows.count { it.isShutout } else null)
            }
            return AlbumPitchingStats(page.games, page.outs, page.strikeouts, page.runs,
                d.getOrNull(0), d.getOrNull(1), d.getOrNull(5), d.getOrNull(2), d.getOrNull(3), d.getOrNull(4), d.getOrNull(6), d.getOrNull(7), page.inningsKnown, d.getOrNull(8), d.getOrNull(9), d.getOrNull(10))
        }
        public fun from(game: CareerGameView): AlbumPitchingStats = AlbumPitchingStats(1, game.outs, game.strikeouts, game.runs,
            game.hits, game.walks, if (game.started) 1 else if (game.id.startsWith("hs:")) null else 0, if (game.decision.isBlank()) null else if (game.decision == "win") 1 else 0,
            if (game.decision.isBlank()) null else if (game.decision == "loss") 1 else 0, if (game.decision.isBlank()) null else if (game.decision == "save") 1 else 0, game.homeRuns, game.pitches, earnedRuns = game.earnedRuns, completeGames = game.completeGame?.let { if (it) 1 else 0 }, shutouts = game.completeGame?.let { if (game.isShutout) 1 else 0 })
    }
}
