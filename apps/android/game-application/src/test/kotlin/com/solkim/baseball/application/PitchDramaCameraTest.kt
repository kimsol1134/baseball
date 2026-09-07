package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.BattedBall
import com.solkim.baseball.core.pitch.PitchOutcome
import kotlin.math.roundToInt
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class PitchDramaCameraTest {
    @Test
    fun fairBallCutsToFieldShotAfterContactWindow() {
        assertFalse(PitchDramaCamera.usesFieldShot(PitchOutcome.SINGLE, 0.40f))
        assertTrue(PitchDramaCamera.usesFieldShot(PitchOutcome.SINGLE, PitchDramaCamera.CUT_PROGRESS))
        assertTrue(PitchDramaCamera.usesFieldShot(PitchOutcome.HOME_RUN, 1f))
        assertTrue(PitchDramaCamera.usesFieldShot(PitchOutcome.IN_PLAY_OUT, 0.9f))
        assertFalse(PitchDramaCamera.usesFieldShot(PitchOutcome.FOUL, 1f))
        assertFalse(PitchDramaCamera.usesFieldShot(PitchOutcome.CALLED_STRIKE, 1f))
        assertFalse(PitchDramaCamera.usesFieldShot(null, 1f))
    }

    @Test
    fun incomingFlightRushesTheLastStretchAndReplayFitsTheKernelFlight() {
        assertEquals(0f, PitchDramaCamera.incomingFlight(0f), 0.001f)
        assertEquals(1f, PitchDramaCamera.incomingFlight(PitchDramaCamera.CONTACT_PROGRESS), 0.001f)
        val halfway = PitchDramaCamera.incomingFlight(PitchDramaCamera.CONTACT_PROGRESS * 0.5f)
        assertTrue(halfway < 0.30f, "ease-in must keep the ball back through the first half of incoming time")
        val late = PitchDramaCamera.incomingFlight(PitchDramaCamera.CONTACT_PROGRESS * 0.8f)
        assertTrue(late > 0.55f, "the last stretch must cover most of the remaining path")

        val reduced = PitchDramaCamera.replayDurationMs(450, reducedMotion = true)
        assertEquals(PitchDramaCamera.REDUCED_MOTION_REPLAY_MS, reduced)
        val fast = PitchDramaCamera.replayDurationMs(330, reducedMotion = false)
        val slow = PitchDramaCamera.replayDurationMs(620, reducedMotion = false)
        assertTrue(fast in PitchDramaCamera.MIN_REPLAY_MS..PitchDramaCamera.MAX_REPLAY_MS)
        assertTrue(slow in PitchDramaCamera.MIN_REPLAY_MS..PitchDramaCamera.MAX_REPLAY_MS)
        val incomingFast = fast * PitchDramaCamera.CONTACT_PROGRESS
        assertTrue(incomingFast < 420f, "incoming must stay under the old 736ms crawl")
        val clutch = PitchDramaCamera.replayDurationMs(450, reducedMotion = false, clutch = true)
        val normal = PitchDramaCamera.replayDurationMs(450, reducedMotion = false, clutch = false)
        assertEquals((normal * PitchDramaCamera.CLUTCH_TEMPO).roundToInt(), clutch)
        assertEquals(
            PitchDramaCamera.REDUCED_MOTION_REPLAY_MS,
            PitchDramaCamera.replayDurationMs(450, reducedMotion = true, clutch = true),
        )
    }

    @Test
    fun battedBallLeavesThePlateAfterContact() {
        assertEquals(0f, PitchDramaCamera.departureProgress(PitchOutcome.SINGLE, 0.30f), 0.001f)
        assertTrue(PitchDramaCamera.departureProgress(PitchOutcome.SINGLE, 0.42f) > 0f)
        assertEquals(1f, PitchDramaCamera.departureProgress(PitchOutcome.SINGLE, PitchDramaCamera.CUT_PROGRESS), 0.001f)
        assertTrue(PitchDramaCamera.departureProgress(PitchOutcome.FOUL, 0.70f) > 0.3f)
        assertEquals(0f, PitchDramaCamera.departureProgress(PitchOutcome.CALLED_STRIKE, 0.80f), 0.001f)

        val fly = BattedBall(1400, 280, 0, 700)
        val center = PitchDramaCamera.departingBallDelta(PitchOutcome.SINGLE, fly, 1f)
        assertTrue(center.y < -40f, "center-field contact must leave toward the mound camera")
        assertEquals(0f, center.x, 8f)

        val pull = BattedBall(1400, 200, -300, 600)
        val pulled = PitchDramaCamera.departingBallDelta(PitchOutcome.SINGLE, pull, 1f)
        assertTrue(pulled.x < 0f, "pulled ball must leave to the third-base side")

        val foul = PitchDramaCamera.departingBallDelta(PitchOutcome.FOUL, null, 1f)
        assertNotEquals(PitchDramaCamera.Delta.ZERO, foul)
        assertTrue(
            PitchDramaCamera.accessibility(PitchOutcome.SINGLE, fly, null, 0.70f) { outcome, ball ->
                "$outcome $ball"
            }.contains("타구"),
        )
        assertTrue(
            PitchDramaCamera.accessibility(PitchOutcome.FOUL, null, null, 0.70f) { _, _ -> "파울" }
                .contains("배트"),
        )
    }
}

class PitchDramaCameraPerfectTest {
    @Test fun perfectReleaseShortensTheClipByFifteenPercentBeforeClutch() {
        val normal = PitchDramaCamera.replayDurationMs(450, reducedMotion = false)
        val perfect = PitchDramaCamera.replayDurationMs(450, reducedMotion = false, perfect = true)
        assertEquals(Math.round(normal * PitchDramaCamera.PERFECT_TEMPO), perfect)
        val clutchPerfect = PitchDramaCamera.replayDurationMs(450, reducedMotion = false, clutch = true, perfect = true)
        assertEquals(Math.round(perfect * PitchDramaCamera.CLUTCH_TEMPO), clutchPerfect)
        assertEquals(PitchDramaCamera.REDUCED_MOTION_REPLAY_MS, PitchDramaCamera.replayDurationMs(450, reducedMotion = true, perfect = true))
    }
}
