package com.solkim.baseball.core.pro

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ProCareerRetiredNumberBalanceTest {
    @Test
    fun v2AttendanceStarterIsNotRetiredNumber() {
        val record = record(seasons = 8, strikeouts = 640, outs = 2_400, awards = 0)
        assertEquals(52, ProTeamLegacyRules.score(record, 2))
        assertEquals(ProTeamLegacyTier.CLUB_ACE, ProTeamLegacyRules.tier(record, 2))
    }

    @Test
    fun v2FaceCareerClearsRetiredNumberScore() {
        val record = record(seasons = 8, strikeouts = 1_200, outs = 3_600, awards = 3)
        assertEquals(87, ProTeamLegacyRules.score(record, 2))
        assertEquals(ProTeamLegacyTier.RETIRED_NUMBER_CANDIDATE, ProTeamLegacyRules.tier(record, 2))
    }

    @Test
    fun v1AttendanceFormulaStaysFrozen() {
        val record = record(seasons = 8, strikeouts = 1_000, outs = 0, awards = 0, community = 7)
        assertEquals(80, ProTeamLegacyRules.score(record, 1))
    }

    @Test
    fun v2AwardsNeedPeakSeasons() {
        val attendance = ProSeasonStats(season = 1, teamId = "t", games = 24, inningsOuts = 360, strikeouts = 150, walks = 40, runsAllowed = 40, hits = 120)
        assertTrue(ProCareerRecognitionRules.awardContentIDs(attendance, 1).contains(ProCareerRecognitionRules.STRIKEOUTS))
        assertFalse(ProCareerRecognitionRules.awardContentIDs(attendance, 2).contains(ProCareerRecognitionRules.STRIKEOUTS))
        val peak = attendance.copy(strikeouts = 180, inningsOuts = 486, runsAllowed = 40, walks = 20, hits = 90)
        assertTrue(ProCareerRecognitionRules.awardContentIDs(peak, 2).contains(ProCareerRecognitionRules.STRIKEOUTS))
        assertTrue(ProCareerRecognitionRules.awardContentIDs(peak, 2).contains(ProCareerRecognitionRules.INNINGS))
    }

    @Test
    fun retirementPreviewUsesVersionedLegacyScore() {
        val v2Record = record(seasons = 8, strikeouts = 640, outs = 2_400, awards = 0)
        val state = ProCareerJourneyState(
            rulesVersion = 2,
            teamRecords = listOf(v2Record),
            reputation = ProReputationState(fanSupport = 80),
        )
        val preview = ProJourneyKernel.retirementPreview(state, v2Record.teamId)
        assertFalse(preview.retiredNumberEligible)
        assertEquals(52, preview.lastTeamLegacy)
    }

    @Test
    fun developmentTicksMatchLiveIosTable() {
        assertEquals(2, ProKernel.developmentTicksRequired(54))
        assertEquals(3, ProKernel.developmentTicksRequired(55))
        assertEquals(3, ProKernel.developmentTicksRequired(64))
        assertEquals(4, ProKernel.developmentTicksRequired(65))
        assertEquals(4, ProKernel.developmentTicksRequired(72))
        assertEquals(6, ProKernel.developmentTicksRequired(73))
        assertEquals(6, ProKernel.developmentTicksRequired(80))
    }

    @Test
    fun liveOutingOffsetFollowsSeason() {
        assertEquals(0, ProKernel.liveOutingOffset(1))
        assertEquals(1, ProKernel.liveOutingOffset(2))
        assertEquals(8, ProKernel.liveOutingOffset(9))
        assertEquals(8, ProKernel.liveOutingOffset(20))
    }

    private fun record(
        seasons: Int,
        strikeouts: Int,
        outs: Int,
        awards: Int,
        community: Int = 0,
    ): ProTeamCareerRecord = ProTeamCareerRecord(
        teamId = "harbor",
        completedSeasons = seasons,
        consecutiveSeasons = seasons,
        games = seasons * 24,
        starts = seasons * 24,
        inningsOuts = outs,
        strikeouts = strikeouts,
        wins = 0,
        saves = 0,
        awardCount = awards,
        communityPoints = community,
        lastSeason = seasons,
    )
}
