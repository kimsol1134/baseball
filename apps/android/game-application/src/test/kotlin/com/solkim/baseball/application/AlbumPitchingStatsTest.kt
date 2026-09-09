package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import kotlin.test.*

class AlbumPitchingStatsTest {
    @Test fun completeGamesRequireEvidenceAndShutoutsUseRunsNotEarnedRuns() {
        val old = CareerGameView("pro:p:1:1:1", "경기", 27, 9, 0, 1, 3, 1, 2, 0, true, started = true)
        assertEquals("—", AlbumPitchingStats.from(old).line.toMap()["CG"])
        val unearned = old.copy(runs = 1, opponent = 1, earnedRuns = 0, completeGame = true)
        val shutout = old.copy(earnedRuns = 0, completeGame = true)
        assertEquals("1", AlbumPitchingStats.from(unearned).line.toMap()["CG"])
        assertEquals("0", AlbumPitchingStats.from(unearned).line.toMap()["SHO"])
        assertEquals("1", AlbumPitchingStats.from(shutout).line.toMap()["SHO"])
        val page = PlayerAlbumPage(RecordScope("pro:p:1", "시즌", "투수"), 1, 27, 0, 9, true, listOf(shutout))
        assertEquals(page, PlayerAlbumCodec.decode(PlayerAlbumCodec.encode(listOf(page))).single())
    }

    @Test fun earnedRunsRemainDistinctFromScoreboardAndSurviveAlbumEncoding() {
        val row = CareerGameView("pro:p:1:1:1", "경기", 18, 6, 3, 2, 4, 1, 4, 3, true, earnedRuns = 2)
        val page = PlayerAlbumPage(RecordScope("pro:p:1", "시즌", "선수"), 1, 18, 3, 6, true, listOf(row))
        assertEquals(page, PlayerAlbumCodec.decode(PlayerAlbumCodec.encode(listOf(page))).single())
        val stats = AlbumPitchingStats.from(page)
        assertEquals("3.00", stats.rates.toMap()["ERA"])
        assertEquals("4.50", stats.rates.toMap()["RA/9"])
    }
    @Test fun fractionalInningsUseOutsAndRatesRoundToTwoPlaces() {
        val stats = AlbumPitchingStats(1, 7, 5, 1, 3, 1)
        assertEquals("2.1", stats.innings)
        assertEquals("1.71", stats.whip)
        assertEquals(mapOf("ERA" to "—", "WHIP" to "1.71", "K/9" to "19.29", "BB/9" to "3.86", "H/9" to "11.57", "K/BB" to "5.00", "RA/9" to "3.86"), stats.rates.toMap())
        assertEquals("—", stats.rates.toMap()["ERA"])
    }
    @Test fun missingHistoryAndZeroDenominatorsAreNeverShownAsPerfectStats() {
        assertEquals("—", AlbumPitchingStats(0, 0, 0, 0, 0, 0).whip)
        assertEquals("—", AlbumPitchingStats(1, 18, 7, 0, 1, 0).rates.toMap()["K/BB"])
        val page = PlayerAlbumPage(RecordScope("hs:old", "고교", "선수"), 10, 60, 8, 19, true, emptyList())
        val stats = AlbumPitchingStats.from(page)
        assertEquals("—", stats.whip)
        assertEquals("—", stats.line.toMap()["H"])
        assertEquals("8.55", stats.rates.toMap()["K/9"])
    }
    @Test fun archivedProTotalsBackfillDetailedStatsWithoutInventingGameLines() {
        val p = ProKernel().startDirect(ProStartDirectRequest("918220", "power_prospect", "통산투수")).state
        val history = p.currentStats.copy(season = 1, games = 20, inningsOuts = 180, hits = 44, walks = 16, strikeouts = 72, wins = 6, losses = 2, saves = 1, starts = 10, homeRuns = 3, pitches = 920)
        val pro = p.copy(season = 2, careerStats = listOf(history), currentStats = p.currentStats.copy(season = 2), currentGameLines = emptyList())
        val state = GameAggregateState.initial("stats").copy(stage = GameStage.PRO, pro = pro)
        assertEquals("1.00", AlbumPitchingStats.from(CareerRecordPresentation.resolve(state)!!).whip)
        val page = PlayerAlbum.pages(state).single { it.scope.id.endsWith(":1") }
        val stats = AlbumPitchingStats.from(page)
        assertEquals("1.00", stats.whip)
        assertEquals("10.80", stats.rates.toMap()["K/9"])
        assertEquals("920", stats.line.toMap()["NP"])
        assertEquals("6", stats.line.toMap()["W"])
        assertTrue(page.rows.isEmpty())
        assertEquals(page, PlayerAlbumCodec.decode(PlayerAlbumCodec.encode(listOf(page))).single())
    }
}
