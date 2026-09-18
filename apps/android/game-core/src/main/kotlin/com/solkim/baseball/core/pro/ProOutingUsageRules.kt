package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.PitcherSnapshot

/** One pitching-change policy for the manager and the player's next-inning choice. */
public object ProOutingUsageRules {
    public fun pitchBudget(pitcher: PitcherSnapshot): Int =
        80 + (pitcher.stamina - 40).coerceAtLeast(0) / 2

    public fun canContinue(pitcher: PitcherSnapshot, outs: Int, pitches: Int, fatigue: Int, runs: Int, starter: Boolean): Boolean {
        if (outs >= if (starter) 27 else 12) return false
        val effectiveFatigue = com.solkim.baseball.core.pitch.PitchAbilityRules.effectiveFatigue(fatigue, pitcher.stamina, pitcher.effectiveMastery.stamina)
        if (fatigue >= 100 || effectiveFatigue >= 88 || runs >= 6) return false
        val budget = if (starter) pitchBudget(pitcher) else 65
        val historicFinish = starter && outs >= 21 && runs == 0 && effectiveFatigue < 70
        val limit = budget + if (historicFinish) 8 else 0
        if (pitches >= limit.coerceAtMost(125)) return false
        if (outs >= 18 && (runs >= 4 || effectiveFatigue >= 75)) return false
        return true
    }

    public fun canContinue(state: ProState): Boolean {
        val session = state.activePitch ?: return false
        val starter = session.assignment?.role == com.solkim.baseball.core.pitch.OutingRole.STARTER
        val longRelief = session.assignment?.role == com.solkim.baseball.core.pitch.OutingRole.RELIEF && (session.assignment?.entryInning ?: 9) <= 6
        return session.sessionId.endsWith(":outing-v2") && session.ended && session.game.inningState?.outs == 0 &&
            (starter || longRelief) && session.context.inning < 9 &&
            canContinue(state.pitcher, session.outs, session.pitches, session.context.fatigue, session.runsAllowed, starter)
    }
}
