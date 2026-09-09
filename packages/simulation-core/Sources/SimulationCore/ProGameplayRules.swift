import Foundation

/// Which professional gameplay rules an engine runs.
///
/// `reference` (10) is the frozen path that the Android parity data compares against, and the
/// version every already-shipped career carries. `current` is what a live career runs.
///
/// The version lives on the state (`ProCareerSnapshot.proRulesVersion`): an engine signs every
/// state it produces with its own version, so an in-progress career moves onto the newer rules at
/// its next command while its recorded seasons, contracts and awards stay exactly as they were.
///
/// - 10: frozen reference.
/// - 11: the current catcher signs and effort split reach automatic outings.
/// - 12: rebalanced professional pitching — one saturating whiff edge, a real opposing lineup,
///   earned runs tracked against an explicit runner ledger, and a direct outing whose remaining
///   innings are simulated by the same pitch engine instead of being split by innings ratio.
/// - 13: workload — pitch count, stamina, runs and the late-inning situation decide the change,
///   so an ace can finish a game.
public enum ProGameplayRules {
    /// The frozen comparison path.
    public static let reference = 10
    /// What a new or resumed career runs.
    public static let current = 13

    /// The rules version a state actually carries. Unversioned legacy saves read as 1.
    public static func version(of proRulesVersion: Int?) -> Int { proRulesVersion ?? 1 }

    /// v11+: modern recommendations in automatic outings.
    public static func usesModernPitching(_ proRulesVersion: Int?) -> Bool { version(of: proRulesVersion) >= 11 }
    /// v12+: the professional balance pass and the earned-run ledger.
    public static func usesProfessionalBalance(_ proRulesVersion: Int?) -> Bool { version(of: proRulesVersion) >= 12 }
    /// v13+: workload-driven changes and complete games.
    public static func usesWorkload(_ proRulesVersion: Int?) -> Bool { version(of: proRulesVersion) >= 13 }
}
