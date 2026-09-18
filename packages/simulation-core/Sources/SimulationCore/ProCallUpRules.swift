import Foundation

/// When the first team calls.
///
/// The engine decided this inline, so the screen could not say what a call-up needs — the
/// player watched a number they were never shown move a threshold they were never told.
/// One place holds the condition now, and the kernel and the advancement board read it
/// together (`ProAdvancementRules`). Kotlin's `ProCallUpRules` is the same rule, name for name.
public enum ProCallUpRules {
    public static let trustRequired = 60
    public static let skillRequired = 46
    public static let gamesRequired = 12
    public static let strikeoutsRequired = 40

    /// The four pitching abilities averaged. The call is about the whole pitcher.
    public static func skill(_ pitcher: PitcherSnapshot) -> Int {
        (pitcher.stuff + pitcher.command + pitcher.movement + pitcher.stamina) / 4
    }

    /// A first-season call needs a body of work behind it; after that the seasons speak.
    public static func experience(season: Int, stats: ProSeasonStats) -> Bool {
        season > 1 || stats.games >= gamesRequired || stats.strikeouts >= strikeoutsRequired
    }

    public static func qualifies(trust: Int, skill: Int, season: Int, stats: ProSeasonStats) -> Bool {
        trust >= trustRequired && skill >= skillRequired && experience(season: season, stats: stats)
    }
}
