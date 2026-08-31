package com.solkim.baseball.core.pitch

/** Shared fixed-point diminishing-return math for the four pitcher mastery tracks. */
public object MasteryEffectRules {
    public const val MAXIMUM_BONUS_PERMILLE: Int = 120

    public fun bonusPermille(level: Int): Int {
        if (level <= 0) return 0
        val safe = level.toLong().coerceIn(0L, AbilityMasterySnapshot.TECHNICAL_MAXIMUM.toLong())
        return minOf(MAXIMUM_BONUS_PERMILLE, (MAXIMUM_BONUS_PERMILLE.toLong() * safe / (safe + 24L)).toInt())
    }

    public fun bonusForContribution(contribution: Int, level: Int): Int {
        if (contribution <= 0) return 0
        val safe = contribution.toLong().coerceAtMost(AbilityMasterySnapshot.TECHNICAL_MAXIMUM.toLong())
        return ((safe * bonusPermille(level) + 500L) / 1_000L).toInt()
    }

    public fun adjustedContribution(contribution: Int, level: Int): Int =
        (contribution.toLong() + bonusForContribution(contribution, level).toLong())
            .coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()

    public fun adjustedRating(rating: Int, level: Int): Int {
        if (rating <= 0) return rating
        val result = rating.toLong() + bonusForContribution(rating, level).toLong()
        return result.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
    }

    public fun displayName(ability: PitchAbilityKind): String = when (ability) {
        PitchAbilityKind.POWER -> "강속구 숙련"
        PitchAbilityKind.COMMAND -> "코스 숙련"
        PitchAbilityKind.MOVEMENT -> "결정구 숙련"
        PitchAbilityKind.STAMINA -> "이닝 숙련"
    }
}
