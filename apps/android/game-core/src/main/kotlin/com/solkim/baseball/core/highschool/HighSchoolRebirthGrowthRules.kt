package com.solkim.baseball.core.highschool

/** Learned fundamentals from completed, archived lives, independent of chosen legacy family.
 * Applied once at creation; changing families cannot erase experience or farm it on reload. */
public object HighSchoolRebirthGrowthRules {
    public fun bonus(completedLives: Int): Int = when {
        completedLives <= 0 -> 0
        completedLives <= 4 -> completedLives * 3
        else -> (12L + completedLives - 4L).coerceAtMost(16L).toInt()
    }
    public fun apply(p: HighSchoolPitcher, completedLives: Int): HighSchoolPitcher {
        val bonus = bonus(completedLives)
        if (bonus == 0) return p
        fun bump(value: Int) = (value + bonus).coerceAtMost(80)
        return p.copy(stuff = bump(p.stuff), command = bump(p.command), movement = bump(p.movement), stamina = bump(p.stamina),
            pitchProfiles = p.pitchProfiles.map { it.copy(
                control = bump(it.control), command = bump(it.command), movement = bump(it.movement),
                whiff = bump(it.whiff), weakContact = bump(it.weakContact),
                velocityTenthsKph = (it.velocityTenthsKph + bonus * 3).coerceAtMost(1600)) })
    }
}
