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

    /// Pro rules 13: fatigue follows the pitch count.
    ///
    /// Fatigue used to be charged per pitch by pitch type, so the eightieth pitch of a game cost a
    /// pitcher exactly what the first one did and a starter could be pulled by an arithmetic that
    /// never knew how long they had been out there. Here the cost accrues against the running total
    /// of pitches thrown in the game, which is what actually tires an arm — and what makes the
    /// decision to send someone back out for the ninth mean something.
    public var pitchCountFatigue: Bool

    public init(arena: Arena = .legacy, pitchCountFatigue: Bool = false) {
        self.arena = arena
        self.pitchCountFatigue = pitchCountFatigue
    }

    public static let legacy = PitchBalanceRules(arena: .legacy)
    public static let school = PitchBalanceRules(arena: .school)
    public static let professional = PitchBalanceRules(arena: .professional)
    /// Pro rules 13 and later: the professional balance pass plus pitch-count fatigue.
    public static let professionalWorkload = PitchBalanceRules(
        arena: .professional, pitchCountFatigue: true
    )

    /// True on either rebalanced arena. Guards everything the two levels share.
    public var rebalanced: Bool { arena != .legacy }
    public var isSchool: Bool { arena == .school }
    public var isProfessional: Bool { arena == .professional }
}
