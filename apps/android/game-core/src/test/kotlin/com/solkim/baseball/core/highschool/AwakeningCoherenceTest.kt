package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchKind
import kotlin.test.*

class AwakeningCoherenceTest {
    private val core = HighSchoolKernel()
    private fun pitcher(): HighSchoolPitcher {
        val p = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "awakening-coherence", "2026-W36", "2026-09-07")).state.run.pitcher
        return p.copy(stuff = 40, command = 40, movement = 40, stamina = 40,
            pitchProfiles = p.pitchProfiles.map { it.copy(command = 40, control = 40, movement = 40, whiff = 40, weakContact = 40, fatigueCost = 4) })
    }
    @Test fun risingFastballImprovesItsOwnMovementWithoutWeakeningOtherPitches() {
        val before = pitcher()
        val after = core.previewAwakening(before, HighSchoolAwakening.RISING_FOUR_SEAM)
        assertEquals(before.movement, after.movement)
        assertEquals(before.command, after.command)
        for (profile in before.pitchProfiles) {
            val next = after.pitchProfiles.single { it.pitchType == profile.pitchType }
            if (profile.pitchType == PitchKind.FOUR_SEAM) assertEquals(profile.movement + 4, next.movement)
            else assertEquals(profile, next)
        }
    }
    @Test fun masteryAndComposureDoNotTradeAwayUnrelatedAbilities() {
        val before = pitcher()
        val techniquesWithPhysicalCosts = setOf(HighSchoolAwakening.EXPLOSIVE_FASTBALL, HighSchoolAwakening.DISAPPEARING_BREAKER, HighSchoolAwakening.SWEEPING_SLIDER)
        for (skill in HighSchoolAwakening.entries.filterNot { it in techniquesWithPhysicalCosts }) {
            val after = core.previewAwakening(before, skill)
            assertTrue(after.stuff >= before.stuff, "$skill stuff")
            assertTrue(after.command >= before.command, "$skill command")
            assertTrue(after.movement >= before.movement, "$skill movement")
            assertTrue(after.stamina >= before.stamina, "$skill stamina")
            before.pitchProfiles.zip(after.pitchProfiles).forEach { (old, new) ->
                assertTrue(new.control >= old.control && new.command >= old.command && new.movement >= old.movement)
                assertTrue(new.fatigueCost <= old.fatigueCost)
            }
        }
    }
    @Test fun powerAndLargeBreakKeepTheirExplicitAccuracyAndEffortCosts() {
        val before = pitcher()
        val power = core.previewAwakening(before, HighSchoolAwakening.EXPLOSIVE_FASTBALL)
        assertEquals(before.command - 2, power.command)
        assertEquals(before.pitchProfiles.first { it.pitchType == PitchKind.FOUR_SEAM }.fatigueCost + 1,
            power.pitchProfiles.first { it.pitchType == PitchKind.FOUR_SEAM }.fatigueCost)
        for (skill in listOf(HighSchoolAwakening.DISAPPEARING_BREAKER, HighSchoolAwakening.SWEEPING_SLIDER)) {
            val after = core.previewAwakening(before, skill)
            assertEquals(before.command - 1, after.command)
            assertTrue(after.movement > before.movement)
        }
    }
}
