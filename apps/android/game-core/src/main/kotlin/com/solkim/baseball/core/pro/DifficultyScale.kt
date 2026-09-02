package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.BatterSnapshot
import kotlin.math.max
import kotlin.math.min

/**
 * 상대는 시간이 갈수록 세져야 한다.
 * 값은 `ProAutomaticOutingSimulator`의 `batterOffset`과 같은 단위다.
 */
public object DifficultyScale {
    public const val CHAPTER_CEILING: Int = 3
    public const val REBIRTH_CEILING: Int = 4
    public const val SEASON_CEILING: Int = 8
    public const val TRACKING_CEILING: Int = 6
    public const val ARC_CEILING: Int = 14
    public const val CHALLENGE_TRACKING_CEILING: Int = 10
    public const val CHALLENGE_ARC_CEILING: Int = 18

    public fun highSchool(chapter: Int, lifeNumber: Int): Int {
        val byChapter = min(CHAPTER_CEILING, max(0, chapter - 1) * CHAPTER_CEILING / 7)
        val byLife = min(REBIRTH_CEILING, max(0, lifeNumber - 1) * 2)
        return byChapter + byLife
    }

    public fun pro(season: Int): Int = min(SEASON_CEILING, max(0, season - 1))

    public fun trackingBonus(season: Int, level: ProLevel, skill: Int, challenge: Boolean = false): Int {
        if (challenge) {
            if (season < 3 || level != ProLevel.MAJOR) return 0
            return min(CHALLENGE_TRACKING_CEILING, max(0, (skill - 54) / 2))
        }
        if (season < 5 || level != ProLevel.MAJOR) return 0
        return min(TRACKING_CEILING, max(0, (skill - 58) / 3))
    }

    public fun proArc(
        season: Int,
        level: ProLevel,
        skill: Int,
        climate: ProSeasonClimate,
        challenge: Boolean = false,
    ): Int {
        val combined = pro(season) +
            trackingBonus(season, level, skill, challenge) +
            ProSeasonClimateRules.offset(climate)
        return min(if (challenge) CHALLENGE_ARC_CEILING else ARC_CEILING, max(-2, combined))
    }

    public fun scaled(batter: BatterSnapshot, offset: Int): BatterSnapshot {
        if (offset == 0) return batter
        fun bump(value: Int): Int = min(80, max(20, value + offset))
        return batter.copy(
            contact = bump(batter.contact),
            discipline = bump(batter.discipline),
            power = bump(batter.power),
        )
    }
}
