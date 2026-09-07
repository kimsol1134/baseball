package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.BattedBall
import com.solkim.baseball.core.pitch.FieldingResolutionSnapshot
import com.solkim.baseball.core.pitch.PitchOutcome
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/** Timing and contact-exit math for the mound 2-cut camera. Does not invent kernel physics. */
public object PitchDramaCamera {
    /** Plate arrival as a fraction of the whole replay. Incoming is this slice of [replayDurationMs]. */
    public const val CONTACT_PROGRESS: Float = 0.38f
    public const val CUT_PROGRESS: Float = 0.48f
    public const val REDUCED_MOTION_REPLAY_MS: Int = 80
    public const val MIN_REPLAY_MS: Int = 720
    public const val MAX_REPLAY_MS: Int = 960
    /** iOS `PitchFeedbackTimeline.clutchTempo` — 풀카운트·2아웃 2S만 늘린다. */
    public const val CLUTCH_TEMPO: Float = 1.625f
    /** A perfect release flies 15% faster — the ball looks like it jumps out of the hand. */
    public const val PERFECT_TEMPO: Float = 0.85f

    /** Whole-clip length so the pitch reaches the plate in about the kernel flight time. */
    public fun replayDurationMs(
        flightDurationMs: Int,
        reducedMotion: Boolean,
        clutch: Boolean = false,
        perfect: Boolean = false,
    ): Int {
        if (reducedMotion) return REDUCED_MOTION_REPLAY_MS
        val flight = flightDurationMs.coerceIn(300, 520)
        val base = (flight / CONTACT_PROGRESS).roundToInt().coerceIn(MIN_REPLAY_MS, MAX_REPLAY_MS)
        val timed = if (perfect) (base * PERFECT_TEMPO).roundToInt() else base
        return if (clutch) (timed * CLUTCH_TEMPO).roundToInt() else timed
    }

    /**
     * Catcher-camera sampling. Quadratic ease-in keeps the ball small, then it covers
     * the last stretch of the path quickly — the speed you feel at 140 km/h.
     */
    public fun incomingFlight(progress: Float): Float {
        val linear = (progress / CONTACT_PROGRESS).coerceIn(0f, 1f)
        return linear * linear
    }

    public val FAIR_BALL_OUTCOMES: Set<PitchOutcome> = setOf(
        PitchOutcome.IN_PLAY_OUT,
        PitchOutcome.SINGLE,
        PitchOutcome.DOUBLE,
        PitchOutcome.TRIPLE,
        PitchOutcome.HOME_RUN,
    )

    public val BATTED_OUTCOMES: Set<PitchOutcome> = setOf(
        PitchOutcome.FOUL,
        PitchOutcome.IN_PLAY_OUT,
        PitchOutcome.SINGLE,
        PitchOutcome.DOUBLE,
        PitchOutcome.TRIPLE,
        PitchOutcome.HOME_RUN,
    )

    public data class Delta(val x: Float, val y: Float) {
        public companion object {
            public val ZERO: Delta = Delta(0f, 0f)
        }
    }

    public fun usesFieldShot(outcome: PitchOutcome?, progress: Float): Boolean =
        outcome in FAIR_BALL_OUTCOMES && progress >= CUT_PROGRESS

    public fun departureProgress(outcome: PitchOutcome?, progress: Float): Float {
        if (outcome !in BATTED_OUTCOMES || progress < CONTACT_PROGRESS) return 0f
        val end = if (outcome in FAIR_BALL_OUTCOMES) CUT_PROGRESS else 1f
        val span = (end - CONTACT_PROGRESS).coerceAtLeast(0.01f)
        return ((progress - CONTACT_PROGRESS) / span).coerceIn(0f, 1f)
    }

    public fun departingBallDelta(
        outcome: PitchOutcome?,
        battedBall: BattedBall?,
        t: Float,
    ): Delta {
        if (t <= 0f) return Delta.ZERO
        val rawDir = (battedBall?.directionTenthsDegrees ?: if (outcome == PitchOutcome.FOUL) 550 else 0) / 10f
        val direction = when {
            outcome == PitchOutcome.FOUL && rawDir in -25f..25f -> if (rawDir >= 0f) 48f else -48f
            else -> rawDir.coerceIn(-48f, 48f)
        }
        val angle = (battedBall?.launchAngleTenthsDegrees ?: 200) / 10f
        val quality = (battedBall?.contactQuality ?: 400) / 1000f
        val reach = 70f + 90f * quality
        val radians = direction * (PI.toFloat() / 180f)
        val lateral = sin(radians) * reach * t
        val depth = cos(radians).coerceAtLeast(0.2f) * reach * t
        val lift = (angle / 40f).coerceIn(0.15f, 1.8f) * 36f * sin(t * PI.toFloat())
        return Delta(lateral, -(depth + lift))
    }

    public fun accessibility(
        outcome: PitchOutcome?,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?,
        progress: Float,
        verdict: (PitchOutcome, BattedBall?) -> String,
    ): String {
        if (usesFieldShot(outcome, progress)) {
            val meters = fielding?.landingDistanceTenthsMeters?.div(10)
            return if (meters != null && meters > 0) "타구가 ${meters}m 지점으로 날아갑니다" else "타구가 필드로 날아갑니다"
        }
        if (outcome in BATTED_OUTCOMES && progress >= CONTACT_PROGRESS) {
            return "배트에 맞은 공이 날아갑니다"
        }
        return if (outcome != null) verdict(outcome, battedBall) else "투구가 홈플레이트로 들어옵니다"
    }
}
