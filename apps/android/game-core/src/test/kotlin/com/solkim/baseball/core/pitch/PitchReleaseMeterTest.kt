package com.solkim.baseball.core.pitch

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PitchReleaseMeterTest {
    @Test
    fun centerReleaseIsPerfectAndIdleAimIsPerfect() {
        val delivery = PitchReleaseMeter.delivery(0.5, 0.0, 0.0)
        assertEquals(1_000, delivery.releaseAccuracy)
        assertEquals(1_000, delivery.aimAccuracy)
        assertTrue(delivery.isPerfectRelease)
    }

    @Test
    fun meterEdgesAreAMissAndAimRadiusIsZero() {
        assertEquals(0, PitchReleaseMeter.delivery(0.0, 0.0, 0.0).releaseAccuracy)
        assertEquals(0, PitchReleaseMeter.delivery(1.0, 0.0, 0.0).releaseAccuracy)
        val missedAim = PitchReleaseMeter.delivery(0.5, PitchReleaseMeter.AIM_RADIUS_POINTS, 0.0)
        assertEquals(1_000, missedAim.releaseAccuracy)
        assertEquals(0, missedAim.aimAccuracy)
        assertTrue(missedAim.isPerfectRelease)
    }

    @Test
    fun phaseOscillatesInsteadOfRunningOffTheEnd() {
        assertEquals(0.0, PitchReleaseMeter.phase(0.0), 1e-9)
        assertEquals(0.5, PitchReleaseMeter.phase(PitchReleaseMeter.SWEEP_SECONDS * 0.5), 1e-9)
        val returning = PitchReleaseMeter.phase(PitchReleaseMeter.SWEEP_SECONDS * 1.25)
        assertEquals(0.75, returning, 1e-9)
    }

    @Test
    fun autoReleasePathStaysNeutral() {
        assertEquals(500, PitchDelivery.NEUTRAL.releaseAccuracy)
        assertEquals(500, PitchDelivery.NEUTRAL.aimAccuracy)
        assertFalse(PitchDelivery.NEUTRAL.isPerfectRelease)
    }
}
