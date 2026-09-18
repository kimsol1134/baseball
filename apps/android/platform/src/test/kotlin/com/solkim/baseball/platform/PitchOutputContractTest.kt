package com.solkim.baseball.platform

import com.solkim.baseball.model.PitchAudioCue
import com.solkim.baseball.model.PitchHapticCue
import java.io.File
import kotlin.test.*
import org.junit.Test

class PitchOutputContractTest {
    @Test fun everyCueHasItsOwnResourceAndReleaseIsNotAnUmpireCall() {
        assertEquals(PitchAudioCue.entries.size, PitchAudioCue.entries.map(NativeAudioResources::pitchCueResource).distinct().size)
        val release = File("src/main/res/raw/baseball_pitch_release.wav").readBytes()
        val strike = File("src/main/res/raw/baseball_umpire_strike.wav").readBytes()
        assertFalse(release.contentEquals(strike))
        assertTrue(release.size < 20_000)
    }

    @Test fun fallbackPatternsAreShortNonRepeatingAndDistinguishable() {
        for (cue in PitchHapticCue.entries) {
            val timings = NativePitchHaptics.timings(cue)
            assertEquals(0L, timings.first())
            assertTrue(timings.drop(1).all { it > 0 })
            assertTrue(timings.sum() <= 300)
            assertTrue(timings.filterIndexed { index, _ -> index % 2 == 1 }.all { it <= if (cue == PitchHapticCue.PERFECT) 80 else 40 })
        }
        assertFalse(NativePitchHaptics.timings(PitchHapticCue.RELEASE).contentEquals(NativePitchHaptics.timings(PitchHapticCue.PERFECT)))
    }
    @Test fun perfectHasAHeavyImmediateHitAndTightAftershockWithinReleaseProtection() {
        val perfect = NativePitchHaptics.timings(PitchHapticCue.PERFECT)
        val release = NativePitchHaptics.timings(PitchHapticCue.RELEASE)
        val onTime = perfect.filterIndexed { i, _ -> i % 2 == 1 }.sum()
        assertTrue(onTime >= release.sum() * 3)
        assertTrue(perfect[1] > perfect[3])
        assertTrue(perfect[2] in 20L..40L)
        // PitchWindUpFeedback suppresses timing ticks for 180 ms after release.
        assertTrue(perfect.sum() <= 180L)
    }

}
