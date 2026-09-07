package com.solkim.baseball.core.pro

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ProNationalTeamTest {
    private val kernel = ProKernel()

    @Test
    fun evenSeasonWithFanSupportOpensTheCallAndDeclineDropsFan() {
        var result = eligibleCall(seed = "940101", fanSupport = 60)
        assertEquals(ProCareerPhase.NATIONAL_TEAM_CALL, result.state.phase)
        assertTrue(ProKernel.shouldOfferNationalTeam(result.state))
        val seed = result.nextSeed
        val fanBefore = result.state.journeyState?.reputation?.fanSupport ?: 0
        result = kernel.respondToNationalTeamCall(result.state, seed, accepted = false)
        assertEquals(seed, result.nextSeed)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, result.state.phase)
        assertEquals(fanBefore - 2, result.state.journeyState?.reputation?.fanSupport)
        assertEquals("국가대표 소집을 정중히 거절했다.", result.state.news.first())
        assertTrue(result.events.contains("pro_national_team_called"))
        assertNull(result.state.nationalTournament)
        val roundTripped = ProStateCodec.decode(ProStateCodec.encode(result.state))
        assertEquals(result.state, roundTripped)
    }

    @Test
    fun recordedLegacyCallSurvivesEligibilityUpdateAndCanBeAnswered() {
        val issued = eligibleCall(seed = "940101", fanSupport = 60).state
        val legacy = issued.copy(pitcher = issued.pitcher.copy(stuff = 20, command = 20, movement = 20, stamina = 20),
            awards = listOf("시즌 1 탈삼진상"), journeyState = issued.journeyState!!.copy(reputation = issued.journeyState.reputation.copy(fanSupport = 0),
                recognitions = issued.journeyState.recognitions.filterNot { it.season == issued.season && it.kind == ProCareerRecognitionKind.AWARD }), commitment = "")
        assertFalse(ProKernel.shouldOfferNationalTeam(legacy))
        val signed = legacy.copy(commitment = kernel.commitment(legacy))
        val restored = ProStateCodec.decode(ProStateCodec.encode(signed))
        val answered = kernel.respondToNationalTeamCall(restored, restored.seed, false)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, answered.state.phase)
        assertEquals(restored.seed, answered.nextSeed)
    }

    @Test
    fun oddSeasonAndV9DoNotOpenTheCall() {
        val odd = settledSeason(seed = "940102", season = 1, fanSupport = 80)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, odd.state.phase)
        assertFalse(ProKernel.shouldOfferNationalTeam(odd.state))

        val v9 = settledSeason(seed = "940103", season = 2, fanSupport = 80, proRulesVersion = 9)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, v9.state.phase)
        assertFalse(ProKernel.usesNationalTeamRules(v9.state))
        assertFalse(ProKernel.shouldOfferNationalTeam(v9.state))
    }

    @Test
    fun acceptSimulatesThreeGroupGamesWithoutConsumingOffseasonSeed() {
        var result = eligibleCall(seed = "940104", fanSupport = 70)
        val seed = result.nextSeed
        result = kernel.respondToNationalTeamCall(result.state, seed, accepted = true)
        assertEquals(seed, result.nextSeed)
        val tournament = assertNotNull(result.state.nationalTournament)
        assertEquals(3, tournament.groupGames.size)
        assertEquals(seed, tournament.resumeSeed)
        if (tournament.stage == ProNationalTournamentStage.AWAITING_FINAL) {
            assertTrue(tournament.groupWins >= 2)
            assertNull(tournament.result)
            assertEquals(ProCareerPhase.NATIONAL_TOURNAMENT, result.state.phase)
        } else {
            assertNotNull(tournament.result)
            assertEquals(ProNationalTournamentStage.RESULT, tournament.stage)
        }
        val roundTripped = ProStateCodec.decode(ProStateCodec.encode(result.state))
        assertEquals(result.state, roundTripped)
        assertEquals(3, roundTripped.nationalTournament?.groupGames?.size)
    }

    @Test
    fun goldPathExemptsMilitaryAndCarryAppliesNextSpring() {
        var result = eligibleCall(seed = "940105", fanSupport = 70)
        assertFalse(result.state.militaryCompleted)
        val fanBefore = result.state.journeyState?.reputation?.fanSupport ?: 0
        result = kernel.respondToNationalTeamCall(result.state, result.nextSeed, accepted = true)
        if (result.state.nationalTournament?.stage != ProNationalTournamentStage.AWAITING_FINAL) {
            result = forceAwaitingFinal(result)
        }
        val awaiting = result
        val started = kernel.startNationalFinal(awaiting.state, awaiting.nextSeed)
        assertEquals(ProCareerPhase.IMPORTANT_GAME, started.state.phase)
        assertEquals(ProSeasonTrigger.NATIONAL_FINAL, started.state.seasonTrigger)
        val seed = awaiting.nextSeed
        result = kernel.resolveNationalFinalAutomatically(awaiting.state, seed)
        assertEquals(seed, result.nextSeed)
        assertEquals(ProCareerPhase.NATIONAL_TOURNAMENT, result.state.phase)
        val tournament = assertNotNull(result.state.nationalTournament)
        assertTrue(tournament.result == ProNationalTournamentResult.GOLD || tournament.result == ProNationalTournamentResult.SILVER)
        if (tournament.result == ProNationalTournamentResult.GOLD || tournament.result == ProNationalTournamentResult.SILVER) {
            assertEquals(true, result.state.journeyState?.reputation?.overseasInterest)
        }
        if (tournament.result == ProNationalTournamentResult.GOLD) {
            assertTrue(tournament.exempted)
            assertTrue(result.state.militaryCompleted)
            assertEquals(
                minOf(100, fanBefore + ProNationalTeamRules.GOLD_FAN_DELTA),
                result.state.journeyState?.reputation?.fanSupport,
            )
            assertTrue(result.state.journeyState?.recognitions.orEmpty().any { it.contentId == "pro.award.national-gold" })
            assertTrue(result.state.milestones.contains("대표팀 금메달"))
            val beforeGoldBonus = kernel.hallOfFameProjection(result.state.copy(nationalTeamHistory = emptyList()))
            assertEquals(minOf(100, beforeGoldBonus + 4), kernel.hallOfFameProjection(result.state))
        }
        assertEquals(tournament.result, result.state.nationalTeamHistory.last().result)
        val carry = assertNotNull(result.state.nationalTeamCarry)
        result = kernel.acknowledgeNationalTeamResult(result.state, result.nextSeed)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, result.state.phase)
        assertNull(result.state.nationalTournament)
        assertEquals(seed, result.nextSeed)
        val investment = kernel.chooseOffseason(result.state, result.nextSeed, OffseasonDecision.CONTINUE)
        assertEquals(ProCareerPhase.OFFSEASON_INVESTMENT, investment.state.phase)
        assertEquals(carry, investment.state.nationalTeamCarry)
        val restoredInvestment = ProStateCodec.decode(ProStateCodec.encode(investment.state))
        val continued = kernel.chooseInvestment(restoredInvestment, investment.nextSeed, ProOffseasonInvestment.NONE, null)
        assertEquals(result.state.season + 1, continued.state.season)
        assertEquals(ProCareerPhase.WEEKLY_PLAN, continued.state.phase)
        assertEquals(carry.fatigue, continued.state.fatigue)
        assertEquals(carry.injuryWeeks, continued.state.injuryWeeks)
        assertNull(continued.state.nationalTeamCarry)
        val roundTripped = ProStateCodec.decode(ProStateCodec.encode(continued.state))
        assertEquals(continued.state, roundTripped)
    }

    @Test
    fun alreadyCompletedMilitaryGetsLargerFanBonusOnGold() {
        var result = eligibleCall(seed = "940106", fanSupport = 60, militaryCompleted = true)
        val fanBefore = result.state.journeyState?.reputation?.fanSupport ?: 0
        result = kernel.respondToNationalTeamCall(result.state, result.nextSeed, accepted = true)
        if (result.state.nationalTournament?.stage != ProNationalTournamentStage.AWAITING_FINAL) {
            result = forceAwaitingFinal(result)
        }
        val unsigned = result.state.copy(commitment = "")
        val signed = unsigned.copy(commitment = kernel.commitment(unsigned))
        result = kernel.resolveNationalFinalAutomatically(signed, result.nextSeed)
        val tournament = assertNotNull(result.state.nationalTournament)
        assertTrue(tournament.result == ProNationalTournamentResult.GOLD || tournament.result == ProNationalTournamentResult.SILVER)
        assertTrue(result.state.militaryCompleted)
        if (tournament.result == ProNationalTournamentResult.GOLD) {
            assertFalse(tournament.exempted)
            assertEquals(
                minOf(100, fanBefore + ProNationalTeamRules.GOLD_FAN_DELTA_ALREADY_COMPLETED),
                result.state.journeyState?.reputation?.fanSupport,
            )
        }
        val pitches = tournament.finalLine?.playerPitches ?: 0
        assertEquals(ProNationalTeamRules.fatigueCarry(pitches), result.state.nationalTeamCarry?.fatigue)
    }

    @Test
    fun headlessFinalResolvesFromTournamentSeedWithoutConsumingCareerSeed() {
        var result = eligibleCall(seed = "940108", fanSupport = 70)
        result = kernel.respondToNationalTeamCall(result.state, result.nextSeed, accepted = true)
        if (result.state.nationalTournament?.stage != ProNationalTournamentStage.AWAITING_FINAL) {
            result = forceAwaitingFinal(result)
        }
        val seed = result.nextSeed
        val first = kernel.resolveNationalFinalAutomatically(result.state, seed)
        val replayed = kernel.resolveNationalFinalAutomatically(result.state, seed)
        assertEquals(seed, first.nextSeed)
        assertEquals(seed, replayed.nextSeed)
        assertEquals(ProCareerPhase.NATIONAL_TOURNAMENT, first.state.phase)
        assertEquals(false, first.state.nationalTournament?.finalLine?.directlyPlayed)
        assertTrue(
            first.state.nationalTournament?.result == ProNationalTournamentResult.GOLD ||
                first.state.nationalTournament?.result == ProNationalTournamentResult.SILVER,
        )
        assertEquals(first.state.nationalTournament?.result, replayed.state.nationalTournament?.result)
        assertEquals(first.state.nationalTournament?.finalLine, replayed.state.nationalTournament?.finalLine)
        assertTrue(first.events.contains("pro_national_final_simulated"))
        val acknowledged = kernel.acknowledgeNationalTeamResult(first.state, first.nextSeed)
        assertEquals(ProCareerPhase.OFFSEASON_DECISION, acknowledged.state.phase)
        assertEquals(seed, acknowledged.nextSeed)
        assertNull(acknowledged.state.nationalTournament)
    }

    @Test
    fun finalBatterOffsetMatchesAutumnChampionship() {
        assertEquals(6, ProNationalTeamRules.FINAL_BATTER_OFFSET)
        assertEquals(ProNationalTeamRules.FINAL_BATTER_OFFSET, ProPostseasonRules.extraOffset(ProAutumnRound.FINAL))
    }

    private fun eligibleCall(
        seed: String,
        fanSupport: Int,
        militaryCompleted: Boolean = false,
    ): ProResult = settledSeason(seed, season = 2, fanSupport = fanSupport, militaryCompleted = militaryCompleted)

    private fun settledSeason(
        seed: String,
        season: Int,
        fanSupport: Int,
        militaryCompleted: Boolean = false,
        proRulesVersion: Int = 10,
    ): ProResult {
        val started = kernel.startDirect(ProStartDirectRequest(seed, "power_prospect", "대표투수"))
        val journey = requireNotNull(started.state.journeyState)
        val unsigned = started.state.copy(
            phase = ProCareerPhase.SEASON_REVIEW,
            season = season,
            age = 18 + season,
            week = ProCatalog.WEEKS_PER_SEASON,
            seasonSegment = ProCatalog.segment(ProCatalog.WEEKS_PER_SEASON),
            militaryCompleted = militaryCompleted,
            proRulesVersion = proRulesVersion,
            currentStats = started.state.currentStats.copy(season = season),
            journeyState = journey.copy(reputation = journey.reputation.copy(fanSupport = fanSupport)),
            commitment = "",
        )
        val reviewed = unsigned.copy(commitment = kernel.commitment(unsigned))
        kernel.validateSavedState(reviewed)
        val afterReview = kernel.reviewSeason(reviewed, started.nextSeed)
        val settlementId = afterReview.state.journeyState?.lastSettlement?.id ?: return afterReview
        if (afterReview.state.phase != ProCareerPhase.SEASON_SETTLEMENT) return afterReview
        return kernel.acknowledgeSeasonSettlement(afterReview.state, afterReview.nextSeed, settlementId)
    }

    private fun forceAwaitingFinal(result: ProResult): ProResult {
        val tournament = requireNotNull(result.state.nationalTournament)
        val unsigned = result.state.copy(
            phase = ProCareerPhase.NATIONAL_TOURNAMENT,
            nationalTournament = tournament.copy(
                stage = ProNationalTournamentStage.AWAITING_FINAL,
                result = null,
                finalLine = null,
            ),
            commitment = "",
        )
        val signed = unsigned.copy(commitment = kernel.commitment(unsigned))
        kernel.validateSavedState(signed)
        return result.copy(state = signed)
    }
}
