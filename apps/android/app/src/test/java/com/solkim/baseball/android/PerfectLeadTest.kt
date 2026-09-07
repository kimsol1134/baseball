package com.solkim.baseball.android

import com.solkim.baseball.core.pitch.PitchReleaseWindow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PerfectLeadTest {
    @Test
    fun warningComesEarlierAsCommandGrows() {
        val baseline = perfectLeadSeconds(PitchReleaseWindow.BASELINE_COMMAND)
        val grown = perfectLeadSeconds(80)
        assertEquals(0.12, baseline, 1e-9)
        assertEquals(0.22, grown, 1e-9)
        assertTrue(grown > baseline)
        // Out-of-range ratings clamp instead of running away.
        assertEquals(baseline, perfectLeadSeconds(10), 1e-9)
        assertEquals(grown, perfectLeadSeconds(120), 1e-9)
    }
}

class PlateLocationTest {
    @Test
    fun theLineNamesTheMissThatDecidedTheCall() {
        assertEquals("존 안 · 홈플레이트를 지날 때 존 안이었다", plateLocationLine(480, -120))
        assertEquals("존 안 · 홈플레이트를 지날 때 존 안이었다", plateLocationLine(500, 500))
        assertEquals("존 밖 · 옆으로 3cm 벗어났다", plateLocationLine(-530, 0))
        assertEquals("존 밖 · 위로 6cm 벗어났다", plateLocationLine(0, 560))
        assertEquals("존 밖 · 아래로 2cm 벗어났다", plateLocationLine(100, -520))
        // A single millimetre outside still reads as a miss rather than rounding to zero.
        assertEquals("존 밖 · 옆으로 1cm 벗어났다", plateLocationLine(501, 0))
        assertEquals(null, plateLocationLine(null, 0))
    }
}
