package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.*
import org.junit.Test
import kotlin.test.assertTrue

class ProfessionalBalanceTest {
    @Test fun roleBudgetsAndStableOpponents() {
        fun outings(role: ProRole) = (1..24).sumOf { weeklyOutingBudget(role, it, 12).first }
        kotlin.test.assertEquals(28, outings(ProRole.STARTER))
        kotlin.test.assertEquals(60, outings(ProRole.CLOSER))
        kotlin.test.assertEquals(60, outings(ProRole.SETUP))
        val lineup = (1..9).map { ProfessionalLineup.batter("opponent", it) }
        kotlin.test.assertEquals(lineup, (10..18).map { ProfessionalLineup.batter("opponent", it) })
        assertTrue(lineup.maxOf { it.power } - lineup.minOf { it.power } >= 20)
    }
    @Test fun realisticEliteStarterAndCloserCanReachTheHallWithoutInflatedStrikeouts() {
        val kernel = ProKernel()
        val start = kernel.startDirect(ProStartDirectRequest("918220", "power_prospect", "검증투수")).state
        fun projection(closer: Boolean, elite: Boolean): Int {
            val seasons = (1..20).map { ProSeasonStats(it, start.team.id, games = if (closer) 60 else 28,
                starts = if (closer) 0 else 28, inningsOuts = if (closer) 180 else 486,
                strikeouts = if (closer) 75 else if (elite) 185 else 140,
                runsAllowed = if (closer) 19 else if (elite) 52 else 90,
                earnedRuns = if (closer) 17 else if (elite) 45 else 81,
                wins = if (closer) 0 else if (elite) 14 else 10, saves = if (closer) 25 else 0) }
            return kernel.hallOfFameProjection(start.copy(careerStats = seasons, currentStats = seasons.last(), serviceYears = 20))
        }
        assertTrue(projection(false, true) >= 70)
        assertTrue(projection(true, true) >= 70)
        assertTrue(projection(false, false) < 70)
    }
    @Test fun perfectDeliveryAndHighMasteryStillAllowHitsAndRuns() {
        val simulator = ProAutomaticOutingSimulator(PitchKernel(professionalBalance = true), professionalBalance = true)
        val pitcher = PitcherSnapshot("elite", "완성형 투수", 80, 80, 80, 80, mastery = AbilityMasterySnapshot(100, 100, 100, 100))
        val lines = (1..120).map { simulator.simulate(pitcher, 10, 18, 100, it.toULong() * 772019UL,
            diverseScouting = true, delivery = PitchDelivery(1000, 1000)) }
        val k9 = lines.sumOf { it.strikeouts } * 27.0 / lines.sumOf { it.outs }
        assertTrue(k9 < 15.0, "perfect release became automatic strikeouts: $k9")
        assertTrue(lines.sumOf { it.hits } > 100)
        assertTrue(lines.sumOf { it.runsAllowed } > 20)
        println("PERFECT_MASTERY K9=$k9 H=${lines.sumOf { it.hits }} R=${lines.sumOf { it.runsAllowed }}")
    }
    @Test fun calibratedPitcherDistribution() {
        val simulator = ProAutomaticOutingSimulator(PitchKernel(professionalBalance = true), professionalBalance = true)
        for (rating in listOf(45, 50, 55, 60, 70, 80)) {
            val pitcher = PitcherSnapshot("audit", "검증 투수", rating, rating, rating, rating)
            val lines = (1..120).map { simulator.simulate(pitcher, 10, 18, 100, it.toULong() * 918221UL, diverseScouting = true) }
            val outs = lines.sumOf { it.outs }.toDouble()
            val k9 = lines.sumOf { it.strikeouts } * 27 / outs
            val ra9 = lines.sumOf { it.runsAllowed } * 27 / outs
            val whip = lines.sumOf { it.hits + it.walks } * 3 / outs
            println("PROBE rating=$rating K9=$k9 RA9=$ra9 ERA=${lines.sumOf { it.earnedRuns ?: 0 } * 27 / outs} WHIP=$whip BB9=${lines.sumOf { it.walks } * 27 / outs} HR9=${lines.sumOf { it.homeRuns } * 27 / outs}")
            assertTrue(lines.all { it.strikeouts <= it.outs && it.earnedRuns != null && it.earnedRuns in 0..it.runsAllowed })
            assertTrue(lines.any { it.earnedRuns!! < it.runsAllowed }, "errors must create genuinely unearned runs")
            assertTrue(k9 in 3.0..13.0, "unbounded strikeouts at $rating: $k9")
            if (rating == 55) {
                assertTrue(k9 in 6.0..9.0); assertTrue(whip in 1.25..1.65)
                assertTrue(ra9 in 3.5..6.0)
            }
            if (rating == 80) assertTrue(whip in 0.85..1.35)
        }
    }
}
