import Foundation

/// Version gate for the pitch-probability balance pass.
///
/// `legacy` is the frozen reference path: high school gameplay rules 4 and pro rules 10, the two
/// versions the Android parity fixtures compare against. Every golden fixture, the CLI, the
/// exporters and the default `PitchKernelEngine()` stay on it, so nothing here may change what a
/// legacy call computes.
///
/// The other two arenas are the rebalanced path. The old formulas let correlated ratings multiply:
/// stuff, movement, pitch whiff and velocity each bought their own whiff bonus, so a grown pitcher
/// erased the batter instead of beating them. One saturating edge replaces that sum, command buys
/// less than perfect location, and weak contact stops being a near-automatic out. School and
/// professional differ only where the two levels genuinely differ — a high school pitcher who
/// leaves one over the middle of the plate is punished for it, a professional one meets a lineup
/// that squares up better contact.
public struct PitchBalanceRules: Equatable, Sendable {
    public enum Arena: String, Equatable, Sendable, Codable {
        /// High school 4 / pro 10 — the frozen parity reference.
        case legacy
        /// High school gameplay rules 7 and later.
        case school
        /// Pro rules 11 and later.
        case professional
    }

    public var arena: Arena

    public init(arena: Arena = .legacy) {
        self.arena = arena
    }

    public static let legacy = PitchBalanceRules(arena: .legacy)
    public static let school = PitchBalanceRules(arena: .school)
    public static let professional = PitchBalanceRules(arena: .professional)

    /// True on either rebalanced arena. Guards everything the two levels share.
    public var rebalanced: Bool { arena != .legacy }
    public var isSchool: Bool { arena == .school }
    public var isProfessional: Bool { arena == .professional }
}
