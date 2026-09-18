package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.BatSide

/** A stable batting order, independent of the player's ability and number of rebirths. */
public object ProfessionalLineup {
    private val contact = listOf(57, 60, 60, 48, 52, 48, 47, 43, 45)
    private val discipline = listOf(59, 56, 58, 54, 48, 48, 46, 45, 48)
    private val power = listOf(43, 44, 61, 69, 60, 53, 45, 42, 40)
    public fun batter(teamKey: String, turn: Int, offset: Int = 0): BatterSnapshot {
        val spot = Math.floorMod(turn - 1, 9)
        fun rating(base: Int, skill: String): Int = (base + offset +
            (StableHash.fnv1a64Value("$teamKey:$spot:$skill") % 11UL).toInt() - 5).coerceIn(20, 80)
        return BatterSnapshot("$teamKey:lineup:${spot + 1}", "상대 ${spot + 1}번 타자",
            rating(contact[spot], "contact"), rating(discipline[spot], "discipline"), rating(power[spot], "power"),
            if (StableHash.fnv1a64Value("$teamKey:$spot:side") % 100UL < 35UL) BatSide.LEFT else BatSide.RIGHT)
    }
}
