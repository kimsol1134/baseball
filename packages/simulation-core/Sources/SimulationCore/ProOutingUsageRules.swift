import Foundation

/// When the manager comes to the mound.
///
/// Before this, an automatic outing simply ran until it had recorded eighteen outs — six innings,
/// every time, whether the pitcher was cruising or had given up seven. A start could not end early
/// and could not go long, so the ninth inning was unreachable and a blowout was something the
/// player watched to completion.
///
/// One policy answers both questions, and both the manager and the player's "one more inning?"
/// choice read it, so the game never offers a decision the manager would have overruled.
public enum ProOutingUsageRules {
    /// The pitch count a starter is trusted with. Stamina buys about one extra inning at the top.
    public static func pitchBudget(_ pitcher: PitcherSnapshot) -> Int {
        80 + max(0, pitcher.stamina - 40) / 2
    }

    /// Does this pitcher go back out?
    ///
    /// - Parameter starter: starters are allowed a full game; relievers are done after four innings.
    public static func canContinue(
        pitcher: PitcherSnapshot,
        outs: Int,
        pitches: Int,
        fatigue: Int,
        runs: Int,
        starter: Bool
    ) -> Bool {
        if outs >= (starter ? 27 : 12) { return false }
        let effectiveFatigue = PitchAbilityRules.effectiveFatigue(
            rawFatigue: fatigue,
            stamina: pitcher.stamina,
            mastery: pitcher.effectiveMastery.stamina
        )
        if fatigue >= 100 || effectiveFatigue >= 88 || runs >= 6 { return false }
        // A shutout into the seventh is the one time a manager stretches the count. This is what
        // makes a complete game something a player can chase rather than something that happens.
        let historicFinish = starter && outs >= 21 && runs == 0 && effectiveFatigue < 70
        let limit = min(125, pitchBudget(pitcher) + (historicFinish ? 8 : 0))
        if pitches >= limit { return false }
        // Past six innings the bar rises: four runs or real fatigue and the bullpen is up.
        if outs >= 18 && (runs >= 4 || effectiveFatigue >= 75) { return false }
        return true
    }
}
