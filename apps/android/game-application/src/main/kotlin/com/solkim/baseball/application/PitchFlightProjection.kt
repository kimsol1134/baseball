package com.solkim.baseball.application

import com.solkim.baseball.model.PitchPresentationRequest
import com.solkim.baseball.model.PitchType
import kotlin.math.floor
import kotlin.math.tanh

public data class PitchFlightPoint(val x: Float, val y: Float)

/** Catcher-view illustration. Amplifies saved curvature, never changes the plate/result. */
public object PitchFlightProjection {
    /** Display-only bend amplitude: movement 20 → ×0.7, movement 80 → ×1.3. Judgment never reads this. */
    public fun movementScale(movement: Int): Float = 0.7f + (movement - 20).coerceIn(0, 60) / 60f * 0.6f

    public fun points(request: PitchPresentationRequest, movementScale: Float = 1f): List<PitchFlightPoint> {
        val start = PitchFlightPoint(160f, 116f)
        val end = PitchFlightPoint((160f + request.plateXMm * .15f).coerceIn(48f, 272f), (205f - request.plateYMm * .15f).coerceIn(48f, 292f))
        val raw = request.trajectory
        val first = raw.firstOrNull()
        val last = raw.lastOrNull()
        return (0..64).map { index ->
            val t = index / 64f
            val x = start.x + (end.x - start.x) * t
            val y = start.y + (end.y - start.y) * t
            if (request.pitchType == PitchType.FOUR_SEAM || raw.size < 2 || first == null || last == null || index == 0 || index == 64) {
                PitchFlightPoint(x, y)
            } else {
                val time = t * 1_000f
                val upper = raw.indexOfFirst { it.timePermille >= time }.coerceAtLeast(1)
                val a = raw[upper - 1]; val b = raw[upper]
                val fraction = ((time - a.timePermille) / (b.timePermille - a.timePermille).coerceAtLeast(1)).coerceIn(0f, 1f)
                val actualX = a.xMm + (b.xMm - a.xMm) * fraction
                val actualY = a.yMm + (b.yMm - a.yMm) * fraction
                val chordX = first.xMm + (last.xMm - first.xMm) * t
                val chordY = first.yMm + (last.yMm - first.yMm) * t
                val xScale = when (request.pitchType) { PitchType.SLIDER -> .95f; PitchType.CHANGEUP -> .70f; else -> .35f }
                val yScale = when (request.pitchType) { PitchType.CURVEBALL -> .27f; PitchType.CHANGEUP -> .18f; else -> .10f }
                val dropLimit = when (request.pitchType) { PitchType.CURVEBALL -> 56f; PitchType.CHANGEUP -> 34f; else -> 18f }
                // Smooth compression avoids flat-topped arcs for large saved movement values.
                val lateral = 46f * tanh((actualX - chordX) * xScale * movementScale * (2f * t) / 46f)
                val availableDrop = minOf(dropLimit, ((y - start.y) * .65f).coerceAtLeast(0f))
                val drop = if (availableDrop < .001f) 0f else availableDrop * tanh((actualY - chordY) * yScale * movementScale * (2f * t) / availableDrop)
                PitchFlightPoint(x + lateral, y - drop)
            }
        }
    }

    public fun visible(points: List<PitchFlightPoint>, progress: Float): List<PitchFlightPoint> {
        if (points.size < 2) return points
        val position = progress.coerceIn(0f, 1f) * (points.size - 1)
        val index = floor(position).toInt().coerceAtMost(points.lastIndex)
        if (index == points.lastIndex) return points
        val a = points[index]; val b = points[index + 1]; val t = position - index
        return points.take(index + 1) + PitchFlightPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    }
}
