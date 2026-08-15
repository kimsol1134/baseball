package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.StableHash

/** The stable, non-UI wind identity used by the current Swift-shaped high-school kernel. */
public object HighSchoolWindRules {
    public const val RULES_VERSION: Int = 2

    public fun bucketFor(careerId: String): Int =
        (StableHash.fnv1a64("$careerId|career_wind_v2").toULong(16) % 100UL).toInt()

    public fun idFor(careerId: String): String = when (bucketFor(careerId)) {
        in 0..29 -> "calm"
        in 30..37 -> "monster_generation"
        in 38..45 -> "scout_frenzy"
        in 46..53 -> "quiet_season"
        in 54..61 -> "heatwave"
        in 62..69 -> "command_year"
        in 70..77 -> "power_year"
        in 78..85 -> "battery_year"
        in 86..92 -> "spotlight_year"
        else -> "underdog_year"
    }
}
