package com.solkim.baseball.application

import kotlin.math.abs
import kotlin.test.*

class PitchFlightProjectionTest {
    @Test fun realKernelPitchesHaveDistinctShapesAndExactEndpoints() {
        val session = KotlinPitchPresentationSession()
        val deviations = (0..3).map { index ->
            val request = session.request("flight-shapes", index)
            val original = request.copy()
            val points = PitchFlightProjection.points(request)
            assertEquals(PitchFlightPoint(160f, 116f), points.first())
            assertEquals((160f + request.plateXMm * .15f).coerceIn(48f, 272f), points.last().x)
            assertEquals((205f - request.plateYMm * .15f).coerceIn(48f, 292f), points.last().y)
            assertEquals(original, request)
            val middle = points[32]
            Pair(middle.x - (points.first().x + points.last().x) / 2, middle.y - (points.first().y + points.last().y) / 2)
        }
        assertTrue(abs(deviations[0].first) < .001f && abs(deviations[0].second) < .001f)
        assertTrue(deviations[1].first > 15f, "Slider must bend across the plate: $deviations")
        assertTrue(deviations[3].first < -10f, "Changeup must fade in the opposite direction: $deviations")
        assertTrue(deviations[2].second < deviations[1].second - 10f, "Curveball must have stronger visible drop: $deviations")
        assertTrue(deviations[2].second < deviations[3].second)
    }

    @Test fun ballMovesContinuouslyBetweenSamplesWithoutJumpingAtRelease() {
        val points = PitchFlightProjection.points(KotlinPitchPresentationSession().request("flight-smooth", 2))
        assertEquals(points.first(), PitchFlightProjection.visible(points, 0f).last())
        assertEquals(points.last(), PitchFlightProjection.visible(points, 1f).last())
        val a = PitchFlightProjection.visible(points, .501f).last()
        val b = PitchFlightProjection.visible(points, .502f).last()
        assertNotEquals(a, b)
        assertTrue(abs(a.x - b.x) < 1 && abs(a.y - b.y) < 1)
    }
}

class PitchFlightMovementScaleTest {
    @Test fun movementScalesTheVisibleBendButNeverTheEndpoints() {
        assertEquals(0.7f, PitchFlightProjection.movementScale(20))
        assertEquals(1f, PitchFlightProjection.movementScale(50))
        assertEquals(1.3f, PitchFlightProjection.movementScale(80))
        assertEquals(1.3f, PitchFlightProjection.movementScale(99))
        val request = KotlinPitchPresentationSession().request("flight-scale", 1)
        val base = PitchFlightProjection.points(request)
        val weak = PitchFlightProjection.points(request, PitchFlightProjection.movementScale(20))
        val strong = PitchFlightProjection.points(request, PitchFlightProjection.movementScale(80))
        assertEquals(base.first(), weak.first()); assertEquals(base.last(), weak.last())
        assertEquals(base.first(), strong.first()); assertEquals(base.last(), strong.last())
        fun bend(points: List<PitchFlightPoint>) = abs(points[32].x - (points.first().x + points.last().x) / 2)
        assertTrue(bend(weak) < bend(base), "weak movement bends less")
        assertTrue(bend(strong) > bend(base), "strong movement bends more")
        assertEquals(base, PitchFlightProjection.points(request, 1f))
    }
}
