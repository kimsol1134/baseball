package com.solkim.baseball.core.pitch

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * iOS `DeliveryControl` hand-feel contract. Scoring stays on meter 0.5 / aim radius 46.
 * Sweep tempo and aim sway are separate so a still finger is not a perfect aim.
 */
public object PitchReleaseMeter {
    public const val PERFECT_PHASE: Double = 0.5
    public const val AIM_RADIUS_POINTS: Double = 46.0
    public const val MINIMUM_HOLD_SECONDS: Double = 0.14
    public const val BASE_SWEEP_SECONDS: Double = 1.18
    public val SWAY_RATES: DoubleArray = doubleArrayOf(0.83, 1.31, 0.67, 1.13)

    public const val SWEEP_SECONDS: Double = BASE_SWEEP_SECONDS

    public fun sweepSeconds(
        velocityTenthsKph: Int,
        fatigue: Int,
        reduceMotion: Boolean = false,
    ): Double {
        val velocity = (minOf(1_500, maxOf(1_100, velocityTenthsKph)) - 1_100) / 400.0
        val fatigueRatio = minOf(100, maxOf(0, fatigue)) / 100.0
        val seconds = 1.18 - velocity * 0.38 - fatigueRatio * 0.24
        return if (reduceMotion) seconds * 1.5 else seconds
    }

    public fun swayAmplitude(fatigue: Int, reduceMotion: Boolean = false): Double {
        val base = 26.0
        val tired = minOf(100, maxOf(0, fatigue)) / 100.0 * 16.0
        val raw = base + tired
        return if (reduceMotion) raw * 0.55 else raw
    }

    public fun swayOffset(
        elapsedSeconds: Double,
        amplitude: Double,
        phases: DoubleArray,
    ): Pair<Double, Double> {
        if (amplitude <= 0.0) return 0.0 to 0.0
        require(phases.size >= 4) { "pitch.release.sway_phases" }
        val x = 0.62 * sin(2 * PI * SWAY_RATES[0] * elapsedSeconds + phases[0]) +
            0.38 * sin(2 * PI * SWAY_RATES[1] * elapsedSeconds + phases[1])
        val y = 0.58 * sin(2 * PI * SWAY_RATES[2] * elapsedSeconds + phases[2]) +
            0.42 * sin(2 * PI * SWAY_RATES[3] * elapsedSeconds + phases[3])
        return amplitude * x to amplitude * y
    }

    public fun phase(elapsedSeconds: Double, sweepSeconds: Double = BASE_SWEEP_SECONDS): Double {
        require(elapsedSeconds.isFinite() && elapsedSeconds >= 0.0) { "pitch.release.elapsed" }
        require(sweepSeconds.isFinite() && sweepSeconds > 0.0) { "pitch.release.sweep" }
        val sweep = elapsedSeconds / sweepSeconds
        val whole = floor(sweep).toLong()
        val fraction = sweep - whole
        return if (whole and 1L == 0L) fraction else 1.0 - fraction
    }

    public fun delivery(
        meter: Double,
        aimX: Double,
        aimY: Double,
        aimRadius: Double = AIM_RADIUS_POINTS,
    ): PitchDelivery {
        val clampedMeter = meter.coerceIn(0.0, 1.0)
        val releaseError = min(1.0, abs(clampedMeter - PERFECT_PHASE) * 2.0)
        val release = ((1.0 - releaseError) * 1_000.0).roundToInt()
        val radius = if (aimRadius > 0.0) aimRadius else AIM_RADIUS_POINTS
        val distance = min(radius, hypot(aimX, aimY))
        val aimScore = ((1.0 - distance / radius) * 1_000.0).roundToInt()
        return PitchDelivery(
            releaseAccuracy = release.coerceIn(0, 1_000),
            aimAccuracy = aimScore.coerceIn(0, 1_000),
        )
    }

    public fun coachingHint(delivery: PitchDelivery): String? {
        if (delivery == PitchDelivery.NEUTRAL || delivery.isPerfectRelease) return null
        val release = delivery.releaseAccuracy
        val aim = delivery.aimAccuracy
        if (minOf(release, aim) >= 700) return null
        return if (release <= aim) {
            if (release < 400) "미터를 크게 놓쳤습니다 — 초록 구간에서 떼세요" else "미터를 살짝 놓쳤습니다"
        } else {
            if (aim < 400) "조준이 크게 흔들렸습니다 — 손가락을 과녁에 머무르게 하세요" else "조준이 살짝 흔들렸습니다"
        }
    }
}
