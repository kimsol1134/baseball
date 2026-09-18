package com.solkim.baseball.application

import kotlin.test.*

class PitchGrowthFeelTest {
    @Test fun fasterPitchesHaveBoundedVisualEmphasisAndHeavierMittTone() {
        val speeds = listOf(1_100, 1_300, 1_500, 1_700)
        assertTrue(speeds.map(PitchGrowthFeel::trailScale).zipWithNext().all { (a, b) -> b > a })
        assertTrue(speeds.map(PitchGrowthFeel::impactScale).zipWithNext().all { (a, b) -> b > a })
        assertTrue(speeds.map { PitchFeedbackPlan.mittRate(it, false) }.zipWithNext().all { (a, b) -> b < a })
        assertEquals(PitchGrowthFeel.trailScale(1_700), PitchGrowthFeel.trailScale(5_000))
        assertTrue(PitchGrowthFeel.impactScale(1_700) <= 1.5f)
        assertTrue(PitchFeedbackPlan.mittRate(1_500, true) < PitchFeedbackPlan.mittRate(1_500, false))
    }
}
