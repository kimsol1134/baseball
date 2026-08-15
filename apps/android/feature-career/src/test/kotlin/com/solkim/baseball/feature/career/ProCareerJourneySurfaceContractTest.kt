package com.solkim.baseball.feature.career

import com.solkim.baseball.application.ProCareerJourneyApplicationSnapshot
import com.solkim.baseball.application.ProCareerJourneyProjector
import com.solkim.baseball.core.pro.ProCareerJourneyState
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ProCareerJourneySurfaceContractTest {
    @Test
    fun featureBoundaryHasAllWave6SurfacesWithoutProductionExposure() {
        assertFalse(CareerModuleBoundary.productionEnabled)
        assertTrue(CareerModuleBoundary.fixtureComplete)
        assertEquals(setOf("contract", "settlement", "investment", "retirement"), CareerModuleBoundary.requiredSurfaces)
        val snapshot = ProCareerJourneyApplicationSnapshot(0UL, ProCareerJourneyState(), emptyList())
        assertFalse(snapshot.productionSurfaceEnabled)
        assertTrue(snapshot.fixtureCompleteBoundary)
        assertFalse(ProCareerJourneyProjector.contractMarket(snapshot.state).visible)
        assertFalse(ProCareerJourneyProjector.settlement(snapshot.state).visible)
    }
}
