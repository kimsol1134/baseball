package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.*
import kotlin.test.*

class AceOutingTest {
    @Test fun exhaustedPitcherDoesNotReceivePhantomAppearancesOrPerformanceTrust() {
        val kernel = ProKernel()
        val start = kernel.startDirect(ProStartDirectRequest("918220", "power_prospect", "회복투수")).state
        val tired = start.copy(role = ProRole.STARTER, rolePreference = ProRole.STARTER, fatigue = 100, commitment = "").let { it.copy(commitment = kernel.commitment(it)) }
        assertEquals(0, proWeekForecast(tired, ProWeekPlan.RECOVER).outings)
        val next = kernel.planWeek(tired, "99881", ProWeekPlan.RECOVER).state
        assertEquals(0, next.currentStats.games); assertEquals(0, next.currentStats.starts); assertEquals(0, next.currentStats.pitches)
        assertTrue(next.fatigue < tired.fatigue); assertTrue(next.managerTrust <= tired.managerTrust)
    }
    @Test fun balancedMaxRatingsDoNotLoseTheStaminaBenefit() {
        val endurance = PitcherSnapshot("p", "투수", 50, 50, 50, 80)
        val elite = endurance.copy(stuff = 80, command = 80, movement = 80)
        assertEquals(ProOutingUsageRules.pitchBudget(endurance), ProOutingUsageRules.pitchBudget(elite))
        for (outs in listOf(18, 21, 24)) assertTrue(ProOutingUsageRules.canContinue(elite, outs, 80, 30, 0, true))
        assertFalse(ProOutingUsageRules.canContinue(elite, 27, 95, 30, 0, true))
        assertFalse(ProOutingUsageRules.canContinue(elite, 21, 126, 30, 0, true))
        assertFalse(ProOutingUsageRules.canContinue(elite, 21, 70, 100, 0, true))
        assertFalse(ProOutingUsageRules.canContinue(elite, 18, 70, 30, 6, true))
    }
    @Test fun fullyDevelopedRealRepertoireCanFinishNineInnings() {
        val raw = ProCatalog.pitcherForPreset("power_prospect", "에이스")
        val pitcher = raw.copy(stuff = 80, command = 80, movement = 80, stamina = 80,
            pitchProfiles = raw.pitchProfiles!!.map { it.copy(control = 80, command = 80, movement = 80, whiff = 80, weakContact = 80,
                velocityTenthsKph = when(it.pitchType) { PitchKind.FOUR_SEAM -> 1550; PitchKind.SLIDER -> 1380; PitchKind.CURVEBALL -> 1200; PitchKind.CHANGEUP -> 1370 }) })
        val sim = ProAutomaticOutingSimulator(PitchKernel(professionalBalance = true, professionalWorkload = true), professionalBalance = true)
        val lines = (1..240).map { sim.simulate(pitcher, 12, 18, 96, it.toULong() * 918220UL, diverseScouting = true, fullStart = true) }
        assertTrue(lines.any { it.outs == 27 && it.runsAllowed == 0 })
        println("PROFILED_ACE fullNine=${lines.count { it.outs == 27 }} scorelessNine=${lines.count { it.outs == 27 && it.runsAllowed == 0 }} meanIP=${lines.sumOf { it.outs } / 720.0}")
    }
    @Test fun completeGamesAreReachableButNotAutomatic() {
        val sim = ProAutomaticOutingSimulator(PitchKernel(professionalBalance = true, professionalWorkload = true), professionalBalance = true)
        for (rating in listOf(50, 65, 80)) {
            val pitcher = PitcherSnapshot("p", "투수", rating, rating, rating, rating)
            val lines = (1..240).map { sim.simulate(pitcher, 12, 18, 96, it.toULong() * 401123UL, diverseScouting = true, fullStart = true) }
            val complete = lines.count { it.outs == 27 }
            val shutout = lines.count { it.outs == 27 && it.runsAllowed == 0 }
            println("ACE rating=$rating starts=${lines.size} fullNine=$complete scorelessNine=$shutout meanIP=${lines.sumOf { it.outs } / (lines.size * 3.0)} meanNP=${lines.sumOf { it.pitches } / lines.size.toDouble()}")
            assertTrue(lines.all { it.outs in 0..27 && it.strikeouts <= it.outs })
            if (rating == 80) { assertTrue(complete > 0); assertTrue(shutout > 0); assertTrue(complete < lines.size / 2) }
        }
    }
}
