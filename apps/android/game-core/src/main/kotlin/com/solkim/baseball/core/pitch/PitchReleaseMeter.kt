package com.solkim.baseball.core.pitch

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * iOS `DeliveryControl`과 같은 손맛 계약. 미터 0.5가 완벽 릴리스이고, 조준 이탈은
 * 반경 안에서 0~1000으로 떨어진다. 자동 릴리스는 이 함수를 타지 않고 `PitchDelivery.NEUTRAL`이다.
 */
public object PitchReleaseMeter {
    public const val SWEEP_SECONDS: Double = 1.20
    public const val PERFECT_PHASE: Double = 0.5
    public const val AIM_RADIUS_POINTS: Double = 46.0
    public const val MINIMUM_HOLD_SECONDS: Double = 0.14

    public fun phase(elapsedSeconds: Double, sweepSeconds: Double = SWEEP_SECONDS): Double {
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
}
