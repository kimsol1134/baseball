package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.model.PitchAudioCue
import com.solkim.baseball.model.PitchHapticCue
import kotlin.test.*

class PitchFeedbackPlanTest {
    /** The flight rush is ambience between the hand and the mitt; the call order is what matters here. */
    private fun voiced(events: List<PitchFeedbackEvent>) = events.filterNot { it.cue == PitchAudioCue.FLIGHT }

    @Test fun ordinaryStrikeAndStrikeoutNeverPlayConflictingCalls() {
        for (outcome in listOf(PitchOutcome.CALLED_STRIKE, PitchOutcome.SWINGING_STRIKE)) {
            val regular = voiced(PitchFeedbackPlan.make(outcome, false, 500, 900, false))
            assertEquals(1, regular.count { it.cue == PitchAudioCue.STRIKE })
            assertFalse(regular.any { it.cue == PitchAudioCue.STRIKEOUT })
            val strikeout = voiced(PitchFeedbackPlan.make(outcome, true, 500, 900, false))
            assertFalse(strikeout.any { it.cue == PitchAudioCue.STRIKE })
            assertEquals(1, strikeout.count { it.cue == PitchAudioCue.STRIKEOUT })
            assertEquals(PitchHapticCue.STRIKEOUT, strikeout[1].haptic)
            assertTrue(strikeout.last().delayMs - strikeout.first { it.cue == PitchAudioCue.STRIKEOUT }.delayMs >= 1_990)
        }
    }

    @Test fun ballUsesIosGloveCueAndContactOutcomesRemainDistinct() {
        assertEquals(listOf(PitchAudioCue.RELEASE, PitchAudioCue.CATCH), voiced(PitchFeedbackPlan.make(PitchOutcome.BALL, false, 500, 900, false)).map { it.cue })
        assertEquals(PitchAudioCue.GROAN, voiced(PitchFeedbackPlan.make(PitchOutcome.BALL, true, 500, 900, false)).last().cue)
        assertEquals(PitchAudioCue.FOUL, voiced(PitchFeedbackPlan.make(PitchOutcome.FOUL, false, 500, 900, false))[1].cue)
        assertEquals(PitchAudioCue.CONTACT, voiced(PitchFeedbackPlan.make(PitchOutcome.HOME_RUN, true, 900, 900, false))[1].cue)
        assertEquals(PitchAudioCue.WEAK_CONTACT, voiced(PitchFeedbackPlan.make(PitchOutcome.HIT_BY_PITCH, true, 900, 900, false))[1].cue)
    }

    @Test fun callsFollowArrivalEvenWithReducedMotionAndSlowMotion() {
        for (reduced in listOf(false, true)) for (duration in listOf(80, 900, 1_460)) {
            for (outcome in PitchOutcome.entries) {
                val events = PitchFeedbackPlan.make(outcome, true, 500, duration, reduced)
                assertEquals(0L, events.first().delayMs)
                assertTrue(events.zipWithNext().all { (before, after) -> before.delayMs <= after.delayMs })
                assertEquals(1, events.count { it.haptic != null })
            }
        }
        assertTrue(PitchFeedbackPlan.make(null, false, 0, 900, false).isEmpty())
    }
}

class PitchFeedbackPerfectAndGrowthTest {
    @Test fun perfectReleaseHoldsTheClipPopsTheMittAndCallsEarlier() {
        val plain = PitchFeedbackPlan.make(PitchOutcome.CALLED_STRIKE, true, 500, 900, false)
        val perfect = PitchFeedbackPlan.make(PitchOutcome.CALLED_STRIKE, true, 500, 900, false, perfect = true)
        assertEquals(0L, perfect.first().delayMs)
        val plainMitt = plain.first { it.cue == PitchAudioCue.CATCH }
        val perfectMitt = perfect.first { it.cue == PitchAudioCue.CATCH }
        assertEquals(plainMitt.delayMs + PitchFeedbackPlan.PERFECT_HOLD_MS, perfectMitt.delayMs)
        assertTrue(perfectMitt.gain > plainMitt.gain)
        assertTrue(perfectMitt.rate < plainMitt.rate)
        val plainCall = plain.first { it.cue == PitchAudioCue.STRIKEOUT }.delayMs - plainMitt.delayMs
        val perfectCall = perfect.first { it.cue == PitchAudioCue.STRIKEOUT }.delayMs - perfectMitt.delayMs
        assertEquals(plainCall - 200L, perfectCall)
        assertTrue(perfect.zipWithNext().all { (a, b) -> a.delayMs <= b.delayMs })
        // Reduced motion never holds.
        val reduced = PitchFeedbackPlan.make(PitchOutcome.BALL, false, 500, 80, true, perfect = true)
        assertEquals(220L, reduced.first { it.cue == PitchAudioCue.CATCH }.delayMs)
    }

    @Test fun mittGrowsWithVelocityOnlyForTheMitt() {
        assertEquals(0.8f, PitchFeedbackPlan.mittGain(1_300))
        assertEquals(1.2f, PitchFeedbackPlan.mittGain(1_500))
        assertEquals(1.2f, PitchFeedbackPlan.mittGain(1_700))
        assertEquals(1f, PitchFeedbackPlan.mittGain(0))
        val fast = PitchFeedbackPlan.make(PitchOutcome.BALL, false, 500, 900, false, velocityTenthsKph = 1_500)
        assertEquals(1.2f, fast.first { it.cue == PitchAudioCue.CATCH }.gain)
        assertEquals(1f, fast.first { it.cue == PitchAudioCue.RELEASE }.gain)
        val swing = PitchFeedbackPlan.make(PitchOutcome.SWINGING_STRIKE, false, 500, 900, false, velocityTenthsKph = 1_500)
        assertEquals(1f, swing.first { it.cue == PitchAudioCue.SWING_MISS }.gain)
    }
}
