import Foundation

/// Which high school gameplay rules an engine runs.
///
/// `reference` (4) is the frozen path. Every golden fixture, the parity exporters and the Android
/// comparison data are generated from it, so a career signed at 4 must keep computing exactly what
/// it computed the day it was signed. `current` is what a live career runs.
///
/// The version lives on the state (`HighSchoolCareerSnapshot.balanceVersion`), not on the engine
/// alone: an engine signs every state it produces with its own version, so an in-progress career
/// moves onto the newer rules at its next command while its already-recorded schedule, ratings,
/// repertoire and finished games stay exactly as they were.
///
/// - 4: frozen reference.
/// - 5: reworked draft evaluation, training progress that accumulates between growth points,
///   intensity-scaled jackpot chance.
/// - 6: intensive training costs 11 fatigue instead of 15.
/// - 7: rebalanced school pitching, opponents that no longer scale with the rebirth count,
///   completed-life inheritance, and a draft threshold matched to the harder games.
public enum HighSchoolGameplayRules {
    /// The frozen comparison path.
    public static let reference = 4
    /// What a new or resumed career runs.
    public static let current = 7

    /// The rules version a state actually carries. Unversioned legacy saves read as 1.
    public static func version(of balanceVersion: Int?) -> Int { balanceVersion ?? 1 }

    /// v5+: the reworked draft evaluation, training progress and intensity jackpot.
    public static func usesCurrentEvaluation(_ balanceVersion: Int?) -> Bool { version(of: balanceVersion) >= 5 }
    /// v6+: the lighter intensive-training fatigue cost.
    public static func usesLightenedIntensity(_ balanceVersion: Int?) -> Bool { version(of: balanceVersion) >= 6 }
    /// v7+: the school balance pass — pitching, opponents, inheritance and draft threshold.
    public static func usesSchoolBalance(_ balanceVersion: Int?) -> Bool { version(of: balanceVersion) >= 7 }
}
