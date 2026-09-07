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
            assertTrue(timings.filterIndexed { index, _ -> index % 2 == 1 }.all { it <= 40 })
        }
        assertFalse(NativePitchHaptics.timings(PitchHapticCue.RELEASE).contentEquals(NativePitchHaptics.timings(PitchHapticCue.PERFECT)))
    }
}
