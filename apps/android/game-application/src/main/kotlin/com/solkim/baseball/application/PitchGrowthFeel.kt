package com.solkim.baseball.application

/** Presentation only: speed emphasis never changes pitch physics or timing windows. */
public object PitchGrowthFeel {
    public fun speedWeight(velocityTenthsKph: Int): Float =
        if (velocityTenthsKph <= 0) 0.5f else ((velocityTenthsKph - 1_100) / 600f).coerceIn(0f, 1f)
    public fun trailScale(velocityTenthsKph: Int): Float = 0.85f + speedWeight(velocityTenthsKph) * 0.45f
    public fun impactScale(velocityTenthsKph: Int): Float = 0.8f + speedWeight(velocityTenthsKph) * 0.6f
}
