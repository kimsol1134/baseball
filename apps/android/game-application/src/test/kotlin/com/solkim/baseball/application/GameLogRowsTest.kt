package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPitchingDecision
import com.solkim.baseball.core.highschool.HighSchoolSeasonLine
import com.solkim.baseball.core.pro.ProGameLine
import com.solkim.baseball.core.pro.ProPitchingDecision
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GameLogRowsTest {
    private fun highSchoolLine(regular: Boolean, perfect: Int) = HighSchoolSeasonLine(
        careerId = "career", lifeNumber = 1, chapter = 3, gameNumber = 2, pitches = 41,
        strikeouts = 5, walks = 1, runsAllowed = 2, expectedDamage = 300, actualDamage = 280,
        abilityMoments = emptyList(), outs = 7, teamRuns = 4, opponentRuns = 3,
        decision = HighSchoolPitchingDecision.WIN, hits = 3, regular = regular, perfectReleases = perfect,
    )

    @Test fun inningsFollowThirdsAndNeverShowRawOuts() {
        assertEquals("0.0이닝", inningsLabel(0))
        assertEquals("2.1이닝", inningsLabel(7))
        assertEquals("6.0이닝", inningsLabel(18))
    }

    @Test fun highSchoolRowSeparatesRegularGamesFromKeyGamesAndShowsPerfect() {
        val key = highSchoolGameRow(highSchoolLine(regular = false, perfect = 0))
        assertEquals("3장 승부처", key.label)
        assertEquals("2.1이닝 2실점 · 5탈삼진", key.value)
        assertTrue("퍼펙트" !in key.detail, "no perfect line must stay quiet: ${key.detail}")
        val regular = highSchoolGameRow(highSchoolLine(regular = true, perfect = 2))
        assertEquals("3장 정규", regular.label)
        assertTrue(regular.detail.contains("퍼펙트 2"), regular.detail)
        assertTrue(regular.detail.contains("4-3"), regular.detail)
    }

    @Test fun proRowNamesTheOutingRoleAndCarriesPerfect() {
        val line = ProGameLine(
            season = 2, week = 9, outingNumber = 4, started = true, outs = 18, strikeouts = 8,
            walks = 2, runsAllowed = 1, pitches = 95, teamRuns = 5, opponentRuns = 1,
            decision = ProPitchingDecision.WIN, played = true, hits = 4, perfectReleases = 3,
        )
        val row = proGameRow(line)
        assertEquals("9주차 선발", row.label)
        assertEquals("6.0이닝 1실점 · 8탈삼진", row.value)
        assertTrue(row.detail.contains("퍼펙트 3"), row.detail)
        assertEquals("9주차 구원", proGameRow(line.copy(started = false)).label)
    }

    @Test fun perfectSuffixOnlyAppearsWhenSomethingWasEarned() {
        assertEquals("", proPerfectSuffix(0))
        assertEquals(" · 퍼펙트 4", proPerfectSuffix(4))
    }
}

class ProCareerPerfectTest {
    private fun stats(season: Int, perfect: Int) = com.solkim.baseball.core.pro.ProSeasonStats(
        season = season, teamId = "team", perfectReleases = perfect,
    )

    @Test fun theSeasonBeingPlayedCountsOnceAndNeverTwiceAfterItIsArchived() {
        val kernel = com.solkim.baseball.core.pro.ProKernel()
        val base = kernel.startDirect(com.solkim.baseball.core.pro.ProStartDirectRequest("7", "power_prospect", "민서준")).state
        val playing = base.copy(careerStats = listOf(stats(1, 4)), currentStats = stats(2, 3))
        assertEquals(7, proCareerPerfect(playing))
        // Between the season review and the next opening the archived season also sits in currentStats.
        val archived = base.copy(careerStats = listOf(stats(1, 4), stats(2, 3)), currentStats = stats(2, 3))
        assertEquals(7, proCareerPerfect(archived))
        assertEquals(0, proCareerPerfect(null))
    }
}
