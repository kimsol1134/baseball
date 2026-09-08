package com.solkim.baseball.core.pitch

import kotlin.test.*

class CatcherSequenceTest {
    private val kernel = PitchKernel()
    private fun request(balls: Int = 0, strikes: Int = 0, observations: List<RivalPitchObservation> = emptyList()): PitchKernel.PrepareRequest =
        PitchKernel.PrepareRequest("918220", PitcherSnapshot("p", "투수", 62, 54, 58, 60,
            pitchProfiles = listOf(
                PitchProfileSnapshot(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1420, 55, 55, 50, 60, 55, 1),
                PitchProfileSnapshot(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1275, 55, 55, 60, 60, 55, 1))),
            BatterSnapshot("b", "타자", 56, 52, 58),
            BatterScoutingSnapshot(PitchZone(1, 1), PitchZone(0, 2), PitchKind.FOUR_SEAM, PitchKind.SLIDER, 48),
            PlateAppearanceContext("pa", 0UL, 7, 0, balls, strikes, 1 + observations.size, 0, 600, 12),
            RivalMemorySnapshot("p:b", 0UL, 0, observations.size, observations))

    @Test fun effortPreviewUsesActualDeliveryRules() {
        val req = request()
        val call = kernel.prepare(req).primaryRecommendation.call
        val velocities = PitchIntensity.entries.map { intensity ->
            val chosen = call.copy(intensity = intensity)
            val velocity = PitchAbilityRules.expectedVelocity(req.pitcher, chosen, req.context.fatigue)
            assertEquals(PitchAbilityRules.readout(req.pitcher, chosen, req.context).nominalVelocityTenthsKph, velocity)
            velocity
        }
        assertTrue(velocities[0] < velocities[1] && velocities[1] < velocities[2])
    }

    @Test fun repeatedLocationChangesAndRefreshDoesNotReroll() {
        val old = RivalPitchObservation(PitchKind.SLIDER, PitchZone(0, 2), ZoneIntent.EDGE, 0, 0, PitchOutcome.FOUL)
        val req = request(observations = List(3) { old })
        val prep = kernel.prepare(req)
        assertNotEquals(old.zone, prep.primaryRecommendation.call.zone)
        assertNotEquals(prep.primaryRecommendation.call.zone, prep.alternativeRecommendation.call.zone)
        assertEquals(prep, kernel.prepare(req))
        assertEquals("sequence.change_location", prep.primaryRecommendation.reasonCodes.first())
    }

    @Test fun threeBallCountsNeverRecommendChasingAndCallsStayPlayable() {
        for (balls in 0..3) for (strikes in 0..2) {
            val req = request(balls, strikes)
            val prep = kernel.prepare(req)
            listOf(prep.primaryRecommendation, prep.alternativeRecommendation).forEach {
                assertTrue(it.call.pitchType in req.pitcher.pitchProfiles!!.map { p -> p.pitchType })
                if (balls == 3) assertEquals(ZoneIntent.STRIKE, it.call.zoneIntent)
            }
            kernel.submit(PitchKernel.SubmitRequest(req.seed, req.pitcher, req.batter, req.scouting, req.context,
                prep.preparationToken, prep.primaryRecommendation.call, req.rivalMemory))
            assertFalse(kernel.matchesPreparation(req.copy(context = req.context.copy(revision = 1UL)), prep.preparationToken))
        }
    }
}
