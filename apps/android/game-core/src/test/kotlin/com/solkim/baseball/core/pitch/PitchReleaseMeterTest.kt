package com.solkim.baseball.core.pitch

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class PitchReleaseMeterTest {
    @Test fun sharedIOSWindowVectorsMatch() {
        assertEquals(listOf(180, 196, 200, 220, 240), listOf(35, 47, 50, 65, 80).map(PitchReleaseWindow::widthPermille))
        assertEquals(listOf(800, 815, 820, 835, 848), listOf(35, 47, 50, 65, 80).map { PitchReleaseWindow.calibratedAccuracy(800, it) })
    }

    @Test fun commandWindowPreservesBeginnersNeutralPerfectAndMonotonicScores() {
        for (command in 20..80) {
            val width = PitchReleaseWindow.widthPermille(command)
            assertTrue(width in 180..240)
            assertEquals(820, PitchReleaseWindow.calibratedAccuracy(1_000 - width, command))
            assertTrue(PitchReleaseWindow.calibratedAccuracy(999 - width, command) < 820)
            var previous = -1
            for (raw in 0..1_000) {
                val score = PitchReleaseWindow.calibratedAccuracy(raw, command)
                assertTrue(score >= previous && score >= raw)
                assertTrue(score - raw <= 60)
                assertEquals(raw >= 975, score >= 975)
                if (command <= 35 || raw <= 500) assertEquals(raw, score)
                previous = score
            }
        }
        assertEquals(240, PitchReleaseWindow.widthPermille(80))
    }

    @Test fun sameReleaseGetsCommandMarginWithoutMovingAimOrPerfectWindow() {
        val before = PitchReleaseMeter.delivery(0.60, 12.0, 7.0, commandRating = 35)
        val after = PitchReleaseMeter.delivery(0.60, 12.0, 7.0, commandRating = 80)
        assertTrue(before.releaseAccuracy < 820 && after.releaseAccuracy >= 820)
        assertEquals(before.aimAccuracy, after.aimAccuracy)
        assertFalse(after.isPerfectRelease)
        assertEquals(PitchReleaseMeter.delivery(0.5, 12.0, 7.0, commandRating = 35), PitchReleaseMeter.delivery(0.5, 12.0, 7.0, commandRating = 80))
        for (rate in listOf(60, 120)) {
            for (step in 0..rate) {
                val phase = PitchReleaseMeter.phase(step / rate.toDouble(), 1.0)
                val left = PitchReleaseMeter.delivery(phase, 4.0, 8.0, commandRating = 80)
                val right = PitchReleaseMeter.delivery(1.0 - phase, 4.0, 8.0, commandRating = 80)
                assertEquals(left, right)
            }
        }
    }

    @Test
    fun centerReleaseAndCenteredAimScorePerfect() {
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

    @Test
    fun fasterPitchHasFasterReleaseMeter() {
        val fourSeam = PitchReleaseMeter.sweepSeconds(1_470, 20)
        val curveball = PitchReleaseMeter.sweepSeconds(1_180, 20)
        assertTrue(fourSeam < curveball)
    }

    @Test
    fun fatigueSpeedsUpReleaseMeter() {
        val fresh = PitchReleaseMeter.sweepSeconds(1_350, 0)
        val tired = PitchReleaseMeter.sweepSeconds(1_350, 100)
        assertTrue(tired < fresh)
    }

    @Test
    fun fatigueAlsoIncreasesAimSway() {
        assertTrue(PitchReleaseMeter.swayAmplitude(100) > PitchReleaseMeter.swayAmplitude(0))
    }

    @Test
    fun reduceMotionSoftensAimSwayAndSlowsMeter() {
        assertTrue(PitchReleaseMeter.swayAmplitude(60, reduceMotion = true) < PitchReleaseMeter.swayAmplitude(60))
        assertTrue(
            PitchReleaseMeter.sweepSeconds(1_350, 60, reduceMotion = true) >
                PitchReleaseMeter.sweepSeconds(1_350, 60),
        )
    }

    @Test
    fun swayMovesOffCenterSoIdleAimIsNotPerfect() {
        val phases = doubleArrayOf(0.0, 1.0, 2.0, 3.0)
        val (x, y) = PitchReleaseMeter.swayOffset(0.37, PitchReleaseMeter.swayAmplitude(0), phases)
        assertNotEquals(0.0, hypot(x, y))
        val delivery = PitchReleaseMeter.delivery(0.5, x, y)
        assertTrue(delivery.aimAccuracy < 1_000)
    }

    @Test
    fun coachingHintNamesTheWorseAxis() {
        val releaseMiss = PitchReleaseMeter.coachingHint(PitchDelivery(300, 900))
        assertTrue(releaseMiss!!.contains("미터"))
        val aimMiss = PitchReleaseMeter.coachingHint(PitchDelivery(900, 300))
        assertTrue(aimMiss!!.contains("조준"))
        assertEquals(null, PitchReleaseMeter.coachingHint(PitchDelivery.NEUTRAL))
    }

    private fun hypot(x: Double, y: Double): Double = kotlin.math.hypot(x, y)
}
