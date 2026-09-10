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

    /// The stamina a start needs to reach the fifth inning, and with it the win.
    ///
    /// A starter cannot be the winning pitcher before fifteen outs. Under rules 13 the manager
    /// decides when the outing ends, so how much stamina buys those fifteen outs is a question
    /// only measurement answers. It is not a gradual climb — it is a step, and it lands in the
    /// same place whatever else the pitcher can do (800 starts per cell, mixed calls, fatigue 50):
    ///
    /// | 체력 | 50/60/40 | 40/45/35 | 65/65/60 |
    /// |---|---|---|---|
    /// | 55 | 17.4% | 15.2% | 10.5% |
    /// | 60 | **75.8%** | **69.4%** | **79.4%** |
    ///
    /// Below this a pitcher can lose but essentially cannot win, which is why the board says so.
    public static let staminaForFiveInnings = 60

    /// The stamina that puts a complete game within reach.
    ///
    /// Seven shutout innings are what make the manager stretch the count (`historicFinish`), and
    /// reaching twenty-one outs is a second step in the same measurement — again in the same place
    /// for every ability profile:
    ///
    /// | 체력 | 50/60/40 | 40/45/35 | 65/65/60 |
    /// |---|---|---|---|
    /// | 75 | 2.4% | 1.9% | 1.2% |
    /// | 78 | **38.6%** | **27.9%** | **37.2%** |
    ///
    /// Twenty-seven outs appear only above it. `ProOutingUsageRulesTests` holds both numbers to
    /// their measurement, so smoothing the curve fails the gate instead of quietly making the
    /// board lie.
    public static let staminaForCompleteGameChase = 78

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
