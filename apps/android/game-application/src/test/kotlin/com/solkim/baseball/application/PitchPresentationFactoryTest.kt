package com.solkim.baseball.application

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

class PitchPresentationFactoryTest {
    @Test
    fun fourPitchTrajectoriesAreDistinctAndRendererBounded() {
        val session = KotlinPitchPresentationSession()
        val requests = (0..3).map { session.request("session-fixture", it) }
        assertEquals(4, requests.map { it.pitchType }.distinct().size)
        assertEquals(4, requests.map { it.visual.trailKind }.distinct().size)
        assertEquals(4, requests.map { it.trajectory }.distinct().size)
        requests.forEach { request ->
            request.validate()
            assertNotEquals("0".repeat(64), request.requestSha256)
        }
    }
}
