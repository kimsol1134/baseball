package com.solkim.baseball.core

import kotlin.test.Test
import kotlin.test.assertEquals

class DeterministicFixtureTest {
    @Test
    fun splitMix64MatchesTheSwiftTranslationFixture() {
        SelectedCoreFixtures.splitMix64.forEach { (seed, expected) ->
            val random = SplitMix64(seed)
            assertEquals(expected, List(expected.size) { random.next() }, "seed=$seed")
        }
    }

    @Test
    fun stableHashMatchesTheSwiftTranslationFixture() {
        SelectedCoreFixtures.stableHash.forEach { (input, expected) ->
            assertEquals(expected, StableHash.fnv1a64(input), "input=$input")
        }
    }

    @Test
    fun pitchFixtureAuthorityIsRecordedAlongsideThePortedKernel() {
        assertEquals("23acbb8ec233836e802009c8852c430e08075d3c", SelectedCoreFixtures.PITCH_ORACLE_SOURCE_COMMIT)
        assertEquals("bdf4288abbc6dc81e96f8c725202af4e764bb293640e3fb0e3571abef182c76b", SelectedCoreFixtures.PITCH_ORACLE_SOURCE_SET_SHA256)
    }
}
