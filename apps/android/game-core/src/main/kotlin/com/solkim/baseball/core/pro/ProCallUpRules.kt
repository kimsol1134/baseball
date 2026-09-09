package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.PitcherSnapshot

public object ProCallUpRules {
    public const val TRUST_REQUIRED = 60
    public const val SKILL_REQUIRED = 46
    public const val GAMES_REQUIRED = 12
    public const val STRIKEOUTS_REQUIRED = 40
    public fun skill(p: PitcherSnapshot): Int = (p.stuff + p.command + p.movement + p.stamina) / 4
    public fun experience(season: Int, stats: ProSeasonStats): Boolean = season > 1 || stats.games >= GAMES_REQUIRED || stats.strikeouts >= STRIKEOUTS_REQUIRED
    public fun qualifies(trust: Int, skill: Int, season: Int, stats: ProSeasonStats): Boolean = trust >= TRUST_REQUIRED && skill >= SKILL_REQUIRED && experience(season, stats)
}
